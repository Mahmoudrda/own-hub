/// The picture of a finished workout, drawn to be shared, and the panel on R10
/// that lets her choose what is in it.
///
/// ## The card
///
/// One big figure, a row of smaller ones, the workout's name and day, a small
/// Own Hub mark on a pink ribbon. Two shapes, Story (9:16) and
/// Square (4:5), and three grounds: linen, petrol, and none at all, for laying
/// over her own photo. Each figure has its own switch.
///
/// It is built from what is on this phone and nothing else: no place, no map,
/// no photo and no name unless she turns the name on. Calories are an estimate
/// (MET x body weight x time) and are labelled so; they are one figure she may
/// hide, like the rest. A session of bodyweight sets lifted no weight, so the
/// card shows reps in that place instead of a zero.
///
/// The card is drawn at a fixed logical size (360 wide) and ignores the phone's
/// text size, so the shared picture is the same whoever shares it and is
/// exactly 1080 wide at three times. Only the preview around it scales.
///
/// ## Sharing
///
/// "Share" renders the card to a PNG and hands it to the share sheet through
/// [WorkoutSharer]; nothing is uploaded and nothing is kept. The share sheet
/// is the way to save the picture, so there is no separate save button.
///
/// The card draws no kitten: R10 already has its one.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../domain/format/date_label.dart';
import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/session_summary.dart';

/// Hands the card's PNG to the share sheet, anchored at [origin].
typedef WorkoutSharer = Future<void> Function(Uint8List png, Rect origin);

enum ShareFormat {
  /// 1080 x 1920 at three times.
  story(640),

  /// 1080 x 1350 at three times.
  square(450);

  const ShareFormat(this.height);

  /// The card's logical height; its width is [shareCardWidth].
  final double height;
}

/// The card's logical width. Times the render ratio, the width of the PNG.
const double shareCardWidth = 360;

/// How sharply the card is rendered: 360 x 3 = 1080.
const double shareRenderRatio = 3;

enum ShareBackground { linen, petrol, transparent }

enum ShareStat { calories, minutes, weight, moves, bests, name }

/// What the card says. Built from the summary; the figures a session did not
/// produce are zero and are not offered.
@immutable
class ShareCardData {
  const ShareCardData({
    required this.title,
    required this.date,
    this.minutes = 0,
    this.kcal = 0,
    this.volumeKg = 0,
    this.reps = 0,
    this.moves = 0,
    this.sets = 0,
    this.bests = 0,
    this.name,
  });

  factory ShareCardData.from({
    required SessionSummary summary,
    required String title,
    required DateTime date,
    double? bodyWeightKg,
    String? name,
  }) => ShareCardData(
    title: title,
    date: date,
    minutes: summary.minutes,
    kcal: summary.estimatedKcal(bodyWeightKg: bodyWeightKg),
    volumeKg: summary.volumeWholeKg,
    reps: summary.totalReps,
    moves: summary.moves,
    sets: summary.sets,
    bests: summary.newBests.length,
    name: name,
  );

  final String title;
  final DateTime date;
  final int minutes;
  final int kcal;

  /// Whole kilograms lifted. Zero for bodyweight work.
  final int volumeKg;

  /// Shown in place of the weight when none was lifted.
  final int reps;
  final int moves;
  final int sets;
  final int bests;
  final String? name;

  /// The figures this session has, in the order they are drawn.
  List<ShareStat> get available => [
    if (kcal > 0) ShareStat.calories,
    if (minutes > 0) ShareStat.minutes,
    if (volumeKg > 0 || reps > 0) ShareStat.weight,
    if (moves > 0) ShareStat.moves,
    if (bests > 0) ShareStat.bests,
    if (name != null && name!.trim().isNotEmpty) ShareStat.name,
  ];
}

/// One figure as drawn: what it is called, its number and its unit.
typedef _Tile = ({String label, String value, String? unit});

