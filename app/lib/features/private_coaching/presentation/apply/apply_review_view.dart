/// The last page before sending: every part summarised, anything missing
/// flagged, and the send with its progress and retry.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/coach_application_draft.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_scaffold.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_application.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import 'apply_labels.dart';
import 'apply_rules.dart';
import 'apply_sender.dart';

class ApplyReviewView extends StatefulWidget {
  const ApplyReviewView({
    super.key,
    required this.draft,
    required this.repository,
    this.onEditStep,
    this.onSent,
    this.onBack,
    this.now,
  });

  final CoachApplicationDraft draft;
  final CoachingRepository repository;

  /// Opens step 1 to 8 for editing; saving there comes back here.
  final ValueChanged<int>? onEditStep;

  /// After the server took the application.
  final VoidCallback? onSent;
  final VoidCallback? onBack;
  final DateTime? now;

  @override
  State<ApplyReviewView> createState() => _ApplyReviewViewState();
}

class _ApplyReviewViewState extends State<ApplyReviewView> {
  bool _sending = false;
  int _done = 0;
  int _total = 0;
  CoachingRefusal? _failure;

  Future<void> _send() async {
    final locale = Localizations.localeOf(context).languageCode;
    setState(() {
      _sending = true;
      _failure = null;
      _done = 0;
      _total = 0;
    });
    try {
      await ApplicationSender(
        repository: widget.repository,
        draft: widget.draft,
      ).send(
        locale: locale,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      widget.onSent?.call();
    } on CoachingFailure catch (error) {
      if (mounted) setState(() => _failure = error.refusal);
    } catch (_) {
      if (mounted) setState(() => _failure = CoachingRefusal.unknown);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _summary(AppL10n l10n, CoachApplication app, int step) {
    switch (step) {
      case 1:
        final p = app.personal;
        return <String>[
          if (p.displayName.isNotEmpty) p.displayName,
          if (p.governorate.isNotEmpty) governorateLabel(l10n, p.governorate),
          if (p.languages.isNotEmpty)
            p.languages.map((id) => languageLabel(l10n, id)).join(' · '),
          if (p.headline.isNotEmpty) p.headline,
        ];
      case 2:
        return <String>[
          for (final e in app.education)
            [
              e.degree,
              e.institution,
              if (e.year != null) '${e.year}',
            ].where((s) => s.isNotEmpty).join(' · '),
        ];
      case 3:
        return <String>[
          for (final c in app.certificates)
            [
              c.title,
              c.issuer,
              if (c.year != null) '${c.year}',
            ].where((s) => s.isNotEmpty).join(' · '),
        ];
      case 4:
        return <String>[
          if (app.specialties.isNotEmpty)
            app.specialties.map((id) => specialtyLabel(l10n, id)).join(' · '),
          if (app.yearsExperience != null)
            '${l10n.yearsOfExperience}: ${app.yearsExperience}',
          if (app.qualifications.trim().isNotEmpty) app.qualifications.trim(),
        ];
      case 5:
        return <String>[
          for (final t in app.testimonials)
            [t.from, t.text].where((s) => s.trim().isNotEmpty).join(' · '),
        ];
      case 6:
        return <String>[
          for (final t in app.transformations)
            '${l10n.weeksItTook}: ${t.weeks}',
        ];
      case 7:
        final a = app.approach;
        return <String>[
          if (a.text.trim().isNotEmpty) a.text.trim(),
          if (CoachingEnums.replyHours.contains(a.replyHours))
            l10n.withinHoursHours('${a.replyHours}'),
          if (a.trainsWhere.isNotEmpty)
            a.trainsWhere.map((id) => trainsWhereLabel(l10n, id)).join(' · '),
        ];
      default:
        return <String>[for (final id in app.rules) ruleLabel(l10n, id)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return RedrawOnChange(
      builder: (context) {
        final app = widget.draft.application;
        final needed = <int>{
          ...applyStepsNeeded(app, now: widget.now),
          for (final section in app.missingSections(now: widget.now))
            ?applyStepOfSection(section, app, now: widget.now),
        };
        final ready = needed.isEmpty;
        return AppScaffold(
          appBar: AppTopBar(
            title: l10n.reviewYourApplication,
            onBack: _sending ? null : widget.onBack,
          ),
          footer: [
            if (_sending)
              Semantics(
                liveRegion: true,
                child: Text(
                  _total == 0
                      ? l10n.sendingYourApplication
                      : l10n.uploadingPhotoDoneOfTotal('$_done', '$_total'),
                  textAlign: TextAlign.center,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            if (_failure != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  applyFailureText(l10n, _failure!),
                  textAlign: TextAlign.center,
                  style: AppText.bodyM.copyWith(color: AppColors.error),
                ),
              ),
            AppButton(
              _failure != null ? l10n.tryAgain : l10n.sendMyApplication,
              onPressed: ready && !_sending ? _send : null,
            ),
          ],
          children: [
            Text(
              l10n.lookOverEachPartYouCanEdit,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            for (var step = 1; step <= kApplyStepCount; step++)
              _SectionCard(
                title: applyStepTitle(l10n, step),
                lines: _summary(l10n, app, step),
                needed: needed.contains(step),
                onEdit: _sending || widget.onEditStep == null
                    ? null
                    : () => widget.onEditStep!(step),
              ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.lines,
    required this.needed,
    required this.onEdit,
  });

  final String title;
  final List<String> lines;
  final bool needed;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      container: true,
      child: AppCard(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.titleM.copyWith(color: AppColors.onSurface),
                ),
              ),
              AppButton(
                l10n.edit,
                variant: AppButtonVariant.text,
                height: 48,
                fontSize: 15,
                onPressed: onEdit,
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                needed ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: needed ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  needed ? l10n.stillNeeded : l10n.complete,
                  style: AppText.bodyM.copyWith(
                    color: needed
                        ? AppColors.error
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (lines.isEmpty)
            Text(
              l10n.nothingAddedYet,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            )
          else
            for (final line in lines)
              Text(
                line,
                textDirection: Bidi.detectRtlDirectionality(line)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
        ],
      ),
    );
  }
}
