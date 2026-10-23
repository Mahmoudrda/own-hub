// The three pure pieces of the ID capture: how big a frame is, whether it is
// worth sending, and what happens to it afterwards.
//
// All of it runs without a camera, which is the point. A sharpness threshold
// that can only be checked by holding a phone is a threshold nobody checks.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/data/frame_budget.dart';
import 'package:own_hub/features/signup/data/frame_quality.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/verification_evidence.dart';

/// The smallest thing a JPEG parser has to cope with: a start marker, one
/// segment with a length it has to skip, and a start-of-frame carrying the
/// size. [appLength] pads the segment the parser must step over, so a parser
/// that ignored lengths and scanned for 0xFFC0 would read the padding instead.
Uint8List _jpeg({
  required int width,
  required int height,
  int marker = 0xC0,
  int appLength = 16,
}) {
  final bytes = <int>[
    0xFF, 0xD8, // SOI
    0xFF, 0xE0, // APP0
    (appLength >> 8) & 0xFF, appLength & 0xFF,
    ...List<int>.filled(appLength - 2, 0x00),
    0xFF, marker, // SOFn
    0x00, 0x11, // length 17
    0x08, // 8 bit precision
    (height >> 8) & 0xFF, height & 0xFF,
    (width >> 8) & 0xFF, width & 0xFF,
    0x03, // components
    ...List<int>.filled(9, 0x01),
  ];
  return Uint8List.fromList(bytes);
}

