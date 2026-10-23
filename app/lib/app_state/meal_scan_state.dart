/// E12 and E13's session state: her consent on this phone, and the one scan
/// being checked.
///
/// ## Consent, remembered per account
///
/// The server keeps the record (`users/{uid}/consents/meal-photo-v1`); this
/// phone keeps only the fact that the record was written, for this uid, so
/// the sheet is not shown again. It is remembered only after the callable
/// has answered, and forgotten the moment the server says `consent_missing`,
/// so the phone can never believe in a consent the server does not hold.
/// Account deletion and sign-out on this phone remove it.
///
/// ## The scan between E12 and E13
///
/// `goTo` carries a route name and nothing else, so the result rides here,
/// as the recipe E06 opens does (`EatAppState.openRecipeId`). It holds foods
/// and grams, never the photo: the photo lives only inside E12 and is wiped
/// there. It is cleared when E13 logs or is left.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../features/eat/data/meal_camera.dart';
import '../features/eat/data/meal_scan_client.dart';
import '../features/eat/domain/meal_scan.dart';

/// The uid whose meal-photo consent the server recorded, on this phone.
const String kMealPhotoConsentKey = 'own_hub.meal_photo_consent_uid';

class MealScanState {
  MealScanState._();

  static final MealScanState instance = MealScanState._();

  /// The callables. Replaced in tests.
  MealScanClient client = CallableMealScanClient();

  /// The camera. Replaced in tests and in the screenshot harness.
  MealCamera camera = PluginMealCamera();

  /// The answer E13 is checking, or null.
  MealScanResult? result;

  /// Stands for "no account" when nobody is signed in, as in a demo build.
  static const String _noAccount = '-';

  String? _consentedUid;
  bool _loaded = false;

  /// Whether [uid] has agreed on this phone. Reads the phone once.
  Future<bool> hasConsented(String? uid) async {
    if (!_loaded) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _consentedUid ??= prefs.getString(kMealPhotoConsentKey);
      } catch (_) {
        // A store that cannot be read means asking again, which is safe.
      }
      _loaded = true;
    }
    return _consentedUid != null && _consentedUid == (uid ?? _noAccount);
  }

  /// The server recorded her agreement. Only ever called after it has.
  Future<void> rememberConsent(String? uid) async {
    final who = uid ?? _noAccount;
    _consentedUid = who;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kMealPhotoConsentKey, who);
    } catch (_) {
      // Kept for this session; she is asked again after a restart.
    }
  }

  /// The server no longer has it, or she left this phone.
  Future<void> forgetConsent() async {
    _consentedUid = null;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kMealPhotoConsentKey);
    } catch (_) {}
  }

  /// Drops the scan being checked.
  void clear() => result = null;

  /// Everything, for sign-out and account deletion. Never throws.
  Future<void> erase() async {
    clear();
    await forgetConsent();
  }

  /// Back to a fresh session without touching the phone. Tests only.
  void resetForTest({MealScanClient? client, MealCamera? camera}) {
    result = null;
    _consentedUid = null;
    _loaded = false;
    this.client = client ?? CallableMealScanClient();
    this.camera = camera ?? PluginMealCamera();
  }
}
