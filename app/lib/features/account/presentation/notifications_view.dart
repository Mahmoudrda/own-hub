/// A01 — Notifications.
///
/// Matches `6-v2/src/screens-account.mjs` → `A01`.
///
/// # Why this screen renders its empty state today
///
/// All four rows the prototype draws are **samples about other people**: "Sara
/// replied to your review" names a coach she may not have, "Beginners group
/// reached 146 sessions" and "Habiba and 12 others liked your best" are fixed
/// names and counts. None has a parameterised form in the dictionary, and G7 Q11
/// — which events A01 ships with — is unresolved.
///
/// `PHASE1-FIXES.md` §13 records four screens that stated the prototype's
/// numbers as a woman's personal facts, and §3 the invented "74 seconds". So
/// [NotificationCopy] maps a kind to authored copy **or to null**, a row with no
/// copy is counted rather than drawn, and A01 falls back to the empty state that
/// rule 17 makes the onboarding anyway.
///
/// The count is the honest part: `unrenderableCount` makes the gap measurable
/// instead of invisible, and the whole arrangement expires by itself the day the
/// strings land.
///
/// # The permission row is real, and is the part that works today
///
/// G7 §3.1's state machine has authored copy in both languages, and "denied
/// forever" is a first-class state whose designed fallback — the in-app card on
/// T01 — is a deliverable rather than a note. A01 never prompts on open; it
/// offers.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../train/domain/notification_plan.dart';
import '../domain/notifications.dart';
import 'account_view_models.dart';
import 'extras_rows.dart';

/// Kind → the sentence A01 draws for it, or null when none is authored.
///
/// Each kind below names the string it is waiting for. Returning null is not a
/// gap in this file — it is the dictionary gap, made visible and countable.
class NotificationCopy {
  const NotificationCopy._();

  static String? titleFor(NotificationKind kind, AppL10n l10n) {
    return switch (kind) {
      // Awaiting `{coach} replied to your review` — the shipped string names
      // Sara, who is one woman's coach and nobody else's.
      NotificationKind.coachReply => null,
      // Awaiting `{group} reached {count} sessions`.
      NotificationKind.groupMilestone => null,
      // Awaiting `{name} and {count} others liked your best`.
      NotificationKind.reaction => null,
      // The four slot strings now exist — `mealNudgeHeading` in
      // `today_cards.dart` picks one from the hour, which is what T03 draws.
      // What this switch cannot do is reach them: it is handed a [kind] and no
      // notification, so it has no `createdAt` to read the slot from, and a
      // meal nudge listed under the wrong meal is the defect T03 just had.
      // Closing this means giving `titleFor` the row rather than its kind.
      NotificationKind.mealNudge => null,
      // Awaiting G7 Q11's MVP event set and its copy.
      NotificationKind.weekClosed => null,
      NotificationKind.tierChanged => null,
      NotificationKind.verificationDecided => null,
    };
  }

  static bool hasAuthoredCopy(NotificationKind kind, AppL10n l10n) =>
      titleFor(kind, l10n) != null;
}

class NotificationsView extends StatelessWidget {
  const NotificationsView({
    super.key,
    this.notifications = const <AppNotification>[],
    this.permission = NotificationPermission.initial,
    this.onBack,
    this.onRequestPermission,
    this.onOpenOsSettings,
    this.onSelectTab,
    this.remindersOn = false,
    this.onOpenReminders,
    this.prefs,
    this.onPrefsChanged,
  });

  /// The switches under the reminders row, or null before the phone has
  /// agreed to show notifications: there is nothing to switch until then.
  final NotificationPrefs? prefs;
  final ValueChanged<NotificationPrefs>? onPrefsChanged;

  /// Whether her training reminders are set.
  final bool remindersOn;

  /// The training reminders sheet: her days, her time, or off. No row when
  /// null.
  final VoidCallback? onOpenReminders;

  /// Already paged and capped by the repository. A01 never asks for more than
  /// [kInboxPageSize].
  final List<AppNotification> notifications;

  final NotificationPermission permission;

  final VoidCallback? onBack;

  /// Offers the OS prompt. Never called on open — G7 §3.1: the product prompts
  /// after her first log, not at launch.
  final VoidCallback? onRequestPermission;

  /// Deep-links to OS settings once the denial is terminal.
  final VoidCallback? onOpenOsSettings;

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final view = NotificationsInboxView.from(
      notifications: notifications,
      permission: permission,
      hasAuthoredCopy: (kind) => NotificationCopy.hasAuthoredCopy(kind, l10n),
    );

