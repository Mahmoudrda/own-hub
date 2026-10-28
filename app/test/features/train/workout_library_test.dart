import 'dart:io';
// The owner's workouts: the document format, the rules the member app holds
// it to, life-stage gating, the member reader, and the mapping onto Train's
// own types.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/data/workout_sync.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/features/train/presentation/authored_workout.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

AuthoredMove _move({
  String id = 'glute_bridge',
  int sets = 3,
  int? reps = 12,
  int? hold,
  List<String> tags = const ['none'],
}) => AuthoredMove(
  exerciseId: id,
  nameEn: 'Glute bridge',
  nameAr: 'jisr',
  sets: sets,
  reps: reps,
  holdSeconds: hold,
  restSeconds: 45,
  notesEn: 'Squeeze at the top.',
  notesAr: 'notes ar',
  safetyEn: 'Stop if your back hurts.',
  safetyAr: 'safety ar',
  contraindications: tags,
  quiet: true,
  floorOnly: true,
);

AuthoredSession _session({
  String id = 's1',
  Set<LifeStage> stages = const {LifeStage.none},
  List<AuthoredMove>? moves,
}) => AuthoredSession(
  sessionId: id,
  titleEn: 'Floor strength',
  titleAr: 'quwwa',
  minutes: 20,
  lifeStages: stages,
  moves: moves ?? [_move()],
);

AuthoredProgramme _programme({
  String id = 'quiet_start',
  ProgrammeStatus status = ProgrammeStatus.published,
  List<AuthoredSession>? sessions,
}) => AuthoredProgramme(
  programId: id,
  titleEn: 'Quiet start',
  titleAr: 'bidaya',
  status: status,
  version: 2,
  sessions: sessions ?? [_session()],
);

class _Memory implements SnapshotStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async => value = snapshot;

  @override
  Future<void> erase() async => value = null;
}

class _Source implements WorkoutRemoteSource {
  int? version;
  Map<String, Object?>? library;
  Object? offline;

  /// Thrown from the library read only, after the version read succeeded.
  Object? libraryFails;
  int versionReads = 0;
  int libraryReads = 0;

  @override
  Future<int?> readVersion() async {
    versionReads++;
    if (offline != null) throw offline!;
    return version;
  }

  @override
  Future<Map<String, Object?>?> readLibrary(int version) async {
    libraryReads++;
    if (libraryFails != null) throw libraryFails!;
    return library;
  }
}