List<_Tile> _tiles(AppL10n l10n, ShareCardData data, Set<ShareStat> shown) {
  bool on(ShareStat s) => shown.contains(s);
  return [
    if (on(ShareStat.calories) && data.kcal > 0)
      (label: l10n.caloriesEst, value: countLabel(data.kcal), unit: l10n.kcal),
    if (on(ShareStat.minutes) && data.minutes > 0)
      (label: l10n.minutes, value: countLabel(data.minutes), unit: null),
    if (on(ShareStat.weight) && data.volumeKg > 0)
      (
        label: l10n.weightLifted,
        value: countLabel(data.volumeKg),
        unit: l10n.weightKg('').trim(),
      )
    else if (on(ShareStat.weight) && data.reps > 0)
      (label: l10n.reps, value: countLabel(data.reps), unit: null),
    if (on(ShareStat.moves) && data.moves > 0) ...[
      (label: l10n.moves, value: countLabel(data.moves), unit: null),
      if (data.sets > 0)
        (label: l10n.sets, value: countLabel(data.sets), unit: null),
    ],
    if (on(ShareStat.bests) && data.bests > 0)
      (label: l10n.personalBests, value: countLabel(data.bests), unit: null),
  ];
}

class _Ink {
  const _Ink({
    required this.number,
    required this.label,
    required this.accent,
    this.shadow = false,
  });

  final Color number;
  final Color label;
  final Color accent;

  /// A soft shadow under the type, for the ground that is the viewer's photo.
  final bool shadow;

  static _Ink of(ShareBackground background) => switch (background) {
    ShareBackground.linen => const _Ink(
      number: AppColors.primary,
      label: AppColors.onSurfaceVariant,
      accent: AppColors.pinkShade,
    ),
    ShareBackground.petrol => const _Ink(
      number: AppColors.brandLinen,
      label: AppColors.pinkSoft,
      accent: AppColors.brandPink,
    ),
    // Linen type with a shadow reads on a dark photo and on a pale one.
    ShareBackground.transparent => const _Ink(
      number: AppColors.brandLinen,
      label: AppColors.brandLinen,
      accent: AppColors.brandPink,
      shadow: true,
    ),
  };

  List<Shadow>? get shadows => shadow
      ? const [
          Shadow(color: Color(0x99123F50), blurRadius: 6, offset: Offset(0, 1)),
        ]
      : null;
}

/// The picture itself. Fixed size, fixed text scale, nothing that moves.
class SessionShareCard extends StatelessWidget {
  const SessionShareCard({
    super.key,
    required this.data,
    this.format = ShareFormat.square,
    this.background = ShareBackground.linen,
    this.shown = const {
      ShareStat.calories,
      ShareStat.minutes,
      ShareStat.weight,
      ShareStat.moves,
      ShareStat.bests,
    },
  });

  static const String markAsset = 'assets/brand/logo/ownhub-tile.png';

  final ShareCardData data;
  final ShareFormat format;
  final ShareBackground background;

  /// The figures she has switched on. The name is drawn only when it is in
  /// here and [data] has one.
  final Set<ShareStat> shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ink = _Ink.of(background);
    final tiles = _tiles(l10n, data, shown);
    final story = format == ShareFormat.story;
    final name = shown.contains(ShareStat.name) ? data.name?.trim() : null;
    final date = dayMonthYearLabel(l10n, data.date);

    TextStyle numeral(double size) => AppText.display.copyWith(
      fontSize: size,
      height: 1.0,
      color: ink.number,
      shadows: ink.shadows,
    );
    TextStyle caption(Color c, {double size = 14}) => AppText.label.copyWith(
      fontSize: size,
      height: 1.2,
      color: c,
      shadows: ink.shadows,
    );

