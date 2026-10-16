/// A surface on the page: a fill, a drawn frame, and — when it is pressable —
/// a body that gives under the finger.
///
/// Every container in the product is one of these with different settings.
/// Which settings a given kind of container uses is decided in `app_card.dart`
/// and nowhere else, so a card family cannot drift into two.
library;

import 'package:flutter/material.dart';

import '../../theme/hand_tokens.dart';
import 'draw_on.dart';
import 'hand_painters.dart';

class HandSurface extends StatelessWidget {
  const HandSurface({
    super.key,
    required this.child,
    required this.seed,
    this.fill,
    this.pressedFill,
    this.frame,
    this.frameWidth = HandStroke.fine,
    this.level = HandLevel.crafted,
    this.radius = 6,
    this.looseCorner = 16,
    this.offsetOutline,
    this.offset = const Offset(3, 3),
    this.dashed = false,
    this.hatch,
    this.looseAt,
    this.hatchOpacity = 0.22,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.985,
    this.pressable = false,
    this.springPress = false,
    this.semanticsButton = false,
  });

  final Widget child;
  final int seed;
  final Color? fill;

  /// The fill a press settles on. Null keeps [fill] while pressed.
  final Color? pressedFill;
  final Color? frame;
  final double frameWidth;
  final HandLevel level;
  final double radius;
  final double looseCorner;
  final Color? offsetOutline;
  final Offset offset;
  final bool dashed;
  final Color? hatch;

  /// Which corner is loose, when it means something; otherwise the seed's
  /// choice. Named by reading direction, so it turns round in Arabic.
  final HandCorner? looseAt;

  /// How dark [hatch] is drawn.
  final double hatchOpacity;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressScale;

  /// Keep the tap machinery even with no handler — a disabled button is
  /// still a button, and says so.
  final bool pressable;

  /// Press on the spring and shrink to [pressScale] even when an offset
  /// outline is also closing.
  final bool springPress;

  /// Announce this surface as a button to a screen reader.
  final bool semanticsButton;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);

    Widget paint(double pressed) {
      // With an offset outline, pressing moves the body onto it: the button
      // is pushed into the page rather than merely shrinking.
      final shift = offsetOutline == null ? Offset.zero : offset * pressed;
      final dirSign = dir == TextDirection.rtl ? -1.0 : 1.0;
      // Its own layer: AppScaffold scrolls a plain Column, so without this
      // every hand-drawn surface on the page re-inked its outline on every
      // scroll frame and every frame of a press. With it a scroll moves the
      // drawing it already has.
      return RepaintBoundary(
        child: CustomPaint(
          painter: SurfacePainter(
            seed: seed,
            fill: pressedFill == null || fill == null
                ? fill
                : Color.lerp(fill, pressedFill, pressed.clamp(0.0, 1.0)),
            frame: frame,
            frameWidth: frameWidth,
            level: level,
            radius: radius,
            looseCorner: looseCorner,
            offsetOutline: offsetOutline,
            offset: offset,
            bodyShift: shift,
            dashed: dashed,
            hatch: hatch,
            looseAt: looseAt,
            hatchOpacity: hatchOpacity,
            textDirection: dir,
          ),
          child: Transform.translate(
            offset: Offset(shift.dx * dirSign, shift.dy),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    if (!pressable && onTap == null && onLongPress == null) return paint(0);
    final pressableChild = HandPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: offsetOutline == null || springPress ? pressScale : 1,
      spring: springPress,
      borderRadius: BorderRadius.circular(radius),
      builder: (_, pressed) => paint(pressed),
    );
    return semanticsButton
        ? Semantics(button: true, enabled: onTap != null, child: pressableChild)
        : pressableChild;
  }
}
