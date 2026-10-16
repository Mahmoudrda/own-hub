/// Y12 — Cycle settings and sharing.
///
/// Matches `screens-cycle.mjs` → `Y12`. Three adaptation switches, three sharing
/// switches, and the deletion.
///
/// ## The sharing switches
///
/// `P0-CYC-13`: "All three start off. Turning one on leaves the other two off.
/// The preview states exactly what the coach would see. Coaching never required
/// any of them."
///
/// Independence is structural — `CycleSharing.grant` copies the other two
/// through — so this screen cannot couple them by accident. Each switch calls
/// `CycleRepository.setSharing`, which is the only way one is ever turned on.
///
/// ## The preview is computed, not written
///
/// The design's preview is the fixed sentence "Sara would see: energy low,
/// appetite usual, and 'client selected a lighter session'." That names a coach
/// who may not be hers and states values that are the mockup's — the defect
/// class `PHASE1-FIXES.md` #13 records four times over.
///
/// So the preview here is **derived from the switches that are actually on**,
/// listing those categories by name, and says `notShared` when none are. It
/// tells her the truth about her own settings rather than reciting a sample.
///
/// ## The deletion asks in place
///
/// [CycleDeletion] drives an inline `confirming` state rather than a dialog.
/// `product_rules_test.dart`'s rule-9 guard fails the build on any `showDialog`
/// under `lib/features/`, and the destructive exemption G7 recorded is an
/// argument about this one action, not a licence to put a dialog in the feature
/// that owns the most sensitive data in the product.
///
/// **What it cannot yet say.** Y12 must state "what was deleted and what was
/// kept" — the check-ins survive, because they are G3's and hold energy, sleep
/// and appetite the rest of the app uses. G9 OQ-8 is explicit that the copy and
/// its Arabic "must not be invented", and the dictionary has only "Delete cycle
/// data". So the confirming state offers the action and no explanation, and
/// `P0-CYC-16` cannot fully pass.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../domain/cycle_document.dart';
import '../domain/cycle_repository.dart';
import '../domain/cycle_sharing_policy.dart';
import 'cycle_deletion_machine.dart';
import 'cycle_widgets.dart';

class CycleSettingsView extends StatefulWidget {
  const CycleSettingsView({
    super.key,
    required this.cycle,
    this.repository,
    this.relId,
    this.onBack,
    this.onChangeMode,
    this.onSymptomOnly,
    this.onDeleted,
    this.onSelectTab,
    this.onAdaptationChanged,
  });

  final CycleDocument? cycle;
  final CycleRepository? repository;

  /// The active coaching relationship, or null when she has no coach.
  ///
  /// A sharing switch cannot be turned on without one: a grant that is not
  /// bound to a relationship is a grant the next coach inherits (OQ-2).
  final String? relId;

  final VoidCallback? onBack;
  final VoidCallback? onChangeMode;
  final VoidCallback? onSymptomOnly;
  final VoidCallback? onDeleted;
  final ValueChanged<String>? onSelectTab;

  /// Fired after an adaptation switch has been written, so whatever reads it
  /// elsewhere — Home's cycle card — can follow.
  final VoidCallback? onAdaptationChanged;

  @override
  State<CycleSettingsView> createState() => _CycleSettingsViewState();
}

class _CycleSettingsViewState extends State<CycleSettingsView> {
  CycleDeletion _deletion = const CycleDeletion();

  CycleDocument? get _cycle => widget.repository?.current ?? widget.cycle;

  Future<void> _setAdaptation(CycleAdaptation next) async {
    await widget.repository?.setAdaptation(next);
    if (!mounted) return;
    setState(() {});
    widget.onAdaptationChanged?.call();
  }

