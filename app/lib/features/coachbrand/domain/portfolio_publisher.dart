/// Publishing, the derived diff, and rollback that never rewinds.
///
/// ## Publishing is the only act that changes what a client sees
///
/// [PortfolioPublisher.publish] is the only producer of a [PublishIntent], and
/// an intent is the only thing that makes the Function write `live`. Editing
/// writes `draft`, which nobody but the coach can read.
///
/// ## The gate checks consent; the page never stores the answer
///
/// This is the distinction the whole flow turns on, so it is worth stating
/// twice. Publishing **refuses** when a `results` block points at an id that is
/// not currently consented — because publishing a page with a hole in it is a
/// worse experience than being told to fix it. But the published page still
/// holds **ids only**, and consent is re-checked at every read. So a client who
/// withdraws an hour after publication disappears from the already-published
/// version, and `publish_test.dart` asserts exactly that sequence.
///
/// If the gate ever *copied* its answer — a `consentedResultIds` field, a
/// `publishedWithConsent` flag — the withdrawal would stop working and every
/// other test would still pass. That is why the JSON scan exists.
///
/// ## Rollback writes a new version
///
/// "Restore version 3" produces version 5 whose content is version 3's.
/// History is append-only: a stranger who bookmarked `v0004.json` still gets
/// version 4, and a coach cannot quietly rewrite what she published last week.
library;

import 'package:meta/meta.dart';

import 'block_validator.dart';
import 'coach_media.dart';
import 'consent.dart';
import 'overlay_floor.dart';
import 'portfolio.dart';
import 'portfolio_block.dart';

/// Why a publish was refused.
enum PublishRefusalReason {
  /// Nothing has been built yet.
  nothingToPublish,

  /// The draft matches what is already live.
  nothingChanged,

  /// The theme carries no current validation stamp.
  themeNotValidated,

  /// A block broke a length, count or layout rule.
  blockInvalid,

  /// `MarketingClaimPolicy` rejected a span.
  claimFailed,

  /// A referenced media item has not finished uploading.
  mediaNotLive,

  /// An `offerIds` entry does not resolve to a live offer.
  offerUnresolved,

  /// A `resultIds` entry is not currently consented.
  resultNotConsented,

  /// A `certIds` entry is not verified.
  certificateNotVerified,

  /// Moderation removed the page.
  suspended,
}

/// One refusal, pointing at the block that caused it.
@immutable
class PublishRefusal {
  const PublishRefusal({
    required this.reason,
    this.blockId,
    this.detail,
    this.problem,
  });

  final PublishRefusalReason reason;

  /// B11 highlights this section. Null for a page-level refusal.
  final String? blockId;

  /// The id that failed to resolve — a media id, an offer id, a result id.
  final String? detail;

  final BlockProblem? problem;

  @override
  String toString() =>
      'PublishRefusal(${reason.name}'
      '${blockId == null ? '' : ', $blockId'}'
      '${detail == null ? '' : ', $detail'})';
}

/// A queued publish. Offline, this is all that exists — **there is never a
/// local `live`**.
///
/// B11's copy says *"it will publish when you're back online"*, not "your page
/// is live". The intent is cancellable while it waits, and the Function
/// re-validates everything on arrival, because the world may have moved: a
/// client can withdraw between the queue and the send.
@immutable
class PublishIntent {
  const PublishIntent({
    required this.coachUid,
    required this.version,
    required this.draftRev,
    required this.queuedAt,
    this.cancelled = false,
  });

  final String coachUid;

  /// The version this will publish as. Keyed on, so a replayed intent collapses
  /// onto the same `v{NNNN}` rather than minting a second one (spine C1).
  final int version;

  /// The revision it was queued at. The Function refuses a draft that has moved
  /// on, so an intent never publishes edits she made after tapping Publish.
  final int draftRev;

  final DateTime queuedAt;
  final bool cancelled;

