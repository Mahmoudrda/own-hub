// Getting started tips on the phone: where the series starts, what settles a
// tip, how the plan reaches the scheduler, the A01 switch, sign-out, the
// snapshot, where a tap lands, and the one offer on C13.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/first_gym_guide_state.dart';
import 'package:own_hub/app_state/getting_started.dart';
import 'package:own_hub/app_state/notification_sync.dart';
import 'package:own_hub/app_state/notification_taps.dart';
import 'package:own_hub/app_state/reminder_scheduler.dart';
import 'package:own_hub/app_state/tip_anchors.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/role_view.dart';
import 'package:own_hub/features/train/domain/getting_started_tips.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Scheduler implements ReminderScheduler {
  int asked = 0;
  final List<List<PlannedNotification>> applied = [];
  int cancelled = 0;
  bool failApply = false;

  List<PlannedNotification> get tips =>
      applied.last.where((n) => n.kind == PlanKind.tip).toList();

  @override
  Future<ReminderPermission> requestPermission() async {
    asked++;
    return ReminderPermission.granted;
  }

  @override
  Future<void> apply(List<PlannedNotification> plan, ReminderText text) async {
    if (failApply) throw StateError('no');
    applied.add(plan);
  }

  @override
  Future<void> scheduleRest(
    PlannedNotification rest,
    ReminderText text,
  ) async {}

  @override
  Future<void> cancelRest() async {}

  @override
  Future<void> cancel() async => cancelled++;
}

VerificationResult _passed() => VerificationResult(
  method: VerificationMethod.automatic,
  decidedAt: DateTime(2026, 10, 2),
  imagesDeletedAt: DateTime(2026, 10, 2),
);

/// Wednesday 14 October 2026, ten in the morning.
final _landed = DateTime(2026, 10, 14, 10);

DateTime _day(int n, int hour) =>
    DateTime(_landed.year, _landed.month, _landed.day + n, hour);

String _route(String id) => appRoutes[id]!.name;

