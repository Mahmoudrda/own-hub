/// The bar she loads, as she last chose it: 20, 15 or 10 kg.
///
/// Chosen once from a small sheet on R07. Phone only: it is kept in the local
/// snapshot and is in no cloud document, and Delete everything clears it.
library;

import '../features/train/domain/plate_math.dart';
import 'app_changes.dart';

class BarPreference {
  BarPreference._();

  static final BarPreference instance = BarPreference._();

  double? _kg;

  /// True once she has chosen a bar.
  bool get touched => _kg != null;

  /// Her bar, or the standard 20 kg one.
  double get kg => _kg ?? kDefaultBarKg;

  /// Keeps [value] when it is one of the bars on offer.
  void choose(double value) {
    if (!kBarChoicesKg.contains(value) || _kg == value) return;
    _kg = value;
    AppChanges.bump();
  }

  /// Puts back what the snapshot held; anything else is dropped.
  void restore(double? saved) =>
      _kg = saved != null && kBarChoicesKg.contains(saved) ? saved : null;

  /// Back to no choice. Delete everything, and tests.
  void reset() => _kg = null;
}
