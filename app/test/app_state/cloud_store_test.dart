// What goes to Firestore, and what happens to her week in each of the four
// states a woman can be in.
//
// Two halves, and they test different kinds of thing.
//
// The first half reads `firebase/firestore.rules` — the deployed file, not a
// copy — pulls the key whitelists and the value lists straight out of it, and
// checks every document this build would write against them. That is deliberate:
// a hand-copied list of allowed keys passes forever while the rules move
// underneath it, and the failure it hides is `PERMISSION_DENIED` on a real
// phone, for a real woman, at the moment she logs something. If a rule is
// tightened, these fail here instead of there.
//
// The second half is the merge, which is where the data loss lives. A woman who
// trained for three weeks with no account and then signed in must still have
// three weeks of training afterwards. There is no worse bug available in this
// product, so the empty-cloud case is tested from both directions: nothing is
// taken away, and nothing local is replaced.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/cloud_store.dart';
import 'package:own_hub/app_state/cloud_transport.dart';
import 'package:own_hub/app_state/cycle_state.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _dayKey = '2026-09-01';
const String _uid = 'her-uid';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    CloudStore.instance.reset();
    CloudStore.instance.ledgerStorage = _MemoryStorage();
    await const ThisPhoneWipe().clearPersistence();
  });

  tearDown(() async {
    CloudStore.instance.reset();
    await const ThisPhoneWipe().clearPersistence();
  });

  // =========================================================================
  group('every document is a shape the deployed rules will accept', () {
    late _Rules rules;

    setUpAll(() {
      final file = File('../firebase/firestore.rules');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'the rules are a deployment artifact and must be there to '
            'check against — a test that skips them checks nothing',
      );
      rules = _Rules(file.readAsStringSync());
    });

    test('no document carries a key its whitelist does not name', () async {
      await _fillEverything();
      final docs = CloudDocuments.capture();
      expect(docs, isNotEmpty);

      for (final collection in const [
        'checkins',
        'meals',
        'eatPrefs',
        'mealPlans',
        'measurements',
        'cycle',
        'periods',
        'notices',
        'firstWeek',
      ]) {
        final allowed = rules.keyWhitelist(collection);
        expect(
          allowed,
          isNotEmpty,
          reason: 'no hasOnly found for $collection — the parser and the '
              'rules have drifted apart',
        );
        final written = docs.where((d) => d.collection == collection);
        expect(
          written,
          isNotEmpty,
          reason: '$collection was never captured, so this proves nothing',
        );
        for (final doc in written) {
          expect(
            doc.data.keys.toSet().difference(allowed),
            isEmpty,
            reason: '$collection/${doc.id} carries a key the rule refuses',
          );
        }
      }
    });

    test('the ids are the deterministic ones the rules demand', () async {
      await _fillEverything();
      final docs = CloudDocuments.capture();

      final day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      final week = RegExp(r'^\d{4}-W\d{2}$');
      for (final doc in docs) {
        switch (doc.collection) {
          // `isDay(id)` — the id IS the date, so a retried write collides with
          // itself rather than becoming a second entry.
          case 'checkins' || 'meals' || 'measurements' || 'periods':
            expect(doc.id, matches(day), reason: '${doc.collection} id');
          case 'mealPlans':
            expect(doc.id, matches(week));
          case 'cycle' || 'eatPrefs':
            expect(doc.id, 'current');
          case 'notices':
            // `noticeId == kind + '-' + forWeek`, so "shown once, never again
            // that week" is structural rather than a flag someone has to check.
            expect(doc.id, '${doc.data['kind']}-${doc.data['forWeek']}');
          case 'firstWeek':
            expect(doc.id, 'arc');
        }
      }
    });

    test('no document can carry a run counter', () async {
      await _fillEverything();
      final banned = rules.runCounterNames();
      expect(banned, contains('streak'));
      for (final doc in CloudDocuments.capture()) {
        expect(
          doc.data.keys.toSet().intersection(banned),
          isEmpty,
          reason: '${doc.collection}/${doc.id} — rule 3 is enforced by the '
              'field not existing, here as well as in the rules',
        );
      }
    });

    test('a check-in answers only in words the rules know, and never null', () async {
      CycleAppState.instance.saveCheckIn(
        const TodayCheckIn(
          energy: Energy.low,
          cramps: Cramps.mild,
          appetite: Appetite.ok,
          sleep: Sleep.poor,
          bloating: Bloating.moderate,
          bleeding: Bleeding.heavy,
        ),
      );
      final doc = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'checkins',
      );

      for (final field in const [
        'energy',
        'cramps',
        'appetite',
        'sleep',
        'bloating',
        'bleeding',
      ]) {
        final allowed = rules.valuesFor(field);
        expect(allowed, isNotEmpty, reason: 'no value list found for $field');
        expect(allowed, contains(doc.data[field]));
      }

      // A key present and null passes `hasOnly` and then fails
      // `energy in ['low','ok','high']`, which refuses the whole document. An
      // unanswered question must be an ABSENT key.
      CycleAppState.instance.reset();
      CycleAppState.instance.saveCheckIn(
        const TodayCheckIn(energy: Energy.high),
      );
      final sparse = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'checkins',
      );
      expect(sparse.data.keys, ['energy']);
      expect(sparse.data.values, isNot(contains(null)));
    });

    test('a finished live session is born with nothing logged', () async {
      _giveHerAFinishedLiveSession();
      final session = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'sessions',
      );

      // `allow create` is `source != 'live' || loggedSetCount == 0`. The final
      // document cannot satisfy it, so there are two writes: the birth the rule
      // describes, then the fill.
      expect(session.data['source'], 'live');
      expect(session.data['loggedSetCount'], 1);
      expect(session.bornAs, isNotNull);
      expect(session.bornAs!['source'], 'live');
      expect(session.bornAs!['loggedSetCount'], 0);
      expect(session.bornAs!['sets'], isEmpty);
    });

    test('a recalled session needs no birth document', () async {
      await AppRouter.trainRepository.logRecalled(
        dateKey: _dayKey,
        method: RecallMethod.plan,
      );
      final session = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'sessions',
      );
      expect(session.data['source'], 'recalled');
      expect(
        session.bornAs,
        isNull,
        reason: 'the rule exempts a session logged after the fact',
      );
    });

    test('a period cannot contradict its own id', () async {
      final draft = PeriodEntry.validate(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
        today: DateTime.now(),
      );
      await AppRouter.periodRepository.save((draft as PeriodValid).entry);

      final period = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'periods',
      );
      // `d.start == day` and `d.stillBleeding == (d.end == null)`.
      expect(period.data['start'], period.id);
      expect(period.data['end'], '2026-09-05');
      expect(period.data['stillBleeding'], isFalse);
    });

    test('the users document touches only the four paths update names', () async {
      await _fillEverything();
      final root = CloudDocuments.capture().firstWhere((d) => d.isRoot);
      final allowed = rules.onlyTouchesForUsers();

      expect(allowed, {'profile', 'privacy', 'notify', 'updatedAt'});
      expect(root.data.keys.toSet().difference(allowed), isEmpty);
      expect(
        root.mergeFields!.toSet(),
        allowed,
        reason: 'named paths, so sign-up\'s own fields on this document are '
            'neither deleted nor deep-merged into something hasOnly refuses',
      );

      // validPrivacy / validNotify, which the app was the only thing checking
      // until the rules grew a shape for them.
      final privacy = root.data['privacy']! as Map<String, Object?>;
      expect(privacy.keys, containsAll(const [
        'profileVisible',
        'showBests',
        'blurFacesDefault',
        'shareLogsWithCoach',
      ]));
      for (final value in privacy.values.take(4)) {
        expect(value, isA<bool>());
      }
      final notify = root.data['notify']! as Map<String, Object?>;
      expect(notify['quietStart'], inInclusiveRange(0, 1439));
      expect(notify['quietEnd'], inInclusiveRange(0, 1439));
    });

    test('nothing computed about her cycle can be stored', () async {
      await AppRouter.cycleRepository.completeSetup(
        mode: CycleMode.datesAndSymptoms,
        contextFlags: const {CycleContextFlag.irregular},
      );
      final cycle = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'cycle',
      );
      // §2.4 at the storage layer: a phase and a prediction are not things this
      // product decides, so they are not things this document can hold.
      for (final banned in const [
        'phase',
        'cycleDay',
        'predictedOvulation',
        'fertileWindow',
        'forecast',
      ]) {
        expect(cycle.data.containsKey(banned), isFalse);
      }
    });
  });

  // =========================================================================
  group('signing in keeps the week she already had', () {
    test('an empty cloud takes nothing away', () async {
      await _fillEverything();
      final before = _whatSheHas();
      final cloud = _FakeCloud(); // no documents at all: a brand-new account

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      expect(
        _whatSheHas(),
        before,
        reason: 'this is the bug that silently deletes a woman\'s training '
            'history — an empty cloud must be indistinguishable from no cloud',
      );
      expect(CloudStore.instance.mergedFromCloud, 0);
      expect(CloudStore.instance.status, CloudStatus.live);
      expect(
        cloud.pushed.map((d) => d.collection).toSet(),
        containsAll(const ['sessions', 'meals', 'checkins', 'periods']),
        reason: 'and the whole of her week goes up, which is the point of '
            'signing in',
      );
    });

    test('a record the cloud holds and this phone does not is added', () async {
      await AppRouter.trainRepository.logRecalled(
        dateKey: _dayKey,
        method: RecallMethod.plan,
      );
      final mine = AppRouter.trainRepository.sessions.single.id;

      final cloud = _FakeCloud()
        ..stored.add(
          const CloudDoc(
            collection: 'sessions',
            id: 'from-her-old-phone',
            data: <String, Object?>{
              'source': 'recalled',
              'dateKey': '2026-08-24',
              'sets': <Object?>[],
              'loggedSetCount': 0,
              'completed': true,
            },
          ),
        );

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      final ids = AppRouter.trainRepository.sessions.map((s) => s.id).toSet();
      expect(ids, containsAll([mine, 'from-her-old-phone']));
      expect(CloudStore.instance.mergedFromCloud, 1);
    });

    test('a record that collides with a local one does not replace it', () async {
      AppRouter.mealRepository.store.apply(
        MealWrite.transform(
          dayId: _dayKey,
          slot: MealSlot.lunch,
          tz: WeekKey.fallbackTimezone,
          libVersion: 1,
          added: [_koshari],
        ),
      );

      final cloud = _FakeCloud()
        ..stored.add(
          const CloudDoc(
            collection: 'meals',
            id: _dayKey,
            // An older copy of the same day, from before she logged lunch.
            data: <String, Object?>{
              'slots': <String, Object?>{},
              'totals': <String, Object?>{'kcal': 0, 'protein': 0},
              'tz': 'Africa/Cairo',
              'libVersion': 1,
            },
          ),
        );

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      final day = AppRouter.mealRepository.store.days[_dayKey];
      expect(
        day?.itemsIn(MealSlot.lunch).single.foodId,
        'koshari_bowl',
        reason: 'the local copy is at least as new as the copy made from it',
      );
      expect(CloudStore.instance.mergedFromCloud, 0);
    });

    test('a cycle she set up here is not replaced by the one in the cloud', () async {
      await AppRouter.cycleRepository.completeSetup(
        mode: CycleMode.symptomsOnly,
        contextFlags: const {CycleContextFlag.perimenopause},
      );

      final cloud = _FakeCloud()
        ..stored.add(
          const CloudDoc(
            collection: 'cycle',
            id: 'current',
            data: <String, Object?>{
              'mode': 'datesAndSymptoms',
              'contextFlags': <Object?>[],
            },
          ),
        );

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      expect(
        AppRouter.cycleRepository.store.cycle?.mode,
        CycleMode.symptomsOnly,
        reason: 'Y14 is a decision she made about what this app may show her, '
            'and a merge must never quietly widen it',
      );
    });

    test('a cycle she never set up here is taken from the cloud', () async {
      expect(AppRouter.cycleRepository.store.cycle, isNull);

      final cloud = _FakeCloud()
        ..stored.add(
          const CloudDoc(
            collection: 'cycle',
            id: 'current',
            data: <String, Object?>{
              'mode': 'datesAndSymptoms',
              'cycleLengthDays': 30,
              'contextFlags': <Object?>['irregular'],
            },
          ),
        );

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      expect(
        AppRouter.cycleRepository.store.cycle?.cycleLengthDays,
        30,
        reason: 'a reinstall is the case this exists for',
      );
    });

    test('a step of the first week done on either side stays done', () async {
      final cloud = _FakeCloud()
        ..stored.add(
          const CloudDoc(
            collection: 'firstWeek',
            id: 'arc',
            data: <String, Object?>{
              'hasAnyLog': true,
              'steps': <String, Object?>{'logMeal': true},
            },
          ),
        );

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      // An arc has no failure state, so an OR can never turn something on that
      // she would rather were off — and taking the remote arc whole would
      // un-complete a step she finished here.
      expect(
        AppRouter.todayRepository.day.arc.completed,
        contains(FirstWeekStep.logMeal),
      );
    });

    test('a notice acknowledged anywhere stays acknowledged', () async {
      final week = WeekKey.of(DateTime(2026, 9, 1));
      final cloud = _FakeCloud()
        ..stored.add(
          CloudDoc(
            collection: 'notices',
            id: 'quietWeek-${week.id}',
            data: <String, Object?>{'kind': 'quietWeek', 'forWeek': week.id},
          ),
        );

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      expect(
        AppRouter.todayRepository.noticeSeen(NoticeKind.quietWeek, week),
        isTrue,
        reason: 'showing "you had a quiet week" again to a woman who has '
            'already read it and moved on is the harm P0-WEEK-03 names',
      );
    });

    test('the capture round-trips back into stores that were emptied', () async {
      await _fillEverything();
      final before = _whatSheHas();
      final captured = CloudDocuments.capture();

      await const ThisPhoneWipe().clearPersistence();
      expect(nothingOfHersRemains, isTrue);

      CloudDocuments.mergeIn(captured);

      final after = _whatSheHas();
      expect(after['sessions'], before['sessions']);
      expect(after['meals'], before['meals']);
      expect(after['checkins'], before['checkins']);
      expect(after['periods'], before['periods']);
      expect(after['measurements'], before['measurements']);
      expect(after['cycle'], before['cycle']);
    });
  });

  // =========================================================================
  group('signed in, not verified yet — which is every account today', () {
    test('a refused pull leaves her on the phone and says nothing', () async {
      await _fillEverything();
      final before = _whatSheHas();
      final cloud = _FakeCloud()..refusePull = CloudRefusal.notVerified;

      CloudStore.instance.transport = cloud;
      // The assertion is partly that this line does not throw.
      await CloudStore.instance.linkFor(_uid);

      expect(CloudStore.instance.status, CloudStatus.notVerified);
      expect(_whatSheHas(), before);
      expect(
        cloud.pushed,
        isEmpty,
        reason: 'nothing is offered to a server that has already said no',
      );
    });

    test('a refused push stops the pushing rather than retrying it', () async {
      await _fillEverything();
      final cloud = _FakeCloud()..refusePush = CloudRefusal.notVerified;

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);
      await _settle();

      expect(CloudStore.instance.status, CloudStatus.notVerified);
      final attempted = cloud.pushed.length;
      expect(attempted, greaterThan(0));

      // She goes on using the app. Nothing further is offered: the claim she is
      // missing is minted by a server on its own schedule, and a client that
      // keeps asking is a client billing her battery to be told no.
      await AppRouter.trainRepository.logRecalled(
        dateKey: '2026-09-02',
        method: RecallMethod.history,
      );
      await CloudStore.instance.syncNow();
      await _settle();

      expect(cloud.pushed.length, attempted);
    });

    test('her week keeps being written to the phone regardless', () async {
      final storage = _MemoryStorage();
      LocalPersistence.instance.storage = storage;
      LocalPersistence.instance.start();
      addTearDown(LocalPersistence.instance.reset);

      CloudStore.instance.transport = _FakeCloud()
        ..refusePull = CloudRefusal.notVerified;
      await CloudStore.instance.linkFor(_uid);

      await AppRouter.trainRepository.logRecalled(
        dateKey: _dayKey,
        method: RecallMethod.plan,
      );
      await LocalPersistence.instance.flush();

      expect(storage.document, isNotNull);
      expect(storage.document, contains(_dayKey));
    });
  });

  // =========================================================================
  group('no account, and no network', () {
    test('with Firebase absent nothing is constructed and nothing runs', () async {
      final cloud = _FakeCloud();
      CloudStore.instance.transport = cloud;

      // `FirebaseBoot.isReady` is false in every widget test, which is the same
      // state as a phone whose Play Services is broken.
      await CloudStore.instance.start();

      expect(CloudStore.instance.status, CloudStatus.unavailable);
      expect(CloudStore.instance.isRunning, isFalse);
      expect(cloud.pulled, isEmpty);
      expect(cloud.pushed, isEmpty);
    });

    test('with no account there is nowhere to write, online or not', () async {
      await _fillEverything();
      final cloud = _FakeCloud();
      CloudStore.instance.transport = cloud;

      await CloudStore.instance.syncNow();

      expect(CloudStore.instance.uid, isNull);
      expect(CloudStore.instance.status, CloudStatus.local);
      expect(cloud.pushed, isEmpty);
    });

    test('a pull that fails for want of signal still pushes', () async {
      await _fillEverything();
      final cloud = _FakeCloud()
        ..refusePull = CloudRefusal.unreachable
        ..acknowledge = false; // offline: the write queues and never acks

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);

      expect(
        CloudStore.instance.status,
        CloudStatus.live,
        reason: 'no signal is a woman on the metro, not a fault',
      );
      expect(cloud.pushed, isNotEmpty);
    });

    test('a write that never acknowledges is not queued twice', () async {
      await _fillEverything();
      final cloud = _FakeCloud()..acknowledge = false;

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);
      final first = cloud.pushed.length;

      await CloudStore.instance.syncNow();
      await _settle();

      expect(
        cloud.pushed.length,
        first,
        reason: 'a document already on Firestore\'s own durable queue is not '
            'handed to it again every three seconds',
      );
    });
  });

  // =========================================================================
  group('what the server has already accepted is not sent again', () {
    test('an unchanged document is written once', () async {
      await _fillEverything();
      final cloud = _FakeCloud();

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);
      await _settle();
      final first = cloud.pushed.length;
      expect(first, greaterThan(0));

      await CloudStore.instance.syncNow();
      await _settle();
      expect(cloud.pushed.length, first);
    });

    test('a changed document is', () async {
      await _fillEverything();
      final cloud = _FakeCloud();

      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);
      await _settle();
      final first = cloud.pushed.length;

      await AppRouter.measurementsRepository.save(
        Measurement(
          dayId: '2026-09-08',
          takenAt: DateTime(2026, 9, 8),
          weightKg: 60,
        ),
      );
      await CloudStore.instance.syncNow();
      await _settle();

      expect(
        cloud.pushed.sublist(first).map((d) => d.path),
        contains('measurements/2026-09-08'),
      );
    });

    test('deleting her account forgets the link and the ledger', () async {
      await _fillEverything();
      final cloud = _FakeCloud();
      CloudStore.instance.transport = cloud;
      await CloudStore.instance.linkFor(_uid);
      await _settle();

      await const ThisPhoneWipe().clearPersistence();
      await _settle();

      expect(CloudStore.instance.uid, isNull);
      // Left behind, a new account on this handset would inherit a ledger
      // claiming her documents were already uploaded, and never upload them.
      final storage = CloudStore.instance.ledgerStorage as _MemoryStorage;
      expect(storage.document, isNull);
    });
  });
}

