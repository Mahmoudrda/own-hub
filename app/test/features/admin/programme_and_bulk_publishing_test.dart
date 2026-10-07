// The two remaining ways the owner adds content, end to end into what the
// member app reads:
//
//   * a programme saved from Z13 with its sessions reaches the workout
//     library, with each move's tags taken from the exercise library, and a
//     programme the member app would refuse writes nothing;
//   * a bulk import of recipe rows with a method column publishes them through
//     the same path as Z12, in one batch, and one bad row writes nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_documents.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/domain/remote_content_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';

late Map<String, Object?> _seed;

RemoteContentRepository _repo(InMemoryContentDocuments docs) =>
    RemoteContentRepository(
      documents: () => docs,
      seedRecipes: () async => _seed,
      rows: [
        ImportRow(
          collection: ContentCollection.exercises,
          id: 'glute_bridge',
          isUpdate: false,
          values: const {
            'exerciseId': 'glute_bridge',
            'name_en': 'Glute bridge',
            'name_ar': 'jisr',
            'equipment': 'mat',
            'contraindicationTags': 'supine_load',
            'quiet': 'true',
            'floorOnly': 'true',
          },
        ),
        ImportRow(
          collection: ContentCollection.exercises,
          id: 'side_lying_leg_lift',
          isUpdate: false,
          values: const {
            'exerciseId': 'side_lying_leg_lift',
            'name_en': 'Side-lying leg lift',
            'name_ar': 'raf3',
            'equipment': 'none',
            'contraindicationTags': 'none',
            'quiet': 'true',
            'floorOnly': 'true',
          },
        ),
      ],
    );

const Map<String, String> _programmeRow = {
  'programId': 'quiet_start',
  'name_en': 'Quiet start',
  'name_ar': 'bidaya',
  'weeks': '4',
  'daysPerWeek': '3',
  'sessionLength': '20',
  'quiet': 'true',
  'equipment': 'none',
};

AuthoredSession _session(
  String exerciseId, {
  Set<LifeStage> stages = const {LifeStage.none},
}) => AuthoredSession(
  sessionId: 's1',
  titleEn: 'Floor strength',
  titleAr: 'quwwa',
  minutes: 20,
  lifeStages: stages,
  moves: [
    AuthoredMove(
      exerciseId: exerciseId,
      nameEn: '',
      nameAr: '',
      sets: 3,
      reps: 12,
      restSeconds: 45,
    ),
  ],
);

