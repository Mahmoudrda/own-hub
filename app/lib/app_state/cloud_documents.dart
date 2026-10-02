/// Her week as Firestore documents, shaped the way the deployed rules take it.
///
/// `app_snapshot.dart` turns every store into ONE document for the handset.
/// This file turns the same stores into the MANY documents
/// `firebase/firestore.rules` describes — one per session, one per day of
/// eating, one per check-in — and back again. The two are deliberately
/// separate: the local document's shape is ours to choose, and this one's is
/// not. Every map below is dictated by a `hasOnly` in the rules file, and a key
/// that is not in the matching whitelist is not a field we forgot to add, it is
/// a write that returns `PERMISSION_DENIED` in production and passes in review.
///
/// ## The ids are the replay defence, not a naming convention
///
/// Spine C1: a day document's id IS the date and a week's IS the ISO week, so a
/// write that is retried — by the offline queue, by a double tap, by a process
/// that died before the ack — lands on the same document instead of becoming a
/// second entry. `isDay`, `isWeek` and `docId == 'current'` in the rules enforce
/// that at the boundary, so every id produced here comes from the model's own
/// deterministic key (`Measurement.dayId`, `PeriodEntry.id`, `WeekKey.id`) and
/// never from a counter or a clock.
///
/// ## The merge rule, stated once
///
/// [mergeIn] folds documents pulled from the cloud into the live stores under
/// one rule:
///
/// > **Union by id. A record this phone already holds wins. A singleton
/// > document is taken from the cloud only where this phone has none. Nothing
/// > is ever removed.**
///
/// Why local wins rather than newest-wins: today there is exactly one handset
/// per woman — sign-in is phone auth on the device she is holding — so a
/// collision means the cloud holds a copy of a record this phone wrote, and the
/// local copy is by construction at least as new as the copy that was made from
/// it. Choosing the remote copy could only ever replace her data with an older
/// version of her data.
///
/// Why nothing is removed: the case this is built for is a woman who used the
/// app for weeks with no account and then signed in. Her cloud side is empty.
/// A merge that mirrored the cloud onto the phone would delete her training
/// history at the exact moment she did the thing we asked her to do. An empty
/// remote side must therefore be indistinguishable from no remote side at all,
/// and it is: a union with nothing changes nothing.
///
/// What this rule costs, stated so it is not discovered later: an edit made on
/// a SECOND device to a record this device also holds is dropped on this
/// device. There is no second device yet. When there is, the resolution has to
/// be per field and timestamped, which is a different design and not a tweak to
/// this one.
///
/// ## Two things are pushed and never pulled
///
/// `privacy` and `notify` on `users/{uid}`. Nothing in the app records whether
/// the switches on this phone are hers or the app's defaults, so a merge cannot
/// tell "she turned this off" from "she has never been asked" — and a merge
/// that cannot tell the difference must not be the thing that turns a
/// protection off. G7 rule 6 says the same about a snapshot missing a key. So
/// they travel up and never down; a reinstall opens on the safe defaults and
/// she sets them again, which is the failure worth having.
library;

import 'package:flutter/foundation.dart';

import '../domain/training/prescribed_set.dart';
import '../domain/week/week_key.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/account/domain/health_backup.dart';
import '../features/cycle/domain/cycle_document.dart';
import '../features/cycle/domain/period_entry.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../features/eat/domain/meal_repository.dart';
import '../features/onboarding/domain/intake.dart';
import '../features/progress/domain/progress_repository.dart';
import '../features/signup/domain/locale_preference.dart';
import '../features/today/domain/today_day.dart';
import '../features/today/domain/today_repository.dart';
import '../features/train/domain/train_repository.dart';
import '../routing/app_router.dart';
import 'cycle_state.dart';

/// The `schemaV` every document carrying one is written with.
///
/// `requiredMeta()` in the rules asserts it is an int on `measurements`, and the
/// key whitelists on `cycle` and `periods` admit it. It is the same idea as
/// [kSnapshotSchema] and deliberately a separate number: the local document and
/// the cloud documents can change shape independently.
const int kCloudSchema = 1;

/// Stands in for `FieldValue.serverTimestamp()`.
///
/// It is a sentinel rather than the real thing so that this file — which holds
/// every decision about what the rules will accept — has no Firebase import and
/// can be exercised by a test with no platform channel. `cloud_store.dart`
/// substitutes the real value on the way out.
///
/// It matters that the server writes it. `freshStamp()` in the rules is
/// `request.resource.data.updatedAt == request.time`, and a client that can
/// backdate a write can lose another device's edit in a merge; one that can
/// postdate it pins itself at the top of a range query forever.
const Object kServerTime = _ServerTime();

@immutable
class _ServerTime {
  const _ServerTime();
  @override
  String toString() => 'serverTimestamp';
}

/// One document, addressed the way the rules address it.
@immutable
class CloudDoc {
  const CloudDoc({
    required this.collection,
    required this.id,
    required this.data,
    this.mergeFields,
    this.bornAs,
  });

  /// The subcollection under `users/{uid}`, or empty for the `users/{uid}`
  /// document itself.
  final String collection;

  /// The document id. Deterministic for everything keyed by a day or a week —
  /// see the note at the top of this file.
  final String id;

  final Map<String, Object?> data;

  /// The field paths this write may touch, or null to replace the document.
  ///
  /// Only `users/{uid}` uses it, and it is not an optimisation. That document
  /// is shared with sign-up, which owns fields this file knows nothing about;
  /// a plain `set` would delete them, and a plain merge would DEEP-merge the
  /// maps — leaving whatever `privacy` used to hold beside what we just wrote,
  /// which is exactly what `validPrivacy()`'s `hasOnly` refuses. Naming the
  /// paths replaces each map whole and leaves every other field alone.
  final List<String>? mergeFields;

  /// The document this one must be BORN as, when the rules forbid creating it
  /// in its final state. Null for everything else.
  ///
  /// One case: `sessions`. Spine C8 says a live session must be born with
  /// nothing logged, and the rule is on CREATE
  /// (`source != 'live' || loggedSetCount == 0`). That is right for a session
  /// being run, and it makes a FINISHED live session impossible to upload in
  /// one write — which is what replication does, every time, for every session
  /// she logged before she had an account. So the store writes the birth
  /// document the rule describes and then fills it, which is the same two
  /// states in the same order a live session goes through anyway.
  final Map<String, Object?>? bornAs;

  /// True for the `users/{uid}` document itself rather than a subcollection.
  bool get isRoot => collection.isEmpty;

