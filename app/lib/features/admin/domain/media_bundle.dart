/// Z10 — the media upload, and the only place a storage path is built.
///
/// G16 §4: videos and pictures go to **Cloud Storage, never to Firestore**,
/// under `content/{collection}/{docId}/{file}`, admin write and signed-in read.
/// `firebase/storage.rules` already carries exactly that block.
///
/// > Read is `signedIn()`, not public: this is a women-only product and the
/// > library is behind the gate like everything else.
///
/// ## Why the path function lives here and not on a screen
///
/// D12's hardest constraint is that nothing this console does may reach a
/// woman's data. [storagePathFor] is the only way this feature can name a file,
/// it can only produce a path under `content/`, and it refuses an id or a file
/// name that tries to climb out of it. A screen that wanted to address something
/// else would have to build a string by hand, which the feature's own guard test
/// fails the build for.
///
/// That is the same discipline `SCHEMA-SPINE.md` uses on a daily streak: the
/// rule is kept by the code being unable to express the violation, rather than
/// by everybody remembering it.
///
/// ## Linking is by exact file name
///
/// §4: Z10 "links them by filename to the ids the CSV named". Exact, including
/// the extension and its case — `goblet_squat` and `goblet_squat.mp4` are
/// different files, and matching on a stem would link a row to whichever of two
/// candidates happened to sort first.
library;

import 'package:meta/meta.dart';

import 'content_schema.dart';

/// What kind of thing was uploaded. Z10 filters on it.
enum MediaKind { video, picture }

/// One uploaded file, before it is linked to anything.
@immutable
class MediaFile {
  const MediaFile({
    required this.name,
    required this.bytes,
    required this.kind,
  });

  /// The file name as uploaded. This is what a CSV row is matched against.
  final String name;

  final int bytes;
  final MediaKind kind;

  @override
  String toString() => 'MediaFile($name, $bytes, ${kind.name})';
}

/// A batch of uploaded files.
@immutable
class MediaBundle {
  const MediaBundle(this.files);

  final List<MediaFile> files;

  Set<String> get names => {for (final f in files) f.name};

  bool contains(String fileName) => names.contains(fileName);

  /// Files that no row names.
  ///
  /// Z10's note: the list "leads with files linked to nothing, because those are
  /// the ones that will break a row at validation".
  ///
  /// A name in [referenced] that is not in this bundle is deliberately **not**
  /// reported here. That is a fault on the CSV side — the importer reports it as
  /// a missing media file — and showing it in a list of uploaded files would be
  /// showing staff a file that does not exist.
  List<MediaFile> unlinked(Set<String> referenced) => [
    for (final f in files)
      if (!referenced.contains(f.name)) f,
  ];

  List<MediaFile> ofKind(MediaKind kind) => [
    for (final f in files)
      if (f.kind == kind) f,
  ];

  bool get isEmpty => files.isEmpty;
}

/// Where one file belongs in Cloud Storage. §4.
///
/// Throws [ArgumentError] for anything that could address a location outside the
/// content library. [documentId] comes from a CSV that a person typed, so it is
/// input, and it is checked like input.
String storagePathFor({
  required ContentCollection collection,
  required String documentId,
  required String fileName,
}) {
  _requireSafeSegment(documentId, 'documentId');
  _requireSafeSegment(fileName, 'fileName');

  return '${ContentSchema.of(collection).storagePrefix}/$documentId/$fileName';
}

/// One path segment, and nothing that could turn into two.
void _requireSafeSegment(String value, String label) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, label, 'must not be empty');
  }
  if (value.contains('/') || value.contains(r'\') || value.contains('..')) {
    throw ArgumentError.value(
      value,
      label,
      'must be a single path segment inside the content library',
    );
  }
}
