/// Removing a session she logged by mistake, from R10 or R12.
///
/// Removing is not logging, so §2 rule 9's "never ask" does not cover it: it
/// takes a session off her week and her points, so it asks first, in the house
/// sheet, with keeping it as the filled answer. Then it goes through the same
/// bus as every log, so there are still five seconds to take it back, and the
/// write (and the credit coming off) waits for them.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/haptics.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';

/// Asks, then removes through [bus] with Undo. [describe] names where her week
/// will stand; [commit] removes the session and its credit once the window
/// closes; [then] runs after the undo offer is up, to take her somewhere that
/// does not still show the session.
///
/// Returns true when she chose to remove it.
Future<bool> removeSessionWithUndo(
  BuildContext context, {
  required LogCommandBus bus,
  required String describe,
  required Future<void> Function() commit,
  VoidCallback? then,
}) async {
  final l10n = AppL10n.of(context);
  final confirmed = await showAppSheet<bool>(
    context: context,
    children: [
      Text(l10n.removeThisSession_1qh67, style: AppText.titleL),
      Text(
        l10n.itComesOffThisWeeksCountAnd,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
      AppButton(l10n.keepIt, onPressed: () => Navigator.of(context).pop(false)),
      AppButton(
        l10n.removeIt,
        variant: AppButtonVariant.outlined,
        height: 48,
        fontSize: 15,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  if (confirmed != true || !context.mounted) return false;

  final handle = bus.submit(UndoableLog(describe: describe, commit: commit));
  unawaited(AppHaptics.play(HapticMoment.actionDone));
  showUndoSnackBar(context, handle: handle, undoLabel: l10n.undo);
  then?.call();
  return true;
}
