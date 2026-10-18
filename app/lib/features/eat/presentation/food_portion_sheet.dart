/// The bottom sheet a tapped food opens: a size, a number of servings, and one
/// Add button. kcal and macros follow every change.
///
/// Not a confirmation. Logging still offers undo afterwards; this is where she
/// says how much, which is the only question a food needs.
library;

import 'package:flutter/material.dart';

import '../../../app_state/eat_state.dart' show EatAppState;
import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart' show HandIconRing;
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_widgets.dart' show moreMacrosLine;

/// "Contains nuts" for a food known to hold something she avoids, else null.
/// A food with no allergen data gets no note: nothing is claimed either way.
String? containsNoteFor(AppL10n l10n, AllergyGuard guard, Food food) {
  final known = guard.knownAllergens(food);
  if (known.isEmpty) return null;
  return l10n.containsAllergens(
    known.map((a) => EatAppState.allergenLabel(l10n, a)).join(', '),
  );
}

/// Opens the sheet for [food] and returns what she chose, or null if she
/// closed it. [containsNote] is the "Contains X" line, when one applies.
Future<ParsedItem?> showFoodPortionSheet({
  required BuildContext context,
  required Food food,
  String? containsNote,
  FoodSize? initialSize,
  int initialServings = 1,
}) {
  return showAppSheet<ParsedItem>(
    context: context,
    children: [
      FoodPortionPanel(
        food: food,
        containsNote: containsNote,
        initialSize: initialSize,
        initialServings: initialServings,
      ),
    ],
  );
}

class FoodPortionPanel extends StatefulWidget {
  const FoodPortionPanel({
    super.key,
    required this.food,
    this.containsNote,
    this.initialSize,
    this.initialServings = 1,
  });

  final Food food;
  final String? containsNote;
  final FoodSize? initialSize;
  final int initialServings;

  @override
  State<FoodPortionPanel> createState() => _FoodPortionPanelState();
}

class _FoodPortionPanelState extends State<FoodPortionPanel> {
  static const int _maxServings = 9;

  late FoodSize _size = widget.initialSize ?? widget.food.defaultSize;
  late int _servings = widget.initialServings.clamp(1, _maxServings);

  ParsedItem get _item => ParsedItem(
    food: widget.food,
    size: _size,
    servings: _servings,
    sourceText: widget.food.names.first,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final item = _item;
    final sizes = widget.food.sizes;
    final macros = moreMacrosLine(
      l10n,
      carbsG: item.carbsG,
      fatG: item.fatG,
      fiberG: item.fiberG,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.food.names.first, style: AppText.titleL),
        if (widget.containsNote != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.containsNote!,
            key: const ValueKey('portion-contains'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
        if (sizes.length > 1) ...[
          const SizedBox(height: 14),
          AppChipRow(
            items: [for (final size in sizes) size.label],
            selected: {sizes.indexWhere((s) => s.id == _size.id)},
            onTap: (index) => setState(() => _size = sizes[index]),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text(l10n.servings, style: AppText.titleS)),
            _StepButton(
              key: const ValueKey('portion-fewer'),
              icon: Icons.remove,
              tooltip: l10n.fewerServings,
              onPressed: _servings > 1
                  ? () => setState(() => _servings--)
                  : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                countLabel(_servings),
                key: const ValueKey('portion-servings'),
                textAlign: TextAlign.center,
                style: AppText.titleM,
              ),
            ),
            _StepButton(
              key: const ValueKey('portion-more'),
              icon: Icons.add,
              tooltip: l10n.moreServings,
              onPressed: _servings < _maxServings
                  ? () => setState(() => _servings++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          l10n.kcalKcalProteinGProtein(
            countLabel(item.kcal),
            countLabel(item.proteinG),
          ),
          key: const ValueKey('portion-totals'),
          style: AppText.titleM,
        ),
        if (macros != null) ...[
          const SizedBox(height: 2),
          Text(
            macros,
            key: const ValueKey('portion-macros'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          l10n.add,
          key: const ValueKey('portion-add'),
          onPressed: () => Navigator.of(context).pop(item),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: HandIconRing(
        seed: handSeed(['servings', tooltip]),
        icon: Icon(
          icon,
          size: 22,
          color: onPressed == null ? AppColors.outline : AppColors.primaryDim,
        ),
      ),
    );
  }
}
