/// G05 — your 30 days, from **one** document.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G05`. Its design note: *"Four full
/// weeks plus two days, with rest days placed on purpose rather than left
/// blank."*
///
/// ## Why this screen is a grid and not a list of days
///
/// `P0-COACH-07`: "Firestore reads for this screen are 1 or 0 (cached), never
/// 30." The cells come from `versions/{v}.calendar[30]` — one field on one
/// document — via `CoachedPlanReader.calendar()`, which the repository test
/// measures. A list that fetched each day would look identical here and cost
/// thirty times as much every time she opened it.
///
/// ## Three kinds of day, and they are not interchangeable
///
///  * **train** — she has a session.
///  * **rest** — her coach planned a rest day. Placed on purpose.
///  * **free** — her coach left the day to her. Different from rest, and it
///    renders differently, because "nothing planned" and "rest" are different
///    instructions.
///
/// `done` is separate from all three: it comes from her own logs, never from
/// the plan. A day the plan asked for is not a day she did.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coached_repository.dart';
import '../domain/g2_contract.dart';
import 'coached_widgets.dart';

class ThirtyDaysView extends StatelessWidget {
  const ThirtyDaysView({
    super.key,
    this.onBack,
    this.onInfo,
    this.onOpenDay,
    this.onOpenSubscription,
    this.onSelectTab,
    this.days,
    this.dateRange,
    this.dayLabel,
    this.subscriptionLabel,
  });

  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final ValueChanged<PlanDay>? onOpenDay;
  final VoidCallback? onOpenSubscription;
  final ValueChanged<String>? onSelectTab;

  /// The thirty cells. Null renders the mockup's shape for the standalone
  /// preview of this screen.
  final List<PlanDay>? days;

  final String? dateRange;
  final String? dayLabel;

  /// "Subscription · 12 Sep to 11 Oct", when her dates are known.
  final String? subscriptionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final cells = days ?? _previewDays();

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachedNavBar(onSelectTab: onSelectTab),
      body: AppScaffold(
        appBar: AppTopBar(
          title: l10n.your30Days,
          onBack: onBack,
          actions: [
            IconButton(
              onPressed: onInfo,
              iconSize: 22,
              color: AppColors.onSurfaceVariant,
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        children: [
          Row(
            children: [
              // "8 Sep to 7 Oct 2026" and "Day 9" are the prototype's month
              // and the prototype's ninth day. A woman on day two of a month
              // that starts in November is told neither rather than both.
              Expanded(
                child: dateRange == null
                    ? const SizedBox.shrink()
                    : Text(
                        dateRange!,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
              ),
              if (dayLabel case final day?)
                AppPill(
                  day,
                  background: AppColors.surfaceContainer,
                  foreground: AppColors.onSurfaceVariant,
                ),
            ],
          ),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            // Taller than it looks like it needs to be. A cell holds two lines
            // — the day number and its kind — and at 1.35 the second one
            // overflowed by 6.5 pixels on a 390-wide phone before a single
            // word of Arabic or a raised text size was involved. The grid is
            // fixed-ratio, so the ratio is where the headroom has to live.
            childAspectRatio: 1.12,
            children: [
              for (final day in cells)
                _DayCell(
                  day: day,
                  // A free day renders its number with **no sub-label**.
                  //
                  // The dictionary has no word for "your coach left this day to
                  // you". The nearest candidate, `somethingFree`, means free of
                  // charge elsewhere in the product, and borrowing it would put
                  // "Something free" on a training calendar. Reported as a
                  // missing string rather than invented: an empty cell that
                  // says nothing is honest, and a cell that says the wrong
                  // thing is not.
                  label: switch (day.kind) {
                    PlanDayKind.rest => l10n.rest,
                    PlanDayKind.train =>
                      day.done ? l10n.done : l10n.train_556cm,
                    PlanDayKind.free => '',
                  },
                  onTap: onOpenDay == null ? null : () => onOpenDay!(day),
                ),
            ],
          ),
          // A key that wraps, so neither word runs off the page at the
          // largest text size.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(child: Text(l10n.completed, style: AppText.bodyM)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.self_improvement,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Flexible(child: Text(l10n.restDay, style: AppText.bodyM)),
                ],
              ),
            ],
          ),
          AppListItem(
            // "Subscription · 8 Sep to 7 Oct" dates a month that is not
            // hers. Where the range is known the row names it; where it is
            // not, the row leads with the question it answers.
            title: subscriptionLabel ?? l10n.whatHappensWhenItEnds,
            subtitle: subscriptionLabel == null
                ? ''
                : l10n.whatHappensWhenItEnds,
            onTap: onOpenSubscription,
            leading: const Icon(
              Icons.event_available,
              size: 22,
              color: AppColors.primaryDim,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// The mockup's month, for the standalone preview only.
  static List<PlanDay> _previewDays() {
    const rest = {3, 7, 10, 14, 17, 21, 24, 28};
    final start = DateTime(2026, 9, 8);
    return [
      for (var n = 1; n <= PlanVersion.calendarLength; n++)
        PlanDay(
          dayNumber: n,
          kind: rest.contains(n) ? PlanDayKind.rest : PlanDayKind.train,
          date: start.add(Duration(days: n - 1)),
          done: n < 9,
          isToday: n == 9,
        ),
    ];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.label, this.onTap});

  final PlanDay day;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Done means a session trained. A rest day is its own state, marked the
    // way the legend marks it, never with the tick a finished session owns.
    final trained = day.done && day.kind == PlanDayKind.train;
    final rest = day.kind == PlanDayKind.rest;
    final background = day.isToday
        ? AppColors.primary
        : trained
        ? AppColors.tertiaryContainer
        : AppColors.surfaceLowest;
    final foreground = day.isToday
        ? AppColors.onPrimary
        : trained
        ? AppColors.onTertiaryContainer
        : AppColors.onSurface;

    // A calendar kept by hand: today inked in, done days on sage, the rest
    // on white paper framed in pencil. Every cell is cut a little
    // differently, so the month reads as a page rather than a grid of tiles.
    return HandSurface(
      seed: handSeed(['plan-day', day.dayNumber]),
      fill: background,
      frame: day.isToday || trained
          ? null
          : AppColors.outline.withValues(alpha: 0.38),
      frameWidth: 1,
      radius: 4,
      looseCorner: 11,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      // A day is a fixed cell of the month; its figures scale with it rather
      // than spilling out at the largest text size.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${day.dayNumber}',
              style: AppText.label.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
            // A done day is ticked, as she would tick it on a paper
            // calendar; the word stays beside the tick for anyone not
            // reading marks.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trained) ...[
                  HandTick(size: 12, seed: day.dayNumber, color: foreground),
                  const SizedBox(width: 3),
                ] else if (rest) ...[
                  Icon(Icons.self_improvement, size: 12, color: foreground),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyM.copyWith(
                    color: foreground.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