  /// `sessions/live-3`, or empty for the root document. Used as the key of the
  /// ledger that remembers what has already been accepted.
  String get path => isRoot ? '' : '$collection/$id';

  @override
  String toString() => 'CloudDoc(${isRoot ? 'users/{uid}' : path})';
}

/// Turns the stores into documents, and documents back into the stores.
abstract final class CloudDocuments {
  /// Every document this phone would write for her, right now.
  ///
  /// Reads the live stores and touches nothing. Cheap enough to call on every
  /// debounce: the caller compares what comes back against what the server has
  /// already accepted and writes only the difference.
  ///
  /// Her health data (check-ins, measurements, cycle, periods, and the
  /// `lifeStage` and `allergies` keys of her profile) is included only while
  /// she has opted in to the health backup. Off, those keys are absent, not
  /// null, because the rules test for their presence. See
  /// `features/account/domain/health_backup.dart`.
  static List<CloudDoc> capture() {
    final health = HealthBackupPreference.instance.enabled;
    return <CloudDoc>[
      _userDoc(includeHealth: health),
      ..._sessions(),
      ..._mealDays(),
      _eatPrefsDoc(),
      ..._mealPlans(),
      if (health) ..._checkIns(),
      if (health) ..._measurements(),
      if (health) ?_cycleDoc(),
      if (health) ..._periods(),
      ..._notices(),
      _firstWeekDoc(),
    ];
  }

  /// Folds [remote] into the live stores under the rule at the top of this
  /// file, and answers how many records it took from the cloud.
  ///
  /// **Never throws.** A document read out of Firestore is untrusted input in
  /// exactly the way a snapshot read off the phone is — it can be older, newer,
  /// written by a Function whose shape changed, or half resolved while its
  /// server timestamp is still pending. Each collection is folded inside its
  /// own guard, so one unreadable shape costs that collection and not her
  /// launch.
  static int mergeIn(Iterable<CloudDoc> remote) {
    final byCollection = <String, List<CloudDoc>>{};
    for (final doc in remote) {
      byCollection.putIfAbsent(doc.collection, () => <CloudDoc>[]).add(doc);
    }

    var taken = 0;
    for (final fold in _folds.entries) {
      final docs = byCollection[fold.key];
      if (docs == null || docs.isEmpty) continue;
      try {
        taken += fold.value(docs);
      } catch (_) {
        // One collection is one collection. The rest of her week still merges,
        // and every store is left exactly as it was found.
      }
    }
    return taken;
  }

  /// Collection name to the function that folds it in. A collection not named
  /// here is ignored, which is what lets a newer backend add one without an
  /// older build choking on it.
  static final Map<String, int Function(List<CloudDoc>)> _folds = {
    '': _foldUser,
    'sessions': _foldSessions,
    'meals': _foldMealDays,
    'eatPrefs': _foldEatPrefs,
    'mealPlans': _foldMealPlans,
    'checkins': _foldCheckIns,
    'measurements': _foldMeasurements,
    'cycle': _foldCycle,
    'periods': _foldPeriods,
    'notices': _foldNotices,
    'firstWeek': _foldFirstWeek,
  };

  /// The subcollections [mergeIn] can read, for the pull to ask for.
  ///
  /// `weeks`, `bests` and `awards` are deliberately absent: the rules make them
  /// `allow write: if false` because G6 says points, weeks, tiers and bests are
  /// server-written, nothing writes them yet, and no document shape for them has
  /// been agreed. Reading them would mean inventing one here — a schema guessed
  /// from a collection name, which is the thing the rules file itself warns
  /// against two hundred lines from the bottom.
  ///
  /// The four health collections are asked for only while the health backup
  /// is on; off, the phone's copy is the only one that counts.
  static List<String> get readableCollections => <String>[
    for (final name in _allReadableCollections)
      if (HealthBackupPreference.instance.enabled ||
          !kHealthCollections.contains(name))
        name,
  ];

  static const List<String> _allReadableCollections = <String>[
    'sessions',
    'meals',
    'eatPrefs',
    'mealPlans',
    'checkins',
    'measurements',
    'cycle',
    'periods',
    'notices',
    'firstWeek',
  ];
}

// ------------------------------------------------------------ users/{uid} ---

CloudDoc _userDoc({required bool includeHealth}) {
  final intake = AppRouter.intakeRepository.read();
  final dietary = AppRouter.dietaryRepository.read();
  final privacy = AppRouter.privacyRepository.settings();
  final notify = AppRouter.privacyRepository.notify();

  return CloudDoc(
    collection: '',
    id: '',
    // The four paths `allow update` names. Anything sign-up put on this
    // document — and it is written there first, before verification — is left
    // untouched.
    mergeFields: const <String>['profile', 'privacy', 'notify', 'updatedAt'],
    data: <String, Object?>{
      // Nothing inside `profile` is validated by the rules, which is why the
      // three things with no collection of their own live here: her setup
      // answers, her allergies and the language she chose. The global
      // invariants bite on the top-level keys only, and none of these is one.
      'profile': <String, Object?>{
        'goal': intake.goal.wireName,
        'place': intake.place.wireName,
        'equipment': [for (final item in intake.equipment) item.wireName],
        'days': intake.days,
        'minutes': intake.minutes,
        if (includeHealth) 'lifeStage': intake.lifeStage.wireName,
        'setupDone': AppRouter.intakeRepository.setupDone,
        // Null is her never having been asked and an empty list is her
        // answering "nothing". Collapsing the two is how an allergy guard
        // silently turns itself off, so the null travels.
        if (includeHealth)
          'allergies': dietary.allergies?.map((a) => a.wireName).toList(),
        'dietary': dietary.dietary?.map((d) => d.wireName).toList(),
        'language': AppRouter.localePreference.read()?.code,
      },
      'privacy': <String, Object?>{
        'profileVisible': privacy.profileVisible,
        'showBests': privacy.showBests,
        'blurFacesDefault': privacy.blurFacesDefault,
        'shareLogsWithCoach': privacy.shareLogsWithCoach,
        'policyVersion': privacy.policyVersion,
      },
      'notify': <String, Object?>{
        'push': notify.push,
        'mealNudge': notify.mealNudge,
        // Clamped here as well as on the way off the phone. `validNotify()`
        // refuses anything outside 0–1439, and a rejected write would take her
        // profile and her setup answers down with it for the sake of a quiet
        // hour nobody can see.
        'quietStart': notify.quietStart.clamp(0, 1439),
        'quietEnd': notify.quietEnd.clamp(0, 1439),
        'usualMealHour': ?notify.usualMealHour,
      },
      'updatedAt': kServerTime,
    },
  );
}

