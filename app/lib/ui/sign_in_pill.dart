/// The always-visible "Sign in or join" control for a woman with no account.
///
/// High contrast on purpose (petrol on linen would disappear): a filled
/// petrol pill, 44 points tall, on Home and at the top of her profile. It
/// opens Rahma's welcome on the sign-in side.
library;

import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';

class SignInPill extends StatelessWidget {
  const SignInPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppL10n.of(context).signInOrJoin;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('sign-in-pill'),
        color: AppColors.primary,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
