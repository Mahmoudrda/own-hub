/// The follow-up card on Home: one question or one note about her week, in
/// Own Hub's own voice.
///
/// It asks and it offers; it never changes her plan by itself. Every card can
/// be sent away for today or switched off for good, and every number it shows
/// is a count of something she did.
library;

import 'package:flutter/material.dart';

import '../../../app_state/follow_up_state.dart';
import '../../../domain/format/day_key.dart';
import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../onboarding/domain/intake_repository.dart';
import '../../train/domain/weight_label.dart';
import '../../train/presentation/exercise_labels.dart' show isolateLtr;
import '../domain/follow_up_plan.dart';
import 'week_review_sheet.dart';

class FollowUpCard extends StatefulWidget {
  FollowUpCard({
    required this.followUp,
    required this.now,
    required this.intakeRepository,
    this.state,
    this.onOpenTrain,
    this.onOpenEat,
  }) : super(key: ValueKey('follow-up-${followUp.kind.name}'));

  /// What to say, from [FollowUpPlan.next].
  final FollowUp followUp;

  /// Today, for "not now" (back tomorrow).
  final DateTime now;

  /// Where a week review suggestion is written when she accepts it.
  final IntakeRepository intakeRepository;

  /// Her answers. The shared one unless a test gives its own.
  final FollowUpState? state;

  final VoidCallback? onOpenTrain;
  final VoidCallback? onOpenEat;

  /// The answer she just gave, kept for the visit so that Home can say thanks
  /// after the card has gone: her answer ends the follow-up, and the screen is
  /// drawn again at once. Cleared when the thanks leaves the screen.
  static ({String dateKey, Feel feel})? lastThanks;

  @override
  State<FollowUpCard> createState() => _FollowUpCardState();
}

class _FollowUpCardState extends State<FollowUpCard> {
  Feel? _answered;

  FollowUpState get _state => widget.state ?? FollowUpState.instance;

