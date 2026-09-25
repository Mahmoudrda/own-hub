/// Deciding whether a preview frame is worth sending, on the phone, for free.
///
/// Every frame we reject here is an OCR call we do not pay for and a two day
/// round trip she does not have. The failure this exists to stop is the one
/// that actually happens: a woman photographs her card in a hallway at night,
/// the frame is soft, nothing on screen says so, and she finds out on Thursday
/// that her application could not be read. The measurements below are cheap
/// enough to run on every preview frame on a phone that costs four thousand
/// pounds, which is the only kind of cheap that matters here.
///
/// **These are camera measurements, not judgements about her.** Nothing here
/// looks for a face, a person or an identity; it reads brightness and gradient
/// off a luma plane. The face detector is a separate step with a separate
/// purpose, and neither one ever decides the verification.
///
/// All of it is pure: a function from pixels to four numbers, with no camera,
/// no plugin and no platform channel, so it is tested against synthetic frames
/// rather than against a phone somebody has to hold.
library;

import 'dart:math' as math;

/// Reads the brightness of one pixel, 0 to 255.
///
/// A callback rather than a buffer because the two platforms hand us different
/// memory. Android gives NV21, whose first `width * height` bytes are the luma
/// plane already. iOS gives BGRA, where luma has to be mixed from three
/// channels. Both collapse to "what is the brightness at x, y", and everything
/// below is written against that and nothing else.
typedef LumaAt = int Function(int x, int y);

/// What one frame measured.
class FrameQuality {
  const FrameQuality({
    required this.sharpness,
    required this.meanLuma,
    required this.contrast,
    required this.glare,
    required this.samples,
  });

  /// Variance of the Laplacian over the sampled region.
  ///
  /// The standard blur metric, and standard for a good reason: the Laplacian is
  /// a second derivative, so it answers "how fast does brightness change" and a
  /// blurred image has no fast changes anywhere. Low variance means every edge
  /// in the frame is smeared. It is scale dependent, which is why [sampleStep]
  /// is fixed rather than tuned per device: change the step and every threshold
  /// below means something different.
  final double sharpness;

  /// Average brightness, 0 to 255.
  final double meanLuma;

  /// Standard deviation of brightness.
  ///
  /// The cheapest available answer to "is the card actually inside the guide".
  /// A printed ID card is dark text on a light field with a photograph on it,
  /// so it has high spread; a wall, a table top or a lap does not. It does not
  /// tell us the card's corners are inside the rectangle, which is a genuine
  /// gap and is written down as one at [CardFrameGate].
  final double contrast;

  /// Fraction of samples at or above 250, which is a blown highlight.
  ///
  /// Egyptian national ID cards are laminated, and a ceiling light reflecting
  /// off that lamination erases whatever is printed under it. The camera's own
  /// exposure will not fix it, because the rest of the frame is correctly
  /// exposed. She has to tilt the card, and nothing but this measurement is
  /// going to tell her so.
  final double glare;

  /// How many pixels were actually read. Zero means the region was empty and
  /// every number above is meaningless.
  final int samples;
}

/// Every Nth pixel, in both directions.
///
/// Four means one pixel in sixteen, which on a 1280 by 720 preview is about
/// fourteen thousand reads per frame inside the card rectangle. That runs in
/// well under a millisecond in Dart and leaves the frame budget to the preview
/// itself. It is a constant and not a parameter because [FrameQuality.sharpness]
/// is measured in units that depend on it, and a caller free to change it could
/// silently move every threshold in this file.
const int sampleStep = 4;

/// Measures one frame inside a rectangle.
///
/// [left], [top], [right] and [bottom] are pixel coordinates in the frame, and
/// are clamped, so a caller that computes a guide rectangle slightly off the
/// edge gets a smaller sample rather than a range error in the middle of a
/// camera callback.
FrameQuality measureFrame({
  required LumaAt luma,
  required int width,
  required int height,
  required int left,
  required int top,
  required int right,
  required int bottom,
}) {
  final x0 = math.max(sampleStep, left);
  final y0 = math.max(sampleStep, top);
  final x1 = math.min(width - sampleStep - 1, right);
  final y1 = math.min(height - sampleStep - 1, bottom);

  var samples = 0;
  var sum = 0.0;
  var sumSquares = 0.0;
  var lapSum = 0.0;
  var lapSumSquares = 0.0;
  var blown = 0;

  for (var y = y0; y <= y1; y += sampleStep) {
    for (var x = x0; x <= x1; x += sampleStep) {
      final centre = luma(x, y);
      // The four-neighbour Laplacian, one sample step out rather than one
      // pixel. At one pixel on a 720p preview the kernel mostly measures sensor
      // noise, which reads as sharpness and would pass a blurry card.
      final lap =
          4 * centre -
          luma(x - sampleStep, y) -
          luma(x + sampleStep, y) -
          luma(x, y - sampleStep) -
          luma(x, y + sampleStep);

      samples++;
      sum += centre;
      sumSquares += centre * centre;
      lapSum += lap;
      lapSumSquares += lap * lap;
      if (centre >= 250) blown++;
    }
  }

  if (samples == 0) {
    return const FrameQuality(
      sharpness: 0,
      meanLuma: 0,
      contrast: 0,
      glare: 0,
      samples: 0,
    );
  }

  final mean = sum / samples;
  final variance = math.max(0.0, sumSquares / samples - mean * mean);
  final lapMean = lapSum / samples;
  final lapVariance = math.max(
    0.0,
    lapSumSquares / samples - lapMean * lapMean,
  );

  return FrameQuality(
    sharpness: lapVariance,
    meanLuma: mean,
    contrast: math.sqrt(variance),
    glare: blown / samples,
    samples: samples,
  );
}

