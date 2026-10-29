import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_application_draft.dart';
import 'package:own_hub/features/private_coaching/domain/coach_agreement.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_flow_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_intro_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_photo.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_review_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_rules.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/application_status_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';

import '../support/fixtures.dart';
import 'support/apply_support.dart';

const _locales = [Locale('en'), Locale('ar')];

void main() {
  late MemoryPhotoStore store;
  late CoachApplicationDraft draft;
  late RecordingRepository repo;

  setUp(() {
    store = MemoryPhotoStore();
    draft = CoachApplicationDraft.forTest()..store = store;
    repo = RecordingRepository();
  });

  AppL10n l10nOf(WidgetTester tester) =>
      AppL10n.of(tester.element(find.byType(Scaffold).first));

  Future<void> pumpFlow(
    WidgetTester tester, {
    int? step,
    Locale locale = const Locale('en'),
    double scale = 1.0,
    bool reduceMotion = false,
    VoidCallback? onReview,
    VoidCallback? onExit,
    ApplyPhotoPicker? picker,
    bool returnToReview = false,
  }) async {
    phone(tester);
    await tester.pumpWidget(
      host(
        ApplyFlowView(
          draft: draft,
          tools: testTools(store, picker),
          initialStep: step,
          now: kNow,
          onReview: onReview,
          onExit: onExit,
          returnToReview: returnToReview,
        ),
        locale: locale,
        textScale: scale,
        reduceMotion: reduceMotion,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('intro', () {
    testWidgets('a verified woman can start; others are sent to verify', (
      tester,
    ) async {
      phone(tester);
      var started = 0, verified = 0;
      await tester.pumpWidget(
        host(
          ApplyIntroView(
            isVerifiedWoman: true,
            hasDraft: false,
            onStart: () => started++,
            onVerify: () => verified++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      expect(find.text(l10n.start), findsOneWidget);
      expect(find.text(l10n.verifyMyAccount), findsNothing);
      expect(
        find.text(l10n.reviewTakesUpToDaysWorkingDays('5')),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.start));
      expect(started, 1);

      await tester.pumpWidget(
        host(
          ApplyIntroView(
            isVerifiedWoman: false,
            onStart: () => started++,
            onVerify: () => verified++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.start), findsNothing);
      expect(find.text(l10n.verifyThatYouAreAWomanFirst), findsOneWidget);
      await tester.tap(find.text(l10n.verifyMyAccount));
      expect(verified, 1);
      expect(started, 1);
    });

    testWidgets('a waiting draft says continue', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(const ApplyIntroView(isVerifiedWoman: true, hasDraft: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10nOf(tester).continueMyApplication), findsOneWidget);
    });

    for (final locale in _locales) {
      testWidgets('fits at text scale 2.0 in ${locale.languageCode}', (
        tester,
      ) async {
        phone(tester);
        for (final verified in [true, false]) {
          await tester.pumpWidget(
            host(
              ApplyIntroView(isVerifiedWoman: verified, hasDraft: false),
              locale: locale,
              textScale: 2.0,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('the flow', () {
    testWidgets('an empty step does not move on and says what is missing', (
      tester,
    ) async {
      await pumpFlow(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.countOfTotal('1', '8')), findsOneWidget);
      await tester.tap(find.text(l10n.saveAndContinue));
      await tester.pumpAndSettle();
      expect(find.text(l10n.countOfTotal('1', '8')), findsOneWidget);
      expect(find.text(l10n.thisIsNeeded), findsWidgets);
      expect(find.text(l10n.somethingIsStillMissingLookAtThe), findsOneWidget);
      expect(draft.touched, isFalse);
    });

    testWidgets('a finished step saves the draft and moves on', (tester) async {
      draft.update(draftApplication(), step: 1);
      await pumpFlow(tester);
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.saveAndContinue));
      await tester.pumpAndSettle();
      expect(find.text(l10n.countOfTotal('2', '8')), findsOneWidget);
      expect(draft.step, 2);
      await tester.tap(find.byTooltip(l10n.back).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.countOfTotal('1', '8')), findsOneWidget);
    });

    testWidgets('typing is kept when she goes back out', (tester) async {
      var exited = 0;
      await pumpFlow(tester, onExit: () => exited++);
      await tester.enterText(find.byType(TextField).first, 'Sara Hassan');
      await tester.tap(find.byTooltip(l10nOf(tester).back).first);
      await tester.pumpAndSettle();
      expect(exited, 1);
      expect(draft.application.personal.fullName, 'Sara Hassan');
    });

    testWidgets('the last step asks for the three rules, then goes to review', (
      tester,
    ) async {
      var reviewed = 0;
      draft.update(
        draftApplication().copyWith(rules: [], termsVersion: 0),
        step: 8,
      );
      await pumpFlow(tester, onReview: () => reviewed++);
      final l10n = l10nOf(tester);
      // Agreement v2 in plain points: the commission, paying within days,
      // the hold, the videos, chat only in the app and the keep-clients rule.
      for (final point in [
        l10n.ownHubTakesFullOfThePackage(
          CoachAgreementFacts.marketplacePercent,
          CoachAgreementFacts.invitePercent,
        ),
        l10n.payOwnHubItsShareWithinDays(
          '${CoachAgreementFacts.payWithinDays}',
          '${CoachAgreementFacts.holdAfterDays}',
        ),
        l10n.makeVideosShortVideosForOwnHub(
          '${CoachAgreementFacts.videosPerMonth}',
        ),
        l10n.keepEveryChatInsideTheAppAnd,
        l10n.doNotWorkWithAClientYou(
          '${CoachAgreementFacts.keepClientsMonths}',
        ),
      ]) {
        expect(find.text(point), findsOneWidget, reason: point);
      }
      await tester.tap(find.text(l10n.saveAndContinue));
      await tester.pumpAndSettle();
      expect(reviewed, 0);
      expect(find.text(l10n.tickThisToContinue), findsWidgets);

      for (final label in [
        l10n.everythingIWroteIsAccurate,
        l10n.iShareClientPhotosOnlyWithTheir,
        l10n.iHaveReadTheCoachAgreementAnd,
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(l10n.saveAndContinue));
      await tester.pumpAndSettle();
      expect(reviewed, 1);
      expect(draft.application.termsVersion, kCoachTermsVersion);
      expect(draft.application.rules.toSet(), CoachingEnums.coachRules.toSet());
    });

    testWidgets('opened from the review it goes straight back to it', (
      tester,
    ) async {
      var reviewed = 0;
      draft.update(draftApplication());
      await pumpFlow(
        tester,
        step: 4,
        returnToReview: true,
        onReview: () => reviewed++,
      );
      await tester.tap(find.text(l10nOf(tester).saveAndContinue));
      await tester.pumpAndSettle();
      expect(reviewed, 1);
    });

    testWidgets(
      'a photo from the camera or her photos is kept as a local copy',
      (tester) async {
        final picker = FakePicker(PickedPhoto(jpegBytes(), 'image/jpeg'));
        await pumpFlow(tester, picker: picker);
        final l10n = l10nOf(tester);
        await tester.ensureVisible(find.text(l10n.addAPhoto));
        await tester.tap(find.text(l10n.addAPhoto));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.chooseFromYourPhotos));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.saveAndContinue));
        await tester.pumpAndSettle();
        expect(find.text(l10n.photoAdded), findsOneWidget);
        expect(store.files, hasLength(1));
        await tester.tap(find.byTooltip(l10n.close));
        await tester.pumpAndSettle();
        expect(isLocalCoachPhoto(draft.application.personal.photoPath), isTrue);
      },
    );

    testWidgets('a file that is not a photo is refused with a message', (
      tester,
    ) async {
      final picker = _ThrowingPicker();
      await pumpFlow(tester, picker: picker);
      final l10n = l10nOf(tester);
      await tester.ensureVisible(find.text(l10n.addAPhoto));
      await tester.tap(find.text(l10n.addAPhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.takePhoto));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.thatPhotoCouldNotBeUsedChoose('10')),
        findsOneWidget,
      );
      expect(store.files, isEmpty);
    });

    for (final locale in _locales) {
      for (final filled in [false, true]) {
        testWidgets(
          'all eight steps fit at text scale 2.0 in ${locale.languageCode}, ${filled ? 'filled' : 'empty, with errors'}',
          (tester) async {
            if (filled) draft.update(draftApplication());
            for (var step = 1; step <= 8; step++) {
              await pumpFlow(
                tester,
                step: step,
                locale: locale,
                scale: 2.0,
                reduceMotion: step.isEven,
              );
              if (!filled) {
                await tester.tap(find.text(l10nOf(tester).saveAndContinue));
                await tester.pumpAndSettle();
              }
              expect(tester.takeException(), isNull, reason: 'step $step');
              expect(
                find.byType(TextField).evaluate().isNotEmpty || step == 8,
                isTrue,
              );
            }
          },
        );
      }
    }
  });

  group('review', () {
    Future<void> pumpReview(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
      double scale = 1.0,
      VoidCallback? onSent,
      ValueChanged<int>? onEdit,
    }) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          ApplyReviewView(
            draft: draft,
            repository: repo,
            now: kNow,
            onSent: onSent,
            onEditStep: onEdit,
          ),
          locale: locale,
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('flags what is missing and will not send', (tester) async {
      draft.update(draftApplication().copyWith(specialties: []));
      await pumpReview(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.stillNeeded), findsOneWidget);
      expect(find.text(l10n.complete), findsNWidgets(7));
      await tester.tap(find.text(l10n.sendMyApplication), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.submits, isEmpty);
    });

    testWidgets('Edit opens that step', (tester) async {
      draft.update(draftApplication());
      final opened = <int>[];
      await pumpReview(tester, onEdit: opened.add);
      final l10n = l10nOf(tester);
      final edits = find.text(l10n.edit);
      expect(edits, findsNWidgets(8));
      await tester.ensureVisible(edits.at(2));
      await tester.tap(edits.at(2));
      expect(opened, [3]);
    });

    testWidgets('sends, uploads the photos and hands over', (tester) async {
      draft.update(await withLocalPhotos(store));
      var sent = 0;
      await pumpReview(tester, onSent: () => sent++);
      await tester.tap(find.text(l10nOf(tester).sendMyApplication));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(repo.uploads, hasLength(4));
      expect(repo.submits, hasLength(1));
      expect(repo.submits.single.containsKey('payout'), isFalse);
      expect(draft.touched, isFalse);
    });

    for (final refusal in CoachingRefusal.values) {
      testWidgets(
        'shows a clear message for ${refusal.code} and lets her try again',
        (tester) async {
          draft.update(draftApplication());
          repo.failWith['submitCoachApplication'] = CoachingFailure(refusal);
          var sent = 0;
          await pumpReview(tester, onSent: () => sent++);
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.sendMyApplication));
          await tester.pumpAndSettle();
          expect(find.text(applyFailureText(l10n, refusal)), findsOneWidget);
          expect(sent, 0);
          expect(draft.touched, isTrue);
          expect(find.text(l10n.tryAgain), findsOneWidget);

          repo.failWith.clear();
          await tester.tap(find.text(l10n.tryAgain));
          await tester.pumpAndSettle();
          expect(sent, 1);
        },
      );
    }

    for (final locale in _locales) {
      testWidgets('fits at text scale 2.0 in ${locale.languageCode}', (
        tester,
      ) async {
        draft.update(draftApplication());
        await pumpReview(tester, locale: locale, scale: 2.0);
        expect(tester.takeException(), isNull);
        draft.update(draftApplication().copyWith(testimonials: []));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('status', () {
    CoachApplication app(
      ApplicationStatus s, {
      Map<String, String> reasons = const {},
      String note = '',
      DateTime? decided,
    }) => CoachApplication.fromMap({
      ...draftApplication().toMap(),
      'status': s.wire,
      'reasons': reasons,
      'note': note,
      if (decided != null) 'decidedAt': decided.toIso8601String(),
    });

    Future<AppL10n> pumpStatus(
      WidgetTester tester,
      CoachApplication? a, {
      Locale locale = const Locale('en'),
      double scale = 1.0,
      ValueChanged<int>? onEdit,
      VoidCallback? onResend,
      VoidCallback? onSpace,
    }) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          ApplicationStatusView(
            application: a,
            now: kNow,
            onEditSection: onEdit,
            onSendAgain: onResend,
            onOpenCoachSpace: onSpace,
          ),
          locale: locale,
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();
      return l10nOf(tester);
    }

    testWidgets('none yet offers to start', (tester) async {
      final l10n = await pumpStatus(tester, null);
      expect(find.text(l10n.noApplicationYet), findsOneWidget);
      expect(find.text(l10n.startMyApplication), findsOneWidget);
    });

    testWidgets('each status has a way out: profile, space, contact', (
      tester,
    ) async {
      var l10n = await pumpStatus(tester, app(ApplicationStatus.submitted));
      expect(find.text(l10n.backToProfile), findsOneWidget);
      l10n = await pumpStatus(
        tester,
        app(
          ApplicationStatus.rejected,
          reasons: {'photo': 'unclear'},
          decided: DateTime(2026, 10, 20, 12),
        ),
      );
      expect(find.text(l10n.backToProfile), findsOneWidget);
      expect(find.text(l10n.contactOwnHub), findsOneWidget);
      l10n = await pumpStatus(
        tester,
        app(ApplicationStatus.approved),
        onSpace: () {},
      );
      expect(find.text(l10n.openMyCoachSpace), findsOneWidget);
    });

    testWidgets('submitted says what happens next', (tester) async {
      final l10n = await pumpStatus(tester, app(ApplicationStatus.submitted));
      expect(find.text(l10n.weHaveYourApplication), findsOneWidget);
      expect(find.text(l10n.whatHappensNext), findsOneWidget);
      expect(find.text(l10n.sendAgain), findsNothing);
      expect(find.text(l10n.openMyCoachSpace), findsNothing);
    });

    testWidgets(
      'needs changes lists each flagged section with its reason and Edit',
      (tester) async {
        final opened = <int>[];
        var resent = 0;
        final l10n = await pumpStatus(
          tester,
          app(
            ApplicationStatus.needsChanges,
            reasons: {
              'personal': 'unclear',
              'certificates': 'unverifiable',
              'payout': 'missing',
              'education': 'other',
            },
            note: 'Please add a clearer photo.',
          ),
          onEdit: opened.add,
          onResend: () => resent++,
        );
        expect(find.text(l10n.thisPartIsNotClearEnough), findsOneWidget);
        expect(find.text(l10n.weCouldNotVerifyThis), findsOneWidget);
        expect(find.text(l10n.pleaseLookAtThisPartAgain), findsOneWidget);
        expect(find.text(l10n.somethingIsMissingHere), findsNothing);
        expect(find.text('Please add a clearer photo.'), findsOneWidget);
        expect(find.text(l10n.edit), findsNWidgets(3));
        await tester.tap(find.text(l10n.edit).first);
        expect(opened, [1]);
        await tester.tap(find.text(l10n.sendAgain));
        expect(resent, 1);
      },
    );

    testWidgets('rejected gives the 30 day note and the date', (tester) async {
      final l10n = await pumpStatus(
        tester,
        app(ApplicationStatus.rejected, decided: DateTime(2026, 10, 20, 12)),
      );
      expect(find.text(l10n.notApprovedThisTime), findsOneWidget);
      expect(
        find.text(l10n.youCanApplyAgainOnDate('19 November 2026')),
        findsOneWidget,
      );
      await tester.pumpWidget(
        host(
          ApplicationStatusView(application: app(ApplicationStatus.rejected)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.youCanApplyAgainDaysDaysAfter('30')),
        findsOneWidget,
      );
    });

    testWidgets('approved opens the coach space', (tester) async {
      var opened = 0;
      final l10n = await pumpStatus(
        tester,
        app(ApplicationStatus.approved),
        onSpace: () => opened++,
      );
      expect(find.text(l10n.youAreApproved), findsOneWidget);
      await tester.tap(find.text(l10n.openMyCoachSpace));
      expect(opened, 1);
    });

    for (final locale in _locales) {
      testWidgets(
        'every status fits at text scale 2.0 in ${locale.languageCode}',
        (tester) async {
          for (final a in [
            null,
            for (final s in ApplicationStatus.values)
              app(
                s,
                reasons: {
                  for (final x in CoachingEnums.applicationSections)
                    x: 'unverifiable',
                },
                note: 'A long note from the reviewer. ' * 4,
                decided: DateTime(2026, 10, 20),
              ),
          ]) {
            await pumpStatus(tester, a, locale: locale, scale: 2.0);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }

    testWidgets(
      'the live screen seeds her draft before editing a flagged part',
      (tester) async {
        phone(tester);
        repo.application.value = app(
          ApplicationStatus.needsChanges,
          reasons: {'approach': 'unclear'},
        );
        final opened = <int>[];
        await tester.pumpWidget(
          host(
            ApplicationStatusScreen(
              repository: repo,
              draft: draft,
              onEditStep: opened.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(draft.touched, isFalse);
        await tester.tap(find.text(l10nOf(tester).edit));
        expect(opened, [7]);
        expect(draft.touched, isTrue);
        expect(
          draft.application.approach.text,
          draftApplication().approach.text,
        );
      },
    );
  });
}

class _ThrowingPicker implements ApplyPhotoPicker {
  @override
  Future<PickedPhoto?> pick(source) async => throw const ApplyPhotoInvalid();
}
