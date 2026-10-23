/// Personalise: her weight, height and age, so the day's targets fit her.
///
/// All three are optional and stay on this phone (D31). Whatever she leaves
/// blank keeps its stated default in the targets.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../signup/domain/digits.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../../onboarding/domain/body_data.dart';

/// Shows the sheet over [current] and returns what she saved, or null.
Future<BodyData?> showPersonaliseSheet({
  required BuildContext context,
  required BodyData current,
}) {
  return showAppSheet<BodyData>(
    context: context,
    children: [PersonalisePanel(current: current)],
  );
}

class PersonalisePanel extends StatefulWidget {
  const PersonalisePanel({super.key, required this.current});

  final BodyData current;

  @override
  State<PersonalisePanel> createState() => _PersonalisePanelState();
}

class _PersonalisePanelState extends State<PersonalisePanel> {
  late final _weight = TextEditingController(
    text: widget.current.weightKg == null ? '' : '${widget.current.weightKg}',
  );
  late final _height = TextEditingController(
    text: widget.current.heightCm == null ? '' : '${widget.current.heightCm}',
  );
  late final _age = TextEditingController(
    text: widget.current.ageYears == null ? '' : '${widget.current.ageYears}',
  );

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  double? _number(TextEditingController c) => parseLocalNumber(c.text);

  /// Null while a filled box holds something outside its range.
  BodyData? get _body {
    final weight = _number(_weight);
    final height = _number(_height);
    final age = _number(_age);
    if (_weight.text.trim().isNotEmpty &&
        (weight == null || !BodyData.weightOk(weight))) {
      return null;
    }
    if (_height.text.trim().isNotEmpty &&
        (height == null || !BodyData.heightOk(height.round()))) {
      return null;
    }
    if (_age.text.trim().isNotEmpty &&
        (age == null || !BodyData.ageOk(age.round()))) {
      return null;
    }
    return BodyData(
      weightKg: weight,
      heightCm: height?.round(),
      ageYears: age?.round(),
    );
  }

  Widget _field(String key, TextEditingController c, String label) => AppField(
    key: ValueKey(key),
    controller: c,
    label: label,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final body = _body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.personalise, style: AppText.titleL),
        const SizedBox(height: 4),
        Text(
          l10n.targetsUseAStandardEstimateAddYour,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _field('personalise-weight', _weight, l10n.weightKg_4v662),
        const SizedBox(height: 10),
        _field('personalise-height', _height, l10n.heightCm),
        const SizedBox(height: 10),
        _field('personalise-age', _age, l10n.ageYears),
        const SizedBox(height: 16),
        AppButton(
          l10n.save,
          key: const ValueKey('personalise-save'),
          onPressed: body == null
              ? null
              : () => Navigator.of(context).pop(body),
        ),
        SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}
