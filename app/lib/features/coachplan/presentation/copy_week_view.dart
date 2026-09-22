/// `W05` — copying a week, with its overwrites named **before** it happens.
///
/// ## This is not the rule-9 violation it looks like
///
/// §2.9 is "undo, not confirmation" — for *logging*. `P1-RULE-09` exempts
/// destructive bulk actions, and copying a week over existing work is the
/// definition of one. No logging action exists anywhere in this feature, so
/// there is nothing here for the undo rule to govern.
///
/// It is also **not a dialog**. The summary is part of the screen: a
/// `showDialog` is banned across every feature, and this panel is the same
/// information without one. Cancelling is simply not confirming — nothing has
/// been written at the moment it is read.
///
/// ## The summary is computed in memory
///
/// `OverwriteSummary` comes from the draft the coach already holds, so the
/// count and the named days are exact with no signal (`P2-OFF-W05`).
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/plan/copy_week_planner.dart';
import 'coachplan_widgets.dart';

class CopyWeekView extends StatelessWidget {
  const CopyWeekView({
    super.key,
    required this.summary,
    this.weekCount = 4,
    this.selectedTargets = const <int>{},
    this.daysOutsideMonth = const <String>[],
    this.onToggleTarget,
    this.onConfirm,
    this.onCancel,
    this.onBack,
  });

  /// What the projection would do. Written days, and the days it replaces.
  final OverwriteSummary summary;

  final int weekCount;

  /// Zero-based week indexes the copy would land on.
  final Set<int> selectedTargets;

  /// `P2-ERR-W05`: days that fall outside the loaded month. Named, so the
  /// coach knows a second document is involved before half a week is written.
  final List<String> daysOutsideMonth;

  final ValueChanged<int>? onToggleTarget;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.copyThisWeek, onBack: onBack),
      body: AppScaffold(
        footer: [
          AppButton(l10n.copyThisWeek, height: 54, onPressed: onConfirm),
          AppButton(
            l10n.cancel,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: onCancel,
          ),
        ],
        children: [
          Text(l10n.chooseWhereItGoesYouCanTailor, style: AppText.bodyM),
          AppChipRow(
            items: [
              for (var i = 0; i < weekCount; i++)
                l10n.weekWeekOfTotal('${i + 1}', '$weekCount'),
            ],
            selected: selectedTargets,
            onTap: onToggleTarget,
          ),
          AppCard(
            // Amber, not error: nothing has gone wrong. She is being told what
            // she is about to do while she can still not do it.
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            gap: 0,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SectionHead(l10n.whatWillChange),
              ),
              LabelledValue(
                label: l10n.daysWritten,
                value: countLabel(summary.daysWritten),
              ),
              // Named by date, never counted. A coach who loses work to a
              // silent copy does not trust the next one.
              LabelledValue(
                label: l10n.existingAssignmentsReplaced,
                value: summary.replaced.isEmpty
                    ? countLabel(0)
                    : summary.replaced.join(' · '),
              ),
              if (daysOutsideMonth.isNotEmpty)
                LabelledValue(
                  label: l10n.dates,
                  value: daysOutsideMonth.join(' · '),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
