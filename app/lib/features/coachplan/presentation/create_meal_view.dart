/// `W07` — a meal the coach writes herself, and the numbers she is not given.
///
/// ## The partial total is the case this screen exists for
///
/// One ingredient outside G5's verified pack and `nutrition.resolved` is false,
/// which means **no figures at all** — not a subset, not an estimate. The card
/// states that, and there is no branch here that could add four resolvable
/// ingredients up: `MealNutrition` has no constructor that takes figures
/// without the claim that everything resolved, so the partial total is
/// unrepresentable rather than merely not drawn.
///
/// The lines that caused it are named, so "unavailable" is a fact about her
/// dish rather than a shrug.
///
/// ## Her dish stays hers
///
/// It is written to `coaches/{coachUid}/meals/*` and never to `foods`. The
/// footer says so, and G5's rules deny the write anyway.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/meal/coach_meal.dart';
import 'coachplan_widgets.dart';

class CreateMealView extends StatefulWidget {
  const CreateMealView({
    super.key,
    this.meal,
    this.onNameChanged,
    this.onIngredientsChanged,
    this.onServingsChanged,
    this.onPrepMinutesChanged,
    this.onNoteChanged,
    this.onSave,
    this.onClose,
  });

  /// The dish as it stands. Null for a new one.
  final CoachMeal? meal;

  final ValueChanged<String>? onNameChanged;
  final ValueChanged<String>? onIngredientsChanged;
  final ValueChanged<String>? onServingsChanged;
  final ValueChanged<String>? onPrepMinutesChanged;
  final ValueChanged<String>? onNoteChanged;
  final VoidCallback? onSave;
  final VoidCallback? onClose;

  @override
  State<CreateMealView> createState() => _CreateMealViewState();
}

class _CreateMealViewState extends State<CreateMealView> {
  late final TextEditingController _name;
  late final TextEditingController _ingredients;
  late final TextEditingController _servings;
  late final TextEditingController _prep;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _name = TextEditingController(text: meal?.name ?? '');
    _ingredients = TextEditingController(
      text: <String>[
        for (final line in meal?.ingredients ?? const <MealIngredient>[])
          line.text,
      ].join(' · '),
    );
    _servings = TextEditingController(text: '${meal?.servings ?? 1}');
    _prep = TextEditingController(
      text: meal?.prepMinutes == null ? '' : '${meal!.prepMinutes}',
    );
    _note = TextEditingController(text: meal?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _ingredients.dispose();
    _servings.dispose();
    _prep.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final meal = widget.meal;
    final nutrition = meal?.nutrition;
    final unresolved = meal?.unresolvedIngredients ?? const <MealIngredient>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.createAMeal,
        leadingIcon: Icons.close,
        onBack: widget.onClose,
      ),
      body: AppScaffold(
        footer: [
          AppButton(
            l10n.saveToMyMealsAndAssign,
            height: 54,
            onPressed: widget.onSave,
          ),
          Text(
            l10n.savedToYourOwnCollectionItIs,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
        children: [
          AppField(
            controller: _name,
            label: l10n.name,
            onChanged: widget.onNameChanged,
          ),
          AppField(
            controller: _ingredients,
            label: l10n.ingredientsAndAmounts,
            onChanged: widget.onIngredientsChanged,
          ),
          Row(
            children: [
              Expanded(
                child: AppField(
                  controller: _servings,
                  label: l10n.servings,
                  keyboardType: TextInputType.number,
                  onChanged: widget.onServingsChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppField(
                  controller: _prep,
                  label: l10n.prepTime,
                  keyboardType: TextInputType.number,
                  onChanged: widget.onPrepMinutesChanged,
                ),
              ),
            ],
          ),
          if (meal != null && meal.labels.isNotEmpty) ...[
            SectionHead(l10n.labels),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in meal.labels)
                  AppPill(
                    label,
                    background: AppColors.surfaceContainer,
                    foreground: AppColors.onSurfaceVariant,
                  ),
              ],
            ),
          ],
          AppField(
            controller: _note,
            label: l10n.noteForHer,
            onChanged: widget.onNoteChanged,
          ),
          // All of them, or none of them. The flag decides; this screen never
          // adds anything up.
          if (nutrition != null)
            AppCard(
              key: const Key('W07.nutrition'),
              variant: AppCardVariant.filled,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gap: 8,
              children: [
                if (nutrition.resolved)
                  Text(
                    l10n.kcalKcalProteinGProtein(
                      '${nutrition.kcal}',
                      '${nutrition.proteinG}',
                    ),
                    style: AppText.bodyM,
                  )
                else ...[
                  Text(
                    l10n.nutritionDetailsUnavailableThisMealUsesIngredien,
                    style: AppText.bodyM,
                  ),
                  // Which lines did it. "Unavailable" with no reason is a
                  // shrug; this is an answer she can act on.
                  if (unresolved.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final line in unresolved)
                          AppPill(
                            line.text,
                            background: AppColors.surfaceLowest,
                            foreground: AppColors.onSurfaceVariant,
                          ),
                      ],
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
