/// Whether a finger stroke is a tick: a short way down, then a longer way up,
/// drawn left to right or right to left. Generous on purpose: the first stroke
/// may be as short as a twelfth of the tick, and a V counts. A dot, a straight
/// line and a scribble in one place are not ticks.
library;

import 'dart:ui';

abstract final class TickStroke {
  /// Smallest width and height of a tick, in logical pixels.
  static const double minExtent = 36;

  /// The first stroke is at least this share of the tick's height.
  static const double minFirstStroke = 0.08;

  /// The whole path may be at most this many times the two straight legs.
  static const double maxWander = 2.5;

  static bool isTick(List<Offset> points) {
    if (points.length < 6) return false;
    var minX = points.first.dx, maxX = minX;
    var minY = points.first.dy, maxY = minY;
    var vertex = 0;
    var length = 0.0;
    var lengthToVertex = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i > 0) length += (p - points[i - 1]).distance;
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) {
        maxY = p.dy;
        vertex = i;
        lengthToVertex = length;
      }
    }
    final w = maxX - minX, h = maxY - minY;
    if (w < minExtent || h < minExtent) return false;
    if (length <= 0) return false;
    // The bottom of the tick must be neither the first nor the last stretch.
    if (lengthToVertex < length * 0.03 || lengthToVertex > length * 0.92) {
      return false;
    }
    final start = points.first, v = points[vertex], end = points.last;
    final legs = (v - start).distance + (end - v).distance;
    if (length > legs * maxWander) return false;
    // Up the other side: left to right, or right to left.
    final side = end.dx >= v.dx ? 1.0 : -1.0;
    return start.dy < v.dy - h * minFirstStroke &&
        end.dy < v.dy - h * 0.4 &&
        side * (start.dx - v.dx) < w * 0.1 &&
        side * (end.dx - v.dx) > w * 0.2;
  }
}
