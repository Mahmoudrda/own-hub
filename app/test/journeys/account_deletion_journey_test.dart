// "Your data", driven through the REAL app: put things in, delete, and assert
// the app is back to its first day.
//
// # The defect this exists for
//
// A02 rendered a row reading "Download everything, or delete your account" and
// the `A02` builder never passed `onOpenYourData`, so the tap did nothing at
// all. That is Apple 2.1 for the dead control and 5.1.1(v) for an account that
// can be made in the app and not removed in it, in one line of a settings list.
// `AccountDeletionService` and the 37-row manifest were built and tested and
// called by nothing.
//
// # What is asserted, and what is not
//
// A widget test has no Firebase and no signed-in account, so this walks the
// no-account branch of `deleteAccount`: this phone is the whole of her data.
// The server branch (the `delete_account` callable, the journal replay, the
// wipe on `authLocked`, and the honest offline and unfinished answers) is
// proved in test/features/account/callable_deletion_transport_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/community_state.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/account/presentation/profile_view.dart';
import 'package:own_hub/features/account/presentation/your_data_sheet.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';

/// Long enough for the five-second undo window to close and the post to land.
const Duration _afterUndoWindow = Duration(seconds: 6);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, String screenId) async {
  _phone(tester);
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  await _goTo(tester, screenId);
}

Future<void> _goTo(WidgetTester tester, String screenId) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[screenId]!.name);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Writes one post from M03's composer and waits for it to land.
Future<void> _writePost(WidgetTester tester, String words) async {
  await _tap(tester, find.text('Write a post'));
  await tester.enterText(find.byType(TextField).first, words);
  await tester.pumpAndSettle();
  await _tap(tester, find.widgetWithText(AppButton, 'Post'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(_afterUndoWindow);
  await tester.pumpAndSettle();
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .clearSnackBars();
  await tester.pumpAndSettle();
}

/// Names an allergy through A02's own editor. A real write to a real store, on
/// the same screen the deletion row lives on.
///
/// The chip was labelled "No nuts" while `AllergenTag` had four members. It
/// reads "Tree nuts" now: the enum grew to sixteen when Rahma's recipe book was
/// authored, `nuts` split into `tree_nuts` and `peanuts` (they are not the same
/// allergy and folding them costs somebody a reaction), and the chips became
/// plain names rather than "No x" because a sixteen-chip list of negations
/// reads as a list of refusals. The subject of this test is unchanged: she
/// names an allergy, it is written, and deletion takes it away again.
Future<void> _sayNoNuts(WidgetTester tester) async {
  await _tap(tester, find.text('Allergies and dietary preferences'));
  await _tap(tester, find.text('Tree nuts'));
  await _tap(tester, find.widgetWithText(AppButton, 'Save'));
}

/// The rest of what the app holds about her, put there directly.
///
/// Composing a workout, a measurement and a block through four more screens
/// would test those screens, not this one. What matters here is that the wipe
/// reaches every store, so each store is given something to lose.
Future<void> _fillTheOtherStores() async {
  AppRouter.progressStore.applyMeasurement(
    Measurement(
      dayId: '2026-09-20',
      takenAt: DateTime(2026, 9, 20, 8),
      weightKg: 62.5,
    ),
  );
  AppRouter.mealRepository.store.days['2026-09-20'] = const MealDay(
    dayId: '2026-09-20',
  );
  await AppRouter.blockService.block('someone', BlockSource.post);
  await AppRouter.reportService.file(
    subjectUid: 'someone',
    reason: ReportReason.harassment,
  );
  AppRouter.todayRepository.recordSession('session-of-hers');
}

void main() {
  final saved = AppRouter.featureFlags;

  void reset() {
    CommunityState.instance.reset();
    EatAppState.instance.reset();
    WorkoutSessionState.instance.reset();
    AppRouter.blockService.reset();
    AppRouter.reportService.reset();
    AppRouter.progressStore.reset();
    AppRouter.personalBestLedger.reset();
    AppRouter.mealRepository.store.reset();
    AppRouter.dietaryRepository.reset();
    AppRouter.intakeRepository.reset();
    AppRouter.privacyRepository.reset();
    AppRouter.notificationsRepository.reset();
    AppRouter.trainRepository.reset();
    AppRouter.todayRepository.reset();
  }

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    reset();
  });

  tearDown(() {
    reset();
    AppRouter.featureFlags = saved;
  });

  group('the row opens something, and that something deletes', () {
    testWidgets('log a post and an allergy, delete, and it is day one', (
      tester,
    ) async {
      await _open(tester, 'M03');
      await _writePost(tester, 'Walked to the market and back.');
      expect(CommunityState.instance.store.posts, hasLength(1));

      await _goTo(tester, 'A02');
      await _sayNoNuts(tester);
      expect(
        AppRouter.dietaryRepository.read().allergies,
        contains(AllergenTag.treeNuts),
      );

      await _fillTheOtherStores();
      expect(nothingOfHersRemains, isFalse, reason: 'she has put things in');

      // The row that used to do nothing.
      await _tap(tester, find.text('Your data'));
      expect(find.byType(YourDataSheet), findsOneWidget);
      await _tap(tester, find.widgetWithText(AppButton, 'Delete everything'));

      // Everything, from every store this build holds.
      expect(nothingOfHersRemains, isTrue);
      expect(CommunityState.instance.store.posts, isEmpty);
      expect(
        AppRouter.dietaryRepository.read(),
        DietaryProfile.unasked,
        reason: 'unasked, not "no allergies": that is a claim she never made',
      );

      // And the app is where it opens: Home, with the settings screen she was
      // standing on gone with the data it was about.
      expect(find.byType(ProfileView), findsNothing);
      expect(find.byType(TodayView), findsOneWidget);
      expect(
        find.text('Your data is gone. The app is back to its first day.'),
        findsOneWidget,
      );
    });

    testWidgets('the sheet says what deleting does before it does it', (
      tester,
    ) async {
      await _open(tester, 'A02');
      await _tap(tester, find.text('Your data'));

      expect(
        find.textContaining('Deleting takes away everything you have put'),
        findsOneWidget,
      );
      // With no account she is told the phone is the whole of it, and the
      // old "there is no server" sentence is gone: the account build has one.
      expect(
        find.textContaining('You have no account on this phone'),
        findsOneWidget,
      );
      expect(find.textContaining('There is no server yet'), findsNothing);
    });

    testWidgets('and offers a copy by request, never a download that is not there', (
      tester,
    ) async {
      await _open(tester, 'A02');
      await _tap(tester, find.text('Your data'));

      // M8: a copy is asked for by email, to the privacy mailbox, until the
      // in-app download exists.
      expect(find.textContaining('Want a copy of your data?'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Ask for a copy'), findsOneWidget);
      expect(find.textContaining('not built yet'), findsNothing);
      // The dead control this whole item is about. There is no download in
      // this build, so there is no button pretending there is.
      expect(find.widgetWithText(AppButton, 'Download'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Export'), findsNothing);
    });

    testWidgets('cancelling keeps every word she wrote', (tester) async {
      await _open(tester, 'M03');
      await _writePost(tester, 'Two rounds, no rush.');

      await _goTo(tester, 'A02');
      await _tap(tester, find.text('Your data'));
      await _tap(tester, find.widgetWithText(AppButton, 'Cancel'));

      expect(find.byType(YourDataSheet), findsNothing);
      expect(CommunityState.instance.store.posts, hasLength(1));
      expect(find.byType(ProfileView), findsOneWidget);
    });
  });
}
