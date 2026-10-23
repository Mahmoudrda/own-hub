// A coach photo leaves the phone without EXIF, vendor blocks or comments, and
// still decodes. Anything that is not a well-formed JPEG is left alone.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/data/strip_jpeg_metadata.dart';

// An 1x1 JPEG that already carries an Exif APP1 and a Photoshop APP13.
const String _sample =
    '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMACQkJCQkJEAkJEBYQEBAWHhYWFhYeJh4eHh4eJi4mJiYmJiYuLi4uLi4uLjc3Nzc3N0BAQEBASEhISEhISEhISP/bAEMBCwwMEhESHxERH0szKjNLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS//dAAQAAf/aAAwDAQACEQMRAD8A6KiiiuA+vP/Z';

Uint8List _segment(int marker, List<int> payload) {
  final length = payload.length + 2;
  return Uint8List.fromList([
    0xFF,
    marker,
    length >> 8,
    length & 0xFF,
    ...payload,
  ]);
}

/// The marker bytes of every segment before the scan.
List<int> _markers(Uint8List jpeg) {
  final found = <int>[];
  var i = 2;
  while (i + 3 < jpeg.length) {
    final marker = jpeg[i + 1];
    found.add(marker);
    if (marker == 0xDA) break;
    i += 2 + ((jpeg[i + 2] << 8) | jpeg[i + 3]);
  }
  return found;
}

/// An Exif APP1 with an Orientation entry and a pointer to a GPS IFD.
Uint8List _exif({required bool little, required int orientation}) {
  List<int> u16(int v) => little ? [v & 0xFF, v >> 8] : [v >> 8, v & 0xFF];
  List<int> u32(int v) => little
      ? [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, v >> 24]
      : [v >> 24, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  final tiff = [
    ...(little ? [0x49, 0x49] : [0x4D, 0x4D]),
    ...u16(42),
    ...u32(8),
    ...u16(2),
    ...u16(0x0112), ...u16(3), ...u32(1), ...u16(orientation), 0, 0,
    ...u16(0x8825), ...u16(4), ...u32(1), ...u32(38),
    ...u32(0),
    // GPS IFD at 38: one entry, then no next.
    ...u16(1), ...u16(2), ...u16(2), ...u32(2), 0x4E, 0, 0, 0, ...u32(0),
  ];
  return _segment(0xE1, [...ascii.encode('Exif'), 0, 0, ...tiff]);
}

/// Tags in the first APP1 of [jpeg] (little-endian, as the stripper writes
/// it) and its Orientation value, or null with no APP1.
({List<int> tags, int orientation})? _readExif(Uint8List jpeg) {
  var i = 2;
  while (i + 3 < jpeg.length && jpeg[i + 1] != 0xDA) {
    final length = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (jpeg[i + 1] == 0xE1) {
      final t = i + 4 + 6;
      int u16(int at) => jpeg[at] | (jpeg[at + 1] << 8);
      final count = u16(t + 8);
      final tags = <int>[];
      var orientation = 0;
      for (var e = 0; e < count; e++) {
        final at = t + 10 + e * 12;
        tags.add(u16(at));
        if (u16(at) == 0x0112) orientation = u16(at + 8);
      }
      return (tags: tags, orientation: orientation);
    }
    i += 2 + length;
  }
  return null;
}

void main() {
  final sample = base64Decode(_sample);

  Uint8List withExtras() {
    final gps = _segment(0xE1, [
      ...ascii.encode('Exif'),
      0,
      0,
      ...List.filled(40, 7),
    ]);
    final comment = _segment(0xFE, ascii.encode('taken at home'));
    return Uint8List.fromList([
      ...sample.sublist(0, 2),
      ...gps,
      ...comment,
      ...sample.sublist(2),
    ]);
  }

  test('removes APP1 to APP15 and COM, keeps JFIF and the image', () {
    final input = withExtras();
    expect(_markers(input), containsAll([0xE1, 0xFE]));
    final out = stripJpegMetadata(input);
    final markers = _markers(out);
    expect(
      markers.where((m) => (m >= 0xE1 && m <= 0xEF) || m == 0xFE),
      isEmpty,
    );
    expect(markers, containsAll([0xE0, 0xDB, 0xC0, 0xC4, 0xDA]));
    expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
    expect(out.length, lessThan(input.length));
  });

  testWidgets('the cleaned file still decodes', (tester) async {
    final out = stripJpegMetadata(withExtras());
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(out);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1);
    });
  });

  test('non-JPEG and malformed data come back unchanged', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
    expect(identical(stripJpegMetadata(png), png), isTrue);
    final cut = Uint8List.fromList(withExtras().sublist(0, 30));
    expect(identical(stripJpegMetadata(cut), cut), isTrue);
    final empty = Uint8List(0);
    expect(identical(stripJpegMetadata(empty), empty), isTrue);
  });

  Uint8List withSegments(List<Uint8List> extra) => Uint8List.fromList([
    ...sample.sublist(0, 2),
    for (final e in extra) ...e,
    ...sample.sublist(2),
  ]);

  // The sample's own Exif and Photoshop blocks are in the way of counting.
  Uint8List bare() {
    final out = stripJpegMetadata(sample);
    return Uint8List.fromList(
      out,
    ); // orientation 1 or absent in the sample, so no APP1 remains
  }

  for (final little in [true, false]) {
    test('orientation 6 survives, GPS does not, little=$little', () {
      final input = withSegments([
        _exif(little: little, orientation: 6),
        _segment(0xE1, ascii.encode('http://ns.adobe.com/xap/1.0/\u0000<x/>')),
        _segment(0xFE, ascii.encode('note')),
      ]);
      final out = stripJpegMetadata(input);
      final exif = _readExif(out)!;
      expect(exif.tags, [0x0112]);
      expect(exif.orientation, 6);
      expect(_markers(out).where((m) => m == 0xE1), hasLength(1));
      expect(_markers(out), isNot(contains(0xFE)));
    });
  }

  test('orientation 1 leaves no APP1', () {
    final out = stripJpegMetadata(
      withSegments([_exif(little: true, orientation: 1)]),
    );
    expect(_readExif(out), isNull);
    expect(bare(), isNotEmpty);
  });

  test('malformed Exif is dropped without a crash', () {
    final bad = _segment(0xE1, [...ascii.encode('Exif'), 0, 0, 0x49, 0x49, 9]);
    final out = stripJpegMetadata(withSegments([bad]));
    expect(_readExif(out), isNull);
    final lying = _segment(0xE1, [
      ...ascii.encode('Exif'),
      0,
      0,
      0x49,
      0x49,
      42,
      0,
      8,
      0,
      0,
      0,
      0xFF,
      0x7F,
    ]);
    expect(_readExif(stripJpegMetadata(withSegments([lying]))), isNull);
  });

  testWidgets('a kept orientation block still decodes', (tester) async {
    final out = stripJpegMetadata(
      withSegments([_exif(little: false, orientation: 8)]),
    );
    expect(_readExif(out)!.orientation, 8);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(out);
      expect((await codec.getNextFrame()).image.width, 1);
    });
  });
}
