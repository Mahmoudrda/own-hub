/// The plates on one side of a bar, drawn, and the line that says them.
///
/// R07 and R08 show it for barbell moves only: "20 kg bar + 10 kg each side"
/// and a small picture of the bar with one side's plates, so loading the bar
/// does not need sums. The bar is hers to choose once (20, 15 or 10 kg) and is
/// kept on this phone only.
library;

import 'package:flutter/material.dart';

import '../../../app_state/bar_preference.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../domain/plate_math.dart';
import '../domain/weight_label.dart';

/// One side of a bar, with its plates, as rounded bars. Heavier plates are
/// taller and nearest the middle, as on a real bar.
class PlateDiagram extends StatelessWidget {
  const PlateDiagram({super.key, required this.load});

  final PlateLoad load;

  static Color _colorFor(double plate) {
    if (plate >= 25) return AppColors.petrolDark;
    if (plate >= 20) return AppColors.primary;
    if (plate >= 15) return AppColors.petrolMuted;
    if (plate >= 10) return AppColors.pinkDeep;
    if (plate >= 5) return AppColors.brandPink;
    return AppColors.pinkSoft;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plates = load.perSideKg;
    final label = plates.isEmpty
        ? l10n.justTheBarKgBar(weightLabel(load.barKg))
        : l10n.platesOnOneSidePlatesKg(
            [for (final p in plates) weightLabel(p)].join(', '),
          );
    // Taller with the text size, so it keeps its place beside larger type.
    final height = MediaQuery.textScalerOf(context)
        .scale(56)
        .clamp(56.0, 112.0);
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('plate-diagram'),
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _PlatePainter(
            plates: plates,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({required this.plates, required this.rtl});

  final List<double> plates;
  final bool rtl;

  static double _heightFraction(double plate) => switch (plate) {
    >= 25 => 1.0,
    >= 20 => 0.92,
    >= 15 => 0.8,
    >= 10 => 0.68,
    >= 5 => 0.54,
    >= 2.5 => 0.42,
    _ => 0.34,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final mid = size.height / 2;
    final barPaint = Paint()..color = AppColors.outline;
    // The bar runs the whole width, thin, with a collar before the plates.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 3, size.width, 6),
        const Radius.circular(3),
      ),
      barPaint,
    );
    const collarW = 8.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 12, collarW, 24),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.secondary,
    );
    if (plates.isEmpty) return;
    const gap = 3.0;
    final room = size.width - collarW - gap;
    final plateW = (room / plates.length - gap).clamp(3.0, 12.0);
    var x = collarW + gap;
    for (final plate in plates) {
      final h = size.height * _heightFraction(plate);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mid - h / 2, plateW, h),
          const Radius.circular(4),
        ),
        Paint()..color = PlateDiagram._colorFor(plate),
      );
      x += plateW + gap;
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.rtl != rtl || old.plates.join(',') != plates.join(',');
}

/// The sentence for [load], for whichever shape it has.
String plateLineFor(AppL10n l10n, PlateLoad load) {
  final bar = weightLabel(load.barKg);
  if (load.perSideKg.isEmpty && load.exact) return l10n.justTheBarKgBar(bar);
  final side = weightLabel(load.eachSideKg);
  if (load.exact) return l10n.barKgBarSideKgEachSide(bar, side);
  return l10n.closestYouCanLoadTotalKgBar(
    weightLabel(load.loadableKg),
    bar,
    side,
  );
}

/// The line, the picture and the way to change the bar, for [totalKg].
/// Draws nothing for a total below the bar.
class PlateHelper extends StatefulWidget {
  const PlateHelper({super.key, required this.totalKg});

  final double? totalKg;

  @override
  State<PlateHelper> createState() => _PlateHelperState();
}

class _PlateHelperState extends State<PlateHelper> {
  Future<void> _chooseBar() async {
    final l10n = AppL10n.of(context);
    final chosen = await showAppSheet<double>(
      context: context,
      children: [
        Text(l10n.whichBarDoYouUse, style: AppText.titleL),
        for (final kg in kBarChoicesKg)
          AppButton(
            l10n.kgKgBar(weightLabel(kg)),
            key: ValueKey('bar-choice-${weightLabel(kg)}'),
            variant: kg == BarPreference.instance.kg
                ? AppButtonVariant.filled
                : AppButtonVariant.tonal,
            height: 52,
            fontSize: 16,
            icon: kg == BarPreference.instance.kg ? Icons.check : null,
            onPressed: () => Navigator.of(context).pop(kg),
          ),
        const SizedBox(height: 4),
      ],
    );
    if (chosen == null) return;
    BarPreference.instance.choose(chosen);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalKg;
    if (total == null || total <= 0) return const SizedBox.shrink();
    final load = platesFor(total, barKg: BarPreference.instance.kg);
    if (load == null) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    return Padding(
      key: const ValueKey('plate-helper'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plateLineFor(l10n, load),
                  key: const ValueKey('plate-line'),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('plate-change-bar'),
                tooltip: l10n.changeBar,
                onPressed: _chooseBar,
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                color: AppColors.onSurfaceVariant,
                icon: const Icon(Icons.fitness_center),
              ),
            ],
          ),
          const SizedBox(height: 4),
          PlateDiagram(load: load),
        ],
      ),
    );
  }
}