void main() {
  setUpAll(() {
    _seed = (jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map).cast<String, Object?>();
  });

  group('a programme from Z13', () {
    test('reaches the workout library the member app reads', () async {
      final docs = InMemoryContentDocuments();
      await _repo(docs).saveToLibrary(
        collection: ContentCollection.programmes,
        values: _programmeRow,
        sessions: [_session('glute_bridge')],
        published: true,
      );
      expect(docs.docs['meta/workouts'], {'version': 1});
      expect(docs.commits, hasLength(1), reason: 'one batch');

      final library = WorkoutLibrary.parse(
        (jsonDecode(jsonEncode(docs.docs['workoutLibrary/v1'])) as Map)
            .cast<String, Object?>(),
      );
      final move = library.programmes.single.sessions.single.moves.single;
      // Names, flags and tags come from the exercise library.
      expect(move.nameEn, 'Glute bridge');
      expect(move.nameAr, 'jisr');
      expect(move.contraindications, ['supine_load']);
      expect(move.needsEquipment, isTrue);
      expect(docs.docs['programs/quiet_start']!['status'], 'published');
    });

    test('a pregnancy session with a supine loaded move is refused, '
        'and nothing is written', () async {
      final docs = InMemoryContentDocuments();
      await expectLater(
        _repo(docs).saveToLibrary(
          collection: ContentCollection.programmes,
          values: _programmeRow,
          sessions: [
            _session('glute_bridge', stages: {LifeStage.pregnant}),
          ],
          published: true,
        ),
        throwsA(isA<WorkoutNotReady>()),
      );
      expect(docs.docs, isEmpty);
    });

    test(
      'the same session with a safe move is accepted for pregnancy',
      () async {
        final docs = InMemoryContentDocuments();
        await _repo(docs).saveToLibrary(
          collection: ContentCollection.programmes,
          values: _programmeRow,
          sessions: [
            _session('side_lying_leg_lift', stages: {LifeStage.pregnant}),
          ],
          published: true,
        );
        expect(docs.docs.keys, contains('workoutLibrary/v1'));
      },
    );

    test('an exercise not in the library is refused', () async {
      final docs = InMemoryContentDocuments();
      await expectLater(
        _repo(docs).saveToLibrary(
          collection: ContentCollection.programmes,
          values: _programmeRow,
          sessions: [_session('made_up_move')],
          published: true,
        ),
        throwsA(isA<WorkoutNotReady>()),
      );
      expect(docs.docs, isEmpty);
    });

    test('back to draft takes it out of the member library', () async {
      final docs = InMemoryContentDocuments();
      final repo = _repo(docs);
      await repo.saveToLibrary(
        collection: ContentCollection.programmes,
        values: _programmeRow,
        sessions: [_session('glute_bridge')],
        published: true,
      );
      await repo.saveToLibrary(
        collection: ContentCollection.programmes,
        values: _programmeRow,
        sessions: [_session('glute_bridge')],
      );
      expect(docs.docs['meta/workouts'], {'version': 2});
      expect(docs.docs['workoutLibrary/v2']!['programmes'], isEmpty);
      expect(repo.isPublished('quiet_start'), isFalse);
      expect(repo.sessionsFor('quiet_start'), hasLength(1));
    });

    test('the console opens it again with its sessions', () async {
      final docs = InMemoryContentDocuments();
      await _repo(docs).saveToLibrary(
        collection: ContentCollection.programmes,
        values: _programmeRow,
        sessions: [_session('glute_bridge')],
        published: true,
      );
      final again = RemoteContentRepository(
        documents: () => docs,
        seedRecipes: () async => _seed,
      );
      await again.loadFromServer();
      expect(again.isPublished('quiet_start'), isTrue);
      expect(
        again.sessionsFor('quiet_start').single.moves.single.exerciseId,
        'glute_bridge',
      );
    });
  });

  group('recipes from a CSV', () {
    final header = ContentSchema.of(ContentCollection.recipes).columnNames;
    String row(Map<String, String> v) =>
        [for (final c in header) csvField(v[c] ?? '')].join(',');
    Map<String, String> recipe(String id, {String method = ''}) => {
      'recipeId': id,
      'name_en': 'Om Ali',
      'name_ar': 'om ali ar',
      'minutes': '45',
      'ingredients': 'pastry|milk',
      'allergens': 'dairy',
      'dietTags': 'vegetarian',
      'sectionId':
          ((_seed['sections']! as List).first as Map)['sectionId']! as String,
      'source': 'authored',
      'status': 'review',
      'authoredBy': 'content_team',
      'allergenReviewedBy': 'qa_reviewer',
      'macroBasis': 'withheld',
      'advisories': 'none',
      'tier': 'free',
      'method_ar': method,
      'method_en': 'Bake it.',
    };

    ImportPlan check(String csv) => validateImport(
      collection: ContentCollection.recipes,
      table: parseCsv(csv),
      uploadedMedia: const {},
      existingIds: const {},
    );

    test('a method cell may hold one step a line, quoted', () {
      final plan = check(
        '${header.join(',')}\n'
        '${row(recipe('om_ali', method: 'one\ntwo\nthree'))}\n',
      );
      expect(plan.problems, isEmpty);
      expect(plan.writes.single.value('method_ar'), 'one\ntwo\nthree');
    });

    test('a row for members with no method is refused at the check', () {
      final plan = check('${header.join(',')}\n${row(recipe('om_ali'))}\n');
      expect(plan.problems.single.column, 'method_ar');
      expect(plan.problems.single.code, ImportProblemCode.blankRequired);
    });

    test('an older file without the method columns still imports drafts', () {
      final old = [
        for (final c in header)
          if (!c.startsWith('method_')) c,
      ];
      final values = {...recipe('om_ali'), 'status': 'draft'};
      final plan = check(
        '${old.join(',')}\n'
        '${[for (final c in old) csvField(values[c] ?? '')].join(',')}\n',
      );
      expect(plan.problems, isEmpty);
    });

    test(
      'imported rows are published in one batch, steps split on | too',
      () async {
        final docs = InMemoryContentDocuments();
        final plan = check(
          '${header.join(',')}\n'
          '${row(recipe('om_ali', method: 'one\ntwo'))}\n'
          '${row(recipe('basbousa', method: 'mix | bake | cool'))}\n',
        );
        await _repo(docs).saveAll(plan.writes);
        expect(docs.commits, hasLength(1));
        final seedVersion = (_seed['contentVersion']! as num).toInt();
        final index = docs.docs['recipeIndex/en_v${seedVersion + 1}']!;
        expect(
          {for (final r in index['rows']! as List) (r as Map)['recipeId']},
          {'om_ali', 'basbousa'},
        );
        final steps = docs.docs['recipes/basbousa']!['steps']! as List;
        expect(
          [for (final s in steps) (s as Map)['textAr']],
          ['mix', 'bake', 'cool'],
        );
        expect(docs.docs['recipes/basbousa']!['stepsEn'], ['Bake it.']);
      },
    );

    test('one row the member app would refuse writes nothing at all', () async {
      final docs = InMemoryContentDocuments();
      final good = ImportRow(
        collection: ContentCollection.recipes,
        id: 'om_ali',
        isUpdate: false,
        values: recipe('om_ali', method: 'one'),
      );
      final bad = ImportRow(
        collection: ContentCollection.recipes,
        id: 'bad',
        isUpdate: false,
        values: {
          ...recipe('bad', method: 'one'),
          'allergenReviewedBy': 'content_team',
        },
      );
      await expectLater(
        _repo(docs).saveAll([good, bad]),
        throwsA(isA<RecipeNotReady>()),
      );
      expect(docs.docs, isEmpty);
    });
  });
}
