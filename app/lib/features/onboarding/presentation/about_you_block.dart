/// The optional "About you" block on O04: weight, height and age.
///
/// Health data (D31): it is read from and written to [BodyDataStore], which the
/// snapshot keeps on the phone and nothing uploads. Every field is optional, and
/// Skip clears all three.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../signup/domain/digits.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../domain/body_data.dart';

/// Reads a number she typed: Western or Arabic-Indic digits, and a comma or a
/// dot for the decimal point. Null when it is not a number.
double? parseBodyNumber(String raw) => parseLocalNumber(raw);

class AboutYouBlock extends StatefulWidget {
  const AboutYouBlock({super.key, required this.store});

  final BodyDataStore store;

  @override
  State<AboutYouBlock> createState() => AboutYouBlockState();
}

class AboutYouBlockState extends State<AboutYouBlock> {
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _age;
  bool _open = true;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final data = widget.store.read();
    String text(num? v) => v == null
        ? ''
        : (v is double && v == v.roundToDouble() ? '${v.round()}' : '$v');
    _weight = TextEditingController(text: text(data.weightKg));
    _height = TextEditingController(text: text(data.heightCm));
    _age = TextEditingController(text: text(data.ageYears));
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  double? get _weightValue => parseBodyNumber(_weight.text);
  int? get _heightValue => parseBodyNumber(_height.text)?.round();
  int? get _ageValue => parseBodyNumber(_age.text)?.round();

  bool get _weightBad =>
      _weight.text.trim().isNotEmpty &&
      !(_weightValue != null && BodyData.weightOk(_weightValue!));
  bool get _heightBad =>
      _height.text.trim().isNotEmpty &&
      !(_heightValue != null && BodyData.heightOk(_heightValue!));
  bool get _ageBad =>
      _age.text.trim().isNotEmpty &&
      !(_ageValue != null && BodyData.ageOk(_ageValue!));

  /// Saves what she typed. False, with the errors showing, when a number is out
  /// of range, so the caller stays on the screen.
  bool save() {
    if (!_open) {
      widget.store.write(BodyData.empty);
      return true;
    }
    if (_weightBad || _heightBad || _ageBad) {
      setState(() => _showErrors = true);
      return false;
    }
    widget.store.write(
      BodyData(
        weightKg: _weightValue,
        heightCm: _heightValue,
        ageYears: _ageValue,
      ),
    );
    return true;
  }

  void _skip() {
    setState(() {
      _weight.clear();
      _height.clear();
      _age.clear();
      _showErrors = false;
      _open = false;
    });
    widget.store.write(BodyData.empty);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.aboutYou, style: AppText.titleM)),
            AppButton(
              _open ? l10n.skipThis : l10n.aboutYou,
              key: const ValueKey('about-you-toggle'),
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: _open ? _skip : () => setState(() => _open = true),
            ),
          ],
        ),
        if (_open) ...[
          Text(
            l10n.optionalItStaysOnThisPhoneAnd,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          AppField(
            key: const ValueKey('about-you-weight'),
            controller: _weight,
            label: l10n.weightKg_4v662,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            errorText: _showErrors && _weightBad
                ? l10n.betweenMinAndMaxKg(
                    '${BodyData.minWeightKg.round()}',
                    '${BodyData.maxWeightKg.round()}',
                  )
                : '',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          AppField(
            key: const ValueKey('about-you-height'),
            controller: _height,
            label: l10n.heightCm,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            errorText: _showErrors && _heightBad
                ? l10n.betweenMinAndMaxCm(
                    '${BodyData.minHeightCm}',
                    '${BodyData.maxHeightCm}',
                  )
                : '',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          AppField(
            key: const ValueKey('about-you-age'),
            controller: _age,
            label: l10n.ageYears,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            errorText: _showErrors && _ageBad
                ? l10n.betweenMinAndMaxYears(
                    '${BodyData.minAgeYears}',
                    '${BodyData.maxAgeYears}',
                  )
                : '',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }
}
