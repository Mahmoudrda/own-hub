import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state/analytics_consent.dart';
import 'app_state/analytics_session.dart';
import 'app_state/posthog_analytics.dart';
import 'app_state/profile_photo_state.dart';
import 'app_state/cloud_store.dart';
import 'app_state/crash_consent.dart';
import 'app_state/feel_prefs.dart';
import 'app_state/first_run_moments.dart';
import 'app_state/sound.dart';
import 'app_state/tip_anchors.dart';
import 'features/eat/data/meal_camera.dart' show sweepCameraLeftovers;
import 'features/eat/data/platform_meal_speech.dart';
import 'features/eat/domain/meal_speech.dart';
import 'features/onboarding/presentation/deep_breath_view.dart';
import 'ui/hand/launch_splash.dart';
import 'features/eat/domain/meal_images.dart';
import 'app_state/crash_reports.dart';
import 'app_state/eat_state.dart';
import 'app_state/events_state.dart';
import 'app_state/remote_features.dart';
import 'app_state/community_foods_state.dart';
import 'app_state/exercise_library_state.dart';
import 'app_state/workout_library_state.dart';
import 'app_state/content_images.dart';
import 'ui/content_image.dart';
import 'app_state/firebase_boot.dart';
import 'app_state/home_widget_sync.dart';
import 'app_state/local_persistence.dart';
import 'app_state/snapshot_owner.dart';
import 'app_state/onboarding_state.dart';
import 'app_state/app_changes.dart';
import 'app_state/role_state.dart';
import 'app_state/notification_taps.dart';
import 'app_state/widget_links.dart';
import 'config/legal_links.dart';
import 'features/account/domain/health_backup.dart';
import 'features/coach/domain/coach_invite.dart';
import 'features/onboarding/domain/starting_program.dart'
    show StartingProgrammes;
import 'domain/analytics/analytics_gateway.dart';
import 'domain/flags/feature_flags.dart';
import 'domain/identity/user_roles.dart';
import 'l10n/app_l10n.dart';
import 'features/signup/domain/auth_repository.dart';
import 'features/train/domain/exercise_traits.dart' show ExerciseTraits;
import 'routing/app_router.dart';
import 'routing/app_routes.dart';
import 'routing/platform_links.dart';
import 'theme/app_tokens.dart';
import 'theme/hand_theme.dart';

/// Reads what each move is measured on, then re-reads her logged history once
/// for bests the old detector could not see. The table comes first: with none
/// loaded a best fails closed. Idempotent, and it pays and counts nothing.
@visibleForTesting
Future<void> prepareMoveBests() async {
  await ExerciseTraits.load();
  AppRouter.sessionBests.backfill(repository: AppRouter.trainRepository);
}

