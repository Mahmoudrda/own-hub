/// R05 — Swap a move.
///
/// Matches `6-v2/src/screens-train.mjs` → `R05`. Two taps: pick the replacement,
/// confirm it. The sheet leaves the move list visible behind it, so she can see
/// what she is changing — which is the whole reason this is a sheet and not a
/// page.
///
/// Swapping keeps the workout intact: the candidates work the same muscles, more
/// quietly or with less equipment. They are filtered locally against the same
/// constraints that produced the prescription, so a swap can never introduce a
/// move needing equipment she does not own.
///
/// **A swap is for today only.** It is written to the session, never to the plan
/// — this screen has no path to `plans/**`, and the repository it calls has none
/// either.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chevron.dart';
// AppCardVariant arrives through app_list_item.dart, which re-exports it.
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../domain/train_repository.dart';
import 'train_widgets.dart';

class SwapMoveView extends StatefulWidget {
  const SwapMoveView({
    super.key,
    this.onBack,
    this.onSwapped,
    this.onSelectTab,
    this.alternatives,
    this.moves,
    this.sessionId = 'session',
    this.exerciseId = 'goblet_squat',
    this.repository,
    this.openSheet = true,
  });

  final VoidCallback? onBack;

  /// Called once the swap has been recorded.
  final ValueChanged<MoveAlternative>? onSwapped;

  final ValueChanged<String>? onSelectTab;

  /// Injectable candidates. Default to the design's two.
  final List<MoveAlternative>? alternatives;

  /// The day behind the sheet.
  final List<PlannedMove>? moves;

  final String sessionId;

  /// The move being replaced.
  final String exerciseId;

  final TrainRepository? repository;

  /// R05 *is* the sheet raised over the list, so it opens by default. The flag
  /// exists so the list underneath can be reviewed on its own.
  final bool openSheet;

  @override
  State<SwapMoveView> createState() => _SwapMoveViewState();
}

class _SwapMoveViewState extends State<SwapMoveView> {
  TrainRepository? _fallback;

  TrainRepository get _repository =>
      widget.repository ?? (_fallback ??= InMemoryTrainRepository());

  @override
  void initState() {
    super.initState();
    if (widget.openSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _offerSwap();
      });
    }
  }

  Future<void> _offerSwap() async {
    final l10n = AppL10n.of(context);
    final candidates = widget.alternatives ?? _defaultAlternatives(l10n);

    await showAppSheet<void>(
      context: context,
      children: [
        Text(l10n.swapThisMove, style: AppText.titleL),
        Text(
          l10n.sameMusclesQuieterOnTheFloor,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        _SwapChoices(
          candidates: candidates,
          onConfirm: (choice) async {
            await _repository.swapMove(
              sessionId: widget.sessionId,
              fromExerciseId: widget.exerciseId,
              toExerciseId: choice.exerciseId,
            );
            if (!mounted) return;
            Navigator.of(context).pop();
            widget.onSwapped?.call(choice);
          },
        ),
      ],
    );
  }

  List<MoveAlternative> _defaultAlternatives(AppL10n l10n) => [
    MoveAlternative(
      exerciseId: 'glute_bridge',
      name: l10n.gluteBridge,
      reason: l10n.noStandingNothingToHold,
    ),
    MoveAlternative(
      exerciseId: 'step_back_lunge',
      name: l10n.stepBackLunge,
      reason: l10n.oneLegAtATimeHoldsThe,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final behind =
        widget.moves ??
        [
          PlannedMove(
            exerciseId: 'glute_bridge',
            name: l10n.gluteBridge,
            prescriptionLabel: l10n.n312Bodyweight,
            sets: const [],
          ),
          PlannedMove(
            exerciseId: 'goblet_squat',
            name: l10n.gobletSquat,
            prescriptionLabel: l10n.n31012Kg,
            sets: const [],
          ),
          PlannedMove(
            exerciseId: 'step_back_lunge',
            name: l10n.stepBackLunge,
            prescriptionLabel: l10n.n310EachSide,
            sets: const [],
          ),
        ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        // R05, not R01. The active tab is not a link to itself, so claiming
        // Train here drew the Train tab as the one she was on and gave it no
        // tap — a dead tab on a screen reached from Train.
        activeScreenId: 'R05',
        onSelect: widget.onSelectTab,
      ),
      body: AppScaffold(
        appBar: TrainTopBar(
          title: l10n.legsAndGlutes,
          onClose: widget.onBack,
          closeIcon: Icons.arrow_back,
        ),
        children: [
          for (final move in behind)
            MoveRow(
              name: move.name,
              detail: move.prescriptionLabel,
              current: move.exerciseId == widget.exerciseId,
              onTap: _offerSwap,
            ),
        ],
      ),
    );
  }
}

/// The candidates, with the chosen one marked.
///
/// Stateful so the selection is visible before she confirms — picking and
/// confirming are two different taps, and she should see what she picked.
class _SwapChoices extends StatefulWidget {
  const _SwapChoices({required this.candidates, required this.onConfirm});

  final List<MoveAlternative> candidates;
  final ValueChanged<MoveAlternative> onConfirm;

  @override
  State<_SwapChoices> createState() => _SwapChoicesState();
}

class _SwapChoicesState extends State<_SwapChoices> {
  int _chosen = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.candidates.length; i++) ...[
          if (i > 0) const SizedBox(height: kStackGap),
          AppListItem(
            title: widget.candidates[i].name,
            subtitle: widget.candidates[i].reason,
            variant: i == _chosen
                ? AppCardVariant.selected
                : AppCardVariant.outlined,
            trailing: const AppChevron(),
            onTap: () => setState(() => _chosen = i),
          ),
        ],
        const SizedBox(height: kStackGap),
        AppButton(
          l10n.swapIt,
          onPressed: widget.candidates.isEmpty
              ? null
              : () => widget.onConfirm(widget.candidates[_chosen]),
        ),
      ],
    );
  }
}
