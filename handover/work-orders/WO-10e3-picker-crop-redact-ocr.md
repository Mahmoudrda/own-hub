# WO-10e3: choose screenshots, hide private lines, read them on the phone
Depends on: WO-10e2
Size: L
Reads first: `app/pubspec.yaml` lines 70-80 and 130-134; `app/lib/features/private_coaching/presentation/apply/apply_photo.dart` lines 70-110 (how `ImagePicker` is called here); `app/lib/app_state/profile_photo_state.dart` lines 380-410 (`toByteData` PNG pattern); `app/lib/features/progress/presentation/share_progress_view.dart` lines 144-165 (`RepaintBoundary.toImage`); `app/lib/features/instapay/domain/receipt_reader.dart`; spec 13.3 and 13.13 items 6-7

## Why
Her bank screenshot may show card numbers, balances and limits. Before anything leaves her phone she can black out lines and crop, and Own Hub uploads only that copy (the original stays on her phone). The amount, the transaction number and the recipient lines are protected: if she hides those the proof is useless and the check would wrongly fail. The phone reads the text of the copy it will upload, so phone and server read the same pixels.

## Final result
After she taps "I have paid" (PAY1), PAY2 (WO-10e4) opens the system photo picker once; she selects up to 3 pictures (the receipt, the "More Details" screen, a bank SMS). For each picture a full-screen step "Hide private details" opens, top to bottom:
1. Top bar "Hide private details", back arrow (skips that picture).
2. Text: "Drag over anything private, like card numbers or balances. The amount, transaction number and name stay visible."
3. The picture, fitted, with lines the phone thinks are private already boxed in black (she can remove with Undo). Dragging draws a black box. A drag that touches a protected line shows the snackbar "That part is needed to check your payment." and draws nothing.
4. Two choice chips: "Black out" (default) and "Crop". In Crop mode a drag sets the crop rectangle; a crop that would cut a protected line is refused with the same snackbar.
5. A text button "Undo".
6. One line: "Only the hidden-detail copy leaves your phone. The original stays here."
7. Footer, the one primary: "Use this picture".
Controls above the fold: back, 2 chips, Undo (4 others) + 1 primary. The drag area is a gesture surface that is not a tap handler (it uses pan callbacks only), so the control counter does not count it.
A picture that cannot be decoded or is over 25 MB shows "This picture is too big or could not be read. Pick another." and is skipped.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/pubspec.yaml | edit | add `google_mlkit_text_recognition` |
| app/lib/features/instapay/domain/redaction_model.dart | create | pure rules: protected, suggested, black boxes, crop |
| app/lib/features/instapay/data/receipt_ocr.dart | create | `ReceiptOcr` interface and the ML Kit implementation |
| app/lib/features/instapay/data/proof_images.dart | create | picker, decode with a size cap, render the redacted PNG |
| app/lib/features/instapay/presentation/redact_view.dart | create | the "Hide private details" step |
| app/lib/features/instapay/data/firestore_instapay_repository.dart | edit | upload `.png` with `image/png` |
| app/test/features/instapay/redaction_model_test.dart | create | model tests |
| app/test/features/instapay/redact_view_test.dart | create | widget and render tests |

