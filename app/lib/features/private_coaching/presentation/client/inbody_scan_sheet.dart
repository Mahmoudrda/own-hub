/// Her InBody result sheet: she chooses a photo or a screenshot, the phone
/// reads it, and every number lands in a form she checks against the paper.
/// Typing the numbers is the same form. Nothing leaves the sheet until she
/// confirms, and the picture is never sent or kept.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_sheet.dart';
import '../../../signup/domain/digits.dart';
import '../../data/inbody_ocr.dart';
import '../../domain/inbody_scan.dart';

/// Where the numbers are going, which decides what she is asked for and what
/// she is told about them.
enum InBodyMode {
  /// Her own targets on this phone: weight and height only.
  forTargets,

  /// The request to her coach: weight, body fat, muscle and metabolic rate,
  /// sent only if she ticks the box.
  forCoach,
}

/// Shows the sheet and returns what she confirmed, or null.
Future<InBodyScan?> showInBodyScanSheet({
  required BuildContext context,
  required InBodyMode mode,
  InBodyOcr? ocr,
}) => showAppSheet<InBodyScan>(
  context: context,
  children: [InBodyScanSheet(mode: mode, ocr: ocr)],
);

enum _Phase { pick, reading, confirm }

class InBodyScanSheet extends StatefulWidget {
  const InBodyScanSheet({super.key, required this.mode, this.ocr});

  final InBodyMode mode;

  /// Null reads with the phone's own text recognition.
  final InBodyOcr? ocr;

  @override
  State<InBodyScanSheet> createState() => _InBodyScanSheetState();
}

class _InBodyScanSheetState extends State<InBodyScanSheet> {
  final Map<InBodyField, TextEditingController> _c = {
    for (final f in InBodyField.values) f: TextEditingController(),
  };
  late final InBodyOcr _ocr = widget.ocr ?? MlKitInBodyOcr();

  _Phase _phase = _Phase.pick;
  InBodyReading _reading = InBodyReading.none;
  bool _fromPhoto = false;

  /// A picture was read and held nothing: say so, and offer another.
  bool _unreadable = false;

