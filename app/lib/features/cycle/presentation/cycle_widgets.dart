/// Pieces shared by the Y screens, built once so they cannot drift apart.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/hand/hand_seed_name.dart';
import '../../today/presentation/today_cards.dart' show openScreen;

/// The hub's three tabs. **Calendar is absent in symptom-only mode** — Y14 has
/// no dates to show, so the tab is not rendered rather than rendered empty.
enum CycleTab { today, calendar, patterns }

class CycleTabs extends StatelessWidget {
  const CycleTabs({
    super.key,
    required this.active,
    required this.showCalendar,
    this.onSelect,
  });

  final CycleTab active;

  /// False in symptom-only mode and nowhere else.
  final bool showCalendar;

  final ValueChanged<CycleTab>? onSelect;

  /// The tabs actually shown, in order. A tab whose screen is switched off
  /// is not drawn, so the server can stop the calendar or the patterns
  /// without leaving a tab that opens nothing.
  List<CycleTab> get tabs => [
    CycleTab.today,
    if (showCalendar && AppRouter.screenIsOn('Y08')) CycleTab.calendar,
    if (AppRouter.screenIsOn('Y10')) CycleTab.patterns,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final shown = tabs;

    String labelFor(CycleTab tab) => switch (tab) {
      CycleTab.today => l10n.today,
      CycleTab.calendar => l10n.calendar,
      CycleTab.patterns => l10n.patterns,
    };

    return AppChipRow(
      items: [for (final tab in shown) labelFor(tab)],
      selected: {if (shown.contains(active)) shown.indexOf(active)},
      onTap: onSelect == null ? null : (i) => onSelect!(shown[i]),
    );
  }
}

/// The bottom bar every hub screen carries.
///
/// **My cycle is not a tab**, so no tab owns these screens and none of them is
/// marked active. This said `'T01'`, which marked Home as the page she was on —
/// and `AppNavBar` gives the active tab no `onTap`, because a tab is not a link
/// to itself. The result was Home rendered as current and dead on all five My
/// cycle screens, which is the one tab a woman reading her cycle is most likely
/// to reach for.
///
/// So each screen passes [screenId] — its own id, the thing
/// `AppNavBar.activeScreenId` has always documented — and every tab stays live.
class CycleNavBar extends StatelessWidget {
  const CycleNavBar({super.key, this.screenId = '', this.onSelectTab});

  /// The My cycle screen being drawn (Y03, Y07, Y08, Y10, Y12). No tab owns
  /// any of them, which is the point: the default marks none of them active.
  final String screenId;

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    return AppNavBar(
      activeScreenId: screenId,
      onSelect: (id) {
        final onTab = onSelectTab;
        if (onTab != null) {
          onTab(id);
          return;
        }
        openScreen(context, id);
      },
    );
  }
}

/// A row with a title, an optional subtitle and a trailing control.
///
/// `AppListItem` already provides the row; this is the layout Y02, Y10 and Y12
/// use for a switch, kept here so four screens cannot end up with four
/// spacings.
class CycleSwitchRow extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'CycleSwitchRow';

  const CycleSwitchRow({
    super.key,
    required this.title,
    required this.trailing,
    this.subtitle = '',
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleM),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}
