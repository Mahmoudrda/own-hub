// C11 — Quick selfie.
//
// Two things are being guarded here. The first is the same honesty guard as C10:
// no camera, no working shutter. The second is rule 8 — the copy on this screen
// has to say that the selfie is matched to the card and then deleted, because
// that is the *only* thing it is used for. Nothing in this product classifies a
// face, and this is the screen where a woman decides whether she believes that.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/presentation/selfie_capture_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_white_button.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

/// See the note in `id_capture_view_test.dart`: wiring only, never a camera.
class _LiveSession implements CaptureSession {
  _LiveSession(this.target);

  final CaptureTarget target;
  int captures = 0;

  @override
  CaptureState get current => const CaptureState.framing(sharp: true);

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async => captures++;

  @override
  Future<void> close() async {}
}

class _LiveCaptureService implements CaptureService {
  final List<_LiveSession> opened = [];

  @override
  Future<CaptureSession> open(CaptureTarget target) async {
    final session = _LiveSession(target);
    opened.add(session);
    return session;
  }
}

/// A live challenge step: the server's prompt, shown as guidance.
class _StepSession implements CaptureSession {
  _StepSession(this.guidance);

  final CaptureGuidance guidance;

  @override
  CaptureState get current => CaptureState.framing(
    sharp: false,
    guidance: guidance,
    stepNumber: 2,
    stepCount: 4,
  );

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async {}

  @override
  Future<void> close() async {}
}

class _StepService implements CaptureService {
  _StepService(this.guidance);

  final CaptureGuidance guidance;

  @override
  Future<CaptureSession> open(CaptureTarget target) async =>
      _StepSession(guidance);
}

/// A camera that is still opening: never live, never refused. The screen as
/// designed, with the shutter waiting. (A camera that cannot run at all draws
/// a different screen; see capture_views_test.dart.)
class _OpeningSession implements CaptureSession {
  @override
  CaptureState get current => const CaptureState.preparing();

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async =>
      throw StateError('nothing to capture while the camera opens');

  @override
  Future<void> close() async {}
}

class _OpeningService implements CaptureService {
  const _OpeningService();

  @override
  Future<CaptureSession> open(CaptureTarget target) async => _OpeningSession();
}

void main() {
  testWidgets('asks for one plain photograph, and explains why', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SelfieCaptureView(captureService: _OpeningService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick selfie'), findsOneWidget);
    expect(find.text('her face, live'), findsOneWidget);
    expect(find.text('Look straight ahead. No smile needed.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('RULE 8 — the selfie proves the card is hers, and is deleted', (
    tester,
  ) async {
    // Matched, then deleted. Never classified: no gender, age or appearance is
    // inferred from this picture anywhere in the product.
    await tester.pumpWidget(
      _host(
        const SelfieCaptureView(captureService: _OpeningService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Matched to the photo on your card'),
      findsOneWidget,
    );
    expect(find.textContaining('then deleted'), findsOneWidget);
    expect(
      find.textContaining('A woman reviews anything the check cannot decide'),
      findsOneWidget,
    );
  });

  testWidgets('until the camera is live, the shutter is disabled', (
    tester,
  ) async {
    var captured = 0;
    await tester.pumpWidget(
      _host(
        SelfieCaptureView(
          captureService: const _OpeningService(),
          onCaptured: () => captured++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppWhiteButton>(find.byType(AppWhiteButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(captured, 0);
  });

  testWidgets('opens the session against the selfie camera', (tester) async {
    final service = _LiveCaptureService();
    await tester.pumpWidget(_host(SelfieCaptureView(captureService: service)));
    await tester.pumpAndSettle();

    expect(service.opened.single.target, CaptureTarget.selfie);
  });

  testWidgets('a live session enables the shutter and hands the frame over', (
    tester,
  ) async {
    final service = _LiveCaptureService();
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

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(service.opened.single.captures, 1);
    expect(captured, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        const SelfieCaptureView(captureService: _OpeningService()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('صورة ذاتية سريعة'), findsOneWidget);
    expect(
      find.textContaining('تُطابَق مع صورة بطاقتك ثم تُحذف'),
      findsOneWidget,
    );
    expect(find.text('Quick selfie'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SelfieCaptureView(captureService: _OpeningService()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the kitten acts out each challenge step, beside the words', (
    tester,
  ) async {
    const shown = {
      CaptureGuidance.turnLeft: KittenPose.lookLeft,
      CaptureGuidance.turnRight: KittenPose.lookRight,
      CaptureGuidance.blink: KittenPose.blink,
      CaptureGuidance.lookStraight: KittenPose.rest,
    };
    for (final MapEntry(key: guidance, value: pose) in shown.entries) {
      await tester.pumpWidget(
        _host(SelfieCaptureView(captureService: _StepService(guidance))),
      );
      await tester.pumpAndSettle();
      final kitten = tester.widget<Kitten>(find.byType(Kitten));
      expect(kitten.pose, pose, reason: guidance.name);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a framing correction is hers to read: no kitten', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SelfieCaptureView(
          captureService: _StepService(CaptureGuidance.centreYourFace),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Kitten), findsNothing);
  });
}
