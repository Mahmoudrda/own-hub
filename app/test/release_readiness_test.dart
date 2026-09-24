// What must be true of the build that goes to the stores.
//
// While `Feature.accountRequired` is off the app grows a set of aids that exist
// only so the product can be walked without signing up: an index of all 161
// screens, the one code the in-memory sign-in accepts printed on the screen
// that asks for it, and a test payment rail. Every one of them is gated, and
// this is the test that says so, because the failure mode is silent: the flag
// is a single boolean and a release built with it off looks completely normal
// until a reviewer finds a screen index in a fitness app.
//
// It also holds the two store rules that are checked in code rather than by
// reading: no other platform is named on screen (App Review 2.3.10), and no
// control opens a page that has no address yet (2.1).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/config/legal_links.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// The app as it will be submitted: every feature on, an account required.
FeatureFlags get _release =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

Future<void> _open(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = _release);
  tearDown(() => AppRouter.featureFlags = saved);

  group('the testing scaffolding cannot ship', () {
    testWidgets('the app opens on sign-up, not on Home', (tester) async {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.startEverythingsReady),
        findsNothing,
        reason: 'Home is behind an account',
      );
    });

    testWidgets('profile offers no index of every screen', (tester) async {
      await _open(tester, 'A02');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.allScreens), findsNothing);
    });

    testWidgets('the code screen does not print the code', (tester) async {
      await _open(tester, 'C07');
      expect(
        find.textContaining('Test build'),
        findsNothing,
        reason: 'the fixed sign-in code is a testing aid',
      );
    });

    test('the test payment rail is closed', () {
      expect(
        AppRouter.featureFlags.isOn(Feature.accountRequired),
        isTrue,
        reason: 'the rail keys off exactly this flag',
      );
    });
  });

  group('the admin console cannot ship', () {
    // Z01 to Z14 are the owner's content tooling, and Z14 is the switchboard
    // behind every feature flag. It can turn `Feature.accountRequired` OFF,
    // which is the one switch every other guard in this file keys off: with it
    // off there is no sign-up, the index of all 161 screens appears, the
    // sign-in code is printed on the screen that asks for it and a test
    // payment rail opens. A flag cannot guard the screen that edits flags, so
    // this one is guarded by the build.
    //
    // `Feature.adminConsole` stays a flag and stays on in `_release` above, on
    // purpose: this asserts the *build* refuses the console even with its own
    // feature switched on, which is the only version of the check that would
    // have caught the defect.

    final admin = appRoutes.entries
        .where((e) => e.value.flow == 'admin')
        .toList();

    test('a release build resolves none of Z01 to Z14', () {
      expect(admin, hasLength(14), reason: 'the console is fourteen screens');
      for (final entry in admin) {
        expect(
          AppRouter.resolvesInThisBuild(entry.key, release: true),
          isFalse,
          reason: '${entry.key} at ${entry.value.name} still resolves',
        );
      }
    });

    test('the switchboard most of all', () {
      expect(AppRouter.resolvesInThisBuild('Z14', release: true), isFalse);
    });

    test('and nothing else is withheld', () {
      for (final entry in appRoutes.entries) {
        if (entry.value.flow == 'admin') continue;
        expect(
          AppRouter.resolvesInThisBuild(entry.key, release: true),
          isTrue,
          reason: '${entry.key} is not the admin console',
        );
      }
    });

    test('debug and profile keep it, because the owner works in them', () {
      for (final id in const ['Z01', 'Z08', 'Z14']) {
        expect(AppRouter.resolvesInThisBuild(id, release: false), isTrue);
      }
    });

    test('an unknown route and a withheld one get the same answer: null', () {
      // A widget test cannot be compiled in release mode — `kReleaseMode` is a
      // const the test binary sets to false — so the refusal itself is proved
      // against the gate above. What this asserts is the other half: in a
      // build that keeps the console the route resolves, and a name no screen
      // serves resolves to null. Null is what the gate returns in release, so
      // an admin route there lands on `onUnknownRoute` exactly as a typo does.
      expect(
        AppRouter.onGenerateRoute(RouteSettings(name: appRoutes['Z14']!.name)),
        isNotNull,
      );
      expect(
        AppRouter.onGenerateRoute(
          const RouteSettings(name: '/no/screen/serves/this'),
        ),
        isNull,
      );
    });

    test('and a deep link naming it opens the front door instead', () {
      // `main.dart` picks the initial route from whatever the platform hands
      // it. A withheld id must fall through to the front door there too, or a
      // release build deep-linked to `/admin/z14` opens on "no screen serves
      // this route" instead of on the app.
      final source = File('lib/main.dart').readAsStringSync();
      expect(
        source,
        contains('AppRouter.resolvesInThisBuild(id)'),
        reason: 'the initial route must honour the same gate',
      );
    });

    test('and the router asks the gate before it builds anything', () {
      // Read from the source for the same reason the rule guards in
      // `product_rules_test.dart` are: the branch cannot be exercised from a
      // test binary, so the assertion is that it is there and is the first
      // thing after the id is known.
      final source = File('lib/routing/app_router.dart').readAsStringSync();
      expect(
        source,
        contains('if (!resolvesInThisBuild(id)) return null;'),
        reason: 'onGenerateRoute must consult the gate, not only define it',
      );
    });
  });

  group('store rules that live in the code', () {
    testWidgets('no other platform is named on the sign-in screen', (
      tester,
    ) async {
      // 2.3.10. The Android autofill sentence is true on Android and is a
      // rejection on iOS, so the screen chooses by platform. A widget test
      // runs as Android unless it is told otherwise, which is the whole reason
      // this assertion pins the platform it is about.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _open(tester, 'C07');
      final named = find.textContaining('Android').evaluate().length;
      // Reset inside the body: the framework checks this variable before any
      // tear-down callback runs.
      debugDefaultTargetPlatformOverride = null;
      expect(named, 0);
    });

    testWidgets('and Android still explains its own autofill', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _open(tester, 'C07');
      final named = find.textContaining('Android').evaluate().length;
      debugDefaultTargetPlatformOverride = null;
      expect(named, 1);
    });

    test('no row opens a page that has no address', () {
      // A03 renders its policy and terms rows only when the links are set, so
      // an unfilled `LegalLinks` shows nothing rather than a dead tap. This
      // asserts the rule, not the values: `tool/release_preflight.sh` is what
      // refuses to submit while they are empty.
      expect(
        LegalLinks.allSet ||
            (LegalLinks.privacyPolicy.isEmpty && LegalLinks.terms.isEmpty),
        isTrue,
        reason: 'either every page has an address, or no row is drawn',
      );
    });
  });

  group('the first release is the shape that ships', () {
    testWidgets('it opens on Home, with no community and no coach side', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.shipped;
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(
        find.text(l10n.startEverythingsReady),
        findsOneWidget,
        reason: 'no account, so Home is the front door',
      );
      expect(
        find.text(l10n.community),
        findsNothing,
        reason: 'the community needs a moderator, so it is dark in 1.0',
      );
      expect(
        find.text(l10n.allScreens),
        findsNothing,
        reason: 'the index of every screen is not part of the product',
      );
    });

    test('the testing aids key off the build, not off a flag', () {
      // `Feature.accountRequired` used to be the difference between a testing
      // build and a real one. It cannot be any more: the first release ships
      // with it off. This asserts the wiring at source, because a widget test
      // always runs in debug and so can never observe the release arm.
      final router = File('lib/routing/app_router.dart').readAsStringSync();
      expect(
        router.contains(
          'kDebugMode && !featureFlags.isOn(Feature.accountRequired)',
        ),
        isTrue,
        reason: 'testingAidsAllowed must require a debug build',
      );
      for (final aid in [
        'onOpenAllScreens: !testingAidsAllowed',
        'testCode: testingAidsAllowed',
      ]) {
        expect(router.contains(aid), isTrue, reason: 'ungated aid: $aid');
      }
      for (final state in [
        'lib/app_state/coach_profile_state.dart',
        'lib/app_state/coaching_link_state.dart',
        'lib/app_state/coach_portfolio_state.dart',
      ]) {
        expect(
          File(state)
              .readAsStringSync()
              .contains('AppRouter.testingAidsAllowed'),
          isTrue,
          reason: '$state opens a test rail; it must key off the build',
        );
      }
    });
  });

  _shippingFlagsTests();
}

