/// B02 — the canvas. The page as an ordered list of rows she owns.
///
/// G13 §1.2: *"Reordering = a permutation of the array and nothing else. Hiding
/// = one boolean. Deleting = removal with a 5-second undo."* This screen is
/// those three operations and nothing more — every one of them is a call into
/// [CanvasViewModel], which is a call into [Portfolio]. There is no switch on
/// [BlockType] here, so a fifteenth type draws a row without this file changing.
///
/// ## Nothing confirms
///
/// §2 rule 9. The eye toggles, the bin removes, and an [AppUndoBar] offers five
/// seconds to put it back **in the place it came from** — [RemovedBlock] carries
/// the index for exactly that reason. There is no dialog on this screen and no
/// parameter one could be passed into.
///
/// ## Strings this screen does not have, and therefore does not draw
///
/// The dictionary has no line for the two-device conflict — neither *"this page
/// was edited on your other phone"* nor a **Take over** label, though
/// `keepMine` exists on its own. A one-sided choice would be worse than none, so
/// [CanvasStatus.conflict] draws no banner and the gap is reported rather than
/// filled with invented English. The same is true of `Hide`, `Show` and
/// `Delete`: those controls are the mockup's glyphs with no tooltip, because a
/// tooltip is copy.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/logging/log_command_bus.dart' show kUndoWindow;
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../domain/block_registry.dart';
import '../domain/portfolio_block.dart';
import 'canvas_view_model.dart';

/// The three tabs across the top of the canvas. B02 is the first of them; the
/// other two are whole screens, which is why this is a navigation row rather
/// than a tab controller.
enum CanvasTab { sections, look, media }

class PortfolioCanvasView extends StatefulWidget {
  const PortfolioCanvasView({
    super.key,
    required this.model,
    this.onBack,
    this.onPreview,
    this.onPublish,
    this.onAddSection,
    this.onEditBlock,
    this.onLook,
    this.onMedia,
    this.onChanged,
  });

  /// The one array, and the only thing this screen edits.
  final CanvasViewModel model;

  final VoidCallback? onBack;
  final VoidCallback? onPreview;
  final VoidCallback? onPublish;
  final VoidCallback? onAddSection;

  /// The editor for one row. The registry says which screen that is.
  final ValueChanged<PortfolioBlock>? onEditBlock;

  final VoidCallback? onLook;
  final VoidCallback? onMedia;

  /// Called after every edit, so the caller can debounce a save. The view model
  /// holds the draft; this hands back the same object rather than a copy.
  final VoidCallback? onChanged;

  @override
  State<PortfolioCanvasView> createState() => _PortfolioCanvasViewState();
}

class _PortfolioCanvasViewState extends State<PortfolioCanvasView> {
  RemovedBlock? _removed;
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _edited() {
    setState(() {});
    widget.onChanged?.call();
  }

  void _delete(String blockId) {
    final removed = widget.model.deleteBlock(blockId);
    if (removed == null) return;

    _undoTimer?.cancel();
    _removed = removed;
    // The offer disappears exactly when it stops being true.
    _undoTimer = Timer(kUndoWindow, () {
      if (!mounted) return;
      setState(() => _removed = null);
    });
    _edited();
  }

