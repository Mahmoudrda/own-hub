/// Y12's "Delete cycle data" — plan §3.5, five states.
///
/// `idle → confirming → purgingLocal → purgingRemote → done`, with
/// `failed → retry`. "Deletion is destructive and not logging, so it **may**
/// confirm (the exemption G7 recorded against P1-RULE-09)."
///
/// ## Why the confirmation is a state and not a dialog
///
/// `test/product_rules_test.dart`'s rule-9 guard fails the build on any
/// `showDialog` or `AlertDialog` anywhere under `lib/features/`. The guard is
/// right to be that blunt — it was widened after shipping vacuous for weeks by
/// not looking at `lib/features/train/` — and the destructive exemption is an
/// argument about *this* action, not a licence to reintroduce dialogs into the
/// feature that owns the most sensitive data in the product.
///
/// So [CycleDeletionState.confirming] is an inline state of the settings screen:
/// the row expands and asks in place. That satisfies the exemption without
/// putting a dialog anywhere a future logging path could copy it from.
///
/// ## What it must not claim
///
/// §4: deletion "needs the callable. The UI says so and offers to run it when
/// signal returns; **it never claims a deletion it has not performed**." So
/// there is no optimistic [CycleDeletionState.done] — [markRemotePurged] is the
/// only way to reach it, and it is called on a server acknowledgement.
library;

import 'package:meta/meta.dart';

/// Plan §3.5's five states, plus the failure it names.
enum CycleDeletionState {
  idle,

  /// Asking, in place. See the library note on why this is not a dialog.
  confirming,

  /// Clearing the local cache entries and the `homeCard` device mirror.
  purgingLocal,

  /// The callable is deleting `cycle/current` and every `periods/*`.
  purgingRemote,

  /// Acknowledged by the server. Only reachable from an ack.
  done,

  /// Something went wrong, or there was no signal. Retryable.
  failed,
}

/// Drives Y12's delete row.
@immutable
class CycleDeletion {
  const CycleDeletion({
    this.state = CycleDeletionState.idle,
    this.offline = false,
  });

  final CycleDeletionState state;

  /// Whether the last attempt failed because there was no signal.
  ///
  /// Separate from [state] because the copy differs: "we could not reach the
  /// server" and "you are offline and we will do this when you are back" are
  /// different promises, and only one of them is true on a plane.
  final bool offline;

  /// She tapped "Delete cycle data".
  CycleDeletion requested() =>
      const CycleDeletion(state: CycleDeletionState.confirming);

  /// She backed out. Nothing was deleted.
  CycleDeletion cancelled() =>
      const CycleDeletion(state: CycleDeletionState.idle);

  /// She confirmed. The local half starts.
  CycleDeletion confirmed() =>
      const CycleDeletion(state: CycleDeletionState.purgingLocal);

  /// The local cache and the device mirror are cleared; the callable is next.
  CycleDeletion localPurged() =>
      const CycleDeletion(state: CycleDeletionState.purgingRemote);

  /// The server acknowledged. **The only route to [CycleDeletionState.done].**
  CycleDeletion markRemotePurged() =>
      const CycleDeletion(state: CycleDeletionState.done);

  /// It did not complete. [offline] distinguishes "no signal" from "refused".
  CycleDeletion markFailed({bool offline = false}) =>
      CycleDeletion(state: CycleDeletionState.failed, offline: offline);

  /// Try again from the beginning of the purge, not from the confirmation —
  /// she already confirmed, and asking twice for the same destructive action is
  /// how people learn to tap through prompts.
  CycleDeletion retry() =>
      const CycleDeletion(state: CycleDeletionState.purgingLocal);

  /// Whether the feature is mid-deletion, for disabling the row.
  bool get isRunning =>
      state == CycleDeletionState.purgingLocal ||
      state == CycleDeletionState.purgingRemote;
}
