// C10 — Your ID card.
//
// The screen is real camera capture and there is no camera yet, so the most
// important assertion in this file is the negative one: with no capture
// implementation the shutter is **disabled** and tapping it reports nothing. A
// screen that cheerfully accepted a tap and moved on would be pretending to have
// photographed an ID card, which is the one failure mode that would let the
// whole verification flow look finished while doing nothing.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/presentation/id_capture_view.dart';
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

/// A session that reports it is framing, so the *wiring* can be tested.
///
/// It is deliberately not exported from `lib/`: it proves the view calls
/// `capture()` and reports the result, and nothing more. It is not a camera and
/// no screen may ship against it.
class _LiveSession implements CaptureSession {
  _LiveSession(this.target);

  final CaptureTarget target;
  int captures = 0;
  bool closed = false;

  @override
  CaptureState get current => const CaptureState.framing(sharp: true);

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async => captures++;

  @override
  Future<void> close() async => closed = true;
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
  testWidgets('frames the card and says what happens to it', (tester) async {
    await tester.pumpWidget(
      _host(const IdCaptureView(captureService: _OpeningService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your ID card'), findsOneWidget);
    expect(find.text('front of the card'), findsOneWidget);
    expect(find.text('Hold it flat, all four corners inside'), findsOneWidget);
    expect(
      find.textContaining('Nothing is uploaded until you tap send'),
      findsOneWidget,
    );
    expect(find.text('Take it myself'), findsOneWidget);
  });

  testWidgets('until the camera is live, the shutter is disabled', (
    tester,
  ) async {
    // The honest state of the product today. If this test ever starts failing
    // because the button became enabled, check that a real capture
    // implementation arrived — and not that someone wired it to a fake.
    var captured = 0;
    await tester.pumpWidget(
      _host(
        IdCaptureView(
          captureService: const _OpeningService(),
          onCaptured: () => captured++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<AppWhiteButton>(find.byType(AppWhiteButton));
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Take it myself'));
    await tester.pumpAndSettle();
    expect(captured, 0, reason: 'nothing was photographed, so nothing is said');
  });

  testWidgets('opens the session against the front of the card', (
    tester,
  ) async {
    final service = _LiveCaptureService();
    await tester.pumpWidget(_host(IdCaptureView(captureService: service)));
    await tester.pumpAndSettle();

    expect(service.opened.single.target, CaptureTarget.idFront);
  });

  testWidgets('a live session enables the shutter and hands the frame over', (
    tester,
  ) async {
    final service = _LiveCaptureService();
    var captured = 0;
    await tester.pumpWidget(
      _host(
        IdCaptureView(captureService: service, onCaptured: () => captured++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take it myself'));
    await tester.pumpAndSettle();

    expect(service.opened.single.captures, 1);
    expect(captured, 0, reason: 'she checks the photo before it is used');

    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();
    expect(captured, 1);
  });

  testWidgets('closing releases the camera rather than leaving it running', (
    tester,
  ) async {
    final service = _LiveCaptureService();
    await tester.pumpWidget(_host(IdCaptureView(captureService: service)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pumpAndSettle();

    expect(service.opened.single.closed, isTrue);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        const IdCaptureView(captureService: _OpeningService()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بطاقتك الشخصية'), findsOneWidget);
    expect(find.text('هصوّرها بنفسي'), findsOneWidget);
    expect(find.text('Your ID card'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const IdCaptureView(captureService: _OpeningService()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
