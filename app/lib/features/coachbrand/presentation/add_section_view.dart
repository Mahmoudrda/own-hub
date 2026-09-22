/// B03 — add a section. Twelve tiles today, fourteen types in the registry.
///
/// G13 §1.3: *"B03's grid shows 12 tiles because `cover` and `about` are
/// already on the starter page; the registry holds all 14 and B03 lists every
/// type not currently capped out."* Twelve is therefore an **outcome**, not a
/// list — this file has no list of its own and no switch on [BlockType], which
/// is what makes a fifteenth type a registry entry plus a widget.
///
/// A type whose name has not been minted is absent from the grid, because
/// [BlockRegistry.tilesFor] drops it. That is a visible gap rather than an
/// English word in front of an Arabic reader, and it is the registry's decision
/// rather than this screen's.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart' show AppCardVariant, handCardLook;
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/block_registry.dart';
import '../domain/portfolio_block.dart';

class AddSectionView extends StatelessWidget {
  const AddSectionView({
    super.key,
    required this.addableTypes,
    this.onAdd,
    this.onBack,
  });

  /// Every type not currently capped out — [Portfolio.addableTypes]. Passed in
  /// rather than computed, so the cap lives in the domain and this screen only
  /// draws what it is given.
  final List<BlockType> addableTypes;

  final ValueChanged<BlockType>? onAdd;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tiles = BlockRegistry.tilesFor(addableTypes, l10n);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.yourPage,
        onBack: onBack,
        leadingIcon: Icons.close,
      ),
      body: AppScaffold(
        children: [
          Text(
            l10n.addASection,
            style: AppText.titleL.copyWith(color: AppColors.onSurface),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            // Taller than it is wide, so a long Arabic label wraps inside the
            // tile instead of clipping. P2-TXT-B03 asks for reflow, not
            // truncation.
            childAspectRatio: 0.92,
            children: [
              for (final entry in tiles)
                _TypeTile(entry: entry, onTap: () => onAdd?.call(entry.type)),
            ],
          ),
          Text(
            l10n.pickAsManyAsYouWantIn,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.entry, required this.onTap});

  final BlockTypeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Non-null by construction: `tilesFor` already dropped the unminted ones.
    final label = entry.labelOf(l10n) ?? '';

    final look = handCardLook(AppCardVariant.outlined);

    // A pencil-framed slip per type, each cut with its own loose corner so the
    // grid reads as twelve pieces of paper rather than one template repeated.
    return HandSurface(
      seed: handSeed(['add-section', entry.type.name]),
      fill: look.fill,
      frame: look.frame,
      frameWidth: look.frameWidth,
      level: look.level,
      radius: 5,
      looseCorner: 14,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.icon, size: 21, color: AppColors.primaryDim),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              label,
              style: AppText.label.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
