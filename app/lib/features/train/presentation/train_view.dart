/// R01 — Train.
///
/// Matches `6-v2/src/screens-train.mjs` → `R01`. The tab opens on the one thing
/// she is in the middle of, with the week drawn as three chips she can tap. Short
/// sessions sit **above** the library because a ten-minute floor session is what
/// gets done on a bad day, and it counts the same as any other.
///
/// Two notes carried from the plan, neither of them mine to resolve here:
///
///  * **OQ-12.** In the prototype "Continue · from Sara" routes to `G06`, the
///    coached session screen, for *every* woman — including the ones who have no
///    coach. The plan records this as an open finding rather than a bug to fix
///    inside the screen, so the destination is a callback: the router decides
///    whether she goes to her coach's session or to R03, and this screen does not
///    pretend to know.
///  * The week ring and the chips render values the rewards group owns. This
///    screen displays them and computes none of them.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';

/// One of the three short sessions offered above the library.
class ShortSession {
  const ShortSession({
    required this.duration,
    required this.constraint,
    this.onTap,
  });

  /// "10 min".
  final String duration;

  /// What makes it possible today — "Floor only", "Quiet".
  final String constraint;

  final VoidCallback? onTap;
}

class TrainView extends StatelessWidget {
  const TrainView({
    super.key,
    this.onSearch,
    this.onContinue,
    this.onSeeProgram,
    this.onOpenToday,
    this.onGentlerOption,
    this.onFollowAlong,
    this.onShortSession,
    this.onSelectTab,
    this.shortSessions,
    this.programTitle,
    this.programWeek,
    this.sessionsThisWeek = 2,
    this.sessionsPrescribed = 3,
  });

  final VoidCallback? onSearch;

  /// See OQ-12 above. The router owns where this goes.
  final VoidCallback? onContinue;

  final VoidCallback? onSeeProgram;
  final VoidCallback? onOpenToday;
  final VoidCallback? onGentlerOption;

  /// The timed follow-along short session — `R06`.
  ///
  /// The design puts this on the FIRST of the three "Short ones that still
  /// count" tiles, and only that one: a follow-along logs itself as the timer
  /// runs out, which is why R06's own note reads "0 taps to log". The other two
  /// are ordinary sessions and open the workout day.
  ///
  /// All three tiles rendered with no `onTap` at all, so R06 was built,
  /// routable, and reachable by nobody.
  final VoidCallback? onFollowAlong;

  /// The other short sessions — an ordinary workout day, `R03`.
  final VoidCallback? onShortSession;

  final ValueChanged<String>? onSelectTab;

  /// Injectable so the real library can supply these later.
  final List<ShortSession>? shortSessions;

  final String? programTitle;
  final String? programWeek;

