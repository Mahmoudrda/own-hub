// E12: Snap your meal, with a fake camera and a fake callable.
//
// The consent is asked once and only remembered after the server records it.
// A scan happens only on "Analyse my meal". Every refusal says what happened
// and offers typing the meal. The photo is wiped once the scan answers.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/meal_scan_state.dart';
import 'package:own_hub/features/eat/data/meal_camera.dart';
import 'package:own_hub/features/eat/data/meal_scan_client.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';
import 'package:own_hub/features/eat/presentation/meal_photo_consent.dart';
import 'package:own_hub/features/eat/presentation/meal_photo_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AppL10n _en = AppL10nEn();
final AppL10n _ar = AppL10nAr();

class FakeScanClient implements MealScanClient {
  int consents = 0;
  int scans = 0;
  bool consentFails = false;
  Object answer = const MealScanResult(
    items: [
      ScannedItem(
        nameEn: 'Boiled egg',
        nameAr: 'بيض مسلوق',
        grams: 100,
        matched: true,
        per100g: Macros(kcal: 155, proteinG: 12.6),
      ),
    ],
  );

  @override
  Future<void> recordConsent({required String locale, String? appVersion}) {
    consents++;
    if (consentFails) {
      return Future.error(
        const MealScanException(MealScanFailure.unavailable),
      );
    }
    return Future.value();
  }

  @override
  Future<MealScanResult> analyse(Uint8List jpeg, {required String locale}) {
    scans++;
    final reply = answer;
    if (reply is MealScanException) return Future.error(reply);
    return Future.value(reply as MealScanResult);
  }
}

class FakeCamera implements MealCamera {
  MealCameraProblem? problem;
  int opened = 0;
  final List<Uint8List> given = <Uint8List>[];

  @override
  Future<MealCameraSession> open() async {
    opened++;
    return _FakeSession(this);
  }
}

class _FakeSession implements MealCameraSession {
  _FakeSession(this.camera);

  final FakeCamera camera;
  bool closed = false;

  @override
  MealCameraProblem? get problem => camera.problem;

  @override
  Widget buildPreview() =>
      const ColoredBox(key: ValueKey('fake-preview'), color: Colors.black12);

