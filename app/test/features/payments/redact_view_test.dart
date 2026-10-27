import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/events/domain/cairo_time.dart';
import 'package:own_hub/features/payments/data/proof_images.dart';
import 'package:own_hub/features/payments/data/receipt_ocr.dart';
import 'package:own_hub/features/payments/domain/receipt_reader.dart';
import 'package:own_hub/features/payments/domain/redaction_model.dart';
import 'package:own_hub/features/payments/presentation/proof_flow.dart';
import 'package:own_hub/features/payments/presentation/redact_view.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/payments_host.dart';

final expected = ExpectedPayment(
  amountPiasters: 50037,
  coachAddress: 'rahma.m@instapay',
  coachAccountName: 'Rahma Mohsen',
  createdAt: parseCairo('2026-10-27 14:00')!,
);

Future<ui.Image> makeImage(int w, int h) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return rec.endRecording().toImage(w, h);
}

RedactionModel emptyModel(int w, int h) => RedactionModel(
  imageSize: Size(w.toDouble(), h.toDouble()),
  lines: const [],
  expected: expected,
);

class _FakeOcr implements ReceiptOcr {
  _FakeOcr(this.lines);
  final List<OcrLine> lines;
  int reads = 0;
  @override
  Future<List<OcrLine>> read(Uint8List png) async {
    reads++;
    return lines;
  }
}

void main() {
  late ui.Image image;
  setUp(() {});

  Future<void> pumpView(
    WidgetTester tester,
    RedactionModel model, {
    String lang = 'en',
    double scale = 1,
    bool small = false,
  }) async {
    small ? smallPhone(tester) : phone(tester);
    image = (await tester.runAsync(() => makeImage(200, 400)))!;
    await tester.pumpWidget(
      host(
        RedactView(image: image, model: model),
        lang: lang,
        scale: scale,
      ),
    );
    await tester.pump();
  }

  testWidgets('a drag draws a black box and Undo removes it', (tester) async {
    final model = emptyModel(200, 400);
    await pumpView(tester, model);
    await tester.drag(
      find.byKey(const ValueKey('redact-surface')),
      const Offset(80, 80),
    );
    await tester.pump();
    expect(model.blackouts.length, 1);
    await tester.tap(find.byKey(const ValueKey('redact-undo')));
    await tester.pump();
    expect(model.blackouts, isEmpty);
  });

  testWidgets('a drag over a protected line draws nothing and says why', (
    tester,
  ) async {
    final model = RedactionModel(
      imageSize: const Size(200, 400),
      lines: const [OcrLine('500.37 EGP', Rect.fromLTWH(0, 0, 200, 400))],
      expected: expected,
    );
    await pumpView(tester, model);
    await tester.drag(
      find.byKey(const ValueKey('redact-surface')),
      const Offset(80, 80),
    );
    await tester.pump();
    expect(model.blackouts, isEmpty);
    expect(
      find.text('That part is needed to check your payment.'),
      findsOneWidget,
    );
  });

  testWidgets('Crop mode sets a crop and keeps it inside the picture', (
    tester,
  ) async {
    final model = emptyModel(200, 400);
    await pumpView(tester, model);
    await tester.tap(find.byKey(const ValueKey('mode-crop')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('redact-surface')),
      const Offset(150, 200),
    );
    await tester.pump();
    expect(model.crop, isNotNull);
  });

  testWidgets('Use this picture pops PNG bytes', (tester) async {
    phone(tester);
    image = (await tester.runAsync(() => makeImage(200, 400)))!;
    Uint8List? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await Navigator.of(context).push<Uint8List?>(
                  MaterialPageRoute<Uint8List?>(
                    builder: (_) =>
                        RedactView(image: image, model: emptyModel(200, 400)),
                  ),
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('use-picture')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('the back arrow leaves with nothing', (tester) async {
    phone(tester);
    image = (await tester.runAsync(() => makeImage(200, 400)))!;
    Uint8List? result = Uint8List(1);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await Navigator.of(context).push<Uint8List?>(
                  MaterialPageRoute<Uint8List?>(
                    builder: (_) =>
                        RedactView(image: image, model: emptyModel(200, 400)),
                  ),
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets(
    'renderRedacted: boxes are black, the crop sizes the output, nothing else changes',
    (tester) async {
      await tester.runAsync(() async {
        final src = await makeImage(200, 400);
        final model = emptyModel(200, 400)
          ..tryAddBlackout(const Rect.fromLTWH(20, 120, 60, 40))
          ..trySetCrop(const Rect.fromLTWH(0, 100, 200, 200));
        final png = (await renderRedacted(src, model))!;
        final out = await decodeCapped(png);
        expect(out!.width, 200);
        expect(out.height, 200);
        final data = (await out.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int px(int x, int y) => data.getUint32((y * 200 + x) * 4);
        expect(
          px(30, 30),
          0x000000FF,
          reason: 'inside the box (RGBA black, opaque)',
        );
        expect(px(150, 150), 0xFFFFFFFF, reason: 'outside the box');
      });
    },
  );

  testWidgets('decodeCapped returns null for garbage bytes', (tester) async {
    final r = await tester.runAsync(
      () => decodeCapped(Uint8List.fromList([1, 2, 3])),
    );
    expect(r, isNull);
  });

  testWidgets('a huge picture is decoded no wider than 1080 pixels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final big = await makeImage(4000, 600);
      final bytes = (await big.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      final out = await decodeCapped(bytes);
      expect(out!.width, lessThanOrEqualTo(1080));
    });
  });

  group('prepareProofImage', () {
    Future<PreparedImage?> run(
      WidgetTester tester,
      _FakeOcr ocr, {
      required bool draw,
    }) async {
      phone(tester);
      Uint8List png = Uint8List(0);
      await tester.runAsync(() async {
        final src = await makeImage(300, 600);
        png = (await src.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List();
      });
      PreparedImage? out;
      var done = false;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                out = await prepareProofImage(context, png, expected, ocr: ocr);
                done = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      if (draw) {
        await tester.drag(
          find.byKey(const ValueKey('redact-surface')),
          const Offset(60, 60),
        );
        await tester.pump();
      }
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('use-picture')));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();
      expect(done, isTrue);
      return out;
    }

    testWidgets('nothing hidden: the text is the first reading, read once', (
      tester,
    ) async {
      final ocr = _FakeOcr(const [
        OcrLine('500.37 EGP', Rect.fromLTWH(10, 10, 100, 20)),
      ]);
      final out = await run(tester, ocr, draw: false);
      expect(out!.text, '500.37 EGP');
      expect(ocr.reads, 1);
    });

    testWidgets(
      'something hidden: the picture that will be sent is read again',
      (tester) async {
        final ocr = _FakeOcr(const [
          OcrLine(
            'Transaction ID 123456789012',
            Rect.fromLTWH(10, 500, 100, 20),
          ),
        ]);
        final out = await run(tester, ocr, draw: true);
        expect(ocr.reads, 2);
        expect(out!.png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      },
    );
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget and layout, $lang at ${scale}x on ${small ? '375x667' : '390x844'}',
          (tester) async {
            await pumpView(
              tester,
              emptyModel(200, 400),
              lang: lang,
              scale: scale,
              small: small,
            );
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
            );
            expect(filledPrimaryActions(tester), 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
