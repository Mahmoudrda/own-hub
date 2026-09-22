/// Certificates — `K02`, and the badge `K18` renders.
///
/// # A certificate is an id, never a sentence
///
/// The owner's rule: *"Certificates are ids into a verified list — no free text;
/// a coach cannot type a certificate she does not hold."* So [Certificate] has
/// **no title, name or body field**. It carries a [Certificate.credentialId]
/// which must resolve inside a [CredentialCatalogue], and the words a woman
/// reads come from the catalogue entry, not from her keyboard.
///
/// That is the difference between this file and `offer.dart`, where free text is
/// correct: an offer is her own words about her own package, and a certificate
/// is a claim about a third party. A text field here would let "NASM CPT" be
/// typed by someone who holds nothing, and the badge on `K18` would then mean
/// only that she could spell it.
///
/// # The catalogue is unauthored, and says so
///
/// **Nobody has written the verified credential list.** It is absent from
/// `6-v2/content`, from `SCHEMA-SPINE.md` and from G12, and the dictionary
/// carries a standalone label for exactly one credential (`nasmCpt`). So
/// [CredentialCatalogue.unauthored] is the default and
/// [CredentialCatalogue.dictionaryBacked] holds the one entry that can honestly
/// be shown today.
///
/// This is the same move `ProgressSummary` makes with `TierLadder.unauthored`
/// and `AllergyGuard` makes with unauthored allergens: a list nobody wrote is
/// rendered as empty, not as a plausible guess. `K02` with an empty catalogue
/// says it cannot offer her anything to pick yet — which is true — rather than
/// inventing six credential names and letting a coach claim one.
///
/// # Only a human clears one
///
/// [CertificateStateMachine] mirrors `coach_verification.dart`: the automated
/// issuing-body lookup can move a certificate to [CertificateState.checking] and
/// no further, and [CertificateState.verified] is reachable only through a
/// [ReviewerDecision]. G12 §5, rule 8's row: *"Certificate review is a human
/// reading a document."*
///
/// # Expiry is lazy
///
/// G12 §3.2 — *"lazily, on read — no sweeper"*, the precedent G6 and G8 set.
/// [Certificate.stateAt] computes expiry from [Certificate.expiresAt] at read
/// time, so there is no scheduled job whose failure silently keeps a lapsed
/// credential looking current.
library;

import 'package:meta/meta.dart';

import 'coach_verification.dart'
    show CoachVerificationFailReason, ReviewerDecision;

/// One credential the platform recognises.
///
/// [id] is what is stored. [labelKey] is the dictionary getter a screen resolves
/// to draw it — a *key*, not a string, so this domain file holds no English and
/// the Arabic build draws Arabic.
@immutable
class Credential {
  const Credential({required this.id, required this.labelKey});

  /// Stable, stored, and never shown. Renaming a label must not rewrite
  /// everybody's certificates.
  final String id;

  /// The `AppL10n` getter name. Resolved in `presentation/`, because a domain
  /// file that imported `AppL10n` would need a `BuildContext` to be useful and
  /// would stop being testable without a widget.
  final String labelKey;

  @override
  bool operator ==(Object other) => other is Credential && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The verified list. A credential not in here cannot be claimed.
@immutable
class CredentialCatalogue {
  const CredentialCatalogue(this.entries);

  /// **The honest default.** Nobody has authored the list, so `K02` offers
  /// nothing to pick and says so, rather than offering names it invented.
  static const CredentialCatalogue unauthored = CredentialCatalogue(
    <Credential>[],
  );

  /// Every credential whose name the dictionary can actually render.
  ///
  /// One entry. The dictionary holds "NASM CPT" standalone; every other
  /// credential it mentions is inside a composite sentence
  /// (`nasmCptPreAndPostnatalVerified`, `registeredDietitianAndCoachPostpartumStrength`)
  /// which cannot be reused as a name. Adding a second entry means minting a
  /// string first, and that is reported rather than worked around.
  static const CredentialCatalogue dictionaryBacked = CredentialCatalogue(
    <Credential>[Credential(id: 'nasm_cpt', labelKey: 'nasmCpt')],
  );

  final List<Credential> entries;

  bool get isAuthored => entries.isNotEmpty;

  int get count => entries.length;

  /// The entry with this id, or null. Null is what makes a typed credential
  /// unstorable.
  Credential? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  bool contains(String id) => byId(id) != null;
}

/// Where one certificate has got to. G12 §3.2.
enum CertificateState {
  /// Chosen on the device with no signal. The file is queued locally and
  /// **nothing has been uploaded** (`P0-CVER-05`).
  localPending,

