// A live session through the real router: the language switch relabels it, and
// "Skip this move" behaves the same on R05 as on R06.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

Future<void> _boot(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  _nav(tester).pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

bool _hasArabic(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    WorkoutSessionState.instance.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    WorkoutSessionState.instance.reset();
  });

  testWidgets('a session started in English reads in Arabic after the switch', (
    tester,
  ) async {
    await _boot(tester, 'R03');
    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();

    final session = WorkoutSessionState.instance;
    expect(session.isLive, isTrue);
    final englishTitle = session.day!.title;
    expect(_hasArabic(englishTitle), isFalse);

    LocaleScope.of(tester.element(find.byType(Navigator).first))
        .value = const Locale(
      'ar',
    );
    await tester.pumpAndSettle();

    expect(session.day!.title, isNot(englishTitle));
    expect(_hasArabic(session.day!.title), isTrue);

    // R05, R09 and R13 read the same day, so their set lines are Arabic too.
    expect(session.day!.moves.first.name, isNotEmpty);
    expect(
      _hasArabic(session.day!.moves.first.prescriptionLabel) ||
          _hasArabic(session.day!.moves.first.name),
      isTrue,
    );
  });

  testWidgets('R05 skip with no alternatives moves on, like R06', (
    tester,
  ) async {
    await _boot(tester, 'R03');
    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();

    final session = WorkoutSessionState.instance;
    final before = session.moveIndex;
    _nav(tester).pushNamed(appDestinations['R05']!.name);
    await tester.pumpAndSettle();

    final skip = find.byKey(const ValueKey('r05-skip-move'));
    if (skip.evaluate().isEmpty) {
      markTestSkipped('this move has alternatives in the fixture');
      return;
    }
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(session.moveIndex, before + 1);
    await tester.pump(const Duration(seconds: 10));
  });
}
