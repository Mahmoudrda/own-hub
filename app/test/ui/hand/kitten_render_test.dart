// Renders every kitten pose to a PNG so the drawing can be looked at.
//
// Every pose at its final frame, plus two mid-move frames for wave, cheer and
// think, at 512 x 512 logical px on cream; and a contact sheet with every pose
// at 32, 56 and 128 dp for silhouette checks. In the normal suite it only
// renders and checks nothing throws, writing nothing. To write the PNGs:
//
//   cd app
//   KITTEN_RENDER_DIR=/path/to/folder \
//     flutter test test/ui/hand/kitten_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/hand/mascot/kitten_painter.dart';

import '../../store/store_screenshots_test.dart' show encodeOpaquePng;

const _cream = ui.Color(0xFFFCF8F2);
const _sizes = [32.0, 56.0, 128.0];
const _scale = 2.0;

String? get _outDir {
  final dir = Platform.environment['KITTEN_RENDER_DIR'];
  return dir == null || dir.isEmpty ? null : dir;
}

/// [pose] drawn at [u] of its run into a square of [dp] at the origin.
void _draw(
  ui.Canvas canvas,
  KittenPose pose,
  double u,
  double dp, [
  KittenProp? prop,
]) {
  KittenPainter(
    progress: AlwaysStoppedAnimation<double>(u),
    pose: pose,
    rtl: false,
    prop: prop,
  ).paint(canvas, ui.Size(dp, dp));
}

Future<ui.Image> _render(
  int width,
  int height,
  void Function(ui.Canvas canvas) body,
) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = _cream,
  );
  body(canvas);
  return recorder.endRecording().toImage(width, height);
}

Future<void> _write(ui.Image image, String path) async {
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(
    encodeOpaquePng(rgba!.buffer.asUint8List(), image.width, image.height),
  );
  image.dispose();
}

void main() {
  /// Where in its run each named still is, as a fraction of the whole run.
  Map<String, double> stills(KittenPose pose) {
    final run = kittenRunFor(pose).inMilliseconds;
    final out = {'${pose.name}-final': 1.0};
    if (pose == KittenPose.wave ||
        pose == KittenPose.cheer ||
        pose == KittenPose.think) {
      out['${pose.name}-mid1'] = 0.35 * pose.moveMs / run;
      out['${pose.name}-mid2'] = 0.65 * pose.moveMs / run;
    }
    return out;
  }

  testWidgets('every pose renders at 512 px on cream', (tester) async {
    await tester.runAsync(() async {
      for (final pose in KittenPose.values) {
        for (final e in stills(pose).entries) {
          final image = await _render(
            512,
            512,
            (c) => _draw(
              c,
              pose,
              e.value,
              512,
              pose == KittenPose.lift ? KittenProp.dumbbell : null,
            ),
          );
          expect(image.width, 512, reason: e.key);
          final dir = _outDir;
          if (dir != null) {
            await _write(image, '$dir/${e.key}.png');
          } else {
            image.dispose();
          }
        }
      }
    });
  });

  testWidgets('every prop renders in hand', (tester) async {
    await tester.runAsync(() async {
      const held = {
        KittenProp.dumbbell: KittenPose.lift,
        KittenProp.heart: KittenPose.rest,
        KittenProp.tickCard: KittenPose.rest,
      };
      for (final e in held.entries) {
        final image = await _render(
          512,
          512,
          (c) => _draw(c, e.value, 1, 512, e.key),
        );
        final dir = _outDir;
        if (dir != null) {
          await _write(image, '$dir/prop-${e.key.name}.png');
        } else {
          image.dispose();
        }
      }
    });
  });

  testWidgets('the contact sheet shows every pose at 32, 56 and 128 dp', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const pad = 12.0;
      final poses = KittenPose.values;
      final rowH = 128 + pad;
      final width = ((32 + 56 + 128 + pad * 4) * _scale).round();
      final height = ((rowH * poses.length + pad) * _scale).round();
      final image = await _render(width, height, (c) {
        c.scale(_scale);
        for (final (i, pose) in poses.indexed) {
          var x = pad;
          final top = pad + i * rowH;
          for (final dp in _sizes) {
            c.save();
            c.translate(x, top + (128 - dp));
            _draw(c, pose, 1, dp);
            c.restore();
            x += dp + pad;
          }
        }
      });
      final dir = _outDir;
      if (dir != null) {
        await _write(image, '$dir/sheet.png');
      } else {
        image.dispose();
      }
    });
  });
}
