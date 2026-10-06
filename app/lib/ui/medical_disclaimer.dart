/// "Own Hub is not a medical device" (APL-12, terms v3 section 4).
///
/// One sentence, the same everywhere it appears: the Profile footer, the
/// cycle screens, the life-stage question, and the short "Your week" once she
/// says she is pregnant or has recently given birth. Quiet type, no card: it
/// is a statement of what the app is, not a warning about her.
library;

import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';

class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer({super.key});

  /// Finds it in a widget test.
  static const ValueKey<String> marker = ValueKey<String>('medical-disclaimer');

  @override
  Widget build(BuildContext context) {
    return Text(
      AppL10n.of(context).ownHubIsAFitnessAndWellbeing,
      key: marker,
      style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
    );
  }
}
