/// Opening this app's own page in the phone's settings.
///
/// Used by the capture screens when she turned camera access off. Lives here
/// for the same reason `open_link.dart` does: screens describe what she sees
/// and never reach past the app by themselves.
///
/// iOS opens it through the documented `app-settings:` URL. Android has no URL
/// for it, so `MainActivity` answers one method on [_channel] with
/// `ACTION_APPLICATION_DETAILS_SETTINGS`. Never throws: a phone that cannot
/// open the page leaves her on the capture screen, where the reviewer path is
/// still offered.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const MethodChannel _channel = MethodChannel('com.ownhub.app/settings');

Future<bool> openAppSettings() async {
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return await launchUrl(Uri.parse('app-settings:'));
      case TargetPlatform.android:
        return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
      default:
        return false;
    }
  } catch (_) {
    return false;
  }
}
