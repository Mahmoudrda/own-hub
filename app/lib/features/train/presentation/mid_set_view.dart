/// R07 — Mid-set. The screen this whole group exists for.
///
/// Matches `6-v2/src/screens-train.mjs` → `R07`. **One tap logs a set.** The
/// numbers are a sentence she agrees with, not two steppers to fight, and the
/// button states exactly what it will save — so confirming and logging are one
/// action rather than two.
///
/// ## Rule 1, precisely
///
/// The large "12 kg × 10" on this screen is the **prescription**: what the plan
/// asked for. There is no field anywhere on it holding what she did, empty or
/// otherwise, and nothing is pre-filled — which is the failure `P1-RULE-01`
/// exists to catch.
///
/// When she taps "Done · 12 kg × 10", the outcome is built from the numbers *the
/// button itself names*, at the moment of an explicit gesture. That is the one
/// permitted way a prescription becomes a result, and it is permitted precisely
/// because she read those numbers and agreed to them. What is forbidden — and
/// impossible here — is a "what did you do?" box that arrives already filled in
/// with the answer. If she did something else, R08 is two taps away.
///
/// ## Rule 9, mechanically
///
/// The tap goes through [LogCommandBus] and nothing else. The set is hers
/// immediately, the five seconds run *before* the write, and there is no dialog
/// on this path — there is no parameter on this screen that could produce one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;

import '../../../app_state/haptics.dart';
import '../../../app_state/move_notes.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_big_button.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/hand/hand.dart';
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import '../domain/load_advice.dart' show LoadKit, loadKitFor;
import '../domain/train_repository.dart';
import '../domain/warm_up.dart';
import '../domain/weight_label.dart';
import 'end_workout_sheet.dart';
import 'exercise_clip_frame.dart';
import 'exercise_clip_player.dart';
import 'plate_diagram.dart';
import 'set_labels.dart';
import 'train_widgets.dart';
import 'warm_up_toggle.dart';
import 'workout_day_view.dart' show localisedMove;
import 'session_notice.dart';
import '../../../ui/screen_art_strip.dart';
import 'exercise_labels.dart';

/// A warm-up set was saved: the log (for Undo on R09) and the set it holds.
typedef WarmUpLogged = void Function(LogHandle handle, SetOutcome outcome);

class MidSetView extends StatefulWidget {
  const MidSetView({
    super.key,
    this.onClose,
    this.onPause,
    this.onChange,
    this.onOpenHistory,
    this.gymHelpers = true,
    this.equipment,
    this.onSetLogged,
    this.onMoveLogged,
    this.move,
    this.sessionId = 'session',
    this.setIndex = 1,
    this.repository,
    this.bus,
    this.lastLogged,
    this.moveNumber,
    this.moveCount,
    this.sets,
    this.onAttach,
    this.onDetach,
    this.progressionLine,
    this.notice,
    this.clip,
    this.media,
    this.players,
    this.end,
    this.warmUps = const <SetOutcome>[],
    this.onWarmUpLogged,
  });

  /// The warm-up sets already saved for this move in this session. They are
  /// shown above the working sets, and a suggestion to warm up is made only
  /// while there are none.
  final List<SetOutcome> warmUps;

  /// A warm-up set was saved. Null hides the warm-up switch, so a warm-up can
  /// never fall through to [onSetLogged], which would count it as a working
  /// set.
  final WarmUpLogged? onWarmUpLogged;

  /// The way to end the workout from here. Null draws no control.
  final SessionEnd? end;

  /// The library's row for [move], when it holds one: its clip plays at the
  /// top of the page. Null keeps the page as it was.
  final LibraryExercise? clip;

  /// Where the clip's files come from. Without it no clip is drawn.
  final ExerciseMediaStore? media;

  /// Makes the player. Null draws the poster alone, as tests do.
  final ExerciseClipPlayerFactory? players;

  /// A swap or a skip that brought her here, with its Undo, drawn in the page
  /// above the move so it never covers the button she taps next.
  final SessionNotice? notice;

  final VoidCallback? onClose;

  /// Why the weight is what it is, for a loaded move she has trained before:
  /// the next weight up, or why it is not going up yet. Read from her own
  /// history by `loadAdviceFor`, and null for a move that has none.
  final String? progressionLine;

  /// Null draws no pause control. A pause icon that did nothing was on this
  /// screen, R09 and R13 for every woman.
  final VoidCallback? onPause;

  /// Sets of today's session behind her, for the bar under the title.
  final ({int done, int total})? sets;

