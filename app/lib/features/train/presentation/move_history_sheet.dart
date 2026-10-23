/// Her last sessions of one move: the date, the sets she logged, and a bar for
/// the best set of each.
///
/// Opened from the live set screen, the move's page and the bests page. It
/// reads [moveHistory], so a discarded workout is never in it. The bars are
/// drawn here rather than by `WeekBarsChart`, whose three fixed heights say
/// "counted or not"; these have to show how much, so they scale to the best
/// figure on show.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/date_label.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../domain/set_history.dart';
import 'set_labels.dart';

/// "40 kg × 10", "12 reps" or "45 s", in her language with Western digits.
String outcomeLabel(AppL10n l10n, SetOutcome outcome) {
  final hold = outcome.holdSeconds;
  if (outcome.reps == null && hold != null) {
    return measuredLabel(l10n, holdSeconds: hold);
  }
  final kg = outcome.weightKg;
  return measuredLabel(
    l10n,
    weightKg: kg != null && kg > 0 ? kg : null,
    reps: outcome.reps ?? 0,
  );
}

/// The date of a `yyyy-MM-dd` key as words, or '' when it is not one.
String sessionDateLabel(AppL10n l10n, String dateKey) {
  final date = DateTime.tryParse(dateKey);
  return date == null ? '' : dayMonthYearLabel(l10n, date);
}

/// How big a set is for the bar: the weight when there is one, else the reps,
/// else the seconds.
double barFigure(SetOutcome? set) {
  if (set == null) return 0;
  final kg = set.weightKg ?? 0;
  if (kg > 0) return kg;
  return (set.reps ?? set.holdSeconds ?? 0).toDouble();
}

Future<void> showMoveHistorySheet(
  BuildContext context, {
  required String moveName,
  required List<MoveSessionHistory> history,
}) {
  return showAppSheet<void>(
    context: context,
    children: [
      MoveHistoryBody(moveName: moveName, history: history),
      Builder(
        builder: (sheet) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppButton(
            AppL10n.of(sheet).close,
            key: const ValueKey('move-history-close'),
            variant: AppButtonVariant.text,
            height: 48,
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ),
      ),
    ],
  );
}

/// The sheet's content, newest session first.
class MoveHistoryBody extends StatelessWidget {
  const MoveHistoryBody({
    super.key,
    required this.moveName,
    required this.history,
  });

  final String moveName;
  final List<MoveSessionHistory> history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(header: true, child: Text(moveName, style: AppText.titleL)),
        const SizedBox(height: 4),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.noSessionsOfThisMoveYet,
              key: const ValueKey('move-history-empty'),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          )
        else ...[
          Text(
            l10n.yourLastSessionsOfThisMove,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _BestBars(history: history),
          const SizedBox(height: 8),
          for (final row in history) _HistoryRow(row: row),
        ],
      ],
    );
  }
}

class _BestBars extends StatelessWidget {
  const _BestBars({required this.history});

  final List<MoveSessionHistory> history;

  @override
  Widget build(BuildContext context) {
    // Oldest on the left, so the line reads forward in time; the row flips
    // by itself under right-to-left.
    final oldestFirst = history.reversed.toList();
    final top = oldestFirst
        .map((h) => barFigure(h.best))
        .fold<double>(0, (a, b) => a > b ? a : b);
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('move-history-bars'),
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < oldestFirst.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Container(
                  key: ValueKey('move-history-bar-${oldestFirst[i].sessionId}'),
                  height: top <= 0
                      ? 8
                      : 8 + 48 * (barFigure(oldestFirst[i].best) / top),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final MoveSessionHistory row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final date = sessionDateLabel(l10n, row.dateKey);
    final sets = row.sets.map((s) => outcomeLabel(l10n, s)).join(' · ');
    final best = row.best;
    return Semantics(
      container: true,
      label: best == null
          ? date
          : '${l10n.bestSetOnDateSet(date, outcomeLabel(l10n, best))}. $sets',
      excludeSemantics: true,
      child: ConstrainedBox(
        key: ValueKey('move-history-row-${row.sessionId}'),
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: AppText.titleS),
              Text(
                sets,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
