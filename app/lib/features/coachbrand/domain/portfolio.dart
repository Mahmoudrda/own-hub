/// The portfolio document, its seven states, and the guard that keeps two
/// phones from silently overwriting a page.
///
/// ## Editing cannot change what a client sees
///
/// `draft` and `live` are **different documents**, and the only writer of
/// `live` is the publish Function. That is HANDOFF rule 2 — the one that
/// already governs plans — applied to a page. A coach can rewrite her headline
/// on the bus and the woman reading her page sees version 3 until she taps
/// Publish, because the thing being edited is not the thing being read.
///
/// ## Order is the array index
///
/// There is no `order` field on a block, so a reorder is a permutation of
/// [Portfolio.blocks] and nothing else. Nothing can drift out of sync with it
/// because there is no second copy of the ordering.
///
/// ## The two-device guard
///
/// The draft is one document holding an embedded array, so Firestore cannot
/// merge two edits to it — its documented conflict strategy is last-write-wins,
/// which here means "one phone's sections vanish". [DraftGuard] refuses a save
/// whose `draftRev` is not exactly one past the server's, and B02 offers
/// **Take over** or **Keep mine**. No silent overwrite, no lost sections.
library;

import 'package:meta/meta.dart';

import 'portfolio_block.dart';
import 'portfolio_theme.dart';
import 'theme_validator.dart';

/// Deterministic document ids (spine C1).
abstract final class PortfolioVersionIds {
  static const String draft = 'draft';
  static const String live = 'live';

  /// `v0007`. Zero-padded so the ids sort lexicographically.
  static String snapshot(int version) =>
      'v${version.toString().padLeft(4, '0')}';

  /// The version number inside a snapshot id, or null.
  static int? versionOf(String id) {
    if (!RegExp(r'^v\d{4,}$').hasMatch(id)) return null;
    return int.tryParse(id.substring(1));
  }
}

/// Mints block ids that are never reused within one portfolio.
///
/// G13 §1.2 specifies `nanoid(8)`. Random ids make a test non-deterministic, so
/// the source is an interface: production mints random, tests mint `b1`, `b2`.
/// Either way the portfolio never sees a repeat, which is what the diff and the
/// analytics depend on.
abstract class BlockIdSource {
  String next();
}

/// `b1`, `b2`, `b3`… Monotonic, so an id is not reused after a delete.
class SequentialBlockIds implements BlockIdSource {
  SequentialBlockIds([this._n = 0]);
  int _n;

  @override
  String next() => 'b${++_n}';

  /// Resumes past the highest `bN` in [existing], so reloading a draft and
  /// adding a block does not mint an id that already lived on this page.
  factory SequentialBlockIds.after(Iterable<String> existing) {
    var highest = 0;
    for (final id in existing) {
      if (!id.startsWith('b')) continue;
      final n = int.tryParse(id.substring(1));
      if (n != null && n > highest) highest = n;
    }
    return SequentialBlockIds(highest);
  }
}

/// The seven states of a page (G13 §3.1).
enum PortfolioLifecycle {
  /// No draft, no live. **B14 renders here** — it is a branch of B01, not a
  /// route.
  empty,

  /// A draft exists and has never been published.
  draft,

  /// A publish intent is queued — offline, or in flight.
  queued,

  /// Live, and the draft matches what is live.
  live,

  /// Live, and the draft has diverged. B01 says "3 unpublished changes".
  liveDirty,

  /// She took the page down herself. Not an error, and not a deletion.
  hidden,

  /// Moderation removed it. Editable, not publishable.
  suspended,
}

/// One version of the page.
@immutable
class Portfolio {
  const Portfolio({
    required this.versionId,
    required this.version,
    required this.published,
    required this.theme,
    required this.blocks,
    this.draftRev = 1,
    this.draftDeviceId,
    this.publishedAt,
    this.publishedFrom,
    this.hidden = false,
    this.suspended = false,
    this.validator,
  });

  /// The first draft a coach ever has.
  ///
  /// Empty blocks, the starter theme, `draftRev` 1 — which is exactly what the
  /// `allow create` rule requires. B14 is what this renders as.
  factory Portfolio.newDraft({PortfolioTheme? theme, DateTime? now}) =>
      Portfolio(
        versionId: PortfolioVersionIds.draft,
        version: 1,
        published: false,
        theme: theme ?? PortfolioTheme.starter(now: now),
        blocks: const <PortfolioBlock>[],
      );

  /// `draft`, `live`, or `v0007`.
  final String versionId;

  /// Monotonic, starting at 1. A draft carries the version it *would* publish
  /// as, which is what lets B11's button say "Publish version 4" truthfully.
  final int version;

  /// True only on `live` and on snapshots. Always false on a draft — the
  /// security rule checks this field by name.
  final bool published;

  final PortfolioTheme theme;

