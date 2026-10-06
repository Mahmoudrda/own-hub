/// `C01`'s "I have a code from my coach", while the coach app is on.
///
/// A coach who already trains her sends her a code by WhatsApp. She types it
/// here before signing up; it waits on her phone, and nothing about her is sent
/// anywhere until she has passed the women-only check. Then it is redeemed once
/// and the coach finds her enquiry on her desk.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../../coach/domain/coach_invite.dart';

/// Opens the sheet. Answers with the code as stored, or null when she left
/// without one.
Future<String?> showInviteCodeSheet(BuildContext context, {String? initial}) =>
    showAppSheet<String>(
      context: context,
      children: [InviteCodeForm(initial: initial)],
    );

class InviteCodeForm extends StatefulWidget {
  const InviteCodeForm({super.key, this.initial});

  /// A code she saved before, shown so she can see or change it.
  final String? initial;

  @override
  State<InviteCodeForm> createState() => _InviteCodeFormState();
}

class _InviteCodeFormState extends State<InviteCodeForm> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initial == null ? '' : displayInviteCode(widget.initial!),
  );
  bool _wrong = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final code = normaliseInviteCode(_code.text);
    if (code == null) {
      setState(() => _wrong = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.iHaveACodeFromMyCoach, style: AppText.titleL),
        const SizedBox(height: 14),
        AppField(
          controller: _code,
          label: l10n.yourCoachsCode,
          // A code is Latin letters and digits in either language.
          textDirection: TextDirection.ltr,
          errorText: _wrong ? l10n.thatCodeDoesNotLookRightCheck : '',
          onChanged: (_) {
            if (_wrong) setState(() => _wrong = false);
          },
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 14),
        AppButton(l10n.saveTheCode, onPressed: _save),
      ],
    );
  }
}
