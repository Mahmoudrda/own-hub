/// P06's body map: a woman's figure from the front and from the back, every
/// muscle its own flat shape, coloured by the sets where it did the work.
///
/// Drawn by hand as paths in a box 100 wide and 220 high per view. Only her
/// right side is written down for each shape; the left is its mirror about
/// the middle, so the two always match. Shapes are listed from the deepest
/// up: one that lies over another is drawn later and its outline is the line
/// between them. Before anything is painted, each shape is cut to what shows
/// of it (inside the body and not under a later shape), so the colours, the
/// white lines between muscles and a tap all read the same outlines.
///
/// A few muscles are drawn so the body reads true but are never coloured:
/// the neck, the side of the ribs, the hip flexors, the strap across the
/// thigh and the shins. Nothing she logs trains them on its own.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../theme/body_map_tokens.dart';
import '../../train/domain/exercise_library.dart';

/// The two views, front on the left and back on the right in every
/// language: it is a body, not a line of text.
enum BodyView { front, back }

/// One muscle as she sees it on one side of one view.
@immutable
class MuscleArea {
  const MuscleArea._({
    required this.id,
    required this.view,
    required this.muscle,
    required this.mirrored,
    required this.outline,
  });

  /// The shape's name, with `.r` or `.l` for the side of the picture.
  final String id;
  final BodyView view;

  /// The muscle it is coloured by, or null for one that is drawn but never
  /// trained on its own.
  final Muscle? muscle;

  /// True for the shape on the right-hand side of the picture.
  final bool mirrored;

  /// The shape as written, in the view's box, before anything covers it.
  final Path outline;
}

/// The figure's colours: light grey where she has not trained, then soft
/// pink, brand pink and a deeper pink, and petrol only for her most trained.
abstract final class MuscleHeat {
  /// The body, and every muscle she has not trained.
  static const Color untrained = BodyMapInk.body;

  /// The steps, lowest first. Petrol is the last and is kept for the top.
  static const List<Color> steps = [
    AppColors.pinkSoft,
    AppColors.brandPink,
    AppColors.pinkDeep,
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

  /// The colour [area] is filled with for these per-muscle [scores]. A shape
  /// with no muscle is always grey, whatever she trained.
  static Color fillFor(MuscleArea area, Map<Muscle, double> scores) {
    final muscle = area.muscle;
    if (muscle == null) return untrained;
    return of(scores[muscle] ?? 0);
  }
}

class _Shape {
  const _Shape(this.id, this.muscle, this.d);
  final String id;
  final Muscle? muscle;

  /// Her right side, as absolute M, L, C, Q and Z commands.
  final String d;
}

/// The art, built once.
abstract final class MuscleMapArt {
  static const double width = 100;
  static const double height = 220;

  /// The body's outline, the same from the front and the back.
  static final Path silhouette = _symmetric(_silhouette);

  /// Her hair: a bun, and the hairline from the front.
  static final Map<BodyView, Path> hair = {
    BodyView.front: _symmetric(_hairFront)
      ..addOval(Rect.fromCircle(center: const Offset(50, 4.8), radius: 4.2)),
    BodyView.back: _symmetric(_hairBack)
      ..addOval(Rect.fromCircle(center: const Offset(50, 4.8), radius: 4.2)),
  };

  /// Every shape, deepest first, per view.
  static final Map<BodyView, List<MuscleArea>> areas = {
    BodyView.front: _build(BodyView.front, _front),
    BodyView.back: _build(BodyView.back, _back),
  };

  /// What shows of each shape: inside the body and under nothing drawn after
  /// it. The visible parts of one view never overlap.
  static final Map<MuscleArea, Path> visible = _visible();

  /// The ids of shapes drawn but never coloured.
  static const Set<String> untrainable = {
    'neck',
    'serratus',
    'hipFlexors',
    'sartorius',
    'shin',
  };

