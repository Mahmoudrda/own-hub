/// The dish a client swapped to, per plan, day, slot and place. On this phone,
/// in memory: the plan on the server is never changed by a swap.
library;

import 'app_changes.dart';

class CoachMealSwaps {
  CoachMealSwaps._();

  static final CoachMealSwaps instance = CoachMealSwaps._();

  final Map<String, String> _chosen = <String, String>{};

  String _key(String planId, int day, String slot, int index) =>
      '$planId|$day|$slot|$index';

  /// The recipe id she chose, or null for the planned dish.
  String? chosen(String planId, int day, String slot, int index) =>
      _chosen[_key(planId, day, slot, index)];

  /// Null puts the planned dish back.
  void choose(String planId, int day, String slot, int index, String? recipeId) {
    final k = _key(planId, day, slot, index);
    if (recipeId == null) {
      if (_chosen.remove(k) == null) return;
    } else {
      if (_chosen[k] == recipeId) return;
      _chosen[k] = recipeId;
    }
    AppChanges.bump();
  }
}
