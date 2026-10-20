/// The Beginner / Intermediate / Advanced tabs on R01 and R02.
///
/// One tap switches the tier the page shows, and the Start button then starts
/// that tier's session: she can begin any of them, whatever her own level is.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_segmented.dart';
import '../../onboarding/domain/intake.dart';
import '../domain/viewed_tier.dart';

class TierTabs extends StatelessWidget {
  const TierTabs({super.key, required this.selected, this.onChanged});

  final TrainingLevel selected;

  /// Defaults to [ViewedTier.show].
  final ValueChanged<TrainingLevel>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppSegmented(
      items: [
        l10n.beginner,
        l10n.intermediate,
        l10n.advanced,
      ],
      selectedIndex: TrainingLevel.values.indexOf(selected),
      onChanged: (i) => (onChanged ?? ViewedTier.show)(TrainingLevel.values[i]),
    );
  }
}
