// Her shutter, and her say before anything is used.
//
// On a real iPhone the selfie never photographed itself: it waited for 1.2
// seconds of a detector-approved face, and turning her head kept resetting
// that clock. The back of the card photographed the front a second time,
// because its camera opened while the card was still the right way up. These
// are the guards for the fix: a shutter that works on any live frame, one frame
// per step in the server's order, a review before every use, "Now turn the card
// over" before the back's camera opens, and a quiet way to a woman reviewer on
// every capture screen.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/id_capture.dart';
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

const List<CaptureGuidance> _challenge = [
  CaptureGuidance.lookStraight,
  CaptureGuidance.turnLeft,
  CaptureGuidance.turnRight,
  CaptureGuidance.blink,
];

/// A session that behaves the way the camera service's contract says, with no
/// camera: one frame per press, the next step's prompt after it, `captured`
/// after the last. It is not exported from `lib/` and it cannot be mistaken for
/// a camera.
class _FakeSession implements CaptureSession, CaptureReview {
  _FakeSession(
    this.target, {
    this.steps = const <CaptureGuidance>[],
    this.hint,
    this.faceOnBack = false,
    this.finishEarly = false,
  }) {
    _state = _framingFor(0);
  }

  /// A broken run: `captured` arrives one frame short of the steps.
  final bool finishEarly;

  final CaptureTarget target;
  final List<CaptureGuidance> steps;

  /// A framing hint sent with every step, such as "no face found".
  final CaptureGuidance? hint;
  final bool faceOnBack;

  final _states = StreamController<CaptureState>.broadcast();
  late CaptureState _state;

  int _step = 0;
  int captures = 0;
  int discards = 0;
  bool closed = false;

  /// The step each frame answered, in the order they were taken.
  final List<CaptureGuidance> answered = <CaptureGuidance>[];
  bool _cardTaken = false;

  /// Holds a press in flight until the test lets it go.
  Completer<void>? hold;

  CaptureState _framingFor(int index) => steps.isEmpty
      ? CaptureState.framing(sharp: false, guidance: hint)
      : CaptureState.framing(
          sharp: false,
          guidance: hint,
          prompt: steps[index],
          stepNumber: index + 1,
          stepCount: steps.length,
        );

