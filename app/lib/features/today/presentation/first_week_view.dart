/// T07 — Your first week, and T08 — First week done.
///
/// Matches `6-v2/src/screens-firstweek.mjs` → `T07` and `T08`.
///
/// **T08 is the completed rendering of the same arc, not somewhere you go.** It
/// is this widget's other branch, taken when every step the arc offers is done,
/// so the screen cannot claim completion while the arc disagrees — there is one
/// source for both and it is [firstWeekIsComplete].
///
/// **The arc has no timer, no expiry and no failure state** (HANDOFF rule 17).
/// [ArcStepState] has three values — done, now, waiting — and none of them means
/// failed, so a failure state is not constructible here rather than merely
/// unused. The copy says so out loud: nothing expires, and missing a day changes
/// nothing on this screen.
///
/// **All five steps ship, in a build that has all five.** `DECISIONS.md` D1
/// withdrew the MVP cut, so "join one group" and "add a follow-up picture" are
/// real steps pointing at real screens, and they are still here. What they are
/// not is *unconditional*: the first release ships with Community dark, and a
/// first week containing a step she cannot complete is a week she cannot
/// finish. So the arc is drawn from [offeredFirstWeekSteps] — the steps this
/// build can actually offer — and the ring, the "done / waiting" line and the
/// completed branch all count the same list. D1's worry was an arc that
/// quietly became three while T08 still demanded five; that cannot happen
/// here, because there is one list and everything reads it.
///
/// Completion is deliberately quiet. The single confetti moment in this product
/// belongs to finishing a workout; spending it here would cheapen that.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import '../domain/today_day.dart';
import '../domain/today_repository.dart';
import 'today_cards.dart';

/// One step of the arc, with the screen it leads to.
class _Step {
  const _Step(this.step, this.title, this.subtitle);

  final FirstWeekStep step;
  final String title;
  final String subtitle;

  /// Read from the arc's own edge list rather than repeated here, so this
  /// screen and Home's count of it cannot come to disagree about which five
  /// steps there are.
  String get screenId => firstWeekStepScreens[step]!;
}

class FirstWeekView extends StatefulWidget {
  const FirstWeekView({
    super.key,
    this.repository,
    this.onClose,
    this.onStartSession,
    this.onOpenStep,
    this.onBackToToday,
    this.onSeeProgress,
    this.points = 90,
    this.level = 2,
  });

  final TodayRepository? repository;
  final VoidCallback? onClose;
  final VoidCallback? onStartSession;

  /// Given the screen id a step leads to. Two of the five are Community's.
  final ValueChanged<String>? onOpenStep;

  final VoidCallback? onBackToToday;
  final VoidCallback? onSeeProgress;

  /// What the arc added up to. The same points the rest of the app gives —
  /// there is no parallel currency here.
  final int points;
  final int level;

  @override
  State<FirstWeekView> createState() => _FirstWeekViewState();
}

