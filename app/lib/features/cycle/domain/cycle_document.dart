/// `users/{uid}/cycle/current` — one document, fixed id (plan §1.1).
///
/// The path in `SCHEMA-SPINE.md` §8 was `users/{uid}/cycle`, which has an odd
/// number of segments and is therefore a *collection*. The spine records the
/// correction: the document is `users/{uid}/cycle/current`, a single fixed id,
/// the shape G5 used for `eatPrefs/current`. That keeps the sensitive data in
/// its own document instead of on the root user document six groups read, and
/// makes Y12's "Delete cycle data" a document delete rather than field surgery.
///
/// ## What this type deliberately cannot hold
///
/// Plan §1.1, "Not stored, deliberately". There is **no `phase`, no `cycleDay`,
/// no `predictedOvulation`, no `fertileWindow` and no `forecastEnabled` field**
/// anywhere in this file. §2.4 is enforced by making a phase *unstorable*, the
/// way spine C6 makes a streak unstorable: "no suggestion path can reach a phase
/// because no document carries one."
///
/// `ForecastPolicy.isEnabled` is a function, not a field, for the reason the
/// plan gives: "A stored derived flag is a flag that goes stale offline."
///
/// There is also **no symptom field**. Symptoms are G3's `checkins/{date}`, and
/// duplicating them here is the failure §1.1 exists to prevent.
library;

import 'package:meta/meta.dart';

/// How she chose to use the feature (Y01).
enum CycleMode {
  /// Dates and symptoms. The calendar tab and estimates are available.
  datesAndSymptoms,

  /// Symptoms only — Y14. No calendar tab, no estimate, no phase name.
  symptomsOnly,
}

/// Y01's optional context chips. At most six, which is every value.
///
/// Four of these **remove forecasting** rather than degrade it (see
/// [ForecastPolicy]): "irregular cycles, hormonal contraception, perimenopause
/// and pregnancy all make an estimate from dates meaningless, and the screen
/// says so instead of quietly widening the range" (§3.1).
enum CycleContextFlag {
  irregular,
  hormonalContraception,
  perimenopause,
  pregnantOrPostpartum,
  preferNotToSay,
  none,
}

/// Her four on/off switches for her own screens (Y02, Y10, Y12).
///
/// These change what the app *suggests to her*. They are not sharing, and
/// nothing here is visible to anybody else.
@immutable
class CycleAdaptation {
  const CycleAdaptation({
    this.workoutSuggestions = false,
    this.mealSuggestions = false,
    this.homeCard = false,
    this.easierWhenLowEnergy = false,
  });

  /// Before setup. No document exists at all in this state, so this is what the
  /// rest of the app behaves as if it had.
  static const CycleAdaptation allOff = CycleAdaptation();

  /// What Y02 renders, pre-checked.
  ///
  /// **OQ-12 is open and this encodes the plan's reading of it**: the spine's
  /// "default OFF" annotation binds `sharing.*` (C12 / HANDOFF 6), and the
  /// prototype binds `adaptation.*`, with no document existing until she
  /// finishes setup. If the owner meant "default OFF" to cover adaptation too,
  /// Y02's toggles ship unchecked and this constant becomes [allOff] — a
  /// one-line change, made here rather than in three screens.
  static const CycleAdaptation y02Defaults = CycleAdaptation(
    workoutSuggestions: true,
    mealSuggestions: true,
    homeCard: true,
  );

  final bool workoutSuggestions;
  final bool mealSuggestions;
  final bool homeCard;
  final bool easierWhenLowEnergy;

