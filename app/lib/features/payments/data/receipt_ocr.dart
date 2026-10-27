library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/redaction_model.dart';

abstract class ReceiptOcr {
  /// Lines of text with their boxes, top to bottom. Empty when nothing is read.
  /// Never throws: a failure is an empty list (the server still reads it).
  Future<List<OcrLine>> read(Uint8List png);
}

/// ML Kit, Latin script and digits. Works on a temporary file that is
/// deleted at once, so no picture is left behind.
class MlKitReceiptOcr implements ReceiptOcr {
  @override
  Future<List<OcrLine>> read(Uint8List png) async {
    File? file;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final dir = await getTemporaryDirectory();
      file = File(
        '${dir.path}/ocr-${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      return <OcrLine>[
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(
              line.text,
              Rect.fromLTRB(
                line.boundingBox.left,
                line.boundingBox.top,
                line.boundingBox.right,
                line.boundingBox.bottom,
              ),
            ),
      ];
    } catch (_) {
      return const <OcrLine>[];
    } finally {
      try {
        await recognizer.close();
      } catch (_) {}
      try {
        await file?.delete();
      } catch (_) {}
    }
  }
}
