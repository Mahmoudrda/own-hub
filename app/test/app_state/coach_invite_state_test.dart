import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/coach_invite_state.dart';
import 'package:own_hub/features/coach/domain/coach_invite.dart';

class _Store implements CoachInviteStore {
  _Store(this.result);
  final InviteResult result;

  @override
  Future<String> create() async => 'ABCD2345';

  @override
  Future<InviteResult> accept(String code) async => result;
}

void main() {
  final invite = CoachInviteState.instance;
  setUp(invite.reset);
  tearDown(invite.reset);

  test('a redeemed code follows its coach through a relaunch, and only her', () async {
    invite.keepPending('ABCD2345');
    final result = await invite.redeem(
      _Store(const InviteResult(InviteRedemption.linked, 'coachA')),
      allowed: true,
    );
    expect(result?.outcome, InviteRedemption.linked);
    expect(invite.pendingCoach, 'coachA');

    // Her page opens: the pending code goes, the used one stays.
    invite.clearPending();
    expect(invite.pendingCode, isNull);
    expect(invite.codeFor('coachA'), 'ABCD2345');

    final document = jsonEncode(AppSnapshot.capture());
    invite.reset();
    expect(invite.codeFor('coachA'), isNull);
    expect(AppSnapshot.restore(document), greaterThan(0));

    expect(invite.pendingCode, isNull);
    expect(invite.codeFor('coachA'), 'ABCD2345');
    expect(invite.codeFor('coachB'), isNull);

    // Once she has asked coach A the code is spent.
    invite.spent('coachB');
    expect(invite.codeFor('coachA'), 'ABCD2345');
    invite.spent('coachA');
    expect(invite.codeFor('coachA'), isNull);
    expect(AppSnapshot.capture()['invite'], isNull);
  });
}
