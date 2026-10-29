// The automated recipe check, run against fixtures it can fail.
//
// `tool/verify_recipes.py` decides which recipes may ship `published` without a
// person's signature, so what matters most is what it refuses: every case below
// builds a small food pack and a recipe, breaks one thing, and expects the
// recipe to stay in `review` with no record. The last group runs it on the
// shipped seed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One food of the fixture pack, per 100 g.
Map<String, Object?> _food(
  String id, {
  required List<String>? allergens,
  String? nameEn,
  double kcal = 100,
  double protein = 10,
  double carbs = 10,
  double fat = 5,
}) => {
  'id': id,
  'nameEn': nameEn ?? id,
  'nameAr': id,
  'per100g': {
    'kcal': kcal,
    'proteinG': protein,
    'carbsG': carbs,
    'fatG': fat,
    'fiberG': 1,
  },
  'allergens': ?allergens,
};

Map<String, Object?> _row(
  String foodId,
  int grams,
  String text, {
  bool optional = false,
}) => {
  'ingredientRef': '${foodId}_ref',
  'foodId': foodId,
  'qtyTextEn': text,
  'qtyTextAr': 'xx',
  'grams': grams,
  'gramsBasis': 'stated',
  'optional': optional,
  'servingSideOnly': false,
};

/// A recipe whose figures are exactly the sum of its rows over [pack].
Map<String, Object?> _recipe(
  String id,
  List<Map<String, Object?>> rows,
  List<Map<String, Object?>> pack, {
  int steps = 2,
  List<String> allergens = const [],
  List<String> diet = const [],
  String status = 'review',
  String? reviewedBy,
  int serves = 1,
}) {
  var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
  for (final row in rows) {
    final food = pack.where((f) => f['id'] == row['foodId']).firstOrNull;
    // A row the pack cannot resolve adds nothing; the check refuses it anyway.
    if (food == null) continue;
    final per = food['per100g']! as Map;
    final g = (row['grams']! as int) / 100;
    kcal += (per['kcal']! as num) * g;
    protein += (per['proteinG']! as num) * g;
    carbs += (per['carbsG']! as num) * g;
    fat += (per['fatG']! as num) * g;
  }
  int one(double v) => (v / serves).round();
  return {
    'recipeId': id,
    'source': 'authored',
    'status': status,
    'titleEn': id,
    'ingredients': rows,
    'steps': [
      for (var i = 1; i <= steps; i++)
        {'index': i, 'textAr': 'خطوة $i', 'textEn': 'Step $i'},
    ],
    'components': <Object?>[],
    'serves': serves,
    'kcal': one(kcal),
    'proteinG': one(protein),
    'carbsG': one(carbs),
    'fatG': one(fat),
    'macroBasis': 'computed',
    'allergensDerived': allergens,
    'allergensExtra': <String>[],
    'allergensRemoved': <String, Object?>{},
    'allergensFinal': allergens,
    'dietTags': diet,
    'authoredBy': 'ownhub_kitchen',
    'allergenReviewedBy': reviewedBy,
    'cookedBy': null,
  };
}

class _Run {
  _Run(this.exitCode, this.stdout, this.stderr, this.recipes);
  final int exitCode;
  final String stdout;
  final String stderr;
  final Map<String, Map<String, Object?>> recipes;
  Map<String, Object?> operator [](String id) => recipes[id]!;
}

late Directory _dir;
var _n = 0;

_Run _verify(
  List<Map<String, Object?>> pack,
  List<Map<String, Object?>> recipes, {
  List<String> extraArgs = const [],
  String? seedFile,
}) {
  final foods = File('${_dir.path}/foods_${_n}_.json')
    ..writeAsStringSync(jsonEncode({'foods': pack}));
  final seed = File(seedFile ?? '${_dir.path}/seed_${_n++}.json');
  if (seedFile == null) {
    seed.writeAsStringSync(jsonEncode({'recipes': recipes, 'assemblies': []}));
  }
  final run = Process.runSync('python3', [
    '-I',
    'tool/verify_recipes.py',
    '--seed',
    seed.path,
    '--foods',
    foods.path,
    '--now',
    '2026-10-21T00:00:00Z',
    ...extraArgs,
  ]);
  final out = (jsonDecode(seed.readAsStringSync()) as Map)['recipes'] as List;
  return _Run(run.exitCode, '${run.stdout}', '${run.stderr}', {
    for (final r in out)
      (r as Map)['recipeId']! as String: r.cast<String, Object?>(),
  });
}

