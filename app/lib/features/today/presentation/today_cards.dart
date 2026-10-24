/// The pieces T01, T02, T04 and T05 share.
///
/// `6-v2/src/screens-today.mjs` defines `greeting`, `workoutCard`, `mealCard`
/// and `weekCard` as local helpers at the top of the file and then reuses them
/// across five screens. They are widgets here for the same reason they are
/// helpers there: T02 and T05 draw the same Today underneath their sheets, and
/// two copies of the workout card would drift apart.
///
/// They live in the feature rather than in `lib/ui/` because they are Today's
/// content, not reusable shapes — the shapes they are built from ([AppCard],
/// [AppPill], [AppSplitRow], [AppWeekSegments]) are the reusable part.
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/format/number_label.dart';
import '../../eat/domain/daily_targets.dart';
import '../../eat/domain/day_totals.dart';
import '../../eat/domain/meal_images.dart';
import '../../eat/domain/meal_repository.dart' show MealSlot;
import '../../eat/presentation/eat_day_view_model.dart' show EatDayViewModel;
import '../../eat/presentation/eat_sample_library.dart' show eatSampleLibrary;
import '../domain/today_day.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chevron.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/app_week_segments.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/meal_image.dart';

/// Opens another screen by id.
///
/// [override] wins when the router owner has wired a callback; otherwise this
/// navigates by screen id through the generated route table. Screens that are
/// not built yet land on the router's "not built yet" page, which is the point —
/// an action that goes nowhere at all would hide the gap.
void openScreen(
  BuildContext context,
  String screenId, [
  VoidCallback? override,
]) {
  if (override != null) {
    override();
    return;
  }
  AppRouter.goTo(context, screenId);
}

/// Where each step of her first week leads.
///
/// The map is the arc's edge list, and it lives here rather than in
/// `first_week_view.dart` because T01 counts the same arc T07 draws: "2 of 5"
/// on Home and five rows on the arc have to be the same five.
const Map<FirstWeekStep, String> firstWeekStepScreens = {
  FirstWeekStep.logSet: 'R07',
  FirstWeekStep.logMeal: 'E02',
  FirstWeekStep.finishSession: 'R03',
  FirstWeekStep.joinGroup: 'M04',
  FirstWeekStep.followUp: 'M11',
};

/// Her first week, minus any step this build cannot offer.
///
/// Two of the five belong to Community, and the first release ships without
/// it. `DECISIONS.md` D1 refused to *cut* those steps — they are written, they
/// are translated and they come back the day Community is on — but an arc that
/// asks her to join a group in a build with no groups is a week she cannot
/// finish, so a dark step is not drawn and, just as importantly, is not
/// counted. The domain stays flag-free (`today_day.dart` knows five steps and
/// nothing about switches); the decision is made here, where every other
/// rendering decision about a feature is made.
List<FirstWeekStep> offeredFirstWeekSteps() => [
  for (final entry in firstWeekStepScreens.entries)
    if (AppRouter.screenIsOn(entry.value)) entry.key,
];

/// How many of the steps she is actually offered are done.
///
/// Never `arc.doneCount`: that counts every step she has completed, including
/// one belonging to a feature since switched off, which would show four of
/// three.
int firstWeekDone(FirstWeekArc arc) =>
    offeredFirstWeekSteps().where(arc.completed.contains).length;

/// True when nothing is left of the arc this build offers.
///
/// This, not [FirstWeekArc.isComplete], is what decides whether T08 renders.
/// With Community dark, `isComplete` can never be true, so the finished screen
/// would be unreachable to every woman in the first release — exactly the
/// outcome D1 was written to prevent, arriving from the other direction.
bool firstWeekIsComplete(FirstWeekArc arc) {
  final offered = offeredFirstWeekSteps();
  return offered.isNotEmpty && offered.every(arc.completed.contains);
}

/// The day's name, from the date rather than from a hardcoded Tuesday.
///
/// All seven are set in full. Saturday and Sunday used to fall back to the
/// abbreviations `sat` and `sun`, which were the only keys the dictionary held
/// for them — so Home's masthead said "Tuesday" on five days of the week and
/// "Sat" on the sixth. `saturday` and `sunday` are now in both languages, so
/// the exception is gone rather than flagged. The short forms stay where they
/// belong: a calendar grid and a day strip, where the full name would not fit.
String weekdayLabel(AppL10n l10n, DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return l10n.monday;
    case DateTime.tuesday:
      return l10n.tuesday;
    case DateTime.wednesday:
      return l10n.wednesday;
    case DateTime.thursday:
      return l10n.thursday;
    case DateTime.friday:
      return l10n.friday;
    case DateTime.saturday:
      return l10n.saturday;
    default:
      return l10n.sunday;
  }
}

