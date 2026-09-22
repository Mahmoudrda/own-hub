/// The commit step at Z09 — five states, and why the confirmation is one of
/// them rather than a dialog.
///
/// Two rules meet here and they pull opposite ways:
///
///   * **Rule 9** — logging never raises a confirmation dialog.
///     `test/product_rules_test.dart` fails the build on any `showDialog` or
///     `AlertDialog` anywhere under `lib/features/`, and it is right to be that
///     blunt: it was widened after shipping vacuous for weeks by not looking at
///     `lib/features/train/`.
///   * **G16 §3.1** — an import rewrites the content library in bulk. That is
///     destructive, and a destructive bulk action *should* ask.
///
/// `cycle_deletion_machine.dart` already settled this, and this file follows it
/// deliberately rather than inventing a second answer: the confirmation is an
/// **inline state of the screen**. Z09's footer swaps in place. That honours the
/// destructive exemption without putting a dialog anywhere a future logging path
/// could copy it from — and this is the feature most likely to reach for one,
/// because "are you sure you want to replace the library?" is what every admin
/// tool anyone has used does.
///
/// ## Nothing is claimed that has not happened
///
/// Z09's banner says "Nothing has been written yet." [ImportCommitState.done] is
/// reachable only through [ImportCommit.markCommitted], which is called on an
/// acknowledgement. There is no optimistic completion: an import that reported
/// success before the write landed would tell staff the library is filled, and
/// the empty library they then stop worrying about is the one that leaves
/// `AllergyGuard` with nothing to read.
///
/// ## Where the write actually runs
///
/// §8 leaves open "whether import runs client-side or through a Cloud Function",
/// and recommends validating on device for instant feedback while committing
/// through a Function. This machine is indifferent to that choice: it models the
/// *steps*, and whoever performs them calls [markCommitted] or [markFailed].
library;

import 'package:meta/meta.dart';

/// The five states of a commit, plus the failure it can land in.
enum ImportCommitState {
  idle,

  /// Asking, in place. See the library note on why this is not a dialog.
  confirming,

  /// The batch is being written.
  committing,

  /// Acknowledged. Only reachable from an acknowledgement.
  done,

  /// It did not complete. Retryable, and nothing was written.
  failed,
}

/// Drives Z09's footer.
@immutable
class ImportCommit {
  const ImportCommit({
    this.state = ImportCommitState.idle,
    this.offline = false,
  });

  final ImportCommitState state;

  /// Whether the last attempt failed for want of a signal.
  ///
  /// Separate from [state] because the two are different promises: "we could not
  /// reach the server" and "you are offline and this will run when you are back"
  /// are not the same sentence, and only one of them is true halfway through a
  /// large upload on Egyptian mobile data.
  final bool offline;

  /// She tapped "Import everything". Nothing is written; the footer asks.
  ImportCommit requested() => state == ImportCommitState.idle
      ? const ImportCommit(state: ImportCommitState.confirming)
      : this;

  /// She backed out. Nothing was written.
  ImportCommit cancelled() =>
      state == ImportCommitState.confirming ? const ImportCommit() : this;

  /// She confirmed. The write starts.
  ///
  /// Guarded so a second tap while a write is in flight cannot start another
  /// one — a double-tap on a bulk import is otherwise two batches.
  ImportCommit confirmed() => state == ImportCommitState.confirming
      ? const ImportCommit(state: ImportCommitState.committing)
      : this;

  /// The write was acknowledged. **The only route to [ImportCommitState.done].**
  ImportCommit markCommitted() => state == ImportCommitState.committing
      ? const ImportCommit(state: ImportCommitState.done)
      : this;

  /// It did not complete. [offline] distinguishes no signal from refused.
  ImportCommit markFailed({bool offline = false}) =>
      state == ImportCommitState.committing
      ? ImportCommit(state: ImportCommitState.failed, offline: offline)
      : this;

  /// Try the write again — not the confirmation. She already confirmed, and
  /// asking twice for the same destructive action is how people learn to tap
  /// through prompts.
  ImportCommit retry() => state == ImportCommitState.failed
      ? const ImportCommit(state: ImportCommitState.committing)
      : this;

  /// Mid-write, for disabling the footer.
  bool get isRunning => state == ImportCommitState.committing;

  /// True in exactly one state. Anything that reads "has this been imported?"
  /// asks here rather than inferring it from the absence of an error.
  bool get hasWritten => state == ImportCommitState.done;

  bool get canCancel => state == ImportCommitState.confirming;

  bool get canRetry => state == ImportCommitState.failed;

  @override
  String toString() => 'ImportCommit(${state.name}, offline: $offline)';
}
