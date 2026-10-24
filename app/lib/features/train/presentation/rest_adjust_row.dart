/// R09's rest controls: fifteen seconds less, and fifteen more. "I'm ready" is
/// the way to end the rest early.
///
/// Each is a 48 point target with a spoken label that says what it does. They
/// wrap onto a second line instead of overflowing at the largest text size or
/// in Arabic. "Less" is off when it would take the rest under fifteen seconds
/// or end it, so a tap here can never end her rest by accident; "more" is off
/// at the longest rest a workout may have.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_button.dart';
import '../domain/rest_adjust.dart';

class RestAdjustRow extends StatelessWidget {
  const RestAdjustRow({
    super.key,
    required this.clock,
    required this.onShorter,
    required this.onLonger,
  });

  final ValueListenable<({Duration remaining, Duration total})> clock;
  final VoidCallback onShorter;
  final VoidCallback onLonger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final step = '${kRestStep.inSeconds}';
    return ValueListenableBuilder<({Duration remaining, Duration total})>(
      valueListenable: clock,
      builder: (context, value, _) {
        final shorter = canShortenRest(value.total, value.remaining);
        final longer = canLengthenRest(value.total);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _RestButton(
              key: const ValueKey('r09-less-15'),
              label: l10n.secondsSLess(step),
              semanticLabel: l10n.shortenTheRestBySecondsSeconds(step),
              onPressed: shorter ? onShorter : null,
            ),
            _RestButton(
              key: const ValueKey('r09-more-15'),
              label: l10n.secondsSMore(step),
              semanticLabel: l10n.addSecondsSecondsToTheRest(step),
              onPressed: longer ? onLonger : null,
            ),
          ],
        );
      },
    );
  }
}

class _RestButton extends StatelessWidget {
  const _RestButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48),
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: AppButton(
            label,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
