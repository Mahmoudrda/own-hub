/// The tour's seven stops: which real screen each one is, what the coach card
/// says about it, and where each of its controls goes.
///
/// Every stop is the product's own widget, given the sample and wired here.
/// A control either moves the tour to another stop or opens the join sheet.
/// Nothing is wired to a route: a control left unwired falls through to
/// `AppRouter.goTo`, which `DemoScope` turns into the join sheet as well.
///
/// The coach cards name only what renders with the shipping flags. The
/// community, coaches, the assistant and video are not mentioned, because
/// none of them is on.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_scaffold.dart';

import '../../../eat/data/seeded_recipe_library.dart';
import '../../../eat/domain/allergy_guard.dart';
import '../../../eat/domain/recipe.dart';
import '../../../eat/presentation/recipes_view.dart';
import '../../../eat/presentation/week_plan_view.dart';
import '../../../../domain/format/day_key.dart';
import '../../../../domain/format/number_label.dart';
import '../../../progress/presentation/you_view.dart';
import '../../../train/presentation/move_history_sheet.dart'
    show sessionDateLabel;
import '../../../today/presentation/today_view.dart';
import '../../../train/presentation/mid_set_view.dart';
import '../../../train/presentation/workout_day_view.dart';
import '../../demo/demo_sample.dart';

/// The stops, in order. The end card comes after the last.
enum DemoStop {
  home('T01'),
  workoutDay('R03'),
  player('R07'),
  recipes('E05'),
  weekPlan('E07'),
  cycle('Y03'),
  progress('P01');

  const DemoStop(this.screenId);

  /// The real screen this stop draws. Given to `ScreenScope`, so the screen
  /// carries its own illustrations.
  final String screenId;

  String title(AppL10n l10n) => switch (this) {
    DemoStop.home => l10n.homeYourDayAtAGlance,
    DemoStop.workoutDay => l10n.todaysWorkout,
    DemoStop.player => l10n.duringAWorkout,
    DemoStop.recipes => l10n.rahmasRecipes,
    DemoStop.weekPlan => l10n.yourWeekOfDinners,
    DemoStop.cycle => l10n.yourDayAsYouFeelIt,
    DemoStop.progress => l10n.yourProgress,
  };

  String line(AppL10n l10n) => switch (this) {
    DemoStop.home => l10n.ownHubIsAFitnessAppFor_loijw,
    DemoStop.workoutDay => l10n.quietSessionsYouCanDoAtHome,
    DemoStop.player => l10n.oneMoveAtATimeTapWhen,
    DemoStop.recipes => l10n.homeCookingYouAlreadyKnowWrittenBy,
    DemoStop.weekPlan => l10n.aWeekOfDinnersPlannedForYou,
    DemoStop.cycle => l10n.sayHowYouFeelTodayOnHarder,
    DemoStop.progress => l10n.yourWeeksYourPersonalBestsAndYour,
  };
}

/// The one recipe the tour opens in full: the first card of Rahma's book, as
/// E05 lists it.
Recipe? firstBookRecipe(RecipeBook? book) {
  if (book == null) return null;
  for (final section in book.sections) {
    final recipes = book.inSection(section.sectionId);
    if (recipes.isNotEmpty) return recipes.first;
  }
  return null;
}

/// Rahma's book as the tour shows it. Her verbatim PS under a section can name
/// the period; before sign-in the cycle is not named, so that one line is left
/// off here. The book itself, and the same section after sign-in, are not
/// touched.
RecipeBook? beforeSignInBook(RecipeBook? book) {
  if (book == null) return null;
  final names = RegExp(r'\b(cycles?|periods?)\b', caseSensitive: false);
  if (!book.sections.any((s) => names.hasMatch(s.psLineEn))) return book;
  return RecipeBook(
    schemaVersion: book.schemaVersion,
    contentVersion: book.contentVersion,
    sections: [
      for (final s in book.sections)
        names.hasMatch(s.psLineEn)
            ? RecipeSection(
                sectionId: s.sectionId,
                titleEn: s.titleEn,
                titleAr: s.titleAr,
                psLineEn: '',
                psLineAr: s.psLineAr,
                order: s.order,
                markKey: s.markKey,
              )
            : s,
    ],
    recipes: book.recipes,
    assemblies: book.assemblies,
    letterAr: book.letterAr,
  );
}

/// What a stop needs from the tour.
class DemoWiring {
  const DemoWiring({
    required this.sample,
    required this.show,
    required this.join,
    required this.openRecipe,
  });

  final DemoSample sample;

  /// Moves the tour to another stop.
  final ValueChanged<DemoStop> show;

  /// Opens the join sheet.
  final VoidCallback join;

  /// Opens the first of Rahma's recipes, or the join sheet for any other.
  final ValueChanged<String> openRecipe;

  /// The bottom bar, as the tour reads it: Home, Train, Eat and You are
  /// stops, and anything else is a door she joins to open.
  void tab(String screenId) => switch (screenId) {
    'T01' => show(DemoStop.home),
    'R01' => show(DemoStop.workoutDay),
    'E01' => show(DemoStop.recipes),
    'P01' => show(DemoStop.progress),
    _ => join(),
  };
}

