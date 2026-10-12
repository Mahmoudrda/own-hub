// What the two capture screens do once there is a real camera behind them:
// both sides of the card, live guidance, and a shutter that fires itself.
//
// In a separate file from id_capture_view_test.dart and
// selfie_capture_view_test.dart, which assert the screens as designed. These
// are the additions, and keeping them apart makes it obvious which assertions
// predate the camera.

import 'dart:async';

import 'package:camera/camera.dart' show CameraDescription, CameraLensDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/data/camera_capture_service.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/liveness_challenge.dart';
import 'package:own_hub/features/signup/domain/verification_evidence.dart';
import 'package:own_hub/features/signup/presentation/id_capture_view.dart';
import 'package:own_hub/features/signup/presentation/selfie_capture_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_white_button.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

/// A session a test can drive frame by frame, so the screens can be asserted
/// against guidance and auto-capture without a camera.
///
/// It is not exported from `lib/`, and it cannot be mistaken for a camera: it
/// emits exactly what a test tells it to.
class _DrivenSession implements CaptureSession {
  _DrivenSession(this.target);

  final CaptureTarget target;
  final _states = StreamController<CaptureState>.broadcast();
  CaptureState _state = const CaptureState.framing(sharp: false);
  int captures = 0;
  bool closed = false;

  void emit(CaptureState state) {
    _state = state;
    _states.add(state);
  }

  @override
  CaptureState get current => _state;

  @override
  Stream<CaptureState> watch() async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Future<void> capture() async => captures++;

  @override
  Future<void> close() async {
    closed = true;
    await _states.close();
  }
}

class _DrivenService implements CaptureService {
  final List<_DrivenSession> opened = <_DrivenSession>[];

  @override
  Future<CaptureSession> open(CaptureTarget target) async {
    final session = _DrivenSession(target);
    opened.add(session);
    return session;
  }
}