  /// Deterministic. The outbox deduplicates on this.
  String get dedupeKey => 'publishPortfolio:$coachUid:$version';

  PublishIntent cancel() => PublishIntent(
    coachUid: coachUid,
    version: version,
    draftRev: draftRev,
    queuedAt: queuedAt,
    cancelled: true,
  );

  @override
  String toString() =>
      'PublishIntent($coachUid v$version rev$draftRev'
      '${cancelled ? ', cancelled' : ''})';
}

/// Queued, or refused with reasons.
sealed class PublishOutcome {
  const PublishOutcome();
}

final class PublishQueued extends PublishOutcome {
  const PublishQueued(this.intent);
  final PublishIntent intent;
}

final class PublishRefused extends PublishOutcome {
  const PublishRefused(this.refusals);
  final List<PublishRefusal> refusals;

  @override
  String toString() => 'PublishRefused($refusals)';
}

/// Everything the gate needs, read live at the moment of publishing.
///
/// Note the types: live documents, not flags. A caller cannot pass
/// "consentOk: true" because there is no such parameter — it passes the
/// results and the gate reads them.
@immutable
class PublishPreconditions {
  const PublishPreconditions({
    this.media = const <String, CoachMediaItem>{},
    this.results = const <String, ClientResult>{},
    this.liveOfferIds = const <String>{},
    this.verifiedCertIds = const <String>{},
    this.overlayFloors = const <String, OverlayDecision>{},
  });

  final Map<String, CoachMediaItem> media;

  /// The live result documents. Read here, **not copied anywhere**.
  final Map<String, ClientResult> results;

  final Set<String> liveOfferIds;
  final Set<String> verifiedCertIds;
  final Map<String, OverlayDecision> overlayFloors;
}

/// The only producer of a [PublishIntent].
@immutable
class PortfolioPublisher {
  const PortfolioPublisher({this.validator = const BlockValidator()});

  final BlockValidator validator;

  /// Queues a publish, or refuses with every reason at once.
  ///
  /// Every reason, not the first: a coach who fixes one problem and is told
  /// about the next one taps Publish five times. B11 shows the list.
  PublishOutcome publish({
    required String coachUid,
    required Portfolio draft,
    required PublishPreconditions preconditions,
    required DateTime now,
    Portfolio? live,
  }) {
    final refusals = <PublishRefusal>[];

    if (draft.suspended || (live?.suspended ?? false)) {
      return const PublishRefused(<PublishRefusal>[
        PublishRefusal(reason: PublishRefusalReason.suspended),
      ]);
    }

    if (draft.isEmpty) {
      return const PublishRefused(<PublishRefusal>[
        PublishRefusal(reason: PublishRefusalReason.nothingToPublish),
      ]);
    }

    if (live != null && draft.draftRev == live.publishedFrom) {
      return const PublishRefused(<PublishRefusal>[
        PublishRefusal(reason: PublishRefusalReason.nothingChanged),
      ]);
    }

    // A `PortfolioTheme` cannot exist without a passing validation — the
    // constructor is private and `validated()` is the only way in — so this
    // branch should be unreachable from the app. It is checked anyway because
    // the publish Function runs this same code against a document that arrived
    // over the wire, where "unrepresentable in Dart" buys nothing. The server
    // re-runs the whole validation and is the authority; this is the client
    // half saying the same thing.
    if (!draft.theme.validation.passed) {
      refusals.add(
        const PublishRefusal(reason: PublishRefusalReason.themeNotValidated),
      );
    }

    final blockProblems = validator.validateAll(
      draft.visibleBlocks,
      overlayFloors: preconditions.overlayFloors,
    );
    for (final problem in blockProblems.problems) {
      refusals.add(
        PublishRefusal(
          reason: problem.kind == BlockProblemKind.claim
              ? PublishRefusalReason.claimFailed
              : PublishRefusalReason.blockInvalid,
          blockId: problem.blockId,
          problem: problem,
        ),
      );
    }

    for (final block in draft.visibleBlocks) {
      refusals.addAll(_referenceRefusals(block, preconditions, now));
    }

    if (refusals.isNotEmpty) {
      return PublishRefused(List.unmodifiable(refusals));
    }

    return PublishQueued(
      PublishIntent(
        coachUid: coachUid,
        version: (live?.version ?? 0) + 1,
        draftRev: draft.draftRev,
        queuedAt: now,
      ),
    );
  }

