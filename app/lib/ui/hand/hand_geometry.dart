/// The geometry behind every hand-drawn mark.
///
/// ## Why everything here is seeded
///
/// A hand-drawn line has to look individually drawn and then hold still. If
/// the wobble were random on every frame the app would shimmer; if every card
/// used the same wobble they would all be the same card. So each mark takes a
/// `seed`: the same seed draws the same shape every time, and a different seed
/// draws a different one. Nothing here reads a clock or a global random source.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Deterministic randomness. Same seed, same sequence, every run.
class HandRandom {
  HandRandom(int seed) : _r = math.Random(seed & 0x7fffffff);

  final math.Random _r;

  double next() => _r.nextDouble();

  double range(double a, double b) => a + (b - a) * _r.nextDouble();

  /// A value in [-amp, amp].
  double signed(double amp) => (_r.nextDouble() * 2 - 1) * amp;
}

/// Smooth 1-D noise from a few seeded sines.
///
/// Hands drift slowly, so this is deliberately low-frequency: a line bows and
/// recovers rather than trembling.
class HandNoise {
  HandNoise(int seed) {
    final r = HandRandom(seed);
    for (var i = 0; i < 3; i++) {
      _freq.add(r.range(0.55, 1.35) * (i + 1));
      _phase.add(r.range(0, math.pi * 2));
      _amp.add(1.0 / (i + 1));
    }
    _norm = _amp.fold<double>(0, (a, b) => a + b);
  }

  final List<double> _freq = [];
  final List<double> _phase = [];
  final List<double> _amp = [];
  late final double _norm;

  /// `t` in [0, 1] gives roughly [-1, 1].
  double at(double t) {
    var v = 0.0;
    for (var i = 0; i < _freq.length; i++) {
      v += _amp[i] * math.sin(t * math.pi * 2 * _freq[i] + _phase[i]);
    }
    return v / _norm;
  }
}

/// Combines numbers into one stable seed.
int handSeed(Iterable<Object?> parts) {
  var h = 0x2545F491;
  for (final p in parts) {
    h = (h * 31 + (p?.hashCode ?? 0)) & 0x7fffffff;
  }
  return h;
}

/// A straight line as a hand draws it: bowing gently, running past its ends.
List<Offset> wobblyLine(
  Offset a,
  Offset b, {
  required int seed,
  double wobble = 1,
  double overshootStart = 0,
  double overshootEnd = 0,
  int steps = 22,
}) {
  final d = b - a;
  final len = d.distance;
  if (len < 0.001) return [a, b];
  final u = d / len;
  final n = Offset(-u.dy, u.dx);
  final start = a - u * overshootStart;
  final total = len + overshootStart + overshootEnd;
  final noise = HandNoise(seed);
  return [
    for (var i = 0; i <= steps; i++)
      start + u * (total * i / steps) + n * (noise.at(i / steps) * wobble),
  ];
}

/// A quadratic curve sampled into points, with a hand's drift along it.
List<Offset> wobblyCurve(
  Offset a,
  Offset control,
  Offset b, {
  required int seed,
  double wobble = 1,
  int steps = 26,
}) {
  final noise = HandNoise(seed);
  final pts = <Offset>[];
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final mt = 1 - t;
    final p = a * (mt * mt) + control * (2 * mt * t) + b * (t * t);
    final tan = (control - a) * (2 * mt) + (b - control) * (2 * t);
    final l = tan.distance;
    final n = l == 0 ? Offset.zero : Offset(-tan.dy / l, tan.dx / l);
    pts.add(p + n * (noise.at(t) * wobble));
  }
  return pts;
}

/// The outline of a rectangle with its own radius at each corner, walked once
/// around and sampled at roughly `spacing` pixels.
List<Offset> roundedRectPoints(
  Rect r, {
  double tl = 0,
  double tr = 0,
  double br = 0,
  double bl = 0,
  double spacing = 7,
}) {
  final pts = <Offset>[];
  void edge(Offset a, Offset b) {
    final n = math.max(1, ((b - a).distance / spacing).round());
    for (var i = 0; i < n; i++) {
      pts.add(Offset.lerp(a, b, i / n)!);
    }
  }

  void arc(Offset c, double rad, double a0) {
    if (rad <= 0.5) return;
    final n = math.max(3, (rad * math.pi / 2 / spacing).round());
    for (var i = 0; i < n; i++) {
      final a = a0 + (math.pi / 2) * (i / n);
      pts.add(c + Offset(math.cos(a), math.sin(a)) * rad);
    }
  }

  final w = r.width, h = r.height;
  double cap(double v) => v.clamp(0, math.min(w, h) / 2).toDouble();
  final a = cap(tl), b = cap(tr), c = cap(br), d = cap(bl);
  edge(Offset(r.left + a, r.top), Offset(r.right - b, r.top));
  arc(Offset(r.right - b, r.top + b), b, -math.pi / 2);
  edge(Offset(r.right, r.top + b), Offset(r.right, r.bottom - c));
  arc(Offset(r.right - c, r.bottom - c), c, 0);
  edge(Offset(r.right - c, r.bottom), Offset(r.left + d, r.bottom));
  arc(Offset(r.left + d, r.bottom - d), d, math.pi / 2);
  edge(Offset(r.left, r.bottom - d), Offset(r.left, r.top + a));
  arc(Offset(r.left + a, r.top + a), a, math.pi);
  return pts;
}

