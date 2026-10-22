/// R07's "Warm-up set" switch: off by default, and for the next set only.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_toggle.dart';

class WarmUpToggle extends StatelessWidget {
  const WarmUpToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      container: true,
      toggled: value,
      label: l10n.warmUpSet,
      hint: l10n.notCountedInYourSetsOrRecords,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        key: const ValueKey('r07-warm-up'),
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.warmUpSet, style: AppText.bodyM),
                    Text(
                      l10n.notCountedInYourSetsOrRecords,
                      style: AppText.label.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IgnorePointer(
                child: AppToggle(value: value, onChanged: (_) {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
