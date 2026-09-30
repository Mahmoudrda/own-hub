/// P04 — Body, privately.
///
/// Matches `6-v2/src/screens-progress.mjs` → `P04`. The design note names the
/// stakes: *"Weight is optional and says so. Photos are compared side by side
/// and never leave the device unencrypted, because this is the data women are
/// most often burned by."*
///
/// **Half of that note describes a feature this build does not have.** There is
/// no camera path, no photo store and no key: grep `lib/` for encryption and
/// the only hits are comments. So the photo half of P04 is not drawn at all,
/// and this screen makes no claim about photographs. See the `build` method.
///
/// ## Rule 9 — undo, never a confirmation
///
/// Adding a weight or a measurement is a **logging action**, so it goes through
/// [LogCommandBus] like every other one: it saves immediately, offers five
/// seconds to take it back, and asks nothing. There is no `showDialog` and no
/// `AlertDialog` in this file, and both "Add" controls open an inline field
/// rather than a modal — a dialog that asks her to confirm her own weight would
/// be the worst possible place in this product for a confirmation.
///
/// Because the bus holds the write for the undo window, an undone measurement
/// **never reaches storage at all**. There is nothing queued to resurface on
/// reconnect, which is what `P0-RWD-03` checks.
///
/// Both paths share [_BodyPrivatelyViewState._submit], so there is exactly one
/// call to `save()` in this file and it is inside the undo closure. That is not
/// tidiness: `rewards_rules_test.dart` asserts the count, because a second call
/// site is how a write escapes the undo window without anybody noticing.
///
/// G6 §9.15 notes that `P1-RULE-09`'s screen list omits P04 even though this is
/// a logging path. Reported; the behaviour is implemented as though it were
/// listed, because it is.
///
/// ## Rule 11 — displayed, never ranked
///
/// Nothing on this screen sorts, compares or ranks. [MeasurementsRepository]
/// offers `latest()` and `historyForOwner()` and no query method, so there is no
/// call this widget could make that would order women by weight. The chips are
/// laid out in [MeasurementField] declaration order — waist, hips, arm, thigh —
/// which is a fixed reading order and not a ranking: it does not move when her
/// figures do, and there is no comparator anywhere in this file.
///
/// The storage half is the single-field index exemption on
/// `measurements.weightKg`, without which the sort would execute in a deployed
/// project no matter what this file says.
///
/// ## What this screen still cannot do, and does not pretend to
///
/// The measurement chips were display-only until the dictionary gained "Waist",
/// "Hips", "Arm", "Thigh" and the composed `{label} {value} cm`. It has them
/// now, so the Add control is built: the four labels name the form's fields and
/// every chip is rendered from her own figure rather than from the mockup's
/// "Waist 82 cm". The withheld control was the right call while the labels were
/// missing; shipping it now is the same decision, taken with the strings that
/// exist.
///
/// What is still missing is a *measurement* undo sentence. `weightKgSaved`
/// gives the weight path "63.5 kg saved"; there is no "{label} {value} cm
/// saved", so the measurement's undo bar names the figure — "Waist 74 cm" —
/// without the word "saved". It names what she can take back, which is the job;
/// the fuller sentence is a reported dictionary gap.
///
/// The photo store is likewise not built. G6 §9.11 describes what it *will* be:
/// local-only, encrypted with a Keychain/Keystore key, and consequently **not
/// surviving a reinstall and not in A02's export**. None of that exists yet,
/// which is why nothing on this screen mentions photographs. Two placeholder
/// frames badged June and September used to render under the sentence "stored
/// on your phone and encrypted", which told a woman who had never opened a
/// camera that the app was holding her pictures safely.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../../train/domain/weight_label.dart';
import '../domain/progress_repository.dart';

/// The four measurements P04 records, in the order it reads them out.
///
/// A fixed presentation order, and the only order this screen has. There is no
/// comparator, no sort and nothing that reorders when a figure changes — see
/// the library comment on rule 11.
///
/// Each member knows three things: the dictionary label for its field, how to
/// read its figure off a [Measurement], and how to write one. Adding a fifth
/// measurement is a member plus a dictionary key, not a fifth branch in three
/// separate switches.
enum MeasurementField {
  waist,
  hips,
  arm,
  thigh;

