/// `K20` — building a split. A week shape, not a plan.
///
/// ## Saving this writes one document, and nothing else transitions
///
/// r12. `Split.withChanges` is K20's only mutation and it reaches no draft, no
/// version and no assignment — there is no listener, no cascade and no job. The
/// screen's two footer buttons are the whole of what it can do: save the
/// template, or save it and materialise a month **by value** into one client's
/// draft.
///
/// ## A split with a missing day is never saved
///
/// `P2-ERR-K20`: change the cycle length and a slot that has not been filled
/// shows as a gap, in the same red the planner uses for a day nobody has
/// written. A four-day split with three days is not a smaller split; it is a
/// template that will materialise a hole into somebody's month.
library;

import 'package:flutter/material.dart' hide Split;

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../domain/split/split.dart';
import '../domain/split/split_validator.dart';
import 'coachplan_widgets.dart';

/// The cycle lengths K20 offers, from the model's own bounds.
List<int> get cycleLengthOptions => <int>[
  for (var i = kMinCycleLength; i <= kMaxCycleLength; i++) i,
];

class SplitBuilderView extends StatefulWidget {
  const SplitBuilderView({
    super.key,
    required this.split,
    this.problems = const <SplitInvalid>[],
    this.onNameChanged,
    this.onSelectCycleLength,
    this.onOpenSlot,
    this.onToggleCarryApproved,
    this.onSave,
    this.onSaveAndApply,
    this.onClose,
  });

  final Split split;

  /// Everything `SplitValidator` refused, in day order.
  final List<SplitInvalid> problems;

  final ValueChanged<String>? onNameChanged;
  final ValueChanged<int>? onSelectCycleLength;

  /// Given the 1-based day index of the slot tapped.
  final ValueChanged<int>? onOpenSlot;

  final ValueChanged<bool>? onToggleCarryApproved;
  final VoidCallback? onSave;

  /// Materialises into one client's draft. Publishes nothing.
  final VoidCallback? onSaveAndApply;

  final VoidCallback? onClose;

  @override
  State<SplitBuilderView> createState() => _SplitBuilderViewState();
}

class _SplitBuilderViewState extends State<SplitBuilderView> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.split.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final split = widget.split;
    final faulted = <int>{
      for (final problem in widget.problems)
        if (problem.dayIndex != null) problem.dayIndex!,
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.buildASplit,
        leadingIcon: Icons.close,
        onBack: widget.onClose,
      ),
      body: AppScaffold(
        footer: [
          AppButton(l10n.saveThisSplit, height: 54, onPressed: widget.onSave),
          AppButton(
            l10n.saveAndApply,
            variant: AppButtonVariant.outlined,
            height: 46,
            fontSize: 15,
            onPressed: widget.onSaveAndApply,
          ),
        ],
        children: [
          AppField(
            controller: _name,
            label: l10n.nameIt,
            onChanged: widget.onNameChanged,
          ),
          Text(l10n.howManyDaysBeforeItRepeats, style: AppText.bodyM),
          AppChipRow(
            items: [
              for (final option in cycleLengthOptions) countLabel(option),
            ],
            selected: <int>{
              for (var i = 0; i < cycleLengthOptions.length; i++)
                if (cycleLengthOptions[i] == split.cycleLength) i,
            },
            onTap: widget.onSelectCycleLength == null
                ? null
                : (i) => widget.onSelectCycleLength!(cycleLengthOptions[i]),
          ),
          // One row per day of the cycle, filled or not. A slot the coach has
          // not written yet is a gap she can see, rather than a refusal she
          // meets at the save button.
          for (var index = 1; index <= split.cycleLength; index++)
            _slotRow(l10n, split.slotFor(index), index, faulted),
          AppCard(
            variant: AppCardVariant.sage,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.keepHerEasierOptions, style: AppText.titleM),
                        const SizedBox(height: 2),
                        Text(
                          l10n.approvedSubstitutionsCarryIntoEveryClientYou,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  // Default off: an approved substitution is a clinical
                  // judgement about one woman, and carrying it to everybody by
                  // default would export that judgement without anyone
                  // deciding to.
                  AppToggle(
                    value: split.carryApproved,
                    semanticLabel: l10n.keepHerEasierOptions,
                    onChanged: widget.onToggleCarryApproved,
                  ),
                ],
              ),
            ],
          ),
          Text(
            l10n.applyingASplitWritesTheseDaysAcross,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _slotRow(
    AppL10n l10n,
    SplitDaySlot? slot,
    int index,
    Set<int> faulted,
  ) {
    final missing = slot == null || faulted.contains(index);
    final value = switch (slot) {
      null => l10n.nothingAssigned,
      SplitDaySlot(isRest: true) => l10n.restDay,
      SplitDaySlot(:final title) =>
        (title ?? '').isEmpty ? l10n.nothingAssigned : title!,
    };

    return PlannerRow(
      key: Key('slot:$index'),
      leading: RowLabel(countLabel(index)),
      value: value,
      isGap: missing,
      onTap: widget.onOpenSlot == null ? null : () => widget.onOpenSlot!(index),
    );
  }
}