int _foldUser(List<CloudDoc> docs) {
  final data = docs.first.data;
  final profile = _map(data['profile']);
  if (profile == null) return 0;

  // Her setup answers are a singleton: this phone either has them or it does
  // not, and `setupDone` is the only thing in the app that knows which. A woman
  // who has answered on this phone keeps her own answers; one who reinstalled
  // gets them back instead of being walked through O01 again.
  if (AppRouter.intakeRepository.setupDone) return 0;
  if (_bool(profile['setupDone']) != true) return 0;

  final defaults = Intake.defaults;
  final equipment = <Equipment>{
    for (final wire in _list(profile['equipment']) ?? const <Object?>[])
      ?_wire(Equipment.values, wire),
  };
  final days = _int(profile['days']) ?? defaults.days;
  final minutes = _int(profile['minutes']) ?? defaults.minutes;

  final intake = Intake(
    goal: _wire(TrainingGoal.values, profile['goal']) ?? defaults.goal,
    place: _wire(TrainingPlace.values, profile['place']) ?? defaults.place,
    equipment: equipment.isEmpty ? defaults.equipment : equipment,
    days: Intake.allowedDays.contains(days) ? days : defaults.days,
    minutes: Intake.allowedMinutes.contains(minutes)
        ? minutes
        : defaults.minutes,
    // Kept as this phone has it when the cloud has none: never replaced by
    // the default "none" from a profile that simply did not carry it.
    lifeStage:
        _wire(LifeStage.values, profile['lifeStage']) ??
        AppRouter.intakeRepository.read().lifeStage,
  );
  // N2. With the health backup off the cloud profile carries no lifeStage
  // (and no allergies). Her other answers come back, but setup is NOT marked
  // done, so she is asked the life-stage question again (and Eat asks her
  // allergies, which stay unknown). Marking it done here would hand a
  // pregnant, postpartum or injured woman the standard programme on a new
  // phone without a word.
  AppRouter.intakeRepository.restore(
    intake,
    setupDone: profile.containsKey('lifeStage'),
  );

  Set<AllergenTag>? allergies;
  if (_list(profile['allergies']) case final stored?) {
    allergies = {
      for (final wire in stored)
        if (_str(wire) case final name?) ?AllergenTag.fromWire(name),
    };
  }
  Set<DietaryTag>? dietary;
  if (_list(profile['dietary']) case final stored?) {
    dietary = {
      for (final wire in stored)
        if (_str(wire) case final name?) ?DietaryTag.fromWire(name),
    };
  }
  if (allergies != null || dietary != null) {
    AppRouter.dietaryRepository.restore(
      DietaryProfile(allergies: allergies, dietary: dietary),
    );
  }

  // Only a language this build has. `AppLanguage.fromCode` answers Arabic for
  // anything it does not recognise, which is right for a chooser and wrong for
  // a document: an unreadable code must leave the app's own default standing.
  final code = _str(profile['language']);
  if ((code == 'ar' || code == 'en') &&
      AppRouter.localePreference.read() == null) {
    AppRouter.localePreference.write(AppLanguage.fromCode(code));
  }

  return 1;
}

// --------------------------------------------------------------- sessions ---

Iterable<CloudDoc> _sessions() sync* {
  for (final session in AppRouter.trainRepository.sessions) {
    if (session.id.isEmpty) continue;
    final logged = session.sets.where((set) => set.outcome != null).length;
    yield CloudDoc(
      collection: 'sessions',
      id: session.id,
      data: <String, Object?>{
        'source': session.source.name,
        'dateKey': session.dateKey,
        'sets': [for (final set in session.sets) _loggedSet(set)],
        // `allow create` reads this field directly for a live session, so it is
        // written always rather than conditionally — a missing field is an
        // error inside a rule, and an error inside a rule is a denial.
        'loggedSetCount': logged,
        'durationSec': session.durationSec,
        'completed': session.completed,
        'assignmentId': ?session.assignmentId,
        'planVersion': ?session.planVersion,
        'workoutId': ?session.workoutId,
        'activity': ?session.activity,
        'recallMethod': ?session.recallMethod?.name,
        'endedReason': ?session.endedReason?.name,
        'schemaV': kCloudSchema,
        'updatedAt': kServerTime,
      },
      // See [CloudDoc.bornAs]. Only a live session needs it; a recalled or an
      // unplanned one is logged after the fact and the rule exempts it.
      bornAs: session.source != SessionSource.live
          ? null
          : <String, Object?>{
              'source': 'live',
              'dateKey': session.dateKey,
              'sets': const <Object?>[],
              'loggedSetCount': 0,
              'schemaV': kCloudSchema,
              'updatedAt': kServerTime,
            },
    );
  }
}

int _foldSessions(List<CloudDoc> docs) {
  final repository = AppRouter.trainRepository;
  final held = {for (final session in repository.sessions) session.id};
  final added = <TrainSession>[];

  for (final doc in docs) {
    if (held.contains(doc.id)) continue;
    final session = _readSession(doc.id, doc.data);
    if (session != null) added.add(session);
  }
  if (added.isEmpty) return 0;

  repository.restore(
    sessions: <TrainSession>[...repository.sessions, ...added],
    flushes: repository.flushes.toList(),
    swaps: repository.swaps.toList(),
    // Deliberately not carried: a session she was midway through is over, and
    // the counter has to stay ahead of every id that now exists or the next
    // live session reuses one.
    sessionCounter: repository.sessionCounter,
  );
  return added.length;
}

TrainSession? _readSession(String id, Map<String, Object?> row) {
  final source = _pick(SessionSource.values, row['source']);
  if (source == null) return null;
  return TrainSession(
    id: id,
    source: source,
    dateKey: _str(row['dateKey']) ?? '',
    sets: _readLoggedSets(row['sets']),
    assignmentId: _str(row['assignmentId']),
    planVersion: _str(row['planVersion']),
    workoutId: _str(row['workoutId']),
    activity: _str(row['activity']),
    recallMethod: _pick(RecallMethod.values, row['recallMethod']),
    endedReason: _pick(EndedReason.values, row['endedReason']),
    durationSec: _int(row['durationSec']) ?? 0,
    completed: _bool(row['completed']) ?? false,
  );
}