  /// The field's name, from the dictionary. Never composed in the widget.
  String label(AppL10n l10n) => switch (this) {
    MeasurementField.waist => l10n.waist,
    MeasurementField.hips => l10n.hips,
    MeasurementField.arm => l10n.arm,
    MeasurementField.thigh => l10n.thigh,
  };

  /// Her figure for this field, or null if she has not recorded one.
  num? valueIn(Measurement? measurement) => switch (this) {
    MeasurementField.waist => measurement?.waistCm,
    MeasurementField.hips => measurement?.hipsCm,
    MeasurementField.arm => measurement?.armCm,
    MeasurementField.thigh => measurement?.thighCm,
  };

  /// A measurement carrying **only** this field.
  ///
  /// Only this one: the document is merged by field on the way in (G8 K6), so
  /// writing a waist must not blank a weight recorded an hour earlier on
  /// another handset. A null is an absence, and an absence does not erase.
  Measurement measurementOf({
    required String dayId,
    required DateTime takenAt,
    required num cm,
  }) => switch (this) {
    MeasurementField.waist => Measurement(
      dayId: dayId,
      takenAt: takenAt,
      waistCm: cm,
    ),
    MeasurementField.hips => Measurement(
      dayId: dayId,
      takenAt: takenAt,
      hipsCm: cm,
    ),
    MeasurementField.arm => Measurement(
      dayId: dayId,
      takenAt: takenAt,
      armCm: cm,
    ),
    MeasurementField.thigh => Measurement(
      dayId: dayId,
      takenAt: takenAt,
      thighCm: cm,
    ),
  };
}

class BodyPrivatelyView extends StatefulWidget {
  const BodyPrivatelyView({
    super.key,
    this.repository,
    this.bus,
    this.now,
    this.onBack,
    this.onLogged,
    this.onSelectTab,
  });

  final MeasurementsRepository? repository;

  /// Shared with Train, Today and Eat in production, so rule 9 has one
  /// implementation rather than one per feature.
  final LogCommandBus? bus;

  /// The clock, injectable so the day key is testable.
  final DateTime? now;

  final VoidCallback? onBack;

  /// The handle for the log she just made, for a caller that wants to show its
  /// own undo affordance.
  final ValueChanged<LogHandle>? onLogged;

  final ValueChanged<String>? onSelectTab;

  @override
  State<BodyPrivatelyView> createState() => _BodyPrivatelyViewState();
}

class _BodyPrivatelyViewState extends State<BodyPrivatelyView> {
  late final MeasurementsRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  final TextEditingController _weight = TextEditingController();
  final TextEditingController _measure = TextEditingController();

  /// Whether the inline weight field is open. A state of this card, never a
  /// route and never a dialog.
  bool _adding = false;

  /// Which measurement the inline form is editing, or null when it is closed.
  /// Same rule as [_adding]: a state of the card, not a screen she navigates to.
  MeasurementField? _field;