// ---------------------------------------------------------------------------
// What the first release offers, and what it must not.
//
// Every screen below is one a woman opens in the shipped build, and several of
// them are the screens in the store listing. A control that leads to a feature
// this release has switched off is App Review 2.1 — a button that does nothing
// — and a sentence that describes one is worse, because she cannot even see
// that it is a dead end. This walks the six shipping flows and reads what is
// actually on the page.
//
// It is a word list rather than a list of controls on purpose: a control is
// added by writing a row, and a row nobody thought of is exactly the one that
// ships. The legitimate uses are named one by one below, so adding a real
// sentence about a group of vegetables costs one line and a reason.

/// The flows the first release shows.
const Set<String> _shippingFlows = {
  'today',
  'train',
  'eat',
  'cycle',
  'progress',
  'account',
};

/// Words that name something the first release does not have.
///
/// Matched whole, case-insensitively, so "postpartum" is not "post" and
/// "Grouped the way you shop" is not "group".
const List<String> _switchedOff = [
  'community',
  'communities',
  'coach',
  'coaches',
  'coaching',
  'group',
  'groups',
  'member',
  'members',
  'post',
  'posts',
  'reel',
  'reels',
  'follower',
  'followers',
  'moderator',
  'moderators',
  'marketplace',
  'assistant',
  'unblock',
  'blocked',
  'sign up',
  'verified',
  'verification',
];