/// A clock time, in her locale's own convention.
///
/// The prototype prints "8:40". There is no dictionary key for it and there
/// should not be — a time is formatted, not translated — so it goes through
/// [MaterialLocalizations], which respects both the locale and her 24-hour
/// setting.
String timeLabel(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(at));

/// A plate's name in her language, from the food id the day carries.
///
/// The same shape as `groceryLabel` in the Eat feature and for the same reason:
/// the food pack is bundled content resolved through `AppL10n` by the view,
/// while the *figure* beside it is data. An id with no name yet renders the id,
/// which is visible and wrong-looking rather than quietly mislabelled.
String plateName(AppL10n l10n, String foodId) => switch (foodId) {
  'ful_baladi' => l10n.fulAndBaladi,
  'eggs_and_tea' => l10n.eggsAndTea,
  'koshari_bowl' => l10n.koshariBowl,
  'boiled_eggs' => l10n.boiledEggs,
  'molokhia_chicken' => l10n.molokhiaWithChicken,
  // The rest of the pack `eat_sample_library.dart` names. Home lists the
  // plates she has actually logged, so any food in the pack can arrive here —
  // and the three missing ids rendered as `lentil_soup_eggs` on the card.
  'lentil_soup_eggs' => l10n.lentilSoupAndEggs,
  'chicken_and_rice' => l10n.chickenAndRice,
  'koshari_and_salad' => l10n.koshariBowlAndSalad,
  _ => eatSampleLibrary(l10n).byId(foodId)?.names.first ?? foodId,
};

/// What to head Today's meal section with.
///
/// It was the fixed `breakfastYourUsual` — "Breakfast, your usual" — for every
/// hour of every day, so a woman who logged a koshari bowl at one in the
/// afternoon read "Breakfast, your usual" with her koshari underneath it. Same
/// class as the week badge and the cover title: a line about her that is not
/// true of her, on the first screen she sees.
///
/// The hour is turned into a meal by [EatDayViewModel.slotAt] rather than by
/// boundaries written again here, so Home and Eat can never disagree about
/// which meal five in the afternoon is.
///
/// Two headings, not one. Before she has logged, the card is a **guess** about
/// the hour she is in and says so ("your usual"); once something is logged it
/// names the meal plainly, because the time it happened is already printed at
/// the other end of the same line.
String mealSlotName(AppL10n l10n, MealSlot slot) => switch (slot) {
  MealSlot.breakfast => l10n.breakfast,
  MealSlot.lunch => l10n.lunch,
  MealSlot.dinner => l10n.dinner,
  MealSlot.snack => l10n.snack,
};

String mealHeading(
  AppL10n l10n, {
  DateTime? loggedAt,
  DateTime? now,
  bool hasUsual = false,
}) {
  final slot = EatDayViewModel.slotAt(loggedAt ?? now ?? AppClock.now());
  if (loggedAt != null) return mealSlotName(l10n, slot);
  // "Your usual" is a claim about a habit, and a woman on a fresh install has
  // none: T01, T02 and E04 all headed the card "Lunch, your usual" over an
  // empty card before she had logged a single meal. The slot logic was always
  // right; the habit sentence is what had to earn itself.
  if (!hasUsual) return mealSlotName(l10n, slot);
  return switch (slot) {
    MealSlot.breakfast => l10n.breakfastYourUsual,
    MealSlot.lunch => l10n.lunchYourUsual,
    MealSlot.dinner => l10n.dinnerYourUsual,
    MealSlot.snack => l10n.snackYourUsual,
  };
}

