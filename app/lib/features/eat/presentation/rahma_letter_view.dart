/// E11 — the letter Rahma closes her book with.
///
/// Page 26, under `Ice cream`: `A message to you :)`, about 120 words of
/// Egyptian colloquial on why we try to eat well, and `With all my love /
/// Rahma`. It is the single warmest thing in the source and on paper it is
/// squeezed under a recipe, so here it gets a screen.
///
/// **Nothing else is on it.** No buttons but back, no related recipes, no
/// nudge to log anything. A letter with a call to action underneath it is an
/// advert wearing a letter's clothes, and a woman can tell.
///
/// Her text arrives from `rahma_recipes.json` like every other word of hers.
/// The only string in the app's voice on the screen is the route's own title in
/// the bar above it.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../theme/recipe_book_tokens.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/hand/hand_geometry.dart' show perturbLoop, smoothPath;

class RahmaLetterView extends StatelessWidget {
  const RahmaLetterView({super.key, required this.letterAr, this.onBack});

  /// Her words, verbatim, with her own line breaks.
  final String letterAr;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PaperPage(
      color: BookInk.bg,
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(onBack: onBack),
        children: [
          BookCard(
            cardId: 'rahma_letter',
            // No food mark. The letter is not a dish, and a drawing of a bowl
            // beside it would be the screen changing the subject.
            child: _Letter(letterAr),
          ),
          // The heart the book draws under her sign-off. Decoration in the
          // strict sense the hand layer means: no information, no tap, not read
          // out, and the letter above says everything it could have said.
          Center(
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 48,
                child: CustomPaint(painter: _HeartPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Her letter, set as the three things it is.
///
/// Page 26 opens with one English line, "A message to you :)", carries about a
/// hundred and twenty words of Egyptian colloquial, and closes "With all my
/// love / Rahma". Rendered as one undifferentiated block it was a wall of text
/// whose heading and signature looked like body copy, and whose Arabic
/// paragraphs were laid out left to right for a woman reading the app in
/// English, because the block took its direction from the interface rather than
/// from the words in it.
///
/// Nothing here is authored. The heading is her first line, the sign-off is her
/// last two, and each part is given the direction of the script it is written
/// in. A letter with no closing lines still renders: the split is by position,
/// and a short letter simply has no sign-off to set apart.
class _Letter extends StatelessWidget {
  const _Letter(this.text);

  final String text;

  /// True for a line whose first letter is Arabic. Read off the line itself
  /// rather than off the locale, because this letter is bilingual on the page.
  static bool _isArabic(String line) {
    for (final rune in line.runes) {
      if (rune >= 0x0600 && rune <= 0x06FF) return true;
      if (rune >= 0x0041 && rune <= 0x024F) return false;
    }
    return false;
  }

  static Widget _line(String text, TextStyle style) => Text(
    text,
    style: style,
    textDirection: _isArabic(text) ? TextDirection.rtl : TextDirection.ltr,
    textAlign: _isArabic(text) ? TextAlign.right : TextAlign.left,
  );

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();

    final body = AppText.body.copyWith(color: BookInk.ink, height: 1.7);
    // Two closing lines, "With all my love" and her name, where there are
    // enough lines for a body to remain between them and the heading.
    final hasSignOff = lines.length >= 4;
    final signOff = hasSignOff
        ? lines.sublist(lines.length - 2)
        : const <String>[];
    final middle = lines.sublist(
      1,
      hasSignOff ? lines.length - 2 : lines.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _line(lines.first, AppText.titleL.copyWith(color: BookInk.ink)),
        for (final line in middle) ...[
          const SizedBox(height: 10),
          _line(line, body),
        ],
        for (final line in signOff) ...[
          const SizedBox(height: 12),
          _line(line, body.copyWith(fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final pen = Paint()
      ..color = BookInk.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pts = <Offset>[
      const Offset(0.50, 0.82),
      const Offset(0.16, 0.50),
      const Offset(0.16, 0.30),
      const Offset(0.33, 0.20),
      const Offset(0.50, 0.34),
      const Offset(0.67, 0.20),
      const Offset(0.84, 0.30),
      const Offset(0.84, 0.50),
    ].map((p) => Offset(p.dx * s, p.dy * s)).toList();
    canvas.drawPath(
      smoothPath(
        perturbLoop(pts, seed: handSeed(const ['rahma-heart']), wobble: 1.4),
        close: true,
      ),
      pen,
    );
  }

  @override
  bool shouldRepaint(covariant _HeartPainter oldDelegate) => false;
}
