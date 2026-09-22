/// The coach's ONE profile — what `K01`–`K06` write and `K07`, `K18`, the
/// directory (`H01`) and her page (`H02`) read.
///
/// ## One repository, not a copy
///
/// `AppRouter.coachRepository` was already the single instance `K07`, `K09`,
/// `K17`, `K25` and the planning screens read. What was missing is that `K01`–
/// `K05` never wrote to it: they filled a form ([CoachSetupViewModel]) and the
/// form was never saved, so her name from `K01` reached nothing. This file is
/// the save. Every setup callback calls [CoachProfileState.saveSetup], which
/// applies the form through [CoachProfileEditor] — the same field-scoped,
/// rule-enforcing path the real backend uses — so a refused write (four
/// specialties, a capacity of 90) is refused here too.
///
/// ## The test coach
///
/// A coach is listed only once a woman reviewer has read her certificates, and
/// there is no reviewer in this build. While no account is required
/// (`Feature.accountRequired` off) the owner has to be able to finish setup and
/// then find herself in the directory, so finishing `K05` makes her a **test
/// coach**: her profile is given the `verified` state a reviewer would have
/// given it, and [isTestCoach] tells every screen to say so. Nothing records a
/// reviewer — no `ReviewerDecision` is fabricated, her certificates stay
/// unchecked (so `K18` and `H02` draw no badge), and `K06`/`K18` state in words
/// that nobody has looked at them.
library;

import '../domain/flags/feature_flags.dart';
import '../features/coach/domain/coach_credentials.dart';
import '../features/coach/domain/coach_desk.dart';
import '../features/coach/domain/coach_profile.dart';
import '../features/coach/domain/coach_repository.dart';
import '../features/coach/domain/coach_verification.dart';
import '../features/coach/domain/offer.dart';
import '../features/coach/domain/payments.dart';
import '../features/coach/presentation/coach_view_models.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'coaching_test_payments.dart';

class CoachProfileState {
  CoachProfileState._() {
    setup = _newSetup();
  }

  static final CoachProfileState instance = CoachProfileState._();

  /// True while no account is required — the only time a test rail or a test
  /// coach may exist.
  static bool get isTestMode =>
      !AppRouter.featureFlags.isOn(Feature.accountRequired);

  /// THE coach repository. The same object every coach screen reads.
  InMemoryCoachRepository get repository => AppRouter.coachRepository;

  String get coachUid => repository.coachUid;

  /// Her profile as it is stored now.
  CoachProfile get profile => repository.profileUnbilled;

  /// The form `K01`–`K05` fill. Saved by [saveSetup].
  late CoachSetupViewModel setup;

  /// `K05`'s rail. A test rail while no account is required; otherwise there
  /// is none, and `K05` says it cannot be completed.
  TestPayoutProvider _payout = TestPayoutProvider();

  bool _testChecked = false;

  /// Whether she is a **test coach** — counted as checked because no account
  /// is required, not because anyone reviewed anything.
  bool get isTestCoach => isTestMode && _testChecked;

  CoachSetupViewModel _newSetup() => CoachSetupViewModel(
    profile: profile,
    // The one credential the dictionary can name. `unauthored` would offer
    // nothing at all, and `K02` could never be tried.
    catalogue: CredentialCatalogue.dictionaryBacked,
    payout: isTestMode
        ? const PayoutMethodState.none()
        : const PayoutMethodState.unavailable(
            PaymentUnavailableReason.notImplemented,
          ),
  );

  // ────────────────────────────────────────────────────────── K01–K05

  /// Writes the form to the profile. Field-scoped: a blank name or city is
  /// left out rather than sent (the editor would refuse the whole draft over
  /// it, and her specialties with it).
  CoachProfileSave saveSetup() {
    final draft = CoachProfileDraft(
      displayName: setup.displayName.trim().isEmpty
          ? null
          : setup.displayName.trim(),
      city: setup.city.trim().isEmpty ? null : setup.city.trim(),
      tagline: setup.tagline,
      photoBlurred: setup.photoBlurred,
      specialties: {...setup.specialties},
      languages: {...setup.languages},
      clientPlaces: {...setup.clientPlaces},
      capacityMax: setup.capacityMax,
    );
    final result = const CoachProfileEditor().apply(
      profile,
      draft,
      now: DateTime.now(),
    );
    // `saveProfile` applies synchronously; the future only reports it.
    repository.saveProfile(draft);
    AppChanges.bump();
    return result;
  }

