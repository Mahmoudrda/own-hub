// P0-PORT-07 — "the photo overlay has a computed floor".
//
// Every expected value here comes from `test/fixtures/contrast_vectors.json`,
// which was computed from the WCAG specification in a different language
// entirely. That is the point of the fixture (G13 §1.4.6): the publish
// Function re-runs this algorithm and is authoritative, so if the two ever
// disagree a coach's cover passes on her phone and is refused by the server.
// One fixture, two readers, no drift.
//
// The case that earns the whole design is "the blown-out sky": a region whose
// MEAN says no darkening is needed and whose 90th percentile says 0.82.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coachbrand/domain/overlay_floor.dart';

Map<String, Object?> _fixture() =>
    jsonDecode(File('test/fixtures/contrast_vectors.json').readAsStringSync())
        as Map<String, Object?>;

Color _hex(String value) =>
    Color(0xFF000000 | int.parse(value.substring(1), radix: 16));

List<double> _samplesOf(Map<String, Object?> vector) {
  final direct = vector['samples'] as List<Object?>?;
  if (direct != null) {
    return [for (final v in direct) (v! as num).toDouble()];
  }
  final repeats = vector['samplesRepeat']! as List<Object?>;
  return [
    for (final r in repeats)
      ...List<double>.filled(
        ((r! as Map)['count']! as num).toInt(),
        ((r as Map)['value']! as num).toDouble(),
      ),
  ];
}

