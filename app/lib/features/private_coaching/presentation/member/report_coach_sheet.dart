/// "Report this profile": a reason, an optional note, then a thank-you. It
/// never says anything about the coach or whether she is looked into.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_chip_row.dart';
import '../../../../ui/app_sheet.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coaching_contract.dart';
import 'coach_labels.dart';

Future<void> showReportCoachSheet({
  required BuildContext context,
  required CoachingRepository repository,
  required String coachUid,
}) => showAppSheet<void>(
  context: context,
  children: [
    ReportCoachForm(repository: repository, coachUid: coachUid),
    const SizedBox(height: 12),
  ],
);

class ReportCoachForm extends StatefulWidget {
  const ReportCoachForm({
    super.key,
    required this.repository,
    required this.coachUid,
  });

  final CoachingRepository repository;
  final String coachUid;

  @override
  State<ReportCoachForm> createState() => _ReportCoachFormState();
}

class _ReportCoachFormState extends State<ReportCoachForm> {
  final TextEditingController _note = TextEditingController();
  String? _reason;
  bool _sending = false;
  bool _failed = false;
  bool _sent = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    final locale = AppL10n.of(context).localeName;
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await widget.repository.reportCoachProfile(
        coachUid: widget.coachUid,
        reason: reason,
        note: _note.text,
        locale: locale.startsWith('ar') ? 'ar' : 'en',
      );
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (_sent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.thankYouWeWillLookAtThis,
              style: AppText.titleL.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.yourReportIsPrivateTheCoachIs,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppButton(l10n.done, onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.whyAreYouReportingThisProfile,
            style: AppText.titleL.copyWith(color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reason in CoachingEnums.reportReasons)
              AppChip(
                reportReasonLabel(l10n, reason),
                selected: _reason == reason,
                onTap: () => setState(() => _reason = reason),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          minLines: 2,
          maxLength: 1000,
          decoration: InputDecoration(labelText: l10n.addANoteOptional),
        ),
        if (_failed)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.weCouldNotSendYourReportTry,
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: 12),
        AppButton(
          l10n.sendReport,
          onPressed: _reason == null || _sending ? null : _send,
        ),
      ],
    );
  }
}
