/// Keeps the Home Screen and Lock Screen widgets in step with her week.
///
/// The widgets (`ios/OwnHubWidgets`) are a separate process and cannot ask the
/// app anything. They read one JSON string from the App Group
/// `group.com.ownhub.fitness`, and this file writes it, through `home_widget`.
/// What the string may contain is decided in `widget_projection.dart` and
/// nowhere else.
///
/// ## Nothing leaves the phone
///
/// The App Group is storage on this handset shared between the app and its
/// own extension (on Android, the app's own SharedPreferences, read by the
/// widget provider in the same package). No network call is made from here and none is reachable
/// from it. The manifest reason is 1C8F.1, the App Group one.
///
/// ## When it writes
///
/// Like `LocalPersistence`: on [AppChanges], debounced by [writeDelay], and at
/// once when the app is paused, so the widget is current the moment she leaves
/// the app. A payload equal to the last one written is not written again and
/// the widgets are not asked to reload, which keeps the reload budget for the
/// changes that matter.
///
/// ## When it is closed
///
/// Whenever [isOpen] says so: signed out, not verified, or waiting on a
/// reviewer. The demo tour never reaches here, because it runs before any
/// account and its sample repositories are not the ones [readDay] reads.
/// Signing out and deleting her account call [clear], which removes the key.
///
/// ## It cannot take the app down
///
/// Every platform call is caught and kept in [lastFailure]. And like
/// `LocalPersistence` it is off unless `main()` turns it on, so a widget test
/// that pumps the app talks to no platform channel.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../features/today/domain/today_day.dart';
import '../features/today/domain/widget_projection.dart';
import '../l10n/app_l10n.dart';
import 'app_changes.dart';

/// The App Group shared with the widget extension. Must match both
/// entitlements files.
const String kWidgetAppGroup = 'group.com.ownhub.fitness';

/// The `kind` of each widget in `ios/OwnHubWidgets`. A reload names them.
const List<String> kWidgetKinds = ['OwnHubWeek', 'OwnHubToday'];

/// The Android `AppWidgetProvider` class (in the app's package) that draws the
/// Today widget. `android/app/src/main/kotlin/com/ownhub/app` holds it.
const String kAndroidWidgetName = 'TodayWidgetProvider';

/// Where the payload goes. One implementation ships; the interface exists so a
/// test can watch what was written without a platform channel.
abstract class WidgetStore {
  Future<void> useAppGroup(String groupId);

  /// Writes [value] under [key], or removes the key when [value] is null.
  Future<void> save(String key, String? value);

  /// Asks the platform to redraw the widget of [kind] from the stored payload.
  Future<void> reload(String kind);
}

/// The App Group, through `home_widget`.
class HomeWidgetStore implements WidgetStore {
  const HomeWidgetStore();

  @override
  Future<void> useAppGroup(String groupId) async {
    await HomeWidget.setAppGroupId(groupId);
  }

  @override
  Future<void> save(String key, String? value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<void> reload(String kind) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android has the Today widget only; the Week kind is iOS-only.
      if (kind != kWidgetKinds[1]) return;
      await HomeWidget.updateWidget(androidName: kAndroidWidgetName);
      return;
    }
    await HomeWidget.updateWidget(iOSName: kind);
  }
}

/// Writes the widget payload as she goes.
class HomeWidgetSync {
  HomeWidgetSync._();

  static final HomeWidgetSync instance = HomeWidgetSync._();

  /// The same settling time `LocalPersistence` uses.
  static const Duration writeDelay = Duration(milliseconds: 400);

  /// Where the payload goes. Replaceable so a test can hold it in memory.
  WidgetStore store = const HomeWidgetStore();

  /// Today as Home draws it. Wired in `main()` to the router's repository.
  TodayDay Function()? readDay;

  /// Whether the widget may show her week at all. Closed unless wired.
  bool Function() isOpen = () => false;

  /// The clock the projection compares the day with.
  DateTime Function() now = DateTime.now;

  /// Her in-app language, which can differ from the phone's.
  Locale _locale = const Locale('en');

  /// The last error a platform call raised, kept rather than thrown.
  Object? lastFailure;

  /// The payload last written, so an unchanged one is not written twice.
  String? _last;

