/// Y04 — How are you feeling? The daily check-in sheet.
///
/// Matches `screens-cycle.mjs` → `Y04`. Three taps, all optional.
///
/// ## Nothing is carried over from yesterday
///
/// `P0-CYC-04`: "Every chip starts unselected — yesterday's severe cramps do not
/// prefill today." The sheet's initial state is [TodayCheckIn.absent] and there
/// is **no parameter on this widget that could carry yesterday's document** —
/// §3.3: "a diary that assumes continuity has stopped being a diary, and a
/// carried-over severe symptom would suppress a workout on a day she feels
/// fine."
///
/// ## Severe shows immediately and writes nothing
///
/// §3.3: "Selecting 'Severe' on Y04 shows the Y11 content immediately but writes
/// nothing until Save. An unsaved severe selection is `severeSelectedUnsaved`, a
/// sheet-local flag; backing out stores nothing and leaves the day at
/// `noCheckIn`. Persisting a symptom she did not save would be a lie in a
/// symptom diary."
///
/// So [severeSelectedUnsaved] is local state, and [onCancel] discards it.
///
/// ## "More to log", and the half of the severe gate it reaches
///
/// The design puts sleep, bloating and bleeding behind "More to log". These
/// controls were withheld while `Sleep`, `Bloating`, `Bleeding`, `Spotting`,
/// `Heavy`, `Poor` and `Good` returned zero matches against `app_en.arb` —
/// inventing them would have put untranslated English in front of an Arabic
/// reader. **All seven now exist in both dictionaries**, so the controls are
/// built.
///
/// The consequence is the reason this mattered. `SevereSymptomGate` fires on
/// `cramps == severe` **or `bleeding == heavy`**, and with no bleeding control
/// the second half of that gate was unreachable from the interface: the domain
/// implemented it and `P0-CYC-06` could only be entered through cramps. The
/// bleeding row below closes that gap, and `check_in_view_test.dart` proves it
/// end to end — heavy bleeding logged here produces a [TodayCheckIn] the gate
/// accepts, and the hub renders Y11 with no workout anywhere on it.
///
/// ## What is still withheld, and why
///
/// Three enum values have no word: `Sleep.ok`, and `Bleeding.light` and
/// `Bleeding.medium`. A row offering Poor and Good with a silent gap where
/// "Okay" belongs is honest about what it can say; a chip labelled with an
/// invented word is not. So the rows show the values the dictionary can name,
/// and the rest are reported rather than guessed. Nothing here is rendered
/// inert — `PHASE1-FIXES.md` #10 and #12 record three screens whose controls
/// looked tappable and did nothing.
///
/// ## Why every chip writes through `copyWith`
///
/// The three original rows each rebuilt the draft with a fresh `TodayCheckIn`
/// naming only energy, cramps and appetite. That was invisible while nothing
/// else could be logged; the moment bleeding could be, tapping an energy chip
/// afterwards would silently drop it — and dropping `bleeding == heavy` drops
/// the suppression with it. `copyWith` keeps what she logged, and the test
/// named "a value logged behind More to log survives a later tap" is the one
/// that fails if anyone reverts this.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/severe_symptom_gate.dart';
import '../domain/today_check_in.dart';

class CheckInView extends StatefulWidget {
  const CheckInView({
    super.key,
    this.onSaved,
    this.onCancel,
    this.gate = const SevereSymptomGate(),
  });

  /// Hands up what she chose. The write is G3's — `checkins/{yyyy-MM-dd}` is
  /// their document and this feature must not write it directly (OQ-3).
  final ValueChanged<TodayCheckIn>? onSaved;

  final VoidCallback? onCancel;

  final SevereSymptomGate gate;

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  /// Starts empty. Always. See the library note.
  TodayCheckIn _draft = TodayCheckIn.absent;

  /// §3.3's `severeSelectedUnsaved` — shown immediately, stored never.
  bool get severeSelectedUnsaved => widget.gate.evaluate(_draft);

  static const List<Energy> _energies = [Energy.low, Energy.ok, Energy.high];
  static const List<Cramps> _cramps = [
    Cramps.none,
    Cramps.mild,
    Cramps.moderate,
    Cramps.severe,
  ];
  static const List<Appetite> _appetites = [
    Appetite.low,
    Appetite.ok,
    Appetite.high,
  ];

  /// `Sleep.ok` is absent: the dictionary has `Poor` and `Good` and no word for
  /// the middle. Two honest chips beat three with one invented.
  static const List<Sleep> _sleeps = [Sleep.poor, Sleep.good];

