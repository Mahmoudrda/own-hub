/// The two callables behind E12: her consent, and one scan of one photo.
///
/// `record_meal_photo_consent` takes `{consentVersion, locale, appVersion}`
/// and writes `users/{uid}/consents/meal-photo-v1` once. `analyze_meal_photo`
/// takes `{imageJpeg, locale}` and answers `{items, totals, estimate}`; both
/// are in `functions/main.py`. App Check and her ID token ride along with the
/// plugin, as on every other callable.
///
/// The photo is sent once, as base64, and the string is dropped the moment
/// the call returns. Nothing here keeps it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/crash_reports.dart';
import '../../../app_state/firebase_boot.dart';
import '../domain/meal_scan.dart';

const String kAnalyzeMealPhotoCallable = 'analyze_meal_photo';
const String kRecordMealPhotoConsentCallable = 'record_meal_photo_consent';

/// How long a scan is waited for. The model call itself is a few seconds; a
/// slow upload on mobile data is most of this.
const Duration kMealScanTimeout = Duration(seconds: 60);

/// How long the consent record is waited for. A few bytes each way.
const Duration kMealConsentTimeout = Duration(seconds: 20);

abstract class MealScanClient {
  /// Records her agreement to [kMealPhotoConsentVersion] on the server.
  /// Throws [MealScanException] when the server refuses or cannot be reached.
  Future<void> recordConsent({required String locale, String? appVersion});

  /// One scan of [jpeg]. Throws [MealScanException] for every refusal.
  Future<MealScanResult> analyse(Uint8List jpeg, {required String locale});
}

/// The real one, over `cloud_functions`.
class CallableMealScanClient implements MealScanClient {
  CallableMealScanClient({this.functions});

  /// Null means the app's own, in Frankfurt.
  final FirebaseFunctions? functions;

  /// Read only when a call is made, never at construction, so a screen can
  /// hold one in a test without touching Firebase.
  FirebaseFunctions get _callables => functions ?? FirebaseBoot.functions;

  @override
  Future<void> recordConsent({
    required String locale,
    String? appVersion,
  }) async {
    final callable = _callables.httpsCallable(
      kRecordMealPhotoConsentCallable,
      options: HttpsCallableOptions(timeout: kMealConsentTimeout),
    );
    try {
      await callable.call<Object?>(<String, Object?>{
        'consentVersion': kMealPhotoConsentVersion,
        'locale': locale,
        'appVersion': ?appVersion,
      });
    } on FirebaseFunctionsException catch (error) {
      throw _refused(error);
    } catch (_) {
      throw const MealScanException(MealScanFailure.unavailable);
    }
  }

  @override
  Future<MealScanResult> analyse(
    Uint8List jpeg, {
    required String locale,
  }) async {
    final callable = _callables.httpsCallable(
      kAnalyzeMealPhotoCallable,
      options: HttpsCallableOptions(timeout: kMealScanTimeout),
    );
    Object? data;
    try {
      // Built inside the call so the encoded copy has no name that outlives
      // it.
      final result = await callable.call<Object?>(<String, Object?>{
        'imageJpeg': base64Encode(jpeg),
        'locale': locale,
      });
      data = result.data;
    } on FirebaseFunctionsException catch (error) {
      throw _refused(error);
    } catch (_) {
      throw const MealScanException(MealScanFailure.unavailable);
    }
    final parsed = MealScanResult.fromWire(data);
    if (parsed == null) {
      throw const MealScanException(MealScanFailure.unavailable);
    }
    if (parsed.items.isEmpty) {
      throw const MealScanException(MealScanFailure.noFoodSeen);
    }
    return parsed;
  }

  /// The server's reason, as E12's. A fault that is ours is also reported
  /// by its status code alone, with her consent to crash reports.
  static MealScanException _refused(FirebaseFunctionsException error) {
    unawaited(CrashReports.serverError(error.code));
    return MealScanException(mealScanFailureOf(error.code, error.message));
  }
}
