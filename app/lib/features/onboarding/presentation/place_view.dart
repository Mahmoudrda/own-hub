/// O02 — Where will you train?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O02`. One question: the place.
/// What she has at home is the next screen (`O06`), and only when home is part
/// of her answer: a woman who trains at a ladies-only gym is not asked about
/// dumbbells in her living room.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_option.dart';
import 'intake_step_scaffold.dart';
import '../../../app_state/onboarding_state.dart' show setupProgress;

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

  @override
  void initState() {
    super.initState();
    final intake = widget.repository.read();
    _place = intake.place;
  }

  Future<void> _continue() async {
    await widget.repository.merge(place: _place);
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

    // Counted from what she has tapped, so choosing the gym shortens the
    // walk on this screen rather than one screen later.
    final at = setupProgress(
      'O02',
      widget.repository.read().copyWith(place: _place),
    );
    return IntakeStepScaffold(
      step: at.step,
      total: at.total,
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
      ],
    );
  }
}
