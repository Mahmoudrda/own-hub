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
final RegExp _needed = RegExp(
  r'transaction|reference|rrn|رقم العملية|رقم المرجع|الرقم المرجعي|successful|approved|بنجاح',
  caseSensitive: false,
);

/// What may be hidden and what may not. The amount, the transaction number,
/// the recipient and the status are protected: hiding them makes the proof
/// useless. Lines that look like card numbers, balances or limits are
/// suggested and black from the start (she can undo).
class RedactionModel {
  RedactionModel({
    required this.imageSize,
    required List<OcrLine> lines,
    required ExpectedPayment expected,
  }) {
    final amountText = _amountTokens(expected.amountPiasters);
    final addr = expected.coachAddress.trim().toLowerCase();
    final first = foldText(expected.coachAccountName.trim())
        .split(RegExp(r'\s+'))
        .first;
    final prefix = first.length >= 3 ? first.substring(0, 3) : first;
    for (final l in lines) {
      final t = foldText(normalizeDigits(l.text));
      final isProtected =
          amountText.any(t.contains) ||
          (addr.isNotEmpty && t.contains(addr)) ||
          (prefix.length >= 2 && t.contains(prefix)) ||
          _needed.hasMatch(t) ||
          (RegExp(r'\b\d{10,20}\b').hasMatch(t) &&
              !_sensitive.hasMatch(t.replaceAll(RegExp(r'\b\d{10,12}\b'), '')));
      if (isProtected) protected.add(l.box.inflate(2));
    }
    for (final l in lines) {
      if (_sensitive.hasMatch(normalizeDigits(l.text)) &&
          !protected.any((p) => p.overlaps(l.box))) {
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

  /// Whether the picture will leave unchanged (no box, no crop).
  bool get untouched => blackouts.isEmpty && crop == null;

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
    final whole = protected.every(
      (p) => box.contains(p.topLeft) && box.contains(p.bottomRight),
    );
    if (!whole) return false;
    crop = box;
    return true;
  }
}
