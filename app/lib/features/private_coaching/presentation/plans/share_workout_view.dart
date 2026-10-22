/// W03/W04/W08: a coach builds a workout plan for one client and publishes it.
///
/// She starts from one of the three splits, a template she saved, or a blank
/// plan; edits the days and moves in the plan editor on a copy of her own
/// (never her personal plan); names it; previews it as the client sees it;
/// and publishes. A plan already published is opened with [existing] and goes
/// out again as a new version of the same plan.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/honest_notice.dart';
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../train/data/exercise_media_store.dart';
import '../../../train/domain/custom_workout.dart';
import '../../../train/domain/exercise_library.dart';
import '../../../train/domain/my_plan.dart';
import '../../../train/domain/train_repository.dart' show PlannedMove;
import '../../../train/domain/workout_library.dart';
import '../../../train/presentation/authored_workout.dart';
import '../../../train/presentation/exercise_clip_player.dart';
import '../../../train/presentation/move_picker_view.dart';
import '../../../train/presentation/plan_editor_view.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_plan.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/coaching_failure.dart';
import '../../domain/subscription.dart';
import '../client/coach_plan_view.dart';
import '../coach/coach_text.dart';
import 'coach_day_editor_view.dart';
import 'coach_plan_logic.dart';
import 'plan_labels.dart';

class ShareWorkoutView extends StatefulWidget {
  const ShareWorkoutView({
    super.key,
    required this.repository,
    required this.subscription,
    this.clientName = '',
    this.splits = const <AuthoredProgramme>[],
    this.templates = const <CoachDraft>[],
    this.existing,
    this.exercises = const <LibraryExercise>[],
    this.media = const NoExerciseMedia(),
    this.players,
    this.onBack,
    this.onPublished,
  });

  final CoachingRepository repository;
  final Subscription subscription;

  /// What the client is called on the buttons.
  final String clientName;

  /// The three coach splits, as they are written.
  final List<AuthoredProgramme> splits;

  /// The coach's saved drafts. Only the workout ones are offered.
  final List<CoachDraft> templates;

  /// A plan already published to this client, to send again as a new version.
  final CoachPlan? existing;

  /// The exercise library: the move picker, the clips and the checks.
  final List<LibraryExercise> exercises;
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory? players;
  final VoidCallback? onBack;

  /// Told when the server has the plan.
  final void Function(String planId, int revision)? onPublished;

  @override
  State<ShareWorkoutView> createState() => _ShareWorkoutViewState();
}

