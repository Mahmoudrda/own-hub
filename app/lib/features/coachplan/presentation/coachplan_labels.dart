/// The words G14's screens put on domain values.
///
/// Every label here comes from the dictionary. Where the dictionary has no
/// figure-free string for a value, this file returns **null** and the caller
/// falls back to the value's own stored token — see [avoidTagLabel] — rather
/// than inventing copy or substituting a string that says something else.
///
/// ## Why a token is an acceptable fallback, and an invented sentence is not
///
/// `number_label.dart` and `day_key.dart` already draw this line: a count and a
/// day id are **values**, not copy, so they are rendered as themselves. A
/// `ContraindicationTag`'s `wireName` is the same kind of thing — it is what is
/// stored, it is identical in both languages, and it is what the assessment,
/// the exercise pack and the ruleset all speak.
///
/// The alternative was to omit an unlabelled tag. For a *selector* that would
/// be merely limited; for the **read-only display of a woman's recorded
/// constraints** it would hide a restriction somebody recorded about her body,
/// which is the one failure r13 exists to prevent. One rule, both places, so
/// the two cannot disagree: name it when the dictionary can, show the stored
/// token when it cannot, never hide it and never guess.
///
/// Each null branch below is a string the dictionary owes this feature. They
/// are listed in the handover rather than filled in with something close.
library;

import '../../../domain/format/number_label.dart';
import '../../../domain/safety/contraindication_tag.dart';
import '../../../domain/safety/life_stage_safety_policy.dart';
import '../../../domain/safety/screening_item.dart';
import '../../../l10n/app_l10n.dart';
// The product's one weight formatter. A second copy is how "14.0 kg" comes
// back, which is the defect that file was written to end.
import '../../train/domain/weight_label.dart';
import '../domain/assessment/assessment_record.dart';
import '../domain/plan/plan_draft.dart';
import '../domain/prescription.dart';

/// The dictionary's name for [tag], or null when it has none.
///
/// Four of the ten restrictions are named today. The other six have no
/// figure-free string, so they are shown as their stored token by
/// [avoidTagLabel].
String? avoidTagName(AppL10n l10n, ContraindicationTag tag) => switch (tag) {
  ContraindicationTag.highImpact => l10n.highImpact,
  ContraindicationTag.deepKneeFlexion => l10n.deepKneeBends,
  ContraindicationTag.loadedTwisting => l10n.loadedTwisting,
  ContraindicationTag.pronePosition => l10n.proneOnBelly,
  // jumping, pelvic_floor_load, breath_hold_valsalva, supine_load,
  // overhead_load, wrist_load: no dictionary entry. The token is shown.
  _ => null,
};

/// What a screen writes for [tag]. Never empty, never a guess.
String avoidTagLabel(AppL10n l10n, ContraindicationTag tag) =>
    avoidTagName(l10n, tag) ?? tag.wireName;

/// The dictionary's name for a life stage, or null.
///
/// `p0_6w` and `p6w_1y` have only figure-bearing strings in the dictionary
/// ("0 to 6 weeks", "6 weeks to 1 year"). Rendering one would state a figure with
/// no placeholder, so the stored token is shown instead and the gap is
/// reported. These two matter more than the rest: the first six weeks are the
/// only stage with a clearance gate.
String? lifeStageName(AppL10n l10n, LifeStage stage) => switch (stage) {
  LifeStage.pregnant => l10n.pregnant,
  LifeStage.over1y => l10n.overAYear,
  LifeStage.none => l10n.none,
  LifeStage.postpartum0to6w || LifeStage.postpartum6wTo1y => null,
};

String lifeStageLabel(AppL10n l10n, LifeStage stage) =>
    lifeStageName(l10n, stage) ?? stage.wireName;

/// K21's birth row. All three are named.
String birthTypeLabel(AppL10n l10n, BirthType type) => switch (type) {
  BirthType.vaginal => l10n.vaginal,
  BirthType.caesarean => l10n.caesarean,
  BirthType.undisclosed => l10n.preferNotToSay,
};

/// K23's three outcomes.
///
/// `unset` has no label because it is not an answer — an unanswered row shows
/// nothing selected. `cleared` has none either: K22 renders a cleared referral
/// by the reason the coach wrote, which is hers and needs no translation.
String? screeningOutcomeName(AppL10n l10n, ScreeningOutcome outcome) =>
    switch (outcome) {
      ScreeningOutcome.pass => l10n.pass,
      ScreeningOutcome.modify => l10n.modify,
      ScreeningOutcome.refer => l10n.refer,
      ScreeningOutcome.unset || ScreeningOutcome.cleared => null,
    };

