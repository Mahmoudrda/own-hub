/// **M06 — the group goal.**
///
/// Matches `screens-community.mjs` → `M06`. The design note is the rule:
///
/// > *"Challenges are shared totals, not leaderboards: everyone who does her
/// > part finishes, so there is no last place and no reason to compare a 3 kg
/// > dumbbell with a barbell."*
///
/// So this screen draws two things — what the group has done together, and what
/// **her own part** is — and nothing that puts one woman above another. There is
/// no ordering of members on this screen and no query that could produce one.
///
/// ## Nothing extra to log
///
/// `yourSessionsCountHereAsYouSave` — *"Your sessions count here as you save
/// them … Nobody sees your weights, only that a session happened."* The credit
/// comes from session completion, and the challenge document stores that a
/// session happened, never a weight.
///
/// ## Missing copy
///
/// The headline the prototype uses bakes the mockup's figures into the sentence
/// ("200 sessions in two weeks"), and so does its days-left line. Every
/// number-bearing community string in the dictionary is of that shape, and
/// `test/baked_in_samples_test.dart` exists precisely to stop those reaching a
/// woman as though they were hers. So the figures here are rendered from her
/// real challenge through `countLabel`, and the two sentences that have no
/// parameterised form are omitted and reported.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import 'groups_view_model.dart';

class GroupGoalView extends StatelessWidget {
  const GroupGoalView({
    super.key,
    required this.model,
    required this.groupName,
    this.onBack,
  });

  final GroupGoalModel model;
  final String groupName;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(onBack: onBack),
      body: AppScaffold(
        children: [
          Text(
            groupName,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),

          // No challenge is running in this room. Zero bars against a zero
          // target would state a goal nobody set — the prototype's "200
          // sessions in two weeks" is its figure, not hers — so the page says
          // what is true and stops.
          if (!model.hasChallenge)
            AppCard(
              variant: AppCardVariant.filled,
              children: [Text(l10n.nothingIsCountedYet, style: AppText.titleM)],
            ),

          // The shared total. Her group's real figures, never the mockup's.
          if (model.hasChallenge)
            AppCard(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The one mark on the page: the room's shared total,
                          // circled the way she would ring a figure worth
                          // keeping. A loop, never a medal — it ranks no one.
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 6,
                              top: 4,
                              bottom: 4,
                            ),
                            child: HandCircled(
                              level: HandLevel.expressive,
                              width: HandStroke.pen,
                              color: AppColors.primaryDim,
                              drawOn: true,
                              child: Text(
                                model.totalLabel,
                                style: AppText.display.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            l10n.togetherSoFar,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      model.targetLabel,
                      style: AppText.titleM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppProgressBar(percent: model.fraction * 100, height: 12),
              ],
            ),

          // Her own part — finishing it does not depend on anyone else.
          if (model.hasChallenge)
            AppCard(
              variant: AppCardVariant.sage,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.yourPart, style: AppText.titleM)),
                    Text(
                      '${model.myDoneLabel} / ${model.perWomanLabel}',
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppWeekSegments(total: model.perWoman, filled: model.myDone),
                const SizedBox(height: 10),
                Text(
                  l10n.oneMoreAndYouHaveFinishedWhatever,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),

          if (model.hasChallenge)
            AppSageNote(l10n.yourSessionsCountHereAsYouSave),
        ],
      ),
    );
  }
}