## Steps
1. File `app/pubspec.yaml`. Anchor: the line `google_mlkit_face_detection: ^0.15.1` (about line 76). Run, from `app/`: `flutter pub add google_mlkit_text_recognition` then `flutter pub get`. UNVERIFIED: the version that resolves with `google_mlkit_commons 0.13.0` (in `pubspec.lock`). If pub reports a conflict, run `flutter pub add google_mlkit_text_recognition:<version>` using the newest version whose `pubspec.yaml` says `google_mlkit_commons: ^0.13.0`, found with `flutter pub deps | grep mlkit` after trying; if none resolves, STOP and write the question to `handover/QUESTIONS.md` (do not downgrade the face detection package). Then check the pod target: `grep -n "platform :ios" app/ios/Podfile` must still be `15.5` or higher (ML Kit text recognition needs 15.5 or higher: UNVERIFIED). Add above the new line in `pubspec.yaml` this comment (the file explains every dependency):
```yaml
  # On-device reading of a bank screenshot's text (Latin script and digits)
  # so her payment details can be filled in for her. ML Kit v2 text
  # recognition has no Arabic model (UNVERIFIED, WO-10e3): Arabic-only
  # receipts are read by the server. The text never leaves the phone; only
  # the extracted fields are sent (WO-10e4). Same ML Kit family as the face
  # detection above, so it adds no new privacy manifest entry (UNVERIFIED:
  # check `ios/Runner/PrivacyInfo.xcprivacy` and `android/play-data-safety.txt`
  # are unchanged by running the Xcode privacy report; WO-10j3).
```
UNVERIFIED supported scripts: after `pub get` run `grep -rn "TextRecognitionScript" ~/.pub-cache/hosted/pub.dev/google_mlkit_text_recognition-*/lib/ | head` and confirm the enum has `latin, chinese, devanagiri, japanese, korean` and no Arabic. If Arabic IS present, use `TextRecognitionScript.latin` still (it also reads Western digits) and write a note in QUESTIONS.md for a later improvement.
2. File `app/lib/features/instapay/domain/redaction_model.dart` (create). Full content:
```dart
library;

import 'dart:ui';

import 'receipt_reader.dart';

class OcrLine {
  const OcrLine(this.text, this.box);
  final String text;

  /// In the picture's own pixels.
  final Rect box;
}

final RegExp _sensitive = RegExp(
  r'(ending\s*\d{4}|card|balance|available|limit|otp|password|pin\b|الرصيد|الحد|كارت|بطاقة|\b\d{13,19}\b)',
  caseSensitive: false,
);

/// What may be hidden and what may not.
class RedactionModel {
  RedactionModel({required this.imageSize, required List<OcrLine> lines, required ExpectedPayment expected}) {
    final amountText = _amountTokens(expected.amountPiasters);
    final addr = expected.coachAddress.trim().toLowerCase();
    final first = expected.coachAccountName.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final prefix = first.length >= 3 ? first.substring(0, 3) : first;
    for (final l in lines) {
      final t = normalizeDigits(l.text).toLowerCase();
      final isProtected = amountText.any(t.contains) ||
          (addr.isNotEmpty && t.contains(addr)) ||
          (prefix.length >= 2 && t.contains(prefix)) ||
          RegExp(r'transaction|reference|rrn|رقم العملية|رقم المرجع|الرقم المرجعي|successful|approved|بنجاح').hasMatch(t) ||
          RegExp(r'\b\d{10,20}\b').hasMatch(t) && !_sensitive.hasMatch(t.replaceAll(RegExp(r'\b\d{10,12}\b'), ''));
      if (isProtected) protected.add(l.box.inflate(2));
    }
    for (final l in lines) {
      if (_sensitive.hasMatch(normalizeDigits(l.text)) && !protected.any((p) => p.overlaps(l.box))) {
        suggested.add(l.box.inflate(2));
        blackouts.add(l.box.inflate(2));
      }
    }
  }

  final Size imageSize;
  final List<Rect> protected = <Rect>[];
  final List<Rect> suggested = <Rect>[];
  final List<Rect> blackouts = <Rect>[];
  Rect? crop;

  static List<String> _amountTokens(int piasters) {
    final whole = piasters ~/ 100;
    final rest = (piasters % 100).toString().padLeft(2, '0');
    return <String>['$whole.$rest', '$whole,$rest'];
  }

  /// False (and nothing drawn) when [r] is too small or touches a protected line.
  bool tryAddBlackout(Rect r) {
    final box = r.intersect(Offset.zero & imageSize);
    if (box.width < 4 || box.height < 4) return false;
    if (protected.any((p) => p.overlaps(box))) return false;
    blackouts.add(box);
    return true;
  }

  bool undo() {
    if (blackouts.isEmpty) return false;
    blackouts.removeLast();
    return true;
  }

  /// False when the crop would cut any protected line.
  bool trySetCrop(Rect r) {
    final box = r.intersect(Offset.zero & imageSize);
    if (box.width < 40 || box.height < 40) return false;
    final whole = protected.every((p) => box.contains(p.topLeft) && box.contains(p.bottomRight));
    if (!whole) return false;
    crop = box;
    return true;
  }
}
```
UNVERIFIED: the `isProtected` expression mixes `||` and `&&`; Dart's precedence makes `&&` bind tighter, which is what is meant (the last term is `A && B`). Keep the parentheses exactly as written to make that explicit if `dart analyze` warns.
3. File `app/lib/features/instapay/data/receipt_ocr.dart` (create). Full content:
```dart
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

/// ML Kit, Latin script. Works on a temporary file that is deleted at once.
class MlKitReceiptOcr implements ReceiptOcr {
  @override
  Future<List<OcrLine>> read(Uint8List png) async {
    File? file;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/ocr-${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(png, flush: true);
      final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
      return <OcrLine>[
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(line.text, Rect.fromLTRB(
              line.boundingBox.left, line.boundingBox.top,
              line.boundingBox.right, line.boundingBox.bottom)),
      ];
    } catch (_) {
      return const <OcrLine>[];
    } finally {
      await recognizer.close();
      try {
        await file?.delete();
      } catch (_) {}
    }
  }
}
```
UNVERIFIED: `TextRecognizer(script:)`, `result.blocks`, `block.lines`, `line.boundingBox` (a `Rect` already in `dart:ui`; then the conversion above is unneeded, keep it only if the type differs). Check with `grep -n "class TextLine" -A12 ~/.pub-cache/hosted/pub.dev/google_mlkit_text_recognition-*/lib/src/text_recognizer.dart`.
4. File `app/lib/features/instapay/data/proof_images.dart` (create). Full content:
```dart
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../domain/redaction_model.dart';

const int kMaxPickedBytes = 25 * 1024 * 1024;
const int kMaxUploadBytes = 5 * 1024 * 1024;
const int kMaxImages = 3;
const int _outputWidth = 1080;

/// Asks the system photo picker for up to [kMaxImages] pictures. No library
/// permission is asked for: `requestFullMetadata: false` keeps iOS from
/// requesting it (UNVERIFIED: copy the exact call from `apply_photo.dart`
/// line 84 and confirm it passes the same flag). Returns the bytes; an
/// oversized file is dropped.
Future<List<Uint8List>> pickProofImages() async {
  final files = await ImagePicker().pickMultiImage(limit: kMaxImages, requestFullMetadata: false);
  final out = <Uint8List>[];
  for (final f in files.take(kMaxImages)) {
    if (await f.length() > kMaxPickedBytes) continue;
    out.add(await f.readAsBytes());
  }
  return out;
}

/// Decodes at most [_outputWidth] pixels wide (an image bomb never fills
/// memory) and returns null when it cannot be read.
Future<ui.Image?> decodeCapped(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: _outputWidth);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// Draws the picture with the black boxes and the crop applied and returns a
/// PNG. PNG from dart:ui carries no EXIF or other metadata. Null if the
/// result is over [kMaxUploadBytes].
Future<Uint8List?> renderRedacted(ui.Image src, RedactionModel m) async {
  final crop = m.crop ?? ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final dst = ui.Rect.fromLTWH(0, 0, crop.width, crop.height);
  canvas.drawImageRect(src, crop, dst, ui.Paint()..filterQuality = ui.FilterQuality.high);
  final black = ui.Paint()..color = const ui.Color(0xFF000000);
  for (final b in m.blackouts) {
    final inter = b.intersect(crop);
    if (inter.isEmpty) continue;
    canvas.drawRect(inter.shift(-crop.topLeft), black);
  }
  final image = await recorder.endRecording().toImage(crop.width.round(), crop.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) return null;
  final bytes = data.buffer.asUint8List();
  return bytes.length > kMaxUploadBytes ? null : bytes;
}
```
Note for the agent: the `RedactionModel` boxes and `crop` are in the DECODED (capped) picture's pixels, because `decodeCapped` is what the view shows and OCRs. Keep one coordinate space: always OCR the PNG re-encoded from the capped image (`ui.Image.toByteData(png)`), never the original file.
5. File `app/lib/features/instapay/presentation/redact_view.dart` (create). It receives the decoded `ui.Image`, a `RedactionModel`, and returns the PNG via `Navigator.pop`. Full content:
```dart
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../data/proof_images.dart';
import '../domain/redaction_model.dart';

enum _Mode { blackOut, crop }

/// Pops with the redacted PNG, or null when she goes back.
class RedactView extends StatefulWidget {
  const RedactView({super.key, required this.image, required this.model});
  final ui.Image image;
  final RedactionModel model;

  @override
  State<RedactView> createState() => _RedactViewState();
}

class _RedactViewState extends State<RedactView> {
  _Mode _mode = _Mode.blackOut;
  Offset? _start;
  Offset? _now;
  bool _busy = false;

  /// BoxFit.contain: widget size to picture pixels.
  ({double scale, Offset offset}) _space(Size box) {
    final iw = widget.image.width.toDouble();
    final ih = widget.image.height.toDouble();
    final s = (box.width / iw) < (box.height / ih) ? box.width / iw : box.height / ih;
    return (scale: s, offset: Offset((box.width - iw * s) / 2, (box.height - ih * s) / 2));
  }

  Rect _toPicture(Rect r, Size box) {
    final sp = _space(box);
    return Rect.fromPoints((r.topLeft - sp.offset) / sp.scale, (r.bottomRight - sp.offset) / sp.scale);
  }

  void _refuse() {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppL10n.of(context).thatPartIsNeededToCheckYourPayment)));
  }

  void _end(Size box) {
    final a = _start, b = _now;
    setState(() {
      _start = null;
      _now = null;
    });
    if (a == null || b == null) return;
    final r = _toPicture(Rect.fromPoints(a, b), box);
    final ok = _mode == _Mode.blackOut ? widget.model.tryAddBlackout(r) : widget.model.trySetCrop(r);
    if (!ok) _refuse();
    setState(() {});
  }

  Future<void> _use() async {
    setState(() => _busy = true);
    final png = await renderRedacted(widget.image, widget.model);
    if (!mounted) return;
    Navigator.of(context).pop<Uint8List?>(png);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      showArt: false,
      scrollable: false,
      appBar: AppTopBar(title: l10n.hidePrivateDetails, onBack: () => Navigator.of(context).pop<Uint8List?>(null)),
      children: [
        Text(l10n.dragOverAnythingPrivateLikeCardNumbersOrBalances, style: AppText.bodyM),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final box = Size(c.maxWidth, c.maxHeight);
            final sp = _space(box);
            return GestureDetector(
              onPanStart: (d) => setState(() { _start = d.localPosition; _now = d.localPosition; }),
              onPanUpdate: (d) => setState(() => _now = d.localPosition),
              onPanEnd: (_) => _end(box),
              child: CustomPaint(
                size: box,
                painter: _Painter(widget.image, widget.model, sp.scale, sp.offset,
                    (_start != null && _now != null) ? Rect.fromPoints(_start!, _now!) : null),
              ),
            );
          }),
        ),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: Text(l10n.blackOut), selected: _mode == _Mode.blackOut, onSelected: (_) => setState(() => _mode = _Mode.blackOut)),
          ChoiceChip(label: Text(l10n.crop), selected: _mode == _Mode.crop, onSelected: (_) => setState(() => _mode = _Mode.crop)),
          AppButton(l10n.undo, variant: AppButtonVariant.text, height: 44, fontSize: 15,
              onPressed: () => setState(widget.model.undo)),
        ]),
        Text(l10n.onlyTheHiddenDetailCopyLeavesYourPhone, style: AppText.bodyM),
      ],
      footer: [AppButton(l10n.useThisPicture, onPressed: _busy ? null : () => unawaited(_use()))],
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.image, this.model, this.scale, this.offset, this.live);
  final ui.Image image;
  final RedactionModel model;
  final double scale;
  final Offset offset;
  final Rect? live;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    final black = Paint()..color = const Color(0xFF000000);
    for (final b in model.blackouts) {
      canvas.drawRect(b, black);
    }
    final c = model.crop;
    if (c != null) {
      canvas.drawRect(c, Paint()..style = PaintingStyle.stroke..strokeWidth = 3 / scale..color = AppColors.primaryDim);
    }
    canvas.restore();
    if (live != null) canvas.drawRect(live!, Paint()..color = const Color(0x66000000));
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
```
UNVERIFIED: `AppScaffold(scrollable: false)` with an `Expanded` child inside `children` (the brief says `scrollable: false` is for `AppSpacer` layouts; confirm an `Expanded` in `children` works with `grep -n "Expanded" app/lib/ui/app_scaffold.dart` and a quick widget test, else wrap the CustomPaint in a `SizedBox(height: 420)`). The `AppColors.primaryDim` name is used in `my_coach_view.dart`.
6. File `app/lib/features/instapay/data/firestore_instapay_repository.dart`. In `submitProof`, replace `final path = 'payment-proofs/$paymentId/$idempotencyKey-$n.jpg';` with `.png`, and `SettableMetadata(contentType: 'image/jpeg')` with `'image/png'` (twice: in `submitProof` and in `coachNotReceived`, where the path ends `.jpg` too). Also fix the INDEX contract line: write to `handover/QUESTIONS.md` "uploads are PNG now: rules in WO-10a must allow image/png under payment-proofs".

