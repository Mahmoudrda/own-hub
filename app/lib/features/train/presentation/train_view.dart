/// R01 — Train.
///
/// Matches `6-v2/src/screens-train.mjs` → `R01`, then redrawn as the one place
/// she trains and looks for something to train. Top to bottom: the section's
/// name set large with her week drawn as marks, a Today card with one Start
/// button, this week's sessions as a short timeline with the next one tagged,
/// and Explore, which is every workout and every filmed move behind a search
/// box, one row of chips and a Filters sheet.
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
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';
import '../../../ui/screen_scope.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import '../domain/train_repository.dart';
import 'program_view.dart' show ProgramDay;
import 'train_explore.dart';
import 'train_widgets.dart';

/// One of the three short sessions offered above the library.
class ShortSession {
  const ShortSession({
    required this.duration,
    required this.constraint,
    this.onTap,
  });

  /// "10 min".
  final String duration;

  /// What makes it possible today — "Floor only", "Quiet".
  final String constraint;

  final VoidCallback? onTap;
}

class TrainView extends StatefulWidget {
  const TrainView({
    super.key,
    this.onContinue,
    this.onSeeProgram,
    this.onOpenToday,
    this.onGentlerOption,
    this.showGentlerOption = true,
    this.onFollowAlong,
    this.onShortSession,
    this.onOpenMuscles,
    this.onSelectTab,
    this.onOpenWorkout,
    this.onOpenExercise,
    this.shortSessions,
    this.programTitle,
    this.programWeek,
    this.sessionsThisWeek = 0,
    this.sessionsPrescribed = 3,
    this.week = const <ProgramDay>[],
    this.workouts = const <LibraryWorkout>[],
    this.exercises = const <LibraryExercise>[],
    this.hiddenFor,
    this.media = const NoExerciseMedia(),
    this.focus,
    this.workoutIsFilmed,
    this.tierTabs,
  });

  /// The Beginner / Intermediate / Advanced tabs, above Today's card.
  final Widget? tierTabs;

  /// See OQ-12 above. The router owns where this goes.
  final VoidCallback? onContinue;

  final VoidCallback? onSeeProgram;

  /// Where the week strip's "Today" chip went. Kept because the router and
  /// the tests pass it; Home is one tap away on the bar below either way.
  final VoidCallback? onOpenToday;

  final VoidCallback? onGentlerOption;

  /// False when the library has no swap for the move she is on: the row is
  /// not drawn rather than opening an empty sheet.
  final bool showGentlerOption;

  /// The timed follow-along short session — `R06`.
  ///
  /// The design puts this on the FIRST of the three "Short ones that still
  /// count" tiles, and only that one: a follow-along logs itself as the timer
  /// runs out, which is why R06's own note reads "0 taps to log". The other two
  /// are ordinary sessions and open the workout day.
  final VoidCallback? onFollowAlong;

  /// The other short sessions — an ordinary workout day, `R03`.
  final VoidCallback? onShortSession;

  /// Her muscles on a body she can turn (`P06`).
  final VoidCallback? onOpenMuscles;

  final ValueChanged<String>? onSelectTab;

  /// A workout from Explore (`R03`).
  final ValueChanged<LibraryWorkout>? onOpenWorkout;

  /// A move from Explore (`R15`).
  final ValueChanged<LibraryExercise>? onOpenExercise;

  /// Injectable so the real library can supply these later.
  final List<ShortSession>? shortSessions;

  final String? programTitle;
  final String? programWeek;

  final int sessionsThisWeek;
  final int sessionsPrescribed;

  /// This week's sessions in order. Empty draws no timeline and a Today card
  /// that carries on with whatever she was in.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final art = ScreenArt.headerFor(ScreenScope.of(context));

    final shorts =
        widget.shortSessions ??
        [
          // The follow-along tile, only while follow-along is on.
          if (AppRouter.screenIsOn('R06'))
            ShortSession(
              duration: l10n.n10Min,
              constraint: l10n.floorOnly,
              onTap: widget.onFollowAlong,
            ),
          ShortSession(
            duration: l10n.n15Min,
            constraint: l10n.quiet,
            onTap: widget.onShortSession,
          ),
          ShortSession(
            duration: l10n.n20Min,
            constraint: l10n.dumbbells,
            onTap: widget.onShortSession,
          ),
        ];

