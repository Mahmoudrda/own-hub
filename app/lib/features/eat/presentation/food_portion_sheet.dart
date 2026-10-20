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
import '../../signup/domain/digits.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart' show HandIconRing;
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_sentence_parser.dart';
import '../domain/units.dart';
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
///
/// [isFavourite] and [onToggleFavourite] draw the star beside the name; the
/// callback returns whether the food is now starred. With no callback there is
/// no star.
Future<ParsedItem?> showFoodPortionSheet({
  required BuildContext context,
  required Food food,
  String? containsNote,
  FoodSize? initialSize,
  int initialServings = 1,
  bool isFavourite = false,
  Future<bool> Function()? onToggleFavourite,
}) {
  return showAppSheet<ParsedItem>(
    context: context,
    children: [
      FoodPortionPanel(
        food: food,
        containsNote: containsNote,
        initialSize: initialSize,
        initialServings: initialServings,
        isFavourite: isFavourite,
        onToggleFavourite: onToggleFavourite,
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
    this.isFavourite = false,
    this.onToggleFavourite,
  });

  final Food food;
  final String? containsNote;
  final FoodSize? initialSize;
  final int initialServings;
  final bool isFavourite;
  final Future<bool> Function()? onToggleFavourite;

  @override
  State<FoodPortionPanel> createState() => _FoodPortionPanelState();
}

class _FoodPortionPanelState extends State<FoodPortionPanel> {
  static const int _maxServings = 9;

  late FoodSize _size = widget.initialSize ?? widget.food.defaultSize;
  late int _servings = widget.initialServings.clamp(1, _maxServings);
  late bool _starred = widget.isFavourite;

  /// The unit she is measuring in, or null while the size chips decide.
  FoodUnit? _unit;
  final TextEditingController _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    // A portion she chose by weight opens on that weight, in grams.
    final grams = Food.gramsOfSizeId(widget.initialSize?.id ?? '');
    if (grams != null && FoodUnits.availableFor(widget.food).isNotEmpty) {
      _unit = FoodUnit.g;
      _amount.text = '$grams';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The amount box as a number. Accepts a comma for the point and Arabic
  /// digits, which is how it is typed on an Arabic keyboard.
  double? get _amountValue => parseLocalNumber(_amount.text);

  /// The portion on screen, or null while the amount is not a usable number.
  ParsedItem? get _item {
    final unit = _unit;
    if (unit == null) {
      return ParsedItem(
        food: widget.food,
        size: _size,
        servings: _servings,
        sourceText: widget.food.names.first,
      );
    }
    final amount = _amountValue;
    final size = amount == null
        ? null
        : FoodUnits.sizeFor(widget.food, unit, amount);
    if (size == null) return null;
    return ParsedItem(
      food: widget.food,
      size: size,
      servings: 1,
      sourceText: widget.food.names.first,
    );
  }

  void _pickUnit(FoodUnit unit) {
    setState(() {
      _unit = unit;
      _amount.text = _formatAmount(FoodUnits.startingAmount(widget.food, unit));
    });
  }

  static String _formatAmount(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  Future<void> _toggleStar() async {
    final toggle = widget.onToggleFavourite;
    if (toggle == null) return;
    final now = await toggle();
    if (mounted) setState(() => _starred = now);
  }

  String _unitLabel(AppL10n l10n, FoodUnit unit) => switch (unit) {
    FoodUnit.g => l10n.g,
    FoodUnit.oz => l10n.oz,
    FoodUnit.ml => l10n.ml,
    FoodUnit.cup => l10n.cup,
    FoodUnit.piece => l10n.piece,
    FoodUnit.serving => l10n.serving_1d0fq,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final item = _item;
    final sizes = widget.food.sizes;
    final units = FoodUnits.availableFor(widget.food);
    final macros = item == null
        ? null
        : moreMacrosLine(
            l10n,
            carbsG: item.carbsG,
            fatG: item.fatG,
            fiberG: item.fiberG,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.food.names.first, style: AppText.titleL),
            ),
            if (widget.onToggleFavourite != null)
              IconButton(
                key: const ValueKey('portion-star'),
                onPressed: _toggleStar,
                tooltip: _starred
                    ? l10n.removeFromFavourites
                    : l10n.addToFavourites,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  _starred ? Icons.star : Icons.star_border,
                  size: 26,
                  color: AppColors.primaryDim,
                ),
              ),
          ],
        ),
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
            selected: {
              if (_unit == null) sizes.indexWhere((s) => s.id == _size.id),
            },
            onTap: (index) => setState(() {
              _size = sizes[index];
              _unit = null;
            }),
          ),
        ],
        if (units.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppChipRow(
            key: const ValueKey('portion-units'),
            items: [for (final unit in units) _unitLabel(l10n, unit)],
            selected: {if (_unit != null) units.indexOf(_unit!)},
            grow: false,
            onTap: (index) => _pickUnit(units[index]),
          ),
        ],
        const SizedBox(height: 14),
        if (_unit == null)
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
          )
        else ...[
          AppField(
            key: const ValueKey('portion-amount'),
            controller: _amount,
            label: l10n.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          if (item?.size.grams case final grams?) ...[
            const SizedBox(height: 6),
            Text(
              FoodUnits.isApproximate(widget.food, _unit!)
                  ? l10n.aboutGramsG(countLabel(grams))
                  : l10n.gramsG_1usqy(countLabel(grams)),
              key: const ValueKey('portion-weight'),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
        const SizedBox(height: 14),
        Text(
          item == null
              ? ''
              : l10n.kcalKcalProteinGProtein(
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
          onPressed: item == null
              ? null
              : () => Navigator.of(context).pop(item),
        ),
        SizedBox(height: 12 + MediaQuery.viewInsetsOf(context).bottom),
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
