/// Her card: pink paper, two wooden clips, a drawn food mark, her words.
///
/// **Not a new painter.** `HandSurface` already draws an irregular container
/// with a wobbly edge, a seeded outline and right-to-left awareness, so the
/// book's card is that surface with the book's settings. The only new drawing
/// is the pair of clips along the top edge, which are decoration in the sense
/// `hand_marks.dart` means it: they carry no information, take no tap and are
/// excluded from the semantics tree.
///
/// ## Why the illustration is at `AlignmentDirectional.topStart`
///
/// It sits top-**right** in the book because the book is Arabic. A fixed corner
/// would put it top-right in the English build too, where it would collide with
/// a left-aligned title. `topStart` follows the text direction, which is the
/// same reason `HandCorner` is named `topStart`/`topEnd` rather than
/// `topLeft`/`topRight`.
///
/// ## Why the English title is forced left-to-right
///
/// `Fool & Ta3mya` in an Arabic paragraph reorders around the ampersand and
/// comes out as `Ta3mya & Fool`. The title is wrapped in an explicit
/// `Directionality(TextDirection.ltr)` for that one reason, and it is announced
/// through `Semantics` so a screen reader in Arabic mode does not try to read
/// `Hwawshi` as Arabic.
library;

import 'package:flutter/semantics.dart'
    show AttributedString, LocaleStringAttribute;
import 'package:flutter/widgets.dart';

import '../../theme/hand_tokens.dart';
import '../../theme/recipe_book_tokens.dart';
import '../meal_image.dart';
import 'food_marks.dart';
import 'hand_geometry.dart';
import 'hand_surface.dart';

/// A card from the book.
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.cardId,
    required this.child,
    this.markKey,
    this.markSize = 54,
    this.imageAsset,
    this.onTap,
    this.padding = BookMetrics.cardPadding,
  });

  /// Seeds the wobble, so a given card is the same shape every time it draws.
  final String cardId;

  final Widget child;

  /// A drawn food mark. Null draws none, which is what an unmapped recipe gets
  /// rather than a guessed picture of the wrong dish.
  final String? markKey;
  final double markSize;

  /// A painted picture of the dish, shown in place of the mark. The mark comes
  /// back if the picture cannot be read.
  final String? imageAsset;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final seed = handSeed(['book-card', cardId]);
    return Padding(
      // Head room for the clips, which sit half off the top edge.
      padding: const EdgeInsets.only(top: BookMetrics.clipHeight / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HandSurface(
            seed: seed,
            fill: BookInk.paper,
            // The book's card has no border at all. Its edge is the change of
            // colour against the pink ground, which is what makes it read as a
            // piece of paper laid down rather than a box drawn on.
            frame: null,
            level: HandLevel.expressive,
            radius: 10,
            looseCorner: 22,
            padding: padding,
            onTap: onTap,
            semanticsButton: onTap != null,
            // The mark is the FIRST child, which puts it at the start of the
            // reading direction: top-right in Arabic, exactly where the book
            // draws it, and top-left in English. One widget, no branch, no
            // `Directionality.of(context) == rtl` anywhere.
            //
            // It was the last child first, which is the same mistake
            // `AlignmentDirectional` exists to prevent: `Row` lays out
            // start-to-end, so trailing meant left in Arabic and right in
            // English, the mirror image of the page.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageAsset != null) ...[
                  MealImage(
                    asset: imageAsset,
                    size: markSize,
                    fallback: markKey == null
                        ? SizedBox.square(dimension: markSize)
                        : FoodMark(
                            markKey: markKey!,
                            size: markSize,
                            ink: BookInk.ink,
                          ),
                  ),
                  const SizedBox(width: 10),
                ] else if (markKey != null) ...[
                  FoodMark(markKey: markKey!, size: markSize, ink: BookInk.ink),
                  const SizedBox(width: 10),
                ],
                Expanded(child: child),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _ClipsPainter(seed: seed)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two wooden clips along the card's top edge.
///
/// Symmetric about the card's centre, so they need no mirroring in Arabic. Drawn
/// above the paper rather than on it, which is the whole reason the card sits in
/// a `Stack` with `clipBehavior: Clip.none`.
class _ClipsPainter extends CustomPainter {
  _ClipsPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = HandRandom(seed ^ 0x3c19ab);
    final body = Paint()..color = BookInk.clip;
    final hole = Paint()..color = BookInk.paper;
    // A short rule between the clips, as the book draws it.
    final rule = Paint()
      ..color = BookInk.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const w = BookMetrics.clipWidth;
    const h = BookMetrics.clipHeight;
    // Far enough in that a narrow phone still shows both, and far enough apart
    // that they never read as one wide block.
    final inset = size.width * 0.16;
    for (final cx in [inset, size.width - inset]) {
      final top = -h / 2 + rnd.signed(1.2);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, top, w, h),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, body);
      canvas.drawCircle(Offset(cx, top + h * 0.62), w * 0.16, hole);
    }
    canvas.drawLine(
      Offset(size.width * 0.40, 6),
      Offset(size.width * 0.60, 6),
      rule,
    );
  }

  @override
  bool shouldRepaint(covariant _ClipsPainter old) => old.seed != seed;
}

/// Her English title, kept in reading order and announced in its own language.
///
/// Two separate problems, one widget, because they always occur together:
/// bidi reordering around `&` and a screen reader trying to pronounce
/// `Shakshoka` with Arabic phonemes.
class BookTitle extends StatelessWidget {
  const BookTitle({
    super.key,
    required this.titleEn,
    this.style,
    this.textAlign,
  });

  final String titleEn;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // The locale attribute is the whole reason this is `attributedLabel` and
      // not `label`: TalkBack and VoiceOver in Arabic will otherwise try to
      // pronounce `Hwawshi` and `Shakshoka` with Arabic phonemes, which is a
      // different word.
      attributedLabel: AttributedString(
        titleEn,
        attributes: [
          LocaleStringAttribute(
            range: TextRange(start: 0, end: titleEn.length),
            locale: const Locale('en'),
          ),
        ],
      ),
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            titleEn,
            style: style,
            textAlign: textAlign,
            textWidthBasis: TextWidthBasis.longestLine,
          ),
        ),
      ),
    );
  }
}