  /// Ordered. The order **is** the index.
  final List<PortfolioBlock> blocks;

  /// Increments on every save. The two-device guard.
  final int draftRev;

  /// K8's single-writer guard on the embedded array.
  final String? draftDeviceId;

  final DateTime? publishedAt;

  /// Which `draftRev` this version was published from.
  final int? publishedFrom;

  /// She unpublished the page without deleting it.
  final bool hidden;

  /// Moderation removed it.
  final bool suspended;

  /// Function-written proof the theme passed. Absent on a client-written draft,
  /// which is why the publisher refuses to queue an intent without one being
  /// computable — the client computes it, the server re-computes it, and the
  /// server's answer is the one that counts.
  final ThemeValidation? validator;

  /// Denormalised so B01 can say "6 sections" without parsing the array.
  int get blockCount => blocks.length;

  bool get isEmpty => blocks.isEmpty;

  /// Only the blocks a client would see. Used by preview **and** by the
  /// published renderer, so a hidden block is absent from both by construction.
  List<PortfolioBlock> get visibleBlocks =>
      List.unmodifiable(blocks.where((b) => b.visible));

  /// How many of [type] this page already holds.
  int countOf(BlockType type) => blocks.where((b) => b.type == type).length;

  /// The types B03 may still offer. A capped-out type is absent from the grid.
  List<BlockType> get addableTypes => List.unmodifiable(
    BlockType.values.where((t) => countOf(t) < t.maxPerPortfolio),
  );

  PortfolioBlock? blockById(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  // ───────────────────────────────────────────── edits, all on the draft

  /// Appends. Refuses past [kMaxBlocks] and past a type's own cap.
  Portfolio addBlock(PortfolioBlock block) {
    if (blocks.length >= kMaxBlocks) {
      throw StateError('A page holds at most $kMaxBlocks sections.');
    }
    if (countOf(block.type) >= block.type.maxPerPortfolio) {
      throw StateError(
        'A page holds at most ${block.type.maxPerPortfolio} '
        '${block.type.name} section(s).',
      );
    }
    if (blockById(block.id) != null) {
      throw StateError(
        'Block id ${block.id} is already on this page. Ids are never reused.',
      );
    }
    return _copy(blocks: [...blocks, block]);
  }

  /// Removes. Undone by re-adding the same block within the five-second window
  /// — which is why the caller keeps the removed value rather than a tombstone.
  Portfolio removeBlock(String id) =>
      _copy(blocks: [...blocks.where((b) => b.id != id)]);

  /// Re-inserts [block] at [index]. The undo half of [removeBlock].
  Portfolio insertBlock(PortfolioBlock block, int index) {
    final next = [...blocks];
    next.insert(index.clamp(0, next.length), block);
    return _copy(blocks: next);
  }

  /// A permutation, and nothing else.
  Portfolio reorder(int from, int to) {
    if (from < 0 || from >= blocks.length) {
      throw RangeError.index(from, blocks, 'from');
    }
    final next = [...blocks];
    final moved = next.removeAt(from);
    next.insert(to.clamp(0, next.length), moved);
    return _copy(blocks: next);
  }

  /// The eye. Keeps the payload untouched.
  Portfolio setVisible(String id, bool visible) => _copy(
    blocks: [
      for (final b in blocks) b.id == id ? b.copyWith(visible: visible) : b,
    ],
  );

  /// An editor screen saving its block.
  Portfolio replacePayload(String id, BlockPayload payload) => _copy(
    blocks: [
      for (final b in blocks) b.id == id ? b.copyWith(payload: payload) : b,
    ],
  );

  Portfolio withTheme(PortfolioTheme next) => _copy(theme: next);

  /// One save. Bumps `draftRev` and records which phone wrote it.
  Portfolio savedBy(String deviceId) =>
      _copy(draftRev: draftRev + 1, draftDeviceId: deviceId);

  // ─────────────────────────────────────────────────── publish and hide

  /// The `live` document this draft would become.
  ///
  /// Only the publish Function calls this in production. `published` flips to
  /// true, the version advances, and `publishedFrom` records the `draftRev` it
  /// came from — which is what makes `live`/`liveDirty` decidable without a
  /// diff.
  Portfolio publishedAs({
    required int version,
    required DateTime at,
    required ThemeValidation validation,
  }) => Portfolio(
    versionId: PortfolioVersionIds.live,
    version: version,
    published: true,
    theme: theme,
    blocks: blocks,
    draftRev: draftRev,
    draftDeviceId: draftDeviceId,
    publishedAt: at,
    publishedFrom: draftRev,
    hidden: false,
    suspended: suspended,
    validator: validation,
  );

  /// The immutable `v{NNNN}` snapshot of a published version.
  Portfolio asSnapshot() => Portfolio(
    versionId: PortfolioVersionIds.snapshot(version),
    version: version,
    published: true,
    theme: theme,
    blocks: blocks,
    draftRev: draftRev,
    publishedAt: publishedAt,
    publishedFrom: publishedFrom,
    validator: validator,
  );

  Portfolio withHidden(bool value) => _copy(hidden: value);
  Portfolio withSuspended(bool value) => _copy(suspended: value);

  Portfolio _copy({
    PortfolioTheme? theme,
    List<PortfolioBlock>? blocks,
    int? draftRev,
    String? draftDeviceId,
    bool? hidden,
    bool? suspended,
  }) => Portfolio(
    versionId: versionId,
    version: version,
    published: published,
    theme: theme ?? this.theme,
    blocks: List.unmodifiable(blocks ?? this.blocks),
    draftRev: draftRev ?? this.draftRev,
    draftDeviceId: draftDeviceId ?? this.draftDeviceId,
    publishedAt: publishedAt,
    publishedFrom: publishedFrom,
    hidden: hidden ?? this.hidden,
    suspended: suspended ?? this.suspended,
    validator: validator,
  );

  /// The stored document.
  ///
  /// Note what is **not** here: no consent field, no result content, no offer
  /// price, no certificate name, no diff, and no `streak`. Every one of those
  /// absences is asserted by a test that walks this map recursively.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'published': published,
    'theme': theme.toJson(),
    'blocks': [for (final b in blocks) b.toJson()],
    'blockCount': blockCount,
    'draftRev': draftRev,
    if (draftDeviceId != null) 'draftDeviceId': draftDeviceId,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    if (publishedFrom != null) 'publishedFrom': publishedFrom,
    if (hidden) 'hidden': hidden,
    if (validator != null) 'validator': validator!.toJson(),
  };

