/// A picture from the content library, or the drawn placeholder.
///
/// The library's pictures live in the content bucket, readable by a signed-in
/// account (`storage.library.rules`). Turning a path into a URL belongs to the
/// data layer (`app_state/content_images.dart`), which sets [resolver] at
/// start-up; with none set, nobody signed in, no network, or a picture that
/// will not load, this draws [placeholder] and never a broken image.
///
/// Sized: the picture is decoded at the width it is drawn, not at the 1600 px
/// it was stored at, so a list of cards costs what it shows.
library;

import 'package:flutter/material.dart';

class ContentImage extends StatefulWidget {
  const ContentImage({
    super.key,
    required this.path,
    required this.placeholder,
    this.height = 180,
    this.borderRadius = 12,
  });

  /// `content/...`, or null for the placeholder alone.
  final String? path;
  final Widget placeholder;
  final double height;
  final double borderRadius;

  /// Path to URL. Null in tests and in a build with no Firebase.
  static Future<String?> Function(String path)? resolver;

  @override
  State<ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<ContentImage> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ContentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _resolve();
  }

  void _resolve() {
    final path = widget.path;
    final resolver = ContentImage.resolver;
    _url = path == null || resolver == null
        ? null
        : resolver(path).catchError((Object _) => null);
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return widget.placeholder;
    return FutureBuilder<String?>(
      future: url,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) return widget.placeholder;
        return LayoutBuilder(
          builder: (context, constraints) {
            final ratio = MediaQuery.devicePixelRatioOf(context);
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            return ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Image.network(
                resolved,
                height: widget.height,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: (width * ratio).round().clamp(1, 2048),
                excludeFromSemantics: true,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : widget.placeholder,
                errorBuilder: (context, error, stack) => widget.placeholder,
              ),
            );
          },
        );
      },
    );
  }
}