  static List<MuscleArea> _build(BodyView view, List<_Shape> shapes) => [
    for (final s in shapes)
      for (final mirrored in [false, true])
        MuscleArea._(
          id: '${s.id}.${mirrored ? 'l' : 'r'}',
          view: view,
          muscle: s.muscle,
          mirrored: mirrored,
          outline: _parse(s.d, mirror: mirrored),
        ),
  ];

  static Map<MuscleArea, Path> _visible() {
    final out = <MuscleArea, Path>{};
    for (final list in areas.values) {
      var covered = Path();
      for (final area in list.reversed) {
        final inside = Path.combine(
          PathOperation.intersect,
          area.outline,
          silhouette,
        );
        out[area] = Path.combine(PathOperation.difference, inside, covered);
        covered = Path.combine(PathOperation.union, covered, area.outline);
      }
    }
    return out;
  }

  static Path _symmetric(String d) => Path.combine(
    PathOperation.union,
    _parse(d, mirror: false),
    _parse(d, mirror: true),
  );

  static final RegExp _token = RegExp(r'[MLCQZ]|-?\d*\.?\d+');
  static final RegExp _command = RegExp(r'^[MLCQZ]$');

  /// A path from absolute M, L, C, Q and Z commands, mirrored about the
  /// middle of the box when [mirror] is true.
  static Path _parse(String d, {required bool mirror}) {
    final tokens = [for (final m in _token.allMatches(d)) m.group(0)!];
    final path = Path();
    var i = 0;
    var command = 'M';
    double x() =>
        mirror ? width - double.parse(tokens[i++]) : double.parse(tokens[i++]);
    double y() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      if (_command.hasMatch(tokens[i])) {
        command = tokens[i++];
        if (command == 'Z') {
          path.close();
          continue;
        }
      }
      switch (command) {
        case 'M':
          path.moveTo(x(), y());
          command = 'L';
        case 'L':
          path.lineTo(x(), y());
        case 'C':
          path.cubicTo(x(), y(), x(), y(), x(), y());
        case 'Q':
          path.quadraticBezierTo(x(), y(), x(), y());
        default:
          throw FormatException('path command $command', d);
      }
    }
    return path;
  }
}

/// Where the two views sit in a painted size, and what is under a point.
@immutable
class MuscleMapLayout {
  const MuscleMapLayout(this.size);

  final Size size;

  /// Art units to logical pixels.
  double get scale => math.min(
    size.width / (2 * MuscleMapArt.width),
    size.height / MuscleMapArt.height,
  );

  /// The top left of [view]'s box. Front on the left in every language.
  Offset originOf(BodyView view) {
    final s = scale;
    final left = (size.width - 2 * MuscleMapArt.width * s) / 2;
    final top = (size.height - MuscleMapArt.height * s) / 2;
    return Offset(
      left + (view == BodyView.front ? 0 : MuscleMapArt.width * s),
      top,
    );
  }

  Offset toArt(BodyView view, Offset point) => (point - originOf(view)) / scale;

  Offset fromArt(BodyView view, Offset art) => originOf(view) + art * scale;

  /// The shape under [point], or null for none (the page, her hands and
  /// face, her hair).
  MuscleArea? areaAt(Offset point) {
    for (final view in BodyView.values) {
      final art = toArt(view, point);
      if (art.dx < 0 || art.dx > MuscleMapArt.width) continue;
      if (MuscleMapArt.hair[view]!.contains(art)) return null;
      for (final area in MuscleMapArt.areas[view]!) {
        if (MuscleMapArt.visible[area]!.contains(art)) return area;
      }
    }
    return null;
  }

  /// A point well inside [area]'s visible part, or null when none of it
  /// shows. For tests and for checking the art.
  Offset? pointIn(MuscleArea area) {
    final shown = MuscleMapArt.visible[area]!;
    final bounds = shown.getBounds();
    if (bounds.isEmpty) return null;
    Offset? best;
    var bestRoom = -1.0;
    const steps = 14;
    for (var i = 1; i < steps; i++) {
      for (var j = 1; j < steps; j++) {
        final p = Offset(
          bounds.left + bounds.width * i / steps,
          bounds.top + bounds.height * j / steps,
        );
        if (!shown.contains(p)) continue;
        // Prefer a point with room around it, away from the white lines.
        var room = 0.0;
        for (final r in [0.4, 0.8, 1.2]) {
          final around = [
            p + Offset(r, 0),
            p - Offset(r, 0),
            p + Offset(0, r),
            p - Offset(0, r),
          ];
          if (around.every(shown.contains)) room = r;
        }
        if (room > bestRoom) {
          bestRoom = room;
          best = p;
        }
      }
    }
    return best == null ? null : fromArt(area.view, best);
  }

