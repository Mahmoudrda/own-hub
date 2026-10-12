// The compliance plan's copy and data rules, held in one place:
//   M6  "not a medical device", in both languages, where it must appear;
//   M7  the claims the plan retired stay retired;
//   M8  the privacy mailbox the app writes to is the one the site publishes;
//   M10 her Ramadan setting never leaves the phone;
//   1.4 no copy promises a video call, and the review window is the server's.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/config/legal_links.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/features/eat/presentation/type_it_view.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/life_stage_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/medical_disclaimer.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('M6: not a medical device', () {
    test('the sentence is in both dictionaries', () {
      expect(
        _arb('en').values
            .whereType<String>()
            .any((v) => v.contains('It is not a medical device')),
        isTrue,
      );
      expect(
        _arb('ar').values
            .whereType<String>()
            .any((v) => v.contains('وليس جهازًا طبيًا')),
        isTrue,
      );
    });

    test('it is placed on every screen the plan names', () {
      for (final path in <String>[
        'lib/features/account/presentation/profile_view.dart',
        'lib/features/cycle/presentation/cycle_hub_view.dart',
        'lib/features/cycle/presentation/cycle_setup_view.dart',
        'lib/features/onboarding/presentation/life_stage_view.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('MedicalDisclaimer()'),
          reason: path,
        );
      }
    });

    test('every screen that asks about a pregnancy places it', () {
      // The short "Your week" used to ask on O03, which put O03 on the list
      // above. Both walks ask on O04 now; this holds the rule wherever the
      // four answers are drawn next.
      final askers = <String>[];
      for (final file in Directory('lib/features').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (!source.contains('lifeStageOptions(')) continue;
        askers.add(file.path);
        expect(source, contains('MedicalDisclaimer()'), reason: file.path);
      }
      expect(askers, isNotEmpty);
    });

    testWidgets('the life-stage question says it', (tester) async {
      await tester.pumpWidget(
        _host(LifeStageView(repository: InMemoryIntakeRepository())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(MedicalDisclaimer.marker),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('not a medical device'), findsOneWidget);
    });

    testWidgets('"Your week" says it when she is pregnant, in Arabic too', (
      tester,
    ) async {
      // The short walk asks about a pregnancy on O04, the same screen as the
      // full walk, before she has an account. The sentence is there before
      // she answers and still there once she says she is pregnant.
      OnboardingState.instance.beforeSignup = true;
      addTearDown(() => OnboardingState.instance.beforeSignup = false);
      for (final (locale, pregnant) in <(Locale, String)>[
        (const Locale('en'), 'Pregnant'),
        (const Locale('ar'), 'حامل'),
      ]) {
        await tester.pumpWidget(
          _host(
            LifeStageView(
              key: UniqueKey(),
              repository: InMemoryIntakeRepository(),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(MedicalDisclaimer.marker, skipOffstage: false),
          findsOneWidget,
        );
        final option = find.text(pregnant);
        await tester.scrollUntilVisible(
          option,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(option);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(MedicalDisclaimer.marker),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(MedicalDisclaimer.marker), findsOneWidget);
      }
    });
  });

  group('M7: the retired claims stay retired', () {
    test('no screen reads a superseded getter', () {
      final retired = <String>[
        'itTakesAbout90Seconds',
        'askForAVideoCheck',
        'aShortVideoCheck',
        'twoMinutesWithAWomanReviewerNothing',
        'aWomanOnTheTeam9amTo',
        'downloadingACopyOfYourDataIs',
        'byJoiningYouAgreeToTheOwn',
        'thePhotographsAreProcessedByGoogleCloud',
        'ifYourCheckIsApprovedOrRefused',
        'nothingYouPhotographIsKeptBothSides',
        'ifAWomanNeedsToCheckIt',
        // 1.4: no video service exists, so no screen may promise a call.
        'aShortVideoCallWithAWoman',
        'yourVideoCallIsBookedForTime',
        'aReviewerCanOnlyCallYouAfter',
        'aWomanReviewerFromOwnHubWill',
        'askForTheCall',
        'ifYouDoNotShowYourFace',
        'thisAccountHasUsedEveryAutomaticCheck',
        'yourPhoneNumberIsUsedOnlyTo',
        // R2-G5: the server keeps more than "the result and nothing else".
        'yourIdPhotoAndSelfieHaveBeen',
        'verifiedInSecondsSecondsYourIdPhoto',
        'bothImagesAreDeletedAfterTheCheck',
        // R1-P7 and R1-P8: a threat on the pledge, and a total time nobody
        // measured.
        'breakOneAndYouLoseYourPlace',
        'firstYourWeekThenYourNumberAnd',
        'weJustNeedYourNumberAndA',
        'usuallySecondsIfItNeedsAPerson',
      ];
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.contains('lib/l10n/')) continue;
        final source = file.readAsStringSync();
        for (final getter in retired) {
          if (RegExp('\\.$getter\\b').hasMatch(source)) {
            offenders.add('${file.path}: $getter');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('no copy promises a time it cannot keep', () {
      for (final path in <String>[
        'lib/features/signup/presentation/consent_view.dart',
        'lib/features/signup/presentation/why_we_check_view.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('usuallyACoupleOfMinutesIfA'),
          reason: path,
        );
      }
    });
  });

  group('M7: no microphone while the app never uses one', () {
    // The privacy policy and the site say the app never uses the microphone,
    // and the release manifest strips RECORD_AUDIO. Saying a meal (E03) is
    // behind Feature.voiceLogging, off in the shipped build.
    final saved = AppRouter.featureFlags;
    setUp(() => AppRouter.featureFlags = FeatureFlags.shipped);
    tearDown(() => AppRouter.featureFlags = saved);

    test('voice logging is off in the shipped build, and E03 with it', () {
      expect(FeatureFlags.shipped.isOn(Feature.voiceLogging), isFalse);
      expect(Feature.voiceLogging.parent, Feature.eat);
      expect(AppRouter.screenIsOn('E03'), isFalse);
      expect(AppRouter.screenIsOn('E02'), isTrue);
    });

    test('the release manifest still strips RECORD_AUDIO', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        RegExp(r'android\.permission\.RECORD_AUDIO"\s+tools:node="remove"')
            .hasMatch(manifest),
        isTrue,
      );
    });

    for (final lang in const ['en', 'ar']) {
      testWidgets('Eat and Type it draw no microphone ($lang)', (tester) async {
        final locale = Locale(lang);
        await tester.pumpWidget(
          _host(
            EatView(
              constraints: DietaryConstraints.none,
              now: DateTime(2026, 10, 12, 9, 30),
              onOpenRecipes: () {},
              onType: () {},
              onSpeak: () {},
              onSelectTab: (_) {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppL10n.of(tester.element(find.byType(EatView)));
        expect(find.byIcon(Icons.mic), findsNothing);
        expect(find.text(l10n.weNeedTheMicrophoneToHearWhat), findsNothing);
        expect(find.text(l10n.sayOrTypeWhatYouAte), findsNothing);
        expect(find.text(l10n.typeWhatYouAte), findsOneWidget);

        await tester.pumpWidget(
          _host(
            TypeItView(
              constraints: DietaryConstraints.none,
              now: DateTime(2026, 10, 12, 9, 30),
              onClose: () {},
              onSpeak: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.mic), findsNothing);
        expect(
          find.byTooltip(l10n.weNeedTheMicrophoneToHearWhat),
          findsNothing,
        );
      });
    }

    testWidgets('with voice logging on, the microphone comes back', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.shipped.with_(const {
        Feature.voiceLogging: true,
      });
      await tester.pumpWidget(
        _host(
          TypeItView(
            constraints: DietaryConstraints.none,
            now: DateTime(2026, 10, 12, 9, 30),
            onClose: () {},
            onSpeak: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });
  });

  group('1.4: a woman from Own Hub, within the server window', () {
    const reviewKeys = <String>[
      'aWomanFromOwnHubReviewsYour',
      'aWomanFromOwnHubCanContact',
      'ifYouDoNotShowYourFace_1pr0p',
      'thisAccountHasUsedEveryAutomaticCheck_rc3un',
    ];

    test('the hours on screen are config.REVIEW_SLA_HOURS', () {
      final config = File('../functions/identity/config.py').readAsStringSync();
      final hours = RegExp(
        r'^REVIEW_SLA_HOURS = (\d+)$',
        multiLine: true,
      ).firstMatch(config)!.group(1)!;
      final en = _arb('en');
      final ar = _arb('ar');
      for (final key in reviewKeys) {
        expect(en[key], contains('$hours hours'), reason: key);
        expect(ar[key], contains('$hours ساعة'), reason: key);
      }
    });

    test('no review string in use mentions video', () {
      final en = _arb('en');
      final ar = _arb('ar');
      for (final key in <String>[
        ...reviewKeys,
        'aWomanFromOwnHubWillReview',
        'aWomanFromOwnHubWillContact',
        'askAWomanToContactMe',
      ]) {
        expect((en[key] as String).toLowerCase(), isNot(contains('video')));
        expect(ar[key] as String, isNot(contains('فيديو')));
        expect(ar[key] as String, isNot(contains('مكالمة')));
      }
    });
  });

  group('M8: the privacy mailbox', () {
    test('the app writes to the address the policy publishes', () {
      final config = jsonDecode(
        File('../site/config.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final values = config['values'] as Map<String, dynamic>;
      expect(
        LegalLinks.privacyEmail,
        (values['contactPrivacy'] as Map<String, dynamic>)['value'],
      );
    });
  });

  group('M10: the Ramadan setting stays on the phone', () {
    test('the eating preferences sent to the cloud carry no Ramadan mode', () {
      final eatPrefs = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'eatPrefs',
      );
      expect(eatPrefs.data.containsKey('ramadanMode'), isFalse);
      expect(eatPrefs.data.keys, contains('plates'));
    });
  });
}
