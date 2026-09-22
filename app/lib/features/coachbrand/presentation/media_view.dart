/// B13 — her media library, and the blur that is on before she asks for it.
///
/// §2 rule 6 / C11: *"blur on by default, on device, before upload."* G13 adds
/// **no second upload path** — the boundary is G8's `MediaUploadGateway`, and
/// this screen's toggle writes the per-image exception and nothing else.
///
/// The exception is narrow, and it is [CoachMediaPolicy.blurRequired] that
/// makes it narrow rather than this widget: a coach may decline to blur a
/// client in shot **only when that client's own result carries
/// `scope.faceVisible`**, which only the client can set, in her own consent
/// sheet, and only while that consent is current. So the switch is disabled
/// unless at least one item in the library has a live grant behind it — a
/// switch she is not allowed to change still renders its state, which is
/// different from one that is off.
///
/// Each thumbnail carries the blur badge while blur applies to it, so the rule
/// is visible per item rather than asserted once in a caption.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_media.dart';
import '../domain/consent.dart';

/// The three filters across the top.
enum MediaFilter { all, photos, video }

class MediaView extends StatelessWidget {
  const MediaView({
    super.key,
    required this.items,
    required this.now,
    this.filter = MediaFilter.all,
    this.results = const <String, ClientResult>{},
    this.blurClientsInShot = true,
    this.onFilter,
    this.onAdd,
    this.onBlurChanged,
    this.onOpen,
    this.onDone,
    this.onBack,
  });

  /// One page of `coaches/{coachUid}/media/*`. Paged at 30 by the repository,
  /// never unbounded — the cap is in the interface, so this screen cannot ask
  /// for more.
  final List<CoachMediaItem> items;

  final DateTime now;
  final MediaFilter filter;

  /// The live result documents, keyed by id. Read at render, never copied —
  /// a grant that has expired stops permitting an unblurred face the moment it
  /// expires.
  final Map<String, ClientResult> results;

  final bool blurClientsInShot;

  final ValueChanged<MediaFilter>? onFilter;
  final VoidCallback? onAdd;
  final ValueChanged<bool>? onBlurChanged;
  final ValueChanged<CoachMediaItem>? onOpen;
  final VoidCallback? onDone;
  final VoidCallback? onBack;

  List<CoachMediaItem> get _visible => switch (filter) {
    MediaFilter.all => items,
    MediaFilter.photos => [
      for (final i in items)
        if (i.kind == CoachMediaKind.photo) i,
    ],
    MediaFilter.video => [
      for (final i in items)
        if (i.kind == CoachMediaKind.video) i,
    ],
  };

  /// Whether blur applies to [item] right now, per the domain policy.
  bool _blurRequired(CoachMediaItem item) {
    final id = item.clientResultId;
    return CoachMediaPolicy.blurRequired(
      clientResult: id == null ? null : results[id],
      now: now,
    );
  }

  /// True when at least one item has a live grant of her own face behind it.
  ///
  /// Not a new rule: it is the same predicate, asked of the library instead of
  /// one file. With no such item there is nothing the switch could turn off.
  bool get _mayTurnBlurOff => items.any((item) => !_blurRequired(item));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.yourMedia,
        onBack: onBack,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.done_54ca1,
              height: 38,
              fontSize: 15,
              onPressed: onDone,
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          AppChipRow(
            items: [l10n.all, l10n.photos, l10n.video],
            selected: <int>{filter.index},
            grow: false,
            onTap: (i) => onFilter?.call(MediaFilter.values[i]),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: [
              for (final item in visible)
                // The picture gives under the finger, with no ripple over it.
                HandPressable(
                  onTap: onOpen == null ? null : () => onOpen!.call(item),
                  builder: (context, pressed) => AppMedia(
                    height: 108,
                    kind: item.kind == CoachMediaKind.photo
                        ? AppMediaKind.photo
                        : AppMediaKind.video,
                    showPlayButton: item.kind == CoachMediaKind.video,
                    borderRadius: AppRadius.xs,
                    badge: _blurRequired(item) ? l10n.blur : null,
                  ),
                ),
            ],
          ),
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            onTap: onAdd,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_camera,
                    size: 22,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.addPhotosOrAVideo,
                      style: AppText.titleS.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.blur_on,
                    size: 21,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.blurAnyClientWhoIsInShot,
                          style: AppText.titleM.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.onUnlessSheConsentedToHerFace,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppToggle(
                    value: blurClientsInShot,
                    semanticLabel: l10n.blurAnyClientWhoIsInShot,
                    onChanged: _mayTurnBlurOff ? onBlurChanged : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
