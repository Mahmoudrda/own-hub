/// How big a captured frame is allowed to be, and how we know.
///
/// The target is about a thousand pixels on the long edge at JPEG quality 80.
/// That is enough for a server to read a national ID number off a card and far
/// less than a modern sensor wants to give: a Redmi Note will happily hand over
/// a nine megapixel, four megabyte photograph, and four megabytes of a woman's
/// ID card is a slow upload on Egyptian mobile data, a bigger bill on the
/// function's ingress, and not one extra digit legible at the other end.
///
/// **We cannot re-encode, so we choose the size at the lens instead.** There is
/// no JPEG encoder in the Dart SDK; `dart:ui` will re-encode only to PNG, and a
/// PNG of a photograph is several times larger than the JPEG it started as, so
/// "compressing" that way would make the problem worse. `package:image` would
/// do it and is not a declared dependency of this app. So the size is set by
/// the resolution preset the camera is opened at, and this file's job is to
/// *verify* that, rather than assume it: [jpegLongEdge] reads the real
/// dimensions back out of the bytes the platform produced, because a preset is
/// a request and some devices ignore it.
library;

import 'dart:typed_data';

import 'package:camera/camera.dart' show ResolutionPreset;

/// What we would ask for if the plugin let us name a number.
const int targetLongEdge = 1000;

/// What we actually ask for.
///
/// `ResolutionPreset.high` is 1280 by 720, so the long edge lands at 1280:
/// 28 percent more than we want, and the nearest the plugin offers at or above
/// the target. The step down, `medium`, is 640 by 480, and 640 pixels across a
/// card is not enough for the fourteen digit number, which is the one thing on
/// it that has to be read. Overshooting costs roughly sixty kilobytes; falling
/// short costs the check.
const ResolutionPreset captureResolution = ResolutionPreset.high;

/// Above this a frame is out of budget and something is wrong.
///
/// A 1280 by 720 JPEG of a document at quality 80 runs about 150 to 250 KB. A
/// megabyte means the device ignored the preset, and three sides plus liveness
/// frames at that size is a multi-megabyte upload on a connection that may be
/// EDGE. Nothing refuses the capture over this, because failing a woman's
/// sign-up to save bandwidth is the wrong trade, but it is asserted in tests
/// and logged in debug so it is visible rather than merely expensive.
const int frameByteCeiling = 700 * 1024;

/// The long edge of a JPEG, read from its own header, or null if the bytes are
/// not a JPEG we can parse.
///
/// Walks the marker segments looking for a start-of-frame. There are several
/// of those: `SOF0` is a baseline JPEG, `SOF2` is progressive, and phone
/// encoders emit both. `DNL`, the restart markers and the standalone markers
/// carry no length field and are skipped rather than mis-parsed, which is what
/// a naive "find 0xFFC0" scan gets wrong when the bytes happen to appear inside
/// the EXIF thumbnail that most phone cameras embed.
int? jpegLongEdge(Uint8List bytes) {
  final size = jpegSize(bytes);
  return size == null ? null : (size.$1 > size.$2 ? size.$1 : size.$2);
}

/// Width and height, in that order.
(int, int)? jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      // Not aligned on a marker. Resynchronise rather than give up: a padding
      // byte between segments is legal and appears in the wild.
      offset++;
      continue;
    }
    final marker = bytes[offset + 1];
    offset += 2;

    // Padding fill bytes, and the standalone markers that carry no payload.
    if (marker == 0xFF) {
      offset--;
      continue;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) continue;

    if (offset + 1 >= bytes.length) return null;
    final length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2) return null;

    final isStartOfFrame =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 && // DHT, the Huffman tables
        marker != 0xC8 && // JPG, reserved
        marker != 0xCC; //  DAC, arithmetic coding conditioning
    if (isStartOfFrame) {
      // Segment layout: length (2), precision (1), height (2), width (2).
      if (offset + 6 >= bytes.length) return null;
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      return (width, height);
    }

    // Start of scan: the entropy-coded data follows and there is no more
    // header to read.
    if (marker == 0xDA) return null;

    offset += length;
  }
  return null;
}

/// Whether a captured frame is the size we expected.
///
/// Both halves matter. A frame far over [frameByteCeiling] is an upload
/// problem; a frame whose long edge is under [targetLongEdge] is a legibility
/// problem, and a device that silently gave us 640 pixels is the reason a card
/// will not read no matter how steadily she holds it.
bool frameIsWithinBudget(Uint8List jpeg) {
  if (jpeg.length > frameByteCeiling) return false;
  final longEdge = jpegLongEdge(jpeg);
  return longEdge != null && longEdge >= targetLongEdge;
}
