/// P06's figure: a woman's body she can turn, each muscle group coloured by
/// how much she trained it.
///
/// Drawn by hand in Dart, with no package and nothing from a network: about
/// twenty capsules and ellipsoids, built into one mesh once and kept for the
/// life of the app. A frame only turns the kept mesh (a yaw with a slight
/// pitch), drops the faces turned away, sorts the rest back to front and
/// draws them in a single call with a soft light on them.
///
/// The torso and the thighs are single surfaces whose faces are filed under a
/// section by where they sit, so a thigh is the front of the thighs at the
/// front, the back of the thighs behind, and the inner and outer thighs at
/// the sides, with no seam for the sort to trip on.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/hand/draw_on.dart' show handMotionOff;
import '../../train/domain/exercise_library.dart';

/// Parts that are not a muscle group.
const int _neutral = 200;
const int _hair = 201;
const int _skinOther = 202;

/// The model, in metres-ish units: y up from the floor, x to the viewer's
/// right when she faces the viewer, z toward the viewer.
class FigureMesh {
  FigureMesh._(
    this.positions,
    this.normals,
    this.triangles,
    this.parts,
    this.bias,
    this.grooves,
  );

  /// x, y, z per vertex.
  final Float32List positions;

  /// Smoothed outward normals, x, y, z per vertex.
  final Float32List normals;

  /// Three vertex indices per triangle.
  final Int32List triangles;

  /// The part each triangle belongs to: a [MuscleSection] index, or one of
  /// the neutral parts.
  final Uint8List parts;

  /// Pulled toward the eye when sorting, per triangle. A part laid over
  /// another (a shoulder cap, the glutes, a hand) is drawn over the surface
  /// it sits on, so where the two meet the edge is the part's own outline
  /// rather than a saw-tooth of faces from both.
  final Float32List bias;

  /// 1 for a vertex on the line between two muscle groups. The faces either
  /// side darken toward it, which draws the groove between muscles and keeps
  /// each group readable even before she has trained it.
  final Uint8List grooves;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => parts.length;

  /// Built once, on first use.
  static final FigureMesh instance = _FigureBuilder().build();

  /// Height of the figure, floor to the top of the hair.
  static const double height = 1.70;
}

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V operator *(double k) => _V(x * k, y * k, z * k);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
  _V cross(_V o) => _V(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  _V get unit {
    final l = length;
    return l == 0 ? const _V(0, 0, 1) : this * (1 / l);
  }
}

/// One ring of a lathed surface: where along the axis, its half width to the
/// side, its half depth to the front, and how far forward its centre sits.
typedef _Ring = ({double t, double rx, double rz, double dz});

class _FigureBuilder {
  final List<double> _pos = [];
  final List<double> _hint = [];
  final List<int> _tri = [];
  final List<int> _part = [];
  final List<double> _triBias = [];

  /// The bias the next faces are given.
  double _bias = 0;

  int _vertex(_V p, _V outward) {
    _pos.addAll([p.x, p.y, p.z]);
    final n = outward.unit;
    _hint.addAll([n.x, n.y, n.z]);
    return _pos.length ~/ 3 - 1;
  }

  _V _p(int i) => _V(_pos[i * 3], _pos[i * 3 + 1], _pos[i * 3 + 2]);
  _V _h(int i) => _V(_hint[i * 3], _hint[i * 3 + 1], _hint[i * 3 + 2]);

  void _triangle(int a, int b, int c, int part) {
    final pa = _p(a);
    final n = (_p(b) - pa).cross(_p(c) - pa);
    if (n.length < 1e-10) return;
    // Every face is wound to point out, so a frame can drop the ones turned
    // away by their normal alone.
    final out = _h(a) + _h(b) + _h(c);
    if (n.dot(out) < 0) {
      _tri.addAll([a, c, b]);
    } else {
      _tri.addAll([a, b, c]);
    }
    _part.add(part);
    _triBias.add(_bias);
  }