Map<String, Object?> _loggedSet(LoggedSet set) => <String, Object?>{
  'prescribed': <String, Object?>{
    'exerciseId': set.prescribed.exerciseId,
    'order': set.prescribed.order,
    'weightKg': set.prescribed.weightKg,
    'reps': set.prescribed.reps,
    'holdSeconds': set.prescribed.holdSeconds,
  },
  if (set.outcome case final outcome?)
    'outcome': <String, Object?>{
      'weightKg': outcome.weightKg,
      'reps': outcome.reps,
      'holdSeconds': outcome.holdSeconds,
      'skipped': outcome.skipped,
    },
};

List<LoggedSet> _readLoggedSets(Object? raw) => <LoggedSet>[
  for (final entry in _list(raw) ?? const <Object?>[])
    if (_map(entry) case final row?)
      if (_map(row['prescribed']) case final prescribed?)
        if (_str(prescribed['exerciseId']) case final exerciseId?)
          LoggedSet(
            prescribed: PrescribedSet(
              exerciseId: exerciseId,
              order: _int(prescribed['order']) ?? 1,
              weightKg: _double(prescribed['weightKg']),
              reps: _int(prescribed['reps']),
              holdSeconds: _int(prescribed['holdSeconds']),
            ),
            outcome: switch (_map(row['outcome'])) {
              null => null,
              final outcome => SetOutcome(
                weightKg: _double(outcome['weightKg']),
                reps: _int(outcome['reps']),
                holdSeconds: _int(outcome['holdSeconds']),
                skipped: _bool(outcome['skipped']) ?? false,
              ),
            },
          ),
];

// ------------------------------------------------------------------ meals ---

Iterable<CloudDoc> _mealDays() sync* {
  for (final entry in AppRouter.mealRepository.store.days.entries) {
    if (!_isDayId(entry.key)) continue;
    final day = entry.value;

    var kcal = 0;
    var protein = 0;
    final slots = <String, Object?>{};
    for (final slot in MealSlot.values) {
      final items = day.itemsIn(slot);
      if (items.isEmpty) continue;
      // The same cap the rule asserts, applied before the write rather than
      // discovered by it.
      final kept = items.length <= kSlotItemCap
          ? items
          : items.sublist(0, kSlotItemCap);
      slots[slot.name] = [for (final item in kept) _mealItem(item)];
      for (final item in kept) {
        kcal += item.kcal;
        protein += item.proteinG;
      }
    }

    yield CloudDoc(
      collection: 'meals',
      id: entry.key,
      data: <String, Object?>{
        'slots': slots,
        // Clamped to the rule's own bounds. A total outside them is a corrupt
        // count, and letting it refuse the write would cost her the whole day.
        'totals': <String, Object?>{
          'kcal': kcal.clamp(0, 30000),
          'protein': protein.clamp(0, 2000),
        },
        'firstLogAt': ?day.firstLogAt,
        'tz': day.tz,
        'libVersion': day.libVersion,
        // `skippedAt` is the only key in the rule's whitelist that can carry
        // which slots she skipped, and the model records which and not when —
        // `MealDay.skipped` is a set of slots with no clock on it. So the slot
        // names travel and no timestamp is invented to match the key's name.
        // The reader below also accepts a map, which is the shape a server
        // writing real skip times would use.
        if (day.skipped.isNotEmpty)
          'skippedAt': [for (final slot in day.skipped) slot.name],
        'updatedAt': kServerTime,
      },
    );
  }
}

int _foldMealDays(List<CloudDoc> docs) {
  final store = AppRouter.mealRepository.store;
  var taken = 0;
  for (final doc in docs) {
    if (!_isDayId(doc.id)) continue;
    if (store.days.containsKey(doc.id)) continue;
    final day = _readMealDay(doc.id, doc.data);
    if (day == null) continue;
    store.days[doc.id] = day;
    taken++;
  }
  return taken;
}

MealDay? _readMealDay(String dayId, Map<String, Object?> row) {
  final slots = <MealSlot, List<MealItem>>{};
  for (final entry in (_map(row['slots']) ?? const {}).entries) {
    final slot = _pick(MealSlot.values, entry.key);
    if (slot == null) continue;
    final items = <MealItem>[
      for (final raw in _list(entry.value) ?? const <Object?>[])
        ?_readMealItem(raw),
    ];
    slots[slot] = items.length <= kSlotItemCap
        ? items
        : items.sublist(0, kSlotItemCap);
  }

  // Both shapes: the list this build writes, and the map a server would.
  final skippedRaw = row['skippedAt'];
  final skippedNames = <Object?>[
    ...?_list(skippedRaw),
    ...?_map(skippedRaw)?.keys,
  ];

  return MealDay(
    dayId: dayId,
    slots: slots,
    firstLogAt: _time(row['firstLogAt']),
    tz: _str(row['tz']) ?? '',
    libVersion: _int(row['libVersion']) ?? 0,
    skipped: {for (final name in skippedNames) ?_pick(MealSlot.values, name)},
  );
}

Map<String, Object?> _mealItem(MealItem item) => <String, Object?>{
  'itemId': item.itemId,
  'foodId': item.foodId,
  'servings': item.servings,
  'size': item.size,
  'loggedAt': item.loggedAt,
  'source': item.source.name,
  'origin': item.origin.name,
  'kcal': item.kcal,
  'proteinG': item.proteinG,
  if (item.planRef case final ref?)
    'planRef': <String, Object?>{
      'assignmentId': ref.assignmentId,
      'slot': ref.slot.name,
      'idx': ref.idx,
    },
  'helpingOf': ?item.helpingOf,
  'allergenOverride': item.allergenOverride,
};

MealItem? _readMealItem(Object? raw) {
  final row = _map(raw);
  if (row == null) return null;
  final itemId = _str(row['itemId']);
  final foodId = _str(row['foodId']);
  final loggedAt = _time(row['loggedAt']);
  if (itemId == null || foodId == null || loggedAt == null) return null;
  final ref = _map(row['planRef']);
  return MealItem(
    itemId: itemId,
    foodId: foodId,
    servings: _num(row['servings']) ?? 1,
    size: _str(row['size']) ?? '',
    loggedAt: loggedAt,
    source: _pick(MealSource.values, row['source']) ?? MealSource.search,
    origin: _pick(MealOrigin.values, row['origin']) ?? MealOrigin.search,
    kcal: _int(row['kcal']) ?? 0,
    proteinG: _int(row['proteinG']) ?? 0,
    planRef: switch (ref) {
      null => null,
      final ref => switch ((
        _str(ref['assignmentId']),
        _pick(MealSlot.values, ref['slot']),
      )) {
        (final String assignmentId, final MealSlot slot) => PlanRef(
          assignmentId: assignmentId,
          slot: slot,
          idx: _int(ref['idx']) ?? 0,
        ),
        _ => null,
      },
    },
    helpingOf: _str(row['helpingOf']),
    allergenOverride: _strings(row['allergenOverride']),
  );
}

