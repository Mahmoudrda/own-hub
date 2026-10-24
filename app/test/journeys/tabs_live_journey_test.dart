// A tab that is drawn must be a tab she can reach.
//
// `AppNavBar` gives the active tab no `onTap`, on purpose: the tab she is
// already on is not a link to itself. That makes `activeScreenId` load-bearing.
// A screen that is not Home but passes `'T01'` draws the Home tab marked
// active and hands it no action, so Home becomes a dead control on that screen
// — drawn, lit, and going nowhere.
//
// Five screens in Train and Today did that: T02, T04, T05, R05 and the old library each
// claimed the tab root they had been opened from. Each one now names itself,
// which is what `AppNavBar.activeScreenId` has always documented ("the screen
// currently shown") and what leaves all three tabs live.
//
// T02, T05 and R05 are covered by the sweep at the bottom rather than walked.
// T02 and T05 draw their bar inside a Stack under a full-screen scrim, and R05
// opens a modal sheet on entry, so no tab on any of the three is reachable by a
// finger whatever id it carries — a separate defect, reported rather than
// changed here. The id still matters on all three: a bar that is visible
// through a scrim must not claim to be somewhere she is not.
//
// Walked in the real app rather than against the widget, because what is being
// proved is that the tap arrives somewhere.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

Future<void> _open(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

/// The route the app is showing now.
String? _route(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byType(AppNavBar).first))?.settings.name;

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    // The first release: Community dark, so the bar is Home, Train, +, Eat and You.
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.today: true,
      Feature.firstWeek: true,
      Feature.quietWeek: true,
      Feature.tiers: true,
      Feature.lockScreenNudge: true,
      Feature.train: true,
      Feature.recordFromMemory: true,
      Feature.program: true,
      Feature.exerciseVideo: true,
      Feature.exerciseSwap: true,
      Feature.followAlong: true,
      Feature.workoutLibrary: true,
      Feature.trainingReminders: true,
      Feature.eat: true,
      Feature.recipes: true,
      Feature.weekPlan: true,
      Feature.groceryList: true,
      Feature.progress: true,
      Feature.milestones: true,
      Feature.personalBests: true,
      Feature.bodyPrivately: true,
      Feature.shareCard: true,
    });
    AppRouter.todayRepository.reset();
    AppRouter.intakeRepository.markSetupDone();
  });

  tearDown(() {
    AppRouter.todayRepository.reset();
    AppRouter.intakeRepository.reset();
    AppRouter.featureFlags = saved;
  });

  testWidgets('from R01, the Home tab reaches Home', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _open(tester, 'R01');
    expect(_route(tester), appDestinations['R01']!.name);

    final bar = tester.widget<AppNavBar>(find.byType(AppNavBar).first);
    expect(bar.activeScreenId, 'R01');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(_route(tester), appDestinations['T01']!.name);
  });

  testWidgets('and from T04, after a quiet week', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _open(tester, 'T04');
    expect(
      tester.widget<AppNavBar>(find.byType(AppNavBar).first).activeScreenId,
      'T04',
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(_route(tester), appDestinations['T01']!.name);
  });

  test('no screen in Train or Today claims a tab it is not', () {
    // A sweep over the two flows this worker owns, so the next screen to grow
    // a bar cannot repeat it. Every screen file here opens its library comment
    // with its own id ("/// R05 — Swap a move."), so a file naming a tab
    // root it does not own is the defect, spelled out.
    const tabRoots = {'T01', 'R01', 'E01', 'P01'};
    final offenders = <String>[];

    for (final directory in const [
      'lib/features/train',
      'lib/features/today',
    ]) {
      for (final entity in Directory(directory).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        final heading = lines.firstWhere(
          (line) => line.startsWith('/// '),
          orElse: () => '',
        );
        for (var i = 0; i < lines.length; i++) {
          final match = RegExp(r"activeScreenId:\s*'([A-Z]\d+)'")
              .firstMatch(lines[i]);
          if (match == null) continue;
          final claimed = match.group(1)!;
          if (!tabRoots.contains(claimed)) continue;
          if (!heading.contains(claimed)) {
            offenders.add('${entity.path}:${i + 1} claims $claimed');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'AppNavBar gives the active tab no onTap, so a screen that claims a '
          'tab root it is not kills that tab:\n${offenders.join('\n')}',
    );
  });
}