  /// "Restore version 3" — as a **new** version, never a rewind.
  ///
  /// Produces the draft that would publish version 3's content, which then goes
  /// through [publish] like anything else. So a restore is re-validated against
  /// today's world: if a client withdrew since version 3, restoring it is
  /// refused rather than quietly republishing her.
  Portfolio draftForRollback({
    required Portfolio snapshot,
    required Portfolio currentDraft,
  }) => Portfolio(
    versionId: PortfolioVersionIds.draft,
    version: currentDraft.version,
    published: false,
    theme: snapshot.theme,
    blocks: snapshot.blocks,
    draftRev: currentDraft.draftRev + 1,
    draftDeviceId: currentDraft.draftDeviceId,
  );

  List<PublishRefusal> _referenceRefusals(
    PortfolioBlock block,
    PublishPreconditions pre,
    DateTime now,
  ) {
    final out = <PublishRefusal>[];
    final payload = block.payload;

    void requireLiveMedia(String? mediaId) {
      if (mediaId == null || mediaId.isEmpty) return;
      final item = pre.media[mediaId];
      if (item == null || !item.state.isPublishable) {
        out.add(
          PublishRefusal(
            reason: PublishRefusalReason.mediaNotLive,
            blockId: block.id,
            detail: mediaId,
          ),
        );
      }
    }

    switch (payload) {
      case CoverPayload():
        requireLiveMedia(payload.mediaId);
      case AboutPayload():
        requireLiveMedia(payload.portraitMediaId);
      case VideoPayload():
        requireLiveMedia(payload.mediaId);
        requireLiveMedia(payload.posterMediaId);
      case GalleryPayload():
        for (final id in payload.mediaIds) {
          requireLiveMedia(id);
        }
      case FreebiePayload():
        requireLiveMedia(payload.mediaId);

      case OffersPayload():
        for (final id in payload.offerIds) {
          if (!pre.liveOfferIds.contains(id)) {
            out.add(
              PublishRefusal(
                reason: PublishRefusalReason.offerUnresolved,
                blockId: block.id,
                detail: id,
              ),
            );
          }
        }

      case ResultsPayload():
        for (final id in payload.resultIds) {
          // READ, not copy. The answer is used to decide whether to queue; it
          // is not written anywhere, and the published block still holds only
          // the id.
          final result = pre.results[id];
          if (result == null || !ResultVisibility.isPublishable(result, now)) {
            out.add(
              PublishRefusal(
                reason: PublishRefusalReason.resultNotConsented,
                blockId: block.id,
                detail: id,
              ),
            );
          }
        }

      case TestimonialsPayload():
        for (final item in payload.items) {
          final id = item.resultId;
          if (id == null) continue;
          final result = pre.results[id];
          if (result == null || !ResultVisibility.isPublishable(result, now)) {
            out.add(
              PublishRefusal(
                reason: PublishRefusalReason.resultNotConsented,
                blockId: block.id,
                detail: id,
              ),
            );
          }
        }

      case CertificatesPayload():
        for (final id in payload.certIds) {
          if (!pre.verifiedCertIds.contains(id)) {
            out.add(
              PublishRefusal(
                reason: PublishRefusalReason.certificateNotVerified,
                blockId: block.id,
                detail: id,
              ),
            );
          }
        }

      case MethodPayload():
      case FaqPayload():
      case AvailabilityPayload():
      case NumbersPayload():
      case CtaPayload():
        break;
    }

    return out;
  }
}

// ─────────────────────────────────────────────────────────────── the diff

