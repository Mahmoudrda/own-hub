/// Where a woman stands with one coach, as far as *buying* is concerned.
///
/// ## Why this exists rather than an import
///
/// `lib/features/coached/domain/relationship.dart` already owns the twelve-state
/// relationship machine, and `lib/features/coach/domain/` owns the coach's half.
/// Neither is mine to edit, and importing either would couple the shopfront to a
/// machine that is being changed by other people in parallel.
///
/// So this is the **narrow read-only port**: seven values, no transitions, no
/// setters. The marketplace needs exactly one fact — *may she pay yet* — and
/// this is that fact and nothing else. The adapter that maps
/// `coached.RelationshipState` onto [MarketplaceStage] belongs at the wiring
/// layer, next to the router, and is listed in this feature's handover notes.
///
/// ## The value that is missing, and why that is the point
///
/// There is **no stage meaning "browsing, and may buy now"**. Buy-direct is
/// removed from this product: an enquiry comes first on every path, and the only
/// stage [CheckoutGate] will open a checkout from is
/// [MarketplaceStage.acceptedAwaitingPayment] — which is reached only when a
/// coach has accepted. That is what makes "she pays only once you accept" true
/// everywhere instead of true in one place and false in another.
library;

import 'package:meta/meta.dart';

/// The shopfront's read-only view of one coaching relationship.
enum MarketplaceStage {
  /// No relationship exists. She can read everything and buy nothing.
  browsing,

  /// She asked a question. No money has moved and none can.
  enquirySent,

  /// The coach said no. The thread stays readable; she may enquire elsewhere.
  enquiryDeclined,

  /// **The only stage a checkout may open from.** The coach accepted and is
  /// holding a place for her.
  acceptedAwaitingPayment,

  /// A checkout exists and the provider has not answered yet. A second
  /// checkout from here would be a second charge.
  paying,

  /// Paid and working together — intake, preparing, active or ending soon.
  /// The shopfront does not distinguish them; `features/coached` does.
  coached,

  /// Over, refunded or suspended. History is readable; renewal starts a new
  /// enquiry, never a resurrection of this one.
  coachingEnded;

  /// Whether an enquiry may be sent from here.
  ///
  /// Not from [enquirySent] (one open enquiry per coach — the relationship id
  /// is deterministic, so a second would collapse onto the first anyway) and
  /// not while she is already being coached by this coach.
  bool get mayEnquire => switch (this) {
    MarketplaceStage.browsing ||
    MarketplaceStage.enquiryDeclined ||
    MarketplaceStage.coachingEnded => true,
    _ => false,
  };

  /// Whether the shopfront should show her a package she can act on.
  bool get maySeePurchasableOffer =>
      this == MarketplaceStage.acceptedAwaitingPayment;
}

/// Who she is with a coach, without any way to change it.
///
/// Deliberately one method and no writes. The marketplace reads this; the
/// relationship is moved by callables and webhooks on the server, and by
/// `features/coached` on the client.
abstract class RelationshipStagePort {
  /// Her stage with [coachUid]. Never null: [MarketplaceStage.browsing] is the
  /// honest answer when no relationship exists, and an absent relationship is
  /// not an error.
  MarketplaceStage stageWith(String coachUid);
}

/// A port backed by a plain map, for tests and for building screens.
///
/// Strict in one way that matters: an unknown coach is [MarketplaceStage.browsing],
/// never an exception and never "coached". A fake that threw would push callers
/// into try/catch around a question that always has an answer.
@immutable
class FixedRelationshipStages implements RelationshipStagePort {
  const FixedRelationshipStages([
    this.stages = const <String, MarketplaceStage>{},
  ]);

  final Map<String, MarketplaceStage> stages;

  @override
  MarketplaceStage stageWith(String coachUid) =>
      stages[coachUid] ?? MarketplaceStage.browsing;
}

/// The relationship document id, computed rather than queried.
///
/// `{coachUid}__{clientUid}`, coach first, double underscore — G11 §1.2, settled
/// against G12 and G14. Both parties can derive it, so no screen in this feature
/// needs a query to find a relationship, and an enquiry retried after a dropped
/// connection lands on the same document instead of forking the thread.
///
/// The double underscore is load-bearing: Firebase Auth uids are alphanumeric
/// today, and a single `_` would parse ambiguously the day a provider widens
/// that alphabet. The storage rules split on this id to decide who may read a
/// voice note.
String relationshipIdFor({
  required String coachUid,
  required String clientUid,
}) {
  if (coachUid.isEmpty || clientUid.isEmpty) {
    throw ArgumentError('A relationship id needs both parties.');
  }
  if (coachUid.contains('__') || clientUid.contains('__')) {
    throw ArgumentError(
      'A uid containing "__" would make the id ambiguous, and the security '
      'rules derive party membership by splitting on it.',
    );
  }
  return '${coachUid}__$clientUid';
}
