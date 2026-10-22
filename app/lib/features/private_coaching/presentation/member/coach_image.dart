/// Public coach images (`coach-public/...`) read as bytes from the personal
/// bucket under her sign-in, loaded when first shown and kept for the run.
library;

import 'dart:collection';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app_state/firebase_boot.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/hand/skeleton.dart';

abstract final class CoachImageBytes {
  static const int _keep = 150;
  static const int maxBytes = 4 * 1024 * 1024;
  static final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();

  /// Where bytes come from. Replaced in tests.
  static Future<Uint8List?> Function(String path) lookup = _fromStorage;

  static Future<Uint8List?> _fromStorage(String path) async {
    if (!FirebaseBoot.isReady) return null;
    if (FirebaseAuth.instance.currentUser == null) return null;
    return FirebaseBoot.personalMedia
        .ref(path)
        .getData(maxBytes)
        .timeout(const Duration(seconds: 15));
  }

  /// The 288 px avatar copy beside a coach's `photo.jpg`, or null for any
  /// other path.
  static String? smallPhotoOf(String path) =>
      path.startsWith('coach-public/') && path.endsWith('/photo.jpg')
      ? '${path.substring(0, path.length - 'photo.jpg'.length)}photo_s.jpg'
      : null;

  /// The bytes for [path], or null. Never throws. [own] also allows a coach's
  /// own file under `coach-docs/` (readable only by her), for the manager.
  /// With [fallback], a [path] that is not there (a photo saved before the
  /// small copy existed) is replaced by the fallback file.
  static Future<Uint8List?> load(
    String path, {
    bool own = false,
    String? fallback,
  }) async {
    final allowed =
        path.startsWith('coach-public/') ||
        (own && path.startsWith('coach-docs/'));
    if (!allowed || path.contains('..')) return null;
    final known = _cache.remove(path);
    if (known != null) {
      _cache[path] = known;
      return known;
    }
    try {
      Uint8List? found;
      try {
        found = await lookup(path);
      } on FirebaseException catch (e) {
        if (fallback == null || e.code != 'object-not-found') rethrow;
      }
      if (found == null && fallback != null) {
        found = await lookup(fallback);
      }
      if (found != null) {
        _cache[path] = found;
        if (_cache.length > _keep) _cache.remove(_cache.keys.first);
      }
      return found;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    _cache.clear();
    lookup = _fromStorage;
  }
}

/// One public image: a placeholder while it loads, a quiet icon if it cannot.
class CoachImage extends StatefulWidget {
  const CoachImage({
    super.key,
    required this.path,
    required this.label,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.own = false,
    this.fallbackPath,
  });

  final String path;

  /// Loaded when [path] is not in storage.
  final String? fallbackPath;

  /// The path is the coach's own private file, not a public one.
  final bool own;

  /// What a screen reader says.
  final String label;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Shown instead of the broken-image icon when the image cannot load.
  final Widget? fallback;

  @override
  State<CoachImage> createState() => _CoachImageState();
}

class _CoachImageState extends State<CoachImage> {
  late Future<Uint8List?> _bytes = CoachImageBytes.load(
    widget.path,
    own: widget.own,
    fallback: widget.fallbackPath,
  );

  @override
  void didUpdateWidget(CoachImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.own != widget.own) {
      _bytes = CoachImageBytes.load(
        widget.path,
        own: widget.own,
        fallback: widget.fallbackPath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.label,
      excludeSemantics: true,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Skeleton(
                width: widget.width,
                height: widget.height,
                radius: 8,
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return widget.fallback ??
                  const ColoredBox(
                    color: AppColors.surfaceContainer,
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.outline,
                      ),
                    ),
                  );
            }
            return Image.memory(
              data,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.surfaceContainer,
                child: Center(
                  child: Icon(Icons.image_outlined, color: AppColors.outline),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
