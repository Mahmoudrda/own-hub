/// The switch that used to sit on My profile: her training streak. It lives
/// under "Reminders and extras" on A01.
library;

import 'package:flutter/material.dart';

import '../../../app_state/training_streak_state.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_toggle.dart';

class ExtrasRows extends StatefulWidget {
  const ExtrasRows({super.key});

  @override
  State<ExtrasRows> createState() => _ExtrasRowsState();
}

class _ExtrasRowsState extends State<ExtrasRows> {
  bool get _streakOn => TrainingStreakState.instance.settings().enabled;

  void _setStreak(bool on) {
    TrainingStreakState.instance.setEnabled(
      on,
      progress: AppRouter.progressStore,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Her training streak (D37): on unless she switches it off, and kept
        // on this phone either way.
        if (AppRouter.featureFlags.isOn(Feature.trainingStreak)) ...[
          AppListItem(
            leading: const Icon(
              Icons.local_florist_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.showMyTrainingStreak,
            subtitle: l10n.keptOnThisPhoneTurnItOff,
            trailing: AppToggle(
              key: const ValueKey('trainingStreakToggle'),
              value: _streakOn,
              semanticLabel: l10n.showMyTrainingStreak,
              onChanged: _setStreak,
            ),
            onTap: () => _setStreak(!_streakOn),
          ),
        ],
      ],
    );
  }
}