Future<void> main() async {
  // Dark status-bar content, before anything is drawn.
  //
  // The theme sets this too, but `AppBarTheme.systemOverlayStyle` only reaches
  // screens that HAVE an app bar, and several — C13 among them — pass none at
  // all. Without this those screens keep the platform default and draw a
  // near-white clock on the pale surface colour.
  WidgetsFlutterBinding.ensureInitialized();
  // Only built, and the phone's speech service only touched, when she taps the
  // microphone on E03.
  MealSpeech.create = PlatformMealSpeechEngine.new;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  LicenseRegistry.addLicense(_handFontLicences);

  // The four public pages must have addresses before a store build runs at
  // all (M2): a release build with an empty privacy URL stops here, as the
  // preflight would have. A debug build only says so, so development is not
  // blocked on a domain.
  LegalLinks.requireForRelease(release: kReleaseMode);
  if (kDebugMode && !LegalLinks.allSet) {
    debugPrint('LegalLinks are empty: a release build will refuse to start.');
  }

  // Usage statistics. A release build uses Firebase and the bounded PostHog
  // milestone sink. Each provider
  // sends nothing until she allows it ("Help improve Own Hub", C06 or
  // Privacy): collection is off natively and the sink checks her choice on
  // every event. A debug build prints the funnel to the console instead. See
  // `lib/app_state/analytics_session.dart`.
  AppRouter.analytics = AnalyticsGateway(
    analyticsSinkFor(release: kReleaseMode, debug: kDebugMode),
  );

  // Her week, read off this phone BEFORE the first frame.
  //
  // Awaited here rather than loaded from a screen so that the first thing she
  // sees is already hers: Home drawn once, from her own session count and her
  // own meal, instead of the app's defaults replaced a frame later. One read,
  // one decode — see `lib/app_state/local_persistence.dart`.
  //
  // It cannot fail the launch. A missing, empty, truncated, corrupt or older
  // snapshot restores nothing and the app opens exactly as it did before any
  // of this existed.
  await LocalPersistence.instance.load();
  // Whose week that was. Read with it, so the check below has the owner.
  await SnapshotOwner.instance.load();
  LocalPersistence.instance.start();

  // Her day moves on to today, and any week that ended while the app was
  // closed is closed now (D41). After the restore, so it works on her data.
  AppRouter.startOfDay();

  // Her crash-report choice, read before Firebase so collection is set from
  // it at once. Off unless she allowed it (privacy policy v3, 3.7).
  await CrashConsent.instance.load();
  // Her usage-statistics choice, read before Firebase for the same reason.
  // Off unless she allowed it, and a separate choice from crash reports.
  await AnalyticsConsent.instance.load();
  unawaited(
    PostHogAnalytics.instance.applyConsent(AnalyticsConsent.instance.allowed),
  );
  // The day each account on this phone first landed, so a woman signing back
  // in does not get the getting started tips again.
  await TipAnchors.instance.load();
  // Whether the first-launch breath and the plan tick have been shown.
  await FirstRunMoments.instance.load();
  // Her profile photo, if she set one. Kept on this phone only.
  await ProfilePhotoState.instance.load();
  // Her Sounds and Haptics switches, kept on this phone only.
  await FeelPrefs.instance.load();
  // The starting programmes, bundled. A file that cannot be read leaves the
  // placeholder catalogue, and Train is what it was.
  try {
    StartingProgrammes.adopt(
      await rootBundle.loadString(StartingProgrammes.assetPath),
    );
  } catch (_) {}

  await prepareMoveBests();

  // Which painted meal pictures are bundled. Unreadable means none, and every
  // screen keeps its drawn mark.
  try {
    MealImages.adopt(await rootBundle.loadString(MealImages.indexPath));
  } catch (_) {}

  // The back end, brought up AFTER her local week and unable to fail the
  // launch. The order matters: whatever Firebase does or does not do, the
  // first frame is already drawn from her own data, so a dead network costs
  // her nothing she can see. See `lib/app_state/firebase_boot.dart`.
  await FirebaseBoot.start();

  // Whose phone this is, BEFORE any of her data can be drawn or synced. A
  // different account than the one the snapshot belongs to wipes it here, and
  // again whenever another account signs in later. This listener is added
  // before the cloud store's, so the erase runs first on the same event.
  // Signed out (the tour) claims nothing.
  final signedIn = AppRouter.authRepository.current;
  if (signedIn is AuthSignedIn) {
    await SnapshotOwner.instance.claim(signedIn.uid);
  }
  AppRouter.authRepository.watch().listen((state) {
    if (state is AuthSignedIn) {
      unawaited(SnapshotOwner.instance.claim(state.uid));
    }
  });
  // Pictures from the content library, for a signed-in account only.
  ContentImage.resolver = ContentImages.url;

  // Crashes, reported in a release build only, and only once she has allowed
  // it: the handlers are wired here and `CrashReports` returns at once
  // without her consent (see FirebaseBoot and CrashConsent). The reports carry the error's type and its stack, never its message and
  // never anything about her: no user identifier, no custom key, no log line
  // is ever set (R8, see `lib/app_state/crash_reports.dart`).
  if (FirebaseBoot.crashReporting) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(CrashReports.flutterError(details));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(CrashReports.uncaught(error, stack));
      return true;
    };
    // Errors outside the Flutter context, on this isolate. The app spawns no
    // isolate of its own; one that is added later reports through the same
    // `CrashReports.uncaught`.
    Isolate.current.addErrorListener(
      RawReceivePort((Object? pair) {
        if (pair is! List || pair.length != 2) return;
        final stack = pair.last;
        final Object error = (pair.first as Object?) ?? 'unknown';
        unawaited(
          CrashReports.uncaught(
            error,
            stack is String ? StackTrace.fromString(stack) : StackTrace.empty,
          ),
        );
      }).sendPort,
    );
  }

  // Has the server already let her in? Read here, because
  // `AppRouter.onGenerateRoute` is synchronous and the whole-app gate has to
  // answer before the first route is built rather than a frame later. Then
  // what the server last said about her check (S8): waiting for a reviewer,
  // booked, refused, or approved while the app was closed.
  //
  // Bounded as a whole at five seconds and unable to fail the launch. A
  // verified woman with no network is not locked out: the token read falls
  // back to what this phone proved before (R1). No evidence still means the
  // check rather than the app. See `AppRouter.readVerificationAtLaunch`.
  await AppRouter.readVerificationAtLaunch();
  AppRouter.watchVerificationToken();
  AppRouter.watchPrivateCoaching();

  // The Home Screen and Lock Screen widgets (iOS), and the Android Today
  // widget. They read this week's
  // count and today's state from the same repository Home draws, and only
  // while she is signed in and verified; otherwise they say "Open Own Hub to
  // start". Started after the verification read above, so the first payload
  // it writes already knows whether she is let in. See
  // `lib/app_state/home_widget_sync.dart`.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    HomeWidgetSync.instance.start(
      readDay: () => AppRouter.todayRepository.day,
      isOpen: () => AppRouter.isVerified && AppRouter.signedInUid != null,
      locale: AppRouter.localePreference.read()?.locale,
    );
    WidgetLinks.enabled = true;
  }

  // A code her coach sent, kept through a check that finished while the app
  // was closed. Nothing happens without one. Not awaited.
  unawaited(AppRouter.redeemPendingInvite());

  // Her acceptance of the Terms and Privacy Policy (M1): a pending one from
  // C06 is sent, and if the versions in force are not accepted the legal
  // update sheet opens over the first screen. Not awaited: the first frame
  // never waits on the network.
  unawaited(AppRouter.checkLegalAtLaunch());

  // The cloud copy of her week, started but deliberately NOT awaited.
  //
  // `start()` only attaches listeners and reads one preferences key; it does
  // no network work of its own, so awaiting it would be harmless today. That
  // is precisely why it is not awaited: the promise this boot makes is that
  // nothing before the first frame touches the network, and a promise kept by
  // accident is one a later edit breaks quietly. `unawaited` makes it
  // structural rather than incidental.
  //
  // With no account, no Firebase, or no verified claim it does nothing at all,
  // and the app is exactly what it was before any of this existed. See
  // `lib/app_state/cloud_store.dart`.
  //
  // Her health backup choice is read first (a local key, no network). If it
  // is on, the server's consent record is checked before the sync starts, so
  // a phone that thinks it may back up her health data cannot push it after
  // the server withdrew the consent. Off, the check returns at once.
  await HealthBackupPreference.instance.load();
  unawaited(() async {
    try {
      await AppRouter.reconcileHealthBackup();
    } catch (_) {
      // The rules refuse health writes without the consent anyway.
    }
    // A pledge agreed offline, or whose record failed, is sent again. Not
    // awaited: the sync never waits on it.
    unawaited(AppRouter.retryPledgeRecord());
    await CloudStore.instance.start();
  }());

  // Only a cold start draws the logo on; a resume never builds the app again.
  LaunchSplash.enabled = true;
  runApp(const OwnHubApp());

  // The cue sounds are loaded into memory after the first frame is queued and
  // never waited on; until they are, nothing plays.
  unawaited(AppSound.start());

  // Any photo file the camera left behind (a shutter that failed after it
  // wrote, a delete that did not go through) goes now, after the first frame
  // and without waiting on it. No photo is kept on the phone.
  unawaited(sweepCameraLeftovers());

  // The once-a-day recipe library check, after the first frame so it can
  // never delay it. Offline or signed out it reads nothing and the bundled
  // seed stays the library.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(EatAppState.instance.refreshRecipes()),
  );

  // The switches members take from the server (only Feature.events), then
  // the events themselves when it is on. After the first frame, and nothing
  // is read for an account that is not verified.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(
      RemoteFeatures.load().then((_) => EventsState.instance.refresh()),
    ),
  );

  // The owner's workouts: the cache at once, the server at most once a day.
  // The bundled session stays the answer for day one whatever this finds.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(WorkoutLibraryState.instance.refresh()),
  );

  // The exercise library (D42) the same way. Its clips are fetched only when
  // she opens a move.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(ExerciseLibraryState.instance.refresh()),
  );

  // The foods other women shared and the owner approved: the cache at once,
  // the server at most once a day.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(CommunityFoodsState.instance.refresh()),
  );

  // The Egyptian dish pack, so the plates Home offers can be named and logged
  // before she ever opens Eat.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => EatAppState.instance.ensureFoodPack(),
  );
}