void _clean() {
  ReminderState.instance.reset();
  FirstGymGuideState.instance.reset();
  AppRouter.intakeRepository.reset();
  AppRouter.trainRepository.reset();
  AppRouter.reminderScheduler = null;
  AppRouter.lastVerification = null;
  AppRouter.lastSignupRole = null;
  AppRouter.navigatorKey = null;
  AppRouter.dietaryRepository.reset();
  AppClock.debugNow = null;
  TipAnchors.instance.resetForTest();
  GettingStarted.currentUid = () => AppRouter.signedInUid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final text = AppRouter.reminderText(lookupAppL10n(const Locale('en')));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _clean();
  });
  tearDown(_clean);

  group('where the series starts', () {
    test('landing verified on C13 starts it, once', () {
      AppClock.debugNow = () => _landed;
      GettingStarted.routeOpened('C13');
      expect(ReminderState.instance.tips.anchorAt, isNull);

      AppRouter.lastVerification = _passed();
      GettingStarted.routeOpened('C13');
      expect(ReminderState.instance.tips.anchorAt, _landed);
      expect(ReminderState.instance.tipsOfferDue, isTrue);

      AppClock.debugNow = () => _day(2, 9);
      GettingStarted.routeOpened('T01');
      expect(ReminderState.instance.tips.anchorAt, _landed);
    });

    test('a coach who does not train starts it only on Home', () {
      AppClock.debugNow = () => _landed;
      AppRouter.lastVerification = _passed();
      AppRouter.lastSignupRole = SignupRole.coach;
      GettingStarted.routeOpened('C13');
      expect(ReminderState.instance.tips.anchorAt, isNull);
      expect(ReminderState.instance.tipsOfferDue, isFalse);
      GettingStarted.routeOpened('T01');
      expect(ReminderState.instance.tips.anchorAt, _landed);
    });
  });

  group('what settles a tip, read from the phone', () {
    // Verified, as every woman the series runs for is.
    setUp(() => AppRouter.lastVerification = _passed());

    test('nothing done, nothing settled', () {
      final facts = GettingStarted.facts();
      for (final tip in GettingStartedTip.values) {
        expect(facts.settles(tip), isFalse, reason: tip.name);
      }
    });

    test('the screens she opened, a photographed meal, a session', () {
      for (final id in ['R15', 'E05', 'P06', 'R02']) {
        GettingStarted.routeOpened(id);
      }
      GettingStarted.notePhotoMeal();
      ReminderState.instance.lastSessionAt = _landed;
      final facts = GettingStarted.facts();
      expect(facts.openedVideos, isTrue);
      expect(facts.openedRecipes, isTrue);
      expect(facts.openedMuscles, isTrue);
      expect(facts.openedProgram, isTrue);
      expect(facts.loggedAPhotoMeal, isTrue);
      expect(facts.loggedASession, isTrue);
      expect(facts.settles(GettingStartedTip.firstGym), isFalse);
    });

    test('home only, said out loud, or the guide seen settles the gym tip', () {
      // The default place is home, and it is not her answer.
      expect(GettingStarted.facts().trainsAtHomeOnly, isFalse);
      AppRouter.intakeRepository.merge(place: TrainingPlace.home);
      expect(GettingStarted.facts().trainsAtHomeOnly, isTrue);
      AppRouter.intakeRepository.merge(place: TrainingPlace.both);
      expect(GettingStarted.facts().trainsAtHomeOnly, isFalse);
      FirstGymGuideState.instance.seen = true;
      expect(GettingStarted.facts().sawGymGuide, isTrue);
    });
  });

  group('the meal photo tip only where she can take one', () {
    setUp(() => AppRouter.lastVerification = _passed());

    test('allergies settle it, so it never comes', () {
      expect(
        GettingStarted.facts().settles(GettingStartedTip.mealScan),
        isFalse,
      );
      AppRouter.dietaryRepository.restore(
        const DietaryProfile(allergies: {AllergenTag.eggs}),
      );
      expect(NotificationTaps.canOpen('E12'), isFalse);
      expect(GettingStarted.facts().cannotScanMeals, isTrue);
      expect(
        GettingStarted.facts().settles(GettingStartedTip.mealScan),
        isTrue,
      );
    });

    test('a moment read as unverified does not settle it for good', () {
      AppRouter.lastVerification = null;
      expect(GettingStarted.facts().cannotScanMeals, isFalse);
    });

    test('the plan leaves it out and marks it done', () async {
      AppRouter.dietaryRepository.restore(
        const DietaryProfile(allergies: {AllergenTag.eggs}),
      );
      ReminderState.instance
        ..permissionGranted = true
        ..tips = TipSeries(anchorAt: _landed)
        ..lastActiveAt = _landed;
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: _landed);
      expect(
        scheduler.tips.map(GettingStartedTip.of),
        isNot(contains(GettingStartedTip.mealScan)),
      );
      // At most three casual notes until she opens the app; the day the
      // removed tip frees goes to the next note in time order.
      expect(scheduler.tips, hasLength(kNudgesUnanswered - 1));
      expect(
        ReminderState.instance.tips.done,
        contains(GettingStartedTip.mealScan),
      );
    });
  });

  group('the series is hers, not the phone sign-in', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppRouter.lastVerification = _passed();
    });

    test(
      'a woman signing back in months later does not start it again',
      () async {
        GettingStarted.currentUid = () => 'uid-a';
        AppClock.debugNow = () => _landed;
        GettingStarted.routeOpened('T01');
        expect(ReminderState.instance.tips.anchorAt, _landed);

        await const ThisPhoneWipe().signOut();
        expect(ReminderState.instance.tips.anchorAt, isNull);
        // The anchor outlives a restart, under its own key.
        await TipAnchors.instance.load();
        expect(TipAnchors.instance.anchorFor('uid-a'), _landed);

        // Back, two months on.
        AppRouter.lastVerification = _passed();
        final later = DateTime(2026, 12, 14, 10);
        AppClock.debugNow = () => later;
        GettingStarted.routeOpened('T01');
        expect(ReminderState.instance.tips.anchorAt, _landed);

        ReminderState.instance.permissionGranted = true;
        final scheduler = _Scheduler();
        await NotificationSync.reapply(scheduler, text, now: later);
        expect(scheduler.tips, isEmpty);
        expect(ReminderState.instance.tips.ended, isTrue);
      },
    );

    test('a new account on the same phone still gets it', () async {
      GettingStarted.currentUid = () => 'uid-a';
      AppClock.debugNow = () => _landed;
      GettingStarted.routeOpened('T01');
      await const ThisPhoneWipe().signOut();

      AppRouter.lastVerification = _passed();
      GettingStarted.currentUid = () => 'uid-b';
      final later = DateTime(2026, 12, 14, 10);
      AppClock.debugNow = () => later;
      GettingStarted.routeOpened('T01');

      expect(ReminderState.instance.tips.anchorAt, later);
      expect(TipAnchors.instance.anchorFor('uid-b'), later);
    });

    test('deleting her data forgets the anchors', () async {
      GettingStarted.currentUid = () => 'uid-a';
      AppClock.debugNow = () => _landed;
      GettingStarted.routeOpened('T01');
      await const ThisPhoneWipe().clearPersistence();
      await pumpEventQueue();
      expect(TipAnchors.instance.anchorFor('uid-a'), isNull);
      await TipAnchors.instance.load();
      expect(TipAnchors.instance.anchorFor('uid-a'), isNull);
    });
  });

  group('on the phone', () {
    setUp(() {
      AppRouter.lastVerification = _passed();
      ReminderState.instance
        ..permissionGranted = true
        ..tips = TipSeries(anchorAt: _landed)
        ..lastActiveAt = _landed;
    });

    test('allowed and landed: seven tips, remembered once the phone has '
        'them', () async {
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: _landed);
      expect(scheduler.tips, hasLength(kNudgesUnanswered));
      expect(scheduler.tips.first.at, _day(1, 18));
      expect(ReminderState.instance.tips.due, hasLength(kNudgesUnanswered));
    });

    test('a phone that refused them remembers nothing', () async {
      final scheduler = _Scheduler()..failApply = true;
      await NotificationSync.reapply(scheduler, text, now: _landed);
      expect(ReminderState.instance.tips, TipSeries(anchorAt: _landed));
    });

    test('opening the app pushes the next one a day out', () async {
      final scheduler = _Scheduler();
      await NotificationSync.reapply(scheduler, text, now: _landed);
      final open = _day(1, 17);
      ReminderState.instance.noteActive(open);
      await NotificationSync.reapply(scheduler, text, now: open);
      expect(scheduler.tips.first.at, _day(2, 17));
    });

    test('a screen she opens takes its tip out of the plan', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await NotificationSync.reapply(scheduler, text, now: _landed);
      AppClock.debugNow = () => _landed;
      GettingStarted.routeOpened('R15');
      await pumpEventQueue();
      expect(
        scheduler.tips.map(GettingStartedTip.of),
        isNot(contains(GettingStartedTip.videos)),
      );
      expect(scheduler.tips, hasLength(kNudgesUnanswered - 1));
    });

    test('the A01 switch off cancels the ones to come', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await NotificationSync.reapply(scheduler, text, now: _landed);
      AppClock.debugNow = () => _landed;
      await AppRouter.setNotificationPrefs(
        ReminderState.instance.prefs.copyWith(tips: false),
      );
      expect(scheduler.tips, isEmpty);
      // What the phone replaces covers every tip id, so off removes them.
      for (final tip in GettingStartedTip.values) {
        expect(kPlannedIds, contains(tip.id));
      }
      // On again before they are due: they come back.
      await AppRouter.setNotificationPrefs(
        ReminderState.instance.prefs.copyWith(tips: true),
      );
      expect(scheduler.tips, hasLength(kNudgesUnanswered));
    });

    test('signing out cancels the series', () async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await NotificationSync.reapply(scheduler, text, now: _landed);
      await const ThisPhoneWipe().signOut();
      await pumpEventQueue();
      expect(scheduler.cancelled, 1);
      expect(ReminderState.instance.tips.anchorAt, isNull);
      expect(ReminderState.instance.tips.due, isEmpty);
      expect(ReminderState.instance.tipMarks, isEmpty);
    });

    test('the series and the switch survive a restart', () async {
      await NotificationSync.reapply(_Scheduler(), text, now: _landed);
      ReminderState.instance
        ..prefs = const NotificationPrefs(tips: false)
        ..tipMarks.add('E05')
        ..tipsOffered = true;
      final saved = ReminderState.instance.tips;
      final snapshot = jsonEncode(AppSnapshot.capture());
      ReminderState.instance.reset();
      AppSnapshot.restore(snapshot);
      final state = ReminderState.instance;
      expect(state.tips, saved);
      expect(state.prefs.tips, isFalse);
      expect(state.tipMarks, {'E05'});
      expect(state.tipsOffered, isTrue);
      expect(state.tipsOfferDue, isFalse);
    });
  });

  group('a tap on a tip', () {
    test('every tip opens a screen on the list', () {
      final expected = {
        GettingStartedTip.firstWorkout: 'R03',
        GettingStartedTip.videos: 'R01',
        GettingStartedTip.mealScan: 'E12',
        GettingStartedTip.recipes: 'E05',
        GettingStartedTip.firstGym: 'R01',
        GettingStartedTip.muscles: 'P06',
        GettingStartedTip.program: 'R02',
      };
      for (final tip in GettingStartedTip.values) {
        expect(NotificationTaps.destinations, contains(tip.screen));
        expect(
          NotificationTaps.routeFor(
            tip.screen,
            sessionLive: false,
            isOn: (_) => true,
          ),
          _route(expected[tip]!),
          reason: tip.name,
        );
      }
    });

    test('a screen that is off opens the nearest one that is on', () {
      String? when(String payload, String off) => NotificationTaps.routeFor(
        payload,
        sessionLive: false,
        isOn: (id) => id != off,
      );
      expect(when('R03', 'R03'), _route('T01'));
      expect(when('R14', 'R14'), _route('R01'));
      expect(when('E12', 'E12'), _route('E01'));
      expect(when('E05', 'E05'), _route('E01'));
      expect(when('P06', 'P06'), _route('P01'));
      expect(when('R02', 'R02'), _route('R01'));
      expect(
        NotificationTaps.routeFor(
          'P06',
          sessionLive: false,
          isOn: (_) => false,
        ),
        isNull,
      );
    });

    test('a photo of her plate only where Eat offers one', () {
      expect(NotificationTaps.canOpen('E12'), isFalse);
      AppRouter.lastVerification = _passed();
      expect(NotificationTaps.canOpen('E12'), AppRouter.screenIsOn('E12'));
    });

    test('the screen she is already on opens nothing', () {
      expect(
        NotificationTaps.routeFor(
          'E05',
          sessionLive: false,
          top: _route('E05'),
          isOn: (_) => true,
        ),
        isNull,
      );
    });
  });

  group('the offer on C13', () {
    Future<void> openC13(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      AppRouter.navigatorKey = navigator;
      AppRouter.lastVerification = _passed();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          initialRoute: _route('C13'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      );
      await tester.pump(
        GettingStarted.offerDelay + const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
    }

    final explainer = find.byKey(const ValueKey('notification-explainer'));
    const question = 'Want a few tips and your workout reminders?';

    testWidgets('yes asks the phone, and the tips are set', (tester) async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await openC13(tester);
      expect(explainer, findsOneWidget);
      expect(find.text(question), findsOneWidget);
      expect(scheduler.asked, 0);

      await tester.tap(find.byKey(const ValueKey('explainer-yes')));
      await tester.pumpAndSettle();
      expect(scheduler.asked, 1);
      expect(ReminderState.instance.permitted, isTrue);
      expect(scheduler.tips, isNotEmpty);
      expect(ReminderState.instance.tipsOffered, isTrue);
    });

    testWidgets('"Not now" asks nothing, blocks nothing, and is final', (
      tester,
    ) async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      await openC13(tester);
      await tester.tap(find.byKey(const ValueKey('explainer-not-now')));
      await tester.pumpAndSettle();
      expect(scheduler.asked, 0);
      expect(ReminderState.instance.permitted, isFalse);
      expect(find.text('Go to Home'), findsOneWidget);

      // Home after it does not ask again.
      await tester.tap(find.text('Go to Home'));
      await tester.pump(
        GettingStarted.offerDelay + const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      expect(explainer, findsNothing);
    });

    testWidgets('a phone that cannot show notifications is never asked', (
      tester,
    ) async {
      await openC13(tester);
      expect(explainer, findsNothing);
    });

    testWidgets('a phone already allowed is not asked again', (tester) async {
      final scheduler = _Scheduler();
      AppRouter.reminderScheduler = scheduler;
      ReminderState.instance.permissionGranted = true;
      await openC13(tester);
      expect(explainer, findsNothing);
      expect(scheduler.asked, 0);
    });
  });
}
