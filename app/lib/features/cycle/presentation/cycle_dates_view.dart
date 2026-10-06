/// Y02 — Dates and preferences.
///
/// Matches `screens-cycle.mjs` → `Y02`. Dates are optional and "I don't know" is
/// a first-class answer.
///
/// ## Nothing pre-fills 28 days
///
/// `P0-CYC-01`: "Usual cycle length stays 'Not sure' — nothing pre-fills 28
/// days." The field renders `l10n.notSure` when [CycleDocument.cycleLengthDays]
/// is null, and null is what is saved. The design note is blunt about why: "an
/// invented average becomes a prediction she never gave us the data for."
///
/// ## Sharing is not on this screen
///
/// `savePreferences` takes no sharing parameter, so setup cannot grant a coach
/// anything (C12). The three switches here are `adaptation.*` — what the app
/// suggests *to her* — and are a different thing entirely.
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../domain/cycle_document.dart';
import '../domain/cycle_repository.dart';
import '../domain/period_entry.dart';
import 'cycle_widgets.dart';

class CycleDatesView extends StatefulWidget {
  const CycleDatesView({
    super.key,
    this.repository,
    this.periods,
    this.now,
    this.onBack,
    this.onSaved,
    this.onOpenProfile,
  });

  final CycleRepository? repository;

  /// Writes the optional first period. Y02 saves a start date "in one
  /// transaction, 2 writes" with the document (plan §1.4).
  final PeriodRepository? periods;

  final DateTime? now;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;
  final VoidCallback? onOpenProfile;

  @override
  State<CycleDatesView> createState() => _CycleDatesViewState();
}

class _CycleDatesViewState extends State<CycleDatesView> {
  /// Her last period start, or null for "I don't know".
  DateTime? _lastStart;

  /// Whether the period she is entering is still open.
  bool _stillBleeding = true;

  /// Null means "Not sure". It stays null unless she says otherwise.
  int? _cycleLength;

  late CycleAdaptation _adaptation = CycleAdaptation.y02Defaults;

  DateTime get _today => widget.now ?? AppClock.now();

  Future<void> _save() async {
    final repository = widget.repository;
    if (repository != null) {
      await repository.savePreferences(
        cycleLengthDays: _cycleLength,
        adaptation: _adaptation,
      );

      // The optional first period, validated before anything is written.
      final start = _lastStart;
      final periods = widget.periods;
      if (start != null && periods != null) {
        final result = PeriodEntry.validate(
          start: start,
          end: _stillBleeding ? null : start,
          today: _today,
        );
        if (result is PeriodValid) await periods.save(result.entry);
      }
    }
    if (!mounted) return;
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: l10n.myCycle, onBack: widget.onBack),
      footer: [AppButton(l10n.savePreferences, onPressed: _save)],
      children: [
        Text(l10n.yourDatesIfYouHaveThem, style: AppText.headline),
        AppField(
          label: l10n.lastPeriodStart,
          // Her own date, or nothing. The mockup's "15 September 2026" is a
          // sample and is not rendered as her answer.
          hint: _lastStart == null ? l10n.iDontKnow : isoDay(_lastStart!),
          trailing: const Icon(
            Icons.calendar_month,
            size: 22,
            color: AppColors.primaryDim,
          ),
        ),
        AppChipRow(
          items: [l10n.iDontKnow, l10n.stillBleeding],
          selected: {
            if (_lastStart == null) 0,
            if (_lastStart != null && _stillBleeding) 1,
          },
          onTap: (i) => setState(() {
            if (i == 0) {
              _lastStart = null;
              return;
            }
            _lastStart ??= _today;
            _stillBleeding = !_stillBleeding;
          }),
        ),
        AppField(
          label: l10n.usualCycleLength,
          // "Not sure" until she says otherwise. See the library note.
          hint: _cycleLength == null ? l10n.notSure : '$_cycleLength',
          helper: l10n.countFromTheFirstDayOfOne,
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          children: [
            CycleSwitchRow(
              title: l10n.showWorkoutSuggestions,
              trailing: AppToggle(
                value: _adaptation.workoutSuggestions,
                semanticLabel: l10n.showWorkoutSuggestions,
                onChanged: (v) => setState(
                  () =>
                      _adaptation = _adaptation.copyWith(workoutSuggestions: v),
                ),
              ),
            ),
            CycleSwitchRow(
              title: l10n.showMealSuggestions,
              trailing: AppToggle(
                value: _adaptation.mealSuggestions,
                semanticLabel: l10n.showMealSuggestions,
                onChanged: (v) => setState(
                  () => _adaptation = _adaptation.copyWith(mealSuggestions: v),
                ),
              ),
            ),
            CycleSwitchRow(
              title: l10n.showTheCycleCardOnHome,
              trailing: AppToggle(
                value: _adaptation.homeCard,
                semanticLabel: l10n.showTheCycleCardOnHome,
                onChanged: (v) => setState(
                  () => _adaptation = _adaptation.copyWith(homeCard: v),
                ),
              ),
            ),
          ],
        ),
        AppListItem(
          leading: const Icon(
            Icons.restaurant,
            size: 22,
            color: AppColors.primaryDim,
          ),
          title: l10n.allergiesAndDietaryPreferences,
          subtitle: l10n.alreadySavedEditInYourProfile,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: widget.onOpenProfile,
        ),
      ],
    );
  }
}
