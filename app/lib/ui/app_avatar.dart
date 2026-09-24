/// Her profile picture — and, for a woman who holds both roles, the switch
/// between her two apps.
///
/// `DECISIONS.md` **D11**. A woman who chose "I train and I coach" moves between
/// the trainee app and the coach app by tapping her own picture. That gesture
/// was chosen over a tab or a settings toggle for a reason: switching role
/// changes the entire app, and the profile picture is the one element on screen
/// that already means *you*. A tab would imply coaching is a section of the
/// trainee app, which is exactly the arrangement D11 removes.
///
/// **A single-role woman never sees a switcher.** Offering one where there is
/// nothing to switch to implies the app is keeping something from her, so the
/// avatar is simply her profile and nothing more.
///
/// There is no photo pipeline yet, so this draws her initial. That is a
/// deliberate placeholder for the image and **not** a placeholder for the
/// behaviour: the switching works now.
library;

import 'package:flutter/material.dart';

import '../domain/identity/user_roles.dart';
import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'app_chevron.dart';
import 'app_list_item.dart';
import 'app_sheet.dart';
import 'hand/hand.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.firstName,
    this.size = 36,
    this.onOpenProfile,
    this.roles,
    this.onRoleChanged,
    this.isSelf = true,
  });

  /// Her name, for the initial. Absent until C13 has one.
  final String? firstName;

  final double size;

  /// Where a single-role tap goes.
  final VoidCallback? onOpenProfile;

  /// Overrides the ambient [RoleScope]. For tests and the design gallery.
  final UserRoles? roles;

  /// Called after a switch, so a host can persist `active`.
  final ValueChanged<UserRoles>? onRoleChanged;

  /// False for another woman's picture — on a post, a comment, a story. Her
  /// picture is never a control over YOUR roles, so it shows no switch badge
  /// and a tap goes only where [onOpenProfile] says.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final notifier = RoleScope.maybeOf(context);
    final current = isSelf
        ? roles ?? notifier?.value ?? UserRoles.trainee
        : UserRoles.trainee;

    final initial = (firstName ?? '').trim().isEmpty
        ? null
        : firstName!.trim().characters.first.toUpperCase();

    return Semantics(
      button: true,
      // Names what the tap does, which differs by role. "Your profile" on a
      // control that switches the whole app would be a lie to anyone using a
      // screen reader.
      label: current.canSwitch ? l10n.switchApp : l10n.yourProfile,
      child: InkWell(
        onTap: () {
          if (!current.canSwitch) {
            onOpenProfile?.call();
            return;
          }
          _openSwitcher(context, current, notifier);
        },
        borderRadius: BorderRadius.circular(AppRadius.full),
        splashFactory: NoSplash.splashFactory,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Her picture, ringed once in fine ink: the one element on the
            // page that means her.
            Positioned.fill(
              child: CustomPaint(
                foregroundPainter: LoopPainter(
                  seed: (firstName ?? '').hashCode,
                  color: AppColors.primaryDim,
                  width: 1.1,
                  level: HandLevel.crafted,
                  inflate: const EdgeInsets.all(2.5),
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: initial == null
                  ? Icon(
                      Icons.person,
                      size: size * 0.58,
                      color: AppColors.onPrimaryContainer,
                    )
                  : Text(
                      initial,
                      style: AppText.titleM.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
            ),
            // A small mark, so a dual-role woman can see the picture is a
            // control before she taps it. Absent for everyone else.
            if (current.canSwitch)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    size: size * 0.3,
                    color: AppColors.surface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSwitcher(
    BuildContext context,
    UserRoles current,
    ValueNotifier<UserRoles>? notifier,
  ) async {
    final l10n = AppL10n.of(context);

    await showAppSheet<void>(
      context: context,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.switchApp, style: AppText.titleL),
            const SizedBox(height: 2),
            Text(
              l10n.youAreATraineeAndACoach,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _RoleRow(
              icon: Icons.self_improvement,
              title: l10n.training,
              active: current.active == AppRole.trainee,
              onTap: () => _choose(context, AppRole.trainee, current, notifier),
            ),
            const SizedBox(height: 10),
            _RoleRow(
              icon: Icons.sports_gymnastics,
              title: l10n.coaching,
              active: current.active == AppRole.coach,
              onTap: () => _choose(context, AppRole.coach, current, notifier),
            ),
            // Her profile stays one tap away for a woman with both roles,
            // whose picture opens this sheet instead of the profile.
            if (onOpenProfile != null) ...[
              const SizedBox(height: 10),
              AppListItem(
                leading: const Icon(
                  Icons.person_outline,
                  size: 22,
                  color: AppColors.primaryDim,
                ),
                title: l10n.yourProfile,
                trailing: const AppChevron(),
                onTap: () {
                  Navigator.of(context).pop();
                  onOpenProfile!();
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _choose(
    BuildContext context,
    AppRole role,
    UserRoles current,
    ValueNotifier<UserRoles>? notifier,
  ) {
    Navigator.of(context).pop();
    if (role == current.active) return;
    final next = current.activating(role);
    notifier?.value = next;
    onRoleChanged?.call(next);
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: active ? AppCardVariant.selected : AppCardVariant.outlined,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      children: [
        Row(
          children: [
            Icon(icon, size: 26, color: AppColors.primaryDim),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppText.titleM)),
            if (active)
              const Icon(
                Icons.check_circle,
                size: 24,
                color: AppColors.primary,
              ),
          ],
        ),
      ],
    );
  }
}
