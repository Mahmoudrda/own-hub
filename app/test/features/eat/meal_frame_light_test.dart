// The meal camera asks the lens for a small picture, and a frame with no
// light in it is refused on the phone before anything is sent.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' show ResolutionPreset;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/data/meal_camera.dart';
import 'package:own_hub/features/eat/data/meal_frame_light.dart';
import 'package:own_hub/features/signup/data/frame_budget.dart';

Future<Uint8List> _png(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 64, 48), Paint()..color = color);
  final image = await recorder.endRecording().toImage(64, 48);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _textured() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var x = 0; x < 8; x++) {
    for (var y = 0; y < 6; y++) {
      canvas.drawRect(
        Rect.fromLTWH(x * 8.0, y * 8.0, 8, 8),
        Paint()..color = (x + y) % 2 == 0 ? Colors.black : Colors.white,
      );
    }
  }
  final image = await recorder.endRecording().toImage(64, 48);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the capture size', () {
    test('meal photos ask for at most 768 pixels on the long edge', () {
      expect(kMealCaptureResolution, ResolutionPreset.medium);
      expect(kMealCaptureLongEdge, lessThanOrEqualTo(768));
    });

    test('the camera opens at that preset by default', () {
      expect(PluginMealCamera().resolution, kMealCaptureResolution);
    });

    test('the ID photos keep their own, larger preset', () {
      expect(captureResolution, ResolutionPreset.high);
      expect(captureResolution, isNot(kMealCaptureResolution));
    });
  });

  group('too dark to read', () {
    test('mean luma is the weighted brightness of the pixels', () {
      expect(meanLuma(Uint8List.fromList([0, 0, 0, 255])), 0);
      expect(
        meanLuma(Uint8List.fromList([255, 255, 255, 255])),
        closeTo(255, 0.01),
      );
      expect(meanLuma(Uint8List(0)), isNull);
    });

    testWidgets('a black frame is refused, a lit one is not', (tester) async {
      await tester.runAsync(() async {
        expect(await mealFrameIsTooDark(await _png(Colors.black)), isTrue);
        expect(
          await mealFrameIsTooDark(await _png(const Color(0xFF0A0A0A))),
          isTrue,
        );
        expect(
          await mealFrameIsTooDark(await _png(const Color(0xFF8A7A66))),
          isFalse,
        );
        expect(await mealFrameIsTooDark(await _png(Colors.white)), isFalse);
      });
    });

    testWidgets('a blank frame is refused, a textured one is not', (
      tester,
    ) async {
      await tester.runAsync(() async {
        expect(await mealFrameIsBlank(await _png(Colors.white)), isTrue);
        expect(
          await mealFrameIsBlank(await _png(const Color(0xFF8A7A66))),
          isTrue,
          reason: 'flat is flat at any brightness',
        );
        expect(await mealFrameIsBlank(await _textured()), isFalse);
      });
    });

    test('contrast is the spread of brightness, by the ID gate\'s measure', () {
      final flat = Uint8List.fromList(List.filled(24 * 24 * 4, 128));
      expect(thumbnailContrast(flat, 24, 24), 0);
      final stripes = Uint8List(24 * 24 * 4);
      for (var i = 0; i < 24 * 24; i++) {
        final v = ((i % 24) ~/ 8).isEven ? 20 : 220;
        stripes.setRange(i * 4, i * 4 + 4, [v, v, v, 255]);
      }
      expect(
        thumbnailContrast(stripes, 24, 24)!,
        greaterThan(kMealFrameMinContrast),
      );
      expect(thumbnailContrast(Uint8List(0), 24, 24), isNull);
    });

    testWidgets('bytes that cannot be decoded are left for the server', (
      tester,
    ) async {
      await tester.runAsync(() async {
        expect(
          await mealFrameIsTooDark(Uint8List.fromList([0xFF, 0xD8, 1, 2, 3])),
          isFalse,
        );
        expect(
          await mealFrameIsBlank(Uint8List.fromList([0xFF, 0xD8, 1, 2, 3])),
          isFalse,
        );
      });
    });
  });
}
