/// Her plan, day by day: open a day to change its moves, put a day back as the
/// split wrote it, take a day out or add one, start again from nothing, or go
/// back to the split she began with.
///
/// The screen holds no copy of the plan. It reads and writes [MyPlanState], so
/// what she sees is what Train follows. Opening a day, and picking moves for a
/// new one, are the caller's: this screen has no idea where R03 or the move
/// catalogue live.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../app_state/my_plan_state.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../domain/my_plan.dart';
import '../domain/programme_week.dart' show programmeSessionsFor;
import '../domain/train_repository.dart';
import '../domain/workout_library.dart';
import 'custom_workout_builder_view.dart';
import 'plan_entry_cards.dart';

class PlanEditorView extends StatefulWidget {
  const PlanEditorView({
    super.key,
    required this.onEditDay,
    required this.onPickMoves,
    this.original,
    this.stage,
    this.onBack,
    this.state,
    this.title,
    this.undoBus,
    this.allowWeeks = false,
  });

  /// Opens day [index] of the plan in R03 with Edit workout on.
  final ValueChanged<int> onEditDay;

  /// Opens the catalogue and answers the moves she added, already prescribed.
  final Future<List<PlannedMove>?> Function() onPickMoves;

  /// The split her plan was copied from, as it is written, for putting a day
  /// back and for taking another day's moves. Null when she started blank.
  final AuthoredProgramme? Function()? original;

  final LifeStage? stage;

  final VoidCallback? onBack;
  final PlanEditing? state;

  /// The bar title; "My plan" when null.
  final String? title;
  final LogCommandBus? undoBus;
  final bool allowWeeks;

  @override
  State<PlanEditorView> createState() => _PlanEditorViewState();
}

class _PlanEditorViewState extends State<PlanEditorView> {
  final LogCommandBus _ownBus = LogCommandBus();

  LogCommandBus get _bus => widget.undoBus ?? _ownBus;
  PlanEditing get _state => widget.state ?? MyPlanState.instance;
  MyPlan get _plan => _state.current ?? const MyPlan.blank();
  AuthoredProgramme? get _original => widget.original?.call();
  String get _language => Localizations.localeOf(context).languageCode;

