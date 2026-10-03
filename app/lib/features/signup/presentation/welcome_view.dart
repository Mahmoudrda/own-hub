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
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, this.onGetStarted, this.onSignIn});

  /// The Own Hub tile, with its 2.0x and 3.0x variants beside it.
  static const String logoAsset = 'assets/brand/logo/ownhub-tile.png';

  final VoidCallback? onGetStarted;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      // Spacers centre the content optically, so this is not a plain scroll
      // view — it fills the viewport and scrolls only when it must.
      scrollable: false,
      footer: [
        AppButton(l10n.getStarted, onPressed: onGetStarted),
        AppButton(
          l10n.iAlreadyHaveAnAccount,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onSignIn,
        ),
      ],
      children: [
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
                l10n.aRoomFullOfWomenTrainingLike,
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
