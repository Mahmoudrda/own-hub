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
    this.plannedDetail,
    this.lastOtherDetail,
  });

  final TodayRepository? repository;
  final LogCommandBus? bus;

  /// Where a saved session lands — R12, "Logged from memory".
  final VoidCallback? onLogged;

  final VoidCallback? onStartSession;
  final VoidCallback? onOpenMeal;

  /// Voice logging. The prototype draws this button with no destination, so it
  /// is inert until the speech surface exists rather than being wired somewhere
  /// plausible-looking.
  final VoidCallback? onSpeak;

  final ValueChanged<String>? onSelectTab;

  /// What today's planned session actually is — "15 min · 5 moves · last
  /// week's weights" — and what her last other session was — "20 min · 6
  /// moves". Null renders the row with its name and no second line.
  ///
  /// They were two fixed strings, and T02 is handed no plan and no history: no
  /// repository read on this screen returns either. So a woman recalling a
  /// twenty-five-minute session of eight moves was offered "15 min · 5 moves ·
  /// last week's weights" — including a claim about weights from a week she may
  /// not have trained — and then tapped Save on it.
  final String? plannedDetail;
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
    openScreen(context, 'R12', widget.onLogged);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Today, still visible underneath — she is logging against this day.
          Column(
            children: [
              Expanded(
                child: AppScaffold(
                  children: [
                    TodayGreeting(day: weekdayLabel(l10n, _day.date)),
                    WorkoutCard(
                      onStart: () =>
                          openScreen(context, 'R07', widget.onStartSession),
                    ),
                    MealCard(
                      loggedAt: _day.mealLoggedAt,
                      onTap: () =>
                          openScreen(context, 'E02', widget.onOpenMeal),
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
          Positioned.fill(
            child: ColoredBox(color: AppColors.ink.withValues(alpha: 0.45)),
          ),
          // Capped against the space this Stack actually has, not against the
          // window. A sheet that measured itself with MediaQuery.sizeOf would
          // collapse to nothing anywhere the ambient MediaQuery is not the full
          // screen — still drawn, still in the tree, but impossible to tap.
          LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.92,
                ),
                child: SingleChildScrollView(child: _sheet(context, l10n)),
              ),
            ),
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
          l10n.tapOneAndItIsSavedUndo,
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
        AppListItem(
          title: l10n.upperBodyLikeLastThursday,
          subtitle: widget.lastOtherDetail ?? '',
          trailing: AppLogButton(
            l10n.save,
            onPressed: () => _save(
              RecalledSession(
                id: 'recalled-${_dateStamp()}-upper',
                title: l10n.upperBodyLikeLastThursday,
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
