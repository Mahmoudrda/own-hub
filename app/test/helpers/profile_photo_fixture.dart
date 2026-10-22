// Pictures and a fake picker for the profile photo tests. Nothing here touches
// the platform: the picker hands back a real file in a temp folder, the way
// the system picker hands back its own copy.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:own_hub/app_state/profile_photo_state.dart';

/// A picture [width] x [height], left half [left], right half [right], as PNG.
Future<Uint8List> twoToneImage(
  int width,
  int height, {
  ui.Color left = const ui.Color(0xFFFF0000),
  ui.Color right = const ui.Color(0xFF0000FF),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    ui.Paint()..color = left,
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
    ui.Paint()..color = right,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The chunk names of a PNG, in order.
List<String> pngChunkNames(Uint8List png) {
  final names = <String>[];
  final view = ByteData.sublistView(png);
  var at = 8;
  while (at + 8 <= png.length) {
    final length = view.getUint32(at);
    names.add(String.fromCharCodes(png.sublist(at + 4, at + 8)));
    at += 12 + length;
  }
  return names;
}

/// [png] with a text chunk and an EXIF chunk spliced in after the header, the
/// way a camera picture carries its location.
Uint8List withMetadata(Uint8List png) {
  final headerEnd = 8 + 12 + 13;
  final gps = _chunk(
    'tEXt',
    'GPSLatitude\u000030.0444;GPSLongitude\u000031.2357'.codeUnits,
  );
  final exif = _chunk('eXIf', 'MM\u0000*GPS-30.0444N-31.2357E'.codeUnits);
  return Uint8List.fromList(<int>[
    ...png.sublist(0, headerEnd),
    ...gps,
    ...exif,
    ...png.sublist(headerEnd),
  ]);
}

List<int> _chunk(String name, List<int> body) {
  final type = name.codeUnits;
  final out = BytesBuilder();
  final length = ByteData(4)..setUint32(0, body.length);
  out.add(length.buffer.asUint8List());
  out.add(type);
  out.add(body);
  final crc = ByteData(4)..setUint32(0, _crc32(<int>[...type, ...body]));
  out.add(crc.buffer.asUint8List());
  return out.toBytes();
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// The colour of one pixel of an encoded picture, as 0xAARRGGBB.
Future<int> pixelAt(Uint8List png, int x, int y) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final at = (y * image.width + x) * 4;
  final b = data!;
  final value =
      (b.getUint8(at + 3) << 24) |
      (b.getUint8(at) << 16) |
      (b.getUint8(at + 1) << 8) |
      b.getUint8(at + 2);
  image.dispose();
  codec.dispose();
  return value;
}

/// Size of an encoded picture.
Future<ui.Size> sizeOf(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final size = ui.Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  codec.dispose();
  return size;
}

/// Answers every pick with a new file in [folder], or with [result].
class FakePhotoPicker implements ProfilePhotoPicker {
  FakePhotoPicker(this.folder, {this.bytes, this.error, this.cancels = false});

  final Directory folder;
  final Uint8List? bytes;
  final Object? error;
  final bool cancels;

  final List<PhotoSource> asked = <PhotoSource>[];
  final List<String> handedOut = <String>[];

  @override
  Future<String?> pick(PhotoSource source) async {
    asked.add(source);
    if (error != null) throw error!;
    if (cancels) return null;
    final file = File('${folder.path}/picked_${handedOut.length}.jpg');
    await file.writeAsBytes(bytes ?? Uint8List.fromList(<int>[1, 2, 3]));
    handedOut.add(file.path);
    return file.path;
  }
}