/// Every OFL face bundled in `assets/fonts/`. The licence asks that its text
/// travel with the font, and the licences page is where it travels to.
///
/// Rubik was missing here for a long time while the two handwriting faces were
/// registered, which is an easy omission to make and a hard one to notice:
/// Rubik is the body face of the entire product, so it is the one a reader is
/// most likely to ask about and the one whose absence says least. The use was
/// always permitted, OFL 1.1 like the others. What was missing was the notice,
/// and a notice nobody can reach is the same as no notice at all.
Stream<LicenseEntry> _handFontLicences() async* {
  for (final (family, asset) in [
    ('La Belle Aurore', 'assets/fonts/OFL-LaBelleAurore.txt'),
    ('Aref Ruqaa', 'assets/fonts/OFL-ArefRuqaa.txt'),
    ('Rubik', 'assets/fonts/OFL-Rubik.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks([
      family,
    ], await rootBundle.loadString(asset));
  }
}

/// Holds the chosen locale. Arabic is not a setting buried in preferences here —
/// C02 asks for the language before anything else, so the app must be able to
/// switch without a restart.
class LocaleScope extends InheritedNotifier<ValueNotifier<Locale>> {
  const LocaleScope({
    super.key,
    required ValueNotifier<Locale> super.notifier,
    required super.child,
  });

