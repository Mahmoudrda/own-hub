/// Y08's month grid — where "logged" and "estimated" must be distinguishable
/// **without colour**.
///
/// `P0-CYC-12`: "Logged days are solid with a text label, estimates are dashed
/// and labelled 'est.'. Colour is never the only signal. The estimate is stated
/// as a range with its reason, and no day is labelled confirmed ovulation."
///
/// So every cell carries three independent signals and the widget is not free to
/// drop any of them:
///
///  * [CalendarCell.kind] — the fill, which is the colour signal;
///  * [CalendarCell.label] — a short visible text label under the number;
///  * [CalendarCell.semanticLabel] — what a screen reader announces.
///
/// A cell cannot be constructed without all three, which is what stops "we will
/// add the text label later" from ever being a state this screen ships in.
///
/// ## Estimates are absent, not empty
///
/// When [ForecastPolicy] is off — symptom-only mode, or a context flag that
/// removes forecasting — there are no estimated cells at all and no "next
/// period" line. §3.1: the calendar "shows logged days only; dashed cells and
/// the 'next period' line are absent, with the reason on screen". The screen
/// says why rather than quietly widening the range.
library;

import 'package:meta/meta.dart';

import '../../domain/cycle_document.dart';
import '../../domain/period_entry.dart';
import 'phase_estimator.dart';

/// What a day cell is showing.
enum CalendarDayKind {
  /// Padding before the first of the month. Carries no number.
  blank,

  /// An ordinary day.
  plain,

  /// She logged a period on this day. Solid.
  logged,

  /// Estimated. Dashed, and labelled.
  estimated,

  /// Today. Outlined.
  today,

  /// A day with a check-in but no period.
  checkIn,
}

/// One cell of the month grid.
@immutable
class CalendarCell {
  const CalendarCell({
    required this.kind,
    required this.date,
    required this.dayOfMonth,
    required this.label,
    required this.semanticLabel,
    this.periodDay,
  });

  /// The blank padding cell before the first of the month.
  const CalendarCell.blank()
    : kind = CalendarDayKind.blank,
      date = null,
      dayOfMonth = null,
      label = '',
      semanticLabel = '',
      periodDay = null;

  final CalendarDayKind kind;
  final DateTime? date;
  final int? dayOfMonth;

  /// The short text under the number — "day 1", "est.", "today".
  ///
  /// Empty for a plain day, which has nothing to say beyond its number.
  final String label;

  /// What a screen reader announces for this cell.
  final String semanticLabel;

  /// Which day of the period this is, when [kind] is [CalendarDayKind.logged].
  final int? periodDay;

  bool get isBlank => kind == CalendarDayKind.blank;
}

/// Everything Y08 renders for one month.
@immutable
class CycleCalendarSnapshot {
  const CycleCalendarSnapshot({
    required this.year,
    required this.month,
    required this.cells,
    required this.estimate,
    required this.showsEstimates,
  });

  final int year;
  final int month;

  /// Leading blanks, then one cell per day of the month.
  final List<CalendarCell> cells;

  /// The next-period estimate, or null when there is nothing to estimate from
  /// or forecasting is off.
  final EstimateRange? estimate;

  /// Whether this month may show estimates at all.
  ///
  /// False in symptom-only mode and whenever a context flag removed
  /// forecasting. When false, [estimate] is null and **no cell is
  /// [CalendarDayKind.estimated]** — asserted in the view model rather than
  /// left to the widget.
  final bool showsEstimates;

  /// The logged cells, for tests and for the legend's count.
  List<CalendarCell> get loggedCells =>
      cells.where((c) => c.kind == CalendarDayKind.logged).toList();

  List<CalendarCell> get estimatedCells =>
      cells.where((c) => c.kind == CalendarDayKind.estimated).toList();
}

