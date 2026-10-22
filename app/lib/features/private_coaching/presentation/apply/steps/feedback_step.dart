import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../../../ui/app_button.dart';
import '../../../../../ui/app_sage_note.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_labels.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 5: messages from women she trained, 2 to 10.
class FeedbackStep extends StatefulWidget {
  const FeedbackStep({
    super.key,
    required this.app,
    required this.problems,
    required this.tools,
    required this.onChanged,
  });

  final CoachApplication app;
  final ApplyProblems problems;
  final ApplyTools tools;
  final ValueChanged<CoachApplication> onChanged;

  @override
  State<FeedbackStep> createState() => _FeedbackStepState();
}

class _FeedbackStepState extends State<FeedbackStep> {
  late final List<Key> _keys = [
    for (final _ in widget.app.testimonials) UniqueKey(),
  ];

  List<CoachTestimonial> get _rows => widget.app.testimonials;

  void _emit(List<CoachTestimonial> rows) =>
      widget.onChanged(widget.app.copyWith(testimonials: rows));

  void _edit(int i, CoachTestimonial row) =>
      _emit(List<CoachTestimonial>.of(_rows)..[i] = row);

  void _add() {
    _keys.add(UniqueKey());
    _emit([..._rows, const CoachTestimonial()]);
  }

  void _remove(int i) {
    _keys.removeAt(i);
    _emit(List<CoachTestimonial>.of(_rows)..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final problems = widget.problems;
    final sources = CoachingEnums.testimonialSource;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        AppSageNote(l10n.screenshotsAreSeenOnlyByOwnHubs),
        for (var i = 0; i < _rows.length; i++)
          ApplyRowCard(
            key: _keys[i],
            title: l10n.feedbackN('${i + 1}'),
            onRemove: _rows.length > CoachingLimits.testimonialsMin
                ? () => _remove(i)
                : null,
            children: [
              ApplyTextField(
                initial: _rows[i].text,
                label: l10n.whatSheSaid,
                maxLines: 4,
                maxLength: CoachingLimits.testimonialTextMax,
                problem: problems['testimonials.$i.text'],
                onChanged: (v) => _edit(
                  i,
                  CoachTestimonial(
                    text: v,
                    from: _rows[i].from,
                    source: _rows[i].source,
                    imagePath: _rows[i].imagePath,
                  ),
                ),
              ),
              ApplyTextField(
                initial: _rows[i].from,
                label: l10n.herFirstName,
                maxLength: 40,
                problem: problems['testimonials.$i.from'],
                onChanged: (v) => _edit(
                  i,
                  CoachTestimonial(
                    text: _rows[i].text,
                    from: v,
                    source: _rows[i].source,
                    imagePath: _rows[i].imagePath,
                  ),
                ),
              ),
              ApplyLabel(l10n.whereItCameFrom),
              ApplyChoice(
                items: [for (final id in sources) sourceLabel(l10n, id)],
                selected: {
                  if (sources.contains(_rows[i].source))
                    sources.indexOf(_rows[i].source),
                },
                onTap: (s) => _edit(
                  i,
                  CoachTestimonial(
                    text: _rows[i].text,
                    from: _rows[i].from,
                    source: sources[s],
                    imagePath: _rows[i].imagePath,
                  ),
                ),
              ),
              ApplyErrorLine(problems['testimonials.$i.source']),
              ApplyPhotoSlot(
                label: l10n.screenshotOptional,
                value: _rows[i].imagePath ?? '',
                tools: widget.tools,
                optional: true,
                onChanged: (marker, _) => _edit(
                  i,
                  CoachTestimonial(
                    text: _rows[i].text,
                    from: _rows[i].from,
                    source: _rows[i].source,
                    imagePath: marker.isEmpty ? null : marker,
                  ),
                ),
              ),
            ],
          ),
        ApplyErrorLine(problems['testimonials']),
        if (_rows.length < CoachingLimits.testimonialsMax)
          AppButton(
            l10n.addFeedback,
            variant: AppButtonVariant.outlined,
            height: 52,
            fontSize: 15,
            icon: Icons.add,
            onPressed: _add,
          ),
      ],
    );
  }
}
