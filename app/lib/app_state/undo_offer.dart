/// One way to say "done, and you can take it back" for a change that is not a
/// training or meal log: a check-in, a swap, an unblock, a rearranged week.
///
/// It is the same bus and the same snackbar every log uses, so the offer reads
/// the same and closes exactly when the window does. [commit] is what lands
/// when the window closes; a change already applied on screen passes none and
/// puts things back in [onUndo] instead.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/logging/log_command_bus.dart';
import '../l10n/app_l10n.dart';
import '../ui/app_undo_snackbar.dart';
import 'haptics.dart';

LogHandle offerUndo(
  BuildContext context, {
  required LogCommandBus bus,
  required String describe,
  Future<void> Function()? commit,
  VoidCallback? onUndo,
  HapticMoment haptic = HapticMoment.actionDone,
}) {
  final handle = bus.submit(
    UndoableLog(describe: describe, commit: commit ?? () async {}),
  );
  unawaited(AppHaptics.play(haptic));
  showUndoSnackBar(
    context,
    handle: handle,
    undoLabel: AppL10n.of(context).undo,
    onUndo: onUndo,
  );
  return handle;
}
