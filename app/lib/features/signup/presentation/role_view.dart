/// C08 — Which one are you?
///
/// Matches `6-v2/src/screens-signup.mjs` → `C08`. Training is preselected
/// because most women here are here to train, and coach onboarding is a longer
/// path that nobody should fall into by accident.
///
/// # This screen changed with D11
///
/// It used to offer two options and tell her the answer was permanent: `role`
/// was written once and could only be changed by messaging support. It now
/// offers **three** — train, coach, or both — and the answer is no longer a
/// sentence. A woman who picks both moves between the two apps by tapping her
/// profile picture, and anyone can change this later from her profile.
///
/// The deliberate two-step (choose, then Continue) survives that change, but for
/// a different reason. It is no longer about permanence: it is that the coach
/// path leads to certificate checks a trainee never sees, so the tap that
/// commits her to it should be her own.
///
/// # What "both" does not mean
///
/// It does not grant her anything. Picking both records an *intent*; the coach
/// role is only held once the coach application and its certificate checks pass
/// — `users/{uid}.roles.held` is server-written for exactly that reason
/// (`SCHEMA-SPINE.md`). Until then she has the trainee app, which is what she
/// would have had anyway.
library;

import 'package:flutter/material.dart';

import '../../../domain/identity/user_roles.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';

/// What she chose on C08.
///
/// Three answers, not two. This is the sign-up *choice*; [UserRoles] is what the
/// app runs on afterwards, and [SignupRoleChoice.toRoles] is the one conversion
/// between them.
enum SignupRole { trainee, coach, both }

extension SignupRoleChoice on SignupRole {
  /// The roles this choice asks for.
  ///
  /// "Both" opens on the trainee side: it is the app she uses daily, and
  /// coaching is work she should choose to open rather than land in.
  UserRoles toRoles() {
    switch (this) {
      case SignupRole.trainee:
        return UserRoles.trainee;
      case SignupRole.coach:
        return UserRoles.coach;
      case SignupRole.both:
        return UserRoles.both;
    }
  }

  /// True when this choice needs the coach application and its certificate
  /// checks before the coach app means anything.
  bool get needsCoachApplication => this != SignupRole.trainee;
}

class RoleView extends StatefulWidget {
  const RoleView({
    super.key,
    this.initialRole = SignupRole.trainee,
    this.onContinue,
    this.onBack,
    this.offerCoach = true,
  });

  final SignupRole initialRole;

  /// Whether the coach and "both" answers are offered at all. False while the
  /// coach app is switched off (`Feature.coachApp`): offering a path that
  /// leads to a screen saying the feature is off is a promise the build cannot
  /// keep. Then only the trainee card is drawn and Continue sends trainee.
  final bool offerCoach;

  /// Carries the chosen role, because the destinations differ: anything that
  /// includes coaching leads to certificate checks a trainee never sees.
  final ValueChanged<SignupRole>? onContinue;

  final VoidCallback? onBack;

  @override
  State<RoleView> createState() => _RoleViewState();
}

class _RoleViewState extends State<RoleView> {
  late SignupRole _role = widget.offerCoach
      ? widget.initialRole
      : SignupRole.trainee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onBack),
      footer: [
        AppButton(
          l10n.continueLabel,
          onPressed: () => widget.onContinue?.call(_role),
        ),
      ],
      children: [
        Text(l10n.whichOneAreYou, style: AppText.display),
        Text(
          // Was "by messaging us". D11 makes this hers to change, so the copy
          // stops sending her to support for it.
          l10n.youCanChangeThisLaterInYour,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        _RoleCard(
          icon: Icons.self_improvement,
          title: l10n.imHereToTrain,
          body: l10n.workoutsRecipesAndTheCommunityFree,
          selected: _role == SignupRole.trainee,
          onTap: () => setState(() => _role = SignupRole.trainee),
        ),
        if (widget.offerCoach) ...[
          _RoleCard(
            icon: Icons.sports_gymnastics,
            title: l10n.iCoachWomen,
            body: l10n.takeClientsSetYourPackagesKeep80,
            selected: _role == SignupRole.coach,
            onTap: () => setState(() => _role = SignupRole.coach),
          ),
          _RoleCard(
            icon: Icons.swap_horiz,
            title: l10n.iTrainAndICoach,
            body: l10n.twoAppsInOneSwitchBetweenThem,
            selected: _role == SignupRole.both,
            onTap: () => setState(() => _role = SignupRole.both),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      children: [
        Row(
          children: [
            Icon(icon, size: 30, color: AppColors.primaryDim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleL),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // The tick, so the chosen row says so with a shape and not only
            // with a border colour.
            if (selected) ...[
              const SizedBox(width: 12),
              const Icon(
                Icons.check_circle,
                size: 26,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
