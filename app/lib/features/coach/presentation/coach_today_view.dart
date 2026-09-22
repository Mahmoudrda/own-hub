/// `K07` — Today, her desk. And `K24` — Today, day one.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K07` and
/// `6-v2/src/screens-firstrun.mjs` → `K24`.
///
/// # `K24` is a state, not a route (HANDOFF 16)
///
/// It is this widget's other branch, taken when her roster is empty, and
/// `app_routes.dart` lists it only because that table is generated from the
/// screen inventory. `firstRunStates` in `app_router.dart` keeps it out of
/// `appDestinations`, so "Today, empty" cannot be opened over a Today that is
/// not empty. **Accepting a first client flips the same route with no
/// navigation** — [CoachToday.resolve] reads the roster, and the branch changes
/// underneath her (`P0-CDAY-01`).
///
/// The branch reads [CoachCapacity.taken], not the queue. A coach with eleven
/// clients and a quiet evening has an empty queue and is emphatically not on day
/// one; branching on the queue would show her the beginner's screen the moment
/// she caught up, which is the opposite of a reward.
///
/// # Two document reads, at any roster size
///
/// `P0-CSCALE-01`. Everything here comes from two documents — her profile and
/// her desk — and the queue is a Cloud-Function aggregate capped at thirty with
/// an overflow count. There is no per-client read on this screen and no query at
/// all. See `coach_desk.dart`.
///
/// # Money is absent rather than zero
///
/// The prototype's `K24` shows "Earnings this month · 0 EGP". This does not.
/// The payment seam has no implementation, so there is no figure to state, and a
/// zero is a claim about her month rather than the absence of one. The row
/// appears when — and only when — a provider supplies a statement **and**
/// `Feature.payments` is on.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';
import '../domain/coach_desk.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

/// The day's name, from her date rather than from a hardcoded Tuesday.
///
/// Saturday and Sunday have no full-name key in the dictionary — only the
/// abbreviations — so those two render short. The same limitation the Today
/// flow has, flagged rather than papered over with an invented string.
String coachWeekdayLabel(AppL10n l10n, DateTime date) => switch (date.weekday) {
  DateTime.monday => l10n.monday,
  DateTime.tuesday => l10n.tuesday,
  DateTime.wednesday => l10n.wednesday,
  DateTime.thursday => l10n.thursday,
  DateTime.friday => l10n.friday,
  DateTime.saturday => l10n.sat,
  _ => l10n.sun,
};

/// Why a row is waiting. Ids into the dictionary, not a sentence a Cloud
/// Function composed in one language.
String deskReasonLabel(AppL10n l10n, DeskReason reason) => switch (reason) {
  DeskReason.reviewDue => l10n.review,
  DeskReason.checkIn => l10n.checkIns,
  DeskReason.newEnquiry => l10n.newEnquiry,
  DeskReason.message => l10n.message,
};

/// Where a row leads. `W09` and `K16` belong to other groups; `K09` is ours.
String deskReasonDestination(DeskReason reason) => switch (reason) {
  DeskReason.reviewDue || DeskReason.checkIn => 'W09',
  DeskReason.newEnquiry => 'K09',
  DeskReason.message => 'K16',
};

class CoachTodayView extends StatelessWidget {
  const CoachTodayView({
    super.key,
    required this.model,
    this.now,
    this.onSelectTab,
    this.onNotifications,
    this.onOpenRow,
    this.onStartReviews,
    this.onOpenPortfolio,
    this.onOpenFirstWeek,
    this.onOpenClients,
    this.onOpenPublicProfile,
  });

  final CoachTodayViewModel model;
  final DateTime? now;

  final ValueChanged<String>? onSelectTab;
  final VoidCallback? onNotifications;

  /// Given the relationship id of the row she tapped.
  final ValueChanged<String>? onOpenRow;

  final VoidCallback? onStartReviews;
  final VoidCallback? onOpenPortfolio;
  final VoidCallback? onOpenFirstWeek;
  final VoidCallback? onOpenClients;