void main() {
  group('frame budget', () {
    test('reads the size out of a baseline JPEG', () {
      expect(jpegSize(_jpeg(width: 1280, height: 720)), (1280, 720));
      expect(jpegLongEdge(_jpeg(width: 1280, height: 720)), 1280);
      // Portrait: the long edge is the height, not the width. A capture
      // rotated by the platform must not read as half the resolution.
      expect(jpegLongEdge(_jpeg(width: 720, height: 1280)), 1280);
    });

    test('reads a progressive JPEG too', () {
      // SOF2. Phone encoders emit both, and a parser that only knew SOF0 would
      // silently report "not a JPEG" for half the devices in the field.
      expect(
        jpegLongEdge(_jpeg(width: 1600, height: 1200, marker: 0xC2)),
        1600,
      );
    });

    test('is not fooled by a marker-shaped byte inside a segment', () {
      // The padding in the APP0 segment below contains 0xFF 0xC0, which is what
      // an EXIF thumbnail does in real life. Skipping by the declared length is
      // the difference between reading the real size and reading the thumbnail.
      final bytes = <int>[
        0xFF, 0xD8,
        0xFF, 0xE0,
        0x00, 0x0A,
        0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x40, 0x00, // decoy, inside APP0
        0xFF, 0xC0,
        0x00, 0x11,
        0x08,
        0x02, 0xD0, // height 720
        0x05, 0x00, // width 1280
        0x03, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      ];
      expect(jpegSize(Uint8List.fromList(bytes)), (1280, 720));
    });

    test('says so rather than guessing when the bytes are not a JPEG', () {
      expect(jpegSize(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
      expect(jpegLongEdge(Uint8List(0)), isNull);
    });

    test('the budget catches both ways a frame can be wrong', () {
      final good = _jpeg(width: 1280, height: 720);
      expect(frameIsWithinBudget(good), isTrue);

      // Too small to read a fourteen digit number off, which is the failure
      // that looks like "the card will not scan" no matter how she holds it.
      expect(frameIsWithinBudget(_jpeg(width: 640, height: 480)), isFalse);

      // A device that ignored the resolution preset. Sent anyway in production,
      // because failing her sign-up to save bandwidth is the wrong trade, but
      // it must be visible.
      final huge = Uint8List(frameByteCeiling + 1);
      huge.setRange(0, good.length, good);
      expect(frameIsWithinBudget(huge), isFalse);
    });
  });

  group('frame quality', () {
    /// A flat grey field. No edges anywhere, which is what an out-of-focus
    /// frame and a blank wall have in common.
    LumaAt flat(int value) =>
        (x, y) => value;

    /// A hard black and white checker, the sharpest thing a luma plane can be.
    LumaAt checker(int size) =>
        (x, y) => ((x ~/ size) + (y ~/ size)).isEven ? 20 : 235;

    FrameQuality measure(LumaAt luma) => measureFrame(
      luma: luma,
      width: 400,
      height: 400,
      left: 50,
      top: 50,
      right: 350,
      bottom: 350,
    );

    test('a flat field reads as unsharp and low contrast', () {
      final quality = measure(flat(128));
      expect(quality.samples, greaterThan(1000));
      expect(quality.sharpness, lessThan(CardFrameGate.minSharpness));
      expect(quality.contrast, lessThan(CardFrameGate.minContrast));
      expect(quality.meanLuma, closeTo(128, 0.5));
    });

    test('a hard edged pattern reads as sharp and high contrast', () {
      final quality = measure(checker(sampleStep * 2));
      expect(quality.sharpness, greaterThan(CardFrameGate.minSharpness));
      expect(quality.contrast, greaterThan(CardFrameGate.minContrast));
      expect(CardFrameGate.advise(quality), isNull);
    });

    test('darkness is reported before blur, because blur cannot be measured '
        'in the dark', () {
      // A dark version of the sharp pattern: the gradients are small purely
      // because the whole frame is dim. "Hold still" would be advice she cannot
      // act on, and the light is the real problem.
      final dim = measure((x, y) => ((x ~/ 8) + (y ~/ 8)).isEven ? 2 : 24);
      expect(dim.meanLuma, lessThan(CardFrameGate.minLuma));
      expect(CardFrameGate.advise(dim), CaptureAdvice.tooDark);
    });

    test(
      'a reflection across the card is reported as glare, not as framing',
      () {
        // Bright and detailed, so contrast and sharpness both pass, but a fifth
        // of the frame is blown out. Without the glare arm this reads as a
        // perfectly framed card and the print under the reflection is gone.
        final glared = measure((x, y) {
          if (x > 150 && x < 230) return 255;
          return ((x ~/ 8) + (y ~/ 8)).isEven ? 60 : 200;
        });
        expect(glared.glare, greaterThan(CardFrameGate.maxGlare));
        expect(CardFrameGate.advise(glared), CaptureAdvice.glare);
      },
    );

    test('a lit but featureless frame reads as too far away', () {
      // Bright, gently varying, no print: the guide rectangle is looking at a
      // table, not at a card.
      final table = measure((x, y) => 150 + (math.sin(x / 90) * 3).round());
      expect(table.meanLuma, greaterThan(CardFrameGate.minLuma));
      expect(CardFrameGate.advise(table), CaptureAdvice.tooFar);
    });

    test('a face is not judged on glare or on contrast', () {
      // "Tilt the card to cut the glare" is a sentence with no card in it, and
      // a woman standing by a window would get it every time. The face gate
      // runs only the two checks that mean the same thing whatever is in front
      // of the lens.
      final brightAndSharp = measure((x, y) {
        if (x > 150 && x < 230) return 255;
        return ((x ~/ 8) + (y ~/ 8)).isEven ? 60 : 200;
      });
      expect(CardFrameGate.advise(brightAndSharp), CaptureAdvice.glare);
      expect(FaceFrameGate.advise(brightAndSharp), isNull);

      // Dark and blurred still mean what they mean.
      expect(FaceFrameGate.advise(measure(flat(10))), CaptureAdvice.tooDark);
      expect(FaceFrameGate.advise(measure(flat(150))), CaptureAdvice.blurred);
    });

    test('an empty region measures nothing and says so', () {
      final nothing = measureFrame(
        luma: flat(128),
        width: 10,
        height: 10,
        left: 100,
        top: 100,
        right: 200,
        bottom: 200,
      );
      expect(nothing.samples, 0);
      // Not "perfect": a measurement of nothing must not read as a pass.
      expect(CardFrameGate.advise(nothing), CaptureAdvice.tooDark);
    });
  });

  group('rule 7 — the evidence is wiped, not dropped', () {
    test('shred overwrites the bytes in place', () {
      final evidence = VerificationEvidence();
      final front = Uint8List.fromList(List<int>.filled(64, 0xAB));
      final back = Uint8List.fromList(List<int>.filled(64, 0xCD));
      final frame = Uint8List.fromList(List<int>.filled(32, 0xEF));

      evidence.holdCardSide(CaptureTarget.idFront, front);
      evidence.holdCardSide(CaptureTarget.idBack, back);
      evidence.addFrame(frame);
      expect(evidence.isComplete, isTrue);
      expect(evidence.byteCount, 160);

      evidence.shred();

      expect(evidence.isEmpty, isTrue);
      expect(evidence.byteCount, 0);
      // The buffers the caller still holds a reference to are zeroed, which is
      // the whole difference between "we let go of it" and "it is gone". A
      // dropped reference leaves a photograph of a national ID card in the heap
      // for as long as the collector feels like it.
      expect(front.every((byte) => byte == 0), isTrue);
      expect(back.every((byte) => byte == 0), isTrue);
      expect(frame.every((byte) => byte == 0), isTrue);
    });

    test('retaking a side wipes the attempt it replaces', () {
      final evidence = VerificationEvidence();
      final first = Uint8List.fromList(List<int>.filled(16, 0x11));
      evidence.holdCardSide(CaptureTarget.idFront, first);
      evidence.holdCardSide(
        CaptureTarget.idFront,
        Uint8List.fromList(List<int>.filled(16, 0x22)),
      );

      expect(first.every((byte) => byte == 0), isTrue);
      expect(evidence.front!.first, 0x22);
    });

    test('shredding twice is safe', () {
      final evidence = VerificationEvidence()
        ..holdCardSide(CaptureTarget.idFront, Uint8List(8))
        ..shred()
        ..shred();
      expect(evidence.isEmpty, isTrue);
    });

    test('one side of the card is not a cheaper version of the check', () {
      // The word printed on the back is an independent reading of the sex the
      // 13th digit carries. A server given only the front can cross-check
      // nothing, so "complete" must mean both.
      final evidence = VerificationEvidence()
        ..holdCardSide(CaptureTarget.idFront, Uint8List(8))
        ..addFrame(Uint8List(8));
      expect(evidence.isComplete, isFalse);

      evidence.holdCardSide(CaptureTarget.idBack, Uint8List(8));
      expect(evidence.isComplete, isTrue);
    });
  });
}