/// What to head T03's notification with.
///
/// The same slot logic as [mealHeading], asking, because a notification is a
/// question and the button under it answers yes. T03 had the fixed
/// "Breakfast, your usual?" — the sixth screen found carrying this defect,
/// after T01, T02 and E04 were fixed and this one was missed — so the nudge
/// that fires at the hour she usually logs said breakfast at six in the
/// evening.
///
/// [hasUsual] is false when the caller has not named a meal. The nudge only
/// fires for a meal she has had three times or more, so in the product it is
/// always true here; a review surface opened with nothing gets the plain slot
/// name rather than a habit she has not shown.
String mealNudgeHeading(AppL10n l10n, {DateTime? now, bool hasUsual = false}) {
  final slot = EatDayViewModel.slotAt(now ?? AppClock.now());
  if (!hasUsual) return mealSlotName(l10n, slot);
  return switch (slot) {
    MealSlot.breakfast => l10n.breakfastYourUsual_1lb0u,
    MealSlot.lunch => l10n.lunchYourUsual_1wxfd,
    MealSlot.dinner => l10n.dinnerYourUsual_1rqgs,
    MealSlot.snack => l10n.snackYourUsual_nkmpd,
  };
}

/// The head of Today: the day and the tools at its edge. Her level is on
/// Progress.
class TodayGreeting extends StatelessWidget {
  const TodayGreeting({super.key, required this.day, this.actions = const []});

  final String day;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // A masthead, not a greeting: the day set small as the issue line, the
    // tools at the far edge, and a pencil
    // rule under all of it. The page's subject starts below the rule.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSplitRow(
          start: Text(day, style: EditorialType.folio),
          end: Row(mainAxisSize: MainAxisSize.min, children: [...actions]),
        ),
        HandRule(seed: day.hashCode, height: 8),
      ],
    );
  }
}

/// Today's session, with everything already filled in.
class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    this.title,
    this.onStart,
    this.onRecall,
    this.evening = false,
    this.week,
    this.totalWeeks,
    this.summary,
    this.weekBlock,
    this.done = false,
  });

  /// Today's session is already logged. Home said "Start, everything's ready"
  /// for the rest of the day after she had trained, and never anything else:
  /// the card now says it is done, with a sage tick, and offers another
  /// session as a quiet text action rather than as the page's main button.
  final bool done;

  /// What today's session is called, when her plan has said.
  ///
  /// This was the fixed `l10n.legsAndGlutes`, set as the page's cover — so the
  /// first screen of the app named a programme to every woman who opened it,
  /// while Train one tap away named a different one ("Postpartum rebuild") and
  /// neither was hers. The cover is the page's subject and cannot simply be
  /// withdrawn the way the week badge and [summary] are, so null falls back to
  /// naming the thing itself rather than naming a programme nobody chose.
  final String? title;

  /// Her week, set between the session and the action on Today's cover.
  /// Null on the screens that draw Today underneath a sheet.
  final Widget? weekBlock;

  final VoidCallback? onStart;
  final VoidCallback? onRecall;

  /// Her place in the programme. Both null renders **no badge**.
  ///
  /// The badge was the fixed `week3Of8`, so Home said "Week 3 of 8" to a woman
  /// on her first day. `train_view.dart` had already withdrawn the identical
  /// fallback — "it stated Week 3 of 8 precisely when the real week was
  /// unknown" — and Home went on stating it, so the two screens disagreed.
  final int? week;
  final int? totalWeeks;

  /// What today's session is, in one line, when the plan has said.
  ///
  /// Null renders nothing. This was `n15Min5MovesQuietNoEquipment` — "15 min ·
  /// 5 moves · quiet, no equipment, last week's weights" — four claims about a
  /// session this card is handed nothing about: its length, its move count, its
  /// equipment, and that its weights come from a week she may not have trained.
  final String? summary;

  /// After 20:00, an unlogged session is far likelier to have already happened
  /// than to be about to. So the two buttons swap weight.
  ///
  /// This is a **rendering of the same state**, not a state of its own — the day
  /// has not changed, only the likelier answer — which is what stops it drifting
  /// out of step with what the resolver decided (plan G3 §3.1).
  final bool evening;

  @override
  Widget build(BuildContext context) {
    final body = KeyedSubtree(
      key: ValueKey((done, evening)),
      child: _body(context),
    );
    // Reduce Motion: the card is replaced, with no size ease to run.
    return handMotionOff(context) ? body : HandSwap(child: body);
  }

  Widget _body(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (done) return _done(context, l10n);

    // "I already did it" is drawn only while recording from memory is on;
    // with it off the card is one button, the start.
    final recall = onRecall;
    final primary = evening && recall != null
        ? AppButton(
            l10n.iAlreadyDidIt,
            height: 56,
            icon: Icons.check,
            onPressed: recall,
          )
        : AppButton(
            l10n.startEverythingsReady,
            height: 56,
            icon: Icons.play_arrow,
            onPressed: onStart,
          );
    final secondary = recall == null
        ? null
        : evening
        ? AppButton(
            l10n.startEverythingsReady,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: onStart,
          )
        : AppButton(
            l10n.iAlreadyDidIt,
            variant: AppButtonVariant.text,
            height: 40,
            onPressed: recall,
          );

    // The cover. Not a card: the session is the page's subject, so it is set
    // on the page itself — large, underlined once by hand — with her week
    // beneath it and one pencil arrow down to the thing to do.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: HandUnderline(
            level: HandLevel.signature,
            width: HandStroke.felt,
            drawOn: true,
            gap: 4,
            child: Text(
              title ?? l10n.todaysWorkout,
              style: EditorialType.cover,
            ),
          ),
        ),
        if (week != null && totalWeeks != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: HandCircled(
                level: HandLevel.crafted,
                width: 1.2,
                color: AppColors.primaryDim,
                child: Text(
                  l10n.weekWeekOfTotal(
                    countLabel(week!),
                    countLabel(totalWeeks!),
                  ),
                  style: AppText.label.copyWith(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 10),
          Text(
            summary!,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
        if (weekBlock != null) ...[const SizedBox(height: 22), weekBlock!],
        // One arrow, pointing at the action — nothing else on the page points.
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 22, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const HandArrow(
                width: 70,
                height: 40,
                from: Offset(0.1, 0.02),
                to: Offset(0.62, 0.95),
                bend: 0.38,
                seed: 5,
                drawOn: true,
                delay: Duration(milliseconds: 520),
              ),
              const SizedBox(width: 6),
              // The one word written on the cover, beside the arrow it
              // explains. The button says the rest in print.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HandNote(l10n.upNext, size: 17, decorative: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        primary,
        if (secondary != null) ...[const SizedBox(height: 10), secondary],
      ],
    );
  }

  /// The cover once today's session is logged: what is true, in sage, and
  /// the week under it. No filled button — the page's main job is done.
  Widget _done(BuildContext context, AppL10n l10n) => Column(
    key: const ValueKey('today-done'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(l10n.todaysSessionIsDone, style: EditorialType.cover),
          ),
          const SizedBox(width: 10),
          const HandTick(size: 40, seed: 17),
        ],
      ),
      if (weekBlock != null) ...[const SizedBox(height: 22), weekBlock!],
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: AppButton(
          l10n.anotherSession,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onStart,
        ),
      ),
    ],
  );
}

