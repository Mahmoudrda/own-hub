/// The four local helpers at the top of `6-v2/src/screens-eat.mjs`, translated.
///
/// The design file defines `slot()`, `mealRow()`, `parsed()` and `boxRow()`
/// inline because they appear across E01–E04 and E09 and must stay identical on
/// all of them. They are feature-local rather than `lib/ui/` primitives for the
/// same reason they are local in the prototype: a meal slot and a parsed row are
/// Eat's vocabulary, not the product's — exactly the position
/// `train_widgets.dart` takes on move rows and set rows.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_stat_hero.dart';
import '../../../ui/app_log_button.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/meal_image.dart';
import '../../../ui/hand/hand.dart';
import '../../../domain/nutrition/target_safety.dart' show TargetNote;
import '../domain/daily_targets.dart';
import '../domain/day_totals.dart';
import '../domain/food_library.dart';
import 'eat_day_view_model.dart';
import 'meal_labels.dart';

/// One column of E01's three-slot card. `slot()` in the prototype.
///
/// The state is carried three ways at once — fill colour, the kind of frame,
/// and a tick glyph on a done slot. Colour alone is not a reliable signal for
/// everyone, and this card is the fastest read on the screen.
class SlotColumn extends StatelessWidget {
  const SlotColumn({
    super.key,
    required this.name,
    required this.value,
    required this.status,
    this.onTap,
  });

  /// Opens what is in the slot, to take something out. Null for an empty slot.
  final VoidCallback? onTap;

  /// "Breakfast".
  final String name;

  /// What is in it — "Ful and baladi" — or "Now" / "Later".
  final String value;

  final SlotStatus status;

  @override
  Widget build(BuildContext context) {
    // Three states, three kinds of mark on the page: a done slot is a plain
    // slip of sage, the slot she is in now is framed in rose ink, and a later
    // one is a dashed pencil box — space still waiting to be filled.
    final (Color fill, Color? frame, Color labelColour) = switch (status) {
      SlotStatus.done => (
        AppColors.tertiaryContainer,
        null,
        AppColors.tertiary,
      ),
      SlotStatus.now => (
        AppColors.surfaceLowest,
        AppColors.primary,
        AppColors.primaryDim,
      ),
      SlotStatus.later => (
        AppColors.surfaceLow,
        AppColors.outline.withValues(alpha: 0.7),
        AppColors.onSurfaceVariant,
      ),
    };

    final surface = HandSurface(
      seed: handSeed(['slot', name]),
      fill: fill,
      frame: frame,
      frameWidth: status == SlotStatus.now ? 1.5 : 1,
      dashed: status == SlotStatus.later,
      level: status == SlotStatus.now
          ? HandLevel.expressive
          : HandLevel.crafted,
      radius: 4,
      looseCorner: 12,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (status == SlotStatus.done) ...[
                const Icon(Icons.check, size: 14, color: AppColors.tertiary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  name,
                  style: AppText.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.bodyM.copyWith(
              fontSize: 14,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );

    final tap = onTap;
    return Expanded(
      child: tap == null
          ? surface
          : HandPressable(
              onTap: tap,
              borderRadius: BorderRadius.circular(4),
              builder: (context, _) => surface,
            ),
    );
  }
}

/// The card at the top of E01 and E04: the slots and the protein bar. There is
/// no calorie line: the app promises no grams and no calorie shaming.
///
/// **There is no countdown on this card and there cannot be one.** The bar is
/// [DayTotals.proteinPercent], which clamps at 100 and has no "over by" partner.
/// Nothing here computes a remainder, because nothing in
/// the domain can (§1.5).
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.slots,
    required this.totals,
    required this.proteinTitle,
    this.proteinDelta,
  });

  final List<SlotColumn> slots;

  /// Everything this card says about her day comes from here.
  ///
  /// It used to take `proteinLabel` and `kcalLabel` as ready-made strings **as
  /// well as** these totals, and the caller passed fixed dictionary constants
  /// selected by whether a log had just happened. So the bar was drawn from her
  /// real data and the sentence beside it from the prototype's sample, and they
  /// disagreed for every woman: a 460 kcal lunch read "About 1,106 kcal so far
  /// today".
  ///
  /// The parameters are gone rather than corrected. Handing a card both a
  /// number and a sentence about that number is an invitation to disagree, and
  /// the third occurrence of this defect class in this codebase is enough — see
  /// `PHASE1-FIXES.md` #3 (C13's invented duration) and #8 (R07's fixed label).
  /// Now there is one source and a disagreement cannot be expressed.
  final DayTotals totals;

