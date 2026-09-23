/// Her page — the one draft `B02`–`B09` edit, the one `live` document `B10`,
/// `B11` and the marketplace read, and the saves in between.
///
/// ## Why the editors dropped every edit before this
///
/// Each block editor (`B04` the cover, `B05` the look, `B06` the offers, `B07`
/// the method, `B08` the results, `B13` the media) hands its caller a new
/// payload through `onChanged` and keeps nothing: the screens are pure, and the
/// document belongs to whoever holds it. Nobody held it. This file is the
/// holder — [replacePayload] writes the payload onto the block she opened,
/// [saveDraft] puts the draft through [InMemoryPortfolioRepository], and every
/// B screen redraws from the same object.
///
/// ## Draft and live stay two documents
///
/// `PortfolioRepository` has no `publishLive`, on purpose: only the publish
/// Function writes `live`. [publish] keeps that shape — it runs
/// [PortfolioPublisher], which refuses with every reason at once, and only a
/// queued intent reaches [InMemoryPortfolioRepository.functionPublished]. So a
/// page with an unresolvable offer id or an unvalidated theme is refused here
/// exactly as it would be on a server.
///
/// ## What it still cannot do
///
///   * **Add a photo.** `pubspec.yaml` carries no picker, so `B13` has nothing
///     to add and says so. Every media id on a block therefore stays null, and
///     the publish gate's `mediaNotLive` arm is unreachable rather than faked.
///   * **Show a client's result.** A result belongs to the woman in it and she
///     consents to it; nobody has. `B08` lists none, which is the truth.
///   * **Count a view.** See `portfolio_insights.dart`: there is no storage and
///     no beacon, so `B12` states that nothing is measured instead of drawing
///     zeros.
library;

import '../features/coachbrand/domain/ad_creative.dart';
import '../features/coachbrand/domain/block_registry.dart';
import '../features/coachbrand/domain/coach_media.dart';
import '../features/coachbrand/domain/consent.dart';
import '../features/coachbrand/domain/offers_port.dart';
import '../features/coachbrand/domain/portfolio.dart';
import '../features/coachbrand/domain/portfolio_block.dart';
import '../features/coachbrand/domain/portfolio_insights.dart';
import '../features/coachbrand/domain/portfolio_publisher.dart';
import '../features/coachbrand/domain/portfolio_repository.dart';
import '../features/coachbrand/domain/portfolio_theme.dart';
import '../features/coachbrand/domain/published_portfolio_reader.dart';
import '../features/coachbrand/presentation/canvas_view_model.dart';
import '../features/coachbrand/presentation/media_view.dart';
import '../features/coachbrand/presentation/portfolio_home_view_model.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'coach_profile_state.dart';
import 'coaching_link_state.dart';

class CoachPortfolioState {
  CoachPortfolioState._();

  static final CoachPortfolioState instance = CoachPortfolioState._();

  /// True only in a build that is not going to a store.
  static bool get isTestMode => AppRouter.testingAidsAllowed;

  /// The device this edit is being made on. The single-writer guard travels
  /// onto every save, so a draft edited on two phones can name the other one.
  static const String deviceId = 'device';

  /// "The server": her `draft`, her `live`, and the retained snapshots.
  final PortfolioStore store = PortfolioStore();

  late final InMemoryPortfolioRepository repository =
      InMemoryPortfolioRepository(store: store);

  static const PortfolioPublisher _publisher = PortfolioPublisher();

  /// The one canvas behind every B screen.
  ///
  /// One instance, for the reason every repository is one: a canvas built
  /// inside each route builder would give `B02` her blocks and `B10` an empty
  /// page, for the same portfolio, one tap apart.
  late CanvasViewModel _canvas = _freshCanvas();

  CanvasViewModel get canvas => _canvas;

  /// A canvas on a first draft, with the store holding the same document.
  ///
  /// The store is seeded rather than left null because `allow create` requires
  /// `draftRev == 1` and every save carries `draftRev + 1`: a canvas that
  /// started at 1 and saved at 2 would be refused as a create, forever. A
  /// document that exists and holds no blocks is day one for the coach either
  /// way — `PortfolioLifecycleRules` says so — so `B01` is unaffected.
  CanvasViewModel _freshCanvas() {
    store.draft ??= Portfolio.newDraft();
    return CanvasViewModel(draft: store.draft!, deviceId: deviceId);
  }

  String get coachUid => AppRouter.coachRepository.coachUid;

  Portfolio get draft => _canvas.draft;

  Portfolio? get live => store.live;

  /// The row she tapped on `B02`, so its editor knows which block it is for.
  PortfolioBlock? editing;

  /// `B09`'s creative. Held here because `B09` changes its size and its words,
  /// and a creative rebuilt in the route builder would forget both.
  AdCreative ad = AdCreative(
    adId: 'ad',
    format: AdFormat.feed,
    portfolioVersion: 1,
  );

  /// `B13`'s chip. It narrows a library that is empty, and will narrow one
  /// that is not the day a picker exists.
  MediaFilter mediaFilter = MediaFilter.all;

