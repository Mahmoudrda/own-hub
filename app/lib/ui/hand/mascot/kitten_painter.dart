/// The kitten: the one character in the product, drawn in the rose tone.
///
/// It is the owner's chosen design (A1): a rose kitten with two big soft ears,
/// deep rose inner ears and eyes, and a small ":3" mouth. Here it is rebuilt
/// from parts so it can move, and painted the way every other mark in the app
/// is painted: a solid [ArtTones.rose] fill with its deeper line drawn round
/// it, wobbling a little because a hand drew it.
///
/// Everything is laid out in a 1 x 1 box and scaled once, so the outlines are
/// built a single time for the whole app and a frame only moves six parts.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../theme/hand_tokens.dart';
import '../art_palette.dart';
import '../hand_geometry.dart';

/// What the kitten does when it appears.
///
/// Every pose is one move of 1.2 s or less followed by two slow breaths,
/// and it ends still on its last frame. Nothing loops.
enum KittenPose {
  /// Already there. Breathes, blinks once, and stops.
  rest(0, physical: false),

  /// Raises the leading paw and waves twice. For a first hello.
  wave(1100, physical: false),

  /// Reaches the leading paw toward what to do next, and looks at it.
  point(900, physical: false),

  /// Hops with both paws up. Only at the end of something.
  cheer(1200, physical: false),

  /// Turns its face to her left as she sees it in the front camera.
  lookLeft(700, physical: true),

  /// Turns its face to her right as she sees it in the front camera.
  lookRight(700, physical: true),

  /// Blinks twice, slowly.
  blink(700, physical: true);

  const KittenPose(this.moveMs, {required this.physical});

  /// How long the move itself takes, before the breathing.
  final int moveMs;

  /// A demonstration of her own body in the camera. These follow the camera,
  /// so they are never mirrored for Arabic; every other pose is, so "point
  /// forward" points the way the page is read.
  final bool physical;
}

/// One slow breath, in milliseconds.
const int kittenBreathMs = 1300;

/// Breaths after the move. Then it is still.
const int kittenBreaths = 2;

/// The whole one-shot run of [pose], move and breaths together.
Duration kittenRunFor(KittenPose pose) =>
    Duration(milliseconds: pose.moveMs + kittenBreathMs * kittenBreaths);

/// Where every moving part is at one instant.
@immutable
class KittenFrame {
  const KittenFrame({
    this.lift = 0,
    this.squash = 1,
    this.headTilt = 0,
    this.lead = _armRest,
    this.trail = _armRest,
    this.look = Offset.zero,
    this.eyeOpen = 1,
    this.happy = 0,
    this.smile = 0,
    this.tail = 0,
    this.ear = 0,
  });

  /// How far the whole kitten is above where it sits, in box units.
  final double lift;

  /// Body height against its resting height; below 1 is squashed down.
  final double squash;

  /// Head rotation in radians, positive toward the leading side.
  final double headTilt;

  /// Leading and trailing arm angles: 0 hangs straight down, pi/2 is out to
  /// the side, pi is straight up.
  final double lead;
  final double trail;

  /// Where the face is turned, -1 to 1 on each axis.
  final Offset look;

  /// 1 open, 0 shut.
  final double eyeOpen;

  /// Above 0.5 the eyes are drawn as smiling arcs.
  final double happy;

  /// Above 0.5 the ":3" becomes an open smile.
  final double smile;

  /// Tail swing in radians.
  final double tail;

  /// Twitch of the trailing ear in radians.
  final double ear;

  /// Where [pose] is at [ms] into its run.
  factory KittenFrame.at(KittenPose pose, double ms) {
    final move = _move(pose, math.min(ms, pose.moveMs.toDouble()));
    final k = (ms - pose.moveMs) / kittenBreathMs;
    if (k <= 0) return move;
    final end = math.min(k, kittenBreaths.toDouble());
    // Whole breaths, so the last one lands exactly where it started.
    final breath = math.sin(2 * math.pi * end);
    return KittenFrame(
      lift: move.lift,
      squash: move.squash * (1 + 0.02 * breath),
      headTilt: move.headTilt,
      lead: move.lead,
      trail: move.trail,
      look: move.look,
      eyeOpen: move.eyeOpen * (1 - _bump(end, 0.55, 0.72)),
      happy: move.happy,
      smile: move.smile,
      tail: 0.24 * math.sin(math.pi * end),
      ear: 0.18 * _bump(end, 1.35, 1.55),
    );
  }

