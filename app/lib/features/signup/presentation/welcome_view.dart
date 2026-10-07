/// C01 — Welcome. The first screen a woman ever sees.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C01`. Two departures from the
/// prototype markup, both deliberate:
///
///  * The prototype's drawn status bar is device chrome, not product UI. See
///    [AppScaffold].
///  * The prototype shows the word "logotype" in a monospace face — a designer's
///    annotation marking where the wordmark goes, not copy. The i18n extractor
///    swept it into the dictionary and even produced an Arabic translation for
///    it, which is how you can tell it was never meant to be read aloud. The
///    product is named now, so the slot holds the name until there is an asset.
///
/// It says what the app does in one line while the community is off ("Your
/// training, your food, your cycle. Women only."), and its first button is
/// "Show me around": a short tour of the real app with a sample week (`C04`),
/// before she is asked for anything. The line under it says so plainly: no
/// account, nothing saved. "Skip the tour and join" is for the woman who
/// already knows she wants in, and starts with her week before her number.
/// The language is two chips at the top rather than a screen of its own.
///
/// A woman who built her week before signing up and then stopped has her
/// answers, her life stage among them, kept on this phone. "Delete what I
/// saved on this phone" is her way to remove them without an account, asked
/// once in a sheet before anything is deleted.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/hand.dart';
import '../domain/locale_preference.dart';
import 'language_view.dart' show LanguageToggle;

class WelcomeView extends StatelessWidget {
  const WelcomeView({
    super.key,
    this.onLookAround,
    this.onGetStarted,
    this.onSignIn,
    this.preference,
    this.onDeleteSaved,
    this.onCoachInterest,
    this.onInviteCode,
  });

  /// Where her language is kept. Null draws no language chips.
  final LocalePreference? preference;

  /// The Own Hub tile, with its 2.0x and 3.0x variants beside it.
  static const String logoAsset = 'assets/brand/logo/ownhub-tile.png';

  /// "Show me around": the tour, `C04`.
  final VoidCallback? onLookAround;

  /// "Skip the tour and join": her week, then her number.
  final VoidCallback? onGetStarted;
  final VoidCallback? onSignIn;

  /// Deletes what she saved on this phone before she had an account. Null,
  /// which is the case unless she is signed out with her week built here,
  /// draws no button.
  final Future<void> Function()? onDeleteSaved;

  /// "I coach women": the coach interest form, while the coach app is off and
  /// `C08` is not asked. Null draws no link.
  final VoidCallback? onCoachInterest;

  /// "I have a code from my coach", while the coach app is on. Null draws no
  /// link.
  final VoidCallback? onInviteCode;

  /// Asks before deleting. Keeping is the filled answer: nothing is lost by
  /// tapping it by mistake.
  Future<void> _confirmDelete(BuildContext context) async {
    final delete = onDeleteSaved;
    if (delete == null) return;
    final l10n = AppL10n.of(context);
    final confirmed = await showAppSheet<bool>(
      context: context,
      children: [
        Text(l10n.deleteWhatYouSavedOnThisPhone, style: AppText.titleL),
        Text(
          l10n.yourWeekYourLifeStageAndAnything,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppButton(
          l10n.keepIt,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          l10n.deleteIt,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    await delete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      // Spacers centre the content optically, so this is not a plain scroll
      // view — it fills the viewport and scrolls only when it must.
      scrollable: false,
      footer: [
        AppButton(l10n.showMeAround, onPressed: onLookAround),
        // What the tour is, said before she takes it: nothing is asked of her
        // and nothing she does in it is kept.
        Text(
          l10n.theTourUsesASampleWeekNo,
          textAlign: TextAlign.center,
          style: AppText.bodyM.copyWith(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        AppButton(
          l10n.skipTheTourAndJoin,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onGetStarted,
        ),
        AppButton(
          l10n.iAlreadyHaveAnAccount,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onSignIn,
        ),
        if (onInviteCode != null)
          AppButton(
            l10n.iHaveACodeFromMyCoach,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: onInviteCode,
          ),
        if (onCoachInterest != null)
          AppButton(
            l10n.iCoachWomen,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: onCoachInterest,
          ),
        if (onDeleteSaved != null)
          AppButton(
            l10n.deleteWhatISavedOnThisPhone,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: () => _confirmDelete(context),
          ),
      ],
      children: [
        // The kitten waves hello from the top row, in space the screen was
        // not using, so nothing below it moves. A wrap, so at the largest
        // text sizes the language toggle takes a line of its own.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            const Kitten(pose: KittenPose.wave, size: 52, moment: 'C01'),
            if (preference case final preference?)
              LanguageToggle(preference: preference),
          ],
        ),
        const AppSpacer(),
        // The brand mark, the Concept 02 monogram on the rose tile, as on the
        // home screen. Rendered from the vector at 1x, 2x and 3x, so it is
        // drawn at its own size and never scaled. Decorative: the name is
        // read out from the caption below it.
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              WelcomeView.logoAsset,
              width: 88,
              height: 88,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),
        // The mark has no wordmark of its own, so the name stays under it.
        Text(
          'Own Hub',
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(
            fontSize: 13,
            letterSpacing: 0.4,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // The cover line, set at editorial scale and underlined once by
          // hand — the first ink she sees. Sized to its longest line so the
          // underline sits under the words rather than across the column.
          child: Center(
            child: HandUnderline(
              level: HandLevel.signature,
              width: HandStroke.felt,
              drawOn: true,
              delay: const Duration(milliseconds: 240),
              gap: 6,
              child: Text(
                // What the app does, while the room it used to promise is
                // switched off.
                AppRouter.featureFlags.isOn(Feature.community)
                    ? l10n.aRoomFullOfWomenTrainingLike
                    : l10n.yourTrainingYourFoodYourCycleWomen,
                textAlign: TextAlign.center,
                textWidthBasis: TextWidthBasis.longestLine,
                style: EditorialType.cover,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            // The community is a promise only while it is switched on. Off,
            // the line keeps what is true at launch: the space is women only
            // because every account passes the check.
            AppRouter.featureFlags.isOn(Feature.community)
                ? l10n.quietWorkoutsForHomeFoodYouAlready
                : l10n.quietWorkoutsForHomeFoodYouAlready_u7fo9,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(
              height: 24 / 16,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const AppSpacer(),
      ],
    );
  }
}