  CycleAdaptation copyWith({
    bool? workoutSuggestions,
    bool? mealSuggestions,
    bool? homeCard,
    bool? easierWhenLowEnergy,
  }) {
    return CycleAdaptation(
      workoutSuggestions: workoutSuggestions ?? this.workoutSuggestions,
      mealSuggestions: mealSuggestions ?? this.mealSuggestions,
      homeCard: homeCard ?? this.homeCard,
      easierWhenLowEnergy: easierWhenLowEnergy ?? this.easierWhenLowEnergy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CycleAdaptation &&
      other.workoutSuggestions == workoutSuggestions &&
      other.mealSuggestions == mealSuggestions &&
      other.homeCard == homeCard &&
      other.easierWhenLowEnergy == easierWhenLowEnergy;

  @override
  int get hashCode => Object.hash(
    workoutSuggestions,
    mealSuggestions,
    homeCard,
    easierWhenLowEnergy,
  );
}

/// The three coach-sharing switches. **All false, always, on a new document.**
///
/// Spine C12 / HANDOFF rule 6, and plan §1.1: "`sharing.*` is different and
/// absolute — it is false on write, cannot be set during setup, and only
/// Y12/G02 can turn it on."
///
/// "Cannot be set during setup" is enforced where it can actually be enforced:
/// `CycleRepository.completeSetup` and `savePreferences` **take no sharing
/// parameter**, so the setup path has nothing to pass. The only way to turn one
/// on is [grant], which requires a relationship id — because a grant that is not
/// bound to one relationship is a grant the next coach inherits (OQ-2).
@immutable
class CycleSharing {
  const CycleSharing({
    this.energyAppetite = false,
    this.symptoms = false,
    this.datesAndPatterns = false,
    this.grantedForRelId,
  });

  /// A new document. Every switch false, bound to nothing.
  static const CycleSharing off = CycleSharing();

  final bool energyAppetite;
  final bool symptoms;
  final bool datesAndPatterns;

  /// The one relationship this grant was given for.
  ///
  /// Spine §8: "The grant lives ONCE, on the relationship, carrying
  /// `grantedForRelId`, so a grant dies with the relationship even on a device
  /// that is offline."
  final String? grantedForRelId;

  /// True when nothing at all is shared.
  bool get isAllOff => !energyAppetite && !symptoms && !datesAndPatterns;

  /// Turns one switch on or off, binding a grant to [relId].
  ///
  /// **Independence is structural here**: this copies the other two through
  /// unchanged, so "setting one never sets another" is not something a caller
  /// has to be careful about. `sharing_independence_test.dart` asserts it
  /// anyway, because the cheap test over a structural guarantee is what catches
  /// the day somebody rewrites this method.
  CycleSharing grant({
    required SharingKey key,
    required bool on,
    required String relId,
  }) {
    final next = CycleSharing(
      energyAppetite: key == SharingKey.energyAppetite ? on : energyAppetite,
      symptoms: key == SharingKey.symptoms ? on : symptoms,
      datesAndPatterns: key == SharingKey.datesAndPatterns
          ? on
          : datesAndPatterns,
      grantedForRelId: relId,
    );
    // Nothing shared means nothing is bound. Leaving a stale relationship id on
    // an all-off map would make "which relationship was this for" answerable
    // for a grant that no longer exists.
    return next.isAllOff ? CycleSharing.off : next;
  }

  @override
  bool operator ==(Object other) =>
      other is CycleSharing &&
      other.energyAppetite == energyAppetite &&
      other.symptoms == symptoms &&
      other.datesAndPatterns == datesAndPatterns &&
      other.grantedForRelId == grantedForRelId;

  @override
  int get hashCode =>
      Object.hash(energyAppetite, symptoms, datesAndPatterns, grantedForRelId);
}

/// Which switch [CycleSharing.grant] is setting.
///
/// Kept in this file rather than reusing `CycleCategory` so that the data model
/// does not depend on the sharing policy; `CycleSharingPolicy` maps between
/// them. Callers outside the feature go through `CycleRepository.setSharing`,
/// which takes the public `CycleCategory` — this is the internal vocabulary.
enum SharingKey { energyAppetite, symptoms, datesAndPatterns }

/// The mapping from a public category name to the internal key.
///
/// A function rather than a second enum-to-enum constructor, so the data model
/// keeps no import of the sharing policy and there is exactly one place the two
/// vocabularies meet.
SharingKey sharingKeyFor(String categoryName) => switch (categoryName) {
  'energyAppetite' => SharingKey.energyAppetite,
  'symptoms' => SharingKey.symptoms,
  'datesAndPatterns' => SharingKey.datesAndPatterns,
  _ => throw ArgumentError.value(categoryName, 'categoryName'),
};

/// A cache of the newest period document (plan §1.1).
///
/// Derived, and able to heal itself: "if two devices disagree,
/// `CycleProjectionReconciler.rebuild()` re-derives it from a bounded
/// `__name__` range (≤12 docs) on reconnect. A derived field that can self-heal
/// is never a conflict" (§4).
@immutable
class LastPeriod {
  const LastPeriod({required this.startDate, this.endDate});

  /// `yyyy-MM-dd`.
  final String startDate;

  /// `yyyy-MM-dd`, or null while she is still bleeding.
  final String? endDate;

  /// Derived, never stored beside [endDate].
  ///
  /// G9 §6 asks Firestore to enforce `stillBleeding == (end == null)` "so the
  /// two can never disagree". A getter is the client-side form of the same
  /// guarantee: there is no second field to fall out of step.
  bool get stillBleeding => endDate == null;

  @override
  bool operator ==(Object other) =>
      other is LastPeriod &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);
}

/// The document. See the library comment for what it cannot hold.
@immutable
class CycleDocument {
  const CycleDocument({
    required this.mode,
    this.contextFlags = const <CycleContextFlag>{},
    this.cycleLengthDays,
    this.adaptation = CycleAdaptation.allOff,
    this.sharing = CycleSharing.off,
    this.lastPeriod,
    this.recentStarts = const <String>[],
  }) : assert(
         contextFlags.length <= maxContextFlags,
         'contextFlags is capped at $maxContextFlags — the rules enforce it, '
         'and an unbounded list is a document that grows without limit.',
       ),
       assert(
         recentStarts.length <= maxRecentStarts,
         'recentStarts is capped at $maxRecentStarts (plan §1.1). It is a '
         'bounded set of dates, not a count — see the library note above.',
       ),
       assert(
         cycleLengthDays == null ||
             (cycleLengthDays >= minCycleLengthDays &&
                 cycleLengthDays <= maxCycleLengthDays),
         'cycleLengthDays is 21–45 or null. Null is "Not sure", and it is a '
         'first-class answer: nothing pre-fills 28 days, because an invented '
         'average becomes a prediction she never gave us the data for.',
       );

