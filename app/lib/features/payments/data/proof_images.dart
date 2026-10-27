library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/redaction_model.dart';

const int kMaxPickedBytes = 25 * 1024 * 1024;

/// Per picture. Three of them travel in one call as base64, and the server
/// refuses a raw picture over 5 MB, so 2 MB each stays well under both.
const int kMaxUploadBytes = 2 * 1024 * 1024;
const int kMaxImages = 3;
const int _outputWidth = 1080;

/// Asks the system photo picker for up to [kMaxImages] pictures. No library
/// permission is asked for (`requestFullMetadata: false`). An oversized file
/// is dropped, and the picker's own copy is deleted once read.
Future<List<Uint8List>> pickProofImages() async {
  final files = await ImagePicker().pickMultiImage(
    limit: kMaxImages,
    requestFullMetadata: false,
  );
  final cache = (await getTemporaryDirectory()).path;
  final out = <Uint8List>[];
  for (final f in files.take(kMaxImages)) {
    try {
      if (await f.length() <= kMaxPickedBytes) out.add(await f.readAsBytes());
    } finally {
      if (f.path.startsWith(cache)) {
        try {
          await File(f.path).delete();
        } catch (_) {}
      }
    }
  }
  return out;
}

/// A picture with more pixels than this is refused before it is decoded
/// (a small file can still hold a huge canvas).
const int _maxPixels = 40 * 1000 * 1000;

/// Decodes at most [_outputWidth] pixels wide (a bigger picture is scaled
/// down while it is decoded, a smaller one is left alone). Null when it
/// cannot be read or holds too many pixels.
Future<ui.Image?> decodeCapped(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (desc.width <= 0 ||
          desc.height <= 0 ||
          desc.width * desc.height > _maxPixels) {
        return null;
      }
      final codec = await desc.instantiateCodec(
        targetWidth: desc.width > _outputWidth ? _outputWidth : null,
      );
      return (await codec.getNextFrame()).image;
    } finally {
      desc.dispose();
    }
  } catch (_) {
    return null;
  } finally {
    buffer?.dispose();
  }
}

/// The picture as PNG bytes (no metadata of any kind).
Future<Uint8List?> toPng(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer
        .asUint8List();

/// Draws the picture with the black boxes and the crop applied and returns a
/// PNG. PNG from dart:ui carries no EXIF or other metadata. When the result is
/// over [kMaxUploadBytes] it is drawn again smaller; null if still too big.
Future<Uint8List?> renderRedacted(ui.Image src, RedactionModel m) async {
  for (final scale in const [1.0, 0.7, 0.5]) {
    final bytes = await _render(src, m, scale);
    if (bytes == null) return null;
    if (bytes.length <= kMaxUploadBytes) return bytes;
  }
  return null;
}

Future<Uint8List?> _render(ui.Image src, RedactionModel m, double scale) async {
  final crop =
      m.crop ??
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final dst = ui.Rect.fromLTWH(0, 0, crop.width * scale, crop.height * scale);
  canvas.drawImageRect(
    src,
    crop,
    dst,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final black = ui.Paint()..color = const ui.Color(0xFF000000);
  for (final b in m.blackouts) {
    final inter = b.intersect(crop);
    if (inter.isEmpty) continue;
    canvas.drawRect(
      ui.Rect.fromLTWH(
        (inter.left - crop.left) * scale,
        (inter.top - crop.top) * scale,
        inter.width * scale,
        inter.height * scale,
      ),
      black,
    );
  }
  final image = await recorder.endRecording().toImage(
    dst.width.round(),
    dst.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
