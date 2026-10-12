/// What the coach screens render, computed without a widget in sight.
///
/// `ARCHITECTURE.md` §1: *"A view model may not restate a rule, and a widget may
/// never contain one."* So nothing here decides anything. The branch comes from
/// [CoachToday.resolve], the rights from [CoachPublishingRights], the rating
/// threshold from [RatingDisplay], the capacity from [CoachCapacity]. This file
/// only *arranges* those answers, which is why the whole of `K07`'s behaviour is
/// testable without pumping a frame.
///
/// # The one thing these models refuse to produce
///
/// **A number about money.** [CoachEarningsViewModel.statement] and
/// [CoachTodayViewModel.statement] are null unless the payment seam supplied a
/// real one, and the seam has no implementation (`payments.dart`). So
/// [CoachEarningsViewModel.canShowMoney] is false today, and `K17` and `K07`
/// render **nothing about money** rather than a zero.
///
/// That is the same move `ProgressSummary` makes with `TierLadder.unauthored`:
/// a figure nobody computed is not drawn. The prototype's `K24` shows
/// "Earnings this month · 0 EGP" and this deliberately does not — a zero is a
/// claim about her month, and we have no basis for it.
///
/// Everything money-shaped is additionally behind `Feature.payments`, which
/// ships off.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../routing/app_router.dart';
import '../domain/coach_capacity.dart';
import '../domain/coach_credentials.dart';
import '../domain/coach_desk.dart';
import '../domain/coach_profile.dart';
import '../domain/coach_verification.dart';
import '../domain/offer.dart';
import '../domain/payments.dart';

/// Her setup, one thing a screen, in the order she meets it.
///
/// Her photo, her name and city, what she coaches, how she coaches, her
/// prices and plans, her clients' results, what her clients say, her
/// certificates, the three rules, how she is paid, and the check. A step whose
/// screen is switched off is skipped and not counted ([coachSetupWalk]), so
/// the bar never promises a step she will not meet.
enum CoachSetupStep {
  photo('K01'),
  about('K08'),
  specialties('K03'),
  howYouCoach('K10'),
  packages('K04'),
  results('K11'),
  reviews('K12'),
  certificates('K02'),
  rules('K13'),
  payout('K05'),
  beingChecked('K06');

  const CoachSetupStep(this.screenId);

  /// The screen this step is.
  final String screenId;

  /// 1-based place in the walk she is on, for "3 of 11" and the bar.
  int get number => coachSetupWalk().indexOf(this) + 1;

  /// How many steps the walk she is on has.
  static int get total => coachSetupWalk().length;

  /// The step after this one in the walk, or null at the end.
  CoachSetupStep? get next {
    final walk = coachSetupWalk();
    final at = walk.indexOf(this);
    return at < 0 || at + 1 >= walk.length ? null : walk[at + 1];
  }
}

/// The steps she will meet, in order: every step of her setup, less any
/// whose own part is switched off. Results and reviews live on her page, so
/// they are skipped while the portfolio is.
List<CoachSetupStep> coachSetupWalk() => [
  for (final step in CoachSetupStep.values)
    if (_ownPartIsOn(step)) step,
];

bool _ownPartIsOn(CoachSetupStep step) {
  final own = AppRouter.screenFeatures[step.screenId];
  return own == null ||
      own == Feature.coachApp ||
      AppRouter.featureFlags.isOn(own);
}

/// The draft `K01`–`K05` accumulate, and whether each step may move on.
///
/// Mutable on purpose — it is a form, held by the flow while she fills it in —
/// but it produces an immutable [CoachProfileDraft] and never a [CoachProfile].
/// The only thing that turns a draft into a profile is [CoachProfileEditor],
/// which enforces every rule the security rules enforce.
class CoachSetupViewModel {
  CoachSetupViewModel({
    required CoachProfile profile,
    this.catalogue = CredentialCatalogue.unauthored,
    List<Certificate> certificates = const <Certificate>[],
    this.payout = const PayoutMethodState.unavailable(
      PaymentUnavailableReason.notImplemented,
    ),
  }) : displayName = profile.displayName,
       city = profile.city,
       tagline = profile.tagline,
       photoBlurred = profile.photoBlurred,
       specialties = {...profile.specialties},
       languages = {...profile.languages},
       clientPlaces = {...profile.clientPlaces},
       capacityMax = profile.capacity.isSet ? profile.capacity.max : null,
       _certificates = [...certificates];

  /// The credentials she may pick from. Empty until somebody authors the list,
  /// and an empty catalogue means `K02` offers nothing rather than inventing
  /// names.
  final CredentialCatalogue catalogue;

  String displayName;
  String city;
  String tagline;

  /// §2 rule 6. Born true, and only an explicit named action moves it.
  bool photoBlurred;

  /// The photo she took on `K01`, held by the flow. Nothing uploads it yet:
  /// the media pipeline that blurs and stores coach photos is not built, so
  /// it lives on this phone until it is.
  Uint8List? photo;