## Strings to add
File `app/tool/_wo10e3_strings.json`; drop keys that already exist (`Undo`, `Crop` are likely present).
| English (key) | Egyptian Arabic |
|---|---|
| Hide private details | خبّي التفاصيل الخاصة |
| Drag over anything private, like card numbers or balances. The amount, transaction number and name stay visible. | اسحبي على أي حاجة خاصة زي أرقام الكارت أو الرصيد. المبلغ ورقم العملية والاسم هيفضلوا ظاهرين. |
| Black out | غطّي بالأسود |
| Crop | قصّي |
| Undo | تراجعي |
| Use this picture | استخدمي الصورة دي |
| That part is needed to check your payment. | الجزء ده لازم عشان نتأكد من الدفع. |
| Only the hidden-detail copy leaves your phone. The original stays here. | النسخة اللي اتخبّت منها التفاصيل بس هي اللي بتتبعت. الأصل بيفضل على تليفونك. |
| This picture is too big or could not be read. Pick another. | الصورة كبيرة أوي أو مقدرناش نقراها. اختاري صورة تانية. |

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| redaction_model_test.dart | `amount, address, txn and success lines are protected` | `RedactionModel(imageSize: Size(1080, 2000), lines: [...], expected: expected)` with lines `500.37 EGP`, `rahma.m@instapay`, `Transaction ID 123456789012`, `Your transaction was successful`; `protected.length == 4` |
| same | `card and balance lines are suggested and pre-blacked` | lines `credit card ending 9412`, `Available limit 20,000`; `suggested.length == 2` and `blackouts.length == 2` |
| same | `a black box over a protected line is refused` | `tryAddBlackout` over the amount box is false; `blackouts` unchanged |
| same | `a black box elsewhere is accepted, undo removes it` | accepted true; `undo()` true; length back |
| same | `a crop that cuts a protected line is refused, one that keeps all is accepted` | two rects |
| same | `a tiny box and a tiny crop are refused` | 2x2 box false; 20x20 crop false |
| same | `a card number line that is also long digits is suggested, a 12 digit txn line is not` | line `Card 4111111111111111` suggested; line `Transaction ID 123456789012` protected not suggested |
| redact_view_test.dart | `drag draws a box, Undo removes it` | build a 200x400 `ui.Image` inside `tester.runAsync` (record a picture, `toImage`); pump `RedactView` in `host`; drag with `tester.drag` on the `CustomPaint`; `model.blackouts.length == 1`; tap Undo; 0 |
| same | `a drag over a protected line shows the refusal` | model with a protected rect in the middle; drag over it; the snackbar text is found |
| same | `Use this picture pops PNG bytes` | inside `runAsync` tap the primary; the route result begins with bytes `89 50 4E 47` |
| same | `budget` | `countControlsAboveFold(tester, includeChrome: false) <= 5`, `filledPrimaryActions == 1` at 390x844 and 375x667, EN and AR |
| same | `renderRedacted: black boxes are black and the crop sizes the output` | decode the result with `decodeCapped`; pixel inside a black box is black via `toByteData(rawRgba)`; width equals the crop width |
| same | `decodeCapped returns null for garbage bytes` | `Uint8List.fromList([1,2,3])` gives null |
Run: `cd app && flutter test test/features/instapay/redaction_model_test.dart test/features/instapay/redact_view_test.dart`

