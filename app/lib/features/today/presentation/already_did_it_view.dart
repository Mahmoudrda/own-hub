/// T02 — I already did it.
///
/// Matches `6-v2/src/screens-today.mjs` → `T02`. For the woman who trains
/// without her phone, which is most of them.
///
/// The sheet is drawn **over Today**, not in place of it: the prototype marks
/// this screen `layered: true`, and she should still see the day she is logging
/// against. So it is a scrim and a sheet in a [Stack] rather than a pushed
/// route.
///
/// This is a logging surface, so §2 rule 9 governs it completely. Every Save
/// here saves *immediately* and offers five seconds to undo. There is no
/// confirmation step, no "are you sure", and no dialog on any path — the text at
/// the top of the sheet promises exactly that, and the code has to keep the
/// promise. Recalled sessions copy last week's numbers and are marked as such,
/// so they can never set a personal best (§2 rule 1).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_log_button.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/today_day.dart';
import '../domain/today_repository.dart';
import 'today_cards.dart';

class AlreadyDidItView extends StatefulWidget {
  const AlreadyDidItView({
    super.key,
    this.repository,
    this.bus,
    this.onLogged,
    this.onStartSession,
    this.onOpenMeal,
    this.onSpeak,
    this.onSelectTab,
    this.onDismiss,
    this.plannedDetail,
    this.lastOtherTitle,
    this.lastOtherDetail,
  });

  final TodayRepository? repository;
  final LogCommandBus? bus;

  /// Where a saved session lands — R12, "Logged from memory".
  ///
  /// **It is handed the session, and the id on it is the one Progress must
  /// credit.** This used to be a plain `VoidCallback`, so the router had no id
  /// to credit with and invented one keyed to the day. Today's three rows carry
  /// three ids (`-planned`, `-other`, `-time<minutes>`), so a woman who logged
  /// her planned session and then a walk on the same day was counted twice by
  /// Home and once by Progress — the same disagreement as the missing dedupe in
  /// `logRecalledSession`, arriving by a different route. One id, both ledgers.
  final ValueChanged<RecalledSession>? onLogged;

  final VoidCallback? onStartSession;
  final VoidCallback? onOpenMeal;

  /// Voice logging. The prototype draws this button with no destination, so it
  /// is inert until the speech surface exists rather than being wired somewhere
  /// plausible-looking.
  final VoidCallback? onSpeak;

  final ValueChanged<String>? onSelectTab;

  /// Closes the sheet. Wired to the scrim, which is what a woman taps when she
  /// opened this by accident.
  ///
  /// Null falls back to popping the route. The scrim used to be a
  /// `Positioned.fill` over the whole Stack with no gesture on it at all, so it
  /// was a barrier that barred and did not dismiss, and it also swallowed every
  /// tap meant for the bottom bar underneath it.
  final VoidCallback? onDismiss;

  /// What today's planned session actually is — "15 minutes, 5 moves". Null
  /// renders the row with its name and no second line.
  ///
  /// It was a fixed string, and T02 is handed no plan: no repository read on
  /// this screen returns one. So a woman recalling a twenty-five-minute session
  /// of eight moves was offered "15 min · 5 moves · last week's weights" —
  /// including a claim about weights from a week she may not have trained — and
  /// then tapped Save on it.
  final String? plannedDetail;

  /// Her last other session, named and described. **Both or neither**: the row
  /// is drawn only when [lastOtherTitle] is supplied.
  ///
  /// This row was "Upper body, like last Thursday" with a fixed second line,
  /// offered to every woman on a fresh install, and tapping Save wrote that
  /// sentence into her log as the session's title. Nothing in this build can
  /// name her last other session — `TrainSession` carries no title and there is
  /// no history read here — so the router passes nothing and the row is not
  /// drawn. It returns with the data, not before.
  final String? lastOtherTitle;
  final String? lastOtherDetail;

  @override
  State<AlreadyDidItView> createState() => _AlreadyDidItViewState();
}

class _AlreadyDidItViewState extends State<AlreadyDidItView> {
  static const List<int> _durations = [20, 30, 45, 60];

