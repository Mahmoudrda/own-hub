import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A painted meal picture, rounded to [size], or [fallback] when [asset] is
/// null or cannot be decoded. Never a broken-image box.
class MealImage extends StatelessWidget {
  const MealImage({
    super.key,
    required this.asset,
    required this.size,
    this.fallback = const SizedBox.shrink(),
    this.semanticLabel,
    this.radius = AppRadius.sm,
  });

  final String? asset;
  final double size;
  final Widget fallback;

  /// The dish's name. Null excludes the picture from the semantics tree, for
  /// where the name is already read beside it.
  final String? semanticLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) return fallback;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        path,
        width: size,
        height: size,
        cacheWidth: pixels,
        cacheHeight: pixels,
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