/// The thresholds, and what they cannot tell you.
///
/// **Every number here is a starting point, not a measurement.** They were
/// chosen from what the metrics mean rather than from a corpus of Egyptian ID
/// cards photographed on the phones Egyptian women actually own, because that
/// corpus does not exist yet. The one that matters most is [minSharpness]: too
/// high and a woman with a mid-range Oppo is told to hold still forever, too
/// low and we pay for OCR on mush. `MANUAL_QA.md` has the device matrix that
/// settles it, and until that is run these are honest guesses.
abstract final class CardFrameGate {
  /// Below this the frame is blurred. Variance of the Laplacian at
  /// [sampleStep], where a hand-held card in focus typically reads in the
  /// hundreds and a moving or out-of-focus one reads in the tens.
  static const double minSharpness = 110;

  /// Below this there is not enough light for [minSharpness] to mean anything:
  /// a dark frame has small gradients everywhere and would be called blurred
  /// when the real problem is the room.
  static const double minLuma = 55;

  /// Below this the rectangle is mostly a flat surface, so the card is not
  /// filling it. **This is a proxy and not a framing check.** A real "all four
  /// corners inside" needs quadrilateral detection, which is not in this app's
  /// dependencies, so the guide rectangle does the aiming and this only catches
  /// the case where she is too far back for the card to matter. A card held at
  /// an angle with one corner outside the guide will pass here and be rejected
  /// server side, which is the failure this file exists to reduce and does not
  /// eliminate.
  static const double minContrast = 24;

  /// Above this, more than one sample in eight is blown out, which on a
  /// laminated card means a reflection is sitting on the print.
  static const double maxGlare = 0.12;

  /// The one thing to say about this frame, or null when it is good enough.
  ///
  /// Ordered by what she can act on first. Light before sharpness, because in a
  /// dark room the sharpness number is noise and "hold still" would be a lie
  /// she cannot satisfy. Glare before contrast, because a reflection raises
  /// spread and would otherwise read as a perfectly framed card.
  static CaptureAdvice? advise(FrameQuality quality) {
    if (quality.samples == 0) return CaptureAdvice.tooDark;
    if (quality.meanLuma < minLuma) return CaptureAdvice.tooDark;
    if (quality.glare > maxGlare) return CaptureAdvice.glare;
    if (quality.contrast < minContrast) return CaptureAdvice.tooFar;
    if (quality.sharpness < minSharpness) return CaptureAdvice.blurred;
    return null;
  }
}

/// The same measurements, read for a face instead of a card.
///
/// **Two of the four card checks are wrong here and are deliberately not run.**
/// Glare is a card problem: a laminated document under a ceiling light loses
/// its print, while a woman standing by a window is merely brightly lit, and
/// "tilt the card to cut the glare" is a sentence with no card in it. Contrast
/// is a card problem too: it stands in for "is the document filling the guide",
/// a question the face detector answers directly and better.
///
/// What is left is the pair that means the same thing whatever is in front of
/// the lens. A dark frame is dark and a blurred frame is blurred.
abstract final class FaceFrameGate {
  static CaptureAdvice? advise(FrameQuality quality) {
    if (quality.samples == 0) return CaptureAdvice.tooDark;
    if (quality.meanLuma < CardFrameGate.minLuma) return CaptureAdvice.tooDark;
    if (quality.sharpness < CardFrameGate.minSharpness) {
      return CaptureAdvice.blurred;
    }
    return null;
  }
}

/// What a frame measurement concluded, before it is turned into copy.
///
/// Deliberately separate from `CaptureGuidance`: this file measures pixels and
/// knows nothing about screens, and keeping the two apart is what stops a
/// threshold change from quietly rewording an Arabic string.
enum CaptureAdvice { tooDark, glare, tooFar, blurred }