// --------------------------------------------------------------- eatPrefs ---

CloudDoc _eatPrefsDoc() {
  final prefs = AppRouter.mealRepository.store.prefs;
  return CloudDoc(
    collection: 'eatPrefs',
    // `docId == 'current'` is in the rule. One document, fixed id, so there is
    // no way to accumulate a second set of preferences that disagrees.
    id: 'current',
    data: <String, Object?>{
      'plates': <String, Object?>{
        for (final entry in prefs.plates.entries.take(kPlateCap))
          entry.key: _plate(entry.value),
      },
      'ramadanMode': prefs.ramadanMode.name,
      'proteinTargetGOverride': ?prefs.proteinTargetGOverride,
      'libVersion': prefs.libVersion,
      'updatedAt': kServerTime,
    },
  );
}

int _foldEatPrefs(List<CloudDoc> docs) {
  final store = AppRouter.mealRepository.store;
  final row = docs.first.data;
  final local = store.prefs;

  // Her plates are a map keyed by a content hash of the plate, so they union
  // like any other record: a plate this phone has never seen is added, one it
  // has is left alone.
  final plates = <String, Plate>{...local.plates};
  var taken = 0;
  for (final entry in (_map(row['plates']) ?? const {}).entries) {
    if (plates.containsKey(entry.key)) continue;
    if (plates.length >= kPlateCap) break;
    final plate = _readPlate(entry.key, entry.value);
    if (plate == null) continue;
    plates[entry.key] = plate;
    taken++;
  }

  // The scalars beside them are singletons, so the cloud only speaks where this
  // phone has said nothing: `auto` is the Ramadan pill's untouched state and a
  // null protein target is the unowned one.
  final ramadan = local.ramadanMode == RamadanMode.auto
      ? _pick(RamadanMode.values, row['ramadanMode']) ?? RamadanMode.auto
      : local.ramadanMode;
  final target =
      local.proteinTargetGOverride ?? _int(row['proteinTargetGOverride']);

  store.prefs = EatPrefs(
    plates: plates,
    ramadanMode: ramadan,
    proteinTargetGOverride: target,
    libVersion: local.libVersion,
  );
  return taken;
}

Map<String, Object?> _plate(Plate plate) => <String, Object?>{
  'items': [for (final item in plate.items) _plateItem(item)],
  'lastAt': plate.lastAt,
  'dayCounts': plate.dayCounts,
  'slotCounts': <String, Object?>{
    for (final entry in plate.slotCounts.entries) entry.key.name: entry.value,
  },
  // Firestore map keys are strings. The weekday is an int in the model and
  // reads back through `int.tryParse` below.
  'dowCounts': <String, Object?>{
    for (final entry in plate.dowCounts.entries) '${entry.key}': entry.value,
  },
};

Plate? _readPlate(String plateId, Object? raw) {
  final row = _map(raw);
  final lastAt = row == null ? null : _time(row['lastAt']);
  if (row == null || lastAt == null) return null;
  return Plate(
    plateId: plateId,
    items: _readPlateItems(row['items']),
    lastAt: lastAt,
    dayCounts: <String, int>{
      for (final entry in (_map(row['dayCounts']) ?? const {}).entries)
        entry.key: ?_int(entry.value),
    },
    slotCounts: <MealSlot, int>{
      for (final entry in (_map(row['slotCounts']) ?? const {}).entries)
        ?_pick(MealSlot.values, entry.key): ?_int(entry.value),
    },
    dowCounts: <int, int>{
      for (final entry in (_map(row['dowCounts']) ?? const {}).entries)
        ?int.tryParse(entry.key): ?_int(entry.value),
    },
  );
}

Map<String, Object?> _plateItem(PlateItem item) => <String, Object?>{
  'foodId': item.foodId,
  'size': item.size,
  'servings': item.servings,
};

List<PlateItem> _readPlateItems(Object? raw) => <PlateItem>[
  for (final entry in _list(raw) ?? const <Object?>[])
    if (_map(entry) case final row?)
      if (_str(row['foodId']) case final foodId?)
        PlateItem(
          foodId: foodId,
          size: _str(row['size']) ?? '',
          servings: _num(row['servings']) ?? 1,
        ),
];

// -------------------------------------------------------------- mealPlans ---

Iterable<CloudDoc> _mealPlans() sync* {
  for (final entry in AppRouter.mealRepository.store.plans.entries) {
    // `weekId.matches('^[0-9]{4}-W[0-9]{2}$')` in the rule. A key that is not a
    // week is a corrupt key, and the write would be refused anyway.
    if (WeekKey.tryParse(entry.key) == null) continue;
    final plan = entry.value;
    yield CloudDoc(
      collection: 'mealPlans',
      id: entry.key,
      data: <String, Object?>{
        'dinners': <String, Object?>{
          for (final dinner in plan.dinners.entries)
            dinner.key.name: dinner.value,
        },
        'groceries': <String, Object?>{
          for (final line in plan.groceries.entries.take(kGroceryCap))
            line.key: <String, Object?>{
              'ingredientId': line.value.ingredientId,
              'group': line.value.group.name,
              'ticked': line.value.ticked,
              'tickedAt': ?line.value.tickedAt,
            },
        },
        'recipeVersion': plan.recipeVersion,
        'updatedAt': kServerTime,
      },
    );
  }
}

int _foldMealPlans(List<CloudDoc> docs) {
  final store = AppRouter.mealRepository.store;
  var taken = 0;
  for (final doc in docs) {
    if (WeekKey.tryParse(doc.id) == null) continue;
    if (store.plans.containsKey(doc.id)) continue;
    final plan = _readMealPlan(doc.id, doc.data);
    if (plan == null) continue;
    store.plans[doc.id] = plan;
    taken++;
  }
  return taken;
}

