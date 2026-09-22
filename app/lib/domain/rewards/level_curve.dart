/// Points to levels.
///
/// Unlike the tier thresholds, this curve **is** authored — not by a decision
/// document, but by the product's own shipped copy, which pins it at two
/// independent points:
///
///   * R10: *"490 total"* and *"70 points to level 8."* → level 7 at 490, and
///     level 8 begins at 560. 560 − 490 = 70. ✓
///   * T08: *"90 points, level 2"* → level 2 begins at 80. ✓
///
/// Both fall out of `level = (points ÷ 80) + 1` exactly, with no rounding slack.
/// Two anchors from two different screens agreeing to the point is evidence, not
/// a guess, which is why this file may hold a number while `tier_policy.dart`
/// may not. G6 §9.1 reaches the same figure and treats the formula as
/// authoritative; G4 renders `pointsToNextLevel` from it.
///
/// The one thing that does **not** fit is R10's progress bar, drawn at roughly
/// 50% where the formula gives 12.5%. The formula wins: a bar is a drawing, and
/// two numbers on two screens are a specification.
///
/// ## The level cannot fall
///
/// `rewards.points` is increment-only and the award ledger is append-only, so
/// the input to this function only ever rises — and since the function is
/// monotonic, so does the level. There is no method here that takes points away.
library;

/// Points per level. See the library comment for the two anchors that fix it.
const int kPointsPerLevel = 80;

/// Converts her points total into a level, and says how far the next one is.
class LevelCurve {
  const LevelCurve({this.pointsPerLevel = kPointsPerLevel});

  final int pointsPerLevel;

  /// Her level. Level 1 starts at zero points, so it is never level 0.
  ///
  /// A negative total cannot occur — points only increment — but it clamps to
  /// level 1 rather than returning something absurd, because a corrupted read
  /// should not put "Level -3" on her Home screen.
  int levelFor(int points) {
    if (points <= 0) return 1;
    return (points ~/ pointsPerLevel) + 1;
  }

  /// Points still needed for the next level. Always 1–[pointsPerLevel].
  ///
  /// G4 asked for this as a stored field so R10 and R12 render without doing
  /// arithmetic; this is the function that computes what the server stores, so
  /// the two cannot disagree.
  int pointsToNextLevel(int points) {
    final atOrAbove = points <= 0 ? 0 : points;
    return (levelFor(atOrAbove) * pointsPerLevel) - atOrAbove;
  }

  /// How far through the current level she is, 0–100.
  double progressPercent(int points) {
    final into = points <= 0 ? 0 : points % pointsPerLevel;
    return into / pointsPerLevel * 100;
  }
}
