/// The painters behind every hand mark.
///
/// Each one draws a single kind of mark and takes a `seed`, so the same mark
/// in the same place is drawn identically on every frame and a mark elsewhere
/// is drawn differently. Each takes a `progress` from 0 to 1 so it can be drawn
/// on; at 1 it is simply the finished mark.
///
/// Every painter that has a direction takes one. A pen moves the way the
/// language reads, so in Arabic an underline is drawn from the right and an
/// arrow that points "forward" points left.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../theme/hand_tokens.dart';
import 'hand_geometry.dart';

/// The leading share of a stroke, for drawing it on.
List<Offset> strokePrefix(List<Offset> pts, double progress) {
  if (progress >= 1 || pts.length < 2) return pts;
  if (progress <= 0) return const [];
  final exact = (pts.length - 1) * progress;
  final whole = exact.floor();
  final out = pts.sublist(0, whole + 1);
  final frac = exact - whole;
  if (frac > 0 && whole + 1 < pts.length) {
    out.add(Offset.lerp(pts[whole], pts[whole + 1], frac)!);
  }
  return out;
}

/// Draws one nib stroke.
void paintInk(
  Canvas canvas,
  List<Offset> pts, {
  required Color color,
  required double width,
  double taper = 0.5,
  int seed = 0,
}) {
  if (pts.length < 2) return;
  canvas.drawPath(
    inkPath(pts, width: width, taper: taper, seed: seed),
    Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );
}

/// Draws a graphite line: two faint passes that do not quite agree, which is
/// what makes a pencil line read as pencil rather than as a grey rule.
void paintPencil(
  Canvas canvas,
  List<Offset> pts, {
  Color color = HandInk.pencil,
  double width = 1.0,
  double opacity = 0.7,
  int seed = 0,
}) {
  if (pts.length < 2) return;
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  canvas.drawPath(
    smoothPath(pts),
    p
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width,
  );
  final drift = HandNoise(seed ^ 0x1f);
  final second = [
    for (var i = 0; i < pts.length; i++)
      pts[i] + Offset(0, drift.at(i / pts.length) * 0.6),
  ];
  canvas.drawPath(
    smoothPath(second),
    p
      ..color = color.withValues(alpha: opacity * 0.45)
      ..strokeWidth = width * 0.7,
  );
}

double _mirrorX(double x, double width, TextDirection dir) =>
    dir == TextDirection.rtl ? width - x : x;

// ------------------------------------------------------------------ underline

/// A line under a word, running a little past both ends and lifting at the
/// finish. At [HandLevel.signature] the pen comes back for a shorter second
/// pass, the way people underline something they mean.
class UnderlinePainter extends CustomPainter {
  UnderlinePainter({
    required this.seed,
    this.color = HandInk.ink,
    this.level = HandLevel.expressive,
    this.width = HandStroke.pen,
    this.progress = 1,
    this.textDirection = TextDirection.ltr,
    this.baseline = 1.0,
  });

  final int seed;
  final Color color;
  final HandLevel level;
  final double width;
  final double progress;
  final TextDirection textDirection;

  /// Where the line sits, as a share of the height. 1 is the bottom edge.
  final double baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final r = HandRandom(seed);
    final y = size.height * baseline + 1;
    final lift = level.wobble * r.range(0.8, 1.8);
    var a = Offset(_mirrorX(0, size.width, textDirection), y);
    var b = Offset(_mirrorX(size.width, size.width, textDirection), y - lift);
    final pts = wobblyLine(
      a,
      b,
      seed: seed,
      wobble: level.wobble * 0.8,
      overshootStart: level.overshoot * 0.35,
      overshootEnd: level.overshoot,
    );
    final isSecond = level == HandLevel.signature;
    final firstShare = isSecond ? 0.72 : 1.0;
    paintInk(
      canvas,
      strokePrefix(pts, (progress / firstShare).clamp(0, 1)),
      color: color,
      width: width,
      taper: level.taper,
      seed: seed,
    );
    if (isSecond && progress > firstShare) {
      a = Offset(_mirrorX(size.width * 0.86, size.width, textDirection), y + 4);
      b = Offset(
        _mirrorX(size.width * 0.18, size.width, textDirection),
        y + 3.2,
      );
      final back = wobblyLine(a, b, seed: seed + 7, wobble: level.wobble * 0.6);
      paintInk(
        canvas,
        strokePrefix(back, (progress - firstShare) / (1 - firstShare)),
        color: color,
        width: width * 0.8,
        taper: 0.8,
        seed: seed + 7,
      );
    }
  }

  @override
  bool shouldRepaint(UnderlinePainter old) =>
      old.seed != seed ||
      old.color != color ||
      old.level != level ||
      old.width != width ||
      old.progress != progress ||
      old.textDirection != textDirection ||
      old.baseline != baseline;
}

