/// R08 — Change a set.
///
/// Matches `6-v2/src/screens-train.mjs` → `R08`. **Two taps, no keyboard.** This
/// is the exception path: she did something other than what was asked, and the
/// chips hold the values she is likeliest to mean — what was planned, one step
/// either side, and what she did last time.
///
/// The keyboard exists behind "Type a different number" and nowhere else. A
/// woman mid-set, one-handed, should not be made to dismiss a numeric keypad to
/// see the set she is editing.
///
/// **A hard set never lowers her weight.** The note says so, and the mechanism
/// backs it: this screen writes an *outcome* and never a prescription. What she
/// lifted today does not rewrite what she is asked for next time — that decision
/// belongs to progression, which lives in the plan and which nothing here can
/// reach.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/haptics.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../domain/train_repository.dart';
import '../domain/weight_label.dart';
import 'set_labels.dart';
import 'train_widgets.dart';

/// What she chose, handed back to the caller.
class ChangedSet {
  const ChangedSet({required this.outcome, required this.prescribed});

  /// What she did. Never merged into the prescription.
  final SetOutcome outcome;

  /// What was asked, unchanged, for the caller to compare against.
  final PrescribedSet prescribed;
}

/// R13's way into R08: one set she already logged, on one move, to change.
class SetCorrection {
  const SetCorrection({
    required this.move,
    required this.moveNumber,
    required this.set,
  });

  final PlannedMove move;

  /// 1-based, for the bar at the top.
  final int moveNumber;

  final LoggedSet set;
}

class ChangeSetView extends StatefulWidget {
  const ChangeSetView({
    super.key,
    this.onClose,
    this.onSaved,
    this.onTypeANumber,
    this.prescribed = const PrescribedSet(
      exerciseId: 'goblet_squat',
      order: 2,
      weightKg: 12,
      reps: 10,
    ),
    this.moveName,
    this.moveNumber,
    this.moveCount,
    this.weightOptionsKg = const [10, 12, 14],
    this.repOptions,
    this.openSheet = true,
    this.sessionId = 'session',
    this.repository,
    this.bus,
    this.sets,
    this.onAttach,
    this.onDetach,
    this.progressionLine,
    this.askWeight = false,
    this.correcting = false,
  });

  /// R13's "change a set she already logged": the save replaces what was
  /// written for this set instead of logging it again, and the session does
  /// not move on.
  final bool correcting;

  final VoidCallback? onClose;

  /// Why the weight is what it is, from her own history (see R07). Replaces
  /// the fixed note when there is one.
  final String? progressionLine;

  /// A loaded move the plan gave no weight: the sheet offers weights anyway,
  /// from [weightOptionsKg], so the session can record what she lifted.
  final bool askWeight;

  /// Sets of today's session behind her, for the bar under the title.
  final ({int done, int total})? sets;

  /// Told when this screen opens and closes, as R07 is, so the session's bus
  /// is committed when the last training screen goes.
  final VoidCallback? onAttach;
  final VoidCallback? onDetach;

  /// R09 — the rest screen, carrying the log this screen just made, so the undo
  /// bar there names *her* numbers and Undo reaches this very write.
  final ValueChanged<LogHandle>? onSaved;

  /// Which move of how many, for the bar at the top.
  ///
  /// Both null renders no count rather than a fixed one. The bar carried
  /// `move2Of5` — "Move 2 of 5" — over the first move of a four-move session.
  final int? moveNumber;
  final int? moveCount;

  /// The only route to a keyboard on this screen.
  final VoidCallback? onTypeANumber;

  final PrescribedSet prescribed;
  final String? moveName;

  /// The planned weight and one step either side.
  final List<double> weightOptionsKg;

  /// Reps she is likeliest to mean. Bare numerals: see the note in build().
  /// Null builds them around the set she was asked for ([repOptionsAround]).
  final List<int>? repOptions;

  /// R08 *is* the sheet raised over the set, so it opens by default.
  final bool openSheet;

  final String sessionId;

  final TrainRepository? repository;
  final LogCommandBus? bus;

  @override
  State<ChangeSetView> createState() => _ChangeSetViewState();
}

class _ChangeSetViewState extends State<ChangeSetView> {
  TrainRepository? _fallbackRepository;
  LogCommandBus? _fallbackBus;

  TrainRepository get _repository =>
      widget.repository ?? (_fallbackRepository ??= InMemoryTrainRepository());

