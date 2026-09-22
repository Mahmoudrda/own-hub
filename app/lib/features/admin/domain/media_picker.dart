/// Choosing videos and pictures at Z10 — the seam, and an implementation that
/// refuses honestly.
///
/// **There is no file picker in `pubspec.yaml`**, so no real picking can happen
/// in this repository. `lib/features/signup/domain/id_capture.dart` met exactly
/// this situation and settled the answer, and this file follows it deliberately
/// rather than inventing a second one:
///
/// > "The screens are built against this interface so that adding the SDK is a
/// > dependency change rather than a rewrite — and so that a fake can never be
/// > mistaken for a working camera, because no fake that *works* exists to be
/// > mistaken."
///
/// So [UnavailableMediaPicker] is the only implementation here. It is **not** a
/// stand-in picker: it never returns a file, it carries the *reason* it cannot,
/// and [MediaPicker.isAvailable] lets Z10 render that state on the first frame
/// instead of offering an upload that silently does nothing when it is tapped.
///
/// ## It speaks the vocabulary the console already has
///
/// A picked file is a [MediaFile] — the same type `media_bundle.dart` defines,
/// that [MediaBundle] holds, that Z10 lists and that the importer checks a row's
/// `videoFile` against. A parallel "PickedFile" type would have to be converted
/// somewhere, and the conversion is where a name loses its extension and a row
/// stops matching its upload.
///
/// Nothing here builds a storage path. `storagePathFor()` in `media_bundle.dart`
/// is the only thing in this feature that may name a location, and it refuses
/// anything that escapes `content/`.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'media_bundle.dart';

/// Why files cannot be chosen, in terms a screen can act on.
///
/// [notImplemented] is first because it is today's real answer, and naming it
/// keeps the gap visible in the UI rather than hidden behind a control that
/// appears to work.
enum MediaPickerUnavailableReason {
  /// No file-picker package is wired up yet. The honest state of this build.
  notImplemented,

  /// She declined access to the device's files. Recoverable: she can grant it.
  permissionDenied,
}

/// What came back from asking for files.
///
/// A sealed hierarchy rather than a nullable list, so "nothing was chosen" and
/// "nothing could be chosen" cannot be confused — they are different sentences
/// and only one of them is a defect worth reporting to the owner.
@immutable
sealed class MediaPickResult {
  const MediaPickResult();

  /// Files were chosen. May be more than one: §4 is a **bulk** upload.
  const factory MediaPickResult.picked(List<MediaFile> files) = MediaPicked;

  /// She closed the picker. Nothing is wrong.
  const factory MediaPickResult.cancelled() = MediaPickCancelled;

  /// The picker never opened, and this says why.
  const factory MediaPickResult.unavailable(
    MediaPickerUnavailableReason reason,
  ) = MediaPickUnavailable;
}

class MediaPicked extends MediaPickResult {
  const MediaPicked(this.files);

  final List<MediaFile> files;

  /// Ready for Z10 and for the importer's `uploadedMedia`.
  MediaBundle get bundle => MediaBundle(files);
}

class MediaPickCancelled extends MediaPickResult {
  const MediaPickCancelled();
}

class MediaPickUnavailable extends MediaPickResult {
  const MediaPickUnavailable(this.reason);

  final MediaPickerUnavailableReason reason;
}

/// Opens the device's file picker for videos and pictures.
abstract class MediaPicker {
  /// Whether there is an implementation behind this seam at all.
  ///
  /// Synchronous on purpose: Z10 has to decide what to draw before anybody taps
  /// anything, and a button that is offered and then explains itself only after
  /// being pressed is the "silently does nothing" control this interface exists
  /// to prevent.
  bool get isAvailable;

  Future<MediaPickResult> pickMedia();
}

/// The only implementation that exists today: one that refuses, and says why.
///
/// When a picker package lands, the replacement goes in `data/` and this class
/// stays for tests of the unavailable path.
class UnavailableMediaPicker implements MediaPicker {
  const UnavailableMediaPicker({
    this.reason = MediaPickerUnavailableReason.notImplemented,
  });

  final MediaPickerUnavailableReason reason;

  @override
  bool get isAvailable => false;

  @override
  Future<MediaPickResult> pickMedia() async =>
      MediaPickResult.unavailable(reason);
}
