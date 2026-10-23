/// The square crop for her profile photo: drag to move, pinch or tap the
/// buttons to zoom, and the circle shows what the avatar will show.
///
/// The picture is fitted so its short side fills the square, so there is never
/// an empty edge, and zooming only goes in. [PhotoCropGeometry] holds the
/// arithmetic on its own, so the rectangle handed back is tested without a
/// screen.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_sheet.dart';

/// The most she can zoom in.
const double kProfilePhotoMaxZoom = 4;

/// Maps the pan and zoom of a square viewport onto the picture's pixels.
///
/// The picture is laid out so its short side equals [viewport]; the transform
/// is the one an [InteractiveViewer] keeps, taking that laid-out picture to the
/// viewport.
class PhotoCropGeometry {
  PhotoCropGeometry({required this.image, required this.viewport})
    : assert(image.width > 0 && image.height > 0 && viewport > 0);

  /// The picture's size in its own pixels.
  final Size image;

  /// The side of the square she sees, in logical pixels.
  final double viewport;

  /// Logical pixels per picture pixel when nothing is zoomed.
  double get baseScale => viewport / math.min(image.width, image.height);

  /// The picture as laid out inside the viewer.
  Size get childSize => Size(image.width * baseScale, image.height * baseScale);

  /// The starting view: the middle of the picture, not zoomed.
  Matrix4 centered() => _compose(
    1,
    -(childSize.width - viewport) / 2,
    -(childSize.height - viewport) / 2,
  );

  /// [m], held inside the picture: no zoom out past the fit, no empty edge.
  Matrix4 clamped(Matrix4 m) {
    final scale = m.getMaxScaleOnAxis().clamp(1.0, kProfilePhotoMaxZoom);
    final t = m.getTranslation();
    final tx = t.x.clamp(viewport - childSize.width * scale, 0.0);
    final ty = t.y.clamp(viewport - childSize.height * scale, 0.0);
    return _compose(scale, tx, ty);
  }

  /// [m] zoomed by [factor] about the middle of the square.
  Matrix4 zoomed(Matrix4 m, double factor) {
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final centre = viewport / 2;
    final pointX = (centre - t.x) / scale;
    final pointY = (centre - t.y) / scale;
    final next = (scale * factor).clamp(1.0, kProfilePhotoMaxZoom);
    return clamped(
      _compose(next, centre - next * pointX, centre - next * pointY),
    );
  }

  /// The square she is looking at, in the picture's own pixels.
  ui.Rect cropRect(Matrix4 m) {
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final side = viewport / scale / baseScale;
    final left = (-t.x / scale / baseScale).clamp(0.0, image.width - side);
    final top = (-t.y / scale / baseScale).clamp(0.0, image.height - side);
    return ui.Rect.fromLTWH(left, top, side, side);
  }

  static Matrix4 _compose(double scale, double tx, double ty) =>
      Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
}

/// Shows the crop sheet for [picture] and returns the chosen square in the
/// picture's pixels, or null if she backs out. Throws if the picture cannot be
/// decoded, so the caller can say so instead of showing an empty sheet.
Future<ui.Rect?> showProfilePhotoCrop(
  BuildContext context,
  Uint8List picture,
) async {
  final codec = await ui.instantiateImageCodec(picture);
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  if (!context.mounted) {
    image.dispose();
    return null;
  }
  try {
    return await showAppSheet<ui.Rect>(
      context: context,
      children: [ProfilePhotoCropper(image: image)],
    );
  } finally {
    image.dispose();
  }
}

class ProfilePhotoCropper extends StatefulWidget {
  const ProfilePhotoCropper({super.key, required this.image});

  final ui.Image image;

  @override
  State<ProfilePhotoCropper> createState() => _ProfilePhotoCropperState();
}

class _ProfilePhotoCropperState extends State<ProfilePhotoCropper> {
  final TransformationController _controller = TransformationController();
  PhotoCropGeometry? _geometry;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PhotoCropGeometry _geometryFor(double side) {
    final held = _geometry;
    if (held != null && held.viewport == side) return held;
    final next = PhotoCropGeometry(
      image: Size(
        widget.image.width.toDouble(),
        widget.image.height.toDouble(),
      ),
      viewport: side,
    );
    final first = held == null;
    _geometry = next;
    if (first) {
      // Nothing listens yet, so this is safe during the first build.
      _controller.value = next.centered();
    } else {
      // The screen turned: start again from the middle, a frame later.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.value = next.centered();
      });
    }
    return next;
  }

  void _zoom(double factor) {
    final geometry = _geometry;
    if (geometry == null) return;
    _controller.value = geometry.zoomed(_controller.value, factor);
  }

  void _use() {
    final geometry = _geometry;
    if (geometry == null) return;
    Navigator.of(context).pop(geometry.cropRect(_controller.value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final size = MediaQuery.sizeOf(context);
    final side = math.max(
      160.0,
      math.min(320.0, math.min(size.width - 32, size.height * 0.4)),
    );
    final geometry = _geometryFor(side);
    final child = geometry.childSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.fitYourPhoto, style: AppText.titleL),
        const SizedBox(height: 4),
        Text(
          l10n.dragToMoveItPinchOrUse,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: InteractiveViewer(
                      key: const ValueKey('profile-photo-viewer'),
                      transformationController: _controller,
                      constrained: false,
                      minScale: 1,
                      maxScale: kProfilePhotoMaxZoom,
                      boundaryMargin: EdgeInsets.zero,
                      child: SizedBox(
                        width: child.width,
                        height: child.height,
                        child: RawImage(
                          image: widget.image,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _Circle())),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('profile-photo-zoom-out'),
              tooltip: l10n.zoomOut,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => _zoom(1 / 1.25),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            const SizedBox(width: 16),
            IconButton(
              key: const ValueKey('profile-photo-zoom-in'),
              tooltip: l10n.zoomIn,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => _zoom(1.25),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppButton(
          l10n.useThisPhoto,
          key: const ValueKey('profile-photo-use'),
          onPressed: _use,
        ),
        AppButton(
          l10n.cancel,
          key: const ValueKey('profile-photo-cancel'),
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Dims everything outside the circle the avatar will show.
class _Circle extends CustomPainter {
  const _Circle();

  @override
  void paint(Canvas canvas, Size size) {
    final whole = Path()..addRect(Offset.zero & size);
    final hole = Path()..addOval(Offset.zero & size);
    canvas.drawPath(
      Path.combine(PathOperation.difference, whole, hole),
      Paint()..color = AppColors.ink.withValues(alpha: 0.45),
    );
    canvas.drawOval(
      (Offset.zero & size).deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.surfaceLowest,
    );
  }

  @override
  bool shouldRepaint(_Circle oldDelegate) => false;
}