void main() {
  group('the format', () {
    test('a programme round trips through its document exactly', () {
      final programme = _programme(
        sessions: [
          _session(
            moves: [
              _move(),
              _move(id: 'plank', reps: null, hold: 30),
            ],
          ),
          _session(id: 's2', stages: {LifeStage.pregnant, LifeStage.none}),
        ],
      );
      final again = AuthoredProgramme.fromJson(
        (jsonDecode(jsonEncode(programme.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(again, programme);
      expect(again.sessions[1].lifeStages, {
        LifeStage.pregnant,
        LifeStage.none,
      });
    });

    test('a library holds only published, valid programmes', () {
      final library = WorkoutLibrary.parse({
        'version': 3,
        'programmes': [_programme().toJson()],
      });
      expect(library.programmes.single.programId, 'quiet_start');
      expect(
        () => WorkoutLibrary.parse({
          'version': 3,
          'programmes': [_programme(status: ProgrammeStatus.draft).toJson()],
        }),
        throwsFormatException,
      );
    });
  });

  group('the rules, refused before anything is written', () {
    final refusals = <String, AuthoredProgramme>{
      'no sessions': _programme(sessions: const []),
      'a session with no moves': _programme(sessions: [_session(moves: [])]),
      'no life stage': _programme(sessions: [_session(stages: const {})]),
      'reps and a hold': _programme(
        sessions: [
          _session(moves: [_move(reps: 10, hold: 30)]),
        ],
      ),
      'neither reps nor a hold': _programme(
        sessions: [
          _session(moves: [_move(reps: null)]),
        ],
      ),
      'zero sets': _programme(
        sessions: [
          _session(moves: [_move(sets: 0)]),
        ],
      ),
      'too many reps': _programme(
        sessions: [
          _session(moves: [_move(reps: 500)]),
        ],
      ),
      'an untagged move': _programme(
        sessions: [
          _session(moves: [_move(tags: const [])]),
        ],
      ),
      'an unknown tag': _programme(
        sessions: [
          _session(
            moves: [
              _move(tags: const ['made_up']),
            ],
          ),
        ],
      ),
      'a pregnancy session with a supine loaded move': _programme(
        sessions: [
          _session(
            stages: {LifeStage.pregnant},
            moves: [
              _move(tags: const ['supine_load']),
            ],
          ),
        ],
      ),
      'an after-a-birth session with jumping': _programme(
        sessions: [
          _session(
            stages: {LifeStage.postpartum},
            moves: [
              _move(tags: const ['jumping']),
            ],
          ),
        ],
      ),
    };
    for (final MapEntry(key: label, value: programme) in refusals.entries) {
      test(label, () => expect(workoutProblems(programme), isNotEmpty));
    }

    test('a complete programme passes', () {
      expect(workoutProblems(_programme()), isEmpty);
    });

    test('a draft is held only to having an id', () {
      expect(
        workoutProblems(
          _programme(status: ProgrammeStatus.draft, sessions: const []),
        ),
        isEmpty,
      );
    });
  });

  group('life stage', () {
    final library = WorkoutLibrary(
      version: 1,
      programmes: [
        _programme(
          sessions: [
            _session(id: 'everyone'),
            _session(id: 'pregnancy', stages: {LifeStage.pregnant}),
            _session(
              id: 'after_birth',
              stages: {LifeStage.postpartum, LifeStage.none},
            ),
          ],
        ),
      ],
    );

    List<String> ids(LifeStage? stage) => [
      for (final e in library.sessionsFor(stage)) e.session.sessionId,
    ];

    test('pregnant: only sessions marked for pregnancy', () {
      expect(ids(LifeStage.pregnant), ['pregnancy']);
    });

    test('after a birth: only sessions marked for it', () {
      expect(ids(LifeStage.postpartum), ['after_birth']);
    });

    test('nothing to train around, or no answer: the general sessions', () {
      expect(ids(LifeStage.none), ['everyone', 'after_birth']);
      expect(ids(null), ['everyone', 'after_birth']);
    });
  });

  group('the member reader', () {
    _Source remote() => _Source()
      ..version = 4
      ..library = {
        'version': 4,
        'programmes': [_programme().toJson()],
      };

    test(
      'nothing reachable: an empty library, and day one is untouched',
      () async {
        final sync = WorkoutSync(
          source: () => null,
          cache: _Memory(),
          checks: _Memory(),
        );
        expect((await sync.refresh()).$1, WorkoutRefreshOutcome.unavailable);
        expect((await sync.load()).programmes, isEmpty);
      },
    );

    test('a newer version is fetched, cached and read back offline', () async {
      final cache = _Memory();
      final source = remote();
      final sync = WorkoutSync(
        source: () => source,
        cache: cache,
        checks: _Memory(),
        now: () => DateTime.utc(2026, 10, 7, 9),
      );
      final (outcome, library) = await sync.refresh();
      expect(outcome, WorkoutRefreshOutcome.updated);
      expect(library!.programmes.single.programId, 'quiet_start');

      final offline = WorkoutSync(
        source: () => null,
        cache: cache,
        checks: _Memory(),
      );
      expect((await offline.load()).version, 4);
    });

    test('a download that fails leaves no "checked" stamp, so the next launch '
        'asks again; a cached library stamps it', () async {
      final source = remote()..libraryFails = const SocketException('cut');
      final checks = _Memory();
      final cache = _Memory();
      final now = DateTime.utc(2026, 10, 7, 9);
      WorkoutSync make() => WorkoutSync(
        source: () => source,
        cache: cache,
        checks: checks,
        now: () => now,
      );
      expect((await make().refresh()).$1, WorkoutRefreshOutcome.failed);
      expect(checks.value, isNull);
      expect(cache.value, isNull);

      source.libraryFails = null;
      expect((await make().refresh()).$1, WorkoutRefreshOutcome.updated);
      expect(checks.value, isNotNull);
      expect(source.versionReads, 2);
    });

    test('a server read gives up after ten seconds', () {
      expect(FirestoreWorkoutSource.readTimeout, const Duration(seconds: 10));
    });

    test('the version is read at most once a day', () async {
      final source = remote();
      final checks = _Memory();
      var now = DateTime.utc(2026, 10, 7, 9);
      WorkoutSync make() => WorkoutSync(
        source: () => source,
        cache: _Memory(),
        checks: checks,
        now: () => now,
      );
      await make().refresh();
      now = now.add(const Duration(hours: 3));
      expect((await make().refresh()).$1, WorkoutRefreshOutcome.notDue);
      expect(source.versionReads, 1);
    });

    test(
      'one broken programme refuses the whole set, and the cache stays',
      () async {
        final cache = _Memory()
          ..value = jsonEncode(
            WorkoutLibrary(version: 2, programmes: [_programme()]).toJson(),
          );
        final source = remote()
          ..library = {
            'version': 4,
            'programmes': [
              _programme().toJson(),
              _programme(id: 'broken', sessions: const []).toJson(),
            ],
          };
        final sync = WorkoutSync(
          source: () => source,
          cache: cache,
          checks: _Memory(),
        );
        expect((await sync.refresh()).$1, WorkoutRefreshOutcome.rejected);
        expect((await sync.load()).version, 2);
      },
    );

    test('offline: failed, and the cache stands', () async {
      final source = remote()..offline = Exception('no signal');
      final sync = WorkoutSync(
        source: () => source,
        cache: _Memory(),
        checks: _Memory(),
      );
      expect((await sync.refresh()).$1, WorkoutRefreshOutcome.failed);
    });

    test('its keys are wiped with the rest of the phone', () {
      expect(kWorkoutCacheKeys, [kWorkoutCacheKey, kWorkoutCheckKey]);
    });
  });

  group('as Train already draws a workout', () {
    testWidgets('a session becomes a WorkoutDay with prescribed sets only', (
      tester,
    ) async {
      late AppL10n l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppL10n.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final programme = _programme(
        sessions: [
          _session(
            moves: [
              _move(),
              _move(id: 'plank', reps: null, hold: 30),
            ],
          ),
        ],
      );
      final day = workoutDayFrom(
        l10n,
        'en',
        programme,
        programme.sessions.single,
        now: DateTime(2026, 10, 7, 9),
      );
      expect(day.id, '2026-10-07', reason: 'a day key, never a library id');
      expect(day.title, 'Floor strength');
      expect(day.moves.first.prescriptionLabel, '3 × 12 · Rest 45 seconds');
      expect(
        day.moves.last.prescriptionLabel,
        '3 × 30 seconds · Rest 45 seconds',
      );
      expect(day.moves.first.restSeconds, 45, reason: 'R09 rests by the plan');
      expect(day.moves.first.sets, hasLength(3));
      expect(day.moves.first.sets.first.reps, 12);
      expect(day.moves.first.cues.first, 'Stop if your back hurts.');

      final arabic = workoutDayFrom(
        l10n,
        'ar',
        programme,
        programme.sessions.single,
        now: DateTime(2026, 10, 7),
      );
      expect(arabic.title, 'quwwa');
      expect(day.moves.first.name, 'Glute bridge');
      expect(arabic.moves.first.name, 'jisr', reason: 'her language');

      final row = libraryRowFrom(
        l10n,
        'en',
        programme,
        programme.sessions.single,
      );
      expect(row.id, 'library:quiet_start/s1');
      expect(row.quiet, isTrue);
    });

    testWidgets('pregnant, a session written for her keeps the doctor card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: const WorkoutDayView(
            lifeStage: LifeStage.pregnant,
            writtenForHerStage: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r03-doctor-first')), findsOneWidget);
      expect(
        find.textContaining('Written for pregnancy. Check with your doctor'),
        findsOneWidget,
      );
      expect(find.text("I have my doctor's OK, start"), findsOneWidget);
    });
  });
}
