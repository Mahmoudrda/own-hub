/// B08 — client results. The screen where the coach cannot author anything.
///
/// `P0-CONSENT-01` and `P0-CONSENT-04`: *"The coach's document is created in
/// state requested with no media, no numbers and no quote. Only the client can
/// grant… Coach attempts to attach a photo, type a number, or edit the quote —
/// all three are refused by the security rules, not only by the UI."*
///
/// This file is the UI half of that, and it is an **absence**: there is no
/// [TextField], no `AppField`, no image picker, no `Slider` and no number pad
/// anywhere in this tree. The only two things a coach can do here are
///
///   * **ask** — [ResultsView.onAskAnotherClient], which produces a
///     [ResultRequest]: five fields, none of them content; and
///   * **reorder** — the one field `coachKeys()` lets her write.
///
/// A widget test walks this tree and asserts the absence, because "we did not
/// put a text field there" is a promise and a search is a fact.
///
/// ## Consent is read here, at render, and nothing is stored
///
/// Each card asks [ClientResult.publishableAt] at the moment it is built. A
/// result that is not currently publishable draws **no photograph, no sentence
/// and no figure** — its content is not "hidden", it is not asked for. That is
/// why a withdrawal three months after publication takes effect on this screen
/// without anything being republished.
///
/// ## What this screen cannot say yet
///
/// The dictionary carries `Live` and nothing for the other six consent states.
/// A requested, declined, expired, revoked or orphaned result therefore draws
/// **no status pill** rather than one invented in English. Reported.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/consent.dart';
import '../domain/derived_numbers.dart';
import '../domain/portfolio_block.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.results,
    required this.now,
    this.payload,
    this.onChanged,
    this.onReorder,
    this.onAskAnotherClient,
    this.onDone,
    this.onClose,
  });

  /// The live documents, in her order. Read, never copied.
  final List<ClientResult> results;

  /// The moment of the read. Injected, because consent is a function of time
  /// and a wall clock in a widget is a test that cannot be written.
  final DateTime now;

  /// The `results` block, when this screen was opened to edit one.
  final ResultsPayload? payload;

  final ValueChanged<ResultsPayload>? onChanged;

  /// `(resultId, order)` — the only field a coach may change after creation.
  final void Function(String resultId, int order)? onReorder;

  /// Produces a [ResultRequest]. There is nothing on this screen to put content
  /// into, which is the point of it.
  final VoidCallback? onAskAnotherClient;

  final VoidCallback? onDone;
  final VoidCallback? onClose;

  bool _isOn(String resultId) => payload?.resultIds.contains(resultId) ?? false;

  void _toggle(String resultId) {
    final current = payload;
    if (current == null || onChanged == null) return;
    final next = [...current.resultIds];
    if (!next.remove(resultId)) {
      // Twelve is the cap in `BlockValidator` and in the rules.
      if (next.length >= 12) return;
      next.add(resultId);
    }
    onChanged!.call(
      ResultsPayload(
        resultIds: next,
        display: current.display,
        showNumbers: current.showNumbers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.clientResults,
        onBack: onClose,
        leadingIcon: Icons.close,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.done_54ca1,
              height: 38,
              fontSize: 15,
              onPressed: onDone,
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          AppCard(
            variant: AppCardVariant.sage,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.handshake,
                    size: 22,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sheHasToAgreeInTheApp,
                          style: AppText.titleM.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.weAskHerShePicksThePictures,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              if (from == to) return;
              onReorder?.call(results[from].resultId, to);
            },
            children: [
              for (var i = 0; i < results.length; i++)
                _ResultCard(
                  key: ValueKey(results[i].resultId),
                  index: i,
                  result: results[i],
                  now: now,
                  selectable: payload != null && onChanged != null,
                  selected: _isOn(results[i].resultId),
                  onToggle: () => _toggle(results[i].resultId),
                ),
            ],
          ),
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            onTap: onAskAnotherClient,
            children: [
              Row(
                children: [
                  const Icon(Icons.add, size: 22, color: AppColors.primaryDim),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.askAnotherClient,
                      style: AppText.titleS.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            l10n.aResultCanBePicturesNumbersOr,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One result, drawn from what she currently agrees to.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.index,
    required this.result,
    required this.now,
    required this.selectable,
    required this.selected,
    required this.onToggle,
  });

  final int index;
  final ClientResult result;
  final DateTime now;
  final bool selectable;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Read time, every time. The answer is used and thrown away.
    final publishable = result.publishableAt(now);
    final quote = publishable && result.scope.quote ? result.quote : null;
    final mediaIds = publishable && result.scope.photos
        ? result.mediaIds
        : const <String>[];
    final numbers = publishable && result.scope.numbers
        ? result.numbers.values.toList()
        : const <DerivedNumber>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
        onTap: selectable ? onToggle : null,
        gap: 10,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.person_outline,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              const Spacer(),
              // `Live` is the one consent state the dictionary names. The other
              // six draw nothing rather than an English word.
              if (publishable)
                AppPill(
                  l10n.live,
                  background: AppColors.tertiaryContainer,
                  foreground: AppColors.tertiary,
                ),
              if (selectable) ...[
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.outline,
                ),
              ],
            ],
          ),
          if (mediaIds.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final _ in mediaIds)
                  AppMedia(
                    width: 82,
                    height: 82,
                    kind: AppMediaKind.photo,
                    showPlayButton: false,
                    borderRadius: AppRadius.xs,
                    // Blur is on unless she turned it off for her own face.
                    badge: result.blurred ? l10n.blur : null,
                  ),
              ],
            ),
          if (numbers.isNotEmpty)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final n in numbers) _NumberChip(number: n)],
            ),
          // Her sentence, written by her, rendered untouched.
          if (quote != null && quote.isNotEmpty)
            Text(
              quote,
              style: AppText.bodyM.copyWith(color: AppColors.onSurface),
            ),
        ],
      ),
    );
  }
}

/// One derived figure. Never typed, and never a weight.
class _NumberChip extends StatelessWidget {
  const _NumberChip({required this.number});

  final DerivedNumber number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final label = measureLabel(l10n, number.measureId);
    // Western digits in both languages, and no NumberFormat.
    final figure = '${number.from} → ${number.to}${number.unit}';

    // A fact on the page, highlighted: the house pill, not a drawn capsule.
    return AppPill(
      label == null ? figure : '$label $figure',
      background: AppColors.surfaceContainer,
      foreground: AppColors.onSurface,
    );
  }
}

/// The dictionary name for a derivable measure, or null.
///
/// Five of the fourteen on [DerivableMeasures.allowed] have a minted name. The
/// other nine draw their figure without one — her own number with no label is a
/// gap; a label invented in English is a defect. Reported.
String? measureLabel(AppL10n l10n, String measureId) => switch (measureId) {
  'sessionsLogged' => l10n.sessions,
  'countedWeeks' => l10n.countedWeeks,
  'personalBests' => l10n.personalBests,
  'plankSec' => l10n.plankHold,
  'wallSitSec' => l10n.wallSit,
  _ => null,
};
