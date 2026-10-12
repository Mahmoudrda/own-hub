/// Y08 — Calendar.
///
/// Matches `screens-cycle.mjs` → `Y08`.
///
/// ## Colour is never the only signal
///
/// `P0-CYC-12`: "Logged days are solid with a text label, estimates are dashed
/// and labelled 'est.'. Colour is never the only signal."
///
/// Three independent signals per cell, and the widget cannot drop any of them
/// because [CalendarCell] cannot be constructed without all three: the fill, a
/// visible text label under the number, and a `Semantics` label for a screen
/// reader. The estimated cells are additionally **dashed rather than filled**,
/// so they differ in shape as well as in colour and in text.
///
/// The dashed cell's short label is **"est."** — `est` now exists, so the cell
/// carries the abbreviation the design draws while its `Semantics` label keeps
/// the whole word, which is the pair `P0-CYC-12` asks for. The header reads
/// `Fri` beside its six neighbours for the same reason: `fri` exists now, and
/// one full weekday name among six abbreviations was the visible seam it left.
///
/// ## One string this screen still does not have
///
/// The month title is the fixed `September 2026`, and no month name beyond
/// `September` and `June` exists in the dictionary. So any other month renders
/// as `yyyy-MM` numerals, which are values rather than copy (the rule
/// `number_label.dart` sets out) instead of a month name the dictionary cannot
/// supply.
///
/// And the next-period sentence — "Next period estimate: 12 to 14 October" —
/// is fixed too, with the prototype's dates inside it. It is **not rendered**;
/// see the estimate card below. All three are reported rather than invented.
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/cycle_document.dart';
import '../domain/period_entry.dart';
import 'calendar/cycle_calendar_view_model.dart';
import 'cycle_widgets.dart';

class CycleCalendarView extends StatelessWidget {
  const CycleCalendarView({
    super.key,
    required this.cycle,
    required this.year,
    required this.month,
    this.periods = const <PeriodEntry>[],
    this.checkInDays = const <String>{},
    this.now,
    this.viewModel = const CycleCalendarViewModel(),
    this.onBack,
    this.onSettings,
    this.onLogPeriod,
    this.onAboutPhases,
    this.onSelectTab,
    this.onSelectCycleTab,
    this.onPreviousMonth,
    this.onNextMonth,
  });

  final CycleDocument? cycle;
  final int year;
  final int month;
  final List<PeriodEntry> periods;
  final Set<String> checkInDays;
  final DateTime? now;
  final CycleCalendarViewModel viewModel;

  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onLogPeriod;
  final VoidCallback? onAboutPhases;
  final ValueChanged<String>? onSelectTab;
  final ValueChanged<CycleTab>? onSelectCycleTab;

