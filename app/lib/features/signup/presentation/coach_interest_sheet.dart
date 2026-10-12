/// `C01`'s "I coach women", while the coach app is switched off.
///
/// A coach who arrives before coaching opens used to be turned away with
/// nothing captured: `C08`, where she would say so, is skipped while the coach
/// app is off. This is one screen: her name, her city and what she coaches,
/// sent as a message she writes to the team herself. Nothing is stored by the
/// app and nothing leaves the phone until she presses send in WhatsApp or in
/// her mail app. With no team WhatsApp number configured it opens an email to
/// the support mailbox instead (`lib/config/team_contact.dart`).
library;

import 'package:flutter/material.dart';

import '../../../config/team_contact.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../../coach/domain/coach_invite.dart' show whatsAppToUri;

/// The message the form opens, to WhatsApp when the team has a number and to
/// the support mailbox otherwise.
Uri coachInterestUri({
  required String subject,
  required String body,
  String whatsApp = TeamContact.coachWhatsApp,
  String email = TeamContact.supportEmail,
}) => whatsApp.trim().isNotEmpty
    ? whatsAppToUri(whatsApp, body)
    : Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent(subject)}'
            '&body=${Uri.encodeComponent(body)}',
      );

/// Opens the form as a sheet over `C01`.
Future<void> showCoachInterestSheet(
  BuildContext context, {
  required Future<bool> Function(Uri uri) open,
}) => showAppSheet<void>(
  context: context,
  children: [CoachInterestForm(open: open)],
);

class CoachInterestForm extends StatefulWidget {
  const CoachInterestForm({
    super.key,
    required this.open,
    this.whatsApp = TeamContact.coachWhatsApp,
  });

  /// Opens the message outside the app. True when something opened it.
  final Future<bool> Function(Uri uri) open;

  /// The team's number. Empty sends an email instead.
  final String whatsApp;

  @override
  State<CoachInterestForm> createState() => _CoachInterestFormState();
}

class _CoachInterestFormState extends State<CoachInterestForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _specialty = TextEditingController();
  bool _failed = false;
  bool _opening = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _specialty.dispose();
    super.dispose();
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _specialty.text.trim().isNotEmpty;

  Future<void> _send(AppL10n l10n) async {
    setState(() {
      _opening = true;
      _failed = false;
    });
    final uri = coachInterestUri(
      subject: l10n.coachingOnOwnHub,
      body: l10n.iCoachWomenAndWouldLikeTo(
        _name.text.trim(),
        _city.text.trim(),
        _specialty.text.trim(),
      ),
      whatsApp: widget.whatsApp,
    );
    final opened = await widget.open(uri);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _opening = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viaWhatsApp = widget.whatsApp.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.weOpenCoachingSoon, style: AppText.titleL),
        const SizedBox(height: 6),
        Text(
          l10n.tellUsAboutYouAndWeWill,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        AppField(
          controller: _name,
          label: l10n.name,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        AppField(
          controller: _city,
          label: l10n.city,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        AppField(
          controller: _specialty,
          label: l10n.whatYouCoach,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Text(
          _failed
              ? l10n.weCouldNotOpenAMessageOn
              : l10n.thisOpensAMessageToOurTeam,
          style: AppText.bodyM.copyWith(
            color: _failed ? AppColors.amber : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          viaWhatsApp ? l10n.sendOnWhatsapp : l10n.sendByEmail,
          onPressed: _complete && !_opening ? () => _send(l10n) : null,
        ),
      ],
    );
  }
}
