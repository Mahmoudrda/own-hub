/// What `W03`, `W04` and `W06` are before she has a single client.
///
/// A plan belongs to one woman: `PlanDraft` carries her `clientUid`, and
/// `InMemoryPlanDraftRepository.assertWritable` refuses a draft that names
/// nobody. So a planner opened by a coach with an empty roster has nothing to
/// write to, and every control on it — the minute chips, the rest chips, the
/// meal slots — would be a control that cannot work. That is correct domain
/// behaviour and a broken-looking screen at the same time.
///
/// Rule 17 settles which of the two it should look like: **the empty state is
/// the onboarding.** So the planner says she has no clients yet, in the same
/// words and the same dashed box `W01` uses for exactly this, and offers the
/// one thing that starts it — her roster, where the three things worth doing
/// before a first client are listed.
///
/// It is the screens' own day one, not a separate destination: there is no id
/// for it in the inventory, and `W03` is still `W03` while it is on screen.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_art.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_scaffold.dart';

class NoClientYetView extends StatelessWidget {
  const NoClientYetView({
    super.key,
    required this.title,
    this.onOpenClients,
    this.onBack,
  });

  /// What this screen is, since there is no client to name in the bar.
  final String title;

  /// Her roster. The one action, because it is where a client comes from.
  final VoidCallback? onOpenClients;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: title, onBack: onBack),
      body: AppScaffold(
        children: [
          AppEmptyState(
            key: const Key('coachplan.noClient'),
            icon: Icons.group,
            art: AppArt.squatWeights,
            title: l10n.noClientsYet,
            body: l10n.womenWhoAskToWorkWithYou,
            onTap: onOpenClients,
          ),
        ],
      ),
    );
  }
}
