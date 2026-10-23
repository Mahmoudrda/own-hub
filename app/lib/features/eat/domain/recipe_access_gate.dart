/// Whether a recipe is hers to read, and the five reasons it might not be.
///
/// Modelled directly on `checkout_gate.dart`: a pure function of its inputs,
/// with no `force`, no `allowOffline` and no `skipChecks` for anyone to reach
/// for at the end of a long day.
///
/// ## Nothing is sold and nothing is locked
///
/// `Feature.payments` is false, `PaymentProvider` has exactly one
/// implementation and it is `UnavailablePaymentProvider`, and `CheckoutOutcome`
/// has no `paid` variant. A paywall shipped against that is a screen that takes
/// a decision it cannot honour, and a locked card that cannot be unlocked is
/// worse than no locked card at all.
///
/// So: every seeded recipe is [RecipeTier.free], `Feature.recipeTiering` is off
/// and cannot be turned on while payments is off, and [decide] therefore returns
/// [RecipeAccess.open] for everything in the shipped build. **No screen in this
/// feature draws a price, an upgrade row or a lock.**
///
/// What this file buys, being inert, is that the shape was designed while
/// nobody was in a hurry: where the entitlement lives, who may write it, what a
/// stale claim costs, and what a woman sees when her subscription lapses.
///
/// ## Where the entitlement lives, and who writes it
///
/// `users/{uid}/private/entitlement`:
/// `{ tier, source, expiresAt, updatedAt }`, with
/// `allow read: if isSelf(uid); allow write: if false;` for the client. Written
/// by a Cloud Function or an admin and by nobody else, exactly as `verified`,
/// `coachV` and `admin` already are. A client-asserted entitlement is not an
/// entitlement, it is a suggestion.
///
/// The **rules** gate reads a custom claim (`request.auth.token.tier`) rather
/// than the document, because a `get()` in a rule bills one extra read on every
/// gated operation. The cost of a claim is staleness: it can be up to an hour
/// behind, so the purchase flow has to force `getIdToken(true)` afterwards.
/// That is written down here because it is the kind of thing that is obvious
/// while you are building it and invisible six months later.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import 'recipe.dart';

/// Why a recipe is not open.
enum RecipeLockReason {
  /// `Feature.recipeTiering` is dark, so tiering means nothing. This is not a
  /// lock reason that can produce a locked card: it is the reason there is no
  /// such thing as a locked card in this build.
  tieringOff,

  /// `Feature.payments` is dark. The parent of the flag above, and the reason
  /// it cannot be switched on by itself.
  paymentsOff,

  /// Her entitlement is `free` and the recipe is `pro`.
  notEntitled,

  /// She had `pro` and it has run out.
  expired,

  /// The entitlement document could not be read. Unknown, not absent.
  unknownEntitlement,
}

/// What she may do with a recipe.
@immutable
class RecipeAccess {
  const RecipeAccess._(this.reason);

  /// Readable. The only value the shipped build produces.
  static const RecipeAccess open = RecipeAccess._(null);

  factory RecipeAccess.locked(RecipeLockReason reason) =>
      RecipeAccess._(reason);

  final RecipeLockReason? reason;

  bool get isOpen => reason == null;

  @override
  String toString() =>
      isOpen ? 'RecipeAccess.open' : 'RecipeAccess.locked($reason)';
}

/// What the entitlement document says, once it has been read.
@immutable
class RecipeEntitlement {
  const RecipeEntitlement({required this.tier, this.expiresAt});

  /// What every woman has today, and what the free tier keeps forever.
  static const RecipeEntitlement free = RecipeEntitlement(
    tier: RecipeTier.free,
  );

  final RecipeTier tier;

  /// Null means it does not run out. A `pro` grant with no expiry is a grant,
  /// not a subscription.
  final DateTime? expiresAt;

  bool isCurrentAt(DateTime now) =>
      expiresAt == null || expiresAt!.isAfter(now);
}

/// The one place a recipe's readability is decided.
abstract final class RecipeAccessGate {
  /// Whether [recipe] is open to her.
  ///
  /// The order of the checks is the point. Tiering being off short-circuits
  /// everything, so no other input can produce a lock in a build that has no
  /// way to sell an unlock. [entitlement] being null is *unknown*, and unknown
  /// resolves to [RecipeAccess.open] rather than locked — deliberately the
  /// opposite direction from the allergy guard, because the two failures are
  /// not symmetrical: failing closed on safety protects her, and failing closed
  /// on billing takes away a recipe she has already paid for because the
  /// network dropped.
  static RecipeAccess decide({
    required Recipe recipe,
    required FeatureFlags flags,
    RecipeEntitlement? entitlement,
    DateTime? now,
  }) {
    if (recipe.tier == RecipeTier.free) return RecipeAccess.open;
    if (!flags.isOn(Feature.payments)) {
      return RecipeAccess.locked(RecipeLockReason.paymentsOff);
    }
    if (!flags.isOn(Feature.recipeTiering)) {
      return RecipeAccess.locked(RecipeLockReason.tieringOff);
    }
    if (entitlement == null) return RecipeAccess.open;
    if (entitlement.tier != RecipeTier.pro) {
      return RecipeAccess.locked(RecipeLockReason.notEntitled);
    }
    if (!entitlement.isCurrentAt(now ?? DateTime.now())) {
      return RecipeAccess.locked(RecipeLockReason.expired);
    }
    return RecipeAccess.open;
  }
}
