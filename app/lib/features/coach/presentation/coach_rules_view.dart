/// `K13` — How we treat each other.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K13`. A woman who signs up to coach
/// does not pass through `C16`, the community's pledge, so the same three rules
/// are here, on a screen of their own, with one tick. Continue waits for it.
/// The router records the agreement exactly as `C16` does (`recordPledge`: the
/// version on the phone and `record_pledge` on the server), so a coach and a
/// trainee have agreed to the same words under the same version number. A
/// woman who has already agreed sees the box ticked.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachRulesView extends StatefulWidget {
  const CoachRulesView({
    super.key,
    required this.model,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
  });

  final CoachSetupViewModel model;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  @override
  State<CoachRulesView> createState() => _CoachRulesViewState();
}

class _CoachRulesViewState extends State<CoachRulesView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return CoachSetupScaffold(
      step: CoachSetupStep.rules,
      title: l10n.howWeTreatEachOther,
      subtitle: l10n.asACoachYouAgreeToThe,
      onBack: widget.onBack,
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: model.canAdvanceFrom(CoachSetupStep.rules)
          ? () => goToScreen(context, 'K05', widget.onContinue)
          : null,
      children: [
        _Rule(
          title: l10n.n1WhatIsSaidHereStaysHere,
          body: l10n.noScreenshotsNoSharingAnyoneElseOutside,
        ),
        _Rule(
          title: l10n.n2NoCommentsOnAnyoneElsesBody,
          body: l10n.notEvenAComplimentTalkAboutThe,
        ),
        _Rule(
          title: l10n.n3NoSellingNoRecruiting,
          body: l10n.coachesHaveProfilesForThat,
        ),
        CheckboxListTile(
          value: model.rulesAgreed,
          onChanged: (on) => setState(() => model.rulesAgreed = on ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: Text(l10n.iAgreeToTheseThreeRules, style: AppText.titleS),
        ),
      ],
    );
  }
}

/// One of the three rules, set as `C16` sets it.
class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: AppText.titleS),
      const SizedBox(height: 2),
      Text(
        body,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ],
  );
}
