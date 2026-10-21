/// Foods other women confirmed and Rahma approved, published for everyone.
///
/// `meta/communityFoods` holds `{version, foods: [...]}` and
/// `meta/communityFoodsVersion` holds `{version}`, the pair the phone checks
/// once a day. Each food is one serving, with the figures that serving carries
/// and the allergens the owner recorded when she approved it. A row that is
/// not usable is dropped, not the list.
library;

import 'package:meta/meta.dart';

import 'food_library.dart';

/// The id prefix the server gives every published food.
const String kCommunityFoodPrefix = 'community_';

@immutable
class CommunityFood {
  const CommunityFood({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.allergens,
    this.category,
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final Set<String> allergens;
  final FoodCategory? category;

  /// The food as search and the log see it: one serving, named in
  /// [arabic]'s language first. Its name travels with every meal it is
  /// logged in, as a food she typed does, because a later list may no longer
  /// hold it.
  Food toFood({required bool arabic}) {
    final first = arabic ? nameAr : nameEn;
    final second = arabic ? nameEn : nameAr;
    final names = <String>[
      if (first.isNotEmpty) first,
      if (second.isNotEmpty && second != first) second,
    ];
    return Food(
      foodId: id,
      names: names,
      sizes: [
        FoodSize(
          id: '1',
          label: '1',
          kcal: kcal,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
        ),
      ],
      allergens: allergens,
      popularity: 30,
      category: category,
      custom: true,
      community: true,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'nameEn': nameEn,
    'nameAr': nameAr,
    'category': category?.name,
    'allergens': allergens.toList()..sort(),
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };

  static CommunityFood? parse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || !id.startsWith(kCommunityFoodPrefix)) return null;
    final nameEn = raw['nameEn'] is String
        ? (raw['nameEn'] as String).trim()
        : '';
    final nameAr = raw['nameAr'] is String
        ? (raw['nameAr'] as String).trim()
        : '';
    if (nameEn.isEmpty && nameAr.isEmpty) return null;
    int? whole(Object? v) =>
        v is num && v.isFinite && v >= 0 ? v.round() : null;
    final kcal = whole(raw['kcal']);
    final protein = whole(raw['proteinG']);
    final carbs = whole(raw['carbsG']);
    final fat = whole(raw['fatG']);
    if (kcal == null || kcal == 0 || protein == null) return null;
    if (carbs == null || fat == null) return null;
    final tags = raw['allergens'];
    if (tags is! List) return null;
    return CommunityFood(
      id: id,
      nameEn: nameEn,
      nameAr: nameAr,
      kcal: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      allergens: {
        for (final tag in tags)
          if (tag is String) tag,
      },
      category: raw['category'] is String
          ? FoodCategory.fromWire(raw['category'] as String)
          : null,
    );
  }
}

/// The published list and the version it was published as.
@immutable
class CommunityFoods {
  const CommunityFoods({required this.version, required this.foods});

  static const CommunityFoods empty = CommunityFoods(
    version: 0,
    foods: <CommunityFood>[],
  );

  final int version;
  final List<CommunityFood> foods;

  bool get isEmpty => foods.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'foods': [for (final food in foods) food.toJson()],
  };

  /// Null when [raw] is not a list at all. A food that cannot be read is left
  /// out; one whose allergens are missing is left out too, since a food with
  /// no allergen record would read as safe.
  static CommunityFoods? parse(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    final foods = raw['foods'];
    if (version is! int || version < 0 || foods is! List) return null;
    return CommunityFoods(
      version: version,
      foods: [for (final row in foods) ?CommunityFood.parse(row)],
    );
  }
}