// ----------------------------------------------------------------- the loop

/// A hand-closed circle around whatever is inside, drawn past its own start.
class LoopPainter extends CustomPainter {
  LoopPainter({
    required this.seed,
    this.color = HandInk.ink,
    this.width = HandStroke.pen,
    this.level = HandLevel.expressive,
    this.progress = 1,
    this.inflate = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.textDirection = TextDirection.ltr,
  });

  final int seed;
  final Color color;
  final double width;
  final HandLevel level;
  final double progress;
  final EdgeInsets inflate;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      -inflate.left,
      -inflate.top,
      size.width + inflate.right,
      size.height + inflate.bottom,
    );
    var pts = handLoop(
      r,
      seed: seed,
      wobble: level.wobble,
      overshoot: 0.06 + level.overshoot / 90,
    );
    if (textDirection == TextDirection.rtl) {
      pts = [for (final p in pts) Offset(size.width - p.dx, p.dy)];
    }
    paintInk(
      canvas,
      strokePrefix(pts, progress),
      color: color,
      width: width,
      taper: level.taper,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(LoopPainter old) =>
      old.seed != seed ||
      old.color != color ||
      old.width != width ||
      old.level != level ||
      old.progress != progress ||
      old.inflate != inflate ||
      old.textDirection != textDirection;
}

// ------------------------------------------------------------------ the tick

/// A tick: a short stroke down, a long one up. The long arm bows slightly.
class TickPainter extends CustomPainter {
  TickPainter({
    required this.seed,
    this.color = HandInk.done,
    this.width = HandStroke.felt,
    this.progress = 1,
  });

  final int seed;
  final Color color;
  final double width;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = HandRandom(seed);
    final a = Offset(w * 0.06, h * r.range(0.46, 0.56));
    final b = Offset(w * r.range(0.34, 0.4), h * 0.9);
    final c = Offset(w * 0.98, h * r.range(0.02, 0.12));
    final short = wobblyLine(a, b, seed: seed, wobble: 0.3, steps: 8);
    final long = wobblyCurve(
      b,
      Offset(w * 0.58, h * 0.36),
      c,
      seed: seed + 3,
      wobble: 0.5,
      steps: 16,
    );
    final pts = [...short, ...long.skip(1)];
    paintInk(
      canvas,
      strokePrefix(pts, progress),
      color: color,
      width: width,
      taper: 0.55,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(TickPainter old) =>
      old.seed != seed ||
      old.color != color ||
      old.width != width ||
      old.progress != progress;
}

// ----------------------------------------------------------------- the arrow

/// A pencil arrow from one point of its box to another, bowing on the way.
///
/// Points are given in the box's own 0–1 space so the arrow survives any
/// layout. They are written for left-to-right; in Arabic the whole arrow is
/// mirrored, so "pointing forward" stays pointing forward.
class ArrowPainter extends CustomPainter {
  ArrowPainter({
    required this.seed,
    this.from = const Offset(0.05, 0.15),
    this.to = const Offset(0.9, 0.85),
    this.bend = 0.35,
    this.color = HandInk.ink,
    this.width = HandStroke.fine,
    this.headSize = 9,
    this.progress = 1,
    this.textDirection = TextDirection.ltr,
  });

  final int seed;
  final Offset from;
  final Offset to;