  Timer? _pending;
  bool _running = false;
  bool _groupSet = false;
  _WriteOnPause? _observer;

  /// Bumped by [clear], so a write already handed to the platform when she
  /// signs out is removed again rather than left behind. See
  /// `LocalPersistence.erase` for the race this closes.
  int _clears = 0;

  bool get isRunning => _running;

  /// Starts listening and writes once. Called from `main()` on iOS and Android.
  void start({
    required TodayDay Function() readDay,
    required bool Function() isOpen,
    Locale? locale,
  }) {
    this.readDay = readDay;
    this.isOpen = isOpen;
    if (locale != null) _locale = locale;
    if (_running) return;
    _running = true;
    AppChanges.instance.addListener(_changed);
    _observer = _WriteOnPause(this);
    WidgetsBinding.instance.addObserver(_observer!);
    unawaited(flush());
  }

  /// Stops listening and drops any pending write.
  void stop() {
    _pending?.cancel();
    _pending = null;
    if (!_running) return;
    _running = false;
    AppChanges.instance.removeListener(_changed);
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _observer = null;
    }
  }

  /// Her language changed in the app. The widget follows it, rather than the
  /// phone's language, so it is rewritten now.
  void useLocale(Locale locale) {
    if (locale == _locale) return;
    _locale = locale;
    if (_running) unawaited(flush());
  }

  /// Writes now, cancelling any pending write.
  Future<void> flush() async {
    _pending?.cancel();
    _pending = null;
    if (!_running) return;
    await _write();
  }

  /// Removes the payload and redraws both widgets closed. Signing out and
  /// deleting her account call it.
  ///
  /// The pending write is cancelled before the first await, so nothing
  /// scheduled before the sign-out can land after it.
  Future<void> clear() async {
    _clears++;
    _pending?.cancel();
    _pending = null;
    _last = null;
    if (!_running) return;
    await _remove();
  }

  /// Back to a fresh instance. Tests only.
  @visibleForTesting
  void reset() {
    stop();
    store = const HomeWidgetStore();
    readDay = null;
    isOpen = () => false;
    now = DateTime.now;
    _locale = const Locale('en');
    lastFailure = null;
    _last = null;
    _groupSet = false;
  }

  /// The payload as it would be written now.
  @visibleForTesting
  String encode() {
    final lang = _locale.languageCode == 'ar' ? 'ar' : 'en';
    final l10n = lookupAppL10n(Locale(lang));
    final day = readDay?.call();
    final open = day != null && isOpen();
    return jsonEncode(
      open
          ? WidgetProjection.build(
              day: day,
              open: true,
              l10n: l10n,
              lang: lang,
              now: now(),
            )
          : WidgetProjection.closed(l10n: l10n, lang: lang),
    );
  }

  void _changed() {
    _pending?.cancel();
    _pending = Timer(writeDelay, () {
      _pending = null;
      unawaited(_write());
    });
  }

  Future<void> _write() async {
    final clearsWhenStarted = _clears;
    String payload;
    try {
      payload = encode();
    } catch (error) {
      lastFailure = error;
      return;
    }
    if (payload == _last) return;
    try {
      await _useGroup();
      await store.save(kWidgetPayloadKey, payload);
      _last = payload;
      await _reloadAll();
    } catch (error) {
      lastFailure = error;
      return;
    }
    // She signed out while the platform held this write: take it back out.
    if (_clears != clearsWhenStarted) {
      _last = null;
      await _remove();
    }
  }

  Future<void> _remove() async {
    try {
      await _useGroup();
      await store.save(kWidgetPayloadKey, null);
      await _reloadAll();
    } catch (error) {
      lastFailure = error;
    }
  }

  Future<void> _useGroup() async {
    if (_groupSet) return;
    await store.useAppGroup(kWidgetAppGroup);
    _groupSet = true;
  }

  Future<void> _reloadAll() async {
    for (final kind in kWidgetKinds) {
      await store.reload(kind);
    }
  }
}

/// Writes when she leaves the app, so the widget is current when she sees it.
class _WriteOnPause with WidgetsBindingObserver {
  _WriteOnPause(this._sync);

  final HomeWidgetSync _sync;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_sync.flush());
  }
}