class _ShareWorkoutViewState extends State<ShareWorkoutView> {
  late final CoachPlanEditState _edit = CoachPlanEditState(
    widget.existing?.workout,
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  AuthoredProgramme? _split;
  bool _busy = false;
  bool _published = false;
  bool _templateSaved = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  LibraryExercise? _byId(String id) {
    for (final e in widget.exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _start(MyPlan plan, {AuthoredProgramme? split, String? name}) {
    _split = split;
    if (name != null && _name.text.trim().isEmpty) _name.text = name;
    _edit.save(plan);
  }

  Future<List<LibraryExercise>?> _pickExercises() => pickMoves(
    context,
    exercises: widget.exercises,
    media: widget.media,
    players: widget.players,
  );

  Future<List<PlannedMove>?> _pickMoves() async {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final picked = await _pickExercises();
    if (picked == null || picked.isEmpty) return null;
    return [
      for (final e in picked)
        plannedMoveFromCustom(l10n, lang, CustomMove.starter(e), exercise: e),
    ];
  }

  Future<void> _editDays() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (editor) => PlanEditorView(
          state: _edit,
          original: _split == null ? null : () => _split,
          onBack: () => Navigator.of(editor).maybePop(),
          onPickMoves: _pickMoves,
          onEditDay: (day) => unawaited(
            Navigator.of(editor).push<void>(
              MaterialPageRoute<void>(
                builder: (dayRoute) => CoachDayEditorView(
                  state: _edit,
                  dayIndex: day,
                  pickExercises: _pickExercises,
                  exerciseFor: _byId,
                  media: widget.media,
                  players: widget.players,
                  onBack: () => Navigator.of(dayRoute).maybePop(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  MyPlan? get _plan {
    final plan = _edit.current;
    if (plan == null) return null;
    return renamedPlan(plan, _name.text);
  }

  List<PlanProblem> _problems() => coachWorkoutProblems(
    _plan ?? const MyPlan.blank(),
    _name.text,
    known: widget.exercises.isEmpty ? null : (id) => _byId(id) != null,
  );

  Future<void> _publish() async {
    final l10n = AppL10n.of(context);
    final plan = _plan;
    final problems = _problems();
    if (plan == null || problems.isNotEmpty) {
      setState(
        () => _error = problems.isEmpty
            ? l10n.addAtLeastOneDayFirst
            : problemText(l10n, problems.first),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final stamped = stampSafetyTags(plan, _byId);
      final sent = await widget.repository.publishCoachPlan(
        subId: widget.subscription.id,
        name: _name.text.trim(),
        workout: stamped,
        planId: widget.existing?.id,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _published = true;
      });
      widget.onPublished?.call(sent.planId, sent.revision);
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coachFailureText(l10n, failure);
      });
      // The line under the form can be out of sight on a long plan.
      showHonestNotice(context, _error);
    }
  }

  Future<void> _saveTemplate() async {
    final l10n = AppL10n.of(context);
    final plan = _plan;
    if (plan == null || plan.days.isEmpty || _name.text.trim().isEmpty) {
      setState(
        () => _error = _name.text.trim().isEmpty
            ? l10n.giveThePlanANameFirst
            : l10n.addAtLeastOneDayFirst,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await widget.repository.saveDraft(
        CoachDraft(
          id: '',
          kind: PlanKind.workout,
          name: _name.text.trim(),
          body: plan.toJson(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _templateSaved = true;
      });
    } on CoachingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = coachFailureText(l10n, failure);
      });
      // The line under the form can be out of sight on a long plan.
      showHonestNotice(context, _error);
    }
  }

  void _preview() {
    final plan = _plan;
    if (plan == null) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (route) => CoachPlanView(
            plan: CoachPlan(
              id: 'preview',
              kind: PlanKind.workout,
              name: _name.text.trim(),
              revision: (widget.existing?.revision ?? 0) + 1,
              workout: plan,
            ),
            exercises: widget.exercises,
            media: widget.media,
            players: widget.players,
            preview: true,
            onBack: () => Navigator.of(route).maybePop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final first = widget.clientName.trim();
    return ListenableBuilder(
      listenable: AppChanges.instance,
      builder: (context, _) {
        final plan = _edit.current;
        return AppScaffold(
          appBar: AppTopBar(title: l10n.shareAWorkoutPlan, onBack: _back),
          footer: plan == null || _published
              ? const []
              : [
                  AppButton(
                    widget.existing == null
                        ? l10n.publishToName(first)
                        : l10n.publishAsANewVersion,
                    key: const ValueKey('workout-publish'),
                    onPressed: _busy ? null : _publish,
                  ),
                ],
          children: [
            if (first.isNotEmpty)
              Text(
                l10n.planForName(first),
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            if (_published)
              AppCard(
                variant: AppCardVariant.sage,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.publishedNameCanSeeItNow(first),
                      key: const ValueKey('workout-published'),
                      style: AppText.titleS,
                    ),
                  ),
                  AppButton(
                    l10n.back,
                    variant: AppButtonVariant.outlined,
                    onPressed: _back,
                  ),
                ],
              )
            else if (plan == null)
              ..._starts(l10n, lang)
            else ...[
              AppField(
                key: const ValueKey('workout-name'),
                controller: _name,
                label: l10n.planName,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(CoachingLimits.planNameMax),
                ],
                onChanged: (_) => setState(() => _error = ''),
              ),
              if (widget.existing != null)
                Text(
                  l10n.versionN(countLabel(widget.existing!.revision + 1)),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              for (var i = 0; i < plan.days.length; i++)
                AppListItem(
                  key: ValueKey('workout-day-$i'),
                  title: plan.days[i].session.title(lang),
                  subtitle: <String>[
                    l10n.minutesMin(countLabel(plan.days[i].session.minutes)),
                    l10n.countPluralOne1MoveOtherCount(
                      plan.days[i].session.moves.length,
                    ),
                  ].join(' · '),
                ),
              AppButton(
                l10n.editDaysAndMoves,
                key: const ValueKey('workout-edit'),
                variant: AppButtonVariant.tonal,
                onPressed: _busy ? null : _editDays,
              ),
              AppButton(
                l10n.seeItFirst,
                key: const ValueKey('workout-preview'),
                variant: AppButtonVariant.outlined,
                onPressed: plan.days.isEmpty ? null : _preview,
              ),
              if (_templateSaved)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.templateSaved,
                    key: const ValueKey('workout-template-saved'),
                    style: AppText.bodyM,
                  ),
                )
              else
                AppButton(
                  l10n.saveAsATemplate,
                  key: const ValueKey('workout-save-template'),
                  variant: AppButtonVariant.text,
                  height: 48,
                  fontSize: 15,
                  onPressed: _busy ? null : _saveTemplate,
                ),
            ],
            if (_error.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error,
                  key: const ValueKey('workout-error'),
                  style: AppText.bodyM.copyWith(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _starts(AppL10n l10n, String lang) {
    final mine = [
      for (final t in widget.templates)
        if (t.kind == PlanKind.workout) t,
    ];
    return [
      Semantics(
        header: true,
        child: Text(l10n.startFrom, style: AppText.titleL),
      ),
      if (widget.splits.isNotEmpty) ...[
        Text(l10n.oneOfTheThreeSplits, style: AppText.titleS),
        for (var i = 0; i < widget.splits.length; i++)
          AppListItem(
            key: ValueKey('workout-split-$i'),
            title: lang == 'ar'
                ? widget.splits[i].titleAr
                : widget.splits[i].titleEn,
            subtitle: <String>[
              l10n.daysPluralOne1DayOtherDays(widget.splits[i].sessions.length),
              l10n.countPluralOne1MoveOtherCount(
                widget.splits[i].sessions.fold<int>(
                  0,
                  (a, s) => a + s.moves.length,
                ),
              ),
            ].join(' · '),
            onTap: () => _start(
              planFromSplit(widget.splits[i]),
              split: widget.splits[i],
              name: lang == 'ar'
                  ? widget.splits[i].titleAr
                  : widget.splits[i].titleEn,
            ),
          ),
      ],
      if (mine.isNotEmpty) ...[
        Text(l10n.yourTemplates, style: AppText.titleS),
        for (var i = 0; i < mine.length; i++)
          AppListItem(
            key: ValueKey('workout-template-$i'),
            title: mine[i].name,
            onTap: () {
              final plan = planFromBody(mine[i].body);
              if (plan != null) _start(plan, name: mine[i].name);
            },
          ),
      ],
      AppListItem(
        key: const ValueKey('workout-blank'),
        title: l10n.blankPlan,
        leading: const Icon(Icons.add, size: 24, color: AppColors.primaryDim),
        onTap: () => _start(const MyPlan.blank()),
      ),
    ];
  }
}
