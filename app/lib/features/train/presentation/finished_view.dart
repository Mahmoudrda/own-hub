/// R10 — Finished.
///
/// Matches `6-v2/src/screens-train.mjs` → `R10`. **The one celebration.**
/// Confetti lives here and nowhere else in the product, because a celebration
/// that happens everywhere stops being one.
///
/// The page is a composition she can screenshot: the day done at the top, then
/// the picture of her workout (minutes, estimated calories, weight lifted, the
/// moves) with its Share button under it and the switches for what is on it,
/// then what she earned in the order she cares about: that it counted, how
/// close the week is, and what she beat. The share is of an image she
/// chooses; nothing is posted from here. The group-post link stays a quiet text
/// link, and only where Community is on.
///
/// The points, the total and the personal best are all read from the rewards
/// group. This screen renders them and computes none of them: a widget that did
/// its own arithmetic would be a second, quieter definition of what a session is
/// worth.
///
/// ## D40: the peak
///
/// Everything below comes from [SessionSummary] — her log and the ledger's own
/// answer — and arrives in a fixed order ([FinishReveal]): the day done, the
/// effort, the week, a best she really beat, the challenge, the streak, then
/// the quiet line of points. The biggest real moment present gets the full
/// paper confetti; a session with none gets a small burst. The staging is the
/// week filling, its figure counting up, the kitten cheering with the one
/// medium haptic, then the paper, in under two seconds, and a tap finishes
/// it.
/// Nothing is decided by chance and nothing is claimed that did not happen:
/// there is no personal-best line without a best, and no points line for
/// points the cap refused.
library;

import '../../../domain/clock/app_clock.dart';
import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import 'dart:async';

import '../../../app_state/haptics.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart' show LogHandle;
import '../../../domain/rewards/personal_best_detector.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/rewards/training_streak.dart';
import '../../../l10n/app_l10n.dart';
import '../../onboarding/domain/body_data.dart';
// `weekdayLabel` is Home's, and the two screens must name the day the same
// way or a woman sees Thursday on one and Tuesday on the next.
import '../../today/presentation/today_cards.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/language_switch.dart' show AppChrome;
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_overflow_menu.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/app_stat_hero.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/finish_wipe.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/hand/paper_confetti.dart';
import '../domain/own_best_challenge.dart';
import '../domain/session_summary.dart';
import '../domain/train_repository.dart';
import 'finish_reveal.dart';
import 'session_share_card.dart';
import 'set_labels.dart';
import 'train_widgets.dart' show TrainTopBar;

// The reveal's order: the day, the effort, the week filling, its figure
// counting up, a best, the challenge, a drawn tick, then the paper.
// Under two seconds in all, so the burst is kept short.
const int _cheerStage = 5;
const int _confettiStage = 6;

class FinishedView extends StatelessWidget {
  const FinishedView({
    super.key,
    this.onBackToToday,
    this.onRemove,
    this.onShare,
    this.session,
    this.finishedOn,
    this.sessionsThisWeek = 2,
    this.sessionsPrescribed = 3,
    this.levelProgressPercent = 50,
    this.eligibility = const PersonalBestEligibility(),
    this.summary,
    this.cheer = false,
    this.awaitingSummary = false,
    this.workoutName,
    this.bodyWeightKg,
    this.displayName,
    this.onShareImage,
    this.onOpenRecentSessions,
    this.lastLog,
    this.onUndoLastLog,
  });

  /// The last set (or move) of the workout, while its five seconds are open.
  /// The page offers Undo for it, and the session is only finished once the
  /// window closes. Null draws no bar.
  final LogHandle? lastLog;

  /// Puts her back on the set that [lastLog] took back. Runs only when the
  /// undo landed.
  final VoidCallback? onUndoLastLog;

  /// Her last sessions, where a set can be corrected. Offered in See details.
  final VoidCallback? onOpenRecentSessions;

  /// The workout's name for the share card. Null names the day instead.
  final String? workoutName;

  /// Her body weight for the calorie estimate. Null reads the weight she set
  /// in her body data, and the estimate assumes 65 kg when she has not.
  final double? bodyWeightKg;

  /// Her first name, offered as a switch on the share card that is off until
  /// she turns it on. Null offers no switch.
  final String? displayName;

  /// Hands the share card's PNG to the share sheet. Null uses the phone's own.
  final WorkoutSharer? onShareImage;

  /// The session has finished and its credit has not landed yet. Only the
  /// day-done stage is drawn until it does, so the page never shows a week
  /// count from before this session — "one more and this week counts" on the
  /// very session that counted it.
  final bool awaitingSummary;

