/// The month being authored — G14 §1.2.
///
/// > This document is the whole of W03/W04/W05/W06 and it is the reason a coach
/// > can plan a month with no signal. `plans/**` is server-authored and not
/// > writable offline, so the work-in-progress cannot live there. It lives in a
/// > document the coach owns.
///
/// ## Why `days` is a map and not a list
///
/// Firestore has no field path to an array element, so an array makes every
/// edit a whole-document rewrite and two devices editing different days lose
/// one of them. As a map, `days.2026-09-16` is a field path, so distinct days
/// merge commutatively — the same correction the spine applied to `meals.slots`.
/// Two devices editing the *same* day is last-write-wins on that one day and
/// nothing else. `P0-PLAN-05` is a test of exactly that property.
///
/// ## A draft can never claim to be published
///
/// [PlanDraftStatus.published] exists because the *state machine* has that
/// state, not because a device may write it. `PlanDraftRepository.save`
/// refuses anything but `draft`; only the publish callable writes that word,
/// and it writes it server-side. G14 §3.4, and the ruleset says the same.
library;

import 'package:meta/meta.dart';

import '../prescription.dart';

/// G14 §3.4's states.
enum PlanDraftStatus {
  draft('draft'),
  publishing('publishing'),
  published('published');

  const PlanDraftStatus(this.wireName);

  final String wireName;
}

/// How the month came to be authored. `assistant` when K26/K27 handed it over.
enum DraftOrigin {
  blank('blank'),
  split('split'),
  assistant('assistant'),
  copy('copy');

  const DraftOrigin(this.wireName);

  final String wireName;
}

/// A day is training or rest. **Absence is rest** in G2's assignment contract;
/// a day held here says so explicitly, so W03 can tell "rest" from "not yet
/// planned" — the distinction the red gap rows on W03 are about.
enum PlanDayKind {
  workout('workout'),
  rest('rest');

  const PlanDayKind(this.wireName);

  final String wireName;
}

/// The four meal slots, fixed forever (spine C3).
enum PlanMealSlot {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack');

  const PlanMealSlot(this.wireName);

  final String wireName;
}

/// Where a filled slot's food comes from.
enum MealSlotSource {
  /// G5's verified pack. Every quantity on W06 traces to `foods[].sizes[]`.
  library('library'),

  /// One of the coach's own meals. Embedded **by value** at publish time —
  /// never referenced, because a reference would force the client to read
  /// another user's document, and because a later edit to the coach's meal
  /// must not silently change a published day.
  coach('coach'),

  /// She chooses. An explicit answer, not a gap.
  freeChoice('free_choice');

  const MealSlotSource(this.wireName);

  final String wireName;
}

/// `yyyy-MM` for [moment]'s calendar month, in her local calendar.
///
/// Local fields rather than `toUtc()`, for the reason `dayKey` gives: the month
/// is the month it was **for her**.
String monthKey(DateTime moment) =>
    '${moment.year.toString().padLeft(4, '0')}-'
    '${moment.month.toString().padLeft(2, '0')}';

/// The deterministic document id (spine C1): a replayed save overwrites itself
/// instead of creating a second month.
String planDraftId({required String clientUid, required String month}) =>
    '${clientUid}__$month';

/// One filled meal slot.
@immutable
class MealSlotAssignment {
  const MealSlotAssignment._({
    required this.source,
    this.foodIds = const <String>[],
    this.coachMealId,
    this.servings = 1,
    this.note,
  });

  /// From the verified pack.
  const MealSlotAssignment.fromLibrary({
    required List<String> foodIds,
    int servings = 1,
    String? note,
  }) : this._(
         source: MealSlotSource.library,
         foodIds: foodIds,
         servings: servings,
         note: note,
       );

  /// One of the coach's own meals, by id **inside her draft**. The publisher
  /// embeds it by value; nothing client-side ever dereferences this id.
  const MealSlotAssignment.coachMeal({
    required String coachMealId,
    int servings = 1,
    String? note,
  }) : this._(
         source: MealSlotSource.coach,
         coachMealId: coachMealId,
         servings: servings,
         note: note,
       );

  /// "She chooses" — stated, so it publishes as an answer rather than a hole.
  const MealSlotAssignment.freeChoice()
    : this._(source: MealSlotSource.freeChoice);

  final MealSlotSource source;
  final List<String> foodIds;
  final String? coachMealId;
  final int servings;
  final String? note;

  bool get isFreeChoice => source == MealSlotSource.freeChoice;

