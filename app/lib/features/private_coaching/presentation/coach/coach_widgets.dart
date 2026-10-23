/// Small pieces the coach's screens share: the loading and offline gate, a
/// whole-row switch, a stepper, her round photo and the heading style.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_scaffold.dart' show kStackGap;
import '../../../../ui/app_toggle.dart';
import '../../domain/coaching_contract.dart';
import '../member/coach_card.dart' show coachInitial;
import 'coach_data.dart';
import 'coach_text.dart';

/// Rebuilds [builder] as [data] changes; shows a calm loading line before the
/// first answer and a retry when the connection fails.
class CoachDataGate extends StatelessWidget {
  const CoachDataGate({super.key, required this.data, required this.builder});

  final CoachSpaceData data;
  final List<Widget> Function(BuildContext context) builder;

  /// The children to show: the gate's own, or the screen's.
  static List<Widget> children(
    BuildContext context,
    CoachSpaceData data,
    List<Widget> Function(BuildContext) builder,
  ) {
    final l10n = AppL10n.of(context);
    final failure = data.failure;
    if (failure != null) {
      return <Widget>[
        AppCard(
          variant: AppCardVariant.filled,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(coachFailureText(l10n, failure), style: AppText.body),
            ),
            if (failure.refusal == CoachingRefusal.unreachable ||
                failure.refusal == CoachingRefusal.unknown)
              AppButton(
                l10n.tryAgain,
                variant: AppButtonVariant.tonal,
                onPressed: data.retry,
              ),
          ],
        ),
      ];
    }
    if (data.loading) {
      return <Widget>[
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.loadingYourCoachSpace,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }
    return builder(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: data,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: kStackGap,
      children: children(context, data, builder),
    ),
  );
}

/// A row with a title, a line under it and a switch. The whole row is the
/// target, at least 48 high, and a screen reader hears one switch.
class CoachSwitchRow extends StatelessWidget {
  const CoachSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle = '',
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: title,
      hint: subtitle.isEmpty ? null : subtitle,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.titleS),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppToggle(value: value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A whole number she nudges up or down between [min] and [max].
class CoachStepper extends StatelessWidget {
  const CoachStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.display,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// The value as written on the screen; defaults to the number.
  final String? display;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final shown = display ?? '$value';
    return Semantics(
      container: true,
      label: label,
      value: shown,
      increasedValue: value < max ? '${value + 1}' : null,
      decreasedValue: value > min ? '${value - 1}' : null,
      onIncrease: value < max ? () => onChanged(value + 1) : null,
      onDecrease: value > min ? () => onChanged(value - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.titleS)),
            _StepButton(
              icon: Icons.remove,
              tooltip: l10n.less,
              onTap: value > min ? () => onChanged(value - 1) : null,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Text(
                shown,
                textAlign: TextAlign.center,
                style: AppText.titleM,
              ),
            ),
            _StepButton(
              icon: Icons.add,
              tooltip: l10n.more,
              onTap: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    icon: Icon(icon),
    color: AppColors.onSurface,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}

/// Her round photo, or her first letter when she has none yet.
class CoachPhoto extends StatelessWidget {
  const CoachPhoto({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 64,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = coachInitial(name);
    final url = photoUrl;
    final letter = Center(
      child: Text(
        initial.toUpperCase(),
        style: AppText.titleL.copyWith(color: AppColors.onPrimaryContainer),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryContainer,
        ),
        child: url == null || url.isEmpty
            ? letter
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => letter,
              ),
      ),
    );
  }
}

/// A heading above a block on one of the coach screens.
class CoachHeading extends StatelessWidget {
  const CoachHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: AppText.titleM),
    ),
  );
}

/// An error line under a field.
class CoachFieldError extends StatelessWidget {
  const CoachFieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(text, style: AppText.bodyM.copyWith(color: AppColors.error)),
  );
}