  LogCommandBus get _bus => widget.bus ?? (_fallbackBus ??= LogCommandBus());

  @override
  void initState() {
    super.initState();
    widget.onAttach?.call();
    if (widget.openSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSheet();
      });
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

  Future<void> _openSheet() async {
    var saved = false;
    await showAppSheet<void>(
      context: context,
      children: [
        _ChangeSetSheet(
          prescribed: widget.prescribed,
          moveName: widget.moveName,
          weightOptionsKg: widget.weightOptionsKg,
          // A hold is changed in seconds. It used to be offered rep chips —
          // 8, 9, 10, 12 — and the one she tapped was written as reps onto a
          // plank.
          repOptions:
              widget.repOptions ??
              (_isHold(widget.prescribed)
                  ? holdOptionsAround(widget.prescribed)
                  : repOptionsAround(widget.prescribed)),
          hold: _isHold(widget.prescribed),
          askWeight: widget.askWeight,
          progressionLine: widget.progressionLine,
          onTypeANumber: widget.onTypeANumber,
          onSave: (changed) {
            saved = true;
            Navigator.of(context).pop();
            _log(changed);
          },
        ),
      ],
    );
    // Closed without saving: back to where she came from. This page is only
    // the backdrop for the sheet, and left on its own it was a blank page
    // with a move name and an X.
    if (!saved && mounted) widget.onClose?.call();
  }

  /// Writes what she actually did, through the one logging path (§2 rule 9).
  ///
  /// This screen used to hand its [ChangedSet] to the caller and stop there. The
  /// router assigned it to a field nothing ever read, so an override was never
  /// written at all — and R09 then announced the *prescribed* numbers she had
  /// just corrected. The change is a real log now, and the handle carries her
  /// numbers to the rest screen so Undo reaches this very write.
  ///
  /// Rule 1 is intact: what persists is a [SetOutcome] recorded against the
  /// prescription. Nothing here rewrites what she is asked for next time.
  void _log(ChangedSet changed) {
    final l10n = AppL10n.of(context);

    // Null weight means bodyweight, and it is carried through as null rather
    // than defaulted to zero. The sheet no longer offers a weight for a set the
    // plan gave none, so "0 kg x 12" is a sentence about a weight she never
    // lifted — `setSavedLabel` says "12 reps" instead.
    final weightKg = changed.outcome.weightKg ?? changed.prescribed.weightKg;
    final hold = changed.outcome.holdSeconds;
    final reps = hold != null
        ? null
        : changed.outcome.reps ?? changed.prescribed.reps;

    final handle = _bus.submit(
      UndoableLog(
        // Her numbers, not the plan's. That is the entire point of this screen.
        describe: setSavedLabel(
          l10n,
          setNumber: changed.prescribed.order,
          weightKg: weightKg,
          reps: reps,
          holdSeconds: hold ?? changed.prescribed.holdSeconds,
        ),
        commit: widget.correcting
            ? () => _repository.replaceSet(
                sessionId: widget.sessionId,
                exerciseId: changed.prescribed.exerciseId,
                set: LoggedSet(prescribed: changed.prescribed)
                    .recording(changed.outcome),
              )
            : () => _repository.flushMove(
                sessionId: widget.sessionId,
                exerciseId: changed.prescribed.exerciseId,
                sets: [
                  LoggedSet(prescribed: changed.prescribed)
                      .recording(changed.outcome),
                ],
              ),
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    widget.onSaved?.call(handle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: TrainTopBar(
        title: moveTitle(l10n, widget.moveNumber, widget.moveCount),
        onClose: widget.onClose,
        sets: widget.sets,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.moveName ?? l10n.gobletSquat, style: AppText.headline),
            // "Set 2 of 3" is not said here.
            //
            // R08 is raised over ONE set and is given that set alone —
            // `prescribed.order` is known, the number of sets in the move is
            // not. The fixed `set2Of3` filled the gap by naming the
            // prototype's, so a woman correcting the first of four sets read
            // "Set 2 of 3". R07 states the same line from `move.sets`, where
            // both halves are real; here neither a total nor a parameterised
            // "Set {n}" exists, so nothing is stated.
          ],
        ),
      ],
    );
  }
}

