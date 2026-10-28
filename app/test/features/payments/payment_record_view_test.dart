import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/payment_record_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/desk_model.dart'
    show tagOf;
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final confirmedAt = DateTime.utc(2026, 10, 27, 11, 32);

Payment confirmed({String reference = 'OH-4821'}) => payment(
  status: PaymentStatus.confirmed,
  clientUid: 'client-uid-9f3a',
  coachUid: 'coach-uid-71bc',
  reference: reference,
  confirmedAt: confirmedAt,
);

Future<void> open(
  WidgetTester tester,
  Payment p, {
  PaymentRecordSharer? onShare,
  String lang = 'en',
  double scale = 1,
  bool small = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  await tester.pumpWidget(
    host(
      PaymentRecordView(payment: p, onShare: onShare),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> tapSave(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('save-record')));
    await tester.pump();
    for (var i = 0; i < 50 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the record shows amount, date, reference, status and both '
      'parties as tags', (tester) async {
    await open(tester, confirmed());
    expect(find.text('Own Hub payment record'), findsOneWidget);
    expect(textOf(tester, 'rec-amount'), '500.37 EGP');
    // 11:32 UTC is 14:32 in Cairo: summer time (UTC+3) runs to 29 October.
    expect(textOf(tester, 'rec-date'), '27/10/2026 14:32 Cairo time');
    expect(textOf(tester, 'rec-ref'), 'OH-4821');
    expect(textOf(tester, 'rec-status'), 'Payment confirmed');
    expect(textOf(tester, 'rec-client'), tagOf('client-uid-9f3a'));
    expect(textOf(tester, 'rec-coach'), tagOf('coach-uid-71bc'));
    expect(
      find.text('This is a payment record. It is not a tax invoice.'),
      findsOneWidget,
    );
  });

  testWidgets('no name, no phone and no uid is drawn', (tester) async {
    await open(tester, confirmed());
    final all = [
      for (final e in find.byType(Text).evaluate())
        (e.widget as Text).data ?? '',
    ].join(' ');
    expect(all, isNot(contains('Rahma')));
    expect(all, isNot(contains('rahma.m@instapay')));
    expect(all, isNot(contains('client-uid')));
    expect(all, isNot(contains('coach-uid')));
    expect(all, isNot(contains('+20')));
    expect(all, isNot(contains('instapay')));
  });

  testWidgets('with no time on the document it still draws, date empty', (
    tester,
  ) async {
    await open(
      tester,
      Payment(
        id: 'p1',
        clientUid: 'c',
        coachUid: 'k',
        status: PaymentStatus.confirmed,
        reference: 'OH-1',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(textOf(tester, 'rec-date'), '');
  });

  testWidgets('Save renders a PNG and hands it to the sharer with the file '
      'name', (tester) async {
    Uint8List? sent;
    Rect? anchor;
    String? name;
    await open(
      tester,
      confirmed(),
      onShare: (png, origin, fileName) async {
        sent = png;
        anchor = origin;
        name = fileName;
      },
    );
    await tapSave(tester, () => sent != null);
    expect(sent, isNotNull);
    expect(sent!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(sent!.length, greaterThan(1000));
    expect(name, 'own-hub-payment-OH-4821.png');
    expect(anchor, isNotNull);
    expect(anchor!.width, greaterThan(0));
  });

  testWidgets('a share sheet that fails costs her nothing she can see', (
    tester,
  ) async {
    await open(
      tester,
      confirmed(),
      onShare: (png, origin, fileName) async => throw StateError('no sheet'),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save-record')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey('save-record')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Arabic: Western digits, tags and amounts left to right', (
    tester,
  ) async {
    await open(tester, confirmed(), lang: 'ar');
    final all = [
      for (final e in find.byType(Text).evaluate())
        (e.widget as Text).data ?? '',
    ].join(' ');
    expect(RegExp(r'[٠-٩]').hasMatch(all), isFalse);
    expect(textOf(tester, 'rec-amount'), '500.37 جنيه');
    expect(textOf(tester, 'rec-date'), startsWith('27/10/2026 14:32'));
    for (final key in ['rec-amount', 'rec-ref', 'rec-client', 'rec-coach']) {
      expect(
        tester.widget<Text>(find.byKey(ValueKey(key))).textDirection,
        TextDirection.ltr,
        reason: key,
      );
    }
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('rec-status')))
          .textDirection,
      isNull,
      reason: 'the status is a sentence in her language',
    );
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets('budget and layout, $lang at ${scale}x on '
            '${small ? '375x667' : '390x844'}', (tester) async {
          await open(
            tester,
            confirmed(),
            lang: lang,
            scale: scale,
            small: small,
          );
          expect(
            countControlsAboveFold(tester, includeChrome: false),
            lessThanOrEqualTo(5),
          );
          expect(filledPrimaryActions(tester), 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