MealPlan? _readMealPlan(String weekId, Map<String, Object?> row) {
  final groceries = <String, GroceryLine>{};
  for (final entry in (_map(row['groceries']) ?? const {}).entries) {
    final line = _map(entry.value);
    final ingredientId = line == null ? null : _str(line['ingredientId']);
    if (line == null || ingredientId == null) continue;
    if (groceries.length >= kGroceryCap) break;
    groceries[entry.key] = GroceryLine(
      itemKey: entry.key,
      ingredientId: ingredientId,
      group: _pick(GroceryGroup.values, line['group']) ?? GroceryGroup.cupboard,
      ticked: _bool(line['ticked']) ?? false,
      tickedAt: _time(line['tickedAt']),
    );
  }
  return MealPlan(
    weekId: weekId,
    dinners: <PlanDay, String>{
      for (final entry in (_map(row['dinners']) ?? const {}).entries)
        ?_pick(PlanDay.values, entry.key): ?_str(entry.value),
    },
    groceries: groceries,
    recipeVersion: _int(row['recipeVersion']) ?? 0,
  );
}

// --------------------------------------------------------------- checkins ---

Iterable<CloudDoc> _checkIns() sync* {
  for (final entry in CycleAppState.instance.checkIns.entries) {
    if (!_isDayId(entry.key)) continue;
    final checkIn = entry.value;
    // Every key is optional and every key that IS present is checked against a
    // closed list. A key carrying null passes `hasOnly` and then fails
    // `energy in ['low','ok','high']`, which would refuse the whole document —
    // so an unanswered question is an absent key, never a null one.
    final data = <String, Object?>{
      if (checkIn.energy case final value?) 'energy': value.name,
      if (checkIn.cramps case final value?) 'cramps': value.name,
      if (checkIn.appetite case final value?) 'appetite': value.name,
      if (checkIn.sleep case final value?) 'sleep': value.name,
      if (checkIn.bloating case final value?) 'bloating': value.name,
      if (checkIn.bleeding case final value?) 'bleeding': value.name,
    };
    // Note what is NOT here: no `schemaV` and no `updatedAt`. The rule's
    // whitelist is the six answers and nothing else, so the K3 metadata every
    // other collection carries would refuse this one.
    if (data.isEmpty) continue;
    yield CloudDoc(collection: 'checkins', id: entry.key, data: data);
  }
}

int _foldCheckIns(List<CloudDoc> docs) {
  final state = CycleAppState.instance;
  final merged = <String, TodayCheckIn>{...state.checkIns};
  var taken = 0;
  for (final doc in docs) {
    if (!_isDayId(doc.id)) continue;
    if (merged.containsKey(doc.id)) continue;
    final checkIn = _readCheckIn(doc.data);
    if (checkIn == null) continue;
    merged[doc.id] = checkIn;
    taken++;
  }
  if (taken == 0) return 0;

  state.restore(
    checkIns: merged,
    decidedOn: state.decidedOn,
    homeCardChosen: state.homeCardChosen,
  );
  // Today's check-in is a fact about today and nothing else (G9 §3.3). A
  // check-in pulled for an earlier day stays in the map for Y10's chart and is
  // never carried forward as though she had logged it this morning.
  final todayId = AppRouter.dayId(DateTime.now());
  AppRouter.todayCheckIn = merged[todayId] ?? TodayCheckIn.absent;
  return taken;
}

TodayCheckIn? _readCheckIn(Map<String, Object?> row) {
  final checkIn = TodayCheckIn(
    energy: _pick(Energy.values, row['energy']),
    cramps: _pick(Cramps.values, row['cramps']),
    appetite: _pick(Appetite.values, row['appetite']),
    sleep: _pick(Sleep.values, row['sleep']),
    bloating: _pick(Bloating.values, row['bloating']),
    bleeding: _pick(Bleeding.values, row['bleeding']),
  );
  // `isEmpty`, not `== TodayCheckIn.absent`: the type carries no equality, so
  // comparing against the sentinel compares identity and is always false.
  return checkIn.isEmpty ? null : checkIn;
}

// ----------------------------------------------------------- measurements ---

Iterable<CloudDoc> _measurements() sync* {
  for (final entry in AppRouter.progressStore.measurements.entries) {
    if (!_isDayId(entry.key)) continue;
    final measurement = entry.value;
    if (measurement.isEmpty) continue;
    yield CloudDoc(
      collection: 'measurements',
      id: entry.key,
      data: <String, Object?>{
        'weightKg': ?measurement.weightKg,
        'waistCm': ?measurement.waistCm,
        'hipsCm': ?measurement.hipsCm,
        'armCm': ?measurement.armCm,
        'thighCm': ?measurement.thighCm,
        'takenAt': measurement.takenAt,
        'note': ?measurement.note,
        // `requiredMeta()` — `schemaV is int && updatedAt == request.time`.
        // This is the one collection where the rules demand both.
        'schemaV': kCloudSchema,
        'updatedAt': kServerTime,
      },
    );
  }
}

int _foldMeasurements(List<CloudDoc> docs) {
  final store = AppRouter.progressStore;
  var taken = 0;
  for (final doc in docs) {
    if (!_isDayId(doc.id)) continue;
    if (store.measurements.containsKey(doc.id)) continue;
    final takenAt = _time(doc.data['takenAt']);
    if (takenAt == null) continue;

    // The store's own bound. A figure that is not positive is a corrupt write,
    // and the one screen she is most sensitive about must not render one.
    num? positive(Object? value) {
      final figure = _num(value);
      return figure != null && figure > 0 ? figure : null;
    }

    final measurement = Measurement(
      dayId: doc.id,
      takenAt: takenAt,
      weightKg: positive(doc.data['weightKg']),
      waistCm: positive(doc.data['waistCm']),
      hipsCm: positive(doc.data['hipsCm']),
      armCm: positive(doc.data['armCm']),
      thighCm: positive(doc.data['thighCm']),
      note: _str(doc.data['note']),
    );
    if (measurement.isEmpty) continue;
    store.measurements[doc.id] = measurement;
    taken++;
  }
  return taken;
}

// ------------------------------------------------------------------ cycle ---

