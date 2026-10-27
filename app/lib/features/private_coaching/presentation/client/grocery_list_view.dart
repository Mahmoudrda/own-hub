library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_scaffold.dart';
import 'grocery_list.dart';

class GroceryListView extends StatefulWidget {
  const GroceryListView({super.key, required this.lines, this.onBack});

  final List<GroceryLine> lines;
  final VoidCallback? onBack;

  @override
  State<GroceryListView> createState() => _GroceryListViewState();
}

class _GroceryListViewState extends State<GroceryListView> {
  final Set<int> _ticked = <int>{};

  void _back() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppScaffold(
      appBar: AppTopBar(title: l10n.groceryList, onBack: _back),
      children: [
        if (widget.lines.isEmpty)
          Text(
            l10n.nothingToBuyYet,
            key: const ValueKey('grocery-empty'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          )
        else ...[
          Text(
            l10n.forTheWholePlanAsTheDishes,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          for (var i = 0; i < widget.lines.length; i++)
            CheckboxListTile(
              key: ValueKey('grocery-$i'),
              value: _ticked.contains(i),
              title: Text(widget.lines[i].name),
              secondary: widget.lines[i].grams == 0
                  ? null
                  : Text(l10n.gramsG_1usqy(countLabel(widget.lines[i].grams))),
              onChanged: (on) => setState(() {
                if (on == true) {
                  _ticked.add(i);
                } else {
                  _ticked.remove(i);
                }
              }),
            ),
        ],
      ],
    );
  }
}
