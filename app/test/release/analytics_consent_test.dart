// Usage statistics ("Help improve Own Hub"): nothing collected before she
// opts in, nothing for advertising ever, and off again the moment she says so.
//
// Held at every layer it can be broken in: the native defaults, the consent
// mode calls, the choice on the phone, the sink, the single import of the SDK,
// and the absence of any user id.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/analytics_consent.dart';
import 'package:own_hub/app_state/analytics_session.dart';
import 'package:own_hub/app_state/debug_analytics_sink.dart';
import 'package:own_hub/app_state/firebase_analytics_sink.dart';
import 'package:own_hub/app_state/firebase_boot.dart';
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

    test('deleting everything on the phone resets it before the kitten', () {
      final wipe = File('lib/app_state/account_data.dart').readAsStringSync();
      final analytics = wipe.indexOf('AnalyticsConsent.instance.erase()');
      final kitten = wipe.indexOf('KittenSetting.instance.erase()');
      expect(analytics, greaterThan(-1));
      expect(
        analytics,
        lessThan(kitten),
        reason: 'putting the kitten back must not be counted',
      );
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