  /// Bloating reuses the four severity words the cramps row already owns, so
  /// `Bloating.moderate` — the third thing `gentlerOffered` listens for — is
  /// reachable without a new string.
  static const List<Bloating> _bloatings = [
    Bloating.none,
    Bloating.mild,
    Bloating.moderate,
    Bloating.severe,
  ];

  /// **This row is the second half of §2.5's gate.** `Bleeding.light` and
  /// `Bleeding.medium` have no words yet and are absent; `heavy` has one, and
  /// with it `SevereSymptomGate` can finally be reached by bleeding.
  static const List<Bleeding> _bleedings = [Bleeding.spotting, Bleeding.heavy];

  /// Whether "More to log" is open. Closed on every new sheet, like every chip.
  bool _showMore = false;

  /// The chip index for a stored value, or null when nothing is stored — and
  /// null too when the stored value has no chip, which is the state a woman
  /// whose document holds `Sleep.ok` is in. `indexOf` returns -1 there, and -1
  /// would light up the last chip in the row.
  static int? _indexIn<T>(List<T> options, T? value) {
    if (value == null) return null;
    final index = options.indexOf(value);
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: widget.onCancel,
        leadingIcon: Icons.close,
      ),
      footer: [
        AppButton(
          l10n.saveCheckIn,
          onPressed: () => widget.onSaved?.call(_draft),
        ),
        AppButton(
          l10n.skip,
          variant: AppButtonVariant.text,
          height: 40,
          fontSize: 15,
          // Discards the draft, including an unsaved severe selection.
          onPressed: widget.onCancel,
        ),
      ],
      children: [
        Text(l10n.howAreYouFeeling, style: AppText.titleL),
        Text(
          l10n.howAreYouFeelingToday,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        _Group(
          label: l10n.energy,
          items: [l10n.low, l10n.okay, l10n.high],
          selectedIndex: _indexIn(_energies, _draft.energy),
          onTap: (i) =>
              setState(() => _draft = _draft.copyWith(energy: _energies[i])),
        ),
        _Group(
          label: l10n.cramps,
          items: [l10n.none, l10n.mild, l10n.moderate, l10n.severe],
          selectedIndex: _indexIn(_cramps, _draft.cramps),
          onTap: (i) =>
              setState(() => _draft = _draft.copyWith(cramps: _cramps[i])),
        ),
        _Group(
          label: l10n.appetite,
          items: [l10n.lessHungry, l10n.usual, l10n.moreHungry],
          selectedIndex: _indexIn(_appetites, _draft.appetite),
          onTap: (i) =>
              setState(() => _draft = _draft.copyWith(appetite: _appetites[i])),
        ),
        // "More to log: sleep, bloating, bleeding". Closed by default, as the
        // design draws it: three taps are the sheet, and the rest is there for
        // the day she wants it.
        AppButton(
          l10n.moreToLogSleepBloatingBleeding,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          icon: _showMore ? Icons.expand_less : Icons.expand_more,
          onPressed: () => setState(() => _showMore = !_showMore),
        ),
        if (_showMore) ...[
          _Group(
            label: l10n.sleep,
            items: [l10n.poor, l10n.good],
            selectedIndex: _indexIn(_sleeps, _draft.sleep),
            onTap: (i) =>
                setState(() => _draft = _draft.copyWith(sleep: _sleeps[i])),
          ),
          _Group(
            label: l10n.bloating,
            items: [l10n.none, l10n.mild, l10n.moderate, l10n.severe],
            selectedIndex: _indexIn(_bloatings, _draft.bloating),
            onTap: (i) => setState(
              () => _draft = _draft.copyWith(bloating: _bloatings[i]),
            ),
          ),
          // Heavy here is severe. The note below appears the instant she taps
          // it, exactly as it does for severe cramps, and nothing is written
          // until Save either way.
          _Group(
            label: l10n.bleeding,
            items: [l10n.spotting, l10n.heavy],
            selectedIndex: _indexIn(_bleedings, _draft.bleeding),
            onTap: (i) => setState(
              () => _draft = _draft.copyWith(bleeding: _bleedings[i]),
            ),
          ),
        ],
        if (severeSelectedUnsaved)
          Text(
            l10n.severeOrUnusualPainDeservesMedicalAdvice,
            style: AppText.bodyM.copyWith(color: AppColors.error),
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final String label;
  final List<String> items;
  final int? selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        AppChipRow(items: items, selected: {?selectedIndex}, onTap: onTap),
      ],
    );
  }
}
