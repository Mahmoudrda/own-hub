/// `coaches/{coachUid}` — the public root, and what `K01`, `K03`, `K18` edit.
///
/// # Rule 11, as a type
///
/// §2 rule 11: nothing is ranked by weight, weight lost or followers. G12 §1.2
/// states it as an absence — *"No rating, follower or weight field exists on this
/// document"* — and §6 backs it with `noRankableKeys()` in the security rules.
///
/// Here it is both. [CoachProfile] has no such field to set, and
/// [CoachProfileWriteMask.rejects] refuses any write whose keys intersect the
/// banned list, so a map assembled at runtime cannot smuggle one past the type.
/// The rules are the second line; this is the first.
///
/// # Rule 6, as an explicit action
///
/// [CoachProfile.photoBlurred] defaults **true**. G12 §9 Q1 records the
/// collision head on: `K01`'s copy says *"Face visible. Clients pick a person,
/// not a logo"* while rule 6 says blur defaults on. The resolution recorded
/// there — and implemented here — is that the default is blurred and showing her
/// face is an **explicit named action with its consequence stated**, never a
/// silent flip. [CoachMediaUploader.resolveBlur] is the only way a photo's blur
/// is decided, and it delegates to G7's `MediaBlurPolicy`, which has no code
/// path that reads a missing choice as "off".
///
/// # A rating is displayed, never stored and never ranked
///
/// The owner's decision: **a rating shows only at five or more reviews.**
/// [RatingDisplay.forReviews] returns null below that, and null renders nothing.
///
/// It is deliberately **not a field on [CoachProfile]** — `ratingAvg` and
/// `ratingCount` are in [kForbiddenRankableKeys], because a numeric field on a
/// world-readable document is auto-indexed by Firestore and therefore sortable,
/// which is a ranking of women whatever the code intends (G12 §1.5, §9 Q11).
/// So the figure is an aggregate read beside the profile, it has no comparison
/// operator, and nothing in this feature sorts by it.
library;

import 'package:meta/meta.dart';

import '../../account/domain/media_blur_policy.dart';
import '../../account/domain/privacy_settings.dart';
import 'coach_capacity.dart';
import 'coach_verification.dart';

/// What she coaches. Ids, not typed words — `K03`'s cap of three only means
/// anything if the client-side filters see the same vocabulary she picked from.
enum Specialty { postpartum, beginners, strength, weightLoss, pregnancy }

/// Languages she coaches in.
enum CoachLanguage { arabic, english }

/// Where her clients train.
enum ClientPlace { atHome, ladiesOnlyGym }

/// Field names a coach document may never carry.
///
/// Mirrors `noRankableKeys()` in G12 §6 exactly. Kept as data rather than as a
/// condition so the same list can be asserted against the deployed rules.
const Set<String> kForbiddenRankableKeys = {
  'followers',
  'followerCount',
  'following',
  'followingCount',
  'ratingAvg',
  'ratingCount',
  'weightKg',
  'weightLost',
  'clientWeightLost',
  'bodyFat',
  'rank',
  'score',
  // §2 rule 3, enforced the same way as rule 11: by naming the fields that may
  // never exist so that a write carrying one is refused before it leaves the
  // device. These two entries are a BAN LIST, not a feature — this file forbids
  // the thing it names, exactly as `product_rules_test.dart` names the same
  // identifiers in order to fail on them.
  'dayStreak',
  'currentStreak',
};

/// Fields the coach herself may write. G12 §6's `coachEditable()`.
const Set<String> coachEditableKeys = {
  'displayName',
  'city',
  'tagline',
  'photoRef',
  'photoBlurred',
  'specialties',
  'languages',
  'clientPlaces',
  'acceptingClients',
  'capacity',
  'serviceHours',
  'updatedAt',
};

/// Fields only a Cloud Function may write. G12 §6's `coachServerOnly()`.
const Set<String> serverOnlyCoachKeys = {
  'verifiedCerts',
  'listed',
  'replyTimeP50Mins',
  'verification',
  'firstWeek',
  // Not in G12's list and belongs there: `capacity.taken` is CF-only, and
  // leaving it out of the mask is exactly how last-write-wins resurrects a
  // stale count and invents a spot (G12 §4).
  'capacity.taken',
};