  /// The bytes are in Storage.
  uploaded,

  /// The automated issuing-body lookup is running. It decides nothing.
  checking,

  /// A woman reviewer cleared it.
  verified,

  /// A woman reviewer did not clear it. She may replace it.
  rejected,

  /// It was genuine and has lapsed. Computed at read time, never swept.
  expired;

  /// Whether this certificate currently supports a badge.
  bool get counts => this == verified;

  /// Whether she may delete it. Never mid-review (G12 §6).
  bool get isDeletable => this == uploaded || this == rejected;

  /// Whether the app may describe it as uploaded. `localPending` may not be,
  /// which is the whole of `P0-CVER-05`.
  bool get hasLeftTheDevice => this != localPending;
}

/// What `K02` sends when she adds one.
///
/// Validated through [validate], so an invalid draft is not constructible and
/// there is no path from a text field to a stored certificate.
@immutable
class CertificateDraft {
  const CertificateDraft._({
    required this.credentialId,
    required this.mediaRef,
    required this.issuedAt,
    this.expiresAt,
  });

  /// Builds a draft, or returns null when it could not be one.
  ///
  /// Three refusals, and each is a rule rather than a nicety:
  ///
  ///  * [credentialId] must exist in [catalogue] — the no-free-text rule.
  ///  * [mediaRef] must sit under `coach-docs/{coachUid}/`, which is what the
  ///    Storage rules enforce (G12 §6). Building the path here means a client
  ///    cannot write outside its own folder even before the rules see it.
  ///  * An expiry before its issue date is a typo, not a credential.
  static CertificateDraft? validate({
    required CredentialCatalogue catalogue,
    required String credentialId,
    required String coachUid,
    required String mediaRef,
    required DateTime issuedAt,
    DateTime? expiresAt,
  }) {
    if (!catalogue.contains(credentialId)) return null;
    if (!mediaRef.startsWith('coach-docs/$coachUid/')) return null;
    if (expiresAt != null && !expiresAt.isAfter(issuedAt)) return null;
    return CertificateDraft._(
      credentialId: credentialId,
      mediaRef: mediaRef,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
    );
  }

  final String credentialId;

  /// The Storage path. **Not a URL and not bytes** — this layer never holds the
  /// picture, and reviewers read it with admin credentials (G12 §6).
  final String mediaRef;

  final DateTime issuedAt;
  final DateTime? expiresAt;
}

/// One certificate, as stored.
///
/// Note the absences. No title. No issuing-body free text. No provider response.
/// No image bytes, path-to-a-photo or download URL. Everything this type can
/// hold is either an id, a date, or a coarse code.
@immutable
class Certificate {
  const Certificate({
    required this.id,
    required this.credentialId,
    required this.mediaRef,
    required this.issuedAt,
    required this.state,
    this.expiresAt,
    this.decidedAt,
    this.failReason,
  });

  /// Built from a validated draft, in the one state a device is allowed to
  /// create: [CertificateState.uploaded] with signal,
  /// [CertificateState.localPending] without it.
  factory Certificate.fromDraft(
    CertificateDraft draft, {
    required String id,
    required bool online,
  }) => Certificate(
    id: id,
    credentialId: draft.credentialId,
    mediaRef: draft.mediaRef,
    issuedAt: draft.issuedAt,
    expiresAt: draft.expiresAt,
    state: online ? CertificateState.uploaded : CertificateState.localPending,
  );

  /// Deterministic in production — `{credentialId}_{issuedAt}` — so a queued
  /// upload replayed on reconnect collides with itself instead of creating a
  /// second certificate (spine C1, `P0-CVER-05`'s "exactly once").
  final String id;

  final String credentialId;
  final String mediaRef;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final CertificateState state;
  final DateTime? decidedAt;

  /// Coarse code only. Shared with `coach_verification.dart` deliberately: one
  /// vocabulary, so a certificate and the account it belongs to cannot describe
  /// the same refusal two different ways.
  final CoachVerificationFailReason? failReason;

  /// Its state as of [now], applying expiry lazily.
  ///
  /// A verified certificate whose [expiresAt] has passed reads as
  /// [CertificateState.expired] without anything having run. G12 §3.2.
  CertificateState stateAt(DateTime now) {
    final ends = expiresAt;
    if (state == CertificateState.verified &&
        ends != null &&
        !now.isBefore(ends)) {
      return CertificateState.expired;
    }
    return state;
  }