void main() {
  final fixture = _fixture();

  group('the 90th percentile, by nearest rank', () {
    final vectors = fixture['percentile90']! as List<Object?>;

    for (var i = 0; i < vectors.length; i++) {
      final vector = vectors[i]! as Map<String, Object?>;
      final note = vector['_'] as String?;

      test('vector $i${note == null ? '' : ' — $note'}', () {
        expect(
          OverlayFloor.percentile90(_samplesOf(vector)),
          closeTo((vector['p90']! as num).toDouble(), 1e-12),
        );
      });
    }

    test('order does not matter — the samples are sorted first', () {
      const region = [0.9, 0.1, 0.5, 0.3, 0.7];
      expect(
        OverlayFloor.percentile90(region),
        OverlayFloor.percentile90(region.reversed.toList()),
      );
    });

    test('a single sample is its own 90th percentile', () {
      expect(OverlayFloor.percentile90(const [0.42]), 0.42);
    });

    test('an empty region is a programming error, not a default', () {
      // A cover with no decodable photo is not a text-over-photo cover, and
      // defaulting to 0 here would hand back "no darkening needed".
      expect(() => OverlayFloor.percentile90(const []), throwsArgumentError);
    });

    test('it is not the mean, and the difference is the whole point', () {
      final sky = _samplesOf(
        (fixture['percentile90']! as List<Object?>).last
            as Map<String, Object?>,
      );
      final mean = sky.reduce((a, b) => a + b) / sky.length;

      expect(OverlayFloor.percentile90(sky), 1.0);
      expect(
        mean,
        lessThan(0.2),
        reason:
            'a mean says this photograph is dark; the bright tenth of it '
            'is what the third word of her headline lands on',
      );
    });
  });

  group('the floor, solved in 1% steps', () {
    final vectors = fixture['overlayFloors']! as List<Object?>;

    for (var i = 0; i < vectors.length; i++) {
      final vector = vectors[i]! as Map<String, Object?>;
      final note = vector['_'] as String?;

      test('vector $i${note == null ? '' : ' — $note'}', () {
        final decision = OverlayFloor.minAlpha(
          regionLuminances: [(vector['regionP90']! as num).toDouble()],
          textColour: _hex(vector['text']! as String),
          scrim: _hex(vector['scrim']! as String),
        );

        expect(decision.refused, vector['refused']);
        expect(
          decision.minAlpha,
          closeTo((vector['minAlpha']! as num).toDouble(), 1e-9),
        );
      });
    }

    test(
      'the blown-out sky needs 0.82 where the mean would have said 0.00',
      () {
        final vector =
            (fixture['overlayFloors']! as List<Object?>)[1]
                as Map<String, Object?>;

        expect(vector['alphaFromMean'], 0.0);
        expect(vector['minAlpha'], 0.82);
        expect(
          OverlayFloor.minAlpha(
            regionLuminances: [1.0],
            textColour: const Color(0xFFFFFFFF),
          ).minAlpha,
          0.82,
        );
      },
    );

    test('a dark photograph needs no scrim at all', () {
      final decision = OverlayFloor.minAlpha(
        regionLuminances: const [0.02],
        textColour: const Color(0xFFFFFFFF),
      );
      expect(decision.isAllowed, isTrue);
      expect(decision.minAlpha, 0.0);
    });

    test('when 0.9 is not enough, the layout is refused', () {
      // Mid-grey text on a blown-out photograph. There is no alpha that works,
      // so the builder says no and offers photo-above — the one place in this
      // flow where it refuses rather than nudges.
      final decision = OverlayFloor.minAlpha(
        regionLuminances: const [1.0],
        textColour: const Color(0xFF808080),
      );

      expect(decision.refused, isTrue);
      expect(decision.isAllowed, isFalse);
      expect(decision.minAlpha, kMaxOverlayAlpha);
    });

    test('the answer is always a whole 1% step the slider can hold', () {
      for (var lp = 0.0; lp <= 1.0; lp += 0.05) {
        final alpha = OverlayFloor.minAlpha(
          regionLuminances: [lp],
          textColour: const Color(0xFFFFFFFF),
        ).minAlpha;
        expect(
          (alpha * 100).roundToDouble(),
          closeTo(alpha * 100, 1e-9),
          reason: 'lp=$lp gave $alpha',
        );
      }
    });

    test('the floor is monotonic in the brightness of the region', () {
      var previous = -1.0;
      for (var lp = 0.0; lp <= 1.0; lp += 0.1) {
        final alpha = OverlayFloor.minAlpha(
          regionLuminances: [lp],
          textColour: const Color(0xFFFFFFFF),
        ).minAlpha;
        expect(alpha, greaterThanOrEqualTo(previous));
        previous = alpha;
      }
    });

    test('it targets 4.5:1, not the large-text allowance', () {
      // A cover headline renders at `display`, which WCAG would let through at
      // 3.0:1. G13 §1.4.5 asks for 4.5 anyway: a scrim's effect varies across
      // the image, the sample is 32×32, and the subline in the same box is
      // normal text.
      expect(kOverlayTargetRatio, 4.5);

      final atFourFive = OverlayFloor.minAlpha(
        regionLuminances: const [0.5],
        textColour: const Color(0xFFFFFFFF),
      );
      final atThree = OverlayFloor.minAlpha(
        regionLuminances: const [0.5],
        textColour: const Color(0xFFFFFFFF),
        target: 3.0,
      );

      expect(atFourFive.minAlpha, greaterThan(atThree.minAlpha));
    });
  });

  group('recomputing when the photo, layout or headline changes', () {
    test('a value below the new floor is raised', () {
      expect(
        OverlayFloor.raiseToFloor(0.2, const OverlayDecision.allowed(0.62)),
        0.62,
      );
    });

    test('a coach who darkened further keeps her choice', () {
      // She is allowed to be stricter than the validator. Snapping her back
      // down to the floor would undo a deliberate design decision every time
      // she changed the photo.
      expect(
        OverlayFloor.raiseToFloor(0.85, const OverlayDecision.allowed(0.62)),
        0.85,
      );
    });

    test('exactly at the floor is left alone', () {
      expect(
        OverlayFloor.raiseToFloor(0.62, const OverlayDecision.allowed(0.62)),
        0.62,
      );
    });
  });

  group('the fixture is the shared contract', () {
    test('it exists and names why', () {
      expect(File('test/fixtures/contrast_vectors.json').existsSync(), isTrue);
      expect(fixture['spec'], contains('WCAG 2.1'));
      expect((fixture['_']! as String), contains('contrast.test.ts'));
    });

    test(
      'it carries the thresholds, so a second implementation reads them too',
      () {
        final thresholds = fixture['thresholds']! as Map<String, Object?>;
        expect(thresholds['display'], 3.0);
        expect(thresholds['headline'], 3.0);
        expect(thresholds['titleL'], 4.5);
        expect(thresholds['titleM'], 4.5);
        expect(thresholds['nonText'], 3.0);
      },
    );
  });
}
