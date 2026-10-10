// Every promise made before she is verified depends on the flag for the
// feature it describes.
//
// A real-device walk of the release build found the welcome line promising a
// community, C03 promising coaches paid in pounds and C04 offering a Coaches
// tab, all with those features switched off. Each case below proves two things
// in the release shape (sign-up and verification on; community, coach app,
// marketplace, payments and assistant off): the claim about a dark feature is
// gone, and a true line stands in its place. Then it turns on ONLY the flag the
// claim depends on and proves the original promise comes back by itself.
//
// The world is built from `FeatureFlags.allOff` with every switch named, as
// `flag_independence_test.dart` requires, so these cases do not move when the
// shipped defaults do. That the release build has those features dark is
// asserted in `release_readiness_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/signup/presentation/phone_number_view.dart';
import 'package:own_hub/features/signup/presentation/pledge_view.dart';
import 'package:own_hub/features/signup/presentation/role_view.dart';
import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/features/signup/presentation/whats_inside_view.dart';
import 'package:own_hub/features/signup/presentation/why_we_check_view.dart';
import 'package:own_hub/features/signup/presentation/youre_in_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

final AppL10n en = lookupAppL10n(const Locale('en'));
final AppL10n ar = lookupAppL10n(const Locale('ar'));

/// The release shape for the switches these screens read.
final FeatureFlags _release = FeatureFlags.allOff.with_(const {
  Feature.accountRequired: true,
  Feature.signUp: true,
  Feature.verification: true,
  Feature.community: false,
  Feature.coachApp: false,
  Feature.marketplace: false,
  Feature.payments: false,
  Feature.assistant: false,
});

