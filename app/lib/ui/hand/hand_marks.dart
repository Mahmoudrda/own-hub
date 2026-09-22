/// The reader's marks, as widgets: underline, circle, tick, arrow, marker,
/// rule, and the handwriting itself.
///
/// All of them are decoration over content that already says what it means.
/// None carries information on its own, none takes a tap, and none is read
/// out by a screen reader — except [HandNote], which is real text and is read
/// like any other unless it is marked decorative.
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/hand_tokens.dart';
import 'draw_on.dart';
import 'hand_geometry.dart';
import 'hand_painters.dart';

/// A stable seed from whatever identifies a mark — usually its text.
int seedFor(Object? a, [Object? b, Object? c]) => handSeed([a, b, c]);

String? _textOf(Widget w) => switch (w) {
  Text(:final data) => data,
  _ => null,
};

/// A text child, made to hug its longest line.
///
/// A [Text] is as wide as its parent by default, so a mark drawn under or
/// behind a title that wraps would run across the whole column rather than
/// under the words. Everything else about the text is kept as given.
Widget _hug(Widget w) {
  if (w is! Text || w.textWidthBasis != null || w.data == null) return w;
  return Text(
    w.data!,
    key: w.key,
    style: w.style,
    strutStyle: w.strutStyle,
    textAlign: w.textAlign,
    textDirection: w.textDirection,
    locale: w.locale,
    softWrap: w.softWrap,
    overflow: w.overflow,
    textScaler: w.textScaler,
    maxLines: w.maxLines,
    semanticsLabel: w.semanticsLabel,
    textWidthBasis: TextWidthBasis.longestLine,
    textHeightBehavior: w.textHeightBehavior,
    selectionColor: w.selectionColor,
  );
}

Widget _drawn({
  required bool drawOn,
  required Duration delay,
  required Widget Function(double progress) build,
}) {
  if (!drawOn) return build(1);
  return DrawOn(delay: delay, builder: (_, p) => build(p));
}

/// A drawn underline beneath [child].
class HandUnderline extends StatelessWidget {
  const HandUnderline({
    super.key,
    required this.child,
    this.seed,
    this.color = HandInk.ink,
    this.level = HandLevel.expressive,
    this.width = HandStroke.pen,
    this.drawOn = false,
    this.delay = Duration.zero,
    this.gap = 2,
  });

  final Widget child;
  final int? seed;
  final Color color;
  final HandLevel level;
  final double width;
  final bool drawOn;
  final Duration delay;

  /// Space between the child's bottom edge and the line.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final s = seed ?? seedFor(_textOf(child), 'u');
    return _drawn(
      drawOn: drawOn,
      delay: delay,
      build: (p) => CustomPaint(
        foregroundPainter: UnderlinePainter(
          seed: s,
          color: color,
          level: level,
          width: width,
          progress: p,
          textDirection: dir,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: gap + width),
          child: _hug(child),
        ),
      ),
    );
  }
}

/// A loop drawn round [child], closing past its own start.
class HandCircled extends StatelessWidget {
  const HandCircled({
    super.key,
    required this.child,
    this.seed,
    this.color = HandInk.ink,
    this.width = HandStroke.pen,
    this.level = HandLevel.expressive,
    this.inflate = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.drawOn = false,
    this.delay = Duration.zero,
  });

  final Widget child;
  final int? seed;
  final Color color;
  final double width;
  final HandLevel level;
  final EdgeInsets inflate;
  final bool drawOn;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final s = seed ?? seedFor(_textOf(child), 'o');
    return _drawn(
      drawOn: drawOn,
      delay: delay,
      build: (p) => CustomPaint(
        foregroundPainter: LoopPainter(
          seed: s,
          color: color,
          width: width,
          level: level,
          progress: p,
          inflate: inflate,
          textDirection: dir,
        ),
        child: _hug(child),
      ),
    );
  }
}

/// A drawn tick. Sage by default: done, never "won".
class HandTick extends StatelessWidget {
  const HandTick({
    super.key,
    this.size = 18,
    this.color = HandInk.done,
    this.width,
    this.seed = 7,
    this.drawOn = false,
    this.delay = Duration.zero,
  });

  final double size;
  final Color color;
  final double? width;
  final int seed;
  final bool drawOn;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _drawn(
      drawOn: drawOn,
      delay: delay,
      build: (p) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: TickPainter(
            seed: seed,
            color: color,
            width: width ?? (size / 8).clamp(1.4, 3.2),
            progress: p,
          ),
        ),
      ),
    );
  }
}

/// A pencil arrow inside a box of the given size, from [from] to [to] in the
/// box's own 0–1 space. Mirrors in Arabic.
class HandArrow extends StatelessWidget {
  const HandArrow({
    super.key,
    required this.width,
    required this.height,
    this.from = const Offset(0.05, 0.1),
    this.to = const Offset(0.92, 0.9),
    this.bend = 0.3,
    this.color = HandInk.ink,
    this.stroke = HandStroke.fine,
    this.seed = 3,
    this.drawOn = false,
    this.delay = Duration.zero,
  });

