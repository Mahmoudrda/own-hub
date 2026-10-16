/// The week as segments, matching `segs()` in `6-v2/src/kit.mjs`.
///
/// One segment per session the week asks for, filled for each one logged. This
/// is the product's only progress indicator, and it is deliberately a **week**:
/// §2 rule 3 is weeks, not days, so there is no seven-segment variant of this
/// widget and [total] is a session target rather than a number of days.
///
/// An unfilled segment is the same neutral outline as an empty field. It is
/// never red, and there is no "missed" styling to reach for — D5 puts the
/// consequence of skipping at the week level, and never as a daily failure mark.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';
import 'hand/hand_geometry.dart' show wobblyLine;
import 'hand/hand_painters.dart' show paintInk, paintPencil;

/// How the week is drawn.
enum WeekStyle {
  /// A row of short strokes: sage nib for a logged session, a pencil line for
  /// one still to come. The compact form, for cards and lists.
  bar,

  /// One hand-drawn circle per session: a sage tick inside each one logged,
  /// the next one ringed in rose ink, the rest waiting in pencil with their
  /// number. The form Today opens with.
  marks,
}

class AppWeekSegments extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'AppWeekSegments';

  const AppWeekSegments({
    super.key,
    required this.total,
    required this.filled,
    this.height = 10,
    this.color = AppColors.tertiarySoft,
    this.style = WeekStyle.bar,
    this.lead = Duration.zero,
    this.popIndex,
  });

  /// Sessions the week asks for.
  final int total;

  /// Sessions logged so far.
  final int filled;

  final double height;
  final Color color;
  final WeekStyle style;

  /// How long the marks wait before they are drawn, for a screen that brings
  /// the week in at a point in its own sequence.
  final Duration lead;

  /// The mark just earned, which arrives with a spring instead of simply
  /// being there. Null when nothing was earned just now.
  final int? popIndex;

  @override
  Widget build(BuildContext context) {
    if (style == WeekStyle.marks) return _marks(context);

    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: height,
              child: CustomPaint(
                painter: _SegmentPainter(
                  done: i < filled,
                  seed: i * 31 + total,
                  thickness: height,
                  color: color,
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _marks(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // As large as reads well, and never so large the week wraps.
        final room = constraints.maxWidth.isFinite ? constraints.maxWidth : 360;
        final size = math.min(
          40.0,
          (room - (total - 1) * 8) / math.max(total, 1),
        );
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < total; i++)
              _Mark(
                index: i,
                size: size,
                lead: lead,
                pop: i == popIndex,
                state: i < filled
                    ? _MarkState.done
                    : i == filled
                    ? _MarkState.next
                    : _MarkState.waiting,
              ),
          ],
        );
      },
    );
  }
}

enum _MarkState { done, next, waiting }

class _Mark extends StatelessWidget {
  const _Mark({
    required this.index,
    required this.size,
    required this.state,
    this.lead = Duration.zero,
    this.pop = false,
  });

  final bool pop;
  final int index;
  final double size;
  final _MarkState state;
  final Duration lead;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    final ring = switch (state) {
      _MarkState.next => DrawOn(
        delay: lead + HandTiming.short,
        builder: (context, p) => CustomPaint(
          size: Size.square(size),
          painter: LoopPainter(
            seed: 900 + index,
            color: HandInk.ink,
            width: HandStroke.felt,
            level: HandLevel.signature,
            progress: p,
            inflate: const EdgeInsets.all(1),
            textDirection: dir,
          ),
        ),
      ),
      _ => CustomPaint(
        size: Size.square(size),
        painter: LoopPainter(
          seed: 700 + index,
          color: AppColors.outline.withValues(alpha: 0.8),
          width: 1.0,
          level: HandLevel.crafted,
          inflate: const EdgeInsets.all(-2),
          textDirection: dir,
        ),
      ),
    };

    final mark = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring,
          if (state == _MarkState.done)
            HandTick(
              size: size * 0.5,
              seed: index + 1,
              drawOn: true,
              delay: lead + Duration(milliseconds: 90 * index),
            )
          else
            HandFigure(
              '${index + 1}',
              size: size * 0.42,
              color: state == _MarkState.next
                  ? HandInk.ink
                  : AppColors.onSurfaceVariant,
            ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: pop ? SpringPop(delay: lead, child: mark) : mark,
    );
  }
}

class _SegmentPainter extends CustomPainter {
  _SegmentPainter({
    required this.done,
    required this.seed,
    required this.thickness,
    required this.color,
    required this.textDirection,
  });

  final bool done;
  final int seed;
  final double thickness;
  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final rtl = textDirection == TextDirection.rtl;
    final inset = done ? thickness * 0.35 : 1.0;
    final a = Offset(rtl ? size.width - inset : inset, y);
    final b = Offset(rtl ? inset : size.width - inset, y);
    final pts = wobblyLine(a, b, seed: seed, wobble: 0.5, steps: 10);
    if (done) {
      paintInk(
        canvas,
        pts,
        color: color,
        width: thickness,
        taper: 0.15,
        seed: seed,
      );
    } else {
      // Waiting, not missed: a pencil line, the same neutral as an empty field.
      paintPencil(
        canvas,
        pts,
        color: AppColors.outline,
        width: 1.1,
        seed: seed,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.done != done ||
      old.seed != seed ||
      old.thickness != thickness ||
      old.color != color ||
      old.textDirection != textDirection;
}
