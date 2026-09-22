/// What the builder reads, and the one document it writes.
///
/// The asymmetry is the design, exactly as `progress_repository.dart` puts it
/// for weeks and bests: **she writes `portfolio/draft` and nothing else,
/// ever.** `live` and every `v{NNNN}` snapshot are Function-written. There is
/// no `publishLive` method on this interface, so no screen can call one — which
/// is HANDOFF rule 2 enforced by the absence of a function rather than by a
/// check somebody could forget.
///
/// ## Why the fake is strict
///
/// `PHASE1-QA-VERDICT` singles this pattern out: pinning the *fake's*
/// strictness is what stops a case passing in memory and failing on a phone. So
/// [InMemoryPortfolioRepository] refuses everything the security rule refuses —
/// a draft with `published: true`, a `blockCount` that disagrees with the
/// array, more than 40 blocks, and a stale `draftRev`. A test that passes
/// against this fake is a test that would pass against Firestore.
library;

import 'dart:async';

import 'portfolio.dart';
import 'portfolio_block.dart';
import 'theme_validator.dart';

/// Refused because the security rule would refuse it.
class PortfolioWriteRejected implements Exception {
  PortfolioWriteRejected(this.reason);
  final String reason;

  @override
  String toString() => 'PortfolioWriteRejected: $reason';
}

/// `coaches/{coachUid}/portfolio/*`.
abstract class PortfolioRepository {
  /// The document B01 and B02 work on. Null before she has started.
  Future<Portfolio?> draft();

  Stream<Portfolio?> watchDraft();

  /// What clients currently see. Null when she has never published.
  Future<Portfolio?> live();

  Stream<Portfolio?> watchLive();

  /// A retained snapshot, for B11's "restore version 3".
  Future<Portfolio?> version(int version);

  /// Which versions are retained, newest first.
  Future<List<int>> versions();

  /// Saves the draft.
  ///
  /// Returns [DraftSaveOutcome.staleRevision] rather than throwing when the
  /// other phone got there first — a conflict is a state B02 draws, not an
  /// error it reports.
  Future<DraftSaveOutcome> saveDraft(
    Portfolio draft, {
    required String deviceId,
  });

  // There is deliberately no publishLive, no writeVersion and no delete.
  // Publishing is a queued intent the Function acts on; see
  // portfolio_publisher.dart.
}

/// The shared document set — "the server", for an offline test.
class PortfolioStore {
  PortfolioStore({this.draft, this.live, Map<int, Portfolio>? versions})
    : versions = {...?versions};

  Portfolio? draft;
  Portfolio? live;
  final Map<int, Portfolio> versions;
}

/// A fake that refuses what Firestore would refuse.
class InMemoryPortfolioRepository implements PortfolioRepository {
  InMemoryPortfolioRepository({PortfolioStore? store})
    : store = store ?? PortfolioStore();

  final PortfolioStore store;

  final StreamController<Portfolio?> _drafts =
      StreamController<Portfolio?>.broadcast();
  final StreamController<Portfolio?> _lives =
      StreamController<Portfolio?>.broadcast();

  @override
  Future<Portfolio?> draft() async => store.draft;

  @override
  Stream<Portfolio?> watchDraft() async* {
    yield store.draft;
    yield* _drafts.stream;
  }

  @override
  Future<Portfolio?> live() async => store.live;

  @override
  Stream<Portfolio?> watchLive() async* {
    yield store.live;
    yield* _lives.stream;
  }

  @override
  Future<Portfolio?> version(int version) async => store.versions[version];

  @override
  Future<List<int>> versions() async {
    final out = store.versions.keys.toList()..sort((a, b) => b.compareTo(a));
    return List.unmodifiable(out);
  }

  @override
  Future<DraftSaveOutcome> saveDraft(
    Portfolio draft, {
    required String deviceId,
  }) async {
    _assertDraftShape(draft);

    final existing = store.draft;

    if (existing == null) {
      // `allow create` requires draftRev == 1.
      if (draft.draftRev != 1) {
        throw PortfolioWriteRejected(
          'A first draft must have draftRev 1; got ${draft.draftRev}.',
        );
      }
      store.draft = draft;
      _drafts.add(draft);
      return DraftSaveOutcome.accepted;
    }

    final outcome = DraftGuard.check(
      incomingRev: draft.draftRev,
      serverRev: existing.draftRev,
    );
    if (outcome == DraftSaveOutcome.staleRevision) return outcome;

    store.draft = draft;
    _drafts.add(draft);
    return DraftSaveOutcome.accepted;
  }

  /// **The publish Function.** Not on the interface, so no screen can reach it.
  ///
  /// Writes three documents — the new `live`, its immutable `v{NNNN}` snapshot,
  /// and (in production) the coach root mirror — regardless of how many women
  /// are reading. Nothing fans out per viewer.
  Portfolio functionPublished({
    required DateTime at,
    required ThemeValidation validation,
  }) {
    final draft = store.draft;
    if (draft == null) {
      throw PortfolioWriteRejected('There is no draft to publish.');
    }

    final nextVersion = (store.live?.version ?? 0) + 1;
    final published = draft.publishedAs(
      version: nextVersion,
      at: at,
      validation: validation,
    );

    store.live = published;
    store.versions[nextVersion] = published.asSnapshot();
    _lives.add(published);
    return published;
  }

  /// Moderation, or the coach hiding her own page.
  Portfolio? functionSetHidden(bool hidden) {
    final live = store.live;
    if (live == null) return null;
    final next = live.withHidden(hidden);
    store.live = next;
    _lives.add(next);
    return next;
  }

  void _assertDraftShape(Portfolio draft) {
    if (draft.versionId != PortfolioVersionIds.draft) {
      throw PortfolioWriteRejected(
        'A coach writes one document: the draft. Got "${draft.versionId}".',
      );
    }
    if (draft.published) {
      throw PortfolioWriteRejected('published must be false on a draft.');
    }
    if (draft.blocks.length > kMaxBlocks) {
      throw PortfolioWriteRejected(
        'A page holds at most $kMaxBlocks sections; got ${draft.blocks.length}.',
      );
    }
    if (draft.blockCount != draft.blocks.length) {
      throw PortfolioWriteRejected('blockCount must equal blocks.size().');
    }
    if (draft.validator != null) {
      throw PortfolioWriteRejected(
        'validator is server-only; a client may not write it.',
      );
    }
    if (draft.publishedAt != null || draft.publishedFrom != null) {
      throw PortfolioWriteRejected(
        'publishedAt and publishedFrom are server-only.',
      );
    }

    final ids = <String>{};
    for (final block in draft.blocks) {
      if (!ids.add(block.id)) {
        throw PortfolioWriteRejected(
          'Block id ${block.id} appears twice. Ids are never reused.',
        );
      }
    }
  }

  Future<void> dispose() async {
    await _drafts.close();
    await _lives.close();
  }
}