  /// A point on [muscle], in either view, or null when it is not drawn.
  Offset? pointOn(Muscle muscle, {BodyView? view}) {
    for (final v in view == null ? BodyView.values : [view]) {
      for (final area in MuscleMapArt.areas[v]!) {
        if (area.muscle != muscle) continue;
        final p = pointIn(area);
        if (p != null) return p;
      }
    }
    return null;
  }
}

/// Paints both views: grey body, each muscle in its colour with a thin white
/// line around it, the outline, her hair, and a white ring round what she
/// chose.
class MuscleMapPainter extends CustomPainter {
  MuscleMapPainter({required this.scores, this.selected = const {}});

  /// Each muscle's score, 0 to 1. A muscle not in the map is untrained.
  final Map<Muscle, double> scores;

  /// The muscles she chose: one she tapped, or a group from the list.
  final Set<Muscle> selected;

  /// Art units.
  static const double _seam = 0.75;
  static const double _outline = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = MuscleMapLayout(size);
    final s = layout.scale;
    final body = Paint()..color = MuscleHeat.untrained;
    final seam = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _seam
      ..strokeJoin = StrokeJoin.round;
    final edge = Paint()
      ..color = BodyMapInk.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outline
      ..strokeJoin = StrokeJoin.round;
    final hair = Paint()..color = BodyMapInk.hair;
    final fill = Paint();
    final chosen = selected;

