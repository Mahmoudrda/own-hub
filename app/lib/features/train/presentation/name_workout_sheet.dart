/// "Save as my workout": a name, then keep it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';

/// Asks for a name over [context] and answers it, or null when she closes the
/// sheet. The name is cleaned by the caller.
Future<String?> askWorkoutName(BuildContext context, {String initial = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.45),
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: _NameSheet(initial: initial),
    ),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});

  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppSheet(
      children: [
        Text(l10n.nameYourWorkout, style: AppText.titleL),
        AppField(
          key: const ValueKey('name-sheet-field'),
          controller: _name,
          label: l10n.workoutName,
          hint: l10n.myWorkout,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        AppButton(
          l10n.save,
          key: const ValueKey('name-sheet-save'),
          onPressed: () => Navigator.of(context).pop(_name.text),
        ),
      ],
    );
  }
}