CloudDoc? _cycleDoc() {
  final cycle = AppRouter.cycleRepository.store.cycle;
  // No document exists before she completes setup, and that absence is what
  // makes the feature invisible everywhere else (§3.1 `notSetUp`). Writing an
  // empty one would create the feature for her.
  if (cycle == null) return null;
  return CloudDoc(
    collection: 'cycle',
    id: 'current',
    data: <String, Object?>{
      'mode': cycle.mode.name,
      'contextFlags': [
        for (final flag in cycle.contextFlags.take(CycleDocument.maxContextFlags))
          flag.name,
      ],
      // Explicitly null rather than absent: `cycleLengthDays == null` is a case
      // the rule names, and "she has not told us her cycle length" is a fact
      // worth storing rather than a field worth omitting.
      'cycleLengthDays': cycle.cycleLengthDays,
      'adaptation': <String, Object?>{
        'workoutSuggestions': cycle.adaptation.workoutSuggestions,
        'mealSuggestions': cycle.adaptation.mealSuggestions,
        'homeCard': cycle.adaptation.homeCard,
        'easierWhenLowEnergy': cycle.adaptation.easierWhenLowEnergy,
      },
      'sharing': <String, Object?>{
        'energyAppetite': cycle.sharing.energyAppetite,
        'symptoms': cycle.sharing.symptoms,
        'datesAndPatterns': cycle.sharing.datesAndPatterns,
        'grantedForRelId': cycle.sharing.grantedForRelId,
      },
      if (cycle.lastPeriod case final last?)
        'lastPeriod': <String, Object?>{
          'startDate': last.startDate,
          'endDate': last.endDate,
        },
      'recentStarts': cycle.recentStarts
          .take(CycleDocument.maxRecentStarts)
          .toList(),
      'schemaV': kCloudSchema,
      'updatedAt': kServerTime,
      // Nothing computed is here, and that is §2.4 at the storage layer: the
      // rule bans `phase`, `cycleDay`, `predictedOvulation`, `fertileWindow`
      // and `forecast` outright, because this product does not decide those.
    },
  );
}

int _foldCycle(List<CloudDoc> docs) {
  final store = AppRouter.cycleRepository.store;
  // A singleton, and the only honest test of "this phone has none" is that it
  // has none. A woman who set My cycle up here keeps exactly what she set.
  if (store.cycle != null) return 0;

  final row = docs.first.data;
  final mode = _pick(CycleMode.values, row['mode']);
  if (mode == null) return 0;

  final adaptation = _map(row['adaptation']) ?? const <String, Object?>{};
  final sharing = _map(row['sharing']) ?? const <String, Object?>{};
  final lastPeriod = _map(row['lastPeriod']);
  final length = _int(row['cycleLengthDays']);

  store.cycle = CycleDocument(
    mode: mode,
    // Capped at the document's own limits, which the rules assert too. A
    // document over them is corrupt, and truncating is what keeps the
    // constructor's asserts from taking the app down.
    contextFlags: {
      for (final name in _list(row['contextFlags']) ?? const <Object?>[])
        ?_pick(CycleContextFlag.values, name),
    }.take(CycleDocument.maxContextFlags).toSet(),
    cycleLengthDays:
        length != null &&
            length >= CycleDocument.minCycleLengthDays &&
            length <= CycleDocument.maxCycleLengthDays
        ? length
        : null,
    adaptation: CycleAdaptation(
      workoutSuggestions: _bool(adaptation['workoutSuggestions']) ?? false,
      mealSuggestions: _bool(adaptation['mealSuggestions']) ?? false,
      homeCard: _bool(adaptation['homeCard']) ?? false,
      easierWhenLowEnergy: _bool(adaptation['easierWhenLowEnergy']) ?? false,
    ),
    sharing: CycleSharing(
      energyAppetite: _bool(sharing['energyAppetite']) ?? false,
      symptoms: _bool(sharing['symptoms']) ?? false,
      datesAndPatterns: _bool(sharing['datesAndPatterns']) ?? false,
      grantedForRelId: _str(sharing['grantedForRelId']),
    ),
    lastPeriod: switch (lastPeriod) {
      null => null,
      final last => switch (_str(last['startDate'])) {
        final String startDate => LastPeriod(
          startDate: startDate,
          endDate: _str(last['endDate']),
        ),
        _ => null,
      },
    },
    recentStarts: _strings(row['recentStarts'])
        .take(CycleDocument.maxRecentStarts)
        .toList(),
  );
  return 1;
}

// ---------------------------------------------------------------- periods ---

Iterable<CloudDoc> _periods() sync* {
  for (final period in AppRouter.cycleRepository.store.periods.values) {
    final id = period.id;
    if (!_isDayId(id)) continue;
    yield CloudDoc(
      collection: 'periods',
      id: id,
      data: <String, Object?>{
        // `d.start == day` — the id and the field can never disagree, which is
        // why this is the id rather than a second formatting of the date.
        'start': id,
        'end': period.end == null ? null : isoDay(period.end!),
        // `d.stillBleeding == (d.end == null)` — derived from the entry, which
        // derives it from `end`, so the two cannot contradict.
        'stillBleeding': period.stillBleeding,
        'schemaV': kCloudSchema,
        'updatedAt': kServerTime,
      },
    );
  }
}

int _foldPeriods(List<CloudDoc> docs) {
  final store = AppRouter.cycleRepository.store;
  final today = DateTime.now();
  var taken = 0;
  for (final doc in docs) {
    if (store.periods.containsKey(doc.id)) continue;
    final start = _day(_str(doc.data['start']) ?? doc.id);
    if (start == null) continue;
    // `PeriodEntry.validate` is the only way to build one, and that is the
    // point: a stored period that no longer validates is dropped rather than
    // forced back in through a side door.
    final result = PeriodEntry.validate(
      start: start,
      end: _day(_str(doc.data['end'])),
      today: today,
    );
    if (result is! PeriodValid) continue;
    store.periods[result.entry.id] = result.entry;
    taken++;
  }
  return taken;
}

// ---------------------------------------------------------------- notices ---

Iterable<CloudDoc> _notices() sync* {
  for (final key in AppRouter.todayRepository.seenNotices) {
    // The local key is already `kind-yyyy-Www`, which is the id the rule
    // demands (`noticeId == kind + '-' + forWeek`) — the two were written
    // against the same convention and neither knew about the other. The kinds
    // carry no dash, so the first one separates them.
    final at = key.indexOf('-');
    if (at <= 0) continue;
    final kind = _pick(NoticeKind.values, key.substring(0, at));
    final forWeek = key.substring(at + 1);
    if (kind == null || WeekKey.tryParse(forWeek) == null) continue;
    yield CloudDoc(
      collection: 'notices',
      id: key,
      data: <String, Object?>{
        'kind': kind.name,
        'forWeek': forWeek,
        // `request.resource.data.seenAt == request.time`. An acknowledgement
        // whose clock the client chose is an acknowledgement that can be
        // backdated out of existence.
        'seenAt': kServerTime,
      },
    );
  }
}

