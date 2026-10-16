/// The kitten: the one character in the product, drawn in the rose tone.
///
/// It is the owner's chosen design (A1): a round, soft rose kitten with a big
/// head, two ears with blunt tips and inner shapes, almond eyes with one light
/// catch each, a small nose and a ":3" mouth. It is drawn the way the licensed
/// illustrations are: flat colour with soft shading, three tones of each
/// colour (base, shade, highlight) and no outline. A paw in front of the body
/// is told apart by its shade edge, nothing darker.
///
/// Everything is laid out in a 1 x 1 box and built once for the whole app;
/// a frame only moves a few parts with the canvas and draws two short lines
/// per arm, so per-frame work stays tiny.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../theme/app_tokens.dart';
import '../../../theme/hand_tokens.dart';
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
  blink(700, physical: true),

  /// A paw to the chin and the eyes up and away, while something is read.
  think(900, physical: false),

  /// Sits down and folds both paws in front, eyes soft. For a wait that is
  /// not hers to hurry.
  wait(700, physical: false),

  /// Dips its head twice, a small yes. Where a cheer would be too much.
  nod(600, physical: false),

  /// One paw over its head and the other out wide, leaning into a long
  /// stretch, glad.
  stretch(1200, physical: false),

  /// Curls both paws up to its chest, as if lifting something, proud.
  lift(1000, physical: false),

  /// Rises into view from the bottom edge of its box and rests its paws on
  /// that edge. The box clips it, so it comes from the screen edge below.
  peek(900, physical: false);

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
    this.dip = 0,
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

  /// How far the head is lowered, in box units.
  final double dip;

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
      dip: move.dip,
    );
  }

  /// This frame with the eyes [open] by that much, for a blink laid over a
  /// kitten that is otherwise still.
  KittenFrame withEyes(double open) => KittenFrame(
    lift: lift,
    squash: squash,
    headTilt: headTilt,
    lead: lead,
    trail: trail,
    leadPaw: leadPaw,
    trailPaw: trailPaw,
    look: look,
    eyeOpen: open,
    happy: happy,
    smile: smile,
    tail: tail,
    ear: ear,
    dip: dip,
  );

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
      case KittenPose.think:
        // The leading paw folds up to the chin, the face tips and the eyes
        // go up and away from it, as if reading something.
        final reach = _pop(u, 0.06, 0.55);
        final eyes = _ease(u, 0.1, 0.6);
        return KittenFrame(
          squash: give,
          lead: _lerp(_armRest, 1.35, reach),
          leadPaw: _lerp(_pawRest, 4.4, reach),
          look: Offset(-0.45 * eyes, -0.8 * eyes),
          headTilt: 0.09 * eyes,
        );
      case KittenPose.wait:
        // Settles a little lower and brings both paws together in front.
        // The eyes soften but stay open: waiting is never sleep.
        final sit = _ease(u, 0.05, 0.8);
        final fold = _ease(u, 0.15, 0.85);
        return KittenFrame(
          squash: give * (1 - 0.05 * sit),
          lead: _lerp(_armRest, 0.3, fold),
          trail: _lerp(_armRest, 0.3, fold),
          leadPaw: _lerp(_pawRest, -1.2, fold),
          trailPaw: _lerp(_pawRest, -1.2, fold),
          headTilt: 0.05 * sit,
          eyeOpen: 1 - 0.22 * sit,
        );
      case KittenPose.stretch:
        // The leading paw goes up and over the head while the other reaches
        // out wide, the body grows a little taller, and it settles back.
        final up = _pop(u, 0.08, 0.42);
        final hold = 1 - 0.1 * _ease(u, 0.62, 1);
        return KittenFrame(
          squash: give * (1 + 0.05 * _hump(u, 0.1, 0.8)),
          lead: _lerp(_armRest, 2.45, up) * hold,
          leadPaw: _lerp(_pawRest, 2.95, up) * hold,
          trail: _lerp(_armRest, 1.7, up) * hold,
          trailPaw: _lerp(_pawRest, 2.2, up) * hold,
          headTilt: -0.09 * _ease(u, 0.1, 0.45) * hold,
          happy: _ease(u, 0.12, 0.34),
          smile: _ease(u, 0.12, 0.34),
        );
      case KittenPose.lift:
        // Both paws take hold low in front and curl up to the chest.
        final curl = _pop(u, 0.1, 0.55);
        final grip = _ease(u, 0, 0.12);
        final arm = _lerp(_armRest, 0.6, grip);
        return KittenFrame(
          squash: give,
          lead: arm,
          trail: arm,
          leadPaw: _lerp(_lerp(_pawRest, -1.0, grip), -1.9, curl),
          trailPaw: _lerp(_lerp(_pawRest, -1.0, grip), -1.9, curl),
          happy: _ease(u, 0.3, 0.55),
          smile: _ease(u, 0.3, 0.55),
        );
      case KittenPose.peek:
        // Up from below the edge to rest its paws on it, eyes on her.
        final rise = _pop(u, 0.04, 0.7);
        final grab = _ease(u, 0.25, 0.7);
        final arm = _lerp(_armRest, 1.9, grab);
        return KittenFrame(
          lift: _lerp(-0.95, -0.4, rise),
          lead: arm,
          trail: arm,
          leadPaw: _lerp(_pawRest, 2.6, grab),
          trailPaw: _lerp(_pawRest, 2.6, grab),
          headTilt: 0.06 * _hump(u, 0.5, 1),
        );
      case KittenPose.nod:
        final down = _hump(u, 0.05, 0.5) + _hump(u, 0.5, 0.95);
        return KittenFrame(
          squash: give,
          dip: 0.045 * down,
          eyeOpen: 1 - 0.35 * down,
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

/// What the kitten holds, drawn in the same flat, soft-shaded style.
enum KittenProp {
  /// A tiny dumbbell, for training screens.
  dumbbell,

  /// A heart, for a finished week.
  heart,

  /// A small card with a tick, for something saved.
  tickCard,
}

/// One colour in three tones.
@immutable
class _Tri {
  const _Tri(this.base, this.shade, this.light);

  final Color base;
  final Color shade;
  final Color light;
}

/// The colour the kitten is drawn in. Pink everywhere, and sage where it
/// keeps her company through a wait rather than celebrating.
@immutable
class KittenTint {
  const KittenTint._(this._body, this.inner, this.nose, this.eye);

  final _Tri _body;

  /// The inside of an ear: a deeper pink than the body.
  final Color inner;

  /// The nose and mouth.
  final Color nose;

  /// The eyes, the one dark on the kitten.
  final Color eye;

  /// The deeper edge that tells a paw from the body behind it.
  Color get edge => _body.shade;

  static const KittenTint rose = KittenTint._(
    _Tri(AppColors.brandPink, AppColors.pinkShade, AppColors.pinkSoft),
    AppColors.pinkDeep,
    AppColors.pinkDeep,
    AppColors.petrolDark,
  );
  static const KittenTint sage = KittenTint._(
    _Tri(Color(0xFFA6CCAC), Color(0xFF8DB896), Color(0xFFC5E0CA)),
    Color(0xFF7FA98A),
    AppColors.tertiary,
    AppColors.onTertiaryContainer,
  );

  @override
  bool operator ==(Object other) =>
      other is KittenTint && other._body == _body && other.eye == eye;

  @override
  int get hashCode => Object.hash(_body, eye);
}

/// The cream of the belly and muzzle, with its own shade.
const _Tri _cream = _Tri(
  Color(0xFFFBEFE0),
  Color(0xFFF0DCC6),
  Color(0xFFFFF8EE),
);

/// The heart: a deeper pink than the body, so it stands out of it.
const _Tri _heartTone = _Tri(
  Color(0xFFE58F8B),
  Color(0xFFC9706C),
  AppColors.pinkSoft,
);

/// The tick on a card: sage, as everything done in the product.
const _Tri _sage = _Tri(
  Color(0xFFA6CCAC),
  Color(0xFF8DB896),
  Color(0xFFC5E0CA),
);

/// A dumbbell bar, and a card's edge.
const _Tri _steel = _Tri(
  AppColors.petrolMuted,
  Color(0xFF4F7480),
  Color(0xFF9FB8C0),
);

/// Paints the kitten at whatever [progress] says, 0 to 1 through its run.
class KittenPainter extends CustomPainter {
  KittenPainter({
    required this.progress,
    required this.pose,
    required this.rtl,
    this.tint = KittenTint.rose,
    this.prop,
    this.blinking = false,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final KittenPose pose;
  final bool rtl;
  final KittenTint tint;

  /// Held in front of it, if anything.
  final KittenProp? prop;

  /// One blink laid over its last frame, with [progress] running 0 to 1
  /// through the blink alone.
  final bool blinking;

  _Tri get _b => tint._body;

  static Paint _solid(Color c) => Paint()..color = c;

  static Paint _stroke(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  late final Paint _base = _solid(_b.base);
  late final Paint _shade = _solid(_b.shade);
  late final Paint _light = _solid(_b.light);
  late final Paint _inner = _solid(tint.inner);
  late final Paint _eye = _solid(tint.eye);
  late final Paint _eyeLine = _stroke(tint.eye);
  late final Paint _noseFill = _solid(tint.nose);
  late final Paint _mouthLine = _stroke(tint.nose);
  static final Paint _glow = _solid(const Color(0x2EFFFFFF));
  late final Paint _cast = _solid(_b.shade.withValues(alpha: 0.18))
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03);
  late final Paint _cheek = _solid(_b.shade.withValues(alpha: 0.85));
  static final Paint _creamBase = _solid(_cream.base);
  static final Paint _creamShade = _solid(_cream.shade);
  static final Paint _shine = _solid(HandInk.page);
  late final Paint _armBase = _stroke(_b.base);
  late final Paint _armShade = _stroke(_b.shade);
  late final Paint _tailBase = _stroke(_b.base);
  late final Paint _tailShade = _stroke(_b.shade);
  static final Paint _tailTip = _stroke(_cream.base);

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
    final f = blinking
        ? KittenFrame.end(pose).withEyes(1 - _hump(progress.value, 0.2, 0.6))
        : KittenFrame.at(pose, progress.value * run);

    canvas.save();
    // Coming in from the edge below: nothing shows past the box.
    if (pose == KittenPose.peek) canvas.clipRect(Offset.zero & size);
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

  static const double _fit = 0.94;

  /// The paw's soft edge in box units: thin, and never under 0.9 px.
  static double _edgeFor(double s) => math.max(0.9, s * 0.008) / s;

  void _paintKitten(Canvas canvas, KittenFrame f, double edge) {
    final drop = 0.3 * (1 - f.squash);

    void arm(double side, double upper, double fore) {
      final s = Offset(0.5 + side * _shoulderX, _shoulderY + drop);
      final e = _elbow(s, side, upper);
      final p = _reach(e, side, fore, _foreLen);
      // The shade is the whole arm; the base sits a little up and in from it.
      final shaft = _armShade..strokeWidth = _armWidth;
      canvas.drawLine(s, e, shaft);
      canvas.drawLine(e, p, shaft);
      final lit = _armBase..strokeWidth = _armWidth - 0.014;
      final nudge = Offset(-side * 0.003, -0.004);
      canvas.drawLine(s + nudge, e + nudge, lit);
      canvas.drawLine(e + nudge, p + nudge, lit);
    }

    void paw(double side, double upper, double fore) {
      final s = Offset(0.5 + side * _shoulderX, _shoulderY + drop);
      final e = _elbow(s, side, upper);
      final p = _reach(e, side, fore, _foreLen);
      canvas.drawCircle(p, _pawR + edge, _shade);
      // The wrist runs over the edge, so the paw joins its arm.
      final wrist = Offset.lerp(e, p, 0.45)!;
      canvas.drawLine(wrist, p, _armBase..strokeWidth = _armWidth - 0.014);
      final top = p.translate(-side * 0.003, -0.004);
      canvas.drawCircle(top, _pawR - 0.002, _base);
      canvas.drawCircle(top.translate(-0.012, -0.014), _pawR * 0.22, _light);
      // Two toe lines, small enough to stay quiet.
      for (final x in const [-0.011, 0.011]) {
        canvas.drawLine(
          top.translate(x, 0.012),
          top.translate(x, 0.031),
          _armShade..strokeWidth = 0.005,
        );
      }
    }

    canvas.save();
    canvas.translate(0, -f.lift);

    // Tail, behind everything, swinging from where it meets the body.
    canvas.save();
    canvas.translate(0.4, 0.92);
    canvas.rotate(f.tail);
    canvas.drawPath(_parts.tailRoot, _tailShade..strokeWidth = 0.07);
    canvas.drawPath(_parts.tailTip, _tailShade..strokeWidth = 0.07);
    canvas.drawPath(_parts.tailRoot, _tailBase..strokeWidth = 0.058);
    canvas.drawPath(_parts.tailTip, _tailTip..strokeWidth = 0.058);
    canvas.restore();

    arm(-1, f.trail, f.trailPaw);
    arm(1, f.lead, f.leadPaw);

    // Body, squashing toward the floor it sits on.
    canvas.save();
    canvas.translate(0.5, 0.995);
    canvas.scale(1, f.squash);
    canvas.translate(-0.5, -0.995);
    canvas.drawPath(_parts.body, _shade);
    canvas.drawPath(_parts.bodyLit, _base);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0.5, 0.735),
        width: 0.34,
        height: 0.08,
      ),
      _cast,
    );
    canvas.drawPath(_parts.belly, _creamShade);
    canvas.drawPath(_parts.bellyLit, _creamBase);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(_parts.foot(side), _shade);
      canvas.drawPath(_parts.footLit(side), _base);
      for (final toe in const [-0.014, 0.014]) {
        final x = 0.5 + side * 0.115 + toe;
        canvas.drawLine(
          Offset(x, 0.948),
          Offset(x, 0.966),
          _armShade..strokeWidth = 0.006,
        );
      }
    }
    canvas.restore();

    // Everything above the body rides down as it squashes.
    canvas.save();
    canvas.translate(0, drop);

    // Head, ears and face turn together about the neck.
    canvas.save();
    canvas.translate(0, f.dip);
    canvas.translate(0.5, 0.72);
    canvas.rotate(f.headTilt);
    canvas.translate(-0.5, -0.72);
    canvas.drawPath(_parts.earLead, _base);
    canvas.drawPath(_parts.earShadeLead, _shade);
    canvas.drawPath(_parts.innerLead, _inner);
    canvas.save();
    canvas.translate(0.33, 0.3);
    canvas.rotate(-f.ear);
    canvas.translate(-0.33, -0.3);
    canvas.drawPath(_parts.earTrail, _base);
    canvas.drawPath(_parts.earShadeTrail, _shade);
    canvas.drawPath(_parts.innerTrail, _inner);
    canvas.restore();
    // The head goes over the ears, so the inner shapes end on its curve.
    canvas.drawPath(_parts.head, _base);
    canvas.drawPath(_parts.glow, _glow);

    final fx = 0.06 * f.look.dx;
    final fy = 0.04 * f.look.dy;
    final happy = f.happy.clamp(0.0, 1.0);

    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0.5 + side * 0.225 + fx, 0.605 + fy),
          width: 0.1,
          height: 0.06,
        ),
        _cheek,
      );
    }
    // The muzzle: two soft cream pads under the nose.
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0.5 + side * 0.046 + fx, 0.6 + fy),
          width: 0.106,
          height: 0.086,
        ),
        _creamShade,
      );
    }
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0.5 + side * 0.046 + fx, 0.597 + fy),
          width: 0.1,
          height: 0.08,
        ),
        _creamBase,
      );
    }

    for (final side in const [-1.0, 1.0]) {
      final c = Offset(0.5 + side * _eyeSpread + fx, _eyeY + fy);
      // The eye on the side she turns toward comes nearer, so a little bigger.
      final r = _eyeR * (1 + 0.12 * side * f.look.dx);
      if (happy >= 0.5) {
        // Smiling arcs that take over from the squeezed eye.
        canvas.save();
        canvas.translate(c.dx, c.dy + r * 0.25);
        canvas.scale(r);
        canvas.drawPath(_parts.happyEye, _eyeLine..strokeWidth = 0.32);
        canvas.restore();
        continue;
      }
      final open = (f.eyeOpen * (1 - 1.7 * happy)).clamp(0.1, 1.0);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(side * r * 1.08, r * 0.96 * open);
      canvas.drawPath(_parts.almond, _eye);
      canvas.restore();
      if (open > 0.55) {
        canvas.drawCircle(
          c.translate(r * 0.2, -r * 0.3 * open),
          r * 0.27,
          _shine,
        );
      }
    }

    canvas.save();
    canvas.translate(0.5 + fx, 0.556 + fy);
    canvas.drawPath(_parts.nose, _noseFill);
    canvas.restore();

    canvas.save();
    canvas.translate(0.5 + fx, _mouthY + fy);
    if (f.smile > 0.5) {
      canvas.drawPath(_parts.smile, _eye);
    } else {
      canvas.drawPath(_parts.mouth, _mouthLine..strokeWidth = 0.011);
    }
    canvas.restore();
    canvas.restore();

    canvas.restore();

    _paintProp(canvas, f, drop);

    // Paws last, so a raised paw is in front of the cheek.
    paw(-1, f.trail, f.trailPaw);
    paw(1, f.lead, f.leadPaw);
    canvas.restore();
  }

  /// What it holds sits low in front of the body, where the resting paws
  /// meet, and between the paws when they curl it up.
  void _paintProp(Canvas canvas, KittenFrame f, double drop) {
    final held = prop;
    if (held == null) return;
    var at = Offset(0.5, 0.9 + drop);
    if (pose == KittenPose.lift) {
      final a = pawOf(f, lead: true), b = pawOf(f, lead: false);
      at = Offset.lerp(a, b, 0.5)!.translate(0, drop);
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    switch (held) {
      case KittenProp.dumbbell:
        _dumbbell(canvas);
      case KittenProp.heart:
        _heart(canvas);
      case KittenProp.tickCard:
        _tickCard(canvas);
    }
    canvas.restore();
  }

  void _lit(Canvas canvas, Path path, _Tri t, Offset shift) {
    canvas.drawPath(path, _solid(t.shade));
    canvas.save();
    canvas.translate(shift.dx, shift.dy);
    canvas.drawPath(path, _solid(t.base));
    canvas.restore();
  }

  void _dumbbell(Canvas canvas) {
    const a = _steel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-0.21, -0.016, 0.21, 0.016),
        const Radius.circular(0.012),
      ),
      _solid(_steel.shade),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-0.21, -0.018, 0.21, 0.008),
        const Radius.circular(0.01),
      ),
      _solid(_steel.base),
    );
    for (final side in const [-1.0, 1.0]) {
      final x = side * 0.21;
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 0), width: 0.06, height: 0.115),
        const Radius.circular(0.022),
      );
      canvas.drawRRect(plate, _solid(a.shade));
      canvas.drawRRect(
        plate.shift(const Offset(-0.004, -0.005)),
        _solid(a.base),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 0.009, -0.03),
          width: 0.016,
          height: 0.034,
        ),
        _solid(a.light),
      );
    }
  }

  void _heart(Canvas canvas) {
    _lit(canvas, _parts.heart, _heartTone, const Offset(-0.004, -0.005));
    canvas.save();
    canvas.translate(-0.034, -0.045);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 0.04, height: 0.02),
      _solid(_heartTone.light),
    );
    canvas.restore();
  }

  void _tickCard(Canvas canvas) {
    const a = _sage;
    canvas.rotate(-0.07);
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 0.19, height: 0.215),
      const Radius.circular(0.026),
    );
    canvas.drawRRect(card, _solid(_steel.shade));
    canvas.drawRRect(
      card.shift(const Offset(-0.004, -0.005)),
      _solid(_cream.light),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-0.07, -0.085, 0.07, -0.062),
        const Radius.circular(0.011),
      ),
      _solid(_heartTone.light),
    );
    final tick = Path()
      ..moveTo(-0.045, 0.02)
      ..cubicTo(-0.035, 0.03, -0.025, 0.045, -0.018, 0.058)
      ..cubicTo(-0.005, 0.03, 0.02, -0.005, 0.05, -0.03);
    canvas.drawPath(tick, _stroke(a.shade)..strokeWidth = 0.036);
    canvas.drawPath(
      tick.shift(const Offset(-0.003, -0.004)),
      _stroke(a.base)..strokeWidth = 0.03,
    );
  }

  static const double _eyeSpread = 0.14;
  static const double _eyeY = 0.54;
  static const double _eyeR = 0.066;
  static const double _mouthY = 0.578;

  @override
  bool shouldRepaint(KittenPainter old) =>
      old.pose != pose ||
      old.rtl != rtl ||
      old.tint != tint ||
      old.prop != prop ||
      old.blinking != blinking ||
      old.progress != progress;
}