  @override
  String toString() =>
      'Portfolio($versionId, v$version, $blockCount blocks, rev $draftRev)';
}

/// Which of the seven states a coach's page is in.
abstract final class PortfolioLifecycleRules {
  /// Resolves the state from the two documents and whether a publish is queued.
  ///
  /// Derived, never stored: there is no `state` field for the resolution to
  /// disagree with.
  static PortfolioLifecycle resolve({
    Portfolio? draft,
    Portfolio? live,
    bool publishQueued = false,
  }) {
    if ((draft?.suspended ?? false) || (live?.suspended ?? false)) {
      return PortfolioLifecycle.suspended;
    }
    if (draft == null && live == null) return PortfolioLifecycle.empty;
    if (publishQueued) return PortfolioLifecycle.queued;

    if (live == null) {
      // A draft with no blocks is still day one, whatever the document says.
      return (draft?.isEmpty ?? true)
          ? PortfolioLifecycle.empty
          : PortfolioLifecycle.draft;
    }

    if (live.hidden) return PortfolioLifecycle.hidden;
    if (draft == null) return PortfolioLifecycle.live;

    return draft.draftRev == live.publishedFrom
        ? PortfolioLifecycle.live
        : PortfolioLifecycle.liveDirty;
  }
}

/// What happened to a save.
enum DraftSaveOutcome {
  /// Written.
  accepted,

  /// The server has a newer draft. B02 offers Take over or Keep mine.
  staleRevision,
}

/// How B02 resolves a two-device conflict.
enum DraftConflictResolution {
  /// Adopt the server's draft, discarding this phone's unsaved edits.
  takeOver,

  /// Write this phone's copy as a new revision on top of the server's.
  keepMine,
}

/// The two-phone guard.
abstract final class DraftGuard {
  /// A save is accepted only when its revision is exactly one past the
  /// server's. Mirrors the rule
  /// `request.resource.data.draftRev == resource.data.draftRev + 1`.
  static DraftSaveOutcome check({
    required int incomingRev,
    required int serverRev,
  }) => incomingRev == serverRev + 1
      ? DraftSaveOutcome.accepted
      : DraftSaveOutcome.staleRevision;

  /// The document to write after she chooses.
  ///
  /// **Take over** returns the server's copy untouched — her local edits are
  /// discarded, which is what she asked for, and nothing is written at all.
  /// **Keep mine** rebases her blocks onto the server's revision so the write
  /// is accepted, rather than retrying a revision that will be refused again.
  static Portfolio resolve({
    required DraftConflictResolution choice,
    required Portfolio mine,
    required Portfolio server,
    required String deviceId,
  }) => switch (choice) {
    DraftConflictResolution.takeOver => server,
    DraftConflictResolution.keepMine => Portfolio(
      versionId: server.versionId,
      version: server.version,
      published: false,
      theme: mine.theme,
      blocks: mine.blocks,
      draftRev: server.draftRev + 1,
      draftDeviceId: deviceId,
      hidden: server.hidden,
      suspended: server.suspended,
    ),
  };
}
