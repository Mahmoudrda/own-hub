/// Keeps a folder out of the phone's backup.
///
/// iOS backs up the app's support folder to iCloud and to a computer unless a
/// folder is marked otherwise. A queued payment screenshot must stay on this
/// phone until it is sent, so the folder that holds them is marked here, in
/// `AppDelegate.swift`, through one method on the `files` channel. Android
/// needs nothing: `allowBackup` is off and `data_extraction_rules.xml` leaves
/// every domain out. Never throws: a phone that refuses changes nothing for
/// the queue, which still works and is still deleted after it is sent.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _iosChannel = MethodChannel('com.ownhub.app/files');

Future<void> excludeFromBackup(String path) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await _iosChannel.invokeMethod<bool>('excludeFromBackup', path);
  } catch (_) {}
}
