/// The kitten: the one character in the product, drawn in the rose tone.
///
/// It is the owner's chosen design (A1): a round, soft rose kitten whose head
/// is most of it, two big ears with blunt tips and deep rose insides, big
/// wide-set deep rose eyes with one light catch each, and a small ":3" mouth.
/// Flat colour, no outline: a paw in front of the body is told apart by a
/// slightly deeper rose edge, nothing darker.
///
/// Everything is laid out in a 1 x 1 box and built once for the whole app;
/// a frame only moves a few parts with the canvas and draws two short lines
/// per arm, so per-frame work stays tiny.
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

  /// Raises the leading paw beside its face, waves twice, lowers it.
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
    this.leadPaw = _pawRest,
    this.trailPaw = _pawRest,
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

  /// Leading and trailing upper arm angles: 0 hangs straight down, pi/2 is
  /// out to the side, pi is straight up.
  final double lead;
  final double trail;

  /// Leading and trailing forearm angles, measured the same way as the arm.
  final double leadPaw;
  final double trailPaw;

  /// Where the face is turned, -1 to 1 on each axis.
  final Offset look;

  /// 1 open, 0 shut.
  final double eyeOpen;

  /// 0 round eyes, 1 smiling arcs; in between the round eyes squeeze shut.
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
    // Whole breaths that start and end at rest, so nothing jumps where the
    // move hands over and the last one lands exactly where it started.
    final breath = (1 - math.cos(2 * math.pi * end)) / 2;
    final sway = math.sin(math.pi * end / kittenBreaths);
    return KittenFrame(
      lift: move.lift,
      squash: move.squash * (1 + 0.02 * breath),
      headTilt: move.headTilt,
      lead: move.lead,
      trail: move.trail,
      leadPaw: move.leadPaw,
      trailPaw: move.trailPaw,
      look: move.look,
      eyeOpen: move.eyeOpen * (1 - _hump(end, 0.5, 0.75)),
      happy: move.happy,
      smile: move.smile,
      tail: 0.22 * sway * sway,
      ear: 0.16 * _hump(end, 1.3, 1.6),
    );
  }

  /// The frame a still kitten shows: the end of the run.
  factory KittenFrame.end(KittenPose pose) =>
      KittenFrame.at(pose, kittenRunFor(pose).inMilliseconds.toDouble());

  static KittenFrame _move(KittenPose pose, double ms) {
    final u = pose.moveMs == 0 ? 1.0 : ms / pose.moveMs;
    // Every move arrives the same way: up from a little low, a small give.
    final arrive = pose.moveMs == 0 ? 0.0 : 0.06 * (1 - _ease(u, 0, 0.35));
    final give = (1 - arrive) * (1 - 0.03 * _hump(u, 0.3, 0.6));
    switch (pose) {
      case KittenPose.rest:
        return const KittenFrame();
      case KittenPose.wave:
        // Up beside the face with a little overshoot, two waves from the
        // elbow that fade in and out, then down again.
        final raise = _pop(u, 0.04, 0.3) * (1 - _ease(u, 0.8, 1));
        final shake =
            0.35 *
            math.sin(2 * math.pi * 2 * (u - 0.31) / 0.5) *
            _ease(u, 0.24, 0.4) *
            (1 - _ease(u, 0.66, 0.82));
        return KittenFrame(
          squash: give,
          lead: _lerp(_armRest, 2.05, raise),
          leadPaw: _lerp(_pawRest, 2.6, raise) + shake,
          headTilt: 0.07 * _hump(u, 0.08, 0.95),
          eyeOpen: 1 - _hump(u, 0.6, 0.72),
        );
      case KittenPose.point:
        final reach = _pop(u, 0.08, 0.5);
        final eyes = _ease(u, 0.04, 0.42);
        return KittenFrame(
          squash: give,
          lead: _lerp(_armRest, 1.05, reach) - 0.1 * _hump(u, 0.52, 0.82),
          leadPaw: _lerp(_pawRest, 1.55, reach) - 0.08 * _hump(u, 0.52, 0.82),
          look: Offset(eyes, -0.2 * eyes),
          headTilt: 0.07 * eyes,
        );
      case KittenPose.cheer:
        final up = _pop(u, 0.1, 0.34);
        final settle = _ease(u, 0.62, 1);
        final arm = _lerp(_armRest, 2.0, up) - 0.2 * settle;
        final paw = _lerp(_pawRest, 2.6, up) - 0.15 * settle;
        return KittenFrame(
          lift: 0.05 * _hump(u, 0.14, 0.6),
          squash:
              give *
              (1 - 0.07 * _hump(u, 0, 0.2) + 0.05 * _hump(u, 0.16, 0.44)) *
              (1 - 0.06 * _hump(u, 0.54, 0.76)),
          lead: arm,
          trail: arm,
          leadPaw: paw,
          trailPaw: paw,
          happy: _ease(u, 0.1, 0.3),
          smile: _ease(u, 0.1, 0.3),
        );
      case KittenPose.lookLeft:
      case KittenPose.lookRight:
        final s = pose == KittenPose.lookLeft ? -1.0 : 1.0;
        final turn = _pop(u, 0.08, 0.62);
        return KittenFrame(
          look: Offset(s * turn, 0),
          headTilt: s * 0.06 * turn,
        );
      case KittenPose.blink:
        return KittenFrame(
          eyeOpen: 1 - _hump(u, 0.14, 0.42) - _hump(u, 0.52, 0.8),
        );
    }
  }
}

