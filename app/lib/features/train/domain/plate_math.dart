/// Which plates go on each side of a bar for a total weight.
///
/// She logs the total, bar included. This turns that total into the plates on
/// one side, so loading the bar is reading a line rather than doing sums.
library;

/// Plates in kg, heaviest first.
const List<double> kPlatesKg = [25, 20, 15, 10, 5, 2.5, 1.25];

/// Bars she may choose, in kg.
const List<double> kBarChoicesKg = [20, 15, 10];

/// The bar a woman starts on.
const double kDefaultBarKg = 20;

/// Plates for a total on a bar.
class PlateLoad {
  const PlateLoad({
    required this.barKg,
    required this.requestedKg,
    required this.loadableKg,
    required this.perSideKg,
  });

  final double barKg;

  /// The total she asked for.
  final double requestedKg;

  /// The total the plates actually make. Equal to [requestedKg] when the
  /// plates can make it exactly.
  final double loadableKg;

  /// One side's plates, heaviest first (empty for the bare bar).
  final List<double> perSideKg;

  /// False when the plates cannot make the total and [loadableKg] is the
  /// nearest total they can.
  bool get exact => (loadableKg - requestedKg).abs() < 1e-9;

  /// The weight on one side.
  double get eachSideKg => (loadableKg - barKg) / 2;
}

/// The plates for [totalKg] on a [barKg] bar, or null when the total is below
/// the bar (or not a usable number), where there is nothing to load.
///
/// Plates are taken greedily, heaviest first. When the total is not a multiple
/// of two of the smallest plate, the nearest total that is loadable is used
/// (the lower one on a tie) and [PlateLoad.exact] is false.
PlateLoad? platesFor(double totalKg, {double barKg = kDefaultBarKg}) {
  if (!totalKg.isFinite || !barKg.isFinite || barKg <= 0) return null;
  if (totalKg < barKg - 1e-9) return null;
  const smallest = 1.25;
  // Work in units of the smallest plate to keep the sums exact.
  final units = ((totalKg - barKg) / 2 / smallest);
  final lower = units.floor();
  final upper = units.ceil();
  final chosen = (units - lower) <= (upper - units) ? lower : upper;
  var remaining = chosen * smallest;
  final plates = <double>[];
  for (final plate in kPlatesKg) {
    while (remaining + 1e-9 >= plate) {
      plates.add(plate);
      remaining -= plate;
    }
  }
  final side = plates.fold<double>(0, (a, b) => a + b);
  return PlateLoad(
    barKg: barKg,
    requestedKg: totalKg,
    loadableKg: barKg + side * 2,
    perSideKg: plates,
  );
}
