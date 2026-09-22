/// `X01` — Ask, and the five other things this one route renders.
///
/// [AskScreen] already decided which of them it is; this widget only draws it.
/// `X02` is one of the six (G15 §3.1 puts `refused` in the same state machine
/// as `answered`), so a refusal is rendered **here**, in the conversation, by
/// the same [AssistantRefusalBody] that `RefusalView` uses. Nothing navigates
/// to "the refusal screen"; she arrives there by asking a question the
/// guardrail declined, which is the only way it is true.
///
/// ## Two properties this widget cannot break
///
///  * **`Ask Sara instead` is in the footer on every state**, enabled, and it
///    is never conditional on anything. G11's messages are offline-writable, so
///    the human path works where the machine path does not.
///  * **The composer is disabled with no spinner**, from
///    [AskScreen.composerEnabled]. There is no progress indicator anywhere in
///    this file and no timer: a question she may no longer be asking is not
///    retried for her.
///
/// ## Three states that used to be silent, and the one that still is
///
/// Each of these had a state and no sentence, because the dictionary carried
/// none. Three of the strings have been minted, so the screen says them:
///
/// | State | What it says now |
/// |---|---|
/// | [AskState.nothingFound] | *"Nothing found for that. I would rather say so than guess."* — and still no row, and no move named |
/// | [AskState.capped] | *"You have used today's questions. There will be more tomorrow."*, beside a disabled composer and an enabled *Ask Sara instead* |
/// | [AskState.unavailable] offline | *"Asking needs a connection."* — which promises no queue, because there is none |
///
/// The kill switch is the one that stays silent:
/// `kUnavailableReasonsWithNoDictionaryLine` still holds
/// `AssistantUnavailableReason.switchedOff`, and the offline line is not
/// borrowed for it — a woman on full signal would be sent to fix the wrong
/// thing. She gets what G15 §2.4 says happens at the `off` rung anyway: the
/// human path, and `X03`.
///
/// Every one of those is asserted in `ask_view_test.dart`, so what is said and
/// what is withheld are both tested decisions.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_log_button.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/assistant_quota.dart';
import '../domain/assistant_wire.dart';
import 'assistant_boundaries.dart';
import 'assistant_copy.dart';
import 'assistant_templates.dart';
import 'assistant_widgets.dart';
import 'ask_view_model.dart';

class AskView extends StatefulWidget {
  const AskView({
    super.key,
    required this.screen,
    this.question,
    this.controller,
    this.onBack,
    this.onBoundaries,
    this.onAskSara,
    this.onFindCare,
    this.onAsk,
    this.onSwap,
  });

  /// What to draw. Built by [AskViewModel]; this widget computes nothing.
  final AskScreen screen;

  /// Her words, held in memory by the route and discarded on pop. Null before
  /// she has asked anything.
  final String? question;

  /// Supplied by the route so the text survives a rebuild. One is created here
  /// when it is not.
  final TextEditingController? controller;

  final VoidCallback? onBack;

  /// `X03`.
  final VoidCallback? onBoundaries;

  /// `H06`. Enabled on every state, including the ones where nothing else is.
  final VoidCallback? onAskSara;

  /// `Y11`, from a refusal.
  final VoidCallback? onFindCare;

  /// Her question leaves this screen and goes to the route, which owns the
  /// service call. Nothing here talks to a model.
  final ValueChanged<String>? onAsk;

  /// `R05`. A **proposal** — G4's swap service is what writes, after her tap
  /// on that screen. Nothing on `X01` changes a plan.
  final ValueChanged<SwapProposal>? onSwap;

  @override
  State<AskView> createState() => _AskViewState();
}

class _AskViewState extends State<AskView> {
  TextEditingController? _owned;

