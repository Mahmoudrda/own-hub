/// G07 — rest between sets, running **her coach's** seconds.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G07`. Its design note: *"The rest
/// timer is the coach's, not a default: it runs the seconds Sara set. Undo sits
/// inside the confirmation, and finishing early is always available — an
/// assigned session is still hers to stop."*
///
/// ## Three properties, each of which is a rule
///
///  1. **The seconds are hers.** [restSeconds] comes from `moves[].restSec` on
///     the assignment. When the coach set none it is null, the "Sara set 45
///     seconds" line is **not rendered**, and the timer falls back to the
///     product's own rest copy — because the app may not attribute a number to
///     a woman who never chose it.
///  2. **Undo, not confirmation.** The bar at the top names the set that was
///     just saved and offers Undo for five seconds. There is no dialog on this
///     screen, and `LogCommandBus` holds the write for the whole window, so an
///     undone set never reaches the server at all.
///  3. **Finishing early needs nobody.** "Finish workout" sits on this screen,
///     next to the timer, and calls straight through to the session controller.
///     It sends no message and waits for no reply.
///
/// The clock is a real clock. `resting_view.dart` records what happens when it
/// is not — a `StatelessWidget` holding a `const Duration` that promised to
/// "start itself, end itself" and never ticked, with every test passing because
/// they all asserted the painted value. [autoStart] exists for the same reason
/// it exists there: a live one-second tick never lets `pumpAndSettle` settle.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_bar.dart';
import '../../train/domain/clock_label.dart';

class RestBetweenSetsView extends StatefulWidget {
  const RestBetweenSetsView({
    super.key,
    this.onClose,
    this.onPause,
    this.onReady,
    this.onSkipTimer,
    this.onShareForm,
    this.onFinishWorkout,
    this.onUndo,
    this.handle,
    this.restSeconds,
    this.autoStart = true,
    this.nextSetLabel,
  });

  final VoidCallback? onClose;
  final VoidCallback? onPause;

  /// Called by her tap **and** by the clock reaching zero.
  final VoidCallback? onReady;

  final VoidCallback? onSkipTimer;
  final VoidCallback? onShareForm;

  /// Ends the session. No coach, no reason, no message.
  final VoidCallback? onFinishWorkout;

  final VoidCallback? onUndo;

  /// The log made on G06. Null once the window has closed, at which point the
  /// bar states what was saved without offering an action that would do
  /// nothing.
  final LogHandle? handle;

  /// **Her coach's** seconds. Null when the coach set none — see the note above.
  final int? restSeconds;

  final bool autoStart;

  /// "Set 3 · 12 kg × 12".
  final String? nextSetLabel;

  @override
  State<RestBetweenSetsView> createState() => _RestBetweenSetsViewState();
}

class _RestBetweenSetsViewState extends State<RestBetweenSetsView> {
  Timer? _tick;
  late Duration _remaining = _initial;
  late Duration _total = _initial;

  /// The coach's seconds, or the product's own default when she set none.
  ///
  /// The fallback is used for the *clock*; it is never described as hers.
  Duration get _initial => Duration(seconds: widget.restSeconds ?? 60);

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _start();
  }

  @override
  void didUpdateWidget(covariant RestBetweenSetsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.restSeconds != oldWidget.restSeconds) {
      _remaining = _initial;
      _total = _initial;
    }
    if (widget.autoStart != oldWidget.autoStart) {
      widget.autoStart ? _start() : _stop();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    _stop();
    if (_remaining <= Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _stop();
        // Rest is over and she was not asked to say so.
        widget.onReady?.call();
        return;
      }
      setState(() => _remaining = next);
    });
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final elapsed = _total.inSeconds == 0
        ? 0.0
        : ((_total.inSeconds - _remaining.inSeconds) / _total.inSeconds).clamp(
            0.0,
            1.0,
          );

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.move2Of5,
        onBack: widget.onClose,
        leadingIcon: Icons.close,
        actions: [
          IconButton(
            onPressed: widget.onPause,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.pause),
          ),
        ],
      ),
      footer: [
        AppButton(l10n.imReadyNextSet, height: 54, onPressed: widget.onReady),
      ],
      children: [
        // With no saved set there is nothing to undo, so there is no bar. The
        // prototype's "Set 2 saved · 12 kg × 12" told every woman she had
        // just saved one coach's sample lift.
        if (widget.handle case final handle?)
          AppUndoBar(
            message: handle.describe,
            undoLabel: l10n.undo,
            onUndo: () {
              // False when she was a moment late; nothing is rolled back,
              // because by then the write has already been made.
              if (handle.undo()) widget.onUndo?.call();
            },
          ),
        const SizedBox(height: 16),
        Center(
          child: AppRingStat(
            fraction: elapsed,
            big: clockLabel(_remaining),
            small: l10n.rest,
            size: 190,
            thickness: 14,
          ),
        ),
        // Rendered only when the seconds are actually hers — and it names
        // whose they are without restating them. The dictionary's "Sara set 45
        // seconds between these sets." said forty-five whatever the clock
        // showed, so a woman resting seventy-five seconds read a figure that
        // was never hers. The ring already shows the real count.
        if (widget.restSeconds != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                l10n.fromCoachSara,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          gap: 6,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.upNext,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      // "Set 3 · 12 kg × 12" is the mockup's next set. Where
                      // no next set was handed in, the row says nothing about
                      // one rather than inventing a load.
                      if (widget.nextSetLabel case final next?) ...[
                        const SizedBox(height: 2),
                        Text(next, style: AppText.titleM),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: AppButton(
                    l10n.skipTimer,
                    variant: AppButtonVariant.text,
                    height: 40,
                    fontSize: 14,
                    onPressed: widget.onSkipTimer,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.shareFormVideo,
                variant: AppButtonVariant.outlined,
                height: 44,
                fontSize: 14,
                icon: Icons.videocam_outlined,
                onPressed: widget.onShareForm,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                l10n.finishWorkout,
                variant: AppButtonVariant.outlined,
                height: 44,
                fontSize: 14,
                onPressed: widget.onFinishWorkout,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
