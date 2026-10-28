// F1: the sentence parser against the real 252-food pack, in English and in
// Arabic, typed and spoken. One row per phrase: what she says, the rows it must
// become (food:size x servings) and the words that must stay a chip.
//
// The rule behind every row: an unresolved chip is acceptable, a wrong log is
// not. So a word that fits many foods ("rice", "chicken", "juice") or a food the
// pack holds only raw is a chip, never the first thing that matched.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';

typedef _Row = ({
  String says,
  List<String> rows,
  List<String> chips,
  int? kcal,
});

_Row _r(
  String says, {
  List<String> rows = const [],
  List<String> chips = const [],
  int? kcal,
}) => (says: says, rows: rows, chips: chips, kcal: kcal);

final List<_Row> _corpus = [
  // Counts: two eggs are two eggs, four are four, never eight.
  _r('2 eggs', rows: ['boiled_eggs:2x1'], kcal: 156),
  _r('4 eggs', rows: ['boiled_eggs:1x4'], kcal: 312),
  _r('6 eggs', rows: ['boiled_eggs:1x6'], kcal: 468),
  _r(
    'two eggs and a piece of bread',
    rows: ['boiled_eggs:2x1'],
    chips: ['a piece of bread'],
  ),
  _r('three dates', rows: ['dates:Mx1'], kcal: 59),
  _r('a banana and an apple', rows: ['banana:Mx1', 'apple:Mx1'], kcal: 199),
  _r('one orange', rows: ['orange:Mx1']),
  _r('koshari', rows: ['koshari_bowl:Mx1'], kcal: 540),
  _r('a koshari', rows: ['koshari_bowl:Mx1']),
  _r('koshary and a salad', rows: ['koshari_bowl:Mx1'], chips: ['a salad']),
  _r('grilled chicken with rice', rows: ['frakh_mashwi:Mx1'], chips: ['rice']),
  // "Ful and taameya" is a dish the pack names, so it is one row.
  _r(
    'ful and taameya and eggs',
    rows: ['ful_taameya_breakfast:Mx1', 'boiled_eggs:2x1'],
  ),
  _r('I had cereal and stuff', chips: ['cereal', 'stuff']),
  // Half, and the weight of what she said.
  _r(
    'half a chicken breast',
    rows: ['chicken_breast_grilled:g86x1'],
    kcal: 142,
  ),
  _r('a cup of milk', rows: ['milk_full:g240x1'], kcal: 146),
  _r('a glass of juice', chips: ['a glass of juice']),
  _r(
    'tea with sugar and milk',
    rows: ['milk_full:Mx1'],
    chips: ['tea', 'sugar'],
  ),
  // Grams route needs a food she named in full; "rice" fits many.
  _r('200 g rice', chips: ['200 g rice']),
  _r('200 grams of rice', chips: ['200 grams of rice']),
  _r('200 g boiled potato', rows: ['potato_boiled:g200x1'], kcal: 172),
  _r('250 g white rice', rows: ['roz_abyad:g250x1']),
  // Raw and cooked: the bare word is the cooked food, or nothing.
  _r('potato', rows: ['potato_boiled:Mx1'], kcal: 146),
  _r('ads', rows: ['lentils_cooked:Mx1'], kcal: 115),
  _r('lentils', rows: ['lentils_cooked:Mx1'], kcal: 115),
  _r('raw potato', rows: ['potato_raw:Mx1']),
  _r('dry lentils', rows: ['lentils_dry:Mx1']),
  _r('chicken', chips: ['chicken']),
  // Egyptian words and numbers.
  _r('بيضتين وعيش', rows: ['boiled_eggs:2x1', 'aish_baladi:Mx1']),
  _r('اتنين بيض', rows: ['boiled_eggs:2x1']),
  _r('تلات بيضات', rows: ['boiled_eggs:3x1'], kcal: 234),
  _r('أربع بيضات', rows: ['boiled_eggs:1x4'], kcal: 312),
  _r('خمس حبات', chips: ['خمس حبات']),
  _r('نص رغيف عيش', rows: ['aish_baladi:g45x1'], kcal: 118),
  _r('ربع كيلو لحمة', chips: ['ربع كيلو لحمة']),
  _r('طبق كشري', rows: ['koshari_bowl:Mx1']),
  _r('كشري كبير', rows: ['koshari_bowl:Lx1'], kcal: 700),
  _r('كشري صغير', rows: ['koshari_bowl:Sx1'], kcal: 380),
  _r(
    'فول وطعمية وسلطة',
    rows: ['ful_baladi:Mx1', 'taameya:Mx1'],
    chips: ['سلطة'],
  ),
  _r('فول بالزيت', rows: ['ful_bel_zeit:Mx1']),
  _r('ساندوتش فول', rows: ['ful_sandwich:Mx1']),
  _r('ملوخية بالفراخ', rows: ['molokhia_chicken:Mx1']),
  _r('ملوخية مع أرز', rows: ['molokhia:Mx1'], chips: ['أرز']),
  _r('رز وفراخ مشوية', rows: ['frakh_mashwi:Mx1'], chips: ['رز']),
  _r('كوباية شاي بلبن', rows: ['shai_bel_laban:g240x1']),
  _r('كوباية عصير مانجو', rows: ['mango_juice:g240x1']),
  _r('كوب لبن', rows: ['milk_full:g240x1'], kcal: 146),
  _r('٣ بيضات', rows: ['boiled_eggs:3x1']),
  _r('٢ عيش', rows: ['aish_baladi:Mx2'], kcal: 472),
  _r('3 بيضات', rows: ['boiled_eggs:3x1']),
  _r('ثلاثة عيش', rows: ['aish_baladi:Mx3'], kcal: 708),
  _r('٢,٥ عيش', rows: ['aish_baladi:g225x1']),
  _r('كُشَرِي', rows: ['koshari_bowl:Mx1']),
  _r('فُول', rows: ['ful_baladi:Mx1']),
  _r('كشرى', rows: ['koshari_bowl:Mx1']),
  _r('أرز', chips: ['أرز']),
  _r('ارز', chips: ['ارز']),
  _r('رز', chips: ['رز']),
  _r('عيش بلدي', rows: ['aish_baladi:Mx1']),
  _r('عيش فينو', rows: ['aish_fino:Mx1']),
  _r('جبنة رومي', rows: ['gebna_rumi:Mx1']),
  _r('لبنة', rows: ['labneh:Mx1']),
  _r('حواوشي', rows: ['hawawshi:Mx1']),
  _r('كفتة', rows: ['kofta:Mx1']),
  _r('ممبار', rows: ['mombar:Mx1']),
  _r('فتة', rows: ['fattah:Mx1']),
  _r('محشي كرنب', rows: ['mahshi_cabbage:Mx1']),
  _r('بطاطس محمرة', rows: ['batates_maqlia:Mx1']),
  _r('بطاطس مسلوقة', rows: ['potato_boiled:Mx1']),
  _r('بطاطس', rows: ['potato_boiled:Mx1']),
  _r('جبنة', chips: ['جبنة']),
  _r('عصير', chips: ['عصير']),
  _r('عدس', rows: ['lentils_cooked:Mx1'], kcal: 115),
  // The waw, attached and spaced.
  _r('وعيش', rows: ['aish_baladi:Mx1']),
  _r('و عيش', rows: ['aish_baladi:Mx1']),
  _r('فول وعيش', rows: ['ful_baladi:Mx1', 'aish_baladi:Mx1']),
  _r('2 eggs و عيش', rows: ['boiled_eggs:2x1', 'aish_baladi:Mx1']),
  // Franco.
  _r('2 beid w 3eesh', rows: ['boiled_eggs:2x1'], chips: ['3eesh']),
  _r('koshari w roz', rows: ['koshari_bowl:Mx1'], chips: ['roz']),
  // Meal words are not foods.
  _r('فطار: فول', rows: ['ful_baladi:Mx1']),
  _r('breakfast: eggs', rows: ['boiled_eggs:2x1']),
  // Nothing to log.
  _r(''),
  _r('   '),
  _r('.'),
  _r('mmm'),
  _r('اه'),
  _r('أه كده'),
  _r('uh, um'),
  // Not in the pack: a chip, never a near neighbour.
  _r('sushi', chips: ['sushi']),
  _r('pad thai', chips: ['pad thai']),
  _r('سوشي', chips: ['سوشي']),
  // Numbers that cannot be a meal.
  _r('999 eggs', chips: ['999 eggs']),
  _r('١٠٠٠٠ عيش', chips: ['١٠٠٠٠ عيش']),
  _r('1e9 rice', chips: ['1e9 rice']),
  _r('-3 eggs', chips: ['-3 eggs']),
  _r('0 eggs', chips: ['0 eggs']),
  _r('2.5 eggs', chips: ['2.5 eggs']),
  _r('3', chips: ['3']),
  _r('٣', chips: ['٣']),
  // Said twice: two rows, each visible and removable.
  _r('2 eggs and 2 eggs', rows: ['boiled_eggs:2x1', 'boiled_eggs:2x1']),
];

