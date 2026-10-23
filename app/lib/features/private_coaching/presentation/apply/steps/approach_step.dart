import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_labels.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 7: how she coaches.
class ApproachStep extends StatelessWidget {
  const ApproachStep({
    super.key,
    required this.app,
    required this.problems,
    required this.onChanged,
  });

  final CoachApplication app;
  final ApplyProblems problems;
  final ValueChanged<CoachApplication> onChanged;

  CoachApproach get _a => app.approach;

  void _set(CoachApproach a) => onChanged(app.copyWith(approach: a));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final replies = CoachingEnums.replyHours;
    final where = CoachingEnums.trainsWhere;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        ApplyTextField(
          initial: _a.text,
          label: l10n.yourApproach,
          helper: l10n.minToMaxCharacters(
            '${CoachingLimits.approachTextMin}',
            '${CoachingLimits.approachTextMax}',
          ),
          maxLines: 8,
          maxLength: CoachingLimits.approachTextMax,
          problem: problems['approachText'],
          onChanged: (v) => _set(_a.copyWith(text: v)),
        ),
        ApplyTextField(
          initial: '${_a.checkInsPerWeek}',
          label: l10n.followUpsWithEachClientPerWeek,
          numeric: true,
          maxLength: 1,
          problem: problems['followUps'],
          onChanged: (v) =>
              _set(_a.copyWith(checkInsPerWeek: parseApplyInt(v) ?? -1)),
        ),
        ApplyLabel(l10n.howFastYouReply),
        ApplyChoice(
          items: [for (final h in replies) l10n.withinHoursHours('$h')],
          selected: {
            if (replies.contains(_a.replyHours)) replies.indexOf(_a.replyHours),
          },
          onTap: (i) => _set(_a.copyWith(replyHours: replies[i])),
        ),
        ApplyErrorLine(problems['replyHours']),
        ApplyLabel(l10n.whereYouTrainClients),
        ApplyChoice(
          items: [for (final id in where) trainsWhereLabel(l10n, id)],
          selected: {
            for (var i = 0; i < where.length; i++)
              if (_a.trainsWhere.contains(where[i])) i,
          },
          onTap: (i) {
            final next = List<String>.of(_a.trainsWhere);
            next.contains(where[i])
                ? next.remove(where[i])
                : next.add(where[i]);
            _set(_a.copyWith(trainsWhere: next));
          },
        ),
        ApplyErrorLine(problems['trainsWhere']),
      ],
    );
  }
}