  /// An ellipsoid. [partOf] files each face by its latitude (0 at the top,
  /// pi at the bottom) and its longitude from the front; returning null
  /// leaves the face out.
  void _ellipsoid(
    _V c,
    _V r, {
    int bands = 8,
    int segments = 12,
    required int? Function(double lat, double lon) partOf,
  }) {
    final ids = <List<int>>[];
    for (var i = 0; i <= bands; i++) {
      final lat = math.pi * i / bands;
      final row = <int>[];
      for (var j = 0; j < segments; j++) {
        final lon = 2 * math.pi * j / segments;
        final dir = _V(
          math.sin(lat) * math.sin(lon),
          math.cos(lat),
          math.sin(lat) * math.cos(lon),
        );
        final p = c + _V(dir.x * r.x, dir.y * r.y, dir.z * r.z);
        final n = _V(dir.x / r.x, dir.y / r.y, dir.z / r.z);
        row.add(_vertex(p, n));
      }
      ids.add(row);
    }
    for (var i = 0; i < bands; i++) {
      for (var j = 0; j < segments; j++) {
        final k = (j + 1) % segments;
        final lat = math.pi * (i + 0.5) / bands;
        var lon = 2 * math.pi * (j + 0.5) / segments;
        if (lon > math.pi) lon -= 2 * math.pi;
        final part = partOf(lat, lon);
        if (part == null) continue;
        _triangle(ids[i][j], ids[i + 1][j], ids[i + 1][k], part);
        _triangle(ids[i][j], ids[i + 1][k], ids[i][k], part);
      }
    }
  }

  /// A surface turned about the axis from [a] to [b], closed at both ends.
  /// [partOf] files each face by its place along the axis (0 at [a]) and its
  /// angle from the front, -pi to pi.
  void _lathe(
    _V a,
    _V b,
    List<_Ring> rings, {
    int segments = 12,
    required int Function(double t, double angle) partOf,
    double Function(double t)? biasOf,
    double Function(double t, double angle)? bump,
  }) {
    final held = _bias;
    final axis = b - a;
    final d = axis.unit;
    const front = _V(0, 0, 1);
    final w = (front - d * front.dot(d)).unit;
    final u = d.cross(w).unit;
    final ids = <List<int>>[];
    for (final ring in rings) {
      final centre = a + axis * ring.t + w * ring.dz;
      final row = <int>[];
      for (var j = 0; j < segments; j++) {
        final angle = 2 * math.pi * j / segments;
        final cw = math.cos(angle);
        final su = math.sin(angle);
        final out =
            bump?.call(ring.t, angle > math.pi ? angle - 2 * math.pi : angle) ??
            0;
        final p =
            centre + w * (cw * (ring.rz + out)) + u * (su * (ring.rx + out));
        final n =
            w * (cw / math.max(ring.rz, 1e-3)) +
            u * (su / math.max(ring.rx, 1e-3));
        row.add(_vertex(p, n));
      }
      ids.add(row);
    }
    for (var i = 0; i + 1 < rings.length; i++) {
      final t = (rings[i].t + rings[i + 1].t) / 2;
      _bias = biasOf?.call(t) ?? held;
      for (var j = 0; j < segments; j++) {
        final k = (j + 1) % segments;
        var angle = 2 * math.pi * (j + 0.5) / segments;
        if (angle > math.pi) angle -= 2 * math.pi;
        final part = partOf(t, angle);
        _triangle(ids[i][j], ids[i + 1][j], ids[i + 1][k], part);
        _triangle(ids[i][j], ids[i + 1][k], ids[i][k], part);
      }
    }
    // Close each end with a fan to a centre point.
    for (final (index, sign) in [(0, -1.0), (rings.length - 1, 1.0)]) {
      final ring = rings[index];
      final centre = a + axis * ring.t + w * ring.dz;
      final pole = _vertex(centre, d * sign);
      final part = partOf(ring.t, 0);
      _bias = biasOf?.call(ring.t) ?? held;
      for (var j = 0; j < segments; j++) {
        final k = (j + 1) % segments;
        _triangle(pole, ids[index][j], ids[index][k], part);
      }
    }
    _bias = held;
  }