String _row(ParsedItem i) => '${i.food.foodId}:${i.size.id}x${i.servings}';

void main() {
  late String packJson;
  final libraries = <String, FoodLibrary>{};

  setUpAll(() async {
    packJson = File('assets/content/foods_eg.json').readAsStringSync();
    EgyptianFoodPack.adopt(packJson);
    for (final code in const ['en', 'ar']) {
      libraries[code] = eatSampleLibrary(
        await AppL10n.delegate.load(Locale(code)),
      );
    }
  });
  tearDownAll(EgyptianFoodPack.reset);

  for (final code in const ['en', 'ar']) {
    for (final spoken in const [false, true]) {
      group('${spoken ? 'spoken' : 'typed'} in $code', () {
        for (final row in _corpus) {
          test('"${row.says}"', () {
            final parse = MealSentenceParser(
              libraries[code]!,
              fromSpeech: spoken,
            ).parse(row.says);
            expect(parse.items.map(_row).toList(), row.rows);
            expect(parse.unresolved.map((c) => c.text).toList(), row.chips);
            if (row.kcal != null) expect(parse.kcal, row.kcal);
          });
        }
      });
    }
  }

  group('every food in the pack is logged as itself by saying its name', () {
    // The raw-only foods are offered only when she says raw or dry, and these
    // Arabic names do not say so.
    const needsTheRawWord = {'beef_mince_lean', 'chicken_wings_raw'};
    // Where a hand-written sample stands for a pack plate, or two foods share a
    // name and the more popular one is the one she means. Named, so a name that
    // quietly lands on the wrong food cannot hide in here.
    const standsIn = {
      'koshary': 'koshari_bowl',
      'eggs_boiled': 'boiled_eggs',
      'ful_medames': 'ful_baladi',
      'molokhia_chicken': 'molokhia_chicken',
    };

    for (final code in const ['en', 'ar']) {
      test('in $code', () {
        final foods = jsonDecode(packJson)['foods'] as List;
        final parser = MealSentenceParser(libraries[code]!, fromSpeech: true);
        // The Arabic name of the whole egg is the bare word for eggs, which
        // means boiled eggs to her; its English name says raw.
        final stands = {
          ...standsIn,
          if (code == 'ar') 'egg_whole': 'boiled_eggs',
        };
        final wrong = <String>[];
        for (final food in foods) {
          final id = food['id'] as String;
          final name =
              (code == 'ar' ? food['nameAr'] : food['nameEn']) as String;
          if (code == 'ar' && needsTheRawWord.contains(id)) continue;
          final parse = parser.parse(name);
          final got = [for (final i in parse.items) i.food.foodId];
          final want = stands[id] ?? id;
          if (got.length != 1 ||
              got.single != want ||
              parse.unresolved.isNotEmpty) {
            wrong.add('$id "$name" -> $got ${parse.unresolved}');
          }
        }
        expect(wrong, isEmpty, reason: wrong.join('\n'));
      });
    }
  });

  group('counts of pieces', () {
    test('a count that fills the medium size is that many servings', () {
      final library = libraries['en']!;
      final parser = MealSentenceParser(library);
      final taameya = library.byId('taameya')!;
      expect(taameya.mediumPieces, 4);
      final four = parser.parse('4 taameya').items.single;
      expect((four.size.id, four.servings), ('M', 1));
      final eight = parser.parse('8 taameya').items.single;
      expect((eight.size.id, eight.servings), ('M', 2));
      final two = parser.parse('2 taameya').items.single;
      expect(two.size.id, startsWith('g'));
      expect(two.size.id, 'g49');
      expect(two.kcal, taameya.sizeForGrams(49)!.kcal);
    });

    test('no count the pack states is read as a single serving', () {
      final library = libraries['en']!;
      for (final food in library.foods.where((f) => f.mediumPieces > 1)) {
        final label = food.defaultSize.label;
        expect(label, matches(RegExp(r'^\d+ ')), reason: food.foodId);
      }
    });
  });

  group('limits', () {
    final parser = MealSentenceParser(
      FoodLibrary([
        const Food(
          foodId: 'bread',
          names: ['bread'],
          sizes: [
            FoodSize(id: 'S', label: 'S', kcal: 100, proteinG: 3, grams: 40),
            FoodSize(id: 'M', label: 'M', kcal: 200, proteinG: 6, grams: 80),
            FoodSize(id: 'L', label: 'L', kcal: 300, proteinG: 9, grams: 120),
          ],
        ),
        const Food(
          foodId: 'light',
          names: ['light'],
          sizes: [FoodSize(id: 'M', label: 'M', kcal: 10, proteinG: 0)],
        ),
        const Food(
          foodId: 'plain',
          names: ['plain'],
          sizes: [FoodSize(id: 'M', label: 'M', kcal: 200, proteinG: 6)],
        ),
      ]),
    );

    test(
      'twenty is the most of one food, and 3,000 kcal the most of one row',
      () {
        expect(parser.parse('20 light').items.single.servings, 20);
        expect(parser.parse('21 light').items, isEmpty);
        expect(
          parser.parse('16 bread').items,
          isEmpty,
          reason: '16 x 200 kcal is over a row',
        );
        expect(parser.parse('15 bread').items.single.kcal, 3000);
      },
    );

    test('a food with no weight has no half and no grams', () {
      expect(parser.parse('half plain').items, isEmpty);
      expect(parser.parse('half plain').unresolved, hasLength(1));
      expect(parser.parse('100 g plain').items, isEmpty);
    });

    test('a very long sentence is one chip, not a pile of rows', () {
      final parse = parser.parse('bread and ' * 100);
      expect(parse.items, isEmpty);
      expect(parse.unresolved, hasLength(1));
    });

    test('more than twelve foods in one sentence keeps the rest as a chip', () {
      final parse = parser.parse(List.filled(14, 'plain').join(' and '));
      expect(parse.items, hasLength(12));
      expect(parse.unresolved, hasLength(1));
    });

    test('hidden direction marks and joiners do not hide a food', () {
      final rlm = String.fromCharCode(0x200f);
      final zwj = String.fromCharCode(0x200d);
      final lre = String.fromCharCode(0x202a);
      final pdf = String.fromCharCode(0x202c);
      expect(parser.parse('${rlm}br${zwj}ead').items, hasLength(1));
      expect(parser.parse('$rlm${lre}bread$pdf').items, hasLength(1));
    });
  });
}
