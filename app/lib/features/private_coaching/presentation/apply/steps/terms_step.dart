import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../../../theme/app_tokens.dart';
import '../../../../../ui/app_button.dart';
import '../../../../../ui/app_card.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../../coach_agreement_points.dart';
import '../apply_labels.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 8: the coach terms in plain points and the three rule ticks.
class TermsStep extends StatelessWidget {
  const TermsStep({
    super.key,
    required this.app,
    required this.problems,
    required this.onChanged,
    this.onOpenTerms,
  });

  final CoachApplication app;
  final ApplyProblems problems;
  final ValueChanged<CoachApplication> onChanged;
  final VoidCallback? onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final points = <String>[
      ...coachAgreementPoints(l10n),
      l10n.youCanWithdrawYourApplicationAtAny,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        AppCard(
          children: [
            for (final point in points)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(top: 2, end: 10),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (onOpenTerms != null)
          AppButton(
            l10n.readTheFullCoachAgreement,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: onOpenTerms,
          ),
        for (final id in CoachingEnums.coachRules)
          ApplyTick(
            text: ruleLabel(l10n, id),
            value: app.rules.contains(id),
            problem: app.rules.contains(id) ? null : problems['rules'],
            onChanged: (on) {
              final next = List<String>.of(app.rules);
              if (on && !next.contains(id)) next.add(id);
              if (!on) next.remove(id);
              onChanged(app.copyWith(rules: next));
            },
          ),
      ],
    );
  }
}
