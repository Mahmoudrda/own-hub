/// The Beginner / Intermediate / Advanced tabs on R01 and R02.
///
/// One tap switches the tier the page shows, and the Start button then starts
/// that tier's session: she can begin any of them, whatever her own level is.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart' show countLabel;
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/hand/hand_swap.dart';
import '../../../ui/hand/draw_on.dart' show handMotionOff;
import '../../onboarding/domain/intake.dart';
import '../domain/tier_facts.dart';
import '../domain/viewed_tier.dart';

class TierTabs extends StatelessWidget {
  const TierTabs({
    super.key,
    required this.selected,
    this.onChanged,
    this.facts,
  });

  final TrainingLevel selected;

  /// What the selected tier's session holds, shown under the tabs. Null draws
  /// the tabs alone.
  final TierFacts? facts;

  /// Defaults to [ViewedTier.show].
  final ValueChanged<TrainingLevel>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tabs = AppSegmented(
      items: [l10n.beginner, l10n.intermediate, l10n.advanced],
      selectedIndex: TrainingLevel.values.indexOf(selected),
      onChanged: (i) => (onChanged ?? ViewedTier.show)(TrainingLevel.values[i]),
    );
    final facts = this.facts;
    if (facts == null) return tabs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabs,
        const SizedBox(height: 8),
        TierFactsBlock(facts: facts),
      ],
    );
  }
}

/// "8 moves · 4 × 10 · 70 s rest · about 40 min", and under it what differs from
/// the level she set. The block eases from one tier's facts to the next, and
/// swaps at once under Reduce Motion.
class TierFactsBlock extends StatelessWidget {
  const TierFactsBlock({super.key, required this.facts});

  final TierFacts facts;

  /// The facts as one line.
  static String line(AppL10n l10n, TierFacts facts) {
    final parts = [
      l10n.countPluralOne1MoveOtherCount(facts.moves),
      if (facts.repsLabel.isNotEmpty)
        l10n.setsReps(countLabel(facts.setsPerMove), facts.repsLabel),
      l10n.secondsSRest(countLabel(facts.restSeconds)),
      l10n.minutesPluralOneAbout1MinOther(facts.estimatedMinutes),
    ];
    return parts.join(' · ');
  }

  /// What the viewed tier does differently from her own level, or null when
  /// nothing differs or no comparison was asked for.
  static String? deltaLabel(AppL10n l10n, TierDelta? delta) {
    if (delta == null || delta.isEmpty) return null;
    final parts = [
      if (delta.sets > 0) l10n.countPluralOne1MoreSetOther(delta.sets),
      if (delta.sets < 0) l10n.countPluralOne1SetLessOther(-delta.sets),
      if (delta.restSeconds > 0)
        l10n.secondsSMoreRest(countLabel(delta.restSeconds)),
      if (delta.restSeconds < 0)
        l10n.secondsSLessRest(countLabel(-delta.restSeconds)),
      if (delta.moves > 0) l10n.countPluralOne1MoreMoveOther(delta.moves),
      if (delta.moves < 0) l10n.countPluralOne1MoveLessOther(-delta.moves),
      if (delta.minutes > 0)
        l10n.minutesPluralOne1MinLongerOther(delta.minutes),
      if (delta.minutes < 0)
        l10n.minutesPluralOne1MinShorterOther(-delta.minutes),
    ];
    return l10n.comparedWithYourLevelChanges(parts.join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final delta = facts.isOwnLevel
        ? l10n.thisIsYourLevel
        : deltaLabel(l10n, facts.versusOwn);
    final style = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final text = line(l10n, facts);
    final block = Column(
      key: ValueKey(facts),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, key: const ValueKey('tier-facts-line'), style: style),
        if (delta != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              delta,
              key: const ValueKey('tier-facts-delta'),
              style: style.copyWith(color: AppColors.primaryDim),
            ),
          ),
      ],
    );
    // Reduce Motion: no fade and no size ease, the facts are simply replaced.
    return handMotionOff(context) ? block : HandSwap(child: block);
  }
}