  /// The frame a still kitten shows: the end of the run.
  factory KittenFrame.end(KittenPose pose) =>
      KittenFrame.at(pose, kittenRunFor(pose).inMilliseconds.toDouble());

  static KittenFrame _move(KittenPose pose, double ms) {
    final u = pose.moveMs == 0 ? 1.0 : ms / pose.moveMs;
    // Every move arrives the same way: up from a little low, a small give.
    final arrive = pose.moveMs == 0 ? 0.0 : 0.05 * (1 - _ramp(u, 0, 0.3));
    final give = 1 - 0.05 * _bump(u, 0.22, 0.42);
    switch (pose) {
      case KittenPose.rest:
        return const KittenFrame();
      case KittenPose.wave:
        final up = _ramp(u, 0.1, 0.32);
        final down = _ramp(u, 0.82, 1);
        final shake = u > 0.32 && u < 0.82
            ? 0.32 * math.sin(2 * math.pi * 2 * (u - 0.32) / 0.5)
            : 0.0;
        return KittenFrame(
          lift: -arrive,
          squash: give,
          lead: _armRest + (2.5 - _armRest) * up - (2.5 - 0.95) * down + shake,
          headTilt: 0.08 * _bump(u, 0.15, 0.95),
          eyeOpen: 1 - _bump(u, 0.66, 0.76),
        );
      case KittenPose.point:
        final reach = _ramp(u, 0.1, 0.45);
        return KittenFrame(
          lift: -arrive,
          squash: give,
          lead: _armRest + (1.6 - _armRest) * reach - 0.14 * _bump(u, 0.5, 0.8),
          look: Offset(reach, -0.2 * reach),
          headTilt: 0.07 * reach,
        );
      case KittenPose.cheer:
        final up = _ramp(u, 0.12, 0.3);
        final settle = _ramp(u, 0.7, 1);
        final arms = _armRest + (2.05 - _armRest) * up - 0.3 * settle;
        return KittenFrame(
          lift: -arrive + 0.07 * _bump(u, 0.18, 0.6),
          squash:
              give *
              (1 - 0.07 * _bump(u, 0, 0.18) + 0.05 * _bump(u, 0.18, 0.45)) *
              (1 - 0.06 * _bump(u, 0.58, 0.72)),
          lead: arms,
          trail: arms,
          happy: _ramp(u, 0.15, 0.25),
          smile: _ramp(u, 0.1, 0.3),
        );
      case KittenPose.lookLeft:
      case KittenPose.lookRight:
        final s = pose == KittenPose.lookLeft ? -1.0 : 1.0;
        final turn = _ramp(u, 0.1, 0.6);
        return KittenFrame(
          lift: -arrive,
          look: Offset(s * turn, 0),
          headTilt: s * 0.06 * turn,
        );
      case KittenPose.blink:
        return KittenFrame(
          lift: -arrive,
          eyeOpen: 1 - _bump(u, 0.2, 0.38) - _bump(u, 0.55, 0.73),
        );
    }
  }
}

const double _armRest = 0.18;

double _ramp(double t, double a, double b) =>
    HandMotion.pen.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

double _bump(double t, double a, double b) =>
    t <= a || t >= b ? 0 : math.sin(math.pi * (t - a) / (b - a));

/// Paints the kitten at whatever [progress] says, 0 to 1 through its run.
class KittenPainter extends CustomPainter {
  KittenPainter({required this.progress, required this.pose, required this.rtl})
    : super(repaint: progress);

  final Animation<double> progress;
  final KittenPose pose;
  final bool rtl;

