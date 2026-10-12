/// Pieces the G14 screens share, built once so they cannot drift apart.
///
/// Two of them carry a rule rather than a layout:
///
///  * [ConstraintPanel] is the **read-only** rendering of a woman's
///    constraints. It has no controller, no `onChanged` and no field — r13's
///    "no coach screen has a text input for `avoid` or allergies" is a shape
///    here, not a review note. W02 and W06 both use this one widget, so the
///    two cannot end up with different answers about the same woman.
///  * [SuppressedMovesNote] states the ids a screen removed. A suppressed move
///    is **absent** from the session above it — not greyed, not warned about —
///    and this note is the screen telling the truth about what it did, which is
///    why it is a plain card and never an error one.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/safety/client_constraints.dart';
import '../../../domain/safety/contraindication_tag.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import 'coachplan_labels.dart';

/// Widget keys the tests address, so an assertion names a control rather than
/// a pixel or a piece of copy that is still being written.
abstract final class CoachPlanKeys {
  static const Key clientsEmpty = Key('W01.empty');
  static const Key clientsList = Key('W01.list');

  static const Key avoidPanel = Key('constraints.avoid');
  static const Key allergyPanel = Key('constraints.allergies');

  static const Key suppressedNote = Key('suppressed.note');

  /// W09's two controls. Separate keys, because they are separate acts.
  static const Key saveFeedback = Key('W09.saveFeedback');
  static const Key publishChanges = Key('W09.publishChanges');

  /// W08's primary button. One key for both labels: it is one control whose
  /// label varies and whose enablement does not.
  static const Key publish = Key('W08.publish');

  /// W08's *Waiting to send* badge, drawn only for a queued intent. Keyed so a
  /// test names the badge rather than the sentence inside it.
  static const Key queued = Key('W08.queued');

  /// K22's referral card. Named so a test can assert what it is *not*.
  static const Key referralCard = Key('K22.referral');

  static Key moveRow(String exerciseId) => Key('move:$exerciseId');
  static Key dayRow(String dayKey) => Key('day:$dayKey');
  static Key slotRow(String slot) => Key('slot:$slot');
}

/// The coach's bottom bar.
///
/// [coachTabs] is passed explicitly rather than read from the role scope: these
/// screens are only ever a coach's, and a widget test should not have to install
/// an identity to render one.
class CoachPlanNavBar extends StatelessWidget {
  const CoachPlanNavBar({super.key, required this.activeScreenId, this.onTab});

  final String activeScreenId;
  final ValueChanged<String>? onTab;

  @override
  Widget build(BuildContext context) => AppNavBar(
    activeScreenId: activeScreenId,
    destinations: coachTabs,
    onSelect: onTab,
  );
}

/// A section heading.
class SectionHead extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'SectionHead';

  const SectionHead(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: AppText.titleM);
}

/// A label and its value on one line — the prototype's `kv()`.
class LabelledValue extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'LabelledValue';

  const LabelledValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    // A split row, not a Row: at the largest text size a long label beside
    // its value is wider than the phone, and this puts the value on its own
    // line instead of overflowing.
    child: AppSplitRow(
      crossAxisAlignment: WrapCrossAlignment.start,
      start: Text(
        label,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
      end: Text(value, style: AppText.bodyM, textAlign: TextAlign.end),
    ),
  );
}

/// The prototype's `daySlot()` — a row of the planner.
///
/// [isGap] draws the red treatment W03 and W06 use for a day or slot with
/// nothing in it. A gap is a **hole in the plan**, which is a different thing
/// from a suppressed move: the gap is shown because nobody has filled it, and
/// the suppressed move is absent because her assessment said so.
///
/// Drawn as a diary line rather than a box: a filled day sits on the page with
/// a pencil rule under it, so a month reads as a ruled planner. A gap is the
/// one row that is boxed — a dashed red frame, the mark for a space still
/// waiting to be filled — so it stands out of the ruled column without a word.
class PlannerRow extends StatelessWidget {
  const PlannerRow({
    super.key,
    required this.leading,
    required this.value,
    this.isGap = false,
    this.onTap,
  });

  /// The left column — a weekday and a date, a slot name, a move's order.
  final Widget leading;