void _expectHeld(_Run run, String id, {String? because}) {
  expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
  expect(run[id]['status'], 'review', reason: run.stdout);
  expect(run[id].containsKey('verification'), isFalse, reason: run.stdout);
  if (because != null) expect(run.stdout, contains(because));
}

void main() {
  setUpAll(() {
    _dir = Directory.systemTemp.createTempSync('verify_recipes');
  });
  tearDownAll(() => _dir.deleteSync(recursive: true));

  final pack = [
    _food('chicken_breast_raw', allergens: const []),
    _food('rice', allergens: const []),
    _food('yoghurt', allergens: const ['milk'], nameEn: 'Greek yoghurt'),
    _food('lemon_juice', allergens: const []),
    _food('olive_oil', allergens: const []),
    _food('plain_paste', allergens: const [], nameEn: 'Paste'),
    _food('peanut_spread', allergens: const ['peanuts']),
    _food('aubergine', allergens: const [], nameEn: 'Eggplant'),
    _food('tomato', allergens: const []),
  ];

  group('a recipe that passes', () {
    test('is published with a record, and no person is named', () {
      final recipe = _recipe(
        'good',
        [
          _row('chicken_breast_raw', 150, '150 g chicken breast'),
          _row('rice', 150, '150 g rice'),
          _row('yoghurt', 50, '50 g Greek yoghurt'),
        ],
        pack,
        allergens: const ['milk'],
        diet: const ['high_protein'],
      );
      final run = _verify(pack, [recipe]);

      expect(run.exitCode, 0, reason: run.stdout + run.stderr);
      expect(run['good']['status'], 'published');
      final record = run['good']['verification']! as Map;
      expect(record['method'], 'ownhub-auto-check-v1');
      expect(record['checkedAt'], '2026-10-21T00:00:00Z');
      expect(record['macroDeltaPct'], 0.0);
      expect(record['allergensDerived'], ['milk']);
      // The script is not a person.
      expect(run['good']['allergenReviewedBy'], isNull);
      expect(run['good']['cookedBy'], isNull);
      expect(run.stdout, contains('PASS'));
    });

    test('is left alone the second time, date and all', () {
      final recipe = _recipe('good', [_row('rice', 150, '150 g rice')], pack);
      final first = _verify(pack, [recipe]);
      final seed = File('${_dir.path}/again.json')
        ..writeAsStringSync(
          jsonEncode({'recipes': first.recipes.values.toList()}),
        );
      final before = seed.readAsStringSync();
      final foods = File('${_dir.path}/foods_again.json')
        ..writeAsStringSync(jsonEncode({'foods': pack}));
      final run = Process.runSync('python3', [
        '-I',
        'tool/verify_recipes.py',
        '--seed',
        seed.path,
        '--foods',
        foods.path,
        '--now',
        '2027-01-01T00:00:00Z',
      ]);
      expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
      expect(
        (jsonDecode(seed.readAsStringSync()) as Map)['recipes'],
        (jsonDecode(before) as Map)['recipes'],
        reason: 'nothing changed, so nothing is rewritten',
      );
    });

    test('words that only look like an allergen do not fire it', () {
      // "peanut butter" is a peanut and not a butter; "eggplant" is not an egg.
      final recipe = _recipe(
        'look_alikes',
        [
          _row('peanut_spread', 20, '20 g peanut butter'),
          _row('aubergine', 100, '100 g eggplant, sliced'),
        ],
        pack,
        allergens: const ['peanuts'],
      );
      final run = _verify(pack, [recipe]);
      expect(run['look_alikes']['status'], 'published', reason: run.stdout);
    });
  });

  group('only Own Hub recipes are published on the check alone', () {
    Map<String, Object?> make(String id, String source, {String? reviewedBy}) =>
        _recipe(
          id,
          [_row('rice', 150, '150 g rice')],
          pack,
          reviewedBy: reviewedBy,
        )..['source'] = source;

    test('an unsigned book card that passes waits in review', () {
      final run = _verify(pack, [make('card', 'book')]);
      _expectHeld(run, 'card');
      expect(run.stdout, contains('PASS'));
    });

    test('an unsigned book card that was published is taken back', () {
      final card = make('card', 'book')
        ..['status'] = 'published'
        ..['verification'] = {'method': 'ownhub-auto-check-v1'};
      _expectHeld(_verify(pack, [card]), 'card');
    });

    test('a signed book card keeps its signature and status', () {
      final run = _verify(pack, [
        make('card', 'book', reviewedBy: 'a_person')..['status'] = 'published',
      ]);
      expect(run['card']['status'], 'published');
      expect(run['card']['allergenReviewedBy'], 'a_person');
    });

    test('an assembly is not published either', () {
      _expectHeld(_verify(pack, [make('mix', 'assembly')]), 'mix');
    });

    test('an authored recipe still is', () {
      final run = _verify(pack, [make('own', 'authored')]);
      expect(run['own']['status'], 'published', reason: run.stdout);
      expect(run['own']['verification'], isNotNull);
    });
  });

  group('fail closed: the recipe stays in review, with no record', () {
    test('an ingredient with no food', () {
      final recipe = _recipe('r', [
        _row('rice', 100, '100 g rice'),
        _row('rice', 50, '50 g rice')..['foodId'] = null,
      ], pack);
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'no foodId');
    });

    test('an ingredient whose food is not in the pack', () {
      final recipe = _recipe('r', [
        _row('rice', 100, '100 g rice'),
        _row('rice', 50, '50 g mystery')..['foodId'] = 'mystery',
      ], pack);
      _expectHeld(
        _verify(pack, [recipe]),
        'r',
        because: 'not in the food pack',
      );
    });

    test('an ingredient with no weight', () {
      final recipe = _recipe('r', [_row('rice', 100, '100 g rice')], pack);
      (recipe['ingredients']! as List).add({
        ..._row('tomato', 80, 'a tomato'),
        'grams': null,
      });
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'no weight');
    });

    test('a food that has no allergen list at all', () {
      final holed = [...pack, _food('mystery_flour', allergens: null)];
      final recipe = _recipe('r', [
        _row('rice', 100, '100 g rice'),
        _row('mystery_flour', 30, '30 g of something'),
      ], holed);
      _expectHeld(
        _verify(holed, [recipe]),
        'r',
        because: 'the food has no allergen list',
      );
    });

    test('a keyword the foods do not carry: tahini in a plain paste', () {
      // The shape of the falafel gap: the food row says nothing, the words do.
      final recipe = _recipe('r', [
        _row('plain_paste', 20, '1 tablespoon tahini'),
      ], pack);
      final run = _verify(pack, [recipe]);
      _expectHeld(run, 'r', because: 'keyword scan found sesame');
    });

    test('the same in Egyptian Arabic', () {
      final recipe = _recipe('r', [
        {..._row('plain_paste', 20, 'a paste'), 'qtyTextAr': 'معلقة طحينة'},
      ], pack);
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'sesame');
    });

    test('a keyword in the method, not the ingredient list', () {
      final recipe = _recipe('r', [_row('rice', 100, '100 g rice')], pack);
      (recipe['steps']! as List)[0] = {
        'index': 1,
        'textAr': 'خطوة',
        'textEn': 'Stir in a spoon of mustard.',
      };
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'mustard');
    });

    group('the words the first list missed', () {
      const cases = <String, List<String>>{
        'shellfish': ['crustaceans', 'molluscs'],
        'seafood': ['fish', 'crustaceans', 'molluscs'],
        'labna': ['milk'],
        'bechamel': ['milk', 'gluten'],
        'vermicelli': ['gluten'],
        'pastry': ['gluten', 'milk'],
        'filo': ['gluten'],
        'croissant': ['gluten', 'milk', 'eggs'],
        'worcestershire': ['fish', 'sulphites'],
        'nutella': ['tree_nuts', 'milk', 'soy'],
      };
      for (final entry in cases.entries) {
        test('${entry.key} is held until its allergens are recorded', () {
          Map<String, Object?> make(List<String> recorded) => _recipe(
            'r',
            [_row('plain_paste', 40, '40 g ${entry.key}')],
            pack,
            allergens: recorded,
          );
          final held = _verify(pack, [make(const [])]);
          expect(held.exitCode, 0, reason: held.stdout);
          expect(held['r']['status'], 'review', reason: held.stdout);
          expect(held['r'].containsKey('verification'), isFalse);
          for (final tag in entry.value) {
            expect(
              held.stdout,
              contains('keyword scan found $tag'),
              reason: '${entry.key} should fire $tag\n${held.stdout}',
            );
          }
          // With every tag recorded the same recipe passes, so the word is
          // the only thing that held it.
          final ok = _verify(pack, [make(entry.value)]);
          expect(ok['r']['status'], 'published', reason: ok.stdout);
        });
      }

      test('shellfish is not read as plain fish only', () {
        final recipe = _recipe(
          'r',
          [_row('plain_paste', 40, '40 g shellfish')],
          pack,
          allergens: const ['fish'],
        );
        _expectHeld(_verify(pack, [recipe]), 'r', because: 'crustaceans');
      });

      test('a word in the title alone holds the recipe', () {
        final english = _recipe('en', [_row('rice', 100, '100 g rice')], pack)
          ..['titleEn'] = 'Seafood rice';
        final arabic = _recipe('ar', [_row('rice', 100, '100 g rice')], pack)
          ..['titleAr'] = 'سلطة بالطحينة';
        final run = _verify(pack, [english, arabic]);
        expect(run['en']['status'], 'review', reason: run.stdout);
        expect(run['ar']['status'], 'review', reason: run.stdout);
        expect(run.stdout, contains('crustaceans'));
        expect(run.stdout, contains('sesame'));
      });
    });

    test('a keyword only in the second method (a variant) still counts', () {
      final recipe = _recipe('r', [_row('rice', 100, '100 g rice')], pack);
      recipe['variants'] = [
        {
          'variantId': 'second',
          'labelAr': 'الطريقة التانية',
          'ingredients': <Object?>[],
          'steps': [
            {'index': 1, 'textAr': 'ضيفي', 'textEn': 'Fold in the tahini.'},
          ],
        },
      ];
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'sesame');
    });

    test('a keyword only in the printed card text still counts', () {
      final recipe = _recipe('r', [_row('rice', 100, '100 g rice')], pack);
      recipe['bodyAr'] = 'رشي سمسم على الوش';
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'sesame');
    });

    test('ingredients hidden in a component are not half checked', () {
      final recipe = _recipe('r', [_row('rice', 100, '100 g rice')], pack);
      recipe['components'] = [
        {
          'componentId': 'sauce',
          'headingAr': 'الصوص',
          'ingredients': [_row('yoghurt', 30, '30 g yoghurt')],
          'steps': <Object?>[],
        },
      ];
      _expectHeld(
        _verify(pack, [recipe]),
        'r',
        because: 'ingredients of its own',
      );
    });

    test('the foods carry an allergen the recorded list leaves out', () {
      final recipe = _recipe('r', [
        _row('yoghurt', 100, '100 g something'),
      ], pack);
      _expectHeld(
        _verify(pack, [recipe]),
        'r',
        because: 'milk is in the foods used',
      );
    });

    test(
      'an allergen removed with a reason is a person\'s job, not the script\'s',
      () {
        final recipe = _recipe('r', [
          _row('yoghurt', 100, '100 g Greek yoghurt'),
        ], pack);
        recipe['allergensRemoved'] = {'milk': 'lactose free'};
        _expectHeld(_verify(pack, [recipe]), 'r', because: 'only a person');
      },
    );

    test('figures that disagree with the grams', () {
      final recipe = _recipe('r', [
        _row('chicken_breast_raw', 150, '150 g chicken'),
      ], pack);
      recipe['kcal'] = (recipe['kcal']! as int) + 40;
      final run = _verify(pack, [recipe]);
      _expectHeld(run, 'r', because: 'kcal: stated');
    });

    test('figures rounded to a whole number still pass', () {
      // The stated figure is rounded; half a gram either way is not a fault.
      final recipe = _recipe('r', [_row('tomato', 33, '33 g tomato')], pack);
      final run = _verify(pack, [recipe]);
      expect(run['r']['status'], 'published', reason: run.stdout);
    });

    test('a single step is not a method', () {
      final recipe = _recipe(
        'r',
        [_row('rice', 100, '100 g rice')],
        pack,
        steps: 1,
      );
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'fewer than 2 steps');
    });

    test('vegetarian with chicken in it', () {
      final recipe = _recipe(
        'r',
        [_row('chicken_breast_raw', 100, '100 g chicken')],
        pack,
        diet: const ['vegetarian'],
      );
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'tagged vegetarian');
    });

    test('no nuts, gluten free or vegan over an allergen of that kind', () {
      final recipe = _recipe(
        'r',
        [
          _row('peanut_spread', 20, '20 g peanut butter'),
          _row('yoghurt', 50, '50 g Greek yoghurt'),
        ],
        pack,
        allergens: const ['milk', 'peanuts'],
        diet: const ['no_nuts', 'vegan'],
      );
      final run = _verify(pack, [recipe]);
      _expectHeld(run, 'r', because: 'tagged no nuts');
      expect(run.stdout, contains('tagged vegan'));
    });

    test('an allergen token the app does not know', () {
      final recipe = _recipe(
        'r',
        [_row('rice', 100, '100 g rice')],
        pack,
        allergens: const ['unobtainium'],
      );
      _expectHeld(_verify(pack, [recipe]), 'r', because: 'does not know');
    });
  });

  group('what the check does to the status', () {
    test('a recipe it published before and can no longer verify goes back', () {
      final recipe = _recipe(
        'r',
        [_row('rice', 100, '100 g rice')],
        pack,
        status: 'published',
      );
      recipe['verification'] = {
        'method': 'ownhub-auto-check-v1',
        'checkedAt': '2026-10-01T00:00:00Z',
        'macroDeltaPct': 0.0,
        'allergensDerived': <String>[],
      };
      recipe['kcal'] = 9999;
      _expectHeld(_verify(pack, [recipe]), 'r');
    });

    test('a signed recipe keeps its signature and status, and is flagged', () {
      final recipe = _recipe(
        'signed',
        [_row('rice', 100, '100 g rice')],
        pack,
        status: 'published',
        reviewedBy: 'rahma_mohsen',
        steps: 1,
      );
      final run = _verify(pack, [recipe]);
      expect(run['signed']['status'], 'published');
      expect(run['signed']['allergenReviewedBy'], 'rahma_mohsen');
      expect(run['signed'].containsKey('verification'), isFalse);
      expect(run.stdout, contains('but read these'));
    });

    test('a draft is not the script\'s to publish', () {
      final recipe = _recipe(
        'd',
        [_row('rice', 100, '100 g rice')],
        pack,
        status: 'draft',
      );
      final run = _verify(pack, [recipe]);
      expect(run['d']['status'], 'draft');
      expect(run['d'].containsKey('verification'), isFalse);
    });

    test('one failing recipe does not hold up the others', () {
      final good = _recipe('good', [_row('rice', 100, '100 g rice')], pack);
      final bad = _recipe(
        'bad',
        [_row('rice', 100, '100 g rice')],
        pack,
        steps: 0,
      );
      final run = _verify(pack, [good, bad]);
      expect(run['good']['status'], 'published');
      expect(run['bad']['status'], 'review');
      expect(run.stdout, contains('1 verified, 1 held in review'));
    });

    test('--check changes nothing and says the file is stale', () {
      final recipe = _recipe('r', [_row('rice', 100, '100 g rice')], pack);
      final seed = File('${_dir.path}/check.json')
        ..writeAsStringSync(
          jsonEncode({
            'recipes': [recipe],
          }),
        );
      final before = seed.readAsStringSync();
      final run = _verify(
        pack,
        const [],
        seedFile: seed.path,
        extraArgs: const ['--check'],
      );
      expect(run.exitCode, 1);
      expect(seed.readAsStringSync(), before);
    });
  });

  group('the shipped seed', () {
    test('is exactly what the check would write', () {
      final run = Process.runSync('python3', [
        '-I',
        'tool/verify_recipes.py',
        '--check',
      ]);
      expect(
        run.exitCode,
        0,
        reason:
            'the seed is out of step with the check. Rebuild it with '
            '`python3 tool/build_rahma_recipes.py`.\n${run.stdout}${run.stderr}',
      );
    });

    test('verifies the eleven signed-off-by-check recipes and holds the twenty', () {
      final seed = jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final ours = (seed['recipes'] as List).cast<Map<String, Object?>>().where(
        (r) => (r['recipeId'] as String).startsWith('ownhub_'),
      );
      expect(ours, hasLength(31));
      for (final r in ours) {
        if (r['status'] == 'review') {
          expect(r.containsKey('verification'), isFalse, reason: '${r['recipeId']}');
          continue;
        }
        expect(r['status'], 'published', reason: '${r['recipeId']}');
        expect((r['verification'] as Map)['method'], 'ownhub-auto-check-v1');
        expect(r['allergenReviewedBy'], isNull);
        expect(r['cookedBy'], isNull);
      }
    });
  });
}
