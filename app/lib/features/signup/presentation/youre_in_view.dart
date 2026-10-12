/// C13 — You're in.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C13`. The payoff screen: what she
/// has actually bought is a room where everyone passed the same check, so that
/// is what it says. **Rule 7 is restated here**, at the moment she is most
/// likely to believe it — the ID photo and the selfie have been deleted and only
/// the result was kept. That sentence is true: `domain/id_capture.dart` never
/// holds an image, and `VerificationResult` has no field one could be stored in.
///
/// ## The greeting, and why it does not take a name
///
/// The design reads "You're in, Mai" — the prototype's sample name. The
/// dictionary now holds two messages instead: a parameterised
/// `youreInName({name})` and a nameless `youreIn`, so the screen can greet her
/// by her own name or say a whole sentence when it does not have one.
///
/// Historical note, kept because it explains the shape: this line used to be a
/// single frozen string with the sample name inside it, and the view
/// deliberately accepted no name at all rather than render "You're in, null".
/// That is fixed. What remains true is why there are two strings rather than one
/// with an empty substitution — Arabic greets with the vocative يا, and a
/// dangling يا with nothing after it reads as broken.
///
/// (Superseded description follows.) The dictionary's key for that line is
/// `youreInMai`, with the prototype's sample name **baked into the string** in
/// both languages ("You're in, Mai" / "أهلًا بك يا مي"), and the generated
/// `AppL10n` contains **no parameterised messages at all** — not one of its 1,789
/// entries takes a placeholder.
///
/// So this view deliberately takes no `firstName`:
///
///  * Interpolating a name would mean splitting a translated sentence or
///    hardcoding the separator and the sample name in Arabic, which the i18n
///    guard forbids and which would read as nonsense in one language or the
///    other.
///  * The absent case is therefore not merely handled, it is **unreachable**:
///    there is no code path here that can render "You're in, null", because
///    nothing is interpolated.
///
/// This matches G1's own open question 1, which proposes that `C13` says "You're
/// in" until she has typed a name in G2's setup — `profile.firstName` is
/// collected *after* verification, so at this moment the product does not know
/// her name. **What is needed is a dictionary change, not a widget change:** a
/// nameless `youreIn` key plus a parameterised `youreInName` taking `{name}`,
/// in both languages. Until those exist the screen shows the dictionary's line
/// as designed.
///
/// The same applies to "Verified in 74 seconds": the duration is baked into
/// `verifiedIn74SecondsYourIdPhoto` and cannot yet reflect the real
/// `decidedAt − submittedAt`.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'widgets/verification_bullet.dart';

class YoureInView extends StatelessWidget {
  const YoureInView({
    super.key,
    this.firstName,
    this.verifiedInSeconds,
    this.onReadTheRules,
    this.onCoachSetup,
    this.onStartDay1,
    this.onGoHome,
    this.isCoach = true,
    this.alsoTrains = true,
  });

  /// "Start day 1": the first workout, over Home. The primary while the
  /// community is off, because a pledge about a room that does not exist yet
  /// is the wrong thing to hand her at this moment.
  final VoidCallback? onStartDay1;

  /// "Go to Home", the quieter way on.
  final VoidCallback? onGoHome;

  /// Whether she signed up as a coach (or as both). The coach link is hers
  /// only; a trainee is not offered a profile setup she did not ask for.
  final bool isCoach;

  /// Whether she trains here too (she chose "both"). A coach's primary action
  /// is her profile; for a woman who also trains, the trainee way on stays as
  /// the second action. A coach only is not offered day one of a programme she
  /// did not ask for.
  final bool alsoTrains;

  /// Her name, if she has given one. Null is expected and handled: setup runs
  /// after verification, so on a first run she usually has no name yet.
  final String? firstName;

  /// How long the check actually took, or null when it was never timed.
  ///
  /// This used to default to **74** — the prototype's sample — so every woman
  /// reaching this screen was told a specific, invented fact about her own
  /// verification. Nothing anywhere recorded a start time, so there was no real
  /// number available to replace it with; `VerificationChecking.startedAt` now
  /// provides one and `VerificationResult.took` measures it.
  ///
  /// Null renders the same rule-7 promise without a duration. A sentence that
  /// says less is better than one that says something untrue, and this screen
  /// is the moment she is most likely to believe what it tells her.
  final int? verifiedInSeconds;

