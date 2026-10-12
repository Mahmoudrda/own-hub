/// P05 — Your progress card.
///
/// One card of what she has done, drawn to be screenshotted or shared: her
/// workouts, the weeks she trained, her best run of weeks, the meals she added,
/// her personal bests and her milestones. Big figures, short captions, the
/// Own Hub tile, and the site's address at the foot, so a friend who sees it knows
/// where it came from.
///
/// ## What is on it, and what is not
///
/// Everything on the card is something she did. Nothing on it is a body figure
/// unless she puts it there: her weight change is behind a switch that is off
/// every time the screen opens, and it is offered only when she has weighed
/// herself at least twice (P04). Calories are never on it. A calorie total on a
/// card made for social media is the calorie countdown this product refuses
/// (`PRODUCT.md`), and rule 11 is that nothing here ranks women by weight; a
/// figure she chooses to share about herself is hers, a default is not.
///
/// Weeks, not days (rule 3): the run is counted in weeks, as P01 counts it.
///
/// ## Sharing
///
/// The card is a [RepaintBoundary]. "Share my card" renders it to a PNG at
/// three times its size and hands it to [onShare], which the router wires to
/// the phone's share sheet. The origin rectangle is the button's, because an
/// iPad (where Apple's reviewers often open iPhone apps) anchors the sheet to
/// it and fails without one. Nothing is uploaded: the image goes from this
/// screen to the share sheet she chose.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../../train/domain/weight_label.dart';

/// What the card says, read from her own stores on this phone.
@immutable
class ProgressStory {
  const ProgressStory({
    required this.sessions,
    required this.countedWeeks,
    required this.bestRun,
    required this.mealsAdded,
    required this.bests,
    required this.milestones,
  });

  final int sessions;
  final int countedWeeks;
  final int bestRun;
  final int mealsAdded;
  final int bests;
  final int milestones;

  /// Nothing done yet: the card would be a row of zeros.
  bool get isEmpty => sessions == 0 && mealsAdded == 0;
}

/// Her weight change from her first weigh-in to her latest, in kilograms
/// rounded to one decimal, or null with fewer than two weigh-ins.
double? weightChangeKg(List<({DateTime at, num kg})> weighIns) {
  if (weighIns.length < 2) return null;
  final ordered = [...weighIns]..sort((a, b) => a.at.compareTo(b.at));
  final change = ordered.last.kg - ordered.first.kg;
  return (change * 10).roundToDouble() / 10;
}

/// "−2.5 kg", "+1 kg", "0 kg". A true minus sign, Western digits.
String weightChangeLabel(AppL10n l10n, double change) {
  final sign = change < 0
      ? '−'
      : change > 0
      ? '+'
      : '';
  return l10n.weightKg('$sign${weightLabel(change.abs())}');
}

/// Hands the card's PNG to the share sheet, anchored at [origin].
typedef ProgressSharer = Future<void> Function(Uint8List png, Rect origin);

class ShareProgressView extends StatefulWidget {
  const ShareProgressView({
    super.key,
    required this.story,
    this.loadWeighIns,
    this.onShare,
    this.onShared,
    this.onBack,
    this.onSelectTab,
  });

  final ProgressStory story;

  /// Her weigh-ins from P04, read when the screen opens. Null or empty: the
  /// weight switch is not offered.
  final Future<List<({DateTime at, num kg})>> Function()? loadWeighIns;

  final ProgressSharer? onShare;

  /// After the share sheet was opened, for the usage count.
  final VoidCallback? onShared;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectTab;

  @override
  State<ShareProgressView> createState() => _ShareProgressViewState();
}

class _ShareProgressViewState extends State<ShareProgressView> {
  final GlobalKey _card = GlobalKey();
  final GlobalKey _button = GlobalKey();

  /// Off every time the screen opens. Never remembered.
  bool _showWeight = false;
  double? _weightChange;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final load = widget.loadWeighIns;
    if (load != null) {
      load().then((weighIns) {
        if (!mounted) return;
        setState(() => _weightChange = weightChangeKg(weighIns));
      }, onError: (Object _) {});
    }
  }

  Future<void> _share() async {
    final share = widget.onShare;
    final boundary =
        _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (share == null || boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null || !mounted) return;
      final box = _button.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null || !box.hasSize
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size;
      await share(bytes.buffer.asUint8List(), origin);
      widget.onShared?.call();
    } catch (_) {
      // A share sheet that could not open costs her nothing she can see.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final story = widget.story;
    final change = _weightChange;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.yourProgressCard, onBack: widget.onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'P01',
        onSelect: (id) {
          final onTab = widget.onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        // Pinned, so "Share my card" is in thumb reach on a small phone
        // however tall the card grows.
        footer: [
          if (story.isEmpty)
            Text(
              l10n.yourCardFillsInAfterYourFirst,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          KeyedSubtree(
            key: _button,
            child: AppButton(
              l10n.shareMyCard,
              icon: Icons.ios_share,
              onPressed: story.isEmpty || _sharing || widget.onShare == null
                  ? null
                  : _share,
            ),
          ),
        ],
        footerScrollsWhenLarge: true,
        children: [
          Text(
            l10n.everythingYouHaveDoneOnOneCard,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          RepaintBoundary(
            key: _card,
            child: _ProgressCard(
              story: story,
              weightChange: _showWeight ? change : null,
            ),
          ),
          if (change != null)
            AppListItem(
              title: l10n.showMyWeightChange,
              subtitle: l10n.offUnlessYouTurnItOnAnd,
              trailing: AppToggle(
                value: _showWeight,
                semanticLabel: l10n.showMyWeightChange,
                onChanged: (on) => setState(() => _showWeight = on),
              ),
            ),
        ],
      ),
    );
  }
}

/// The card itself: what the PNG is made of.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.story, this.weightChange});

  /// The app tile C01 shows, with its 2.0x and 3.0x variants beside it.
  static const String _tile = 'assets/brand/logo/ownhub-tile.png';

  final ProgressStory story;
  final double? weightChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final stats = <(String, int)>[
      (l10n.weeksTrained, story.countedWeeks),
      (l10n.bestRunInWeeks, story.bestRun),
      (l10n.mealsAdded, story.mealsAdded),
      (l10n.personalBests, story.bests),
      (l10n.milestones, story.milestones),
    ].where((s) => s.$2 > 0).toList();
    final change = weightChange;

    return AppCard(
      variant: AppCardVariant.tonal,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      gap: 14,
      seed: 5,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.myProgressOnOwnHub,
                    style: AppText.titleS.copyWith(color: AppColors.primaryDim),
                  ),
                  const SizedBox(height: 6),
                  HandUnderline(
                    seed: 11,
                    color: AppColors.primary,
                    child: Text(
                      l10n.workoutsDone,
                      style: AppText.titleL.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The Own Hub tile, so a friend who sees the card knows where it
            // came from. Not the kitten: it stays off every progress screen.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                _tile,
                width: 52,
                height: 52,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
        Text(
          countLabel(story.sessions),
          style: AppText.display.copyWith(
            fontSize: 56,
            height: 1.05,
            color: AppColors.primary,
          ),
        ),
        if (stats.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (label, value) in stats)
                _Stat(label: label, value: countLabel(value)),
            ],
          ),
        if (change != null)
          _Stat(
            label: l10n.weightSinceMyFirstWeighIn,
            value: weightChangeLabel(l10n, change),
            wide: true,
          ),
        Text(
          l10n.ownHubAppWomenOnly,
          style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: wide ? 260 : 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppText.headline.copyWith(color: AppColors.onSurface),
              ),
              Text(
                label,
                style: AppText.label.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
