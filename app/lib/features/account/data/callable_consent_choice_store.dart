/// The server's record of her optional choices, and the meal-photo withdrawal.
///
/// Usage statistics and crash reports are applied on the phone (see
/// `AnalyticsConsent` and `CrashConsent`); each change is also sent to
/// `record_consent_choice`, which keeps the choice, its version and the time
/// at `users/{uid}/consents/{purpose}-v{N}`. A change that could not be sent
/// (offline, signed out) waits in SharedPreferences and goes with the next
/// change or when Privacy opens. Taking back the meal-photo consent goes
/// through `withdraw_meal_photo_consent` and throws when it fails, so the
/// switch can say so.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../app_state/firebase_boot.dart';
import '../../signup/domain/legal_acceptance.dart' show kAppVersion;

const String kRecordConsentChoiceCallable = 'record_consent_choice';
const String kWithdrawMealPhotoConsentCallable = 'withdraw_meal_photo_consent';

/// The version of each choice's wording, pinned to
/// `CHOICE_CONSENT_VERSIONS` in `functions/identity/config.py`.
const Map<String, int> kChoiceConsentVersions = <String, int>{
  'analytics': 2,
  'crash': 1,
};

String _pendingKey(String purpose) => 'own_hub.consent_choice_pending_$purpose';

/// The body `record_consent_choice` accepts.
Map<String, Object?> consentChoicePayload(
  String purpose,
  bool granted, {
  String? locale,
  String appVersion = kAppVersion,
}) => <String, Object?>{
  'purpose': purpose,
  'granted': granted,
  'consentVersion': kChoiceConsentVersions[purpose],
  'locale': ?locale,
  if (appVersion.isNotEmpty) 'appVersion': appVersion,
};

/// Keeps her change, then sends it and any earlier change that is still
/// waiting. Never throws: the choice is already applied on the phone.
Future<void> recordConsentChoice(
  String purpose,
  bool granted, {
  String? locale,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey(purpose), granted);
  } catch (_) {
    // Sent below anyway; only a failure to send is then not retried.
  }
  await flushPendingConsentChoices(locale: locale);
}

/// Sends every waiting change; a change stays waiting until the server has it.
Future<void> flushPendingConsentChoices({String? locale}) async {
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }
  for (final purpose in kChoiceConsentVersions.keys) {
    final granted = prefs.getBool(_pendingKey(purpose));
    if (granted == null) continue;
    try {
      await FirebaseBoot.functions
          .httpsCallable(kRecordConsentChoiceCallable)
          .call<Object?>(
            consentChoicePayload(purpose, granted, locale: locale),
          );
      await prefs.remove(_pendingKey(purpose));
    } catch (_) {
      // Signed out, offline or refused: it waits for the next time.
    }
  }
}

/// Takes back the consent to send meal photos to Google. Throws when the
/// server could not be reached, so nothing is shown as withdrawn that is not.
Future<void> withdrawMealPhotoConsent() async {
  await FirebaseBoot.functions
      .httpsCallable(kWithdrawMealPhotoConsentCallable)
      .call<Object?>(<String, Object?>{});
}