  final String value;
  final bool isGap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final seed = handSeed(['planner-row', '$key', value]);
    final row = Row(
      children: [
        SizedBox(width: 84, child: leading),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: AppText.bodyM.copyWith(
              color: isGap ? AppColors.error : AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          isGap ? Icons.add : Icons.edit,
          size: 18,
          color: isGap ? AppColors.error : AppColors.onSurfaceVariant,
        ),
      ],
    );

    if (isGap) {
      return HandSurface(
        seed: seed,
        fill: AppColors.errorContainer,
        frame: AppColors.error.withValues(alpha: 0.7),
        dashed: true,
        radius: 5,
        looseCorner: 14,
        onTap: onTap,
        pressable: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: row,
        ),
      );
    }

    return HandPressable(
      onTap: onTap,
      builder: (context, pressed) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: row,
            ),
          ),
          HandRule(seed: seed, height: 4),
        ],
      ),
    );
  }
}

/// A weekday over a day-of-month number.
///
/// Two text runs rather than one composed sentence: a date is a value, and
/// gluing a translated weekday to a numeral produces a string that mirrors
/// badly in Arabic and belongs to neither dictionary.
class DayStamp extends StatelessWidget {
  const DayStamp({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekdayLabel(l10n, date),
          style: AppText.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          countLabel(date.day),
          style: AppText.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// A short plain label for the left column of a [PlannerRow].
class RowLabel extends StatelessWidget {
  const RowLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.label.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.onSurfaceVariant,
    ),
  );
}

/// Her constraints, rendered and **never edited**.
///
/// There is no controller, no `onChanged` and no field on this widget, and
/// there is no parameter through which a caller could add one. The assessment
/// is the only source; W02 and W06 read it.
///
/// Unresolved is not empty. When `constraints.isResolved` is false the panel
/// shows what her life stage derives — which is known even on a cold start —
/// and states nothing at all about the rest, because nobody knows it. The line
/// the plan asks for there ("her constraints haven't loaded") has no dictionary
/// entry yet, so it is withheld rather than guessed at.
class ConstraintPanel extends StatelessWidget {
  const ConstraintPanel({super.key, required this.constraints});

  final ClientConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final avoid = <ContraindicationTag>[
      for (final tag in ContraindicationTag.values)
        if (constraints.blockedTags.contains(tag)) tag,
    ];
    final allergies = constraints.allergies;
    final dietary = constraints.dietary;

    return AppCard(
      variant: AppCardVariant.amber,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      gap: 8,
      children: [
        Column(
          key: CoachPlanKeys.avoidPanel,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.whatToAvoid, style: AppText.titleM),
            if (avoid.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in avoid)
                    AppPill(
                      avoidTagLabel(l10n, tag),
                      background: AppColors.surfaceLowest,
                      foreground: AppColors.amber,
                    ),
                ],
              ),
            ],
          ],
        ),
        Column(
          key: CoachPlanKeys.allergyPanel,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.anythingYouCannotEat, style: AppText.titleM),
            if (allergies != null && allergies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final allergen in allergies)
                    AppPill(
                      allergen,
                      background: AppColors.surfaceLowest,
                      foreground: AppColors.error,
                    ),
                ],
              ),
            ],
            if (dietary != null && dietary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preference in dietary)
                    AppPill(
                      preference,
                      background: AppColors.surfaceLowest,
                      foreground: AppColors.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// What her assessment removed on the way in, named.
///
/// `SplitApplication.suppressedExerciseIds`, said out loud. The moves
/// themselves are **gone** from the session above — this is not a list of
/// things shown greyed out, and the card is deliberately the plain filled
/// variant rather than the error one, because nothing went wrong.
class SuppressedMovesNote extends StatelessWidget {
  const SuppressedMovesNote({super.key, required this.exerciseIds});

  final Set<String> exerciseIds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ids = exerciseIds.toList()..sort();

    return AppCard(
      key: CoachPlanKeys.suppressedNote,
      variant: AppCardVariant.filled,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 8,
      children: [
        Text(
          l10n.herAvoidListWasAppliedFirstDeep,
          style: AppText.bodyM.copyWith(color: AppColors.onSurface),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in ids)
              AppPill(
                id,
                background: AppColors.surfaceLowest,
                foreground: AppColors.onSurfaceVariant,
              ),
          ],
        ),
      ],
    );
  }
}
