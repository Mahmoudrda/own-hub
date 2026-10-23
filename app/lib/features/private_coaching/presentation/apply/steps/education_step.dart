import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../../../ui/app_button.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 2: degrees and courses, 1 to 6, with an optional proof photo.
class EducationStep extends StatefulWidget {
  const EducationStep({
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
  State<EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends State<EducationStep> {
  late final List<Key> _keys = [
    for (final _ in widget.app.education) UniqueKey(),
  ];

  List<CoachEducation> get _rows => widget.app.education;

  void _emit(List<CoachEducation> rows) =>
      widget.onChanged(widget.app.copyWith(education: rows));

  void _edit(int i, CoachEducation row) =>
      _emit(List<CoachEducation>.of(_rows)..[i] = row);

  void _add() {
    _keys.add(UniqueKey());
    _emit([..._rows, const CoachEducation()]);
  }

  void _remove(int i) {
    _keys.removeAt(i);
    _emit(List<CoachEducation>.of(_rows)..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final problems = widget.problems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        for (var i = 0; i < _rows.length; i++)
          ApplyRowCard(
            key: _keys[i],
            title: l10n.educationN('${i + 1}'),
            onRemove: _rows.length > CoachingLimits.educationMin
                ? () => _remove(i)
                : null,
            children: [
              ApplyTextField(
                initial: _rows[i].degree,
                label: l10n.degreeOrCourse,
                problem: problems['education.$i.degree'],
                maxLength: 80,
                onChanged: (v) => _edit(
                  i,
                  CoachEducation(
                    degree: v,
                    institution: _rows[i].institution,
                    year: _rows[i].year,
                    path: _rows[i].path,
                  ),
                ),
              ),
              ApplyTextField(
                initial: _rows[i].institution,
                label: l10n.institution,
                problem: problems['education.$i.institution'],
                maxLength: 80,
                onChanged: (v) => _edit(
                  i,
                  CoachEducation(
                    degree: _rows[i].degree,
                    institution: v,
                    year: _rows[i].year,
                    path: _rows[i].path,
                  ),
                ),
              ),
              ApplyTextField(
                initial: _rows[i].year?.toString() ?? '',
                label: l10n.year,
                numeric: true,
                maxLength: 4,
                problem: problems['education.$i.year'],
                onChanged: (v) => _edit(
                  i,
                  CoachEducation(
                    degree: _rows[i].degree,
                    institution: _rows[i].institution,
                    year: parseApplyInt(v),
                    path: _rows[i].path,
                  ),
                ),
              ),
              ApplyPhotoSlot(
                label: l10n.proofPhotoOptional,
                value: _rows[i].path,
                tools: widget.tools,
                optional: true,
                onChanged: (marker, _) => _edit(
                  i,
                  CoachEducation(
                    degree: _rows[i].degree,
                    institution: _rows[i].institution,
                    year: _rows[i].year,
                    path: marker,
                  ),
                ),
              ),
            ],
          ),
        ApplyErrorLine(problems['education']),
        if (_rows.length < CoachingLimits.educationMax)
          AppButton(
            l10n.addEducation,
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
