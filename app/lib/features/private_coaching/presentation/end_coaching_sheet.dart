/// The sheet both sides see before a coaching ends: what happens, then End or
/// Keep. True only when she chose End.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';

Future<bool> confirmEndCoaching(
  BuildContext context, {
  required String body,
}) async {
  final l10n = AppL10n.of(context);
  final yes = await showAppSheet<bool>(
    context: context,
    children: [
      Text(l10n.endThisCoaching, style: AppText.titleL),
      Text(body, style: AppText.bodyM),
      Builder(
        builder: (sheet) => AppButton(
          l10n.endCoaching,
          key: const ValueKey('end-coaching-yes'),
          onPressed: () => Navigator.of(sheet).pop(true),
        ),
      ),
      Builder(
        builder: (sheet) => AppButton(
          l10n.keepCoaching,
          key: const ValueKey('end-coaching-no'),
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(sheet).pop(false),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );
  return yes == true;
}
