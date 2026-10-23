/// Whether a meal photo has any light in it, decided on the phone.
///
/// A photo taken in a dark room, or with a finger over the lens, reads as no
/// food and still costs one of her five scans. So before anything is sent the
/// frame is decoded at a thumbnail size and its mean brightness (Rec. 601
/// luma, 0 to 255) is measured. Below [kMealFrameMinLuma] it is refused with
/// "too dark" and she is asked to retake. Nothing is kept: the thumbnail is
/// disposed as soon as it is measured, and the photo itself is not touched.
///
/// A frame with no picture in it at all, a white wall or a lens pressed to a
/// sleeve, is refused the same way: its brightness can be fine and it is just
/// as unreadable. That is measured with the contrast of
/// `signup/data/frame_quality.dart` (the spread of brightness), at a bar far
/// below the ID-card gate's, because this only has to catch a flat frame and
/// never to judge a plate. Blur is not judged here: the sharpness number there
/// is calibrated for a card at preview size and means nothing on a 24 pixel
/// thumbnail.
///
/// A frame that cannot be decoded here is let through: the server judges it,
/// and a check that fails closed on its own error would refuse good photos.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../signup/data/frame_quality.dart';

/// The mean luma under which a frame is too dark to read food from. A dim
/// kitchen at night sits near 50; a covered lens near 0.
const double kMealFrameMinLuma = 28;

/// The spread of brightness (standard deviation, 0 to 255) under which a frame
/// is blank. A photographed meal, even a pale one on a white plate, sits well
/// above it; a flat wall or a covered lens reads under 3.
const double kMealFrameMinContrast = 6;

/// The width the frame is shrunk to for the blank check: wide enough that the
/// contrast measure, which reads one pixel in sixteen, sees a few hundred.
const int kMealFrameBlankProbeWidth = 96;

/// The width the frame is shrunk to before it is measured.
const int kMealFrameProbeWidth = 24;

/// The mean luma of [image] (RGBA, 8 bits), 0 to 255, or null when empty.
double? meanLuma(Uint8List rgba) {
  final pixels = rgba.length ~/ 4;
  if (pixels == 0) return null;
  var sum = 0.0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    sum += 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
  }
  return sum / pixels;
}

/// The thumbnail of [photo] as RGBA, or null when it cannot be decoded.
Future<({Uint8List rgba, int width, int height})?> _probe(
  Uint8List photo, {
  int width = kMealFrameProbeWidth,
}) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    codec = await ui.instantiateImageCodec(photo, targetWidth: width);
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return (
      rgba: data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

/// True when [photo] decodes and is darker than [kMealFrameMinLuma].
Future<bool> mealFrameIsTooDark(Uint8List photo) async {
  final probe = await _probe(photo);
  if (probe == null) return false;
  final luma = meanLuma(probe.rgba);
  return luma != null && luma < kMealFrameMinLuma;
}

/// The spread of brightness across an RGBA thumbnail, by the same measure the
/// ID-card gate reads, or null when it has no pixels.
double? thumbnailContrast(Uint8List rgba, int width, int height) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return null;
  }
  final quality = measureFrame(
    luma: (x, y) {
      final at = (y * width + x) * 4;
      return (0.299 * rgba[at] + 0.587 * rgba[at + 1] + 0.114 * rgba[at + 2])
          .round();
    },
    width: width,
    height: height,
    left: 0,
    top: 0,
    right: width,
    bottom: height,
  );
  return quality.samples == 0 ? null : quality.contrast;
}

/// True when [photo] decodes and is a flat frame with nothing in it.
Future<bool> mealFrameIsBlank(Uint8List photo) async {
  final probe = await _probe(photo, width: kMealFrameBlankProbeWidth);
  if (probe == null) return false;
  final contrast = thumbnailContrast(probe.rgba, probe.width, probe.height);
  return contrast != null && contrast < kMealFrameMinContrast;
}