  final int sessionsThisWeek;
  final int sessionsPrescribed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final shorts =
        shortSessions ??
        [
          ShortSession(
            duration: l10n.n10Min,
            constraint: l10n.floorOnly,
            onTap: onFollowAlong,
          ),
          ShortSession(
            duration: l10n.n15Min,
            constraint: l10n.quiet,
            onTap: onShortSession,
          ),
          ShortSession(
            duration: l10n.n20Min,
            constraint: l10n.dumbbells,
            onTap: onShortSession,
          ),
        ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'R01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          // The section's own page: its name set large with one swipe of
          // marker behind it. The programme sheet below is what she opens.
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MarkerHighlight(
                    drawOn: true,
                    child: Text(l10n.train, style: EditorialType.section),
                  ),
                ),
              ),
              // The section's drawings sit beside its name, as on a cover,
              // rather than in a strip above it.
              const ScreenArtInline(),
              IconButton(
                onPressed: onSearch,
                iconSize: 24,
                color: AppColors.onSurfaceVariant,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          AppCard(
            gap: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          programTitle ?? l10n.postpartumRebuild,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 1),
                        // Her week, or nothing.
                        //
                        // This read `programWeek ?? week3Of8`, so it
                        // stated "Week 3 of 8" precisely when the real week was
                        // unknown — a fallback whose only job was to fill the
                        // gap with the prototype's number. Saying nothing is
                        // the honest reading of not knowing.
                        if (programWeek != null)
                          Text(programWeek!, style: AppText.titleL),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Her week the way every week is drawn in this product —
                  // a circle per session, ticked when done, the next one
                  // ringed in ink — rather than a ring of its own here.
                  SizedBox(
                    width: 136,
                    child: AppWeekSegments(
                      total: sessionsPrescribed,
                      filled: sessionsThisWeek,
                      style: WeekStyle.marks,
                    ),
                  ),
                ],
              ),
              // The week as three chips she can tap. Composed from AppChip
              // rather than AppChipRow because each one has its own action and
              // its own selected state, which a shared index cannot express.
              Row(
                children: [
                  Expanded(child: AppChip(l10n.mon_4jow1, selected: true)),
                  const SizedBox(width: 8),
                  Expanded(child: AppChip(l10n.today, onTap: onOpenToday)),
                  const SizedBox(width: 8),
                  Expanded(child: AppChip(l10n.thu)),
                ],
              ),
              AppButton(
                // "Continue · from Sara" credits a coach. In a build with
                // no coaching there is no Sara and nobody wrote this
                // programme for her, so the button says what it does. The
                // credit comes back with the feature.
                AppRouter.featureFlags.isOn(Feature.coachedLife)
                    ? l10n.continueFromSara
                    : l10n.continueLabel,
                icon: Icons.play_arrow,
                onPressed: onContinue,
              ),
              AppButton(
                l10n.seeTheWholeProgram,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: onSeeProgram,
              ),
            ],
          ),
          Text(l10n.shortOnesThatStillCount, style: AppText.titleM),
          // IntrinsicHeight so the three tiles match each other's height —
          // "Floor only" and "Dumbbells" wrap to different line counts in
          // Arabic, and three cards of different heights read as a mistake.
          //
          // It is needed rather than decorative: CrossAxisAlignment.stretch in a
          // scroll view asks the Row to fill an unbounded height, which is a
          // layout assertion rather than a stretched card.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shorts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _ShortSessionTile(session: shorts[i])),
                ],
              ],
            ),
          ),
          // The library is a second, quieter section of the page.
          const HandRule(seed: 41, height: 14),
          Row(
            children: [
              Expanded(child: Text(l10n.allWorkouts, style: AppText.titleM)),
              // `n124Videos` — "124 videos" — is the size of a library
              // `WorkoutVideoRepository` says has not been produced: every
              // `urlFor` returns null and every tile below draws a placeholder.
              // A count beside a list that contradicts it is worse than no
              // count.
            ],
          ),
          // Filters wrap rather than scroll: a constraint she has — "quiet",
          // "no equipment" — must never sit off the edge of the screen where she
          // will not find it.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(l10n.quiet, icon: Icons.volume_off, onTap: onSearch),
              AppChip(l10n.noEquipment, onTap: onSearch),
              AppChip(l10n.n10Min, onTap: onSearch),
            ],
          ),
          AppListItem(
            title: l10n.notFeelingItToday,
            subtitle: l10n.seeAGentlerOptionBasedOnYour,
            leading: const Icon(
              Icons.self_improvement,
              size: 24,
              color: AppColors.primaryDim,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: onGentlerOption,
          ),
        ],
      ),
    );
  }
}

class _ShortSessionTile extends StatelessWidget {
  const _ShortSessionTile({required this.session});

  final ShortSession session;

  @override
  Widget build(BuildContext context) {
    // Three slips of the page rather than three more cards under the
    // programme sheet: a faint tint, framed in pencil, pressed in when tapped.
    return HandSurface(
      seed: handSeed(['short', session.duration, session.constraint]),
      fill: AppColors.surfaceLow,
      frame: AppColors.outline.withValues(alpha: 0.5),
      frameWidth: 1,
      radius: 5,
      looseCorner: 14,
      onTap: session.onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.duration,
            style: AppText.label.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session.constraint,
            style: AppText.label.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