    Widget heroOf(_Tile t) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.label, style: caption(ink.label, size: 17)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            Flexible(
              child: HandUnderline(
                seed: 17,
                color: ink.accent,
                width: 4,
                level: HandLevel.signature,
                // A long figure shrinks to the width rather than run off.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    t.value,
                    maxLines: 1,
                    softWrap: false,
                    style: numeral(story ? 104 : 84),
                  ),
                ),
              ),
            ),
            if (t.unit != null) ...[
              const SizedBox(width: 8),
              Text(t.unit!, style: caption(ink.label, size: 22)),
            ],
          ],
        ),
      ],
    );

    Widget smallOf(_Tile t) => SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: caption(ink.label, size: 13),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              t.unit == null ? t.value : '${t.value} ${t.unit}',
              maxLines: 1,
              style: numeral(30),
            ),
          ),
        ],
      ),
    );

    final content = SizedBox(
      width: shareCardWidth - 48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The mark and the day: small, at the top, like a signature.
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  markAsset,
                  width: 34,
                  height: 34,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caption(ink.label, size: 15),
                ),
              ),
            ],
          ),
          SizedBox(height: story ? 28 : 14),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.titleL.copyWith(
              fontSize: story ? 26 : 22,
              height: 1.2,
              color: ink.number,
              shadows: ink.shadows,
            ),
          ),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: caption(ink.label, size: 15),
            ),
          ],
          SizedBox(height: story ? 44 : 20),
          if (tiles.isNotEmpty) heroOf(tiles.first),
          if (tiles.length > 1) ...[
            SizedBox(height: story ? 40 : 20),
            Wrap(
              spacing: 12,
              runSpacing: story ? 22 : 14,
              children: [for (final t in tiles.skip(1)) smallOf(t)],
            ),
          ],
        ],
      ),
    );

    final footer = Row(
      children: [
        Expanded(
          child: Text(
            l10n.ownHubAppWomenOnly,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: caption(ink.label, size: 13),
          ),
        ),
      ],
    );

    Widget card = SizedBox(
      width: shareCardWidth,
      height: format.height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (background == ShareBackground.linen)
              const ColoredBox(color: AppColors.brandLinen),
            if (background == ShareBackground.petrol)
              const ColoredBox(color: AppColors.brandPetrol),
            // The pink ribbon: a band across the top, and one under the foot.
            Positioned.fill(
              child: CustomPaint(painter: _RibbonPainter(story: story)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, story ? 44 : 34, 24, 18),
              child: Column(
                children: [
                  // If a long title or a big text ever made the content taller
                  // than the card, it shrinks to fit rather than overflow.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.topStart,
                      child: content,
                    ),
                  ),
                  const SizedBox(height: 10),
                  footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // The picture is the same whatever size she reads her phone at.
    card = MediaQuery.withNoTextScaling(child: card);
    return card;
  }
}

/// A pale-pink ribbon: a band over the top edge with a deeper strip in it, and
/// a thinner one across the foot.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.story});

  final bool story;

  @override
  void paint(Canvas canvas, Size size) {
    final band = story ? 22.0 : 16.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, band),
      Paint()..color = AppColors.brandPink,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, band, size.width, 4),
      Paint()..color = AppColors.pinkShade,
    );
    final footTop = size.height - 6;
    canvas.drawRect(
      Rect.fromLTWH(0, footTop, size.width, 6),
      Paint()..color = AppColors.brandPink,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.story != story;
}

/// The share section of R10: the live preview first, the share button under
/// it, then what she can change.
///
/// Everything is chosen again each time the screen opens: the name is off
/// unless she turns it on.
class SessionSharePanel extends StatefulWidget {
  const SessionSharePanel({
    super.key,
    required this.data,
    required this.onShare,
    this.onShared,
  });

  final ShareCardData data;

  /// Hands over the PNG. Null leaves the button disabled.
  final WorkoutSharer? onShare;

  /// After the share sheet was opened.
  final VoidCallback? onShared;

  @override
  State<SessionSharePanel> createState() => _SessionSharePanelState();
}

class _SessionSharePanelState extends State<SessionSharePanel> {
  final GlobalKey _card = GlobalKey();
  final GlobalKey _button = GlobalKey();

  ShareFormat _format = ShareFormat.square;
  ShareBackground _background = ShareBackground.linen;
  late Set<ShareStat> _shown;
  bool _sharing = false;

