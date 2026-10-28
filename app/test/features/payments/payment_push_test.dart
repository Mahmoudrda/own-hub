import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/domain/payment_push.dart';

/// The kinds the server can send, read from `functions/payments/notices.py`.
Set<String> serverKinds() {
  final notices = File('../functions/payments/notices.py').readAsStringSync();
  final kinds = RegExp(
    r'^    "(instapay\w+)": \{"en"',
    multiLine: true,
  ).allMatches(notices).map((m) => m.group(1)!).toSet();
  expect(kinds, isNotEmpty);
  return kinds;
}

void main() {
  test('every kind the server sends has a screen, and no screen is stale', () {
    final server = serverKinds();
    expect(
      kPaymentPushScreens.keys.toSet().difference(server),
      isEmpty,
      reason: 'a kind the server no longer sends',
    );
    expect(
      server.difference(kPaymentPushScreens.keys.toSet()),
      isEmpty,
      reason: 'a new kind with no place to go: add it to kPaymentPushScreens',
    );
  });

  test('the fee kinds are the ones the server names by month', () {
    final notices = File('../functions/payments/notices.py').readAsStringSync();
    final listed = RegExp(r'STATEMENT_KINDS = frozenset\(\{([^}]*)\}\)')
        .firstMatch(notices)!
        .group(1)!;
    final server = RegExp(r'"(instapay\w+)"')
        .allMatches(listed)
        .map((m) => m.group(1))
        .toSet();
    final here = {
      for (final e in kPaymentPushScreens.entries)
        if (e.value == PaymentPushScreen.statements) e.key,
    };
    expect(here, server);
    expect(notices, contains('"statementMonth"'));
    expect(notices, contains('"paymentId"'));
  });

  test('each kind opens the side of the app the server sends it to', () {
    final states = File('../functions/payments/states.py').readAsStringSync();
    final recipients = <String, Set<String>>{};
    for (final m in RegExp(
      r'\((CLIENT|COACH), "(instapay\w+)"\)',
    ).allMatches(states)) {
      recipients.putIfAbsent(m.group(2)!, () => {}).add(m.group(1)!);
    }
    expect(recipients, isNotEmpty);
    for (final e in recipients.entries) {
      expect(e.value.length, 1, reason: '${e.key} goes to one side only');
      final push = paymentPushFor({'kind': e.key})!;
      expect(push.forCoach, e.value.single == 'COACH', reason: e.key);
    }
  });

  test('the kinds sent outside the state table go where their words say', () {
    PaymentPushScreen screen(String kind) =>
        paymentPushFor({'kind': kind})!.screen;
    expect(
      screen('instapayAddressChangedCoach'),
      PaymentPushScreen.coachAddress,
    );
    expect(screen('instapayAddressChanged'), PaymentPushScreen.status);
    expect(screen('instapaySuspended'), PaymentPushScreen.coachInbox);
    expect(screen('instapayPaused'), PaymentPushScreen.status);
    expect(screen('instapayRefundRequested'), PaymentPushScreen.coachInbox);
    expect(screen('instapayStatementReady'), PaymentPushScreen.statements);
    expect(screen('instapayFeeOverdue'), PaymentPushScreen.statements);
  });

  test('the ids travel as the server sends them and odd ones are dropped', () {
    final ok = paymentPushFor({
      'kind': 'instapayConfirmed',
      'paymentId': 'aB3dE5-fG_h',
    })!;
    expect(ok.paymentId, 'aB3dE5-fG_h');
    final month = paymentPushFor({
      'kind': 'instapayFeeOverdue',
      'statementMonth': '2026-10',
    })!;
    expect(month.statementMonth, '2026-10');
    for (final bad in ['', 'a/b', '..', 'x' * 129, ' pay', 'p\n1']) {
      expect(
        paymentPushFor({'kind': 'instapayConfirmed', 'paymentId': bad})!
            .paymentId,
        isNull,
        reason: bad,
      );
    }
    for (final bad in ['2026-13', '2026-00', '26-10', 'last month', '']) {
      expect(
        paymentPushFor({
          'kind': 'instapayStatementReady',
          'statementMonth': bad,
        })!.statementMonth,
        isNull,
        reason: bad,
      );
    }
    expect(
      paymentPushFor({'kind': 'instapayConfirmed', 'paymentId': 7})!.paymentId,
      isNull,
    );
  });

  test('anything that is not a payments kind opens nothing', () {
    expect(paymentPushFor({}), isNull);
    expect(paymentPushFor({'kind': 'verificationApproved'}), isNull);
    expect(paymentPushFor({'kind': 'planShared'}), isNull);
    expect(paymentPushFor({'kind': 3}), isNull);
    expect(paymentPushFor({'paymentId': 'p1'}), isNull);
  });
}