  /// Told when this screen opens and closes, so the session's one log bus is
  /// committed when the last training screen goes, never dropped with it.
  final VoidCallback? onAttach;
  final VoidCallback? onDetach;

  /// R08 — she did something other than what was asked.
  final VoidCallback? onChange;

  /// Opens the history of this move. Null draws no History button.
  final VoidCallback? onOpenHistory;

  /// The kit this move uses. A barbell or Smith move shows the plate line.
  final Iterable<LibraryEquipment>? equipment;

  /// Whether the plate line and the move note are drawn.
  final bool gymHelpers;

  /// R09. The handle carries the five-second window, so the rest screen can
  /// offer Undo on the very log that was just made.
  final ValueChanged<LogHandle>? onSetLogged;

  /// R13. Logs every remaining set of this move at once and returns to the move
  /// list — **the session does not end.**
  final ValueChanged<LogHandle>? onMoveLogged;

  final PlannedMove? move;
  final String sessionId;

  /// Zero-based. The design shows set 2 of 3, so set 1 is already done.
  final int setIndex;

  final TrainRepository? repository;
  final LogCommandBus? bus;

  /// The last set she logged for this move, in an earlier session.
  ///
  /// Null when she has never logged one, which is the case for every woman on
  /// her first session — and the reason the progression note below is drawn
  /// from this rather than from the prescription. See `domain/set_history.dart`
  /// for where a caller gets it.
  final SetOutcome? lastLogged;

  /// Which move of how many, for the bar at the top.
  ///
  /// Both null renders no count rather than a fixed one. The bar said
  /// "Move 2 of 5" to a woman on the first move of four.
  final int? moveNumber;
  final int? moveCount;

  @override
  State<MidSetView> createState() => _MidSetViewState();
}

class _MidSetViewState extends State<MidSetView> {
  TrainRepository? _fallbackRepository;
  LogCommandBus? _fallbackBus;

  /// Whether the sets other than the current one are drawn.
  bool _allSets = false;

  /// Whether the move's cues are open under its clip.
  bool _cuesOpen = false;

  /// Whether the next set is a warm-up. Off whenever this screen opens.
  bool _warmUp = false;

  /// The moves whose clip would not play. Their page keeps no player at all.
  final Set<String> _unplayable = <String>{};

  TrainRepository get _repository =>
      widget.repository ?? (_fallbackRepository ??= InMemoryTrainRepository());

  LogCommandBus get _bus => widget.bus ?? (_fallbackBus ??= LogCommandBus());

  @override
  void initState() {
    super.initState();
    widget.onAttach?.call();
  }

