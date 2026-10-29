/// The agreement in plain points: the apply flow's terms step and the coach
/// space's gate sheet read the same lines, so they cannot drift apart.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/coach_agreement.dart';

List<String> coachAgreementPoints(AppL10n l10n) => <String>[
  l10n.ownHubReviewsEveryCoachBeforeShe,
  l10n.everythingYouTellUsMustBeAccurate,
  l10n.photosOfClientsAreSharedOnlyWith,
  l10n.ownHubTakesFullOfThePackage(
    CoachAgreementFacts.marketplacePercent,
    CoachAgreementFacts.invitePercent,
  ),
  l10n.payOwnHubItsShareWithinDays(
    '${CoachAgreementFacts.payWithinDays}',
    '${CoachAgreementFacts.holdAfterDays}',
  ),
  l10n.makeVideosShortVideosForOwnHub('${CoachAgreementFacts.videosPerMonth}'),
  l10n.keepEveryChatInsideTheAppAnd,
  l10n.doNotWorkWithAClientYou('${CoachAgreementFacts.keepClientsMonths}'),
];
