// What `analyze_meal_photo` answers, read without trusting its shape, and
// every refusal it can give mapped to what E12 says.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';

/// The shape `functions/nutrition/meal.py` returns for a USDA food, a known
/// Egyptian dish and an item nothing was found for.
Map<String, Object?> _answer() => <String, Object?>{
  'items': <Object?>[
    <Object?, Object?>{
      'nameEn': 'Boiled egg',
      'nameAr': 'بيض مسلوق',
      'grams': 100,
      'confidence': 0.91,
      'matched': true,
      'source': 'usda',
      'fdcId': 173424,
      'usdaName': 'Egg, whole, cooked, hard-boiled',
      'per100g': <Object?, Object?>{
        'kcal': 155.0,
        'proteinG': 12.6,
        'carbsG': 1.12,
        'fatG': 10.6,
        'fiberG': 0.0,
      },
      'kcal': 155,
      'proteinG': 12.6,
      'carbsG': 1.1,
      'fatG': 10.6,
      'fiberG': 0.0,
    },
    <Object?, Object?>{
      'nameEn': 'Koshary',
      'nameAr': 'كشري',
      'grams': 441.0,
      'confidence': 0.8,
      'matched': true,
      'source': 'dish',
      'fdcId': null,
      'usdaName': null,
      'dishKey': 'koshary',
      'dishNameEn': 'Koshary',
      'dishNameAr': 'كشري',
      'review': 'estimated from a standard recipe, pending dietitian review',
      'per100g': <Object?, Object?>{
        'kcal': 150.0,
        'proteinG': 5.0,
        'carbsG': 27.0,
        'fatG': 2.5,
        'fiberG': 3.0,
      },
      'kcal': 662,
      'proteinG': 22.1,
      'carbsG': 119.1,
      'fatG': 11.0,
      'fiberG': 13.2,
      'ingredients': <Object?>[
        <Object?, Object?>{
          'nameEn': 'rice, cooked',
          'grams': 100.0,
          'matched': true,
          'fdcId': 168878,
          'usdaName': 'Rice, white, cooked',
          'per100g': <Object?, Object?>{'kcal': 130.0, 'proteinG': 2.7},
          'kcal': 130,
          'proteinG': 2.7,
        },
      ],
    },
    <Object?, Object?>{
      'nameEn': 'Mystery sauce',
      'nameAr': 'صوص',
      'grams': 30,
      'confidence': 0.2,
      'matched': false,
      'source': null,
      'fdcId': null,
      'usdaName': null,
      'per100g': null,
      'kcal': null,
      'proteinG': null,
      'carbsG': null,
      'fatG': null,
      'fiberG': null,
    },
  ],
  'totals': <String, Object?>{
    'kcal': 817,
    'proteinG': 34.7,
    'carbsG': 120.2,
    'fatG': 21.6,
    'fiberG': 13.2,
  },
  'estimate': true,
};

