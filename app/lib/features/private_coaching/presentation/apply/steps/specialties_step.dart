import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_labels.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 4: specialties (1 to 5), years of experience and qualifications.
class SpecialtiesStep extends StatelessWidget {
  const SpecialtiesStep({
    super.key,
    required this.app,
    required this.problems,
    required this.onChanged,
  });

  final CoachApplication app;
  final ApplyProblems problems;
  final ValueChanged<CoachApplication> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ids = CoachingEnums.specialties;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        ApplyChoice(
          items: [for (final id in ids) specialtyLabel(l10n, id)],
          selected: {
            for (var i = 0; i < ids.length; i++)
              if (app.specialties.contains(ids[i])) i,
          },
          onTap: (i) {
            final next = List<String>.of(app.specialties);
            if (next.contains(ids[i])) {
              next.remove(ids[i]);
            } else if (next.length < CoachingLimits.specialtiesMax) {
              next.add(ids[i]);
            }
            onChanged(app.copyWith(specialties: next));
          },
        ),
        ApplyErrorLine(problems['specialties']),
        ApplyTextField(
          initial: app.yearsExperience?.toString() ?? '',
          label: l10n.yearsOfExperience,
          numeric: true,
          maxLength: 2,
          problem: problems['years'],
          onChanged: (v) {
            final years = parseApplyInt(v);
            onChanged(
              CoachApplication(
                payoutOptional: app.payoutOptional,
                personal: app.personal,
                education: app.education,
                certificates: app.certificates,
                specialties: app.specialties,
                qualifications: app.qualifications,
                yearsExperience: years,
                testimonials: app.testimonials,
                transformations: app.transformations,
                approach: app.approach,
                payout: app.payout,
                termsVersion: app.termsVersion,
                rules: app.rules,
              ),
            );
          },
        ),
        ApplyTextField(
          initial: app.qualifications,
          label: l10n.yourQualifications,
          helper: l10n.minToMaxCharacters(
            '20',
            '${CoachingLimits.qualificationsMax}',
          ),
          problem: problems['qualifications'],
          maxLines: 5,
          maxLength: CoachingLimits.qualificationsMax,
          onChanged: (v) => onChanged(app.copyWith(qualifications: v)),
        ),
      ],
    );
  }
}
