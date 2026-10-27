import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/events/domain/cairo_time.dart';
import 'package:own_hub/features/payments/domain/receipt_reader.dart';
import 'package:own_hub/features/payments/domain/redaction_model.dart';

final expected = ExpectedPayment(
  amountPiasters: 50037,
  coachAddress: 'rahma.m@instapay',
  coachAccountName: 'Rahma Mohsen',
  createdAt: parseCairo('2026-10-27 14:00')!,
);

OcrLine line(String text, double top) =>
    OcrLine(text, Rect.fromLTWH(40, top, 600, 40));

RedactionModel model(List<OcrLine> lines) => RedactionModel(
  imageSize: const Size(1080, 2000),
  lines: lines,
  expected: expected,
);

void main() {
  test(
    'amount, address, name, transaction and success lines are protected',
    () {
      final m = model([
        line('500.37 EGP', 100),
        line('rahma.m@instapay', 200),
        line('Rah*** M***', 300),
        line('Transaction ID 123456789012', 400),
        line('Your transaction was successful', 500),
        line('Weather today', 900),
      ]);
      expect(m.protected.length, 5);
      expect(m.suggested, isEmpty);
    },
  );

  test('card and balance lines are suggested and black from the start', () {
    final m = model([
      line('credit card ending 9412', 700),
      line('Available limit 20,000', 800),
    ]);
    expect(m.suggested.length, 2);
    expect(m.blackouts.length, 2);
  });

  test(
    'a long digit line is a card number, a 12 digit transaction number is not',
    () {
      final m = model([
        line('Card 4111111111111111', 700),
        line('Transaction ID 123456789012', 400),
      ]);
      expect(m.suggested.length, 1);
      expect(m.protected.length, 1);
    },
  );

  test(
    'a line holding the amount AND a card word stays protected, not hidden',
    () {
      final m = model([line('Card ending 1234 paid 500.37 EGP', 100)]);
      expect(m.protected.length, 1);
      expect(m.suggested, isEmpty);
    },
  );

  test('a black box over a protected line is refused', () {
    final m = model([line('500.37 EGP', 100)]);
    expect(m.tryAddBlackout(const Rect.fromLTWH(50, 90, 200, 60)), isFalse);
    expect(m.blackouts, isEmpty);
  });

  test('a black box elsewhere is accepted and undo removes it', () {
    final m = model([line('500.37 EGP', 100)]);
    expect(m.tryAddBlackout(const Rect.fromLTWH(50, 600, 200, 60)), isTrue);
    expect(m.blackouts.length, 1);
    expect(m.undo(), isTrue);
    expect(m.blackouts, isEmpty);
    expect(m.undo(), isFalse);
  });

  test('a crop that cuts a protected line is refused, one that keeps all is accepted', () {
    final m = model([line('500.37 EGP', 100), line('rahma.m@instapay', 200)]);
    expect(m.trySetCrop(const Rect.fromLTWH(0, 150, 1080, 800)), isFalse);
    expect(m.crop, isNull);
    expect(m.trySetCrop(const Rect.fromLTWH(0, 0, 1080, 800)), isTrue);
    expect(m.crop, isNotNull);
  });

  test('a tiny box and a tiny crop are refused', () {
    final m = model([line('Weather', 900)]);
    expect(m.tryAddBlackout(const Rect.fromLTWH(10, 10, 2, 2)), isFalse);
    expect(m.trySetCrop(const Rect.fromLTWH(0, 0, 20, 20)), isFalse);
  });

  test('untouched means no box and no crop', () {
    final m = model([line('Weather', 900)]);
    expect(m.untouched, isTrue);
    m.tryAddBlackout(const Rect.fromLTWH(50, 600, 200, 60));
    expect(m.untouched, isFalse);
  });

  test('no lines at all (the phone read nothing) is a model with nothing protected', () {
    final m = model(const []);
    expect(m.protected, isEmpty);
    expect(m.tryAddBlackout(const Rect.fromLTWH(10, 10, 100, 100)), isTrue);
  });
}
