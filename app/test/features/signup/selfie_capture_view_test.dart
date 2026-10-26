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
  CaptureState _state = const CaptureState.framing(sharp: true);

  @override
  CaptureState get current => _state;

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  /// A one-step challenge: the first press takes the only frame.
  @override
  Future<void> capture() async {
    captures++;
    _state = const CaptureState.captured();
  }

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
      _host(const SelfieCaptureView(captureService: _OpeningService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick selfie'), findsOneWidget);
    expect(find.text('her face, live'), findsOneWidget);
    expect(find.text('Look straight ahead. No smile needed.'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
  });

  testWidgets('RULE 8 — the selfie proves the card is hers, and is deleted', (
    tester,
  ) async {
    // Matched, then deleted. Never classified: no gender, age or appearance is
    // inferred from this picture anywhere in the product.
    await tester.pumpWidget(
      _host(const SelfieCaptureView(captureService: _OpeningService())),
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

    await tester.tap(find.text('Take photo'));
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

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(service.opened.single.captures, 1);
    expect(captured, 0, reason: 'she checks the photos before they are used');

    await tester.tap(find.text('Use these photos'));
    await tester.pumpAndSettle();
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

    expect(find.text('سيلفي سريعة'), findsOneWidget);
    expect(
      find.textContaining('بتتطابق مع صورة بطاقتك، وبعدين بتتمسح'),
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
}