/// One plate of a meal — the size she actually serves, never grams.
class MealPlate extends StatelessWidget {
  const MealPlate({
    super.key,
    required this.name,
    required this.kcal,
    this.onTap,
  });

  final String name;
  final String kcal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A plate is a line in the day's list — its name, and its figure at the
    // far side — ruled underneath in pencil, not a tile inside a card.
    final line = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: AppSplitRow(
              start: Text(name, style: AppText.titleM.copyWith(fontSize: 16)),
              end: Text(
                kcal,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        HandRule(seed: handSeed(['plate', name]), height: 3),
      ],
    );
    if (onTap == null) return line;
    return HandPressable(onTap: onTap, builder: (_, _) => line);
  }
}

/// The meal she has at this hour, already guessed.
class MealCard extends StatelessWidget {
  const MealCard({
    super.key,
    this.title,
    this.loggedAt,
    this.now,
    this.plates = const <PlateSuggestion>[],
    this.onTap,
    this.onPlateTap,
    this.onPlateLog,
    this.art,
  });

  /// An illustration set in the card's head, on the cover.
  final Widget? art;

  /// Overrides the heading; T04 heads the same card differently. Null lets
  /// [mealHeading] name the meal from the hour.
  final String? title;

  /// The clock, injectable so a test can state the hour it means.
  final DateTime? now;

  /// The plates on offer, each carrying its own figure. Empty renders none.
  ///
  /// The two plates were fixed: `n410Kcal` and `n290Kcal`, the prototype's
  /// breakfast, read to every woman whatever she eats.
  final List<PlateSuggestion> plates;