  /// How far the shaft bows, as a share of its length. Negative bows the
  /// other way.
  final double bend;
  final Color color;
  final double width;
  final double headSize;
  final double progress;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Offset f) => Offset(
      _mirrorX(f.dx * size.width, size.width, textDirection),
      f.dy * size.height,
    );
    final a = at(from), b = at(to);
    final d = b - a;
    final len = d.distance;
    if (len < 4) return;
    final n = Offset(-d.dy / len, d.dx / len);
    final sign = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    final control = Offset.lerp(a, b, 0.5)! + n * (len * bend * sign);
    final shaft = wobblyCurve(a, control, b, seed: seed, wobble: 0.7);
    final shaftShare = 0.8;
    paintInk(
      canvas,
      strokePrefix(shaft, (progress / shaftShare).clamp(0, 1)),
      color: color,
      width: width,
      taper: 0.45,
      seed: seed,
    );
    if (progress <= shaftShare) return;
    final headT = (progress - shaftShare) / (1 - shaftShare);
    final end = shaft.last;
    final tan = end - shaft[shaft.length - 3];
    final ang = math.atan2(tan.dy, tan.dx);
    final r = HandRandom(seed + 11);
    for (final spread in [0.52 + r.signed(0.08), -0.46 + r.signed(0.08)]) {
      final tip =
          end -
          Offset(math.cos(ang + spread), math.sin(ang + spread)) *
              headSize *
              r.range(0.85, 1.1);
      paintInk(
        canvas,
        strokePrefix([end, Offset.lerp(end, tip, 0.5)!, tip], headT),
        color: color,
        width: width,
        taper: 0.6,
        seed: seed + 13,
      );
    }
  }

  @override
  bool shouldRepaint(ArrowPainter old) =>
      old.seed != seed ||
      old.from != from ||
      old.to != to ||
      old.bend != bend ||
      old.color != color ||
      old.width != width ||
      old.progress != progress ||
      old.textDirection != textDirection;
}

// ---------------------------------------------------------------- the marker

/// A marker swath laid behind a word: slightly tilted, ends not quite square,
/// denser where the nib paused.
class MarkerPainter extends CustomPainter {
  MarkerPainter({
    required this.seed,
    this.color = HandInk.marker,
    this.progress = 1,
    this.cover = 0.62,
    this.textDirection = TextDirection.ltr,
  });

  final int seed;
  final Color color;
  final double progress;

  /// How much of the text height the swath covers, from the bottom up.
  final double cover;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || progress <= 0) return;
    final r = HandRandom(seed);
    final h = size.height * cover;
    final top = size.height - h - size.height * 0.04;
    final tilt = r.signed(1.6);
    final padStart = r.range(3, 6), padEnd = r.range(4, 9);
    final x0 = -padStart;
    final x1 = x0 + (size.width + padStart + padEnd) * progress;
    final noise = HandNoise(seed);
    const steps = 14;
    final upper = <Offset>[];
    final lower = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = x0 + (x1 - x0) * t;
      final dy = tilt * (t - 0.5);
      upper.add(Offset(x, top + dy + noise.at(t) * 0.9));
      lower.add(Offset(x, top + h + dy + noise.at(1 - t) * 0.9));
    }
    // Ragged ends: a marker's square nib leaves a slanted, slightly frayed end.
    final path = Path()..moveTo(upper.first.dx + r.range(0, 2), upper.first.dy);
    for (final p in upper.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(lower.last.dx - r.range(1, 3.5), lower.last.dy);
    for (final p in lower.reversed.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    if (textDirection == TextDirection.rtl) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (textDirection == TextDirection.rtl) canvas.restore();
  }

  @override
  bool shouldRepaint(MarkerPainter old) =>
      old.seed != seed ||
      old.color != color ||
      old.progress != progress ||
      old.cover != cover ||
      old.textDirection != textDirection;
}

// ----------------------------------------------------------------- the rule

/// A drawn rule: a pencil line across, or a fine ink one.
class RulePainter extends CustomPainter {
  RulePainter({
    required this.seed,
    this.color = HandInk.pencil,
    this.ink = false,
    this.level = HandLevel.crafted,
    this.progress = 1,
    this.textDirection = TextDirection.ltr,
  });

  final int seed;
  final Color color;