  Future<void> _setSharing(CycleCategory category, bool on) async {
    final relId = widget.relId;
    // No relationship, no grant. The control is disabled rather than throwing.
    if (relId == null) return;
    await widget.repository?.setSharing(
      category: category,
      on: on,
      relId: relId,
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete() async {
    setState(() => _deletion = _deletion.confirmed());
    await widget.repository?.purge();
    if (!mounted) return;
    setState(() => _deletion = _deletion.localPurged().markRemotePurged());
    widget.onDeleted?.call();
  }

  bool _isOn(CycleCategory category) {
    final sharing = _cycle?.sharing ?? CycleSharing.off;
    return switch (category) {
      CycleCategory.energyAppetite => sharing.energyAppetite,
      CycleCategory.symptoms => sharing.symptoms,
      CycleCategory.datesAndPatterns => sharing.datesAndPatterns,
    };
  }

  String _categoryLabel(AppL10n l10n, CycleCategory category) =>
      switch (category) {
        CycleCategory.energyAppetite => l10n.energyAndAppetite,
        CycleCategory.symptoms => l10n.cycleSymptoms,
        CycleCategory.datesAndPatterns => l10n.periodDatesAndPatterns,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final adaptation = _cycle?.adaptation ?? CycleAdaptation.allOff;

    final on = [
      for (final category in CycleCategory.values)
        if (_isOn(category)) _categoryLabel(l10n, category),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CycleNavBar(
        screenId: 'Y12',
        onSelectTab: widget.onSelectTab,
      ),
      appBar: AppTopBar(title: l10n.cycleSettings, onBack: widget.onBack),
      body: AppScaffold(
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              CycleSwitchRow(
                title: l10n.showTheCycleCardOnHome,
                trailing: AppToggle(
                  value: adaptation.homeCard,
                  semanticLabel: l10n.showTheCycleCardOnHome,
                  onChanged: (v) =>
                      _setAdaptation(adaptation.copyWith(homeCard: v)),
                ),
              ),
              CycleSwitchRow(
                title: l10n.workoutSuggestions,
                trailing: AppToggle(
                  value: adaptation.workoutSuggestions,
                  semanticLabel: l10n.workoutSuggestions,
                  onChanged: (v) => _setAdaptation(
                    adaptation.copyWith(workoutSuggestions: v),
                  ),
                ),
              ),
              CycleSwitchRow(
                title: l10n.mealSuggestions,
                trailing: AppToggle(
                  value: adaptation.mealSuggestions,
                  semanticLabel: l10n.mealSuggestions,
                  onChanged: (v) =>
                      _setAdaptation(adaptation.copyWith(mealSuggestions: v)),
                ),
              ),
            ],
          ),
          // Cycle sharing is a grant to a coach. The first release has no
          // coaching, so this card offered five switches that could reach
          // nobody, under a heading naming a person she cannot have. It is
          // her most sensitive data and the switches are already off by
          // default; the honest rendering is not to draw them.
          if (AppRouter.featureFlags.isOn(Feature.coachedLife))
            AppCard(
              variant: AppCardVariant.sage,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              children: [
                Text(l10n.shareWithMyCoach, style: AppText.titleM),
                Text(
                  l10n.offByDefaultCoachingNeverRequiresIt,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                for (final category in CycleCategory.values)
                  CycleSwitchRow(
                    title: _categoryLabel(l10n, category),
                    trailing: AppToggle(
                      value: _isOn(category),
                      semanticLabel: _categoryLabel(l10n, category),
                      // Null with no relationship: the switch still renders its
                      // state, because one she is not allowed to change is
                      // different from one that is off.
                      onChanged: widget.relId == null
                          ? null
                          : (v) => _setSharing(category, v),
                    ),
                  ),
                // The preview, derived from what is actually on. See the note.
                Text(
                  on.isEmpty ? l10n.notShared : on.join(' · '),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          AppListItem(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: const Icon(
              Icons.edit,
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: l10n.changeHowYouUseMyCycle,
            subtitle: l10n.datesAndSymptomsOrSymptomsOnly,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: widget.onChangeMode,
          ),
          AppListItem(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: const Icon(
              Icons.visibility_off,
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: l10n.symptomOnlyMode,
            subtitle: l10n.noDatesNoEstimates,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: widget.onSymptomOnly,
          ),
          // Deleting is kept apart and named, so it is never a stray tap on
          // the way to a switch.
          AppCard(
            variant: AppCardVariant.error,
            children: [
              Text(
                l10n.dangerZone,
                style: AppText.titleM.copyWith(color: AppColors.error),
              ),
              if (_deletion.state == CycleDeletionState.confirming)
                // Asks in place. No dialog — see the library note.
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        l10n.deleteCycleData,
                        height: 44,
                        fontSize: 15,
                        onPressed: _confirmDelete,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        l10n.cancel,
                        variant: AppButtonVariant.outlined,
                        height: 44,
                        fontSize: 15,
                        onPressed: () =>
                            setState(() => _deletion = _deletion.cancelled()),
                      ),
                    ),
                  ],
                )
              else
                AppButton(
                  l10n.deleteCycleData,
                  variant: AppButtonVariant.outlined,
                  height: 44,
                  fontSize: 15,
                  onPressed: () =>
                      setState(() => _deletion = _deletion.requested()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
