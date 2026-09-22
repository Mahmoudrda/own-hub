/// Every screen in the app, one tap away — for testing only.
///
/// Reached from Profile, and only while [Feature.accountRequired] is off: it
/// exists so the owner can look at every screen without an account, including
/// the ones no path reaches in a fresh app — sign-up, onboarding, the admin
/// console, and screens that need data she has not made yet.
///
/// Rows are labelled with the screen id and its inventory title, the same way
/// Z14 labels switches with their identifiers: this is an inspection tool, and
/// the ids are what the designs, the tests and the QA report all use.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';

/// The order flows are listed in: hers first, then the coach's, then the
/// doors in and the console.
const _flowOrder = [
  'today',
  'train',
  'eat',
  'community',
  'progress',
  'cycle',
  'account',
  'assistant',
  'coaching',
  'coached',
  'coach',
  'coach-setup',
  'coachbrand',
  'coachplan',
  'signup',
  'onboarding',
  'admin',
];

class AllScreensView extends StatelessWidget {
  const AllScreensView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final byFlow = <String, List<String>>{};
    for (final e in appDestinations.entries) {
      byFlow.putIfAbsent(e.value.flow, () => []).add(e.key);
    }
    final flows = [
      ..._flowOrder.where(byFlow.containsKey),
      ...byFlow.keys.where((f) => !_flowOrder.contains(f)),
    ];

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.allScreens,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Text(
          l10n.openAnyScreenForTesting,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        for (final flow in flows) ...[
          const SizedBox(height: 8),
          Text(
            flow,
            textDirection: TextDirection.ltr,
            style: EditorialType.folio,
          ),
          for (final id in byFlow[flow]!)
            AppListItem(
              title: '$id  ${appDestinations[id]!.title}',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () => AppRouter.goTo(context, id),
            ),
        ],
      ],
    );
  }
}
