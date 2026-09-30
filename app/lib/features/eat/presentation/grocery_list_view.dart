/// E08 — Grocery list.
///
/// Matches `6-v2/src/screens-eat.mjs` → `E08`. **One shop.** Grouped the way an
/// Egyptian market trip actually goes, and it survives being closed mid-shop.
///
/// ## Ticks are local-first
///
/// A tick updates the screen immediately and the flush to Firestore is
/// debounced. E08 is used standing in a market, often with no signal, and a tick
/// that waited for a round-trip would fail exactly where the screen is for. The
/// keys are deterministic (`sha1(ingredientId:unit)`), so a tick made on two
/// devices converges on one line rather than ticking two.
///
/// ## Ticked lines stay where they are
///
/// Struck through, in place. A list that reorders itself under her thumb while
/// she is shopping is harder to read than one that does not.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/week/week_key.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../domain/meal_repository.dart';
import 'eat_sample_library.dart';
import 'week_plan_view_model.dart';

class GroceryListView extends StatefulWidget {
  const GroceryListView({
    super.key,
    this.repository,
    this.now,
    this.onBack,
    this.onShare,
    this.onSelectTab,
  });

  final MealRepository? repository;
  final DateTime? now;
  final VoidCallback? onBack;

  /// G5 §9 Q8: an OS share sheet with generated text. Nothing leaves the device
  /// unless she chooses — no server, no link.
  final VoidCallback? onShare;

  final ValueChanged<String>? onSelectTab;

  @override
  State<GroceryListView> createState() => _GroceryListViewState();
}

class _GroceryListViewState extends State<GroceryListView> {
  late final MealRepository _repo;
  late final bool _ownsRepo;

  static const _model = WeekPlanViewModel();

  WeekPlanView? _view;

  DateTime get _now => widget.now ?? DateTime.now();
  String get _weekId => WeekKey.of(_now).id;

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? InMemoryMealRepository();
    unawaited(_load());
  }

  Future<void> _load() async {
    final plan = await _repo.mealPlan(_weekId);
    if (!mounted) return;
    setState(() => _view = _model.build(weekId: _weekId, plan: plan));
  }

  @override
  void dispose() {
    if (_ownsRepo) unawaited(_repo.dispose());
    super.dispose();
  }

  /// Local first: the row changes now, the document catches up.
  void _tick(String itemKey, bool ticked) {
    final current = _view;
    if (current == null) return;
    setState(() => _view = _model.tick(current, itemKey, ticked));
    unawaited(
      _repo.tickGrocery(weekId: _weekId, itemKey: itemKey, ticked: ticked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = _view ?? _model.build(weekId: _weekId);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.groceryList,
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: widget.onShare,
            // Named. It was an icon with no tooltip, no label and no hint, so
            // E08 shipped a tappable a screen reader announces as nothing at
            // all — the only unnamed control on the screen.
            tooltip: l10n.share,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        // E08, which is what this screen is. Claiming 'E01' marked the Eat tab
        // active, and the active tab is not a link to itself — so the Eat tab
        // was dead from the grocery list.
        activeScreenId: 'E08',
        onSelect: (id) {
          final onTab = widget.onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          openScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: [
          Text(
            l10n.groupedTheWayYouShopTickAs,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          // A list she keeps, not a stack of cards: each market stop is an
          // open section on the page, and a pencil rule separates one stop
          // from the next.
          for (var i = 0; i < view.groups.length; i++) ...[
            if (i > 0) HandRule(seed: 50 + i, height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  groceryGroupLabel(l10n, view.groups[i].group),
                  style: AppText.titleS.copyWith(color: AppColors.primaryDim),
                ),
                const SizedBox(height: 4),
                for (final line in view.groups[i].lines)
                  _GroceryTick(
                    label: groceryLabel(l10n, line.ingredientId),
                    ticked: line.ticked,
                    onTap: () => _tick(line.itemKey, !line.ticked),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One line. A filled tick or an empty pencil ring — shape, not colour alone.
class _GroceryTick extends StatelessWidget {
  const _GroceryTick({
    required this.label,
    required this.ticked,
    required this.onTap,
  });

  final String label;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: ticked,
      button: true,
      child: HandPressable(
        onTap: onTap,
        builder: (_, _) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (ticked)
                  const Icon(
                    Icons.check_circle,
                    size: 22,
                    color: AppColors.tertiary,
                  )
                else
                  // The box she has not ticked yet, drawn in pencil the way a
                  // shopping list is ruled by hand.
                  SizedBox.square(
                    dimension: 22,
                    child: CustomPaint(
                      painter: LoopPainter(
                        seed: handSeed(['grocery', label]),
                        color: AppColors.outline,
                        width: 1.4,
                        level: HandLevel.crafted,
                        inflate: EdgeInsets.zero,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.body.copyWith(
                      color: ticked
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                      decoration: ticked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
