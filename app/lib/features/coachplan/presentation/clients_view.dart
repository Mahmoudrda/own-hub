/// `W01` — Clients and the queue. And `W11`, which is a **state of this
/// widget**, not a screen.
///
/// HANDOFF 16: "first-run is a state, not a route". `W11` is the branch taken
/// when the listener has delivered and returned nothing, so there is no route
/// to it, nothing navigates to it, and accepting a first client flips the same
/// screen with no navigation at all. A test reaches it by pumping this widget
/// with an empty roster, which is the only way it is ever true.
///
/// ## Three states, and the middle one matters most
///
/// `hasLoaded == false` is **not** an empty roster. Rendering the day-one
/// screen over a coach's real book — at the moment her signal dropped — would
/// be a lie at the worst possible time, so the list and the empty state are
/// both withheld until the listener has spoken. `CoachClientRepository.hasLoaded`
/// exists for exactly this branch.
///
/// ## The chips are filters, never a second query
///
/// `ClientQueue.matching` runs over the documents this screen already holds.
/// Opening the inbox afterwards costs nothing for the same reason.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import '../domain/clients/coach_client.dart';
import 'coachplan_widgets.dart';

class ClientsView extends StatelessWidget {
  const ClientsView({
    super.key,
    required this.clients,
    required this.hasLoaded,
    this.now,
    this.filter,
    this.onSelectFilter,
    this.onOpenClient,
    this.onStartWaiting,
    this.onBuildAPlan,
    this.onOpenSplits,
    this.onOpenAssessment,
    this.onOpenPortfolio,
    this.onTab,
  });

  /// Everything the one listener delivered. Already capped at [kClientCap].
  final List<CoachClient> clients;

  /// False until the listener has answered. See the library note.
  final bool hasLoaded;

  final DateTime? now;

  /// The chip in force, or null for all of them.
  final QueueFilter? filter;
  final ValueChanged<QueueFilter?>? onSelectFilter;

  final ValueChanged<CoachClient>? onOpenClient;
  final VoidCallback? onStartWaiting;
  final VoidCallback? onBuildAPlan;
  final VoidCallback? onOpenSplits;

  /// `W11`'s third action. Real work, not a tour.
  final VoidCallback? onOpenAssessment;
  final VoidCallback? onOpenPortfolio;

  final ValueChanged<String>? onTab;

