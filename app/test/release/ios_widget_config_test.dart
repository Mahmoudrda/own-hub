// The iOS widget extension's configuration, held by file.
//
// None of this is visible to a Dart test any other way, and each line is a
// rejection or a dead widget if it drifts: the App Group on both targets, the
// URL scheme the widgets open the app with, Flutter's own deep linking on (so
// coach links reach the router) with the widget URL answered by home_widget
// first, the UserDefaults reason (1C8F.1) in both
// privacy manifests, and the extension target in the Xcode project at the
// same iOS floor as the app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/home_widget_sync.dart';

const String _group = 'group.com.ownhub.fitness';

String _read(String path) => File(path).readAsStringSync();

/// The `<array>` under [key] in a plist, as text.
String _arrayUnder(String plist, String key) =>
    RegExp('<key>$key</key>\\s*<array>([\\s\\S]*?)</array>')
        .firstMatch(plist)
        ?.group(1) ??
    '';

void main() {
  test('both targets share the App Group the app writes to', () {
    expect(kWidgetAppGroup, _group);
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/OwnHubWidgets/OwnHubWidgets.entitlements',
    ]) {
      expect(
        _arrayUnder(_read(path), 'com.apple.security.application-groups'),
        contains('<string>$_group</string>'),
        reason: path,
      );
    }
    expect(_read('ios/OwnHubWidgets/WidgetPayload.swift'), contains(_group));
  });

  test('Runner registers ownhub:// and keeps the Firebase scheme', () {
    final info = _read('ios/Runner/Info.plist');
    final schemes = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>([^<]+)</string>',
    ).allMatches(info).map((m) => m.group(1)).toList();
    expect(schemes, contains('ownhub'));
    expect(
      schemes.any((s) => s!.startsWith('com.googleusercontent.apps.')),
      isTrue,
    );
  });

  test("Flutter's own deep linking is on, so coach links reach the app", () {
    expect(
      RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<true/>')
          .hasMatch(_read('ios/Runner/Info.plist')),
      isTrue,
    );
  });

  test('both privacy manifests declare UserDefaults 1C8F.1', () {
    for (final path in [
      'ios/Runner/PrivacyInfo.xcprivacy',
      'ios/OwnHubWidgets/PrivacyInfo.xcprivacy',
    ]) {
      final manifest = _read(path);
      expect(
        RegExp(
          r'NSPrivacyAccessedAPICategoryUserDefaults</string>\s*'
          r'<key>NSPrivacyAccessedAPITypeReasons</key>\s*<array>\s*'
          r'<string>1C8F\.1</string>',
        ).hasMatch(manifest),
        isTrue,
        reason: path,
      );
    }
    final ext = _read('ios/OwnHubWidgets/PrivacyInfo.xcprivacy');
    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(ext),
      isTrue,
    );
    expect(
      RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array/>')
          .hasMatch(ext),
      isTrue,
    );
  });

  test('the app declares FileTimestamp C617.1 for the exercise clip cache', () {
    // path_provider is in pubspec for one folder, the clip cache (D42), and
    // Dart's file calls read file sizes and timestamps there.
    expect(_read('pubspec.yaml'), contains('\n  path_provider:'));
    expect(
      RegExp(
        r'NSPrivacyAccessedAPICategoryFileTimestamp</string>\s*'
        r'<key>NSPrivacyAccessedAPITypeReasons</key>\s*<array>\s*'
        r'<string>C617\.1</string>',
      ).hasMatch(_read('ios/Runner/PrivacyInfo.xcprivacy')),
      isTrue,
    );
  });

  test('the extension is in the project, embedded, at the app floor', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    expect(
      project,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.ownhub.fitness.OwnHubWidgets;'),
    );
    expect(project, contains('"com.apple.product-type.app-extension"'));
    expect(
      project,
      contains('OwnHubWidgetsExtension.appex in Embed Foundation Extensions'),
    );
    expect(project, contains('dstSubfolderSpec = 13;'));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(
      'CODE_SIGN_ENTITLEMENTS = OwnHubWidgets/OwnHubWidgets.entitlements;'
          .allMatches(project)
          .length,
      3,
    );
    // Every deployment target in the project, the extension's three included.
    final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);')
        .allMatches(project)
        .map((m) => m.group(1))
        .toList();
    expect(targets.length, greaterThanOrEqualTo(6));
    expect(targets.toSet(), {'15.5'});
    // iPhone only, everywhere.
    expect(
      RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);')
          .allMatches(project)
          .map((m) => m.group(1))
          .toSet(),
      {'1'},
    );
    expect(
      _read('ios/OwnHubWidgets/OwnHubWidgets.xcconfig'),
      contains('#include "../Flutter/Generated.xcconfig"'),
    );
  });

  test('the widget kinds the app reloads are the ones the extension has', () {
    expect(
      _read('ios/OwnHubWidgets/WeekWidget.swift'),
      contains('static let kind = "${kWidgetKinds[0]}"'),
    );
    expect(
      _read('ios/OwnHubWidgets/TodayWidget.swift'),
      contains('static let kind = "${kWidgetKinds[1]}"'),
    );
  });

  test("the extension's own strings match the app's dictionary", () {
    final catalog = jsonDecode(
      _read('ios/OwnHubWidgets/Localizable.xcstrings'),
    ) as Map<String, Object?>;
    final strings = (catalog['strings']! as Map).cast<String, Object?>();
    final en = jsonDecode(_read('lib/l10n/app_en.arb')) as Map<String, Object?>;
    final ar = jsonDecode(_read('lib/l10n/app_ar.arb')) as Map<String, Object?>;
    final keyFor = {
      for (final e in en.entries)
        if (!e.key.startsWith('@') && e.value is String) e.value: e.key,
    };
    expect(strings, isNotEmpty);
    for (final MapEntry(key: english, value: entry) in strings.entries) {
      final key = keyFor[english];
      expect(key, isNotNull, reason: '"$english" is not in app_en.arb');
      final localizations = ((entry! as Map)['localizations']! as Map);
      String valueIn(String lang) =>
          (((localizations[lang]! as Map)['stringUnit']! as Map)['value'])!
              as String;
      expect(valueIn('en'), english);
      expect(valueIn('ar'), ar[key], reason: english);
    }
  });
}
