/// The coach application she is still writing, kept on this phone only.
///
/// Every step saves here, so closing the app or the screen loses nothing. The
/// photos are copies in the app's own documents folder (the picker's cache
/// files can vanish), named in the application by a `local:` marker until the
/// send uploads them. Delete everything, signing in as someone else and a
/// successful send remove the draft and every photo copy; the photos are of
/// other women and of certificates.
///
/// Nothing here touches the network.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../features/private_coaching/domain/coach_application.dart';
import 'app_changes.dart';

const String _localPrefix = 'local:';
const String _photoFolder = 'coach_application_photos';

/// Whether [path] names a photo copy on this phone that is not uploaded yet.
bool isLocalCoachPhoto(String? path) =>
    path != null && path.startsWith(_localPrefix);

/// `image/jpeg` or `image/png` from a marker's ending, or null.
String? contentTypeOfLocalPhoto(String marker) {
  if (marker.endsWith('.jpg')) return 'image/jpeg';
  if (marker.endsWith('.png')) return 'image/png';
  return null;
}

/// Where her photo copies live.
abstract class CoachPhotoStore {
  /// Keeps [bytes] and returns the marker that names them.
  Future<String> save(Uint8List bytes, String contentType);

  Future<Uint8List?> read(String marker);

  Future<void> delete(String marker);

  Future<void> deleteAll();
}

class FileCoachPhotoStore implements CoachPhotoStore {
  const FileCoachPhotoStore();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_photoFolder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The marker is a bare file name; anything else is refused so a crafted
  /// snapshot cannot point outside the folder.
  static bool _safe(String marker) =>
      RegExp(r'^local:[0-9a-f]{24}\.(jpg|png)$').hasMatch(marker);

  @override
  Future<String> save(Uint8List bytes, String contentType) async {
    final ext = contentType == 'image/png' ? 'png' : 'jpg';
    final r = Random.secure();
    final token = List<String>.generate(
      24,
      (_) => '0123456789abcdef'[r.nextInt(16)],
    ).join();
    final file = File('${(await _dir()).path}/$token.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return '$_localPrefix$token.$ext';
  }

  @override
  Future<Uint8List?> read(String marker) async {
    if (!_safe(marker)) return null;
    final file = File(
      '${(await _dir()).path}/${marker.substring(_localPrefix.length)}',
    );
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String marker) async {
    if (!_safe(marker)) return;
    final file = File(
      '${(await _dir()).path}/${marker.substring(_localPrefix.length)}',
    );
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> deleteAll() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_photoFolder');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Every photo path an application names, in the order the steps ask.
List<String> coachPhotoPaths(CoachApplication app) => <String>[
  app.personal.photoPath,
  for (final e in app.education) e.path,
  for (final c in app.certificates) c.path,
  for (final t in app.testimonials) ?t.imagePath,
  for (final t in app.transformations) ...[t.beforePath, t.afterPath],
].where((p) => p.isNotEmpty).toList();

/// The photo copies on this phone that [app] still names.
List<String> coachLocalPhotos(CoachApplication app) => <String>[
  for (final p in coachPhotoPaths(app))
    if (isLocalCoachPhoto(p)) p,
];

/// [app] with each path in [swap] replaced by its value.
CoachApplication coachSwapPaths(
  CoachApplication app,
  Map<String, String> swap,
) {
  String s(String p) => swap[p] ?? p;
  return app.copyWith(
    personal: app.personal.copyWith(photoPath: s(app.personal.photoPath)),
    education: <CoachEducation>[
      for (final e in app.education)
        CoachEducation(
          degree: e.degree,
          institution: e.institution,
          year: e.year,
          path: s(e.path),
        ),
    ],
    certificates: <CoachCertificate>[
      for (final c in app.certificates)
        CoachCertificate(
          id: c.id,
          title: c.title,
          issuer: c.issuer,
          year: c.year,
          path: s(c.path),
          mime: c.mime,
        ),
    ],
    testimonials: <CoachTestimonial>[
      for (final t in app.testimonials)
        CoachTestimonial(
          text: t.text,
          from: t.from,
          source: t.source,
          imagePath: t.imagePath == null ? null : s(t.imagePath!),
        ),
    ],
    transformations: <CoachTransformation>[
      for (final t in app.transformations)
        CoachTransformation(
          beforePath: s(t.beforePath),
          afterPath: s(t.afterPath),
          weeks: t.weeks,
          note: t.note,
          clientConsent: t.clientConsent,
        ),
    ],
  );
}

class CoachApplicationDraft {
  CoachApplicationDraft._();

  static final CoachApplicationDraft instance = CoachApplicationDraft._();

  /// A draft of its own for a test.
  factory CoachApplicationDraft.forTest() => CoachApplicationDraft._();

  /// Replaced in tests, so nothing touches the disk.
  CoachPhotoStore store = const FileCoachPhotoStore();

  static const CoachApplication empty = CoachApplication(payoutOptional: true);

  CoachApplication _application = empty;
  int _step = 1;
  bool _touched = false;

  CoachApplication get application => _application;

  /// The step she was on, counted from 1.
  int get step => _step;

  /// True once she has written or loaded anything.
  bool get touched => _touched;

  /// Keeps [application] (and the [step] she is on, when given).
  void update(CoachApplication application, {int? step}) {
    final before = coachLocalPhotos(_application);
    final kept = coachLocalPhotos(application).toSet();
    for (final marker in before) {
      if (!kept.contains(marker)) _drop(marker);
    }
    _application = application;
    if (step != null) _step = step.clamp(1, 8);
    _touched = true;
    AppChanges.bump();
  }

  /// Starts a draft from the application the server holds, for the sections
  /// the reviewer asked her to change. Its photos are already uploaded.
  void seedFrom(CoachApplication server) {
    reset();
    _application = CoachApplication.fromMap(
      server.toMap(),
      payoutOptional: true,
    );
    _step = 1;
    _touched = true;
    AppChanges.bump();
  }

  void _drop(String marker) {
    store.delete(marker).catchError((Object _) {});
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'step': _step,
    'application': _application.toMap(),
  };

  void restore(Map<String, Object?> saved) {
    _application = CoachApplication.fromMap(
      saved['application'],
      payoutOptional: true,
    );
    final step = saved['step'];
    _step = step is int ? step.clamp(1, 8) : 1;
    _touched = true;
  }

  /// Back to nothing, and every photo copy deleted. Delete everything, a
  /// different woman signing in, a sent application, and tests.
  void reset() {
    _application = empty;
    _step = 1;
    _touched = false;
    store.deleteAll().catchError((Object _) {});
  }
}
