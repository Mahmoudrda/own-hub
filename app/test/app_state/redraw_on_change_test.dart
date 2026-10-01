// What a bump redraws, and what it leaves alone.
//
// `app_router.dart` used to wrap every routed screen in a `ListenableBuilder`
// on `AppChanges`, so one tap rebuilt and re-laid-out every screen in the
// stack. Measured at 375x667 in Arabic, median of twenty bumps, on the stack
// Home → R01 → R02 → E01 → E07 → P01 (`test/qa/round5/r5_05_rebuild_cost_test
// .dart`): 6.3 ms at depth 1 and 11.6 ms at depth 6, climbing with the stack.
// With `RedrawOnChange` the same measurement is 4.7 ms and 4.1 ms — flat,
// because only the screen she is looking at is rebuilt.
//
// The saving is only safe if the contract it replaced still holds, and that is
// what this file is: a covered screen must be CURRENT when she comes back to
// it, not merely cheap while she is away. Every case below is a way of being
// uncovered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_changes.dart';

/// What the screens read. Stands in for every store the router draws from.
int _shared = 0;

/// How many times each screen has been built since the counters were cleared.
final Map<String, int> _builds = <String, int>{};

class _Screen extends StatelessWidget {
  const _Screen(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    _builds[name] = (_builds[name] ?? 0) + 1;
    return Scaffold(
      body: Center(child: Text('$name=$_shared', textDirection: TextDirection.ltr)),
    );
  }
}

/// A navigator shaped the way `AppRouter.onGenerateRoute` shapes one.
Widget _app() => MaterialApp(
  initialRoute: '/a',
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) =>
        RedrawOnChange(builder: (context) => _Screen(settings.name!)),
  ),
);

Future<void> _bump(WidgetTester tester) async {
  _shared++;
  AppChanges.bump();
  await tester.pump();
}

void main() {
  setUp(() {
    _shared = 0;
    _builds.clear();
  });

  testWidgets('the screen she is looking at redraws on every bump', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final atFirst = _builds['/a']!;

    await _bump(tester);
    await _bump(tester);

    expect(_builds['/a'], atFirst + 2);
    expect(find.text('/a=2'), findsOneWidget);
  });

  testWidgets('a screen buried under another is not rebuilt', (tester) async {
    await tester.pumpWidget(_app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/b'));
    await tester.pumpAndSettle();

    final aBuilds = _builds['/a']!;
    final bBuilds = _builds['/b']!;

    await _bump(tester);
    await _bump(tester);
    await _bump(tester);

    expect(_builds['/b'], bBuilds + 3, reason: 'she is looking at this one');
    expect(
      _builds['/a'],
      aBuilds,
      reason: 'nothing of it reaches the glass, so nothing of it is built',
    );
  });

  testWidgets('and is current again the moment she comes back to it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/b'));
    await tester.pumpAndSettle();

    await _bump(tester);
    await _bump(tester);
    final whileCovered = _builds['/a']!;

    navigator.pop();
    // One frame of the back transition, not the whole of it: she must not be
    // shown the old figure while the screen slides in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(_builds['/a'], whileCovered + 1);
    await tester.pumpAndSettle();
    expect(find.text('/a=2'), findsOneWidget);
    expect(
      _builds['/a'],
      whileCovered + 1,
      reason: 'two missed bumps are one redraw, not two',
    );
  });

  testWidgets('a bump after she is back redraws it again', (tester) async {
    await tester.pumpWidget(_app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/b'));
    await tester.pumpAndSettle();
    await _bump(tester);
    navigator.pop();
    await tester.pumpAndSettle();

    final back = _builds['/a']!;
    await _bump(tester);
    expect(_builds['/a'], back + 1);
    expect(find.text('/a=2'), findsOneWidget);
  });

  testWidgets('a screen under an open sheet still redraws', (tester) async {
    await tester.pumpWidget(_app());
    final context = tester.element(find.byType(Scaffold));
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 100),
      ),
    );
    await tester.pumpAndSettle();

    final covered = _builds['/a']!;
    await _bump(tester);

    expect(
      _builds['/a'],
      covered + 1,
      reason: 'half of it is on screen behind the sheet',
    );
    expect(find.text('/a=1'), findsOneWidget);
  });

  testWidgets('a screen under a dialog still redraws', (tester) async {
    await tester.pumpWidget(_app());
    final context = tester.element(find.byType(Scaffold));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    final covered = _builds['/a']!;
    await _bump(tester);

    expect(_builds['/a'], covered + 1);
  });

  testWidgets('a route removed without an animation still catches up', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/b'));
    await tester.pumpAndSettle();
    await _bump(tester);

    // No pop animation at all: the proxy is re-pointed from inside the
    // navigator's own build, which is the case `_coverChanged` defers a frame.
    navigator.removeRoute(ModalRoute.of(tester.element(find.text('/b=1')))!);
    await tester.pumpAndSettle();

    expect(find.text('/a=1'), findsOneWidget);
  });

  testWidgets('outside a navigator it redraws on every bump', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // Not `const`: `Element.updateChild` short-circuits on a widget that is
        // identical to the one already there, so a const screen would never be
        // rebuilt however many times this asked. The router builds a fresh
        // `ScreenScope` every time, which is why it is not affected.
        home: RedrawOnChange(builder: (_) => _Screen('bare')),
      ),
    );
    final atFirst = _builds['bare']!;

    await _bump(tester);

    expect(_builds['bare'], atFirst + 1);
    expect(find.text('bare=1'), findsOneWidget);
  });

  testWidgets('a disposed screen is not a listener any more', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpWidget(const SizedBox.shrink());

    // Nothing to rebuild and nothing to throw: a bump after the whole app is
    // gone is what every `tearDown` in this repository does.
    expect(() => AppChanges.bump(), returnsNormally);
  });
}

/// `unawaited`, without pulling `dart:async` in for one line.
void unawaited(Future<void> future) {}
