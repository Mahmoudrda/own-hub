// R2-19 (launch QA round 2, "Nothing routes into a dark flow").
//
// Parses every `goTo(context, 'XX')` and `_goCarryingHandle(context, 'XX'`
// literal inside `AppRouter._built` -- there are no others anywhere in
// `lib/`, confirmed separately by grep -- and, for each edge, checks that a
// screen whose flow SHIPS never leads straight into a screen whose flow is
// DARK. `AppRouter.screenIsOn` is the same function the app itself calls
// before drawing a row, a chip or a button, so this test asks the production
// gate the real question rather than re-deriving the answer.
//
// The graph-extraction regexes are copied from `test/nav_reachability_test.dart`
// (P0-NAV-01), which established this source-scanning idiom against this exact
// map. They are duplicated rather than imported: that file is owned by round 1
// and this one must not depend on, or risk breaking under, an edit there.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

/// The shipping set, LAUNCH-QA-PLAN.md R2-19's own list, copied here BY NAME
/// rather than read off `FeatureFlags.shipped`.
/// `test/domain/flags/flag_independence_test.dart` forbids a test file from
/// borrowing its precondition from today's defaults -- a case has to state
/// the flags it depends on so it survives the defaults moving -- and this
/// file's whole subject is "what a shipping screen may lead to", so it must
/// pin the shipping set explicitly rather than trust `FeatureFlags.shipped`
/// to still mean the same six features tomorrow.
final FeatureFlags _shipping = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.today: true,
  Feature.firstWeek: true,
  Feature.quietWeek: true,
  Feature.train: true,
  Feature.recordFromMemory: true,
  Feature.program: true,
  Feature.exerciseVideo: true,
  Feature.exerciseSwap: true,
  Feature.followAlong: true,
  Feature.workoutLibrary: true,
  Feature.exerciseLibrary: true,
  Feature.trainingReminders: true,
  Feature.trainingStreak: true,
  Feature.weeklyChallenge: true,
  Feature.finishReveal: true,
  Feature.haptics: true,
  Feature.reassuringWaits: true,
  Feature.eat: true,
  Feature.recipes: true,
  Feature.mealPhotos: true,
  Feature.weekPlan: true,
  Feature.groceryList: true,
  Feature.progress: true,
  Feature.milestones: true,
  Feature.personalBests: true,
  Feature.bodyPrivately: true,
  Feature.shareCard: true,
  Feature.muscleMap: true,
  Feature.cycle: true,
  Feature.cycleCalendar: true,
  Feature.cyclePatterns: true,
  Feature.cycleMeals: true,
  Feature.privacyCentre: true,
});

/// Every `'XX': (context) => ...` entry in `AppRouter._built`, and every
/// `goTo`/`_goCarryingHandle(context, 'YY'` literal written inside that
/// entry's builder, attributed to it.
///
/// Comment lines are skipped. `app_router.dart`'s own Community section
/// header names this exact hazard: "`goTo(context, 'M17')` would resolve to
/// nothing, so writing it in a builder would be a dead call that also LIED TO
/// THE REACHABILITY PARSER" -- a warning written for `nav_reachability_test`,
/// which this file's graph-extraction is deliberately modelled on. Without a
/// comment skip, that sentence's own backticked example is misread as a real
/// edge out of whichever screen was last entered before the comment block --
/// measured: `Y13 -> M17`, a screen that is not even in `appRoutes`.
({Set<String> built, Map<String, Set<String>> edges}) _navGraph() {
  final lines = File('lib/routing/app_router.dart').readAsLinesSync();

  final entry = RegExp(r"^    '([A-Za-z0-9]+)':\s*\(context\)");
  final edge = RegExp(
    r"(?:goTo|_goCarryingHandle)\(\s*context,\s*'([A-Za-z0-9]+)'",
  );

  final start = lines.indexWhere(
    (l) => l.contains('static final Map<String, WidgetBuilder> _built'),
  );
  expect(
    start,
    isNot(-1),
    reason:
        'AppRouter._built was not found. If the router was restructured, '
        'this parser must be updated -- a silently empty graph would report '
        'zero offenders over zero edges.',
  );

  final built = <String>{};
  final edges = <String, Set<String>>{};
  String? current;

  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('  };')) break; // end of the map

    final m = entry.firstMatch(line);
    if (m != null) {
      current = m.group(1)!;
      built.add(current);
      edges.putIfAbsent(current, () => <String>{});
    }
    if (current == null) continue;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    for (final e in edge.allMatches(line)) {
      edges[current]!.add(e.group(1)!);
    }
  }

  // E01, E02 and E04 are one page built by a helper, so its calls are theirs.
  final hub = lines.indexWhere((l) => l.contains('static Widget _eatHub('));
  if (hub != -1) {
    for (var i = hub + 1; i < lines.length && lines[i] != '  }'; i++) {
      for (final e in edge.allMatches(lines[i])) {
        for (final id in const ['E01', 'E02', 'E04']) {
          edges[id]?.add(e.group(1)!);
        }
      }
    }
  }

  return (built: built, edges: edges);
}