  final Set<Specialty> specialties;
  final Set<CoachLanguage> languages;
  final Set<ClientPlace> clientPlaces;

  /// Null until she answers `K04`. **Not defaulted to twenty** — see
  /// [CoachCapacity.unset].
  int? capacityMax;

  final List<Certificate> _certificates;

  /// What the payment seam last said about her payout method.
  ///
  /// Mutable, because `K05` replaces it when the rail answers — and
  /// [PayoutMethodState.unavailable] by default, because today the rail does
  /// not answer at all.
  PayoutMethodState payout;

  /// She chose "Add payout later" on `K05` rather than a method.
  bool payoutLater = false;

  /// She has agreed to the three rules on `K13`, or had already.
  bool rulesAgreed = false;

  List<Certificate> get certificates => List.unmodifiable(_certificates);

  void addCertificate(Certificate certificate) {
    final at = _certificates.indexWhere((c) => c.id == certificate.id);
    if (at >= 0) {
      _certificates[at] = certificate;
    } else {
      _certificates.add(certificate);
    }
  }

  void removeCertificate(String id) =>
      _certificates.removeWhere((c) => c.id == id);

  /// Turning a specialty on, within `K03`'s cap of three.
  ///
  /// Returns false when the cap refused it, so the screen can say so rather
  /// than silently dropping the tap.
  bool toggleSpecialty(Specialty specialty) {
    if (specialties.remove(specialty)) return true;
    if (specialties.length >= CoachProfile.maxSpecialties) return false;
    specialties.add(specialty);
    return true;
  }

  void toggleLanguage(CoachLanguage language) {
    if (!languages.remove(language)) languages.add(language);
  }

  void togglePlace(ClientPlace place) {
    if (!clientPlaces.remove(place)) clientPlaces.add(place);
  }

  /// Whether the primary button on [step] may be tapped.
  bool canAdvanceFrom(CoachSetupStep step) => switch (step) {
    // A photo is asked for, not demanded: a coach can add it from her page.
    CoachSetupStep.photo => true,
    CoachSetupStep.about =>
      displayName.trim().isNotEmpty && city.trim().isNotEmpty,
    CoachSetupStep.specialties => specialties.isNotEmpty,
    CoachSetupStep.howYouCoach => true,
    CoachSetupStep.packages => capacityMax != null,
    // Results and reviews come from her clients once she has them.
    CoachSetupStep.results => true,
    CoachSetupStep.reviews => true,
    // She may move on without one — `K02` is where she adds them and the
    // check cannot start until she does, but trapping her on the screen
    // teaches her nothing. `SetupCompleted` is what actually requires one.
    CoachSetupStep.certificates => true,
    CoachSetupStep.rules => rulesAgreed,
    // `K05` cannot be completed at all until a payment rail exists.
    CoachSetupStep.payout => payout.isUsable,
    CoachSetupStep.beingChecked => true,
  };

  /// The field-scoped update this flow would write.
  CoachProfileDraft toDraft() => CoachProfileDraft(
    displayName: displayName,
    city: city,
    tagline: tagline,
    photoBlurred: photoBlurred,
    specialties: specialties,
    languages: languages,
    clientPlaces: clientPlaces,
    capacityMax: capacityMax,
  );

  /// The three preconditions `SetupCompleted` needs, read from real state
  /// rather than from a button she tapped.
  SetupCompleted toSetupEvent({required DateTime now}) => SetupCompleted(
    hasCertificate: CertificateStanding.of(
      _certificates,
      now: now,
    ).hasSubmittedAny,
    hasPayoutMethod: payout.isUsable,
    hasCapacity: capacityMax != null,
    payoutDeferred: payoutLater,
  );
}

/// `K07` and `K24` — the same route, two renderings.
@immutable
class CoachTodayViewModel {
  const CoachTodayViewModel({
    required this.state,
    required this.rows,
    required this.overflowCount,
    required this.capacity,
    required this.firstWeek,
    required this.rights,
    required this.canShowMoney,
    this.statement,
    this.oldestWait,
    this.asOf,
  });

  factory CoachTodayViewModel.from({
    required CoachProfile profile,
    required CoachDesk desk,
    required DateTime now,
    FeatureFlags flags = FeatureFlags.shipped,
  }) {
    final statement = desk.earnings.statementOrNull;
    final oldest = desk.oldestWaitingSince;

    return CoachTodayViewModel(
      state: CoachToday.resolve(desk: desk, capacity: profile.capacity),
      rows: desk.queue,
      overflowCount: desk.overflowCount,
      capacity: profile.capacity,
      firstWeek: desk.firstWeek,
      rights: CoachPublishingRights.forState(desk.verification),
      // Both halves. The flag is the switch; the statement is the substance.
      canShowMoney: flags.isOn(Feature.payments) && statement != null,
      statement: statement,
      oldestWait: oldest == null ? null : now.difference(oldest),
      asOf: desk.builtAt,
    );
  }