/// Decides whether a write may leave the device.
///
/// A function rather than a comment, because the failure it prevents is a map
/// built at runtime — from a form, from a merge, from a migration — where no
/// reviewer is looking at a field list.
abstract final class CoachProfileWriteMask {
  /// Every reason [keys] may not be written, or empty when it may.
  ///
  /// Returns the offending keys rather than a boolean so the caller can say
  /// which field it was. A silent `false` is how this gets debugged by guessing.
  static Set<String> rejects(Iterable<String> keys) {
    final offending = <String>{};
    for (final key in keys) {
      if (kForbiddenRankableKeys.contains(key)) offending.add(key);
      if (serverOnlyCoachKeys.contains(key)) offending.add(key);
      if (!coachEditableKeys.contains(key)) offending.add(key);
    }
    return offending;
  }

  static bool allows(Iterable<String> keys) => rejects(keys).isEmpty;
}

/// The public root, as the app holds it.
@immutable
class CoachProfile {
  const CoachProfile({
    this.displayName = '',
    this.city = '',
    this.tagline = '',
    this.photoRef,
    this.photoBlurred = true,
    this.specialties = const <Specialty>{},
    this.languages = const <CoachLanguage>{},
    this.clientPlaces = const <ClientPlace>{},
    this.capacity = CoachCapacity.unset,
    this.acceptingClients = false,
    this.verification = CoachVerificationState.setupIncomplete,
    this.replyTimeP50Mins,
    this.updatedAt,
  });

  /// `K03`'s cap. Three, because a coach who claims everything ranks for
  /// nothing and the client-side filter stops meaning anything.
  static const int maxSpecialties = 3;

  final String displayName;
  final String city;

  /// Her one line. `K01`'s third field.
  final String tagline;

  /// Content-addressed and immutable (G4/G8's CDN convention). Null until she
  /// adds one, and a null photo is a placeholder rather than a blank.
  final String? photoRef;

  /// **Defaults true** — §2 rule 6, spine C11.
  final bool photoBlurred;

  final Set<Specialty> specialties;
  final Set<CoachLanguage> languages;
  final Set<ClientPlace> clientPlaces;
  final CoachCapacity capacity;

  /// May only be true while she holds the claim (G12 §6).
  final bool acceptingClients;

  /// Her credential state. Server-written; read here.
  final CoachVerificationState verification;

  /// **Measured, not typed** — `K18`'s own words. A 30-day rolling p50 computed
  /// by a Cloud Function. Null when there is not enough history to state one,
  /// and null renders no claim at all rather than a plausible "about 2 hours".
  final int? replyTimeP50Mins;

  final DateTime? updatedAt;

  /// Whether the public page is readable. Derived from [verification], never
  /// stored twice — `listed` and `verifiedCerts` are the server's projection of
  /// exactly this.
  bool get isListed => verification.pageIsLive;

  /// What she may do, as one object.
  CoachPublishingRights get rights =>
      CoachPublishingRights.forState(verification);

  /// Whether `acceptingClients` may honestly be shown as true.
  ///
  /// Both halves matter: a coach who holds the claim but has filled her roster
  /// is not accepting anyone, and a coach with room who has lost the claim is
  /// not either.
  bool get isTakingClients =>
      acceptingClients && verification.mayAcceptClients && capacity.hasRoom;

  /// Whether `K01`–`K05` are answered well enough to submit.
  ///
  /// Certificates and payout are not here: they live in their own collections
  /// and are checked by the caller, which is what `SetupCompleted`'s three
  /// separate flags are for.
  bool get profileStepsComplete =>
      displayName.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      specialties.isNotEmpty &&
      capacity.isSet;