/// Edges the literal scan finds that DO cross from a shipping screen into a
/// dark one, verified by hand to be unreachable in practice because the
/// control that would fire them is never drawn (or the call is never made)
/// while the destination is off -- and the guard is `AppRouter.screenIsOn`,
/// the same gate `AppRouter.goTo` itself is protected by, not an ad hoc
/// condition invented for this test.
///
/// Each entry names the exact file:line of the guard, and the check below
/// re-reads that file and fails if the cited text is gone -- so a guard that
/// is later deleted turns back into a real failure here instead of staying
/// silently exempted.
const Map<String, ({String file, String guard})> _sourceGuardedEdges = {
  // ProfileView (A02) wraps the "her coach" row so it is not drawn at all
  // while H01 is dark; `onOpenCoach` is therefore never invoked.
  'A02->H01': (
    file: 'lib/features/account/presentation/profile_view.dart',
    guard: "if (AppRouter.screenIsOn('H01'))",
  ),
  // LanguageView's own "Continue" callback, wired in AppRouter itself: it
  // calls goTo('C03') only when C03 is on, and pops otherwise.
  'C02->C03': (
    file: 'lib/routing/app_router.dart',
    guard: "onContinue: screenIsOn('C03')",
  ),
  // LanguageView's Skip, wired in AppRouter itself: drawn only while sign-in
  // (C06) is on and she has no account, so it is never a door into a dark C06.
  'C02->C06': (
    file: 'lib/routing/app_router.dart',
    guard: "onSkip: signedInUid == null && screenIsOn('C06')",
  ),
  // O04 ends a Skip that began before sign-up. The edge to C06 is taken only
  // while she is building her week before sign-up, and only while C06 is on.
  'O04->C06': (
    file: 'lib/routing/app_router.dart',
    guard: "if (screenIsOn('C06')) goTo(context, 'C06');",
  ),
  // EatView (E01, E04) and TypeItView (E02) draw the microphone only while
  // E03, saying a meal, is on (`Feature.voiceLogging`); with it off they offer
  // typing alone and `onSpeak` is never invoked.
  'E01->E03': (
    file: 'lib/features/eat/presentation/eat_view.dart',
    guard: "AppRouter.screenIsOn('E03')",
  ),
  'E04->E03': (
    file: 'lib/features/eat/presentation/eat_view.dart',
    guard: "AppRouter.screenIsOn('E03')",
  ),
  'E02->E03': (
    file: 'lib/features/eat/presentation/type_it_view.dart',
    guard: "AppRouter.screenIsOn('E03')",
  ),
  // FinishedView (R10) draws the "share" action only while M03 is on.
  // "Save my week and join" exists only while she is building her week
  // before sign-up, which only C01 (sign-up) can start. With sign-up dark the
  // flag is never set and O05 draws its ordinary three exits.
  'O05->C06': (
    file: 'lib/routing/app_router.dart',
    guard: ": OnboardingState.instance.beforeSignup\n        ? StartingProgramView(",
  ),
  'R10->M03': (
    file: 'lib/features/train/presentation/finished_view.dart',
    guard: "if (AppRouter.screenIsOn('M03'))",
  ),
  // TodayView (T01) draws the assistant icon and the beginners-group row
  // only while their destinations are on.
  'T01->M01': (
    file: 'lib/features/today/presentation/today_view.dart',
    guard: "if (AppRouter.screenIsOn('M01'))",
  ),
  'T01->X01': (
    file: 'lib/features/today/presentation/today_view.dart',
    guard: "if (AppRouter.screenIsOn('X01'))",
  ),
  // The Upcoming card on Home is drawn only while T09, the owner's events
  // (Feature.events), is on.
  'T01->T09': (
    file: 'lib/features/today/presentation/today_view.dart',
    guard: "when AppRouter.screenIsOn('T09')",
  ),
  // ProfileView (A02) draws the admin console row only when `onOpenAdmin` is
  // passed, and the router passes it only where the console resolves and is
  // switched on: the owner's admin build, never a store build.
  'A02->Z01': (
    file: 'lib/routing/app_router.dart',
    guard:
        "onOpenAdmin: adminConsoleOffered ? () => goTo(context, 'Z01') : null",
  ),
  // Dark at launch (D43): the doors into these are drawn only while the
  // screen is on.
  'P01->T05': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('T05'))",
  ),
};