  final CoachTodayState state;
  final List<DeskQueueItem> rows;
  final int overflowCount;
  final CoachCapacity capacity;
  final CoachFirstWeek firstWeek;
  final CoachPublishingRights rights;

  /// False whenever the seam did not supply a figure, or the flag is dark.
  /// **A false here means the screen says nothing about money at all.**
  final bool canShowMoney;

  final EarningsStatement? statement;
  final Duration? oldestWait;

  /// When the desk was last rebuilt, for the "as of" line on a cached read.
  final DateTime? asOf;

  bool get isDayOne => state.isDayOne;

  bool get showsVerificationCard => state.showsVerificationCard;

  /// Whether anything is waiting on her, counting the overflow.
  bool get hasWork => rows.isNotEmpty || overflowCount > 0;

  int get waitingCount => rows.length + overflowCount;

  /// Enquiry rows, which are the ones that open `K09`.
  List<DeskQueueItem> get enquiries =>
      rows.where((r) => r.reason == DeskReason.newEnquiry).toList();
}

/// `K17` — her earnings.
@immutable
class CoachEarningsViewModel {
  const CoachEarningsViewModel({
    required this.canShowMoney,
    this.statement,
    this.destination,
    this.unavailableReason,
    this.payoutUnavailableReason,
  });

  factory CoachEarningsViewModel.from({
    required EarningsState earnings,
    required PayoutMethodState payout,
    FeatureFlags flags = FeatureFlags.shipped,
  }) {
    final flagOff = !flags.isOn(Feature.payments);
    final statement = earnings.statementOrNull;

    return CoachEarningsViewModel(
      canShowMoney: !flagOff && statement != null,
      statement: flagOff ? null : statement,
      destination: payout is PayoutMethodSet ? payout.destination : null,
      unavailableReason: flagOff
          ? PaymentUnavailableReason.featureOff
          : earnings is EarningsUnavailable
          ? earnings.reason
          : null,
      payoutUnavailableReason: flagOff
          ? PaymentUnavailableReason.featureOff
          : payout is PayoutMethodUnavailable
          ? payout.reason
          : null,
    );
  }

  /// The one gate. False means `K17` draws its empty state and no figures.
  final bool canShowMoney;

  final EarningsStatement? statement;
  final PayoutDestination? destination;

  /// Why there is no statement. Null when there is one.
  final PaymentUnavailableReason? unavailableReason;

  /// Why her payout method is unknown. Null when it is known — including when
  /// the answer is "she has not set one", which is a different thing.
  final PaymentUnavailableReason? payoutUnavailableReason;

  /// Whether the screen may say where her money goes.
  bool get knowsDestination => destination != null;
}

/// `K18` — her public profile, as she sees it.
@immutable
class CoachPublicProfileViewModel {
  const CoachPublicProfileViewModel({
    required this.profile,
    required this.offers,
    required this.rights,
    required this.certificateStanding,
    required this.rating,
    required this.replyTimeMinutes,
  });

  factory CoachPublicProfileViewModel.from({
    required CoachProfile profile,
    required OfferReader offers,
    required List<Certificate> certificates,
    required DateTime now,
    CoachReviewSummary reviews = CoachReviewSummary.none,
  }) => CoachPublicProfileViewModel(
    profile: profile,
    // Read, never written. `K18` is handed an OfferReader and therefore has no
    // method that could change one — `K04` is the single writer.
    offers: offers.allOffers(),
    rights: CoachPublishingRights.forState(profile.verification),
    certificateStanding: CertificateStanding.of(certificates, now: now),
    // Null below five reviews, and null renders nothing at all.
    rating: RatingDisplay.forReviews(reviews),
    // Measured, not typed. Null renders no claim rather than a plausible one.
    replyTimeMinutes: profile.replyTimeP50Mins,
  );

  final CoachProfile profile;
  final List<Offer> offers;
  final CoachPublishingRights rights;
  final CertificateStanding certificateStanding;

  /// Her average, or null. **Null draws nothing** — not a placeholder, not zero
  /// stars, not "no rating yet".
  final double? rating;

  /// Her measured reply time, or null.
  final int? replyTimeMinutes;

  bool get showsRating => rating != null;

  bool get showsReplyTime => replyTimeMinutes != null;

  /// Whether the badge stands.
  bool get showsVerifiedBadge => certificateStanding.holdsAnyCleared;

  /// Whether the page is visible to anyone yet.
  bool get isLive => rights.pageIsLive;

  /// The state `K06` promises and `K18` has to make visible: she wrote all of
  /// this and none of it is public.
  bool get isAuthoredButUnpublished =>
      rights.isAuthoringWhileUnpublished && offers.isNotEmpty;

  /// Offers a client would actually see.
  List<Offer> get publishedOffers => offers.where((o) => o.published).toList();
}
