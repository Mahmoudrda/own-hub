/// R01 — Train.
///
/// Matches `6-v2/src/screens-train.mjs` → `R01`, then redrawn as one purpose:
/// pick or start a workout. Top to bottom: the section's name, a Today card
/// with the one Start button, a "Your plan" row (R02 holds the programme, its
/// tiers and every way to change the plan), a "My workouts" row, and Explore:
/// every workout and every filmed move behind a search box and one Filters
/// button.
///
/// Two notes carried from the plan, neither of them mine to resolve here:
///
///  * **OQ-12.** In the prototype "Continue · from Sara" routes to `G06`, the
///    coached session screen, for *every* woman — including the ones who have no
///    coach. The plan records this as an open finding rather than a bug to fix
///    inside the screen, so the destination is a callback: the router decides
///    whether she goes to her coach's session or to R03, and this screen does not
///    pretend to know.
///  * The week marks render values the rewards group owns. This screen displays
///    them and computes none of them. They count sessions, not days: which day
///    she trained is not a fact the product holds, so no strip names Monday.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../theme/screen_art.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart' show kBodyPadding, kStackGap;
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';
import '../../../ui/screen_scope.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../data/exercise_media_store.dart';
import '../domain/custom_workout.dart';
import '../domain/exercise_library.dart';
import '../domain/train_repository.dart';
import 'program_view.dart' show ProgramDay;
import 'train_explore.dart';

class TrainView extends StatefulWidget {
  const TrainView({
    super.key,
    this.onContinue,
    this.onSeeProgram,
    this.onSelectTab,
    this.onOpenWorkout,
    this.onOpenExercise,
    this.programTitle,
    this.week = const <ProgramDay>[],
    this.workouts = const <LibraryWorkout>[],
    this.exercises = const <LibraryExercise>[],
    this.hiddenFor,
    this.media = const NoExerciseMedia(),
    this.focus,
    this.workoutIsFilmed,
    this.myWorkouts = const <CustomWorkout>[],
    this.onBuildOwn,
    this.onStartMine,
    this.onEditMine,
    this.onDeleteMine,
  });

  /// The workouts she built herself, newest first.
  final List<CustomWorkout> myWorkouts;

  /// "Build my own workout": opens the builder.
  final VoidCallback? onBuildOwn;

  final ValueChanged<CustomWorkout>? onStartMine;
  final ValueChanged<CustomWorkout>? onEditMine;
  final ValueChanged<CustomWorkout>? onDeleteMine;

  /// See OQ-12 above. The router owns where this goes.
  final VoidCallback? onContinue;

  /// "Your plan": R02, where the programme, its tiers and every way to change
  /// the plan are. Null (or R02 switched off) draws no row.
  final VoidCallback? onSeeProgram;

  final ValueChanged<String>? onSelectTab;

  /// A workout from Explore (`R03`).
  final ValueChanged<LibraryWorkout>? onOpenWorkout;

  /// A move from Explore (`R15`).
  final ValueChanged<LibraryExercise>? onOpenExercise;

  /// Her programme's name for the "Your plan" row's second line, or nothing:
  /// no title is invented for her.
  final String? programTitle;

  /// This week's sessions in order. Empty draws a Today card that carries on
  /// with whatever she was in.
  final List<ProgramDay> week;

  /// Every workout Explore may list. Narrowed here to the ones she can watch.
  final List<LibraryWorkout> workouts;

  /// The moves she may be shown, already screened for her life stage and for
  /// a clip on the phone.
  final List<LibraryExercise> exercises;

  /// Her stage, when screening it held moves back. Null when nothing was.
  final LifeStage? hiddenFor;

  final ExerciseMediaStore media;

  /// What a door asked Explore to show. Opens the page scrolled to Explore.
  final ExploreFocus? focus;

  /// Whether every move in a workout has a clip. Null lists every workout.
  final bool Function(LibraryWorkout workout)? workoutIsFilmed;

  @override
  State<TrainView> createState() => _TrainViewState();
}

