// Y03 with no cycle document — the branch a screenshot found empty.
//
// `CycleHubView` rendered `SizedBox.shrink()` for `HubBranch.notSetUp`, so a
// woman who skipped cycle setup and then tapped "My cycle" in My profile got a
// title bar, a settings gear, a navigation bar, and nothing at all in between.
//
// The whole suite was green. All 115 cycle tests pass a cycle document, because
// a null one was taken to mean "this screen is never shown" — true of Home's
// row, which is gated, and not true of the route, which My profile links to
// unconditionally. The view-model was right, the view was empty, and no
// assertion in the project looked at the combination.
//
// So this guards the combination: the branch must render something a woman can
// act on, and the action must lead somewhere.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/presentation/cycle_hub_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

void main() {
  testWidgets('the hub is never a blank screen', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const CycleHubView(cycle: null)));
    await tester.pumpAndSettle();

    // Something beyond the chrome. The title and the settings gear render from
    // the scaffold regardless of the branch, so asserting on them would pass
    // over the empty body that caused this.
    expect(
      find.byType(AppButton),
      findsWidgets,
      reason:
          'notSetUp rendered SizedBox.shrink(), which is a running, responsive '
          'and completely empty page. A branch with no content is not an empty '
          'state, it is a missing one.',
    );
  });

  testWidgets('it offers setting up, and says what the feature is', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const CycleHubView(cycle: null)));
    await tester.pumpAndSettle();

    expect(find.text('Make it work for you'), findsOneWidget);
    expect(find.text('Track periods and symptoms'), findsOneWidget);
  });

  testWidgets('the one action it offers actually leads somewhere', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    var opened = 0;
    await tester.pumpWidget(
      _host(CycleHubView(cycle: null, onSetUp: () => opened++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track periods and symptoms'));
    await tester.pumpAndSettle();

    expect(
      opened,
      1,
      reason: 'an affordance wired to nothing is the empty screen again',
    );
  });

  testWidgets('nothing here claims a date, a phase or a day number', (
    tester,
  ) async {
    // She has told us nothing, so there is nothing to say back. §2.4 forbids a
    // phase or a prediction anywhere; this branch is the easiest place for one
    // to be invented as filler.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const CycleHubView(cycle: null)));
    await tester.pumpAndSettle();

    for (final banned in [
      'Period day',
      'period day',
      'Ovulation',
      'ovulation',
      'Follicular',
      'Luteal',
      'Next period',
    ]) {
      expect(
        find.textContaining(banned),
        findsNothing,
        reason: 'notSetUp knows nothing about her cycle: found "$banned"',
      );
    }
  });
}