  /// Rings for a limb with rounded ends: [profile] gives radii along the
  /// limb, and each end is closed with a quarter circle of its own radius.
  List<_Ring> _limb(
    double length,
    List<(double, double)> profile, {
    double Function(double t)? forward,
    double depthScale = 1,
  }) {
    double radiusAt(double t) {
      if (t <= profile.first.$1) return profile.first.$2;
      for (var i = 0; i + 1 < profile.length; i++) {
        final (t0, r0) = profile[i];
        final (t1, r1) = profile[i + 1];
        if (t <= t1) {
          final f = (t - t0) / (t1 - t0);
          final s = f * f * (3 - 2 * f);
          return r0 + (r1 - r0) * s;
        }
      }
      return profile.last.$2;
    }

    final out = <_Ring>[];
    final r0 = profile.first.$2;
    final r1 = profile.last.$2;
    for (final a in [0.18, 0.5, 0.8]) {
      final ang = a * math.pi / 2;
      out.add((
        t: -r0 * 0.8 * math.cos(ang) / length,
        rx: r0 * math.sin(ang),
        rz: r0 * math.sin(ang) * depthScale,
        dz: forward?.call(0) ?? 0,
      ));
    }
    const steps = 9;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final r = radiusAt(t);
      out.add((t: t, rx: r, rz: r * depthScale, dz: forward?.call(t) ?? 0));
    }
    for (final a in [0.8, 0.5, 0.18]) {
      final ang = a * math.pi / 2;
      out.add((
        t: 1 + r1 * 0.8 * math.cos(ang) / length,
        rx: r1 * math.sin(ang),
        rz: r1 * math.sin(ang) * depthScale,
        dz: forward?.call(1) ?? 0,
      ));
    }
    return out;
  }

  static double _deg(double radians) => radians.abs() * 180 / math.pi;

  FigureMesh build() {
    int part(MuscleSection section) => section.index;
    assert(MuscleSection.values.length < _neutral);

    _torso();

    // Head, hair to the jaw at the sides, and a high bun.
    _bias = 0.01;
    _ellipsoid(
      const _V(0, 1.585, 0.006),
      const _V(0.074, 0.098, 0.088),
      segments: 14,
      partOf: (lat, lon) => _skinOther,
    );
    _bias = 0.02;
    _ellipsoid(
      const _V(0, 1.596, -0.008),
      const _V(0.082, 0.102, 0.094),
      bands: 9,
      segments: 16,
      // Hair over the crown, the sides and the back: never over the face.
      partOf: (lat, lon) {
        final a = _deg(lon);
        final reach = a < 40
            ? 0.62
            : a < 75
            ? 1.12
            : a < 115
            ? 1.5
            : 2.05;
        return lat < reach ? _hair : null;
      },
    );
    _bias = 0.03;
    _ellipsoid(
      const _V(0, 1.683, -0.050),
      const _V(0.050, 0.044, 0.048),
      bands: 6,
      segments: 12,
      partOf: (lat, lon) => _hair,
    );
    _bias = 0;
    _lathe(
      const _V(0, 1.43, -0.008),
      const _V(0, 1.53, -0.004),
      const [
        (t: 0, rx: 0.045, rz: 0.042, dz: 0),
        (t: 1, rx: 0.039, rz: 0.039, dz: 0),
      ],
      segments: 12,
      partOf: (t, angle) =>
          _deg(angle) > 115 ? part(MuscleSection.upperBack) : _skinOther,
    );

    for (final side in [-1.0, 1.0]) {
      // Shoulder caps, over the top of the arm and the edge of the chest.
      _bias = 0.03;
      _ellipsoid(
        _V(side * 0.183, 1.322, -0.010),
        const _V(0.050, 0.068, 0.057),
        segments: 14,
        partOf: (lat, lon) => part(MuscleSection.shoulders),
      );
      // Glutes.
      _bias = 0.12;
      _ellipsoid(
        _V(side * 0.074, 0.872, -0.058),
        const _V(0.090, 0.092, 0.080),
        segments: 14,
        // The back half only: the front of it is inside the hips.
        partOf: (lat, lon) =>
            _deg(lon) < 100 ? null : part(MuscleSection.glutes),
      );
      // Upper arm and forearm, in a relaxed A.
      _bias = 0;
      final shoulder = _V(side * 0.208, 1.325, -0.012);
      final elbow = _V(side * 0.262, 1.068, -0.024);
      final wrist = _V(side * 0.298, 0.828, 0.012);
      _lathe(
        shoulder,
        elbow,
        _limb(0.265, const [(0, 0.052), (0.42, 0.050), (1, 0.038)]),
        partOf: (t, angle) => part(MuscleSection.arms),
      );
      _bias = 0.03;
      _lathe(
        elbow,
        wrist,
        _limb(0.245, const [(0, 0.039), (0.3, 0.041), (1, 0.027)]),
        partOf: (t, angle) => part(MuscleSection.arms),
      );
      _bias = 0.02;
      _ellipsoid(
        _V(side * 0.305, 0.764, 0.018),
        const _V(0.026, 0.058, 0.036),
        bands: 6,
        segments: 10,
        partOf: (lat, lon) => _skinOther,
      );
      // Thigh: the front, the back, and the inner and outer sides. Drawn
      // under the hips and over the knee.
      _bias = 0.06;
      final hip = _V(side * 0.088, 0.875, 0.000);
      final knee = _V(side * 0.080, 0.482, 0.012);
      final ankle = _V(side * 0.073, 0.078, -0.006);
      _lathe(
        hip,
        knee,
        _limb(0.395, const [
          (0, 0.090),
          (0.3, 0.086),
          (0.75, 0.064),
          (1, 0.052),
        ], depthScale: 0.95),
        segments: 16,
        partOf: (t, angle) {
          final a = _deg(angle);
          if (a < 54) return part(MuscleSection.frontOfThighs);
          if (a > 126) return part(MuscleSection.backOfThighs);
          return part(MuscleSection.innerAndOuterThighs);
        },
      );
      // Lower leg: the calf behind, the shin in front.
      _bias = 0;
      _lathe(
        knee,
        ankle,
        _limb(0.405, const [
          (0, 0.051),
          (0.28, 0.058),
          (0.62, 0.040),
          (1, 0.028),
        ], forward: (t) => -0.014 * math.sin(math.pi * math.min(t / 0.6, 1))),
        segments: 14,
        partOf: (t, angle) =>
            _deg(angle) > 76 && t < 0.8 ? part(MuscleSection.calves) : _neutral,
      );
      // Foot.
      _bias = 0.02;
      _ellipsoid(
        _V(side * 0.075, 0.034, 0.036),
        const _V(0.037, 0.031, 0.094),
        bands: 6,
        segments: 10,
        partOf: (lat, lon) => _skinOther,
      );
    }
    _bias = 0;

    return _finish();
  }

  /// One surface from the hips to the base of the neck, filed by height and
  /// by angle from the front.
  void _torso() {
    const key = <(double, double, double, double)>[
      // (y, half width, half depth, forward offset)
      (0.80, 0.060, 0.050, -0.006),
      (0.84, 0.146, 0.094, -0.010),
      (0.88, 0.174, 0.106, -0.012),
      (0.93, 0.176, 0.108, -0.010),
      (0.98, 0.156, 0.098, -0.005),
      (1.03, 0.128, 0.087, 0.000),
      (1.08, 0.124, 0.087, 0.003),
      (1.13, 0.132, 0.093, 0.006),
      (1.19, 0.146, 0.099, 0.008),
      (1.25, 0.156, 0.102, 0.008),
      (1.31, 0.164, 0.098, 0.004),
      (1.36, 0.168, 0.088, -0.003),
      (1.40, 0.144, 0.074, -0.008),
      (1.43, 0.088, 0.058, -0.008),
      (1.455, 0.044, 0.044, -0.006),
    ];
    const bottom = 0.80;
    const top = 1.455;
    // Catmull-Rom between the key rings, four steps each, for a smooth side.
    final rings = <_Ring>[];
    double cr(double p0, double p1, double p2, double p3, double f) =>
        0.5 *
        (2 * p1 +
            (-p0 + p2) * f +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f +
            (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f);
    for (var i = 0; i + 1 < key.length; i++) {
      final p0 = key[math.max(i - 1, 0)];
      final p1 = key[i];
      final p2 = key[i + 1];
      final p3 = key[math.min(i + 2, key.length - 1)];
      for (var k = 0; k < 4; k++) {
        final f = k / 4;
        final y = cr(p0.$1, p1.$1, p2.$1, p3.$1, f);
        rings.add((
          t: (y - bottom) / (top - bottom),
          rx: cr(p0.$2, p1.$2, p2.$2, p3.$2, f),
          rz: cr(p0.$3, p1.$3, p2.$3, p3.$3, f),
          dz: cr(p0.$4, p1.$4, p2.$4, p3.$4, f),
        ));
      }
    }
    final last = key.last;
    rings.add((t: 1, rx: last.$2, rz: last.$3, dz: last.$4));

    _lathe(
      const _V(0, bottom, 0),
      const _V(0, top, 0),
      rings,
      segments: 32,
      // The hips are drawn over the tops of the thighs.
      biasOf: (t) => bottom + t * (top - bottom) < 0.95 ? 0.10 : 0,
      // A modest athletic bust, part of the chest.
      bump: (t, angle) {
        final y = bottom + t * (top - bottom);
        final dy = (y - 1.232) / 0.046;
        final da = (_deg(angle) - 30) / 21;
        return 0.038 * math.exp(-(dy * dy + da * da) / 2);
      },
      partOf: (t, angle) {
        final y = bottom + t * (top - bottom);
        final a = _deg(angle);
        // The collarbones and the base of the neck in front; the top of the
        // back behind.
        if (y >= 1.40) {
          return a > 70 ? MuscleSection.upperBack.index : _skinOther;
        }
        if (y >= 1.17) {
          return a < 58
              ? MuscleSection.chest.index
              : MuscleSection.upperBack.index;
        }
        if (y >= 1.09) {
          return a < 112
              ? MuscleSection.absAndSides.index
              : MuscleSection.upperBack.index;
        }
        if (y >= 0.965) {
          return a < 118
              ? MuscleSection.absAndSides.index
              : MuscleSection.lowerBack.index;
        }
        return a > 100 ? MuscleSection.glutes.index : _neutral;
      },
    );
  }

  FigureMesh _finish() {
    // Smooth normals: each vertex takes the faces around it, already wound
    // to point out.
    final normals = Float32List(_pos.length);
    for (var t = 0; t < _part.length; t++) {
      final a = _tri[t * 3], b = _tri[t * 3 + 1], c = _tri[t * 3 + 2];
      final pa = _p(a);
      final n = (_p(b) - pa).cross(_p(c) - pa);
      for (final v in [a, b, c]) {
        normals[v * 3] += n.x;
        normals[v * 3 + 1] += n.y;
        normals[v * 3 + 2] += n.z;
      }
    }
    for (var v = 0; v < normals.length; v += 3) {
      final n = _V(normals[v], normals[v + 1], normals[v + 2]);
      final u = n.length < 1e-12
          ? _V(_hint[v], _hint[v + 1], _hint[v + 2])
          : n.unit;
      normals[v] = u.x;
      normals[v + 1] = u.y;
      normals[v + 2] = u.z;
    }
    // A vertex whose faces belong to more than one muscle group sits on a
    // groove. The parts that are not a muscle count as one.
    final first = List<int>.filled(_pos.length ~/ 3, -1);
    final grooves = Uint8List(_pos.length ~/ 3);
    for (var t = 0; t < _part.length; t++) {
      final kind = _part[t] >= _neutral ? _neutral : _part[t];
      for (var k = 0; k < 3; k++) {
        final v = _tri[t * 3 + k];
        if (first[v] == -1) {
          first[v] = kind;
        } else if (first[v] != kind) {
          grooves[v] = 1;
        }
      }
    }
    return FigureMesh._(
      Float32List.fromList(_pos),
      normals,
      Int32List.fromList(_tri),
      Uint8List.fromList(_part),
      Float32List.fromList(_triBias),
      grooves,
    );
  }
}

