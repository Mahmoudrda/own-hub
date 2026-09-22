/// E03 — Say it.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E03`. A voice note is one of her three
/// fluent gestures, and this screen exists to make a misheard word obvious
/// before anything is saved.
///
/// ## The interface is MSA; the speech is Egyptian
///
/// The two halves live in different places and this screen is where they meet.
/// Every string comes from `AppL10n`, which is Modern Standard Arabic. The
/// recogniser's locale is `ar-EG`, because dictation grammar is not how she
/// actually talks. Nothing on this screen renders a literal, so one cannot leak
/// into the other.
///
/// ## The transcript is shown before saving — `P0-LOG-08`
///
/// Enforced by the view model, not by the order of the widgets:
/// `SayItView` can only log in [VoiceState.transcriptShown], so there is no
/// arrangement of this screen that could save something she has not read.
///
/// ## There is no sample transcript
///
/// The prototype draws an Arabic sentence. That is a **mockup value, not copy** —
/// it is what the designer imagined a woman saying. Rendering it here would show
/// her words she never said, on the one screen whose entire purpose is showing
/// her what was actually heard. So the transcript is null until a recogniser
/// produces one, and the card simply does not appear.
///
/// The recogniser itself is not wired: G5 §9 Q4 is blocking and owner-track
/// (vendor, PDPL data-processing agreement, consent copy, whether audio may
/// leave Egypt), and tier 1 is on-device. Until a platform recogniser is
/// attached, tapping the microphone reaches [VoiceState.refused] and offers the
/// keyboard — which is honest, and is what §3.3 specifies for exactly this case.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';
import 'meal_log_session.dart';
import 'say_it_view_model.dart';

class SayItView extends StatefulWidget {
  const SayItView({
    super.key,
    required this.constraints,
    this.repository,
    this.bus,
    this.session,
    this.library,
    this.now,
    this.initialTranscript,
    this.onClose,
    this.onLogged,
    this.onBlocked,
    this.onTypeInstead,
  });

  /// See `EatView.constraints` — required, never defaulted.
  final DietaryConstraints constraints;

  final MealRepository? repository;
  final LogCommandBus? bus;

  /// The Eat tab's shared five seconds — see `EatView.session`.
  final MealLogSession? session;

  final FoodLibrary? library;
  final DateTime? now;

  /// A transcript from the recogniser.
  ///
  /// Null in the shipped app, because no recogniser is attached yet. Supplying
  /// one drives the screen into [VoiceState.transcriptShown], which is how the
  /// `P0-LOG-08` path is exercised.
  final String? initialTranscript;

  final VoidCallback? onClose;
  final ValueChanged<LogHandle>? onLogged;
  final ValueChanged<MealLogRefused>? onBlocked;

  /// Where `refused` and `failed` send her — E02, with an explanation rather
  /// than a spinner.
  final VoidCallback? onTypeInstead;

  @override
  State<SayItView> createState() => _SayItViewState();
}