void main() {
  group('the answer', () {
    test('every item, with its source, numbers and per-100 g values', () {
      final result = MealScanResult.fromWire(_answer())!;
      expect(result.items, hasLength(3));
      expect(result.estimate, isTrue);
      expect(result.totals.kcal, 817);

      final egg = result.items[0];
      expect(egg.source, MealScanSource.usda);
      expect(egg.fdcId, 173424);
      expect(egg.grams, 100);
      expect(egg.matched, isTrue);
      expect(egg.per100g!.proteinG, 12.6);
      expect(egg.amounts.fatG, 10.6);
      expect(egg.nameFor('en'), 'Boiled egg');
      expect(egg.nameFor('ar'), 'بيض مسلوق');
    });

    test('a dish keeps its own names, its note and its parts', () {
      final dish = MealScanResult.fromWire(_answer())!.items[1];
      expect(dish.isDish, isTrue);
      expect(dish.dishKey, 'koshary');
      expect(dish.review, contains('standard recipe'));
      expect(dish.nameFor('ar'), 'كشري');
      expect(dish.ingredients.single.nameEn, 'rice, cooked');
      expect(dish.ingredients.single.grams, 100);
      expect(dish.ingredients.single.per100g!.kcal, 130);
    });

    test('an item nothing was found for has no numbers, not zeros', () {
      final sauce = MealScanResult.fromWire(_answer())!.items[2];
      expect(sauce.matched, isFalse);
      expect(sauce.source, isNull);
      expect(sauce.per100g, isNull);
      expect(sauce.amounts.kcal, isNull);
      expect(sauce.amounts.proteinG, isNull);
    });

    test('numbers in any shape a callable delivers: int, double, string, '
        'and the Int64Value wrapper', () {
      final wrapped = <String, Object?>{
        'items': <Object?>[
          <Object?, Object?>{
            'nameEn': 'Bread',
            'nameAr': 'عيش',
            'grams': <String, Object?>{
              '@type': 'type.googleapis.com/google.protobuf.Int64Value',
              'value': '90',
            },
            'matched': true,
            'source': 'usda',
            'fdcId': <String, Object?>{
              '@type': 'type.googleapis.com/google.protobuf.Int64Value',
              'value': '172686',
            },
            'per100g': <Object?, Object?>{'kcal': '247', 'proteinG': 13},
          },
        ],
      };
      final bread = MealScanResult.fromWire(wrapped)!.items.single;
      expect(bread.grams, 90);
      expect(bread.fdcId, 172686);
      expect(bread.per100g!.kcal, 247);
      expect(bread.per100g!.proteinG, 13);
      expect(bread.per100g!.carbsG, isNull);
    });

    test('missing fields are absent, never invented', () {
      final thin = <String, Object?>{
        'items': <Object?>[
          <Object?, Object?>{'nameEn': 'Apple', 'grams': 150},
        ],
      };
      final result = MealScanResult.fromWire(thin)!;
      final apple = result.items.single;
      expect(apple.nameAr, '');
      expect(apple.nameFor('ar'), 'Apple');
      expect(apple.matched, isFalse);
      expect(apple.source, isNull);
      expect(apple.per100g, isNull);
      expect(apple.ingredients, isEmpty);
      expect(result.totals, Macros.none);
      expect(result.estimate, isTrue);
    });

    test('an item that cannot be read is left out; a non-answer is null', () {
      final mixed = <String, Object?>{
        'items': <Object?>[
          'not an item',
          <Object?, Object?>{'nameEn': 'No weight'},
          <Object?, Object?>{'nameEn': 'Negative', 'grams': -5},
          <Object?, Object?>{'nameEn': 'Rice', 'grams': 200},
        ],
      };
      expect(MealScanResult.fromWire(mixed)!.items.single.nameEn, 'Rice');
      expect(MealScanResult.fromWire(null), isNull);
      expect(MealScanResult.fromWire('items'), isNull);
      expect(MealScanResult.fromWire(<String, Object?>{'items': 3}), isNull);
    });

    test('readNumber refuses what is not a number', () {
      expect(readNumber(true), isNull);
      expect(readNumber('abc'), isNull);
      expect(readNumber(double.nan), isNull);
      expect(readNumber(double.infinity), isNull);
      expect(readNumber(' 12.5 '), 12.5);
    });
  });

  group('every refusal has its reason', () {
    final cases = <(String, String?), MealScanFailure>{
      ('failed-precondition', 'consent_missing'):
          MealScanFailure.consentMissing,
      ('resource-exhausted', 'meal_scan_daily_limit'):
          MealScanFailure.dailyLimit,
      ('resource-exhausted', 'meal_scans_paused'): MealScanFailure.paused,
      ('not-found', 'no_food_seen'): MealScanFailure.noFoodSeen,
      ('failed-precondition', 'meal_unclear'): MealScanFailure.unclear,
      ('unavailable', 'meal_service_unavailable'): MealScanFailure.unavailable,
      ('permission-denied', 'not_verified'): MealScanFailure.notVerified,
      ('invalid-argument', 'image_undecodable'):
          MealScanFailure.photoUnreadable,
      ('invalid-argument', 'image_too_large'): MealScanFailure.photoUnreadable,
      ('failed-precondition', 'app_check_missing'): MealScanFailure.appOutdated,
      ('unauthenticated', 'unauthenticated'): MealScanFailure.signedOut,
      ('permission-denied', 'phone_sign_in_required'):
          MealScanFailure.signedOut,
      // The status alone, when the reason is not one this build knows.
      ('unauthenticated', null): MealScanFailure.signedOut,
      ('deadline-exceeded', null): MealScanFailure.unavailable,
      ('internal', 'internal_error'): MealScanFailure.unavailable,
      ('unavailable', 'Unable to resolve host'): MealScanFailure.unavailable,
    };
    for (final MapEntry(key: (code, message), value: failure)
        in cases.entries) {
      test('$code / $message', () {
        expect(mealScanFailureOf(code, message), failure);
      });
    }
  });

  test('the consent version is the server\'s', () {
    // functions/identity/config.py MEAL_PHOTO_CONSENT_VERSION.
    expect(kMealPhotoConsentVersion, 1);
    expect(kMealScansPerDay, 5);
  });
}