  /// `K02` in test mode: records the certificate she picked, without a photo.
  ///
  /// There is no file picker in this build. The row it produces is labelled as
  /// a test and as unchecked on `K02`, and nothing ever moves it further.
  Certificate? addTestCertificate(String credentialId) {
    if (!isTestMode) return null;
    final issued = DateTime.now();
    final day = DateTime(issued.year, issued.month, issued.day);
    final draft = CertificateDraft.validate(
      catalogue: setup.catalogue,
      credentialId: credentialId,
      coachUid: coachUid,
      mediaRef: 'coach-docs/$coachUid/test-$credentialId',
      issuedAt: day,
    );
    if (draft == null) return null;
    final certificate = Certificate.fromDraft(
      draft,
      id: '${draft.credentialId}_${draft.issuedAt.toIso8601String()}',
      online: true,
    );
    repository.addCertificate(draft, online: true);
    setup.addCertificate(certificate);
    AppChanges.bump();
    return certificate;
  }

  /// `K05` in test mode: records where she would be paid.
  Future<PayoutMethodState> setTestPayout(PayoutMethodDraft draft) async {
    if (!isTestMode) return setup.payout;
    final next = await _payout.setPayoutMethod(draft);
    setup.payout = next;
    AppChanges.bump();
    return next;
  }

  /// `K05` → `K06`. Saves, submits, and — in test mode — makes her a test
  /// coach.
  void completeSetup() {
    saveSetup();
    final now = DateTime.now();
    final outcome = const CoachVerificationStateMachine().transition(
      profile.verification,
      setup.toSetupEvent(now: now),
    );
    var next = profile;
    if (outcome.changed) next = next.copyWith(verification: outcome.state);

    if (isTestMode) {
      // What a reviewer's decision would have produced, and nothing more: no
      // reviewer is named, no certificate is cleared, and `isTestCoach` makes
      // every screen say so.
      next = next.copyWith(
        verification: CoachVerificationState.verified,
        acceptingClients: next.capacity.hasRoom,
      );
      _testChecked = true;
    }
    repository.applyServerProfileChange(next);
    _mirrorDesk();
    if (next.verification.mayPublish) _publishOffers();
    AppChanges.bump();
  }

  /// The desk mirrors her credential state, as the desk Function would.
  void _mirrorDesk() {
    final desk = repository.deskUnbilled;
    repository.rebuildDesk(
      CoachDesk(
        queue: desk.queue,
        overflowCount: desk.overflowCount,
        verification: profile.verification,
        firstWeek: desk.firstWeek,
        earnings: desk.earnings,
        builtAt: DateTime.now(),
      ),
    );
  }

  /// Marks a step of her first week done on the desk (the Function's job).
  void markFirstWeekStep(CoachFirstWeekStep step) {
    final desk = repository.deskUnbilled;
    if (desk.firstWeek.completed.contains(step)) return;
    repository.rebuildDesk(
      CoachDesk(
        queue: desk.queue,
        overflowCount: desk.overflowCount,
        verification: desk.verification,
        firstWeek: desk.firstWeek.withStep(step),
        earnings: desk.earnings,
        builtAt: DateTime.now(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────── K04

  /// `K04`'s single write path, with the rights her state gives her now.
  PackagesEditor get packagesEditor => PackagesEditor(
    reader: repository,
    writer: repository,
    rights: CoachPublishingRights.forState(profile.verification),
  );

  /// Everything she wrote, published or not.
  List<Offer> get offers => repository.allOffers();

  /// What a client can see.
  List<Offer> get publishedOffers => repository.publicOffers();

  /// The next deterministic offer id.
  String nextOfferId() {
    var highest = 0;
    for (final offer in repository.allOffers()) {
      final n = int.tryParse(offer.id.replaceFirst('offer-', ''));
      if (n != null && n > highest) highest = n;
    }
    return 'offer-${highest + 1}';
  }

  /// `K04`'s save path: writes nothing itself, and publishes what her
  /// credential state already allows.
  ///
  /// [PackagesEditor.save] deliberately leaves a brand-new offer unpublished —
  /// "she writes it now, and nobody sees it until her certificates clear". Once
  /// they have cleared there is no second screen where she would tap publish,
  /// so the same rule is applied here, through the same editor.
  void publishOffersIfAllowed() {
    if (profile.verification.mayPublish) _publishOffers();
    AppChanges.bump();
  }

  /// Publishes every offer she wrote while she could not publish.
  void _publishOffers() {
    final editor = packagesEditor;
    for (final offer in repository.allOffers()) {
      if (!offer.published) editor.publish(offer.id);
    }
  }

  // ───────────────────────────────────────────────────────────── K18

  CoachPublicProfileViewModel publicProfileModel(DateTime now) =>
      CoachPublicProfileViewModel.from(
        profile: profile,
        offers: repository,
        certificates: setup.certificates,
        now: now,
      );

  // ──────────────────────────────────────────────────────────── tests

  /// Back to a coach who has answered nothing. For tests.
  void reset() {
    repository.applyServerProfileChange(const CoachProfile());
    for (final offer in [...repository.allOffers()]) {
      repository.deleteOffer(offer.id);
    }
    for (final certificate in setup.certificates) {
      repository.removeCertificate(certificate.id);
    }
    repository.rebuildDesk(CoachDesk());
    _payout = TestPayoutProvider();
    _testChecked = false;
    setup = _newSetup();
  }
}