  /// `K18`, the page a client reads before she decides.
  ///
  /// It was built and tested and **nothing in the product opened it**: the
  /// prototype's only door was a row on `K17`, and `coach_earnings_view.dart`
  /// deliberately points that row at `K05` instead, because a payout method has
  /// nothing to do with a public profile. That decision stands; this is a
  /// separate, honestly-labelled way in, on the screen she starts her day on and
  /// on both of its branches.
  final VoidCallback? onOpenPublicProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'K07',
        onSelect: (id) {
          final onTab = onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          goToScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: model.isDayOne
            ? _dayOne(context, l10n)
            : _working(context, l10n),
      ),
    );
  }

  // ---------------------------------------------------------------- head ----

  Widget _header(BuildContext context, AppL10n l10n) {
    // Her desk's masthead, laid out like her own Today: the day as the issue
    // line with the tools beside it, a pencil rule, and then "Today" at
    // section size with one swipe of marker and the page's drawing beside
    // it. Her own Today is underlined; the coach's desk is highlighted, so
    // the two front pages are not the same page.
    final folio = AppSplitRow(
      start: Text(
        coachWeekdayLabel(l10n, now ?? DateTime.now()),
        style: EditorialType.folio,
      ),
      end: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // In the header rather than in either branch's list, so a coach on
          // her first day and a coach with a full roster reach it the same way.
          IconButton(
            tooltip: l10n.yourPublicProfile,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => goToScreen(context, 'K18', onOpenPublicProfile),
          ),
          IconButton(
            tooltip: l10n.notifications,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.notifications_none),
            onPressed: () => goToScreen(context, 'A01', onNotifications),
          ),
          // Her picture, as on her own Today: for a woman who trains and
          // coaches it is the way back to the trainee side, and it keeps her
          // profile one tap away from the desk.
          AppAvatar(size: 32, onOpenProfile: () => goToScreen(context, 'A02')),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        folio,
        const HandRule(seed: 41, height: 8),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: MarkerHighlight(
                  drawOn: true,
                  child: Text(l10n.today, style: EditorialType.section),
                ),
              ),
            ),
            const ScreenArtInline(size: 64),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- K07 ----

  List<Widget> _working(BuildContext context, AppL10n l10n) {
    // The prototype's "3 check-ins waiting" is a sentence with a number baked
    // into it, and the dictionary has no parameterised form. `statedLine`
    // renders it only to a coach for whom it is literally true; everyone else
    // gets the number-free line instead. A sentence that says less beats one
    // that says something untrue.
    final waitingLine = statedLine(
      l10n.n3CheckInsWaiting,
      states: 3,
      hers: model.waitingCount,
    );

    return [
      _header(context, l10n),
      if (model.hasWork)
        AppCard(
          variant: AppCardVariant.amber,
          children: [
            AppSplitRow(
              start: Text(
                waitingLine ?? l10n.needsAReply,
                style: AppText.titleM,
              ),
              end: AppButton(
                l10n.start,
                height: 44,
                fontSize: 15,
                onPressed: () => goToScreen(context, 'W09', onStartReviews),
              ),
            ),
          ],
        ),
      ..._queue(context, l10n),
      // Everyone past the cap, as a count. `W01` is the paginated list.
      if (model.overflowCount > 0)
        AppListItem(
          leading: const Icon(
            Icons.group,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.clients,
          trailing: AppPill(
            countLabel(model.overflowCount),
            background: AppColors.surfaceContainer,
            foreground: AppColors.onSurfaceVariant,
          ),
          onTap: () => goToScreen(context, 'W01', onOpenClients),
        ),
      AppListItem(
        leading: const Icon(Icons.image, size: 24, color: AppColors.primaryDim),
        title: l10n.myPortfolio,
        trailing: const Icon(
          Icons.chevron_right,
          size: 22,
          color: AppColors.onSurfaceVariant,
        ),
        onTap: () => goToScreen(context, 'B01', onOpenPortfolio),
      ),
      // Money, only when a provider actually supplied a figure.
      if (model.canShowMoney)
        Text(l10n.earningsThisMonth, style: AppText.titleM),
    ];
  }

  /// The rows waiting on her, on **both** branches.
  ///
  /// It used to be drawn only by `_working`, which is chosen from
  /// `capacity.taken` — so the very first enquiry a coach ever receives was
  /// invisible on her desk, because a woman who has asked is not yet a client
  /// and the counter had not moved. The empty state below still says she has
  /// no clients, which stays true; what changed is that somebody waiting on
  /// her is now on the screen she starts her day on.
  List<Widget> _queue(BuildContext context, AppL10n l10n) => <Widget>[
    for (final row in model.rows)
      AppListItem(
        key: Key('desk:${row.relId}'),
        leading: _InitialCircle(initial: row.initial),
        title: row.displayName,
        subtitle: deskReasonLabel(l10n, row.reason),
        trailing: const Icon(
          Icons.chevron_right,
          size: 22,
          color: AppColors.onSurfaceVariant,
        ),
        onTap: () => goToScreen(
          context,
          deskReasonDestination(row.reason),
          onOpenRow == null ? null : () => onOpenRow!(row.relId),
        ),
      ),
  ];

  // ---------------------------------------------------------------- K24 ----

  List<Widget> _dayOne(BuildContext context, AppL10n l10n) {
    const chevron = Icon(
      Icons.chevron_right,
      size: 21,
      color: AppColors.onSurfaceVariant,
    );

    // The prototype's "2 of 4 done" is the mockup's progress, frozen into the
    // dictionary. `countOfTotal` is the parameterised form the dictionary
    // already carries, so the row states HER count against HER total and is
    // right for every coach rather than only the one on two.
    final arcLine = l10n.countOfTotal(
      '${model.firstWeek.doneCount}',
      '${model.firstWeek.stepCount}',
    );

    return [
      _header(context, l10n),
      // Amber, not error: she has done nothing wrong, she is being checked.
      if (model.showsVerificationCard)
        AppCard(
          variant: AppCardVariant.amber,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.hourglass_top,
                  size: 24,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.weAreCheckingYourCertificates,
                        style: AppText.titleM,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.usuallyTheSameDayYouCanBuild,
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
      ..._queue(context, l10n),
      // Rule 17: what will appear here, why it is empty, one way in.
      AppEmptyState(
        icon: Icons.group,
        art: AppArt.stretchSeated,
        title: l10n.noClientsYet,
        body: l10n.whenAWomanAsksToWorkWith_4vp4g,
        onTap: () => goToScreen(context, 'W01', onOpenClients),
      ),
      // An open line on the page, not a third box under the two above it.
      AppListItem(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: const Icon(
          Icons.checklist,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.yourFirstWeek,
        subtitle: arcLine,
        trailing: chevron,
        onTap: () => goToScreen(context, 'K25', onOpenFirstWeek),
      ),
      // The work list is its own section. The ruled line above already
      // closes the arc, so a second rule here would only double it.
      const SizedBox(height: 8),
      Text(l10n.worthDoingBeforeYourFirstClient, style: AppText.titleM),
      // Three pieces of real work. None of it is a tour, and none of it is
      // busywork — each produces something a client will see.
      _TodoRow(
        icon: Icons.image,
        title: l10n.finishYourPage,
        // "Clients decide from it · 3 sections so far" counts sections she
        // may not have written. The row keeps the part that is true of every
        // coach and states no figure.
        subtitle: l10n.sectionsColoursAndWordsAllYours,
        // B14 is the portfolio's own day-one STATE, so it is not a
        // destination. B01 is the portfolio, and it decides which to draw.
        screenId: 'B01',
        onTap: onOpenPortfolio,
      ),
      _TodoRow(
        icon: Icons.repeat,
        title: l10n.saveASplit,
        subtitle: l10n.writeYourWeekOnceUseItOn,
        screenId: 'K19',
      ),
      _TodoRow(
        icon: Icons.restaurant,
        title: l10n.addAMealYouAlwaysPrescribe,
        subtitle: l10n.itWaitsInYourOwnCollection,
        screenId: 'W07',
      ),
      // What she keeps, with no invented figure beside it.
      Text(
        l10n.youKeep80OfWhatShePays,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
    ];
  }
}

/// A queue row's avatar. Her initial, because there is no photo pipeline.
class _InitialCircle extends StatelessWidget {
  const _InitialCircle({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: initial.isEmpty
        ? const Icon(
            Icons.person,
            size: 24,
            color: AppColors.onPrimaryContainer,
          )
        : Text(
            initial,
            style: AppText.titleM.copyWith(color: AppColors.onPrimaryContainer),
          ),
  );
}

/// One piece of real work on `K24`.
class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.screenId,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String screenId;
  final VoidCallback? onTap;

  // A bare icon, so the row rings it in pencil like every other leading
  // glyph rather than setting it on a tile of its own.
  @override
  Widget build(BuildContext context) => AppListItem(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    leading: Icon(icon, size: 20, color: AppColors.primaryDim),
    title: title,
    subtitle: subtitle,
    trailing: const Icon(
      Icons.chevron_right,
      size: 21,
      color: AppColors.onSurfaceVariant,
    ),
    onTap: () => goToScreen(context, screenId, onTap),
  );
}
