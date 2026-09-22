// The level curve, pinned to the two anchors the product's own copy states.
//
// Unlike the tier thresholds, this one IS authored — by two shipped screens that
// agree to the point:
//
//   R10: "490 total" and "70 points to level 8."   → level 7 at 490
//   T08: "90 points, level 2"                      → level 2 begins at 80
//
// Both fall out of (points ÷ 80) + 1 exactly. The third group below uses values
// from neither screen, because two anchors that happen to be the mockup's are
// exactly the kind of figure a hardcoded constant would also satisfy.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/level_curve.dart';

void main() {
  const curve = LevelCurve();

  group('the two anchors the copy states', () {
    test('R10 — 490 points is level 7, with 70 to level 8', () {
      expect(curve.levelFor(490), 7);
      expect(curve.pointsToNextLevel(490), 70);
    });

    test('T08 — 90 points is level 2', () {
      expect(curve.levelFor(90), 2);
    });
  });

  group('values from neither screen', () {
    test('a level boundary is the first point of the new level', () {
      expect(curve.levelFor(79), 1);
      expect(curve.levelFor(80), 2);
      expect(curve.levelFor(159), 2);
      expect(curve.levelFor(160), 3);
    });

    test('the distance to the next level is never zero and never over 80', () {
      for (final points in [1, 37, 123, 235, 404, 639, 1041]) {
        final toNext = curve.pointsToNextLevel(points);
        expect(toNext, greaterThan(0), reason: 'at $points');
        expect(
          toNext,
          lessThanOrEqualTo(kPointsPerLevel),
          reason: 'at $points',
        );
        // Arriving there really does level her up.
        expect(curve.levelFor(points + toNext), curve.levelFor(points) + 1);
      }
    });

    test('235 points is level 3, five short of level 4', () {
      expect(curve.levelFor(235), 3);
      expect(curve.pointsToNextLevel(235), 5);
    });

    test('640 points is level 9, a whole level short of the next', () {
      expect(curve.levelFor(640), 9);
      expect(curve.pointsToNextLevel(640), 80);
    });
  });

  group('the level cannot fall', () {
    test('it is monotonic across the whole range', () {
      var previous = 1;
      for (var points = 0; points <= 2000; points += 7) {
        final level = curve.levelFor(points);
        expect(level, greaterThanOrEqualTo(previous), reason: 'at $points');
        previous = level;
      }
    });

    test('a woman with nothing is level 1, never level 0', () {
      expect(curve.levelFor(0), 1);
      expect(curve.pointsToNextLevel(0), kPointsPerLevel);
    });

    test('a corrupt negative read does not put "Level -3" on her screen', () {
      expect(curve.levelFor(-240), 1);
      expect(curve.pointsToNextLevel(-240), kPointsPerLevel);
    });
  });

  group('progress through the current level', () {
    test('it is the remainder, as a percentage', () {
      expect(curve.progressPercent(0), 0);
      expect(curve.progressPercent(40), 50);
      expect(curve.progressPercent(120), 50);
      // R10 draws its bar at roughly half where the formula gives an eighth.
      // The formula is authoritative: a bar is a drawing, two numbers on two
      // screens are a specification. Recorded here so the discrepancy is not
      // rediscovered as a bug.
      expect(curve.progressPercent(490), closeTo(12.5, 0.001));
    });
  });

  group('the curve is a parameter, not a constant nobody can find', () {
    test('a different curve gives different levels', () {
      const gentler = LevelCurve(pointsPerLevel: 100);
      expect(gentler.levelFor(490), 5);
      expect(gentler.pointsToNextLevel(490), 10);
    });
  });
}