  /// Ink rather than pencil.
  final bool ink;
  final HandLevel level;
  final double progress;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final pts = wobblyLine(
      Offset(_mirrorX(0, size.width, textDirection), y),
      Offset(_mirrorX(size.width, size.width, textDirection), y),
      seed: seed,
      wobble: level.wobble * 0.7,
      steps: math.max(8, (size.width / 14).round()),
    );
    final shown = strokePrefix(pts, progress);
    if (ink) {
      paintInk(
        canvas,
        shown,
        color: color,
        width: HandStroke.fine,
        taper: 0.3,
        seed: seed,
      );
    } else {
      paintPencil(canvas, shown, color: color, width: 1, seed: seed);
    }
  }

  @override
  bool shouldRepaint(RulePainter old) =>
      old.seed != seed ||
      old.color != color ||
      old.ink != ink ||
      old.level != level ||
      old.progress != progress ||
      old.textDirection != textDirection;
}

// ------------------------------------------------------------------ hatching

/// Pencil hatching inside a shape. Tone, the way a pencil makes it.
class HatchPainter extends CustomPainter {
  HatchPainter({
    required this.seed,
    this.color = HandInk.pencil,
    this.gap = 5,
    this.opacity = 0.32,
    this.angle = -0.9,
    this.radius = 0,
  });

  final int seed;
  final Color color;
  final double gap;
  final double opacity;
  final double angle;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final p = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = HandStroke.pencil
      ..strokeCap = StrokeCap.round;
    final r = HandRandom(seed);
    for (final l in hatchLines(rect, seed: seed, gap: gap, angle: angle)) {
      // A hand never hatches edge to edge; each stroke starts and stops a
      // little short, differently every time.
      final a = Offset.lerp(l[0], l[1], r.range(0.0, 0.04))!;
      final b = Offset.lerp(l[0], l[1], r.range(0.96, 1.0))!;
      canvas.drawLine(a, b, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HatchPainter old) =>
      old.seed != seed ||
      old.color != color ||
      old.gap != gap ||
      old.opacity != opacity ||
      old.angle != angle ||
      old.radius != radius;
}

// ------------------------------------------------------------------ surfaces

/// A corner named the way the page reads, so it turns round in Arabic.
enum HandCorner { topStart, topEnd, bottomEnd, bottomStart }

/// A surface: a fill, a drawn frame, and optionally a second outline set a
/// few pixels off, like a print whose colours did not quite register.
///
/// One corner is drawn looser than the other three. Which one is the seed's
/// choice, so two cards on a screen do not share it.
class SurfacePainter extends CustomPainter {
  SurfacePainter({
    required this.seed,
    this.fill,
    this.frame,
    this.frameWidth = HandStroke.fine,
    this.level = HandLevel.crafted,
    this.radius = 6,
    this.looseCorner = 16,
    this.offsetOutline,
    this.offset = const Offset(3, 3),
    this.bodyShift = Offset.zero,
    this.dashed = false,
    this.hatch,
    this.looseAt,
    this.hatchOpacity = 0.22,
    this.textDirection = TextDirection.ltr,
  });

  final int seed;
  final Color? fill;
  final Color? frame;
  final double frameWidth;
  final HandLevel level;

  /// The three disciplined corners.
  final double radius;

  /// The one loose corner.
  final double looseCorner;

  /// The misregistered second outline, or null for none.
  final Color? offsetOutline;
  final Offset offset;

  /// Moves the body toward its outline — the press.
  final Offset bodyShift;

  /// A dashed pencil frame: space waiting to be filled in.
  final bool dashed;

  /// Pencil hatching over the fill, for tone.
  final Color? hatch;

  /// How dark the hatching is. Tone is set by density and weight, never by a
  /// gradient.
  final double hatchOpacity;

  /// Which corner is the loose one, when it carries meaning — a speech
  /// bubble's tail. Null leaves it to the seed.
  final HandCorner? looseAt;

  final TextDirection textDirection;

  static final Map<int, List<Offset>> _cache = {};

  /// The loose corner as an index into top-left, top-right, bottom-right,
  /// bottom-left, turned round for right-to-left.
  int _looseIndex(int s) {
    final at = looseAt;
    if (at == null) return (HandRandom(s).next() * 4).floor().clamp(0, 3);
    final rtl = textDirection == TextDirection.rtl;
    return switch (at) {
      HandCorner.topStart => rtl ? 1 : 0,
      HandCorner.topEnd => rtl ? 0 : 1,
      HandCorner.bottomEnd => rtl ? 3 : 2,
      HandCorner.bottomStart => rtl ? 2 : 3,
    };
  }

