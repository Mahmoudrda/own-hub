// A coach's way in, end to end: R1-P15 to R1-P18, R1-P25 and M3.
//
//   * R1-P15: K02 takes a real certificate photo, K05 can be finished with
//     "Add payout later", and K07 keeps "Build your first plan" open while she
//     is being checked.
//   * R1-P16: K01 carries the community's three rules with a checkbox, and
//     Continue waits for it.
//   * R1-P17: her roles and her application survive a relaunch, the front door
//     opens on her side, and the trainee setup questions are not hers.
//   * R1-P18: a coach's invite code, kept by the woman she sent it to through
//     sign-up, and redeemed once she is in.
//   * R1-P25 and M3: a coach who arrives while coaching is closed can still
//     reach the team, and Back on K02 to K05 is a pop.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/coach_invite_state.dart';
import 'package:own_hub/app_state/coach_profile_state.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/app_state/pledge.dart';
import 'package:own_hub/app_state/role_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/features/coach/data/certificate_upload.dart';
import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_desk.dart';
import 'package:own_hub/features/coach/domain/coach_invite.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/presentation/certificate_camera_view.dart';
import 'package:own_hub/features/coach/presentation/coach_photo_view.dart';
import 'package:own_hub/features/coach/presentation/coach_rules_view.dart';
import 'package:own_hub/features/coach/presentation/coach_certificates_view.dart';
import 'package:own_hub/features/coach/presentation/coach_payout_view.dart';
import 'package:own_hub/features/coach/presentation/coach_today_view.dart';
import 'package:own_hub/features/coach/presentation/coach_view_models.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/role_view.dart'
    show SignupRole;
import 'package:own_hub/features/signup/presentation/coach_interest_sheet.dart';
import 'package:own_hub/features/signup/presentation/invite_code_sheet.dart';
import 'package:own_hub/features/signup/presentation/welcome_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_field.dart';

final _now = DateTime(2026, 10, 6, 10);

/// Everything on, an account required: the coach side as it will ship, and
/// no test rail (testing aids need the account flag off).
final FeatureFlags _coachLive = FeatureFlags.allOff.with_({
  for (final f in Feature.values) f: true,
});

/// The same with the coach side and the community switched off, as the first
/// release has them.
final FeatureFlags _coachOff = _coachLive.with_({
  Feature.coachApp: false,
  Feature.community: false,
});

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
  home: Scaffold(body: child),
);

void _asVerifiedWoman() {
  AppRouter.lastVerification = VerificationResult(
    method: VerificationMethod.automatic,
    decidedAt: _now,
    imagesDeletedAt: _now,
  );
}

class _FakeUploader implements CertificateUploader {
  _FakeUploader({this.failure});

  final CertificateUploadFailure? failure;
  final List<String> mediaRefs = <String>[];

  @override
  Future<String> upload({
    required String mediaRef,
    required String credentialId,
    required Uint8List jpeg,
  }) async {
    if (failure case final failure?) throw CertificateUploadException(failure);
    mediaRefs.add(mediaRef);
    return mediaRef.split('/').last.split('.').first;
  }
}

class _OfflineInviteStore implements CoachInviteStore {
  @override
  Future<String> create() async => throw const InviteUnavailable();

  @override
  Future<InviteRedemption> accept(String code) async =>
      InviteRedemption.unreachable;
}

