/// §2 rule 9 made visible: **undo, not confirmation.**
///
/// Matches `snackbar()` in `6-v2/src/kit.mjs` — the inverse surface, the text,
/// and one action. It appears *after* a log has already been made, never before,
/// and it is the only thing a logging path is allowed to raise. There is no
/// dialog anywhere on this route and no "are you sure": a woman logging a set
/// between breaths taps once.
///
/// The text is [LogHandle.describe], which names the same numbers the button
/// named. That is not decoration — it is how she knows what she just agreed to
/// without having to remember what she tapped.
///
/// The snackbar's lifetime is [kUndoWindow], the same five seconds the bus holds
/// the write for, so the offer disappears exactly when it stops being true.
library;

import 'package:flutter/material.dart';

import '../domain/logging/log_command_bus.dart';
import '../theme/app_tokens.dart';

/// Shows the undo offer for [handle].
///
/// [onUndo] runs only if the undo actually landed inside the window — tapping a
/// moment late reports false and changes nothing, rather than rolling back a
/// write that has already been made.
void showUndoSnackBar(
  BuildContext context, {
  required LogHandle handle,
  required String undoLabel,
  VoidCallback? onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // One at a time: two stacked undo offers would make it ambiguous which log
  // the visible one belongs to.
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: kUndoWindow,
      // **`persist` defaults to `action != null`**, and this bar always has an
      // action — so without this line every undo offer in the product stayed on
      // screen indefinitely, long after its five seconds had closed and tapping
      // Undo had become a no-op. That is the defect the doc comment above
      // describes as impossible, and it is the same class as E04's old undo bar:
      // an offer that outlives the thing it is offering.
      persist: false,
      backgroundColor: AppColors.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      content: Text(
        handle.describe,
        style: AppText.bodyM.copyWith(color: AppColors.inverseOnSurface),
      ),
      action: SnackBarAction(
        label: undoLabel,
        textColor: AppColors.primaryContainer,
        onPressed: () {
          if (handle.undo()) onUndo?.call();
        },
      ),
    ),
  );
}
