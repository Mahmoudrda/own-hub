import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coach_agreement.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/coach_desk_view.dart';

import 'desk_repo.dart';
import 'desk_support.dart';

DeskRepo _withRequest() => DeskRepo()
  ..setSubscriptions([
    deskSub(
      'r1',
      status: SubscriptionStatus.requested,
      name: 'Mona Ali',
      createdAt: kDeskNow.subtract(const Duration(days: 1)),
      intake: deskIntake(),
    ),
  ]);

CoachPrivateSummary _private(AgreementStatus? status, {int version = 2}) =>
    CoachPrivateSummary(
      agreement: status == null
          ? null
          : CoachAgreement(version: version, status: status),
    );

void main() {
  for (final (label, summary) in <(String, CoachPrivateSummary)>[
    ('no agreement yet', _private(null)),
    ('accepted only', _private(AgreementStatus.accepted)),
    ('waiting for Own Hub', _private(AgreementStatus.uploaded)),
    ('needs a new copy', _private(AgreementStatus.rejected)),
    (
      'verified, but version one',
      _private(AgreementStatus.verified, version: 1),
    ),
  ]) {
    testWidgets('Accept is off and says why: $label', (tester) async {
      deskPhone(tester);
      final repo = _withRequest()..setCoachPrivate(summary);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('agreement-needed')), findsOneWidget);
      await tester.tap(find.text('Accept'), warnIfMissed: false);
      await tester.pump();
      expect(repo.responses, isEmpty);
    });
  }

  testWidgets('a verified agreement lets her accept at once', (tester) async {
    deskPhone(tester);
    final repo = _withRequest()
      ..setCoachPrivate(_private(AgreementStatus.verified));
    final state = await startedState(tester, repo);
    await tester.pumpWidget(
      deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('agreement-needed')), findsNothing);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(repo.responses, [('r1', true, null)]);
  });

  testWidgets('before her record is known nothing is blocked', (tester) async {
    deskPhone(tester);
    final repo = _withRequest();
    final state = await startedState(tester, repo);
    await tester.pumpWidget(
      deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('agreement-needed')), findsNothing);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(repo.responses, [('r1', true, null)]);
  });
}
