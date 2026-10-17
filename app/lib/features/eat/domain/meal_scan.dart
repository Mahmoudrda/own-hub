/// What the server says is on her plate, read without trusting its shape.
///
/// `analyze_meal_photo` (`functions/main.py`, `functions/nutrition/meal.py`)
/// answers `{items, totals, estimate: true}`. Every energy and macro number in
/// it comes from the Egyptian dish table or USDA FoodData Central; the model
/// only names the foods and guesses their grams. Each item carries its own
/// `per100g`, so a changed weight on E13 is recomputed here with the server's
/// own arithmetic: grams / 100 x the value per 100 g.
///
/// The parser takes nothing on faith. A callable's nested maps arrive as
/// `Map<Object?, Object?>`, a number may be an int, a double, a numeric string
/// or the `Int64Value` wrapper some platforms put round a long, and a field the
/// server did not send is simply absent. A missing number stays null, never
/// zero: zero is a claim about the food, null is the honest "not known".
library;

import 'package:meta/meta.dart';

/// The wording of the meal-photo consent she agrees to on E12.
///
/// The server's `MEAL_PHOTO_CONSENT_VERSION` (`functions/identity/config.py`).
/// Any other number is refused there with `consent_missing`, so the two move
/// together.
const int kMealPhotoConsentVersion = 1;

/// Scans a verified member may make in a day. The server's
/// `MEAL_SCANS_PER_UID_PER_DAY`; here only for the copy that names it.
const int kMealScansPerDay = 5;

/// Where an item's numbers came from.
enum MealScanSource {
  /// A known Egyptian dish, from a standard recipe.
  dish,

  /// The ingredients the model saw, each matched to USDA.
  ingredients,

  /// One USDA food.
  usda,
}

/// The five numbers, per 100 g or for an amount. Any of them can be unknown.
@immutable
class Macros {
  const Macros({
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  static const Macros none = Macros();

  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;

  /// The server's camelCase keys, from a map of any shape. Null when [raw] is
  /// not a map at all.
  static Macros? fromWire(Object? raw) {
    if (raw is! Map) return null;
    return Macros(
      kcal: readNumber(raw['kcal']),
      proteinG: readNumber(raw['proteinG']),
      carbsG: readNumber(raw['carbsG']),
      fatG: readNumber(raw['fatG']),
      fiberG: readNumber(raw['fiberG']),
    );
  }

  /// These values per 100 g, for [grams]: grams / 100 x each value. An unknown
  /// value stays unknown.
  Macros forGrams(num grams) {
    double? scale(double? per100) =>
        per100 == null ? null : per100 * grams / 100;
    return Macros(
      kcal: scale(kcal),
      proteinG: scale(proteinG),
      carbsG: scale(carbsG),
      fatG: scale(fatG),
      fiberG: scale(fiberG),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Macros &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG;

  @override
  int get hashCode => Object.hash(kcal, proteinG, carbsG, fatG, fiberG);

  @override
  String toString() =>
      'Macros($kcal kcal, P $proteinG, C $carbsG, F $fatG, fibre $fiberG)';
}

/// One part of a dish or a mixed plate, as the server broke it down.
@immutable
class ScannedIngredient {
  const ScannedIngredient({
    required this.nameEn,
    required this.grams,
    required this.matched,
    this.per100g,
    this.amounts = Macros.none,
  });

  final String nameEn;
  final double grams;
  final bool matched;
  final Macros? per100g;
  final Macros amounts;

  static ScannedIngredient? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final name = readText(raw['nameEn']);
    final grams = readNumber(raw['grams']);
    if (name == null || grams == null) return null;
    return ScannedIngredient(
      nameEn: name,
      grams: grams,
      matched: raw['matched'] == true,
      per100g: Macros.fromWire(raw['per100g']),
      amounts: Macros.fromWire(raw) ?? Macros.none,
    );
  }
}

/// One food on her plate, as the server returned it.
@immutable
class ScannedItem {
  const ScannedItem({
    required this.nameEn,
    required this.nameAr,
    required this.grams,
    required this.matched,
    this.confidence = 0,
    this.source,
    this.fdcId,
    this.usdaName,
    this.per100g,
    this.amounts = Macros.none,
    this.dishKey,
    this.dishNameEn,
    this.dishNameAr,
    this.review,
    this.ingredients = const <ScannedIngredient>[],
  });

  final String nameEn;
  final String nameAr;
  final double grams;
  final double confidence;

  /// False when the item, or any part of it, was not found. The numbers then
  /// cover only the parts that were, and with no [per100g] there are none.
  final bool matched;

  final MealScanSource? source;
  final int? fdcId;
  final String? usdaName;

  /// Null when nothing was found for it: she enters the numbers or removes it.
  final Macros? per100g;

  /// The server's own figures for [grams].
  final Macros amounts;

  final String? dishKey;
  final String? dishNameEn;
  final String? dishNameAr;

  /// The dish table's note on how the dish was estimated.
  final String? review;

  final List<ScannedIngredient> ingredients;

  bool get isDish => source == MealScanSource.dish;

  /// Its name in her language: the dish's own name for a known dish, and the
  /// other language when hers is missing.
  String nameFor(String languageCode) {
    final arabic = languageCode == 'ar';
    final dishName = arabic ? dishNameAr : dishNameEn;
    if (isDish && dishName != null && dishName.isNotEmpty) return dishName;
    final own = arabic ? nameAr : nameEn;
    if (own.isNotEmpty) return own;
    return arabic ? nameEn : nameAr;
  }

  static ScannedItem? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final nameEn = readText(raw['nameEn']) ?? '';
    final nameAr = readText(raw['nameAr']) ?? '';
    final grams = readNumber(raw['grams']);
    if ((nameEn.isEmpty && nameAr.isEmpty) || grams == null || grams < 0) {
      return null;
    }
    final ingredients = raw['ingredients'];
    return ScannedItem(
      nameEn: nameEn,
      nameAr: nameAr,
      grams: grams,
      confidence: readNumber(raw['confidence']) ?? 0,
      matched: raw['matched'] == true,
      source: switch (raw['source']) {
        'dish' => MealScanSource.dish,
        'ingredients' => MealScanSource.ingredients,
        'usda' => MealScanSource.usda,
        _ => null,
      },
      fdcId: readNumber(raw['fdcId'])?.round(),
      usdaName: readText(raw['usdaName']),
      per100g: Macros.fromWire(raw['per100g']),
      amounts: Macros.fromWire(raw) ?? Macros.none,
      dishKey: readText(raw['dishKey']),
      dishNameEn: readText(raw['dishNameEn']),
      dishNameAr: readText(raw['dishNameAr']),
      review: readText(raw['review']),
      ingredients: ingredients is List
          ? [for (final part in ingredients) ?ScannedIngredient.fromWire(part)]
          : const <ScannedIngredient>[],
    );
  }
}

/// The whole answer.
@immutable
class MealScanResult {
  const MealScanResult({
    required this.items,
    this.totals = Macros.none,
    this.estimate = true,
  });

  final List<ScannedItem> items;
  final Macros totals;

  /// Always true from this server. Carried so the screen never has to assume.
  final bool estimate;

  /// The callable's data, or null when it is not an answer at all. An item
  /// that cannot be read is left out rather than guessed at.
  static MealScanResult? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final items = raw['items'];
    if (items is! List) return null;
    return MealScanResult(
      items: [for (final item in items) ?ScannedItem.fromWire(item)],
      totals: Macros.fromWire(raw['totals']) ?? Macros.none,
      estimate: raw['estimate'] != false,
    );
  }
}

/// Why a scan did not come back with food, in the terms E12 answers with.
enum MealScanFailure {
  /// `consent_missing`: her agreement is not on the server. Ask again.
  consentMissing,

