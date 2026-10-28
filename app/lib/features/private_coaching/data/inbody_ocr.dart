/// Reads an InBody result sheet on the phone: she chooses a photo or a
/// screenshot, the phone's text recognition reads it, and no copy is left
/// behind. The picture never leaves the phone.
library;

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/inbody_scan.dart';

abstract class InBodyOcr {
  /// The sheet's text, one row per row of the picture. Null when she chose
  /// nothing; empty when nothing could be read. Never throws.
  Future<String?> readPhoto();
}

/// ML Kit, Latin script: labels in Arabic are not read, and she types those
/// numbers into the same form.
class MlKitInBodyOcr implements InBodyOcr {
  @override
  Future<String?> readPhoto() async {
    XFile? picked;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (picked == null) return null;
      final result = await recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      return InBodyReader.rows([
        for (final block in result.blocks)
          for (final line in block.lines)
            InBodyLine(
              line.text,
              line.boundingBox.left,
              line.boundingBox.top,
              line.boundingBox.right,
              line.boundingBox.bottom,
            ),
      ]);
    } catch (_) {
      return '';
    } finally {
      try {
        await recognizer.close();
      } catch (_) {}
      try {
        if (picked != null) await File(picked.path).delete();
      } catch (_) {}
    }
  }
}
