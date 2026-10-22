import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/chat_screen.dart';
import 'package:own_hub/features/private_coaching/domain/pricing.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('../contracts/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('price vectors', () {
    final vectors = _json('coaching_price_vectors.json');

    test('every vector gives the same final price as the server', () {
      final rows = (vectors['vectors'] as List).cast<Map<String, dynamic>>();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(
          finalPrice(row['coach'] as int),
          row['final'],
          reason: 'coach ${row['coach']}',
        );
      }
    });

    test('the range is the contract range, and refused prices are outside', () {
      expect(coachPriceInRange(vectors['coachMin'] as int), isTrue);
      expect(coachPriceInRange(vectors['coachMax'] as int), isTrue);
      for (final refused in (vectors['refused'] as List).cast<int>()) {
        expect(coachPriceInRange(refused), isFalse, reason: '$refused');
      }
    });
  });

  group('refund and sessions', () {
    test('sessions included scale with the length', () {
      expect(sessionsIncluded(4, 28), 4);
      expect(sessionsIncluded(4, 56), 8);
      expect(sessionsIncluded(3, 84), 9);
      expect(sessionsIncluded(2, 28), 2);
    });

    test('refund is the price less the share of sessions held', () {
      expect(refundAmount(1150, 0, 4), 1150);
      expect(refundAmount(1150, 1, 4), 1150 - 287);
      expect(refundAmount(1150, 4, 4), 0);
    });

    test('refund and coach share clamp out-of-range used counts', () {
      expect(refundAmount(1150, 9, 4), 0);
      expect(refundAmount(1150, -3, 4), 1150);
      expect(refundAmount(1150, 1, 0), 0);
      expect(coachShareAfterRefund(1000, 9, 4), 1000);
      expect(coachShareAfterRefund(1000, 1, 4), 250);
      expect(coachShareAfterRefund(1000, 1, 0), 0);
    });

    test('refund and coach share never add up past the price', () {
      for (var used = 0; used <= 8; used++) {
        final price = 3449;
        final coach = 2999;
        expect(refundAmount(price, used, 8) + (price * used) ~/ 8, price);
        expect(coachShareAfterRefund(coach, used, 8), lessThanOrEqualTo(coach));
      }
    });

    test('monthly equivalent uses integer division', () {
      expect(monthlyEquivalent(1150, 28), 1150);
      expect(monthlyEquivalent(3000, 84), 1000);
      expect(monthlyEquivalent(2312, 56), 1156);
    });
  });

  group('chat screen vectors', () {
    final cases = (_json('coaching_chat_screen_vectors.json')['cases'] as List)
        .cast<Map<String, dynamic>>();

    test('every vector gives the verdict the server gives', () {
      expect(cases.length, greaterThan(15));
      for (final row in cases) {
        final reason = ChatScreen.screen(row['text'] as String);
        expect(reason?.name, row['reason'], reason: row['text'] as String);
      }
    });

    test('plain numbers in a workout message are fine', () {
      for (final text in <String>[
        'Week 1: 3x10 at 40 kg, 3x8 at 45 kg',
        'Session on 24/10/2026 at 18:30',
        'Take 1500 kcal and 120 g protein',
      ]) {
        expect(ChatScreen.screen(text), isNull, reason: text);
      }
    });

    test('normalisation: letters, marks and invisible characters', () {
      // ة to ه, hamza forms to ا, ى to ي, diacritics and tatweel dropped.
      expect(ChatScreen.screen('انتِ غبيّـة'), ChatScreenReason.abuse);
      expect(
        ChatScreen.screen('ا\u200bن\u200cس\u200dتا باي'),
        ChatScreenReason.payment,
      );
      expect(ChatScreen.screen('INSTAPAY'), ChatScreenReason.payment);
      expect(ChatScreen.screen('Vodafone    Cash'), ChatScreenReason.payment);
      expect(ChatScreen.screen('ＩＮＳＴＡＰＡＹ'), ChatScreenReason.payment);
      expect(ChatScreen.screen('ＷＷＷ.example.com'), ChatScreenReason.link);
      expect(
        ChatScreen.screen('0\u200b1\u200b0 1234 5678'),
        ChatScreenReason.contact,
      );
      expect(ChatScreen.screen('010.1234.5678'), ChatScreenReason.contact);
      expect(ChatScreen.normalise('إأآٱ'), 'اااا');
      expect(ChatScreen.normalise('ىةؤئ'), 'يهوي');
    });

    test('digits written in Persian and Arabic count as digits', () {
      expect(ChatScreen.screen('۰۱۰۱۲۳۴۵۶۷۸'), ChatScreenReason.contact);
      expect(ChatScreen.screen('٠١٢٣٤٥٦٧٨٩٠١'), ChatScreenReason.contact);
    });

    test('the first reason wins when a text has several', () {
      expect(
        ChatScreen.screen('call 01012345678 or instapay'),
        ChatScreenReason.contact,
      );
      expect(
        ChatScreen.screen('instapay at https://x.com'),
        ChatScreenReason.payment,
      );
    });

    test('an insult is found as a word, not inside another word', () {
      expect(ChatScreen.screen('You idiot'), ChatScreenReason.abuse);
      expect(ChatScreen.screen('A classic assistant'), isNull);
      expect(ChatScreen.screen('Rest, then a shitake dish'), isNull);
    });

    test('ordinary decimals and abbreviations are not links', () {
      expect(ChatScreen.screen('2.5 litres, e.g. water'), isNull);
      expect(ChatScreen.screen('Eat well. Sleep well.'), isNull);
    });
  });
}