/// The figure's colours: neutral linen where she has not trained, then soft
/// pink, pale pink and a deeper pink, and petrol only for her most trained.
abstract final class MuscleHeat {
  /// Where nothing is trained yet, and the parts that are not a muscle.
  static const Color untrained = AppColors.surfaceHighest;
  static const Color skin = AppColors.surfaceLow;
  static final Color hair = Color.lerp(
    AppColors.amber,
    AppColors.petrolDark,
    0.3,
  )!;

  /// The steps, lowest first. Petrol is the last and is kept for the top.
  static const List<Color> steps = [
    AppColors.pinkSoft,
    AppColors.brandPink,
    AppColors.pinkShade,
    AppColors.primary,
  ];

  /// The step a score falls in: -1 for nothing, otherwise 0 to 3.
  static int stepOf(double score) {
    if (score <= 0) return -1;
    if (score < 0.35) return 0;
    if (score < 0.65) return 1;
    if (score < 0.9) return 2;
    return 3;
  }

  static Color of(double score) {
    final step = stepOf(score);
    return step < 0 ? untrained : steps[step];
  }
}

/// What the last frame drew, for a tap to be read against.
class FigureHits {
  Float32List _xy = Float32List(0);
  Uint8List _parts = Uint8List(0);
  Int32List _order = Int32List(0);
  int _count = 0;