  void _answer(Feel feel) {
    final session = widget.followUp.session;
    if (session == null) return;
    setState(() => _answered = feel);
    FollowUpCard.lastThanks = (dateKey: session.dateKey, feel: feel);
    _state.answerFeel(session.dateKey, feel);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final f = widget.followUp;
    final answered = _answered;
    final body = _body(context, l10n, f);
    return _Appear(
      child: AppCard(
        children: [
          // The one way out: a close that sends the card away until
          // tomorrow. Switching a kind off for good is on Notifications (A01).
          if (answered == null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: body.first),
                _close(l10n, f.kind),
              ],
            )
          else
            body.first,
          ...body.skip(1),
          if (answered == null) ..._notes(l10n, f),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, AppL10n l10n, FollowUp f) {
    switch (f.kind) {
      case FollowUpKind.afterSession:
        return _afterSession(l10n, f);
      case FollowUpKind.weekReview:
        return _weekReview(context, l10n, f);
      case FollowUpKind.comeBack:
        return [
          Text(l10n.welcomeBack, style: AppText.titleM),
          Text(
            l10n.daysPluralOneYourLastSessionWas(f.daysAway ?? 7),
            style: AppText.body,
          ),
          if (widget.onOpenTrain != null)
            AppButton(
              l10n.goToTrain,
              variant: AppButtonVariant.tonal,
              onPressed: widget.onOpenTrain,
            ),
        ];
      case FollowUpKind.food:
        final pick = f.pick;
        return [
          Text(l10n.proteinIdeas, style: AppText.titleM),
          if (pick != null)
            Text(
              l10n.underYourTargetOnLowdaysOfYour(
                countLabel(f.lowDays ?? 0),
                // In Arabic a food name may be Arabic or Latin, so it takes
                // the direction of its own first letter.
                l10n.localeName == 'ar'
                    ? '\u2068${pick.name}\u2069'
                    : pick.name,
                countLabel(pick.proteinG),
              ),
              style: AppText.body,
            ),
          if (widget.onOpenEat != null)
            AppButton(
              l10n.logAMeal,
              variant: AppButtonVariant.tonal,
              onPressed: widget.onOpenEat,
            ),
        ];
    }
  }

  List<Widget> _afterSession(AppL10n l10n, FollowUp f) {
    final session = f.session;
    final answered = _answered;
    final name = session?.topMoveName;
    final kg = session?.topKg;
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    return [
      Text(l10n.yourLastSession, style: AppText.titleM),
      if (f.gentle && answered == null)
        Text(l10n.todayCanBeAGentleDay, style: quiet),
      // A session she did without the phone has no sets to count.
      if (session != null && session.sets > 0)
        Text(
          l10n.movesMovesSetsSets(
            countLabel(session.moves),
            countLabel(session.sets),
          ),
          style: quiet,
        ),
      if (name != null && kg != null)
        Text(
          l10n.upToWeightOnMove(
            '${weightLabel(kg)} ${l10n.kg}',
            isolateLtr(l10n, name),
          ),
          style: quiet,
        ),
      if (answered == null) ...[
        Text(l10n.howDoYouFeelToday, style: AppText.titleS),
        AppChipRow(
          items: [l10n.fresh, l10n.aBitSore, l10n.verySore],
          height: 48,
          selected: const <int>{},
          onTap: (i) => _answer(Feel.values[i]),
        ),
      ] else ...[
        Text(l10n.thanksForTellingUs, style: AppText.body),
        if (FollowUpPlan.holdsLoad(_state.feels))
          Text(l10n.nextTimeTheSameWeightsBuildUp, style: AppText.body),
      ],
    ];
  }

  List<Widget> _weekReview(BuildContext context, AppL10n l10n, FollowUp f) {
    final counts = <String>[
      if (f.sessions > 0) '${l10n.sessions}: ${countLabel(f.sessions)}',
      if (f.sets > 0) '${l10n.sets}: ${countLabel(f.sets)}',
      if (f.bests > 0) l10n.newBestsCount(countLabel(f.bests)),
      if (f.avgProtein != null)
        l10n.averageProteinGramsG(countLabel(f.avgProtein!)),
    ];
    return [
      Text(l10n.yourWeek, style: AppText.titleM),
      if (counts.isNotEmpty)
        Text(counts.join(' · '), style: AppText.body)
      else
        Text(l10n.aFewQuestionsAboutYourWeek, style: AppText.body),
      AppButton(
        l10n.n3QuickQuestions,
        variant: AppButtonVariant.tonal,
        onPressed: () => showWeekReviewSheet(
          context,
          weekStartKey:
              f.weekStartKey ?? FollowUpPlan.weekStartKeyOf(widget.now),
          repository: widget.intakeRepository,
          state: widget.state,
          summary: counts.join(' · '),
          safetyFirst: f.safetyFirst,
        ),
      ),
    ];
  }

  List<Widget> _notes(AppL10n l10n, FollowUp f) {
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    return [
      if (f.safetyFirst)
        Text(l10n.onlyMovesScreenedForYouAndStop, style: quiet),
    ];
  }

  Widget _close(AppL10n l10n, FollowUpKind kind) {
    return IconButton(
      key: ValueKey('follow-up-not-now-${kind.name}'),
      tooltip: l10n.notNow,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.close, size: 20),
      color: AppColors.onSurfaceVariant,
      onPressed: () => _state.notNow(kind, dayKey(widget.now)),
    );
  }
}

/// The line that follows her answer after the card has gone: Home is drawn
/// again the moment she answers, and the follow-up it was drawing is finished.
class FollowUpThanks extends StatefulWidget {
  const FollowUpThanks({super.key, required this.feel, this.state});

  final Feel feel;
  final FollowUpState? state;

  @override
  State<FollowUpThanks> createState() => _FollowUpThanksState();
}

class _FollowUpThanksState extends State<FollowUpThanks> {
  @override
  void dispose() {
    FollowUpCard.lastThanks = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = widget.state ?? FollowUpState.instance;
    return AppCard(
      key: const ValueKey('follow-up-thanks'),
      children: [
        Text(l10n.thanksForTellingUs, style: AppText.body),
        if (FollowUpPlan.holdsLoad(state.feels))
          Text(l10n.nextTimeTheSameWeightsBuildUp, style: AppText.body),
      ],
    );
  }
}

/// Fades its child in once, and not at all when the phone asks for less
/// motion.
class _Appear extends StatelessWidget {
  const _Appear({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.short,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