  final DateTime? loggedAt;
  final VoidCallback? onTap;
  final VoidCallback? onPlateTap;

  /// Logs the plate she tapped. Takes precedence over [onPlateTap], which only
  /// ever navigated — see `TodayView.onLogPlate`.
  final ValueChanged<PlateSuggestion>? onPlateLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final head = Row(
      children: [
        Expanded(
          child: AppSplitRow(
            start: Text(
              title ??
                  mealHeading(
                    l10n,
                    loggedAt: loggedAt,
                    now: now,
                    // She has a usual when there is a plate to name. Empty is a
                    // woman with no history, and the card then names the meal.
                    hasUsual: plates.isNotEmpty,
                  ),
              style: AppText.titleM,
            ),
            end: loggedAt == null
                ? const SizedBox.shrink()
                : Text(
                    timeLabel(context, loggedAt!),
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        if (art != null) ...[const SizedBox(width: 8), art!],
      ],
    );

    // Not a card: the meal is a short section of the page — its heading, and
    // each plate as one ruled line — so nothing below the cover competes
    // with it for weight.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap == null)
          head
        else
          HandPressable(onTap: onTap, builder: (_, _) => head),
        for (final plate in plates)
          MealPlate(
            name: plateName(l10n, plate.foodId),
            kcal: l10n.kcalKcal(countLabel(plate.kcal)),
            onTap: onPlateLog == null ? onPlateTap : () => onPlateLog!(plate),
          ),
      ],
    );
  }
}

/// The week, which is the only unit this product counts in.
class WeekCard extends StatelessWidget {
  const WeekCard({
    super.key,
    required this.title,
    required this.line,
    required this.total,
    required this.filled,
    this.onTap,
    this.open = false,
    this.art,
  });

  /// An illustration set beside the marks on the cover.
  final Widget? art;

  final String title;
  final String line;
  final int total;
  final int filled;
  final VoidCallback? onTap;

  /// Drawn on the page as circled marks rather than as a card of segments —
  /// the form Today's cover uses.
  final bool open;

  @override
  Widget build(BuildContext context) {
    if (open) {
      final lineText = Text(
        line,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      );
      // Six screens hang off this block — P01, P02, P03, P04, T04, T05 and, now
      // that the first-week row is drawn on Home too, T07 — and until this
      // chevron it was a 358×159 point paragraph with nothing at all to say it
      // opened anything: no card, no border, no underline, no button. A woman
      // who never guessed it had a three-screen app. The chevron is the same
      // mark every row in the product uses for "this leads somewhere", at the
      // same size and in the same ink.
      final block = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSplitRow(
            start: Text(title, style: AppText.titleM),
            end: onTap == null
                ? lineText
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: lineText),
                      const SizedBox(width: 4),
                      const AppChevron(),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppWeekSegments(
                  total: total,
                  filled: filled,
                  style: WeekStyle.marks,
                ),
              ),
              ?art,
            ],
          ),
        ],
      );
      if (onTap == null) return block;
      return HandPressable(onTap: onTap, builder: (_, _) => block);
    }

    return AppCard(
      gap: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: onTap,
      children: [
        AppSplitRow(
          start: Text(title, style: AppText.titleM),
          end: Text(
            line,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        AppWeekSegments(total: total, filled: filled),
      ],
    );
  }
}

/// Hello, by the hour, then her name when Home has it.
String homeGreeting(AppL10n l10n, DateTime now, String? firstName) {
  final name = firstName?.trim();
  final named = name != null && name.isNotEmpty;
  if (now.hour < 12) {
    return named ? l10n.goodMorningName(name) : l10n.goodMorning;
  }
  if (now.hour < 17) {
    return named ? l10n.goodAfternoonName(name) : l10n.goodAfternoon;
  }
  return named ? l10n.goodEveningName(name) : l10n.goodEvening;
}

