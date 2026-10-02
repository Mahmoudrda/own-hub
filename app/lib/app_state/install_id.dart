/// A random id for this installation, and a fresh id for each check attempt.
///
/// The install id is sent raw on `verify_identity`; the server hashes it before
/// storing anything (functions/main.py `_install_hash`). It is random, not
/// derived from the device, and it is erased with everything else when she
/// deletes her data (`ThisPhoneWipe.clearPersistence`).
///
/// The operation id is a uuid v4, one per check attempt, reused on the single
/// retry so a retried call is recognised by the server and never pays for OCR
/// twice.
library;

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const String kInstallIdKey = 'own_hub.install_id';

class InstallId {
  InstallId._();

  static String? _cached;

  /// The id for this install, created on first use. Throws if preferences are
  /// unavailable; callers treat that as "no id" rather than failing a check.
  static Future<String> read() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(kInstallIdKey);
    if (id == null || id.length != 32) {
      id = _hex(16);
      await prefs.setString(kInstallIdKey, id);
    }
    return _cached = id;
  }

  /// Forgets the id. The next [read] makes a new one.
  static Future<void> erase() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kInstallIdKey);
  }
}

final Random _random = Random.secure();

String _hex(int bytes) =>
    [for (var i = 0; i < bytes; i++) _random.nextInt(256)]
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

/// A random (version 4) uuid.
String newOperationId() {
  final b = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