  /// The outline's points, local to [size], walked from the seed's corner.
  List<Offset> _points(Size size, int s, double wobble) {
    final loose = _looseIndex(s);
    final key = handSeed([
      s,
      size.width.round(),
      size.height.round(),
      wobble,
      radius,
      looseCorner,
      loose,
    ]);
    final hit = _cache[key];
    if (hit != null) return hit;
    final corners = [radius, radius, radius, radius];
    corners[loose] = looseCorner;
    var pts = perturbLoop(
      roundedRectPoints(
        Offset.zero & size,
        tl: corners[0],
        tr: corners[1],
        br: corners[2],
        bl: corners[3],
        spacing: 6,
      ),
      seed: s,
      wobble: wobble,
    );
    // Start the pen somewhere of the seed's choosing, not always top-left.
    final start = (HandRandom(s + 1).next() * pts.length).floor();
    pts = [...pts.sublist(start), ...pts.sublist(0, start)];
    if (_cache.length > 400) _cache.clear();
    _cache[key] = pts;
    return pts;
  }

  static List<Offset> _shift(List<Offset> pts, Offset by) =>
      by == Offset.zero ? pts : [for (final p in pts) p + by];

  /// The frame as one nib stroke: round once, and a little past the start,
  /// so the two ends overlap where the pen came back.
  void _frameStroke(
    Canvas canvas,
    List<Offset> loop,
    Color color,
    double width,
    int s,
  ) {
    if (loop.length < 4) return;
    final r = HandRandom(s + 2);
    final overlap = (loop.length * r.range(0.02, 0.05)).ceil();
    final closed = [...loop, ...loop.take(overlap + 1)];
    // Lift off slightly outward at the end, the way a pen leaves a line.
    final last = closed.length - 1;
    final tan = closed[last] - closed[last - 1];
    final l = tan.distance;
    if (l > 0) {
      closed[last] =
          closed[last] + Offset(tan.dy / l, -tan.dx / l) * r.range(0.6, 1.6);
    }
    paintInk(canvas, closed, color: color, width: width, taper: 0.22, seed: s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final dirSign = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    final o = Offset(offset.dx * dirSign, offset.dy);
    final shift = Offset(bodyShift.dx * dirSign, bodyShift.dy);

    if (offsetOutline != null) {
      // A different seed and a looser hand than the body, so the outline
      // disagrees with it slightly — misregistration, not a copy.
      final outline = _shift(_points(size, seed + 101, level.wobble + 0.9), o);
      _frameStroke(canvas, outline, offsetOutline!, frameWidth, seed + 101);
    }

    final bodyPts = _shift(_points(size, seed, level.wobble), shift);
    final body = smoothPath(bodyPts, close: true);
    if (fill != null) {
      canvas.drawPath(body, Paint()..color = fill!);
    }
    if (hatch != null) {
      canvas.save();
      canvas.clipPath(body);
      HatchPainter(
        seed: seed,
        color: hatch!,
        gap: 6,
        opacity: hatchOpacity,
      ).paint(canvas, size);
      canvas.restore();
    }
    if (frame == null) return;
    if (dashed) {
      final paint = Paint()
        ..color = frame!
        ..style = PaintingStyle.stroke
        ..strokeWidth = frameWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      final r = HandRandom(seed);
      for (final m in body.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          final dash = r.range(5, 9);
          canvas.drawPath(m.extractPath(d, d + dash), paint);
          d += dash + r.range(4, 6);
        }
      }
    } else if (level == HandLevel.structural) {
      canvas.drawPath(
        body,
        Paint()
          ..color = frame!
          ..style = PaintingStyle.stroke
          ..strokeWidth = frameWidth
          ..isAntiAlias = true,
      );
    } else {
      _frameStroke(canvas, bodyPts, frame!, frameWidth, seed);
    }
  }