const Map<Feature, bool> _community = {Feature.community: true};
const Map<Feature, bool> _coachApp = {Feature.coachApp: true};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Map<Feature, bool> on = const {},
  Locale locale = const Locale('en'),
}) async {
  final before = AppRouter.featureFlags;
  addTearDown(() => AppRouter.featureFlags = before);
  AppRouter.featureFlags = _release.with_(on);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('C01 Welcome', () {
    testWidgets(
      'release flags: no community, a space only verified women enter',
      (tester) async {
        await _pump(tester, const WelcomeView());
        expect(find.text(en.quietWorkoutsForHomeFoodYouAlready), findsNothing);
        expect(
          find.text(en.quietWorkoutsForHomeFoodYouAlready_u7fo9),
          findsOneWidget,
        );
        expect(find.textContaining('community'), findsNothing);
      },
    );

    testWidgets('release flags, Arabic: the same true line', (tester) async {
      await _pump(tester, const WelcomeView(), locale: const Locale('ar'));
      expect(find.text(ar.quietWorkoutsForHomeFoodYouAlready), findsNothing);
      expect(
        find.text(ar.quietWorkoutsForHomeFoodYouAlready_u7fo9),
        findsOneWidget,
      );
    });

    testWidgets('community on: the community promise returns', (tester) async {
      await _pump(tester, const WelcomeView(), on: _community);
      expect(find.text(en.quietWorkoutsForHomeFoodYouAlready), findsOneWidget);
    });
  });

  group("C03 What's inside", () {
    testWidgets('release flags: no posts, no coaches row', (tester) async {
      await _pump(tester, const WhatsInsideView());
      expect(find.text(en.everyAccountIsVerifiedWithIdBefore), findsNothing);
      expect(
        find.text(en.everyAccountIsVerifiedWithIdBefore_p7ucu),
        findsOneWidget,
      );
      expect(find.text(en.coachesWhoGetIt), findsNothing);
      expect(
        find.text(en.verifiedWomenCoachesPaidMonthlyInEgyptian),
        findsNothing,
      );
    });

    testWidgets('release flags, Arabic: no coaches row, no posts', (
      tester,
    ) async {
      await _pump(tester, const WhatsInsideView(), locale: const Locale('ar'));
      expect(find.text(ar.coachesWhoGetIt), findsNothing);
      expect(find.text(ar.everyAccountIsVerifiedWithIdBefore), findsNothing);
      expect(
        find.text(ar.everyAccountIsVerifiedWithIdBefore_p7ucu),
        findsOneWidget,
      );
    });

    testWidgets('community on: the post line returns', (tester) async {
      await _pump(tester, const WhatsInsideView(), on: _community);
      expect(find.text(en.everyAccountIsVerifiedWithIdBefore), findsOneWidget);
    });

    testWidgets('coach app on but no payment rail: still no coaches row', (
      tester,
    ) async {
      await _pump(tester, const WhatsInsideView(), on: _coachApp);
      expect(find.text(en.coachesWhoGetIt), findsNothing);
    });

    testWidgets('coach app, marketplace and payments on: the row returns', (
      tester,
    ) async {
      await _pump(
        tester,
        const WhatsInsideView(),
        on: const {
          Feature.coachApp: true,
          Feature.marketplace: true,
          Feature.payments: true,
        },
      );
      expect(find.text(en.coachesWhoGetIt), findsOneWidget);
      expect(
        find.text(en.verifiedWomenCoachesPaidMonthlyInEgyptian),
        findsOneWidget,
      );
    });
  });

  group('C04 the tour', () {
    // The tour draws the product's own screens, so the product's own flags
    // are on here, as they are at launch.
    const product = {
      Feature.today: true,
      Feature.train: true,
      Feature.eat: true,
      Feature.progress: true,
      Feature.cycle: true,
    };

    testWidgets('release flags: nothing switched off is shown; Join stays', (
      tester,
    ) async {
      var joined = 0;
      await _pump(
        tester,
        LookAroundView(onJoin: () => joined++),
        on: product,
      );
      expect(find.text(en.community), findsNothing);
      expect(find.text(en.coaches), findsNothing);
      expect(find.byTooltip(en.askSomething), findsNothing);
      expect(find.text(en.sampleNothingIsSaved), findsOneWidget);
      await tester.tap(find.text(en.joinOwnHub));
      expect(joined, 1);
    });

    testWidgets('release flags, Arabic: the same, in her language', (
      tester,
    ) async {
      await _pump(
        tester,
        const LookAroundView(),
        on: product,
        locale: const Locale('ar'),
      );
      expect(find.text(ar.community), findsNothing);
      expect(find.text(ar.sampleNothingIsSaved), findsOneWidget);
      expect(find.text(ar.joinOwnHub), findsOneWidget);
    });

    testWidgets('coach app on: still no coach in the tour', (tester) async {
      await _pump(
        tester,
        const LookAroundView(),
        on: {...product, ..._coachApp},
      );
      expect(find.text(en.coaches), findsNothing);
    });

    testWidgets('community on: the real bar carries it, behind the join', (
      tester,
    ) async {
      await _pump(
        tester,
        const LookAroundView(),
        on: {...product, ..._community},
      );
      expect(find.text(en.community), findsOneWidget);
      await tester.tap(find.text(en.community));
      await tester.pumpAndSettle();
      expect(find.text(en.joinToMakeThisYours), findsOneWidget);
    });
  });

  group('C06 Phone number', () {
    Widget view() => PhoneNumberView(repository: FakeAuthRepository());

    testWidgets('release flags: the Terms and Privacy, not community rules', (
      tester,
    ) async {
      await _pump(tester, view());
      expect(find.text(en.byJoiningYouAgreeToTheCommunity), findsNothing);
      expect(find.text(en.byTappingAgreeAndSendMeA), findsOneWidget);
    });

    testWidgets('release flags, Arabic', (tester) async {
      await _pump(tester, view(), locale: const Locale('ar'));
      expect(find.text(ar.byTappingAgreeAndSendMeA), findsOneWidget);
    });

    testWidgets('community on: community rules return', (tester) async {
      await _pump(tester, view(), on: _community);
      expect(find.text(en.byJoiningYouAgreeToTheCommunity), findsOneWidget);
    });
  });

  group('C08 Role', () {
    testWidgets('release flags: no community in the trainee card', (
      tester,
    ) async {
      await _pump(tester, const RoleView(offerCoach: false));
      expect(find.text(en.workoutsRecipesAndTheCommunityFree), findsNothing);
      expect(find.text(en.workoutsRecipesAndYourProgressFree), findsOneWidget);
    });

    testWidgets('release flags, Arabic', (tester) async {
      await _pump(
        tester,
        const RoleView(offerCoach: false),
        locale: const Locale('ar'),
      );
      expect(find.text(ar.workoutsRecipesAndYourProgressFree), findsOneWidget);
    });

    testWidgets('community on: the community returns', (tester) async {
      await _pump(tester, const RoleView(offerCoach: false), on: _community);
      expect(find.text(en.workoutsRecipesAndTheCommunityFree), findsOneWidget);
    });
  });

  group('C09 Why we check', () {
    testWidgets('release flags: women only, without the community', (
      tester,
    ) async {
      await _pump(tester, const WhyWeCheckView());
      expect(find.text(en.thisIsTheWholeReasonTheCommunity), findsNothing);
      expect(find.text(en.thisIsWhatKeepsOwnHubWomen), findsOneWidget);
    });

    testWidgets('release flags, Arabic', (tester) async {
      await _pump(tester, const WhyWeCheckView(), locale: const Locale('ar'));
      expect(find.text(ar.thisIsWhatKeepsOwnHubWomen), findsOneWidget);
    });

    testWidgets('community on: the community line returns', (tester) async {
      await _pump(tester, const WhyWeCheckView(), on: _community);
      expect(find.text(en.thisIsTheWholeReasonTheCommunity), findsOneWidget);
    });
  });

  group("C13 You're in", () {
    testWidgets('release flags: no coach set-up, no members', (tester) async {
      await _pump(tester, const YoureInView());
      expect(find.text(en.imACoachSetUpMyProfile), findsNothing);
      expect(find.text(en.yourNumberYourIdYourMealsAnd), findsNothing);
      expect(find.text(en.yourNumberYourIdYourMealsAnd_1ix08), findsOneWidget);
    });

    testWidgets('release flags, Arabic', (tester) async {
      await _pump(tester, const YoureInView(), locale: const Locale('ar'));
      expect(find.text(ar.setUpMyCoachProfile), findsNothing);
      expect(find.text(ar.yourNumberYourIdYourMealsAnd_1ix08), findsOneWidget);
    });

    testWidgets('coach app on: the coach set-up returns', (tester) async {
      await _pump(tester, const YoureInView(), on: _coachApp);
      expect(find.text(en.setUpMyCoachProfile), findsOneWidget);
    });

    testWidgets('community on: the members line returns', (tester) async {
      await _pump(tester, const YoureInView(), on: _community);
      expect(find.text(en.yourNumberYourIdYourMealsAnd), findsOneWidget);
    });
  });

  group('C16 Pledge', () {
    testWidgets('release flags: rule 3 names no coach profiles', (
      tester,
    ) async {
      await _pump(tester, const PledgeView());
      expect(find.text(en.coachesHaveProfilesForThat), findsNothing);
      expect(find.text(en.ownHubIsForTrainingNotFor), findsOneWidget);
    });

    testWidgets('release flags, Arabic', (tester) async {
      await _pump(tester, const PledgeView(), locale: const Locale('ar'));
      expect(find.text(ar.ownHubIsForTrainingNotFor), findsOneWidget);
    });

    testWidgets('coach app on: coach profiles return', (tester) async {
      await _pump(tester, const PledgeView(), on: _coachApp);
      expect(find.text(en.coachesHaveProfilesForThat), findsOneWidget);
    });
  });
}