int _foldNotices(List<CloudDoc> docs) {
  final repository = AppRouter.todayRepository;
  final seen = <String>{...repository.seenNotices};
  var taken = 0;
  for (final doc in docs) {
    final kind = _str(doc.data['kind']);
    final forWeek = _str(doc.data['forWeek']);
    if (kind == null || forWeek == null) continue;
    // The rule makes the id and the fields agree, so a document where they do
    // not is one no conformant writer produced.
    if (doc.id != '$kind-$forWeek') continue;
    if (!seen.add(doc.id)) continue;
    taken++;
  }
  if (taken == 0) return 0;

  // Union, and the direction is the safe one: a notice acknowledged anywhere
  // stays acknowledged. Re-showing "you had a quiet week" to a woman who has
  // already read it and moved on is the harm P0-WEEK-03 names; failing to show
  // it once is not.
  repository.restore(
    day: repository.day,
    seenNotices: seen,
    creditedSessions: repository.creditedSessions,
  );
  return taken;
}

// -------------------------------------------------------------- firstWeek ---

CloudDoc _firstWeekDoc() {
  final arc = AppRouter.todayRepository.day.arc;
  return CloudDoc(
    collection: 'firstWeek',
    id: 'arc',
    data: <String, Object?>{
      'hasAnyLog': arc.hasAnyLog,
      // Written in full every time. `request.resource.data.steps.keys()` is
      // read unconditionally by the rule, so a document with no `steps` map is
      // an error inside the rule and therefore a denial.
      'steps': <String, Object?>{
        for (final step in FirstWeekStep.values)
          step.name: arc.completed.contains(step),
      },
      // No `updatedAt` and no `schemaV`: the whitelist is `hasAnyLog`, `steps`
      // and `completedAt`, and nothing else. `expiresAt`, `deadline` and
      // `failedAt` are banned outright — HANDOFF rule 17 made structural, so
      // the first week cannot become something she loses.
    },
  );
}

int _foldFirstWeek(List<CloudDoc> docs) {
  final repository = AppRouter.todayRepository;
  final arc = repository.day.arc;
  final row = docs.first.data;

  // The one place a union happens INSIDE a singleton, and the only sensible
  // reading of two arcs: a step done on either side is done. An arc has no
  // failure state, so there is nothing an OR can wrongly turn on, and taking
  // the remote arc whole would un-complete a step she finished on this phone.
  final completed = <FirstWeekStep>{...arc.completed};
  for (final entry in (_map(row['steps']) ?? const {}).entries) {
    if (_bool(entry.value) != true) continue;
    final step = _pick(FirstWeekStep.values, entry.key);
    if (step != null) completed.add(step);
  }
  final hasAnyLog = arc.hasAnyLog || (_bool(row['hasAnyLog']) ?? false);

  if (completed.length == arc.completed.length && hasAnyLog == arc.hasAnyLog) {
    return 0;
  }
  repository.restore(
    day: repository.day.copyWith(
      arc: FirstWeekArc(hasAnyLog: hasAnyLog, completed: completed),
    ),
    seenNotices: repository.seenNotices,
    creditedSessions: repository.creditedSessions,
  );
  return 1;
}

// ---------------------------------------------------------------- readers ---
//
// A second set, rather than sharing `app_snapshot.dart`'s, and the difference is
// real rather than a copy: that file decodes JSON, where every time is a string
// and every number arrives as it was written. These decode Firestore values,
// where a time arrives as a `DateTime` (`cloud_store.dart` converts the
// `Timestamp` before this file sees it), an integer can arrive as a double, and
// a field whose server timestamp has not resolved yet arrives as null.
//
// Every one answers null rather than throwing, so a field of the wrong type
// costs that field and not the document.

Map<String, Object?>? _map(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  final Map<Object?, Object?> map => map.map(
    (key, value) => MapEntry('$key', value),
  ),
  _ => null,
};

List<Object?>? _list(Object? value) => value is List ? value.toList() : null;

String? _str(Object? value) => value is String ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

num? _num(Object? value) => value is num ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

double? _double(Object? value) => value is num ? value.toDouble() : null;

/// A moment, however Firestore handed it over. A `Timestamp` has already been
/// converted by the transport; an ISO string is accepted so a document written
/// by a Function that stored a date as text still reads.
DateTime? _time(Object? value) => switch (value) {
  final DateTime time => time,
  final String text => DateTime.tryParse(text),
  _ => null,
};

/// `yyyy-MM-dd` as a local midnight, or null. Used for the two fields that are
/// dates rather than moments: a period's start and its end.
DateTime? _day(String? text) {
  if (text == null || !_isDayId(text)) return null;
  return DateTime.tryParse(text);
}

List<String> _strings(Object? value) => <String>[
  for (final entry in _list(value) ?? const <Object?>[]) ?_str(entry),
];

/// One enum value by its Dart name, or null for a name this build does not
/// have. That is what lets an older build read a document written by a newer
/// one: a value it has never heard of is dropped, not guessed at.
T? _pick<T extends Enum>(List<T> values, Object? value) {
  final name = _str(value);
  if (name == null) return null;
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return null;
}

/// The same, for the enums that carry a stored `wireName` distinct from the
/// Dart name — the ones a rename must not silently rewrite.
T? _wire<T extends Enum>(List<T> values, Object? value) {
  final name = _str(value);
  if (name == null) return null;
  for (final candidate in values) {
    final wire = switch (candidate) {
      TrainingGoal(:final wireName) => wireName,
      TrainingPlace(:final wireName) => wireName,
      Equipment(:final wireName) => wireName,
      LifeStage(:final wireName) => wireName,
      _ => candidate.name,
    };
    if (wire == name) return candidate;
  }
  return null;
}

/// `yyyy-MM-dd`, which is `isDay(id)` in the rules and the id every day-keyed
/// document must carry.
bool _isDayId(String id) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(id);

// ------------------------------------------------------- deliberately out ---
//
// **`weeks`, `bests` and `awards`** are `allow write: if false` — G6 says
// points, weeks, tiers and bests are server-written, because a client that can
// increment its own points can mint any tier. Nothing writes them yet and no
// document shape for them has been agreed, so neither direction is implemented:
// pushing is refused by the rules, and pulling would mean inventing a schema
// from a collection name. This app computes both locally and keeps them in the
// local snapshot, which is where they stay until a Function writes them.
//
// **`splits`** is writable (`ownerKind == 'self'`), and there is nothing to put
// in it. A self-authored split lives in `CoachingDeskState`, which is coaching
// state, which `app_snapshot.dart` deliberately does not carry either — both
// coaching and community are off for the first release. When the snapshot grows
// a `splits` section this grows a collection beside it.
//
// **Where she was standing** — the open post, the scrolled month, the session in
// flight — is not here for the same reason it is not in the snapshot. Those are
// places, not records.
