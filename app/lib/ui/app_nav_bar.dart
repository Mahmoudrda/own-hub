/// The bottom navigation, matching `navBar()` in `6-v2/src/kit.mjs`.
///
/// Five destinations for a woman, four for a coach. This is the product's
/// primary navigation and the thing the "everything is two taps away" goal is
/// measured from, so the tab list lives here once rather than being repeated on
/// each of the screens that shows it.
///
/// **Which list is shown follows her active role** (`DECISIONS.md` D11), read
/// from [RoleScope] here rather than passed down by every screen. Nine screens
/// render this bar; making each one role-aware would be nine chances to get it
/// wrong, and a woman who switches role would see the old bar on whichever one
/// was missed.
///
/// The active tab is marked four ways at once — a marker swash behind the
/// icon, the filled variant of the icon, a colour change, and a pen line drawn
/// under its name. Colour alone is not a reliable signal for everyone.
///
/// The bar sits on the page itself, under a pencil rule, rather than on a
/// tinted tray: it is the foot of the page, not a separate piece of chrome.
library;

import 'package:flutter/material.dart';

import '../domain/identity/user_roles.dart';
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import '../theme/app_tokens.dart';
import 'hand/hand.dart';

/// A destination in the bottom bar. [screenId] is the screen the tab opens, so
/// navigation is expressed in the same ids the design and the plans use.
class NavDestination {
  const NavDestination({
    required this.screenId,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isAction = false,
  });

  final String screenId;
  final IconData icon;
  final IconData activeIcon;

  /// Resolved per locale — the tab labels are translated like everything else.
  final String Function(AppL10n) label;

  /// A button in the bar that opens a screen over the current tab instead of
  /// being a place. It is drawn as a filled pink disc and is never active.
  final bool isAction;
}

/// Her bar: Home, Train, the centre "+ Log food" (D59), Eat, You.
///
/// "Log food" is an action, not a place: it opens the food search over the tab
/// she is on and is never marked active. Events and the community have no tab;
/// both are rows on You. Insights and her profile are inside You too.
///
/// **Coaching is deliberately absent, and was deliberately not deleted.** It was
/// once a fifth tab pointing at `H01` — `F53 — Find a coach`, a *trainee*
/// feature. D11 moved it off the bar: hiring a coach and being a coach are
/// different things, and only the second one is a role. It lives on You.
const List<NavDestination> traineeTabs = [
  NavDestination(
    screenId: 'T01',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: _homeLabel,
  ),
  NavDestination(
    screenId: 'R01',
    icon: Icons.fitness_center_outlined,
    activeIcon: Icons.fitness_center,
    label: _trainLabel,
  ),
  logFoodAction,
  NavDestination(
    screenId: 'E01',
    icon: Icons.restaurant_outlined,
    activeIcon: Icons.restaurant,
    label: _eatLabel,
  ),
  NavDestination(
    screenId: 'P01',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: _youLabel,
  ),
];

/// The centre "+": opens the food search (`E02`) from any tab.
const NavDestination logFoodAction = NavDestination(
  screenId: 'E02',
  icon: Icons.add,
  activeIcon: Icons.add,
  label: _logFoodLabel,
  isAction: true,
);

/// A coach's tabs: Today, Clients, Chats, Earnings.
const List<NavDestination> coachTabs = [
  NavDestination(
    screenId: 'K07',
    icon: Icons.today_outlined,
    activeIcon: Icons.today,
    label: _todayLabel,
  ),
  NavDestination(
    screenId: 'W01',
    icon: Icons.group_outlined,
    activeIcon: Icons.group,
    label: _clientsLabel,
  ),
  NavDestination(
    screenId: 'W10',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    label: _chatsLabel,
  ),
  NavDestination(
    screenId: 'K17',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments,
    label: _earningsLabel,
  ),
];

// Top-level functions, because a const list cannot hold a closure.
String _homeLabel(AppL10n l) => l.home;
String _trainLabel(AppL10n l) => l.train;
String _eatLabel(AppL10n l) => l.eat;
String _youLabel(AppL10n l) => l.you;
String _logFoodLabel(AppL10n l) => l.logFood;
String _todayLabel(AppL10n l) => l.today;
String _clientsLabel(AppL10n l) => l.clients;
String _chatsLabel(AppL10n l) => l.chats;
String _earningsLabel(AppL10n l) => l.earnings;

