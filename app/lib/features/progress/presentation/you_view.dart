/// P01 — You, the last tab: who she is, how her training is going, and the
/// places that are hers (coach, events, cycle).
///
/// Strava's "You": a header with her picture and a gear for settings, then a
/// two-way switch between Progress (one weekly chart and three figures) and
/// Activities (her finished sessions). The long record behind Progress (body
/// map, muscles, milestones, food) is one row away, on the insights screen.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/identity/user_roles.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/app_stat_hero.dart';
import '../../../ui/hand/hand.dart' show HandRule;
import '../../today/presentation/today_cards.dart' show openScreen;
import 'progress_view_model.dart';
import 'progress_widgets.dart';

class YouView extends StatefulWidget {
  const YouView({
    super.key,
    required this.summary,
    required this.activities,
    this.minutesThisWeek = 0,
    this.firstName,
    this.hasCoach = false,
    this.onOpenSettings,
    this.onOpenInsights,
    this.onOpenCoach,
    this.onOpenEvents,
    this.onOpenCycle,
    this.onOpenCommunity,
    this.onSelectTab,
  });

  final ProgressSummary summary;

  /// Her finished sessions, newest first: shown under the Activities segment.
  final Widget activities;
  final int minutesThisWeek;
  final String? firstName;

  /// Whether she has a coach now: the row reads "My coach", else "Find a coach".
  final bool hasCoach;

  final VoidCallback? onOpenSettings;

  /// The insights detail (body map, muscles, milestones, food).
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenCoach;
  final VoidCallback? onOpenEvents;
  final VoidCallback? onOpenCycle;
  final VoidCallback? onOpenCommunity;
  final ValueChanged<String>? onSelectTab;

  @override
  State<YouView> createState() => _YouViewState();
}

class _YouViewState extends State<YouView> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = widget.summary;
    final name = widget.firstName?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        // Her picture and the gear are on the page itself.
        showChrome: false,
        actions: [
          IconButton(
            key: const ValueKey('you-settings'),
            tooltip: l10n.openSettings,
            icon: const Icon(Icons.settings_outlined),
            color: AppColors.onSurface,
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'P01',
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
        showChrome: false,
        children: [
          Row(
            children: [
              // The gear opens settings; the picture is a control only when it
              // switches between her two roles.
              _avatar(context, name),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name.isEmpty ? l10n.you : name,
                  style: AppText.titleL,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSegmented(
            key: const ValueKey('you-segments'),
            items: [l10n.progress, l10n.activities],
            selectedIndex: _segment,
            onChanged: (i) => setState(() => _segment = i),
          ),
          if (_segment == 0) ...[
            AppStatHero(
              hero: AppStat(
                value: countLabel(s.sessionsThisWeek),
                label: l10n.sessionsThisWeek,
              ),
              others: [
                AppStat(
                  value: countLabel(widget.minutesThisWeek),
                  label: l10n.minutes,
                ),
                AppStat(value: countLabel(s.bestsCount), label: l10n.bests),
              ],
            ),
            WeekBarsChart(weeks: s.recentWeeks),
            if (widget.onOpenInsights != null)
              AppListItem(
                key: const ValueKey('you-see-more'),
                title: l10n.seeMore,
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
                onTap: widget.onOpenInsights,
              ),
          ] else
            widget.activities,
          if (_segment == 0) ...[
            const HandRule(seed: 41, height: 14),
            if (widget.onOpenCoach != null && AppRouter.screenIsOn('H05'))
              _row(
                const ValueKey('you-coach'),
                Icons.sports_outlined,
                widget.hasCoach ? l10n.myCoach : l10n.findACoach,
                widget.onOpenCoach,
              ),
            if (widget.onOpenEvents != null && AppRouter.screenIsOn('T09'))
              _row(
                const ValueKey('you-events'),
                Icons.event_outlined,
                l10n.events,
                widget.onOpenEvents,
              ),
            if (widget.onOpenCycle != null && AppRouter.screenIsOn('Y03'))
              _row(
                const ValueKey('you-cycle'),
                Icons.self_improvement,
                l10n.myCycle,
                widget.onOpenCycle,
              ),
            if (widget.onOpenCommunity != null && AppRouter.screenIsOn('M01'))
              _row(
                const ValueKey('you-community'),
                Icons.groups_outlined,
                l10n.community,
                widget.onOpenCommunity,
              ),
          ],
        ],
      ),
    );
  }

  /// A picture, unless it switches between her two roles: then it is a button.
  /// For one role it is neither tappable nor announced as a button.
  Widget _avatar(BuildContext context, String name) {
    final canSwitch = RoleScope.maybeOf(context)?.value.canSwitch ?? false;
    final avatar = AppAvatar(
      firstName: name,
      size: 56,
      onOpenProfile: widget.onOpenSettings,
    );
    return canSwitch
        ? avatar
        : ExcludeSemantics(child: IgnorePointer(child: avatar));
  }

  Widget _row(Key key, IconData icon, String title, VoidCallback? onTap) =>
      AppListItem(
        key: key,
        leading: Icon(icon, size: 22, color: AppColors.primaryDim),
        title: title,
        trailing: const Icon(
          Icons.chevron_right,
          size: 22,
          color: AppColors.onSurfaceVariant,
        ),
        onTap: onTap,
      );
}