  static ValueNotifier<Locale> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;

  /// The same, or null where the app's scope is not above [context], which is
  /// a screen built on its own in a test.
  static ValueNotifier<Locale>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}

class OwnHubApp extends StatefulWidget {
  const OwnHubApp({super.key});

  @override
  State<OwnHubApp> createState() => _OwnHubAppState();
}

class _OwnHubAppState extends State<OwnHubApp> with WidgetsBindingObserver {
  /// This app's navigator, lent to the router for the launch-time legal
  /// update sheet. Owned here so every app gets its own.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Read once: the logo draws on at a cold start only.
  final bool _coldStart = LaunchSplash.takeColdStart();

  @override
  void initState() {
    super.initState();
    AppRouter.navigatorKey = _navigatorKey;
    WidgetsBinding.instance.addObserver(this);
    // Her training reminders, set again in the language the app opens in and
    // again whenever she changes it, so a reminder never arrives in the
    // language she left. Nothing happens when she has none. After the first
    // frame: setting them up first reads the whole time-zone database, which
    // the first frame has no use for.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Opening the app starts the gentle check-ins counting again. The
      // navigator exists by now, so a tap on a notification that launched
      // the app can open its screen.
      _noteOpened();
      NotificationTaps.start(_navigatorKey);
      unawaited(AppRouter.startPushWatch(_locale.value.languageCode));
    });
    _locale.addListener(_reapplyReminders);
    // The widgets speak the language she chose here, not the phone's.
    _relabelWidgets();
    _locale.addListener(_relabelWidgets);
    // A language she chooses is counted, as the code alone.
    _locale.addListener(_reportLanguage);
    // The facts every event carries (language, widget, channel), and
    // a return after a quiet week, after the first frame and again whenever
    // she allows statistics. Nothing leaves the phone unless she allowed it.
    // Granting also counts this opening: the first frame ran before she chose.
    AnalyticsConsent.onGranted = _onStatisticsGranted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _describeForStatistics();
      unawaited(AnalyticsSession.noteOpened(DateTime.now()));
    });
    // A tap on a widget opens its screen, once there is a navigator to push
    // it on. Nothing happens off iOS.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(WidgetLinks.start(_navigatorKey)),
    );
    // Every change of side, chosen at C08 or switched from her picture, is
    // kept for the next launch (R1-P17).
    _roles.addListener(_keepRoles);
    AppChanges.instance.addListener(_followAccount);
  }

  void _keepRoles() => RoleState.instance.keep(_roles.value);

  String? _roleUid = AppRouter.signedInUid;

  /// Her side follows the account: another woman signing in on this phone
  /// starts from her own roles, not the last one's.
  void _followAccount() {
    final uid = AppRouter.signedInUid;
    final next = rolesAfterAccountChange(_roleUid, uid, AppRouter.featureFlags);
    _roleUid = uid;
    if (next == null || next == _roles.value) return;
    // Not a choice of hers, so it is not kept as one.
    _roles.removeListener(_keepRoles);
    _roles.value = next;
    _roles.addListener(_keepRoles);
  }

  void _relabelWidgets() => HomeWidgetSync.instance.useLocale(_locale.value);

  void _reportLanguage() =>
      AnalyticsSession.languageChanged(_locale.value.languageCode);

  void _onStatisticsGranted() {
    _describeForStatistics();
    unawaited(AnalyticsSession.noteOpened(DateTime.now()));
  }

  void _describeForStatistics() => unawaited(
    AnalyticsSession.describe(languageCode: _locale.value.languageCode),
  );

  void _reapplyReminders() => unawaited(
    AppRouter.reapplyTrainingReminders(lookupAppL10n(_locale.value)),
  );

  /// Opened or brought back: notes it, then sets everything again, which also
  /// catches a new time zone or a day that moved on.
  void _noteOpened() =>
      unawaited(AppRouter.noteAppOpened(lookupAppL10n(_locale.value)));

  /// A URL the platform pushes onto the running app. This State is registered
  /// before the navigator's own observer, so it is asked first: a coach link
  /// or a screen goes on to the router, anything else (a widget tap, a sign-in
  /// callback) is dropped here instead of opening the unknown-route page.
  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async => !appFollowsPushedRoute(routeInformation.uri);

  /// Back in the foreground: a refresh the network refused at launch is
  /// tried again (R1). Does nothing when nothing is owed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) AppRouter.finishWorkoutIfClosing();
    if (state == AppLifecycleState.resumed) {
      // A phone left open overnight comes back on a new day, and on a Monday
      // on a new week.
      AppRouter.startOfDay();
      unawaited(AppRouter.refreshVerificationIfOwed());
      // A library published while she was away, or one an offline launch
      // could not fetch. Rate-limited inside; usually a no-op.
      unawaited(ExerciseLibraryState.instance.refresh());
      unawaited(CommunityFoodsState.instance.refresh());
      unawaited(CrashReports.trail(CrashTrail.resumed));
      unawaited(AnalyticsSession.noteOpened(DateTime.now()));
      _noteOpened();
    }
  }

  /// The language she has already chosen, else the one her phone is set to,
  /// else English.
  ///
  /// The phone is the better guess and it used to be ignored: this shipped in
  /// Egypt opening in English on a handset set to Arabic, with the chooser one
  /// screen deep. The whole Arabic product was in the binary and she had to go
  /// looking for it.
  ///
  /// `--dart-define=OWNHUB_LOCALE=ar` still forces a language, because a
  /// screenshot of the Arabic build has to be repeatable and right-to-left
  /// layout is only ever checked by looking at it. A choice she has made wins
  /// over everything, and it is read before the first frame so the app opens in
  /// her language rather than switching once she notices.
  final ValueNotifier<Locale> _locale = ValueNotifier(
    AppRouter.localePreference.read()?.locale ?? _firstRunLocale(),
  );

  /// What to open in before she has said. `const String.fromEnvironment`
  /// defaults to empty rather than to a language, so an unforced build falls
  /// through to the phone.
  static Locale _firstRunLocale() {
    const forced = String.fromEnvironment('OWNHUB_LOCALE');
    if (forced.isNotEmpty) return Locale(forced);
    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      for (final supported in AppL10n.supportedLocales) {
        if (supported.languageCode == locale.languageCode) return supported;
      }
    }
    return const Locale('en');
  }

  /// Her roles, and which app she is in (D11). Trainee until C08 says
  /// otherwise: it is the common case, and it is the safe one — the trainee
  /// side grants nothing a coach account would.
  ///
  /// With [Feature.accountRequired] off there is no sign-up to choose a role
  /// in, so she is a guest. She holds both roles only where there is a coach
  /// side to hold: the first release ships without one, and a picture that
  /// switches to an app that is switched off is a door into nothing.
  ///
  /// What she chose before is restored first (R1-P17): it used to start as a
  /// trainee on every launch, so a coach came back to the trainee side.
  final ValueNotifier<UserRoles> _roles = ValueNotifier(
    launchRoles(AppRouter.featureFlags),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locale.removeListener(_reapplyReminders);
    _locale.removeListener(_relabelWidgets);
    _locale.removeListener(_reportLanguage);
    if (AnalyticsConsent.onGranted == _onStatisticsGranted) {
      AnalyticsConsent.onGranted = null;
    }
    _locale.dispose();
    _roles.removeListener(_keepRoles);
    AppChanges.instance.removeListener(_followAccount);
    _roles.dispose();
    super.dispose();
  }

  /// The route to open on, preferring one the platform supplied.
  ///
  /// Falls back to the front door for anything unrecognised. The fallback is
  /// the point: an unknown route must not reach the initial-route machinery,
  /// which resolves nothing and renders a blank white page — running,
  /// responsive and completely empty. That shipped once already.
  ///
  /// With no route supplied, the front door depends on
  /// [Feature.accountRequired]: sign-up (C01) when an account is required,
  /// Home (T01) when it is not.
  ///
  /// The setup questions are not chosen here, and the reason is worth stating
  /// where somebody will look for them. They are not an alternative front door;
  /// they open **on top of** the front door, as the second entry of
  /// [_firstRunStack], so that finishing, skipping or closing is a pop back to
  /// the screen underneath rather than a push to a new one. See
  /// `lib/app_state/onboarding_state.dart`.
  String _initialRoute() =>
      _openable(WidgetsBinding.instance.platformDispatcher.defaultRouteName);

  /// [name] if the app is willing to OPEN on it, else the front door.
  ///
  /// Two rules, and both are about the first thing a woman ever sees rather
  /// than about reachability, which `onGenerateRoute` already decides.
  ///
  ///   * **A route this build does not resolve.** The admin console in a
  ///     release binary. It is already unreachable; without this she would
  ///     launch into the "no screen serves this" page instead of the app.
  ///   * **A route whose feature is switched off.** `onGenerateRoute` answers
  ///     one with `FeatureOff` — an app bar carrying the raw screen id and a
  ///     sentence about a feature flag, in English, with no way back because
  ///     there is nothing underneath it. Pushed onto a running app that is a
  ///     dead end she can leave. As the opening screen it is the entire
  ///     product. `community`, `coaching`, `marketplace` and `assistant` are
  ///     all off in the first release, so every link anyone shares about them
  ///     before the second release arrives exactly here. `resolvesInThisBuild`
  ///     does not cover it: those screens are built, tested and resolvable,
  ///     they are merely switched off.
  ///
  /// It is a separate method because it has to be applied in TWO places, and
  /// the reason is a trap worth naming. `WidgetsApp` does not simply use the
  /// `initialRoute` it is handed: when the platform supplied a route of its
  /// own it prefers that one and ignores `initialRoute` entirely. So the
  /// filtering this app did in `_initialRoute` alone never ran in the one case
  /// it was written for — a deep link — and the admin-console guard above has
  /// been quietly ineffective for as long as it has existed. [_firstRunStack]
  /// is where the name actually arrives, so that is where it must also hold.
  static String _openable(String name) {
    final id = screenIdForRoute(name);
    if (id != null &&
        AppRouter.resolvesInThisBuild(id) &&
        AppRouter.screenIsOn(id)) {
      return name;
    }
    return _frontDoor;
  }

  /// The app's own first screen, with nothing supplied from outside.
  ///
  /// With an account required, the welcome screen is for a woman who has no
  /// account on this phone yet. A verified woman opens on Home, and a signed
  /// in one who is not verified yet also asks for Home, where the gate sends
  /// her to the check (C09) or to the screen that says a reviewer will call
  /// (C14). Sending everyone to C01 put a verified woman on "Get started"
  /// every time she opened the app.
  static String get _frontDoor => AppRouter.frontDoor;

  /// The routes the app opens holding, newest last.
  ///
  /// Generated here as ONE route each, rather than letting Flutter split them.
  ///
  /// Flutter's default splits "/signup/c01" into "/", "/signup" and
  /// "/signup/c01" and asks onGenerateRoute for each ancestor. Neither "/" nor
  /// "/signup" is a screen, so both return null, the initial route fails, and
  /// the app renders a blank white page — running, responsive, and completely
  /// empty.
  ///
  /// This shipped once. Every test passed and the app launched fine; only a
  /// screenshot caught it, because pumpWidget does not exercise the
  /// ancestor-splitting path that breaks it.
  ///
  /// On a first launch the stack is two deep: the front door, and the setup
  /// questions open on top of it. Both are built before the first frame and
  /// neither is animated in, so she sees `O01` and not a flash of a Home she
  /// has not filled in yet. The questions are stacked only over the app's own
  /// front door — a build launched straight onto a named screen for a
  /// screenshot, or a notification landing on `T03`, is left exactly where it
  /// was sent.
  List<Route<dynamic>> _firstRunStack(String supplied) {
    // Filtered HERE, not only in `_initialRoute`. `WidgetsApp` prefers the
    // platform's own route over the `initialRoute` it was given, so on the one
    // path that matters — a deep link — this is the only place the decision
    // can be made. See [_openable].
    // A link from the platform: keep what it names; the front door still opens.
    final link = parseOwnHubLink(supplied);
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppRouter.followLink(link),
      );
    }
    final initial = _openable(supplied);

    Route<dynamic> routeFor(String name) =>
        AppRouter.onGenerateRoute(RouteSettings(name: name)) ??
        AppRouter.onUnknownRoute(RouteSettings(name: name));

    final front = routeFor(initial);
    // Compared against the front door itself rather than against
    // `_initialRoute()`, which answers with whatever the platform supplied. A
    // build launched straight onto `/onboarding/o02` for a screenshot would
    // otherwise have question one stacked on top of question two.
    if (!OnboardingState.instance.isDue || initial != _frontDoor) {
      return [front];
    }
    final setup = AppRouter.onGenerateRoute(
      RouteSettings(name: appRoutes['O01']!.name),
    );
    if (setup == null) return [front];
    // The very first launch of a phone with nobody signed in: one deep breath
    // on top of the questions, shown once. Never for a returning member.
    if (FirstRunMoments.instance.breathDue &&
        AppRouter.signedInUid == null &&
        !OnboardingState.instance.beforeSignup) {
      return [
        front,
        setup,
        MaterialPageRoute<void>(builder: (_) => const DeepBreathView()),
      ];
    }
    return [front, setup];
  }

  @override
  Widget build(BuildContext context) {
    // RoleScope sits above MaterialApp so every route can read it: routes are
    // built by the Navigator, which is a descendant, and a role switch must
    // rebuild the navigation and the screen under it together.
    return RoleScope(
      notifier: _roles,
      child: LocaleScope(
        notifier: _locale,
        child: ValueListenableBuilder<Locale>(
          valueListenable: _locale,
          builder: (context, locale, _) => MaterialApp(
            navigatorKey: _navigatorKey,
            onGenerateTitle: (context) => 'Own Hub',
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            // buildTheme takes the locale because Arabic renders two points larger
            // with more line height; the size decision belongs in the theme, not in
            // per-screen overrides.
            theme: handTheme(buildTheme(locale)),
            // The front door: C01, the first screen a woman ever sees. Expressed
            // as a screen id rather than a path string so it cannot drift from the
            // generated inventory.
            //
            // A route the platform supplies wins, when it names a real screen.
            // That is the form a notification tap or a deep link arrives in —
            // T07's lock-screen nudge has nowhere to land without it — and it is
            // also what allows a build to be launched directly onto any screen
            // for a screenshot. Both rendering defects in this app's history
            // were caught by a screenshot and by nothing else, so being able to
            // take one of an arbitrary screen is worth this much.
            initialRoute: _initialRoute(),
            // Generated ourselves, one route per entry, and two of them on a
            // first launch. See `_firstRunStack`.
            onGenerateInitialRoutes: _firstRunStack,
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
            builder: (context, child) => LaunchSplash(
              show: _coldStart,
              child: child ?? const SizedBox(),
            ),
            scrollBehavior: const _CalmScrollBehavior(),
          ),
        ),
      ),
    );
  }
}

/// A list stops at its end. Android 12 and later otherwise stretch the whole
/// page when she scrolls past the top or bottom, which reads as the app
/// sagging under her thumb. iPhone keeps its own bounce, which is what people
/// there expect from every app.
class _CalmScrollBehavior extends MaterialScrollBehavior {
  const _CalmScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
