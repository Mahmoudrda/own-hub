/// The three intake steps — G01 training, G17 food, G02 support.
///
/// Three properties, each of which is a rule somewhere else in the product:
///
///  1. **Nothing is asked twice.** [ProfileEcho] is a read-only copy of what
///     `users/{uid}.profile` already knows, so G01 opens with her existing
///     answers selected rather than blank. The echo is *for the coach's
///     convenience*; the authority is the profile, and nothing here writes it
///     except through the port below.
///  2. **Her allergies have exactly one writer.** G17 writes them through
///     [DietaryProfileRepository] — the port G7 already published and G2 already
///     owns the document for. This feature does not keep a second allergy list,
///     because HANDOFF 13's failure mode is precisely two sources for one
///     safety fact. The intake's own `avoid[]` is a *training* list — a knee, a
///     shoulder — and is never a food.
///  3. **Every answer stays editable.** The repository's only write is a merge
///     of the fields named, the same shape `IntakeRepository` uses, so
///     `P0-INTAKE-02` ("nothing collected at intake is frozen") is a property
///     of the type rather than a promise.
///
/// Sharing switches are set on G02 but are **not** stored here: they live on
/// the relationship, once, so the grant dies with it. See `sharing.dart`.
library;

import 'package:meta/meta.dart';

import '../../account/domain/dietary_profile.dart';

/// Where she is in the three steps.
enum IntakeStep { training, food, support, done }

/// What her profile already says, echoed for the coach.
///
/// Read-only: no setter, no `copyWith`. A coach screen rendering this has no
/// API to type into, which is HANDOFF 13 at the type level.
@immutable
class ProfileEcho {
  const ProfileEcho({
    this.goal,
    this.days,
    this.sessionLength,
    this.place,
    this.equipment = const <String>[],
    this.allergies = const <String>[],
    this.dietary = const <String>[],
  });

  final String? goal;
  final int? days;
  final int? sessionLength;
  final String? place;
  final List<String> equipment;

  /// Copied from the profile. The **authority is the profile**: a reader
  /// prefers the live document and uses this only when that read is denied.
  final List<String> allergies;
  final List<String> dietary;

  @override
  String toString() => 'ProfileEcho(goal: $goal, allergies: $allergies)';
}

/// `relationships/{relId}/intake/current`.
@immutable
class CoachingIntake {
  const CoachingIntake({
    this.step = IntakeStep.training,
    this.goalNote,
    this.avoid = const <String>[],
    this.cookMinutes,
    this.familyPot = false,
    this.reminderLocalTime,
    this.dailyCheckin = false,
    this.profileEcho = const ProfileEcho(),
    this.submittedAt,
  });

  final IntakeStep step;

  /// "I want to feel strong enough to carry my son" — her words, optional.
  final String? goalNote;

  /// Things to train **around**: a knee, a back, a shoulder. Never a food:
  /// foods live in `profile.allergies` and `profile.dietary`, which have one
  /// writer between them.
  final List<String> avoid;

  /// How long she has to cook. From G17.
  final int? cookMinutes;

  /// Someone else cooks at home, so the coach plans around the family pot.
  final bool familyPot;

  /// "7:30 in the morning", as a local `HH:mm`.
  final String? reminderLocalTime;

  /// A daily check-in sheet. **It does not mean a daily reply**, and the screen
  /// says so.
  final bool dailyCheckin;

  final ProfileEcho profileEcho;

  /// Null until all three steps are complete.
  final DateTime? submittedAt;

  bool get isSubmitted => submittedAt != null;

  CoachingIntake copyWith({
    IntakeStep? step,
    String? goalNote,
    List<String>? avoid,
    int? cookMinutes,
    bool? familyPot,
    String? reminderLocalTime,
    bool? dailyCheckin,
    ProfileEcho? profileEcho,
    DateTime? submittedAt,
  }) => CoachingIntake(
    step: step ?? this.step,
    goalNote: goalNote ?? this.goalNote,
    avoid: avoid ?? this.avoid,
    cookMinutes: cookMinutes ?? this.cookMinutes,
    familyPot: familyPot ?? this.familyPot,
    reminderLocalTime: reminderLocalTime ?? this.reminderLocalTime,
    dailyCheckin: dailyCheckin ?? this.dailyCheckin,
    profileEcho: profileEcho ?? this.profileEcho,
    submittedAt: submittedAt ?? this.submittedAt,
  );