  late final TodayRepository _repo;
  late final LogCommandBus _bus;
  late final bool _ownsRepo;
  late final bool _ownsBus;
  StreamSubscription<TodayDay>? _sub;
  late TodayDay _day;
  int? _chosenDuration;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryTodayRepository();
    _ownsBus = widget.bus == null;
    _bus = widget.bus ?? LogCommandBus();
    _day = _repo.day;
    _sub = _repo.watch().listen((day) {
      if (mounted) setState(() => _day = day);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_ownsBus) unawaited(_bus.flushAll());
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  String _dateStamp() {
    final d = _day.date;
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  /// Saves, then offers undo. In that order, always.
  ///
  /// The write is held by [LogCommandBus] for five seconds, so undoing it means
  /// the repository never hears about it at all — nothing is queued offline to
  /// resurface later.
  void _save(RecalledSession session) {
    final l10n = AppL10n.of(context);
    final handle = _bus.submit(
      UndoableLog(
        describe: session.title,
        commit: () => _repo.logRecalledSession(session),
      ),
    );
    showUndoSnackBar(context, handle: handle, undoLabel: l10n.undo);
    final onLogged = widget.onLogged;
    openScreen(
      context,
      'R12',
      onLogged == null ? null : () => onLogged(session),
    );
  }

  void _saveDuration(int index) {
    final l10n = AppL10n.of(context);
    final minutes = _durations[index];
    setState(() => _chosenDuration = index);
    _save(
      RecalledSession(
        // Deterministic (spine C1): the same activity on the same day replayed
        // after reconnect collides with itself instead of logging twice.
        id: 'recalled-${_dateStamp()}-time$minutes',
        title: l10n.aClassOrAWalk,
        minutes: minutes,
      ),
    );
  }

  /// Closes the sheet. The caller's route if it gave one, otherwise a pop.
  void _dismiss() {
    final onDismiss = widget.onDismiss;
    if (onDismiss != null) {
      onDismiss();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      // THE BAR IS THE TOP LAYER, AND THE SCRIM STOPS ABOVE IT.
      //
      // The bar used to be a sibling drawn *under* a `Positioned.fill` scrim,
      // so all three tabs were painted, marked live, and could not be touched:
      // every pointer that reached them was taken by the coloured box on top.
      // `tester.semantics.tap` does not hit-test, so every dead-control sweep
      // in this repository passed it.
      //
      // So the scrim and the sheet live inside the Expanded above the bar, and
      // the bar is the last thing laid down. Nothing overlaps it, which is also
      // why the sheet can no longer cover the tabs it claims to keep live.
      body: Stack(
        children: [
          // Today, still visible underneath — she is logging against this day.
          AppScaffold(
            children: [
              TodayGreeting(day: weekdayLabel(l10n, _day.date)),
              WorkoutCard(
                onStart: () =>
                    openScreen(context, 'R07', widget.onStartSession),
              ),
              MealCard(
                loggedAt: _day.mealLoggedAt,
                onTap: () => openScreen(context, 'E02', widget.onOpenMeal),
              ),
            ],
          ),
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        label: l10n.close,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _dismiss,
                          child: ColoredBox(
                            color: AppColors.ink.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    // Capped against the space this Stack actually has, not
                    // against the window. A sheet that measured itself with
                    // MediaQuery.sizeOf would collapse to nothing anywhere the
                    // ambient MediaQuery is not the full screen — still drawn,
                    // still in the tree, but impossible to tap.
                    LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * 0.92,
                          ),
                          child: SingleChildScrollView(
                            child: _sheet(context, l10n),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppNavBar(
                // T02, not T01. The active tab is deliberately not a link to
                // itself, so a screen that claims to be Home while it is a
                // sheet over Home leaves the Home tab drawn, marked active,
                // and doing nothing. Its own id keeps all three tabs live.
                activeScreenId: 'T02',
                onSelect: (id) {
                  final onTab = widget.onSelectTab;
                  if (onTab != null) {
                    onTab(id);
                    return;
                  }
                  openScreen(context, id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context, AppL10n l10n) {
    return AppSheet(
      gap: 12,
      children: [
        Text(l10n.whatDidYouDo, style: AppText.titleL),
        Text(
          l10n.tapOneAndItsSavedYouCan,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // Three likely answers instead of one guess: today's plan, her last
        // other session, and an activity that counts by time alone.
        AppListItem(
          variant: AppCardVariant.selected,
          title: l10n.legsAndGlutesTodaysPlan,
          subtitle: widget.plannedDetail ?? '',
          trailing: AppLogButton(
            l10n.save,
            primary: true,
            onPressed: () => _save(
              RecalledSession(
                id: 'recalled-${_dateStamp()}-planned',
                title: l10n.legsAndGlutesTodaysPlan,
              ),
            ),
          ),
        ),
        // Her last other session, and only when something has told us what it
        // was. The title is whatever the caller names, never a string from this
        // file: it becomes `RecalledSession.title`, so an invented one does not
        // stay on the screen, it goes into her log.
        if (widget.lastOtherTitle case final String lastOther)
          AppListItem(
            title: lastOther,
            subtitle: widget.lastOtherDetail ?? '',
            trailing: AppLogButton(
              l10n.save,
              onPressed: () => _save(
                RecalledSession(
                  id: 'recalled-${_dateStamp()}-other',
                  title: lastOther,
                ),
              ),
            ),
          ),
        AppCard(
          variant: AppCardVariant.filled,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          gap: 8,
          children: [
            Text(l10n.aClassOrAWalk, style: AppText.titleM),
            Text(
              l10n.countsByTimeAlone,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            AppChipRow(
              items: [l10n.n20Min, l10n.n30Min, l10n.n45Min, l10n.n1Hour],
              // This row is single-select, and the shared primitive models
              // selection as a set. An empty set means "she has not chosen
              // yet", which is a real state here and not the same as having
              // chosen 20 minutes.
              selected: {?_chosenDuration},
              onTap: _saveDuration,
            ),
          ],
        ),
        AppButton(
          l10n.orSayItZumba40Minutes,
          variant: AppButtonVariant.outlined,
          height: 52,
          fontSize: 15,
          icon: Icons.mic,
          onPressed: widget.onSpeak,
        ),
      ],
    );
  }
}
