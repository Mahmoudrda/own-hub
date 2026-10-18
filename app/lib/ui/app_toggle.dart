/// The switch, matching `toggle()` in `6-v2/src/kit.mjs`.
///
/// Phase 2 is switch-dense — A03, Y02, Y10 and Y12 are mostly rows of these —
/// and the product had no switch primitive at all. Building it once here is the
/// difference between one control and four that drifted apart.
///
/// # This is the control, not the row
///
/// [AppListItem] already provides the row: optional leading icon, title,
/// optional subtitle, optional trailing widget. Every settings row in the design
/// is that row with this in its `trailing` slot, so there is deliberately no
/// `AppToggleRow` here to go stale beside it.
///
/// # Why the geometry is written out
///
/// The numbers are the prototype's, not Material's defaults: a 52×32 track with
/// a 2px border, and a knob that **changes size** as well as position — 16px
/// off, 24px on. That size change is doing accessibility work. A switch that
/// signals its state only by which end the knob sits at, and by a colour, gives
/// someone with low vision or colour-blindness two weak signals; the third one
/// is free.
///
/// # RTL
///
/// The knob is placed with [AlignmentDirectional], so "on" is the *end* of the
/// track — the right in English and the left in Arabic. A raw `Alignment` would
/// have left every switch in the product unmirrored, which is the kind of thing
/// that looks fine to whoever built it and wrong to everyone reading Arabic.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'hand/draw_on.dart' show handMotionOff;

class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables it. The control still renders its state — a switch she is
  /// not allowed to change is different from one that is off.
  final ValueChanged<bool>? onChanged;

  /// What this switch governs. Usually null, because the row's own title says
  /// it; supply one where the switch stands alone.
  final String? semanticLabel;

  /// The prototype's track, to the pixel.
  static const double trackWidth = 52;
  static const double trackHeight = 32;

  static const double _knobOn = 24;
  static const double _knobOff = 16;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final duration = handMotionOff(context) ? Duration.zero : AppMotion.fast;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        // Opaque so the whole 52×32 track is the target, not just the knob.
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.emphasized,
          width: trackWidth,
          height: trackHeight,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          // Squarer than a stock switch, the way the rest of the page is cut.
          // A switch stays structural — exact geometry, no hand — because its
          // state has to be read at a glance, mid-set.
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value ? AppColors.primaryDim : AppColors.outline,
              width: 2,
            ),
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: AppMotion.emphasized,
            // Directional, so it mirrors in Arabic. See the note above.
            alignment: value
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.emphasized,
              margin: value
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 4),
              width: value ? _knobOn : _knobOff,
              height: value ? _knobOn : _knobOff,
              decoration: BoxDecoration(
                color: value ? AppColors.onPrimary : AppColors.outline,
                borderRadius: BorderRadius.circular(value ? 7 : 5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
