/// B11 — publish. What changed, what is kept, and what rollback actually does.
///
/// `P0-PORT-04`: *"The diff is computed from v3 versus the draft and is not
/// stored anywhere. v4 is immutable, v3 is retained, and restoring writes a NEW
/// version rather than rewinding history."*
///
/// [PortfolioDiffer.between] is the diff and there is no `diff` field for it to
/// disagree with. [PortfolioPublisher.draftForRollback] is the restore, and it
/// produces a **draft** — which then goes through `publish()` like anything
/// else, so restoring a version that shows a woman who has since withdrawn is
/// refused rather than quietly republishing her.
///
/// ## Refusals are a list, not the first one
///
/// A coach who fixes one problem and is told about the next taps Publish five
/// times. [PortfolioPublisher.publish] returns every reason at once and this
/// screen draws them all, naming the section each belongs to.
///
/// ## Strings this screen does not have
///
/// Four of the seven change verbs are minted — `added`, `replaced`, `hidden`,
/// and nothing for `removed`, `shown`, `moved` or `edited`. A row whose verb is
/// missing draws the section's name alone, which is true (this section differs)
/// rather than invented. The headings *"What changed since version 3"*,
/// *"Version 3 is kept"* and *"Publish version 4"* all bake the prototype's
/// version number into the sentence, so none of them is used: the button says
/// `Publish`, and the versions she can go back to are drawn from her own
/// history. Nothing states a figure that is not hers.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/block_registry.dart';
import '../domain/block_validator.dart';
import '../domain/portfolio_publisher.dart';
import '../../../ui/hand/hand_seed_name.dart';

class PublishView extends StatelessWidget {
  const PublishView({
    super.key,
    required this.diff,
    this.refusals = const <PublishRefusal>[],
    this.retainedVersions = const <int>[],
    this.online = true,
    this.onPublish,
    this.onKeepDraft,
    this.onRestore,
    this.onClose,
  });

  /// Derived, never stored.
  final PortfolioDiff diff;

  /// Everything [PortfolioPublisher.publish] refused, or empty.
  final List<PublishRefusal> refusals;

  /// The versions she can go back to, newest first. Her own history.
  final List<int> retainedVersions;

  /// Offline, a publish is a **queued intent** and the copy does not claim the
  /// page is live.
  final bool online;

  final VoidCallback? onPublish;
  final VoidCallback? onKeepDraft;
  final ValueChanged<int>? onRestore;
  final VoidCallback? onClose;

  bool get _canPublish => refusals.isEmpty && !diff.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.publish,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      body: AppScaffold(
        footer: [
          AppButton(
            l10n.publish,
            height: 56,
            icon: Icons.rocket_launch,
            onPressed: _canPublish ? onPublish : null,
          ),
          AppButton(
            l10n.keepAsADraft,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: onKeepDraft,
          ),
        ],
        children: [
          if (diff.changes.isNotEmpty)
            AppCard(
              gap: 4,
              children: [
                for (final change in diff.changes) _ChangeRow(change: change),
                if (diff.themeChanged)
                  // Her look changed. The row names the screen it came from,
                  // which is a section name she already knows.
                  Text(
                    l10n.yourLook,
                    style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                  ),
              ],
            ),
          if (refusals.isNotEmpty)
            AppCard(
              variant: AppCardVariant.error,
              gap: 6,
              children: [
                for (final refusal in refusals) _RefusalRow(refusal: refusal),
              ],
            ),
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    online ? Icons.schedule : Icons.cloud_off,
                    size: 21,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Offline this says it is waiting, never that the
                          // page is live: the intent is queued, and G2's O05
                          // has the same shape.
                          online
                              ? l10n.liveWithinAMinute
                              : l10n.waitingForSignal,
                          style: AppText.titleM.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          online
                              ? l10n.womenAlreadyReadingItSeeTheOld
                              : l10n.savedItWillSyncWhenYouHave,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (retainedVersions.isNotEmpty)
            AppCard(
              gap: 10,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.history,
                      size: 21,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.goBackToItAnyTime,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final version in retainedVersions)
                      // A version she can go back to is a thing to tap, so it
                      // is a chip, not a highlighted fact.
                      AppChip(
                        // Her own version numbers, Western digits, no
                        // NumberFormat and no sentence around them.
                        'v$version',
                        height: 34,
                        onTap: onRestore == null
                            ? null
                            : () => onRestore!.call(version),
                      ),
                  ],
                ),
              ],
            ),
          AppSageNote(l10n.yourPriceChangeAppliesToNewClients),
        ],
      ),
    );
  }
}

/// One line of the diff. Section name, and the verb where one is minted.
class _ChangeRow extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => '_ChangeRow';

  const _ChangeRow({required this.change});

  final BlockChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final label = BlockRegistry.of(change.type).labelOf(l10n);
    final verb = changeVerb(l10n, change.kind);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label ?? '',
            style: AppText.bodyM.copyWith(color: AppColors.onSurface),
          ),
        ),
        if (verb != null) ...[
          const SizedBox(width: 10),
          Text(
            verb,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// One reason the publish was refused, pointing at the section it belongs to.
///
/// The dictionary has a sentence for exactly one [BlockProblemKind] — a section
/// that needs a photo and has none, which is the refusal a coach with no
/// picker actually meets. The rest are still the section's name and an error
/// glyph: that tells her **where** without telling her **why**, which is a gap
/// rather than a fabrication, and the missing sentences are reported.
class _RefusalRow extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => '_RefusalRow';

  const _RefusalRow({required this.refusal});

  final PublishRefusal refusal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final type = refusal.problem?.type;
    final label = type == null ? null : BlockRegistry.of(type).labelOf(l10n);
    final why = switch (refusal.problem?.kind) {
      BlockProblemKind.missingMedia => l10n.thisSectionNeedsAPhotoOrVideo,
      _ => null,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 19, color: AppColors.error),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label ?? '',
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
              if (why != null) ...[
                const SizedBox(height: 2),
                Text(
                  why,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The minted verb for a change, or null.
///
/// Three of seven. `removed`, `shown`, `moved` and `edited` have no line in the
/// dictionary, and a row without a verb still says truthfully that the section
/// differs.
String? changeVerb(AppL10n l10n, BlockChangeKind kind) => switch (kind) {
  BlockChangeKind.added => l10n.added,
  BlockChangeKind.replaced => l10n.replaced,
  BlockChangeKind.hidden => l10n.hidden,
  BlockChangeKind.removed ||
  BlockChangeKind.shown ||
  BlockChangeKind.moved ||
  BlockChangeKind.edited => null,
};
