/// `K25` — her first week.
///
/// Matches `6-v2/src/screens-firstweek.mjs` → `K25`.
///
/// # Four steps, all of them real work
///
/// The coach arc is the client arc's shape with a different payload: every step
/// produces something a client will see, so finishing it leaves her with a
/// published page, a saved split, an assessment and an accepted client — rather
/// than a completed tutorial.
///
/// # Nothing expires, and nothing can fail
///
/// [CoachStepState] has three values — done, now, waiting — and **none of them
/// means failed**, so a failure state is not constructible here rather than
/// merely unused. There is no timer and no deadline. §2 rule 3 and the
/// health-app evidence the design cites: visible failure indicators erode the
/// motivation they were built to create.
///
/// # No client sees her progress through it
///
/// `firstWeek` lives on `coaches/{c}/private/desk`, never on the public root.
/// G12 §1.3 is explicit that this is a **schema requirement rather than a UI
/// preference**, and the note at the foot of the screen says so to her.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_desk.dart';
import 'coach_setup_scaffold.dart';

/// One step, with the screen it leads to.
class _Step {
  const _Step(this.step, this.title, this.subtitle, this.screenId);

  final CoachFirstWeekStep step;
  final String title;
  final String subtitle;
  final String screenId;
}

class CoachFirstWeekView extends StatelessWidget {
  const CoachFirstWeekView({
    super.key,
    required this.firstWeek,
    this.onClose,
    this.onOpenStep,
    this.onSetUpAssessment,
    this.onBackToToday,
  });

  final CoachFirstWeek firstWeek;
  final VoidCallback? onClose;

  /// Given the screen id a step leads to.
  final ValueChanged<String>? onOpenStep;

  final VoidCallback? onSetUpAssessment;
  final VoidCallback? onBackToToday;

  List<_Step> _steps(AppL10n l10n) => [
    // The mockup's subtitles for the first two steps state one coach's
    // figures — "Live for 1,204 women a month", "Upper / lower — on 3
    // clients". Those are samples about somebody else, so the rows carry the
    // step and no invented detail.
    _Step(CoachFirstWeekStep.publishPage, l10n.publishYourPage, '', 'B01'),
    _Step(CoachFirstWeekStep.saveSplit, l10n.saveOneSplit, '', 'K19'),
    _Step(
      CoachFirstWeekStep.setUpAssessment,
      l10n.setUpAnAssessment,
      l10n.itRunsBeforeAnyonesFirstWeek,
      'K21',
    ),
    _Step(
      CoachFirstWeekStep.answerEnquiry,
      l10n.answerYourFirstEnquiry,
      l10n.shePaysOnlyOnceYouAccept,
      'K09',
    ),
  ];

  void _close(BuildContext context) {
    // `K24` is a state of the `K07` route, so there is nothing to go "back" to
    // by name — Today decides which branch to draw from her roster.
    goToScreen(context, 'K07', onClose);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final steps = _steps(l10n);

    final doneLine = statedLine(
      l10n.twoDone,
      states: 2,
      hers: firstWeek.doneCount,
    );

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.yourFirstWeek,
        onBack: () => _close(context),
        actions: [
          IconButton(
            tooltip: l10n.close,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.close),
            onPressed: () => _close(context),
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.setUpTheAssessment,
          height: 54,
          onPressed: () => goToScreen(context, 'K21', onSetUpAssessment),
        ),
        AppButton(
          l10n.backToToday,
          variant: AppButtonVariant.text,
          height: 42,
          fontSize: 15,
          onPressed: () => goToScreen(context, 'K07', onBackToToday),
        ),
      ],
      children: [
        Row(
          children: [
            AppRingStat(
              fraction: firstWeek.doneCount / firstWeek.stepCount,
              big: '${firstWeek.doneCount}',
              small: l10n.of4,
              size: 78,
              thickness: 10,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (doneLine != null) ...[
                    Text(doneLine, style: AppText.titleM),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    l10n.eachOneIsWorkAClientWill,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        for (var i = 0; i < steps.length; i++)
          _ArcStepRow(
            number: i + 1,
            title: steps[i].title,
            subtitle: steps[i].subtitle,
            state: firstWeek.stateOf(steps[i].step),
            onTap: () => goToScreen(
              context,
              steps[i].screenId,
              onOpenStep == null ? null : () => onOpenStep!(steps[i].screenId),
            ),
          ),

        if (firstWeek.certificatesCleared)
          AppCard(
            variant: AppCardVariant.sage,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user,
                    size: 22,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.certificatesChecked, style: AppText.titleM),
                        const SizedBox(height: 2),
                        Text(
                          l10n.yourPageIsVisibleAndYouCan,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

        AppSageNote(l10n.nothingHereExpiresAndNoClientSees),
      ],
    );
  }
}

/// One row of the arc. Done, current, or waiting — never failed.
class _ArcStepRow extends StatelessWidget {
  const _ArcStepRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
  });

  final int number;
  final String title;
  final String subtitle;
  final CoachStepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final done = state == CoachStepState.done;
    final now = state == CoachStepState.now;

    // Three kinds of line in the diary: a done step is a plain slip of sage,
    // the one she is on is ringed in ink, and the rest wait on white paper
    // framed in pencil. Each step's number is circled by the same hand.
    return HandSurface(
      seed: handSeed(['arc-step', number]),
      fill: done ? AppColors.tertiaryContainer : AppColors.surfaceLowest,
      frame: done
          ? null
          : now
          ? AppColors.primary
          : AppColors.outline.withValues(alpha: 0.55),
      frameWidth: now ? 2 : 1.05,
      level: now ? HandLevel.expressive : HandLevel.crafted,
      radius: 5,
      looseCorner: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      onTap: done ? null : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (done)
            const Icon(Icons.check_circle, size: 24, color: AppColors.tertiary)
          else
            HandCircled(
              seed: number,
              level: HandLevel.crafted,
              width: now ? HandStroke.pen : 1.1,
              color: now
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: 0.75),
              inflate: EdgeInsets.zero,
              child: SizedBox.square(
                dimension: 24,
                child: Center(
                  child: Text(
                    '$number',
                    style: AppText.nav.copyWith(
                      fontWeight: FontWeight.w700,
                      color: now
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.titleS.copyWith(
                    color: done
                        ? AppColors.onTertiaryContainer
                        : AppColors.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.nav.copyWith(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (done) ...[
            const SizedBox(width: 8),
            Text(
              l10n.done,
              style: AppText.nav.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.tertiary,
              ),
            ),
          ] else if (now) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 21, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}