  CoachProfile copyWith({
    String? displayName,
    String? city,
    String? tagline,
    String? photoRef,
    bool? photoBlurred,
    Set<Specialty>? specialties,
    Set<CoachLanguage>? languages,
    Set<ClientPlace>? clientPlaces,
    CoachCapacity? capacity,
    bool? acceptingClients,
    CoachVerificationState? verification,
    int? replyTimeP50Mins,
    DateTime? updatedAt,
  }) => CoachProfile(
    displayName: displayName ?? this.displayName,
    city: city ?? this.city,
    tagline: tagline ?? this.tagline,
    photoRef: photoRef ?? this.photoRef,
    photoBlurred: photoBlurred ?? this.photoBlurred,
    specialties: specialties ?? this.specialties,
    languages: languages ?? this.languages,
    clientPlaces: clientPlaces ?? this.clientPlaces,
    capacity: capacity ?? this.capacity,
    acceptingClients: acceptingClients ?? this.acceptingClients,
    verification: verification ?? this.verification,
    replyTimeP50Mins: replyTimeP50Mins ?? this.replyTimeP50Mins,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// What `K01`, `K03` and `K04` send.
///
/// Every field is nullable and null means "not touched", so a draft is a
/// field-scoped update rather than a whole document — which is what stops an
/// offline edit of her tagline from clobbering a Cloud Function's
/// `replyTimeP50Mins` (G12 §4).
@immutable
class CoachProfileDraft {
  const CoachProfileDraft({
    this.displayName,
    this.city,
    this.tagline,
    this.photoRef,
    this.photoBlurred,
    this.specialties,
    this.languages,
    this.clientPlaces,
    this.capacityMax,
    this.acceptingClients,
  });

  final String? displayName;
  final String? city;
  final String? tagline;
  final String? photoRef;
  final bool? photoBlurred;
  final Set<Specialty>? specialties;
  final Set<CoachLanguage>? languages;
  final Set<ClientPlace>? clientPlaces;

  /// Her ceiling only. There is deliberately no `capacityTaken` here.
  final int? capacityMax;

  final bool? acceptingClients;

  /// The field names this draft would write. Fed to [CoachProfileWriteMask].
  Set<String> get touchedKeys => <String>{
    if (displayName != null) 'displayName',
    if (city != null) 'city',
    if (tagline != null) 'tagline',
    if (photoRef != null) 'photoRef',
    if (photoBlurred != null) 'photoBlurred',
    if (specialties != null) 'specialties',
    if (languages != null) 'languages',
    if (clientPlaces != null) 'clientPlaces',
    if (capacityMax != null) 'capacity',
    if (acceptingClients != null) 'acceptingClients',
    'updatedAt',
  };
}

/// Why a draft could not be saved.
enum CoachProfileRefusal {
  /// More than three specialties (`K03`).
  tooManySpecialties,

  /// A capacity outside 1–60.
  capacityOutOfRange,

  /// `acceptingClients: true` without the claim (G12 §6).
  notVerified,

  /// A key the client may not write — rule 11, or a server-only field.
  forbiddenField,

  /// Her name or city is blank.
  incomplete,
}

/// The outcome of applying a draft.
@immutable
sealed class CoachProfileSave {
  const CoachProfileSave();

  const factory CoachProfileSave.applied(CoachProfile profile) =
      CoachProfileApplied;

  const factory CoachProfileSave.refused(CoachProfileRefusal reason) =
      CoachProfileRefused;
}

class CoachProfileApplied extends CoachProfileSave {
  const CoachProfileApplied(this.profile);
  final CoachProfile profile;
}

class CoachProfileRefused extends CoachProfileSave {
  const CoachProfileRefused(this.reason);
  final CoachProfileRefusal reason;
}

/// Applies a draft to a profile, enforcing every rule the security rules
/// enforce.
///
/// Deliberately strict in the same places the server is strict. A lenient editor
/// lets `K03` pass its tests with four specialties and fail in production, which
/// is the failure mode `InMemoryCycleRepository` and `InMemoryMealRepository`
/// were both written to avoid.
class CoachProfileEditor {
  const CoachProfileEditor();

  CoachProfileSave apply(
    CoachProfile current,
    CoachProfileDraft draft, {
    DateTime? now,
  }) {
    if (!CoachProfileWriteMask.allows(draft.touchedKeys)) {
      return const CoachProfileSave.refused(CoachProfileRefusal.forbiddenField);
    }

    final specialties = draft.specialties ?? current.specialties;
    if (specialties.length > CoachProfile.maxSpecialties) {
      return const CoachProfileSave.refused(
        CoachProfileRefusal.tooManySpecialties,
      );
    }

    CoachCapacity capacity = current.capacity;
    final max = draft.capacityMax;
    if (max != null) {
      try {
        capacity = capacity.isSet
            ? capacity.withMax(max)
            : CoachCapacity(max: max, taken: current.capacity.taken);
      } on ArgumentError {
        return const CoachProfileSave.refused(
          CoachProfileRefusal.capacityOutOfRange,
        );
      }
    }

    final accepting = draft.acceptingClients ?? current.acceptingClients;
    if (accepting && !current.verification.mayAdvertiseAvailability) {
      return const CoachProfileSave.refused(CoachProfileRefusal.notVerified);
    }

    final name = draft.displayName ?? current.displayName;
    final city = draft.city ?? current.city;
    if (draft.displayName != null && name.trim().isEmpty) {
      return const CoachProfileSave.refused(CoachProfileRefusal.incomplete);
    }
    if (draft.city != null && city.trim().isEmpty) {
      return const CoachProfileSave.refused(CoachProfileRefusal.incomplete);
    }

    return CoachProfileSave.applied(
      current.copyWith(
        displayName: name,
        city: city,
        tagline: draft.tagline,
        photoRef: draft.photoRef,
        photoBlurred: draft.photoBlurred,
        specialties: specialties,
        languages: draft.languages,
        clientPlaces: draft.clientPlaces,
        capacity: capacity,
        acceptingClients: accepting,
        updatedAt: now ?? DateTime.now(),
      ),
    );
  }
}

/// Rule 6 at the one place a coach's photo is prepared.
///
/// G12 §5: *"`CoachMediaUploader.upload(bytes, purpose)` calls G7/G8's
/// `MediaBlurPolicy.resolve()` before any byte leaves the device."* There is no
/// second way to decide it, and this class reads G7's policy rather than the
/// flag, so "read the flag directly" and "apply the rule" stay visibly different
/// acts in a diff.
abstract final class CoachMediaUploader {
  /// Whether this photo is blurred before it is uploaded.
  ///
  /// [herExplicitChoice] is null in the normal case — she did not choose — and a
  /// null must never read as "off". That is `MediaBlurPolicy`'s whole contract
  /// and the reason this delegates instead of reimplementing one line.
  static bool resolveBlur({
    bool? herExplicitChoice,
    required PrivacySettings settings,
  }) =>
      MediaBlurPolicy.resolve(perImage: herExplicitChoice, settings: settings);

  /// Whether turning blur off needs its consequence spelled out first.
  ///
  /// Always true for a coach going from blurred to visible: her photo is the top
  /// of a world-readable page, which is a larger consequence than a community
  /// post and the same answer either way (G7 §5).
  static bool needsConsequenceStated({required bool turningBlurOn}) =>
      MediaBlurPolicy.needsConsequenceSheet(turningOn: turningBlurOn);
}

/// Reviews of a coach, as an aggregate read beside her profile.
///
/// **Not a field on [CoachProfile]** — see the file note.
@immutable
class CoachReviewSummary {
  const CoachReviewSummary({required this.count, required this.average});

  /// Nobody has reviewed her. The state every new coach is in.
  static const CoachReviewSummary none = CoachReviewSummary(
    count: 0,
    average: 0,
  );

  final int count;
  final double average;
}

/// Whether a rating may be shown at all.
abstract final class RatingDisplay {
  /// The owner's threshold. Below five, one disappointed client is a whole star.
  static const int minimumReviews = 5;

  /// The average to render, or null.
  ///
  /// Null renders **nothing** — not "no rating yet", not a grey placeholder and
  /// not zero stars. The precedent is `statedLine` in
  /// `domain/rewards/stated_figure.dart`: a sentence that says less is better
  /// than one that says something untrue.
  static double? forReviews(CoachReviewSummary summary) =>
      summary.count >= minimumReviews ? summary.average : null;

  /// Whether the caller may say anything about her rating.
  static bool mayShow(CoachReviewSummary summary) =>
      forReviews(summary) != null;
}