/// The head of Home: the weekday as the small line, the greeting under it,
/// and the tools at the far edge.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    super.key,
    required this.day,
    required this.greeting,
    this.actions = const [],
    this.signIn,
  });

  final String day;
  final String greeting;
  final List<Widget> actions;

  /// The "Sign in or join" pill for a woman with no account. Supplied, the
  /// weekday moves to a line of its own with the pill at the far edge, and the
  /// greeting and the tools sit under it.
  final Widget? signIn;

  @override
  Widget build(BuildContext context) {
    final dayStyle = AppText.label.copyWith(color: AppColors.onSurfaceVariant);
    final greetingText = Text(
      greeting,
      key: const ValueKey('today-greeting'),
      style: EditorialType.section,
    );
    final tools = Row(mainAxisSize: MainAxisSize.min, children: [...actions]);
    final signInPill = signIn;
    if (signInPill != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dayStyle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: signInPill),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: greetingText),
              const SizedBox(width: 8),
              tools,
            ],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(day, style: dayStyle),
              const SizedBox(height: 2),
              greetingText,
            ],
          ),
        ),
        const SizedBox(width: 8),
        tools,
      ],
    );
  }
}

/// The week as seven circles, today boxed. A circle is ticked for a day she
/// trained and is otherwise simply empty: there is no mark for a day she did
/// not, and nothing here adds the days up.
class HomeWeekStrip extends StatelessWidget {
  const HomeWeekStrip({
    super.key,
    required this.today,
    this.doneWeekdays = const <int>{},
    this.caption,
    this.onTap,
  });

  final DateTime today;

  /// One quiet line under the circles, e.g. "This week, 2 of 3".
  final String? caption;

  /// Opens her progress. The strip is not a control when null.
  final VoidCallback? onTap;

  /// `DateTime.weekday` numbers of the days this week she trained.
  final Set<int> doneWeekdays;

  /// Saturday first, the way the week is laid out in Egypt.
  static const List<int> order = [6, 7, 1, 2, 3, 4, 5];

  static String shortName(AppL10n l10n, int weekday) => switch (weekday) {
    DateTime.monday => l10n.mon,
    DateTime.tuesday => l10n.tue,
    DateTime.wednesday => l10n.wed,
    DateTime.thursday => l10n.thu,
    DateTime.friday => l10n.fri,
    DateTime.saturday => l10n.sat,
    _ => l10n.sun,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final days = Row(
      children: [
        for (final weekday in order)
          Expanded(
            child: _DayCircle(
              label: shortName(l10n, weekday),
              done: doneWeekdays.contains(weekday),
              isToday: weekday == today.weekday,
              doneLabel: l10n.done_54ca1,
            ),
          ),
      ],
    );
    final strip = caption == null
        ? days
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              days,
              const SizedBox(height: 4),
              Text(
                caption!,
                textAlign: TextAlign.center,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          );
    if (onTap == null) {
      return KeyedSubtree(
        key: const ValueKey('today-week-strip'),
        child: strip,
      );
    }
    return HandPressable(
      key: const ValueKey('today-week-strip'),
      onTap: onTap,
      builder: (_, _) => strip,
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.label,
    required this.done,
    required this.isToday,
    required this.doneLabel,
  });