  void _undo() {
    final removed = _removed;
    if (removed == null) return;
    widget.model.undoDelete(removed);
    _undoTimer?.cancel();
    _removed = null;
    _edited();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.yourPage,
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: () => openScreen(context, 'B10', widget.onPreview),
            icon: const Icon(Icons.visibility),
            color: AppColors.onSurface,
            tooltip: l10n.preview,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.publish,
              height: 38,
              fontSize: 15,
              onPressed: () => openScreen(context, 'B11', widget.onPublish),
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          Row(
            children: [
              Expanded(
                child: AppChipRow(
                  items: [l10n.sections, l10n.yourLook, l10n.media],
                  selected: <int>{CanvasTab.sections.index},
                  onTap: (i) {
                    switch (CanvasTab.values[i]) {
                      case CanvasTab.sections:
                        break;
                      case CanvasTab.look:
                        openScreen(context, 'B05', widget.onLook);
                      case CanvasTab.media:
                        openScreen(context, 'B13', widget.onMedia);
                    }
                  },
                ),
              ),
              if (_statusPill(l10n, model.status) case final pill?) ...[
                const SizedBox(width: 8),
                pill,
              ],
            ],
          ),
          if (_removed != null)
            AppUndoBar(
              // Her own section's name, never a sentence about it: the row she
              // removed said "How I work", so this says "How I work".
              message:
                  BlockRegistry.of(_removed!.block.type).labelOf(l10n) ?? '',
              undoLabel: l10n.undo,
              onUndo: _undo,
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // `onReorderItem`, not `onReorder`: it hands back the index the
            // block actually lands at, so the permutation this screen performs
            // is the one the array performs.
            onReorderItem: (from, to) {
              model.reorder(from, to);
              _edited();
            },
            children: [
              for (var i = 0; i < model.blocks.length; i++)
                _BlockRow(
                  key: ValueKey(model.blocks[i].id),
                  index: i,
                  block: model.blocks[i],
                  onOpen: () => widget.onEditBlock?.call(model.blocks[i]),
                  onToggleVisible: () {
                    model.setVisible(
                      model.blocks[i].id,
                      !model.blocks[i].visible,
                    );
                    _edited();
                  },
                  onDelete: () => _delete(model.blocks[i].id),
                ),
            ],
          ),
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => openScreen(context, 'B03', widget.onAddSection),
            children: [
              Row(
                children: [
                  const Icon(Icons.add, size: 23, color: AppColors.primaryDim),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      l10n.addASection,
                      style: AppText.titleM.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            l10n.dragToReorderTheEyeHidesA,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// What the top-right corner is doing.
  ///
  /// `conflict` deliberately returns null: the dictionary carries `Keep mine`
  /// and nothing else, and offering one half of a two-way choice would lose a
  /// section rather than save one.
  Widget? _statusPill(AppL10n l10n, CanvasStatus status) => switch (status) {
    CanvasStatus.saved => AppPill(
      l10n.saved,
      background: AppColors.tertiaryContainer,
      foreground: AppColors.tertiary,
    ),
    // Full opacity, a quiet glyph, never a spinner.
    CanvasStatus.queued => AppPill(
      l10n.waitingForSignal,
      background: AppColors.surfaceContainer,
      foreground: AppColors.onSurfaceVariant,
      icon: Icons.schedule,
    ),
    CanvasStatus.failed => AppPill(
      l10n.tryAgain,
      background: AppColors.amberContainer,
      foreground: AppColors.amber,
    ),
    CanvasStatus.conflict => null,
  };
}

/// One row. Drag handle, glyph, name, the eye, the bin.
class _BlockRow extends StatelessWidget {
  const _BlockRow({
    super.key,
    required this.index,
    required this.block,
    required this.onOpen,
    required this.onToggleVisible,
    required this.onDelete,
  });

  final int index;
  final PortfolioBlock block;
  final VoidCallback onOpen;
  final VoidCallback onToggleVisible;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final entry = BlockRegistry.of(block.type);
    final label = entry.labelOf(l10n);
    final subtitle = block.visible ? entry.subtitleOf(l10n) : l10n.hiddenForNow;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      // A hidden section keeps its place but loses its solid edge: the frame
      // goes to dashes, the mark for space waiting to be filled.
      child: HandSurface(
        seed: handSeed(['canvas-row', block.id]),
        fill: AppColors.surfaceLowest,
        frame: AppColors.outline.withValues(alpha: 0.55),
        frameWidth: 1.05,
        dashed: !block.visible,
        radius: 5,
        looseCorner: 14,
        onTap: onOpen,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Opacity(
          opacity: block.visible ? 1 : 0.55,
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(width: 10),
              Icon(entry.icon, size: 22, color: AppColors.primaryDim),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A type whose name has not been minted draws no name
                    // rather than an English one in front of an Arabic
                    // reader. All fourteen are minted today.
                    if (label != null)
                      Text(
                        label,
                        style: AppText.titleS.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // The eye keeps the payload untouched, which is why it is not
              // a bin and why un-hiding restores her words exactly.
              IconButton(
                onPressed: onToggleVisible,
                iconSize: 21,
                color: AppColors.onSurfaceVariant,
                icon: Icon(
                  block.visible ? Icons.visibility : Icons.visibility_off,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                iconSize: 21,
                color: AppColors.onSurfaceVariant,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
