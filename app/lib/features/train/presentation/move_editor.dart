/// The inline editor under a move: sets, reps or seconds, and a target weight.
///
/// Used by R03 before she starts and by the workout builder. Steppers rather
/// than text fields, so an edit never takes the keyboard (and her place) away,
/// and every value stays inside the bounds in `custom_workout.dart`.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/custom_workout.dart';
import '../domain/weight_label.dart';

class MoveEditor extends StatelessWidget {
  const MoveEditor({
    super.key,
    required this.move,
    required this.onChanged,
    this.showWeight = false,
    this.onSwap,
    this.onRemove,
    this.onEarlier,
    this.onLater,
  });

  final CustomMove move;
  final ValueChanged<CustomMove> onChanged;

  /// Whether a target weight means something for this move.
  final bool showWeight;

  /// Null hides the button.
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  double? _weightUp() {
    final now = move.weightKg;
    if (now == null) return kMinWeightKg;
    return now + kWeightStepKg;
  }

  CustomMove _weightStep(bool up) {
    final now = move.weightKg;
    if (up) return move.copyWith(weightKg: _weightUp());
    if (now == null) return move;
    final next = now - kWeightStepKg;
    return next < kMinWeightKg
        ? move.copyWith(clearWeight: true)
        : move.copyWith(weightKg: next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final timed = move.timed;
    final weight = move.weightKg;
    return AppCard(
      variant: AppCardVariant.selected,
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      gap: 8,
      children: [
        _StepperRow(
          rowKey: 'sets',
          label: l10n.sets,
          value: countLabel(move.sets),
          onDown: move.sets > kMinSets
              ? () => onChanged(move.copyWith(sets: move.sets - 1))
              : null,
          onUp: move.sets < kMaxSets
              ? () => onChanged(move.copyWith(sets: move.sets + 1))
              : null,
        ),
        AppChipRow(
          key: const ValueKey('edit-unit'),
          items: [l10n.reps, l10n.seconds],
          selected: {timed ? 1 : 0},
          onTap: (i) => onChanged(move.copyWith(timed: i == 1)),
        ),
        if (timed)
          _StepperRow(
            rowKey: 'hold',
            label: l10n.seconds,
            value: countLabel(move.holdSeconds ?? kMinHoldSeconds),
            onDown: (move.holdSeconds ?? 0) > kMinHoldSeconds
                ? () => onChanged(
                    move.copyWith(
                      holdSeconds: (move.holdSeconds ?? 0) - kHoldStepSeconds,
                    ),
                  )
                : null,
            onUp: (move.holdSeconds ?? 0) < kMaxHoldSeconds
                ? () => onChanged(
                    move.copyWith(
                      holdSeconds: (move.holdSeconds ?? 0) + kHoldStepSeconds,
                    ),
                  )
                : null,
          )
        else
          _StepperRow(
            rowKey: 'reps',
            label: l10n.reps,
            value: countLabel(move.reps ?? kMinReps),
            onDown: (move.reps ?? 0) > kMinReps
                ? () => onChanged(move.copyWith(reps: (move.reps ?? 0) - 1))
                : null,
            onUp: (move.reps ?? 0) < kMaxReps
                ? () => onChanged(move.copyWith(reps: (move.reps ?? 0) + 1))
                : null,
          ),
        if (showWeight)
          _StepperRow(
            rowKey: 'weight',
            label: l10n.weight,
            value: weight == null
                ? l10n.bodyweight
                : '${weightLabel(weight)} ${l10n.kg}',
            onDown: weight == null ? null : () => onChanged(_weightStep(false)),
            onUp: (weight ?? 0) < kMaxWeightKg
                ? () => onChanged(_weightStep(true))
                : null,
          ),
        Row(
          children: [
            if (onEarlier != null)
              IconButton(
                key: const ValueKey('edit-earlier'),
                tooltip: l10n.moveEarlier,
                onPressed: onEarlier,
                icon: const Icon(Icons.arrow_upward, size: 22),
              ),
            if (onLater != null)
              IconButton(
                key: const ValueKey('edit-later'),
                tooltip: l10n.moveLater,
                onPressed: onLater,
                icon: const Icon(Icons.arrow_downward, size: 22),
              ),
            const Spacer(),
            if (onSwap != null)
              AppButton(
                l10n.swap,
                key: const ValueKey('edit-swap'),
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: onSwap,
              ),
            if (onRemove != null)
              AppButton(
                l10n.remove,
                key: const ValueKey('edit-remove'),
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: onRemove,
              ),
          ],
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.onDown,
    required this.onUp,
  });

  final String rowKey;
  final String label;
  final String value;
  final VoidCallback? onDown;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.bodyM)),
        IconButton(
          key: ValueKey('edit-$rowKey-down'),
          tooltip: l10n.decreaseLabel(label),
          onPressed: onDown,
          icon: const Icon(Icons.remove_circle_outline, size: 26),
        ),
        SizedBox(
          width: 76,
          child: Semantics(
            label: label,
            value: value,
            excludeSemantics: true,
            child: Text(
              value,
              key: ValueKey('edit-$rowKey-value'),
              textAlign: TextAlign.center,
              style: AppText.titleM,
            ),
          ),
        ),
        IconButton(
          key: ValueKey('edit-$rowKey-up'),
          tooltip: l10n.increaseLabel(label),
          onPressed: onUp,
          icon: const Icon(Icons.add_circle_outline, size: 26),
        ),
      ],
    );
  }
}
