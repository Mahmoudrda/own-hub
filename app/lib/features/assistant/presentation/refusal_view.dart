/// `X02` — when it will not answer.
///
/// The most important screen in the feature, and the one with the least code in
/// it: everything it renders comes from [AssistantRefusalBody], which `X01`
/// draws too. That is deliberate. G15 §3.1 makes `refused` a state of the
/// conversation rather than a destination, so this widget exists for the case
/// where the refusal is opened on its own — a deep link, a back stack, a
/// refusal that was already on screen when the signal went — and it must render
/// the identical thing. One widget, two hosts, no drift.
///
/// ## What it does not do
///
/// It hedges nothing, it partially answers nothing, and it offers no way back
/// into the question. There is no *"but generally…"* on this screen because
/// there is no field on [AssistantRefusalBody] that could carry one.
///
/// **It makes no call.** Both routes out — care, and her coach — are local
/// navigations, so the screen works offline exactly as G15 §4 requires.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/safety_classifier.dart';
import 'assistant_widgets.dart';

class RefusalView extends StatelessWidget {
  const RefusalView({
    super.key,
    required this.category,
    this.question,
    this.onBack,
    this.onBoundaries,
    this.onFindCare,
    this.onMessageSara,
  });

  /// Chooses the copy and the ordering of the two routes.
  final RefusalCategory category;

  /// Her words, if the route still holds them. Nothing was logged and nothing
  /// was shared — the question lives in memory and dies with the route.
  final String? question;

  final VoidCallback? onBack;

  /// `X03`.
  final VoidCallback? onBoundaries;

  /// `Y11`.
  final VoidCallback? onFindCare;

  /// `H06`.
  final VoidCallback? onMessageSara;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.assistant,
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.whatItCanAndCannotDo,
            icon: const Icon(Icons.info_outline),
            onPressed: onBoundaries,
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.back,
          variant: AppButtonVariant.outlined,
          height: 46,
          fontSize: 15,
          onPressed: onBack,
        ),
      ],
      children: [
        if (question case final asked?) AssistantAskBubble(asked),
        AssistantRefusalBody(
          category: category,
          promotesCare: category.promotesCare,
          onFindCare: onFindCare,
          onMessageSara: onMessageSara,
          onBoundaries: onBoundaries,
        ),
      ],
    );
  }
}
