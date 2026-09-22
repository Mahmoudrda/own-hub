/// `W03` — the month being authored, a week at a time.
///
/// ## A gap is red; a suppressed move is gone
///
/// Two different absences, and conflating them is the defect this screen has
/// to avoid. A **gap** is a day nobody has filled: it is drawn in red because
/// the coach still owes it. A **suppressed move** is one her assessment
/// removed on the way in: it is not on the day at all, not greyed and not
/// warned about — `SplitApplicator` already took it out. What this screen owes
/// her instead is the truth about what was removed, which is
/// [SuppressedMovesNote] naming every `suppressedExerciseIds` entry.
///
/// ## Never an empty planner for a document that failed to load
///
/// `P2-ERR-W03`. A blank month invites a coach to plan over work that already
/// exists, so a failed read states itself and offers a retry. Absent data and
/// an empty month are different screens.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/plan/plan_draft.dart';
import 'coachplan_labels.dart';
import 'coachplan_widgets.dart';

/// Every calendar day of [month] (`yyyy-MM`), in order, as `yyyy-MM-dd`.
List<String> monthDayKeys(String month) {
  final parts = month.split('-');
  if (parts.length != 2) return const <String>[];
  final year = int.tryParse(parts[0]);
  final index = int.tryParse(parts[1]);
  if (year == null || index == null) return const <String>[];
  final length = DateTime(year, index + 1, 0).day;
  return <String>[
    for (var day = 1; day <= length; day++)
      '$month-${day.toString().padLeft(2, '0')}',
  ];
}

class WorkoutPlannerView extends StatelessWidget {
  const WorkoutPlannerView({
    super.key,
    required this.draft,
    this.clientName = '',
    this.weekIndex = 0,
    this.suppressedExerciseIds = const <String>{},
    this.loadFailed = false,
    this.onSelectWeek,
    this.onOpenDay,
    this.onApplySplit,
    this.onAddWorkout,
    this.onCopyWeek,
    this.onSaveAsSplit,
    this.onDraftForMe,
    this.onPublish,
    this.onRetry,
    this.onBack,
  });

  /// The whole month, in one document. Null while it is being read, or when
  /// the read failed — the two are told apart by [loadFailed].
  final PlanDraft? draft;

  final String clientName;

  /// Which week of the month is shown. Zero-based.
  final int weekIndex;

  /// What her assessment removed on the way in. Stated, never silently
  /// narrowed away.
  final Set<String> suppressedExerciseIds;

  final bool loadFailed;

  final ValueChanged<int>? onSelectWeek;

  /// Given the `yyyy-MM-dd` key of the day tapped.
  final ValueChanged<String>? onOpenDay;

  final VoidCallback? onApplySplit;
  final VoidCallback? onAddWorkout;
  final VoidCallback? onCopyWeek;
  final VoidCallback? onSaveAsSplit;
  final VoidCallback? onDraftForMe;
  final VoidCallback? onPublish;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final month = draft;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: clientName, onBack: onBack),
      body: AppScaffold(
        footer: month == null
            ? const <Widget>[]
            : <Widget>[
                AppButton(
                  l10n.previewAndPublish,
                  height: 54,
                  onPressed: onPublish,
                ),
              ],
        children: month == null ? _unavailable(l10n) : _planner(l10n, month),
      ),
    );
  }

  /// The read failed, or has not answered yet. Never an empty month.
  List<Widget> _unavailable(AppL10n l10n) => <Widget>[
    if (loadFailed) ...[
      AppCard(
        variant: AppCardVariant.amber,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          Text(l10n.weCouldNotReachTheServerYour, style: AppText.bodyM),
        ],
      ),
      AppButton(
        l10n.tryAgain,
        variant: AppButtonVariant.outlined,
        height: 48,
        fontSize: 15,
        onPressed: onRetry,
      ),
    ],
  ];

  List<Widget> _planner(AppL10n l10n, PlanDraft month) {
    final days = monthDayKeys(month.month);
    final weeks = (days.length / 7).ceil();
    final safeWeek = weekIndex.clamp(0, weeks == 0 ? 0 : weeks - 1);
    final shown = days.skip(safeWeek * 7).take(7).toList(growable: false);
    final published = month.lastPublished;

    return [
      Row(
        children: [
          AppPill(
            l10n.draft,
            background: AppColors.amberContainer,
            foreground: AppColors.amber,
          ),
          if (published != null) ...[
            const SizedBox(width: 8),
            // The version id, as the id it is. Rendered from a document the
            // coach already holds, so it is right with no signal.
            AppPill(
              published.version,
              background: AppColors.surfaceContainer,
              foreground: AppColors.onSurfaceVariant,
            ),
          ],
        ],
      ),
      AppChipRow(
        items: [
          for (var i = 0; i < weeks; i++)
            l10n.weekWeekOfTotal('${i + 1}', '$weeks'),
        ],
        selected: <int>{safeWeek},
        onTap: onSelectWeek,
      ),
      for (final key in shown) _dayRow(l10n, month, key),
      if (suppressedExerciseIds.isNotEmpty)
        SuppressedMovesNote(exerciseIds: suppressedExerciseIds),
      Row(
        children: [
          Expanded(
            child: AppButton(
              l10n.applyASplit,
              variant: AppButtonVariant.tonal,
              height: 44,
              fontSize: 14,
              icon: Icons.repeat,
              onPressed: onApplySplit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              l10n.addWorkout,
              variant: AppButtonVariant.outlined,
              height: 44,
              fontSize: 14,
              icon: Icons.add,
              onPressed: onAddWorkout,
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: AppButton(
              l10n.copyThisWeek,
              variant: AppButtonVariant.text,
              height: 40,
              fontSize: 14,
              onPressed: onCopyWeek,
            ),
          ),
          Expanded(
            child: AppButton(
              l10n.saveAsASplit,
              variant: AppButtonVariant.text,
              height: 40,
              fontSize: 14,
              onPressed: onSaveAsSplit,
            ),
          ),
          Expanded(
            child: AppButton(
              l10n.draftItForMe,
              variant: AppButtonVariant.text,
              height: 40,
              fontSize: 14,
              onPressed: onDraftForMe,
            ),
          ),
        ],
      ),
    ];
  }

  Widget _dayRow(AppL10n l10n, PlanDraft month, String key) {
    final day = month.dayAt(key);
    final date = dateFromDayKey(key);

    // Absence is rest in G2's contract, so a day the coach has not touched and
    // a day she marked as rest must not read the same here. "Nothing assigned"
    // is the gap; "Rest day" is a decision.
    final value = switch (day) {
      null => l10n.nothingAssigned,
      PlanDay(isRest: true) => l10n.restDay,
      PlanDay(:final workout) => workout?.title ?? l10n.nothingAssigned,
    };

    return PlannerRow(
      key: CoachPlanKeys.dayRow(key),
      leading: date == null ? RowLabel(key) : DayStamp(date: date),
      value: value,
      isGap: day == null,
      onTap: onOpenDay == null ? null : () => onOpenDay!(key),
    );
  }
}