  void _store(Float32List xy, Uint8List parts, Int32List order, int count) {
    _xy = xy;
    _parts = parts;
    _order = order;
    _count = count;
  }

  /// The muscle group drawn on top at [point], or null for none.
  MuscleSection? sectionAt(Offset point) {
    for (var n = _count - 1; n >= 0; n--) {
      final t = _order[n];
      if (!_inside(t, point)) continue;
      final part = _parts[t];
      return part < MuscleSection.values.length
          ? MuscleSection.values[part]
          : null;
    }
    return null;
  }

  bool _inside(int t, Offset p) {
    final o = t * 6;
    final ax = _xy[o], ay = _xy[o + 1];
    final bx = _xy[o + 2], by = _xy[o + 3];
    final cx = _xy[o + 4], cy = _xy[o + 5];
    double side(double x1, double y1, double x2, double y2) =>
        (x2 - x1) * (p.dy - y1) - (y2 - y1) * (p.dx - x1);
    final d1 = side(ax, ay, bx, by);
    final d2 = side(bx, by, cx, cy);
    final d3 = side(cx, cy, ax, ay);
    final neg = d1 < 0 || d2 < 0 || d3 < 0;
    final pos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(neg && pos);
  }

  /// A point inside [section] where a tap lands on it, or null when no face
  /// of it is in view. For tests and for screen readers' focus.
  Offset? pointOn(MuscleSection section) {
    Offset? best;
    var bestArea = 0.0;
    for (var n = _count - 1; n >= 0; n--) {
      final t = _order[n];
      if (_parts[t] != section.index) continue;
      final o = t * 6;
      final centre = Offset(
        (_xy[o] + _xy[o + 2] + _xy[o + 4]) / 3,
        (_xy[o + 1] + _xy[o + 3] + _xy[o + 5]) / 3,
      );
      if (sectionAt(centre) != section) continue;
      final area =
          ((_xy[o + 2] - _xy[o]) * (_xy[o + 5] - _xy[o + 1]) -
                  (_xy[o + 4] - _xy[o]) * (_xy[o + 3] - _xy[o + 1]))
              .abs();
      if (area > bestArea) {
        bestArea = area;
        best = centre;
      }
    }
    return best;
  }
}