/// The kitten's outlines, built once in the 1 x 1 box.
final _KittenParts _parts = _KittenParts();

class _KittenParts {
  _KittenParts() {
    head = _loop((a) {
      final ca = math.cos(a), sa = math.sin(a);
      // Fuller in the cheeks than on top, so the face is round where it
      // meets the neck.
      final rx = 0.32 * (1 + 0.07 * sa);
      return Offset(0.5 + rx * _soft(ca, 2.1), 0.5 + 0.225 * _soft(sa, 2.1));
    });
    // The lit face sits a little up and to the light, so the shade shows as
    // a soft crescent along the chin and the far cheek.
    // A soft crescent along the top-left of the head, where the light is.
    glow = Path.combine(
      PathOperation.difference,
      _fit(head, 0.5, 0.5, 0.9, 0.86, -0.012, -0.02),
      _fit(head, 0.5, 0.5, 0.9, 0.86, 0.02, 0.026),
    );
    body = _loop(
      (a) => Offset(
        0.5 + 0.225 * _soft(math.cos(a), 2.25),
        0.83 + 0.165 * _soft(math.sin(a), 2.25),
      ),
    );
    bodyLit = _fit(body, 0.5, 0.83, 0.94, 0.93, -0.01, -0.014);
    belly = _loop(
      (a) => Offset(
        0.5 + 0.125 * _soft(math.cos(a), 2.2),
        0.875 + 0.1 * _soft(math.sin(a), 2.2),
      ),
    );
    bellyLit = _fit(belly, 0.5, 0.875, 0.93, 0.9, -0.004, -0.007);
    // The leading ear sits on the right; the painter mirrors it for Arabic.
    // Broad at the base, leaning out, a blunt round tip, the outer side
    // running down into the cheek.
    earLead = Path()
      ..moveTo(0.53, 0.31)
      ..cubicTo(0.62, 0.22, 0.7, 0.115, 0.775, 0.09)
      ..cubicTo(0.83, 0.072, 0.862, 0.095, 0.865, 0.14)
      ..cubicTo(0.88, 0.25, 0.878, 0.38, 0.83, 0.5)
      ..lineTo(0.6, 0.5)
      ..close();
    // The outer edge of the ear in shade, a thin band down its far side.
    earShadeLead = Path()
      ..moveTo(0.865, 0.14)
      ..cubicTo(0.88, 0.25, 0.878, 0.38, 0.83, 0.5)
      ..lineTo(0.775, 0.5)
      ..cubicTo(0.812, 0.4, 0.822, 0.27, 0.815, 0.16)
      ..cubicTo(0.812, 0.115, 0.79, 0.098, 0.775, 0.1)
      ..cubicTo(0.835, 0.075, 0.862, 0.098, 0.865, 0.14)
      ..close();
    innerLead = Path()
      ..moveTo(0.575, 0.335)
      ..cubicTo(0.64, 0.25, 0.71, 0.16, 0.765, 0.142)
      ..cubicTo(0.795, 0.132, 0.815, 0.148, 0.82, 0.18)
      ..cubicTo(0.832, 0.26, 0.83, 0.35, 0.8, 0.44)
      ..lineTo(0.62, 0.45)
      ..close();
    // Shorter and narrower, so they sit on the head rather than tower.
    earLead = _fit(earLead, 0.7, 0.5, 0.9, 0.82, 0, 0);
    earShadeLead = _fit(earShadeLead, 0.7, 0.5, 0.9, 0.82, 0, 0);
    innerLead = _fit(innerLead, 0.7, 0.5, 0.9, 0.82, 0, 0);
    innerLead = _fit(innerLead, 0.7, 0.45, 0.88, 0.88, 0, 0);
    earTrail = earLead.transform(_mirror);
    earShadeTrail = earShadeLead.transform(_mirror);
    innerTrail = innerLead.transform(_mirror);
    // The tail rises from the hip in one S, its tip in cream.
    final tail = Path()
      ..moveTo(0, 0)
      ..cubicTo(-0.15, 0.015, -0.25, -0.07, -0.22, -0.18)
      ..cubicTo(-0.19, -0.24, -0.22, -0.3, -0.31, -0.31);
    final metric = tail.computeMetrics().first;
    tailRoot = metric.extractPath(0, metric.length * 0.8);
    tailTip = metric.extractPath(metric.length * 0.8, metric.length);
    nose = Path()
      ..moveTo(-0.021, -0.007)
      ..cubicTo(-0.012, -0.012, 0.012, -0.012, 0.021, -0.007)
      ..cubicTo(0.019, 0.004, 0.008, 0.012, 0, 0.014)
      ..cubicTo(-0.008, 0.012, -0.019, 0.004, -0.021, -0.007)
      ..close();
    // ":3", two small soft bumps.
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
    // An almond in a unit eye, the outer corner on +x and a little higher
    // than the inner, a gentle lid on top and a fuller curve beneath.
    almond = Path()
      ..moveTo(-0.95, 0.14)
      ..cubicTo(-0.6, -0.95, 0.6, -1.0, 1.0, -0.02)
      ..cubicTo(0.6, 0.9, -0.4, 1.0, -0.95, 0.14)
      ..close();
    // A heart about 0.14 wide, centred on its middle.
    heart = Path()
      ..moveTo(0, 0.07)
      ..cubicTo(-0.05, 0.035, -0.085, 0.01, -0.085, -0.03)
      ..cubicTo(-0.085, -0.065, -0.04, -0.085, 0, -0.045)
      ..cubicTo(0.04, -0.085, 0.085, -0.065, 0.085, -0.03)
      ..cubicTo(0.085, 0.01, 0.05, 0.035, 0, 0.07)
      ..close();
  }

