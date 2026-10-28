/// E03 — Say it.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E03`. A voice note is one of her three
/// fluent gestures, and this screen exists to make a misheard word obvious
/// before anything is saved.
///
/// ## The interface is the app's voice; the speech is hers
///
/// The two halves live in different places and this screen is where they meet.
/// Every string comes from `AppL10n`, the app's own Arabic. The
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
/// it is what the designer imagined a woman saying. So the transcript is null
/// until the phone's speech service produces one, and the card simply does not
/// appear.
///
/// ## The recogniser is the phone's own
///
/// `MealSpeechEngine`: Apple Speech or Android's recogniser, on the phone where
/// it can be and through the phone's own service where it must. The screen
/// listens on its own only when the phone has **already** let Own Hub listen;
/// otherwise it says why in one sentence and waits for a tap, and after the
/// system's prompts it waits for another. Nothing here keeps audio.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/first_run_moments.dart';
import '../../../app_state/guest_session.dart';
import '../../../app_state/haptics.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../app_state/open_app_settings.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_log_service.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import '../domain/meal_speech.dart';
import 'eat_day_view_model.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';
import 'meal_log_session.dart';
import 'meal_result_card.dart';
import 'say_it_view_model.dart';
import 'meal_labels.dart';
import 'voice_mic_button.dart';

class SayItView extends StatefulWidget {
  const SayItView({
    super.key,
    required this.constraints,
    this.repository,
    this.bus,
    this.session,
    this.library,
    this.now,
    this.engine,
    this.initialTranscript,
    this.onClose,
    this.onLogged,
    this.onBlocked,
    this.onTypeInstead,
    this.onEditSentence,
  });

  /// See `EatView.constraints` — required, never defaulted.
  final DietaryConstraints constraints;

  final MealRepository? repository;
  final LogCommandBus? bus;

  /// The Eat tab's shared five seconds — see `EatView.session`.
  final MealLogSession? session;

  final FoodLibrary? library;
  final DateTime? now;

  /// The phone's speech service. Null uses [MealSpeech.engine], the one the app
  /// installs and a test replaces.
  final MealSpeechEngine? engine;

  /// A transcript already in hand, which drives the screen straight into
  /// [VoiceState.transcriptShown]. How the `P0-LOG-08` path is exercised
  /// without a recogniser.
  final String? initialTranscript;

  final VoidCallback? onClose;
  final ValueChanged<LogHandle>? onLogged;
  final ValueChanged<MealLogRefused>? onBlocked;

  /// Where `refused`, `failed` and `denied` send her: E02, with an explanation
  /// rather than a spinner.
  final VoidCallback? onTypeInstead;

  /// "Type what you ate" once there are words: opens E02 with what she said
  /// already in the box. Falls back to [onTypeInstead] when not given.
  final ValueChanged<String>? onEditSentence;

  @override
  State<SayItView> createState() => _SayItViewState();
}

class _SayItViewState extends State<SayItView> with WidgetsBindingObserver {
  late final MealRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;

  final TextEditingController _editor = TextEditingController();
  StreamSubscription<SpeechEvent>? _hearing;

  SayItState? _state;

  /// A system prompt or the phone is busy; a second press must wait.
  bool _preparing = false;

  /// The phone already lets Own Hub listen, so no prompt can appear.
  bool _knownAllowed = false;

  /// Which language the phone listens for. The sentence parser reads both, so
  /// it is her choice and not the interface's.
  bool? _speaksArabic;

  DateTime get _now => widget.now ?? AppClock.now();