  /// What the session really was (D40). Null until its credit has landed —
  /// R10 is pushed the moment she finishes and redraws when it does — and in
  /// previews, where the page shows only what it was told.
  final SessionSummary? summary;

  /// Whether the tick is drawn: her first sessions, and the session that
  /// counts her week.
  final bool cheer;

  final VoidCallback? onBackToToday;

  /// Takes this session off her week, after a confirmation. Null draws nothing.
  final VoidCallback? onRemove;

  /// Community. Hands over an intent only — no post is written from here.
  final VoidCallback? onShare;

  /// The session just finished. Decides whether a personal best may be shown at
  /// all: only a measured live session can set one.
  final TrainSession? session;

  /// The day she finished. Null means today, which is what it always is in
  /// the product: this screen is shown the moment a session ends.
  final DateTime? finishedOn;

  final int sessionsThisWeek;
  final int sessionsPrescribed;
  final double levelProgressPercent;

  // ------------------------------------------------ four withdrawn lines ----
  //
  // R10 used to state five figures. `n30Points` stays, because 30 is the
  // product's own number for a live session — `SessionCredit.livePoints` — and
  // is the same for every woman. The other four were hers, and this screen is
  // handed none of them:
  //
  //   * `n15Minutes5Moves14SetsYou` — "15 minutes, 5 moves, 14 sets. You typed
  //     nothing." — the prototype's session, under the heading announcing hers.
  //   * `n490Total` — "490 total" — a lifetime points balance.
  //   * `session20PersonalBest10` — "Session 20 · personal best 10" — two
  //     counts of her whole history, on her first session as readily as her
  //     hundredth.
  //   * `n70PointsToLevel8` — "70 points to level 8." — a distance from a level
  //     she may be nowhere near. The bar above it is drawn from
  //     `levelProgressPercent`, which IS passed in, so the two disagreed.
  //   * `gobletSquat12Kg10TwoKilos_75cjy` — "Goblet squat, 12 kg × 10 — two
  //     kilos more than your best." — the trophy card named the prototype's
  //     lift. The card still appears, and still only for a session that may set
  //     one; it no longer says what the best was.
  //
  // None has a parameterised form, and inventing English here would ship
  // English to an Arabic reader. The dictionary gap is five `{n}` messages; the
  // silence is the honest state until they exist.

  /// The rule, injected so it is testable and so the widget cannot restate it.
  final PersonalBestEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final flags = AppRouter.featureFlags;
    final revealOn = flags.isOn(Feature.finishReveal);

    // A live session may show a best. A recalled or unplanned one never can —
    // the numbers were copied or absent, not measured. And no session at all
    // can: an unstated session is not an eligible one.
    final measured = session != null && eligibility.isEligible(session!);
    final summary = this.summary;
    final bests = measured && summary != null
        ? summary.newBests
        : const <PersonalBest>[];
    final firstMarks = measured && summary != null ? summary.firstMarks : 0;
    final weekCountedNow = summary?.credit.weekCountedNow ?? false;
    // The week as this session's credit left it, once there is one, so the
    // marks and "This week counts." come from the same answer.
    final credited =
        summary != null &&
        !summary.credit.alreadyCredited &&
        summary.credit.target > 0;
    final weekDone = credited ? summary.credit.loggedAfter : sessionsThisWeek;
    final weekTarget = credited ? summary.credit.target : sessionsPrescribed;
    final challenge =
        flags.isOn(Feature.weeklyChallenge) &&
            summary != null &&
            summary.challengeMetNow
        ? summary.challenge
        : null;
    final streakStatus = flags.isOn(Feature.trainingStreak)
        ? summary?.trainingStreak
        : null;

    // One firm touch, as the tick draws (stage 5): the reveal's single
    // haptic, so what she feels lands with what she sees.
    void stageShown(int stage) {
      if (stage == _cheerStage) {
        unawaited(AppHaptics.play(HapticMoment.sessionFinished));
      }
    }

    final stats = <AppStat>[
      if (summary != null && summary.minutes > 0)
        AppStat(value: countLabel(summary.minutes), label: l10n.minutes),
      if (summary != null && summary.sets > 0)
        AppStat(value: countLabel(summary.sets), label: l10n.sets),
      if (bests.isNotEmpty)
        AppStat(value: countLabel(bests.length), label: l10n.bests),
    ];

