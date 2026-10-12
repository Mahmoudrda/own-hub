/// `K08` — Tell clients who you are.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K08`. Her name, her city and one
/// line about her, on a screen of their own. Her photo, and the blur that goes
/// with it, is the step before (`K01`); the three rules are their own step
/// (`K13`). Continue waits for a name and a city.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_field.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachBasicsView extends StatefulWidget {
  const CoachBasicsView({
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
  State<CoachBasicsView> createState() => _CoachBasicsViewState();
}

class _CoachBasicsViewState extends State<CoachBasicsView> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _tagline;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.model.displayName);
    _city = TextEditingController(text: widget.model.city);
    _tagline = TextEditingController(text: widget.model.tagline);
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _tagline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return CoachSetupScaffold(
      step: CoachSetupStep.about,
      title: l10n.tellClientsWhoYouAre,
      subtitle: l10n.thisIsTheTopOfYourPublic,
      onBack: widget.onBack,
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: model.canAdvanceFrom(CoachSetupStep.about)
          ? () => goToScreen(context, 'K03', widget.onContinue)
          : null,
      children: [
        AppField(
          controller: _name,
          label: l10n.name,
          textInputAction: TextInputAction.next,
          onChanged: (value) => setState(() => model.displayName = value),
        ),
        AppField(
          controller: _city,
          label: l10n.city,
          textInputAction: TextInputAction.next,
          onChanged: (value) => setState(() => model.city = value),
        ),
        AppField(
          controller: _tagline,
          label: l10n.oneLineAboutYou,
          onChanged: (value) => setState(() => model.tagline = value),
        ),
      ],
    );
  }
}
