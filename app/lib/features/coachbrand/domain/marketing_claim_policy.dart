/// The claims a coach may not make on her own page, in Arabic and in English.
///
/// B09 shows a banner: *"No weight-loss promises and no timelines. We check
/// every ad against the same rules before it runs."* `P0-ADS-03` is the row that
/// turns the banner into a fact — *"the claim rules are enforced not just
/// displayed"* — so this class is the enforcement and the banner is its
/// description, not the other way round.
///
/// ## Three kinds, plus one that only applies to a figure
///
///   * **weight loss** — "lose 10 kg", "10 kg down", "weight loss", "تخسيس".
///     Rule 11 / C7: this product does not sell a number on a scale, and it
///     will not let a coach sell one either.
///   * **timeline** — "in 30 days", "within 6 weeks", "خلال شهر". A promise
///     about *when* is a promise about a body the coach has never met.
///   * **medical** — "cures", "reverses PCOS", "علاج". A coach is not a
///     clinician, and the product says so on the screens that matter.
///   * **ranking** — "#1 coach in Cairo", "الأفضل". Rule 11 again. Checked only
///     by [checkStat], because a `numbers` stat is the one place a ranking
///     would look like data.
///
/// ## Where it runs
///
/// G13 §5 specifies cover, ad, `numbers` and testimonial text. **The owner has
/// extended that coverage**: it runs over `about`, `method` and `faq` prose as
/// well. Those three are the longest free text on the page and the obvious
/// place to put the sentence that would not fit in the headline, so leaving
/// them out would have made the rule a formality. `BlockValidator` is where the
/// seven surfaces are wired; this file is only the pattern set.
///
/// ## What is deliberately NOT a claim
///
/// The patterns carry their own negative controls, because a policy that
/// flags honest copy gets switched off:
///
///   * *"Giza · at home · 20 minutes"* — a duration, not a timeline promise.
///     Minutes and hours are not in the unit set at all.
///   * *"Six weeks after birth, on the floor"* — the mockup's own ad headline.
///     A timeline needs a preposition **before** the number ("in six weeks"),
///     which is what makes it a promise rather than a description.
///   * *"Plank 20s → 75s · 12 weeks"* — a bare duration on a derived result.
///   * *"24 sessions, no weight ever discussed"* — contains "weight" and is the
///     opposite of a weight-loss claim.
///   * *"Slowly, with your doctor's clearance."* — deferring to a clinician is
///     not practising as one.
///   * *"Personal best"* — "best" about her own history is not a ranking.
///
/// Every one of those strings is a test.
library;

import 'package:meta/meta.dart';

/// What kind of promise a span is.
enum ClaimKind {
  /// A promise about a number on a scale.
  weightLoss,

  /// A promise about how long it will take.
  timeline,

  /// A promise only a clinician could make.
  medical,

  /// A claim to be first, best or most. Rule 11.
  ranking,
}

/// One offending span, with the offsets B09 needs to mark it.
@immutable
class ClaimViolation {
  const ClaimViolation({
    required this.kind,
    required this.start,
    required this.end,
    required this.span,
  });

  final ClaimKind kind;

  /// UTF-16 offsets into the text that was checked, so the editor can underline
  /// exactly the words that failed rather than the whole field.
  final int start;
  final int end;

  /// The matched text.
  final String span;

  @override
  String toString() => 'ClaimViolation(${kind.name}, "$span" @$start..$end)';
}

/// The verdict. `pass` is the only thing publish looks at; `violations` is what
/// the editor draws.
@immutable
class ClaimCheck {
  const ClaimCheck(this.violations);

  const ClaimCheck.passed() : violations = const <ClaimViolation>[];

  final List<ClaimViolation> violations;

  bool get pass => violations.isEmpty;

  bool has(ClaimKind kind) => violations.any((v) => v.kind == kind);

  /// The kinds present, for a single summary line.
  Set<ClaimKind> get kinds => {for (final v in violations) v.kind};

  @override
  String toString() => pass ? 'ClaimCheck.passed()' : 'ClaimCheck($violations)';
}

