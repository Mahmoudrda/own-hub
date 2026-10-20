/// A food she typed in herself: a name and the figures off the packet.
///
/// Kept in her eating preferences on this phone and offered in search beside
/// the pack, so a food she logs by hand once is one tap the next time. The
/// figures she left blank stay unknown rather than becoming zero.
library;

import 'package:meta/meta.dart';

import 'food_library.dart';

/// The most custom foods kept.
const int kCustomFoodCap = 60;

@immutable
class CustomFood {
  const CustomFood({
    required this.id,
    required this.name,
    required this.kcal,
    this.proteinG = 0,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  static const String idPrefix = 'custom-';

  static bool isCustomId(String foodId) => foodId.startsWith(idPrefix);

  final String id;
  final String name;
  final int kcal;
  final int proteinG;
  final int? carbsG;
  final int? fatG;
  final int? fiberG;

  /// The food as search and the log see it: one serving, her name.
  Food toFood() => Food(
    foodId: id,
    names: [name],
    custom: true,
    sizes: [
      FoodSize(
        id: '1',
        label: '1',
        kcal: kcal,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        fiberG: fiberG,
      ),
    ],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'fiberG': fiberG,
  };

  /// Null for a row that is not a usable food.
  static CustomFood? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final kcal = raw['kcal'];
    if (id is! String || !isCustomId(id) || name is! String) return null;
    if (name.trim().isEmpty || kcal is! num || kcal < 0) return null;
    int? whole(Object? v) => v is num && v >= 0 ? v.round() : null;
    return CustomFood(
      id: id,
      name: name.trim(),
      kcal: kcal.round(),
      proteinG: whole(raw['proteinG']) ?? 0,
      carbsG: whole(raw['carbsG']),
      fatG: whole(raw['fatG']),
      fiberG: whole(raw['fiberG']),
    );
  }
}