  MealSlotAssignment copy() => MealSlotAssignment._(
    source: source,
    foodIds: List<String>.unmodifiable(foodIds),
    coachMealId: coachMealId,
    servings: servings,
    note: note,
  );

  Map<String, Object?> toWire() => switch (source) {
    MealSlotSource.freeChoice => <String, Object?>{'freeChoice': true},
    MealSlotSource.library => <String, Object?>{
      'source': source.wireName,
      'foodIds': List<String>.of(foodIds),
      'servings': servings,
      if (note != null) 'note': note,
    },
    MealSlotSource.coach => <String, Object?>{
      'source': source.wireName,
      'coachMealId': coachMealId,
      'servings': servings,
      if (note != null) 'note': note,
    },
  };

  @override
  String toString() => 'MealSlotAssignment(${source.wireName})';
}

/// The meals planned for one day. A slot that is **null is a gap**, counted on
/// W06 and W08 — never the same thing as a stated free choice.
@immutable
class DraftMealDay {
  DraftMealDay({Map<PlanMealSlot, MealSlotAssignment?> slots = const {}})
    : slots = Map<PlanMealSlot, MealSlotAssignment?>.unmodifiable(slots);

  final Map<PlanMealSlot, MealSlotAssignment?> slots;

  /// The slots with nothing in them at all.
  List<PlanMealSlot> get gaps => <PlanMealSlot>[
    for (final slot in PlanMealSlot.values)
      if (slots[slot] == null) slot,
  ];

  int get filledCount => PlanMealSlot.values.length - gaps.length;

  DraftMealDay withSlot(PlanMealSlot slot, MealSlotAssignment? assignment) =>
      DraftMealDay(
        slots: <PlanMealSlot, MealSlotAssignment?>{...slots, slot: assignment},
      );

  DraftMealDay copy() => DraftMealDay(
    slots: <PlanMealSlot, MealSlotAssignment?>{
      for (final entry in slots.entries) entry.key: entry.value?.copy(),
    },
  );

  Map<String, Object?> toWire() => <String, Object?>{
    'slots': <String, Object?>{
      for (final slot in PlanMealSlot.values)
        slot.wireName: slots[slot]?.toWire(),
    },
  };
}

/// The session planned for one day.
@immutable
class DraftWorkout {
  DraftWorkout({
    required this.title,
    required this.minutes,
    this.sessionTemplateId,
    this.restBetweenSetsSec,
    this.note,
    List<PrescribedMove> moves = const <PrescribedMove>[],
    List<ApprovedAlternative> approvedAlternatives =
        const <ApprovedAlternative>[],
  }) : moves = List<PrescribedMove>.unmodifiable(moves),
       approvedAlternatives = List<ApprovedAlternative>.unmodifiable(
         approvedAlternatives,
       );

  final String title;
  final int minutes;
  final String? sessionTemplateId;
  final int? restBetweenSetsSec;

  /// "Keep 12 kg and aim for 12 reps." Her coach's words, shown to her.
  final String? note;

  final List<PrescribedMove> moves;
  final List<ApprovedAlternative> approvedAlternatives;

  DraftWorkout copy() => DraftWorkout(
    title: title,
    minutes: minutes,
    sessionTemplateId: sessionTemplateId,
    restBetweenSetsSec: restBetweenSetsSec,
    note: note,
    moves: <PrescribedMove>[for (final move in moves) move.copy()],
    approvedAlternatives: <ApprovedAlternative>[
      for (final alternative in approvedAlternatives) alternative.copy(),
    ],
  );

  DraftWorkout withMoves(List<PrescribedMove> next) => DraftWorkout(
    title: title,
    minutes: minutes,
    sessionTemplateId: sessionTemplateId,
    restBetweenSetsSec: restBetweenSetsSec,
    note: note,
    moves: next,
    approvedAlternatives: approvedAlternatives,
  );

  Map<String, Object?> toWire() => <String, Object?>{
    if (sessionTemplateId != null) 'sessionTemplateId': sessionTemplateId,
    'title': title,
    'minutes': minutes,
    if (restBetweenSetsSec != null) 'restBetweenSetsSec': restBetweenSetsSec,
    if (note != null) 'note': note,
    'moves': <Map<String, Object?>>[for (final move in moves) move.toWire()],
    if (approvedAlternatives.isNotEmpty)
      'approvedAlternatives': <Map<String, Object?>>[
        for (final alternative in approvedAlternatives) alternative.toWire(),
      ],
  };
}