/// The pattern set, and the only place it is decided.
///
/// Stateless and `const`-constructible so the publish Function's Dart port, the
/// validator and the editor all use the same instance semantics. `version` is
/// carried into `ad.claimCheck.v` so a re-check after a pattern update is
/// detectable rather than assumed.
@immutable
class MarketingClaimPolicy {
  const MarketingClaimPolicy();

  /// Bumped whenever a pattern changes. Stored on the ad's `claimCheck`.
  static const int version = 1;

  /// Prose: cover strings, ad copy, testimonials, and — the owner's extension —
  /// `about` paragraphs, `method` steps and `faq` questions and answers.
  ClaimCheck check(String text) => _run(text, _proseRules);

  /// A `numbers` stat's value or label. Prose rules **plus** ranking.
  ///
  /// Separate because "the best" in a paragraph about her own training is
  /// ordinary English, while "Best in Cairo" as a headline figure is the
  /// leaderboard rule 11 forbids.
  ClaimCheck checkStat(String text) =>
      _run(text, [..._proseRules, ..._ranking]);

  ClaimCheck _run(String text, List<_Rule> rules) {
    if (text.trim().isEmpty) return const ClaimCheck.passed();

    final found = <ClaimViolation>[];
    for (final rule in rules) {
      for (final match in rule.pattern.allMatches(text)) {
        final span = match.group(0);
        if (span == null || span.isEmpty) continue;
        found.add(
          ClaimViolation(
            kind: rule.kind,
            start: match.start,
            end: match.end,
            span: span,
          ),
        );
      }
    }

    // Stable order: by position, then by kind, so two runs over the same text
    // produce the same list and a golden can be written against it.
    found.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.kind.index.compareTo(b.kind.index);
    });

    return ClaimCheck(List.unmodifiable(found));
  }
}

class _Rule {
  const _Rule(this.kind, this.pattern);
  final ClaimKind kind;
  final RegExp pattern;
}

// English number words, so "lose ten kilos" is caught alongside "lose 10 kilos".
const String _num =
    r'(?:\d+(?:[.,]\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|'
    r'eleven|twelve|twenty|thirty|forty|fifty)';

// Day / week / month only. Minutes and hours are session lengths, not promises.
const String _period = r'(?:day|days|week|weeks|month|months|year|years)';

const String _mass = r'(?:kg|kgs|kilo|kilos|kilogram|kilograms|lb|lbs|pounds)';

// ───────────────────────────────────────────────── the Arabic vocabularies
//
// Escaped, not written literally, because `i18n_guard_test.dart` forbids an
// Arabic character on a code line anywhere under `lib/`. The guard is right
// even here: a literal that bypasses the dictionary is the defect it exists to
// catch, and "this one is a matcher, not copy" is exactly the argument every
// exception starts with. `lib/features/admin/domain/seed_library.dart` solved
// the same problem the same way — \u escapes, with the readable form in a
// comment directly above — and `marketing_claim_policy_test.dart` asserts each
// constant decodes back to the pattern written here, so the comment cannot
// drift away from the code.
//
// No \b anywhere below. Dart's word boundary is defined on ASCII word
// characters, so it never matches between two Arabic letters; these are
// substring patterns on purpose.