    Widget details(BuildContext sheet) => _details(
      sheet,
      l10n,
      summary: summary,
      measured: measured,
      bests: bests,
      firstMarks: firstMarks,
      challenge: challenge,
      streakStatus: streakStatus,
      weekDone: weekDone,
      weekTarget: weekTarget,
      weekCountedNow: weekCountedNow,
    );

    final page = AppScaffold(
      appBar: TrainTopBar(
        actions: [
          // The card she can screenshot or send: opened from here, so the peak
          // stays one picture and one button.
          if (!awaitingSummary &&
              summary != null &&
              summary.isLive &&
              summary.sets > 0)
            Builder(
              builder: (bar) => IconButton(
                key: const ValueKey('r10-share'),
                tooltip: l10n.share,
                iconSize: 24,
                color: AppColors.onSurfaceVariant,
                icon: const Icon(Icons.ios_share),
                onPressed: () => unawaited(
                  showAppSheet<void>(
                    context: bar,
                    children: [
                      SessionSharePanel(
                        data: ShareCardData.from(
                          summary: summary,
                          title:
                              workoutName ??
                              l10n.dayWorkout(
                                weekdayLabel(
                                  l10n,
                                  finishedOn ?? AppClock.now(),
                                ),
                              ),
                          date: finishedOn ?? AppClock.now(),
                          bodyWeightKg:
                              bodyWeightKg ??
                              BodyDataStore.instance.read().weightKg,
                          name: displayName,
                        ),
                        onShare: onShareImage ?? AppRouter.shareProgressCard,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // A session logged by mistake comes off her week, after a
          // confirmation, with Undo. Only once its credit has landed. The
          // group link is Community's, and the first release ships without it.
          if (onRemove != null ||
              (AppRouter.screenIsOn('M03') && onShare != null))
            AppOverflowMenu(
              items: [
                if (AppRouter.screenIsOn('M03') && onShare != null)
                  AppOverflowItem(
                    icon: Icons.groups_outlined,
                    label: l10n.shareTheSquatWithYourGroup,
                    onTap: onShare!,
                  ),
                if (onRemove != null)
                  AppOverflowItem(
                    icon: Icons.delete_outline,
                    label: l10n.removeThisSession,
                    confirmMessage: l10n.removeThisSession_1qh67,
                    onTap: onRemove!,
                  ),
              ],
            ),
          const AppChrome(routedOnly: true),
        ],
      ),
      footer: [
        AppButton(l10n.done_54ca1, onPressed: onBackToToday),
        if (!awaitingSummary)
          Builder(
            builder: (foot) => AppButton(
              l10n.seeDetails,
              key: const ValueKey('r10-see-details'),
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: () => unawaited(
                showAppSheet<void>(context: foot, children: [details(foot)]),
              ),
            ),
          ),
      ],
      children: [
        if (lastLog != null) ...[
          // Five seconds to take the last set back and go on with the workout.
          AppLiveUndoBar(
            key: const ValueKey('r10-undo-last-set'),
            handle: lastLog,
            message: lastLog!.describe,
            undoLabel: l10n.undo,
            onUndo: onUndoLastLog,
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 6),
        // Stage 0 — the day, done. A finished session is the one
        // unambiguously good moment in this product. The drawing is
        // decorative -- the heading already says what happened, so it is
        // excluded from semantics rather than read aloud.
        RevealStage(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Center(
                    child: TiltParallax(
                      child: AppArt.image(AppArt.strongArms, size: 128),
                    ),
                  ),
                  // The one celebration (D40): the full burst when there is a
                  // big real moment, a small one when there is not. Keyed by
                  // the session, so it plays once for each.
                  if (revealOn && summary != null)
                    Positioned.fill(
                      // Last, after the tick has drawn: the week fills, the
                      // figure counts up, the tick draws, then the paper.
                      child: RevealOnArrival(
                        index: _confettiStage,
                        child: PaperConfetti(
                          key: ValueKey('confetti-${summary.sessionId}'),
                          seed: summary.sessionId.hashCode,
                          pieces: summary.hasBigMoment ? 28 : 10,
                          height: 180,
                          duration: HandTiming.long,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Ticked off in sage beside the heading — done, not won — drawn
              // on once, as the page arrives.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      // Her day, not the prototype's Tuesday. `finishedOn`
                      // defaults to now, so a screen built with nothing still
                      // names today.
                      l10n.thatsDayDone(
                        weekdayLabel(l10n, finishedOn ?? AppClock.now()),
                      ),
                      style: AppText.display,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const HandTick(
                    size: 52,
                    seed: 11,
                    drawOn: true,
                    delay: HandTiming.medium,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!awaitingSummary) ...[
          // Stage 1 — one hero figure and at most three more, from what she
          // logged: the week is what this product counts, and the work shown
          // is the work done.
          RevealStage(
            index: 1,
            child: AppStatHero(
              key: const ValueKey('r10-hero'),
              hero: AppStat(
                value: l10n.countOfTotal(
                  countLabel(weekDone),
                  countLabel(weekTarget),
                ),
                label: l10n.sessionsThisWeek,
              ),
              // The one figure counts up to this week's total, from the week
              // as it stood before this session. Still under Reduce Motion.
              heroBuilder: (style) => RevealCount(
                index: 1,
                from: credited && weekDone > 0 ? weekDone - 1 : weekDone,
                value: weekDone,
                format: (shown) => l10n.countOfTotal(
                  countLabel(shown),
                  countLabel(weekTarget),
                ),
                style: style,
              ),
              others: stats,
            ),
          ),
          // Stage 5 — one warm line, and a drawn tick on the sessions
          // that earn it. The session that counted
          // the week says so instead, in sage.
          RevealStage(
            index: _cheerStage,
            child: Row(
              children: [
                Expanded(
                  child: weekCountedNow
                      ? Text(
                          l10n.thisWeekCounts,
                          key: const ValueKey('r10-week-counts'),
                          style: AppText.titleM.copyWith(
                            color: AppColors.tertiary,
                          ),
                        )
                      : Text(
                          l10n.gladYouShowedUpToday,
                          key: const ValueKey('r10-kitten-caption'),
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                ),
                // Built as its stage arrives, so the tick is drawn when she sees it.
                if (cheer)
                  RevealOnArrival(
                    index: _cheerStage,
                    child: const Moment(size: 40),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    FinishReveal reveal({required bool hold}) => FinishReveal(
      // One reveal for the page: it plays once, not again when the page
      // redraws, and runs on from the first stage when the summary lands.
      key: const ValueKey('r10-reveal'),
      stages: 7,
      enabled: revealOn && summary != null,
      hold: hold,
      onStageShown: summary == null ? null : stageShown,
      child: page,
    );
    // After a measured live session a pale-pink ribbon wipes across once and
    // uncovers the page, and the reveal begins when it has gone. Not a second
    // celebration: the confetti stays the peak. Nothing is drawn under Reduce
    // Motion or for a recalled session.
    if (!revealOn || !measured) return reveal(hold: false);
    return _WipedReveal(builder: reveal);
  }

  /// Everything R10 used to stack under the celebration, in one sheet she
  /// opens from "See details": the effort, the week's marks, the bests, the
  /// challenge, the streak, the points and what comes next.
  Widget _details(
    BuildContext context,
    AppL10n l10n, {
    required SessionSummary? summary,
    required bool measured,
    required List<PersonalBest> bests,
    required int firstMarks,
    required ChallengeProgress? challenge,
    required StreakStatus? streakStatus,
    required int weekDone,
    required int weekTarget,
    required bool weekCountedNow,
  }) {
    final oneMore = weekCountedNow
        ? null
        : statedLine(
            l10n.oneMoreSessionAndThisWeekCounts,
            states: 1,
            hers: weekTarget - weekDone,
          );
    return Column(
      key: const ValueKey('r10-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: [
        if (summary != null && summary.sets > 0 && summary.minutes > 0)
          Text(
            l10n.minutesPluralOneMovesMovesSetsSets(
              summary.minutes,
              countLabel(summary.moves),
              countLabel(summary.sets),
            ),
            key: const ValueKey('r10-effort'),
            style: AppText.titleM.copyWith(color: AppColors.onSurface),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.thisWeek, style: AppText.titleM)),
                Text(
                  l10n.countOfTotal(
                    countLabel(weekDone),
                    countLabel(weekTarget),
                  ),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppWeekSegments(
              style: WeekStyle.marks,
              total: weekTarget,
              filled: weekDone,
            ),
            // "One more session and this week counts" states the figure 1,
            // and `statedLine` renders it only to the woman it is true of.
            if (oneMore != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  oneMore,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        // A best she really beat, with the value it beat, in sage: done, not
        // won.
        if (bests.isNotEmpty || firstMarks > 0)
          Column(
            key: const ValueKey('r10-bests'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final best in bests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 22,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bestLine(l10n, summary!, best),
                          style: AppText.titleS.copyWith(
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (firstMarks > 0)
                Text(
                  l10n.countPluralOneFirstMarkSetOn(firstMarks),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        // The weekly challenge, on the session that met it (D38).
        if (challenge != null)
          Text(
            _challengeLine(l10n, summary!, challenge),
            key: const ValueKey('r10-challenge'),
            style: AppText.titleS.copyWith(color: AppColors.tertiary),
          ),
        // Her training streak, when she keeps one (D37).
        if (_showsStreak(streakStatus))
          Text(
            l10n.daysPluralOneTrainingStreak1Day(streakStatus!.days),
            key: const ValueKey('r10TrainingStreak'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurface),
          ),
        _points(context, l10n),
        if (onOpenRecentSessions != null)
          AppButton(
            l10n.recentSessions,
            key: const ValueKey('r10-recent-sessions'),
            icon: Icons.history,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: () {
              Navigator.of(context).pop();
              onOpenRecentSessions!();
            },
          ),
        // The next step, while her week still has sessions left in it. The
        // reason to come back is her own week, said in the week's terms: the
        // next session, any day this week. Never a day count.
        if (weekDone < weekTarget)
          AppCard(
            key: const ValueKey('r10-next-step'),
            variant: AppCardVariant.sage,
            borderRadius: AppRadius.md,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                l10n.nextSessionNumberOnAnyDayThis(countLabel(weekDone + 1)),
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
      ],
    );
  }

  /// The points this session actually earned, as a quiet line with the level
  /// bar beside it. Nothing at all when the cap granted nothing.
  Widget _points(BuildContext context, AppL10n l10n) {
    final summary = this.summary;
    // What the ledger granted for this session: the session, the week when it
    // counted, and the bests it paid while she trained. Nothing is claimed
    // before the ledger has answered, or when it granted nothing.
    final granted = summary == null
        ? 0
        : summary.credit.pointsGranted + summary.bestPoints;
    final label = granted > 0 ? l10n.pointsPoints(countLabel(granted)) : null;
    final bar = AppProgressBar(percent: levelProgressPercent, height: 5);
    if (label == null) return bar;
    final note = Text(
      label,
      style: AppText.bodyM.copyWith(color: AppColors.tertiary),
    );
    // Side by side until the text is turned up, then the bar goes under it.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [note, const SizedBox(height: 10), bar],
      );
    }
    return Row(
      children: [
        note,
        const SizedBox(width: 16),
        Expanded(child: bar),
      ],
    );
  }

  static bool _showsStreak(StreakStatus? status) =>
      status != null && status.enabled && status.days > 0;

  static String _bestLine(
    AppL10n l10n,
    SessionSummary summary,
    PersonalBest best,
  ) {
    final name = summary.nameOf(best.exerciseId);
    if (best.metric == BestMetric.variation) {
      return l10n.moveAHarderVersionThanBefore(name);
    }
    final previous = best.previous!;
    return l10n.moveNowUpFromBefore(
      name,
      setFigure(
        l10n,
        weightKg: best.loadKg,
        reps: best.reps,
        holdSeconds: best.holdSec,
      ),
      setFigure(
        l10n,
        weightKg: previous.loadKg,
        reps: previous.reps,
        holdSeconds: previous.holdSec,
      ),
    );
  }

  static String _challengeLine(
    AppL10n l10n,
    SessionSummary summary,
    ChallengeProgress progress,
  ) {
    final challenge = progress.challenge;
    final name = summary.nameOf(challenge.exerciseId);
    final amount = challenge.unit == ChallengeUnit.reps
        ? l10n.repsReps(countLabel(progress.thisWeek))
        : l10n.secondsSeconds(countLabel(progress.thisWeek));
    // A match she went past is a beat, and R10 says so.
    return challenge.kind == ChallengeKind.beat ||
            progress.thisWeek > challenge.lastWeek
        ? l10n.youBeatLastWeekOnMoveAmount(name, amount)
        : l10n.youMatchedLastWeekOnMoveAmount(name, amount);
  }
}

/// The page under the finish wipe: the reveal waits until the ribbon has
/// crossed, so no stage plays under the cover.
class _WipedReveal extends StatefulWidget {
  const _WipedReveal({required this.builder});

  final Widget Function({required bool hold}) builder;

  @override
  State<_WipedReveal> createState() => _WipedRevealState();
}

class _WipedRevealState extends State<_WipedReveal> {
  bool _covered = true;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.builder(hold: _covered),
      Positioned.fill(
        child: FinishWipe(
          key: const ValueKey('r10-wipe'),
          onDone: () {
            if (mounted) setState(() => _covered = false);
          },
        ),
      ),
    ],
  );
}
