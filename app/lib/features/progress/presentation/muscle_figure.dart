/// P06's figure: her body from the front and from the back, side by side,
/// each muscle coloured by the sets where it did the work.
///
/// Flat, still and drawn once per change: there is nothing to turn and
/// nothing that moves, so reduced motion changes nothing here. A tap on a
/// muscle chooses it; a tap anywhere else lets it go.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../train/domain/exercise_library.dart';
import 'muscle_map_art.dart';

class MuscleFigure extends StatelessWidget {
  const MuscleFigure({
    super.key,
    required this.scores,
    required this.semanticsLabel,
    required this.frontLabel,
    required this.backLabel,
    this.selected = const {},
    this.onSelect,
    this.maxScale = 1.9,
  });

  /// Each muscle's score, 0 to 1, from the sets where it did the work.
  final Map<Muscle, double> scores;

  /// The muscles drawn with a ring: the one she tapped, or a whole group
  /// she opened from the list.
  final Set<Muscle> selected;

  /// A muscle she tapped, or null for a tap off every muscle or on the one
  /// already chosen.
  final ValueChanged<Muscle?>? onSelect;

  /// What a screen reader hears for the figure: the muscles with their sets.
  final String semanticsLabel;

  /// The words under each view.
  final String frontLabel;
  final String backLabel;

  /// The most logical pixels one art unit takes, so a tablet does not get a
  /// figure taller than the screen.
  final double maxScale;

  /// The figure's painted size for [width].
  static Size sizeFor(double width, {double maxScale = 1.9}) {
    final scale = math.min(width / (2 * MuscleMapArt.width), maxScale);
    return Size(width, MuscleMapArt.height * scale);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = sizeFor(constraints.maxWidth, maxScale: maxScale);
        final layout = MuscleMapLayout(size);
        final viewWidth = MuscleMapArt.width * layout.scale;
        final style = AppText.label.copyWith(color: AppColors.onSurfaceVariant);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: semanticsLabel,
              image: true,
              child: ExcludeSemantics(
                child: GestureDetector(
                  key: const ValueKey('p06-figure'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final muscle = layout.areaAt(details.localPosition)?.muscle;
                    final again =
                        muscle != null &&
                        selected.length == 1 &&
                        selected.contains(muscle);
                    onSelect?.call(again ? null : muscle);
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: MuscleMapPainter(
                        scores: scores,
                        selected: selected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Under the body it names, in either reading direction: the
            // front stays on the left.
            Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (key, label) in [
                  ('p06-front-label', frontLabel),
                  ('p06-back-label', backLabel),
                ])
                  SizedBox(
                    width: viewWidth,
                    child: Text(
                      label,
                      key: ValueKey(key),
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