  @override
  bool shouldRepaint(SurfacePainter old) =>
      old.seed != seed ||
      old.fill != fill ||
      old.frame != frame ||
      old.frameWidth != frameWidth ||
      old.level != level ||
      old.radius != radius ||
      old.looseCorner != looseCorner ||
      old.offsetOutline != offsetOutline ||
      old.offset != offset ||
      old.bodyShift != bodyShift ||
      old.dashed != dashed ||
      old.hatch != hatch ||
      old.looseAt != looseAt ||
      old.hatchOpacity != hatchOpacity ||
      old.textDirection != textDirection;
}

// ------------------------------------------------------------------ the ring

/// A ring painted by hand over a pencil guide.
///
/// The **value is exact**: the painted arc starts at twelve o'clock and sweeps
/// precisely `fraction` of the circle. Only the nib's pressure varies, across
/// the stroke, never along it — a hand-painted ring that overstated her week
/// would be a lie with good manners.
class RingPainter extends CustomPainter {
  RingPainter({
    required this.seed,
    required this.fraction,
    required this.thickness,
    required this.color,
    this.guide = HandInk.pencil,
    this.progress = 1,
    this.textDirection = TextDirection.ltr,
  });

  final int seed;
  final double fraction;
  final double thickness;
  final Color color;
  final Color guide;
  final double progress;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rad = (math.min(size.width, size.height) - thickness) / 2;
    // The guide: a pencil circle, drawn once round and a touch past.
    final guideLoop = handLoop(
      Rect.fromCircle(center: c, radius: rad),
      seed: seed,
      wobble: 0.6,
      overshoot: 0.05,
    );
    paintPencil(
      canvas,
      guideLoop,
      color: guide,
      width: 1,
      opacity: 0.8,
      seed: seed,
    );

    final f = fraction.clamp(0.0, 1.0) * progress;
    if (f <= 0) return;
    final steps = math.max(6, (f * 72).round());
    final noise = HandNoise(seed + 5);
    // Clockwise in English; in Arabic the ring fills the way the page reads.
    final dir = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    final pts = [
      for (var i = 0; i <= steps; i++)
        () {
          final t = i / steps;
          final a = -math.pi / 2 + dir * math.pi * 2 * f * t;
          final rr = rad + noise.at(t) * 0.6;
          return c + Offset(math.cos(a), math.sin(a)) * rr;
        }(),
    ];
    paintInk(
      canvas,
      pts,
      color: color,
      width: thickness,
      taper: 0.12,
      seed: seed,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.seed != seed ||
      old.fraction != fraction ||
      old.thickness != thickness ||
      old.color != color ||
      old.guide != guide ||
      old.progress != progress ||
      old.textDirection != textDirection;
}

// ------------------------------------------------------------------- paper

/// A faint paper grain for the page, rendered once into a tile and repeated.
class PaperGrainPainter extends CustomPainter {
  const PaperGrainPainter();

  static ui.Image? _tile;
  static bool _failed = false;

  static ui.Image? _build() {
    if (_tile != null || _failed) return _tile;
    try {
      const px = 384;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final r = HandRandom(0x0ff1ce);
      final p = Paint();
      for (var i = 0; i < 1600; i++) {
        p.color = HandInk.print.withValues(alpha: r.range(0.018, 0.05));
        c.drawCircle(
          Offset(r.next() * px, r.next() * px),
          r.range(0.35, 0.9),
          p,
        );
      }
      // A few fibres, the way uncoated stock shows them.
      final fibre = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = HandInk.pencil.withValues(alpha: 0.05);
      for (var i = 0; i < 28; i++) {
        final a = Offset(r.next() * px, r.next() * px);
        final b = a + Offset(r.signed(9), r.signed(5));
        c.drawLine(a, b, fibre);
      }
      _tile = rec.endRecording().toImageSync(px, px);
    } catch (_) {
      _failed = true;
    }
    return _tile;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = _build();
    if (tile == null) return;
    // Rendered at 2x and drawn at half size, so the grain stays fine on a
    // high-density screen.
    final m = Matrix4.diagonal3Values(0.5, 0.5, 1).storage;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(tile, TileMode.repeated, TileMode.repeated, m),
    );
  }

  @override
  bool shouldRepaint(PaperGrainPainter old) => false;
}
