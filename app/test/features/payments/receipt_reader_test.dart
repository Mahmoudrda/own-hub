import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/events/domain/cairo_time.dart';
import 'package:own_hub/features/payments/domain/receipt_reader.dart';

// Synthetic receipts in the shapes real banks and the InstaPay app draw.
// No real name, number or account appears here.
final created = parseCairo('2026-10-27 14:00')!;
final now = parseCairo('2026-10-27 14:40')!;
final expected = ExpectedPayment(
  amountPiasters: 50037,
  coachAddress: 'rahma.m@instapay',
  coachAccountName: 'Rahma Mohsen',
  createdAt: created,
);

PhoneVerdict verdict(List<String> texts, {ExpectedPayment? e}) =>
    phoneVerdict(readReceipt(texts, e ?? expected, now));

const instapayScreen =
    'Approved Transaction\nYour transaction was successful\n500.37 EGP\nFrom\nsara.k@instapay 1234\nTo Instapay\nRah*** M***\nrahma.m@instapay\nMore Details';
const instapayDetails = 'Transaction ID 123456789012\n27/10/2026 14:32';

void main() {
  group('green: every fact found', () {
    final fixtures = <String, List<String>>{
      'InstaPay result screen plus More Details': [
        instapayScreen,
        instapayDetails,
      ],
      'one picture with the details open': [
        'Transfer successful\nAmount EGP 500.37\nTo: rahma.m@instapay\nTransaction number 201234567890123\nDate 27/10/2026 14:32:45',
      ].toList(),
      'text month and 12 hour clock': [
        'Transfer completed\n500.37 EGP\nBeneficiary rahma.m@instapay\nReference Number: 201234567890123\n27 Oct 2026, 02:32 PM',
      ],
      'comma decimal and RRN': [
        'Your transaction was successful\n500,37 EGP\nTo rahma.m@instapay\nRRN 612345678901\n27-10-2026 14:32',
      ],
      'ISO date': [
        'Approved Transaction\nEGP 500.37\nrahma.m@instapay\nTransaction ID 123456789012\n2026-10-27 14:32',
      ],
      'label and value on separate lines': [
        'Your transaction was successful\n500.37 EGP\nrahma.m@instapay\nTransaction ID\n123456789012\nDate and time\n27/10/2026 14:32',
      ],
      'masked name and no address': [
        'Approved Transaction\n500.37 EGP\nTo\nRah*** M***\nTransaction ID 123456789012\n27/10/2026 14:32',
      ],
      'Arabic receipt, Arabic-Indic digits': [
        'تمت العملية بنجاح\n٥٠٠٫٣٧ جنيه\nإلى: rahma.m@instapay\nرقم العملية ١٢٣٤٥٦٧٨٩٠١٢\n٢٧/١٠/٢٠٢٦ ٠٢:٣٢ م',
      ],
      'Arabic receipt with a month name': [
        'تم التحويل بنجاح\n500.37 جنيه\nإلى rahma.m@instapay\nالرقم المرجعي 123456789012\n٢٧ أكتوبر ٢٠٢٦، ٢:٣٢ م',
      ],
      'Arabic details on a second picture': [
        'Approved Transaction\n500.37 EGP\nrahma.m@instapay',
        'رقم العملية 123456789012\n27/10/2026 14:32',
      ],
      'noisy OCR with extra lines': [
        '10:41  5G\nHome\nYour transaction was successful\n500.37 EGP\nFrom sara.k@instapay\nTo rahma.m@instapay\nTransaction ID 123456789012\n27/10/2026 14:32\nShare receipt',
      ],
    };
    fixtures.forEach((name, texts) {
      test(name, () {
        final r = readReceipt(texts, expected, now);
        expect(
          phoneVerdict(r),
          PhoneVerdict.green,
          reason: r.reasons.join(','),
        );
        expect(r.txnNumber, isNotNull);
        expect(r.timeInWindow, isTrue);
      });
    });

    test('an Arabic account name matches its first letters', () {
      final e = ExpectedPayment(
        amountPiasters: 50037,
        coachAddress: '',
        coachAccountName: 'رحمة محسن',
        createdAt: created,
      );
      final r = readReceipt(
        [
          'تمت العملية بنجاح\n500.37 جنيه\nإلى: رحمة م***\nرقم العملية 123456789012\n27/10/2026 14:32',
        ],
        e,
        now,
      );
      expect(r.recipientNameStartFound, isTrue);
      expect(phoneVerdict(r), PhoneVerdict.green);
    });

    test('thousands in the amount are read', () {
      final e = ExpectedPayment(
        amountPiasters: 150037,
        coachAddress: 'rahma.m@instapay',
        coachAccountName: 'Rahma Mohsen',
        createdAt: created,
      );
      expect(
        verdict([
          'Your transaction was successful\n1,500.37 EGP\nrahma.m@instapay\nTransaction ID 123456789012\n27/10/2026 14:32',
        ], e: e),
        PhoneVerdict.green,
      );
    });

    test('a long account name still matches its masked start', () {
      final e = ExpectedPayment(
        amountPiasters: 50037,
        coachAddress: '',
        coachAccountName: 'Rahma Mohsen Abdelrahman Elsayed Ibrahim',
        createdAt: created,
      );
      final r = readReceipt(['Rah*** M*** A***'], e, now);
      expect(r.recipientNameStartFound, isTrue);
    });

    test('the sender handle is read', () {
      expect(
        readReceipt(
          [instapayScreen, instapayDetails],
          expected,
          now,
        ).senderHandle,
        'sara.k@instapay',
      );
    });
  });

  group('amber: something not found, never red', () {
    test('the receipt alone has no number and no time', () {
      final r = readReceipt([instapayScreen], expected, now);
      expect(phoneVerdict(r), PhoneVerdict.amber);
      expect(r.reasons, containsAll(['no_txn', 'no_time']));
    });

    test('each fact missing on its own is amber and never red', () {
      final full = '$instapayScreen\n$instapayDetails';
      final variants = <String, String>{
        'no success line': full.replaceAll(
          'Approved Transaction\nYour transaction was successful\n',
          '',
        ),
        'no amount': full.replaceAll('500.37 EGP', ''),
        'no recipient': full
            .replaceAll('rahma.m@instapay', '')
            .replaceAll('Rah*** M***', ''),
        'no transaction number': full.replaceAll(
          'Transaction ID 123456789012',
          '',
        ),
        'no time': full.replaceAll('27/10/2026 14:32', ''),
      };
      variants.forEach((name, text) {
        expect(verdict([text]), PhoneVerdict.amber, reason: name);
      });
    });

    test('a time before the request is not accepted', () {
      final r = readReceipt(
        [instapayScreen, 'Transaction ID 123456789012\n26/10/2026 10:00'],
        expected,
        now,
      );
      expect(r.timeSeen, isNotNull);
      expect(r.timeInWindow, isFalse);
      expect(phoneVerdict(r), PhoneVerdict.amber);
    });

    test('a time in the future is not accepted', () {
      final r = readReceipt(
        [instapayScreen, 'Transaction ID 123456789012\n27/10/2026 18:30'],
        expected,
        now,
      );
      expect(r.timeInWindow, isFalse);
    });

    test('a bank SMS alone is never green', () {
      expect(
        verdict([
          'Your account was credited EGP 500.37 on 27/10/2026 14:32 ref 123456789012',
        ]),
        isNot(PhoneVerdict.green),
      );
    });

    test('a balance-style line with the same figure is not the amount', () {
      final r = readReceipt(
        [
          'Your transaction was successful\nAvailable balance 500.37 EGP\nrahma.m@instapay',
        ],
        expected,
        now,
      );
      expect(r.amountFound, isFalse);
    });

    test('a screenshot in a script the phone cannot read is amber', () {
      expect(verdict(['', '   ']), PhoneVerdict.amber);
    });

    test('an unknown layout with the right words is amber at worst', () {
      expect(verdict(['OK\n500.37\nrahma.m@instapay']), PhoneVerdict.amber);
    });
  });

  group('red: a contradiction', () {
    test('a different amount next to EGP', () {
      final r = readReceipt(
        [
          instapayScreen.replaceAll('500.37 EGP', '450.00 EGP'),
          instapayDetails,
        ],
        expected,
        now,
      );
      expect(phoneVerdict(r), PhoneVerdict.red);
      expect(r.otherAmountPiasters, 45000);
      expect(r.reasons, contains('different_amount'));
    });

    test('a failed, pending or unsuccessful status', () {
      for (final status in [
        'Transaction failed',
        'Pending',
        'Transaction unsuccessful',
        'Your transfer was declined',
        'فشلت العملية',
        'قيد التنفيذ',
      ]) {
        final r = readReceipt(
          [
            '$status\n500.37 EGP\nrahma.m@instapay\nTransaction ID 123456789012\n27/10/2026 14:32',
          ],
          expected,
          now,
        );
        expect(phoneVerdict(r), PhoneVerdict.red, reason: status);
      }
    });
  });

  group('the wrong kind of message', () {
    test('a card purchase alert', () {
      final r = readReceipt(
        [
          'Your credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre',
        ],
        expected,
        now,
      );
      expect(phoneVerdict(r), PhoneVerdict.wrongMessage);
      expect(r.reasons, contains('card_message'));
    });

    test('an Arabic card alert', () {
      expect(
        verdict([
          'تم استخدام بطاقة الائتمان المنتهية 9412 بمبلغ 570.00 جنيه. الحد المتاح 10,000',
        ]),
        PhoneVerdict.wrongMessage,
      );
    });

    test('an OTP message', () {
      expect(
        verdict(['Your OTP is 481516. Do not share it.']),
        PhoneVerdict.wrongMessage,
      );
    });

    test('a receipt that names InstaPay is not a card message even with the word purchase', () {
      expect(
        verdict([
          'Purchase receipt via InstaPay\nYour transaction was successful\n500.37 EGP\nrahma.m@instapay',
        ]),
        isNot(PhoneVerdict.wrongMessage),
      );
    });
  });

  group('parts', () {
    test('amount formats', () {
      expect(amountToPiasters('500.37'), 50037);
      expect(amountToPiasters('500,37'), 50037);
      expect(amountToPiasters('1,500.00'), 150000);
      expect(amountToPiasters('1 500,50'), 150050);
      expect(amountToPiasters('abc'), isNull);
      expect(amountToPiasters(normalizeDigits('٥٧٠٫٣٧')), 57037);
    });

    test('31 February is refused', () {
      final r = readReceipt(['31/02/2026 10:00'], expected, now);
      expect(r.timeSeen, isNull);
    });

    test('the same screenshot read twice gives the same reading', () {
      expect(
        readReceipt([instapayScreen, instapayDetails], expected, now).toJson(),
        readReceipt([instapayScreen, instapayDetails], expected, now).toJson(),
      );
    });

    test('what goes to the server has no text and no picture', () {
      final json = readReceipt(
        [instapayScreen, instapayDetails],
        expected,
        now,
      ).toJson();
      expect(
        json.keys,
        containsAll(['success', 'amountFound', 'txnNumber', 'timeInWindow']),
      );
      expect(
        json.values.whereType<String>().any((v) => v.length > 40),
        isFalse,
      );
      expect(json.containsKey('text'), isFalse);
    });
  });

  test('garbage never throws and is never green', () {
    final random = Random(7);
    final inputs = <List<String>>[
      const [],
      const [''],
      [
        String.fromCharCodes(
          List.generate(100000, (_) => random.nextInt(0xD7FF)),
        ),
      ],
      ['\u0000' * 5000],
      ['1' * 20000],
      ['😀' * 9000],
      ['((((' * 2000],
      ['Transaction ID ${'9' * 60}'],
      ['٠' * 3000],
      ['27/13/2026 99:99 500.37 EGP'],
    ];
    for (final texts in inputs) {
      final r = readReceipt(texts, expected, now);
      expect(phoneVerdict(r), isNot(PhoneVerdict.green));
    }
  });
}