/// The reps she most likely did, around what she was asked for.
///
/// Mostly fewer, because the usual reason to change a set is not finishing
/// it, and one step more for the day it went well. The asked-for number is
/// always among them and is what the sheet opens on, so a set she did as
/// asked is one tap. It used to be a fixed 8, 9, 10, 12 with 8 chosen, so a
/// woman asked for 15 had to find a keyboard to say 14.
/// A timed hold: seconds asked for, and no reps.
bool _isHold(PrescribedSet set) =>
    set.reps == null && (set.holdSeconds ?? 0) > 0;

/// The planned weight and one step either side, for a loaded set. Empty for a
/// bodyweight one.
///
/// The router passed nothing, so every loaded set was offered the widget's own
/// 10, 12 and 14 kg — and a plan asking for 17.5 kg opened with 10 selected,
/// because the planned weight was not among the chips at all.
List<double> weightOptionsAround(PrescribedSet set, {double step = 2}) {
  final planned = set.weightKg;
  if (planned == null || planned <= 0) return const <double>[];
  return {
    for (final kg in [planned - step, planned, planned + step])
      if (kg > 0) kg,
  }.toList()..sort();
}

/// Seconds she most likely held, around the hold she was asked for.
List<int> holdOptionsAround(PrescribedSet set) {
  final asked = set.holdSeconds;
  if (asked == null || asked <= 0) return const <int>[];
  return {
    for (final s in [asked - 10, asked - 5, asked, asked + 5, asked + 10])
      if (s > 0) s,
  }.toList()..sort();
}

List<int> repOptionsAround(PrescribedSet set) {
  final asked = set.reps;
  if (asked == null) return const [8, 9, 10, 12];
  return {
    for (final r in [asked - 4, asked - 2, asked - 1, asked, asked + 2])
      if (r > 0) r,
  }.toList()..sort();
}

class _ChangeSetSheet extends StatefulWidget {
  const _ChangeSetSheet({
    required this.prescribed,
    required this.weightOptionsKg,
    required this.repOptions,
    required this.onSave,
    this.moveName,
    this.onTypeANumber,
    this.hold = false,
    this.askWeight = false,
    this.progressionLine,
  });

  final bool askWeight;
  final String? progressionLine;

  /// The chips are seconds of a hold rather than reps.
  final bool hold;

  final PrescribedSet prescribed;
  final String? moveName;
  final List<double> weightOptionsKg;
  final List<int> repOptions;
  final ValueChanged<ChangedSet> onSave;
  final VoidCallback? onTypeANumber;

  @override
  State<_ChangeSetSheet> createState() => _ChangeSetSheetState();
}

class _ChangeSetSheetState extends State<_ChangeSetSheet> {
  late int _weightIndex = _indexOfPlannedWeight();
  late int _repIndex = _indexOfAskedReps();

  /// "Type a different number": a number pad in the sheet itself, for the
  /// set the chips do not cover. Null until she asks for it.
  TextEditingController? _typed;

  int _indexOfAskedReps() {
    final asked = widget.hold
        ? widget.prescribed.holdSeconds
        : widget.prescribed.reps;
    final found = asked == null ? -1 : widget.repOptions.indexOf(asked);
    return found < 0 ? 0 : found;
  }

  /// What she typed, when it is a number of reps anyone could do in a set.
  int? get _typedReps {
    final n = int.tryParse(_typed?.text.trim() ?? '');
    return n != null && n > 0 && n <= 200 ? n : null;
  }

  int get _reps => _typedReps ?? widget.repOptions[_repIndex];

  @override
  void dispose() {
    _typed?.dispose();
    super.dispose();
  }

