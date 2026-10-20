/// Quick custom: a name and the numbers off the packet, logged as one food.
///
/// Only the name and the kcal are needed. Whatever she leaves blank stays
/// unknown rather than becoming a zero. Not a confirmation: Save and log logs
/// at once, and the usual five seconds to undo follow.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../signup/domain/digits.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';

/// What the sheet hands back.
class QuickCustomEntry {
  const QuickCustomEntry({
    required this.name,
    required this.kcal,
    this.proteinG = 0,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  final String name;
  final int kcal;
  final int proteinG;
  final int? carbsG;
  final int? fatG;
  final int? fiberG;
}

Future<QuickCustomEntry?> showQuickCustomSheet({
  required BuildContext context,
  String initialName = '',
}) {
  return showAppSheet<QuickCustomEntry>(
    context: context,
    children: [QuickCustomPanel(initialName: initialName)],
  );
}

class QuickCustomPanel extends StatefulWidget {
  const QuickCustomPanel({super.key, this.initialName = ''});

  final String initialName;

  @override
  State<QuickCustomPanel> createState() => _QuickCustomPanelState();
}

class _QuickCustomPanelState extends State<QuickCustomPanel> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fibre = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat, _fibre]) {
      c.dispose();
    }
    super.dispose();
  }

  /// A whole number from a box, accepting Arabic digits; null when blank or
  /// not a number.
  static int? _whole(TextEditingController controller) {
    final value = parseLocalNumber(controller.text);
    if (value == null || value < 0 || value > 99999) return null;
    return value.round();
  }

  bool _blank(TextEditingController c) => c.text.trim().isEmpty;

  QuickCustomEntry? get _entry {
    final name = _name.text.trim();
    final kcal = _whole(_kcal);
    if (name.isEmpty || kcal == null) return null;
    // A box with something in it that is not a number is not saved around.
    for (final c in [_protein, _carbs, _fat, _fibre]) {
      if (!_blank(c) && _whole(c) == null) return null;
    }
    return QuickCustomEntry(
      name: name,
      kcal: kcal,
      proteinG: _whole(_protein) ?? 0,
      carbsG: _whole(_carbs),
      fatG: _whole(_fat),
      fiberG: _whole(_fibre),
    );
  }

  Widget _number(String key, TextEditingController c, String label) {
    return AppField(
      key: ValueKey(key),
      controller: c,
      label: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final entry = _entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.quickCustom, style: AppText.titleL),
        const SizedBox(height: 14),
        AppField(
          key: const ValueKey('custom-name'),
          controller: _name,
          label: l10n.foodName,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _number('custom-kcal', _kcal, l10n.kcal)),
            const SizedBox(width: 10),
            Expanded(child: _number('custom-protein', _protein, l10n.protein)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _number('custom-carbs', _carbs, l10n.carbs)),
            const SizedBox(width: 10),
            Expanded(child: _number('custom-fat', _fat, l10n.fat)),
            const SizedBox(width: 10),
            Expanded(child: _number('custom-fibre', _fibre, l10n.fibre)),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
          l10n.saveAndLog,
          key: const ValueKey('custom-save'),
          onPressed: entry == null
              ? null
              : () => Navigator.of(context).pop(entry),
        ),
        SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}
