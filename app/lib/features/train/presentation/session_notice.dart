/// A change to the session that is not a log (a swap on R05, a skip on R06),
/// carried to the next training screen as its route argument.
///
/// That screen draws the offer in the page, with [AppLiveUndoBar], above the
/// move. A floating snackbar would sit over the one button she taps next, the
/// set she is about to log, for the whole five seconds.
library;

import 'package:flutter/foundation.dart';

import '../../../domain/logging/log_command_bus.dart';

@immutable
class SessionNotice {
  const SessionNotice({required this.handle, required this.onUndo});

  /// What changed, and the five seconds to take it back.
  final LogHandle handle;

  /// Puts the session back. Runs only when the undo landed.
  final VoidCallback onUndo;
}
