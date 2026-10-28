/// The microphone on E03: tap to start and tap to stop, or hold while she
/// speaks and let go when she is done. One control for both, because a woman
/// who has used voice notes in chat holds, and a woman with one free thumb taps.
///
/// A screen reader cannot hold, so the semantic action is the tap.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/hand/hand.dart';

class VoiceMicButton extends StatelessWidget {
  const VoiceMicButton({
    super.key,
    required this.label,
    required this.listening,
    required this.enabled,
    required this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
  });

  /// What a screen reader says, and what the button is called.
  final String label;

  /// Lit and showing a stop square while she is being listened to.
  final bool listening;

  /// False while a system prompt or the phone is busy, so a second press cannot
  /// start a second session.
  final bool enabled;

  final VoidCallback onTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        key: const ValueKey('voice-mic'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        onLongPressStart: enabled && onHoldStart != null
            ? (_) => onHoldStart!()
            : null,
        onLongPressEnd: enabled && onHoldEnd != null
            ? (_) => onHoldEnd!()
            : null,
        child: Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: HandSurface(
              seed: handSeed(['voice-mic', listening]),
              fill: listening ? AppColors.primary : AppColors.primaryContainer,
              radius: 48,
              looseCorner: 30,
              child: Center(
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic,
                  size: 40,
                  color: listening
                      ? AppColors.onPrimary
                      : AppColors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