  List<InBodyField> get _shown => widget.mode == InBodyMode.forCoach
      ? const [
          InBodyField.weight,
          InBodyField.bodyFat,
          InBodyField.muscle,
          InBodyField.bmr,
        ]
      : const [InBodyField.weight, InBodyField.height];

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() => _phase = _Phase.reading);
    final text = await _ocr.readPhoto();
    if (!mounted) return;
    final reading = text == null ? null : InBodyReader.read(text);
    setState(() {
      if (reading == null || reading.scan.isEmpty) {
        _unreadable = reading != null;
        _phase = _Phase.pick;
        return;
      }
      _unreadable = false;
      _reading = reading;
      _fromPhoto = true;
      final scan = reading.scan;
      _set(InBodyField.weight, scan.weightKg);
      _set(InBodyField.height, scan.heightCm);
      _set(InBodyField.bodyFat, scan.bodyFatPercent);
      _set(InBodyField.muscle, scan.skeletalMuscleMassKg);
      _set(InBodyField.bmr, scan.bmrKcal?.toDouble());
      _phase = _Phase.confirm;
    });
  }

  void _set(InBodyField field, double? value) => _c[field]!.text = value == null
      ? ''
      : (value == value.roundToDouble()
            ? value.round().toString()
            : value.toStringAsFixed(1));

  /// Null when empty, [double.nan] when filled with something unusable.
  double? _value(InBodyField field) {
    final text = _c[field]!.text.trim();
    if (text.isEmpty) return null;
    final v = parseLocalNumber(text);
    return v != null && InBodyRanges.contains(field, v) ? v : double.nan;
  }

  bool get _ready =>
      _shown.any((f) => _value(f) != null) &&
      _shown.every((f) => _value(f)?.isNaN != true);

  void _confirm() {
    double? v(InBodyField f) => _shown.contains(f) ? _value(f) : null;
    Navigator.of(context).pop(
      InBodyScan(
        weightKg: v(InBodyField.weight),
        heightCm: v(InBodyField.height),
        bodyFatPercent: v(InBodyField.bodyFat),
        skeletalMuscleMassKg: v(InBodyField.muscle),
        bmrKcal: v(InBodyField.bmr)?.round(),
      ),
    );
  }

  String _label(AppL10n l10n, InBodyField f) => switch (f) {
    InBodyField.weight => l10n.weightKg_4v662,
    InBodyField.height => l10n.heightCm,
    InBodyField.bodyFat => l10n.bodyFat,
    InBodyField.muscle => l10n.muscleSmmKg,
    InBodyField.bmr => l10n.bmrKcal,
  };

  String _key(InBodyField f) => switch (f) {
    InBodyField.weight => 'inbody-weight-field',
    InBodyField.height => 'inbody-height-field',
    InBodyField.bodyFat => 'inbody-fat-field',
    InBodyField.muscle => 'inbody-smm-field',
    InBodyField.bmr => 'inbody-bmr-field',
  };

  Widget _field(AppL10n l10n, InBodyField f) => AppField(
    key: ValueKey(_key(f)),
    controller: _c[f],
    label: _label(l10n, f),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    errorText: _value(f)?.isNaN == true
        ? l10n.checkThisNumberItLooksOutsideThe
        : '',
    onChanged: (_) => setState(() {}),
  );

  Widget _title(String text) => Semantics(
    header: true,
    child: Text(text, style: AppText.titleL.copyWith(color: AppColors.ink)),
  );

  Text _body(String text) => Text(
    text,
    style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return switch (_phase) {
      _Phase.pick => _pick(l10n),
      _Phase.reading => _readingView(l10n),
      _Phase.confirm => _confirmView(l10n),
    };
  }

  Widget _pick(AppL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(l10n.yourInbodySheet),
      const SizedBox(height: 6),
      if (_unreadable) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.weCouldNotReadNumbersFromThat,
            key: const ValueKey('inbody-unreadable'),
            style: AppText.bodyM.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 6),
      ],
      _body(l10n.chooseAPhotoOrScreenshotOfYour),
      const SizedBox(height: 16),
      AppButton(
        _unreadable ? l10n.chooseAnotherPhoto : l10n.chooseAPhoto,
        key: const ValueKey('inbody-choose'),
        onPressed: _choose,
      ),
      const SizedBox(height: 8),
      AppButton(
        l10n.typeTheNumbersInstead,
        key: const ValueKey('inbody-type'),
        variant: AppButtonVariant.text,
        onPressed: () => setState(() => _phase = _Phase.confirm),
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _readingView(AppL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: _title(l10n.readingYourSheet)),
      const SizedBox(height: 24),
    ],
  );

  Widget _confirmView(AppL10n l10n) {
    final notes = <String>[
      if (_reading.checks.contains(InBodyCheck.weightFromPounds))
        l10n.yourSheetShowsPoundsSoTheWeight,
      if (_reading.checks.contains(InBodyCheck.bmiDisagrees))
        l10n.weightHeightAndBmiOnYourSheet,
      if (_reading.checks.contains(InBodyCheck.compositionDisagrees))
        l10n.weightFatAndLeanMassOnYour,
    ];
    final fields = _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(l10n.checkYourNumbers),
        const SizedBox(height: 6),
        _body(
          _fromPhoto
              ? l10n.weReadTheseFromYourSheetCheck
              : l10n.typeTheNumbersFromYourSheetLeave,
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final note in notes)
                  Text(
                    note,
                    key: const ValueKey('inbody-note'),
                    style: AppText.bodyM.copyWith(color: AppColors.ink),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < fields.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field(l10n, fields[i])),
              if (i + 1 < fields.length) ...[
                const SizedBox(width: 12),
                Expanded(child: _field(l10n, fields[i + 1])),
              ] else
                const Spacer(),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _body(
          widget.mode == InBodyMode.forCoach
              ? l10n.yourCoachSeesTheseNumbersOnlyIf
              : l10n.yourWeightAndHeightStayOnThis,
        ),
        const SizedBox(height: 12),
        AppButton(
          l10n.confirmTheseNumbers,
          key: const ValueKey('inbody-confirm-btn'),
          onPressed: _ready ? _confirm : null,
        ),
        SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}
