/// Buying coaching offline is a **hard no**.
///
/// G11 §4, stated as a hard requirement: "You need a connection to pay. No
/// optimistic state, no local 'pending purchase', no queued charge." Same
/// posture G7 takes for account deletion.
///
/// The type is the enforcement. [PurchaseAttempt] is sealed with **two**
/// variants — allowed, and refused-offline. There is deliberately no third
/// variant for a queued, pending or optimistic purchase, so there is nothing
/// for a screen to render as "we'll charge you when you're back" and nothing
/// for a sync layer to replay.
///
/// ## Why this lives in the coached feature at all
///
/// Renewal. G16 offers "Work with Sara again", which is a purchase reached from
/// a screen this feature owns. The checkout itself is the marketplace's, and
/// this gate is what that button must pass through first.
///
/// ## Paying may confirm
///
/// G11 §5 names paying and ending coaching as the two carve-outs from rule 9 —
/// destructive, non-logging, irreversible acts. Every other action in this
/// feature is undo, not confirmation.
library;

import 'package:meta/meta.dart';

/// The answer to "may she buy right now".
@immutable
sealed class PurchaseAttempt {
  const PurchaseAttempt();

  /// Whether the caller may proceed to the provider's hosted page.
  bool get mayProceed => this is PurchaseAllowed;
}

/// Online, and the checkout may open.
@immutable
final class PurchaseAllowed extends PurchaseAttempt {
  const PurchaseAllowed();

  @override
  String toString() => 'PurchaseAllowed';
}

/// Offline. Nothing is charged, nothing is queued, and retry is offered.
///
/// It carries no amount, no order id and no timestamp — there is nothing to
/// carry, because nothing was created.
@immutable
final class PurchaseRefusedOffline extends PurchaseAttempt {
  const PurchaseRefusedOffline();

  @override
  bool operator ==(Object other) => other is PurchaseRefusedOffline;

  @override
  int get hashCode => 17;

  @override
  String toString() => 'PurchaseRefusedOffline';
}

/// The one place a purchase is gated.
class CoachingPurchaseGate {
  const CoachingPurchaseGate();

  /// Whether a checkout may be created.
  ///
  /// Takes connectivity and nothing else: there is no `force`, no `queue` and
  /// no `allowOffline` parameter for a caller to reach for at the end of a long
  /// day.
  PurchaseAttempt attempt({required bool online}) =>
      online ? const PurchaseAllowed() : const PurchaseRefusedOffline();
}
