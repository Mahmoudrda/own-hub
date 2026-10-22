/// A portfolio item Own Hub has approved, as members read it from
/// `coaches/{uid}/media/{id}`. The images are re-encoded copies under
/// `coach-public/{uid}/media/`, named by `publicPaths`.
library;

import 'parse.dart';
import 'portfolio_media.dart';

class ApprovedMedia {
  const ApprovedMedia({
    required this.id,
    required this.kind,
    this.weeks,
    this.note = '',
    this.text = '',
    this.from = '',
    this.caption = '',
    this.beforePath,
    this.afterPath,
    this.imagePath,
    this.createdAt,
  });

  final String id;
  final MediaKind kind;
  final int? weeks;
  final String note;
  final String text;
  final String from;
  final String caption;
  final String? beforePath;
  final String? afterPath;
  final String? imagePath;
  final DateTime? createdAt;

  /// Null unless the document is approved and has what its kind shows.
  static ApprovedMedia? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    final kind = MediaKind.fromWire(map?['kind']);
    if (map == null || id.isEmpty || kind == null) return null;
    if (map['status'] != 'approved') return null;
    final paths = asMap(map['publicPaths']) ?? const <String, Object?>{};
    final before = readStringOrNull(paths['before']);
    final after = readStringOrNull(paths['after']);
    final image = readStringOrNull(paths['image']);
    final ok = switch (kind) {
      MediaKind.transformation => before != null && after != null,
      MediaKind.feedback => readString(map['text']).isNotEmpty,
      MediaKind.photo => image != null,
    };
    if (!ok) return null;
    return ApprovedMedia(
      id: id,
      kind: kind,
      weeks: readIntOrNull(map['weeks']),
      note: readString(map['note']),
      text: readString(map['text']),
      from: readString(map['from']),
      caption: readString(map['caption']),
      beforePath: before,
      afterPath: after,
      imagePath: image,
      createdAt: readTime(map['createdAt']),
    );
  }
}