/// Where a day came from, when it came from a split. **Provenance only** — it
/// is never dereferenced, at render time or at publish time.
@immutable
class SplitProvenance {
  const SplitProvenance({required this.splitId, required this.dayIndex});

  final String splitId;
  final int dayIndex;

  Map<String, Object?> toWire() => <String, Object?>{
    'splitId': splitId,
    'dayIndex': dayIndex,
  };
}

/// One day of the month.
@immutable
class PlanDay {
  const PlanDay({required this.kind, this.workout, this.meal, this.fromSplit});

  /// A rest day the coach chose. Carries meals like any other day — a woman
  /// still eats on a rest day, which is why `meal` is independent of `kind`.
  const PlanDay.rest({DraftMealDay? meal, SplitProvenance? fromSplit})
    : this(kind: PlanDayKind.rest, meal: meal, fromSplit: fromSplit);

  final PlanDayKind kind;

  /// Null on a rest day.
  final DraftWorkout? workout;

  final DraftMealDay? meal;
  final SplitProvenance? fromSplit;

  bool get isRest => kind == PlanDayKind.rest;
  bool get hasWorkout => workout != null;

  PlanDay copy() => PlanDay(
    kind: kind,
    workout: workout?.copy(),
    meal: meal?.copy(),
    fromSplit: fromSplit,
  );

  PlanDay withWorkout(DraftWorkout? next) =>
      PlanDay(kind: kind, workout: next, meal: meal, fromSplit: fromSplit);

  PlanDay withMeal(DraftMealDay? next) =>
      PlanDay(kind: kind, workout: workout, meal: next, fromSplit: fromSplit);

  Map<String, Object?> toWire() => <String, Object?>{
    'kind': kind.wireName,
    if (workout != null) 'workout': workout!.toWire(),
    if (meal != null) 'meal': meal!.toWire(),
    if (fromSplit != null) 'fromSplit': fromSplit!.toWire(),
  };
}

/// What was published last, as the coach's own document already holds it.
///
/// G14 §2: W03 and W08 render "already published" from a document she already
/// has — 0 extra reads, and correct with no signal, where a `plans/**` read is
/// only available offline if it happens to be in cache.
@immutable
class LastPublished {
  const LastPublished({
    required this.version,
    required this.at,
    required this.dayCount,
    required this.mealSlotCount,
  });

  final String version;
  final DateTime at;
  final int dayCount;
  final int mealSlotCount;
}

/// The month, as one document.
@immutable
class PlanDraft {
  PlanDraft({
    required this.clientUid,
    required this.coachUid,
    required this.month,
    Map<String, PlanDay> days = const <String, PlanDay>{},
    this.status = PlanDraftStatus.draft,
    this.origin = DraftOrigin.blank,
    this.basedOnVersion,
    this.lastPublished,
    this.templateRef,
    this.effectiveFrom,
    this.lastEditedByDevice,
    this.updatedAt,
  }) : days = Map<String, PlanDay>.unmodifiable(days);

  final String clientUid;
  final String coachUid;

  /// `yyyy-MM`. Sharded by month so the document cannot grow without bound.
  final String month;

  /// Keyed `yyyy-MM-dd`. See the library note on why this is a map.
  final Map<String, PlanDay> days;

  final PlanDraftStatus status;
  final DraftOrigin origin;

  /// The published version this draft was opened from.
  final String? basedOnVersion;

  final LastPublished? lastPublished;

  /// `coaches/{coachUid}/splits/{splitId}`, as a string. **Never
  /// dereferenced** — if the split is deleted this becomes a dangling
  /// provenance string and nothing breaks, because nothing reads it.
  final String? templateRef;

  /// `yyyy-MM-dd`. G2 clamps it to `max(requested, today)` at publish.
  final String? effectiveFrom;

  /// Stamped so W03 can name the other device on a same-day divergence,
  /// instead of silently keeping one of two edits.
  final String? lastEditedByDevice;

  final DateTime? updatedAt;

  String get draftId => planDraftId(clientUid: clientUid, month: month);

  bool get isDraft => status == PlanDraftStatus.draft;

  PlanDay? dayAt(String dayKey) => days[dayKey];

  int get workoutDayCount =>
      days.values.where((day) => day.kind == PlanDayKind.workout).length;

  int get restDayCount =>
      days.values.where((day) => day.kind == PlanDayKind.rest).length;