  final double width;
  final double height;
  final Offset from;
  final Offset to;
  final double bend;
  final Color color;
  final double stroke;
  final int seed;
  final bool drawOn;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    return ExcludeSemantics(
      child: _drawn(
        drawOn: drawOn,
        delay: delay,
        build: (p) => SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: ArrowPainter(
              seed: seed,
              from: from,
              to: to,
              bend: bend,
              color: color,
              width: stroke,
              progress: p,
              textDirection: dir,
            ),
          ),
        ),
      ),
    );
  }
}

/// A marker swath behind [child].
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({
    super.key,
    required this.child,
    this.seed,
    this.color = HandInk.marker,
    this.cover = 0.62,
    this.drawOn = false,
    this.delay = Duration.zero,
  });

  final Widget child;
  final int? seed;
  final Color color;

  /// Share of the child's height the swath covers, from the bottom.
  final double cover;
  final bool drawOn;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final s = seed ?? seedFor(_textOf(child), 'm');
    return _drawn(
      drawOn: drawOn,
      delay: delay,
      build: (p) => CustomPaint(
        painter: MarkerPainter(
          seed: s,
          color: color,
          progress: p,
          cover: cover,
          textDirection: dir,
        ),
        child: _hug(child),
      ),
    );
  }
}

/// A drawn rule across the column: pencil by default, ink when it must hold
/// a section apart.
class HandRule extends StatelessWidget {
  const HandRule({
    super.key,
    this.seed = 1,
    this.ink = false,
    this.color,
    this.height = 12,
    this.level = HandLevel.crafted,
  });

  final int seed;
  final bool ink;
  final Color? color;
  final double height;
  final HandLevel level;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: RulePainter(
            seed: seed,
            ink: ink,
            color: color ?? (ink ? HandInk.ink : HandInk.pencil),
            level: level,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

bool _hasArabic(String s) => s.runes.any(
  (r) => (r >= 0x0600 && r <= 0x06FF) || (r >= 0x0750 && r <= 0x077F),
);

/// The hand's own style: Aref Ruqaa for Arabic, La Belle Aurore for Latin
/// and for numerals in both languages.
///
/// La Belle Aurore sits small on its body, so it is set larger than the
/// size asked for, to match Rubik's x-height at that size.
TextStyle handStyle(
  String text, {
  double size = 18,
  Color color = HandInk.ink,
}) {
  final arabic = _hasArabic(text);
  return TextStyle(
    fontFamily: arabic ? 'ArefRuqaa' : 'LaBelleAurore',
    fontFamilyFallback: const ['ArefRuqaa', 'Rubik'],
    fontSize: arabic ? size * 1.05 : size * 1.28,
    height: arabic ? 1.35 : 1.1,
    color: color,
    fontWeight: FontWeight.w400,
  );
}

/// A short handwritten note. Never a paragraph: two or three words, a figure,
/// a word of encouragement that is actually true.
class HandNote extends StatelessWidget {
  const HandNote(
    this.text, {
    super.key,
    this.size = 18,
    this.color = HandInk.ink,
    this.tilt = -0.035,
    this.decorative = false,
    this.textAlign,
  });

  final String text;
  final double size;
  final Color color;

  /// Radians. Notes are rarely written level.
  final double tilt;

  /// True when the same words are already on screen in print, so a screen
  /// reader should not hear them twice.
  final bool decorative;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final t = Transform.rotate(
      angle: dir == TextDirection.rtl ? -tilt : tilt,
      child: Text(
        text,
        textAlign: textAlign,
        style: handStyle(text, size: size, color: color),
      ),
    );
    return decorative ? ExcludeSemantics(child: t) : t;
  }
}

/// A figure set by hand — a week number, a count.
///
/// Painted rather than laid out as a [Text]: it is decoration beside a figure
/// the screen already states in print, so it must not be found, read out or
/// counted as a second copy of that figure.
class HandFigure extends StatelessWidget {
  const HandFigure(
    this.value, {
    super.key,
    this.size = 28,
    this.color = HandInk.ink,
  });

  final String value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: handStyle('0', size: size, color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    return ExcludeSemantics(
      child: SizedBox(
        width: painter.width,
        height: painter.height,
        child: CustomPaint(painter: _FigurePainter(painter)),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.text);
  final TextPainter text;

  @override
  void paint(Canvas canvas, Size size) {
    text.paint(canvas, Offset.zero);
    // La Belle Aurore writes a one as a single slanted stroke, and on its own
    // — a lone step number — it reads as a slash. A person writing a figure
    // they mean to be read adds the flag, so the hand adds it here.
    final value = text.text?.toPlainText() ?? '';
    final colour = text.text?.style?.color ?? HandInk.ink;
    for (var i = 0; i < value.length; i++) {
      if (value[i] != '1') continue;
      final boxes = text.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      final b = boxes.first.toRect();
      final h = b.height;
      final top = Offset(b.left + b.width * 0.86, b.top + h * 0.27);
      paintInk(
        canvas,
        [
          top,
          top + Offset(-h * 0.05, h * 0.04),
          top + Offset(-h * 0.11, h * 0.085),
        ],
        color: colour,
        width: (h * 0.055).clamp(1.0, 2.4),
        taper: 0.5,
        seed: i + 11,
      );
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.text.text != text.text;
}

/// The page: warm paper with a faint grain.
class PaperPage extends StatelessWidget {
  const PaperPage({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color ?? AppColors.surface,
      child: CustomPaint(painter: const PaperGrainPainter(), child: child),
    );
  }
}
