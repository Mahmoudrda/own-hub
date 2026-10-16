/// What the tour draws around the real screens: the sample badge with the way
/// in, the coach card that says what each screen is for, the end card, and the
/// join sheet.
///
/// None of it is inside `DemoScope`. Every control here is one of the tour's
/// exits or its own Back and Next, and none of them can reach a product
/// screen.
library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_pill.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../../ui/app_sheet.dart';
import '../../../../ui/hand/hand.dart';

/// "Sample · nothing is saved", the way in, and the way out.
///
/// On every stop and on the end card, so she is never one screen away from
/// knowing that this week is not hers, or from joining.
class DemoBadgeBar extends StatelessWidget {
  const DemoBadgeBar({
    super.key,
    required this.joinLabel,
    this.onJoin,
    this.onLeave,
  });

  /// "Join Own Hub", or "Back to my check" for a woman already waiting on it.
  final String joinLabel;
  final VoidCallback? onJoin;

  /// Leaves the tour. Null draws no close button.
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final badge = AppPill(
      l10n.sampleNothingIsSaved,
      icon: Icons.visibility_outlined,
      background: AppColors.amberContainer,
      foreground: AppColors.amber,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flexible, so at the largest text sizes the label wraps inside the
        // button rather than pushing the close button off the screen.
        Flexible(
          // Its own width, not the row's: a button left to fill the space
          // would push the badge onto a line of its own at every size.
          child: IntrinsicWidth(
            child: AppButton(
              joinLabel,
              variant: AppButtonVariant.tonal,
              height: 44,
              fontSize: 15,
              onPressed: onJoin,
            ),
          ),
        ),
        if (onLeave != null)
          IconButton(
            tooltip: l10n.leaveTheTour,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.close),
            onPressed: onLeave,
          )
        else
          const SizedBox(width: 12),
      ],
    );

    // One line when the two fit, and the way in drops under the badge when
    // they do not: a longer language or a larger text size must never cut
    // the badge short, because the badge is the one thing here that has to
    // be read whole.
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 2,
          spacing: 8,
          children: [badge, actions],
        ),
      ),
    );
  }
}

/// One stop's explanation: where she is in the tour, what this screen is,
/// and Back and Next.
///
/// One short card at the top rather than a spotlight over the screen. The
/// screen under it stays hers to tap.
class DemoCoachCard extends StatelessWidget {
  const DemoCoachCard({
    super.key,
    required this.number,
    required this.total,
    required this.title,
    required this.line,
    this.onBack,
    this.onNext,
    this.guide = true,
  });

  /// One-based.
  final int number;
  final int total;
  final String title;
  final String line;

  /// Null on the first stop, where the close button is the way back.
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  /// Whether the kitten points at this stop. Off on the check-in stop: nothing
  /// reacts to how she feels.
  final bool guide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.countOfTotal(countLabel(number), countLabel(total)),
          style: AppText.label.copyWith(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // Read out when the stop changes, so a woman using a screen reader
        // hears where Next took her.
        Semantics(
          liveRegion: true,
          header: true,
          child: Text(title, style: AppText.titleM),
        ),
      ],
    );

    return AppCard(
      variant: AppCardVariant.tonal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      gap: 4,
      children: [
        if (guide)
          Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 8),
              // Points into the screen below, once each time Next moves on.
              Kitten(pose: KittenPose.point, size: 48, replayKey: number),
            ],
          )
        else
          heading,
        Text(line, style: AppText.bodyM.copyWith(color: AppColors.onSurface)),
        Row(
          mainAxisAlignment: onBack == null
              ? MainAxisAlignment.end
              : MainAxisAlignment.spaceBetween,
          children: [
            if (onBack != null)
              Flexible(
                child: IntrinsicWidth(
                  child: AppButton(
                    l10n.back,
                    variant: AppButtonVariant.text,
                    height: 44,
                    fontSize: 15,
                    onPressed: onBack,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: IntrinsicWidth(
                child: AppButton(
                  l10n.next,
                  variant: AppButtonVariant.outlined,
                  height: 44,
                  fontSize: 15,
                  onPressed: onNext,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// After the last stop: what joining involves, said before she starts it.
class DemoEndCard extends StatelessWidget {
  const DemoEndCard({
    super.key,
    required this.joinLabel,
    this.onJoin,
    this.onAgain,
    this.onSignIn,
  });

  /// "Make it mine", or "Back to my check" for a woman already waiting on it.
  final String joinLabel;
  final VoidCallback? onJoin;
  final VoidCallback? onAgain;

  /// Null draws no sign-in link: a woman waiting on her check already has an
  /// account.
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    Widget step(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: AppColors.primaryDim),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppText.body.copyWith(color: AppColors.onSurface),
          ),
        ),
      ],
    );

    return AppScaffold(
      footerScrollsWhenLarge: true,
      footer: [
        AppButton(joinLabel, onPressed: onJoin),
        AppButton(
          l10n.seeTheTourAgain,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          onPressed: onAgain,
        ),
        if (onSignIn != null)
          AppButton(
            l10n.iAlreadyHaveAnAccount,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: onSignIn,
          ),
      ],
      children: [
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          header: true,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: HandUnderline(
                    level: HandLevel.signature,
                    width: HandStroke.felt,
                    gap: 6,
                    child: Text(
                      l10n.thatsOwnHub,
                      style: EditorialType.section,
                    ),
                  ),
                ),
              ),
              // The end of the tour: one small cheer.
              const Kitten(pose: KittenPose.cheer, size: 56),
            ],
          ),
        ),
        const SizedBox(height: 4),
        step(Icons.phone_iphone, l10n.toMakeItYoursJoinWithYour),
        step(Icons.verified_user_outlined, l10n.ownHubIsForWomenOnlySo),
        step(Icons.event_note_outlined, l10n.firstOneScreenToBuildYourWeek),
      ],
    );
  }
}

/// "Join to make this yours", over the stop she was on.
///
/// Raised by every real action in the tour: starting a workout, logging a
/// set or a meal, opening a screen the sample does not carry. "Keep looking"
/// leaves her exactly where she was.
///
/// For a woman already signed up and waiting on her check, the sheet says the
/// app opens when the check is done, and its button takes her back to it.
///
/// Join opens her week first, so the sheet says so. When her week is already
/// built ([setupDone]), Join goes straight on to her number, and the sheet
/// says that instead.
Future<void> showJoinSheet(
  BuildContext context, {
  required bool waiting,
  bool setupDone = false,
  VoidCallback? onJoin,
}) {
  final l10n = AppL10n.of(context);
  return showAppSheet<void>(
    context: context,
    children: [
      Text(
        waiting ? l10n.theAppOpensAsSoonAsYour : l10n.joinToMakeThisYours,
        style: AppText.titleL,
      ),
      if (!waiting)
        Text(
          setupDone
              ? l10n.weJustNeedYourNumberAndA_1vu4x
              : l10n.firstYourWeekThenYourNumberAnd_10ray,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      AppButton(
        waiting ? l10n.backToMyCheck : l10n.joinOwnHub,
        onPressed: () {
          Navigator.of(context).pop();
          onJoin?.call();
        },
      ),
      AppButton(
        l10n.keepLooking,
        variant: AppButtonVariant.text,
        height: 44,
        fontSize: 15,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