class _TrainViewState extends State<TrainView> {
  late final ExploreFilter _filter = ExploreFilter(widget.focus);
  final GlobalKey _exploreKey = GlobalKey();
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = _filter.query;
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _exploreKey.currentContext;
        if (!mounted || target == null) return;
        Scrollable.ensureVisible(
          target,
          duration: handMotionOff(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  /// "My workouts" is open: her list shows under the row.
  bool _mineOpen = false;

  /// "My workouts": opens her list, or the builder when there is none yet.
  void _openMyWorkouts() {
    if (widget.myWorkouts.isEmpty) {
      widget.onBuildOwn?.call();
      return;
    }
    setState(() => _mineOpen = !_mineOpen);
  }

  List<LibraryExercise> _shownMoves() =>
      widget.exercises.where(_filter.keepMove).toList();

  List<LibraryWorkout> _shownWorkouts() => [
    for (final w in widget.workouts)
      if (AppRouter.featureFlags.isOn(Feature.workoutLibrary) &&
          (widget.workoutIsFilmed?.call(w) ?? true) &&
          _filter.keepWorkout(w))
        w,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final art = ScreenArt.headerFor(ScreenScope.of(context));

    final moves = _shownMoves();
    final workouts = _shownWorkouts();

    final next =
        widget.week.where((d) => d.today).firstOrNull ??
        widget.week.where((d) => !d.done).firstOrNull;

    final top = <Widget>[
      if (art.isNotEmpty) const ScreenArtStrip(),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkerHighlight(
                  drawOn: true,
                  child: Text(l10n.train, style: EditorialType.section),
                ),
                Text(
                  l10n.readyWhenYouAre,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      _TodayCard(
        title: next?.title ?? l10n.startTodaysSession,
        detail: next?.detail ?? '',
        onStart: next?.onTap ?? widget.onContinue,
      ),
      // One row each: the plan (R02 holds its tiers and every way to change
      // it) and her own workouts. Side by side they are one list.
      if (AppRouter.screenIsOn('R02') && widget.onSeeProgram != null)
        AppListItem(
          key: const ValueKey('r01-your-plan'),
          title: l10n.yourPlan,
          subtitle: widget.programTitle ?? '',
          leading: const Icon(
            Icons.event_note_outlined,
            size: 24,
            color: AppColors.primaryDim,
          ),
          trailing: const AppChevron(),
          onTap: widget.onSeeProgram,
        ),
      if (widget.onBuildOwn != null || widget.myWorkouts.isNotEmpty)
        AppListItem(
          key: const ValueKey('r01-open-my-workouts'),
          title: l10n.myWorkouts,
          subtitle: widget.myWorkouts.isEmpty
              ? l10n.buildMyOwnWorkout
              : countLabel(widget.myWorkouts.length),
          leading: const Icon(
            Icons.fitness_center,
            size: 24,
            color: AppColors.primaryDim,
          ),
          trailing: widget.myWorkouts.isEmpty
              ? const AppChevron()
              : Icon(
                  _mineOpen ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.onSurfaceVariant,
                ),
          onTap: _openMyWorkouts,
        ),
      if (_mineOpen && widget.myWorkouts.isNotEmpty)
        Column(
          key: const ValueKey('r01-my-workouts'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final mine in widget.myWorkouts)
              AppListItem(
                key: ValueKey('r01-mine-${mine.id}'),
                title: mine.name.isEmpty ? l10n.myWorkout : mine.name,
                subtitle: l10n.minutesMinutesMovesMoves(
                  countLabel(estimateMinutesOf(mine.moves)),
                  countLabel(mine.moves.length),
                ),
                leading: const Icon(
                  Icons.fitness_center,
                  size: 24,
                  color: AppColors.primaryDim,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('r01-mine-edit-${mine.id}'),
                      tooltip: l10n.edit,
                      onPressed: () => widget.onEditMine?.call(mine),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: ValueKey('r01-mine-delete-${mine.id}'),
                      tooltip: l10n.deleteThisWorkout,
                      onPressed: () => widget.onDeleteMine?.call(mine),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                onTap: () => widget.onStartMine?.call(mine),
              ),
            if (widget.onBuildOwn != null)
              AppButton(
                l10n.buildMyOwnWorkout,
                key: const ValueKey('r01-build-own'),
                icon: Icons.add,
                variant: AppButtonVariant.text,
                height: 48,
                fontSize: 15,
                onPressed: widget.onBuildOwn,
              ),
          ],
        ),
      const HandRule(seed: 41, height: 14),
      Semantics(
        header: true,
        child: Text(l10n.explore, key: _exploreKey, style: AppText.headline),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AppField(
              controller: _search,
              hint: l10n.search,
              onChanged: (value) {
                _filter.query = value;
                _changed();
              },
              trailing: const Icon(
                Icons.search,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The one Filters button: what she trains, where, with what, and
          // how gentle, in one sheet that keeps the count of what it leaves.
          AppChip(
            l10n.filters,
            key: const ValueKey('r01-filters'),
            icon: Icons.tune,
            selected: _filter.narrowsBySheet,
            onTap: () => showExploreFilters(
              context,
              filter: _filter,
              exercises: widget.exercises,
              onChanged: _changed,
              workouts: widget.workouts,
              matchCount: () => _shownMoves().length + _shownWorkouts().length,
            ),
          ),
        ],
      ),
      if (widget.hiddenFor != null)
        AppSageNote(
          widget.hiddenFor == LifeStage.pregnant
              ? l10n.someMovesAreHiddenWhileYouAre
              : l10n.someMovesAreHiddenInTheWeeks,
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'R01',
        onSelect: widget.onSelectTab,
      ),
      body: PaperPage(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: kBodyPadding,
              // Lazy below the controls: the moves are built as she scrolls,
              // and every move asks for its poster.
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < top.length; i++) ...[
                          if (i > 0) const SizedBox(height: kStackGap),
                          StaggerIn(index: i, group: 'r01', child: top[i]),
                        ],
                      ],
                    ),
                  ),
                  ...exploreResultSlivers(
                    context,
                    workouts: workouts,
                    moves: moves,
                    media: widget.media,
                    filtered: _filter.isActive,
                    onOpenWorkout: widget.onOpenWorkout,
                    onOpenMove: widget.onOpenExercise,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The session she does today, with the one Start button on the page.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.title,
    required this.detail,
    required this.onStart,
  });

  final String title;
  final String detail;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      variant: AppCardVariant.tonal,
      gap: 8,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      children: [
        Text(
          l10n.today,
          style: AppText.label.copyWith(color: AppColors.onPrimaryContainer),
        ),
        Text(
          title,
          style: AppText.headline.copyWith(color: AppColors.onPrimaryContainer),
        ),
        if (detail.isNotEmpty)
          Text(
            detail,
            style: AppText.bodyM.copyWith(color: AppColors.onPrimaryContainer),
          ),
        const SizedBox(height: 4),
        AppButton(
          // "Continue · from Sara" credits a coach. In a build with no
          // coaching nobody wrote this programme for her, so the button says
          // what it does. The credit comes back with the feature.
          AppRouter.featureFlags.isOn(Feature.coachedLife)
              ? l10n.continueFromSara
              : l10n.start,
          icon: Icons.play_arrow,
          onPressed: onStart,
        ),
      ],
    );
  }
}