  /// Planned days that hold no meal day at all, plus the empty slots inside
  /// the days that do. W08 counts this before publishing, and publishing marks
  /// them explicitly as free choice rather than leaving them undefined.
  int get unfilledMealSlots {
    var gaps = 0;
    for (final day in days.values) {
      final meal = day.meal;
      gaps += meal == null ? PlanMealSlot.values.length : meal.gaps.length;
    }
    return gaps;
  }

  int get filledMealSlots {
    var filled = 0;
    for (final day in days.values) {
      filled += day.meal?.filledCount ?? 0;
    }
    return filled;
  }

  /// Every day that already holds something, in date order. W05 names these
  /// **before** it replaces them.
  List<String> get plannedDayKeys => days.keys.toList(growable: false)..sort();

  PlanDraft withDay(String dayKey, PlanDay? day) {
    final next = Map<String, PlanDay>.of(days);
    if (day == null) {
      next.remove(dayKey);
    } else {
      next[dayKey] = day;
    }
    return _copyWith(days: next);
  }

  /// Several days at once — a split application or a week copy.
  ///
  /// Every other day is carried through untouched, which is the whole point of
  /// a map: writing Tuesday cannot lose Thursday.
  PlanDraft withDays(Map<String, PlanDay> incoming, {DraftOrigin? origin}) {
    final next = Map<String, PlanDay>.of(days)..addAll(incoming);
    return _copyWith(days: next, origin: origin ?? this.origin);
  }

  PlanDraft withTemplateRef(String? ref) => _copyWith(templateRef: ref);

  PlanDraft withLastPublished(LastPublished published) =>
      _copyWith(lastPublished: published, basedOnVersion: published.version);

  PlanDraft withEffectiveFrom(String? day) => _copyWith(effectiveFrom: day);

  PlanDraft withDevice(String deviceId) =>
      _copyWith(lastEditedByDevice: deviceId);

  PlanDraft withUpdatedAt(DateTime at) => _copyWith(updatedAt: at);

  PlanDraft _copyWith({
    Map<String, PlanDay>? days,
    DraftOrigin? origin,
    String? basedOnVersion,
    LastPublished? lastPublished,
    String? templateRef,
    String? effectiveFrom,
    String? lastEditedByDevice,
    DateTime? updatedAt,
  }) => PlanDraft(
    clientUid: clientUid,
    coachUid: coachUid,
    month: month,
    days: days ?? this.days,
    // Deliberately not a parameter. A draft's status is moved by the publish
    // path alone, never by an edit — G14 §3.4.
    status: status,
    origin: origin ?? this.origin,
    basedOnVersion: basedOnVersion ?? this.basedOnVersion,
    lastPublished: lastPublished ?? this.lastPublished,
    templateRef: templateRef ?? this.templateRef,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    lastEditedByDevice: lastEditedByDevice ?? this.lastEditedByDevice,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// The document, as stored.
  Map<String, Object?> toWire() => <String, Object?>{
    'clientUid': clientUid,
    'coachUid': coachUid,
    'month': month,
    'status': status.wireName,
    'origin': origin.wireName,
    'days': <String, Object?>{
      for (final entry in days.entries) entry.key: entry.value.toWire(),
    },
    if (basedOnVersion != null) 'basedOnVersion': basedOnVersion,
    if (templateRef != null) 'templateRef': templateRef,
    if (effectiveFrom != null) 'effectiveFrom': effectiveFrom,
    if (lastEditedByDevice != null) 'lastEditedByDevice': lastEditedByDevice,
  };

  /// A stable fingerprint of the content being published.
  ///
  /// Part of the idempotency key, so three retries of one publish produce
  /// exactly one version. It is **not** `Object.hash`: that is seeded per
  /// isolate, so a queued intent hashed before a restart would not match the
  /// same content hashed after one — which is precisely the replay this key
  /// exists to collapse. FNV-1a over the canonical wire text is deterministic
  /// everywhere, forever.
  String get contentHash {
    final buffer = StringBuffer();
    for (final key in plannedDayKeys) {
      buffer
        ..write(key)
        ..write(_canonical(days[key]!.toWire()))
        ..write(';');
    }
    var hash = 0x811c9dc5;
    for (final unit in buffer.toString().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _canonical(Object? node) {
    if (node is Map) {
      final keys = node.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '$k:${_canonical(node[k])}').join(',')}}';
    }
    if (node is Iterable) {
      return '[${node.map(_canonical).join(',')}]';
    }
    return '$node';
  }

  @override
  String toString() =>
      'PlanDraft($draftId, ${status.wireName}, ${days.length} days)';
}
