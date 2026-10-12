/// O07 — How long can a session be?
///
/// One number on its own screen, after days a week (`O03`). Together they used
/// to be one crowded page; apart, each is a single tap on an answer that is
/// already chosen.
///
/// The chips keep Western numerals in Arabic (`P0-A11Y-01`): they are built
/// from the integers in [Intake.allowedMinutes] through the dictionary's own
/// "{n} min", so a number cannot become "١٥" on one screen and stay "15" on
/// the next.
library;

import 'package:flutter/material.dart';

import '../../../app_state/onboarding_state.dart' show setupProgress;
import '../../../l10n/app_l10n.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_step_scaffold.dart';

class MinutesView extends StatefulWidget {
  const MinutesView({
    super.key,
    required this.repository,
    this.onContinue,
    this.onBack,
    this.onClose,
    this.titleOverride,
  });

  final IntakeRepository repository;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  /// See [IntakeStepScaffold.titleOverride].
  final String? titleOverride;

  @override
  State<MinutesView> createState() => _MinutesViewState();
}

class _MinutesViewState extends State<MinutesView> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = widget.repository.read().minutes;
  }

  Future<void> _continue() async {
    await widget.repository.merge(minutes: _minutes);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final at = setupProgress('O07', widget.repository.read());

    return IntakeStepScaffold(
      step: at.step,
      total: at.total,
      title: l10n.howLongCanASessionBe,
      subtitle: l10n.shortIsFineFifteenMinutesDoneBeats,
      titleOverride: widget.titleOverride,
      onContinue: _continue,
      onBack: widget.onBack,
      onClose: widget.onClose,
      children: [
        AppChipRow(
          items: [for (final m in Intake.allowedMinutes) l10n.nMin('$m')],
          selected: {Intake.allowedMinutes.indexOf(_minutes)},
          onTap: (i) => setState(() => _minutes = Intake.allowedMinutes[i]),
        ),
      ],
    );
  }
}
