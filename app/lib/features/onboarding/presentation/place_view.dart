/// O02 — Where will you train, and with what?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O02`. Two answers on one screen:
/// the place, as a list, and the equipment, as chips.
///
/// **The equipment is chips rather than a list on purpose.** The design note
/// says it plainly: the honest answer for most women here is "nothing", and that
/// answer has to be the easy one. A list of equipment to tick reads as a list of
/// things she ought to own; four chips with "Nothing" already chosen reads as a
/// question she has already answered correctly.
///
/// "Nothing" is exclusive — the rule lives in [Intake.toggleEquipment], not in
/// this widget, because My Profile will edit the same set later (D3) and a rule
/// in a widget only holds on the screen that contains it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_option.dart';
import 'intake_step_scaffold.dart';

class PlaceView extends StatefulWidget {
  const PlaceView({
    super.key,
    required this.repository,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onClose,
  });

  final IntakeRepository repository;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  State<PlaceView> createState() => _PlaceViewState();
}

class _PlaceViewState extends State<PlaceView> {
  late TrainingPlace _place;
  late Set<Equipment> _equipment;

  /// The chip order the design uses.
  static const List<Equipment> _equipmentOrder = [
    Equipment.none,
    Equipment.mat,
    Equipment.dumbbells,
    Equipment.bands,
  ];

  @override
  void initState() {
    super.initState();
    final intake = widget.repository.read();
    _place = intake.place;
    _equipment = intake.equipment;
  }

  Future<void> _continue() async {
    await widget.repository.merge(place: _place, equipment: _equipment);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final places = <(TrainingPlace, String, String)>[
      (TrainingPlace.home, l10n.atHome, l10n.quietMovesFloorNothingToCarry),
      (
        TrainingPlace.ladiesGym,
        l10n.aLadiesOnlyGym,
        l10n.machinesAndFreeWeights,
      ),
      (TrainingPlace.both, l10n.both, l10n.homeOnWeekdaysGymWhenICan),
    ];

    final equipmentLabels = <Equipment, String>{
      Equipment.none: l10n.nothing,
      Equipment.mat: l10n.aMat,
      Equipment.dumbbells: l10n.dumbbells,
      Equipment.bands: l10n.bands,
    };

    return IntakeStepScaffold(
      step: 2,
      title: l10n.whereWillYouTrain,
      subtitle: l10n.youCanChangeItOnAnyDay,
      onContinue: _continue,
      onSkip: widget.onSkip,
      onBack: widget.onBack,
      onClose: widget.onClose,
      children: [
        for (final (place, title, subtitle) in places)
          IntakeOption(
            title: title,
            subtitle: subtitle,
            selected: _place == place,
            onTap: () => setState(() => _place = place),
          ),
        IntakeAnswerGroup(
          label: l10n.whatDoYouHaveAtHome,
          child: AppChipRow(
            // Natural widths, not equal thirds: "Nothing" is much shorter than
            // "Dumbbells" and stretching it would make the easiest answer look
            // like the biggest commitment.
            grow: false,
            items: [for (final item in _equipmentOrder) equipmentLabels[item]!],
            selected: {
              for (var i = 0; i < _equipmentOrder.length; i++)
                if (_equipment.contains(_equipmentOrder[i])) i,
            },
            onTap: (i) => setState(() {
              _equipment = Intake.toggleEquipment(
                _equipment,
                _equipmentOrder[i],
              );
            }),
          ),
        ),
      ],
    );
  }
}
