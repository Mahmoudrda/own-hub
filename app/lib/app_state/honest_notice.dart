/// A short, plain note at the foot of the screen — for a control whose honest
/// answer is "this build cannot do that yet", or for saying what just happened
/// when nothing else on the page changes.
///
/// Styled exactly like the undo bar (`app_undo_snackbar.dart`) so the product
/// has one voice down there, but it carries no action: it is information, never
/// a confirmation and never an undo.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

void showHonestNotice(BuildContext context, String text) =>
    showHonestNoticeOn(ScaffoldMessenger.maybeOf(context), text);

/// The same note, for a caller that took the messenger **before** an await.
///
/// Account deletion needs this: it empties the stores, pops back to the first
/// route and only then has something to say, by which point the context it
/// started from is gone. The messenger lives above the navigator and survives.
void showHonestNoticeOn(ScaffoldMessengerState? messenger, String text) {
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 4),
      backgroundColor: AppColors.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      content: Text(
        text,
        style: AppText.bodyM.copyWith(color: AppColors.inverseOnSurface),
      ),
    ),
  );
}