// ------------------------------------------------------------------ fakes ---

/// A cloud that records what it was given and can be told to refuse.
class _FakeCloud implements CloudTransport {
  final List<CloudDoc> stored = <CloudDoc>[];
  final List<CloudDoc> pushed = <CloudDoc>[];
  final List<String> pulled = <String>[];

  CloudRefusal? refusePull;
  CloudRefusal? refusePush;

  /// False stands in for no signal: the write is queued and its future never
  /// completes, which is exactly what Firestore's own `set()` does offline.
  bool acknowledge = true;

  @override
  Future<List<CloudDoc>> pull(String uid) async {
    pulled.add(uid);
    final refusal = refusePull;
    if (refusal != null) throw CloudRefused(refusal);
    return stored;
  }

  @override
  Future<void> push(String uid, CloudDoc doc) async {
    pushed.add(doc);
    final refusal = refusePush;
    if (refusal != null) throw CloudRefused(refusal);
    if (!acknowledge) return Completer<void>().future;
  }
}

/// A snapshot store held in memory, so a test can look at what was written.
class _MemoryStorage implements SnapshotStorage {
  String? document;

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String snapshot) async => document = snapshot;

  @override
  Future<void> erase() async => document = null;
}

/// The deployed rules, read rather than copied.
class _Rules {
  _Rules(this.text);

