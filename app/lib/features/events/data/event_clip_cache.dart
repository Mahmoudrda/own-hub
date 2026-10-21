/// An event's clip on the phone, fetched the first time she taps it.
///
/// Read through `firebase_storage` from `content/events/{id}/`, written beside
/// its final name as `.part` and renamed only once whole, so a download cut
/// off by a tunnel never plays as a broken clip. Kept in the cache folder:
/// the system may clear it, and the clip is then simply fetched again.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../app_state/firebase_boot.dart';

/// The file for the stored object at [storagePath], or null when it cannot be
/// had now. Never throws.
typedef EventClipFetcher = Future<File?> Function(String storagePath);

Future<File?> fetchEventClip(String storagePath) async {
  try {
    if (!storagePath.startsWith('content/events/') ||
        storagePath.contains('..')) {
      return null;
    }
    final base = await getApplicationCacheDirectory();
    final folder = await Directory('${base.path}/event_clips')
        .create(recursive: true);
    final file = File('${folder.path}/${storagePath.replaceAll('/', '_')}');
    if (await file.exists() && await file.length() > 0) return file;
    if (!FirebaseBoot.isReady) return null;
    final part = File('${file.path}.part');
    await FirebaseBoot.library
        .ref(storagePath)
        .writeToFile(part)
        .timeout(const Duration(seconds: 120));
    await part.rename(file.path);
    return file;
  } catch (_) {
    return null;
  }
}
