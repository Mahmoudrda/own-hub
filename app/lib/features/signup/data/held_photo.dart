/// A photograph she has just taken, drawn so she can check it.
///
/// Decoded straight from the bytes `VerificationEvidence` holds, with
/// `instantiateImageCodec`, and drawn with [RawImage]. Deliberately not
/// `Image.memory`: that goes through the global image cache, which would keep
/// the decoded pixels of a national ID card alive after the bytes behind them
/// were wiped. Here the decoded picture belongs to this widget alone and is
/// disposed the moment the widget leaves the tree.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class HeldPhoto extends StatefulWidget {
  const HeldPhoto({super.key, required this.jpeg, this.decodeWidth = 720});

  /// The held JPEG. Read, never copied or kept.
  final Uint8List jpeg;

  /// The width to decode at. A review never needs the full sensor resolution,
  /// and a smaller decode is less memory on the phones this product is for.
  final int decodeWidth;

  @override
  State<HeldPhoto> createState() => _HeldPhotoState();
}

class _HeldPhotoState extends State<HeldPhoto> {
  ui.Image? _picture;

  /// Bumped on every decode and on dispose, so a decode that finishes late
  /// releases its result instead of drawing it.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(HeldPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.jpeg, widget.jpeg)) {
      _release();
      _decode();
    }
  }

  Future<void> _decode() async {
    final generation = ++_generation;
    try {
      final codec = await ui.instantiateImageCodec(
        widget.jpeg,
        targetWidth: widget.decodeWidth,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        if (!mounted || generation != _generation) {
          frame.image.dispose();
          return;
        }
        setState(() => _picture = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      // A buffer already wiped, or one the decoder cannot read. The frame stays
      // empty, and "Retake" is beside it.
    }
  }

  void _release() {
    _picture?.dispose();
    _picture = null;
  }

  @override
  void dispose() {
    _generation++;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    if (picture == null) return const SizedBox.expand();
    return SizedBox.expand(
      child: RawImage(image: picture, fit: BoxFit.cover),
    );
  }
}