  bool _markLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoded while she looks at the preview, so the picture has its mark.
    if (_markLoading) return;
    _markLoading = true;
    precacheImage(
      const AssetImage(SessionShareCard.markAsset),
      context,
      onError: (_, _) {},
    );
  }

  @override
  void initState() {
    super.initState();
    _shown = {
      for (final s in widget.data.available)
        if (s != ShareStat.name) s,
    };
  }

  Future<void> _share() async {
    final share = widget.onShare;
    final boundary =
        _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (share == null || boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      // The mark must be decoded before the card is drawn into the picture.
      await precacheImage(
        const AssetImage(SessionShareCard.markAsset),
        context,
      );
      if (!mounted) return;
      final image = await boundary.toImage(pixelRatio: shareRenderRatio);
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

  void _toggle(ShareStat stat, bool on) => setState(() {
    _shown = {
      for (final s in _shown)
        if (s != stat) s,
      if (on) stat,
    };
  });

  String _label(AppL10n l10n, ShareStat stat) => switch (stat) {
    ShareStat.calories => l10n.caloriesEst,
    ShareStat.minutes => l10n.minutes,
    ShareStat.weight =>
      widget.data.volumeKg > 0 ? l10n.weightLifted : l10n.reps,
    ShareStat.moves => l10n.movesAndSets,
    ShareStat.bests => l10n.personalBests,
    ShareStat.name => l10n.myName,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final data = widget.data;
    final story = _format == ShareFormat.story;
    final transparent = _background == ShareBackground.transparent;

    final preview = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: story ? 232 : 300),
      child: AspectRatio(
        aspectRatio: shareCardWidth / _format.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outline),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (transparent) const CustomPaint(painter: _CheckerPainter()),
              FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: _card,
                  child: SessionShareCard(
                    data: data,
                    format: _format,
                    background: _background,
                    shown: _shown,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      key: const ValueKey('r10-share'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.shareYourWorkout, style: AppText.titleM),
        const SizedBox(height: 12),
        Center(
          child: Semantics(
            label: l10n.previewOfYourWorkoutCard,
            image: true,
            child: ExcludeSemantics(child: preview),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.thisIsThePictureYouWillShare,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: _button,
          child: AppButton(
            l10n.share,
            icon: Icons.ios_share,
            onPressed: _sharing || widget.onShare == null ? null : _share,
          ),
        ),
        const SizedBox(height: 18),
        Text(l10n.customiseTheCard, style: AppText.titleS),
        const SizedBox(height: 10),
        Text(l10n.format, style: AppText.label),
        const SizedBox(height: 6),
        AppChipRow(
          items: [l10n.story, l10n.square],
          selected: {_format.index},
          grow: false,
          onTap: (i) => setState(() => _format = ShareFormat.values[i]),
        ),
        const SizedBox(height: 12),
        Text(l10n.background, style: AppText.label),
        const SizedBox(height: 6),
        AppChipRow(
          items: [l10n.linen, l10n.petrol, l10n.transparent],
          selected: {_background.index},
          grow: false,
          onTap: (i) => setState(() => _background = ShareBackground.values[i]),
        ),
        const SizedBox(height: 12),
        Text(l10n.showOnTheCard, style: AppText.label),
        for (final stat in data.available)
          _SwitchRow(
            key: ValueKey('share-switch-${stat.name}'),
            label: _label(l10n, stat),
            value: _shown.contains(stat),
            onChanged: (on) => _toggle(stat, on),
          ),
        if (data.kcal > 0) ...[
          const SizedBox(height: 6),
          Text(
            l10n.caloriesAreARoughEstimateFromYour,
            key: const ValueKey('share-calorie-note'),
            style: AppText.bodyM.copyWith(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A label and a switch, the whole row a tap target of at least 48.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.body)),
            const SizedBox(width: 12),
            AppToggle(value: value, semanticLabel: label, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A grey and white check, behind a transparent preview so she can see it is.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final light = Paint()..color = AppColors.surfaceLowest;
    final dark = Paint()..color = AppColors.surfaceHighest;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), odd ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}
