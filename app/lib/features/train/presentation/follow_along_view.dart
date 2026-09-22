/// R06 — Follow-along move.
///
/// Matches `6-v2/src/screens-train.mjs` → `R06`. **Zero taps to log.** A timed
/// follow-along move logs itself as it finishes: the timer *is* the log, and the
/// "logs itself" pill says so plainly, because silence after a set is otherwise
/// indistinguishable from a missed one.
///
/// This is the one dark screen in the group. It inverts because a video fills it
/// and a pink surface around moving footage is noise — which is also why the ring
/// and the buttons take explicit light colours here rather than the defaults.
///
/// **The countdown is not driven by this widget.** There is no video yet, and
/// when there is one the player owns the clock — a second timer ticking beside a
/// video position is two clocks that disagree. So [remaining] is supplied, and
/// the screen renders the time it is given. That also keeps the widget free of a
/// live timer, which is what makes it testable without pumping a real clock.
library;

import '../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_white_button.dart';
import '../../../ui/hand/hand.dart';
import '../domain/clock_label.dart';

/// White at 16% — the prototype's overlay tint on the inverted surface.
const Color _onDarkSoft = Color(0x29FFFFFF);
const Color _onDarkTrack = Color(0x2EFFFFFF);
const Color _onDark = Color(0xFFFFFFFF);
const Color _onDarkMuted = Color(0xB3FFFFFF);

/// White at 45%, for a drawn frame. A thin hand line needs more than the
/// track's 18% to read against the dark.
const Color _onDarkLine = Color(0x73FFFFFF);

class FollowAlongView extends StatelessWidget {
  const FollowAlongView({
    super.key,
    this.onPause,
    this.onSkip,
    this.moveName,
    this.positionLabel,
    this.remaining = const Duration(seconds: 24),
    this.total = const Duration(seconds: 40),
    this.bus,
  });

  final VoidCallback? onPause;

  /// Skipping moves on without logging. A skipped set is not a logged set, and
  /// it is not a failure either.
  final VoidCallback? onSkip;

  final String? moveName;

  /// "Move 3 of 5".
  final String? positionLabel;

  final Duration remaining;
  final Duration total;

  /// Every log in this product goes through the bus. Held here so the screen
  /// that logs *without a tap* uses the same five-second undo as the one that
  /// logs with one — there is no second logging path.
  final LogCommandBus? bus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final elapsed = total.inSeconds == 0
        ? 0.0
        : (total.inSeconds - remaining.inSeconds) / total.inSeconds;

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: ScreenArtStrip(size: 76),
            ),
            Expanded(
              child: Center(
                child: AppRingStat(
                  fraction: elapsed,
                  big: clockLabel(remaining),
                  small: l10n.left,
                  size: 168,
                  thickness: 14,
                  color: AppColors.primaryContainer,
                  bigColor: _onDark,
                  smallColor: _onDarkMuted,
                  trackColor: _onDarkTrack,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Where she is in the workout, or nothing.
                            //
                            // This read `positionLabel ?? move3Of5`, so
                            // it stated "Move 3 of 5" precisely when the real
                            // position was unknown — a fallback whose only job
                            // was to fill the line, and which filled it with
                            // the prototype's. R06 is given a position or it
                            // says nothing about one.
                            if (positionLabel != null) ...[
                              Text(
                                positionLabel!,
                                style: AppText.bodyM.copyWith(
                                  color: _onDarkMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              moveName ?? l10n.gluteBridge,
                              style: AppText.titleL.copyWith(
                                fontSize: 24,
                                color: _onDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Says out loud that nothing is expected of her, so the
                      // absence of a log button does not read as a missing one.
                      //
                      // Flexible because a Row hands its non-flex children
                      // unbounded width: at the largest text size the pill would
                      // otherwise take what it liked and overflow the row.
                      Flexible(
                        child: AppPill(
                          l10n.logsItself,
                          icon: Icons.check,
                          background: _onDarkSoft,
                          foreground: _onDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppWhiteButton(
                          l10n.pause,
                          icon: Icons.pause,
                          onPressed: onPause,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OnDarkOutlinedButton(
                          l10n.skipThisMove,
                          onPressed: onSkip,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An outlined button on the inverted surface.
///
/// [AppButton]'s outlined variant draws its label in `onSurface`, which is very
/// nearly black and invisible here. Local rather than a sixth shared variant, for
/// the reason `app_white_button.dart` gives: several groups are editing
/// `app_button.dart` at once. Fold both in together.
class _OnDarkOutlinedButton extends StatelessWidget {
  const _OnDarkOutlinedButton(this.label, {this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Framed in white pencil with tight corners, beside the white block of
    // Pause — the same cut as that button, only unfilled.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: HandSurface(
        seed: handSeed(['on-dark', label]),
        frame: _onDarkLine,
        frameWidth: 1.3,
        radius: 7,
        looseCorner: 15,
        onTap: onPressed,
        pressable: true,
        semanticsButton: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _onDark,
            ),
          ),
        ),
      ),
    );
  }
}