  void setMediaFilter(MediaFilter filter) {
    mediaFilter = filter;
    AppChanges.bump();
  }

  // ──────────────────────────────────────────────────────── what B01 draws

  PortfolioHomeState get home => PortfolioHomeState.from(
    draft: store.draft,
    live: store.live,
    // `kPortfolioInsightsEnabled` is false, so this is the only state there is.
    insights: PortfolioInsights.deferred,
  );

  /// `B11`'s diff: the live page against the draft. Derived, never stored.
  PortfolioDiff get diff => PortfolioDiffer.between(live: live, draft: draft);

  List<int> get retainedVersions =>
      store.versions.keys.toList()..sort((a, b) => b.compareTo(a));

  /// `B10` and `H02` render the same object through the same widget.
  ///
  /// [page] is the draft for the preview and the live document for a client.
  /// Hidden blocks are absent from both, because both call this.
  PublishedPortfolio resolve({
    required Portfolio page,
    required DateTime now,
  }) => PublishedPortfolio.resolve(
    page: page,
    now: now,
    // Nobody has consented to anything, and there are no verified
    // certificates: both resolve to nothing rather than to a placeholder.
    results: const <String, ClientResult>{},
    offers: offerSummaries,
    verifiedCertIds: const <String>{},
  );

  /// `K04`'s offers, read through the port `B06` is given. Read-only by type.
  List<OfferSummary> get offerSummaries => <OfferSummary>[
    for (final offer in AppRouter.coachRepository.allOffers())
      OfferSummary(
        offerId: offer.id,
        title: offer.name,
        priceMinor: offer.pricePiastres,
        currency: offer.currency,
        lines: offer.lines,
        spotsLeft: _spotsLeft,
        isActive: true,
      ),
  ];

  /// Read from the coach root at render, never copied onto the page. Null when
  /// she has not answered `K04`, and the row then states no figure.
  int? get _spotsLeft {
    final capacity = AppRouter.coachRepository.profileUnbilled.capacity;
    return capacity.isSet ? capacity.spotsLeft : null;
  }

  // ─────────────────────────────────────────────────────────── the edits

  /// Saves the draft through the repository, exactly as `B02` would.
  ///
  /// The revision is bumped once per save by [CanvasViewModel.prepareSave], and
  /// a stale one comes back as [CanvasStatus.conflict] rather than as an
  /// exception — the same two-device guard Firestore's rule applies.
  /// [notify] is false while she is typing: a block editor holds its own
  /// state and reads the payload once, so redrawing the whole app on every
  /// keystroke would buy nothing. The screens underneath are redrawn when she
  /// leaves the editor, through [doneEditing].
  void saveDraft({bool notify = true}) {
    final document = _canvas.prepareSave();
    repository.saveDraft(document, deviceId: deviceId).then(_canvas.recordSave);
    // `saveDraft` applies synchronously and the future only reports it, so the
    // store is already current when this returns.
    if (notify) AppChanges.bump();
  }

  /// Leaving a block editor: everything is already written, and now every
  /// screen behind it redraws from it.
  void doneEditing() => AppChanges.bump();

  /// `B09`: the same creative at another size. Three sizes, one look — the
  /// claim stamp travels with it, because the words did not change.
  void setAdFormat(AdFormat format) {
    ad = ad.inFormat(format);
    AppChanges.bump();
  }

  /// `B03`: adds a starter block of [type] and returns its id.
  String addSection(BlockType type) {
    final id = _canvas.addSection(type);
    saveDraft();
    return id;
  }

  /// Drag to reorder. A permutation of the array, and nothing else.
  void reorder(int from, int to) {
    _canvas.reorder(from, to);
    saveDraft();
  }

  /// The eye. Keeps the payload untouched.
  void setVisible(String blockId, bool visible) {
    _canvas.setVisible(blockId, visible);
    saveDraft();
  }

  /// Removes a block and hands back what is needed to put it back.
  RemovedBlock? deleteBlock(String blockId) {
    final removed = _canvas.deleteBlock(blockId);
    if (removed != null) saveDraft();
    return removed;
  }

  /// The five-second undo. Puts her section back where it was.
  void undoDelete(RemovedBlock removed) {
    _canvas.undoDelete(removed);
    saveDraft();
  }

  /// `B05`: her look, already validated by construction.
  void setTheme(PortfolioTheme theme) {
    _canvas.replaceTheme(theme);
    saveDraft(notify: false);
  }

  /// An editor screen saving its block.
  ///
  /// The block is the row she tapped on `B02`. When she reached the editor from
  /// `B01` or `B14` instead there is no row yet, so the section is added first
  /// — which is what makes the day-one "Start" button build a page rather than
  /// open an editor that saves into nothing.
  void replacePayload(BlockPayload payload) {
    var block = editing;
    if (block == null || draft.blockById(block.id) == null) {
      block = _blockToEditCold(payload.type);
    }
    if (block == null) return;
    _canvas.replacePayload(block.id, payload);
    editing = draft.blockById(block.id);
    saveDraft(notify: false);
  }