    for (final view in BodyView.values) {
      canvas.save();
      final origin = layout.originOf(view);
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(s);
      canvas.drawPath(MuscleMapArt.silhouette, body);
      canvas.save();
      canvas.clipPath(MuscleMapArt.silhouette);
      for (final area in MuscleMapArt.areas[view]!) {
        final shown = MuscleMapArt.visible[area]!;
        var colour = MuscleHeat.fillFor(area, scores);
        // With a muscle chosen, the rest steps back a little so the chosen
        // one stands out by its outline and its colour.
        if (chosen.isNotEmpty && !chosen.contains(area.muscle)) {
          colour = Color.lerp(colour, AppColors.surface, 0.35)!;
        }
        canvas.drawPath(shown, fill..color = colour);
        canvas.drawPath(shown, seam);
      }
      canvas.restore();
      canvas.drawPath(MuscleMapArt.silhouette, edge);
      canvas.drawPath(MuscleMapArt.hair[view]!, hair);
      if (chosen.isNotEmpty) {
        final ring = Path();
        for (final area in MuscleMapArt.areas[view]!) {
          if (chosen.contains(area.muscle)) {
            ring.addPath(MuscleMapArt.visible[area]!, Offset.zero);
          }
        }
        canvas.drawPath(
          ring,
          Paint()
            ..color = AppColors.petrolDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.1
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(
          ring,
          Paint()
            ..color = AppColors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..strokeJoin = StrokeJoin.round,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(MuscleMapPainter old) =>
      !_same(old.scores, scores) ||
      old.selected.length != selected.length ||
      !old.selected.containsAll(selected);

  static bool _same(Map<Muscle, double> a, Map<Muscle, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- the art
//
// Her right side only, in a box 100 wide and 220 high: the middle of the
// body is x = 50, the top of the bun y = 0.6 and the soles y = 214.6.

const String _silhouette = '''
M50,8.0
C44.6,8.0 41.0,11.8 41.1,18.2
C41.2,23.0 42.4,27.4 44.6,30.4
C45.1,31.1 45.4,31.9 45.4,32.8
L45.3,37.0
C42.6,39.4 38.6,41.2 34.6,42.4
C32.0,43.2 29.4,44.4 27.8,46.6
C25.8,49.2 24.9,53.2 24.8,57.4
C24.6,62.4 23.1,67.4 22.5,72.6
C21.9,77.6 21.3,82.0 21.0,86.0
C20.0,89.4 18.9,93.0 18.5,97.0
C18.0,102.6 17.7,108.4 17.6,113.6
C16.8,116.6 15.9,119.8 15.8,123.6
C15.7,128.0 16.6,132.6 18.7,134.9
C19.9,136.1 21.5,135.4 21.9,133.4
C22.5,129.8 22.7,125.0 22.6,121.0
C22.6,118.8 22.5,117.0 22.4,115.6
C23.4,108.8 25.2,101.0 26.2,95.0
C26.7,92.0 27.2,89.6 27.4,87.6
C28.2,82.0 29.8,76.0 30.4,70.4
C30.8,66.0 31.4,62.4 32.6,59.6
C33.2,61.6 33.6,64.6 34.0,67.6
C34.6,73.0 36.0,80.6 37.0,87.0
C37.2,90.4 36.4,94.0 34.8,98.0
C32.6,102.6 30.8,106.6 30.6,111.2
C30.4,117.0 30.8,124.4 31.6,131.0
C32.4,138.6 34.2,146.6 35.6,153.0
C36.0,155.6 35.9,158.0 35.6,160.6
C34.8,165.0 34.4,169.2 34.7,173.6
C35.2,181.0 37.8,191.0 39.6,199.6
C39.8,202.0 39.2,204.6 39.0,207.0
C38.8,209.8 39.6,212.6 41.6,213.8
C43.2,214.8 45.6,214.6 46.3,213.2
C46.8,211.6 46.4,208.0 45.8,205.0
C45.5,203.0 45.5,200.6 45.6,198.6
C46.4,191.0 47.4,182.6 47.2,175.4
C47.0,169.0 46.0,164.0 46.0,160.2
C46.0,156.4 46.6,152.6 47.0,148.6
C47.6,141.0 48.6,131.0 49.0,124.0
C49.2,120.6 49.6,118.6 50.0,117.8
L50.3,117.8 L50.3,8.0 Z
''';

const String _hairFront = '''
M50,7.0
C44.2,7.0 40.4,11.0 40.4,17.4
C40.4,19.6 40.7,21.6 41.3,23.4
C41.8,21.2 42.4,18.6 43.6,16.6
C45.2,14.2 47.6,12.6 50.3,12.4
L50.3,7.0 Z
''';

const String _hairBack = '''
M50,7.0
C44.0,7.0 40.2,11.2 40.3,18.0
C40.4,23.2 41.8,27.6 44.4,29.9
C46.2,31.0 48.2,30.9 50.3,30.4
L50.3,7.0 Z
''';

/// From the front, deepest first.
const List<_Shape> _front = [
  // Inner thigh, under the strap and the hip flexors.
  _Shape('adductors', Muscle.adductors, '''
M50,116.6 C49.0,115.0 48.2,113.4 47.4,111.4 L43.6,118.0
C45.6,126.0 47.0,136.0 47.6,146.0 L50,146.0 Z'''),
  _Shape('hipFlexors', null, '''
M38.0,103.0 L47.6,110.8 C46.6,113.2 45.6,116.4 45.0,119.4
C43.2,115.2 41.0,109.6 39.4,104.6 Z'''),
  // Outer thigh, under the front of the thigh.
  _Shape('vastusLateralis', Muscle.quads, '''
M36.0,106.0 L29.0,110.0 L29.0,150.0
C32.4,153.6 34.6,156.0 36.4,156.4 C38.0,155.0 39.6,152.6 40.8,150.2
L41.6,140.0 L40.0,106.0 Z'''),
  _Shape('rectusFemoris', Muscle.quads, '''
M38.0,106.0 C36.8,116.0 36.8,128.0 38.4,139.0
C39.2,144.0 40.4,148.4 41.6,151.6 C43.0,148.0 44.2,143.0 44.8,137.0
C45.4,128.0 44.6,117.0 42.0,106.0 Z'''),
  // The teardrop above the inside of the knee.
  _Shape('vastusMedialis', Muscle.quads, '''
M44.8,128.0 C43.8,136.0 43.6,144.6 42.8,151.6
C43.8,154.8 45.4,156.2 47.0,155.4 L49.0,150.0 L48.8,134.0 Z'''),
  // The outer hip, at the front.
  _Shape('hipFront', Muscle.abductors, '''
M37.6,102.0 L29.0,104.0 L29.0,118.0
C31.0,121.6 32.6,123.6 33.6,124.6 C35.0,120.0 36.4,113.6 38.6,106.0 Z'''),
  // The long strap from the hip bone across to the inside of the knee.
  _Shape('sartorius', null, '''
M38.4,103.8 C40.6,109.6 43.0,117.6 44.8,125.4
C46.0,131.0 46.6,137.0 46.8,143.0 L48.4,152.0 L50,152.0
L48.6,143.0 C48.4,136.6 47.6,130.0 46.6,124.0
C44.6,115.6 41.6,108.6 39.0,103.4 Z'''),
  _Shape('obliques', Muscle.obliques, '''
M50,64.0 L31.0,64.0 L30.6,98.6
C33.4,100.6 35.6,102.4 37.4,103.6 C40.4,105.6 43.6,108.4 46.6,110.6
L50,112.0 Z'''),
  // The six-pack, in four pieces either side of the middle line.
  _Shape('abs1', Muscle.core, '''
M50,67.4 C47.6,67.4 45.6,67.8 44.0,68.6 C43.6,71.2 43.4,73.8 43.4,76.2
C45.6,76.0 48.0,76.4 50,76.8 Z'''),
  _Shape('abs2', Muscle.core, '''
M50,76.8 C48.0,76.4 45.6,76.0 43.4,76.2 C43.2,79.0 43.1,81.8 43.2,84.6
C45.4,84.4 47.8,84.6 50,85.0 Z'''),
  _Shape('abs3', Muscle.core, '''
M50,85.0 C47.8,84.6 45.4,84.4 43.2,84.6 C43.2,87.6 43.3,90.6 43.5,93.4
C45.6,93.2 47.8,93.4 50,93.8 Z'''),
  _Shape('abs4', Muscle.core, '''
M50,93.8 C47.8,93.4 45.6,93.2 43.5,93.4 C43.7,96.4 44.0,99.0 44.4,101.6
C44.9,104.4 45.5,106.8 46.4,109.0 C47.2,110.8 48.4,112.0 50,112.6 Z'''),
  // The side of the ribs, between the chest and the obliques.
  _Shape('serratus', null, '''
M32.6,58.0 L41.6,63.6 C42.0,66.4 41.4,68.8 39.6,69.8
C38.8,70.0 38.4,70.2 38.6,70.8 C39.8,71.8 39.8,73.6 38.4,74.0
C37.8,74.2 37.4,74.6 37.6,75.2 C38.4,76.4 38.0,78.0 36.6,78.2
L35.4,78.4 L33.0,62.0 Z'''),
  // The edge of the lats, seen past the ribs.
  _Shape('latsFront', Muscle.lats, '''
M33.2,60.4 C35.0,64.4 36.4,69.4 37.0,74.0
C37.4,77.4 37.6,80.6 37.6,84.0 L30.0,84.0 L30.0,58.0 Z'''),
  _Shape('chest', Muscle.chest, '''
M50,47.0 C46.4,46.0 41.6,45.6 35.8,44.8 C34.8,48.8 33.4,53.0 31.6,57.0
L31.8,58.6 C32.6,59.4 33.2,60.0 33.6,60.8
C36.4,63.4 40.0,65.6 43.6,66.4 C46.0,66.8 48.2,66.4 50,65.6 Z'''),
  // The top of the traps, between the neck and the shoulder.
  _Shape('trapsFront', Muscle.upperBack, '''
M45.6,32.0 L45.6,40.6 C42.6,42.8 39.0,44.2 35.0,45.4
L31.0,45.6 L30.0,40.0 Z'''),
  _Shape('neck', null, '''
M44.0,29.6 C45.4,33.6 47.0,38.4 48.0,44.6 L50,44.6
C49.0,40.0 47.4,34.6 46.0,30.4 Z'''),
  // Upper arm: the back of it shows at the outside edge.
  _Shape('tricepsFront', Muscle.triceps, '''
M28.0,62.0 L20.0,62.0 L20.0,82.6
C21.6,82.4 23.4,81.8 25.0,80.4 Z'''),
  _Shape('biceps', Muscle.biceps, '''
M29.0,60.6 C27.6,62.4 26.0,65.6 25.2,69.4 C24.4,73.6 24.2,78.0 24.8,81.6
C25.2,83.4 25.8,84.6 26.4,85.4 C27.4,84.2 28.4,82.4 29.4,79.8
C30.6,76.0 31.0,71.0 31.0,66.4 C30.8,63.8 30.0,61.8 29.0,60.6 Z'''),
  // The whole shoulder cap; the front of it is laid over.
  _Shape('sideDelts', Muscle.sideDelts, '''
M37.4,45.0 C33.4,43.0 29.4,43.6 27.0,46.4 C23.6,50.4 23.0,56.4 23.6,61.4
C24.2,64.4 25.4,66.8 27.0,68.0 C28.6,64.4 30.6,60.4 32.0,56.0 Z'''),
  _Shape('frontDelts', Muscle.frontDelts, '''
M37.4,45.0 C36.4,49.6 34.4,54.4 31.6,59.2 C30.0,62.4 28.4,65.4 27.0,68.0
C26.9,65.8 26.9,63.2 27.2,60.4 C28.0,55.0 29.0,49.4 30.4,43.6
C33.0,43.0 35.4,43.6 37.4,45.0 Z'''),
  // Forearm, palm forward: the flexors inside, the long muscle outside.
  _Shape('forearmInner', Muscle.forearms, '''
M25.0,85.0 C26.6,85.4 27.6,86.4 28.0,88.0 C27.4,96.0 25.2,105.0 23.2,113.4
L22.8,115.0 L20.4,114.6 C20.6,106.0 21.6,96.0 23.2,88.0
C23.6,86.6 24.2,85.6 25.0,85.0 Z'''),
  _Shape('forearmOuter', Muscle.forearms, '''
M22.6,82.0 C21.2,84.0 19.4,88.0 18.0,94.0 L17.4,112.0 L19.0,113.6
C19.8,108.0 20.8,102.0 22.2,96.0 C23.2,92.0 24.2,88.4 24.8,85.6 Z'''),
  // Lower leg: the calf either side, the shin muscle between.
  _Shape('calfOuter', Muscle.calves, '''
M36.0,162.0 L32.0,164.0 L32.0,182.0
C33.6,185.0 35.6,186.4 37.6,186.2 C38.6,186.0 39.4,185.0 39.8,184.0
L40.0,176.0 L38.0,163.0 Z'''),
  _Shape('soleusFront', Muscle.calves, '''
M47.0,183.0 C45.6,185.0 44.6,188.0 44.2,192.0
C44.4,194.0 45.0,195.6 46.0,196.6 L49.0,196.0 L49.0,183.0 Z'''),
  _Shape('calfInner', Muscle.calves, '''
M46.6,160.6 C45.2,161.0 44.4,162.0 44.2,163.6
C43.4,168.0 43.2,174.0 43.8,179.0 C44.2,182.6 45.2,185.6 46.6,187.6
L49.0,186.0 L49.0,160.0 Z'''),
  _Shape('shin', null, '''
M38.0,162.6 C39.6,161.8 41.2,162.6 41.6,164.8
C42.0,170.0 41.8,176.0 41.8,182.0 C41.8,186.0 42.4,190.0 43.4,196.0
L42.6,196.4 C41.4,191.0 40.2,187.0 39.2,183.0
C37.8,177.0 36.8,171.0 36.8,166.8 C36.8,164.8 37.2,163.4 38.0,162.6 Z'''),
];

/// From the back, deepest first.
const List<_Shape> _back = [
  _Shape('adductorsBack', Muscle.adductors, '''
M42.0,120.0 L50,120.0 L50,150.0 L46.0,150.0 Z'''),
  // The outer thigh, past the hamstrings.
  _Shape('quadsBack', Muscle.quads, '''
M34.0,126.4 C33.6,134.0 34.4,142.0 36.0,150.0
C36.4,153.0 36.8,155.4 37.2,157.6 L36.0,158.0 L29.0,150.0 L29.0,128.0 Z'''),
  // The inner hamstrings, then the outer one over them.
  _Shape('hamstringsInner', Muscle.hamstrings, '''
M40.8,122.0 L45.0,122.0 C45.4,130.0 45.8,138.0 45.8,144.0
C45.8,150.0 45.4,155.0 44.8,160.6 C43.8,157.4 42.8,153.0 42.0,148.6
C41.2,144.0 40.8,136.0 40.8,122.0 Z'''),
  _Shape('hamstringsOuter', Muscle.hamstrings, '''
M40.8,122.0 C41.4,130.0 41.6,137.0 41.0,143.6
C40.4,149.0 39.2,153.8 37.8,159.0 C37.2,155.6 36.2,151.2 35.4,146.6
C34.6,141.0 34.2,134.0 34.4,127.0 Z'''),
  _Shape('obliquesBack', Muscle.obliques, '''
M30.0,88.0 L36.0,88.0 L42.6,92.0 L42.6,101.6
C40.4,99.8 38.0,99.0 35.6,99.2 C34.0,99.4 32.0,99.8 30.0,100.0 Z'''),
  // The outer hip, above the glutes.
  _Shape('hipBack', Muscle.abductors, '''
M30.0,100.0 C32.0,99.8 34.0,99.4 35.6,99.2 C38.0,99.0 40.4,99.8 42.6,101.6
L45.0,105.0 L40.0,108.0 L35.0,118.0
C33.8,122.0 33.0,126.0 32.6,131.0 L29.0,131.0 Z'''),
  _Shape('lowerBack', Muscle.lowerBack, '''
M50,70.0 L50,104.8 C48.4,104.6 46.6,103.6 45.2,102.0
C43.6,100.2 42.8,97.4 42.6,94.4 C42.6,90.0 43.2,84.0 44.2,78.0
L46.0,70.0 Z'''),
  _Shape('glutes', Muscle.glutes, '''
M49.0,104.2 C45.0,104.6 38.6,107.4 35.0,110.8 C33.2,112.6 32.4,115.6 32.6,118.6
C32.8,122.6 35.0,126.6 39.6,128.2 C43.4,129.4 47.6,128.4 49.8,125.8
L49.8,110.0 C49.6,107.8 49.4,105.8 49.0,104.2 Z'''),
  _Shape('lats', Muscle.lats, '''
M30.6,58.0 L44.0,66.0 L47.4,80.0 C45.8,84.6 44.4,88.6 43.0,91.6
C40.6,94.6 37.2,95.0 34.2,93.6 L30.0,92.0 Z'''),
  _Shape('infraspinatus', Muscle.upperBack, '''
M33.0,49.0 L44.2,56.0 L44.6,68.6 C42.0,69.4 39.4,68.8 37.2,67.4
C35.4,66.2 34.0,64.4 32.8,62.0 L32.0,52.0 Z'''),
  _Shape('teres', Muscle.upperBack, '''
M44.6,68.6 C42.0,69.4 39.4,68.8 37.2,67.4 C35.4,66.2 34.0,64.4 32.8,62.0
L31.4,63.6 C32.4,66.6 34.0,69.2 36.2,71.0 C38.8,72.8 41.8,73.2 44.8,72.4 Z'''),
  // The middle and lower traps, a kite down to the middle of the back.
  _Shape('trapsLower', Muscle.upperBack, '''
M50,51.0 L50,84.0 C48.6,80.0 46.8,75.0 45.2,70.4
C43.6,66.0 42.2,62.0 41.0,58.6 C39.6,55.6 37.2,52.6 34.8,50.0
C34.2,49.0 33.8,47.6 34.0,46.4 C39.6,48.4 45.0,50.4 50,51.0 Z'''),
  _Shape('trapsUpper', Muscle.upperBack, '''
M50,29.6 L50,51.0 C45.0,50.4 39.6,48.4 34.0,46.4
L30.0,46.0 L30.0,40.0 L45.4,30.0 Z'''),
  _Shape('tricepsLong', Muscle.triceps, '''
M30.2,56.0 C28.6,61.0 27.4,66.6 27.0,71.0 C26.8,74.6 27.0,78.0 27.8,81.4
C28.4,82.6 29.6,82.6 30.4,81.4 C31.2,76.0 32.0,68.0 32.6,60.0 Z'''),
  _Shape('tricepsOuter', Muscle.triceps, '''
M27.6,60.0 C26.6,64.0 26.2,68.6 26.2,72.6 C26.2,76.0 25.8,78.8 25.0,80.6
C23.6,81.4 22.2,80.8 21.6,79.4 L21.0,64.0 Z'''),
  _Shape('sideDeltsBack', Muscle.sideDelts, '''
M35.2,46.0 C32.4,44.6 29.4,45.0 27.2,46.8 C24.0,50.6 23.2,56.4 23.6,61.4
C24.0,64.4 25.2,66.8 27.0,68.0 C28.6,64.0 30.6,58.6 32.4,52.0 Z'''),
  _Shape('rearDelts', Muscle.rearDelts, '''
M30.2,43.6 C28.8,49.6 27.8,55.4 27.2,60.6 C26.9,63.4 26.9,65.8 27.0,68.0
C29.0,64.8 31.4,61.6 33.6,58.8 C35.6,56.2 37.4,53.6 38.2,51.0
C36.6,48.6 34.4,46.6 32.0,45.2 C31.4,44.6 30.8,44.0 30.2,43.6 Z'''),
  _Shape('forearmBackOuter', Muscle.forearms, '''
M22.4,82.0 C21.0,84.4 19.6,88.4 18.6,93.4 L17.4,112.0 L19.4,113.0
C20.0,106.0 21.0,99.0 22.4,93.0 C23.0,90.0 23.4,87.0 23.6,84.0 Z'''),
  _Shape('forearmBackInner', Muscle.forearms, '''
M24.2,87.4 C25.6,87.0 26.8,87.6 27.6,88.6 L27.6,96.0
C26.0,102.0 24.0,108.0 22.8,113.6 L21.0,113.6
C21.2,106.0 21.8,98.0 22.8,92.0 C23.2,90.0 23.6,88.4 24.2,87.4 Z'''),
  // The calf: the deep muscle round the bottom, the two heads over it.
  _Shape('soleus', Muscle.calves, '''
M34.4,170.0 C35.0,178.0 36.8,186.0 39.0,192.4 C39.8,194.2 40.6,195.4 41.4,196.0
C42.4,195.4 43.4,194.0 44.6,191.6 C46.0,188.0 47.0,183.0 47.6,177.0
L48.0,170.0 Z'''),
  _Shape('calfOuterHead', Muscle.calves, '''
M41.0,160.0 C40.4,158.4 39.0,157.6 37.6,158.4 C35.6,159.8 34.6,163.0 34.2,167.0
C34.0,172.0 35.2,177.6 37.2,181.6 C38.2,183.4 39.6,184.2 40.6,183.2
C41.2,178.0 41.4,170.0 41.2,163.0 Z'''),
  _Shape('calfInnerHead', Muscle.calves, '''
M41.8,160.0 C42.4,158.4 43.8,157.6 45.2,158.2 C47.0,159.4 47.8,162.6 47.8,167.0
C47.8,173.0 46.8,180.0 44.8,185.4 C43.8,187.6 42.6,188.0 41.8,186.4
C41.6,178.0 41.6,168.0 41.8,160.0 Z'''),
];
