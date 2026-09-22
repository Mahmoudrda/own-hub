/// R11 — Workout library.
///
/// Matches `6-v2/src/screens-train.mjs` → `R11`. The filters are the constraints
/// she actually has — quiet, no equipment, ten minutes — not muscle-group jargon.
/// The result count is shown so the filters explain the list rather than silently
/// shortening it.
///
/// **This screen issues no query.** The library ships with the app, so filtering
/// is a local list operation: it costs nothing, works with no signal, and there
/// is no index behind it to maintain. That is why the one screen in this group
/// which looks like a search is also the cheapest.
///
/// ## The D7 gap, reported rather than invented
///
/// `DECISIONS.md` D7 says a trainee may **pick a predefined split *or* design her
/// own** from this library. The prototype's R11 has no affordance for the second
/// half: every split-builder string in the dictionary (`buildASplit`, `mySplits`,
/// `applyASplit`, `saveAsASplit`) belongs to the coach screens K19/K20/W03, and
/// no client screen in `screens-train.mjs` offers one. Rather than invent the
/// entry point, it is named here and in the hand-off so the owner can place it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/train_repository.dart';
import 'train_widgets.dart';

class WorkoutLibraryView extends StatefulWidget {
  const WorkoutLibraryView({
    super.key,
    this.onBack,
    this.onOpenWorkout,
    this.onSelectTab,
    this.workouts,
  });

  final VoidCallback? onBack;
  final ValueChanged<LibraryWorkout>? onOpenWorkout;
  final ValueChanged<String>? onSelectTab;

  /// Injectable. Defaults to the design's three rows, resolved from the
  /// dictionary — the real 124-title library does not exist yet.
  final List<LibraryWorkout>? workouts;

  @override
  State<WorkoutLibraryView> createState() => _WorkoutLibraryViewState();
}

class _WorkoutLibraryViewState extends State<WorkoutLibraryView> {
  /// Which of the three filters are on. The design opens with quiet and
  /// no-equipment already chosen.
  final Set<int> _filters = {0, 1};

  String _query = '';

  static const int _quiet = 0;
  static const int _noEquipment = 1;
  static const int _tenMinutes = 2;

  List<LibraryWorkout> _visible(List<LibraryWorkout> all) {
    final query = _query.trim().toLowerCase();
    return all.where((workout) {
      if (_filters.contains(_quiet) && !workout.quiet) return false;
      if (_filters.contains(_noEquipment) && workout.needsEquipment) {
        return false;
      }
      if (_filters.contains(_tenMinutes) && workout.minutes > 10) return false;
      if (query.isEmpty) return true;
      return workout.title.toLowerCase().contains(query) ||
          workout.detail.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final all =
        widget.workouts ??
        [
          LibraryWorkout(
            id: 'floor_legs',
            title: l10n.floorLegsNoJumping,
            detail: l10n.n10MinBeginnerNour,
            quiet: true,
            minutes: 10,
          ),
          LibraryWorkout(
            id: 'quiet_full_body',
            title: l10n.quietFullBody,
            detail: l10n.n15MinBeginnerMariam,
            quiet: true,
            minutes: 15,
          ),
          LibraryWorkout(
            id: 'upper_body_home',
            title: l10n.upperBodyAtHome,
            detail: l10n.n20MinEasyHabiba,
            quiet: true,
            minutes: 20,
          ),
        ];

    final visible = _visible(all);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'R01',
        onSelect: widget.onSelectTab,
      ),
      body: AppScaffold(
        appBar: TrainTopBar(
          onClose: widget.onBack,
          closeIcon: Icons.arrow_back,
        ),
        children: [
          AppField(
            // `search124Workouts` — "Search 124 workouts" — counts a library
            // that does not exist yet: `WorkoutVideoRepository` states plainly
            // that "the 124 titles do not exist yet", and this screen filters
            // three bundled rows. The box searches; it does not claim a size.
            hint: l10n.search,
            onChanged: (value) => setState(() => _query = value),
            trailing: const Icon(
              Icons.search,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          AppChipRow(
            grow: false,
            items: [l10n.quiet, l10n.noEquipment, l10n.n10Min],
            selected: _filters,
            onTap: (i) => setState(() {
              // Multi-select: these are constraints that stack, not a choice
              // between three.
              _filters.contains(i) ? _filters.remove(i) : _filters.add(i);
            }),
          ),
          // `n18WorkoutsQuietAndNoEquipment` — "18 workouts, quiet and no
          // equipment" — sat directly above `visible`, the list the filters had
          // just produced, and said eighteen however many rows were under it
          // and whichever chips were lit. The count is real (`visible.length`)
          // and so are the filters; the dictionary has no "{n} workouts" form
          // to state them in, so the line is withheld rather than invented.
          // The result list IS the answer.
          for (final workout in visible)
            AppListItem(
              title: workout.title,
              subtitle: workout.detail,
              leading: const AppMedia(
                width: 72,
                height: 56,
                borderRadius: AppRadius.sm,
                showPlayButton: false,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () => widget.onOpenWorkout?.call(workout),
            ),
        ],
      ),
    );
  }
}
