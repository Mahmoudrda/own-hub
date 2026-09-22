/// `K21` — step 1 of the assessment, and **the** source of her constraints.
///
/// ## The avoid list is chips, and it is the only input anywhere that writes it
///
/// r13 and §1.5. The list is a closed vocabulary of ten tokens, so this screen
/// offers chips rather than prose: a tag outside the vocabulary is
/// unrepresentable, not merely rejected, because `ContraindicationTag` has no
/// constructor taking a string. W02 and W06 render what is chosen here and have
/// no control that could change it.
///
/// `painNotes` sits beside the chips and is a text field on purpose. It is
/// **displayed to the coach and never parsed** — a filter driven by prose is a
/// safety claim this product cannot honour — which is exactly why it cannot be
/// the avoid list.
///
/// ## Nothing is written here
///
/// K21 and K23 are two steps of **one document**. This screen holds a value in
/// memory and hands it forward; killing the app between the steps writes
/// nothing, because a half-saved assessment is a half-stated constraint and a
/// partial source is worse than none.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/day_key.dart';
import '../../../domain/safety/contraindication_tag.dart';
import '../../../domain/safety/life_stage_safety_policy.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/app_toggle.dart';
import '../domain/assessment/assessment_form.dart';
import 'coachplan_labels.dart';
import 'coachplan_widgets.dart';

/// The ten that restrict something. `none` is authored content meaning "there
/// is nothing to avoid", and offering it as a chip would let a coach tick a
/// token that suppresses nothing while looking like an answer.
List<ContraindicationTag> get offeredAvoidTags => <ContraindicationTag>[
  for (final tag in ContraindicationTag.values)
    if (tag.restricts) tag,
];

class AssessmentHealthView extends StatefulWidget {
  const AssessmentHealthView({
    super.key,
    required this.form,
    this.onSelectLifeStage,
    this.onSelectBirthType,
    this.onClearanceChanged,
    this.onToggleAvoidTag,
    this.onPainNotesChanged,
    this.onContinue,
    this.onClose,
  });

  /// Held in memory. It has no repository and no `save`.
  final AssessmentForm form;

  final ValueChanged<LifeStage>? onSelectLifeStage;
  final ValueChanged<BirthType>? onSelectBirthType;

  /// `granted:false` is a recorded answer; null is nobody having answered.
  final ValueChanged<bool>? onClearanceChanged;

  final ValueChanged<ContraindicationTag>? onToggleAvoidTag;
  final ValueChanged<String>? onPainNotesChanged;

  /// Enabled only once her stage and her clearance are both answered.
  final VoidCallback? onContinue;

  final VoidCallback? onClose;

  @override
  State<AssessmentHealthView> createState() => _AssessmentHealthViewState();
}

class _AssessmentHealthViewState extends State<AssessmentHealthView> {
  late final TextEditingController _painNotes;

  @override
  void initState() {
    super.initState();
    _painNotes = TextEditingController(text: widget.form.painNotes ?? '');
  }

  @override
  void dispose() {
    _painNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final form = widget.form;
    final clearance = form.clearance;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.assessment,
        leadingIcon: Icons.close,
        onBack: widget.onClose,
      ),
      body: AppScaffold(
        footer: [
          AppButton(
            l10n.continueLabel,
            height: 54,
            // Both answers are required: the life stage derives restrictions
            // on its own, and the clearance gates publishing in the first six
            // weeks after birth.
            onPressed: form.canContinue ? widget.onContinue : null,
          ),
        ],
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.healthAndClearance, style: AppText.titleM),
                    const SizedBox(height: 3),
                    Text(
                      l10n.step1Of2,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The step the line beside it prints, jotted in the margin.
              const HandFigure('1', size: 26),
            ],
          ),
          AppCard(
            variant: AppCardVariant.sage,
            gap: 10,
            children: [
              SectionHead(l10n.stage),
              // TODO(l10n): `p0_6w` and `p6w_1y` have only figure-bearing
              // strings in the dictionary ("0 to 6 weeks", "6 weeks to 1 year").
              // Both chips are still offered — omitting the clearance-gated
              // stage would be a safety hole — and they carry their stored
              // token until the staged copy lands.
              AppChipRow(
                grow: false,
                items: [
                  for (final stage in LifeStage.values)
                    lifeStageLabel(l10n, stage),
                ],
                selected: <int>{
                  for (var i = 0; i < LifeStage.values.length; i++)
                    if (LifeStage.values[i] == form.lifeStage) i,
                },
                onTap: widget.onSelectLifeStage == null
                    ? null
                    : (i) => widget.onSelectLifeStage!(LifeStage.values[i]),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.doctorsClearanceToTrain,
                          style: AppText.titleS,
                        ),
                        if (clearance != null) ...[
                          const SizedBox(height: 2),
                          // The day it was recorded, as the id it is.
                          Text(
                            dayKey(clearance.recordedAt),
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppToggle(
                    value: clearance?.granted ?? false,
                    semanticLabel: l10n.doctorsClearanceToTrain,
                    onChanged: widget.onClearanceChanged,
                  ),
                ],
              ),
              SectionHead(l10n.birth),
              AppChipRow(
                grow: false,
                items: [
                  for (final type in BirthType.values)
                    birthTypeLabel(l10n, type),
                ],
                selected: <int>{
                  for (var i = 0; i < BirthType.values.length; i++)
                    if (BirthType.values[i] == form.birthType) i,
                },
                onTap: widget.onSelectBirthType == null
                    ? null
                    : (i) => widget.onSelectBirthType!(BirthType.values[i]),
              ),
            ],
          ),
          AppCard(
            key: const Key('K21.avoid'),
            variant: AppCardVariant.amber,
            gap: 9,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.whatToAvoid, style: AppText.titleM),
                  const SizedBox(height: 2),
                  Text(
                    l10n.theseWriteStraightOntoHerPlanSo,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Chips, never prose. The vocabulary is closed, so an avoid list
              // that nothing can match is unrepresentable here.
              AppChipRow(
                grow: false,
                items: [
                  for (final tag in offeredAvoidTags) avoidTagLabel(l10n, tag),
                ],
                selected: <int>{
                  for (var i = 0; i < offeredAvoidTags.length; i++)
                    if (form.avoid.contains(offeredAvoidTags[i])) i,
                },
                onTap: widget.onToggleAvoidTag == null
                    ? null
                    : (i) => widget.onToggleAvoidTag!(offeredAvoidTags[i]),
              ),
              // Shown to the coach. Never parsed, never used to filter.
              AppField(
                controller: _painNotes,
                label: l10n.painInjuriesOrSurgery,
                onChanged: widget.onPainNotesChanged,
              ),
            ],
          ),
          Text(
            l10n.nothingHereIsShownToOtherMembers,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