class _FirstWeekViewState extends State<FirstWeekView> {
  late final TodayRepository _repo;
  late final bool _ownsRepo;
  StreamSubscription<TodayDay>? _sub;
  late TodayDay _day;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryTodayRepository();
    _day = _repo.day;
    _sub = _repo.watch().listen((day) {
      if (mounted) setState(() => _day = day);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// The rows this build draws, in arc order.
  List<_Step> _steps(AppL10n l10n) {
    final offered = offeredFirstWeekSteps().toSet();
    return [
      for (final step in _allSteps(l10n))
        if (offered.contains(step.step)) step,
    ];
  }

  /// The state of [step], measured against the steps she is actually offered.
  ///
  /// Not `arc.stateOf`: that walks all five, so with the last two dark the
  /// "now" marker could land on a row this screen does not draw and every
  /// visible row would read as waiting.
  ArcStepState _stateOf(FirstWeekArc arc, FirstWeekStep step) {
    if (arc.completed.contains(step)) return ArcStepState.done;
    final offered = offeredFirstWeekSteps();
    final next = offered.firstWhere(
      (s) => !arc.completed.contains(s),
      orElse: () => step,
    );
    return step == next ? ArcStepState.now : ArcStepState.waiting;
  }

  List<_Step> _allSteps(AppL10n l10n) => [
    // No subtitle on this one.
    //
    // It read `youDidGobletSquat12Kg` — "You did · goblet squat, 12 kg" — under
    // "Log one set", in the past tense, to a woman who has logged no set at all
    // and whose plan may hold no goblet squat. The step's own title is the
    // instruction; the prototype's lift is not an example worth inventing.
    _Step(FirstWeekStep.logSet, l10n.logOneSet, ''),
    // No subtitle on this one either, and for the reason written three lines
    // above. `youDidFulAndBaladi` — "You did · ful and baladi" — is the past
    // tense about a meal she has not logged, and one of the two instances of
    // this defect was fixed in the same pass while this one was missed.
    _Step(FirstWeekStep.logMeal, l10n.logOneMeal, ''),
    // `n15MinutesFiveMoves` — "15 minutes, five moves" — describes the
    // prototype's session, not today's, and this screen is handed no session.
    _Step(FirstWeekStep.finishSession, l10n.finishOneSession, ''),
    // Community's two. Drawn only where Community is on — see the library
    // note and `offeredFirstWeekSteps`.
    _Step(
      FirstWeekStep.joinGroup,
      l10n.joinOneGroup,
      l10n.beginnersPostpartumOrYourCity,
    ),
    _Step(
      FirstWeekStep.followUp,
      l10n.addAFollowUpPicture,
      l10n.onceYouHaveAPostToFollow,
    ),
  ];

  void _openStep(String screenId) {
    final onOpen = widget.onOpenStep;
    openScreen(
      context,
      screenId,
      onOpen == null ? null : () => onOpen(screenId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Finished is measured against the steps this build offers, not against
    // all five — see `firstWeekIsComplete`.
    return firstWeekIsComplete(_day.arc)
        ? _done(context, l10n)
        : _arc(context, l10n);
  }

  // ---------------------------------------------------------------- T07 ----

  Widget _arc(BuildContext context, AppL10n l10n) {
    final arc = _day.arc;
    final steps = _steps(l10n);
    final done = firstWeekDone(arc);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.yourFirstWeek,
        onBack: _close,
        actions: [
          IconButton(
            tooltip: l10n.close,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.startTodaysSession,
          height: 54,
          icon: Icons.play_arrow,
          onPressed: () => openScreen(context, 'R03', widget.onStartSession),
        ),
      ],
      children: [
        Row(
          children: [
            AppRingStat(
              // Her arc, over the arc she was given. `arc.stepCount` is
              // always five; `steps.length` is however many of them this
              // build can offer, which is what she is looking at.
              fraction: steps.isEmpty ? 0 : done / steps.length,
              big: countLabel(done),
              small: l10n.ofTotal(countLabel(steps.length)),
              size: 78,
              thickness: 10,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // `twoDoneThreeWaiting` — "Two done, three waiting" — was
                  // fixed copy above two live numbers, so it said two and
                  // three to a woman who had done none of three. Counted from
                  // the same list the ring counts.
                  Text(
                    l10n.doneDoneWaitingWaiting(
                      countLabel(done),
                      countLabel(steps.length - done),
                    ),
                    style: AppText.titleM,
                  ),
                  const SizedBox(height: 3),
                  // No timer on any of them. Said plainly, because the absence
                  // of a deadline is the feature.
                  Text(
                    l10n.noTimerOnAnyOfThemMiss,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Numbered by position in ONE list. This was `_steps(l10n).indexOf`,
        // which searched a second, freshly built list for a step it could
        // never contain, so every waiting step was numbered 0.
        for (final (i, step) in steps.indexed) ...[
          _ArcStepRow(
            number: i + 1,
            title: step.title,
            subtitle: step.subtitle,
            state: _stateOf(arc, step.step),
            onTap: () => _openStep(step.screenId),
          ),
          const SizedBox(height: 0),
        ],
        // The reward is the points system that already exists. Nothing extra is
        // given for opening the app, and the copy says so.
        AppCard(
          variant: AppCardVariant.tonal,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 22,
                  color: AppColors.primaryDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Her points, as a label and a value — the shape T08
                      // below already uses.
                      //
                      // This was `n35PointsSoFar` — "35 points so far" — a
                      // fixed string sitting two lines above `widget.points`,
                      // which is the real figure. A woman with five points read
                      // thirty-five.
                      AppSplitRow(
                        start: Text(l10n.points, style: AppText.titleM),
                        end: Text(
                          countLabel(widget.points),
                          style: AppText.titleM,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.theSamePointsTheRestOfThe,
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
        // No number. `offeredFirstWeekSteps` returns three in this build, and
        // "Finishing all five is not a deadline" sat under a ring, a heading
        // and three rows that all said three.
        AppSageNote(l10n.finishingThemAllIsNotADeadline),
      ],
    );
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    // T06 is a state rather than a destination, so there is nothing to go
    // "back" to by name: this returns to whatever opened the arc.
    Navigator.of(context).maybePop();
  }

  // ---------------------------------------------------------------- T08 ----

  Widget _done(BuildContext context, AppL10n l10n) {
    return AppScaffold(
      footer: [
        AppButton(
          l10n.backToToday,
          height: 54,
          onPressed: () => openScreen(context, 'T01', widget.onBackToToday),
        ),
        AppButton(
          l10n.seeYourProgress,
          variant: AppButtonVariant.text,
          height: 42,
          fontSize: 15,
          onPressed: () => openScreen(context, 'P01', widget.onSeeProgress),
        ),
      ],
      children: [
        const SizedBox(height: 14),
        // The one mark on this page: a loop drawn once round the tick, in
        // sage, the way she would circle a finished week in a diary. Quiet on
        // purpose — the confetti belongs to finishing a workout.
        Center(
          child: DrawOn(
            delay: const Duration(milliseconds: 200),
            builder: (context, progress) => CustomPaint(
              foregroundPainter: LoopPainter(
                seed: 61,
                color: HandInk.done,
                width: HandStroke.felt,
                level: HandLevel.signature,
                progress: progress,
                inflate: const EdgeInsets.all(7),
                textDirection: Directionality.of(context),
              ),
              child: HandSurface(
                seed: 62,
                fill: AppColors.tertiaryContainer,
                radius: 36,
                looseCorner: 38,
                child: const SizedBox.square(
                  dimension: 76,
                  child: Center(
                    child: Icon(
                      Icons.check_circle,
                      size: 40,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.youKnowYourWayAround,
          textAlign: TextAlign.center,
          style: AppText.headline.copyWith(
            fontSize: 26,
            height: 33 / 26,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            // No number, for the same reason the line on T07 has none: this
            // build offers three of the five steps.
            l10n.allDoneNothingAboutTheAppChanges,
            textAlign: TextAlign.center,
            style: AppText.bodyM.copyWith(
              height: 23 / 15,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // What carried forward, named plainly. Not a second celebration.
        AppCard(
          variant: AppCardVariant.sage,
          gap: 7,
          children: [
            Text(l10n.whatItAddedUpTo, style: AppText.titleM),
            _tally(l10n.points, '${widget.points}'),
            _tally(l10n.level, '${widget.level}'),
            // Her week, from the same two numbers everything else counts
            // with. `n3Of3ItCounted` — "3 of 3 · it counted" — declared a
            // finished week to a woman whose goal is four and who had done two.
            _tally(
              l10n.thisWeek,
              l10n.countOfTotal(
                countLabel(_day.week.sessionsLogged),
                countLabel(_day.week.sessionsTarget),
              ),
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.spa, size: 22, color: AppColors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.yourFirstRestWeekIsBanked,
                        style: AppText.titleM,
                      ),
                      const SizedBox(height: 2),
                      // D5: it covers a week she misses, without being asked.
                      Text(
                        l10n.itCoversAWeekYouMissWithout,
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
      ],
    );
  }

  Widget _tally(String label, String value) {
    return AppSplitRow(
      start: Text(
        label,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
      end: Text(value, style: AppText.titleS),
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
  final ArcStepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final done = state == ArcStepState.done;
    final now = state == ArcStepState.now;
    final seed = handSeed(['arc', number, title]);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (done)
          const Icon(Icons.check_circle, size: 24, color: AppColors.tertiary)
        else
          // Her number in a drawn loop: pencil while it waits, rose ink on
          // the one she is on. Same marks the week is kept in.
          SizedBox.square(
            dimension: 24,
            child: CustomPaint(
              painter: LoopPainter(
                seed: seed,
                color: now
                    ? HandInk.ink
                    : AppColors.outline.withValues(alpha: 0.8),
                width: now ? HandStroke.pen : 1.2,
                level: HandLevel.crafted,
                inflate: const EdgeInsets.all(-1),
                textDirection: Directionality.of(context),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: AppText.nav.copyWith(
                    fontWeight: FontWeight.w700,
                    color: now ? AppColors.primary : AppColors.onSurfaceVariant,
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
          const AppChevron(size: 21, color: AppColors.primary),
        ],
      ],
    );

    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 11);

    // A step still waiting is a ruled line in the list she keeps, not one
    // more box. The same horizontal padding as the slips above it keeps the
    // numbers in one column.
    if (!done && !now) {
      return HandPressable(
        onTap: onTap,
        scale: 0.985,
        builder: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: padding, child: row),
            HandRule(seed: seed, height: 3),
          ],
        ),
      );
    }

    // Done is a slip of sage; the one she is on is ringed in ink — the card
    // families' own looks, so the arc reads like the rest of the app.
    final look = handCardLook(
      done ? AppCardVariant.sage : AppCardVariant.selected,
    );
    return HandSurface(
      seed: seed,
      fill: look.fill,
      frame: look.frame,
      frameWidth: look.frameWidth,
      level: look.level,
      radius: handTightRadius(AppRadius.md),
      looseCorner: handLooseRadius(AppRadius.md),
      onTap: done ? null : onTap,
      padding: padding,
      child: row,
    );
  }
}
