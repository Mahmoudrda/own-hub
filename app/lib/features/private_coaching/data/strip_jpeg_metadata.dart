/// Removes the metadata segments from a JPEG before it leaves the phone.
///
/// The camera and the gallery picker can write her location and device into
/// the file (EXIF in APP1, other vendor blocks in APP2 to APP15) and a free
/// text comment (COM). Coach application and portfolio photos go to storage
/// before the server re-encodes them, so they are cleaned here first.
///
/// APP0 (JFIF), the tables, the frame header and the image data stay. The
/// Exif orientation is the one thing kept: a phone photo is often stored
/// sideways with only that tag saying how to turn it, so a small Exif block
/// with the orientation alone takes the place of the original. Anything that
/// is not a well-formed JPEG comes back unchanged.
library;

import 'dart:typed_data';

Uint8List stripJpegMetadata(Uint8List input) {
  try {
    return _strip(input);
  } catch (_) {
    return input;
  }
}

/// The Exif orientation (1 to 8) in the APP1 payload [p] (starting at the
/// segment's length bytes), or null when absent or unreadable.
int? _exifOrientation(Uint8List p, int start, int end) {
  const head = [0x45, 0x78, 0x69, 0x66, 0, 0];
  final tiff = start + 6;
  if (end - start < 6 + 8) return null;
  for (var k = 0; k < 6; k++) {
    if (p[start + k] != head[k]) return null;
  }
  final little = p[tiff] == 0x49 && p[tiff + 1] == 0x49;
  if (!little && !(p[tiff] == 0x4D && p[tiff + 1] == 0x4D)) return null;
  int u16(int at) =>
      little ? p[at] | (p[at + 1] << 8) : (p[at] << 8) | p[at + 1];
  int u32(int at) =>
      little ? u16(at) | (u16(at + 2) << 16) : (u16(at) << 16) | u16(at + 2);
  if (u16(tiff + 2) != 42) return null;
  final ifd = tiff + u32(tiff + 4);
  if (ifd < tiff || ifd + 2 > end) return null;
  final count = u16(ifd);
  for (var e = 0; e < count; e++) {
    final at = ifd + 2 + e * 12;
    if (at + 12 > end) return null;
    if (u16(at) == 0x0112) {
      if (u16(at + 2) != 3 || u32(at + 4) != 1) return null;
      final v = u16(at + 8);
      return v >= 1 && v <= 8 ? v : null;
    }
  }
  return null;
}

/// An Exif block holding the orientation and nothing else.
Uint8List _orientationOnly(int value) => Uint8List.fromList([
  0xFF, 0xE1, 0, 34, // marker, length
  0x45, 0x78, 0x69, 0x66, 0, 0, // "Exif\0\0"
  0x49, 0x49, 0x2A, 0, 8, 0, 0, 0, // little-endian TIFF header, IFD0 at 8
  1, 0, // one entry
  0x12, 0x01, 3, 0, 1, 0, 0, 0, value, 0, 0, 0, // Orientation, SHORT, 1
  0, 0, 0, 0, // no next IFD
]);

Uint8List _strip(Uint8List input) {
  var exifSeen = false;
  final n = input.length;
  if (n < 4 || input[0] != 0xFF || input[1] != 0xD8) return input;
  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var i = 2;
  while (i < n) {
    if (input[i] != 0xFF) return input;
    var j = i;
    while (j < n && input[j] == 0xFF) {
      j++;
    }
    if (j >= n) return input;
    final marker = input[j];
    final start = j - 1;
    i = j + 1;
    if (marker == 0xD9) {
      out.add(input.sublist(start, i));
      return out.toBytes();
    }
    // Markers that carry no length.
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      out.add(input.sublist(start, i));
      continue;
    }
    if (i + 2 > n) return input;
    final length = (input[i] << 8) | input[i + 1];
    if (length < 2 || i + length > n) return input;
    final end = i + length;
    if (marker == 0xDA) {
      // The scan and everything after it is image data, copied as it is.
      out.add(input.sublist(start, n));
      return out.toBytes();
    }
    if (marker == 0xE1 && !exifSeen) {
      final value = _exifOrientation(input, i + 2, end);
      if (value != null) {
        exifSeen = true;
        if (value > 1) out.add(_orientationOnly(value));
      }
    }
    final metadata = (marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE;
    if (!metadata) out.add(input.sublist(start, end));
    i = end;
  }
  // No scan found: not a usable JPEG.
  return input;
}
