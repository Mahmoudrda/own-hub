/// Content library paths, turned into URLs a picture can be loaded from.
///
/// Read only for a signed-in account, which is all `storage.library.rules`
/// lets read `content/`. Each URL is asked for once a run and kept in memory;
/// the pictures themselves are kept by Flutter's image cache while the app
/// runs. Offline, signed out or refused, the answer is null and every caller
/// draws its placeholder.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';

import 'firebase_boot.dart';

abstract final class ContentImages {
  static final Map<String, String> _urls = {};

  /// Where a URL comes from. Replaced in tests.
  static Future<String?> Function(String path) lookup = _storageUrl;

  static Future<String?> _storageUrl(String path) async {
    if (!FirebaseBoot.isReady) return null;
    if (FirebaseAuth.instance.currentUser == null) return null;
    return FirebaseBoot.library
        .ref(path)
        .getDownloadURL()
        .timeout(const Duration(seconds: 8));
  }

  /// The URL for [path] under `content/`, or null. Never throws.
  static Future<String?> url(String path) async {
    if (!path.startsWith('content/') || path.contains('..')) return null;
    final known = _urls[path];
    if (known != null) return known;
    try {
      final found = await lookup(path);
      if (found != null) _urls[path] = found;
      return found;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    _urls.clear();
    lookup = _storageUrl;
  }
}