class _SayItViewState extends State<SayItView> {
  late final MealRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  SayItState? _state;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    _ownsBus = widget.bus == null && widget.session == null;
    _bus = widget.bus ?? widget.session?.bus ?? LogCommandBus();
  }

  @override
  void dispose() {
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  FoodLibrary _library(AppL10n l10n) =>
      widget.library ?? eatSampleLibrary(l10n);

  SayItViewModel _model(AppL10n l10n) =>
      SayItViewModel(parser: MealSentenceParser(_library(l10n)));

  SayItState _current(AppL10n l10n) {
    final held = _state;
    if (held != null) return held;
    final transcript = widget.initialTranscript;
    if (transcript != null) return _model(l10n).heard(transcript);
    return SayItState.idle;
  }

  /// No recogniser is attached, so this refuses clearly rather than spinning.
  void _listen() {
    final l10n = AppL10n.of(context);
    setState(() => _state = _model(l10n).refuse());
  }

  void _log(List<ParsedItem> entries) {
    final l10n = AppL10n.of(context);
    final service = MealLogService(
      repository: _repo,
      library: _library(l10n),
      guard: AllergyGuard(widget.constraints),
    );

    final slot = EatDayViewModel.slotAt(_now);
    final outcome = service.logNew(
      day: MealDay(dayId: _dayIdOf(_now)),
      slot: slot,
      entries: entries,
      // The spine's enum, unchanged. Voice is a source, and `origin` carries
      // the finer provenance.
      source: MealSource.voice,
      origin: MealOrigin.voice,
      at: _now,
    );

    if (outcome is MealLogRefused) {
      widget.onBlocked?.call(outcome);
      return;
    }

    final prepared = outcome as MealLogPrepared;
    final session = widget.session;
    if (session != null) {
      final handle = session.submit(
        prepared,
        slot: slot,
        describe: l10n.foodLogged,
      );
      showUndoSnackBar(
        context,
        handle: handle,
        undoLabel: l10n.undo,
        onUndo: session.settle,
      );
      widget.onLogged?.call(handle);
      return;
    }

    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.foodLogged,
        commit: () => service.commit(prepared.write),
      ),
    );
    showUndoSnackBar(context, handle: handle, undoLabel: l10n.undo);
    widget.onLogged?.call(handle);
  }

  static String _dayIdOf(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = _current(l10n);
    final model = _model(l10n);

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onClose, leadingIcon: Icons.close),
      footer: [
        AppButton(
          // `thatsRightLog696Kcal` — "That's right · log 696 kcal" — states the
          // total of the prototype's sample sentence, so it named 696 whatever
          // the recogniser had actually heard. The rows above state the
          // numbers; this states the action.
          l10n.logIt,
          onPressed: state.canLog ? () => _log(state.parse.items) : null,
        ),
        AppButton(
          state.shouldOfferTyping ? l10n.sayOrTypeWhatYouAte : l10n.sayItAgain,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          icon: state.shouldOfferTyping ? Icons.keyboard : Icons.mic,
          onPressed: state.shouldOfferTyping ? widget.onTypeInstead : _listen,
        ),
      ],
      children: [
        Text(l10n.weHeardThis, style: AppText.headline),
        _Waveform(active: state.isRecording),
        // Only ever her words. Absent until a recogniser produces some.
        if (state.transcript != null)
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [Text(state.transcript!, style: AppText.body)],
          ),
        if (state.shouldOfferTyping)
          Text(
            l10n.weNeedTheMicrophoneToHearWhat,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (state.parse.items.isNotEmpty)
          Text(
            l10n.soWereLogging,
            style: AppText.titleS.copyWith(color: AppColors.tertiary),
          ),
        for (var i = 0; i < state.parse.items.length; i++)
          ParsedRow(
            name: state.parse.items[i].food.names.first,
            meta: _metaFor(l10n, state.parse.items[i]),
            sizeLabels: [
              for (final size in state.parse.items[i].food.sizes) size.label,
            ],
            selectedSize: state.parse.items[i].food.sizes.indexWhere(
              (s) => s.id == state.parse.items[i].size.id,
            ),
            onPickSize: (index) => setState(
              () => _state = model.resize(
                state,
                i,
                state.parse.items[i].food.sizes[index],
              ),
            ),
            onRemove: () => setState(() => _state = model.remove(state, i)),
            removeTooltip: l10n.edit,
          ),
      ],
    );
  }

  /// The row's macros, computed from the size and servings she picked.
  ///
  /// Identical to `TypeItView._metaFor`, and it had the identical defect: a
  /// four-case switch on `foodId` whose default arm reported koshari's
  /// "540 kcal · 18 g protein" for every other food, and which never moved when
  /// she tapped a different size chip on the row it describes.
  String _metaFor(AppL10n l10n, ParsedItem item) =>
      l10n.kcalKcalProteinGProtein(
        countLabel(item.kcal),
        countLabel(item.proteinG),
      );
}

/// The level meter the prototype draws.
///
/// Decorative and deliberately **not** driven by a fake signal: bars that danced
/// while nothing was being recorded would tell her the microphone is listening
/// when it is not. Lit only while [active].
class _Waveform extends StatelessWidget {
  const _Waveform({required this.active});

  final bool active;

  static const List<double> _heights = [14, 26, 38, 20, 34, 44, 22, 30, 16, 24];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Container(
                height: _heights[i],
                decoration: BoxDecoration(
                  color: active && i < 7
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                  // Squared off like a marker stroke, not a pill.
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