  Certificate copyWith({
    CertificateState? state,
    DateTime? decidedAt,
    CoachVerificationFailReason? failReason,
  }) => Certificate(
    id: id,
    credentialId: credentialId,
    mediaRef: mediaRef,
    issuedAt: issuedAt,
    expiresAt: expiresAt,
    state: state ?? this.state,
    decidedAt: decidedAt ?? this.decidedAt,
    failReason: failReason ?? this.failReason,
  );
}

/// What can happen to one certificate.
@immutable
sealed class CertificateEvent {
  const CertificateEvent();
}

/// The queued file reached Storage. The only transition a device may cause.
class CertificateUploaded extends CertificateEvent {
  const CertificateUploaded();
}

/// The automated lookup started. **It never finishes into a decision** — see
/// [CertificateStateMachine].
class CertificateLookupStarted extends CertificateEvent {
  const CertificateLookupStarted();
}

/// A woman reviewer cleared it.
class CertificateCleared extends CertificateEvent {
  const CertificateCleared(this.decision);
  final ReviewerDecision decision;
}

/// A woman reviewer did not clear it.
class CertificateRefused extends CertificateEvent {
  const CertificateRefused(this.decision, this.reason);
  final ReviewerDecision decision;
  final CoachVerificationFailReason reason;
}

/// The certificate's own machine. Pure, like the account-level one.
class CertificateStateMachine {
  const CertificateStateMachine();

  /// Applies [event]. Returns the certificate unchanged when the event does not
  /// apply, so a replayed write is inert rather than fatal.
  Certificate transition(Certificate current, CertificateEvent event) {
    switch (event) {
      case CertificateUploaded():
        if (current.state != CertificateState.localPending) return current;
        return current.copyWith(state: CertificateState.uploaded);

      case CertificateLookupStarted():
        if (current.state != CertificateState.uploaded) return current;
        return current.copyWith(state: CertificateState.checking);

      // The rule. A lookup gets it as far as `checking`; a person gets it the
      // rest of the way. There is no event here that a machine can raise which
      // reaches `verified`.
      case CertificateCleared():
        if (!event.decision.isAdmissible) return current;
        if (current.state != CertificateState.uploaded &&
            current.state != CertificateState.checking) {
          return current;
        }
        return current.copyWith(
          state: CertificateState.verified,
          decidedAt: event.decision.decidedAt,
        );

      case CertificateRefused():
        if (!event.decision.isAdmissible) return current;
        if (current.state != CertificateState.uploaded &&
            current.state != CertificateState.checking) {
          return current;
        }
        return current.copyWith(
          state: CertificateState.rejected,
          decidedAt: event.decision.decidedAt,
          failReason: event.reason,
        );
    }
  }
}

/// What a whole set of certificates says about her, at a moment in time.
///
/// `K02`'s list, `K18`'s badge and `coach_verification.dart`'s
/// [AllCertificatesExpired] event all ask the same three questions of the same
/// list, and asking them in one place is what stops the badge and the list
/// disagreeing.
@immutable
class CertificateStanding {
  const CertificateStanding({
    required this.total,
    required this.cleared,
    required this.waiting,
    required this.refused,
    required this.lapsed,
    required this.queuedOnDevice,
  });

  factory CertificateStanding.of(
    List<Certificate> certificates, {
    required DateTime now,
  }) {
    var cleared = 0, waiting = 0, refused = 0, lapsed = 0, queued = 0;
    for (final c in certificates) {
      switch (c.stateAt(now)) {
        case CertificateState.verified:
          cleared++;
        case CertificateState.uploaded:
        case CertificateState.checking:
          waiting++;
        case CertificateState.rejected:
          refused++;
        case CertificateState.expired:
          lapsed++;
        case CertificateState.localPending:
          queued++;
      }
    }
    return CertificateStanding(
      total: certificates.length,
      cleared: cleared,
      waiting: waiting,
      refused: refused,
      lapsed: lapsed,
      queuedOnDevice: queued,
    );
  }

  final int total;
  final int cleared;
  final int waiting;
  final int refused;
  final int lapsed;

  /// Chosen with no signal and not yet uploaded. Never counted as anything else.
  final int queuedOnDevice;

  /// Whether `SetupCompleted` can be raised: at least one certificate that has
  /// actually left the device.
  bool get hasSubmittedAny => total - queuedOnDevice > 0;

  /// Whether her badge stands.
  bool get holdsAnyCleared => cleared > 0;

  /// `AllCertificatesExpired`'s precondition: she had some, and every one of
  /// them has lapsed.
  bool get everythingLapsed => total > 0 && lapsed == total;
}