/// The guard on every door into a part of a feature the server can switch
/// off on its own (`Feature.serverMayTurnOff`), cited the same way as
/// [_sourceGuardedEdges]: a file, and the text of the check in it.
///
/// The owner can stop a broken part for every member without a release. That
/// is only safe if no screen she can still reach draws a control leading into
/// the stopped part; otherwise the stop leaves a door on a wall. The test
/// below switches each part off in turn and requires every edge into it to be
/// listed here, and every cited guard to still exist.
const Map<String, ({String file, String guard})> _killSwitchGuards = {
  // The camera beside "Type what you ate" (E01, E04) and in E02's field is
  // passed by the router only while E12 is on, and only to a verified member.
  // The Scan chip on Home's eat card is passed only on the same terms.
  'T01->E12': (
    file: 'lib/routing/app_router.dart',
    guard: "onScanMeal: screenIsOn('E12') && isVerified",
  ),
  'E01->E12': (
    file: 'lib/routing/app_router.dart',
    guard: "onSnap: screenIsOn('E12') && isVerified",
  ),
  'E02->E12': (
    file: 'lib/routing/app_router.dart',
    guard: "onSnap: screenIsOn('E12') && isVerified",
  ),
  'E04->E12': (
    file: 'lib/routing/app_router.dart',
    guard: "onSnap: screenIsOn('E12') && isVerified",
  ),
  'E07->E08': (
    file: 'lib/features/eat/presentation/week_plan_view.dart',
    guard: "if (!widget.embedded && AppRouter.screenIsOn('E08'))",
  ),
  'Y03->Y07': (
    file: 'lib/routing/app_router.dart',
    guard: "onOpenMeals: screenIsOn('Y07')",
  ),
  // The Moves cards in Explore open a demo only while R15 is on.
  'R01->R15': (
    file: 'lib/routing/app_router.dart',
    guard: "onOpenExercise: screenIsOn('R15')",
  ),
  // The set she is on is sent to R06 only for a hold, and only while R06 is
  // on (`_holdIsNext`); otherwise it is R07's.
  'R03->R06': (
    file: 'lib/routing/app_router.dart',
    guard: "return hold && screenIsOn('R06');",
  ),
  'R05->R06': (
    file: 'lib/routing/app_router.dart',
    guard: "return hold && screenIsOn('R06');",
  ),
  'R09->R06': (
    file: 'lib/routing/app_router.dart',
    guard: "return hold && screenIsOn('R06');",
  ),
  'R13->R06': (
    file: 'lib/routing/app_router.dart',
    guard: "return hold && screenIsOn('R06');",
  ),
  'T01->T02': (
    file: 'lib/features/today/presentation/today_view.dart',
    guard: "onRecall: AppRouter.screenIsOn('T02')",
  ),
  'T01->T07': (
    file: 'lib/features/today/presentation/today_view.dart',
    guard: "if (AppRouter.screenIsOn('T07'))",
  ),
  'P01->T07': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('T07'))",
  ),
  'P01->T04': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('T04'))",
  ),
  'P01->P02': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('P02'))",
  ),
  'P01->P03': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('P03'))",
  ),
  'P01->P04': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('P04'))",
  ),
  'P01->P05': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('P05'))",
  ),
  'P01->P06': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('P06'))",
  ),
  'R01->P06': (
    file: 'lib/features/train/presentation/train_view.dart',
    guard: "if (AppRouter.screenIsOn('P06') && widget.onOpenMuscles != null)",
  ),
  // P06 names moves for a muscle group and links them to their demo only
  // while it is on.
  'P06->R15': (
    file: 'lib/routing/app_router.dart',
    guard: "onOpenMove: screenIsOn('R15')",
  ),
  'R01->R02': (
    file: 'lib/features/train/presentation/train_view.dart',
    guard: "if (AppRouter.screenIsOn('R02'))",
  ),
  'R01->R05': (
    file: 'lib/features/train/presentation/train_view.dart',
    guard: "if (AppRouter.screenIsOn('R05') && widget.showGentlerOption)",
  ),
  'R04->R05': (
    file: 'lib/features/train/presentation/exercise_video_view.dart',
    guard: "if (AppRouter.screenIsOn('R05') && canSwap)",
  ),
  'R03->R04': (
    file: 'lib/features/train/presentation/workout_day_view.dart',
    guard: "AppRouter.screenIsOn('R04')",
  ),
  'T01->E07': (
    file: 'lib/features/today/presentation/today_view.dart',
    guard: "AppRouter.screenIsOn('E07')",
  ),
  'E05->E07': (
    file: 'lib/features/eat/presentation/recipes_view.dart',
    guard: "AppRouter.screenIsOn('E07')",
  ),
  'Y03->Y08': (
    file: 'lib/features/cycle/presentation/cycle_widgets.dart',
    guard: "AppRouter.screenIsOn('Y08')) CycleTab.calendar",
  ),
  'E01->E06': (
    file: 'lib/features/eat/presentation/eat_hub_view.dart',
    guard: "AppRouter.screenIsOn('E05'))",
  ),
  'E01->E11': (
    file: 'lib/features/eat/presentation/eat_hub_view.dart',
    guard: "AppRouter.screenIsOn('E05'))",
  ),
  'E02->E06': (
    file: 'lib/features/eat/presentation/eat_hub_view.dart',
    guard: "AppRouter.screenIsOn('E05'))",
  ),
  'E02->E11': (
    file: 'lib/features/eat/presentation/eat_hub_view.dart',
    guard: "AppRouter.screenIsOn('E05'))",
  ),
  'E04->E06': (
    file: 'lib/features/eat/presentation/eat_hub_view.dart',
    guard: "AppRouter.screenIsOn('E05'))",
  ),
  'E04->E11': (
    file: 'lib/features/eat/presentation/eat_hub_view.dart',
    guard: "AppRouter.screenIsOn('E05'))",
  ),
  'P01->Y10': (
    file: 'lib/features/progress/presentation/progress_view.dart',
    guard: "if (AppRouter.screenIsOn('Y10'))",
  ),
  'Y10->Y08': (
    file: 'lib/features/cycle/presentation/cycle_widgets.dart',
    guard: "AppRouter.screenIsOn('Y08')) CycleTab.calendar",
  ),
  'Y03->Y10': (
    file: 'lib/features/cycle/presentation/cycle_widgets.dart',
    guard: "if (AppRouter.screenIsOn('Y10')) CycleTab.patterns",
  ),
  'Y08->Y10': (
    file: 'lib/features/cycle/presentation/cycle_widgets.dart',
    guard: "if (AppRouter.screenIsOn('Y10')) CycleTab.patterns",
  ),
  'C01->C04': (
    file: 'lib/features/signup/presentation/welcome_view.dart',
    guard: "if (AppRouter.screenIsOn('C04'))",
  ),
  'C01->C03': (
    file: 'lib/routing/app_router.dart',
    guard: "if (!screenIsOn('C03'))",
  ),
  'C02->C03': (
    file: 'lib/routing/app_router.dart',
    guard: "onContinue: screenIsOn('C03')",
  ),
};

