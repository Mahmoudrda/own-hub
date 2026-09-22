/// What the coach app reads and writes.
///
/// The interface is what the screens depend on; [InMemoryCoachRepository] is the
/// fake they are built and tested against until Firestore lands. Keeping the
/// screens on an interface is what lets `K01`–`K25` be verified without a
/// network, an emulator or a signed-in account.
///
/// # The read budget is part of the contract
///
/// `P0-CSCALE-01` counts document reads. So does this fake:
/// [InMemoryCoachRepository.documentReads] increments once per document
/// returned — the correction `RECONCILIATION.md` row 9 records, that a range
/// read is not one read — and a test asserts that opening Today costs **two**
/// at any roster size. A fake that did not count could not fail that case.
///
/// # Offers are read here and written elsewhere
///
/// This repository implements [OfferReader]. It also implements [OfferWriter],
/// because something has to persist an offer — but the writer is reached only
/// through [PackagesEditor], which `K04` constructs and no other screen is
/// given. See `offer.dart`.
///
/// # The desk is never written by a device
///
/// G12 §1.3 and §4: `private/desk` is self-read, Cloud-Function-write. There is
/// no `saveDesk` on this interface, and [InMemoryCoachRepository.rebuildDesk] is
/// named for what it stands in for — the Function — rather than pretending to be
/// something a screen may call.
library;

import 'dart:async';

import 'client_view.dart';
import 'coach_capacity.dart';
import 'coach_credentials.dart';
import 'coach_desk.dart';
import 'coach_profile.dart';
import 'coach_verification.dart';
import 'enquiry.dart';
import 'offer.dart';

/// Everything the coach app needs from storage.
abstract class CoachRepository implements OfferReader {
  /// Her public root. Synchronous, because `K07` must render from cache on open
  /// rather than waiting for a network that may not be there.
  CoachProfile get profile;

  Stream<CoachProfile> watchProfile();

  /// Applies a `K01`/`K03`/`K04` draft. Field-scoped, so a Cloud Function field
  /// is never clobbered.
  Future<CoachProfileSave> saveProfile(CoachProfileDraft draft);

  /// Her certificates — `K02`.
  Future<List<Certificate>> certificates();

  /// Adds one. Queued locally with no signal, and **never shown as uploaded**
  /// (`P0-CVER-05`).
  Future<Certificate> addCertificate(
    CertificateDraft draft, {
    required bool online,
  });

  /// Removes one. Refused mid-review (G12 §6).
  Future<bool> removeCertificate(String certificateId);

  /// The desk — `K06`, `K07`, `K24`, `K25`.
  CoachDesk get desk;

  Stream<CoachDesk> watchDesk();

  /// One enquiry — `K09`.
  Future<Enquiry?> enquiry(String relId);

  /// Records the outcome of an accept or decline, status and capacity together.
  ///
  /// Takes the whole [EnquiryApplied] rather than its parts, so a caller cannot
  /// persist a status change without the capacity that came with it — spine C4,
  /// an increment never travels alone.
  Future<void> commitEnquiry(EnquiryApplied applied);

  Future<void> dispose();
}

