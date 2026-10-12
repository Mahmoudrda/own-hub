/// O06 — What do you have at home?
///
/// Asked only when home is part of where she trains (`setupWalk`). One
/// question, as chips rather than a list on purpose: the honest answer for
/// most women here is "nothing", and that answer has to be the easy one. A
/// list of equipment to tick reads as a list of things she ought to own; four
/// chips with "Nothing" already chosen reads as a question she has already
/// answered correctly.
///
/// "Nothing" is exclusive. The rule lives in [Intake.toggleEquipment], not in
/// this widget, because My Profile edits the same set (D3) and a rule in a
/// widget only holds on the screen that contains it.
library;

import 'package:flutter/material.dart';

import '../../../app_state/onboarding_state.dart' show setupProgress;
import '../../../l10n/app_l10n.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_step_scaffold.dart';

class EquipmentView extends StatefulWidget {
  const EquipmentView({
    super.key,
    required this.repository,
    this.onContinue,
    this.onBack,
    this.onClose,
  });

  final IntakeRepository repository;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  State<EquipmentView> createState() => _EquipmentViewState();
}

class _EquipmentViewState extends State<EquipmentView> {
  late Set<Equipment> _equipment;

  /// The chip order the design uses.
  static const List<Equipment> _order = [
    Equipment.none,
    Equipment.mat,
    Equipment.dumbbells,
    Equipment.bands,
  ];

  @override
  void initState() {
    super.initState();
    _equipment = widget.repository.read().equipment;
  }

  Future<void> _continue() async {
    await widget.repository.merge(equipment: _equipment);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final labels = <Equipment, String>{
      Equipment.none: l10n.nothing,
      Equipment.mat: l10n.aMat,
      Equipment.dumbbells: l10n.dumbbells,
      Equipment.bands: l10n.bands,
    };
    final at = setupProgress('O06', widget.repository.read());

    return IntakeStepScaffold(
      step: at.step,
      total: at.total,
      title: l10n.whatDoYouHaveAtHome,
      subtitle: l10n.mostWomenStartWithNothingThatIs,
      onContinue: _continue,
      onBack: widget.onBack,
      onClose: widget.onClose,
      children: [
        AppChipRow(
          // Natural widths, not equal quarters: "Nothing" is much shorter than
          // "Dumbbells" and stretching it would make the easiest answer look
          // like the biggest commitment.
          grow: false,
          items: [for (final item in _order) labels[item]!],
          selected: {
            for (var i = 0; i < _order.length; i++)
              if (_equipment.contains(_order[i])) i,
          },
          onTap: (i) => setState(() {
            _equipment = Intake.toggleEquipment(_equipment, _order[i]);
          }),
        ),
      ],
    );
  }
}