  Measurement? _latest;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _ownsBus = widget.bus == null;
    _repo = widget.repository ?? InMemoryMeasurementsRepository();
    _bus = widget.bus ?? LogCommandBus();
    unawaited(_load());
  }

  Future<void> _load() async {
    final latest = await _repo.latest();
    if (!mounted) return;
    setState(() => _latest = latest);
  }

  @override
  void dispose() {
    _weight.dispose();
    _measure.dispose();
    if (_ownsBus) _bus.dispose();
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  DateTime get _now => widget.now ?? DateTime.now();

  /// `yyyy-MM-dd` in her timezone — the document id (spine C1).
  String get _dayId {
    final at = _now;
    final month = at.month.toString().padLeft(2, '0');
    final day = at.day.toString().padLeft(2, '0');
    return '${at.year}-$month-$day';
  }

  /// The one logging path on this screen.
  ///
  /// [measurement] carries only the field she just entered, because the document
  /// is merged by field. [describe] is the undo bar's text and must name the
  /// figure she can still take back — "63.5 kg saved", "Waist 74 cm" — never a
  /// bare "Saved", which is true of every measurement and tells her nothing.
  void _submit(
    Measurement measurement, {
    required String describe,
    required String undoLabel,
  }) {
    setState(() {
      // Shown immediately, at full opacity, before anything is written — it is
      // her own private document and it is not waiting on a network. Merged
      // rather than replaced so adding a waist does not take a weight off the
      // screen that is still perfectly true.
      final latest = _latest;
      _latest = latest == null || latest.dayId != measurement.dayId
          ? measurement
          : latest.mergedWith(measurement);
    });

    final handle = _bus.submit(
      UndoableLog(describe: describe, commit: () => _repo.save(measurement)),
    );

    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: undoLabel,
      onUndo: () {
        if (!mounted) return;
        // The write never left the bus, so there is nothing to roll back —
        // only the optimistic row to take off the screen.
        unawaited(_load());
      },
    );

    widget.onLogged?.call(handle);
  }

  void _saveWeight(AppL10n l10n) {
    final kg = double.tryParse(_weight.text.trim());
    // Nothing usable typed. Closing the field is the whole response: there is no
    // error string for this in either language, and inventing one would be the
    // same defect as inventing a number.
    if (kg == null || kg <= 0) {
      setState(() {
        _adding = false;
        _weight.clear();
      });
      return;
    }

    setState(() {
      _adding = false;
      _weight.clear();
    });

    _submit(
      Measurement(dayId: _dayId, takenAt: _now, weightKg: kg),
      // Names the weight she can still take back, in Western digits with the
      // trailing ".0" dropped — "63 kg saved", never "63.0 kg saved".
      describe: l10n.weightKgSaved(weightLabel(kg)),
      undoLabel: l10n.undo,
    );
  }

  void _saveMeasurement(AppL10n l10n) {
    final field = _field;
    final cm = double.tryParse(_measure.text.trim());

    // Same silence as the weight field: nothing usable typed closes the form and
    // says nothing, because there is no error string to say it with.
    if (field == null || cm == null || cm <= 0) {
      setState(() {
        _field = null;
        _measure.clear();
      });
      return;
    }

    setState(() {
      _field = null;
      _measure.clear();
    });

    _submit(
      field.measurementOf(dayId: _dayId, takenAt: _now, cm: cm),
      // "Waist 74 cm" — the chip she just made, so the undo bar and the screen
      // say the same thing.
      describe: l10n.labelValueCm(field.label(l10n), weightLabel(cm)),
      undoLabel: l10n.undo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.bodyPrivately,
        onBack: widget.onBack,
        actions: const [
          // Not a control: the padlock states what the screen is. There is
          // nothing to toggle, because it is private to her unconditionally.
          Padding(
            // Directional: in Arabic the bar mirrors, and `right` pinned the
            // padding to the physical right edge on a screen that reads the
            // other way.
            padding: EdgeInsetsDirectional.only(end: 8),
            child: Icon(
              Icons.lock,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'P04',
        onSelect: (id) {
          final onTab = widget.onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: [
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.visibility_off,
                    size: 24,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    // "Nobody sees this. Not the community, not your coach
                    // unless you send it." is true and names two things this
                    // build does not have, which on the most private screen
                    // in the product reads as a promise about rooms she
                    // cannot find. Same promise, only what exists.
                    child: Text(
                      AppRouter.featureFlags.isOn(Feature.community) ||
                              AppRouter.featureFlags.isOn(Feature.coachedLife)
                          ? l10n.nobodySeesThisNotTheCommunityNot
                          : l10n.onlyYouCanSeeWhatYouSaved,
                      style: AppText.bodyM,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _weightCard(l10n),
          _measurementsCard(l10n),
          // The photo-compare card is not drawn, and the decision is the same
          // one `safety_centre_view.dart` and `privacy_view.dart` take for the
          // community: a screen does not describe a room the build does not
          // have. There is no capture path in this app, no photo store and no
          // key (`account_data.dart:destroyPhotoStoreKey` says so outright), so
          // the card drew two placeholder frames badged June and September for
          // a woman who has never taken a photo, under the sentence "stored on
          // your phone and encrypted". Nothing in `lib/` encrypts anything.
          //
          // It comes back with the capture path, not before.
        ],
      ),
    );
  }

  Widget _weightCard(AppL10n l10n) {
    return AppCard(
      gap: 8,
      children: [
        AppSplitRow(
          start: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.weight, style: AppText.titleM),
              const SizedBox(height: 3),
              Text(
                l10n.optionalYouCanUseTheAppForever,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          end: _adding
              ? const SizedBox.shrink()
              : AppButton(
                  l10n.add,
                  variant: AppButtonVariant.tonal,
                  height: 40,
                  fontSize: 15,
                  onPressed: () => setState(() => _adding = true),
                ),
        ),
        if (_adding) ...[
          AppField(
            controller: _weight,
            label: l10n.weight,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveWeight(l10n),
          ),
          _saveOrCancel(
            l10n,
            onSave: () => _saveWeight(l10n),
            onCancel: () => setState(() {
              _adding = false;
              _weight.clear();
            }),
          ),
        ],
      ],
    );
  }

  /// Waist, hips, arm and thigh — displayed, never ranked.
  ///
  /// Every chip is `{label} {value} cm` built from her own figure, so there is
  /// no sentence here that could be true of somebody else. A field she has not
  /// recorded has no chip at all: an absence is an absence, not a zero.
  Widget _measurementsCard(AppL10n l10n) {
    final latest = _latest;
    final open = _field;

    final chips = <Widget>[
      for (final field in MeasurementField.values)
        if (field.valueIn(latest) case final num cm)
          AppChip(l10n.labelValueCm(field.label(l10n), weightLabel(cm))),
      // The prototype's third chip. Opens the form below rather than a dialog,
      // and defaults to the first field for the same reason the chips are in
      // declaration order: something has to be selected, and the choice must not
      // depend on her figures.
      if (open == null)
        AppChip(
          l10n.add,
          icon: Icons.add,
          onTap: () => setState(() => _field = MeasurementField.waist),
        ),
    ];

    return AppCard(
      gap: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.measurements, style: AppText.titleM),
            const SizedBox(height: 3),
            Text(
              l10n.waistHipsArmEvery4WeeksIs,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        // Wrap, not Row. "Waist 82 cm" and "Hips 96 cm" side by side overflow
        // a 390pt phone by 66 pixels in English at the default text size, and
        // Arabic at the largest accessibility size is wider still. A chip that
        // will not fit moves to a second line instead of being clipped, which
        // is what the prototype's flex row does and a Flutter Row does not.
        if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: chips),
        if (open != null) ...[
          // Which measurement she is entering. A single-choice row, wrapped
          // rather than grown: four Arabic labels at the largest text size do
          // not fit one line, and an option she cannot see is an option she
          // does not have.
          AppChipRow(
            items: [
              for (final field in MeasurementField.values) field.label(l10n),
            ],
            selected: {open.index},
            grow: false,
            onTap: (i) => setState(() => _field = MeasurementField.values[i]),
          ),
          AppField(
            controller: _measure,
            // The field she picked names the field she is filling in.
            label: open.label(l10n),
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveMeasurement(l10n),
          ),
          _saveOrCancel(
            l10n,
            onSave: () => _saveMeasurement(l10n),
            onCancel: () => setState(() {
              _field = null;
              _measure.clear();
            }),
          ),
        ],
      ],
    );
  }

  /// The two buttons both inline forms end with.
  ///
  /// Cancel is an outlined button beside Save, never a dialog's "are you sure" —
  /// it closes the field and writes nothing, which is the whole of it.
  Widget _saveOrCancel(
    AppL10n l10n, {
    required VoidCallback onSave,
    required VoidCallback onCancel,
  }) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            l10n.save,
            height: 48,
            fontSize: 15,
            onPressed: onSave,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton(
            l10n.cancel,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: onCancel,
          ),
        ),
      ],
    );
  }

}