  TextEditingController get _field =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _ask() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    widget.onAsk?.call(text);
    _field.text = '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final screen = widget.screen;

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.assistant,
        onBack: widget.onBack,
        actions: [
          IconButton(
            tooltip: l10n.whatItCanAndCannotDo,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.info_outline),
            onPressed: widget.onBoundaries,
          ),
        ],
      ),
      footer: [
        _Composer(
          controller: _field,
          enabled: screen.composerEnabled,
          hint: l10n.askOrHoldToTalk,
          onAsk: _ask,
        ),
        AppButton(
          l10n.askSaraInstead,
          variant: AppButtonVariant.outlined,
          height: 44,
          fontSize: 14,
          // Never conditional. See the file note.
          onPressed: widget.onAskSara,
        ),
      ],
      children: [
        if (widget.question case final asked? when !screen.showsExamples)
          AssistantAskBubble(asked),
        ...switch (screen.state) {
          AskState.idle => _examples(l10n),
          AskState.answered => _answer(l10n, screen),
          // The same builder: the sentence is resolved from the same key, and
          // there are no rows to draw. It says so and it names no move.
          AskState.nothingFound => _answer(l10n, screen),
          AskState.refused => _refused(screen),
          // The composer above is already disabled; this says why, and says
          // when it stops being true.
          AskState.capped => _capped(l10n),
          AskState.unavailable => _unavailable(l10n, screen),
        },
        // Absent on a refusal: she is already reading the explanation it
        // leads to, and a row that offers what is on screen reads as filler.
        if (screen.state != AskState.refused)
          AssistantBoundaryRow(onTap: widget.onBoundaries),
      ],
    );
  }

  /// Rule 17: the empty state **is** the onboarding. Three of the things `X03`
  /// says it can do, read from the same source as `X03` itself — so the
  /// examples can never promise something the boundaries screen denies.
  List<Widget> _examples(AppL10n l10n) {
    final can = assistantBoundaries(l10n).can;
    return [
      AppCard(
        variant: AppCardVariant.filled,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        gap: 7,
        children: [
          for (final ability in [
            AssistantAbility.findAMove,
            AssistantAbility.swapForAnApprovedAlternative,
            AssistantAbility.portionOfADishSheLogs,
          ])
            if (can[ability] case final line?)
              AssistantBoundaryLine(line, allowed: true),
        ],
      ),
    ];
  }

  List<Widget> _answer(AppL10n l10n, AskScreen screen) {
    // Resolved through the dictionary by key. Null when the template states a
    // count that is not hers — `assistant_templates.dart`, and the reason the
    // sentence can be absent while the rows are not.
    final sentence = screen.answerKey == null
        ? null
        : assistantAnswerTemplate(
            l10n,
            screen.answerKey!,
            rowCount: screen.rows.length,
          );

    // One chip per distinct provenance, in the order the rows carry it.
    final sources = <PickSource, String>{
      for (final row in screen.rows)
        row.source: pickSourceLabel(l10n, row.source),
    };

    return [
      if (sentence != null || sources.isNotEmpty)
        AssistantReplyBubble(
          children: [
            if (sentence != null) Text(sentence, style: AppText.bodyM),
            if (sources.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in sources.entries)
                    AppPill(
                      entry.value,
                      background: AppColors.surfaceContainer,
                      foreground: AppColors.onSurfaceVariant,
                      icon: entry.key == PickSource.herPlan
                          ? Icons.list_alt
                          : Icons.menu_book,
                    ),
                ],
              ),
          ],
        ),
      for (final row in screen.rows)
        AppListItem(
          leading: const Icon(
            Icons.fitness_center,
            size: 21,
            color: AppColors.primaryDim,
          ),
          title: row.name,
          // Null when the pack has no authored phrase for this move. The row
          // renders without a detail line rather than with an invented figure.
          subtitle: row.detail ?? '',
          trailing: row.canSwap
              ? AppLogButton(
                  l10n.swap,
                  onPressed: widget.onSwap == null
                      ? null
                      : () => widget.onSwap!(row.swap!),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        ),
      // Only where something is actually being swapped. On an answer that
      // replaces nothing the sentence would be true and irrelevant, which is
      // how a promise starts reading as boilerplate.
      if (screen.swaps.isNotEmpty)
        AssistantNotice(
          icon: Icons.info_outline,
          text: l10n.swappingChangesTodayOnlyYourPlanFrom,
        ),
    ];
  }

  /// Today's allowance is spent. No figure: the cap is tightened from Remote
  /// Config, and a sentence naming five would be wrong the day it becomes
  /// three.
  List<Widget> _capped(AppL10n l10n) => [
    AssistantNotice(
      icon: Icons.schedule,
      text: assistantCappedLine(l10n),
      variant: AppCardVariant.amber,
      tone: AppColors.amber,
    ),
  ];

  List<Widget> _refused(AskScreen screen) => [
    AssistantRefusalBody(
      category: screen.refusal!,
      promotesCare: screen.promotesCare,
      onFindCare: widget.onFindCare,
      onMessageSara: widget.onAskSara,
      onBoundaries: widget.onBoundaries,
    ),
  ];

  List<Widget> _unavailable(AppL10n l10n, AskScreen screen) {
    // Offline says "Asking needs a connection." — this is the asking route, so
    // it is not the drafting sentence. Null for the kill switch, which has no
    // honest line: the composer is disabled, the human path is in the footer,
    // and the screen says nothing it cannot support.
    final line = assistantUnavailableLine(
      l10n,
      screen.reason!,
      route: QuotaRoute.question,
    );
    return [
      if (line != null)
        AssistantNotice(
          icon: Icons.cloud_off,
          text: line,
          variant: AppCardVariant.amber,
          tone: AppColors.amber,
        ),
    ];
  }
}

/// The composer. Disabled with a stated reason — never a spinner, and there is
/// no progress indicator in this file to make one out of.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.onAsk,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final tone = enabled ? AppColors.primaryDim : AppColors.outline;

    // An input, so it is drawn clean: the page's corners, no wavering line.
    return HandSurface(
      seed: handSeed(['ask-composer']),
      fill: AppColors.surfaceLowest,
      frame: AppColors.outline.withValues(alpha: 0.55),
      frameWidth: 1.05,
      level: HandLevel.structural,
      radius: 6,
      looseCorner: 14,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onAsk(),
              style: AppText.bodyM,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Named, because an icon has nothing to read, and live only once
          // there is a question in the field: `_ask` drops an empty one, so
          // an always-live button would be one that does nothing on most taps.
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => IconButton(
              color: tone,
              tooltip: AppL10n.of(context).send,
              icon: const Icon(Icons.send),
              onPressed: enabled && controller.text.trim().isNotEmpty
                  ? onAsk
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