  /// Plan §1.1 / §6: `contextFlags` is a list of at most six.
  static const int maxContextFlags = 6;

  /// Plan §1.1 / §6: `recentStarts` holds at most twelve, newest first.
  static const int maxRecentStarts = 12;

  static const int minCycleLengthDays = 21;
  static const int maxCycleLengthDays = 45;

  final CycleMode mode;
  final Set<CycleContextFlag> contextFlags;

  /// Y02's "Usual cycle length". **Null means "Not sure"**, and stays null.
  final int? cycleLengthDays;

  final CycleAdaptation adaptation;
  final CycleSharing sharing;
  final LastPeriod? lastPeriod;

  /// Up to twelve period start dates, `yyyy-MM-dd`, newest first.
  final List<String> recentStarts;

  CycleDocument copyWith({
    CycleMode? mode,
    Set<CycleContextFlag>? contextFlags,
    int? cycleLengthDays,
    bool clearCycleLength = false,
    CycleAdaptation? adaptation,
    CycleSharing? sharing,
    LastPeriod? lastPeriod,
    bool clearLastPeriod = false,
    List<String>? recentStarts,
  }) {
    return CycleDocument(
      mode: mode ?? this.mode,
      contextFlags: contextFlags ?? this.contextFlags,
      cycleLengthDays: clearCycleLength
          ? null
          : (cycleLengthDays ?? this.cycleLengthDays),
      adaptation: adaptation ?? this.adaptation,
      sharing: sharing ?? this.sharing,
      lastPeriod: clearLastPeriod ? null : (lastPeriod ?? this.lastPeriod),
      recentStarts: recentStarts ?? this.recentStarts,
    );
  }
}

/// Whether an estimate may be shown at all.
///
/// Plan §1.1: "derived, never stored — `ForecastPolicy.isEnabled(cycle)` returns
/// false whenever `mode != datesAndSymptoms` or any of `irregular` /
/// `hormonalContraception` / `perimenopause` / `pregnantOrPostpartum` is set."
class ForecastPolicy {
  const ForecastPolicy();

  /// The four flags that remove forecasting.
  ///
  /// `preferNotToSay` and `none` are not here, deliberately: neither says
  /// anything about whether dates can carry meaning.
  static const Set<CycleContextFlag> suppressing = {
    CycleContextFlag.irregular,
    CycleContextFlag.hormonalContraception,
    CycleContextFlag.perimenopause,
    CycleContextFlag.pregnantOrPostpartum,
  };

  static bool isEnabled(CycleDocument? cycle) {
    if (cycle == null) return false;
    if (cycle.mode != CycleMode.datesAndSymptoms) return false;
    return !cycle.contextFlags.any(suppressing.contains);
  }
}

/// The feature's own lifecycle (plan §3.1).
enum CycleSetupState {
  /// No `cycle/current` document. Y01 is reachable from T01 and there is **no
  /// cycle card on Home, no check-in prompt, no trace anywhere else**.
  notSetUp,

  /// Y03 hub with the calendar tab and estimates.
  datesAndSymptoms,

  /// Y14 — a branch of the Y03 route. No calendar tab, no estimate, no phase.
  symptomsOnly,

  /// Dates mode, but a context flag removed forecasting. The calendar shows
  /// logged days only, with the reason on screen.
  forecastSuppressed,

  /// Y12's "Delete cycle data" completed.
  ///
  /// **[resolveCycleSetupState] can never return this**, and that is the
  /// guarantee rather than an omission: a purged account is byte-identical to
  /// one that never set the feature up, so there is no observable residue for a
  /// screen to render. The value exists for the deletion machine to report its
  /// own outcome.
  purged,
}

/// Which of the four observable states she is in.
CycleSetupState resolveCycleSetupState(CycleDocument? cycle) {
  if (cycle == null) return CycleSetupState.notSetUp;
  if (cycle.mode == CycleMode.symptomsOnly) return CycleSetupState.symptomsOnly;
  return ForecastPolicy.isEnabled(cycle)
      ? CycleSetupState.datesAndSymptoms
      : CycleSetupState.forecastSuppressed;
}
