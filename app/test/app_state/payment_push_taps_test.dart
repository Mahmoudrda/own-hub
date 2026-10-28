import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/payment_push_taps.dart';
import 'package:own_hub/features/payments/data/payments_hub.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/domain/payment_push.dart';
import 'package:own_hub/features/payments/presentation/coach_payments_view.dart';
import 'package:own_hub/features/payments/presentation/fee_statement_view.dart';
import 'package:own_hub/features/payments/presentation/payment_address_view.dart';
import 'package:own_hub/features/payments/presentation/status_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../features/payments/support/fake_payments_repository.dart';

final DateTime _now = DateTime.utc(2026, 11, 10, 12);

FeeStatement _statement(int month, int due) => FeeStatement(
  id: 'coach__2026-${month.toString().padLeft(2, '0')}',
  year: 2026,
  month: month,
  status: 'open',
  totalDuePiasters: due,
  lines: const [],
  payTo: const FeePayTo(address: 'ownhub@instapay', holderName: 'Own Hub'),
  dueAt: _now.add(const Duration(days: 20)),
);

void main() {
  late FakePaymentsRepository fake;
  late List<String> asked;
  late bool open;

  setUp(() {
    fake = FakePaymentsRepository(uid: 'me')
      ..setPayments([payment(id: 'p1')])
      ..statements = [_statement(10, 9000), _statement(9, 4000)];
    PaymentsHub.override = fake;
    asked = [];
    open = true;
  });

  tearDown(() => PaymentsHub.override = null);

  Future<NavigatorState> app(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        routes: {appRoutes['H05']!.name: (_) => const Text('my coach screen')},
        home: const Scaffold(body: Text('home')),
      ),
    );
    return tester.state<NavigatorState>(find.byType(Navigator));
  }

  bool tap(NavigatorState nav, Map<String, Object?> data) =>
      PaymentPushTaps.open(
        nav,
        data,
        allowed: (screen) {
          asked.add(screen);
          return open;
        },
      );

  testWidgets('a client kind with its payment opens that payment', (
    tester,
  ) async {
    final nav = await app(tester);
    expect(
      tap(nav, {'kind': 'instapayDifferentAmount', 'paymentId': 'p1'}),
      isTrue,
    );
    await tester.pumpAndSettle();
    final view = tester.widget<PaymentStatusView>(
      find.byType(PaymentStatusView),
    );
    expect(view.paymentId, 'p1');
    expect(asked, ['H05']);
  });

  testWidgets('a client kind with no payment opens her coach screen', (
    tester,
  ) async {
    final nav = await app(tester);
    expect(tap(nav, {'kind': 'instapayAccessEndsSoon'}), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('my coach screen'), findsOneWidget);
    expect(find.byType(PaymentStatusView), findsNothing);
  });

  testWidgets('a coach kind opens the inbox, her details or the statement', (
    tester,
  ) async {
    final nav = await app(tester);
    expect(tap(nav, {'kind': 'instapayProofSent', 'paymentId': 'p1'}), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(CoachPaymentsView), findsOneWidget);
    expect(asked, ['K18']);
    nav.pop();
    await tester.pumpAndSettle();

    expect(tap(nav, {'kind': 'instapayAddressChangedCoach'}), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(PaymentAddressView), findsOneWidget);
    nav.pop();
    await tester.pumpAndSettle();

    expect(tap(nav, {'kind': 'instapaySuspended'}), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(CoachPaymentsView), findsOneWidget);
  });

  testWidgets('a fee kind opens the statement of the month it names', (
    tester,
  ) async {
    final nav = await app(tester);
    expect(
      tap(nav, {'kind': 'instapayFeeOverdue', 'statementMonth': '2026-09'}),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.byType(FeeStatementView), findsOneWidget);
    // September is the one shown, so October is listed as another month.
    expect(find.byKey(const ValueKey('month-coach__2026-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-coach__2026-09')), findsNothing);
  });

  testWidgets('a fee kind with no month opens the newest statement', (
    tester,
  ) async {
    final nav = await app(tester);
    expect(tap(nav, {'kind': 'instapayStatementReady'}), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-coach__2026-09')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-coach__2026-10')), findsNothing);
  });

  testWidgets('a closed gate opens nothing, for every kind', (tester) async {
    final nav = await app(tester);
    open = false;
    for (final kind in kPaymentPushScreens.keys) {
      expect(
        tap(nav, {
          'kind': kind,
          'paymentId': 'p1',
          'statementMonth': '2026-10',
        }),
        isFalse,
        reason: kind,
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(nav.canPop(), isFalse);
    expect(asked.toSet(), {'H05', 'K18'});
  });

  testWidgets('every kind opens its side of the app when the gate is open', (
    tester,
  ) async {
    final nav = await app(tester);
    for (final kind in kPaymentPushScreens.keys) {
      asked.clear();
      final coach = paymentPushFor({'kind': kind})!.forCoach;
      expect(
        tap(nav, {
          'kind': kind,
          'paymentId': 'p1',
          'statementMonth': '2026-10',
        }),
        isTrue,
        reason: kind,
      );
      await tester.pumpAndSettle();
      expect(nav.canPop(), isTrue, reason: kind);
      expect(asked, [coach ? 'K18' : 'H05'], reason: kind);
      nav.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('something that is not a payments push opens nothing', (
    tester,
  ) async {
    final nav = await app(tester);
    expect(tap(nav, {'kind': 'verificationApproved'}), isFalse);
    expect(tap(nav, {}), isFalse);
    expect(
      PaymentPushTaps.open(null, {
        'kind': 'instapayConfirmed',
        'paymentId': 'p1',
      }, allowed: (_) => true),
      isFalse,
    );
    expect(asked, isEmpty);
    expect(nav.canPop(), isFalse);
  });
}