/// The bar a given role sees, minus anything this build has switched off.
///
/// The filter is not a detail. A tab whose feature is dark renders, takes a
/// fifth of the bar, and lands on the "not in this build" panel: a door drawn
/// on a wall.
List<NavDestination> tabsFor(AppRole role) {
  final all = role == AppRole.coach ? coachTabs : traineeTabs;
  return [
    for (final tab in all)
      if (_isOn(tab)) tab,
  ];
}

/// The tab that owns [screenId]: You also carries the screens opened from it.
String _tabOwning(String screenId) =>
    const {'progress', 'community'}.contains(appRoutes[screenId]?.flow)
    ? 'P01'
    : screenId;

bool _isOn(NavDestination tab) => AppRouter.screenIsOn(tab.screenId);

class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.activeScreenId,
    this.destinations,
    this.onSelect,
  });

  /// The screen currently shown. A tab is active when it owns this screen.
  final String activeScreenId;

  /// Normally null, which means "whichever bar her active role should see".
  ///
  /// Passing an explicit list is for tests and for the design gallery, where a
  /// bar is rendered on its own with no app shell around it. Production screens
  /// leave it null so a role switch reaches all of them at once.
  final List<NavDestination>? destinations;

  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final role = RoleScope.rolesOf(context).active;
    final tabs = destinations ?? tabsFor(role);

    Widget tabAt(NavDestination tab) => Expanded(
      child: _Tab(
        tab: tab,
        label: tab.label(l10n),
        active: !tab.isAction && tab.screenId == _tabOwning(activeScreenId),
        // The tab she is on is not a link to itself; a screen opened from it is.
        onTap: tab.screenId == activeScreenId || onSelect == null
            ? null
            : () => onSelect!(tab.screenId),
      ),
    );

    // Labels grow with the system text size only so far. The bar is a fixed
    // 60 high, and past this its names would be cut off at the bottom —
    // the platform's own tab bars stop growing for the same reason.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: ColoredBox(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HandRule(seed: 17, height: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [for (final tab in tabs) tabAt(tab)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.label,
    required this.active,
    this.onTap,
  });

  final NavDestination tab;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colour = active
        ? AppColors.onPrimaryContainer
        : AppColors.onSurfaceVariant;

    final iconWidget = Icon(
      active ? tab.activeIcon : tab.icon,
      size: 24,
      color: colour,
    );
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.nav.copyWith(fontWeight: FontWeight.w600, color: colour),
    );

    return Semantics(
      selected: active,
      button: true,
      child: HandPressable(
        onTap: onTap,
        scale: 0.94,
        borderRadius: BorderRadius.circular(8),
        builder: (context, _) => SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 32,
                child: active
                    // A swash of marker behind the icon, where the pill was.
                    ? CustomPaint(
                        painter: MarkerPainter(
                          seed: tab.screenId.hashCode,
                          cover: 0.82,
                          textDirection: Directionality.of(context),
                        ),
                        child: Center(child: iconWidget),
                      )
                    : tab.isAction
                    // "+ Log food": a pink disc with a petrol edge, the one
                    // filled mark on the bar.
                    ? Center(
                        child: DecoratedBox(
                          key: const ValueKey('nav-log-food'),
                          decoration: BoxDecoration(
                            color: AppColors.actionPrimary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.onActionPrimary.withValues(
                                alpha: 0.55,
                              ),
                              width: 1.2,
                            ),
                          ),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.add,
                              size: 22,
                              color: AppColors.onActionPrimary,
                            ),
                          ),
                        ),
                      )
                    : Center(child: iconWidget),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: active
                    // The pen line is painted over the label's own box rather
                    // than padded under it, so it adds no height: at 1.6 in
                    // Arabic this bar has none to spare.
                    ? DrawOn(
                        builder: (context, p) => CustomPaint(
                          foregroundPainter: UnderlinePainter(
                            seed: tab.screenId.hashCode,
                            color: AppColors.primary,
                            level: HandLevel.crafted,
                            width: 1.4,
                            progress: p,
                            baseline: 0.94,
                            textDirection: Directionality.of(context),
                          ),
                          child: text,
                        ),
                      )
                    : text,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