  /// On to `C16`, the community pledge, while the community is on. The
  /// community does not open until she has accepted it.
  final VoidCallback? onReadTheRules;

  /// A coach's branch: `K01`, her profile setup.
  final VoidCallback? onCoachSetup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final community = AppRouter.featureFlags.isOn(Feature.community);
    // She signed up to coach: her profile is the next thing she does, so it is
    // the primary. K01 is the coach app's first screen, and with the coach app
    // off it would open the "not in this build" panel, so it is offered only
    // while the coach app is on. The community's rules are part of K01 for a
    // coach, so her way on does not pass through C16.
    final coachFirst = isCoach && AppRouter.featureFlags.isOn(Feature.coachApp);
    final trainee = !coachFirst || alsoTrains;
    final traineeVariant = coachFirst
        ? AppButtonVariant.outlined
        : AppButtonVariant.filled;

    return AppScaffold(
      scrollable: false,
      footer: [
        if (coachFirst)
          AppButton(
            l10n.setUpMyCoachProfile,
            icon: Icons.badge_outlined,
            onPressed: onCoachSetup,
          ),
        if (trainee && community)
          AppButton(
            l10n.readTheThreeRules,
            variant: traineeVariant,
            onPressed: onReadTheRules,
          ),
        if (trainee && !community) ...[
          AppButton(
            l10n.startDay1,
            icon: Icons.play_arrow,
            variant: traineeVariant,
            onPressed: onStartDay1,
          ),
          AppButton(
            l10n.goToHome,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: onGoHome,
          ),
        ],
      ],
      children: [
        const AppSpacer(),
        // The one mark on the payoff screen: the seal circled in sage as it
        // arrives. Sage because this is done, not won.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HandCircled(
              seed: 13,
              color: HandInk.done,
              width: HandStroke.felt,
              level: HandLevel.signature,
              inflate: const EdgeInsets.all(7),
              drawOn: true,
              delay: const Duration(milliseconds: 200),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified,
                  size: 52,
                  color: AppColors.tertiary,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // The end of onboarding: the kitten's one cheer.
            const Kitten(pose: KittenPose.cheer, size: 72, moment: 'C13'),
          ],
        ),
        Text(
          // Her name when she has given one, and a complete sentence when she
          // has not. profile.firstName is collected during setup, which runs
          // AFTER this screen, so nameless is the common case on a first run —
          // not an edge case.
          //
          // Two separate strings rather than substituting an empty name: Arabic
          // greets with a vocative ("أهلًا بك يا {name}"), and a dangling يا
          // with nothing after it reads as broken.
          (firstName == null || firstName!.trim().isEmpty)
              ? l10n.youreIn
              : l10n.youreInName(firstName!.trim()),
          textAlign: TextAlign.center,
          // Cover scale, as on C01: the first and last pages of sign-up are
          // set the same.
          style: EditorialType.cover,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            // Rule 7, stated to her face: the images are gone. What stays is
            // said whole: the result, its reasons and the keyed code of her ID
            // number, as C09b disclosed. "The result and nothing else" was
            // untrue. The duration is claimed only when it was measured.
            verifiedInSeconds == null
                ? l10n.yourIdPhotoAndSelfieHaveBeen_1qfoh
                : l10n.verifiedInSecondsSecondsYourIdPhoto_mbpt8(
                    verifiedInSeconds!,
                  ),
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(
              height: 24 / 16,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        AppCard(
          variant: AppCardVariant.sage,
          gap: 10,
          children: [
            VerificationBullet(
              icon: Icons.groups,
              text: l10n.everyWomanHereWentThroughTheSame,
            ),
            VerificationBullet(
              icon: Icons.visibility_off,
              // "Members" are the community's; with it off there is nobody
              // to be shown to, so the line says what is true.
              text: AppRouter.featureFlags.isOn(Feature.community)
                  ? l10n.yourNumberYourIdYourMealsAnd
                  : l10n.yourNumberYourIdYourMealsAnd_1ix08,
            ),
          ],
        ),
        const AppSpacer(),
      ],
    );
  }
}
