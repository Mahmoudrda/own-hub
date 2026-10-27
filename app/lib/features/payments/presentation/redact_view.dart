library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../data/proof_images.dart';
import '../domain/redaction_model.dart';

enum _Mode { blackOut, crop }

/// "Hide private details": drag a black box over anything private, or crop.
/// Pops with the redacted PNG, or null when she goes back. The amount, the
/// transaction number and the recipient cannot be hidden (the proof would be
/// useless), so a drag over them draws nothing and says why.
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
    final s = (box.width / iw) < (box.height / ih)
        ? box.width / iw
        : box.height / ih;
    return (
      scale: s,
      offset: Offset((box.width - iw * s) / 2, (box.height - ih * s) / 2),
    );
  }

  Rect _toPicture(Rect r, Size box) {
    final sp = _space(box);
    return Rect.fromPoints(
      (r.topLeft - sp.offset) / sp.scale,
      (r.bottomRight - sp.offset) / sp.scale,
    );
  }

  void _refuse() {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).thatPartIsNeededToCheckYour),
        ),
      );
  }

  void _end(Size box) {
    final a = _start;
    final b = _now;
    setState(() {
      _start = null;
      _now = null;
    });
    if (a == null || b == null) return;
    final r = _toPicture(Rect.fromPoints(a, b), box);
    final ok = _mode == _Mode.blackOut
        ? widget.model.tryAddBlackout(r)
        : widget.model.trySetCrop(r);
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
    return PaperPage(
      color: AppColors.surface,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: l10n.hidePrivateDetails,
          onBack: () => Navigator.of(context).pop<Uint8List?>(null),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              // The picture keeps a usable height at any text size; the rest
              // of the screen scrolls around it.
              final pictureHeight = (c.maxHeight * 0.5).clamp(220.0, 520.0);
              final box = Size(c.maxWidth - 32, pictureHeight);
              final sp = _space(box);
              return SingleChildScrollView(
                padding: kBodyPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.dragOverAnythingPrivateLikeCardNumbers,
                      style: AppText.bodyM,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: pictureHeight,
                      // A pan that starts after two pixels, so a drag over the
                      // picture draws a box instead of scrolling the page.
                      child: RawGestureDetector(
                        key: const ValueKey('redact-surface'),
                        gestures: <Type, GestureRecognizerFactory>{
                          PanGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                PanGestureRecognizer
                              >(PanGestureRecognizer.new, (
                                PanGestureRecognizer r,
                              ) {
                                r.gestureSettings = const DeviceGestureSettings(
                                  touchSlop: 1,
                                );
                                r.onStart = (DragStartDetails d) =>
                                    setState(() {
                                      _start = d.localPosition;
                                      _now = d.localPosition;
                                    });
                                r.onUpdate = (DragUpdateDetails d) =>
                                    setState(() => _now = d.localPosition);
                                r.onEnd = (DragEndDetails _) => _end(box);
                              }),
                        },
                        child: Semantics(
                          label: l10n.dragOverAnythingPrivateLikeCardNumbers,
                          image: true,
                          child: CustomPaint(
                            size: box,
                            painter: _Painter(
                              widget.image,
                              widget.model,
                              sp.scale,
                              sp.offset,
                              (_start != null && _now != null)
                                  ? Rect.fromPoints(_start!, _now!)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('mode-blackout'),
                          label: Text(l10n.blackOut),
                          selected: _mode == _Mode.blackOut,
                          onSelected: (_) =>
                              setState(() => _mode = _Mode.blackOut),
                        ),
                        ChoiceChip(
                          key: const ValueKey('mode-crop'),
                          label: Text(l10n.crop),
                          selected: _mode == _Mode.crop,
                          onSelected: (_) => setState(() => _mode = _Mode.crop),
                        ),
                        AppButton(
                          l10n.undo,
                          key: const ValueKey('redact-undo'),
                          variant: AppButtonVariant.text,
                          height: 44,
                          fontSize: 15,
                          onPressed: () => setState(widget.model.undo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.onlyTheHiddenDetailCopyLeavesYour,
                      style: AppText.bodyM,
                    ),
                    Padding(
                      padding: kFooterPadding.copyWith(left: 0, right: 0),
                      child: AppButton(
                        l10n.useThisPicture,
                        key: const ValueKey('use-picture'),
                        onPressed: _busy ? null : () => unawaited(_use()),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
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
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final black = Paint()..color = const Color(0xFF000000);
    for (final b in model.blackouts) {
      canvas.drawRect(b, black);
    }
    final c = model.crop;
    if (c != null) {
      canvas.drawRect(
        c,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 / scale
          ..color = AppColors.primaryDim,
      );
    }
    canvas.restore();
    if (live != null) {
      canvas.drawRect(live!, Paint()..color = const Color(0x66000000));
    }
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
