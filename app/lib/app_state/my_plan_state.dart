/// Her plan: the copy of a split she changed, or the plan she started blank.
///
/// Phone only. It is in the local snapshot and in no cloud document, and
/// Delete everything clears it. With none, Train follows the split she chose.
library;

import 'package:flutter/foundation.dart' show VoidCallback;

import '../features/onboarding/domain/intake.dart' show LifeStage;
import '../features/train/domain/my_plan.dart';
import '../features/train/domain/train_repository.dart' show PlannedMove;
import '../features/train/domain/workout_library.dart';
import 'app_changes.dart';

/// What the plan editor needs of the plan it edits, so it can edit her plan or
/// a plan a coach is building for a client.
abstract interface class PlanEditing {
  MyPlan? get current;
  bool get hasPlan;
  void save(MyPlan next);
  void backToOriginal();
}

class MyPlanState implements PlanEditing {
  MyPlanState._();

  static final MyPlanState instance = MyPlanState._();

  MyPlan? plan;

  /// A plan the editor shows and she has not changed yet. Looking at a split in
  /// the editor keeps nothing: it becomes her plan with her first change, and
  /// is not in the snapshot, not followed by Train and not counted by
  /// [hasPlan].
  MyPlan? pending;

  /// What happens once the copy in [pending] is hers: the split it was copied
  /// from becomes the one she follows. Run once, by her first change or by
  /// opening a day to edit, never by looking.
  VoidCallback? _onConfirm;

  /// Whether she has a plan of her own.
  @override
  bool get hasPlan => plan != null;

  /// What the editor shows: her plan, else the copy she is looking at.
  @override
  MyPlan? get current => plan ?? pending;

  /// Sets the plan and tells every open screen.
  @override
  void save(MyPlan next) {
    plan = next;
    pending = null;
    confirmPending();
    AppChanges.bump();
  }

  /// Runs what was waiting on her keeping [pending], once.
  void confirmPending() {
    final confirm = _onConfirm;
    _onConfirm = null;
    confirm?.call();
  }

  /// Shows a copy of [template] in the editor without keeping it. A plan she
  /// already has is the one shown. Her first change in the editor, or Update on
  /// a day, is what keeps it, and then [onConfirm] runs.
  MyPlan preview(
    AuthoredProgramme template,
    LifeStage? stage, {
    VoidCallback? onConfirm,
  }) {
    final kept = plan;
    if (kept != null) return kept;
    _onConfirm = onConfirm;
    return pending = MyPlan.fork(template, stage: stage);
  }

  /// Shows an empty plan in the editor without keeping it.
  MyPlan previewBlank() {
    final kept = plan;
    if (kept != null) return kept;
    _onConfirm = null;
    return pending = const MyPlan.blank();
  }

  /// Drops her plan: Train follows the split again.
  @override
  void backToOriginal() {
    if (plan == null && pending == null) return;
    plan = null;
    pending = null;
    _onConfirm = null;
    AppChanges.bump();
  }

  /// Writes today's moves into the day that [slot] opens, forking [template]
  /// first when she has no plan. False when no day of the plan suits [stage].
  bool saveDayMoves({
    required AuthoredProgramme template,
    required LifeStage? stage,
    required int slot,
    required List<PlannedMove> moves,
  }) {
    // A copy she is looking at is the plan these moves go into, so the day she
    // opened is the day that changes. A blank one has no day to take them.
    final shown = pending;
    final next = planWithDayMoves(
      current: plan ?? (shown == null || shown.isBlank ? null : shown),
      template: template,
      stage: stage,
      slot: slot,
      moves: moves,
    );
    if (next == null) return false;
    save(next);
    return true;
  }

  /// The snapshot's say-so.
  void restore(MyPlan? saved) => plan = saved;

  /// Back to nothing: an account deleted, or a test.
  void reset() {
    plan = null;
    pending = null;
    _onConfirm = null;
  }
}
