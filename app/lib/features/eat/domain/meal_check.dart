/// E13's working copy of her plate: what the scan found, as she corrects it.
///
/// Nothing here is logged. This is a draft she edits, and only "Log this
/// meal" turns it into [CheckedEntry]s for the one logging path
/// (`MealLogService.logChecked`, then the undo bus).
///
/// ## The arithmetic is the server's
///
/// An item's figures are its `per100g` values scaled to the grams she sees:
/// grams / 100 x value, the same sum `functions/nutrition/meal.py` does. Each
/// figure is rounded to a whole number once, for the item, and the meal total
/// is the sum of those whole numbers, so the total always equals what the
/// cards above it say.
///
/// A number she types herself replaces the computed one and stays until she
/// changes it, through any later change of weight: it is hers, marked "edited
/// by you", and the app does not overwrite her.
///
/// An item with no `per100g` (nothing was found for it) has no figures until
/// she enters them. Until it has energy and protein it counts for nothing in
/// the total, and the meal cannot be logged with it in: a food with no
/// numbers logged as zero would be a claim nobody made.
library;

import 'package:meta/meta.dart';

import 'food_library.dart';
import 'meal_scan.dart';

/// The longest name the shared list and her own foods keep for a meal.
const int kMealNameMaxChars = 60;

/// The most parts of a meal the shared list takes.
const int kMealPartsMax = 12;

/// The figures she can see and change on one item.
enum MacroKind { kcal, protein, carbs, fat, fiber }

/// Where an item on E13 came from.
enum CheckItemKind {
  /// Found in the photo.
  scanned,

  /// Added from the food list, at one of its own sizes.
  library,

  /// Typed in by her: a name, a weight and its numbers.
  own,
}

/// The step on the weight buttons.
const double kGramsStep = 10;

/// The heaviest single item E13 accepts. A plate is never three kilos.
const double kMaxItemGrams = 3000;

/// The id a food the pack does not hold is logged under.
///
/// Never shown: the item carries her name for it. The prefix is what keeps
/// these out of her remembered plates, which can only offer foods the pack
/// can log again in one tap.
const String kPhotoFoodPrefix = 'photo_';

@immutable
class CheckItem {
  const CheckItem._({
    required this.key,
    required this.kind,
    this.scanned,
    this.food,
    this.size,
    this.ownName,
    this.grams,
    this.per100g,
    this.edited = const <MacroKind, int>{},
  });

  /// An item from the scan, at the weight the server estimated.
  factory CheckItem.scanned(String key, ScannedItem item) => CheckItem._(
    key: key,
    kind: CheckItemKind.scanned,
    scanned: item,
    grams: _clampGrams(item.grams),
    per100g: item.per100g,
  );

  /// A food from the list, at [size].
  factory CheckItem.library(String key, Food food, FoodSize size) =>
      CheckItem._(
        key: key,
        kind: CheckItemKind.library,
        food: food,
        size: size,
      );

  /// One she typed. Her numbers are for [grams]; when the weight is above
  /// zero they become per 100 g, so changing the weight scales them as it
  /// scales a scanned item.
  factory CheckItem.own(
    String key, {
    required String name,
    required double grams,
    int? kcal,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? fiberG,
  }) {
    final weight = _clampGrams(grams);
    if (weight > 0) {
      double? per(int? value) => value == null ? null : value * 100 / weight;
      return CheckItem._(
        key: key,
        kind: CheckItemKind.own,
        ownName: name,
        grams: weight,
        per100g: Macros(
          kcal: per(kcal),
          proteinG: per(proteinG),
          carbsG: per(carbsG),
          fatG: per(fatG),
          fiberG: per(fiberG),
        ),
      );
    }
    return CheckItem._(
      key: key,
      kind: CheckItemKind.own,
      ownName: name,
      grams: weight,
      edited: {
        MacroKind.kcal: ?kcal,
        MacroKind.protein: ?proteinG,
        MacroKind.carbs: ?carbsG,
        MacroKind.fat: ?fatG,
        MacroKind.fiber: ?fiberG,
      },
    );
  }