/// The three a coach may choose between, in K23's order.
const List<ScreeningOutcome> kOfferedOutcomes = <ScreeningOutcome>[
  ScreeningOutcome.pass,
  ScreeningOutcome.modify,
  ScreeningOutcome.refer,
];

/// The dictionary's name for a screening item id, or the id itself.
///
/// The domain carries an id and no label — G14 §1.4's `screening[i].id` — so
/// the three seeded items are named here and anything else shows its id.
String screeningItemLabel(AppL10n l10n, String id) => switch (id) {
  'sit_to_stand' => l10n.sitToStand,
  'single_leg_balance' => l10n.singleLegBalance,
  'pelvic_floor' || 'pelvic_floor_symptoms' => l10n.pelvicFloorSymptoms,
  _ => id,
};

/// The one-line description under a screening item, when there is one.
String? screeningItemHint(AppL10n l10n, String id) => switch (id) {
  'sit_to_stand' => l10n.fiveTimesNoHands,
  'single_leg_balance' => l10n.tenSecondsEachSide,
  'pelvic_floor' || 'pelvic_floor_symptoms' => l10n.anyLeakingHeavinessOrDoming,
  _ => null,
};

/// The four slots, fixed forever.
String mealSlotLabel(AppL10n l10n, PlanMealSlot slot) => switch (slot) {
  PlanMealSlot.breakfast => l10n.breakfast,
  PlanMealSlot.lunch => l10n.lunch,
  PlanMealSlot.dinner => l10n.dinner,
  PlanMealSlot.snack => l10n.snack,
};

/// What a move is prescribed with, or null when there is nothing to write.
///
/// `bodyweight` carries **no number at all** — that is the whole reason the
/// load is a kind and not a nullable double — and the dictionary has no word
/// for the kind itself, so it renders as nothing rather than as a zero.
/// `seconds` has a figure and no unit string, so it too is withheld: "45" beside
/// "3 × 12" would read as a count of something.
String? prescribedLoadLabel(AppL10n l10n, PrescribedLoad load) {
  final value = load.value;
  if (load.kind != PrescribedLoadKind.kg || value == null) return null;
  return '${weightLabel(value)} ${l10n.kg}';
}

/// One prescribed move, as a coach reads it back.
///
/// Composed from values only — an exercise id, two counts and a weight — so
/// there is no sentence here for a dictionary to own. Nothing in it is a
/// result: `PrescribedMove` has no field that could hold one.
String moveSummary(AppL10n l10n, PrescribedMove move) {
  final parts = <String>[move.exerciseId];
  final reps = move.reps;
  if (reps != null) {
    parts.add('${countLabel(move.sets)} × ${countLabel(reps)}');
  }
  final load = prescribedLoadLabel(l10n, move.load);
  if (load != null) parts.add(load);
  return parts.join(' · ');
}

/// One measured thing — "45 s", "78 cm".
///
/// The unit travels with the measure, so nothing here has to know what was
/// measured. It can never be a weight of any kind: `AssessmentRecord` refuses
/// a baseline key that names one, which is what stops a baseline being ranked
/// by one.
String baselineLabel(BaselineMeasure measure) =>
    '${weightLabel(measure.value)} ${measure.unit}';

/// A weekday, from her date rather than from a hardcoded Tuesday.
///
/// Saturday and Sunday have only abbreviations in the dictionary, so those two
/// render short — the same limitation `coach_today_view.dart` flags rather than
/// papering over with an invented string.
String weekdayLabel(AppL10n l10n, DateTime date) => switch (date.weekday) {
  DateTime.monday => l10n.monday,
  DateTime.tuesday => l10n.tuesday,
  DateTime.wednesday => l10n.wednesday,
  DateTime.thursday => l10n.thursday,
  DateTime.friday => l10n.friday,
  DateTime.saturday => l10n.sat,
  _ => l10n.sun,
};

/// `yyyy-MM-dd` back to a date. Null for anything that is not one.
///
/// The draft keys its days by that string, so every screen that wants a
/// weekday out of one parses it here instead of five times.
DateTime? dateFromDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}