  /// `meal_scan_daily_limit`: her five for today are used.
  dailyLimit,

  /// `meal_scans_paused`: the app's own daily ceiling, for everyone.
  paused,

  /// `no_food_seen`.
  noFoodSeen,

  /// `meal_unclear`.
  unclear,

  /// `meal_service_unavailable`, a timeout, no connection, or a server fault.
  unavailable,

  /// `not_verified`: only verified members can scan.
  notVerified,

  /// `image_undecodable` or `image_too_large`: the photo itself. Retake.
  photoUnreadable,

  /// `app_check_missing`: this copy of the app cannot reach Own Hub.
  appOutdated,

  /// Signed out, or not signed in with her phone number.
  signedOut,
}

/// A refused scan, carrying its reason.
@immutable
class MealScanException implements Exception {
  const MealScanException(this.failure);

  final MealScanFailure failure;

  @override
  String toString() => 'MealScanException(${failure.name})';
}

/// A failed callable in E12's terms, from its status [code] and the reason the
/// server put in [message]. The reason wins where there is one; the status is
/// the fallback, so a refusal this build does not know still gets an honest
/// "not available right now" rather than a wrong specific.
MealScanFailure mealScanFailureOf(String code, String? message) {
  switch ((message ?? '').trim()) {
    case 'consent_missing':
      return MealScanFailure.consentMissing;
    case 'meal_scan_daily_limit':
      return MealScanFailure.dailyLimit;
    case 'meal_scans_paused':
      return MealScanFailure.paused;
    case 'no_food_seen':
      return MealScanFailure.noFoodSeen;
    case 'meal_unclear':
      return MealScanFailure.unclear;
    case 'meal_service_unavailable':
      return MealScanFailure.unavailable;
    case 'not_verified':
      return MealScanFailure.notVerified;
    case 'image_undecodable':
    case 'image_too_large':
      return MealScanFailure.photoUnreadable;
    case 'app_check_missing':
      return MealScanFailure.appOutdated;
    case 'unauthenticated':
    case 'phone_sign_in_required':
      return MealScanFailure.signedOut;
  }
  return switch (code) {
    'unauthenticated' => MealScanFailure.signedOut,
    'permission-denied' => MealScanFailure.notVerified,
    'resource-exhausted' => MealScanFailure.dailyLimit,
    'not-found' => MealScanFailure.noFoodSeen,
    _ => MealScanFailure.unavailable,
  };
}

/// A number from the wire: an int, a double, a numeric string, or the
/// `{"@type": ...Int64Value, "value": "123"}` wrapper. Null for anything
/// else, including a boolean and a value that is not finite.
double? readNumber(Object? raw) {
  final Object? value = raw is Map ? raw['value'] : raw;
  final double? parsed = switch (value) {
    final bool _ => null,
    final num n => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };
  if (parsed == null || !parsed.isFinite) return null;
  return parsed;
}

/// A non-empty string from the wire, trimmed, or null.
String? readText(Object? raw) {
  if (raw is! String) return null;
  final text = raw.trim();
  return text.isEmpty ? null : text;
}