  final String text;

  /// The body of `match /<name>/{...} { … }` inside `users/{uid}`, by brace
  /// balance rather than by a line count — the file is a thousand lines and
  /// growing, and a count would rot on the next edit.
  ///
  /// The path placeholder is skipped rather than counted. `match /meals/{day}`
  /// opens and closes a brace before the block's own body starts, and balancing
  /// naively returns the match line and nothing else — which then finds no
  /// `hasOnly` and reads as "the rule has no whitelist" rather than as a broken
  /// parser. A placeholder is the one `{` that follows a slash.
  String block(String collection) {
    final start = text.indexOf(RegExp('match /$collection/\\{'));
    expect(start, isNot(-1), reason: 'no match block for $collection');
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      if (text[i] == '{' && i > 0 && text[i - 1] == '/') {
        i = text.indexOf('}', i);
        continue;
      }
      if (text[i] == '{') depth++;
      if (text[i] == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return text.substring(start);
  }

  /// The first `keys().hasOnly([...])` in that block, which in every one of
  /// these is the whole-document whitelist.
  Set<String> keyWhitelist(String collection) {
    final body = block(collection);
    final match = RegExp(
      r'keys\(\)\s*\.hasOnly\(\s*\[([^\]]*)\]',
      dotAll: true,
    ).firstMatch(body);
    if (match == null) return const <String>{};
    return _quoted(match.group(1)!);
  }

  /// `onlyTouches([...])` on the `users/{uid}` update rule.
  Set<String> onlyTouchesForUsers() {
    final match = RegExp(
      r'onlyTouches\(\s*\[([^\]]*)\]',
      dotAll: true,
    ).firstMatch(text);
    return match == null ? const <String>{} : _quoted(match.group(1)!);
  }

  /// The closed list a check-in field is compared against.
  Set<String> valuesFor(String field) {
    final match = RegExp(
      'data\\.$field\\s+in \\[([^\\]]*)\\]',
      dotAll: true,
    ).firstMatch(text);
    return match == null ? const <String>{} : _quoted(match.group(1)!);
  }

  /// Every spelling of a consecutive-day counter the rules refuse.
  Set<String> runCounterNames() {
    final body = RegExp(
      r'function noRunCounter\(\)[^}]*hasAny\(\s*\[([^\]]*)\]',
      dotAll: true,
    ).firstMatch(text);
    return body == null ? const <String>{} : _quoted(body.group(1)!);
  }

  static Set<String> _quoted(String list) => RegExp("'([^']*)'")
      .allMatches(list)
      .map((m) => m.group(1)!)
      .toSet();
}

// ---------------------------------------------------------------- fixtures --

final MealItem _koshari = MealItem(
  itemId: 'item-1',
  foodId: 'koshari_bowl',
  servings: 1,
  size: 'M',
  loggedAt: DateTime(2026, 9, 1, 13, 5),
  source: MealSource.search,
  origin: MealOrigin.search,
  kcal: 540,
  proteinG: 18,
);

/// A woman who has been using the app: a session, a meal, a check-in, a period,
/// a measurement, her cycle and her setup answers.
Future<void> _fillEverything() async {
  await AppRouter.trainRepository.logRecalled(
    dateKey: _dayKey,
    method: RecallMethod.plan,
  );
  AppRouter.mealRepository.store.apply(
    MealWrite.transform(
      dayId: _dayKey,
      slot: MealSlot.lunch,
      tz: WeekKey.fallbackTimezone,
      libVersion: 1,
      added: [_koshari],
    ),
  );
  AppRouter.mealRepository.store.plans[WeekKey.of(DateTime(2026, 9, 1)).id] =
      const MealPlan(weekId: '2026-W36', dinners: {PlanDay.mon: 'molokhia'});
  CycleAppState.instance.saveCheckIn(
    const TodayCheckIn(energy: Energy.low, cramps: Cramps.mild),
  );
  await AppRouter.cycleRepository.completeSetup(
    mode: CycleMode.datesAndSymptoms,
    contextFlags: const {CycleContextFlag.irregular},
  );
  final draft = PeriodEntry.validate(
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 9, 5),
    today: DateTime.now(),
  );
  await AppRouter.periodRepository.save((draft as PeriodValid).entry);
  await AppRouter.measurementsRepository.save(
    Measurement(dayId: _dayKey, takenAt: DateTime(2026, 9, 1), weightKg: 61),
  );
  await AppRouter.todayRepository.markNoticeSeen(
    NoticeKind.quietWeek,
    WeekKey.of(DateTime(2026, 9, 1)),
  );
  await AppRouter.intakeRepository.merge(
    goal: TrainingGoal.loseSteadily,
    days: 4,
    minutes: 20,
    equipment: const {Equipment.dumbbells},
    lifeStage: LifeStage.postpartum,
  );
}

