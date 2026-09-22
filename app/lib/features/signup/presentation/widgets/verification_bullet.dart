/// The `bullet()` helper from `6-v2/src/screens-signup.mjs`, shared by `C09`
/// and `C13`.
///
/// A 22px sage icon beside a line of plain speech, both top-aligned so the icon
/// sits with the first line rather than floating in the middle of a wrapped
/// paragraph. That matters more in Arabic, where these lines run longer.
///
/// It is a file rather than a private widget in one screen because the two
/// screens that use it are the two that carry the product's promises about what
/// is read and what is deleted — and those should not be able to drift apart.
library;

import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';

class VerificationBullet extends StatelessWidget {
  const VerificationBullet({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            // 15/22 is the prototype's value for this helper specifically, and
            // is a touch tighter than `bodyM`.
            style: AppText.bodyM.copyWith(
              height: 22 / 15,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