  late final Path head;
  late final Path glow;
  late final Path body;
  late final Path bodyLit;
  late final Path belly;
  late final Path bellyLit;
  late Path earLead;
  late Path earShadeLead;
  late Path innerLead;
  late final Path earTrail;
  late final Path earShadeTrail;
  late final Path innerTrail;
  late final Path tailRoot;
  late final Path tailTip;
  late final Path nose;
  late final Path mouth;
  late final Path smile;
  late final Path happyEye;
  late final Path almond;
  late final Path heart;

  /// A hind foot on [side], and the lit top of it.
  Path foot(double side) => _feet[side < 0 ? 0 : 1];
  Path footLit(double side) => _feetLit[side < 0 ? 0 : 1];

  late final List<Path> _feet = [
    for (final side in const [-1.0, 1.0])
      _loop(
        (a) => Offset(
          0.5 + side * 0.115 + 0.075 * _soft(math.cos(a), 2.2),
          0.955 + 0.038 * _soft(math.sin(a), 2.2),
        ),
        n: 24,
      ),
  ];
  late final List<Path> _feetLit = [
    for (final (i, side) in const [-1.0, 1.0].indexed)
      _fit(_feet[i], 0.5 + side * 0.115, 0.955, 0.92, 0.88, -0.004, -0.005),
  ];

  /// [p] scaled about ([cx], [cy]) and then moved by ([dx], [dy]).
  static Path _fit(
    Path p,
    double cx,
    double cy,
    double sx,
    double sy,
    double dx,
    double dy,
  ) => p.transform(
    Float64List.fromList([
      sx, 0, 0, 0, //
      0, sy, 0, 0, //
      0, 0, 1, 0, //
      cx - sx * cx + dx, cy - sy * cy + dy, 0, 1, //
    ]),
  );

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

  static Path _loop(Offset Function(double a) at, {int n = 64}) => smoothPath([
    for (var i = 0; i < n; i++) at(2 * math.pi * i / n),
  ], close: true);
}