  MealSpeechEngine get _engine => widget.engine ?? MealSpeech.engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    _ownsBus = widget.bus == null && widget.session == null;
    _bus = widget.bus ?? widget.session?.bus ?? LogCommandBus();
    _editor.text = widget.initialTranscript ?? '';
    if (widget.initialTranscript == null) unawaited(_listenIfAlreadyAllowed());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speaksArabic ??= Localizations.localeOf(context).languageCode == 'ar';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopHearing());
    _editor.dispose();
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// Out of sight means not listening: the microphone is never left open behind
  /// the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) return;
    final held = _state;
    if (held == null || !held.isBusy) return;
    unawaited(_stopHearing());
    if (mounted) setState(() => _state = SayItState.idle);
  }

  Future<void> _stopHearing() async {
    final hearing = _hearing;
    _hearing = null;
    // The phone is told first and not after a wait: closing the microphone is
    // the part that must not be late.
    unawaited(hearing?.cancel());
    await _engine.cancel();
  }

  FoodLibrary _library(AppL10n l10n) =>
      widget.library ?? eatSampleLibrary(l10n);

  SayItViewModel _model(AppL10n l10n) => SayItViewModel(
    parser: MealSentenceParser(_library(l10n), fromSpeech: true),
  );

  SayItState _current(AppL10n l10n) {
    final held = _state;
    if (held != null) return held;
    final transcript = widget.initialTranscript;
    if (transcript != null) return _model(l10n).heard(transcript);
    return SayItState.idle;
  }

  /// Listens on its own only when the phone has already let Own Hub listen and
  /// she has already read, on this screen, who turns her words into text. So
  /// opening it can never raise a system prompt, and a woman who allowed the
  /// microphone for a voice note is still told before the first meal.
  Future<void> _listenIfAlreadyAllowed() async {
    final allowed = await _engine.isAllowed();
    if (!mounted) return;
    setState(() => _knownAllowed = allowed);
    if (allowed && FirstRunMoments.instance.voiceExplained && _state == null) {
      await _start();
    }
  }

  /// Her tap. The first time it raises the system's prompts, and when they have
  /// been answered it waits for her next tap rather than listening at once.
  Future<void> _start() async {
    if (_preparing || (_state?.isBusy ?? false)) return;
    FirstRunMoments.instance.markVoiceExplained();
    setState(() => _preparing = true);
    final wasAllowed = _knownAllowed || await _engine.isAllowed();
    final problem = await _engine.prepare();
    if (!mounted) return;
    final model = _model(AppL10n.of(context));
    if (problem != null) {
      setState(() {
        _preparing = false;
        _state = model.failed(problem);
      });
      return;
    }
    if (!wasAllowed) {
      setState(() {
        _preparing = false;
        _knownAllowed = true;
        _state = SayItState.idle;
      });
      return;
    }
    final offered = await _engine.locales();
    if (!mounted) return;
    final locale = pickSpeechLocale(offered, arabic: _speaksArabic ?? false);
    unawaited(_hearing?.cancel());
    setState(() {
      _preparing = false;
      _knownAllowed = true;
      _state = model.start();
    });
    _hearing = _engine
        .listen(localeId: locale)
        .listen(
          _onSpeech,
          onDone: () {
            final held = _state;
            if (mounted && held != null && held.isBusy) {
              setState(() => _state = model.failed(SpeechFailure.noSpeech));
            }
          },
        );
  }

  void _stop() {
    final held = _state;
    if (held == null || !held.isRecording) return;
    setState(() => _state = _model(AppL10n.of(context)).stopped());
    unawaited(_engine.stop());
  }

  void _onSpeech(SpeechEvent event) {
    if (!mounted) return;
    final model = _model(AppL10n.of(context));
    final failure = event.failure;
    if (failure != null) {
      setState(() => _state = model.failed(failure));
      return;
    }
    if (!event.isFinal) {
      // Words so far are shown dimly while she speaks. They are not the
      // transcript, and nothing can be logged from them.
      final held = _state;
      if (held != null && held.isRecording) {
        setState(() => _state = model.listening(event.words));
      }
      return;
    }
    final next = model.heard(event.words);
    if (next.transcript != null) _editor.text = next.transcript!;
    setState(() => _state = next);
  }

  /// She fixed a word: the sentence is read again from what is in the box.
  void _edited(String text) {
    final l10n = AppL10n.of(context);
    setState(() => _state = _model(l10n).edited(_current(l10n), text));
  }

  /// The **one** undo offer for one log (§2 rule 9).
  ///
  /// When [SayItView.onLogged] is wired the handle travels on to E04, which
  /// draws the in-page `AppUndoBar` for it. Raising a floating snackbar here as
  /// well put two offers for the same meal on screen, and the one she reached
  /// second had already expired. Without that handler nothing downstream would
  /// offer the five seconds, so the snackbar stands in.
  void _offerUndo(LogHandle handle, {VoidCallback? onUndo}) {
    unawaited(AppHaptics.play(HapticMoment.actionDone));
    if (widget.onLogged != null) return;
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: AppL10n.of(context).undo,
      onUndo: onUndo,
    );
  }

  void _log(List<ParsedItem> entries) {
    if (!GuestSession.require(
      context,
      PendingAction.logMeal(entries, origin: MealOrigin.voice),
    )) {
      return;
    }
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
        describe: mealAddedLabel(
          l10n,
          mealFoodNames(_library(l10n), prepared.items),
          slot,
        ),
      );
      _offerUndo(handle, onUndo: session.settle);
      widget.onLogged?.call(handle);
      return;
    }

    final handle = _bus.submit(
      UndoableLog(
        describe: mealAddedLabel(
          l10n,
          mealFoodNames(_library(l10n), prepared.items),
          slot,
        ),
        commit: () => service.commit(prepared.write),
      ),
    );
    _offerUndo(handle);
    widget.onLogged?.call(handle);
  }

  static String _dayIdOf(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  /// The calm line for a state with nothing to confirm.
  String? _reason(AppL10n l10n, SayItState state) => switch (state.state) {
    VoiceState.denied => l10n.ownHubCantUseTheMicrophoneOr,
    VoiceState.refused => l10n.thisPhoneCantTurnSpeechIntoText,
    VoiceState.failed => switch (state.failure) {
      SpeechFailure.noSpeech => l10n.weDidntCatchAnythingTryAgainA,
      SpeechFailure.offline => l10n.sayingYourMealNeedsAnInternetConnection,
      _ => l10n.somethingWentWrongWhileListeningTryAgain,
    },
    VoiceState.transcriptShown when state.parse.items.isEmpty =>
      l10n.weHeardYouButNoneOfIt,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = _current(l10n);
    final model = _model(l10n);
    final transcript = state.transcript;
    final reason = _reason(l10n, state);
    final canSpeak =
        state.state != VoiceState.denied && state.state != VoiceState.refused;
    final isBusy = state.isBusy;
    final typeInstead = transcript != null && widget.onEditSentence != null
        ? () => widget.onEditSentence!(transcript)
        : widget.onTypeInstead;

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onClose, leadingIcon: Icons.close),
      footer: [
        AppButton(
          l10n.addIt,
          onPressed: state.canLog ? () => _log(state.parse.items) : null,
        ),
        if (state.state == VoiceState.denied)
          AppButton(
            l10n.openSettings,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            icon: Icons.settings,
            onPressed: () => unawaited(openAppSettings()),
          ),
        if (!isBusy && transcript != null && canSpeak)
          AppButton(
            l10n.sayItAgain,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            icon: Icons.mic,
            onPressed: _preparing ? null : () => unawaited(_start()),
          ),
        if (!isBusy)
          AppButton(
            l10n.typeWhatYouAte,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            icon: Icons.keyboard,
            onPressed: typeInstead,
          ),
      ],
      children: [
        Text(
          transcript != null ? l10n.weHeardThis : l10n.sayWhatYouAte,
          style: AppText.headline,
        ),
        if (canSpeak && transcript == null) ...[
          _Waveform(active: state.isRecording),
          VoiceMicButton(
            label: state.isRecording
                ? l10n.listeningTapWhenYouAreDone
                : l10n.tapToSpeak,
            listening: state.isRecording,
            enabled: !_preparing && state.state != VoiceState.transcribing,
            onTap: state.isRecording ? _stop : () => unawaited(_start()),
            onHoldStart: () => unawaited(_start()),
            onHoldEnd: _stop,
          ),
          Text(
            state.isRecording
                ? l10n.listeningTapWhenYouAreDone
                : l10n.tapToSpeak,
            textAlign: TextAlign.center,
            style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (state.isRecording && (state.partial ?? '').isNotEmpty)
            Text(
              state.partial!,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
            ),
          if (state.state == VoiceState.idle &&
              !FirstRunMoments.instance.voiceExplained &&
              !_preparing)
            Text(
              l10n.ownHubListensOnlyWhileYouSpeak,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],
        if (canSpeak && transcript == null && !isBusy) ...[
          Text(
            l10n.speakIn,
            style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
          ),
          AppSegmented(
            items: [l10n.arabic, l10n.english],
            selectedIndex: (_speaksArabic ?? false) ? 0 : 1,
            onChanged: (index) => setState(() => _speaksArabic = index == 0),
          ),
        ],
        if (reason != null)
          Text(
            reason,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        // Only ever her words, editable. Absent until the phone produces some.
        if (transcript != null)
          AppField(
            key: const ValueKey('voice-transcript'),
            controller: _editor,
            hint: l10n.sayOrTypeWhatYouAte,
            helper: l10n.fixAnyWordAndWeWillAdd,
            maxLines: 3,
            onChanged: _edited,
          ),
        if (state.parse.unresolved.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fragment in state.parse.unresolved)
                HandSurface(
                  seed: handSeed(['unresolved', fragment.text]),
                  frame: AppColors.outline,
                  dashed: true,
                  radius: 4,
                  looseCorner: 12,
                  child: Chip(
                    label: Text(fragment.text, style: AppText.bodyM),
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        if (state.parse.items.isNotEmpty)
          Text(
            l10n.soWereAdding,
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
            imageAsset: state.parse.items[i].food.imageAsset,
          ),
        // Below the rows she edits, so the card never pushes them off-screen.
        if (state.state == VoiceState.transcribing)
          const MealResultCard(adding: true)
        else if (state.canLog)
          MealResultCard(items: state.parse.items, asksIfRight: false),
        if (canSpeak && transcript != null && !isBusy) ...[
          Text(
            l10n.speakIn,
            style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
          ),
          AppSegmented(
            items: [l10n.arabic, l10n.english],
            selectedIndex: (_speaksArabic ?? false) ? 0 : 1,
            onChanged: (index) => setState(() => _speaksArabic = index == 0),
          ),
        ],
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
                  // The quiet bars are the other half of a state, so they
                  // take `outline` rather than the hairline role.
                  color: active && i < 7
                      ? AppColors.primary
                      : AppColors.outline,
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
