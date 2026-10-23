/// What Own Hub approved when she applied, in one place.
library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_scaffold.dart';
import 'coach_data.dart';
import 'coach_text.dart';
import 'coach_widgets.dart';

class CoachApplicationView extends StatelessWidget {
  const CoachApplicationView({super.key, required this.data});

  final CoachSpaceData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.yourApplication,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        CoachDataGate(
          data: data,
          builder: (context) {
            final app = data.application;
            final profile = data.profile;
            final years = app?.yearsExperience ?? profile?.yearsExperience;
            final specialties = app?.specialties ?? profile?.specialties ?? [];
            return <Widget>[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppPill(l10n.approved, icon: Icons.check),
              ),
              AppCard(
                children: [
                  if (specialties.isNotEmpty) ...[
                    Text(l10n.specialties, style: AppText.titleS),
                    Text(
                      [for (final s in specialties) specialtyLabel(l10n, s)]
                          .join(' · '),
                      style: AppText.body,
                    ),
                  ],
                  if (years != null)
                    _Line(l10n.yearsCoaching, countLabel(years)),
                  if (app != null) ...[
                    _Line(
                      l10n.certificates,
                      countLabel(app.certificates.length),
                    ),
                    _Line(
                      l10n.clientFeedback,
                      countLabel(app.testimonials.length),
                    ),
                    _Line(
                      l10n.beforeAndAfterStories,
                      countLabel(app.transformations.length),
                    ),
                  ],
                ],
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppText.titleS)),
        Text(value, style: AppText.body),
      ],
    ),
  );
}