  final String label;
  final bool done;
  final bool isToday;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.primaryContainer : Colors.transparent,
        border: Border.all(
          color: done ? AppColors.pinkShade : AppColors.outline,
          width: 1.2,
        ),
      ),
      child: done
          ? const Icon(
              Icons.check,
              size: 18,
              color: AppColors.onPrimaryContainer,
            )
          : null,
    );
    return Semantics(
      label: done ? '$label, $doneLabel' : label,
      excludeSemantics: true,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: isToday
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppText.nav.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              circle,
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's session as the page's one big card: a poster, what it is called,
/// how long it takes, one Start and a quiet "Change". Once it is logged the
/// poster turns sage and the card says so.
class TodayHero extends StatelessWidget {
  const TodayHero({
    super.key,
    this.title,
    this.minutes,
    this.week,
    this.totalWeeks,
    this.art,
    this.onStart,
    this.onChange,
    this.coached = false,
    this.done = false,
  });

  final String? title;
  final int? minutes;
  final int? week;
  final int? totalWeeks;

  /// The poster drawing, set on the pink panel.
  final Widget? art;

  final VoidCallback? onStart;

  /// Opens the Change sheet. No link when null.
  final VoidCallback? onChange;

  /// The card is her coach's workout, not her own plan's.
  final bool coached;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final body = KeyedSubtree(key: ValueKey(done), child: _body(context));
    // Reduce Motion: the card is replaced, with no size ease to run.
    return handMotionOff(context) ? body : HandSwap(child: body);
  }

  Widget _poster({required Color color, required Widget child}) => Container(
    height: 128,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    alignment: Alignment.center,
    child: child,
  );

  Widget _body(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (done) {
      return AppCard(
        key: const ValueKey('today-done'),
        gap: 12,
        children: [
          _poster(
            color: AppColors.tertiaryContainer,
            child: const HandTick(size: 56, seed: 17),
          ),
          Text(
            l10n.todaysSessionIsDone,
            style: EditorialType.section.copyWith(fontSize: 24),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              l10n.anotherSession,
              variant: AppButtonVariant.text,
              height: 48,
              fontSize: 15,
              onPressed: onStart,
            ),
          ),
        ],
      );
    }

    final facts = [
      if (week != null && totalWeeks != null)
        l10n.weekWeekOfTotal(countLabel(week!), countLabel(totalWeeks!)),
      if (minutes != null) l10n.nMin(countLabel(minutes!)),
    ];

    return AppCard(
      key: const ValueKey('today-card'),
      gap: 12,
      children: [
        _poster(
          color: AppColors.primaryContainer,
          child: art ?? const SizedBox.shrink(),
        ),
        if (coached)
          Text(
            l10n.fromYourCoach,
            style: AppText.label.copyWith(color: AppColors.primaryDim),
          ),
        Text(
          title ?? l10n.todaysWorkout,
          style: EditorialType.section.copyWith(fontSize: 26),
        ),
        if (facts.isNotEmpty)
          Text(
            facts.join(' · '),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        AppButton(
          l10n.startEverythingsReady,
          height: 56,
          icon: Icons.play_arrow,
          onPressed: onStart,
        ),
        if (onChange != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              l10n.change,
              key: const ValueKey('today-change'),
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: onChange,
            ),
          ),
      ],
    );
  }
}

/// Home's one Eat line: what she has eaten against today's target, and a tap
/// into Eat, where logging lives.
class HomeEatLine extends StatelessWidget {
  const HomeEatLine({
    super.key,
    this.totals = DayTotals.empty,
    this.targets,
    this.onTap,
  });

  final DayTotals totals;
  final DailyTargets? targets;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final target = targets?.kcal;
    final eaten = countLabel(totals.kcalSoFar);
    final line = target == null || target == 0
        ? l10n.kcalKcal(eaten)
        : l10n.eatenOfTargetKcal(eaten, countLabel(target));
    return AppListItem(
      key: const ValueKey('today-eat-line'),
      leading: const Icon(
        Icons.restaurant_outlined,
        size: 22,
        color: AppColors.primaryDim,
      ),
      title: line,
      trailing: const AppChevron(),
      onTap: onTap,
    );
  }
}

/// What she has eaten today, and the two plates she has most often: a ring
/// for protein with the calories in it, carbs and fat beside it, and a "+"
/// that logs a plate in one tap.
class HomeEatCard extends StatelessWidget {
  const HomeEatCard({
    super.key,
    this.totals = DayTotals.empty,
    this.targets,
    this.onLogFood,
    this.onScanMeal,
    this.loggedAt,
    this.now,
    this.plates = const <PlateSuggestion>[],
    this.onTap,
    this.onPlateTap,
    this.onPlateLog,
  });

  final DayTotals totals;

  /// The day's targets. The ring is calories eaten against the calorie target
  /// and each macro reads against its own; null shows what she has eaten and
  /// says nothing about a target.
  final DailyTargets? targets;

  /// "Log food": opens the meal search.
  final VoidCallback? onLogFood;