/// The labels the grid needs, passed in from the localised layer.
///
/// The view model builds text labels, and text belongs to the dictionary — so
/// the strings arrive here rather than being written here. That keeps the view
/// model testable without a widget tree while still keeping `AppL10n` the only
/// source of copy.
@immutable
class CalendarLabels {
  const CalendarLabels({
    required this.periodDay,
    required this.estimated,
    required this.estimatedShort,
    required this.today,
    required this.logged,
  });

  /// "day 1" — takes the day number.
  final String Function(int day) periodDay;

  /// The word a screen reader announces on a dashed cell — "Estimated".
  ///
  /// Separate from [estimatedShort] because the two audiences need different
  /// text and a single field would have to fail one of them: a 36pt cell has
  /// room for "est." and not for "Estimated", while "est." read aloud is not a
  /// word. `P0-CYC-12` requires both signals, so both are stored.
  final String estimated;

  /// The short label printed under the number. The design draws **"est."**.
  final String estimatedShort;

  /// The label on today's cell.
  final String today;

  /// The screen-reader word for a solid cell — "Logged by you".
  final String logged;
}

class CycleCalendarViewModel {
  const CycleCalendarViewModel({this.estimator = const PhaseEstimator()});

  final PhaseEstimator estimator;

  /// Builds one month.
  ///
  /// [today] is passed rather than read from a clock so the grid is
  /// deterministic in a test. This is the calendar, not the suggestion path —
  /// rule 4's ban on a clock applies to `SymptomSuggestionResolver.resolve`.
  CycleCalendarSnapshot build({
    required int year,
    required int month,
    required CycleDocument? cycle,
    required List<PeriodEntry> periods,
    required Set<String> checkInDays,
    required DateTime today,
    required CalendarLabels labels,
  }) {
    final showsEstimates = ForecastPolicy.isEnabled(cycle);

    final estimate = showsEstimates
        ? estimator.estimateNextStart(
            recentStarts: cycle?.recentStarts ?? const <String>[],
            statedCycleLength: cycle?.cycleLengthDays,
          )
        : null;

    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Monday-first, matching the M T W T F S S header the design draws.
    final leadingBlanks = first.weekday - DateTime.monday;

    final cells = <CalendarCell>[
      for (var i = 0; i < leadingBlanks; i++) const CalendarCell.blank(),
    ];

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final period = _periodCovering(periods, date);
      final isToday = _sameDay(date, today);

      if (period != null) {
        final number = period.dayNumberOn(date)!;
        cells.add(
          CalendarCell(
            kind: CalendarDayKind.logged,
            date: date,
            dayOfMonth: day,
            label: labels.periodDay(number),
            semanticLabel: '${labels.logged} · ${labels.periodDay(number)}',
            periodDay: number,
          ),
        );
        continue;
      }

      if (estimate != null && estimate.covers(date)) {
        cells.add(
          CalendarCell(
            kind: CalendarDayKind.estimated,
            date: date,
            dayOfMonth: day,
            label: labels.estimatedShort,
            semanticLabel: labels.estimated,
          ),
        );
        continue;
      }

      if (isToday) {
        cells.add(
          CalendarCell(
            kind: CalendarDayKind.today,
            date: date,
            dayOfMonth: day,
            label: labels.today,
            semanticLabel: labels.today,
          ),
        );
        continue;
      }

      if (checkInDays.contains(isoDay(date))) {
        cells.add(
          CalendarCell(
            kind: CalendarDayKind.checkIn,
            date: date,
            dayOfMonth: day,
            label: '',
            semanticLabel: '',
          ),
        );
        continue;
      }

      cells.add(
        CalendarCell(
          kind: CalendarDayKind.plain,
          date: date,
          dayOfMonth: day,
          label: '',
          semanticLabel: '',
        ),
      );
    }

    return CycleCalendarSnapshot(
      year: year,
      month: month,
      cells: cells,
      estimate: estimate,
      showsEstimates: showsEstimates,
    );
  }

  PeriodEntry? _periodCovering(List<PeriodEntry> periods, DateTime date) {
    for (final period in periods) {
      if (period.covers(date)) return period;
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
