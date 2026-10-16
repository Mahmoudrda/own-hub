// C09b — Before the camera opens.
//
// The assertion this file exists for is the ordering one: the camera does not
// open until the agreement has been written down. Everything else on this
// screen is copy, and copy is only worth testing here because it is the copy a
// regulator and a woman would both be reading.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/capture_consent.dart';
import 'package:own_hub/features/signup/presentation/consent_view.dart';
import 'package:own_hub/features/signup/presentation/widgets/verification_bullet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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

/// A store whose write fails, for the case that decides whether this screen is
/// a consent gate or a consent decoration.
class _RefusingStore implements CaptureConsentStore {
  int attempts = 0;

  @override
  Future<CaptureConsent?> current(String uid) async => null;

  @override
  Future<void> record(CaptureConsent consent) async {
    attempts++;
    throw StateError('the consent callable is not deployed');
  }
}

void main() {
  testWidgets('names the processors and the retention, in her language', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(ConsentView(uid: 'u1', store: InMemoryCaptureConsentStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Before the camera opens'), findsOneWidget);
    // Named, not implied. "Processed securely" is what a privacy page says when
    // it does not want to say Virginia.
    // Version 2: where, by whom, what is kept and for how long.
    expect(find.textContaining('Frankfurt, Germany'), findsOneWidget);
    expect(find.textContaining('Google Cloud Vision'), findsOneWidget);
    expect(find.textContaining('European Union'), findsOneWidget);
    expect(find.textContaining('matched on our own server'), findsOneWidget);
    expect(find.textContaining('No photo is ever stored'), findsOneWidget);
    expect(find.textContaining('180 days'), findsOneWidget);
    expect(find.textContaining('keyed code of your ID number'), findsOneWidget);
    // When the check cannot decide, a woman checks instead. No promise of a
    // video call before the route is decided.
    expect(find.textContaining('a woman from Own Hub'), findsOneWidget);
    expect(find.textContaining('short video call'), findsNothing);
    // The superseded v1 lines.
    expect(find.textContaining('outside Egypt'), findsNothing);
    expect(find.textContaining('one way keyed hash'), findsNothing);
    // The superseded model, and the processor we no longer use. Consent to
    // something that is not happening is worse than no consent screen: it has
    // to be withdrawn and taken again.
    expect(find.textContaining('72 hours'), findsNothing);
    expect(find.textContaining('Amazon Web Services'), findsNothing);
    // The restriction people mistake for a bug.
    expect(
      find.textContaining('cannot choose a picture you already have'),
      findsOneWidget,
    );
  });

  testWidgets('agreeing records the version before it opens anything', (
    tester,
  ) async {
    final store = InMemoryCaptureConsentStore();
    final agreed = <String>[];
    final when = DateTime.utc(2026, 9, 25, 10, 30);

    await tester.pumpWidget(
      _host(
        ConsentView(
          uid: 'u1',
          store: store,
          now: () => when,
          onAgreed: () => agreed.add('camera'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await store.current('u1'), isNull);

    await tester.tap(find.text('I agree, start the camera'));
    await tester.pumpAndSettle();

    final recorded = await store.current('u1');
    expect(recorded, isNotNull);
    expect(recorded!.uid, 'u1');
    // The version is the field that makes the record worth keeping: "she
    // consented" is unanswerable a year later once the wording has changed.
    expect(recorded.version, kCaptureConsentVersion);
    expect(recorded.agreedAt, when);
    // Version 2 also records the language she read it in, and the app version.
    expect(recorded.locale, 'en');
    expect(recorded.appVersion, isNotEmpty);
    expect(agreed, <String>['camera']);
  });

  testWidgets('a failed write does not open the camera', (tester) async {
    // The case that decides whether this screen is a gate or a decoration.
    // Advancing anyway would mean photographing a woman's national ID card
    // with no record that she ever agreed to it.
    final store = _RefusingStore();
    final agreed = <String>[];

    await tester.pumpWidget(
      _host(
        ConsentView(
          uid: 'u1',
          store: store,
          onAgreed: () => agreed.add('camera'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('consent-error')), findsNothing);
    await tester.tap(find.text('I agree, start the camera'));
    await tester.pumpAndSettle();

    expect(agreed, isEmpty);
    // She is told, in words, that nothing was saved and nothing opened. A
    // button that silently does nothing reads as a broken app.
    expect(
      find.text(
        'We could not save your agreement, so the camera has not opened. '
        'Check your connection and try again.',
      ),
      findsOneWidget,
    );
    // And she can try again rather than being stranded.
    await tester.tap(find.text('I agree, start the camera'));
    await tester.pumpAndSettle();
    expect(store.attempts, 2);
  });

  testWidgets('declining is a real option that goes somewhere', (tester) async {
    // A consent screen whose only button is "agree" is not consent. This one
    // leads to the woman-reviewer path, which needs no camera and no processor
    // outside Egypt.
    final declined = <String>[];
    await tester.pumpWidget(
      _host(
        ConsentView(
          uid: 'u1',
          store: InMemoryCaptureConsentStore(),
          onDeclined: () => declined.add('C15'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I would rather not'));
    await tester.pumpAndSettle();
    expect(declined, <String>['C15']);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        ConsentView(uid: 'u1', store: InMemoryCaptureConsentStore()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قبل ما الكاميرا تفتح'), findsOneWidget);
    expect(find.text('موافقة، يلا نشغّل الكاميرا'), findsOneWidget);
    expect(find.text('Before the camera opens'), findsNothing);
    // Right to left, so the disclosure is laid out the way she reads it.
    expect(
      Directionality.of(
        tester.element(find.text('موافقة، يلا نشغّل الكاميرا')),
      ),
      TextDirection.rtl,
    );
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    // Four paragraphs of disclosure is the screen most likely to break at 1.6,
    // and a disclosure that is clipped is a disclosure that was not made.
    await tester.pumpWidget(
      _host(
        ConsentView(uid: 'u1', store: InMemoryCaptureConsentStore()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the failure notice fits in Arabic at the largest text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ConsentView(uid: 'u1', store: _RefusingStore()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('موافقة، يلا نشغّل الكاميرا'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('consent-error')), findsOneWidget);
    expect(find.textContaining('ماقدرناش نحفظ موافقتك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('a record for older wording does not count as consent', () async {
    // Rewriting the consent copy must not silently re-use an old agreement for
    // new terms, which is the failure that makes consent records worthless.
    final store = InMemoryCaptureConsentStore();
    await store.record(
      CaptureConsent(uid: 'u1', version: 0, agreedAt: DateTime.utc(2020)),
    );
    expect(await store.current('u1'), isNull);
  });

  // B6. On the first run C09's promise sits above the disclosure, so the
  // check is explained and agreed to on one screen. The disclosure is the v1
  // text, every bullet visible, and agreeing still writes the record first.
  group('with the promise above it', () {
    testWidgets('title, all six disclosures, and three ways on', (
      tester,
    ) async {
      var niqab = 0;
      await tester.pumpWidget(
        _host(
          ConsentView(
            uid: 'u1',
            store: InMemoryCaptureConsentStore(),
            showPromise: true,
            title: '3 of 3 · Quick check',
            onNiqabPath: () => niqab++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 of 3 · Quick check'), findsOneWidget);
      expect(find.text('One check, then you are in'), findsNothing);
      expect(find.textContaining('a couple of minutes'), findsNothing);
      expect(find.text('Before the camera opens'), findsOneWidget);
      expect(find.textContaining('Google Cloud'), findsOneWidget);
      expect(find.byType(VerificationBullet), findsNWidgets(6));
      expect(
        kCaptureConsentVersion,
        3,
        reason: 'v2 was privacy policy v3; v3 is the same wording in Egyptian Arabic',
      );

      final link = find.text('I wear niqab, check me another way');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(niqab, 1);
    });

    testWidgets('agreeing still writes the record before the camera', (
      tester,
    ) async {
      final store = InMemoryCaptureConsentStore();
      final order = <String>[];
      await tester.pumpWidget(
        _host(
          ConsentView(
            uid: 'u1',
            store: store,
            showPromise: true,
            onAgreed: () async {
              order.add(
                (await store.current('u1'))?.version == kCaptureConsentVersion
                    ? 'recorded'
                    : 'missing',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final agree = find.text('I agree, start the camera');
      await tester.ensureVisible(agree);
      await tester.tap(agree);
      await tester.pumpAndSettle();
      expect(order, ['recorded']);
    });

    testWidgets('fits in Arabic at the largest text size', (tester) async {
      await tester.pumpWidget(
        _host(
          ConsentView(
            uid: 'u1',
            store: InMemoryCaptureConsentStore(),
            showPromise: true,
            onNiqabPath: () {},
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the privacy policy is one tap away when it has an address', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        ConsentView(
          uid: 'u1',
          store: InMemoryCaptureConsentStore(),
          onOpenPrivacy: () => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final link = find.text('Read the Privacy Policy');
    await tester.ensureVisible(link);
    await tester.tap(link);
    expect(opened, 1);

    await tester.pumpWidget(
      _host(ConsentView(uid: 'u1', store: InMemoryCaptureConsentStore())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Read the Privacy Policy'), findsNothing);
  });
}
