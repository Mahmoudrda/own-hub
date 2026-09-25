/// C14 — Being checked.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C14`.
///
/// **This screen is not a rejection and must never read as one.** A check that
/// needs a person, a check that did not pass, and a call that never completed
/// all arrive here. `DECISIONS.md` D8 fixes the substance: we are reviewing your
/// application to make sure this community stays safe and private. Nothing here
/// accuses her and nothing dead-ends.
///
/// The card is **amber, not error**. Amber is the product's "a caution that is
/// not a failure"; red is reserved for genuine problems and medical guidance.
/// Using the error variant here would turn waiting into an accusation with one
/// word of code.
///
/// ## Two owner decisions rewrote this screen
///
/// **Nothing of hers is in a queue being looked at.** The photographs are
/// deleted outright when the check finishes, whatever the outcome, so there is
/// no encrypted bundle and no reviewer studying her ID card. Review is a short
/// video call with a woman, the same two minutes `C15` already offers. The old
/// headline, "A woman reviewer is looking", described a model that no longer
/// exists and would have been a lie on the one screen where she is most
/// reliant on being told the truth.
///
/// **The gate is the whole app, not only the community.** This screen used to
/// carry three rows promising that workouts, recipes and coach profiles were
/// open while she waited. They are not, so they are gone, and the copy says
/// what is actually true: the app opens when the check is done.
///
/// The three `onOpen…` callbacks that used to open workouts, recipes and coach
/// profiles are **gone**, in the same change that closed the rest of the app:
/// `AppRouter.verificationGate` now refuses every product route to an account
/// that has not passed the check, so those three rows would have been doors
/// onto a screen that turns her straight back. A callback wired to nothing is
/// not harmless, it is a row waiting to be drawn again by somebody who finds
/// it, and this is the screen where a row that goes nowhere costs the most.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';

class BeingCheckedView extends StatelessWidget {
  const BeingCheckedView({super.key, this.onSelectTab});

  /// The bottom bar. It is drawn because the design draws it and because a
  /// screen with no bar reads as a modal she is trapped in, and every tab it
  /// offers lands back here while the check is running — which is the gate
  /// saying the same thing twice rather than a dead control.
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'T01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        // No lead: there is nowhere to step back to, and nothing to undo.
        appBar: AppTopBar(title: l10n.beingChecked),
        children: [
          AppCard(
            variant: AppCardVariant.amber,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.hourglass_top,
                    size: 26,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aShortVideoCallWithAWoman,
                          style: AppText.titleM,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.weWillTextYouATimeIt,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Rule 7, at the moment she is most likely to wonder where her
          // photographs went. Nothing was filed, nothing is waiting, nobody is
          // looking at a picture of her.
          Text(
            l10n.nothingYouPhotographedIsStoredItWas,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          // The closed door, named as the point rather than as a punishment.
          // It is the whole app now, not only the community.
          Text(
            l10n.theAppOpensAsSoonAsYour,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
