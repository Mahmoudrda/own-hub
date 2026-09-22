/// Her media library, and the blur that is on before she asks for it.
///
/// §2 rule 6 / C11: **blur on by default, on device, before upload.** G13 owns
/// the *resolution* — whether this particular image needs it — and **adds no
/// second upload path**: the boundary is G8's `MediaUploadGateway.upload()`,
/// which throws when a file arrives unblurred. B13's toggle writes the
/// per-image exception and nothing else.
///
/// The exception is narrow on purpose. A coach may turn blur off for a client
/// in shot **only when that client's own result carries
/// `scope.faceVisible == true`** — which only the client can set, in her own
/// consent sheet. So the coach's toggle cannot reach a face the client did not
/// offer; it can only decline to blur one she did.
library;

import 'package:meta/meta.dart';

import 'consent.dart';

/// At most 40 blocks may reference one media item (G13 §1.1, `usedBy ≤ 40`).
const int kMaxUsedBy = 40;

enum CoachMediaKind { photo, video }

/// G13 §3.3, eight states plus two failure states.
///
/// **Nothing leaves [blurredLocal] without `blurApplied == true`.** A block
/// referencing a `blurredLocal` item renders it from disk, so a page built on a
/// microbus looks finished rather than broken.
enum CoachMediaState {
  local,
  blurring,
  blurredLocal,
  queued,
  uploading,
  live,
  purging,
  purged,

  /// From [live], by moderation.
  rejected,

  /// From [uploading]. Retried, then a rejected row per G8's convention.
  failed;

  /// Whether a published page may reference this item.
  ///
  /// Only `live`. A queued or local item renders in the builder and in preview
  /// from the local file, but publishing one would put a 404 on a stranger's
  /// page.
  bool get isPublishable => this == CoachMediaState.live;

  /// Whether the builder can draw it at all.
  bool get isRenderable => switch (this) {
    CoachMediaState.blurredLocal ||
    CoachMediaState.queued ||
    CoachMediaState.uploading ||
    CoachMediaState.live => true,
    _ => false,
  };
}

/// Thrown when something tries to move an unblurred file toward the network.
class BlurNotAppliedError extends Error {
  BlurNotAppliedError(this.mediaId);

  final String mediaId;

  @override
  String toString() =>
      'BlurNotAppliedError($mediaId): C11 — blur runs on device, before '
      'upload. Nothing leaves blurredLocal without blurApplied.';
}

/// Thrown when a coach deletes a media item a block still points at.
class MediaInUseError extends Error {
  MediaInUseError(this.mediaId, this.usedBy);

  final String mediaId;
  final List<String> usedBy;

  @override
  String toString() =>
      'MediaInUseError($mediaId): still used by ${usedBy.length} block(s). '
      'Remove it from the section first — deleting it underneath a published '
      'page would leave a hole in it.';
}

/// One item in `coaches/{coachUid}/media/{mediaId}`.
@immutable
class CoachMediaItem {
  const CoachMediaItem({
    required this.mediaId,
    required this.kind,
    required this.state,
    required this.createdAt,
    this.blurApplied = true,
    this.facesBlurred = 0,
    this.usedBy = const <String>[],
    this.clientResultId,
    this.width = 0,
    this.height = 0,
    this.bytes = 0,
    this.durationSec,
  });

  final String mediaId;
  final CoachMediaKind kind;
  final CoachMediaState state;
  final DateTime createdAt;

  /// Always true on anything that reaches the network. The security rule says
  /// `blurApplied == true` at the door; this field is what it reads.
  final bool blurApplied;

  final int facesBlurred;

  /// Block ids referencing this item. What makes "delete refuses while in use"
  /// and a withdrawal purge bounded and cheap rather than a collection scan.
  final List<String> usedBy;

  /// Set when this file belongs to a client result. Deleted on withdrawal.
  final String? clientResultId;

  final int width;
  final int height;
  final int bytes;
  final int? durationSec;

  bool get isInUse => usedBy.isNotEmpty;

  CoachMediaItem usedByBlock(String blockId) {
    if (usedBy.contains(blockId)) return this;
    if (usedBy.length >= kMaxUsedBy) {
      throw StateError(
        'A media item may be referenced by at most $kMaxUsedBy blocks.',
      );
    }
    return _copy(usedBy: [...usedBy, blockId]);
  }

  CoachMediaItem releasedByBlock(String blockId) =>
      _copy(usedBy: [...usedBy.where((b) => b != blockId)]);

  /// Moves toward the network, refusing an unblurred file.
  ///
  /// This is a *guard*, not the upload. G13 adds no second upload path; the
  /// real chokepoint is G8's gateway, and this method exists so the same
  /// refusal is testable without one.
  CoachMediaItem queuedForUpload() {
    if (!blurApplied) throw BlurNotAppliedError(mediaId);
    if (state != CoachMediaState.blurredLocal) {
      throw StateError(
        'Only a blurredLocal item may be queued; $mediaId is ${state.name}.',
      );
    }
    return _copy(state: CoachMediaState.queued);
  }

  CoachMediaItem inState(CoachMediaState next) => _copy(state: next);

  CoachMediaItem _copy({
    CoachMediaState? state,
    List<String>? usedBy,
    bool? blurApplied,
  }) => CoachMediaItem(
    mediaId: mediaId,
    kind: kind,
    state: state ?? this.state,
    createdAt: createdAt,
    blurApplied: blurApplied ?? this.blurApplied,
    facesBlurred: facesBlurred,
    usedBy: List.unmodifiable(usedBy ?? this.usedBy),
    clientResultId: clientResultId,
    width: width,
    height: height,
    bytes: bytes,
    durationSec: durationSec,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'state': state.name,
    'blurApplied': blurApplied,
    'facesBlurred': facesBlurred,
    'usedBy': usedBy,
    if (clientResultId != null) 'clientResultId': clientResultId,
    'w': width,
    'h': height,
    'bytes': bytes,
    if (durationSec != null) 'durationSec': durationSec,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'CoachMediaItem($mediaId, ${state.name})';
}

/// Whether this image has to be blurred before it goes anywhere.
abstract final class CoachMediaPolicy {
  /// True unless the client in shot has granted `scope.faceVisible`.
  ///
  /// [clientResult] is null for a picture with no client in it — her own
  /// portrait, a gym, a plate of food — which still defaults to blurred,
  /// because the app cannot tell from the file whether somebody else is in the
  /// frame and the safe answer is the default answer.
  static bool blurRequired({ClientResult? clientResult, DateTime? now}) {
    if (clientResult == null) return true;

    // Not merely "she ticked it once": the consent has to be current. A face
    // shown under a withdrawn or expired grant is exactly the failure C10
    // exists to prevent.
    final at = now ?? DateTime.now();
    if (!ResultVisibility.isPublishable(clientResult, at)) return true;

    return !clientResult.scope.faceVisible;
  }

  /// Refuses a delete while a block still points at the item.
  static void assertDeletable(CoachMediaItem item) {
    if (item.isInUse) throw MediaInUseError(item.mediaId, item.usedBy);
  }
}