AppButton _button(WidgetTester tester, String label) =>
    tester.widget<AppButton>(
      find.ancestor(of: find.text(label), matching: find.byType(AppButton)),
    );

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = _coachLive;
    CoachProfileState.instance.reset();
    RoleState.instance.reset();
    CoachInviteState.instance.reset();
    PledgeState.instance.reset();
  });

  tearDown(() {
    CoachProfileState.instance.reset();
    RoleState.instance.reset();
    CoachInviteState.instance.reset();
    PledgeState.instance.reset();
    AppRouter.lastVerification = null;
    AppRouter.intakeRepository.reset();
    AppRouter.featureFlags = savedFlags;
  });

  // ------------------------------------------------------------ R1-P15

  group('R1-P15: setup can be completed', () {
    testWidgets('K05 offers "Add payout later" while no method can be set', (
      tester,
    ) async {
      _phone(tester);
      var later = 0;
      final model = CoachSetupViewModel(profile: const CoachProfile());
      await tester.pumpWidget(
        _host(
          CoachPayoutView(
            model: model,
            flags: _coachLive,
            onPayoutLater: () => later++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_button(tester, 'Continue').onPressed, isNull);
      await tester.ensureVisible(find.text('Add payout later'));
      await tester.tap(find.text('Add payout later'));
      await tester.pumpAndSettle();
      expect(later, 1);
    });

    test(
      'a certificate photo is uploaded, then recorded as checking',
      () async {
        final uploader = _FakeUploader();
        final state = CoachProfileState.instance..uploaderOverride = uploader;
        final result = await state.submitCertificatePhoto(
          credentialId: 'nasm_cpt',
          jpeg: Uint8List(8),
          signedInUid: 'coach1',
          now: _now,
        );

        expect(result, CertificateSubmission.sent);
        expect(
          uploader.mediaRefs.single,
          startsWith('coach-docs/coach1/nasm_cpt-'),
        );
        final certificate = state.setup.certificates.single;
        expect(certificate.credentialId, 'nasm_cpt');
        expect(certificate.mediaRef, uploader.mediaRefs.single);
      },
    );

    test('a photo that did not go is never shown as sent', () async {
      for (final (failure, expected) in [
        (
          CertificateUploadFailure.unreachable,
          CertificateSubmission.unreachable,
        ),
        (CertificateUploadFailure.refused, CertificateSubmission.refused),
      ]) {
        CoachProfileState.instance.reset();
        final state = CoachProfileState.instance
          ..uploaderOverride = _FakeUploader(failure: failure);
        final result = await state.submitCertificatePhoto(
          credentialId: 'nasm_cpt',
          jpeg: Uint8List(8),
          signedInUid: 'coach1',
        );
        expect(result, expected);
        expect(state.setup.certificates, isEmpty);
      }
    });

    test(
      'no account, or a credential not on the list, sends nothing',
      () async {
        final uploader = _FakeUploader();
        final state = CoachProfileState.instance..uploaderOverride = uploader;
        expect(
          await state.submitCertificatePhoto(
            credentialId: 'nasm_cpt',
            jpeg: Uint8List(8),
            signedInUid: null,
          ),
          CertificateSubmission.invalid,
        );
        expect(
          await state.submitCertificatePhoto(
            credentialId: 'personal trainer',
            jpeg: Uint8List(8),
            signedInUid: 'coach1',
          ),
          CertificateSubmission.invalid,
        );
        expect(uploader.mediaRefs, isEmpty);
      },
    );

    test(
      '"Add payout later" submits her application without a method',
      () async {
        final state = CoachProfileState.instance
          ..uploaderOverride = _FakeUploader();
        state.setup
          ..displayName = 'Hala'
          ..city = 'Tanta'
          ..capacityMax = 8;
        state.setup.specialties.add(Specialty.strength);
        await state.submitCertificatePhoto(
          credentialId: 'nasm_cpt',
          jpeg: Uint8List(8),
          signedInUid: 'coach1',
        );

        state.completeSetup();
        expect(
          state.profile.verification,
          CoachVerificationState.setupIncomplete,
          reason: 'Continue alone still needs a payout method',
        );

        state.completeSetup(payoutLater: true);
        expect(state.profile.verification, CoachVerificationState.submitted);
        expect(state.isSetupComplete, isTrue);
        expect(
          state.isTestCoach,
          isFalse,
          reason: 'no test rail in this build',
        );
      },
    );

    test(
      'the state machine: deferring the payout is not skipping a certificate',
      () {
        const machine = CoachVerificationStateMachine();
        expect(
          machine
              .transition(
                CoachVerificationState.setupIncomplete,
                const SetupCompleted(
                  hasCertificate: false,
                  hasPayoutMethod: false,
                  hasCapacity: true,
                  payoutDeferred: true,
                ),
              )
              .changed,
          isFalse,
        );
        expect(
          machine
              .transition(
                CoachVerificationState.setupIncomplete,
                const SetupCompleted(
                  hasCertificate: true,
                  hasPayoutMethod: false,
                  hasCapacity: true,
                  payoutDeferred: true,
                ),
              )
              .state,
          CoachVerificationState.submitted,
        );
      },
    );

    CoachTodayView today({
      required CoachVerificationState verification,
      VoidCallback? onBuild,
      VoidCallback? onInvite,
      int taken = 0,
    }) => CoachTodayView(
      now: _now,
      onSelectTab: (_) {},
      onBuildFirstPlan: onBuild,
      onInviteClient: onInvite,
      model: CoachTodayViewModel.from(
        profile: CoachProfile(
          displayName: 'Hala',
          capacity: CoachCapacity(max: 10, taken: taken),
          verification: verification,
        ),
        desk: CoachDesk(verification: verification),
        now: _now,
      ),
    );

    testWidgets('K07 keeps "Build your first plan" open while she is checked', (
      tester,
    ) async {
      _phone(tester);
      var built = 0;
      await tester.pumpWidget(
        _host(
          today(
            verification: CoachVerificationState.submitted,
            onBuild: () => built++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Build your first plan'), findsOneWidget);
      await tester.tap(find.text('Build your first plan'));
      await tester.pumpAndSettle();
      expect(built, 1);
    });

    testWidgets('and not once a woman has cleared her', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(today(verification: CoachVerificationState.verified)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Build your first plan'), findsNothing);
    });

    testWidgets('K02 opens the camera for a real photo, and says so when it '
        'cannot start', (tester) async {
      _phone(tester);
      _asVerifiedWoman();
      AppRouter.intakeRepository.markSetupDone();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(appDestinations['K02']!.name);
      await tester.pumpAndSettle();

      expect(find.byType(CoachCertificatesView), findsOneWidget);
      await tester.tap(find.text('NASM CPT'));
      // Not pumpAndSettle: the well spins while the lens is asked for.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(CertificateCameraView), findsOneWidget);
      // Closed without a photo: back on K02, and nothing was recorded.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CoachCertificatesView), findsOneWidget);
      expect(CoachProfileState.instance.setup.certificates, isEmpty);
    });

    testWidgets('the camera says why it did not open, and never crashes', (
      tester,
    ) async {
      _phone(tester);
      for (final (lenses, text) in [
        (
          () async => throw CameraException('CameraAccessDenied', 'no'),
          'Camera access is off. You can turn it on in settings.',
        ),
        (
          () async => throw MissingPluginException(),
          'The camera could not start. Close this and try again.',
        ),
        (
          () async => <CameraDescription>[],
          'The camera could not start. Close this and try again.',
        ),
      ]) {
        await tester.pumpWidget(
          _host(CertificateCameraView(key: UniqueKey(), lenses: lenses)),
        );
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
        expect(find.text('Take the photo'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Close'), findsOneWidget);
      }
    });
  });

  // ------------------------------------------------------------ R1-P16

  group('R1-P16: K13 carries the three rules', () {
    CoachSetupViewModel filled() =>
        CoachSetupViewModel(profile: const CoachProfile())
          ..displayName = 'Hala'
          ..city = 'Tanta';

    testWidgets('Continue waits for her agreement', (tester) async {
      _phone(tester);
      var continued = 0;
      await tester.pumpWidget(
        _host(CoachRulesView(model: filled(), onContinue: () => continued++)),
      );
      await tester.pumpAndSettle();

      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.n1WhatIsSaidHereStaysHere), findsOneWidget);
      expect(find.text(l10n.n2NoCommentsOnAnyoneElsesBody), findsOneWidget);
      expect(find.text(l10n.n3NoSellingNoRecruiting), findsOneWidget);
      expect(_button(tester, 'Continue').onPressed, isNull);

      await tester.ensureVisible(find.text('I agree to these three rules'));
      await tester.tap(find.text('I agree to these three rules'));
      await tester.pumpAndSettle();
      expect(_button(tester, 'Continue').onPressed, isNotNull);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, 1);
    });

    testWidgets('a woman who already agreed finds the box ticked', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachRulesView(model: filled()..rulesAgreed = true)),
      );
      await tester.pumpAndSettle();
      expect(_button(tester, 'Continue').onPressed, isNotNull);
    });

    testWidgets('in Arabic, in the same words as the pledge', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CoachRulesView(model: filled()), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('أوافق على هذه القواعد الثلاث'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------ R1-P17

  group('R1-P17: a coach is still a coach after a relaunch', () {
    test('the front door opens on her side once she is in', () {
      String door({
        bool accountRequired = true,
        bool verified = true,
        bool signedIn = true,
        bool coachSide = true,
        bool done = false,
      }) => AppRouter.frontDoorFor(
        accountRequired: accountRequired,
        verified: verified,
        signedIn: signedIn,
        coachSide: coachSide,
        coachSetupDone: done,
      );

      expect(door(), appRoutes['K01']!.name);
      expect(door(done: true), appRoutes['K07']!.name);
      expect(
        door(verified: false),
        appRoutes['T01']!.name,
        reason: 'not verified: Home, where the gate holds her',
      );
      expect(door(verified: false, signedIn: false), appRoutes['C01']!.name);
      expect(door(coachSide: false), appRoutes['T01']!.name);
      expect(
        door(accountRequired: false, verified: false),
        appRoutes['K01']!.name,
      );
    });

    test('the front door reads her kept role and her application', () {
      _asVerifiedWoman();
      RoleState.instance.roles = UserRoles.coach;
      expect(AppRouter.frontDoor, appRoutes['K01']!.name);

      CoachProfileState.instance.repository.applyServerProfileChange(
        const CoachProfile(verification: CoachVerificationState.submitted),
      );
      expect(AppRouter.frontDoor, appRoutes['K07']!.name);

      RoleState.instance.roles = UserRoles.both;
      expect(
        AppRouter.frontDoor,
        appRoutes['T01']!.name,
        reason: 'both opens on the trainee side',
      );

      AppRouter.featureFlags = _coachOff;
      RoleState.instance.roles = UserRoles.coach;
      expect(
        AppRouter.frontDoor,
        appRoutes['T01']!.name,
        reason: 'no coach side in the first release',
      );
    });

    test('the trainee setup questions are not owed to a coach only', () {
      _asVerifiedWoman();
      expect(OnboardingState.instance.isDue, isTrue);
      RoleState.instance.roles = UserRoles.coach;
      expect(OnboardingState.instance.isDue, isFalse);
      RoleState.instance.roles = UserRoles.both;
      expect(OnboardingState.instance.isDue, isTrue);
    });

    test('launch restores her roles, and only where there is a coach side', () {
      expect(launchRolesForTest(), UserRoles.trainee);
      RoleState.instance.roles = UserRoles.coach;
      expect(launchRolesForTest(), UserRoles.coach);
      AppRouter.featureFlags = _coachOff;
      expect(launchRolesForTest(), UserRoles.trainee);
    });

    test('roles, her application and a kept code round-trip the snapshot', () {
      RoleState.instance.roles = UserRoles.coach;
      CoachInviteState.instance.pendingCode = 'ABCD2345';
      final state = CoachProfileState.instance;
      state.setup
        ..displayName = 'Hala'
        ..city = 'Tanta'
        ..capacityMax = 8
        ..payoutLater = true;
      state.setup.specialties.add(Specialty.postpartum);
      state.saveSetup();
      state.repository.applyServerProfileChange(
        state.profile.copyWith(verification: CoachVerificationState.verified),
      );

      final raw = jsonEncode(AppSnapshot.capture());

      RoleState.instance.reset();
      CoachInviteState.instance.reset();
      state.reset();
      AppSnapshot.restore(raw);

      expect(RoleState.instance.roles, UserRoles.coach);
      expect(CoachInviteState.instance.pendingCode, 'ABCD2345');
      expect(state.profile.displayName, 'Hala');
      expect(state.profile.city, 'Tanta');
      expect(state.profile.specialties, {Specialty.postpartum});
      expect(state.profile.capacity.max, 8);
      expect(state.setup.payoutLater, isTrue);
      expect(
        state.profile.verification,
        CoachVerificationState.submitted,
        reason: '"verified" is the server\'s word, never restored from a phone',
      );
    });

    test('a trainee\'s snapshot carries no coach section', () {
      final snapshot = AppSnapshot.capture();
      expect(snapshot['coach'], isNull);
      expect(snapshot['invite'], isNull);
    });

    test('the server copy of her roles is read as she left it', () {
      expect(
        rolesFromUserDoc({
          'roles': {
            'held': ['coach'],
            'chosen': 'coach',
          },
        }),
        UserRoles.coach,
      );
      expect(
        rolesFromUserDoc({
          'roles': {
            'held': ['trainee', 'coach'],
          },
        }),
        UserRoles.both,
      );
      expect(
        rolesFromUserDoc({
          'roles': {
            'held': ['admin'],
          },
        }),
        isNull,
      );
      expect(rolesFromUserDoc(null), isNull);
    });
  });

  // ------------------------------------------------------------ R1-P18

  group('R1-P18: a coach invites a woman she already coaches', () {
    test('a code survives being copied out of a chat bubble', () {
      expect(normaliseInviteCode('abcd-2345'), 'ABCD2345');
      expect(normaliseInviteCode(' ABCD 2345 '), 'ABCD2345');
      expect(normaliseInviteCode('ABCD٢٣٤٥'), 'ABCD2345');
      expect(normaliseInviteCode('ABCD234'), isNull);
      expect(normaliseInviteCode('ABCD2340'), isNull, reason: 'no zero');
      expect(normaliseInviteCode('ABCDO345'), isNull, reason: 'no letter O');
      expect(displayInviteCode('ABCD2345'), 'ABCD-2345');
    });

    test('the WhatsApp message carries the code and nothing about her', () {
      final uri = whatsAppShareUri('Join me, code ABCD-2345');
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], 'Join me, code ABCD-2345');
    });

    test('a kept code is redeemed once she is in, and only then', () async {
      final store = InMemoryCoachInviteStore(code: 'ABCD2345');
      final invite = CoachInviteState.instance..pendingCode = 'ABCD2345';

      expect(await invite.redeem(store, allowed: false), isNull);
      expect(invite.pendingCode, 'ABCD2345', reason: 'kept until she is in');

      expect(
        await invite.redeem(store, allowed: true),
        InviteRedemption.linked,
      );
      expect(store.accepted, ['ABCD2345']);
      expect(invite.pendingCode, isNull);
      expect(await invite.redeem(store, allowed: true), isNull);
    });

    test('no network keeps the code; a dead code is dropped', () async {
      final invite = CoachInviteState.instance..pendingCode = 'ABCD2345';
      expect(
        await invite.redeem(_OfflineInviteStore(), allowed: true),
        InviteRedemption.unreachable,
      );
      expect(invite.pendingCode, 'ABCD2345');

      expect(
        await invite.redeem(
          InMemoryCoachInviteStore(code: 'ZZZZ2222'),
          allowed: true,
        ),
        InviteRedemption.refused,
      );
      expect(invite.pendingCode, isNull);
    });

    testWidgets('C01 takes the code, and refuses one that cannot be a code', (
      tester,
    ) async {
      _phone(tester);
      String? saved;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await showInviteCodeSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.byType(AppField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'nope');
      await tester.tap(find.text('Save the code'));
      await tester.pumpAndSettle();
      expect(
        find.text('That code does not look right. Check it and try again.'),
        findsOneWidget,
      );

      await tester.enterText(field, 'abcd-2345');
      await tester.tap(find.text('Save the code'));
      await tester.pumpAndSettle();
      expect(saved, 'ABCD2345');
    });

    testWidgets('K07 offers "Invite a client" when it is hers to offer', (
      tester,
    ) async {
      _phone(tester);
      var invited = 0;
      await tester.pumpWidget(
        _host(
          CoachTodayView(
            now: _now,
            onSelectTab: (_) {},
            onInviteClient: () => invited++,
            model: CoachTodayViewModel.from(
              profile: CoachProfile(
                displayName: 'Hala',
                capacity: CoachCapacity(max: 10, taken: 0),
                verification: CoachVerificationState.verified,
              ),
              desk: CoachDesk(verification: CoachVerificationState.verified),
              now: _now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Invite a client'));
      await tester.tap(find.text('Invite a client'));
      await tester.pumpAndSettle();
      expect(invited, 1);
    });
  });

  group('the app and the server name the same callables and fields', () {
    test('every coach callable exists in functions/main.py', () {
      final main = File('../functions/main.py').readAsStringSync();
      for (final name in [
        kRecordSignupRoleCallable,
        kSubmitCoachCertificateCallable,
        kCreateCoachInviteCallable,
        kAcceptCoachInviteCallable,
      ]) {
        expect(main, contains('def $name('), reason: name);
      }
    });

    test('and the fields each one reads are the ones the app sends', () {
      String read(String file) =>
          File('../functions/coaching/$file').readAsStringSync();
      for (final key in signupRolePayload(SignupRole.coach).keys) {
        expect(read('roles.py'), contains('data.get("$key")'));
      }
      for (final key in certificatePayload(
        credentialId: 'nasm_cpt',
        mediaRef: 'coach-docs/u/x.jpg',
      ).keys) {
        expect(read('certificates.py'), contains('data.get("$key")'));
      }
      expect(read('invites.py'), contains('data.get("code")'));
      expect(read('invites.py'), contains('ALPHABET = "$kInviteAlphabet"'));
      expect(
        certificateMediaRef(coachUid: 'u1', credentialId: 'nasm_cpt', at: _now),
        matches(RegExp(r'^coach-docs/u1/nasm_cpt-\d+\.jpg$')),
      );
    });
  });

  // ------------------------------------------------- R1-P25 and M3

  group('R1-P25: a coach who arrives early is heard', () {
    testWidgets('C01 offers "I coach women" while the coach app is off, and '
        'the invite code while it is on', (tester) async {
      _phone(tester);
      AppRouter.featureFlags = _coachOff;
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeView), findsOneWidget);
      expect(find.text('I coach women'), findsOneWidget);
      expect(find.text('I have a code from my coach'), findsNothing);

      AppRouter.featureFlags = _coachLive;
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(find.text('I coach women'), findsNothing);
      expect(find.text('I have a code from my coach'), findsOneWidget);
    });

    testWidgets('the form opens a message to the team, by email until a '
        'WhatsApp number is set', (tester) async {
      _phone(tester);
      final opened = <Uri>[];
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: CoachInterestForm(
              open: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('We open coaching soon'), findsOneWidget);
      expect(_button(tester, 'Send by email').onPressed, isNull);

      final fields = find.descendant(
        of: find.byType(AppField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(fields.at(0), 'Salma');
      await tester.enterText(fields.at(1), 'Alexandria');
      await tester.enterText(fields.at(2), 'postpartum strength');
      await tester.pump();
      await tester.tap(find.text('Send by email'));
      await tester.pumpAndSettle();

      final uri = opened.single;
      expect(uri.scheme, 'mailto');
      final body = Uri.decodeComponent(uri.query);
      expect(body, contains('Salma'));
      expect(body, contains('Alexandria'));
      expect(body, contains('postpartum strength'));
    });

    test('with a team number it is a WhatsApp message to that number', () {
      final uri = coachInterestUri(
        subject: 's',
        body: 'Name: Salma',
        whatsApp: '+20 100 000 0000',
      );
      expect(uri.toString(), startsWith('https://wa.me/201000000000?text='));
      expect(uri.queryParameters['text'], 'Name: Salma');
    });

    testWidgets('a message that could not open is said, not swallowed', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: CoachInterestForm(
              whatsApp: '+201000000000',
              open: (_) async => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AppField),
        matching: find.byType(EditableText),
      );
      for (var i = 0; i < 3; i++) {
        await tester.enterText(fields.at(i), 'x');
      }
      await tester.pump();
      await tester.tap(find.text('Send on WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        find.text('We could not open a message on this phone.'),
        findsOneWidget,
      );
    });
  });

  group('M3: Back through her setup goes back, it does not push', () {
    testWidgets('every step, last to first, in that order', (tester) async {
      _phone(tester);
      _asVerifiedWoman();
      AppRouter.intakeRepository.markSetupDone();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      // Every step she meets up to getting paid, in her order.
      final walk = [
        for (final step in coachSetupWalk())
          if (step != CoachSetupStep.beingChecked) step.screenId,
      ];
      expect(walk.first, 'K01');
      expect(walk.last, 'K05');
      for (final id in walk) {
        navigator.pushNamed(appDestinations[id]!.name);
        await tester.pumpAndSettle();
      }
      expect(find.byType(CoachPayoutView), findsOneWidget);

      Future<void> back() async {
        await tester.tap(find.byTooltip('Back').last);
        await tester.pumpAndSettle();
      }

      // Each Back lands on the step before it, and nothing is pushed.
      for (var i = walk.length - 2; i >= 0; i--) {
        await back();
        expect(
          find.text(
            '${i + 1} of ${CoachSetupStep.total}',
            skipOffstage: true,
          ),
          findsOneWidget,
          reason: 'Back from ${walk[i + 1]} lands on ${walk[i]}',
        );
      }
      expect(find.byType(CoachPhotoView), findsOneWidget);
      expect(
        find.byType(CoachPayoutView),
        findsNothing,
        reason: 'a push would have left K05 underneath',
      );
    });
  });
}

UserRoles launchRolesForTest() => launchRoles(AppRouter.featureFlags);