    final moves = widget.exercises.where(_filter.keepMove).toList();
    final workouts = [
      for (final w in widget.workouts)
        if (AppRouter.featureFlags.isOn(Feature.workoutLibrary) &&
            (widget.workoutIsFilmed?.call(w) ?? true) &&
            _filter.keepWorkout(w))
          w,
    ];

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
          const Kitten(
            pose: KittenPose.lift,
            prop: KittenProp.dumbbell,
            size: 40,
            moment: 'R01',
            holdStill: true,
            blinkOnRevisit: true,
          ),
        ],
      ),
      _WeekStrip(
        title: widget.programWeek ?? l10n.thisWeek,
        programTitle: widget.programTitle,
        done: widget.sessionsThisWeek,
        total: widget.sessionsPrescribed,
      ),
      ?widget.tierTabs,
      _TodayCard(
        title: next?.title ?? l10n.startTodaysSession,
        detail: next?.detail ?? '',
        onStart: next?.onTap ?? widget.onContinue,
      ),
      if (widget.week.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final day in widget.week)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: MoveRow(
                  name: day.title,
                  detail: day.detail,
                  done: day.done,
                  current: identical(day, next),
                  note: identical(day, next) ? l10n.upNext : null,
                  onTap: day.onTap,
                ),
              ),
          ],
        ),
      if (AppRouter.screenIsOn('R02'))
        AppButton(
          l10n.seeTheWholeProgram,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: widget.onSeeProgram,
        ),
      if (shorts.isNotEmpty)
        Text(l10n.shortOnesThatStillCount, style: AppText.titleM),
      if (shorts.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final session in shorts)
              AppChip(
                '${session.duration} · ${session.constraint}',
                onTap: session.onTap,
              ),
          ],
        ),
      if (AppRouter.screenIsOn('P06') && widget.onOpenMuscles != null)
        AppListItem(
          key: const ValueKey('r01-muscles'),
          title: l10n.yourMuscles,
          subtitle: l10n.whatYouTrainedOnABodyMap,
          leading: const Icon(
            Icons.accessibility_new,
            size: 24,
            color: AppColors.primaryDim,
          ),
          trailing: const AppChevron(),
          onTap: widget.onOpenMuscles,
        ),
      if (AppRouter.screenIsOn('R05') && widget.showGentlerOption)
        AppListItem(
          title: l10n.notFeelingItToday,
          subtitle: l10n.seeAGentlerOptionBasedOnYour,
          leading: const Icon(
            Icons.self_improvement,
            size: 24,
            color: AppColors.primaryDim,
          ),
          trailing: const AppChevron(),
          onTap: widget.onGentlerOption,
        ),
      const HandRule(seed: 41, height: 14),
      Semantics(
        header: true,
        child: Text(l10n.explore, key: _exploreKey, style: AppText.headline),
      ),
      AppField(
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
      ExploreChips(
        filter: _filter,
        onChanged: _changed,
        showFilters: exploreHasSheet(widget.exercises),
        onOpenFilters: () => showExploreFilters(
          context,
          filter: _filter,
          exercises: widget.exercises,
          onChanged: _changed,
        ),
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

/// Her week as marks, one circle for each session it asks for, ticked as they
/// are logged. A count beside them, so she is never left to count circles.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.title,
    required this.programTitle,
    required this.done,
    required this.total,
  });

  final String title;
  final String? programTitle;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Her programme, or nothing: no title is invented for her.
              if (programTitle != null)
                Text(
                  programTitle!,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              Text(title, style: AppText.titleL),
              Text(
                l10n.countOfTotal(countLabel(done), countLabel(total)),
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 136,
          child: AppWeekSegments(
            total: total,
            filled: done,
            style: WeekStyle.marks,
          ),
        ),
      ],
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