  void emit(CaptureState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  void fail(Object error) {
    if (!_states.isClosed) _states.addError(error);
  }

  @override
  CaptureState get current => _state;

  @override
  Stream<CaptureState> watch() async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Future<void> capture() async {
    captures++;
    final waiting = hold;
    if (waiting != null) await waiting.future;
    if (steps.isEmpty) {
      _cardTaken = true;
      emit(const CaptureState.captured());
      return;
    }
    answered.add(steps[_step]);
    final last = finishEarly ? steps.length - 1 : steps.length;
    if (_step + 1 < last) {
      _step++;
      emit(_framingFor(_step));
    } else {
      emit(const CaptureState.captured());
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await _states.close();
  }

  @override
  int get takenCount => steps.isEmpty ? (_cardTaken ? 1 : 0) : answered.length;

  @override
  int get neededCount => steps.isEmpty ? 1 : steps.length;

  @override
  Widget buildTaken(int index) =>
      SizedBox.expand(key: ValueKey('taken-$index'));

  @override
  bool get looksLikeFront => target == CaptureTarget.idBack && faceOnBack;

  @override
  void discardTaken() {
    discards++;
    answered.clear();
    _cardTaken = false;
  }
}

class _FakeService implements CaptureService {
  _FakeService({
    this.steps = const <CaptureGuidance>[],
    this.hint,
    this.faceOnBack = false,
    this.finishEarlyOnce = false,
  });

  final List<CaptureGuidance> steps;
  final CaptureGuidance? hint;
  final bool faceOnBack;

  /// The first session opened ends one frame short; later ones are whole.
  final bool finishEarlyOnce;
  final List<_FakeSession> opened = <_FakeSession>[];

  @override
  Future<CaptureSession> open(CaptureTarget target) async {
    final session = _FakeSession(
      target,
      steps: target == CaptureTarget.selfie ? steps : const [],
      hint: hint,
      faceOnBack: faceOnBack,
      finishEarly: finishEarlyOnce && opened.isEmpty,
    );
    opened.add(session);
    return session;
  }
}

VoidCallback? _shutter(WidgetTester tester) =>
    tester.widget<AppWhiteButton>(find.byType(AppWhiteButton)).onPressed;

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('the selfie shutter is hers', () {
    testWidgets('enabled with no face detected', (tester) async {
      final service = _FakeService(
        steps: _challenge,
        hint: CaptureGuidance.centreYourFace,
      );
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();

      // The hint is shown as advice, beside the step, and blocks nothing.
      expect(find.text('Bring your face into the circle'), findsOneWidget);
      expect(find.text('Look straight at the camera'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(_shutter(tester), isNotNull);

      await _tap(tester, 'Take photo');
      expect(service.opened.single.captures, 1);
    });

    testWidgets('enabled when the detector throws', (tester) async {
      final service = _FakeService(steps: _challenge);
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();

      service.opened.single.fail(
        PlatformException(code: 'mlkit', message: 'detector failed'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_shutter(tester), isNotNull);
      await _tap(tester, 'Take photo');
      expect(service.opened.single.captures, 1);
      expect(
        find.text('Turn your head a little to your left'),
        findsOneWidget,
        reason: 'on to the next step',
      );
    });

    testWidgets('a second tap while the shutter is busy takes nothing', (
      tester,
    ) async {
      // A double tap would otherwise answer two steps with one pose.
      final service = _FakeService(steps: _challenge);
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();
      final session = service.opened.single..hold = Completer<void>();

      await tester.tap(find.text('Take photo'));
      await tester.pump();
      expect(_shutter(tester), isNull);
      await tester.tap(find.text('Take photo'), warnIfMissed: false);
      await tester.pump();
      expect(session.captures, 1);

      session.hold!.complete();
      await tester.pumpAndSettle();
      expect(session.answered, [CaptureGuidance.lookStraight]);
      expect(_shutter(tester), isNotNull);
    });
  });

  group('one frame per step, in order, then her review', () {
    testWidgets('each step is prompted big, and each press answers it', (
      tester,
    ) async {
      final service = _FakeService(steps: _challenge);
      var captured = 0;
      await tester.pumpWidget(
        _host(
          SelfieCaptureView(
            captureService: service,
            onCaptured: () => captured++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const prompts = [
        'Look straight at the camera',
        'Turn your head a little to your left',
        'Turn your head a little to your right',
        'Blink slowly',
      ];
      for (var i = 0; i < prompts.length; i++) {
        expect(find.text(prompts[i]), findsOneWidget, reason: 'step ${i + 1}');
        expect(find.text('Step ${i + 1} of 4'), findsOneWidget);
        await _tap(tester, 'Take photo');
      }

      final session = service.opened.single;
      expect(session.captures, 4);
      expect(session.answered, _challenge, reason: 'frame n answers step n');

      // The review gates continuation.
      expect(find.text('Check your photos'), findsOneWidget);
      expect(find.byKey(const ValueKey('capture-review-photos')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('taken-$i')), findsOneWidget);
      }
      expect(captured, 0);
      expect(find.text('Take photo'), findsNothing);

      await _tap(tester, 'Use these photos');
      expect(captured, 1);
    });

    testWidgets('Retake wipes the frames and starts again from step 1', (
      tester,
    ) async {
      final service = _FakeService(steps: _challenge);
      var captured = 0;
      await tester.pumpWidget(
        _host(
          SelfieCaptureView(
            captureService: service,
            onCaptured: () => captured++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await _tap(tester, 'Take photo');
      }
      expect(find.text('Use these photos'), findsOneWidget);

      await _tap(tester, 'Retake');

      final first = service.opened.first;
      expect(first.discards, 1);
      expect(first.answered, isEmpty);
      expect(first.closed, isTrue);
      expect(service.opened, hasLength(2), reason: 'a fresh run of the steps');
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Look straight at the camera'), findsOneWidget);
      expect(find.text('Use these photos'), findsNothing);
      expect(captured, 0);
    });

    testWidgets('a session that runs out offers Start again, with a new one', (
      tester,
    ) async {
      final service = _FakeService(steps: _challenge);
      var expiresAt = DateTime.now().add(const Duration(seconds: 20));
      var startAgain = 0;
      var captured = 0;
      await tester.pumpWidget(
        _host(
          SelfieCaptureView(
            captureService: service,
            expiresAt: () => expiresAt,
            onCaptured: () => captured++,
            onStartAgain: () async {
              startAgain++;
              expiresAt = DateTime.now().add(const Duration(minutes: 5));
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Take photo');

      // Fifteen seconds of margin for the submit: gone after about five.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Time is up for this step'), findsOneWidget);
      expect(service.opened.single.discards, 1, reason: 'frames wiped');
      expect(find.text('Take photo'), findsNothing);

      await _tap(tester, 'Start again');
      expect(startAgain, 1);
      expect(service.opened, hasLength(2));
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(captured, 0);
    });
  });

  group('the card, front then back', () {
    testWidgets('the front must be confirmed before anything moves on', (
      tester,
    ) async {
      final service = _FakeService();
      var captured = 0;
      await tester.pumpWidget(
        _host(
          IdCaptureView(captureService: service, onCaptured: () => captured++),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, 'Take it myself');
      expect(find.text('Check your photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('capture-review-photo')), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      expect(captured, 0);

      await _tap(tester, 'Use this photo');
      expect(captured, 1);
      expect(
        service.opened.single.closed,
        isTrue,
        reason: 'the lens is let go before the back opens its own',
      );
    });

    testWidgets('Retake on the card wipes it and opens the camera again', (
      tester,
    ) async {
      final service = _FakeService();
      var captured = 0;
      await tester.pumpWidget(
        _host(
          IdCaptureView(captureService: service, onCaptured: () => captured++),
        ),
      );
      await tester.pumpAndSettle();
      // The card photographs itself; the review follows all the same.
      service.opened.single.emit(const CaptureState.captured());
      await tester.pumpAndSettle();
      expect(find.text('Use this photo'), findsOneWidget);

      await _tap(tester, 'Retake');
      expect(service.opened.first.discards, 1);
      expect(service.opened, hasLength(2));
      expect(find.text('Take it myself'), findsOneWidget);
      expect(captured, 0);
    });

    testWidgets('the back opens its camera only after Ready', (tester) async {
      final service = _FakeService();
      await tester.pumpWidget(
        _host(
          IdCaptureView(captureService: service, side: CaptureTarget.idBack),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Now turn the card over'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(service.opened, isEmpty, reason: 'no camera, so no auto-capture');

      await _tap(tester, 'Ready');
      expect(service.opened.single.target, CaptureTarget.idBack);
      expect(find.text('Take it myself'), findsOneWidget);
      expect(_shutter(tester), isNotNull);
    });

    testWidgets('a face on the back asks whether this is the front', (
      tester,
    ) async {
      final service = _FakeService(faceOnBack: true);
      var captured = 0;
      await tester.pumpWidget(
        _host(
          IdCaptureView(
            captureService: service,
            side: CaptureTarget.idBack,
            onCaptured: () => captured++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Ready');
      await _tap(tester, 'Take it myself');

      expect(
        find.text('This looks like the front of the card. Retake?'),
        findsOneWidget,
      );
      // Advice only: she can still use it.
      await _tap(tester, 'Use this photo');
      expect(captured, 1);
    });

    testWidgets('no face on the back, no warning', (tester) async {
      final service = _FakeService();
      await tester.pumpWidget(
        _host(
          IdCaptureView(captureService: service, side: CaptureTarget.idBack),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Ready');
      await _tap(tester, 'Take it myself');

      expect(find.text('Check your photo'), findsOneWidget);
      expect(
        find.text('This looks like the front of the card. Retake?'),
        findsNothing,
      );
    });

    testWidgets('the front never shows the back-of-card warning', (
      tester,
    ) async {
      final service = _FakeService(faceOnBack: true);
      await tester.pumpWidget(_host(IdCaptureView(captureService: service)));
      await tester.pumpAndSettle();
      await _tap(tester, 'Take it myself');
      expect(
        find.text('This looks like the front of the card. Retake?'),
        findsNothing,
      );
    });
  });

  group('a woman reviewer is one quiet link away', () {
    const link = 'Having trouble? Ask a woman to check you';

    for (final screen in const ['C10', 'C10b', 'C11']) {
      testWidgets('on $screen', (tester) async {
        var asked = 0;
        final service = _FakeService(steps: _challenge);
        await tester.pumpWidget(
          _host(switch (screen) {
            'C10' => IdCaptureView(
              captureService: service,
              onAskWoman: () => asked++,
            ),
            'C10b' => IdCaptureView(
              captureService: service,
              side: CaptureTarget.idBack,
              onAskWoman: () => asked++,
            ),
            _ => SelfieCaptureView(
              captureService: service,
              onAskWoman: () => asked++,
            ),
          }),
        );
        await tester.pumpAndSettle();

        expect(find.text(link), findsOneWidget);
        await _tap(tester, link);
        expect(asked, 1);
      });
    }

    testWidgets('and in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(
          SelfieCaptureView(
            captureService: _FakeService(steps: _challenge),
            onAskWoman: () {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('في مشكلة؟ اطلبي واحدة ست تتحقق منك'), findsOneWidget);
      expect(find.text('بصّي في الكاميرا على طول'), findsOneWidget);
      expect(find.text('صوّري'), findsOneWidget);
    });

    test('the router wires it on all three, to the woman reviewer', () {
      final src = File('lib/routing/app_router.dart').readAsStringSync();
      for (final id in const ['C10', 'C10b', 'C11']) {
        final from = src.indexOf("    '$id': (context)");
        expect(from, isNot(-1), reason: id);
        final next = src.indexOf(
          RegExp("\\n    '[A-Z]\\d{2}[a-z]?': \\(context\\)"),
          from + 1,
        );
        final block = src
            .substring(from, next)
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        final link = block.indexOf('onAskWoman:');
        expect(link, isNot(-1), reason: id);
        final wiring = block.substring(link);
        expect(wiring, contains('ReviewPath.declined'), reason: id);
        expect(wiring, contains("goTo(context, 'C15')"), reason: id);
      }
    });
  });

  group('every new state fits a small phone at the largest text', () {
    Future<void> pumpSmall(WidgetTester tester, Widget view) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('ar')),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: view,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the back before Ready, and its review with the warning', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        IdCaptureView(
          captureService: _FakeService(faceOnBack: true),
          side: CaptureTarget.idBack,
          onAskWoman: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, 'جاهزة');
      await _tap(tester, 'هصوّرها بنفسي');
      expect(find.text('استخدمي الصورة دي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a step with a hint, the review and the timeout', (
      tester,
    ) async {
      await pumpSmall(
        tester,
        SelfieCaptureView(
          captureService: _FakeService(
            steps: _challenge,
            hint: CaptureGuidance.moreLight,
          ),
          expiresAt: () => DateTime.now().add(const Duration(minutes: 2)),
          onStartAgain: () async => false,
          onAskWoman: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        await _tap(tester, 'صوّري');
      }
      expect(find.text('استخدمي الصور دي'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
      expect(find.text('ابدئي من تاني'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('leaving for a woman reviewer leaves nothing running', () {
    for (final screen in const ['C10', 'C10b', 'C11']) {
      testWidgets('on $screen the camera is closed and the photos wiped first', (
        tester,
      ) async {
        final service = _FakeService(steps: _challenge);
        _FakeSession? session;
        var closedFirst = false;
        var wipedFirst = false;
        void ask() {
          final open = session!;
          closedFirst = open.closed;
          wipedFirst = open.discards == 1;
        }

        await tester.pumpWidget(
          _host(switch (screen) {
            'C10' => IdCaptureView(captureService: service, onAskWoman: ask),
            'C10b' => IdCaptureView(
              captureService: service,
              side: CaptureTarget.idBack,
              onAskWoman: ask,
            ),
            _ => SelfieCaptureView(captureService: service, onAskWoman: ask),
          }),
        );
        await tester.pumpAndSettle();
        if (screen == 'C10b') await _tap(tester, 'Ready');
        session = service.opened.single;
        await _tap(tester, screen == 'C11' ? 'Take photo' : 'Take it myself');

        await _tap(tester, 'Having trouble? Ask a woman to check you');

        expect(closedFirst, isTrue, reason: 'closed before the reviewer');
        expect(wipedFirst, isTrue, reason: 'wiped before the reviewer');
        // Nothing left to fire under the reviewer screen.
        expect(find.text('Use this photo'), findsNothing);
        expect(find.text('Use these photos'), findsNothing);
      });
    }

    testWidgets('back from the reviewer, the selfie starts clean at step 1', (
      tester,
    ) async {
      final service = _FakeService(steps: _challenge);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => SelfieCaptureView(
              captureService: service,
              onAskWoman: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SizedBox()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Take photo');
      await _tap(tester, 'Take photo');
      expect(find.text('Step 3 of 4'), findsOneWidget);

      await _tap(tester, 'Having trouble? Ask a woman to check you');
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(service.opened, hasLength(2), reason: 'a fresh camera');
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(service.opened.first.answered, isEmpty);
    });
  });

  group('the review gate counts the frames', () {
    testWidgets('a set one frame short is never offered, and the steps restart', (
      tester,
    ) async {
      final service = _FakeService(steps: _challenge, finishEarlyOnce: true);
      var captured = 0;
      await tester.pumpWidget(
        _host(
          SelfieCaptureView(
            captureService: service,
            onCaptured: () => captured++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await _tap(tester, 'Take photo');
      }

      // Three frames for four steps: no review, a fresh run.
      expect(find.text('Use these photos'), findsNothing);
      expect(service.opened.first.discards, 1);
      expect(service.opened, hasLength(2));
      expect(find.text('Step 1 of 4'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await _tap(tester, 'Take photo');
      }
      expect(_shutter(tester), isNotNull, reason: 'a whole set may be used');
      await _tap(tester, 'Use these photos');
      expect(captured, 1);
    });

    testWidgets('each thumbnail is read out as Photo n of N', (tester) async {
      final handle = tester.ensureSemantics();
      final service = _FakeService(steps: _challenge);
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await _tap(tester, 'Take photo');
      }
      for (var n = 1; n <= 4; n++) {
        expect(find.bySemanticsLabel('Photo $n of 4'), findsOneWidget);
      }
      handle.dispose();
    });
  });

  group('leaving mid-steps wipes the frames', () {
    testWidgets('closing C11 halfway zeroes what was taken', (tester) async {
      final service = _FakeService(steps: _challenge);
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Take photo');
      await _tap(tester, 'Take photo');

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpAndSettle();

      final session = service.opened.single;
      expect(session.discards, 1);
      expect(session.answered, isEmpty);
      expect(session.closed, isTrue);
    });

    testWidgets('photos she chose to use are the submit\'s to wipe', (
      tester,
    ) async {
      final service = _FakeService(steps: _challenge);
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: service, onCaptured: () {})),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await _tap(tester, 'Take photo');
      }
      await _tap(tester, 'Use these photos');

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpAndSettle();
      expect(service.opened.single.discards, 0);
    });
  });

  group('the app going to the background releases the camera', () {
    for (final screen in const ['C10', 'C11']) {
      testWidgets('on $screen, and it opens again on return', (tester) async {
        final service = _FakeService(steps: _challenge);
        await tester.pumpWidget(
          _host(
            screen == 'C10'
                ? IdCaptureView(captureService: service)
                : SelfieCaptureView(captureService: service),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 'C11') await _tap(tester, 'Take photo');
        final first = service.opened.single;

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pumpAndSettle();

        expect(first.closed, isTrue);
        expect(service.opened, hasLength(1), reason: 'nothing opens while away');
        if (screen == 'C11') {
          expect(first.discards, 1, reason: 'an unfinished run is wiped');
        }

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(service.opened, hasLength(2));
        expect(_shutter(tester), isNotNull);
        if (screen == 'C11') {
          expect(find.text('Step 1 of 4'), findsOneWidget);
        }
      });
    }

    testWidgets('a photo under review stays, only the camera goes', (
      tester,
    ) async {
      final service = _FakeService();
      await tester.pumpWidget(_host(IdCaptureView(captureService: service)));
      await tester.pumpAndSettle();
      await _tap(tester, 'Take it myself');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(service.opened.single.closed, isTrue);
      expect(service.opened.single.discards, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(service.opened, hasLength(1));
      expect(find.text('Use this photo'), findsOneWidget);
    });
  });

  group('the real camera session keeps the shutter hers', () {
    // The view tests run against fakes, and the bug lived in the camera
    // service: a selfie tap dropped unless the frame was "sharp", and frames
    // left to a dwell clock. Read from the source, the idiom of
    // `product_rules_test.dart`, so putting either back fails here.
    final src = File(
      'lib/features/signup/data/camera_capture_service.dart',
    ).readAsStringSync();
    final session = src.substring(src.indexOf('class _LensSession'));

    test('capture() is not gated on sharpness or a face', () {
      final from = session.indexOf('Future<void> capture() async {');
      expect(from, isNot(-1));
      final body = session.substring(from, session.indexOf('\n  }\n', from));
      expect(body, contains('_take()'));
      expect(body, isNot(contains('sharp')));
      expect(body, isNot(contains('CaptureTarget.selfie')));
    });

    test('the challenge never takes a frame by itself', () {
      final from = session.indexOf('Future<void> _onFrame(');
      final to = session.indexOf('Future<CaptureGuidance?> _read(');
      expect(from, isNot(-1));
      expect(to, greaterThan(from));
      final body = session.substring(from, to);
      final card = body.indexOf('if (steps.isEmpty) {');
      expect(card, isNot(-1));
      final afterCard = body.substring(body.indexOf('return;', card));
      expect(afterCard, isNot(contains('_take(')));
      expect(src, isNot(contains('_stepDwell')));
    });
  });

  group('the frames are wiped, not dropped', () {
    test('a new front zeroes frames left from an earlier run', () {
      final stale = Uint8List.fromList([5, 5]);
      final evidence = VerificationEvidence()..addFrame(stale);

      evidence.holdCardSide(CaptureTarget.idFront, Uint8List.fromList([1]));

      expect(evidence.frames, isEmpty);
      expect(stale, [0, 0]);
    });

    test('the back keeps the frames of the run it belongs to', () {
      final frame = Uint8List.fromList([5, 5]);
      final evidence = VerificationEvidence()
        ..holdCardSide(CaptureTarget.idFront, Uint8List.fromList([1]))
        ..addFrame(frame)
        ..holdCardSide(CaptureTarget.idBack, Uint8List.fromList([2]));
      expect(evidence.frames.single, same(frame));
    });

    test('dropFrames leaves the card and zeroes the frames', () {
      final frame = Uint8List.fromList([7, 7, 7]);
      final front = Uint8List.fromList([1, 2]);
      final evidence = VerificationEvidence()
        ..holdCardSide(CaptureTarget.idFront, front)
        ..addFrame(frame);

      evidence.dropFrames();

      expect(evidence.frames, isEmpty);
      expect(frame, [0, 0, 0]);
      expect(evidence.front, same(front));
    });

    test('dropCardSide zeroes that side only', () {
      final front = Uint8List.fromList([1, 2]);
      final back = Uint8List.fromList([3, 4]);
      final evidence = VerificationEvidence()
        ..holdCardSide(CaptureTarget.idFront, front)
        ..holdCardSide(CaptureTarget.idBack, back);

      evidence.dropCardSide(CaptureTarget.idBack);

      expect(evidence.back, isNull);
      expect(back, [0, 0]);
      expect(evidence.front, same(front));
    });
  });
}
