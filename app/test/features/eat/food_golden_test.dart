// F4: the golden table. food_golden.csv puts every food in the pack beside the
// USDA FoodData Central record it was checked against, written by
// tool/build_food_golden.py from records read live on the day in its `fetched`
// column. This test keeps the file honest: it covers the whole pack, it matches
// the pack as it is now, and each row's status is what its figures say.
//
//   record_matches  the food is one USDA record; the pack agrees with it to
//                   rounding (a transcription check, same source as the build)
//   verified        a USDA record of the same food the recipe does not use,
//                   within the plan's tolerance for a composite dish
//   unverified      nothing claimed: no source consulted, or the one analogue
//                   read fell outside the tolerance and is only named in the
//                   note

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/csv_parser.dart';

const _statuses = {'verified', 'record_matches', 'unverified'};

typedef _Row = Map<String, String>;

double _d(String text) => double.parse(text);

/// Energy within 25 percent; protein, carbohydrate and fat each within 20
/// percent or 3 g (the production plan's rule for a composite dish).
List<String> _misses(_Row row) {
  final out = <String>[];
  if ((_d(row['ours_kcal']!) - _d(row['ref_kcal']!)).abs() >
      0.25 * _d(row['ref_kcal']!)) {
    out.add('energy');
  }
  for (final key in const ['protein_g', 'carbs_g', 'fat_g']) {
    final ref = _d(row['ref_$key']!);
    if ((_d(row['ours_$key']!) - ref).abs() > max(0.2 * ref, 3)) out.add(key);
  }
  return out;
}

void main() {
  late List<_Row> rows;
  late List<Map<String, Object?>> pack;
  late Map<String, Object?> packFile;

  setUpAll(() {
    packFile = jsonDecode(
      File('assets/content/foods_eg.json').readAsStringSync(),
    ) as Map<String, Object?>;
    pack = [
      for (final f in packFile['foods']! as List)
        (f as Map).cast<String, Object?>(),
    ];
    final table = parseCsv(
      File('test/features/eat/food_golden.csv').readAsStringSync(),
    );
    rows = [
      for (final r in table.rows)
        {
          for (var i = 0; i < table.headers.length; i++)
            table.headers[i]: r.values[i],
        },
    ];
  });

  test('every food in the pack has one row, and no row is left over', () {
    expect(rows.map((r) => r['id']), pack.map((f) => f['id']));
  });

  test('the "ours" figures are the pack as it is now', () {
    for (var i = 0; i < pack.length; i++) {
      final per = (pack[i]['per100g']! as Map).cast<String, Object?>();
      final row = rows[i];
      final id = row['id'];
      expect(
        _d(row['ours_kcal']!),
        closeTo((per['kcal']! as num).toDouble(), 1e-6),
        reason: id,
      );
      expect(
        _d(row['ours_protein_g']!),
        closeTo((per['proteinG']! as num).toDouble(), 1e-6),
        reason: id,
      );
      expect(
        _d(row['ours_carbs_g']!),
        closeTo((per['carbsG']! as num).toDouble(), 1e-6),
        reason: id,
      );
      expect(
        _d(row['ours_fat_g']!),
        closeTo((per['fatG']! as num).toDouble(), 1e-6),
        reason: id,
      );
    }
  });

  test('every row names its source and carries a status from the fixed set; '
      'a row with no source consulted claims no figure', () {
    for (final r in rows) {
      expect(_statuses, contains(r['status']), reason: r['id']);
      expect(r['source'], isNotEmpty, reason: r['id']);
      final consulted = r['status'] != 'unverified';
      expect(
        r['source']!.startsWith('USDA FoodData Central'),
        consulted,
        reason: r['id'],
      );
      for (final key in const [
        'ref_kcal',
        'ref_protein_g',
        'ref_carbs_g',
        'ref_fat_g',
        'source_id',
        'fetched',
      ]) {
        expect(r[key]!.isNotEmpty, consulted, reason: '${r['id']} $key');
      }
      if (consulted) {
        expect(
          r['fetched'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
          reason: r['id'],
        );
        expect(int.tryParse(r['source_id']!), isNotNull, reason: r['id']);
      }
    }
  });

  test('at least 60 foods have a reference, and the count is not inflated '
      'by foods that merely stand in', () {
    final withReference = rows.where((r) => r['status'] != 'unverified');
    expect(withReference.length, greaterThanOrEqualTo(60));
    for (final r in rows.where(
      (r) => (r['note'] ?? '').startsWith('stand-in'),
    )) {
      expect(r['status'], 'unverified', reason: r['id']);
    }
  });

  test('a food that is one USDA record agrees with it to rounding', () {
    for (final r in rows.where((r) => r['status'] == 'record_matches')) {
      expect(
        (_d(r['ours_kcal']!) - _d(r['ref_kcal']!)).abs(),
        lessThanOrEqualTo(1),
        reason: '${r['id']} kcal',
      );
      for (final key in const ['protein_g', 'carbs_g', 'fat_g']) {
        expect(
          (_d(r['ours_$key']!) - _d(r['ref_$key']!)).abs(),
          lessThanOrEqualTo(0.11),
          reason: '${r['id']} $key',
        );
      }
    }
  });

  test('a verified row is inside the plan tolerance', () {
    final verified = rows.where((r) => r['status'] == 'verified').toList();
    expect(verified, isNotEmpty);
    for (final r in verified) {
      expect(_misses(r), isEmpty, reason: '${r['id']} is outside');
    }
  });

  test('the pack still says its figures are pending dietitian review', () {
    expect(packFile['review'], contains('pending dietitian review'));
  });
}