void main() {
  test('every goTo/_goCarryingHandle literal in app/lib is inside AppRouter._built', () {
    // Confirms the premise this test relies on: that scanning `_built` is
    // scanning EVERY real call site in the app, not a subset of them. Text
    // that merely MENTIONS `goTo(context, 'XX')` inside a comment or a
    // doc string is excluded the same way `nav_reachability_test.dart`
    // excludes it -- by requiring the call to appear inside `_built`,
    // which a comment line describing it does not.
    final libDir = Directory('lib');
    final offenders = <String>[];
    final call = RegExp(
      r"(?:goTo|_goCarryingHandle)\(\s*context,\s*'[A-Za-z0-9]+'",
    );
    for (final f
        in libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('routing/app_router.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('///') ||
            trimmed.startsWith('*')) {
          continue;
        }
        if (call.hasMatch(line)) {
          offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A real navigation call exists outside AppRouter._built, so the '
          'edge scan below is incomplete:\n  ${offenders.join('\n  ')}',
    );
  });

  test(
    'no edge in AppRouter._built routes from a shipping screen into a dark one',
    () {
      final saved = AppRouter.featureFlags;
      AppRouter.featureFlags = _shipping;
      addTearDown(() => AppRouter.featureFlags = saved);

      final graph = _navGraph();
      expect(graph.built, isNotEmpty);

      var totalEdges = 0;
      final offenders = <String>[];
      final exempted = <String>[];
      for (final source in graph.edges.keys) {
        final sourceOn = AppRouter.screenIsOn(source);
        for (final dest in graph.edges[source]!) {
          totalEdges++;
          // The case is about edges FROM a shipping screen.
          if (!sourceOn) continue;
          if (!AppRouter.screenIsOn(dest)) {
            final key = '$source->$dest';
            if (_sourceGuardedEdges.containsKey(key)) {
              exempted.add(key);
              continue;
            }
            offenders.add(
              '$source (${appRoutes[source]?.flow}) -> '
              '$dest (${appRoutes[dest]?.flow})',
            );
          }
        }
      }
      offenders.sort();

      // Every entry in the exemption list must actually have been hit -- an
      // edge that stopped existing (the screen was removed, or wired some
      // other way) is a stale exemption, not a harmless leftover.
      final unused = _sourceGuardedEdges.keys.toSet()..removeAll(exempted);
      expect(
        unused,
        isEmpty,
        reason:
            'These exemptions no longer match a real edge in AppRouter._built '
            'and should be deleted: $unused',
      );

      // And every cited guard must still be in its file, so a deleted guard
      // fails here rather than staying silently exempted.
      for (final entry in _sourceGuardedEdges.entries) {
        final source = File(entry.value.file).readAsStringSync();
        expect(
          source.contains(entry.value.guard),
          isTrue,
          reason:
              '${entry.key} is exempted on the strength of a guard that is no '
              'longer in ${entry.value.file}: "${entry.value.guard}"',
        );
      }

      // Sanity floor on the parser itself: `nav_reachability_test.dart`
      // finds several hundred edges over the same map today. A much lower
      // count here would mean the regex silently stopped matching most of
      // the file rather than that the app got smaller.
      expect(
        totalEdges,
        greaterThan(300),
        reason:
            'Only $totalEdges edges were found; the parser may have stopped '
            'matching AppRouter._built.',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'These edges lead from a screen whose flow ships into a screen '
            'whose flow is dark under the R2-19 shipping set:\n  '
            '${offenders.join('\n  ')}',
      );
    },
  );

  test(
    'switching off any one part leaves no door into it from what is still on',
    () {
      final saved = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = saved);

      final graph = _navGraph();
      // The launch with sign-up in it, so the tour's doors are walked too.
      final launch = _shipping.with_({
        Feature.signUp: true,
        Feature.appTour: true,
      });
      final parts = [
        for (final f in Feature.values)
          if (f.parent != null && f.serverMayTurnOff && launch.isOn(f)) f,
      ];
      expect(parts, isNotEmpty);

      AppRouter.featureFlags = launch;
      final onAtLaunch = {
        for (final id in appRoutes.keys)
          if (AppRouter.screenIsOn(id)) id,
      };

      final offenders = <String>[];
      final used = <String>{};
      for (final part in parts) {
        AppRouter.featureFlags = launch.with_({part: false});
        for (final source in graph.edges.keys) {
          if (!AppRouter.screenIsOn(source)) continue;
          for (final dest in graph.edges[source]!) {
            // Only what this part's switch closed. A screen already dark at
            // launch is the test above's subject.
            if (AppRouter.screenIsOn(dest) || !onAtLaunch.contains(dest)) {
              continue;
            }
            final key = '$source->$dest';
            if (_killSwitchGuards.containsKey(key)) {
              used.add(key);
              continue;
            }
            offenders.add('${part.name}: $key');
          }
        }
      }

      for (final entry in _killSwitchGuards.entries) {
        final source = File(entry.value.file).readAsStringSync();
        expect(
          source.contains(entry.value.guard),
          isTrue,
          reason:
              '${entry.key} is exempted on the strength of a guard that is no '
              'longer in ${entry.value.file}: "${entry.value.guard}"',
        );
      }
      expect(
        _killSwitchGuards.keys.toSet()..removeAll(used),
        isEmpty,
        reason: 'These guards no longer match an edge into a switchable part',
      );
      expect(
        offenders..sort(),
        isEmpty,
        reason:
            'Switching the named part off leaves a control leading into it. '
            'Draw the control only while AppRouter.screenIsOn is true for '
            'its screen, and cite the guard in _killSwitchGuards:\n  '
            '${offenders.join('\n  ')}',
      );
    },
  );
}
