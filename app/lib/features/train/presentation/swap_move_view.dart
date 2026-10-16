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
import 'workout_day_view.dart' show sampleWorkoutDay;

class SwapMoveView extends StatefulWidget {
  const SwapMoveView({
    super.key,
    this.onBack,
    this.onSwapped,
    this.onSelectTab,
    this.alternatives,
    this.moves,
    this.title,
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

  /// The day's title. Null is the sample day's.
  final String? title;

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

  /// True while the swap sheet is raised over the move list.
  bool _sheetOpen = false;

  TrainRepository get _repository =>
      widget.repository ?? (_fallback ??= InMemoryTrainRepository());

  /// What the repository found for the move, once it has answered.
  List<MoveAlternative>? _found;

  @override
  void initState() {
    super.initState();
    final repository = widget.repository;
    if (widget.alternatives == null && repository != null) {
      repository.alternativesFor(widget.exerciseId).then((found) {
        if (mounted) setState(() => _found = found);
      });
    }
    if (widget.openSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _offerSwap();
      });
    }
  }

  void _offerSwap() {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);
  }

  /// Closes the sheet and leaves her on the list she was looking at.
  void _dismiss() {
    if (!_sheetOpen) return;
    setState(() => _sheetOpen = false);
  }

  Future<void> _confirm(MoveAlternative choice) async {
    await _repository.swapMove(
      sessionId: widget.sessionId,
      fromExerciseId: widget.exerciseId,
      toExerciseId: choice.exerciseId,
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    widget.onSwapped?.call(choice);
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

    // The session the app actually has, not a hand-written list with a 12 kg
    // goblet squat in the middle of it. R03 offers this session as "Quiet · no
    // equipment · floor" and every move in it is bodyweight, so offering a
    // loaded swap underneath that promise was the app contradicting its own
    // subtitle.
    final behind =
        widget.moves ??
        (widget.repository == null
            ? sampleWorkoutDay(l10n).moves
            : const <PlannedMove>[]);

    return Scaffold(
      backgroundColor: AppColors.surface,
      // THE BAR IS THE TOP LAYER, AND THE SCRIM STOPS ABOVE IT.
      //
      // The same rule `already_did_it_view.dart` (T02) carries, applied to the
      // last screen that broke it. This sheet used to be a real
      // `showModalBottomSheet`, and a modal route's barrier covers the whole
      // window — so all three tabs were painted at the foot of R05, marked
      // live, and could not be touched: a finger on "Home" hit the barrier and
      // dismissed the sheet instead. `tester.semantics.tap` does not hit-test,
      // so every dead-control sweep in this repository passed it, and only
      // `r1_49d_tabs_finger_test.dart` (a real finger at the painted pixel)
      // could see it.
      //
      // The scrim and the sheet now live inside `body`, which in a Scaffold is
      // laid out ABOVE `bottomNavigationBar` and cannot reach it. She can leave
      // mid-swap, which is the whole point of drawing a bar at all.
      bottomNavigationBar: AppNavBar(
        // R05, not R01. The active tab is not a link to itself, so claiming
        // Train here drew the Train tab as the one she was on and gave it no
        // tap — a dead tab on a screen reached from Train.
        activeScreenId: 'R05',
        onSelect: widget.onSelectTab,
      ),
      body: Stack(
        children: [
          // The move list, still visible behind the sheet — she can see what
          // she is changing, which is why this is a sheet and not a page.
          AppScaffold(
            appBar: TrainTopBar(
              title: widget.title ?? l10n.legsAndGlutes,
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
          if (_sheetOpen) ...[
            Positioned.fill(
              child: Semantics(
                button: true,
                label: l10n.close,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  child: ColoredBox(
                    color: AppColors.ink.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            // Capped against the space this Stack actually has, not against the
            // window: a sheet that measured itself with MediaQuery.sizeOf
            // collapses to nothing wherever the ambient MediaQuery is not the
            // full screen.
            LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.92,
                  ),
                  child: AppSheet(
                    children: [
                      Text(l10n.swapThisMove, style: AppText.titleL),
                      _SwapChoices(
                        candidates:
                            widget.alternatives ??
                            _found ??
                            (widget.repository == null
                                ? _defaultAlternatives(l10n)
                                : const <MoveAlternative>[]),
                        onConfirm: _confirm,
                        onClose: _dismiss,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
  const _SwapChoices({
    required this.candidates,
    required this.onConfirm,
    required this.onClose,
  });

  final List<MoveAlternative> candidates;
  final ValueChanged<MoveAlternative> onConfirm;
  final VoidCallback onClose;

  @override
  State<_SwapChoices> createState() => _SwapChoicesState();
}

class _SwapChoicesState extends State<_SwapChoices> {
  int _chosen = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (widget.candidates.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.noSwapForThisMoveRightNow,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: kStackGap),
          AppButton(
            l10n.close,
            variant: AppButtonVariant.text,
            onPressed: widget.onClose,
          ),
        ],
      );
    }

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
            trailing: i == _chosen
                ? const Icon(Icons.check, color: AppColors.primary)
                : const AppChevron(),
            onTap: () => setState(() => _chosen = i),
          ),
        ],
        const SizedBox(height: kStackGap),
        AppButton(
          l10n.swapIt,
          onPressed: () => widget.onConfirm(widget.candidates[_chosen]),
        ),
      ],
    );
  }
}