## Verify
- `cd app && flutter pub get` succeeds; `git diff app/pubspec.lock` shows `google_mlkit_text_recognition` added and `google_mlkit_commons` unchanged or only patch-bumped.
- `cd app && dart analyze lib/features/instapay test/features/instapay` ends `No issues found!`
- both test files end `All tests passed!`
- `cd app && flutter build apk --debug` (or `flutter build ios --no-codesign` on the Mac) succeeds: UNVERIFIED; the iOS simulator cannot run ML Kit (`.claude/CLAUDE.md`: ML Kit ships no arm64 simulator slice) so run on the Android emulator `ownhub_pixel8`.

## Do not
- Do not upload or keep the original file; only the redacted PNG leaves the phone.
- Do not run OCR on the original for the reading: the reading comes from the PNG that will be uploaded (WO-10e4 step 2).
- Do not request photo library permission (no `NSPhotoLibraryUsageDescription` change).
- Do not store the text of the receipt anywhere on the phone.

## Done checklist
- [ ] dependency resolved, platform floors checked
- [ ] model, OCR, image helpers, view
- [ ] repository uses PNG
- [ ] tests pass; one run on the Android emulator with a real screenshot noted in the report

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10f1).

UNVERIFIED in this order: 7 (package version and Arabic support, Podfile floor, ML Kit API names, `requestFullMetadata` flag, Expanded in scaffold, precedence note, privacy manifest unchanged).