    return AppScaffold(
      appBar: AppTopBar(title: l10n.notifications, onBack: onBack),
      // Its own id: A01 is not a tab, and claiming Home was the active one left
      // the Home tab drawn and unresponsive. See `profile_view.dart`.
      footer: [AppNavBar(activeScreenId: 'A01', onSelect: onSelectTab)],
      children: [
        Text(l10n.remindersAndExtras, style: AppText.titleM),
        // One ask, not two: the switch is her reminders, and turning it on
        // asks the phone for permission first when it has not been given.
        // Where she changes her days and her time, or stops them (R10).
        if (onOpenReminders != null)
          AppListItem(
            key: const ValueKey('a01-reminders'),
            leading: const Icon(
              Icons.alarm,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.trainingReminders,
            subtitle: l10n.aFewGentleRemindersTurnAnyOf,
            trailing: AppToggle(
              value: remindersOn,
              semanticLabel: l10n.trainingReminders,
              onChanged: (_) => view.showsPermissionPrompt && !remindersOn
                  ? (onRequestPermission ?? onOpenReminders)?.call()
                  : onOpenReminders?.call(),
            ),
            onTap: onOpenReminders,
          ),
        if (onOpenReminders != null && prefs != null) ...[
          _switchRow(
            key: 'a01-log-nudge',
            icon: Icons.edit_note,
            title: l10n.remindMeToAddASessionI,
            value: prefs!.logNudge,
            onChanged: (on) =>
                onPrefsChanged?.call(prefs!.copyWith(logNudge: on)),
          ),
          _switchRow(
            key: 'a01-check-ins',
            icon: Icons.favorite_border,
            title: l10n.gentleCheckInsWhenIveBeenAway,
            value: prefs!.checkIns,
            onChanged: (on) =>
                onPrefsChanged?.call(prefs!.copyWith(checkIns: on)),
          ),
          _switchRow(
            key: 'a01-rest-alert',
            icon: Icons.timer_outlined,
            title: l10n.restTimerAlert,
            value: prefs!.restAlert,
            onChanged: (on) =>
                onPrefsChanged?.call(prefs!.copyWith(restAlert: on)),
          ),
          // Off cancels the tips still to come.
          _switchRow(
            key: 'a01-tips',
            icon: Icons.lightbulb_outline,
            title: l10n.gettingStartedTips,
            value: prefs!.tips,
            onChanged: (on) => onPrefsChanged?.call(prefs!.copyWith(tips: on)),
          ),
        ],
        // The moving kitten and her streak, moved here from My profile.
        const ExtrasRows(),
        if (onOpenReminders == null && view.showsPermissionPrompt)
          AppListItem(
            leading: const Icon(
              Icons.notifications_active_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            // What this release can actually notify her about.
            //
            // It read "Turn on notifications so we can tell you when your
            // check is done" — ID-verification copy, for a check this build
            // does not run and a sign-up flow that is switched off. The
            // promise below it, on the same screen, has always been "one nudge
            // a day at most, at the hour you usually log", so that is what the
            // permission is asked for.
            title: l10n.turnNotificationsOnSoWeCanNudge,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: onRequestPermission,
          ),
        if (view.showsSettingsDeepLink)
          AppListItem(
            leading: const Icon(
              Icons.settings_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.openSettings,
            onTap: onOpenOsSettings,
          ),

        if (view.isEmpty && onOpenReminders == null)
          AppEmptyState(
            icon: Icons.notifications_none,
            title: l10n.notifications,
            body: l10n.aFewGentleRemindersTurnAnyOf,
          )
        else if (!view.isEmpty) ...[
          for (final row in view.rows)
            AppListItem(
              leading: const Icon(
                Icons.notifications_none,
                size: 24,
                color: AppColors.primaryDim,
              ),
              title: NotificationCopy.titleFor(row.kind, l10n)!,
            ),
          // The rule about them stopping is stated where she would go to turn
          // them off.
          if (onOpenReminders == null)
            AppSageNote(l10n.aFewGentleRemindersTurnAnyOf),
        ],
      ],
    );
  }
}

Widget _switchRow({
  required String key,
  required IconData icon,
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) => AppListItem(
  key: ValueKey(key),
  leading: Icon(icon, size: 24, color: AppColors.primaryDim),
  title: title,
  trailing: AppToggle(value: value, semanticLabel: title, onChanged: onChanged),
  onTap: () => onChanged(!value),
);