/// The resting arm: hanging just off the body, the paw tucked in front.
const double _armRest = -0.3;
const double _pawRest = -0.1;

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _unit(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

/// 0 to 1 starting and ending at rest (smootherstep): no jump in speed.
double _ease(double t, double a, double b) {
  final x = _unit(t, a, b);
  return x * x * x * (x * (6 * x - 15) + 10);
}

/// 0 to 1 that runs a little past and settles back, starting and ending at
/// rest: a back-out curve driven by a smooth clock.
double _pop(double t, double a, double b) {
  final x = _unit(t, a, b);
  final s = x * x * (3 - 2 * x) - 1;
  const c = 1.3;
  return 1 + (c + 1) * s * s * s + c * s * s;
}

/// Up and back down again between [a] and [b], leaving and landing at rest.
double _hump(double t, double a, double b) {
  if (t <= a || t >= b) return 0;
  final v = math.sin(math.pi * (t - a) / (b - a));
  return v * v;
}

/// Paints the kitten at whatever [progress] says, 0 to 1 through its run.
class KittenPainter extends CustomPainter {
  KittenPainter({required this.progress, required this.pose, required this.rtl})
    : super(repaint: progress);

  final Animation<double> progress;
  final KittenPose pose;
  final bool rtl;

  static const ArtTone _tone = ArtTones.rose;

  /// The deeper rose that tells a paw from the body behind it.
  static const Color _edgeColour = Color(0xFFE99BB2);

  static Paint _stroke(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _fill = Paint()..color = _tone.fill;
  static final Paint _ink = Paint()..color = _tone.line;
  static final Paint _inkLine = _stroke(_tone.line);
  static final Paint _shine = Paint()..color = HandInk.page;
  static final Paint _pawEdge = Paint()..color = _edgeColour;
  static final Paint _armFill = _stroke(_tone.fill);
  static final Paint _tailFill = _stroke(_tone.fill);

  // Arm layout in the box, leading side to the right.
  static const double _shoulderX = 0.14;
  static const double _shoulderY = 0.66;
  static const double _upperLen = 0.125;
  static const double _foreLen = 0.145;
  static const double _armWidth = 0.086;
  static const double _pawR = 0.05;

  /// Where a shoulder is, in the unmirrored box, for the leading or trailing
  /// side, before the frame lifts or squashes it.
  @visibleForTesting
  static Offset shoulderOf({required bool lead}) =>
      Offset(0.5 + (lead ? 1 : -1) * _shoulderX, _shoulderY);

  /// Where the paw (the end of the arm) is for [f], in the same box.
  @visibleForTesting
  static Offset pawOf(KittenFrame f, {required bool lead}) {
    final side = lead ? 1.0 : -1.0;
    final s = shoulderOf(lead: lead);
    final e = _elbow(s, side, lead ? f.lead : f.trail);
    return _reach(e, side, lead ? f.leadPaw : f.trailPaw, _foreLen);
  }

  /// Where a point of the kitten at [p] (as [pawOf] gives it) lands in the
  /// square it is painted into, 0 to 1, once [f] lifts and squashes it and
  /// the margin is applied. Mirroring for Arabic flips x about 0.5.
  @visibleForTesting
  static Offset placed(KittenFrame f, Offset p) {
    final y = p.dy - f.lift + 0.3 * (1 - f.squash);
    return Offset(0.5 + (p.dx - 0.5) * _fit, 0.49 + (y - 0.5) * _fit);
  }

  /// The upper arm is hidden behind the head and body, so it may grow as
  /// it rises: a raised paw then clears the cheek and reads as a paw up.
  static Offset _elbow(Offset shoulder, double side, double angle) =>
      _reach(shoulder, side, angle, _upperLen + 0.06 * _ease(angle, 1.2, 2.0));

  static Offset _reach(Offset from, double side, double angle, double len) =>
      from + Offset(side * math.sin(angle), math.cos(angle)) * len;

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
    // A little room all round, so a hop or a raised paw never leaves the box.
    canvas.translate(0.5, 0.49);
    canvas.scale(_fit);
    canvas.translate(-0.5, -0.5);
    _paintKitten(canvas, f, _edgeFor(s * _fit));
    canvas.restore();
  }

  static const double _fit = 0.955;

  /// The paw's soft edge in box units: thin, and never under 0.9 px.
  static double _edgeFor(double s) => math.max(0.9, s * 0.008) / s;

  static void _paintKitten(Canvas canvas, KittenFrame f, double edge) {
    final fill = _fill;
    final ink = _ink;

    // An arm comes out from behind the body and head in their own colour,
    // so only the part against the page shows. The paw at its end is drawn
    // on top with a deeper rose edge, so it reads in front of the body.
    final drop = 0.3 * (1 - f.squash);
    void arm(double side, double upper, double fore) {
      final s = Offset(0.5 + side * _shoulderX, _shoulderY + drop);
      final e = _elbow(s, side, upper);
      final p = _reach(e, side, fore, _foreLen);
      final shaft = _armFill..strokeWidth = _armWidth;
      canvas.drawLine(s, e, shaft);
      canvas.drawLine(e, p, shaft);
    }

    void paw(double side, double upper, double fore) {
      final s = Offset(0.5 + side * _shoulderX, _shoulderY + drop);
      final e = _elbow(s, side, upper);
      final p = _reach(e, side, fore, _foreLen);
      canvas.drawCircle(p, _pawR + edge, _pawEdge);
      // The wrist runs over the edge, so the paw joins its arm.
      final wrist = Offset.lerp(e, p, 0.45)!;
      canvas.drawLine(wrist, p, _armFill..strokeWidth = _armWidth);
      canvas.drawCircle(p, _pawR, fill);
    }

    canvas.save();
    canvas.translate(0, -f.lift);

    // Tail, behind everything, swinging from where it meets the body.
    canvas.save();
    canvas.translate(0.36, 0.93);
    canvas.rotate(f.tail);
    canvas.drawPath(_parts.tail, _tailFill..strokeWidth = 0.062);
    canvas.restore();

    arm(-1, f.trail, f.trailPaw);
    arm(1, f.lead, f.leadPaw);

    // Body, squashing toward the floor it sits on.
    canvas.save();
    canvas.translate(0.5, 0.995);
    canvas.scale(1, f.squash);
    canvas.translate(-0.5, -0.995);
    canvas.drawPath(_parts.body, fill);
    canvas.restore();

    // Everything above the body rides down as it squashes.
    canvas.save();
    canvas.translate(0, drop);

    // Head, ears and face turn together about the neck.
    canvas.save();
    canvas.translate(0.5, 0.72);
    canvas.rotate(f.headTilt);
    canvas.translate(-0.5, -0.72);
    canvas.drawPath(_parts.earLead, fill);
    canvas.drawPath(_parts.innerLead, ink);
    canvas.save();
    canvas.translate(0.33, 0.3);
    canvas.rotate(-f.ear);
    canvas.translate(-0.33, -0.3);
    canvas.drawPath(_parts.earTrail, fill);
    canvas.drawPath(_parts.innerTrail, ink);
    canvas.restore();
    // The head goes over the ears, so the deep rose insides end on its curve.
    canvas.drawPath(_parts.head, fill);

    final fx = 0.06 * f.look.dx;
    final fy = 0.04 * f.look.dy;
    final happy = f.happy.clamp(0.0, 1.0);
    for (final side in const [-1.0, 1.0]) {
      final c = Offset(0.5 + side * _eyeSpread + fx, _eyeY + fy);
      // The eye on the side she turns toward comes nearer, so a little bigger.
      final r = _eyeR * (1 + 0.12 * side * f.look.dx);
      if (happy >= 0.5) {
        // Smiling arcs that take over from the squeezed eye.
        canvas.save();
        canvas.translate(c.dx, c.dy + r * 0.25);
        canvas.scale(r);
        canvas.drawPath(_parts.happyEye, _inkLine..strokeWidth = 0.32);
        canvas.restore();
        continue;
      }
      final open = (f.eyeOpen * (1 - 1.7 * happy)).clamp(0.1, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * 2 * open),
        ink,
      );
      if (open > 0.55) {
        canvas.drawCircle(
          c.translate(r * 0.24, -r * 0.34 * open),
          r * 0.27,
          _shine,
        );
      }
    }

    canvas.save();
    canvas.translate(0.5 + fx, _mouthY + fy);
    if (f.smile > 0.5) {
      canvas.drawPath(_parts.smile, ink);
    } else {
      canvas.drawPath(_parts.mouth, _inkLine..strokeWidth = 0.011);
    }
    canvas.restore();
    canvas.restore();

    canvas.restore();

    // Paws last, so a raised paw is in front of the cheek.
    paw(-1, f.trail, f.trailPaw);
    paw(1, f.lead, f.leadPaw);
    canvas.restore();
  }

  static const double _eyeSpread = 0.15;
  static const double _eyeY = 0.54;
  static const double _eyeR = 0.066;
  static const double _mouthY = 0.578;

  @override
  bool shouldRepaint(KittenPainter old) =>
      old.pose != pose || old.rtl != rtl || old.progress != progress;
}