  void _back() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _remove(int i) {
    final before = _plan;
    if (i >= before.days.length) return;
    final gone = before.days[i];
    final removed = gone.session.title(_language);
    _state.save(before.withoutDay(i));
    final l10n = AppL10n.of(context);
    final handle = _bus.submit(
      UndoableLog(describe: l10n.removedName(removed), commit: () async {}),
    );
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: l10n.undo,
      onUndo: () {
        // Only that day comes back; anything changed since stays changed.
        if (mounted) _state.save(_plan.insertDay(i, gone));
      },
    );
  }

  void _duplicate(int i) {
    final copy = lookupAppL10n(const Locale('en')).copy_1g7xp;
    final copyAr = lookupAppL10n(const Locale('ar')).copy_1g7xp;
    _state.save(_plan.withCopyOf(i, suffixEn: ' $copy', suffixAr: ' $copyAr'));
  }

  Future<void> _replace(int i) async {
    final l10n = AppL10n.of(context);
    final original = _original;
    if (original == null) return;
    final plan = _plan;
    final days = programmeSessionsFor(original, widget.stage);
    await showAppSheet<void>(
      context: context,
      children: [
        Text(l10n.replaceThisDay, style: AppText.titleL),
        if (plan.canRestore(i, original, widget.stage))
          AppListItem(
            key: ValueKey('plan-restore-$i'),
            title: l10n.putThisDayBackAsItWas,
            leading: const Icon(
              Icons.restart_alt,
              size: 24,
              color: AppColors.primaryDim,
            ),
            onTap: () {
              Navigator.of(context).pop();
              _state.save(_plan.restoreDay(i, original, stage: widget.stage));
            },
          ),
        if (days.isNotEmpty) ...[
          Text(
            l10n.orUseTheMovesOfAnotherDay,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          for (var j = 0; j < days.length; j++)
            AppListItem(
              key: ValueKey('plan-use-$i-$j'),
              title: days[j].title(_language),
              subtitle: l10n.minutesMinutesMovesMoves(
                countLabel(days[j].minutes),
                countLabel(days[j].moves.length),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _state.save(_plan.withDayFrom(i, days[j]));
              },
            ),
        ],
      ],
    );
  }

  Future<void> _addDay() async {
    final l10n = AppL10n.of(context);
    final plan = _plan;
    await showAppSheet<void>(
      context: context,
      children: [
        Text(l10n.addADay, style: AppText.titleL),
        AppListItem(
          key: const ValueKey('plan-add-blank'),
          title: l10n.blankDay,
          leading: const Icon(Icons.add, size: 24, color: AppColors.primaryDim),
          onTap: () {
            Navigator.of(context).pop();
            unawaited(_buildBlank());
          },
        ),
        for (var i = 0; i < plan.days.length; i++)
          AppListItem(
            key: ValueKey('plan-add-copy-$i'),
            title: l10n.copyOfName(plan.days[i].session.title(_language)),
            leading: const Icon(
              Icons.copy_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            onTap: () {
              Navigator.of(context).pop();
              _state.save(_plan.withCopyOf(i));
            },
          ),
      ],
    );
  }

  Future<void> _buildBlank() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (builder) => CustomWorkoutBuilderView(
          forPlan: true,
          onPickMoves: widget.onPickMoves,
          onSave: (name, moves) {
            _state.save(
              _plan.withNewDay(
                name,
                moves,
                titleEn: lookupAppL10n(const Locale('en'))
                    .dayNumber(countLabel(_plan.days.length + 1)),
                titleAr: lookupAppL10n(const Locale('ar'))
                    .dayNumber(countLabel(_plan.days.length + 1)),
              ),
            );
            Navigator.of(builder).pop();
            return true;
          },
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String yes,
    required Key yesKey,
  }) async {
    final answer = await showPlanConfirm(
      context,
      title: title,
      body: body,
      yes: yes,
      no: AppL10n.of(context).cancel,
      yesKey: yesKey,
      noKey: const ValueKey('plan-confirm-cancel'),
    );
    return answer && mounted;
  }

  Future<void> _startFromScratch() async {
    final l10n = AppL10n.of(context);
    if (!_plan.isBlank) {
      final yes = await _confirm(
        title: l10n.startFromABlankPlan,
        body: l10n.thisRemovesEveryDayFromYourPlan,
        yes: l10n.clearMyPlan,
        yesKey: const ValueKey('plan-scratch-yes'),
      );
      if (!yes) return;
    }
    _state.save(_plan.cleared());
  }

  Future<void> _backToOriginal() async {
    final l10n = AppL10n.of(context);
    final yes = await _confirm(
      title: l10n.goBackToTheOriginalSplit,
      body: l10n.yourChangesToThePlanWillBe,
      yes: l10n.goBackToTheOriginal,
      yesKey: const ValueKey('plan-original-yes'),
    );
    if (!yes) return;
    _state.backToOriginal();
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return ListenableBuilder(
      listenable: AppChanges.instance,
      builder: (context, _) {
        final plan = _plan;
        final canReplace = _original != null;
        return AppScaffold(
          appBar: AppTopBar(title: widget.title ?? l10n.myPlan, onBack: _back),
          footer: [
            AppButton(
              l10n.addADay,
              key: const ValueKey('plan-add-day'),
              icon: Icons.add,
              onPressed: plan.isFull ? null : _addDay,
            ),
          ],
          children: [
            Text(
              plan.isBlank
                  ? l10n.noDaysYetAddYourFirstDay
                  : l10n.theseAreYourTrainingDaysOpenA,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            for (var i = 0; i < plan.days.length; i++) ...[
              if (widget.allowWeeks &&
                  plan.weekCount > 1 &&
                  (i == 0 || plan.days[i].week != plan.days[i - 1].week))
                Semantics(
                  header: true,
                  child: Text(
                    l10n.weekN(countLabel(plan.days[i].week)),
                    key: ValueKey('plan-week-${plan.days[i].week}'),
                    style: AppText.titleS,
                  ),
                ),
              AppCard(
                key: ValueKey('plan-day-$i'),
                variant: AppCardVariant.outlined,
                borderRadius: AppRadius.md,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                gap: 4,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            '${countLabel(i + 1)}. '
                            '${plan.days[i].session.title(_language)}',
                            style: AppText.titleM,
                          ),
                        ),
                      ),
                      if (i > 0)
                        IconButton(
                          key: ValueKey('plan-up-$i'),
                          tooltip: l10n.moveEarlier,
                          onPressed: () =>
                              _state.save(_plan.withDayMoved(i, i - 1)),
                          icon: const Icon(Icons.arrow_upward, size: 22),
                        ),
                      if (i < plan.days.length - 1)
                        IconButton(
                          key: ValueKey('plan-down-$i'),
                          tooltip: l10n.moveLater,
                          onPressed: () =>
                              _state.save(_plan.withDayMoved(i, i + 1)),
                          icon: const Icon(Icons.arrow_downward, size: 22),
                        ),
                    ],
                  ),
                  Text(
                    l10n.minutesMinutesMovesMoves(
                      countLabel(plan.days[i].session.minutes),
                      countLabel(plan.days[i].session.moves.length),
                    ),
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      _DayAction(
                        key: ValueKey('plan-edit-$i'),
                        label: l10n.edit,
                        icon: Icons.edit_outlined,
                        onPressed: () => widget.onEditDay(i),
                      ),
                      if (canReplace)
                        _DayAction(
                          key: ValueKey('plan-replace-$i'),
                          label: l10n.replace,
                          icon: Icons.swap_horiz,
                          onPressed: () => unawaited(_replace(i)),
                        ),
                      _DayAction(
                        key: ValueKey('plan-duplicate-$i'),
                        label: l10n.duplicate,
                        icon: Icons.copy_outlined,
                        onPressed: plan.isFull ? null : () => _duplicate(i),
                      ),
                      _DayAction(
                        key: ValueKey('plan-remove-$i'),
                        label: l10n.removeDay,
                        icon: Icons.delete_outline,
                        onPressed: () => _remove(i),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (widget.allowWeeks)
              AppButton(
                l10n.repeatLastWeek,
                key: const ValueKey('plan-repeat-week'),
                variant: AppButtonVariant.outlined,
                height: 48,
                fontSize: 16,
                onPressed: plan.isBlank || plan.weekCount >= kMaxCoachPlanWeeks
                    ? null
                    : () => _state.save(_plan.withRepeatedLastWeek()),
              ),
            AppButton(
              l10n.startFromScratch,
              key: const ValueKey('plan-scratch'),
              variant: AppButtonVariant.text,
              height: 48,
              fontSize: 15,
              onPressed: () => unawaited(_startFromScratch()),
            ),
            if (_state.hasPlan)
              AppButton(
                l10n.backToTheOriginalSplit,
                key: const ValueKey('plan-original'),
                variant: AppButtonVariant.text,
                height: 48,
                fontSize: 15,
                onPressed: () => unawaited(_backToOriginal()),
              ),
          ],
        );
      },
    );
  }
}

class _DayAction extends StatelessWidget {
  const _DayAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.primaryDim,
      padding: const EdgeInsets.symmetric(horizontal: 10),
    ),
    icon: Icon(icon, size: 20),
    label: Text(label, style: AppText.label.copyWith(fontSize: 15)),
  );
}
