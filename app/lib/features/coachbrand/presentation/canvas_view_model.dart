/// B02's canvas, and B03's grid — the block list, computed without a widget.
///
/// Every operation here is an edit to one array. Add, reorder, hide, delete.
/// There is nothing else, which is what "the page is data, not a template"
/// means in practice: the canvas has no concept of a section *type* beyond the
/// registry entry it draws, so a fifteenth type needs no change to this file.
///
/// ## Deleting goes through the undo bus, and nothing confirms
///
/// §2 rule 9. [CanvasViewModel.deleteBlock] removes the block from the local
/// draft, hands the caller a [RemovedBlock] holding the payload and the index
/// it came from, and [CanvasViewModel.undoDelete] puts it back exactly where it
/// was. There is no `confirmDelete`, no `onConfirm` and no parameter a dialog
/// could be passed into.
///
/// The one thing in this whole flow that *does* confirm is consent withdrawal,
/// and it lives in `results_view_model.dart`, not here.
///
/// ## Saving is debounced, and a conflict is a state rather than an error
///
/// A save carries `draftRev + 1`. If the other phone got there first the
/// repository reports [DraftSaveOutcome.staleRevision] and this view model
/// moves to [CanvasStatus.conflict], which B02 draws with two buttons. No
/// silent overwrite, no lost sections, and no exception for the widget to
/// catch.
library;

import 'package:meta/meta.dart';

import '../domain/block_registry.dart';
import '../domain/block_validator.dart';
import '../domain/portfolio.dart';
import '../domain/portfolio_block.dart';
import '../domain/portfolio_theme.dart';

/// What B02's top-right corner is doing.
enum CanvasStatus {
  /// Everything written.
  saved,

  /// Held locally, waiting for signal. **Full opacity, quiet glyph** — this is
  /// a normal state, not an error, and never a spinner.
  queued,

  /// The other phone got there first.
  conflict,

  /// The backend refused for a reason retrying might fix.
  failed,
}

/// A block that has just been deleted, and can be put back.
///
/// Held by the caller for the five-second window. Note what it carries: the
/// block itself, payload and all, and the index it sat at — so undo restores
/// her section to the same place rather than appending it at the bottom.
@immutable
class RemovedBlock {
  const RemovedBlock({required this.block, required this.index});

  final PortfolioBlock block;
  final int index;
}

/// B02 and B03, as one view model over one array.
class CanvasViewModel {
  CanvasViewModel({
    required Portfolio draft,
    required this.deviceId,
    BlockIdSource? ids,
    this.validator = const BlockValidator(),
  }) : _draft = draft,
       _ids = ids ?? SequentialBlockIds.after(draft.blocks.map((b) => b.id));

  Portfolio _draft;
  final BlockIdSource _ids;

  /// K8's single-writer guard. Travels onto every save.
  final String deviceId;

  final BlockValidator validator;

  CanvasStatus status = CanvasStatus.saved;

  /// The draft as it stands, including unsaved edits.
  Portfolio get draft => _draft;

  List<PortfolioBlock> get blocks => _draft.blocks;

  int get blockCount => _draft.blockCount;

  /// The types B03 may still offer — every type not currently capped out.
  List<BlockTypeEntry> get addableTypes =>
      List.unmodifiable(_draft.addableTypes.map(BlockRegistry.of));

  /// Problems across the whole page, for the publish button's state.
  BlockValidation get validation => validator.validateAll(_draft.blocks);

  // ───────────────────────────────────────────────────────────── edits

  /// B03: adds a starter block of [type] and returns its id.
  ///
  /// The id comes from [BlockIdSource], never from the array length, so an id
  /// is not reused after a delete.
  String addSection(BlockType type) {
    final entry = BlockRegistry.of(type);
    final block = PortfolioBlock(id: _ids.next(), payload: entry.starter());
    _draft = _draft.addBlock(block);
    return block.id;
  }

  /// Drag to reorder. A permutation of the array, and nothing else.
  void reorder(int from, int to) => _draft = _draft.reorder(from, to);

  /// The eye. Keeps the payload untouched.
  void setVisible(String blockId, bool visible) =>
      _draft = _draft.setVisible(blockId, visible);

  /// An editor screen saving its block.
  void replacePayload(String blockId, BlockPayload payload) =>
      _draft = _draft.replacePayload(blockId, payload);

  /// B05 saving her look.
  ///
  /// A [PortfolioTheme] cannot exist without a passing validation — the
  /// constructor is private and `validated()` is the only way in — so this
  /// takes the theme and asks nothing about it.
  void replaceTheme(PortfolioTheme next) => _draft = _draft.withTheme(next);

  /// Removes a block and hands back what is needed to put it back.
  ///
  /// Returns null when the id is not on the page, rather than throwing — a
  /// double tap on a row that is already gone is not an error.
  RemovedBlock? deleteBlock(String blockId) {
    final index = _draft.blocks.indexWhere((b) => b.id == blockId);
    if (index < 0) return null;

    final removed = RemovedBlock(block: _draft.blocks[index], index: index);
    _draft = _draft.removeBlock(blockId);
    return removed;
  }

  /// The five-second undo. Puts her section back where it was.
  void undoDelete(RemovedBlock removed) =>
      _draft = _draft.insertBlock(removed.block, removed.index);

  // ───────────────────────────────────────────────────────── the save

  /// Marks the local edits as written, ready to hand to the repository.
  ///
  /// Bumps `draftRev` exactly once per save, which is what the two-device
  /// guard compares. Returns the document to write.
  Portfolio prepareSave() {
    _draft = _draft.savedBy(deviceId);
    return _draft;
  }

  /// Records what the repository said.
  void recordSave(DraftSaveOutcome outcome) {
    status = switch (outcome) {
      DraftSaveOutcome.accepted => CanvasStatus.saved,
      DraftSaveOutcome.staleRevision => CanvasStatus.conflict,
    };
  }

  /// Offline. The edit is hers already; the write is waiting.
  void recordQueued() => status = CanvasStatus.queued;

  /// A backend error a retry might fix.
  void recordFailure() => status = CanvasStatus.failed;

  /// **Take over** or **Keep mine**, after a two-device conflict.
  ///
  /// Neither branch loses a section: take-over adopts the server's copy, and
  /// keep-mine rebases her blocks onto the server's revision so the retry is
  /// accepted rather than refused again for the same reason.
  Portfolio resolveConflict(
    DraftConflictResolution choice, {
    required Portfolio server,
  }) {
    _draft = DraftGuard.resolve(
      choice: choice,
      mine: _draft,
      server: server,
      deviceId: deviceId,
    );
    status = CanvasStatus.saved;
    return _draft;
  }
}