  bool get isFirstRun => hasLoaded && clients.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final moment = now ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachPlanNavBar(activeScreenId: 'W01', onTab: onTab),
      body: AppScaffold(
        children: isFirstRun ? _firstRun(l10n) : _roster(context, l10n, moment),
      ),
    );
  }

  // ------------------------------------------------------------- W01 ------

  List<Widget> _roster(BuildContext context, AppL10n l10n, DateTime moment) {
    final chosen = filter;
    final shown = chosen == null
        ? ClientQueue.longestWaitingFirst(clients)
        : ClientQueue.matching(clients, chosen, now: moment);
    final waiting = clients.where((c) => c.queue.hasUnanswered).length;

    return [
      AppSplitRow(
        start: _masthead(l10n),
        end: AppPill(
          // Her book against her cap. Both numbers are hers, so the
          // parameterised form is right and no mockup figure is stated.
          l10n.countOfTotal('${clients.length}', '$kClientCap'),
          background: AppColors.surfaceContainer,
          foreground: AppColors.onSurfaceVariant,
        ),
      ),
      AppChipRow(
        grow: false,
        items: [
          for (final value in QueueFilter.values) _filterLabel(l10n, value),
        ],
        selected: chosen == null
            ? const <int>{}
            : <int>{QueueFilter.values.indexOf(chosen)},
        onTap: onSelectFilter == null
            ? null
            : (i) {
                final tapped = QueueFilter.values[i];
                onSelectFilter!(tapped == chosen ? null : tapped);
              },
      ),
      // Nothing is drawn below the chips until the listener has spoken:
      // neither the roster nor the day-one screen is true yet.
      if (hasLoaded) ...[
        if (waiting > 0)
          AppCard(
            variant: AppCardVariant.amber,
            children: [
              AppSplitRow(
                start: Text(l10n.needsAReply, style: AppText.titleM),
                end: AppButton(
                  l10n.start,
                  height: 44,
                  fontSize: 15,
                  onPressed: onStartWaiting,
                ),
              ),
            ],
          ),
        Column(
          key: CoachPlanKeys.clientsList,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final client in shown) ...[
              const SizedBox(height: kStackGap),
              AppListItem(
                key: Key('client:${client.clientUid}'),
                title: client.displayName,
                trailing: _stateFor(l10n, client, moment),
                onTap: onOpenClient == null
                    ? null
                    : () => onOpenClient!(client),
              ),
            ],
          ],
        ),
      ],
      Row(
        children: [
          Expanded(
            child: AppButton(
              l10n.buildAPlan,
              variant: AppButtonVariant.tonal,
              height: 48,
              fontSize: 15,
              onPressed: onBuildAPlan,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              l10n.mySplits,
              variant: AppButtonVariant.outlined,
              height: 48,
              fontSize: 15,
              icon: Icons.repeat,
              onPressed: onOpenSplits,
            ),
          ),
        ],
      ),
    ];
  }

  /// The coach's home, set as a section title and underlined once by hand —
  /// the one mark on this page. Her roster below it stays print.
  static Widget _masthead(AppL10n l10n) => HandUnderline(
    level: HandLevel.signature,
    width: HandStroke.felt,
    drawOn: true,
    gap: 4,
    child: Text(l10n.clients, style: EditorialType.section),
  );

  static String _filterLabel(AppL10n l10n, QueueFilter value) =>
      switch (value) {
        QueueFilter.needsReply => l10n.needsReply,
        QueueFilter.reviewsDue => l10n.reviewsDue,
        QueueFilter.planNeeded => l10n.planNeeded,
        QueueFilter.assessmentDue => l10n.assessmentDue,
      };

  /// What this row is waiting for, as a pill.
  ///
  /// Ordered by what the coach owes her: a reply first, then a plan, then an
  /// assessment. It is a statement of outstanding work, not a score.
  static Widget _stateFor(AppL10n l10n, CoachClient client, DateTime moment) {
    if (client.queue.hasUnanswered) {
      return AppPill(
        l10n.reply,
        background: AppColors.amberContainer,
        foreground: AppColors.amber,
      );
    }
    if (client.queue.matches(QueueFilter.planNeeded, moment)) {
      return AppPill(
        l10n.planNeeded,
        background: AppColors.surfaceContainer,
        foreground: AppColors.onSurfaceVariant,
      );
    }
    if (client.queue.matches(QueueFilter.assessmentDue, moment)) {
      return AppPill(
        l10n.assessmentDue,
        background: AppColors.surfaceContainer,
        foreground: AppColors.onSurfaceVariant,
      );
    }
    return AppPill(
      l10n.onTrack,
      background: AppColors.tertiaryContainer,
      foreground: AppColors.tertiary,
    );
  }

  // ------------------------------------------------------------- W11 ------

  /// Rule 17: name what will appear, say why it is empty, offer real work.
  ///
  /// No tour, no overlay and no coach-mark — three pieces of work that each
  /// produce something a client will actually see.
  List<Widget> _firstRun(AppL10n l10n) {
    const chevron = Icon(
      Icons.chevron_right,
      size: 21,
      color: AppColors.onSurfaceVariant,
    );

    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: _masthead(l10n),
      ),
      AppEmptyState(
        key: CoachPlanKeys.clientsEmpty,
        icon: Icons.group,
        art: AppArt.squatWeights,
        title: l10n.noClientsYet,
        body: l10n.womenWhoAskToWorkWithYou,
      ),
      SectionHead(l10n.worthDoingBeforeYourFirstClient),
      AppListItem(
        leading: const Icon(Icons.image, size: 22, color: AppColors.primaryDim),
        title: l10n.workOnMyPage,
        trailing: chevron,
        onTap: onOpenPortfolio,
      ),
      AppListItem(
        leading: const Icon(
          Icons.repeat,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.saveOneSplit,
        trailing: chevron,
        onTap: onOpenSplits,
      ),
      AppListItem(
        leading: const Icon(
          Icons.checklist,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.setUpAnAssessment,
        trailing: chevron,
        onTap: onOpenAssessment,
      ),
    ];
  }
}
