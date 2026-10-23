/// Her optional "About you" answers, O04: weight, height and age.
///
/// **Health data, `DECISIONS.md` D31: this never leaves the phone.** It is kept
/// in the local snapshot only, it is not part of [Intake] (which is mirrored to
/// `users/{uid}.profile`), and nothing in the cloud mapping reads it. Age is a
/// number of years she types, never a date of birth.
///
/// Every field is optional, and skipping the block is a complete answer.
library;

import 'package:meta/meta.dart';

@immutable
class BodyData {
  const BodyData({this.weightKg, this.heightCm, this.ageYears});

  static const BodyData empty = BodyData();

  static const double minWeightKg = 30;
  static const double maxWeightKg = 250;
  static const int minHeightCm = 120;
  static const int maxHeightCm = 230;
  static const int minAgeYears = 14;
  static const int maxAgeYears = 90;

  final double? weightKg;
  final int? heightCm;
  final int? ageYears;

  bool get isEmpty => weightKg == null && heightCm == null && ageYears == null;

  /// Whether the three of them are present, which a calorie target needs.
  bool get isComplete =>
      weightKg != null && heightCm != null && ageYears != null;

  static bool weightOk(double v) => v >= minWeightKg && v <= maxWeightKg;
  static bool heightOk(int v) => v >= minHeightCm && v <= maxHeightCm;
  static bool ageOk(int v) => v >= minAgeYears && v <= maxAgeYears;

  /// A value outside its range reads as absent, so a hand-edited or newer
  /// document can never put an impossible body into a target.
  BodyData sanitised() => BodyData(
    weightKg: weightKg != null && weightOk(weightKg!) ? weightKg : null,
    heightCm: heightCm != null && heightOk(heightCm!) ? heightCm : null,
    ageYears: ageYears != null && ageOk(ageYears!) ? ageYears : null,
  );

  /// Pass `clearX: true` to remove one answer; null otherwise means "keep".
  BodyData copyWith({
    double? weightKg,
    int? heightCm,
    int? ageYears,
    bool clearWeight = false,
    bool clearHeight = false,
    bool clearAge = false,
  }) => BodyData(
    weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
    heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
    ageYears: clearAge ? null : (ageYears ?? this.ageYears),
  );

  @override
  bool operator ==(Object other) =>
      other is BodyData &&
      other.weightKg == weightKg &&
      other.heightCm == heightCm &&
      other.ageYears == ageYears;

  @override
  int get hashCode => Object.hash(weightKg, heightCm, ageYears);
}

/// Where [BodyData] lives for the session. Local only: the snapshot saves and
/// restores it, and nothing else reads it off the phone.
class BodyDataStore {
  BodyDataStore([BodyData? initial]) : _data = initial ?? BodyData.empty;

  /// The one the app uses. Tests may build their own.
  static final BodyDataStore instance = BodyDataStore();

  BodyData _data;

  BodyData read() => _data;

  void write(BodyData data) => _data = data.sanitised();

  void restore(BodyData data) => _data = data.sanitised();

  void reset() => _data = BodyData.empty;
}
