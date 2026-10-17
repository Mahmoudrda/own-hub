// The small language button on the sign-up, verification and main tab screens,
// reached through the real router, and the card viewfinder's cover fit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/language_switch.dart';

import 'package:own_hub/features/signup/data/cover_fit_viewfinder.dart';
import 'package:own_hub/features/signup/domain/id_capture.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/id_capture_view.dart';
import 'package:own_hub/features/signup/presentation/selfie_capture_view.dart';
import 'package:own_hub/features/signup/presentation/widgets/capture_scaffold.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart' show LocaleScope;
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

class _App extends StatelessWidget {
  const _App(this.notifier, this.screenId);

  final ValueNotifier<Locale> notifier;
  final String screenId;

  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      notifier: notifier,
      child: ValueListenableBuilder<Locale>(
        valueListenable: notifier,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(locale),
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          initialRoute: appRoutes[screenId]!.name,
        ),
      ),
    );
  }
}

class _OpeningSession implements CaptureSession {
  @override
  CaptureState get current => const CaptureState.preparing();

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async {}

  @override
  Future<void> close() async {}
}

class _Opening implements CaptureService {
  const _Opening();

  @override
  Future<CaptureSession> open(CaptureTarget target) async => _OpeningSession();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    AppRouter.consentRecorded = true;
    AppRouter.lastVerification = VerificationResult(
      method: VerificationMethod.automatic,
      decidedAt: DateTime(2026, 10, 2),
      imagesDeletedAt: DateTime(2026, 10, 2),
    );
  });
  tearDown(() {
    AppRouter.consentRecorded = false;
    AppRouter.lastVerification = null;
  });

  group('the language button', () {
    testWidgets('C01 keeps its own two chips and they flip the locale', (
      tester,
    ) async {
      _phone(tester);
      final notifier = ValueNotifier<Locale>(const Locale('en'));
      await tester.pumpWidget(_App(notifier, 'C01'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(notifier.value.languageCode, 'ar');
    });

    for (final id in ['C01', 'C02']) {
      testWidgets('$id has its own language choice, not the strip', (
        tester,
      ) async {
        _phone(tester);
        final notifier = ValueNotifier<Locale>(const Locale('en'));
        await tester.pumpWidget(_App(notifier, id));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(LanguageSwitchButton), findsNothing);
      });
    }

    testWidgets('the strip is a 48dp tap target', (tester) async {
      _phone(tester);
      final notifier = ValueNotifier<Locale>(const Locale('en'));
      await tester.pumpWidget(_App(notifier, 'T01'));
      await tester.pump(const Duration(milliseconds: 600));
      final size = tester.getSize(find.byType(LanguageSwitchButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    for (final id in ['C06', 'C10', 'C14', 'T01', 'R01']) {
      testWidgets('$id carries it and tapping it flips the locale', (
        tester,
      ) async {
        _phone(tester);
        final notifier = ValueNotifier<Locale>(const Locale('en'));
        await tester.pumpWidget(_App(notifier, id));
        await tester.pump(const Duration(milliseconds: 600));

        final toArabic = find.text('العربية');
        expect(toArabic, findsOneWidget, reason: '$id has no language button');
        expect(
          find.bySemanticsLabel('Switch language to Arabic'),
          findsOneWidget,
        );

        await tester.tap(toArabic);
        await tester.pump(const Duration(milliseconds: 600));
        expect(notifier.value.languageCode, 'ar');
        expect(find.text('English'), findsWidgets);

        await tester.tap(find.text('English').first);
        await tester.pump(const Duration(milliseconds: 600));
        expect(notifier.value.languageCode, 'en');
      });
    }
  });

  group('the card viewfinder', () {
    testWidgets('covers its landscape frame without stretching', (
      tester,
    ) async {
      const frame = Size(300, 300 / idCardAspectRatio);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: frame.width,
              height: frame.height,
              child: ClipRect(
                child: CoverFitViewfinder(
                  previewSize: const Size(3000, 4000),
                  preview: Container(key: const Key('preview')),
                ),
              ),
            ),
          ),
        ),
      );

      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.cover);

      final shown = tester.getRect(find.byKey(const Key('preview')));
      final window = tester.getRect(find.byType(CoverFitViewfinder));
      expect(window.width, closeTo(frame.width, 0.01));
      expect(window.height, closeTo(frame.height, 0.01));
      expect(shown.left, lessThanOrEqualTo(window.left + 0.01));
      expect(shown.right, greaterThanOrEqualTo(window.right - 0.01));
      expect(shown.top, lessThanOrEqualTo(window.top + 0.01));
      expect(shown.bottom, greaterThanOrEqualTo(window.bottom - 0.01));
      expect(shown.width / shown.height, closeTo(3 / 4, 0.001));
    });

    test('the card frame is an ID-1 card', () {
      expect(idCardAspectRatio, closeTo(85.6 / 53.98, 0.001));
    });

    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    );
    Finder frameAround(Finder label) =>
        find.ancestor(of: label, matching: find.byType(Container)).first;

    testWidgets('the card screen frames at the aspect of a card', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const IdCaptureView(captureService: _Opening())),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(frameAround(find.byType(CaptureFrameLabel)));
      expect(size.width / size.height, closeTo(idCardAspectRatio, 0.01));
    });

    testWidgets('the selfie frame stays portrait', (tester) async {
      await tester.pumpWidget(
        host(const SelfieCaptureView(captureService: _Opening())),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(frameAround(find.byType(CaptureFrameLabel)));
      expect(size.height, greaterThan(size.width));
    });
  });
}