// تخسيس|تنحيف|خسارة\s*(?:ال)?وزن|إنقاص\s*(?:ال)?وزن|انقاص\s*(?:ال)?وزن|
// نزول\s*(?:ال)?وزن|فقدان\s*(?:ال)?وزن|تخفيف\s*(?:ال)?وزن|حرق\s*(?:ال)?دهون|
// (?:خسّ?ي|اخسري|تخسري)\s*\d+\s*كيلو|\d+\s*كيلو\s*(?:أقل|اقل|تحت|في)
//
// "slimming", "thinning", "weight loss / reduction / drop", "fat burning",
// and the imperative "lose N kilos" a coach writes to a woman directly.
const String kArabicWeightLossPattern =
    '\u062A\u062E\u0633\u064A\u0633|\u062A\u0646\u062D\u064A\u0641|'
    '\u062E\u0633\u0627\u0631\u0629\\s*(?:\u0627\u0644)?\u0648\u0632'
    '\u0646|\u0625\u0646\u0642\u0627\u0635\\s*(?:\u0627\u0644)?\u0648'
    '\u0632\u0646|\u0627\u0646\u0642\u0627\u0635\\s*(?:\u0627\u0644)?'
    '\u0648\u0632\u0646|\u0646\u0632\u0648\u0644\\s*(?:\u0627\u0644)?'
    '\u0648\u0632\u0646|\u0641\u0642\u062F\u0627\u0646\\s*(?:\u0627'
    '\u0644)?\u0648\u0632\u0646|\u062A\u062E\u0641\u064A\u0641\\s*(?:'
    '\u0627\u0644)?\u0648\u0632\u0646|\u062D\u0631\u0642\\s*(?:\u0627'
    '\u0644)?\u062F\u0647\u0648\u0646|(?:\u062E\u0633\u0651?\u064A|'
    '\u0627\u062E\u0633\u0631\u064A|\u062A\u062E\u0633\u0631\u064A)\\s*'
    '\\d+\\s*\u0643\u064A\u0644\u0648|\\d+\\s*\u0643\u064A\u0644\u0648'
    '\\s*(?:\u0623\u0642\u0644|\u0627\u0642\u0644|\u062A\u062D\u062A|'
    '\u0641\u064A)';

// (?:في|خلال|بعد|خلال\s*مدة)\s*(?:\d+|شهرين|أسبوعين|اسبوعين|يومين)\s*
// (?:يوم|أيام|يوما|يومًا|أسبوع|أسابيع|اسبوع|اسابيع|شهر|شهور|أشهر|اشهر)|
// (?:في|خلال)\s*(?:شهرين|أسبوعين|اسبوعين)|
// (?:في|خلال)\s*(?:شهر|أسبوع|اسبوع)\s*(?:واحد|فقط)
//
// The singular needs "واحد" or "فقط" after it — "one month", "a month only" —
// because "في شهر رمضان" means "in the month of Ramadan" and is a coach saying
// when she trains, not what she promises. Blocking that would flag honest
// Egyptian copy every spring.
const String kArabicTimelinePattern =
    '(?:\u0641\u064A|\u062E\u0644\u0627\u0644|\u0628\u0639\u062F|\u062E'
    '\u0644\u0627\u0644\\s*\u0645\u062F\u0629)\\s*(?:\\d+|\u0634\u0647'
    '\u0631\u064A\u0646|\u0623\u0633\u0628\u0648\u0639\u064A\u0646|'
    '\u0627\u0633\u0628\u0648\u0639\u064A\u0646|\u064A\u0648\u0645'
    '\u064A\u0646)\\s*(?:\u064A\u0648\u0645|\u0623\u064A\u0627\u0645|'
    '\u064A\u0648\u0645\u0627|\u064A\u0648\u0645\u064B\u0627|\u0623'
    '\u0633\u0628\u0648\u0639|\u0623\u0633\u0627\u0628\u064A\u0639|'
    '\u0627\u0633\u0628\u0648\u0639|\u0627\u0633\u0627\u0628\u064A'
    '\u0639|\u0634\u0647\u0631|\u0634\u0647\u0648\u0631|\u0623\u0634'
    '\u0647\u0631|\u0627\u0634\u0647\u0631)|(?:\u0641\u064A|\u062E'
    '\u0644\u0627\u0644)\\s*(?:\u0634\u0647\u0631\u064A\u0646|\u0623'
    '\u0633\u0628\u0648\u0639\u064A\u0646|\u0627\u0633\u0628\u0648'
    '\u0639\u064A\u0646)|(?:\u0641\u064A|\u062E\u0644\u0627\u0644)\\s*('
    '?:\u0634\u0647\u0631|\u0623\u0633\u0628\u0648\u0639|\u0627\u0633'
    '\u0628\u0648\u0639)\\s*(?:\u0648\u0627\u062D\u062F|\u0641\u0642'
    '\u0637)';

