/// A segmented control, matching `segmented()` in `6-v2/src/kit.mjs`.
///
/// A strip 44 high framed in pencil, the segments divided by pencil strokes,
/// and the chosen one laid over with marker and prefixed with a drawn tick. The tick matters: colour alone is not a reliable signal for
/// everyone, so the selected segment says so with a shape as well.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/hand.dart';

class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onChanged,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: HandSurface(
        seed: handSeed(['seg', ...items]),
        frame: AppColors.outline.withValues(alpha: 0.7),
        frameWidth: 1.1,
        radius: 6,
        looseCorner: 14,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _Segment(
                  label: items[i],
                  selected: i == selectedIndex,
                  // The prototype draws the divider on every segment but the
                  // first, so adjacent segments never show a double line.
                  showDivider: i > 0,
                  onTap: onChanged == null ? null : () => onChanged!(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.showDivider,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.onPrimaryContainer
        : AppColors.onSurfaceVariant;

    final seg = Semantics(
      selected: selected,
      child: HandPressable(
        onTap: onTap,
        scale: 0.97,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(4),
          child: CustomPaint(
            painter: selected
                ? MarkerPainter(
                    seed: label.hashCode,
                    cover: 0.9,
                    textDirection: Directionality.of(context),
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  HandTick(size: 15, color: foreground, seed: label.hashCode),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!showDivider) return seg;
    // A pencil stroke between segments, on the reading-start side so the
    // layout mirrors in Arabic.
    return Row(
      children: [
        const SizedBox(
          width: 1,
          height: 26,
          child: ColoredBox(color: Color(0x669C838A)),
        ),
        Expanded(child: seg),
      ],
    );
  }
}