/// An in-memory [CoachRepository]. Real behaviour, no storage.
///
/// Deliberately strict where the real one is strict — the specialty cap, the
/// capacity ceiling, the queue cap, the certificate delete rule — because a fake
/// that accepts anything lets a screen pass its tests and then fail in
/// production.
class InMemoryCoachRepository
    implements CoachRepository, OfferWriter, ClientViewReader {
  InMemoryCoachRepository({
    CoachProfile? profile,
    CoachDesk? desk,
    List<Certificate>? certificates,
    List<Offer>? offers,
    Map<String, Enquiry>? enquiries,
    InMemoryClientViewProjection? clientViews,
    this.coachUid = 'coach-1',
  }) : _profile = profile ?? const CoachProfile(),
       _desk = desk ?? CoachDesk(),
       _certificates = [...?certificates],
       _offers = [...?offers],
       _enquiries = {...?enquiries},
       _clientViews = clientViews ?? InMemoryClientViewProjection();

  /// A coach mid-setup: `K01`–`K03` answered, nothing checked yet.
  ///
  /// Figures deliberately unlike the prototype's, so a screen that renders a
  /// sample rather than her data is visible in a test.
  static CoachProfile settingUp() => const CoachProfile(
    displayName: 'Hala Mansour',
    city: 'Tanta',
    tagline: 'Back to lifting, one small week at a time.',
    specialties: {Specialty.postpartum, Specialty.beginners},
    languages: {CoachLanguage.arabic},
    clientPlaces: {ClientPlace.atHome},
    verification: CoachVerificationState.setupIncomplete,
  );

  /// A verified coach with a roster and a quiet evening.
  static CoachProfile working() => CoachProfile(
    displayName: 'Hala Mansour',
    city: 'Tanta',
    tagline: 'Back to lifting, one small week at a time.',
    specialties: const {Specialty.postpartum, Specialty.strength},
    languages: const {CoachLanguage.arabic, CoachLanguage.english},
    clientPlaces: const {ClientPlace.atHome, ClientPlace.ladiesOnlyGym},
    capacity: CoachCapacity(max: 14, taken: 7),
    acceptingClients: true,
    verification: CoachVerificationState.verified,
    replyTimeP50Mins: 95,
  );

  final String coachUid;

  CoachProfile _profile;
  CoachDesk _desk;
  final List<Certificate> _certificates;
  final List<Offer> _offers;
  final Map<String, Enquiry> _enquiries;
  final InMemoryClientViewProjection _clientViews;

  final StreamController<CoachProfile> _profiles =
      StreamController<CoachProfile>.broadcast();
  final StreamController<CoachDesk> _desks =
      StreamController<CoachDesk>.broadcast();

  final CoachProfileEditor _editor = const CoachProfileEditor();

  /// Documents returned since construction. `P0-CSCALE-01`'s instrument.
  int documentReads = 0;

  /// Resets the counter. A test measures one screen open, not a lifetime.
  void resetReadCount() => documentReads = 0;

  // ------------------------------------------------------------- profile ----

  @override
  CoachProfile get profile {
    documentReads++;
    return _profile;
  }

  /// The profile without charging a read. For assertions, never for rendering.
  CoachProfile get profileUnbilled => _profile;

  @override
  Stream<CoachProfile> watchProfile() => _profiles.stream;

  @override
  Future<CoachProfileSave> saveProfile(CoachProfileDraft draft) async {
    final result = _editor.apply(_profile, draft, now: DateTime.now());
    if (result is CoachProfileApplied) {
      _profile = result.profile;
      if (!_profiles.isClosed) _profiles.add(_profile);
    }
    return result;
  }

  /// What a Cloud Function does to the profile. Never reachable from a screen.
  void applyServerProfileChange(CoachProfile next) {
    _profile = next;
    if (!_profiles.isClosed) _profiles.add(next);
  }

  // -------------------------------------------------------- certificates ----

  @override
  Future<List<Certificate>> certificates() async {
    documentReads += _certificates.length;
    return List.unmodifiable(_certificates);
  }

  @override
  Future<Certificate> addCertificate(
    CertificateDraft draft, {
    required bool online,
  }) async {
    // Deterministic, so a queued upload replayed on reconnect collides with
    // itself instead of creating a second certificate.
    final id = '${draft.credentialId}_${draft.issuedAt.toIso8601String()}';
    final existing = _certificates.indexWhere((c) => c.id == id);
    final certificate = Certificate.fromDraft(draft, id: id, online: online);
    if (existing >= 0) {
      _certificates[existing] = certificate;
    } else {
      _certificates.add(certificate);
    }
    return certificate;
  }

  @override
  Future<bool> removeCertificate(String certificateId) async {
    final at = _certificates.indexWhere((c) => c.id == certificateId);
    if (at < 0) return false;
    // G12 §6: `resource.data.state in ['uploaded','rejected']` — never
    // mid-review. The fake enforces what the rules enforce.
    if (!_certificates[at].state.isDeletable) return false;
    _certificates.removeAt(at);
    return true;
  }

  /// What the reviewer's Cloud Function does. Never reachable from a screen.
  void applyCertificateEvent(String certificateId, CertificateEvent event) {
    final at = _certificates.indexWhere((c) => c.id == certificateId);
    if (at < 0) return;
    _certificates[at] = const CertificateStateMachine().transition(
      _certificates[at],
      event,
    );
  }

  // ------------------------------------------------------------ the desk ----

  @override
  CoachDesk get desk {
    documentReads++;
    return _desk;
  }

  /// The desk without charging a read.
  CoachDesk get deskUnbilled => _desk;

  @override
  Stream<CoachDesk> watchDesk() => _desks.stream;

  /// What the debounced Cloud Function does. Named for what it stands in for.
  void rebuildDesk(CoachDesk next) {
    _desk = next;
    if (!_desks.isClosed) _desks.add(next);
  }

  // ----------------------------------------------------------- enquiries ----

  @override
  Future<Enquiry?> enquiry(String relId) async {
    final found = _enquiries[relId];
    if (found != null) documentReads++;
    return found;
  }

  void seedEnquiry(Enquiry enquiry) => _enquiries[enquiry.relId] = enquiry;

  @override
  Future<void> commitEnquiry(EnquiryApplied applied) async {
    _enquiries[applied.enquiry.relId] = applied.enquiry;
    _profile = _profile.copyWith(capacity: applied.capacity);
    if (!_profiles.isClosed) _profiles.add(_profile);
  }

  // -------------------------------------------------------------- offers ----

  @override
  List<Offer> allOffers() => List.unmodifiable(_offers);

  @override
  List<Offer> publicOffers() =>
      List.unmodifiable(_offers.where((o) => o.published));

  @override
  Offer? offerById(String id) {
    for (final o in _offers) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<void> writeOffer(Offer offer) async {
    final at = _offers.indexWhere((o) => o.id == offer.id);
    if (at >= 0) {
      _offers[at] = offer;
    } else {
      _offers.add(offer);
    }
  }

  @override
  Future<void> deleteOffer(String offerId) async =>
      _offers.removeWhere((o) => o.id == offerId);

  // --------------------------------------------------------- client view ----

  @override
  Future<ClientView> forRelationship(String relId) {
    documentReads++;
    return _clientViews.forRelationship(relId);
  }

  /// The projection, for seeding and revoking in tests.
  InMemoryClientViewProjection get projection => _clientViews;

  @override
  Future<void> dispose() async {
    await _profiles.close();
    await _desks.close();
  }
}