/// Paints the figure at [yaw], turning with it and nothing else.
class MuscleFigurePainter extends CustomPainter {
  MuscleFigurePainter({
    required this.yaw,
    required this.scores,
    required this.hits,
    this.selected,
    this.pitch = 0.10,
  }) : super(repaint: yaw);

  final ValueListenable<double> yaw;

  /// Each section's score, 0 to 1. A section not in the map is untrained.
  final Map<MuscleSection, double> scores;
  final FigureHits hits;
  final MuscleSection? selected;
  final double pitch;

  static const double _centreY = 0.86;
  static const double _camera = 4.2;

  // Kept between frames so a frame allocates nothing it does not have to.
  static Float32List _rx = Float32List(0);
  static Float32List _ry = Float32List(0);
  static Float32List _rz = Float32List(0);
  static Float32List _sx = Float32List(0);
  static Float32List _sy = Float32List(0);
  static Float32List _nx = Float32List(0);
  static Float32List _ny = Float32List(0);
  static Float32List _nz = Float32List(0);

  @override
  void paint(Canvas canvas, Size size) {
    final mesh = FigureMesh.instance;
    final vc = mesh.vertexCount;
    if (_rx.length != vc) {
      _rx = Float32List(vc);
      _ry = Float32List(vc);
      _rz = Float32List(vc);
      _sx = Float32List(vc);
      _sy = Float32List(vc);
      _nx = Float32List(vc);
      _ny = Float32List(vc);
      _nz = Float32List(vc);
    }

    final scale = size.height / (FigureMesh.height * 1.06);
    final cx = size.width / 2;
    final cy = size.height / 2 + size.height * 0.01;
    final cyaw = math.cos(yaw.value), syaw = math.sin(yaw.value);
    final cp = math.cos(pitch), sp = math.sin(pitch);

    final pos = mesh.positions;
    final nrm = mesh.normals;
    for (var v = 0; v < vc; v++) {
      final x = pos[v * 3], y = pos[v * 3 + 1] - _centreY, z = pos[v * 3 + 2];
      final x1 = x * cyaw + z * syaw;
      final z1 = -x * syaw + z * cyaw;
      final y2 = y * cp - z1 * sp;
      final z2 = y * sp + z1 * cp;
      _rx[v] = x1;
      _ry[v] = y2;
      _rz[v] = z2;
      final k = scale * _camera / (_camera - z2);
      _sx[v] = cx + x1 * k;
      _sy[v] = cy - y2 * k;

      final nx = nrm[v * 3], ny = nrm[v * 3 + 1], nz = nrm[v * 3 + 2];
      final nx1 = nx * cyaw + nz * syaw;
      final nz1 = -nx * syaw + nz * cyaw;
      _nx[v] = nx1;
      _ny[v] = ny * cp - nz1 * sp;
      _nz[v] = ny * sp + nz1 * cp;
    }

    // Faces turned toward the eye, back to front.
    final tris = mesh.triangles;
    final tc = mesh.triangleCount;
    final depth = Float64List(tc);
    final visible = <int>[];
    for (var t = 0; t < tc; t++) {
      final a = tris[t * 3], b = tris[t * 3 + 1], c = tris[t * 3 + 2];
      final ux = _rx[b] - _rx[a], uy = _ry[b] - _ry[a], uz = _rz[b] - _rz[a];
      final vx = _rx[c] - _rx[a], vy = _ry[c] - _ry[a], vz = _rz[c] - _rz[a];
      final nx = uy * vz - uz * vy;
      final ny = uz * vx - ux * vz;
      final nz = ux * vy - uy * vx;
      final mx = (_rx[a] + _rx[b] + _rx[c]) / 3;
      final my = (_ry[a] + _ry[b] + _ry[c]) / 3;
      final mz = (_rz[a] + _rz[b] + _rz[c]) / 3;
      // Toward the camera at (0, 0, _camera).
      if (nx * -mx + ny * -my + nz * (_camera - mz) <= 0) continue;
      depth[t] = mz + mesh.bias[t];
      visible.add(t);
    }
    visible.sort((p, q) => depth[p].compareTo(depth[q]));

    // Ground shadow, under her feet.
    final floor = cy - (-_centreY * cp) * scale;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, floor + 2),
        width: scale * 0.42,
        height: scale * 0.07,
      ),
      Paint()
        ..color = AppColors.onSurface.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final base = <int, Color>{
      for (final s in MuscleSection.values) s.index: _baseFor(s),
      _neutral: _dim(MuscleHeat.skin, null),
      _skinOther: _dim(MuscleHeat.skin, null),
      _hair: _dim(MuscleHeat.hair, null),
    };

    final count = visible.length;
    final positions = Float32List(count * 6);
    final colors = Int32List(count * 3);
    final order = Int32List(tc);
    final screen = Float32List(tc * 6);
    const lx = -0.48, ly = 0.52, lz = 0.70;
    final grooves = mesh.grooves;
    for (var n = 0; n < count; n++) {
      final t = visible[n];
      order[n] = t;
      final colour = base[mesh.parts[t]]!;
      for (var k = 0; k < 3; k++) {
        final v = tris[t * 3 + k];
        positions[n * 6 + k * 2] = _sx[v];
        positions[n * 6 + k * 2 + 1] = _sy[v];
        screen[t * 6 + k * 2] = _sx[v];
        screen[t * 6 + k * 2 + 1] = _sy[v];
        final lambert = math.max(0.0, _nx[v] * lx + _ny[v] * ly + _nz[v] * lz);
        colors[n * 3 + k] = _shade(colour, lambert, groove: grooves[v] == 1);
      }
    }
    hits._store(screen, mesh.parts, order, count);

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  Color _baseFor(MuscleSection section) {
    final score = scores[section] ?? 0;
    return _dim(MuscleHeat.of(score), section);
  }

  /// With a section chosen, everything else steps back toward the page so
  /// the chosen one stands out by its shape as well as its colour.
  Color _dim(Color colour, MuscleSection? section) {
    final chosen = selected;
    if (chosen == null || section == chosen) return colour;
    return Color.lerp(colour, AppColors.surface, 0.62)!;
  }

  /// Soft light: a cool shadow from the theme's own ink on the side turned
  /// away, and a little lift where the light falls.
  static int _shade(Color colour, double lambert, {bool groove = false}) {
    final shadow = (1 - lambert) * 0.58 + (groove ? 0.16 : 0);
    // Lift toward the page where the light falls, so a dark petrol part
    // still shows its form.
    final lift = lambert * lambert * lambert * 0.2;
    final r = colour.r, g = colour.g, b = colour.b;
    const sr = 0x12 / 255, sg = 0x3F / 255, sb = 0x50 / 255;
    double mix(double c, double s) {
      final shaded = c + (s - c) * shadow;
      return shaded + (1 - shaded) * lift;
    }

    int ch(double v) => (v.clamp(0.0, 1.0) * 255).round();
    return (0xFF << 24) |
        (ch(mix(r, sr)) << 16) |
        (ch(mix(g, sg)) << 8) |
        ch(mix(b, sb));
  }

  @override
  bool shouldRepaint(MuscleFigurePainter old) =>
      old.yaw != yaw ||
      old.selected != selected ||
      old.pitch != pitch ||
      !_sameScores(old.scores, scores);

  static bool _sameScores(
    Map<MuscleSection, double> a,
    Map<MuscleSection, double> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

/// The figure she turns and taps.
///
/// A drag turns it with her finger in either reading direction (the body is
/// never mirrored), and keeps turning a little after she lets go, slowing to
/// a stop. With reduced motion it stands facing her and turns only while her
/// finger moves.
class MuscleFigure extends StatefulWidget {
  const MuscleFigure({
    super.key,
    required this.scores,
    required this.semanticsLabel,
    required this.frontLabel,
    required this.backLabel,
    this.selected,
    this.onSelect,
    this.height = 400,
    this.hits,
  });

  final Map<MuscleSection, double> scores;
  final MuscleSection? selected;
  final ValueChanged<MuscleSection?>? onSelect;

  /// What a screen reader hears for the figure: the sections with their sets.
  final String semanticsLabel;

  /// The toggle's words: "See the front" while her back is shown, and
  /// "See the back" while her front is.
  final String frontLabel;
  final String backLabel;
  final double height;

  /// Where the last frame's faces landed. Given by a test that taps a part.
  final FigureHits? hits;

  @override
  State<MuscleFigure> createState() => MuscleFigureState();
}

class MuscleFigureState extends State<MuscleFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _yaw = AnimationController.unbounded(
    vsync: this,
  );
  late final FigureHits _hits = widget.hits ?? FigureHits();
  final ValueNotifier<bool> _back = ValueNotifier<bool>(false);
  bool _introduced = false;

  @override
  void initState() {
    super.initState();
    _yaw.addListener(() {
      final back = _showsBack;
      if (back != _back.value) _back.value = back;
    });
  }

  /// The current turn, in radians: 0 faces her, pi shows the back.
  double get yaw => _yaw.value;

  FigureHits get hits => _hits;

  bool get _showsBack => math.cos(_yaw.value) < 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introduced) return;
    _introduced = true;
    if (!handMotionOff(context)) {
      // A short turn in, once, so she can see it is a body she can turn.
      _yaw.value = -0.55;
      _yaw.animateTo(
        0,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _yaw.dispose();
    _back.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails details) {
    _yaw.stop();
    _yaw.value += details.delta.dx * 0.012;
  }

  void _dragEnd(DragEndDetails details) {
    if (handMotionOff(context)) return;
    final velocity = details.velocity.pixelsPerSecond.dx * 0.012;
    if (velocity.abs() < 0.05) return;
    _yaw.animateWith(FrictionSimulation(0.08, _yaw.value, velocity));
  }

  /// Turns her to face the front, or the back.
  void turn({required bool toBack}) {
    final now = _yaw.value;
    final base = (now / (2 * math.pi)).roundToDouble() * 2 * math.pi;
    var target = toBack ? base + math.pi : base;
    if ((target - now).abs() > math.pi) {
      target += target > now ? -2 * math.pi : 2 * math.pi;
    }
    if (handMotionOff(context)) {
      _yaw.value = target;
    } else {
      _yaw.animateTo(
        target,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _tap(TapUpDetails details) {
    final hit = _hits.sectionAt(details.localPosition);
    widget.onSelect?.call(hit == widget.selected ? null : hit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: widget.semanticsLabel,
          image: true,
          child: ExcludeSemantics(
            child: GestureDetector(
              key: const ValueKey('p06-figure'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _dragUpdate,
              onHorizontalDragEnd: _dragEnd,
              onTapUp: _tap,
              child: RepaintBoundary(
                child: SizedBox(
                  height: widget.height,
                  child: CustomPaint(
                    painter: MuscleFigurePainter(
                      yaw: _yaw,
                      scores: widget.scores,
                      hits: _hits,
                      selected: widget.selected,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.center,
          child: ValueListenableBuilder<bool>(
            valueListenable: _back,
            builder: (context, back, _) {
              return TextButton.icon(
                key: const ValueKey('p06-turn'),
                onPressed: () => turn(toBack: !back),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDim,
                  minimumSize: const Size(48, 44),
                ),
                icon: const Icon(Icons.threesixty, size: 20),
                label: Text(
                  back ? widget.frontLabel : widget.backLabel,
                  style: AppText.label.copyWith(color: AppColors.primaryDim),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
