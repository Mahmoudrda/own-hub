/// The "New best" chip under R09's saved bar: what she just beat, in her own
/// numbers. It appears only for a real improvement on a best she already had.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_pill.dart';
import '../domain/live_best.dart';
import '../domain/weight_label.dart';

/// What improved, as a sentence.
String liveBestLine(AppL10n l10n, LiveBest best) {
  String kg(num value) => '${weightLabel(value)} ${l10n.kg}';
  switch (best.kind) {
    case LiveBestKind.heavier:
      return l10n.heaviestWeightYetWeight(kg(best.loadKg ?? 0));
    case LiveBestKind.moreReps:
      final load = best.loadKg;
      final reps = countLabel(best.reps ?? 0);
      return load == null || load <= 0
          ? l10n.mostRepsYetReps(reps)
          : l10n.mostRepsAtWeightReps(kg(load), reps);
    case LiveBestKind.longerHold:
      return l10n.longestHoldYetTime(
        l10n.secondsSeconds(countLabel(best.holdSec ?? 0)),
      );
    case LiveBestKind.harderVersion:
      return l10n.aHarderVersionOfThisMove;
  }
}

class LiveBestChip extends StatelessWidget {
  const LiveBestChip({super.key, required this.best});

  final LiveBest best;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final line = liveBestLine(l10n, best);
    return Semantics(
      container: true,
      label: '${l10n.newBest}. $line',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            AppPill(
              l10n.newBest,
              icon: Icons.emoji_events_outlined,
              background: AppColors.primaryContainer,
              foreground: AppColors.onPrimaryContainer,
            ),
            Text(
              line,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