  @override
  String toString() => 'CoachingIntake(${step.name})';
}

/// Where the intake is read and written.
///
/// Every write is a merge of named fields — there is no `create`, no `replace`
/// and no whole-document save, so three partial steps leave three real answers
/// and abandoning after two is a designed path rather than a repair.
abstract class CoachingIntakeRepository {
  CoachingIntake read(String relId);

  /// G01. Writes only the training fields.
  Future<CoachingIntake> mergeTraining({
    required String relId,
    String? goalNote,
    List<String>? avoid,
  });

  /// G17. Writes the cooking fields **and her allergies, through the profile
  /// port** — never into this document.
  Future<CoachingIntake> mergeFood({
    required String relId,
    int? cookMinutes,
    bool? familyPot,
    Set<AllergenTag>? allergies,
    Set<DietaryTag>? dietary,
  });

  /// G02. Writes only the support fields. Sharing switches are not here.
  Future<CoachingIntake> mergeSupport({
    required String relId,
    String? reminderLocalTime,
    bool? dailyCheckin,
  });

  /// Completes the intake. Throws when a step is still missing, rather than
  /// submitting a half-answered record the coach then has to chase.
  Future<CoachingIntake> submit({required String relId, required DateTime at});
}

/// In-memory, recording which fields each call wrote.
///
/// The evidence matters: "G17 wrote allergies to the profile and nothing to the
/// intake" is the assertion that proves the allergy list has one writer.
class InMemoryCoachingIntakeRepository implements CoachingIntakeRepository {
  InMemoryCoachingIntakeRepository({
    required this.profile,
    CoachingIntake? initial,
  }) : _intake = initial ?? const CoachingIntake();

  /// The one writer of `profile.allergies` and `profile.dietary`.
  final DietaryProfileRepository profile;

  CoachingIntake _intake;

  /// Field names written into the intake document, per call.
  final List<Set<String>> writes = <Set<String>>[];

  @override
  CoachingIntake read(String relId) => _intake;

  @override
  Future<CoachingIntake> mergeTraining({
    required String relId,
    String? goalNote,
    List<String>? avoid,
  }) async {
    writes.add({
      if (goalNote != null) 'goalNote',
      if (avoid != null) 'avoid',
      'step',
    });
    _intake = _intake.copyWith(
      goalNote: goalNote,
      avoid: avoid,
      step: IntakeStep.food,
    );
    return _intake;
  }

  @override
  Future<CoachingIntake> mergeFood({
    required String relId,
    int? cookMinutes,
    bool? familyPot,
    Set<AllergenTag>? allergies,
    Set<DietaryTag>? dietary,
  }) async {
    // The allergy list goes to the profile. Note what is NOT added to `writes`:
    // this document never holds a copy that could drift from it.
    if (allergies != null || dietary != null) {
      await profile.save(allergies: allergies, dietary: dietary);
    }

    writes.add({
      if (cookMinutes != null) 'cookMinutes',
      if (familyPot != null) 'familyPot',
      'step',
    });
    _intake = _intake.copyWith(
      cookMinutes: cookMinutes,
      familyPot: familyPot,
      step: IntakeStep.support,
      profileEcho: _echoOf(profile.read()),
    );
    return _intake;
  }

  @override
  Future<CoachingIntake> mergeSupport({
    required String relId,
    String? reminderLocalTime,
    bool? dailyCheckin,
  }) async {
    writes.add({
      if (reminderLocalTime != null) 'reminderLocalTime',
      if (dailyCheckin != null) 'dailyCheckin',
    });
    _intake = _intake.copyWith(
      reminderLocalTime: reminderLocalTime,
      dailyCheckin: dailyCheckin,
    );
    return _intake;
  }

  @override
  Future<CoachingIntake> submit({
    required String relId,
    required DateTime at,
  }) async {
    if (_intake.step == IntakeStep.training) {
      throw StateError(
        'The intake has not reached the food step. Nothing is submitted '
        'half-answered.',
      );
    }
    writes.add({'submittedAt', 'step'});
    _intake = _intake.copyWith(step: IntakeStep.done, submittedAt: at);
    return _intake;
  }

  static ProfileEcho _echoOf(DietaryProfile p) => ProfileEcho(
    allergies: (p.allergies ?? const <AllergenTag>{})
        .map((a) => a.wireName)
        .toList(),
    dietary: (p.dietary ?? const <DietaryTag>{})
        .map((d) => d.wireName)
        .toList(),
  );
}
