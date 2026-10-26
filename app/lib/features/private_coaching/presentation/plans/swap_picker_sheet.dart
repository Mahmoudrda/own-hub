library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_field.dart';
import 'coach_plan_logic.dart';

class SwapPickerSheet extends StatefulWidget {
  const SwapPickerSheet({
    super.key,
    required this.catalog,
    required this.language,
    required this.exclude,
    required this.initial,
  });

  final MealCatalog catalog;
  final String language;
  final String exclude;
  final List<String> initial;

  @override
  State<SwapPickerSheet> createState() => _SwapPickerSheetState();
}

class _SwapPickerSheetState extends State<SwapPickerSheet> {
  late final List<String> _picked = [...widget.initial];
  final TextEditingController _q = TextEditingController();
  bool _full = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _title(String id) {
    final r = widget.catalog.recipe(id);
    if (r == null) return id;
    final ar = r.titleAr;
    return widget.language == 'ar' && ar != null && ar.isNotEmpty
        ? ar
        : r.titleEn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final q = _q.text.trim().toLowerCase();
    final ids = [
      for (final r in widget.catalog.recipes)
        if (r.recipeId != widget.exclude &&
            (q.isEmpty || _title(r.recipeId).toLowerCase().contains(q)))
          r.recipeId,
    ].take(40).toList();
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.approvedSwaps, style: AppText.titleL),
          AppField(
            key: const ValueKey('swaps-search'),
            controller: _q,
            label: l10n.search,
            onChanged: (_) => setState(() {}),
          ),
          if (_full)
            Text(
              l10n.threeAtMost,
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final id in ids)
                CheckboxListTile(
                  key: ValueKey('swap-$id'),
                  value: _picked.contains(id),
                  title: Text(_title(id)),
                  onChanged: (on) => setState(() {
                    if (on == true) {
                      if (_picked.length >= 3) {
                        _full = true;
                      } else {
                        _picked.add(id);
                        _full = false;
                      }
                    } else {
                      _picked.remove(id);
                      _full = false;
                    }
                  }),
                ),
            ],
          ),
          AppButton(
            l10n.saveSwaps,
            key: const ValueKey('swaps-save'),
            onPressed: () => Navigator.of(context).pop(<String>[..._picked]),
          ),
        ],
      ),
    );
  }
}