  int _indexOfPlannedWeight() {
    final planned = widget.prescribed.weightKg;
    if (planned == null) return 0;
    final found = widget.weightOptionsKg.indexOf(planned);
    return found < 0 ? 0 : found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Each chip names the weight it actually selects.
    //
    // This was three fixed strings — `n10Kg`, `n12Kg`, `n14Kg` — beside a
    // `weightOptionsKg` list the caller supplies. They agree only for the
    // default [10, 12, 14]: a plan offering 17.5/20/22.5 drew chips reading
    // "10 kg / 12 kg / 14 kg" and wrote 20 when she tapped the middle one,
    // and any list that was not three long indexed off the end of the labels.
    //
    // A weight is a value and not copy — `weight_label.dart` — so the number is
    // formatted and only the unit comes from the dictionary. That keeps the
    // digits Western under `ar`, which P0-A11Y-01 requires, and renders
    // "12 كجم" exactly as the fixed Arabic strings did. The reps are bare
    // numerals for the same reason: a "9" has nothing to translate.
    final weightLabels = [
      for (final kg in widget.weightOptionsKg) '${weightLabel(kg)} ${l10n.kg}',
    ];
    final repLabels = [for (final reps in widget.repOptions) '$reps'];

    // A bodyweight set has no weight to change, and offering one is the app
    // inventing equipment. The session this build ships is "Quiet · no
    // equipment · floor" and every move in it is bodyweight, so this sheet used
    // to offer 10/12/14 kg over a glute bridge and then write whichever she
    // tapped into her log as a weight she had lifted.
    final loaded =
        widget.prescribed.weightKg != null ||
        (widget.askWeight && widget.weightOptionsKg.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.whatDidYouDo, style: AppText.titleL),
        const SizedBox(height: 2),
        Text(
          // The move she is correcting. `set2GobletSquat` — "Set 2 · Goblet
          // squat" — named the prototype's set AND the prototype's move, so it
          // stayed "Set 2 · Goblet squat" for the fourth set of a hip thrust.
          // The move name is hers; the set number has no parameterised form, so
          // it is not stated rather than stated wrongly.
          widget.moveName ?? l10n.gobletSquat,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (loaded) ...[
          const SizedBox(height: 14),
          Text(
            l10n.weight,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          AppChipRow(
            items: weightLabels,
            selected: {_weightIndex},
            onTap: (i) => setState(() => _weightIndex = i),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          widget.hold ? l10n.seconds : l10n.reps,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        AppChipRow(
          items: repLabels,
          selected: {if (_typedReps == null) _repIndex},
          onTap: (i) => setState(() {
            _repIndex = i;
            _typed?.clear();
          }),
        ),
        if (_typed != null) ...[
          const SizedBox(height: 10),
          AppField(
            controller: _typed,
            label: widget.hold ? l10n.seconds : l10n.reps,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 14),
        // 'Next time we keep 12 kg and aim for 10 again.' — names the weight
        // and the rep target it is about, so it is shown only to the woman
        // whose set those are. The rule inside it is general; the two figures
        // are not, and the dictionary has no parameterised form. Withheld
        // rather than told to a woman who was asked for 20 kg × 8.
        if (widget.progressionLine != null)
          AppSageNote(widget.progressionLine!)
        else if (statesHerFigure<(num?, int?)>(
          states: const (12, 10),
          hers: (widget.prescribed.weightKg, widget.prescribed.reps),
        ))
          AppSageNote(l10n.nextTimeWeKeep12KgAnd),
        const SizedBox(height: 14),
        AppButton(
          // Names what it is about to save, read off the chips she tapped.
          //
          // This was `save12Kg8` — "Save · 12 kg × 8" — a fixed string beside
          // two chip rows, so the button named one set and wrote another. R08's
          // own test tapped "14 kg", then "9", then a button reading
          // "Save · 12 kg × 8", and asserted 14 × 9 was written: the defect was
          // pinned by a passing test. Same string R07 uses, so the two screens
          // cannot disagree about what a saved set is called.
          setDoneLabel(
            l10n,
            weightKg: loaded ? widget.weightOptionsKg[_weightIndex] : null,
            reps: widget.hold ? null : _reps,
            holdSeconds: widget.hold ? _reps : null,
          ),
          onPressed: () => widget.onSave(
            ChangedSet(
              prescribed: widget.prescribed,
              outcome: SetOutcome(
                weightKg: loaded ? widget.weightOptionsKg[_weightIndex] : null,
                reps: widget.hold ? null : _reps,
                holdSeconds: widget.hold ? _reps : null,
              ),
            ),
          ),
        ),
        if (_typed == null) ...[
          const SizedBox(height: 10),
          AppButton(
            l10n.typeADifferentNumber,
            variant: AppButtonVariant.text,
            // 44, not 40: the iOS minimum, and this sheet is used mid-set with
            // one hand. AppButton already floors the *tap target* at 44 — the
            // block she can see is now the block she can hit.
            height: 44,
            fontSize: 15,
            // A caller's own route to a keyboard wins; otherwise the number
            // pad opens here. It used to be a button that did nothing.
            onPressed:
                widget.onTypeANumber ??
                () => setState(() => _typed = TextEditingController()),
          ),
        ],
      ],
    );
  }
}