  static const ArtTone _tone = ArtTones.rose;

  static Paint _stroke(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _line = _stroke(_tone.line);
  static final Paint _mark = _stroke(_tone.line);
  static final Paint _tubeEdge = _stroke(_tone.line);
  static final Paint _tubeFill = _stroke(_tone.fill);
  static final Paint _fill = Paint()..color = _tone.fill;
  static final Paint _ink = Paint()..color = _tone.line;
  static final Paint _shine = Paint()..color = HandInk.page;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final run = kittenRunFor(pose).inMilliseconds;
    final f = KittenFrame.at(pose, progress.value * run);

    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    if (rtl && !pose.physical) {
      canvas.translate(s, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(s);
    _paintKitten(canvas, f, _nibFor(s));
    canvas.restore();
  }

  /// The line in box units: heavier than an object's, like the app's figures,
  /// and never under 1.4 px however small the kitten is drawn.
  static double _nibFor(double s) => math.max(1.4, s * 0.034) / s;

  static void _paintKitten(Canvas canvas, KittenFrame f, double nib) {
    // Reused, never built per frame: only their widths change with size.
    final line = _line..strokeWidth = nib;
    final fill = _fill;
    final ink = _ink;
    final mark = _mark;

    void shape(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, line);
    }

    // A limb is a soft tube: the line colour drawn wide, the fill inside it.
    void tube(Path p, double width) {
      canvas.drawPath(p, _tubeEdge..strokeWidth = width + nib * 2);
      canvas.drawPath(p, _tubeFill..strokeWidth = width);
    }

    void arm(double side, double angle) {
      final shoulder = Offset(0.5 + side * 0.13, 0.82);
      final end =
          shoulder + Offset(side * math.sin(angle), math.cos(angle)) * 0.1;
      tube(
        Path()
          ..moveTo(shoulder.dx, shoulder.dy)
          ..lineTo(end.dx, end.dy),
        0.115,
      );
    }

    canvas.save();
    canvas.translate(0, f.lift);

    // Tail, behind everything, swinging from where it meets the body.
    canvas.save();
    canvas.translate(0.29, 0.9);
    canvas.rotate(-f.tail);
    tube(_parts.tail, 0.075);
    canvas.restore();

    // Body, squashing toward the floor it sits on.
    canvas.save();
    canvas.translate(0.5, 0.97);
    canvas.scale(1, f.squash);
    canvas.translate(-0.5, -0.97);
    shape(_parts.body);
    canvas.restore();

    // Head, ears and face ride on top of the body.
    canvas.save();
    canvas.translate(0, 0.38 * (1 - f.squash));
    canvas.translate(0.5, 0.68);
    canvas.rotate(f.headTilt);
    canvas.translate(-0.5, -0.68);

    shape(_parts.earLead);
    canvas.drawPath(_parts.innerLead, ink);
    canvas.save();
    canvas.translate(0.31, 0.235);
    canvas.rotate(-f.ear);
    canvas.translate(-0.31, -0.235);
    shape(_parts.earTrail);
    canvas.drawPath(_parts.innerTrail, ink);
    canvas.restore();
    shape(_parts.head);

    final fx = 0.07 * f.look.dx;
    final fy = 0.045 * f.look.dy;
    for (final side in const [-1.0, 1.0]) {
      final c = Offset(0.5 + side * 0.135 + fx, 0.505 + fy);
      // The eye on the side she turns toward comes nearer, so a little bigger.
      final r = 0.066 * (1 + 0.14 * side * f.look.dx);
      if (f.happy > 0.5) {
        canvas.drawPath(
          Path()..addArc(
            Rect.fromCircle(center: c.translate(0, r * 0.4), radius: r),
            math.pi * 1.1,
            math.pi * 0.8,
          ),
          mark..strokeWidth = nib * 1.5,
        );
        continue;
      }
      final open = f.eyeOpen.clamp(0.08, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * 2 * open),
        ink,
      );
      if (open > 0.6) {
        canvas.drawCircle(c.translate(-r * 0.3, -r * 0.35), r * 0.32, _shine);
      }
    }

    final m = Offset(0.5 + fx, 0.6 + fy);
    if (f.smile > 0.5) {
      canvas.drawPath(
        Path()
          ..moveTo(m.dx - 0.045, m.dy - 0.008)
          ..quadraticBezierTo(m.dx, m.dy + 0.07, m.dx + 0.045, m.dy - 0.008)
          ..close(),
        ink,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(m.dx - 0.048, m.dy - 0.006)
          ..quadraticBezierTo(m.dx - 0.024, m.dy + 0.03, m.dx, m.dy)
          ..quadraticBezierTo(
            m.dx + 0.024,
            m.dy + 0.03,
            m.dx + 0.048,
            m.dy - 0.006,
          ),
        mark..strokeWidth = nib * 1.1,
      );
    }
    canvas.restore();

    // Paws last, so a raised paw is in front of the face, never behind it.
    arm(-1, f.trail);
    arm(1, f.lead);
    canvas.restore();
  }

