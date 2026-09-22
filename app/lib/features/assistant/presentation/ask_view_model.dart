/// What `X01` and `X02` render, derived from an outcome and the local pack.
///
/// The view model is where the last of G15's structural promises is kept: **a
/// row exists only if the pack knows the id.** `AssistantResponseValidator` has
/// already dropped unknown ids by the time an outcome arrives here, and this
/// layer drops them again — not because the validator is doubted, but because
/// this is the layer that actually *reads the quantity*, and the read is the
/// thing that must be impossible for an invented id. Defence in depth, and the
/// cheaper of the two places to get it wrong.
///
/// ## Two things are true on every state
///
///  * **`Ask Sara instead` is always enabled.** Offline, capped, refused,
///    unavailable, switched off — every one. G11's messages are `users`-adjacent
///    and offline-writable, so the human path works on a microbus and the
///    machine path does not. G15 §4 calls that inversion the honest one, and it
///    is asserted on every state below rather than in one place.
///  * **The composer is disabled with a stated reason, never a spinner.** There
///    is no queue: a question she may no longer be asking is not retried on
///    reconnect.
library;

import 'package:meta/meta.dart';

import '../domain/assistant_pack.dart';
import '../domain/assistant_provider.dart';
import '../domain/assistant_service.dart';
import '../domain/assistant_wire.dart';
import '../domain/safety_classifier.dart';

/// Which of X01's states is on screen.
enum AskState {
  /// Nothing asked yet. Rule 17: the empty state *is* the onboarding — it shows
  /// what it can be asked, and offers Sara. No tour, no overlay.
  idle,

  /// A grounded answer with its sources.
  answered,

  /// The library had nothing. It says so and names no move.
  nothingFound,

  /// `X02`.
  refused,

  /// Today's allowance is spent.
  capped,

  /// Offline, switched off, a guardrail failure, a truncation, a server error.
  unavailable,
}

/// One rendered pick. Every string here came from the pack, not from a model.
@immutable
class AskRow {
  const AskRow({
    required this.exerciseId,
    required this.name,
    required this.source,
    this.detail,
    this.swap,
  });

  final String exerciseId;

  /// Read from the pack row. A model cannot supply a name.
  final String name;

  /// The prescription, read from the pack row. **Null when the dictionary has
  /// no phrase for this move** — the row then renders without a detail line
  /// rather than with an invented figure.
  final String? detail;

  /// Drives the source chip: her plan, or the library.
  final PickSource source;

  /// What the *Swap* control would propose, or null when this row replaces
  /// nothing.
  ///
  /// A proposal, never an applied change: the control routes to `R05`, and
  /// G4's `SwapService` is what writes, after her tap. `P0-ASK-03`.
  final SwapProposal? swap;

  /// The row shows a *Swap* control only when there is something to swap.
  bool get canSwap => swap != null;
}

/// Everything `X01` needs to draw itself.
@immutable
class AskScreen {
  const AskScreen({
    required this.state,
    this.rows = const <AskRow>[],
    this.refusal,
    this.reason,
    this.answerKey,
  });

  final AskState state;
  final List<AskRow> rows;

  /// Which dictionary template the sentence above the rows is.
  ///
  /// Set only in [AskState.answered] and [AskState.nothingFound]. It is a key,
  /// not a sentence: the screen resolves it through `assistantAnswerTemplate`,
  /// so there is no arrangement of this type in which un-localised prose from a
  /// model reaches a widget.
  final AnswerKey? answerKey;

  /// Set only in [AskState.refused]. Chooses X02's copy and whether the route
  /// to care leads.
  final RefusalCategory? refusal;

  /// Set only in [AskState.unavailable].
  final AssistantUnavailableReason? reason;

  /// She can type a question.
  ///
  /// False whenever asking cannot work, so the control is disabled with a
  /// stated reason rather than accepting input that goes nowhere.
  /// `notImplemented` is in the list for the same reason `switchedOff` is, and
  /// not for the reason the three server faults are left out: a fault is worth
  /// retrying and there is nothing here to retry. Nothing is wired to the
  /// assistant in this build, so a live composer would take a question that
  /// has nowhere to go. The human path in the footer still works.
  bool get composerEnabled =>
      state != AskState.capped &&
      !(state == AskState.unavailable &&
          (reason == AssistantUnavailableReason.offline ||
              reason == AssistantUnavailableReason.switchedOff ||
              reason == AssistantUnavailableReason.notImplemented));

  /// **Always true.** See the file note — this is the property that holds on
  /// every state, including the ones where nothing else works.
  bool get askSaraEnabled => true;

  /// X02 shows the route to care above the refusal when the category is an
  /// emergency.
  bool get promotesCare => refusal?.promotesCare ?? false;

  /// The empty state that doubles as the onboarding.
  bool get showsExamples => state == AskState.idle;

  /// **Always true, on every state.** Nothing this screen can do changes her
  /// plan: the assistant returns a payload and writes nothing, and a swap is a
  /// proposal that G4 applies to today's session after her tap. Asserted here
  /// rather than described in copy, so `P0-ASK-03`'s "plans/** is
  /// byte-identical" has something to point at.
  bool get planUntouched => true;

  /// Every swap this screen could propose. Empty unless the answer was about a
  /// move in today's session.
  List<SwapProposal> get swaps => <SwapProposal>[
    for (final row in rows) ?row.swap,
  ];
}

/// Turns an [AssistantOutcome] into an [AskScreen].
class AskViewModel {
  const AskViewModel(this.pack);

  final AssistantPack pack;

  /// Before anything has been asked.
  AskScreen idle({bool online = true}) => online
      ? const AskScreen(state: AskState.idle)
      : const AskScreen(
          state: AskState.unavailable,
          reason: AssistantUnavailableReason.offline,
        );

  /// After a call.
  AskScreen from(AssistantOutcome outcome) => switch (outcome) {
    AssistantRefusal(:final category) => AskScreen(
      state: AskState.refused,
      refusal: category,
    ),
    AssistantCapped() => const AskScreen(state: AskState.capped),
    AssistantUnavailable(:final reason) => AskScreen(
      state: AskState.unavailable,
      reason: reason,
    ),
    AssistantAnswered(:final answer) => _fromAnswer(answer),
    // The draft outcomes cannot arrive on this route; treat them as a server
    // error rather than rendering something X01 has no shape for.
    AssistantPlanDrafted() || AssistantMealDrafted() => const AskScreen(
      state: AskState.unavailable,
      reason: AssistantUnavailableReason.serverError,
    ),
  };

  AskScreen _fromAnswer(AssistantAnswer answer) {
    final rows = <AskRow>[
      for (final pick in answer.picks)
        if (pick.kind == PickKind.exercise)
          if (pack.exerciseById(pick.id) case final move?)
            AskRow(
              exerciseId: move.exerciseId,
              name: move.name,
              detail: move.prescriptionLabel,
              source: pick.source,
              swap: answer.swapFor(pick),
            ),
    ];

    // An answer whose picks all failed to resolve is nothing found, whatever
    // the key said. The screen never renders a grounded answer with no moves.
    if (rows.isEmpty || answer.answerKey == AnswerKey.nothingFound) {
      return const AskScreen(
        state: AskState.nothingFound,
        answerKey: AnswerKey.nothingFound,
      );
    }

    return AskScreen(
      state: AskState.answered,
      rows: rows,
      answerKey: answer.answerKey,
    );
  }
}