/// The kitten's outlines, built once in the 1 x 1 box.
final _KittenParts _parts = _KittenParts();

class _KittenParts {
  _KittenParts() {
    head = _loop((a) {
      final ca = math.cos(a), sa = math.sin(a);
      // A little fuller in the cheeks than on top, like A1.
      final rx = 0.32 * (1 + 0.05 * sa);
      return Offset(0.5 + rx * _soft(ca, 2.15), 0.5 + 0.24 * _soft(sa, 2.15));
    });
    body = _loop(
      (a) => Offset(
        0.5 + 0.225 * _soft(math.cos(a), 2.25),
        0.83 + 0.165 * _soft(math.sin(a), 2.25),
      ),
    );
    // The leading ear sits on the right; the painter mirrors it for Arabic.
    // Broad at the base, leaning out, a blunt round tip, the outer side
    // running down into the cheek the way A1's does.
    earLead = Path()
      ..moveTo(0.53, 0.31)
      ..cubicTo(0.62, 0.22, 0.7, 0.115, 0.775, 0.09)
      ..cubicTo(0.83, 0.072, 0.862, 0.095, 0.865, 0.14)
      ..cubicTo(0.88, 0.25, 0.878, 0.38, 0.83, 0.5)
      ..lineTo(0.6, 0.5)
      ..close();
    innerLead = Path()
      ..moveTo(0.575, 0.335)
      ..cubicTo(0.64, 0.25, 0.71, 0.16, 0.775, 0.137)
      ..cubicTo(0.81, 0.125, 0.83, 0.14, 0.835, 0.175)
      ..cubicTo(0.848, 0.26, 0.846, 0.35, 0.815, 0.44)
      ..lineTo(0.62, 0.45)
      ..close();
    earTrail = earLead.transform(_mirror);
    innerTrail = innerLead.transform(_mirror);
    tail = Path()
      ..moveTo(0, 0)
      ..cubicTo(-0.14, 0.01, -0.22, -0.06, -0.2, -0.17)
      ..cubicTo(-0.19, -0.22, -0.15, -0.24, -0.12, -0.22);
    // ":3", the way A1 draws it: two small soft bumps.
    mouth = Path()
      ..moveTo(-0.034, -0.008)
      ..cubicTo(-0.032, 0.014, -0.006, 0.016, 0, 0.0)
      ..cubicTo(0.006, 0.016, 0.032, 0.014, 0.034, -0.008);
    smile = Path()
      ..moveTo(-0.036, -0.006)
      ..cubicTo(-0.03, 0.05, 0.03, 0.05, 0.036, -0.006)
      ..quadraticBezierTo(0, 0.004, -0.036, -0.006)
      ..close();
    // An upturned arc in a unit eye, scaled to the eye when drawn.
    happyEye = Path()
      ..moveTo(-0.85, 0.25)
      ..quadraticBezierTo(0, -0.9, 0.85, 0.25);
  }

  late final Path head;
  late final Path body;
  late final Path earLead;
  late final Path innerLead;
  late final Path earTrail;
  late final Path innerTrail;
  late final Path tail;
  late final Path mouth;
  late final Path smile;
  late final Path happyEye;

  /// x to 1 - x: the other side of the box.
  static final Float64List _mirror = Float64List.fromList(const [
    -1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    1, 0, 0, 1, //
  ]);

  /// A superellipse component: rounder than a box, fuller than an oval.
  static double _soft(double v, double n) =>
      v.sign * math.pow(v.abs(), 2 / n).toDouble();

  static Path _loop(Offset Function(double a) at) => smoothPath([
    for (var i = 0; i < 64; i++) at(2 * math.pi * i / 64),
  ], close: true);
}