  /// Steps the calendar a month back or forward. Null draws no arrows, which
  /// is how the one-month calendar looked before a period could be logged in
  /// a month other than this one.
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final snapshot = viewModel.build(
      year: year,
      month: month,
      cycle: cycle,
      periods: periods,
      checkInDays: checkInDays,
      today: now ?? AppClock.now(),
      labels: CalendarLabels(
        // "day 1" exists as a fixed string only; any other day renders its
        // number rather than a sentence naming the wrong one.
        periodDay: (day) => day == 1 ? l10n.day1 : '$day',
        // The whole word for a screen reader, the abbreviation for the cell.
        estimated: l10n.estimated,
        estimatedShort: l10n.est,
        today: l10n.today_554hp,
        logged: l10n.notedByYou,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CycleNavBar(
        screenId: 'Y08',
        onSelectTab: onSelectTab,
      ),
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.cycleSettings,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.settings),
            onPressed: onSettings,
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          CycleTabs(
            active: CycleTab.calendar,
            showCalendar: true,
            onSelect: onSelectCycleTab,
          ),
          if (onPreviousMonth == null && onNextMonth == null)
            Text(_monthTitle(l10n), style: AppText.titleM)
          else
            Row(
              children: [
                // Material's own tooltips: localised in both languages, and
                // no new dictionary strings for two arrows.
                IconButton(
                  tooltip: MaterialLocalizations.of(context)
                      .previousMonthTooltip,
                  color: AppColors.onSurfaceVariant,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPreviousMonth,
                ),
                Expanded(
                  child: Text(
                    _monthTitle(l10n),
                    textAlign: TextAlign.center,
                    style: AppText.titleM,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                  color: AppColors.onSurfaceVariant,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNextMonth,
                ),
              ],
            ),
          _WeekdayHeader(l10n: l10n),
          _Grid(cells: snapshot.cells),
          _Legend(l10n: l10n),
          if (snapshot.estimate != null)
            AppCard(
              variant: AppCardVariant.filled,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              children: [
                // The dashed, labelled cells above ARE the range. The
                // dictionary's "Next period estimate: 12 to 14 October" is a
                // fixed string with the mockup's dates baked in, so rendering
                // it would tell every woman those two dates whatever her own
                // cycles say — the defect PHASE1-FIXES.md #3 and #13 record on
                // five screens. It waits for a parameterised {from}/{to} form.
                //
                // What renders instead is true for everyone and is a required
                // string rather than decoration (plan §12).
                Text(
                  l10n.cycleDatesAreEstimatesThisFeatureIs,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.noteAPeriod,
                  height: 48,
                  fontSize: 15,
                  onPressed: onLogPeriod,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  l10n.aboutCyclePhases,
                  variant: AppButtonVariant.outlined,
                  height: 48,
                  fontSize: 15,
                  onPressed: onAboutPhases,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The month name where the dictionary has one, numerals otherwise.
  String _monthTitle(AppL10n l10n) {
    if (year == 2026 && month == DateTime.september) return l10n.september2026;
    return '$year-${month.toString().padLeft(2, '0')}';
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    // Seven abbreviations, at last. This row read M T W T **Friday** S S while
    // `fri` was missing, which is the kind of seam a reader notices before any
    // test does.
    final days = <String>[
      l10n.mon,
      l10n.tue,
      l10n.wed,
      l10n.thu,
      l10n.fri,
      l10n.sat,
      l10n.sun,
    ];

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: AppText.nav.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cells});

  final List<CalendarCell> cells;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Today's ring runs a hair outside its cell; a grid that never scrolls
      // has nothing to clip.
      clipBehavior: Clip.none,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1,
      children: [for (final cell in cells) _Cell(cell: cell)],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final CalendarCell cell;

  @override
  Widget build(BuildContext context) {
    if (cell.isBlank) return const SizedBox.shrink();

    final logged = cell.kind == CalendarDayKind.logged;
    final estimated = cell.kind == CalendarDayKind.estimated;
    final isToday = cell.kind == CalendarDayKind.today;

    // A cell is a fixed square, so its figures scale with it rather than with
    // the system text size, which would push them out of the square.
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${cell.dayOfMonth}',
            style: AppText.bodyM.copyWith(
              color: logged ? AppColors.onPrimary : AppColors.onSurface,
              fontWeight: logged || estimated || isToday
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
          if (cell.label.isNotEmpty)
            Text(
              cell.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.nav.copyWith(
                fontSize: 10,
                color: logged
                    ? AppColors.onPrimary
                    : AppColors.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );

    // As on a paper calendar: a logged day is filled in solid, an estimate is
    // only pencilled in — dashed, as `P0-CYC-12` asks, and labelled — and
    // today is circled in ink. The grid itself stays exact, so the fills and
    // the dashes are drawn clean and only the circle shows a hand.
    final seed = handSeed(['cal', cell.dayOfMonth, cell.kind.index]);
    final Widget marked = switch (cell.kind) {
      CalendarDayKind.logged => HandSurface(
        seed: seed,
        fill: AppColors.onPrimaryContainer,
        level: HandLevel.structural,
        radius: 4,
        looseCorner: 10,
        child: content,
      ),
      CalendarDayKind.estimated => HandSurface(
        seed: seed,
        frame: AppColors.onPrimaryContainer,
        frameWidth: 1.5,
        dashed: true,
        level: HandLevel.structural,
        radius: 4,
        looseCorner: 10,
        child: content,
      ),
      CalendarDayKind.checkIn => HandSurface(
        seed: seed,
        fill: AppColors.surfaceContainer,
        level: HandLevel.structural,
        radius: 4,
        looseCorner: 10,
        child: content,
      ),
      CalendarDayKind.today => HandCircled(
        seed: seed,
        color: AppColors.primary,
        width: HandStroke.pen,
        level: HandLevel.crafted,
        inflate: const EdgeInsets.all(1),
        drawOn: true,
        child: content,
      ),
      _ => content,
    };

    return Semantics(
      label: cell.semanticLabel.isEmpty ? null : cell.semanticLabel,
      child: marked,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    // This was a Row, and it overflowed by 30 pixels the first time the screen
    // was rendered in a widget test rather than reasoned about. A legend that
    // runs off the edge takes the meaning of the cells with it — and this is
    // the screen where colour is explicitly not allowed to be the only signal,
    // so the key to the other signals had better be readable.
    //
    // Two items that wrap, like `AppChipRow(grow: false)`: Arabic runs longer
    // than English and the largest system text size longer still, and neither
    // has anywhere to go in a fixed Row.
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendItem(filled: true, label: l10n.notedByYou),
        _LegendItem(filled: false, label: l10n.estimated),
      ],
    );
  }
}

/// One swatch and its word. Solid for logged, dashed for estimated — the same
/// two shapes the cells use.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.filled, required this.label});

  final bool filled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The key is drawn the way the cells are, or it would not be a key.
        SizedBox.square(
          dimension: 14,
          child: HandSurface(
            seed: handSeed(['legend', filled]),
            fill: filled ? AppColors.onPrimaryContainer : null,
            frame: filled ? null : AppColors.onPrimaryContainer,
            frameWidth: 1.5,
            dashed: !filled,
            level: HandLevel.structural,
            radius: 2,
            looseCorner: 5,
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: AppText.bodyM)),
      ],
    );
  }
}