/// The real screen for [stop], wired to the tour.
Widget buildDemoStop(BuildContext context, DemoStop stop, DemoWiring w) {
  final l10n = AppL10n.of(context);
  final sample = w.sample;
  final day = sampleWorkoutDay(l10n, now: sample.now);
  final join = w.join;

  return switch (stop) {
    DemoStop.home => TodayView(
      repository: sample.today,
      bus: sample.bus,
      sessionTitle: day.title,
      onStartSession: () => w.show(DemoStop.workoutDay),
      onRecall: join,
      onOpenMeal: join,
      // Joining is asked for, never the real plan editor or Train.
      onEditToday: join,
      onChangePlan: join,
      onShortVersion: join,
      onOpenWeek: () => w.show(DemoStop.progress),
      onOpenCycle: () => w.show(DemoStop.cycle),
      onAsk: join,
      onNotifications: join,
      onOpenFirstWeek: join,
      onTellUsWhatYouEat: join,
      onOpenBeginnersGroup: join,
      onOpenWeekPlan: () => w.show(DemoStop.weekPlan),
      onTrackCycle: join,
      onNotNowCycle: join,
      // The walk row stays as it was: the sample counts nothing.
      onCountWalk: join,
      onSelectTab: w.tab,
    ),
    DemoStop.workoutDay => WorkoutDayView(
      day: day,
      repository: sample.train,
      onBack: () => w.show(DemoStop.home),
      // Never reached: the sample refuses to start a session, and the
      // refusal opens the join sheet.
      onStart: join,
      onOpenMove: (_) => join(),
      onNotToday: join,
      onMore: join,
    ),
    DemoStop.player => MidSetView(
      move: day.moves.first,
      setIndex: 0,
      moveNumber: 1,
      moveCount: day.moves.length,
      sessionId: 'sample',
      repository: sample.train,
      bus: sample.bus,
      onClose: () => w.show(DemoStop.workoutDay),
      onPause: join,
      onChange: join,
      // Taken back before anything else, so nothing reads as logged.
      onSetLogged: (handle) {
        handle.undo();
        join();
      },
      onMoveLogged: (handle) {
        handle.undo();
        join();
      },
    ),
    DemoStop.recipes => RecipesView(
      book: beforeSignInBook(sample.book),
      // The sample woman was asked and avoids nothing, so the book is open
      // and its "nothing here has been checked" line is shown, exactly as it
      // is to a real woman who gave that answer. Asking the tour's visitor
      // about her allergies would be asking for health data before she has
      // agreed to anything.
      constraints: DietaryConstraints.none,
      asked: true,
      onSearch: join,
      onOpenRecipe: w.openRecipe,
      onOpenWeekPlan: () => w.show(DemoStop.weekPlan),
      onOpenLetter: join,
      onAnswerAllergies: join,
      onSelectTab: w.tab,
    ),
    DemoStop.weekPlan => WeekPlanView(
      repository: sample.meal,
      now: sample.now,
      // Not "built from recipes you have logged before": she has logged
      // nothing, and these five are the sample's.
      lead: l10n.aSampleWeekOfFiveDinnersJoin,
      onBack: () => w.show(DemoStop.recipes),
      onRegenerate: join,
      onOpenRecipe: w.openRecipe,
      onOpenGroceryList: join,
    ),
    DemoStop.cycle => CheckInStopView(
      onBack: () => w.show(DemoStop.weekPlan),
      onJoin: join,
    ),
    // P01 is You, the last tab. Its figures and its sessions are the sample's:
    // one session this week, and the earlier ones the progress counts. Every
    // door in it is the join sheet.
    DemoStop.progress => YouView(
      summary: sample.progress,
      minutesThisWeek:
          DemoSample.sessionMinutes * sample.progress.sessionsThisWeek,
      activities: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: kStackGap,
        children: [
          for (final ago in DemoSample.sessionDaysAgo)
            AppListItem(
              key: ValueKey('demo-session-$ago'),
              title: day.title,
              subtitle:
                  '${sessionDateLabel(l10n, dayKey(sample.now.subtract(Duration(days: ago))))} · '
                  '${l10n.nMin(countLabel(DemoSample.sessionMinutes))}',
              leading: const Icon(
                Icons.history,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: join,
            ),
        ],
      ),
      onOpenSettings: join,
      onOpenInsights: join,
      onSelectTab: w.tab,
    ),
  };
}

/// The tour's check-in stop. Before she signs in the cycle is not named, so
/// this is the daily check-in on its own: "How are you feeling?" and the
/// gentler plan it can lead to. The real Y03 is a cycle screen and opens only
/// after sign-in. Nothing here is wired to anything but the join sheet.
class CheckInStopView extends StatelessWidget {
  const CheckInStopView({
    super.key,
    required this.onBack,
    required this.onJoin,
  });

  final VoidCallback onBack;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.howYouFeelToday, onBack: onBack),
      body: AppScaffold(
        children: [
          AppButton(
            l10n.howAreYouFeeling,
            height: 48,
            icon: Icons.mood,
            onPressed: onJoin,
          ),
          AppCard(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.aGentlerOptionToday, style: AppText.titleM),
                  AppPill(
                    l10n.appSuggestion,
                    background: AppColors.surfaceContainer,
                    foreground: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
              Text(
                l10n.lowOnEnergyALighterVersionOf,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    l10n.viewOption,
                    variant: AppButtonVariant.tonal,
                    height: 44,
                    fontSize: 15,
                    onPressed: onJoin,
                  ),
                  AppButton(
                    l10n.keepMine,
                    variant: AppButtonVariant.outlined,
                    height: 44,
                    fontSize: 15,
                    onPressed: onJoin,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
