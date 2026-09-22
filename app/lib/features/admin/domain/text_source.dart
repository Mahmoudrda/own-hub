/// Choosing a CSV at Z08 — the same seam as `media_picker.dart`, for text.
///
/// Z08's own note has recorded the gap since it was written: "There is no
/// file-picker package in `pubspec.yaml`, and adding one is not this feature's
/// to do… that keeps the decision — and the platform permissions that come with
/// it — with the owner, and it is reported rather than worked around with a stub
/// that looks finished."
///
/// This is that seam, written down. [UnavailableTextSource] is the only
/// implementation, it returns a *reason*, and [TextSource.isAvailable] lets Z08
/// draw an honest state rather than a "Choose a file" button that does nothing
/// when tapped.
///
/// ## Why text and not bytes
///
/// `parseCsv` takes a [String], and it takes one for a reason its own file
/// records: a leading byte order mark is stripped, CRLF and a lone CR both end a
/// record, and nothing is trimmed. Handing this seam bytes would put the
/// decoding decision somewhere that has none of that reasoning, and Excel's
/// "CSV UTF-8" is exactly the file that punishes it.
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// Why a file cannot be chosen.
enum TextSourceUnavailableReason {
  /// No file-picker package is wired up yet. The honest state of this build.
  notImplemented,

  /// She declined access to the device's files.
  permissionDenied,

  /// A file was chosen and could not be read as text — a spreadsheet saved as
  /// `.xlsx` rather than CSV, most often. Named rather than folded into
  /// "unavailable", because the way out is different: choose a different file.
  unreadable,
}

/// A chosen file: what it is called, and what is in it.
@immutable
class ChosenText {
  const ChosenText({required this.name, required this.text});

  /// The file name as chosen. Z08 shows it back — data, not copy — and it is
  /// what makes "the file I picked" and "the file being checked" visibly the
  /// same file.
  final String name;

  /// The whole file, for `parseCsv`.
  final String text;

  @override
  String toString() => 'ChosenText($name, ${text.length} characters)';
}

/// What came back from asking for a file.
@immutable
sealed class TextPickResult {
  const TextPickResult();

  const factory TextPickResult.picked(ChosenText file) = TextPicked;

  /// She closed the picker. Nothing is wrong.
  const factory TextPickResult.cancelled() = TextPickCancelled;

  const factory TextPickResult.unavailable(TextSourceUnavailableReason reason) =
      TextPickUnavailable;
}

class TextPicked extends TextPickResult {
  const TextPicked(this.file);

  final ChosenText file;
}

class TextPickCancelled extends TextPickResult {
  const TextPickCancelled();
}

class TextPickUnavailable extends TextPickResult {
  const TextPickUnavailable(this.reason);

  final TextSourceUnavailableReason reason;
}

/// Opens the device's file picker for a CSV.
abstract class TextSource {
  /// Whether there is an implementation behind this seam. See the note on
  /// [MediaPicker.isAvailable] in `media_picker.dart` — Z08 has to decide what
  /// to draw before anybody taps anything.
  bool get isAvailable;

  Future<TextPickResult> chooseText();
}

/// The only implementation that exists today: one that refuses, and says why.
class UnavailableTextSource implements TextSource {
  const UnavailableTextSource({
    this.reason = TextSourceUnavailableReason.notImplemented,
  });

  final TextSourceUnavailableReason reason;

  @override
  bool get isAvailable => false;

  @override
  Future<TextPickResult> chooseText() async =>
      TextPickResult.unavailable(reason);
}
