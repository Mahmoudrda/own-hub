// The shared setup for round one, so 69 cases measure the same app.
//
// Three things it fixes that no existing harness fixes at once:
//
//  1. **The shipping flag set.** Every sweep in this repository today builds a
//     different app: the tap crawler, the 1.6x sweep and foundations_test all
//     turn every feature on, and release_readiness_test turns every feature on
//     plus accountRequired. None of them is the app a woman installs. The set
//     below is the shipping set copied deliberately, feature by feature, from
//     `FeatureFlags.shipped` (lib/domain/flags/feature_flags.dart:173) — copied
//     rather than referenced, because
//     `test/domain/flags/flag_independence_test.dart` forbids a test file from
//     naming that constant, and rightly so.
//
//  2. **The real fonts** (see font_harness.dart, case R1-00).
//
//  3. **A clean phone.** Every repository on AppRouter is a process-wide
//     singleton, so one case's log is the next case's "history" unless it is
//     wiped.
//
// Not a `_test.dart` file, so the runner does not execute it.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/community_state.dart';
import 'package:own_hub/app_state/cycle_state.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/locale_preference.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/screen_scope.dart';

import 'font_harness.dart';

/// The six features the first release ships, and nothing else.
///
/// This list is `FeatureFlags.shipped` written out on purpose. If the shipping
/// set changes, this must be changed by hand — which is the point.
FeatureFlags shippingFlags() => FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.today: true,
  Feature.train: true,
  Feature.eat: true,
  Feature.progress: true,
  Feature.cycle: true,
  Feature.privacyCentre: true,
});

/// A 390x844 logical phone at 3x, the device shape the plan fixes for round one.
void phone(WidgetTester tester, {double textScale = 1.0}) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  addTearDown(tester.view.reset);
}

/// Everything the app holds about a woman, emptied. A fresh install.
void wipe() {
  CommunityState.instance.reset();
  EatAppState.instance.reset();
  WorkoutSessionState.instance.reset();
  CycleAppState.instance.reset();
  AppRouter.blockService.reset();
  AppRouter.reportService.reset();
  AppRouter.progressStore.reset();
  AppRouter.personalBestLedger.reset();
  AppRouter.mealRepository.store.reset();
  AppRouter.dietaryRepository.reset();
  AppRouter.intakeRepository.reset();
  AppRouter.privacyRepository.reset();
  AppRouter.notificationsRepository.reset();
  AppRouter.trainRepository.reset();
  AppRouter.todayRepository.reset();
}

/// Sets the shipping flags and wipes, for the whole file.
void useShippingApp() {
  final saved = AppRouter.featureFlags;
  setUpAll(loadAppFonts);
  setUp(() {
    AppRouter.featureFlags = shippingFlags();
    wipe();
  });
  tearDown(() {
    wipe();
    AppRouter.featureFlags = saved;
  });
}

Future<void> settle(WidgetTester t, {Duration timeout = const Duration(seconds: 3)}) async {
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  } catch (_) {
    // A long-running animation is not what any of these cases is about.
  }
}

/// Boots the real app through the real router.
Future<void> boot(WidgetTester t, {Locale? locale}) async {
  if (locale != null) {
    await AppRouter.localePreference.write(AppLanguage.fromCode(locale.languageCode));
  }
  await t.pumpWidget(OwnHubApp(key: UniqueKey()));
  await settle(t);
}

NavigatorState nav(WidgetTester t) =>
    t.state<NavigatorState>(find.byType(Navigator).first);

/// Home, with [route] opened on top of it. Returns false if opening threw.
Future<bool> open(WidgetTester t, String route, {Locale? locale}) async {
  await boot(t, locale: locale);
  nav(t).pushNamed(route);
  await settle(t);
  return t.takeException() == null;
}

/// The id of the screen on top.
String? topScreen(WidgetTester t) {
  final scopes = t.widgetList<ScreenScope>(find.byType(ScreenScope)).toList();
  return scopes.isEmpty ? null : scopes.last.screenId;
}

