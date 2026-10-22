/// Sending the application: upload every photo still on the phone, then
/// submit. A failed send keeps what was uploaded, so trying again only
/// uploads the rest.
library;

import '../../../../app_state/coach_application_draft.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_application.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';

class ApplicationSender {
  ApplicationSender({required this.repository, required this.draft});

  final CoachingRepository repository;
  final CoachApplicationDraft draft;

  /// Which folder each photo of [app] goes to, by its current path.
  static Map<String, CoachDocFolder> foldersOf(CoachApplication app) {
    final out = <String, CoachDocFolder>{};
    void put(String? path, CoachDocFolder folder) {
      if (path != null && path.isNotEmpty) out[path] = folder;
    }

    put(app.personal.photoPath, CoachDocFolder.photo);
    for (final e in app.education) {
      put(e.path, CoachDocFolder.education);
    }
    for (final c in app.certificates) {
      put(c.path, CoachDocFolder.certificates);
    }
    for (final t in app.testimonials) {
      put(t.imagePath, CoachDocFolder.testimonials);
    }
    for (final t in app.transformations) {
      put(t.beforePath, CoachDocFolder.transformations);
      put(t.afterPath, CoachDocFolder.transformations);
    }
    return out;
  }

  /// Uploads, then submits. Throws [CoachingFailure]; the draft stays.
  /// On success the draft and its photo copies are deleted.
  Future<({ApplicationStatus status, int round})> send({
    required String locale,
    void Function(int done, int total)? onProgress,
  }) async {
    final pending = coachLocalPhotos(draft.application).toSet().toList();
    final folders = foldersOf(draft.application);
    var done = 0;
    onProgress?.call(done, pending.length);
    for (final marker in pending) {
      final bytes = await draft.store.read(marker);
      final type = contentTypeOfLocalPhoto(marker);
      if (bytes == null || bytes.isEmpty) {
        throw const CoachingFailure(CoachingRefusal.fileNotUploaded);
      }
      if (type == null) {
        throw const CoachingFailure(CoachingRefusal.imageInvalid);
      }
      final path = await repository.uploadCoachDoc(
        folders[marker] ?? CoachDocFolder.certificates,
        bytes,
        type,
      );
      draft.update(coachSwapPaths(draft.application, {marker: path}));
      onProgress?.call(++done, pending.length);
    }
    final app = draft.application;
    if (coachLocalPhotos(app).isNotEmpty) {
      throw const CoachingFailure(CoachingRefusal.fileNotUploaded);
    }
    if (app.missingSections().isNotEmpty) {
      throw const CoachingFailure(CoachingRefusal.applicationIncomplete);
    }
    final result = await repository.submitCoachApplication(app, locale: locale);
    draft.reset();
    return result;
  }
}
