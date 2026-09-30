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
import '../domain/notifications.dart';
import 'account_view_models.dart';

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
    this.onOpenSettings,
    this.onRequestPermission,
    this.onOpenOsSettings,
    this.onSelectTab,
  });

  /// Already paged and capped by the repository. A01 never asks for more than
  /// [kInboxPageSize].
  final List<AppNotification> notifications;

  final NotificationPermission permission;

  final VoidCallback? onBack;

  /// The gear in the app bar, which the prototype sends to A02.
  ///
  /// The router used to send it to `A03`, the privacy centre. A gear on a
  /// notifications screen does not mean "privacy" to anybody, and it carried no
  /// label or tooltip, so a screen reader announced it as "button" and a
  /// sighted woman had no way to guess. It is labelled, and it goes where the
  /// line above always said it goes.
  final VoidCallback? onOpenSettings;

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
      appBar: AppTopBar(
        title: l10n.notifications,
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: onOpenSettings,
            iconSize: 24,
            color: AppColors.onSurface,
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      // Its own id: A01 is not a tab, and claiming Home was the active one left
      // the Home tab drawn and unresponsive. See `profile_view.dart`.
      footer: [AppNavBar(activeScreenId: 'A01', onSelect: onSelectTab)],
      children: [
        if (view.showsPermissionPrompt)
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
          )
        else if (view.showsSettingsDeepLink)
          AppListItem(
            leading: const Icon(
              Icons.settings_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.openSettings,
            onTap: onOpenOsSettings,
          ),

        if (view.isEmpty)
          AppEmptyState(
            icon: Icons.notifications_none,
            title: l10n.notifications,
            body: l10n.oneNudgeADayAtMostAt,
          )
        else ...[
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
          AppSageNote(l10n.oneNudgeADayAtMostAt),
        ],
      ],
    );
  }
}