  /// "Scan": a photo of the plate. No chip when null.
  final VoidCallback? onScanMeal;
  final DateTime? loggedAt;
  final DateTime? now;
  final List<PlateSuggestion> plates;
  final VoidCallback? onTap;
  final VoidCallback? onPlateTap;
  final ValueChanged<PlateSuggestion>? onPlateLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final head = AppSplitRow(
      start: Text(
        mealHeading(
          l10n,
          loggedAt: loggedAt,
          now: now,
          hasUsual: plates.isNotEmpty,
        ),
        style: AppText.titleM,
      ),
      end: loggedAt == null
          ? const SizedBox.shrink()
          : Text(
              timeLabel(context, loggedAt!),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
    );

    final kcalTarget = targets?.kcal;
    final ring = AppRingStat(
      key: const ValueKey('today-eat-ring'),
      fraction: kcalTarget == null || kcalTarget == 0
          ? 0
          : totals.kcalSoFar / kcalTarget,
      big: countLabel(totals.kcalSoFar),
      small: kcalTarget == null
          ? l10n.kcal
          : l10n.ofTargetKcal(countLabel(kcalTarget)),
      size: 112,
      thickness: 11,
    );

    final triad = [
      (l10n.protein, totals.proteinSoFar, targets?.proteinG),
      (l10n.carbs, totals.carbsSoFar, targets?.carbsG),
      (l10n.fat, totals.fatSoFar, targets?.fatG),
    ];
    // A figure no logged food carries is a dash, not a zero.
    String eaten((String, int?, int?) m) =>
        l10n.gramsG_1usqy(m.$2 == null ? '–' : countLabel(m.$2!));
    String? target((String, int?, int?) m) =>
        m.$3 == null ? null : l10n.ofTargetG(countLabel(m.$3!));

    // The value on top, "of 120 g" under it, the name last. Each column keeps
    // its own width and wraps instead of shrinking, so no figure is squeezed.
    Widget macro((String, int?, int?) m) {
      final of = target(m);
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            key: ValueKey('today-eat-macro-${triad.indexOf(m)}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eaten(m),
                style: AppText.titleM,
                textAlign: TextAlign.center,
              ),
              if (of != null)
                Text(
                  of,
                  style: AppText.bodyM.copyWith(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 4),
              Text(m.$1, style: AppText.bodyM, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    Widget divider() => Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.outline,
    );

    final macros = stacked
        ? Column(
            key: const ValueKey('today-eat-macros'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in triad)
                AppSplitRow(
                  start: Text(m.$1, style: AppText.bodyM),
                  end: Text(
                    target(m) == null
                        ? eaten(m)
                        : l10n.sofarOfTargetG(
                            m.$2 == null ? '–' : countLabel(m.$2!),
                            countLabel(m.$3!),
                          ),
                    style: AppText.titleS,
                  ),
                ),
            ],
          )
        : IntrinsicHeight(
            key: const ValueKey('today-eat-macros'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < triad.length; i++) ...[
                  if (i > 0) divider(),
                  Expanded(child: Center(child: macro(triad[i]))),
                ],
              ],
            ),
          );

    return AppCard(
      gap: 10,
      children: [
        if (onTap == null)
          head
        else
          HandPressable(onTap: onTap, builder: (_, _) => head),
        Center(child: ring),
        macros,
        if (onLogFood != null || onScanMeal != null)
          Row(
            children: [
              if (onLogFood != null)
                Expanded(
                  child: AppButton(
                    l10n.logFood,
                    key: const ValueKey('today-log-food'),
                    icon: Icons.add,
                    height: 52,
                    variant: AppButtonVariant.tonal,
                    onPressed: onLogFood,
                  ),
                ),
              if (onLogFood != null && onScanMeal != null)
                const SizedBox(width: 10),
              if (onScanMeal != null)
                Expanded(
                  child: AppButton(
                    l10n.scan,
                    key: const ValueKey('today-scan-meal'),
                    icon: Icons.camera_alt_rounded,
                    height: 52,
                    variant: AppButtonVariant.tonal,
                    onPressed: onScanMeal,
                  ),
                ),
            ],
          ),
        for (final plate in plates)
          _PlateAddRow(
            name: plateName(l10n, plate.foodId),
            imageAsset: MealImages.assetFor(plate.foodId),
            kcal: l10n.kcalKcal(countLabel(plate.kcal)),
            onTap: onPlateLog == null ? onPlateTap : () => onPlateLog!(plate),
          ),
      ],
    );
  }
}

class _PlateAddRow extends StatelessWidget {
  const _PlateAddRow({
    required this.name,
    required this.kcal,
    this.imageAsset,
    this.onTap,
  });

  final String name;
  final String? imageAsset;
  final String kcal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (imageAsset != null) ...[
            MealImage(asset: imageAsset, size: 40),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: AppText.titleM.copyWith(fontSize: 16)),
                Text(
                  kcal,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
              border: Border.all(color: AppColors.pinkShade, width: 1.2),
            ),
            child: const Icon(
              Icons.add,
              size: 24,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return HandPressable(onTap: onTap, builder: (_, _) => row);
  }
}