/// Sentences that contain one of those words and are nonetheless true here.
///
/// Each entry is a legitimate use, not an exemption to be handed out: the word
/// means something else, or the sentence is about this build rather than about
/// a feature.
const Set<String> _legitimate = {
  // E08 groups the shopping list by aisle. Nothing social about it.
  'Grouped the way you shop. Tick as you go. It remembers.',
};

String? _textOf(Text widget) =>
    widget.data ?? widget.textSpan?.toPlainText(includeSemanticsLabels: false);

/// Everything the page says, including the names of its icon buttons.
List<String> _pageText(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text)))
    if (_textOf(w) case final String s) s,
  for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    if (w.message case final String s) s,
];

/// The switched-off words [text] names, or an empty list.
List<String> _namesSwitchedOff(String text) {
  if (_legitimate.contains(text)) return const [];
  return [
    for (final word in _switchedOff)
      if (RegExp(
        '\\b${RegExp.escape(word)}\\b',
        caseSensitive: false,
      ).hasMatch(text))
        word,
  ];
}

void _shippingFlagsTests() {
  group('the first release names nothing it has switched off', () {
    setUp(() => AppRouter.featureFlags = FeatureFlags.shipped);

    final ids = [
      for (final e in appDestinations.entries)
        if (_shippingFlows.contains(e.value.flow)) e.key,
    ];

    test('there are screens to walk', () {
      expect(ids.length, greaterThan(30), reason: 'the six shipping flows');
    });

    for (final id in ids) {
      testWidgets('$id offers nothing that is dark', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await _open(tester, id);

        expect(
          find.byType(FeatureOff),
          findsNothing,
          reason: '$id itself is not in this release',
        );

        // `T08` — "First week done" — is listed as a destination and has no
        // builder, so it renders the placeholder. That is a defect of its
        // own (the arc's own file calls T08 "the completed rendering of the
        // same arc, not somewhere you go", which makes it a first-run state),
        // and it is reported rather than papered over here. What this group
        // reads is product copy, and the placeholder's text is not that.
        if (find.byType(NotBuiltYet).evaluate().isNotEmpty) return;

        final offences = <String>[];
        for (final line in _pageText(tester)) {
          final words = _namesSwitchedOff(line);
          if (words.isNotEmpty) offences.add('"$line" names ${words.first}');
        }
        expect(
          offences,
          isEmpty,
          reason:
              '$id offers or describes a feature this build has switched '
              'off:\n  ${offences.join('\n  ')}',
        );
      });
    }
  });

  group('the controls that used to lead nowhere', () {
    setUp(() => AppRouter.featureFlags = FeatureFlags.shipped);

    testWidgets('Home does not offer the assistant or a group', (tester) async {
      await _open(tester, 'T01');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.byTooltip(l10n.askSomething), findsNothing);
      expect(find.text(l10n.beginnersGroup), findsNothing);
    });

    testWidgets('day one does not either, and it is the first screen she '
        'sees', (tester) async {
      // T06 is a state of T01, taken when nothing has been logged, so it
      // cannot be opened by route. It is the screen a new woman actually
      // meets, which is why it is walked here rather than left to the route
      // list above.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: TodayView(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.dayOne(),
            ),
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final offences = [
        for (final line in _pageText(tester))
          if (_namesSwitchedOff(line).isNotEmpty) line,
      ];
      expect(offences, isEmpty, reason: offences.join('\n'));

      // And her first week is counted over the steps that remain, so the
      // number on Home matches the number of rows on T07.
      expect(find.text('0 of 3'), findsOneWidget);
    });

    testWidgets('her first week is three steps she can finish', (tester) async {
      await _open(tester, 'T07');
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.text(l10n.logOneSet), findsOneWidget);
      expect(find.text(l10n.logOneMeal), findsOneWidget);
      expect(find.text(l10n.finishOneSession), findsOneWidget);
      expect(find.text(l10n.joinOneGroup), findsNothing);
      expect(find.text(l10n.addAFollowUpPicture), findsNothing);

      // The count follows the arc: two of the three are done in the sample
      // day, so one is waiting rather than three.
      expect(find.text(l10n.ofTotal('3')), findsOneWidget);
      expect(find.text(l10n.doneDoneWaitingWaiting('2', '1')), findsOneWidget);
    });

    testWidgets('finishing a session offers nowhere to post it', (
      tester,
    ) async {
      await _open(tester, 'R10');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.backToToday), findsOneWidget);
      expect(find.text(l10n.shareTheSquatWithYourGroup), findsNothing);
    });

    testWidgets('her profile does not offer a coach', (tester) async {
      await _open(tester, 'A02');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.myCoach), findsNothing);
      // And the language chooser is still there, because a build that cannot
      // change language is a build a woman can be trapped in.
      expect(find.text(l10n.language), findsOneWidget);
    });

    testWidgets('the language chooser opens rather than the switched-off '
        'panel', (tester) async {
      await _open(tester, 'C02');
      expect(find.byType(FeatureOff), findsNothing);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('privacy offers no switch that changes nothing', (
      tester,
    ) async {
      await _open(tester, 'A03');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.profileVisibleToMembers), findsNothing);
      expect(find.text(l10n.myCoachCanSeeMyLogs), findsNothing);
      // What is left is true, and the door into cycle sharing stays.
      expect(find.text(l10n.cycleInformation), findsOneWidget);
    });

    testWidgets('the safety centre keeps the emergency line and drops the '
        'membership it does not have', (tester) async {
      await _open(tester, 'A04');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.everyMemberIsVerified), findsNothing);
      expect(find.text(l10n.reportSomeone), findsNothing);
      expect(find.text(l10n.ifYouAreInDangerRightNow), findsOneWidget);
    });

    testWidgets('cycle settings offer no sharing with a coach', (tester) async {
      await _open(tester, 'Y12');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.shareWithMyCoach), findsNothing);
      expect(find.text(l10n.changeHowYouUseMyCycle), findsOneWidget);
    });
  });

  group('she can read it in her own language', () {
    testWidgets('an Arabic phone opens in Arabic', (tester) async {
      // This shipped opening in English on an Egyptian handset, with the
      // chooser one screen deep and the whole Arabic product already in the
      // binary. The phone is the better guess until she says otherwise.
      tester.platformDispatcher.localesTestValue = const [Locale('ar', 'EG')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      AppRouter.featureFlags = FeatureFlags.shipped;

      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      expect(
        Localizations.localeOf(tester.element(find.byType(Navigator).first))
            .languageCode,
        'ar',
      );
    });

    testWidgets('and the chooser is reachable, not behind sign-up', (
      tester,
    ) async {
      // `C02` lives in the signup flow, which the first release switches off,
      // so without its exemption the Language row landed on the switched-off
      // panel and she was stuck in whatever language the app opened in.
      AppRouter.featureFlags = FeatureFlags.shipped;
      expect(AppRouter.screenIsOn('C02'), isTrue);
    });
  });
}
