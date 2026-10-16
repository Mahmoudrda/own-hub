// The Android home-screen widget's configuration, held by file.
//
// A Dart test cannot see the launcher, so this holds the three things that
// leave a dead widget if they drift: the receiver in the manifest, the
// appwidget-provider XML it points at, and the Kotlin class whose name Dart
// asks to redraw.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/home_widget_sync.dart';
import 'package:own_hub/features/today/domain/widget_projection.dart';

String _read(String path) => File(path).readAsStringSync();

const String _main = 'android/app/src/main';

void main() {
  test('the manifest declares the widget receiver and its provider info', () {
    final manifest = _read('$_main/AndroidManifest.xml');
    final receiver = RegExp(
      r'<receiver[^>]*android:name="\.' +
          kAndroidWidgetName +
          r'"[\s\S]*?</receiver>',
    ).firstMatch(manifest);
    expect(receiver, isNotNull, reason: 'receiver for $kAndroidWidgetName');
    final block = receiver!.group(0)!;
    expect(block, contains('android.appwidget.action.APPWIDGET_UPDATE'));
    expect(block, contains('android:name="android.appwidget.provider"'));
    expect(block, contains('android:resource="@xml/today_widget_info"'));
  });

  test('the provider XML, layouts and strings exist', () {
    final info = _read('$_main/res/xml/today_widget_info.xml');
    expect(info, contains('<appwidget-provider'));
    expect(info, contains('android:targetCellWidth="4"'));
    expect(info, contains('android:targetCellHeight="2"'));
    for (final ref in ['today_widget', 'today_widget_preview']) {
      expect(info, contains('@layout/$ref'));
    }
    for (final layout in [
      'today_widget',
      'today_widget_rtl',
      'today_widget_preview',
    ]) {
      expect(
        File('$_main/res/layout/$layout.xml').existsSync(),
        isTrue,
        reason: layout,
      );
    }
    expect(info, contains('@string/widget_today_description'));
    expect(
      File('$_main/res/values-ar/widget_strings.xml').existsSync(),
      isTrue,
    );
  });

  test('the Kotlin class matches the name Dart asks to redraw', () {
    final kotlin = _read('$_main/kotlin/com/ownhub/app/$kAndroidWidgetName.kt');
    expect(kotlin, contains('package com.ownhub.app'));
    expect(
      kotlin,
      contains('class $kAndroidWidgetName : HomeWidgetProvider()'),
    );
  });

  test(
    'it reads the payload key the app writes, and opens ownhub://widget',
    () {
      final kotlin = _read(
        '$_main/kotlin/com/ownhub/app/$kAndroidWidgetName.kt',
      );
      expect(kotlin, contains('"$kWidgetPayloadKey"'));
      expect(kotlin, contains('ownhub://widget?homeWidget=1&to='));
    },
  );

  test('it reads no payload key outside the allow-list', () {
    final kotlin = _read('$_main/kotlin/com/ownhub/app/$kAndroidWidgetName.kt');
    final allowed = {...kWidgetPayloadKeys, ...kWidgetStringKeys};
    final read = RegExp(
      r'(?:optString|optInt|optBoolean|optJSONObject|has|isNull|str)\("([A-Za-z0-9]+)"',
    ).allMatches(kotlin).map((m) => m.group(1)!);
    expect(read, isNotEmpty);
    for (final key in read) {
      expect(allowed, contains(key));
    }
  });
}
