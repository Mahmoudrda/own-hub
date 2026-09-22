/// R10 — Finished.
///
/// Matches `6-v2/src/screens-train.mjs` → `R10`. **The one celebration.**
/// Confetti lives here and nowhere else in the product, because a celebration
/// that happens everywhere stops being one.
///
/// What she earned is named in the order she cares about: that it counted, how
/// close the week is, and what she beat. Sharing is a quiet text link rather than
/// a second button — offering a post at the peak moment is a second decision on a
/// screen that should have none.
///
/// The points, the total and the personal best are all read from the rewards
/// group. This screen renders them and computes none of them: a widget that did
/// its own arithmetic would be a second, quieter definition of what a session is
/// worth.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import '../domain/train_repository.dart';

class FinishedView extends StatelessWidget {
  const FinishedView({
    super.key,
    this.onBackToToday,
    this.onShare,
    this.session,
    this.sessionsThisWeek = 2,
    this.sessionsPrescribed = 3,
    this.levelProgressPercent = 50,
    this.eligibility = const PersonalBestEligibility(),
  });

  final VoidCallback? onBackToToday;

  /// Community. Hands over an intent only — no post is written from here.
  final VoidCallback? onShare;

  /// The session just finished. Decides whether a personal best may be shown at
  /// all: only a measured live session can set one.
  final TrainSession? session;

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

    // A live session may show the trophy. A recalled or unplanned one never
    // can — the numbers were copied or absent, not measured.
    final mayShowPersonalBest =
        session == null || eligibility.isEligible(session!);

    return AppScaffold(
      footer: [
        AppButton(l10n.backToToday, onPressed: onBackToToday),
        AppButton(
          l10n.shareTheSquatWithYourGroup,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: onShare,
        ),
      ],
      children: [
        const SizedBox(height: 6),
        // A finished session is the one unambiguously good moment in this
        // product, and it was the only one carried entirely by type. The
        // drawing is decorative -- the heading already says what happened, so
        // it is excluded from semantics rather than read aloud.
        Center(child: AppArt.image(AppArt.strongArms, size: 128)),
        const SizedBox(height: 12),
        // Ticked off in sage beside the heading — done, not won — drawn on
        // once, as the page arrives.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(l10n.thatsTuesdayDone, style: AppText.display),
            ),
            const SizedBox(width: 12),
            const HandTick(
              size: 52,
              seed: 11,
              drawOn: true,
              delay: Duration(milliseconds: 240),
            ),
          ],
        ),
        // The week leads — a circle per session, the one she just did
        // ticked — because the week is what this product counts. The points
        // are a note in the margin, not the headline.
        const HandRule(seed: 23, height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.thisWeek, style: AppText.titleM)),
                Text(
                  // The same two numbers the marks below are drawn from.
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
            const SizedBox(height: 12),
            AppWeekSegments(
              total: sessionsPrescribed,
              filled: sessionsThisWeek,
              style: WeekStyle.marks,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.oneMoreSessionAndThisWeekCounts,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        // The points, written in the margin in sage, with the level they
        // count toward as a thin line beside them.
        // Her points and the bar they moved, side by side until the text is
        // turned up: the note is hand-painted at its own size, so past 1.3x it
        // takes the whole line and the bar goes under it rather than off the
        // edge of the page.
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3) ...[
          HandNote(l10n.n30Points, size: 22, color: AppColors.tertiary),
          const SizedBox(height: 10),
          AppProgressBar(percent: levelProgressPercent, height: 5),
        ] else
          Row(
            children: [
              HandNote(l10n.n30Points, size: 22, color: AppColors.tertiary),
              const SizedBox(width: 16),
              Expanded(
                child: AppProgressBar(percent: levelProgressPercent, height: 5),
              ),
            ],
          ),
        if (mayShowPersonalBest)
          AppCard(
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 24,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.aPersonalBest, style: AppText.titleM),
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
}
