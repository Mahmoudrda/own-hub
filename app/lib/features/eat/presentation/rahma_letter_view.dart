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
/// The only Modern Standard string on the screen is the route's own title in
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
            child: Text(
              letterAr,
              style: AppText.body.copyWith(color: BookInk.ink, height: 1.7),
            ),
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
      const Offset(0.50, 0.82), const Offset(0.16, 0.50),
      const Offset(0.16, 0.30), const Offset(0.33, 0.20),
      const Offset(0.50, 0.34), const Offset(0.67, 0.20),
      const Offset(0.84, 0.30), const Offset(0.84, 0.50),
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