  @override
  bool shouldRepaint(KittenPainter old) =>
      old.pose != pose || old.rtl != rtl || old.progress != progress;
}

/// The kitten's outlines, built once in the 1 x 1 box.
final _KittenParts _parts = _KittenParts();

class _KittenParts {
  _KittenParts() {
    final seed = handSeed(['mascot', 'kitten']);
    head = _closed(_blob(const Offset(0.5, 0.48), 0.36, 0.27, 2.6), seed);
    body = _closed(_blob(const Offset(0.5, 0.82), 0.25, 0.15, 2.2), seed + 1);
    // The leading ear sits on the right; the painter mirrors it for Arabic.
    earLead = _closed(_ear(const Offset(0.69, 0.235), 1, 1), seed + 2);
    innerLead = _closed(_ear(const Offset(0.69, 0.25), 1, 0.62), seed + 3);
    earTrail = _closed(_ear(const Offset(0.31, 0.235), -1, 1), seed + 4);
    innerTrail = _closed(_ear(const Offset(0.31, 0.25), -1, 0.62), seed + 5);
    tail = Path()
      ..moveTo(0, 0)
      ..cubicTo(-0.12, -0.02, -0.17, -0.12, -0.14, -0.24);
  }

  late final Path head;
  late final Path body;
  late final Path earLead;
  late final Path innerLead;
  late final Path earTrail;
  late final Path innerTrail;
  late final Path tail;

  static Path _closed(List<Offset> pts, int seed) =>
      smoothPath(perturbLoop(pts, seed: seed, wobble: 0.0035), close: true);

  /// A rounded box-ish oval: wider in the cheeks than an ellipse.
  static List<Offset> _blob(Offset c, double rx, double ry, double n) => [
    for (var i = 0; i < 48; i++)
      () {
        final a = 2 * math.pi * i / 48;
        final ca = math.cos(a), sa = math.sin(a);
        return c +
            Offset(
              rx * ca.sign * math.pow(ca.abs(), 2 / n),
              ry * sa.sign * math.pow(sa.abs(), 2 / n),
            );
      }(),
  ];

  /// A soft triangle with a blunt tip, leaning out to [side].
  static List<Offset> _ear(Offset base, double side, double k) {
    final tip = base + Offset(side * 0.07, -0.215) * k;
    final inner = base + Offset(-side * 0.13, 0.03) * k;
    final outer = base + Offset(side * 0.13, 0.11) * k;
    final pts = <Offset>[];
    // Corners pulled in, so the tip is round and nothing reads as sharp.
    void corner(Offset from, Offset at, Offset to) {
      pts.add(Offset.lerp(from, at, 0.62)!);
      pts.add(Offset.lerp(at, Offset.lerp(from, to, 0.5)!, 0.18)!);
      pts.add(Offset.lerp(to, at, 0.62)!);
    }

    corner(outer, inner, tip);
    corner(inner, tip, outer);
    corner(tip, outer, inner);
    return pts;
  }
}