/// A live session she finished, put in through the repository's own restore
/// because the live path needs a running workout and this is a codec test.
void _giveHerAFinishedLiveSession() {
  AppRouter.trainRepository.restore(
    sessions: const [
      TrainSession(
        id: 'live-1',
        source: SessionSource.live,
        dateKey: _dayKey,
        sets: [
          LoggedSet(
            prescribed: PrescribedSet(exerciseId: 'goblet_squat', order: 1),
            outcome: SetOutcome(weightKg: 12, reps: 10),
          ),
        ],
        completed: true,
      ),
    ],
    sessionCounter: 1,
  );
}

/// A comparable fingerprint of everything of hers the merge can touch.
///
/// Compared as a whole rather than field by field, so a section that silently
/// stops surviving a merge fails with the name of the section.
Map<String, Object?> _whatSheHas() => <String, Object?>{
  'sessions': AppRouter.trainRepository.sessions.map((s) => s.id).toList()
    ..sort(),
  'meals': <String, Object?>{
    for (final entry in AppRouter.mealRepository.store.days.entries)
      entry.key: entry.value.allItems.map((i) => i.itemId).toList()..sort(),
  },
  'checkins': <String, Object?>{
    for (final entry in CycleAppState.instance.checkIns.entries)
      entry.key: entry.value.energy?.name,
  },
  'periods': AppRouter.cycleRepository.store.periods.keys.toList()..sort(),
  'measurements': <String, Object?>{
    for (final entry in AppRouter.progressStore.measurements.entries)
      entry.key: entry.value.weightKg,
  },
  'cycle': AppRouter.cycleRepository.store.cycle?.mode.name,
  'setupDone': AppRouter.intakeRepository.setupDone,
};

/// Lets the unawaited push futures resolve before the assertions read them.
Future<void> _settle() => Future<void>.delayed(Duration.zero);