  /// Which block an editor opened without a row should write to.
  ///
  /// Her existing section of that type when she has one — a page holds one
  /// cover, so a second "Start with a cover" must reach the cover she already
  /// wrote rather than throw — and a new section when she has none and one may
  /// still be added. Null when the page is full, which leaves her words where
  /// she typed them instead of losing the screen to an exception.
  PortfolioBlock? _blockToEditCold(BlockType type) {
    for (final block in draft.blocks.reversed) {
      if (block.type == type) return block;
    }
    if (!draft.addableTypes.contains(type)) return null;
    // Two statements, not one: `draft` is a fresh object after `addSection`,
    // and Dart evaluates the receiver before the argument — so
    // `draft.blockById(_canvas.addSection(type))` would look the new id up in
    // the portfolio as it was before the section was added, and find nothing.
    final id = _canvas.addSection(type);
    return draft.blockById(id);
  }

  /// The payload the open block carries, or the starter for that type.
  ///
  /// The starter is what `BlockRegistry` hands `B03` when a section is added,
  /// so opening an editor cold and adding a section produce the same empty
  /// block rather than two different ones.
  /// Pure: it never adds a section, because a route builder runs during a
  /// build. [replacePayload] resolves a cold open to the same block, so what
  /// she reads and what she writes are one section either way.
  T payloadFor<T extends BlockPayload>(BlockType type) {
    final open = editing?.payload;
    if (open is T) return open;
    for (final block in draft.blocks.reversed) {
      final payload = block.payload;
      if (payload is T) return payload;
    }
    return BlockRegistry.of(type).starter() as T;
  }

  /// Null when `B08` was opened from `B01` rather than to edit a block — the
  /// screen then lists her results without a block to switch them on in.
  ResultsPayload? get openResultsPayload {
    final payload = editing?.payload;
    return payload is ResultsPayload ? payload : null;
  }

  // ─────────────────────────────────────────────────────────── publishing

  /// Everything the gate reads live at the moment of publishing.
  ///
  /// Live documents, not flags: the gate is handed the offers and reads them,
  /// so "the offer resolves" cannot be asserted by a caller.
  PublishPreconditions get preconditions => PublishPreconditions(
    liveOfferIds: <String>{
      for (final offer in AppRouter.coachRepository.publicOffers()) offer.id,
    },
    // No picker, no consent, no reviewer: three empty maps rather than three
    // fabricated ones.
    media: const <String, CoachMediaItem>{},
    results: const <String, ClientResult>{},
    verifiedCertIds: const <String>{},
  );

  /// Everything the publisher refused last time `B11` tried. Empty until it has.
  List<PublishRefusal> refusals = const <PublishRefusal>[];

  /// `B11`. Queues the intent, and — standing in for the Function the intent
  /// would reach — writes `live` and its immutable snapshot.
  ///
  /// The page is only visible to a client after this, which is what makes
  /// "editing cannot change what a client sees" true rather than promised.
  PublishOutcome publish({DateTime? now}) {
    final at = now ?? DateTime.now();
    final outcome = _publisher.publish(
      coachUid: coachUid,
      draft: draft,
      preconditions: preconditions,
      now: at,
      live: live,
    );
    if (outcome is PublishRefused) {
      refusals = outcome.refusals;
      AppChanges.bump();
      return outcome;
    }
    refusals = const <PublishRefusal>[];
    final published = repository.functionPublished(
      at: at,
      validation: draft.theme.validation,
    );
    // The page is live, so the coach it belongs to is findable. This is the
    // one call that puts a woman in the directory, and it carries her own
    // published document — never a row somebody typed.
    CoachingLinkState.instance.publishCoach(
      profile: CoachProfileState.instance.profile,
      coachUid: coachUid,
      page: published,
      offers: AppRouter.coachRepository.publicOffers(),
      verified: CoachProfileState.instance.isTestCoach,
    );
    AppChanges.bump();
    return outcome;
  }

  /// "Restore version 3" — as a **new** version, never a rewind.
  void restore(int version) {
    final snapshot = store.versions[version];
    if (snapshot == null) return;
    _canvas = CanvasViewModel(
      draft: _publisher.draftForRollback(
        snapshot: snapshot,
        currentDraft: draft,
      ),
      deviceId: deviceId,
    );
    // The rollback draft already carries its own revision, so it is written
    // rather than bumped again.
    repository.saveDraft(_canvas.draft, deviceId: deviceId);
    AppChanges.bump();
  }

  // ──────────────────────────────────────────────────────────────── tests

  /// Back to a coach who has built nothing.
  void reset() {
    store
      ..draft = null
      ..live = null
      ..versions.clear();
    _canvas = _freshCanvas();
    editing = null;
    refusals = const <PublishRefusal>[];
    ad = AdCreative(adId: 'ad', format: AdFormat.feed, portfolioVersion: 1);
    mediaFilter = MediaFilter.all;
  }
}
