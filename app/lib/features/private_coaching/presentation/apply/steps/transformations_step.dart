import 'package:flutter/material.dart';

import '../../../../../l10n/app_l10n.dart';
import '../../../../../ui/app_button.dart';
import '../../../domain/coach_application.dart';
import '../../../domain/coaching_contract.dart';
import '../apply_rules.dart';
import '../apply_widgets.dart';

/// Step 6: client transformations, 1 to 6, each with her client's consent.
class TransformationsStep extends StatefulWidget {
  const TransformationsStep({
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
  State<TransformationsStep> createState() => _TransformationsStepState();
}

class _TransformationsStepState extends State<TransformationsStep> {
  late final List<Key> _keys = [
    for (final _ in widget.app.transformations) UniqueKey(),
  ];

  List<CoachTransformation> get _rows => widget.app.transformations;

  void _emit(List<CoachTransformation> rows) =>
      widget.onChanged(widget.app.copyWith(transformations: rows));

  CoachTransformation _with(
    CoachTransformation t, {
    String? before,
    String? after,
    int? weeks,
    String? note,
    bool? consent,
  }) => CoachTransformation(
    beforePath: before ?? t.beforePath,
    afterPath: after ?? t.afterPath,
    weeks: weeks ?? t.weeks,
    note: note ?? t.note,
    clientConsent: consent ?? t.clientConsent,
  );

  void _edit(int i, CoachTransformation row) =>
      _emit(List<CoachTransformation>.of(_rows)..[i] = row);

  void _add() {
    _keys.add(UniqueKey());
    _emit([..._rows, const CoachTransformation()]);
  }

  void _remove(int i) {
    _keys.removeAt(i);
    _emit(List<CoachTransformation>.of(_rows)..removeAt(i));
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
            title: l10n.transformationN('${i + 1}'),
            onRemove: _rows.length > CoachingLimits.transformationsMin
                ? () => _remove(i)
                : null,
            children: [
              ApplyPhotoSlot(
                label: l10n.beforePhoto,
                value: _rows[i].beforePath,
                tools: widget.tools,
                problem: problems['transformations.$i.before'],
                onChanged: (m, _) => _edit(i, _with(_rows[i], before: m)),
              ),
              ApplyPhotoSlot(
                label: l10n.afterPhoto,
                value: _rows[i].afterPath,
                tools: widget.tools,
                problem: problems['transformations.$i.after'],
                onChanged: (m, _) => _edit(i, _with(_rows[i], after: m)),
              ),
              ApplyTextField(
                initial: _rows[i].weeks > 0 ? '${_rows[i].weeks}' : '',
                label: l10n.weeksItTook,
                numeric: true,
                maxLength: 3,
                problem: problems['transformations.$i.weeks'],
                onChanged: (v) =>
                    _edit(i, _with(_rows[i], weeks: parseApplyInt(v) ?? 0)),
              ),
              ApplyTextField(
                initial: _rows[i].note,
                label: l10n.noteOptional,
                maxLines: 3,
                maxLength: 300,
                problem: problems['transformations.$i.note'],
                onChanged: (v) => _edit(i, _with(_rows[i], note: v)),
              ),
              ApplyTick(
                text: l10n.myClientAgreedInWritingThatOwn,
                value: _rows[i].clientConsent,
                problem: problems['transformations.$i.consent'],
                onChanged: (v) => _edit(i, _with(_rows[i], consent: v)),
              ),
            ],
          ),
        ApplyErrorLine(problems['transformations']),
        if (_rows.length < CoachingLimits.transformationsMax)
          AppButton(
            l10n.addATransformation,
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