/// Pushes each point of a closed outline in or out along its normal.
List<Offset> perturbLoop(
  List<Offset> loop, {
  required int seed,
  double wobble = 1,
}) {
  if (loop.length < 3 || wobble == 0) return loop;
  final noise = HandNoise(seed);
  final out = <Offset>[];
  for (var i = 0; i < loop.length; i++) {
    final prev = loop[(i - 1 + loop.length) % loop.length];
    final next = loop[(i + 1) % loop.length];
    final tan = next - prev;
    final l = tan.distance;
    final n = l == 0 ? Offset.zero : Offset(tan.dy / l, -tan.dx / l);
    out.add(loop[i] + n * (noise.at(i / loop.length) * wobble));
  }
  return out;
}

/// A loop drawn by hand: it starts, goes round, and runs a little past where
/// it began, drifting outward so the ends overlap instead of meeting.
List<Offset> handLoop(
  Rect r, {
  required int seed,
  double wobble = 1.5,
  double overshoot = 0.14,
  int steps = 72,
}) {
  final rnd = HandRandom(seed);
  final noise = HandNoise(seed ^ 0x51ed27);
  final c = r.center;
  final rx = r.width / 2, ry = r.height / 2;
  // A right hand usually starts a circle up and to the left.
  final a0 = -math.pi * 0.72 + rnd.signed(0.35);
  final sweep = math.pi * 2 * (1 + overshoot);
  final spiral = rnd.range(0.035, 0.07);
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final t = i / steps;
        final ang = a0 + sweep * t;
        final k =
            1 + (t - 0.5) * spiral + noise.at(t) * wobble / math.max(rx, 1);
        return c + Offset(math.cos(ang) * rx * k, math.sin(ang) * ry * k);
      }(),
  ];
}

/// A smooth path through points (Catmull-Rom, drawn as cubic Béziers).
Path smoothPath(List<Offset> pts, {bool close = false}) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  _appendSmooth(path, pts, closed: close);
  if (close) path.close();
  return path;
}

void _appendSmooth(Path path, List<Offset> pts, {bool closed = false}) {
  final n = pts.length;
  Offset at(int i) {
    if (closed) return pts[(i + n) % n];
    return pts[i.clamp(0, n - 1)];
  }

  final last = closed ? n : n - 1;
  for (var i = 0; i < last; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
}

/// A stroke drawn with a real nib: a filled shape that thins toward its ends
/// and varies a little in weight along the way.
///
/// This is where the ink quality comes from. A uniform `Paint.strokeWidth`
/// line always reads as drawn by software, however much the path wobbles.
Path inkPath(
  List<Offset> pts, {
  required double width,
  double taper = 0.5,
  int seed = 0,
}) {
  if (pts.length < 2) return Path();
  final noise = HandNoise(seed ^ 0x6a09e6);
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    final prev = pts[math.max(0, i - 1)];
    final next = pts[math.min(pts.length - 1, i + 1)];
    final tan = next - prev;
    final l = tan.distance;
    final n = l == 0 ? const Offset(0, 1) : Offset(-tan.dy / l, tan.dx / l);
    final t = i / (pts.length - 1);
    // Thin at both ends, full through the middle, never quite constant.
    final profile = (1 - taper) + taper * math.sin(math.pi * t);
    final pressure = 1 + noise.at(t) * 0.18;
    final half = math.max(0.25, width / 2 * profile * pressure);
    left.add(pts[i] + n * half);
    right.add(pts[i] - n * half);
  }
  final path = Path()..moveTo(left.first.dx, left.first.dy);
  _appendSmooth(path, left);
  final back = right.reversed.toList();
  path.lineTo(back.first.dx, back.first.dy);
  _appendSmooth(path, back);
  path.close();
  return path;
}

/// Parallel pencil strokes filling a rectangle at an angle, for tone.
///
/// Tone in this system comes from hatching density, never from gradients.
List<List<Offset>> hatchLines(
  Rect r, {
  required int seed,
  double gap = 5,
  double angle = -0.9,
}) {
  final rnd = HandRandom(seed);
  final dir = Offset(math.cos(angle), math.sin(angle));
  final nrm = Offset(-dir.dy, dir.dx);
  final diag = r.size.longestSide * 1.5;
  final lines = <List<Offset>>[];
  for (var o = -diag; o <= diag; o += gap + rnd.signed(gap * 0.25)) {
    final c = r.center + nrm * o;
    lines.add([c - dir * diag, c + dir * diag]);
  }
  return lines;
}