  /// Stable for the life of the draft, so a card keeps its fields while the
  /// list around it changes.
  final String key;
  final CheckItemKind kind;

  final ScannedItem? scanned;
  final Food? food;
  final FoodSize? size;
  final String? ownName;

  /// Null for a food from the list, which is a size and never a weight.
  final double? grams;

  /// Null when nothing was found for a scanned item.
  final Macros? per100g;

  /// The figures she typed over the computed ones.
  final Map<MacroKind, int> edited;

  bool get hasGrams => kind != CheckItemKind.library;

  /// A scanned item nothing was found for, still waiting for her numbers.
  bool get needsNumbers =>
      kind == CheckItemKind.scanned && per100g == null && !isComplete;

  /// A scanned item only part of which was found: its figures cover the
  /// parts that were, so they may be low, and she is told so.
  bool get partlyFound =>
      kind == CheckItemKind.scanned &&
      per100g != null &&
      !scanned!.matched &&
      edited.isEmpty;

  /// True once it has energy and protein, the two figures every logged item
  /// carries. Only a complete item counts in the total.
  bool get isComplete =>
      value(MacroKind.kcal) != null && value(MacroKind.protein) != null;

  bool isEdited(MacroKind kind) => edited.containsKey(kind);

  /// Her name for it, in [languageCode].
  String nameFor(String languageCode) => switch (kind) {
    CheckItemKind.scanned => scanned!.nameFor(languageCode),
    CheckItemKind.library => food!.names.first,
    CheckItemKind.own => ownName ?? '',
  };

  /// The figure on the card: hers if she typed one, otherwise worked out.
  int? value(MacroKind macro) => edited[macro] ?? computed(macro);

  /// The figure worked out from the weight, or the size's own.
  int? computed(MacroKind macro) {
    if (kind == CheckItemKind.library) {
      final s = size!;
      return switch (macro) {
        MacroKind.kcal => s.kcal,
        MacroKind.protein => s.proteinG,
        MacroKind.carbs => s.carbsG,
        MacroKind.fat => s.fatG,
        MacroKind.fiber => s.fiberG,
      };
    }
    final per = per100g;
    final weight = grams;
    if (per == null || weight == null) return null;
    final amounts = per.forGrams(weight);
    final raw = switch (macro) {
      MacroKind.kcal => amounts.kcal,
      MacroKind.protein => amounts.proteinG,
      MacroKind.carbs => amounts.carbsG,
      MacroKind.fat => amounts.fatG,
      MacroKind.fiber => amounts.fiberG,
    };
    return raw?.round();
  }

  /// The parts of a dish or mixed plate, scaled to the weight she set.
  List<({String name, double grams})> get parts {
    final item = scanned;
    if (item == null || item.ingredients.isEmpty) return const [];
    final weight = grams ?? item.grams;
    final scale = item.grams > 0 ? weight / item.grams : 0.0;
    return [
      for (final part in item.ingredients)
        (name: part.nameEn, grams: part.grams * scale),
    ];
  }

  CheckItem withGrams(double next) =>
      hasGrams ? _copy(grams: _clampGrams(next)) : this;

  CheckItem stepGrams(int steps) =>
      withGrams((grams ?? 0) + steps * kGramsStep);

  /// [macro] set to [value] by her, or back to the worked-out figure when
  /// [value] is null.
  CheckItem withEdit(MacroKind macro, int? value) {
    final next = Map<MacroKind, int>.of(edited);
    if (value == null) {
      next.remove(macro);
    } else {
      next[macro] = value < 0 ? 0 : value;
    }
    return _copy(edited: next);
  }

  CheckItem withSize(FoodSize next) =>
      kind == CheckItemKind.library ? _copy(size: next) : this;