// (?:علاج|أعالج|اعالج|يعالج|نعالج)\s*(?:ال)?
// (?:تكيس|سكري|ضغط|ألم|الم|إصابة|اصابة|مرض|حالة|عقم|اكتئاب|قلق)|
// شفاء\s*(?:تام|كامل|مضمون)|(?:تشخيص|أشخص|اشخص|يشخص)|
// بدون\s*(?:طبيب|دواء|أدوية|ادوية|جراحة)|
// (?:بديل|بدل)\s*(?:عن\s*)?(?:ال)?(?:طبيب|دواء|علاج\s*طبيعي)
//
// "I treat X", where X is a condition — PCOS, diabetes, blood pressure, pain,
// injury, infertility. Plus "complete cure", "I diagnose", "no doctor needed",
// and "a substitute for your doctor / medicine / physiotherapy". The verb
// needs its object, so "علاج طبيعي" as a profession is not caught on its own.
const String kArabicMedicalPattern =
    '(?:\u0639\u0644\u0627\u062C|\u0623\u0639\u0627\u0644\u062C|\u0627'
    '\u0639\u0627\u0644\u062C|\u064A\u0639\u0627\u0644\u062C|\u0646'
    '\u0639\u0627\u0644\u062C)\\s*(?:\u0627\u0644)?(?:\u062A\u0643'
    '\u064A\u0633|\u0633\u0643\u0631\u064A|\u0636\u063A\u0637|\u0623'
    '\u0644\u0645|\u0627\u0644\u0645|\u0625\u0635\u0627\u0628\u0629|'
    '\u0627\u0635\u0627\u0628\u0629|\u0645\u0631\u0636|\u062D\u0627'
    '\u0644\u0629|\u0639\u0642\u0645|\u0627\u0643\u062A\u0626\u0627'
    '\u0628|\u0642\u0644\u0642)|\u0634\u0641\u0627\u0621\\s*(?:\u062A'
    '\u0627\u0645|\u0643\u0627\u0645\u0644|\u0645\u0636\u0645\u0648'
    '\u0646)|(?:\u062A\u0634\u062E\u064A\u0635|\u0623\u0634\u062E\u0635'
    '|\u0627\u0634\u062E\u0635|\u064A\u0634\u062E\u0635)|\u0628\u062F'
    '\u0648\u0646\\s*(?:\u0637\u0628\u064A\u0628|\u062F\u0648\u0627'
    '\u0621|\u0623\u062F\u0648\u064A\u0629|\u0627\u062F\u0648\u064A'
    '\u0629|\u062C\u0631\u0627\u062D\u0629)|(?:\u0628\u062F\u064A\u0644'
    '|\u0628\u062F\u0644)\\s*(?:\u0639\u0646\\s*)?(?:\u0627\u0644)?(?:'
    '\u0637\u0628\u064A\u0628|\u062F\u0648\u0627\u0621|\u0639\u0644'
    '\u0627\u062C\\s*\u0637\u0628\u064A\u0639\u064A)';

// الأفضل|الافضل|الأولى|الاولى|رقم\s*(?:1|واحد)|
// الأكثر\s*(?:طلبا|طلبًا|متابعة|حجزا|حجزًا)|الاكثر\s*(?:طلبا|متابعة)
//
// "the best", "the first", "number one", "the most booked / most followed" —
// with and without the hamza, because both spellings are typed. Rule 11:
// nothing in this product ranks women, and a coach's own figure is the first
// place a ranking would look like data.
const String kArabicRankingPattern =
    '\u0627\u0644\u0623\u0641\u0636\u0644|\u0627\u0644\u0627\u0641'
    '\u0636\u0644|\u0627\u0644\u0623\u0648\u0644\u0649|\u0627\u0644'
    '\u0627\u0648\u0644\u0649|\u0631\u0642\u0645\\s*(?:1|\u0648\u0627'
    '\u062D\u062F)|\u0627\u0644\u0623\u0643\u062B\u0631\\s*(?:\u0637'
    '\u0644\u0628\u0627|\u0637\u0644\u0628\u064B\u0627|\u0645\u062A'
    '\u0627\u0628\u0639\u0629|\u062D\u062C\u0632\u0627|\u062D\u062C'
    '\u0632\u064B\u0627)|\u0627\u0644\u0627\u0643\u062B\u0631\\s*(?:'
    '\u0637\u0644\u0628\u0627|\u0645\u062A\u0627\u0628\u0639\u0629)';

