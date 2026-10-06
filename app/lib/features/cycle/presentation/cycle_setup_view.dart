/// Y01 — Set up My cycle.
///
/// Matches `6-v2/src/screens-cycle.mjs` → `Y01`. Two questions: how she wants to
/// use it, and anything the app should not try to infer.
///
/// ## Skipping writes nothing at all
///
/// `P0-CYC-03`: "No cycle document is written. Home shows no cycle card, no
/// check-in prompt and no trace of the feature." So [onSkip] does not touch the
/// repository — the write happens on Continue and nowhere else. §3.1's
/// `notSetUp` is "no `cycle/current` document", and the cheapest way to keep
/// that true is to have no code path that creates one early.
///
/// ## Sharing cannot be turned on here
///
/// There is no sharing control on this screen and no way to reach one, because
/// `CycleRepository.completeSetup` takes no sharing parameter (C12). Y01 could
/// not grant a coach anything if it tried.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/cycle_document.dart';
import '../domain/cycle_repository.dart';
import '../../../ui/medical_disclaimer.dart';

class CycleSetupView extends StatefulWidget {
  const CycleSetupView({
    super.key,
    this.repository,
    this.onBack,
    this.onContinueWithDates,
    this.onContinueSymptomsOnly,
    this.onSkip,
    this.initialMode = CycleMode.datesAndSymptoms,
  });

  final CycleRepository? repository;

  final VoidCallback? onBack;

  /// Continue in dates-and-symptoms mode — on to Y02.
  final VoidCallback? onContinueWithDates;

  /// Continue in symptom-only mode — straight to the hub, which renders Y14.
  final VoidCallback? onContinueSymptomsOnly;

  /// Leaves without writing anything.
  final VoidCallback? onSkip;

  final CycleMode initialMode;

  @override
  State<CycleSetupView> createState() => _CycleSetupViewState();
}

class _CycleSetupViewState extends State<CycleSetupView> {
  late CycleMode _mode = widget.initialMode;
  final Set<CycleContextFlag> _flags = <CycleContextFlag>{};

  CycleRepository? _fallback;

  CycleRepository get _repository =>
      widget.repository ?? (_fallback ??= InMemoryCycleRepository());

  /// The chips, in the order the design draws them.
  static const List<CycleContextFlag> _chipOrder = [
    CycleContextFlag.irregular,
    CycleContextFlag.hormonalContraception,
    CycleContextFlag.perimenopause,
    CycleContextFlag.pregnantOrPostpartum,
    CycleContextFlag.preferNotToSay,
    CycleContextFlag.none,
  ];

  String _chipLabel(AppL10n l10n, CycleContextFlag flag) => switch (flag) {
    CycleContextFlag.irregular => l10n.irregularPeriods,
    CycleContextFlag.hormonalContraception => l10n.hormonalContraception,
    CycleContextFlag.perimenopause => l10n.perimenopause,
    CycleContextFlag.pregnantOrPostpartum => l10n.pregnantOrPostpartum,
    CycleContextFlag.preferNotToSay => l10n.preferNotToSay,
    CycleContextFlag.none => l10n.noneOfThese,
  };

  void _toggleFlag(CycleContextFlag flag) {
    setState(() {
      if (_flags.contains(flag)) {
        _flags.remove(flag);
        return;
      }
      // "None of these" and "Prefer not to say" are answers about the whole
      // question, so they replace the specific ones rather than sitting
      // alongside them.
      if (flag == CycleContextFlag.none ||
          flag == CycleContextFlag.preferNotToSay) {
        _flags
          ..clear()
          ..add(flag);
        return;
      }
      _flags
        ..remove(CycleContextFlag.none)
        ..remove(CycleContextFlag.preferNotToSay)
        ..add(flag);
    });
  }

  Future<void> _continue() async {
    await _repository.completeSetup(mode: _mode, contextFlags: _flags);
    if (!mounted) return;
    if (_mode == CycleMode.datesAndSymptoms) {
      widget.onContinueWithDates?.call();
    } else {
      widget.onContinueSymptomsOnly?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: widget.onBack,
        leadingIcon: Icons.close,
      ),
      footer: [
        AppButton(l10n.continueLabel, onPressed: _continue),
        AppButton(
          l10n.skipSetup,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          // Deliberately not touching the repository. See the library note.
          onPressed: widget.onSkip,
        ),
      ],
      children: [
        Text(l10n.makeItWorkForYou, style: AppText.display),
        Text(
          l10n.youChooseWhatToLogYouCan,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        _ModeCard(
          title: l10n.trackPeriodsAndSymptoms,
          subtitle: l10n.datesBleedingAndHowYouFeel,
          selected: _mode == CycleMode.datesAndSymptoms,
          onTap: () => setState(() => _mode = CycleMode.datesAndSymptoms),
        ),
        _ModeCard(
          title: l10n.trackSymptomsOnly,
          subtitle: l10n.noDatesNoEstimatesJustHowYou,
          selected: _mode == CycleMode.symptomsOnly,
          onTap: () => setState(() => _mode = CycleMode.symptomsOnly),
        ),
        Text(
          l10n.anythingWeShouldKnowOptional,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppChipRow(
          grow: false,
          items: [for (final flag in _chipOrder) _chipLabel(l10n, flag)],
          selected: {
            for (var i = 0; i < _chipOrder.length; i++)
              if (_flags.contains(_chipOrder[i])) i,
          },
          onTap: (i) => _toggleFlag(_chipOrder[i]),
        ),
        // What the app is not, before she starts tracking (APL-12).
        const MedicalDisclaimer(),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: onTap,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Selection is a filled tick as well as a border, so it does not
            // depend on colour alone.
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 26,
              // Unselected takes `outline`, the boundary role, for the same
              // reason the intake answers do: it is a state, not a divider.
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ],
        ),
      ],
    );
  }
}