void main() {
  group('the back of the card', () {
    testWidgets('is its own pass of the same screen, with its own copy', (
      tester,
    ) async {
      // The back prints the sex as a word, أنثى or ذكر, which is an independent
      // reading of what the 13th digit says. It is a second check, not a second
      // photograph of the same thing, so it gets its own instruction.
      final service = _DrivenService();
      await tester.pumpWidget(
        _host(
          IdCaptureView(captureService: service, side: CaptureTarget.idBack),
        ),
      );
      await tester.pumpAndSettle();

      expect(service.opened.single.target, CaptureTarget.idBack);
      expect(find.text('The back of your card'), findsOneWidget);
      expect(find.text('Turn the card over'), findsOneWidget);
      expect(find.text('back of the card'), findsOneWidget);
      // The front's copy must not leak into the back's pass.
      expect(find.text('Your ID card'), findsNothing);
    });

    testWidgets('reads in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(
          IdCaptureView(
            captureService: _DrivenService(),
            side: CaptureTarget.idBack,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ضهر بطاقتك'), findsOneWidget);
      expect(find.text('اقلبي البطاقة'), findsOneWidget);
    });
  });

  group('live guidance', () {
    testWidgets('shows the one correction, and nothing when there is none', (
      tester,
    ) async {
      final service = _DrivenService();
      await tester.pumpWidget(_host(IdCaptureView(captureService: service)));
      await tester.pumpAndSettle();

      // Null most of the time, and that is the design: a viewfinder with a
      // permanent instruction on it is a viewfinder she stops reading.
      expect(find.text('There is not enough light'), findsNothing);

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.moreLight,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('There is not enough light'), findsOneWidget);

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.lessGlare,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tilt the card to cut the glare'), findsOneWidget);
      expect(find.text('There is not enough light'), findsNothing);

      service.opened.single.emit(const CaptureState.framing(sharp: true));
      await tester.pumpAndSettle();
      expect(find.text('Tilt the card to cut the glare'), findsNothing);
    });

    testWidgets('says "hold the card still" on the card and "hold still" on '
        'the selfie', (tester) async {
      // One shared sentence would have had to be vague enough to be useless in
      // both places.
      final cardService = _DrivenService();
      await tester.pumpWidget(
        _host(IdCaptureView(captureService: cardService)),
      );
      await tester.pumpAndSettle();
      cardService.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.holdSteady,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hold the card still'), findsOneWidget);

      final selfieService = _DrivenService();
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: selfieService)),
      );
      await tester.pumpAndSettle();
      selfieService.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.holdSteady,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hold still'), findsOneWidget);
    });

    testWidgets('guidance is announced to a screen reader as it changes', (
      tester,
    ) async {
      // A viewfinder is worth nothing to a woman using TalkBack unless the
      // correction is spoken, and a live region is what makes it spoken again
      // each time it changes.
      final handle = tester.ensureSemantics();
      final service = _DrivenService();
      await tester.pumpWidget(_host(IdCaptureView(captureService: service)));
      await tester.pumpAndSettle();

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.moveCloser,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Move a little closer')),
        matchesSemantics(label: 'Move a little closer', isLiveRegion: true),
      );
      handle.dispose();
    });
  });

  group('the shutter', () {
    testWidgets('the card photographs itself and reports once', (tester) async {
      // Auto-capture is what removes the blurry-photo retry loop. The screen
      // has to react to the camera taking its own picture, and it must not push
      // the next route twice when the manual and automatic paths overlap.
      final service = _DrivenService();
      var captured = 0;
      await tester.pumpWidget(
        _host(
          IdCaptureView(captureService: service, onCaptured: () => captured++),
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, 0);

      service.opened.single.emit(const CaptureState.captured());
      await tester.pumpAndSettle();
      expect(captured, 1);

      service.opened.single.emit(const CaptureState.captured());
      await tester.pumpAndSettle();
      expect(captured, 1, reason: 'one capture is one navigation');
    });

    testWidgets('the selfie waits until the framing is good', (tester) async {
      // Unlike the card, where she may always override because she can see the
      // card and we can only see a number. Here the frame itself is the thing
      // being judged, and a still with two faces in it or none costs her a
      // check she did nothing to earn.
      final service = _DrivenService();
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.onlyOneFace,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Only one face in the frame'), findsOneWidget);
      expect(
        tester.widget<AppWhiteButton>(find.byType(AppWhiteButton)).onPressed,
        isNull,
      );

      service.opened.single.emit(const CaptureState.framing(sharp: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppWhiteButton>(find.byType(AppWhiteButton)).onPressed,
        isNotNull,
      );
    });
  });

  group('the liveness challenge', () {
    testWidgets('prompts the server\'s step and counts her through it', (
      tester,
    ) async {
      // The sequence is the server's. The screen's whole job is to say which
      // step she is on and what it is, in her language, and then get out of
      // the way while the frames are taken.
      final service = _DrivenService();
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.blink,
          stepNumber: 2,
          stepCount: 4,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Blink slowly'), findsOneWidget);
      // The designed headline steps aside while a challenge is running.
      expect(find.text('Look straight ahead. No smile needed.'), findsNothing);
    });

    testWidgets('every step the server can send has copy in both languages', (
      tester,
    ) async {
      // A step with no sentence behind it would be a woman staring at a blank
      // prompt she cannot answer. The mapping is exhaustive in Dart; this is
      // the half that proves the strings exist and are translated.
      const prompts = <CaptureGuidance, (String, String)>{
        CaptureGuidance.lookStraight: (
          'Look straight ahead',
          'بصّي قدّامك على طول',
        ),
        CaptureGuidance.blink: ('Blink slowly', 'رمّشي بالراحة'),
        CaptureGuidance.turnLeft: (
          'Turn your head slightly to the left',
          'لفّي راسك شوية ناحية الشمال',
        ),
        CaptureGuidance.turnRight: (
          'Turn your head slightly to the right',
          'لفّي راسك شوية ناحية اليمين',
        ),
      };

      for (final entry in prompts.entries) {
        for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
          final service = _DrivenService();
          await tester.pumpWidget(
            _host(
              SelfieCaptureView(
                // A fresh key per iteration, or Flutter reuses the State at
                // this position and initState never runs again, so the second
                // service is handed a screen that never opened a session.
                key: ValueKey('${entry.key.name}-${locale.languageCode}'),
                captureService: service,
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          service.opened.single.emit(
            CaptureState.framing(
              sharp: false,
              guidance: entry.key,
              stepNumber: 1,
              stepCount: 1,
            ),
          );
          await tester.pumpAndSettle();

          final expected = locale.languageCode == 'en'
              ? entry.value.$1
              : entry.value.$2;
          expect(
            find.text(expected),
            findsOneWidget,
            reason: '${entry.key.name} in ${locale.languageCode}',
          );
        }
      }
    });

    testWidgets('a framing problem outranks the prompt', (tester) async {
      // There is no point asking her to blink at a lens that cannot see her
      // face. The session sends the framing correction instead and the step
      // counter stays put.
      final service = _DrivenService();
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.centreYourFace,
          stepNumber: 3,
          stepCount: 4,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bring your face into the circle'), findsOneWidget);
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('Blink slowly'), findsNothing);
    });

    testWidgets('the shutter is not hers while the server is asking', (
      tester,
    ) async {
      // A button she could press between prompts would take a frame answering
      // the wrong step, and the server matches frame n against step n.
      final service = _DrivenService();
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();

      service.opened.single.emit(
        const CaptureState.framing(
          sharp: false,
          guidance: CaptureGuidance.turnLeft,
          stepNumber: 1,
          stepCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppWhiteButton>(find.byType(AppWhiteButton)).onPressed,
        isNull,
      );
    });
  });

  group('CameraCaptureService without a camera', () {
    test('a phone with no rear lens refuses rather than using the front one', () async {
      // A front camera pointed at a card gives a mirrored, soft photograph that
      // fails server side, so "this phone cannot do this" is the useful answer.
      final service = CameraCaptureService(
        evidence: VerificationEvidence(),
        lenses: () async => const <CameraDescription>[
          CameraDescription(
            name: 'front',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 270,
          ),
        ],
      );

      final session = await service.open(CaptureTarget.idFront);
      expect(
        session.current,
        isA<CaptureUnavailable>().having(
          (state) => state.reason,
          'reason',
          CaptureUnavailableReason.noCamera,
        ),
      );
      // And it never pretends: a refusing session throws rather than silently
      // succeeding, which is what would turn a missing camera into a screen
      // that claims to have photographed an ID card.
      expect(session.capture, throwsStateError);
    });

    test('the selfie refuses when there is no challenge to prompt', () async {
      // A lone photograph the server has no question to match against is not a
      // cheaper liveness check, it is a frame nothing can score. She goes to
      // the video call, which is a path that already exists and already works.
      final service = CameraCaptureService(
        evidence: VerificationEvidence(),
        lenses: () async => const <CameraDescription>[
          CameraDescription(
            name: 'front',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 270,
          ),
        ],
      );

      final session = await service.open(CaptureTarget.selfie);
      expect(
        session.current,
        isA<CaptureUnavailable>().having(
          (state) => state.reason,
          'reason',
          CaptureUnavailableReason.providerUnavailable,
        ),
      );
    });

    test('and when the challenge contains a step it cannot prompt', () async {
      final service = CameraCaptureService(
        evidence: VerificationEvidence(),
        challenge: LivenessChallenge(
          sessionId: 's',
          steps: const <LivenessStep>[LivenessStep.unsupported],
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
        lenses: () async => const <CameraDescription>[
          CameraDescription(
            name: 'front',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 270,
          ),
        ],
      );

      final session = await service.open(CaptureTarget.selfie);
      expect(session.current, isA<CaptureUnavailable>());
    });

    test('no cameras at all is the same honest answer', () async {
      final service = CameraCaptureService(
        evidence: VerificationEvidence(),
        lenses: () async => const <CameraDescription>[],
      );
      final session = await service.open(CaptureTarget.idFront);
      expect(session.current.isLive, isFalse);
      expect(session.current, isA<CaptureUnavailable>());
    });
  });

  // A5. A camera that cannot run used to leave an empty frame and a disabled
  // button. Every reason now says what happened and offers a way forward.
  group('a camera that cannot run is never a dead end', () {
    for (final reason in CaptureUnavailableReason.values) {
      for (final selfie in [false, true]) {
        testWidgets('${reason.name}, ${selfie ? 'selfie' : 'card'}', (
          tester,
        ) async {
          var settings = 0;
          final askedWith = <CaptureUnavailableReason>[];
          final service = UnavailableCaptureService(reason: reason);
          await tester.pumpWidget(
            _host(
              selfie
                  ? SelfieCaptureView(
                      captureService: service,
                      onOpenSettings: () => settings++,
                      onAskReviewer: askedWith.add,
                    )
                  : IdCaptureView(
                      captureService: service,
                      onOpenSettings: () => settings++,
                      onAskReviewer: askedWith.add,
                    ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('capture-unavailable')),
            findsOneWidget,
          );
          final primary = tester.widget<AppWhiteButton>(
            find.byType(AppWhiteButton),
          );
          expect(primary.onPressed, isNotNull, reason: 'never a dead button');

          if (reason == CaptureUnavailableReason.permissionDenied) {
            expect(find.text('Camera access is off'), findsOneWidget);
            await tester.tap(find.text('Open settings'));
            await tester.pumpAndSettle();
            expect(settings, 1);
          } else {
            expect(find.text('Try again'), findsOneWidget);
          }

          await tester.tap(find.text('Check me another way'));
          await tester.pumpAndSettle();
          expect(askedWith, [reason]);
        });
      }
    }

    testWidgets('back from Settings, the camera is asked for again', (
      tester,
    ) async {
      final service = _CountingUnavailable();
      await tester.pumpWidget(
        _host(IdCaptureView(captureService: service, onOpenSettings: () {})),
      );
      await tester.pumpAndSettle();
      expect(service.opens, 1);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(service.opens, 2);
    });
  });

  // A6. A dropped connection as the liveness session starts keeps her on the
  // back of the card with her photographs, and offers a person only after
  // retries have failed too.
  group('a network blip at the hand-off is a retry, not a review', () {
    testWidgets('offline keeps her here, and Try again asks again', (
      tester,
    ) async {
      final service = _DrivenService();
      final answers = <CaptureHandOff>[
        CaptureHandOff.offline,
        CaptureHandOff.offline,
        CaptureHandOff.offlineOfferReviewer,
        CaptureHandOff.moved,
      ];
      var handOffs = 0;
      var reviewer = 0;
      await tester.pumpWidget(
        _host(
          IdCaptureView(
            captureService: service,
            side: CaptureTarget.idBack,
            onHandOff: () async => answers[handOffs++],
            onAskReviewer: (_) => reviewer++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      service.opened.single.emit(const CaptureState.captured());
      await tester.pumpAndSettle();

      expect(handOffs, 1);
      expect(
        find.text('No connection. Your photos are still here, try again.'),
        findsOneWidget,
      );
      expect(find.text('Check me another way'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(handOffs, 2, reason: 'asked again, without a new photograph');
      expect(service.opened, hasLength(1), reason: 'the camera stayed shut');
      expect(find.text('Check me another way'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(handOffs, 3);
      expect(find.text('Check me another way'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(handOffs, 4);
      expect(reviewer, 0);
    });
  });
}

/// Refuses the camera every time, and counts how often it was asked.
class _CountingUnavailable implements CaptureService {
  int opens = 0;

  @override
  Future<CaptureSession> open(CaptureTarget target) async {
    opens++;
    return const UnavailableCaptureService(
      reason: CaptureUnavailableReason.permissionDenied,
    ).open(target);
  }
}