final List<_Rule> _proseRules = <_Rule>[
  // ─────────────────────────── weight loss, English
  _Rule(
    ClaimKind.weightLoss,
    RegExp(
      '\\b(?:lose|losing|lost|drop|dropping|dropped|shed|shedding|burn|'
      'burning|melt|melting)\\s+(?:up\\s+to\\s+)?$_num\\s*$_mass\\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    ClaimKind.weightLoss,
    RegExp(
      '\\b$_num\\s*$_mass\\s+(?:down|off|gone|lighter|lost)\\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    ClaimKind.weightLoss,
    RegExp(
      r'\b(?:weight[\s-]?loss|fat[\s-]?loss|lose\s+(?:the\s+)?weight|'
      r'lose\s+(?:the\s+)?(?:baby\s+)?(?:belly|fat)|burn\s+(?:the\s+)?fat|'
      r'slim(?:ming)?\s+down|get\s+(?:skinny|lean\s+fast)|'
      r'drop\s+(?:a|\d+)\s+(?:dress\s+)?sizes?)\b',
      caseSensitive: false,
    ),
  ),
  // ─────────────────────────── weight loss, Arabic (MSA + common Egyptian)
  _Rule(ClaimKind.weightLoss, RegExp(kArabicWeightLossPattern, unicode: true)),
  // ─────────────────────────── timeline, English
  // The preposition comes FIRST. "in six weeks" is a promise; "six weeks after
  // birth" is a description of where a woman is.
  _Rule(
    ClaimKind.timeline,
    RegExp(
      '\\b(?:in|within|after|inside|under|just|only)\\s+$_num\\s*$_period\\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    ClaimKind.timeline,
    RegExp(
      '\\b$_num[\\s-]?$_period\\s+'
      '(?:challenge|transformation|makeover|shred|fix|plan\\s+to\\s+lose)\\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    ClaimKind.timeline,
    RegExp(
      '\\b(?:results?|change|difference)\\s+(?:in|within|after)\\s+'
      '$_num\\s*$_period\\b',
      caseSensitive: false,
    ),
  ),
  // ─────────────────────────── timeline, Arabic
  _Rule(ClaimKind.timeline, RegExp(kArabicTimelinePattern, unicode: true)),
  // ─────────────────────────── medical, English
  // Each verb needs an object, so "treat yourself" and "healing takes time"
  // stay ordinary language.
  _Rule(
    ClaimKind.medical,
    RegExp(
      r'\b(?:cure|cures|cured|curing|reverse|reverses|reversing|heal|heals|'
      r'healing|treat|treats|treating|diagnose|diagnoses|diagnosing)\s+'
      r'(?:your|her|my|the)?\s*(?:pcos|thyroid|diabetes|hypertension|'
      r'prolapse|diastasis|incontinence|endometriosis|infertility|depression|'
      r'anxiety|pain|injury|condition|illness|disease)\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    ClaimKind.medical,
    RegExp(
      r'\b(?:medically\s+(?:proven|guaranteed)|'
      r'no\s+(?:doctor|medication|medicine|surgery)\s+needed|'
      r'(?:replaces?|instead\s+of)\s+(?:your\s+)?(?:doctor|physiotherapist|'
      r'medication)|clinically\s+proven|prescribe\s+(?:you\s+)?medication)\b',
      caseSensitive: false,
    ),
  ),
  // ─────────────────────────── medical, Arabic
  _Rule(ClaimKind.medical, RegExp(kArabicMedicalPattern, unicode: true)),
];

final List<_Rule> _ranking = <_Rule>[
  _Rule(
    ClaimKind.ranking,
    RegExp(
      r'(?:#\s*1|\bno\.?\s*1\b|\bnumber\s+one\b|\btop[\s-]?(?:rated|coach|'
      r'trainer|in)\b|\bbest\s+(?:coach|trainer|in|on)\b|\bmost\s+(?:popular|'
      r'booked|followed|picked)\b|\branked\b|\b(?:first|1st)\s+place\b)',
      caseSensitive: false,
    ),
  ),
  _Rule(ClaimKind.ranking, RegExp(kArabicRankingPattern, unicode: true)),
];