  @override
  Future<Uint8List?> takePhoto() async {
    // Not a decodable picture: HeldPhoto draws nothing, which is all a test
    // needs, and the bytes are still a JPEG by their first two.
    final bytes = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3, 4, 5, 6]);
    camera.given.add(bytes);
    return bytes;
  }

  @override
  Future<void> close() async => closed = true;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeScanClient client;
  late FakeCamera camera;
  final state = MealScanState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    client = FakeScanClient();
    camera = FakeCamera();
    state.resetForTest(client: client, camera: camera);
  });

  tearDown(() => state.resetForTest());

  Future<int> scanned(WidgetTester tester, {Locale? locale}) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        MealPhotoView(
          state: state,
          uid: 'uid-1',
          onScanned: () => calls++,
          onTypeInstead: () {},
          onClose: () {},
        ),
        locale: locale ?? const Locale('en'),
      ),
    );
    await _settle(tester);
    return calls;
  }

  group('consent', () {
    testWidgets('asked before the camera opens, and remembered only once the '
        'server records it', (tester) async {
      _phone(tester);
      await scanned(tester);
      expect(find.text(_en.beforeYourFirstPhoto), findsOneWidget);
      expect(find.text(_en.yourPhotoGoesToOurAiIn), findsOneWidget);
      expect(camera.opened, 0, reason: 'no lens before she agrees');

      await tester.tap(find.byKey(const ValueKey('meal-consent-agree')));
      await _settle(tester);
      expect(client.consents, 1);
      expect(camera.opened, 1);
      expect(await state.hasConsented('uid-1'), isTrue);
      expect(await state.hasConsented('someone-else'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kMealPhotoConsentKey), 'uid-1');
    });

    testWidgets('a refused record is not remembered, and says so', (
      tester,
    ) async {
      _phone(tester);
      client.consentFails = true;
      await scanned(tester);
      await tester.tap(find.byKey(const ValueKey('meal-consent-agree')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('meal-consent-failed')), findsOneWidget);
      expect(camera.opened, 0);
      expect(await state.hasConsented('uid-1'), isFalse);
    });

    testWidgets('the sheet shows once: a second time she goes straight on', (
      tester,
    ) async {
      _phone(tester);
      final answers = <bool>[];
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => answers.add(
                  await ensureMealPhotoConsent(
                    context,
                    state: state,
                    uid: 'uid-1',
                  ),
                ),
                child: const Text('snap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('snap'));
      await tester.pumpAndSettle();
      expect(find.text(_en.beforeYourFirstPhoto), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meal-consent-agree')));
      await tester.pumpAndSettle();
      expect(answers, [true]);

      await tester.tap(find.text('snap'));
      await tester.pumpAndSettle();
      expect(find.text(_en.beforeYourFirstPhoto), findsNothing);
      expect(answers, [true, true]);
      expect(client.consents, 1, reason: 'recorded once');
    });

    testWidgets('"Not now" closes it and sends nothing', (tester) async {
      _phone(tester);
      final answers = <bool>[];
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => answers.add(
                  await ensureMealPhotoConsent(
                    context,
                    state: state,
                    uid: 'uid-1',
                  ),
                ),
                child: const Text('snap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('snap'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meal-consent-not-now')));
      await tester.pumpAndSettle();
      expect(answers, [false]);
      expect(client.consents, 0);
    });
  });

  group('the shot', () {
    setUp(() async => state.rememberConsent('uid-1'));

    testWidgets('nothing is sent until "Analyse my meal"; then the photo is '
        'wiped', (tester) async {
      _phone(tester);
      var calls = 0;
      await tester.pumpWidget(
        _host(
          MealPhotoView(
            state: state,
            uid: 'uid-1',
            onScanned: () => calls++,
            onTypeInstead: () {},
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('fake-preview')), findsOneWidget);
      expect(find.text(_en.takeItFromAboveWithTheWhole), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meal-scan-shutter')));
      await _settle(tester);
      expect(find.text(_en.useThisPhoto_6wkqn), findsOneWidget);
      expect(find.text(_en.thisUses1OfYour5Photos), findsOneWidget);
      expect(client.scans, 0, reason: 'a photo taken is not a scan');

      await tester.tap(find.byKey(const ValueKey('meal-scan-retake')));
      await _settle(tester);
      expect(camera.given.first.every((b) => b == 0), isTrue,
          reason: 'a retaken photo is zeroed, not kept');
      expect(client.scans, 0);

      await tester.tap(find.byKey(const ValueKey('meal-scan-shutter')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('meal-scan-analyse')));
      await _settle(tester);
      expect(client.scans, 1);
      expect(calls, 1);
      expect(state.result!.items.single.nameEn, 'Boiled egg');
      expect(camera.given.last.every((b) => b == 0), isTrue,
          reason: 'wiped once the scan has answered');
    });

    for (final (failure, retake) in <(MealScanFailure, bool)>[
      (MealScanFailure.dailyLimit, false),
      (MealScanFailure.noFoodSeen, true),
      (MealScanFailure.unclear, true),
      (MealScanFailure.unavailable, true),
      (MealScanFailure.paused, false),
      (MealScanFailure.photoUnreadable, true),
      (MealScanFailure.notVerified, false),
      (MealScanFailure.appOutdated, false),
      (MealScanFailure.signedOut, false),
    ]) {
      testWidgets('${failure.name}: its own sentence, and typing offered', (
        tester,
      ) async {
        _phone(tester);
        client.answer = MealScanException(failure);
        var typed = 0;
        await tester.pumpWidget(
          _host(
            MealPhotoView(
              state: state,
              uid: 'uid-1',
              onTypeInstead: () => typed++,
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('meal-scan-shutter')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('meal-scan-analyse')));
        await _settle(tester);

        final advice = scanAdviceFor(_en, failure);
        expect(find.text(advice.message), findsOneWidget);
        expect(advice.retake, retake);
        expect(
          find.byKey(const ValueKey('meal-scan-retake')),
          retake ? findsOneWidget : findsNothing,
        );
        final typeIt = find.byKey(const ValueKey('meal-scan-type-instead'));
        expect(typeIt, findsOneWidget);
        await tester.tap(typeIt);
        expect(typed, 1);
        expect(state.result, isNull);
        expect(camera.given.last.every((b) => b == 0), isTrue);
      });
    }

    test('the copy the owner asked for', () {
      expect(
        scanAdviceFor(_en, MealScanFailure.dailyLimit).message,
        "You've used your 5 scans for today. You can still type your meal.",
      );
      expect(
        scanAdviceFor(_en, MealScanFailure.noFoodSeen).message,
        "We couldn't make out the food. Try a clearer photo from above, or "
        'type it.',
      );
      expect(
        scanAdviceFor(_en, MealScanFailure.unavailable).message,
        "Scanning isn't available right now. Type your meal instead.",
      );
      for (final failure in MealScanFailure.values) {
        expect(scanAdviceFor(_ar, failure).message, isNotEmpty);
        expect(scanAdviceFor(_en, failure).message.contains('\u2014'), isFalse);
      }
    });

    testWidgets('a server without her consent: asked again, phone forgets', (
      tester,
    ) async {
      _phone(tester);
      client.answer = const MealScanException(MealScanFailure.consentMissing);
      await scanned(tester);
      await tester.tap(find.byKey(const ValueKey('meal-scan-shutter')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('meal-scan-analyse')));
      await _settle(tester);
      expect(find.text(_en.beforeYourFirstPhoto), findsOneWidget);
      expect(await state.hasConsented('uid-1'), isFalse);
    });

    testWidgets('camera turned off: Settings, and typing instead', (
      tester,
    ) async {
      _phone(tester);
      camera.problem = MealCameraProblem.permissionDenied;
      var settings = 0;
      await tester.pumpWidget(
        _host(
          MealPhotoView(
            state: state,
            uid: 'uid-1',
            onOpenSettings: () => settings++,
            onTypeInstead: () {},
          ),
        ),
      );
      await _settle(tester);
      expect(find.text(_en.cameraAccessIsOff), findsOneWidget);
      expect(find.text(_en.ownHubNeedsTheCameraToPhotograph), findsOneWidget);
      await tester.tap(find.text(_en.openSettings));
      expect(settings, 1);
      expect(
        find.byKey(const ValueKey('meal-scan-type-instead')),
        findsOneWidget,
      );
    });
  });

  group('large text and Arabic', () {
    setUp(() async => state.rememberConsent('uid-1'));

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('the review lays out at 2x, ${locale.languageCode}', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            MealPhotoView(state: state, uid: 'uid-1', onTypeInstead: () {}),
            locale: locale,
            textScale: 2,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('meal-scan-shutter')));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        final l10n = locale.languageCode == 'ar' ? _ar : _en;
        expect(find.text(l10n.analyseMyMeal), findsOneWidget);
        if (locale.languageCode == 'ar') {
          expect(
            Directionality.of(tester.element(find.text(l10n.analyseMyMeal))),
            TextDirection.rtl,
          );
        }
      });

      testWidgets('the consent lays out at 2x, ${locale.languageCode}', (
        tester,
      ) async {
        _phone(tester);
        await state.forgetConsent();
        await tester.pumpWidget(
          _host(
            MealPhotoView(state: state, uid: 'uid-1'),
            locale: locale,
            textScale: 2,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('the callable names match the server', () {
    expect(kAnalyzeMealPhotoCallable, 'analyze_meal_photo');
    expect(kRecordMealPhotoConsentCallable, 'record_meal_photo_consent');
  });
}