/// What changed about one block.
enum BlockChangeKind { added, removed, replaced, hidden, shown, moved, edited }

@immutable
class BlockChange {
  const BlockChange({
    required this.kind,
    required this.blockId,
    required this.type,
  });

  final BlockChangeKind kind;
  final String blockId;
  final BlockType type;

  @override
  String toString() => 'BlockChange(${kind.name}, $blockId, ${type.name})';
}

/// B11's "What changed since version 3".
///
/// **Derived, never stored.** There is no `diff` field on any document, which
/// is why `P0-PORT-04` can say "is not stored anywhere" and a grep proves it.
@immutable
class PortfolioDiff {
  const PortfolioDiff({required this.changes, required this.themeChanged});

  final List<BlockChange> changes;
  final bool themeChanged;

  bool get isEmpty => changes.isEmpty && !themeChanged;

  /// How many unpublished changes B01 reports.
  int get count => changes.length + (themeChanged ? 1 : 0);

  @override
  String toString() => 'PortfolioDiff($count changes)';
}

abstract final class PortfolioDiffer {
  /// [live] versus [draft]. A null [live] means everything is an addition.
  static PortfolioDiff between({Portfolio? live, required Portfolio draft}) {
    final changes = <BlockChange>[];

    if (live == null) {
      for (final block in draft.blocks) {
        changes.add(
          BlockChange(
            kind: BlockChangeKind.added,
            blockId: block.id,
            type: block.type,
          ),
        );
      }
      return PortfolioDiff(
        changes: List.unmodifiable(changes),
        themeChanged: false,
      );
    }

    final liveById = <String, PortfolioBlock>{
      for (final b in live.blocks) b.id: b,
    };
    final draftById = <String, PortfolioBlock>{
      for (final b in draft.blocks) b.id: b,
    };

    for (final block in draft.blocks) {
      final before = liveById[block.id];
      if (before == null) {
        changes.add(
          BlockChange(
            kind: BlockChangeKind.added,
            blockId: block.id,
            type: block.type,
          ),
        );
        continue;
      }

      if (before.visible != block.visible) {
        changes.add(
          BlockChange(
            kind: block.visible
                ? BlockChangeKind.shown
                : BlockChangeKind.hidden,
            blockId: block.id,
            type: block.type,
          ),
        );
      }

      if (before.type != block.type) {
        changes.add(
          BlockChange(
            kind: BlockChangeKind.replaced,
            blockId: block.id,
            type: block.type,
          ),
        );
      } else if (!_sameJson(before.payload.toJson(), block.payload.toJson())) {
        changes.add(
          BlockChange(
            kind: BlockChangeKind.edited,
            blockId: block.id,
            type: block.type,
          ),
        );
      }
    }

    for (final block in live.blocks) {
      if (draftById.containsKey(block.id)) continue;
      changes.add(
        BlockChange(
          kind: BlockChangeKind.removed,
          blockId: block.id,
          type: block.type,
        ),
      );
    }

    // Order, computed over the ids both versions share, so an addition does not
    // report every block after it as moved.
    final common = draft.blocks
        .map((b) => b.id)
        .where(liveById.containsKey)
        .toList();
    final commonBefore = live.blocks
        .map((b) => b.id)
        .where(draftById.containsKey)
        .toList();
    for (var i = 0; i < common.length; i++) {
      if (i >= commonBefore.length || common[i] == commonBefore[i]) continue;
      final block = draftById[common[i]]!;
      changes.add(
        BlockChange(
          kind: BlockChangeKind.moved,
          blockId: block.id,
          type: block.type,
        ),
      );
    }

    return PortfolioDiff(
      changes: List.unmodifiable(changes),
      themeChanged: !_sameJson(live.theme.toJson(), draft.theme.toJson()),
    );
  }

  static bool _sameJson(Map<String, Object?> a, Map<String, Object?> b) =>
      a.toString() == b.toString();
}