  CheckItem _copy({
    double? grams,
    FoodSize? size,
    Map<MacroKind, int>? edited,
  }) => CheckItem._(
    key: key,
    kind: kind,
    scanned: scanned,
    food: food,
    size: size ?? this.size,
    ownName: ownName,
    grams: grams ?? this.grams,
    per100g: per100g,
    edited: edited ?? this.edited,
  );

  /// The id it is logged under. A food from the list keeps its own.
  String get foodId => switch (kind) {
    CheckItemKind.library => food!.foodId,
    CheckItemKind.own => '${kPhotoFoodPrefix}own',
    CheckItemKind.scanned => switch (scanned!) {
      ScannedItem(isDish: true, dishKey: final String dish) =>
        '${kPhotoFoodPrefix}dish_$dish',
      ScannedItem(fdcId: final int fdc) => '${kPhotoFoodPrefix}usda_$fdc',
      _ => '${kPhotoFoodPrefix}item',
    },
  };

  static double _clampGrams(double grams) {
    if (!grams.isFinite || grams < 0) return 0;
    return grams > kMaxItemGrams ? kMaxItemGrams : grams;
  }
}

/// The meal's running total over the items that count.
@immutable
class CheckTotals {
  const CheckTotals({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  final int kcal;
  final int proteinG;

  /// Null when no counted item carries the figure.
  final int? carbsG;
  final int? fatG;
  final int? fiberG;

  @override
  bool operator ==(Object other) =>
      other is CheckTotals &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG;

  @override
  int get hashCode => Object.hash(kcal, proteinG, carbsG, fatG, fiberG);

  @override
  String toString() =>
      'CheckTotals($kcal kcal, P $proteinG, C $carbsG, F $fatG, fibre $fiberG)';
}

/// What "Log this meal" hands to the logging path, one per item.
@immutable
class CheckedEntry {
  const CheckedEntry({
    required this.foodId,
    required this.kcal,
    required this.proteinG,
    this.food,
    this.sizeId = '',
    this.name,
    this.grams,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  final String foodId;

  /// The food from the list, when it is one. Null for a food the pack does
  /// not hold.
  final Food? food;
  final String sizeId;

  /// Her name for a food the pack does not hold.
  final String? name;
  final double? grams;

  final int kcal;
  final int proteinG;
  final int? carbsG;
  final int? fatG;
  final int? fiberG;
}

/// The whole plate on E13.
@immutable
class MealCheck {
  const MealCheck(this.items);

  static const MealCheck empty = MealCheck(<CheckItem>[]);

  /// Every item the scan returned, in its order.
  factory MealCheck.fromScan(MealScanResult result) => MealCheck([
    for (var i = 0; i < result.items.length; i++)
      CheckItem.scanned('scan-$i', result.items[i]),
  ]);

  final List<CheckItem> items;

  bool get isEmpty => items.isEmpty;

  /// Only items with energy and protein count. See the library note.
  CheckTotals get totals {
    var kcal = 0;
    var protein = 0;
    int? carbs;
    int? fat;
    int? fiber;
    int? add(int? sum, int? value) => value == null ? sum : (sum ?? 0) + value;
    for (final item in items) {
      if (!item.isComplete) continue;
      kcal += item.value(MacroKind.kcal)!;
      protein += item.value(MacroKind.protein)!;
      carbs = add(carbs, item.value(MacroKind.carbs));
      fat = add(fat, item.value(MacroKind.fat));
      fiber = add(fiber, item.value(MacroKind.fiber));
    }
    return CheckTotals(
      kcal: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      fiberG: fiber,
    );
  }

  /// Every allergen the plate is known to hold: the union of its parts'. Null
  /// when any part is unknown (a photo read, or her own entry), because a
  /// plate is only as known as its least known part.
  Set<String>? get allergens {
    if (items.isEmpty) return null;
    final union = <String>{};
    for (final item in items) {
      final known = item.food?.allergens;
      if (known == null) return null;
      union.addAll(known);
    }
    return union;
  }

  /// Items still waiting for her numbers.
  int get incomplete => items.where((item) => !item.isComplete).length;

  /// Something to log, and nothing left without its numbers.
  bool get canLog => items.isNotEmpty && incomplete == 0;

  MealCheck replace(int index, CheckItem item) =>
      MealCheck([...items]..[index] = item);

  MealCheck removeAt(int index) => MealCheck([...items]..removeAt(index));

  MealCheck add(CheckItem item) => MealCheck([...items, item]);

  /// What the whole plate is called in [languageCode]: its parts, in order,
  /// joined with " + ", cut to [kMealNameMaxChars].
  String nameFor(String languageCode) {
    final joined = items
        .map((item) => item.nameFor(languageCode).trim())
        .where((name) => name.isNotEmpty)
        .join(' + ');
    return joined.length <= kMealNameMaxChars
        ? joined
        : joined.substring(0, kMealNameMaxChars).trim();
  }

  /// The plate as `submit_community_food` takes it, or null when it cannot be
  /// shared: nothing to log, no carbs or fat on any part, a part with no
  /// weight, or figures that do not add up (4 protein + 4 carbs + 9 fat
  /// against the energy, the server's own tolerance). Only names, weights and
  /// totals: never the photo, never anything of hers.
  Map<String, Object?>? communityDish(String languageCode) {
    if (!canLog) return null;
    final total = totals;
    final carbs = total.carbsG;
    final fat = total.fatG;
    if (total.kcal <= 0 || carbs == null || fat == null) return null;
    final atwater = 4 * total.proteinG + 4 * carbs + 9 * fat;
    final slack = total.kcal * 0.15 > 20 ? total.kcal * 0.15 : 20;
    if ((atwater - total.kcal).abs() > slack) return null;

    final parts = <Map<String, Object?>>[];
    for (final item in items) {
      final grams = item.hasGrams ? item.grams : item.size?.grams;
      final name = item.nameFor(languageCode).trim();
      if (grams == null || grams <= 0 || name.isEmpty) continue;
      parts.add(<String, Object?>{
        'name': name.length <= kMealNameMaxChars
            ? name
            : name.substring(0, kMealNameMaxChars).trim(),
        'grams': grams.round(),
      });
    }
    if (parts.isEmpty || parts.length > kMealPartsMax) return null;

    final arabic = languageCode == 'ar';
    final both = items.every(
      (item) =>
          item.kind == CheckItemKind.scanned &&
          item.scanned!.nameEn.isNotEmpty &&
          item.scanned!.nameAr.isNotEmpty,
    );
    final primary = nameFor(arabic ? 'ar' : 'en');
    if (primary.isEmpty) return null;
    final other = both ? nameFor(arabic ? 'en' : 'ar') : '';
    return <String, Object?>{
      if (arabic) 'nameAr': primary else 'nameEn': primary,
      if (other.isNotEmpty)
        if (arabic) 'nameEn': other else 'nameAr': other,
      'items': parts,
      'kcal': total.kcal,
      'proteinG': total.proteinG,
      'carbsG': carbs,
      'fatG': fat,
    };
  }

  /// The entries to log, each named in [languageCode]. Empty unless [canLog].
  List<CheckedEntry> entries(String languageCode) {
    if (!canLog) return const <CheckedEntry>[];
    return [
      for (final item in items)
        CheckedEntry(
          foodId: item.foodId,
          food: item.food,
          sizeId: item.size?.id ?? '',
          name: item.kind == CheckItemKind.library
              ? null
              : item.nameFor(languageCode),
          grams: item.hasGrams ? item.grams : null,
          kcal: item.value(MacroKind.kcal)!,
          proteinG: item.value(MacroKind.protein)!,
          carbsG: item.value(MacroKind.carbs),
          fatG: item.value(MacroKind.fat),
          fiberG: item.value(MacroKind.fiber),
        ),
    ];
  }
}