  @override
  void didUpdateWidget(MidSetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.move?.exerciseId != widget.move?.exerciseId) {
      _cuesOpen = false;
      _warmUp = false;
    }
  }

  @override
  void dispose() {
    // Only the one this screen created. A bus passed in belongs to the caller,
    // and disposing it would drop a log the caller is still holding.
    _fallbackBus?.dispose();
    widget.onDetach?.call();
    super.dispose();
  }

  /// The move a caller that named none is shown.
  ///
  /// A fixture, and only a fixture: every route into R07 passes the move she is
  /// actually on, and the router falls back to the first move of the one
  /// authored session when there is no live one. Nothing a woman can reach
  /// renders this, which is why a 12 kg goblet squat here is not the
  /// twelve-kilogram prescription round one found inside a no-equipment
  /// session. That one came from the router passing nothing.
  PlannedMove _defaultMove(AppL10n l10n) => PlannedMove(
    exerciseId: 'goblet_squat',
    name: englishMoveNames.gobletSquat,
    prescriptionLabel: l10n.n12Kg10,
    sets: const [
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 1,
        weightKg: 12,
        reps: 10,
      ),
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 2,
        weightKg: 12,
        reps: 10,
      ),
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 3,
        weightKg: 12,
        reps: 10,
      ),
    ],
  );

  /// Builds the outcome from the numbers the button named.
  ///
  /// Takes them as arguments rather than reading the prescription itself, so the
  /// gesture is what supplies the values — there is no path here that copies a
  /// prescription into a result without one.
  LoggedSet _recordAgreed(PrescribedSet prescribed) =>
      LoggedSet(prescribed: prescribed).recording(
        SetOutcome(
          weightKg: prescribed.weightKg,
          reps: prescribed.reps,
          holdSeconds: prescribed.holdSeconds,
        ),
      );

  /// The set this screen is about.
  ///
  /// The button label and the log read the **same** set through this. They used
  /// to be independent — a fixed label beside an indexed log — which is how a
  /// button can name one set and save another. That is what R08 did, and it is
  /// not a class of bug worth leaving a second door open to.
  ///
  /// Bounds-checked rather than indexed blind: an out-of-range index would
  /// throw during *build*, taking the whole workout player down mid-session. A
  /// crash on tap is recoverable; a crash on render is not. (Written out rather
  /// than with `clamp`, whose static type is `num` and cannot index a list.)
  PrescribedSet? _prescribedOf(PlannedMove move) {
    if (move.sets.isEmpty) return null;
    final last = move.sets.length - 1;
    final index = widget.setIndex < 0
        ? 0
        : (widget.setIndex > last ? last : widget.setIndex);
    return move.sets[index];
  }

  /// The 1-based number of the set this screen is about.
  ///
  /// Bounds-checked exactly as [_prescribedOf] is, and for the same reason: the
  /// heading and the row list must name the set the button is going to write.
  int _setNumberOf(PlannedMove move) {
    if (move.sets.isEmpty) return 0;
    final last = move.sets.length - 1;
    final index = widget.setIndex < 0
        ? 0
        : (widget.setIndex > last ? last : widget.setIndex);
    return index + 1;
  }

  /// The warm-up set the button names while the switch is on. Both the label
  /// and the log read it from here, so the button never names one set and
  /// saves another.
  SetOutcome _warmUpOutcome(PrescribedSet prescribed) =>
      warmUpOutcomeFor(prescribed, lastKg: widget.lastLogged?.weightKg);

  /// Saves the warm-up set. It goes through the bus like any other log, but
  /// commits nothing to the repository: a warm-up is not a working set, so it
  /// never reaches the sets that bests, volume and the summary are read from.
  void _logWarmUp(PlannedMove move) {
    final l10n = AppL10n.of(context);
    final prescribed = _prescribedOf(move);
    final logged = widget.onWarmUpLogged;
    if (prescribed == null || logged == null) return;

    final outcome = _warmUpOutcome(prescribed);
    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.warmUpSavedFigure(_figure(l10n, outcome)),
        commit: () async {},
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    setState(() => _warmUp = false);
    logged(handle, outcome);
  }

  static String _figure(AppL10n l10n, SetOutcome outcome) => setFigure(
    l10n,
    weightKg: outcome.weightKg,
    reps: outcome.reps,
    holdSeconds: outcome.holdSeconds,
  );

  void _logOneSet(PlannedMove move) {
    final l10n = AppL10n.of(context);
    final prescribed = _prescribedOf(move);
    // The button that calls this is disabled in the same case. Belt and braces.
    if (prescribed == null) return;
    if (_warmUp && widget.onWarmUpLogged != null) {
      _logWarmUp(move);
      return;
    }

    final handle = _bus.submit(
      UndoableLog(
        // Names the same numbers the button named — read off the prescription
        // she just agreed to, never off a hardcoded string that would keep
        // saying "12 kg × 10" for a woman who was asked for something else.
        //
        // Through `setSavedLabel`, so a bodyweight set reads "12 reps" and a
        // hold reads "30 seconds". It used to force the loaded form with
        // `weightKg ?? 0`, which announced a glute bridge as "0 kg × 12" — a
        // weight she never lifted, in the sentence that offers her the undo.
        describe: setSavedLabel(
          l10n,
          setNumber: prescribed.order,
          weightKg: prescribed.weightKg,
          reps: prescribed.reps,
          holdSeconds: prescribed.holdSeconds,
        ),
        commit: () => _repository.flushMove(
          sessionId: widget.sessionId,
          exerciseId: move.exerciseId,
          sets: [_recordAgreed(prescribed)],
        ),
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    widget.onSetLogged?.call(handle);
  }

  /// The sage note under the prescription: what she did last time. Null when
  /// there is no last time.
  ///
  /// Every figure in it comes from [MidSetView.lastLogged], which is a set she
  /// logged. Nothing here reads a prescription for a number, so there is no
  /// path by which this line can state a session that did not happen.
  Widget? _progressionNote(AppL10n l10n, PrescribedSet? prescribed) {
    final line = widget.progressionLine;
    final last = widget.lastLogged;
    final was = last == null
        ? ''
        : setFigure(
            l10n,
            weightKg: last.weightKg,
            reps: last.reps,
            holdSeconds: last.holdSeconds,
          );
    if (line != null) {
      // The advice may already say what she did; when it does not, her last
      // result is stated beside it, so it is always in view.
      if (was.isEmpty || line.contains(was)) return AppSageNote(line);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSageNote(line),
          const SizedBox(height: 8),
          Text(
            l10n.lastTimeLast(was),
            key: const ValueKey('r07-last-time'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      );
    }
    // No history, nothing to say: an empty note is not worth a line mid-set.
    // A logged set with nothing in it to state is not claimed about either.
    if (last == null || was.isEmpty) return null;

    final lastKg = last.weightKg;
    final nowKg = prescribed?.weightKg;
    final added = (lastKg != null && nowKg != null) ? nowKg - lastKg : null;
    // The step is stated only when there is one. "So we added 0 kg" is not a
    // reason, and a lighter day is not something to announce as progress.
    if (added != null && added > 0) {
      return AppSageNote(
        l10n.lastTimeLastSoWeAddedAdded(was, weightLabel(added)),
      );
    }
    return AppSageNote(l10n.lastTimeLast(was));
  }

  void _logWholeMove(PlannedMove move) {
    final l10n = AppL10n.of(context);

    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.moveSavedSetsSets(
          isolateLtr(l10n, move.name),
          move.sets.length,
        ),
        commit: () => _repository.flushMove(
          sessionId: widget.sessionId,
          exerciseId: move.exerciseId,
          sets: [for (final set in move.sets) _recordAgreed(set)],
        ),
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    widget.onMoveLogged?.call(handle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // In the language on screen now, not the one the session started in.
    final move = localisedMove(l10n, widget.move ?? _defaultMove(l10n));
    final prescribed = _prescribedOf(move);
    final canWarmUp = widget.onWarmUpLogged != null && prescribed != null;
    final warmingUp = canWarmUp && _warmUp;

    final hasClip = widget.clip != null && widget.media != null;
    return AppScaffold(
      footerScrollsWhenLarge: true,
      // The clip is the picture; art stands in only when there is no clip
      // (the header) or it cannot play (the strip below).
      showArt: !hasClip,
      appBar: TrainTopBar(
        // Which move of how many, when the caller knows. It was the fixed
        // `move2Of5`, so the bar read "Move 2 of 5" above the first move of a
        // four-move session. A caller that does not know says nothing.
        title: moveTitle(l10n, widget.moveNumber, widget.moveCount),
        onClose: widget.onClose,
        sets: widget.sets,
        actions: [
          if (widget.onPause != null)
            IconButton(
              onPressed: widget.onPause,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              tooltip: l10n.pause,
              icon: const Icon(Icons.pause),
            ),
          if (widget.end case final end?) SessionEndButton(end: end),
        ],
      ),
      footer: [
        AppBigButton(
          // Names the set it is about to save, read from HER prescription.
          //
          // This was the fixed `done12Kg10`, so it read
          // "Done · 12 kg × 10" to every woman whatever her plan asked for —
          // and tapping it logged numbers the screen had never shown her. The
          // agreement between what the button says and what gets written is the
          // whole basis of rule 1's one permitted path from prescription to
          // result.
          //
          // Through `setDoneLabel`, which picks the sentence the set's own
          // shape asks for. Forcing the loaded form put "Done · 0 kg × 12" on
          // the first bodyweight move of the first session.
          prescribed == null
              ? l10n.done_54ca1
              : warmingUp
              ? _warmUpDoneLabel(l10n, _warmUpOutcome(prescribed))
              : setDoneLabel(
                  l10n,
                  weightKg: prescribed.weightKg,
                  reps: prescribed.reps,
                  holdSeconds: prescribed.holdSeconds,
                ),
          subtitle: l10n.restStartsItself,
          // A move with no sets has nothing to log, and _logOneSet would have
          // thrown on the index. A button that does nothing is better than one
          // that crashes her session.
          onPressed: prescribed == null ? null : () => _logOneSet(move),
        ),
        // For the woman training with the phone on the floor: the whole move in
        // one tap, and she stays in the session.
        //
        // "I did all 3 sets, log them" names three, and `_logWholeMove` logs
        // `move.sets.length` — so a four-set move offered to log three and
        // wrote four. The named figure is only offered to the woman it is true
        // of; everyone else gets the plain action, which is what the button
        // does either way. The dictionary gap is a `{sets}` form of this label.
        AppButton(
          statesHerFigure(states: 3, hers: move.sets.length)
              ? l10n.iDidAll3Sets
              : l10n.iDidThemAll,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: () => _logWholeMove(move),
        ),
      ],
      children: [
        if (widget.notice case final notice?)
          AppLiveUndoBar(
            handle: notice.handle,
            message: notice.handle.describe,
            undoLabel: l10n.undo,
            onUndo: notice.onUndo,
          ),
        if (widget.clip case final library?)
          if (widget.media case final media?)
            if (!_unplayable.contains(library.id)) ...[
              ExerciseClipFrame(
                key: ValueKey('r07-clip-${library.id}'),
                clipKey: const ValueKey('r07-clip'),
                exercise: library,
                media: media,
                players: widget.players,
                maxHeight: 220,
                onFailed: () {
                  if (mounted) setState(() => _unplayable.add(library.id));
                },
              ),
              if (move.cues.isNotEmpty)
                _FormCues(
                  label: l10n.formCues,
                  cues: move.cues,
                  open: _cuesOpen,
                  onTap: () => setState(() => _cuesOpen = !_cuesOpen),
                ),
            ] else
              const ScreenArtStrip(size: 76),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: MoveName(move.name, style: AppText.headline),
              ),
            ),
            IconButton(
              key: const ValueKey('r07-change'),
              tooltip: l10n.change,
              onPressed: widget.onChange,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              icon: const Icon(Icons.tune),
            ),
            if (widget.onOpenHistory != null)
              IconButton(
                key: const ValueKey('r07-history'),
                tooltip: l10n.history,
                onPressed: widget.onOpenHistory,
                iconSize: 24,
                color: AppColors.onSurfaceVariant,
                icon: const Icon(Icons.show_chart),
              ),
          ],
        ),
        if (widget.gymHelpers && move.exerciseId.isNotEmpty)
          _MoveNoteRow(
            key: ValueKey('r07-note-${move.exerciseId}'),
            exerciseId: move.exerciseId,
          ),
        AppCard(
          padding: const EdgeInsets.all(18),
          children: [
            Builder(
              builder: (context) {
                // The numbers she is agreeing to, underlined once. It is the
                // only mark on this screen: she reads it mid-set, one-handed,
                // and everything else stays plain print.
                //
                // Already display-sized, so it grows with the system text
                // size only so far — past that it would stack one word per
                // line — and at a large size the Change button goes under it.
                final scaler = MediaQuery.textScalerOf(context);
                final figure = HandUnderline(
                  level: HandLevel.crafted,
                  color: AppColors.primaryDim,
                  gap: 2,
                  child: Text(
                    move.prescriptionLabel,
                    textScaler: scaler.clamp(maxScaleFactor: 1.3),
                    style: AppText.display.copyWith(
                      fontSize: 38,
                      height: 46 / 38,
                      color: AppColors.onSurface,
                    ),
                  ),
                );
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: figure,
                );
              },
            ),
            // Why the weight moved. Progression explains itself rather than
            // arriving as a number she did not ask for.
            //
            // This was "Last Tuesday: 10 kg × 10, every set finished. So we
            // added 2 kg." — three figures about a session that had to have
            // happened. It was guarded by `statesHerFigure` against the
            // prescription `(12, 10)`, which is a sound guard defeated by the
            // one workout in the build prescribing exactly 12 kg × 10 to
            // everybody. So the first set a woman was ever asked to do cited a
            // Tuesday she had not trained.
            //
            // The note now reads her history (`lastLogged`) rather than her
            // prescription, so it reaches only a woman who has one. Where she
            // has none, the true thing to say is that this is the first, and
            // that what she logs today is the measure for the next one.
            ?_progressionNote(l10n, prescribed),
          ],
        ),
        if (widget.gymHelpers &&
            loadKitFor(widget.equipment) == LoadKit.barbell)
          PlateHelper(
            totalKg: warmingUp
                ? _warmUpOutcome(prescribed).weightKg
                : prescribed?.weightKg,
          ),
        if (canWarmUp) ...[
          WarmUpToggle(
            value: _warmUp,
            onChanged: (on) => setState(() => _warmUp = on),
          ),
          if (!_warmUp) ?_warmUpHint(l10n, move, prescribed),
        ],
        // The set she is on, and the rest one tap away.
        _ThisMoveHeading(
          label: l10n.thisMove,
          open: _allSets,
          onTap: () => setState(() => _allSets = !_allSets),
        ),
        // One row per set her move prescribes.
        //
        // These were three fixed rows, each valued `n12Kg10`, so a two-set
        // move grew a third set that did not exist and every row read
        // "12 kg x 10" however little that had to do with her plan.
        // Warm-ups she has saved, above the working sets and apart from them.
        for (final warm in widget.warmUps)
          SetRow(label: l10n.warmUp, value: _figure(l10n, warm), done: true),
        for (var i = 0; i < move.sets.length; i++)
          if (_allSets || i == _setNumberOf(move) - 1)
            SetRow(
              label: l10n.countOfTotal(
                countLabel(i + 1),
                countLabel(move.sets.length),
              ),
              value: _setValue(l10n, move, i),
              done: i < _setNumberOf(move) - 1,
              current: i == _setNumberOf(move) - 1,
            ),
      ],
    );
  }

  static String _warmUpDoneLabel(AppL10n l10n, SetOutcome outcome) {
    final figure = _figure(l10n, outcome);
    return figure.isEmpty ? l10n.done_54ca1 : l10n.doneWarmUpFigure(figure);
  }

  /// A quiet line before the first set of a loaded move that she has not
  /// warmed up for. Once only: it goes with her first warm-up, and it is not
  /// made again on the later sets.
  Widget? _warmUpHint(AppL10n l10n, PlannedMove move, PrescribedSet? set) {
    if (set == null || widget.warmUps.isNotEmpty) return null;
    if (_setNumberOf(move) != 1) return null;
    final working = set.weightKg;
    if (working == null || working <= 0) return null;
    final kg = _warmUpOutcome(set).weightKg;
    if (kg == null) return null;
    return Padding(
      key: const ValueKey('r07-warm-up-hint'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        l10n.warmUpWithAboutWeightFirstAround('${weightLabel(kg)} ${l10n.kg}'),
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  /// One set's own figure, never the whole move's "3 × 30 seconds" repeated on
  /// every row.
  static String _setValue(AppL10n l10n, PlannedMove move, int i) {
    final set = move.sets[i];
    final figure = setFigure(
      l10n,
      weightKg: set.weightKg,
      reps: set.reps,
      holdSeconds: set.holdSeconds,
    );
    return figure.isEmpty ? move.prescriptionLabel : figure;
  }
}

/// "This move", which opens the other sets when tapped.
class _ThisMoveHeading extends StatelessWidget {
  const _ThisMoveHeading({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: const ValueKey('r07-all-sets'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Form cues", which opens the move's cues under its clip when tapped.
class _FormCues extends StatelessWidget {
  const _FormCues({
    required this.label,
    required this.cues,
    required this.open,
    required this.onTap,
  });

  final String label;
  final List<String> cues;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        button: true,
        expanded: open,
        child: InkWell(
          key: const ValueKey('r07-form-cues'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
      if (open)
        for (final cue in cues)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 6),
            child: Text(cue, style: AppText.bodyM),
          ),
    ],
  );
}

/// The note she keeps for a move, under its name, with the way to write it.
class _MoveNoteRow extends StatefulWidget {
  const _MoveNoteRow({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<_MoveNoteRow> createState() => _MoveNoteRowState();
}

class _MoveNoteRowState extends State<_MoveNoteRow> {
  Future<void> _edit() async {
    final saved = await showAppSheet<String>(
      context: context,
      children: [
        _NoteSheet(initial: MoveNotes.instance.forMove(widget.exerciseId)),
      ],
    );
    if (saved == null) return;
    MoveNotes.instance.setFor(widget.exerciseId, saved);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final note = MoveNotes.instance.forMove(widget.exerciseId);
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey('r07-note'),
        onTap: _edit,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note ?? l10n.addNote,
                  key: const ValueKey('r07-note-text'),
                  style: AppText.bodyM.copyWith(
                    color: note == null
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Text(
                    l10n.editNote,
                    key: const ValueKey('r07-note-edit'),
                    style: AppText.label.copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({this.initial});

  final String? initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.noteForThisMove, style: AppText.titleL),
          const SizedBox(height: 4),
          Text(
            l10n.keptOnThisPhoneOnly,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          AppField(
            key: const ValueKey('r07-note-field'),
            controller: _controller,
            label: l10n.noteForThisMove,
            hint: l10n.seatAndPinNumbers,
            autofocus: true,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kMoveNoteMaxLength),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            l10n.save,
            key: const ValueKey('r07-note-save'),
            onPressed: () => Navigator.of(context).pop(_controller.text),
          ),
          if (widget.initial != null)
            AppButton(
              l10n.remove,
              key: const ValueKey('r07-note-remove'),
              variant: AppButtonVariant.text,
              height: 48,
              fontSize: 15,
              onPressed: () => Navigator.of(context).pop(''),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
