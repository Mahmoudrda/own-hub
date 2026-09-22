// B09's banner is a promise: "No weight-loss promises and no timelines. We
// check every ad against the same rules before it runs." P0-ADS-03 is the row
// that makes it a fact rather than a sentence — "the claim rules are enforced
// not just displayed".
//
// Two halves to this file, and the second matters more than the first.
//
// The POSITIVE cases prove the policy catches a claim in English and in
// Arabic. The NEGATIVE controls prove it does not catch the product's own
// honest copy — because a policy that flags "Giza · at home · 20 minutes" gets
// switched off by the first coach who hits it, and then it protects nobody.
// Every negative control below is a real string from the mockup or the
// dictionary.
//
// The Arabic literals live here, in test/, not in lib/. `i18n_guard_test.dart`
// forbids Arabic on a code line under lib/, so the patterns themselves ship as
// \u escapes — and the "decodes to" group is what stops an escape sequence
// silently becoming the wrong word.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/marketing_claim_policy.dart';

const policy = MarketingClaimPolicy();

void main() {
  group('the escaped patterns decode to the Arabic they claim to', () {
    // seed_library.dart carries 56 Arabic values the same way and has the same
    // test. An escape sequence is unreadable by design; this is the readable
    // half, and it is executable, which a comment is not.

    test('weight-loss vocabulary', () {
      expect(
        kArabicWeightLossPattern,
        r'تخسيس|تنحيف|خسارة\s*(?:ال)?وزن|إنقاص\s*(?:ال)?وزن|انقاص\s*(?:ال)?وزن|نزول\s*(?:ال)?وزن|فقدان\s*(?:ال)?وزن|تخفيف\s*(?:ال)?وزن|حرق\s*(?:ال)?دهون|(?:خسّ?ي|اخسري|تخسري)\s*\d+\s*كيلو|\d+\s*كيلو\s*(?:أقل|اقل|تحت|في)',
      );
    });

    test('timeline vocabulary', () {
      expect(
        kArabicTimelinePattern,
        r'(?:في|خلال|بعد|خلال\s*مدة)\s*(?:\d+|شهرين|أسبوعين|اسبوعين|يومين)\s*(?:يوم|أيام|يوما|يومًا|أسبوع|أسابيع|اسبوع|اسابيع|شهر|شهور|أشهر|اشهر)|(?:في|خلال)\s*(?:شهرين|أسبوعين|اسبوعين)|(?:في|خلال)\s*(?:شهر|أسبوع|اسبوع)\s*(?:واحد|فقط)',
      );
    });

    test('medical vocabulary', () {
      expect(
        kArabicMedicalPattern,
        r'(?:علاج|أعالج|اعالج|يعالج|نعالج)\s*(?:ال)?(?:تكيس|سكري|ضغط|ألم|الم|إصابة|اصابة|مرض|حالة|عقم|اكتئاب|قلق)|شفاء\s*(?:تام|كامل|مضمون)|(?:تشخيص|أشخص|اشخص|يشخص)|بدون\s*(?:طبيب|دواء|أدوية|ادوية|جراحة)|(?:بديل|بدل)\s*(?:عن\s*)?(?:ال)?(?:طبيب|دواء|علاج\s*طبيعي)',
      );
    });

    test('ranking vocabulary', () {
      expect(
        kArabicRankingPattern,
        r'الأفضل|الافضل|الأولى|الاولى|رقم\s*(?:1|واحد)|الأكثر\s*(?:طلبا|طلبًا|متابعة|حجزا|حجزًا)|الاكثر\s*(?:طلبا|متابعة)',
      );
    });

    test('every escaped pattern is a valid regular expression', () {
      for (final source in const [
        kArabicWeightLossPattern,
        kArabicTimelinePattern,
        kArabicMedicalPattern,
        kArabicRankingPattern,
      ]) {
        expect(
          () => RegExp(source, unicode: true),
          returnsNormally,
          reason:
              'a broken escape would make the policy silently match '
              'nothing, which fails open',
        );
      }
    });
  });

  group('weight-loss promises are rejected', () {
    test('English, the headline P0-ADS-03 names', () {
      final check = policy.check('Lose 10 kg in 30 days');
      expect(check.pass, isFalse);
      expect(check.has(ClaimKind.weightLoss), isTrue);
      expect(check.has(ClaimKind.timeline), isTrue);
    });

    test('English, written as a result rather than a promise', () {
      expect(policy.check('20 kg down, guaranteed').pass, isFalse);
      expect(policy.check('Rapid weight loss for busy mums').pass, isFalse);
      expect(policy.check('Drop 2 dress sizes').pass, isFalse);
    });

    test('English, spelled out rather than digits', () {
      // "lose ten kilos" is the same promise as "lose 10 kg".
      expect(policy.check('Lose ten kilos with me').pass, isFalse);
    });

    test('Arabic', () {
      expect(policy.check('تخسيس سريع للسيدات').pass, isFalse);
      expect(policy.check('خسارة الوزن بدون مجهود').pass, isFalse);
      expect(policy.check('إنقاص الوزن مضمون').pass, isFalse);
      expect(policy.check('حرق الدهون في البيت').pass, isFalse);
    });

    test('the offending span is marked, not the whole field', () {
      final text = 'Back to lifting. Lose 10 kg. Slowly.';
      final check = policy.check(text);
      final violation = check.violations.firstWhere(
        (v) => v.kind == ClaimKind.weightLoss,
      );
      expect(text.substring(violation.start, violation.end), 'Lose 10 kg');
    });
  });

  group('timeline promises are rejected', () {
    test('English', () {
      expect(policy.check('Results in 30 days').pass, isFalse);
      expect(policy.check('Transformed within six weeks').pass, isFalse);
      expect(policy.check('Our 30-day challenge').pass, isFalse);
      expect(policy.check('A new you in just 2 months').pass, isFalse);
    });

    test('Arabic', () {
      expect(policy.check('نتائج في 30 يوم').pass, isFalse);
      expect(policy.check('تغيير خلال شهرين').pass, isFalse);
      expect(policy.check('في شهر واحد فقط').pass, isFalse);
    });

    test('the preposition has to come first — that is what makes it a promise', () {
      // The mockup's own ad headline. "Six weeks after birth" describes where a
      // woman IS; "in six weeks" promises where she will be.
      expect(policy.check('Six weeks after birth, on the floor').pass, isTrue);
      expect(policy.check('In six weeks you will be lifting').pass, isFalse);
    });
  });

  group('medical claims are rejected', () {
    test('English', () {
      expect(policy.check('I cure PCOS with training').pass, isFalse);
      expect(policy.check('Reverses diabetes').pass, isFalse);
      expect(policy.check('Heals your diastasis').pass, isFalse);
      expect(policy.check('No doctor needed').pass, isFalse);
      expect(policy.check('Clinically proven programme').pass, isFalse);
    });

    test('Arabic', () {
      expect(policy.check('أعالج تكيس المبايض').pass, isFalse);
      expect(policy.check('شفاء تام من الألم').pass, isFalse);
      expect(policy.check('بدون طبيب').pass, isFalse);
    });
  });

  group('rankings are rejected — but only where a figure is claimed', () {
    test('checkStat rejects a ranking', () {
      expect(policy.checkStat('#1 coach in Cairo').pass, isFalse);
      expect(policy.checkStat('Most booked').pass, isFalse);
      expect(policy.checkStat('الأفضل في مصر').pass, isFalse);
      expect(
        policy.checkStat('#1 coach in Cairo').has(ClaimKind.ranking),
        isTrue,
      );
    });

    test('prose is not checked for rankings', () {
      // Rule 11 is about a leaderboard, and a `numbers` stat is the one place a
      // ranking would look like data. Running it over every paragraph would
      // flag ordinary sentences and teach coaches the policy is noise.
      expect(policy.check('#1 coach in Cairo').has(ClaimKind.ranking), isFalse);
    });

    test('a personal best is not a ranking', () {
      // "Measured against your own history only." The product's own words.
      expect(policy.checkStat('Personal best').pass, isTrue);
      expect(policy.checkStat('Her best plank').pass, isTrue);
    });
  });

  group('negative controls — the product\'s own copy must pass', () {
    // Every string here is from the mockup or app_en.arb. A failure in this
    // group means the policy would block honest writing, which is how a safety
    // rule gets disabled.
    const honest = <String>[
      'Back to lifting, after birth',
      'Giza · at home · 20 minutes',
      'Six weeks after birth, on the floor',
      'Carried both kids up the stairs. 24 sessions, no weight ever discussed.',
      'Plank 20s → 75s',
      '12 weeks',
      'Pelvic floor and breathing before a single squat.',
      "Slowly, with your doctor's clearance.",
      'The last month you run the plan, I only watch.',
      'Twenty minutes, no charge, before you pay anything.',
      'I take women from six weeks after birth back to lifting, slowly.',
      'Numbers only, never a weight from the scale.',
      'A plan built for your days',
      'Chat, replies in about 2 hours',
      'Monthly coaching',
      'Rebuilt around the pelvic floor first.',
    ];

    for (final text in honest) {
      test('"$text"', () {
        final check = policy.check(text);
        expect(check.pass, isTrue, reason: 'flagged ${check.violations}');
      });
    }

    test('Arabic that is not a claim', () {
      expect(policy.check('تدريب في البيت').pass, isTrue);
      expect(policy.check('تمارين قاع الحوض أولا').pass, isTrue);
      // Ramadan is a month, and a coach writing about it is not promising one.
      expect(policy.check('تدريب في شهر رمضان').pass, isTrue);
    });

    test('empty and blank text is not a claim', () {
      expect(policy.check('').pass, isTrue);
      expect(policy.check('   ').pass, isTrue);
    });
  });

  group('the verdict is stable', () {
    test('violations come back in position order', () {
      final check = policy.check('Lose 10 kg. I cure PCOS. In 30 days.');
      final starts = check.violations.map((v) => v.start).toList();
      final sorted = [...starts]..sort();
      expect(starts, sorted);
    });

    test('the same text twice gives the same answer', () {
      const text = 'Lose 10 kg in 30 days and I cure PCOS';
      expect(
        policy.check(text).violations.map((v) => v.toString()),
        policy.check(text).violations.map((v) => v.toString()),
      );
    });

    test('a passing check carries no violations', () {
      expect(policy.check('Back to lifting').violations, isEmpty);
      expect(const ClaimCheck.passed().pass, isTrue);
    });
  });
}