/// Every string the semantics tree exposes on the screen as it stands.
List<String> spokenLabels(WidgetTester t) {
  final out = <String>[];
  for (final n in find.semantics.byPredicate((_) => true).evaluate()) {
    final d = n.getSemanticsData();
    for (final s in <String>[d.label, d.value, d.tooltip, d.hint]) {
      if (s.trim().isNotEmpty) out.add(s.replaceAll('\n', ' '));
    }
  }
  return out;
}

/// Every string actually painted, read off the Text widgets.
List<String> paintedText(WidgetTester t) {
  final out = <String>[];
  for (final w in t.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText();
    if (s != null && s.trim().isNotEmpty) out.add(s);
  }
  return out;
}

/// Tapped the way a screen reader taps: through the semantics action, so a
/// control a screen reader cannot reach cannot pass.
Future<void> tapLabel(WidgetTester t, Pattern label) async {
  t.semantics.tap(find.semantics.byLabel(label));
  await settle(t);
}

bool hasLabel(WidgetTester t, Pattern label) =>
    find.semantics.byLabel(label).evaluate().isNotEmpty;

/// True when [name] is one of the strings a screen reader would announce for
/// this node, with newlines flattened to spaces the way [tappables] prints them.
bool _named(SemanticsData d, Pattern name) {
  for (final raw in <String>[d.label, d.tooltip, d.hint]) {
    final s = raw.replaceAll('\n', ' ').trim();
    if (s.isEmpty) continue;
    if (name is RegExp ? name.hasMatch(s) : s == name) return true;
  }
  return false;
}

/// Activates the control a woman would call [name], and returns false if there
/// is no such control.
///
/// [tapLabel] is the strict instrument and stays that way. This is the one to
/// use when the name comes off a printed sweep, because `find.semantics
/// .byLabel` reads `SemanticsData.label` and nothing else, and two things in
/// this app are not in that field:
///
///   * **Every top-bar Back and X is named by `tooltip`**, not by `label` —
///     `app_scaffold.dart:202` sets `MaterialLocalizations.backButtonTooltip`
///     on an `IconButton` whose icon has no label. A screen reader announces
///     it; `byLabel('Back')` cannot see it. `r1_22` and `r1_02b` both tapped a
///     name they had just printed and got "no element".
///   * **Row labels carry newlines.** "Legs and glutes\n15 min · beginner · no
///     equipment" is one label with a line break in it; [tappables] prints it
///     with a space, so a matcher built from that printout never matched.
///
/// Takes the FIRST match rather than insisting on one, because a screen may
/// honestly have several controls with the same name — E01 draws a "Log" on
/// every suggested plate — and a sweep that wants to log one meal should log
/// the first, not throw.
Future<bool> tapControl(WidgetTester t, Pattern name) async {
  final match = find.semantics
      .byPredicate(
        (n) =>
            n.getSemanticsData().hasAction(SemanticsAction.tap) &&
            _named(n.getSemanticsData(), name),
      )
      .evaluate();
  if (match.isEmpty) return false;
  final id = match.first.id;
  t.semantics.tap(find.semantics.byPredicate((n) => n.id == id));
  await settle(t);
  return true;
}

/// Every node a screen reader could activate, with its label.
List<({int id, String label, Rect rect})> tappables(WidgetTester t) {
  final out = <({int id, String label, Rect rect})>[];
  for (final n in find.semantics.byAction(SemanticsAction.tap).evaluate()) {
    final d = n.getSemanticsData();
    final parts = <String>[d.label, d.tooltip, d.hint]
        .where((s) => s.trim().isNotEmpty);
    out.add((
      id: n.id,
      label: parts.join(' / ').replaceAll('\n', ' '),
      rect: MatrixUtils.transformRect(n.transform ?? Matrix4.identity(), n.rect),
    ));
  }
  return out;
}
