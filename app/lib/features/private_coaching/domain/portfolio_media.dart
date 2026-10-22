/// The photos and results a coach shows on her portfolio, as
/// `coaches/{uid}/media/{id}` holds them (written by the server only), and the
/// forms she fills to add one.
///
/// Every item waits for Own Hub's check before members see it. Items that came
/// from her application can also wait for her to confirm her client agreed.
library;

import 'coaching_contract.dart';
import 'parse.dart';

/// Most items one coach may have.
const int kPortfolioMediaMax = 30;

const int kMediaWeeksMin = 1;
const int kMediaWeeksMax = 104;
const int kMediaNoteMax = 300;
const int kMediaCaptionMax = 120;
const int kMediaFromMax = 40;
const int kMediaFeedbackMin = 10;

/// The callables behind the manager.
abstract final class PortfolioMediaCallables {
  static const String add = 'add_portfolio_media';
  static const String remove = 'remove_portfolio_media';
  static const String confirmConsent = 'confirm_portfolio_consent';
}

enum MediaKind {
  transformation('transformation'),
  feedback('feedback'),
  photo('photo');

  const MediaKind(this.wire);

  final String wire;

  static MediaKind? fromWire(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

enum MediaStatus {
  pending('pending'),

  /// From her application: waiting for her to say her client agreed.
  needsConsent('needsConsent'),
  approved('approved'),
  rejected('rejected');

  const MediaStatus(this.wire);

  final String wire;

  static MediaStatus? fromWire(Object? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

class PortfolioMedia {
  const PortfolioMedia({
    required this.id,
    required this.kind,
    this.status = MediaStatus.pending,
    this.reason = '',
    this.weeks,
    this.note = '',
    this.text = '',
    this.from = '',
    this.caption = '',
    this.beforePath,
    this.afterPath,
    this.imagePath,
    this.publicPaths = const <String, String>{},
    this.clientConsentPublic = false,
    this.consentAt,
    this.createdAt,
  });

  final String id;
  final MediaKind kind;
  final MediaStatus status;

  /// Why Own Hub did not approve it, when it did not.
  final String reason;

  /// Her client's consent is still to be confirmed (items from her
  /// application).
  bool get needsConsent => status == MediaStatus.needsConsent;
  final int? weeks;
  final String note;
  final String text;
  final String from;
  final String caption;

  /// Her own uploads under `coach-docs/`, while the item waits for Own Hub's
  /// check. The server clears them when it approves.
  final String? beforePath;
  final String? afterPath;
  final String? imagePath;

  /// Once approved: `before`, `after`, `image` under `coach-public/`.
  final Map<String, String> publicPaths;
  final bool clientConsentPublic;

  /// When she ticked that her client agreed.
  final DateTime? consentAt;
  final DateTime? createdAt;

  /// The file to show for each part: the public copy, else her own upload.
  String? get beforeFile => publicPaths['before'] ?? beforePath;
  String? get afterFile => publicPaths['after'] ?? afterPath;
  String? get imageFile => publicPaths['image'] ?? imagePath;

  /// Null when it has no id or a kind this build does not know.
  static PortfolioMedia? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    final kind = MediaKind.fromWire(map?['kind']);
    if (map == null || id.isEmpty || kind == null) return null;
    return PortfolioMedia(
      id: id,
      kind: kind,
      status: MediaStatus.fromWire(map['status']) ?? MediaStatus.pending,
      reason: readString(map['reason']),
      weeks: readIntOrNull(map['weeks']),
      note: readString(map['note']),
      text: readString(map['text']),
      from: readString(map['from']),
      caption: readString(map['caption']),
      beforePath: readStringOrNull(map['beforePath']),
      afterPath: readStringOrNull(map['afterPath']),
      imagePath: readStringOrNull(map['imagePath']),
      publicPaths: _paths(map['publicPaths']),
      clientConsentPublic: readBool(map['clientConsentPublic']),
      consentAt: readTime(asMap(map['consent'])?['at']),
      createdAt: readTime(map['createdAt']),
    );
  }
}

Map<String, String> _paths(Object? raw) {
  final map = asMap(raw);
  if (map == null) return const <String, String>{};
  return <String, String>{
    for (final key in const ['before', 'after', 'image'])
      if (readStringOrNull(map[key]) != null) key: readString(map[key]),
  };
}

/// A new item, as `add_portfolio_media` takes it. The paths are the ones
/// `uploadCoachDoc` returned.
class MediaDraft {
  const MediaDraft.transformation({
    required String this.beforePath,
    required String this.afterPath,
    required int this.weeks,
    this.note = '',
    required bool this.clientConsentPublic,
  }) : kind = MediaKind.transformation,
       text = null,
       from = null,
       imagePath = null,
       path = null,
       caption = null;

  const MediaDraft.feedback({
    required String this.text,
    required String this.from,
    this.imagePath,
  }) : kind = MediaKind.feedback,
       beforePath = null,
       afterPath = null,
       weeks = null,
       note = '',
       clientConsentPublic = null,
       path = null,
       caption = null;

  const MediaDraft.photo({required String this.path, this.caption = ''})
    : kind = MediaKind.photo,
      beforePath = null,
      afterPath = null,
      weeks = null,
      note = '',
      clientConsentPublic = null,
      text = null,
      from = null,
      imagePath = null;

  final MediaKind kind;
  final String? beforePath;
  final String? afterPath;
  final int? weeks;
  final String note;
  final bool? clientConsentPublic;
  final String? text;
  final String? from;
  final String? imagePath;
  final String? path;
  final String? caption;

  /// The fields that fail, by request key. The server stays the judge.
  List<String> problems() => switch (kind) {
    MediaKind.transformation => <String>[
      if ((beforePath ?? '').isEmpty) 'beforePath',
      if ((afterPath ?? '').isEmpty) 'afterPath',
      if (weeks == null || weeks! < kMediaWeeksMin || weeks! > kMediaWeeksMax)
        'weeks',
      if (note.trim().length > kMediaNoteMax) 'note',
      if (clientConsentPublic != true) 'clientConsentPublic',
    ],
    MediaKind.feedback => <String>[
      if ((text ?? '').trim().length < kMediaFeedbackMin ||
          (text ?? '').trim().length > CoachingLimits.testimonialTextMax)
        'text',
      if ((from ?? '').trim().isEmpty ||
          (from ?? '').trim().length > kMediaFromMax)
        'from',
    ],
    MediaKind.photo => <String>[
      if ((path ?? '').isEmpty) 'path',
      if ((caption ?? '').trim().length > kMediaCaptionMax) 'caption',
    ],
  };

  Json toRequest() => switch (kind) {
    MediaKind.transformation => <String, Object?>{
      'kind': kind.wire,
      'beforePath': beforePath,
      'afterPath': afterPath,
      'weeks': weeks,
      if (note.trim().isNotEmpty) 'note': note.trim(),
      'clientConsentPublic': clientConsentPublic,
    },
    MediaKind.feedback => <String, Object?>{
      'kind': kind.wire,
      'text': text!.trim(),
      'from': from!.trim(),
      if ((imagePath ?? '').isNotEmpty) 'imagePath': imagePath,
    },
    MediaKind.photo => <String, Object?>{
      'kind': kind.wire,
      'path': path,
      if ((caption ?? '').trim().isNotEmpty) 'caption': caption!.trim(),
    },
  };
}
