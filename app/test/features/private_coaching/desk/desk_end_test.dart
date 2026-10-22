// The coach ends a coaching from the client's page, and reads the plans she
// shared from the plans collection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/client_detail_view.dart';

import 'desk_repo.dart';
import 'desk_support.dart';

DeskRepo _repo() => DeskRepo()
  ..setSubscriptions([deskSub('a', name: 'Nour Hassan')])
  ..setRelationships([deskRel('ua', lastAt: kDeskNow)]);

Future<void> _show(
  WidgetTester tester,
  DeskRepo repo, {
  VoidCallback? onBack,
}) async {
  deskPhone(tester);
  final state = await startedState(tester, repo);
  await tester.pumpWidget(
    deskHost(
      ClientDetailView(
        subId: 'a',
        state: state,
        now: () => kDeskNow,
        onBack: onBack,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('End coaching asks first and says what happens', (tester) async {
    final repo = _repo();
    var left = 0;
    await _show(tester, repo, onBack: () => left++);
    await tester.tap(find.byKey(const ValueKey('end-coaching')));
    await tester.pumpAndSettle();
    expect(find.text('End this coaching?'), findsOneWidget);
    expect(
      find.text(
        'The chat becomes read only. Her plans stay with her. '
        'You will no longer see her answers.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('end-coaching-no')));
    await tester.pumpAndSettle();
    expect(repo.ended, isEmpty);

    await tester.tap(find.byKey(const ValueKey('end-coaching')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('end-coaching-yes')));
    await tester.pumpAndSettle();
    expect(repo.ended, ['a']);
    expect(find.text('Coaching ended'), findsOneWidget);
    expect(left, 1);
  });

  testWidgets('a refusal stays on the page as a calm line', (tester) async {
    final repo = _repo()
      ..failEnd = const CoachingFailure(CoachingRefusal.unreachable);
    var left = 0;
    await _show(tester, repo, onBack: () => left++);
    await tester.tap(find.byKey(const ValueKey('end-coaching')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('end-coaching-yes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('end-coaching-error')), findsOneWidget);
    expect(repo.ended, isEmpty);
    expect(left, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Plans you shared come from the plans stream', (tester) async {
    final repo = _repo()
      ..setPlans([
        CoachPlan(
          id: 'p1',
          kind: PlanKind.meal,
          coachUid: 'me',
          name: 'Meals week one',
          publishedAt: kDeskNow,
        ),
        CoachPlan(
          id: 'p2',
          kind: PlanKind.workout,
          coachUid: 'me',
          publishedAt: kDeskNow,
        ),
      ]);
    await _show(tester, repo);
    await tester.scrollUntilVisible(
      find.text('Meals week one'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Meals week one'), findsOneWidget);
    expect(find.text('Workout plan'), findsWidgets);
  });
}