  final String proteinTitle;

  /// E04's "+31 g" — what this meal added.
  ///
  /// **Currently always null, deliberately.** It is what she just logged, and
  /// nothing computes it: `justLogged` is a `LogHandle` carrying only a
  /// description and an undo, and `EatDayView` exposes the current totals with
  /// no before/after pair. It was a fixed "+31 g". Rendering nothing is the
  /// honest state until a real delta exists.
  final String? proteinDelta;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Derived here, from the one source, so the sentence and the bar below it
    // cannot come apart. Western digits in both locales — countLabel, never
    // NumberFormat (P0-A11Y-01).
    final proteinLabel = l10n.sofarOfTargetG(
      countLabel(totals.proteinSoFar),
      countLabel(totals.proteinTargetG),
    );

    return AppCard(
      gap: 12,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              slots[i],
            ],
          ],
        ),
        // A pencil rule between what she ate and what it came to.
        HandRule(seed: handSeed(['day-card', proteinTitle]), height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSplitRow(
              start: Text(proteinTitle, style: AppText.titleS),
              end: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    proteinLabel,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (proteinDelta != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      proteinDelta!,
                      style: AppText.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Same `totals` as the sentence above and the one below. That is
            // the point: this bar was previously the only element on the card
            // reading her real data.
            AppProgressBar(percent: totals.proteinPercent, height: 10),
            // Carbs, fat and fibre, once anything today carries them: a quiet
            // line in the same grey as the protein figure, with no target and
            // no colour that could read as a warning.
            if (moreMacrosLine(
                  l10n,
                  carbsG: totals.carbsSoFar,
                  fatG: totals.fatSoFar,
                  fiberG: totals.fiberSoFar,
                )
                case final line?) ...[
              const SizedBox(height: 8),
              Text(
                line,
                key: const ValueKey('day-card-more-macros'),
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// "Carbs 120 g · Fat 45 g · Fibre 18 g", with only the figures that are
/// known, or null when none is. Western digits in both languages. Never a
/// target and never a remainder: these are what she ate, and nothing more.
String? moreMacrosLine(AppL10n l10n, {int? carbsG, int? fatG, int? fiberG}) {
  final parts = [
    if (carbsG != null) l10n.carbsGramsG(countLabel(carbsG)),
    if (fatG != null) l10n.fatGramsG(countLabel(fatG)),
    if (fiberG != null) l10n.fibreGramsG(countLabel(fiberG)),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// A row she can log in one tap. `mealRow()` in the prototype.
class MealRow extends StatelessWidget {
  const MealRow({
    super.key,
    required this.title,
    required this.meta,
    required this.logLabel,
    this.onLog,
    this.primary = false,
    this.onTap,
    this.imageAsset,
  });

  final String title;

  /// The painted picture of the dish, when it has one.
  final String? imageAsset;

  /// "34 g protein".
  final String meta;

  final String logLabel;
  final VoidCallback? onLog;

  /// The likeliest answer. One per list, so the eye lands on it.
  final bool primary;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: title,
      subtitle: meta,
      leading: imageAsset == null
          ? null
          : MealImage(asset: imageAsset, size: 48, semanticLabel: null),
      variant: primary ? AppCardVariant.selected : AppCardVariant.outlined,
      onTap: onTap,
      // One tap saves and offers five seconds to undo. AppLogButton carries
      // that rule; it never opens a dialog and never leads to a confirm screen.
      trailing: AppLogButton(logLabel, primary: primary, onPressed: onLog),
    );
  }
}

/// A parsed item on E02 and E03, with its sizes as chips on the row.
///
/// `parsed()` in the prototype. The size chips are here rather than behind a tap
/// because E02's design note is explicit: "Sizes are chips on the row, so she
/// never opens a food to fix one."
class ParsedRow extends StatelessWidget {
  const ParsedRow({
    super.key,
    required this.name,
    required this.meta,
    required this.sizeLabels,
    required this.selectedSize,
    this.onPickSize,
    this.onRemove,
    this.removeTooltip,
    this.imageAsset,
  });

  final String name;

  /// The painted picture of the food, when it has one.
  final String? imageAsset;
  final String meta;
  final List<String> sizeLabels;
  final int selectedSize;
  final ValueChanged<int>? onPickSize;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gap: 10,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        Row(
          children: [
            if (imageAsset != null) ...[
              MealImage(asset: imageAsset, size: 48),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // The minus in a pencil ring rather than a filled bubble. The
            // padding keeps the tap target at 44 around the 40 ring.
            IconButton(
              onPressed: onRemove,
              tooltip: removeTooltip,
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: HandIconRing(
                seed: handSeed(['remove', name]),
                icon: const Icon(
                  Icons.remove,
                  size: 22,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        if (sizeLabels.isNotEmpty)
          AppChipRow(
            items: sizeLabels,
            selected: {selectedSize},
            onTap: onPickSize,
          ),
      ],
    );
  }
}

/// The camera beside "Type what you ate": E12, a photo of her plate.
///
/// A square the height of the box, in the pink that marks the one thing to do
/// on a card, with the camera drawn in petrol and a name for a screen reader.
class SnapMealButton extends StatelessWidget {
  const SnapMealButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: HandSurface(
          key: const ValueKey('eat-snap-meal'),
          seed: handSeed(['snap-meal', label]),
          fill: AppColors.primaryContainer,
          radius: 5,
          looseCorner: 14,
          onTap: onPressed,
          padding: const EdgeInsets.all(14),
          child: const Icon(
            Icons.photo_camera_outlined,
            size: 26,
            color: AppColors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// E03. Two gestures, one row, because searching for a food and describing a
/// meal are the same act.
class SayOrTypeBox extends StatelessWidget {
  const SayOrTypeBox({
    super.key,
    required this.label,
    this.micTooltip,
    this.onType,
    this.onSpeak,
    this.searchIcon = false,
  });

  final String label;

  /// A magnifier in place of the keyboard, for the box that opens search.
  final bool searchIcon;

  /// The microphone's tooltip. With no [onSpeak] there is no microphone.
  final String? micTooltip;
  final VoidCallback? onType;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    // Drawn as the line she writes on in E02 — a faint tint with a pencil
    // line under it — so the box reads as the field it opens rather than as
    // one more card.
    return HandUnderline(
      seed: handSeed(['say-or-type-line', label]),
      color: HandInk.pencil,
      level: HandLevel.crafted,
      width: HandStroke.fine,
      gap: 0,
      child: HandSurface(
        seed: handSeed(['say-or-type', label]),
        fill: AppColors.surfaceLow,
        radius: 5,
        looseCorner: 14,
        onTap: onType,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (onSpeak != null) ...[
              IconButton(
                onPressed: onSpeak,
                tooltip: micTooltip,
                iconSize: 22,
                color: AppColors.primaryDim,
                icon: const Icon(Icons.mic),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            Icon(
              searchIcon ? Icons.search : Icons.keyboard,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The round "+" that logs or opens a food. Pink with petrol ink, 44 square.
class PlusButton extends StatelessWidget {
  const PlusButton({
    super.key,
    required this.label,
    this.onPressed,
    this.size = 44,
  });

  /// The side of the square, 44 in a list and 48 where it is the row's one
  /// control.
  final double size;

  /// What a screen reader says, "Add Koshari".
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: HandSurface(
          seed: handSeed(['plus', label]),
          fill: AppColors.primaryContainer,
          radius: 22,
          looseCorner: 22,
          onTap: onPressed,
          pressable: true,
          pressScale: 0.92,
          child: SizedBox(
            width: size,
            height: size,
            child: const Icon(
              Icons.add,
              size: 24,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// A food in E02's live results: name, what a medium portion comes to, a note
/// when it is known to hold something she avoids, and a "+".
class FoodResultRow extends StatelessWidget {
  const FoodResultRow({
    super.key,
    required this.title,
    required this.meta,
    required this.addLabel,
    this.note,
    this.onTap,
    this.onAdd,
  });

  final String title;
  final String meta;

  /// "Contains nuts", or null.
  final String? note;
  final String addLabel;
  final VoidCallback? onTap;

  /// What "+" does. The row itself opens the portion sheet.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: title,
      subtitle: note == null ? meta : '$meta\n$note',
      onTap: onTap,
      // Without its own handler the "+" only marks the row, which already adds.
      trailing: PlusButton(label: addLabel, onPressed: onAdd),
    );
  }
}

/// A small food picture with the drawn bowl mark behind it, for a food that has
/// no painted picture yet.
class FoodThumb extends StatelessWidget {
  const FoodThumb({super.key, required this.imageAsset, this.size = 40});

  final String? imageAsset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MealImage(
      asset: imageAsset,
      size: size,
      semanticLabel: null,
      fallback: FoodMark(
        markKey: FoodMarks.bowl,
        size: size,
        ink: AppColors.primaryDim,
      ),
    );
  }
}

/// One plate in E01's Quick add strip, with a "+" that logs it.
class QuickAddCard extends StatelessWidget {
  const QuickAddCard({
    super.key,
    required this.title,
    required this.meta,
    required this.addLabel,
    this.imageAsset,
    this.onAdd,
  });

  final String title;
  final String meta;
  final String addLabel;

  /// The dish's painted picture, or null where it has none yet: the card then
  /// draws the plain bowl mark in its place.
  final String? imageAsset;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Row(
            children: [
              FoodThumb(imageAsset: imageAsset, size: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.titleS,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: AppText.bodyM.copyWith(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PlusButton(label: addLabel, onPressed: onAdd),
            ],
          ),
        ],
      ),
    );
  }
}

/// E01's hero: kcal eaten against the day's target as the one big figure, and
/// protein, carbs and fat as three small figures, each with a bar against its
/// target. Four figures, no more.
///
/// It shows what she has eaten against a figure to aim at and nothing counts
/// down: past a target a bar is simply full. [totals] already include any meal
/// still inside its undo window, so they move the moment she logs.
class EatHero extends StatelessWidget {
  const EatHero({
    super.key,
    required this.totals,
    required this.targets,
    this.onPersonalise,
    this.compact = false,
  });

  final DayTotals totals;
  final DailyTargets targets;

  /// Opens where she adds her weight, height and age. Shown only while the
  /// targets rest on the stated defaults.
  final VoidCallback? onPersonalise;

  /// Four figures and nothing else. The hub draws the fibre line and the
  /// personalise link under the meals instead.
  final bool compact;

  static double _fraction(int eaten, int target) =>
      target <= 0 ? 0 : (eaten / target).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (targets.withheld) {
      return AppCard(
        key: const ValueKey('eat-hero-withheld'),
        children: [
          Text(l10n.yourCoachSetsYourFoodPlanWith, style: AppText.bodyM),
        ],
      );
    }
    final carbs = totals.carbsSoFar;
    final fat = totals.fatSoFar;

    // A figure no logged food carries shows as a dash, never as a zero she did
    // not earn.
    Widget macro(String name, int? eaten, int target, Color colour) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: AppText.titleS),
            Text(
              l10n.sofarOfTargetG(
                eaten == null ? '–' : countLabel(eaten),
                countLabel(target),
              ),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            AppProgressBar(
              percent: eaten == null ? 0 : _fraction(eaten, target) * 100,
              height: 8,
              colour: colour,
            ),
          ],
        ),
      );
    }

    return AppCard(
      key: const ValueKey('eat-hero'),
      children: [
        Semantics(
          key: const ValueKey('eat-kcal-hero'),
          label: '${countLabel(totals.kcalSoFar)} ${l10n.kcal} ${l10n.eaten}',
          excludeSemantics: true,
          child: AppStatHero(
            hero: AppStat(
              value: countLabel(totals.kcalSoFar),
              label: l10n.ofTargetKcal(countLabel(targets.kcal)),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            macro(
              l10n.protein,
              totals.proteinSoFar,
              targets.proteinG,
              AppColors.tertiarySoft,
            ),
            const SizedBox(width: 12),
            macro(l10n.carbs, carbs, targets.carbsG, AppColors.primary),
            const SizedBox(width: 12),
            macro(l10n.fat, fat, targets.fatG, AppColors.outline),
          ],
        ),
        if (targetNoteText(l10n, targets.note) case final note?)
          Text(
            note,
            key: const ValueKey('eat-target-note'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (!compact && totals.fiberSoFar != null) FibreLine(totals: totals),
        if (!compact && onPersonalise != null)
          PersonaliseLink(targets: targets, onPressed: onPersonalise),
      ],
    );
  }
}

/// Why a target is not the one her body data alone would give, or null when
/// there is nothing to say.
String? targetNoteText(AppL10n l10n, TargetNote note) => switch (note) {
  TargetNote.floor => l10n.weNeverSetATargetBelow1,
  TargetNote.noDeficitMinor => l10n.weDoNotSetWeightLossTargets,
  TargetNote.noDeficitStage => l10n.weDoNotSetWeightLossTargets_14owx,
  TargetNote.none || TargetNote.withheld => null,
};

/// "Personalise", shown while the targets rest on the stated defaults.
class PersonaliseLink extends StatelessWidget {
  const PersonaliseLink({
    super.key,
    required this.targets,
    required this.onPressed,
  });

  final DailyTargets targets;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!targets.usesDefaults || onPressed == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppL10n.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: l10n.targetsUseAStandardEstimateAddYour,
        child: TextButton(
          key: const ValueKey('eat-personalise'),
          onPressed: onPressed,
          child: Text(
            l10n.personalise,
            style: AppText.label.copyWith(
              color: AppColors.primaryDim,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Fibre 18 g", drawn only when a logged food carries the figure.
class FibreLine extends StatelessWidget {
  const FibreLine({super.key, required this.totals});

  final DayTotals totals;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppL10n.of(context).fibreGramsG(countLabel(totals.fiberSoFar!)),
      key: const ValueKey('day-card-more-macros'),
      style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
    );
  }
}

/// "Lunch" with a chevron: the meal she is logging into, changeable.
class SlotPill extends StatelessWidget {
  const SlotPill({
    super.key,
    required this.label,
    required this.changeLabel,
    this.onTap,
  });

  final String label;

  /// Screen reader hint, "Change".
  final String changeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $changeLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: HandSurface(
        seed: handSeed(['slot-pill', label]),
        fill: AppColors.primaryContainer,
        radius: 18,
        looseCorner: 18,
        onTap: onTap,
        pressable: true,
        pressScale: 0.96,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppText.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more,
              size: 20,
              color: AppColors.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

/// "All" and the seven food shelves, one tap to narrow what is listed.
///
/// [selected] is null for All. The chips scroll sideways rather than wrapping,
/// so the list under them stays where it is.
class FoodCategoryChips extends StatelessWidget {
  const FoodCategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final FoodCategory? selected;
  final ValueChanged<FoodCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    const categories = FoodCategory.values;
    return Semantics(
      container: true,
      label: l10n.foodCategories,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: AppChipRow(
          grow: false,
          items: [
            l10n.all,
            for (final category in categories)
              foodCategoryLabel(l10n, category),
          ],
          selected: {selected == null ? 0 : categories.indexOf(selected!) + 1},
          onTap: (index) =>
              onChanged(index == 0 ? null : categories[index - 1]),
        ),
      ),
    );
  }
}

/// One meal of E01's diary: its name, what is in it, and one "+". On an empty
/// meal with a usual plate the "+" logs that plate; otherwise it opens the
/// search aimed at the meal. A row with something in it also opens what is
/// there, to take an item out.
class MealDiaryRow extends StatelessWidget {
  const MealDiaryRow({
    super.key,
    required this.name,
    required this.value,
    required this.status,
    required this.plusLabel,
    this.itemImageAssets = const <String?>[],
    this.onLog,
    this.onTap,
  });

  /// The painted picture of each logged item, in order (null where an item has
  /// none). The first three show as thumbnails; an empty meal shows none.
  final List<String?> itemImageAssets;

  /// "Breakfast".
  final String name;

  /// What is in it, or "Now" / "Later".
  final String value;

  final SlotStatus status;

  /// What a screen reader says for the "+": "Add Ful with egg" or "Log
  /// Breakfast".
  final String plusLabel;

  final VoidCallback? onLog;

  /// Opens what is in the meal. Null for an empty one.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = status == SlotStatus.done;
    return AppListItem(
      title: name,
      subtitle: value,
      leading: itemImageAssets.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final asset in itemImageAssets.take(3))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: FoodThumb(imageAsset: asset, size: 40),
                  ),
              ],
            )
          : done
          ? const Icon(Icons.check, size: 23, color: AppColors.tertiary)
          : null,
      variant: status == SlotStatus.now
          ? AppCardVariant.selected
          : AppCardVariant.outlined,
      onTap: onTap,
      trailing: PlusButton(label: plusLabel, onPressed: onLog, size: 48),
    );
  }
}
