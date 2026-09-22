/// §2 rule 7 — the ID photo and the selfie are deleted; only the result is kept.
///
/// The deletion is G1's. **A03's claim about it is G7's**, and the whole design
/// of this file is that the claim is *derived* rather than written.
///
/// # Why this is a sealed state and not a string
///
/// `PHASE1-FIXES.md` §3 records the same defect on `C13`: the screen told every
/// woman "Verified in 74 seconds" because 74 was the prototype's sample and
/// nothing measured the real duration. The fix was to make the number nullable
/// and render a duration-free sentence when it was not measured — "a sentence
/// that says less is better than one that says something untrue."
///
/// Rule 7's claim is the same shape and higher stakes. `verification.imagesDeletedAt`
/// is G1's evidence field, and G1's plan is explicit that **null is an alarm, not
/// a state** — `PurgeReconciler.sweep()` pages on any job decided over an hour
/// ago that still has a null value. So:
///
///   * `imagesDeletedAt != null` → [ImagesDeleted], and A03 may state it.
///   * `imagesDeletedAt == null` → [ImagesDeletionPending], and A03 **may not**.
///
/// A03 therefore renders a fact, never a promise. There is no branch that
/// produces the deletion sentence from an absent timestamp, so the screen cannot
/// claim a deletion that has not happened even if someone wired it carelessly.
///
/// # Rule 7's other half: nowhere to put an image
///
/// [VerificationRecord] holds two timestamps and nothing else. There is
/// deliberately no field an image, a document number, a date of birth or a legal
/// name could live in. `test/product_rules_test.dart` scans `lib/` for exactly
/// those identifier shapes and its positive control already whitelists
/// `final DateTime? imagesDeletedAt;` — the evidence field is allowed; somewhere
/// to keep the evidence is not.
library;

import 'package:meta/meta.dart';

/// The slice of `users/{uid}.verification` that A02 and A03 read.
///
/// Server-write-only (spine C5). The client reads it and never writes it, which
/// is why there is no `copyWith` here.
@immutable
class VerificationRecord {
  const VerificationRecord({this.decidedAt, this.imagesDeletedAt});

  /// Nothing has been checked yet.
  static const VerificationRecord none = VerificationRecord();

  /// When the check completed. Null while it is still running.
  final DateTime? decidedAt;

  /// Rule 7's evidence field, written by G1's purge Function.
  ///
  /// **Null is an alarm, not a state.** See the file note.
  final DateTime? imagesDeletedAt;

  /// True once a decision exists, whatever it was.
  bool get isDecided => decidedAt != null;

  @override
  bool operator ==(Object other) =>
      other is VerificationRecord &&
      other.decidedAt == decidedAt &&
      other.imagesDeletedAt == imagesDeletedAt;

  @override
  int get hashCode => Object.hash(decidedAt, imagesDeletedAt);
}

/// What A03 is entitled to say about rule 7.
///
/// Sealed, so a widget handling it must handle both cases — and the pending case
/// carries no timestamp and no sentence, so there is nothing for a careless
/// render to turn into a claim.
@immutable
sealed class ImagesDeletedStatement {
  const ImagesDeletedStatement();

  /// True only when the product may state that the images are gone.
  bool get mayClaimDeletion => this is ImagesDeleted;
}

/// The images are confirmed deleted. A03 states it.
@immutable
class ImagesDeleted extends ImagesDeletedStatement {
  const ImagesDeleted(this.at);

  /// When G1's purge recorded the deletion.
  final DateTime at;

  @override
  bool operator ==(Object other) => other is ImagesDeleted && other.at == at;

  @override
  int get hashCode => at.hashCode;
}

/// No deletion has been recorded. A03 renders "deletion pending" and **never**
/// the deletion sentence.
@immutable
class ImagesDeletionPending extends ImagesDeletedStatement {
  const ImagesDeletionPending();

  @override
  bool operator ==(Object other) => other is ImagesDeletionPending;

  @override
  int get hashCode => 0;
}

class VerificationClaim {
  const VerificationClaim();

  /// Derived from the record. Never hardcoded, and never defaulted to the
  /// reassuring branch.
  static ImagesDeletedStatement imagesDeletedStatement(
    VerificationRecord record,
  ) {
    final at = record.imagesDeletedAt;
    return at == null ? const ImagesDeletionPending() : ImagesDeleted(at);
  }
}
