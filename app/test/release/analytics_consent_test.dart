// Usage statistics ("Help improve Own Hub"): nothing collected before she
// opts in, nothing for advertising ever, and off again the moment she says so.
//
// Held at every layer it can be broken in: the native defaults, the consent
// mode calls, the choice on the phone, the sink, the single import of the SDK,
// and the absence of any user id.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/analytics_consent.dart';
import 'package:own_hub/app_state/analytics_session.dart';
import 'package:own_hub/app_state/debug_analytics_sink.dart';
import 'package:own_hub/app_state/firebase_analytics_sink.dart';
import 'package:own_hub/app_state/firebase_boot.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/domain/analytics/analytics_gateway.dart';

Iterable<File> _dartFiles(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AnalyticsConsent.instance.resetForTest();
  });

  group('her choice', () {
    test('off until she says otherwise', () async {
      await AnalyticsConsent.instance.load();
      expect(AnalyticsConsent.instance.allowed, isFalse);
    });

    test(
      'kept on the phone, read back, and separate from crash reports',
      () async {
        await AnalyticsConsent.instance.set(true);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kAnalyticsAllowedKey), isTrue);
        expect(prefs.containsKey('own_hub.crash_reports_allowed'), isFalse);

        AnalyticsConsent.instance.resetForTest();
        await AnalyticsConsent.instance.load();
        expect(AnalyticsConsent.instance.allowed, isTrue);

        await AnalyticsConsent.instance.set(false);
        expect(prefs.getBool(kAnalyticsAllowedKey), isFalse);
      },
    );

    test(
      'granting it describes the session once; withdrawing does not',
      () async {
        var described = 0;
        AnalyticsConsent.onGranted = () => described++;
        addTearDown(() => AnalyticsConsent.onGranted = null);
        await AnalyticsConsent.instance.set(true);
        await AnalyticsConsent.instance.set(true);
        await AnalyticsConsent.instance.set(false);
        expect(described, 1);
      },
    );

    test('erasing puts it back to off and removes both keys', () async {
      await AnalyticsConsent.instance.set(true);
      await AnalyticsConsent.instance.daysSinceLastOpen(DateTime(2026, 10, 1));
      await AnalyticsConsent.instance.erase();
      expect(AnalyticsConsent.instance.allowed, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kAnalyticsAllowedKey), isFalse);
      expect(prefs.containsKey(kAnalyticsLastOpenKey), isFalse);
    });

    test('a quiet week is measured only while she allows statistics', () async {
      expect(
        await AnalyticsConsent.instance.daysSinceLastOpen(
          DateTime(2026, 10, 1),
        ),
        isNull,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(kAnalyticsLastOpenKey),
        isFalse,
        reason: 'nothing is written while it is off',
      );

      await AnalyticsConsent.instance.set(true);
      expect(
        await AnalyticsConsent.instance.daysSinceLastOpen(
          DateTime(2026, 10, 1),
        ),
        isNull,
      );
      expect(
        await AnalyticsConsent.instance.daysSinceLastOpen(
          DateTime(2026, 10, 9, 23, 30),
        ),
        8,
      );
      // Turning it off removes the day too.
      await AnalyticsConsent.instance.set(false);
      expect(prefs.containsKey(kAnalyticsLastOpenKey), isFalse);
    });

    test('retention and activation clocks run only with consent', () async {
      final prefs = await SharedPreferences.getInstance();
      final day0 = DateTime.utc(2026, 10, 1, 9);
      expect(await AnalyticsConsent.instance.firstOpen(day0), isNull);
      expect(await AnalyticsConsent.instance.claimActivation(), isFalse);
      expect(prefs.containsKey(kAnalyticsFirstOpenKey), isFalse);
      expect(prefs.containsKey(kAnalyticsActivatedKey), isFalse);

      await AnalyticsConsent.instance.set(true, now: day0);
      expect(await AnalyticsConsent.instance.firstOpen(day0), day0);
      expect(
        await AnalyticsConsent.instance.firstOpen(DateTime.utc(2026, 10, 5)),
        day0,
        reason: 'the first opening is kept',
      );
      expect(await AnalyticsConsent.instance.claimActivation(), isTrue);
      expect(await AnalyticsConsent.instance.claimActivation(), isFalse);

      await AnalyticsConsent.instance.set(false);
      expect(
        prefs.getString(kAnalyticsFirstOpenKey),
        kAnalyticsFirstOpenDeclined,
      );
      expect(prefs.containsKey(kAnalyticsActivatedKey), isFalse);
    });

    group('activation counts the right workout', () {
      late List<(String, Map<String, Object>)> sent;
      late AnalyticsGateway saved;
      setUp(() {
        sent = <(String, Map<String, Object>)>[];
        saved = AppRouter.analytics;
        AppRouter.analytics = AnalyticsGateway(_ListSink(sent));
      });
      tearDown(() => AppRouter.analytics = saved);
      final day0 = DateTime.utc(2026, 10, 1, 9);
      final later = day0.add(const Duration(hours: 30));
      bool activated() => sent.any((e) => e.$1 == 'firstWorkoutDone');

      test(
        'a new woman: the workout in the session she opts in counts',
        () async {
          await AnalyticsConsent.instance.set(true, now: day0);
          await AnalyticsSession.noteWorkoutFinished(
            day0.add(const Duration(minutes: 20)),
          );
          expect(activated(), isTrue);
          await AnalyticsSession.noteWorkoutFinished(later);
          expect(sent.where((e) => e.$1 == 'firstWorkoutDone'), hasLength(1));
        },
      );

      test('upgrade from 1.0.0: nothing is sent for her workout', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kAnalyticsAllowedKey: true,
        });
        await AnalyticsConsent.instance.load();
        await AnalyticsSession.noteOpened(later);
        await AnalyticsSession.noteWorkoutFinished(later, earlierWorkout: true);
        await AnalyticsSession.noteWorkoutFinished(later);
        expect(sent, isEmpty);
      });

      test(
        'declined at sign-up, restart, then on later: a fresh cohort',
        () async {
          await AnalyticsConsent.instance.set(false);
          await AnalyticsConsent.instance.load();
          await AnalyticsConsent.instance.set(true, now: day0);
          await AnalyticsSession.noteOpened(day0);
          await AnalyticsSession.noteWorkoutFinished(
            day0.add(const Duration(minutes: 30)),
          );
          expect(
            sent.firstWhere((e) => e.$1 == 'appOpened').$2.values,
            contains('d0'),
          );
          expect(activated(), isTrue);
        },
      );

      test('a 1.0.0 upgrader who toggles keeps the unknown marker', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kAnalyticsAllowedKey: true,
        });
        await AnalyticsConsent.instance.load();
        await AnalyticsConsent.instance.set(false);
        await AnalyticsConsent.instance.set(true, now: day0);
        await AnalyticsSession.noteOpened(later);
        await AnalyticsSession.noteWorkoutFinished(later);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(kAnalyticsFirstOpenKey),
          kAnalyticsFirstOpenUnknown,
        );
        expect(sent, isEmpty);
      });

      test('erasing everything clears both markers', () async {
        final prefs = await SharedPreferences.getInstance();
        await AnalyticsConsent.instance.set(false);
        expect(prefs.containsKey(kAnalyticsFirstOpenKey), isTrue);
        await AnalyticsConsent.instance.erase();
        expect(prefs.containsKey(kAnalyticsFirstOpenKey), isFalse);
        await AnalyticsConsent.instance.load();
        expect(prefs.containsKey(kAnalyticsFirstOpenKey), isFalse);
        await AnalyticsConsent.instance.set(true, now: day0);
        expect(prefs.getString(kAnalyticsFirstOpenKey), isNot('unknown'));
        expect(
          DateTime.tryParse(prefs.getString(kAnalyticsFirstOpenKey)!),
          day0,
        );
      });

      test('on, off, restart, on: a new date and a d0 opening', () async {
        final prefs = await SharedPreferences.getInstance();
        await AnalyticsConsent.instance.set(true, now: day0);
        await AnalyticsConsent.instance.set(false);
        await AnalyticsConsent.instance.load();
        await AnalyticsConsent.instance.set(true, now: later);
        expect(
          DateTime.tryParse(prefs.getString(kAnalyticsFirstOpenKey)!),
          later,
        );
        await AnalyticsSession.noteOpened(later);
        expect(
          sent.where((e) => e.$1 == 'appOpened').single.$2.values,
          contains('d0'),
        );
      });

      test('off throughout: only the two keys, nothing sent', () async {
        final prefs = await SharedPreferences.getInstance();
        await AnalyticsConsent.instance.set(false);
        await AnalyticsConsent.instance.load();
        await AnalyticsSession.noteOpened(later);
        await AnalyticsSession.noteWorkoutFinished(later);
        expect(
          <String, Object?>{for (final k in prefs.getKeys()) k: prefs.get(k)},
          <String, Object?>{
            kAnalyticsAllowedKey: false,
            kAnalyticsFirstOpenKey: kAnalyticsFirstOpenDeclined,
          },
        );
        expect(sent, isEmpty);
      });

      test('granting counts that opening once (the hook main wires)', () async {
        final saved = AnalyticsConsent.onGranted;
        addTearDown(() => AnalyticsConsent.onGranted = saved);
        AnalyticsConsent.onGranted = () =>
            unawaited(AnalyticsSession.noteOpened(day0));
        await AnalyticsConsent.instance.set(true, now: day0);
        await Future<void>.delayed(Duration.zero);
        await AnalyticsSession.noteOpened(day0);
        expect(sent.where((e) => e.$1 == 'appOpened'), hasLength(1));
        // The hook main wires: a named method that also counts the opening,
        // assigned to onGranted and compared against it in dispose.
        final main = File('lib/main.dart').readAsStringSync();
        final body = RegExp(
          r'void _onStatisticsGranted\(\) \{(.*?)\n  \}',
          dotAll: true,
        ).firstMatch(main)?.group(1);
        expect(body, isNotNull, reason: 'main has _onStatisticsGranted');
        expect(body, contains('_describeForStatistics()'));
        expect(body, contains('AnalyticsSession.noteOpened('));
        expect(
          main,
          contains('AnalyticsConsent.onGranted = _onStatisticsGranted;'),
        );
        expect(
          main,
          contains('AnalyticsConsent.onGranted == _onStatisticsGranted'),
        );
      });

      test('off in 1.0.0, then on in 1.1: no cohort, no activation', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          kAnalyticsAllowedKey: false,
        });
        await AnalyticsConsent.instance.load();
        await AnalyticsConsent.instance.set(true, now: day0);
        await AnalyticsSession.noteOpened(later);
        await AnalyticsSession.noteWorkoutFinished(later);
        expect(sent, isEmpty);
      });

      test(
        'statistics turned on after earlier workouts: not counted',
        () async {
          await AnalyticsConsent.instance.set(true, now: day0);
          await AnalyticsSession.noteWorkoutFinished(
            later,
            earlierWorkout: true,
          );
          await AnalyticsSession.noteWorkoutFinished(
            later.add(const Duration(days: 1)),
          );
          expect(activated(), isFalse);
        },
      );
    });

    test('install age words match the day 1, 7 and 30 cohorts', () {
      final first = DateTime.utc(2026, 10, 1, 23);
      String at(int days) => AnalyticsSession.installAgeToken(
        first,
        first.add(Duration(days: days)),
      );
      expect(
        [
          for (final d in [0, 1, 2, 6, 7, 8, 29, 30, 31]) at(d),
        ],
        ['d0', 'd1', 'd2_6', 'd2_6', 'd7', 'd8_29', 'd8_29', 'd30', 'd31p'],
      );
      for (final d in [0, 1, 4, 7, 20, 30, 90]) {
        expect(
          AnalyticsVocabulary.allows(
            AnalyticsProp.installAge,
            AnalyticsValue.token(at(d)),
          ),
          isTrue,
        );
      }
    });

    test('main reads the choice before Firebase starts', () {
      final main = File('lib/main.dart').readAsStringSync();
      final load = main.indexOf('AnalyticsConsent.instance.load()');
      expect(load, greaterThan(-1));
      expect(load, lessThan(main.indexOf('FirebaseBoot.start()')));
    });
  });

  group('only a build that may send, and only with her consent', () {
    test(
      'release sends with consent; debug only when asked to; never without',
      () {
        for (final debugSend in [false, true]) {
          expect(
            FirebaseBoot.analyticsCollectionFor(
              release: true,
              allowed: false,
              debugSend: debugSend,
            ),
            isFalse,
          );
          expect(
            FirebaseBoot.analyticsCollectionFor(
              release: false,
              allowed: false,
              debugSend: debugSend,
            ),
            isFalse,
          );
        }
        expect(
          FirebaseBoot.analyticsCollectionFor(release: true, allowed: true),
          isTrue,
        );
        expect(
          FirebaseBoot.analyticsCollectionFor(
            release: false,
            allowed: true,
            debugSend: false,
          ),
          isFalse,
        );
        expect(
          FirebaseBoot.analyticsCollectionFor(
            release: false,
            allowed: true,
            debugSend: true,
          ),
          isTrue,
        );
      },
    );

    test('nothing is sent before Firebase is up, whatever she chose', () {
      AnalyticsConsent.instance.resetForTest(allowed: true);
      expect(FirebaseBoot.analyticsSending, isFalse);
    });

    test('the sink drops everything while it may not send', () async {
      var asked = 0;
      final sink = FirebaseAnalyticsSink(
        maySend: () {
          asked++;
          return false;
        },
      );
      // With the plugin absent in a test, anything past the check would
      // throw inside the sink's own guard; the count proves the check ran
      // first and stopped it.
      await sink.send('screenViewed', {'screenId': 'T01', 'flow': 'today'});
      await sink.setUserProperty('app_language', 'ar');
      expect(asked, 2);
    });

    test('each build mode gets its sink', () {
      expect(
        analyticsSinkFor(release: true, debug: false, debugSend: false),
        isA<TeeAnalyticsSink>(),
      );
      expect(
        analyticsSinkFor(release: false, debug: true, debugSend: false),
        isA<DebugPrintAnalyticsSink>(),
      );
      expect(
        analyticsSinkFor(release: false, debug: true, debugSend: true),
        isA<TeeAnalyticsSink>(),
      );
      expect(
        analyticsSinkFor(release: false, debug: false, debugSend: false),
        isA<NullAnalyticsSink>(),
      );
    });
  });

  group('consent mode v2, and never advertising', () {
    final boot = File('lib/app_state/firebase_boot.dart').readAsStringSync();

    test('the advertising consents are denied in every call', () {
      expect(boot, isNot(contains('adStorageConsentGranted: true')));
      expect(boot, isNot(contains('adUserDataConsentGranted: true')));
      expect(
        boot,
        isNot(contains('adPersonalizationSignalsConsentGranted: true')),
      );
      final calls = 'setConsent('.allMatches(boot).length;
      expect(calls, 3);
      expect('adStorageConsentGranted: false'.allMatches(boot).length, calls);
      expect('adUserDataConsentGranted: false'.allMatches(boot).length, calls);
      expect(
        'adPersonalizationSignalsConsentGranted: false'.allMatches(boot).length,
        calls,
      );
    });

    test('withdrawing turns collection off and resets the instance id', () {
      final apply = boot.substring(
        boot.indexOf('static Future<void> applyAnalyticsConsent'),
        boot.indexOf('static Future<void> start()'),
      );
      expect(apply, contains('setAnalyticsCollectionEnabled(false)'));
      expect(apply, contains('resetAnalyticsData()'));
      // Consent is granted before collection is turned on.
      expect(
        apply.indexOf('analyticsStorageConsentGranted: true'),
        lessThan(apply.indexOf('setAnalyticsCollectionEnabled(true)')),
      );
    });

    test('no user id is ever set, and only two files touch the SDK', () {
      final importers = <String>[];
      for (final file in _dartFiles('lib')) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('setUserId(')), reason: file.path);
        if (source.contains("import 'package:firebase_analytics/")) {
          importers.add(file.path.split('/').last);
        }
      }
      expect(importers.toSet(), {
        'firebase_boot.dart',
        'firebase_analytics_sink.dart',
      });
    });
  });

  group('the native defaults hold until Dart applies her choice', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    for (final key in [
      'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA',
      'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS',
      'GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED',
      'GOOGLE_ANALYTICS_ADID_COLLECTION_ENABLED',
      'GOOGLE_ADS_ON_DEVICE_CONVERSION_EVENT_DATA_ENABLED',
      'FirebaseAutomaticScreenReportingEnabled',
    ]) {
      test('iOS $key is false', () {
        expect(RegExp('<key>$key</key>\\s*<false/>').hasMatch(plist), isTrue);
      });
    }

    for (final key in [
      'firebase_analytics_collection_enabled',
      'google_analytics_default_allow_analytics_storage',
      'google_analytics_default_allow_ad_storage',
      'google_analytics_default_allow_ad_user_data',
      'google_analytics_default_allow_ad_personalization_signals',
      'google_analytics_adid_collection_enabled',
      'google_analytics_automatic_screen_reporting_enabled',
    ]) {
      test('Android $key is false', () {
        expect(
          RegExp('android:name="$key"\\s*android:value="false"')
              .hasMatch(manifest),
          isTrue,
        );
      });
    }

    test('no advertising ID permission, no IDFA, no tracking prompt', () {
      expect(
        manifest,
        contains(
          '<uses-permission android:name="com.google.android.gms.permission.AD_ID" '
          'tools:node="remove" />',
        ),
      );
      expect(
        File('ios/Podfile').readAsStringSync(),
        contains(r'$FirebaseAnalyticsWithoutAdIdSupport = true'),
      );
      expect(
        File('tool/build_release.sh').readAsStringSync(),
        contains('export FIREBASE_ANALYTICS_WITHOUT_ADID=true'),
      );
      expect(plist, isNot(contains('NSUserTrackingUsageDescription')));
      final privacy = File('ios/Runner/PrivacyInfo.xcprivacy')
          .readAsStringSync();
      expect(
        RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(privacy),
        isTrue,
      );
    });
  });

  group('the stores are told', () {
    final privacy = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();

    String entryFor(String type) {
      final at = privacy.indexOf(
        '<string>NSPrivacyCollectedDataType$type</string>',
      );
      expect(at, greaterThan(-1), reason: '$type is not declared');
      return privacy.substring(
        privacy.lastIndexOf('<dict>', at),
        privacy.indexOf('</dict>', at),
      );
    }

    for (final type in ['ProductInteraction', 'CoarseLocation']) {
      test('$type: not linked, not tracking, Analytics only', () {
        final entry = entryFor(type);
        expect(
          entry,
          matches(RegExp(r'NSPrivacyCollectedDataTypeLinked</key>\s*<false/>')),
        );
        expect(
          entry,
          matches(
            RegExp(r'NSPrivacyCollectedDataTypeTracking</key>\s*<false/>'),
          ),
        );
        expect(entry, contains('NSPrivacyCollectedDataTypePurposeAnalytics'));
        expect(
          entry,
          isNot(contains('NSPrivacyCollectedDataTypePurposeAppFunctionality')),
        );
      });
    }

    test('the analytics instance id is declared under Device ID', () {
      expect(
        entryFor('DeviceID'),
        contains('NSPrivacyCollectedDataTypePurposeAnalytics'),
      );
    });

    test('the Play answers name every analytics data type', () {
      final safety = File('android/play-data-safety.txt').readAsStringSync();
      for (final phrase in [
        'App interactions',
        'Approximate location',
        'app instance ID',
        'No Advertising ID',
        'Help improve',
      ]) {
        expect(safety, contains(phrase));
      }
      expect(safety, isNot(contains('app\nactivity, and photos')));
    });
  });

  group('the gateway names', () {
    test('every user property the session sets is in its closed list', () {
      expect(
        analyticsUserPropertyValues[AnalyticsUserProperty.buildChannel],
        contains(kBuildChannel),
      );
    });
  });
}

class _ListSink implements AnalyticsSink {
  _ListSink(this.sent);

  final List<(String, Map<String, Object>)> sent;

  @override
  Future<void> send(String event, Map<String, Object> properties) async =>
      sent.add((event, properties));
}
