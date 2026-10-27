library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/proof_images.dart';
import '../data/receipt_ocr.dart';
import '../domain/receipt_reader.dart';
import '../domain/redaction_model.dart';
import 'redact_view.dart';

/// One picture after she hid private lines: the PNG that will be sent and the
/// text read from THAT png (phone and server read the same pixels).
class PreparedImage {
  const PreparedImage(this.png, this.text);
  final Uint8List png;
  final String text;
}

/// Returns null when she backs out of the "hide" step; throws
/// [FormatException] when the picture cannot be read or is too big.
typedef PrepareImage = Future<PreparedImage?> Function(
  BuildContext context,
  Uint8List raw,
  ExpectedPayment expected,
);

/// decode (capped) -> read it -> let her hide lines -> read the result.
Future<PreparedImage?> prepareProofImage(
  BuildContext context,
  Uint8List raw,
  ExpectedPayment expected, {
  ReceiptOcr? ocr,
}) async {
  final reader = ocr ?? MlKitReceiptOcr();
  final image = await decodeCapped(raw);
  if (image == null) throw const FormatException('unreadable picture');
  final capped = await toPng(image);
  if (capped == null) throw const FormatException('unreadable picture');
  final lines = await reader.read(capped);
  final model = RedactionModel(
    imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
    lines: lines,
    expected: expected,
  );
  if (!context.mounted) return null;
  final png = await Navigator.of(context).push<Uint8List?>(
    MaterialPageRoute<Uint8List?>(
      builder: (_) => RedactView(image: image, model: model),
    ),
  );
  if (png == null) return null;
  // Nothing hidden or cropped: the first reading is of the same pixels.
  final after = model.untouched ? lines : await reader.read(png);
  return PreparedImage(png, after.map((l) => l.text).join('\n'));
}
