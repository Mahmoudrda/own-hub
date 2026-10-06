/// R12 — Logged from memory.
///
/// Matches `6-v2/src/screens-train.mjs` → `R12`. It counts, but it sets no best.
///
/// The product states in two places that a session logged from memory never sets
/// a personal best, because the numbers were copied rather than measured. This is
/// the screen that honours it: the week still counts, the points are smaller, and
/// **the reason is written where the trophy would have been** — so the absence
/// reads as a rule rather than as something that failed to load.
///
/// The rule itself is [PersonalBestEligibility] and lives in the domain layer.
/// This screen asks it; it does not restate it. That matters because the test is
/// `source == live` rather than `source != recalled`: a walk or a studio class is
/// `unplanned`, and it is suppressed here by construction rather than by a second
/// clause somebody has to remember to add.
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show weekdayLabel;
import '../domain/train_repository.dart';

class LoggedFromMemoryView extends StatelessWidget {
  const LoggedFromMemoryView({
    super.key,
    this.onBackToToday,
    this.session,
    this.loggedOn,
    this.sessionsThisWeek = 2,
    this.sessionsPrescribed = 3,
    this.levelProgressPercent = 44,
    this.eligibility = const PersonalBestEligibility(),
  });

  final VoidCallback? onBackToToday;

  /// The session just recorded. Defaults to a recalled one, which is what this
  /// screen exists to report.
  final TrainSession? session;

  /// The day she logged. Null means today, so a screen built with nothing still
  /// names the real day.
  ///
  /// The heading was the fixed `thatsTuesdayDone`, which is the same defect
  /// commit 5e78faa fixed on R10 one screen away: `countOfTotal` on this page
  /// was parameterised in that pass and the sentence above it was missed, so a
  /// woman logging on a Friday was told "That's Tuesday done".
  final DateTime? loggedOn;

  final int sessionsThisWeek;
  final int sessionsPrescribed;
  final double levelProgressPercent;

  // R12's three withdrawn lines, for the same reason R10's five went:
  // `n475Total` ("475 total"), `session20` ("Session 20") and
  // `n85PointsToLevel8` ("85 points to level 8.") are her lifetime balance, her
  // session count and her distance to a level — none of which this screen is
  // given, and none of which has a parameterised form. `n15Points` stays: 15 is
  // `SessionCredit.reducedPoints`, the product's number for a session logged
  // from memory, and it is the same for everybody.

  final PersonalBestEligibility eligibility;

  /// The day the heading names. See the comment at its call site.
  DateTime get _loggedDay {
    final named = loggedOn;
    if (named != null) return named;
    final dated = session?.dateKey;
    return (dated == null ? null : DateTime.tryParse(dated)) ?? AppClock.now();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final recorded =
        session ??
        const TrainSession(
          id: 'recalled-2026-09-15-day-2',
          source: SessionSource.recalled,
          dateKey: '2026-09-15',
          recallMethod: RecallMethod.plan,
          sets: [],
          completed: true,
        );

    final mayShowPersonalBest = eligibility.isEligible(recorded);

    return AppScaffold(
      footer: [AppButton(l10n.backToToday, onPressed: onBackToToday)],
      children: [
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same sage tick as a live session, set above the heading:
            // the week counts either way, and only the best is withheld.
            const HandTick(size: 48, seed: 13, drawOn: true),
            const SizedBox(height: 10),
            // The day she is being told about, in this order: the one the
            // caller named, then the one the SUPPLIED session is dated, then
            // today.
            //
            // The middle step is not decoration. This screen is handed a
            // session and reports it, so naming a different day than the
            // session carries is the same defect as the fixed "Tuesday" that
            // was just removed, one step further in. The `recorded` fallback
            // above is deliberately NOT consulted: it is a placeholder dated
            // 2026-09-15, and reading it would put the word "Tuesday" back on
            // the screen for every woman the router reaches, which is exactly
            // what this heading stopped doing.
            Text(
              l10n.thatsDayDone(weekdayLabel(l10n, _loggedDay)),
              style: AppText.display,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.loggedFromMemoryYourWeekCountsIt,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        AppCard(
          variant: AppCardVariant.sage,
          gap: 10,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    // Fewer points than a live session, and the number comes
                    // from the rewards group rather than from this widget.
                    l10n.n15Points,
                    style: AppText.display.copyWith(
                      fontSize: 32,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
              ],
            ),
            AppProgressBar(percent: levelProgressPercent),
          ],
        ),
        // Open on the page under a rule, as on R10: the points are the slip,
        // the week is the page's own line.
        const HandRule(seed: 27, height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.thisWeek, style: AppText.titleM)),
                Text(
                  // The same two numbers the segments below are drawn from.
                  //
                  // This was the fixed `n2Of3`, so the sentence and the bar
                  // disagreed for every woman whose week was not the
                  // prototype's: four segments under the words "2 of 3".
                  l10n.countOfTotal(
                    countLabel(sessionsThisWeek),
                    countLabel(sessionsPrescribed),
                  ),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppWeekSegments(
              total: sessionsPrescribed,
              filled: sessionsThisWeek,
            ),
            const SizedBox(height: 10),
            // "One more session and this week counts" states the figure 1,
            // and it was drawn beside her real "1 of 4". `statedLine` renders
            // it only to the woman it is true of and nothing at all to anyone
            // else, which is the arrangement four other screens already use.
            if (statedLine(
                  l10n.oneMoreSessionAndThisWeekCounts,
                  states: 1,
                  hers: sessionsPrescribed - sessionsThisWeek,
                )
                case final String line)
              Text(
                line,
                style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
              ),
          ],
        ),
        // Where the trophy would have been.
        if (!mayShowPersonalBest)
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, size: 22, color: AppColors.primaryDim),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.noPersonalBestFromThisOneThe,
                      style: AppText.bodyM.copyWith(height: 22 / 15),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
