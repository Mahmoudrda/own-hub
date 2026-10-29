/// Her acceptance of the Terms of Use and the Privacy Policy (M1).
///
/// C06 is where she accepts: the button reads "Agree and send me a code", the
/// line under it names both documents and links to them, and one tap is both
/// the acceptance and the send. She has no account yet at that moment, so the
/// acceptance is written to this phone first ([PendingLegalAcceptance]) and
/// sent to the server once her code is accepted (`record_legal_acceptance`,
/// recorded at `users/{uid}/consents/legal-t3-p3`). The server keeps the
/// versions, the language, the app version, the platform, when her phone says
/// she tapped and when it recorded it. Clients may read that record and never
/// write it, like every consent record.
///
/// **Versions are material.** [kTermsVersion] and [kPrivacyVersion] move only
/// when a change needs her agreement again; the app then shows the legal
/// update sheet at launch until she agrees or deletes her account. A wording
/// fix is a document number (3.0 to 3.1) and does not move them. They must
/// equal the server's `TERMS_VERSION` and `PRIVACY_VERSION`
/// (functions/identity/config.py); the shared contract and the release
/// preflight both check it.
///
/// O03 and O05, the questions before C06, never count as acceptance.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The material version of the Terms of Use. Moves with the server's
/// `config.TERMS_VERSION`.
const int kTermsVersion = 3;

/// The material version of the Privacy Policy. Moves with the server's
/// `config.PRIVACY_VERSION`.
const int kPrivacyVersion = 3;

/// The app version recorded beside an acceptance or a consent. Set by
/// `tool/build_release.sh` with `--dart-define=APP_VERSION=<pubspec version>`.
/// A build made any other way records `0.0.0`, which is honest about not
/// knowing.
const String kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.0.0',
);

/// The build number after the `+` in [kAppVersion] (minutes since 1 Jan 2026
/// UTC, as `tool/build_ios.sh` numbers it), or 0 when unknown. Sent as
/// `appBuild` with a coaching request so the server can refuse an app too old
/// to show payments (`coaching.common.MIN_APP_BUILD`).
int get kAppBuild => int.tryParse(kAppVersion.split('+').last) ?? 0;

/// The callable that records an acceptance.
const String kRecordLegalAcceptanceCallable = 'record_legal_acceptance';

/// The SharedPreferences key holding an acceptance not yet on the server.
const String kLegalPendingKey = 'own_hub.legal_pending';

/// The server's document id for a pair of versions, under
/// `users/{uid}/consents/`.
String legalAcceptanceDocId({
  int terms = kTermsVersion,
  int privacy = kPrivacyVersion,
}) => 'legal-t$terms-p$privacy';

/// Where the request comes from, in the server's words.
String legalPlatform([TargetPlatform? platform]) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };

/// One acceptance, as her phone knows it.
@immutable
class LegalAcceptance {
  const LegalAcceptance({
    required this.termsVersion,
    required this.privacyVersion,
    required this.locale,
    required this.acceptedAtMs,
  });

  /// Accepted now, of the versions in force, in [locale].
  factory LegalAcceptance.now(String locale, {DateTime Function()? clock}) =>
      LegalAcceptance(
        termsVersion: kTermsVersion,
        privacyVersion: kPrivacyVersion,
        locale: locale == 'ar' ? 'ar' : 'en',
        acceptedAtMs: (clock ?? DateTime.now)().millisecondsSinceEpoch,
      );

  final int termsVersion;
  final int privacyVersion;

  /// `en` or `ar`: the language the documents and the button were shown in.
  final String locale;

  /// When she tapped, by her phone's clock.
  final int acceptedAtMs;

  /// Whether this covers the versions in force today.
  bool get isCurrent =>
      termsVersion == kTermsVersion && privacyVersion == kPrivacyVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    't': termsVersion,
    'p': privacyVersion,
    'locale': locale,
    'acceptedAtMs': acceptedAtMs,
  };

  /// Null for anything that is not a well-formed acceptance.
  static LegalAcceptance? fromJson(Object? json) {
    if (json is! Map) return null;
    final t = json['t'];
    final p = json['p'];
    final locale = json['locale'];
    final at = json['acceptedAtMs'];
    if (t is! int || p is! int || at is! int) return null;
    if (locale != 'en' && locale != 'ar') return null;
    return LegalAcceptance(
      termsVersion: t,
      privacyVersion: p,
      locale: locale as String,
      acceptedAtMs: at,
    );
  }

  /// The body `record_legal_acceptance` accepts. Pinned to the contract by
  /// test/contracts/identity_contract_test.dart.
  Map<String, Object?> payload({
    String appVersion = kAppVersion,
    String? platform,
  }) => <String, Object?>{
    'termsVersion': termsVersion,
    'privacyVersion': privacyVersion,
    'locale': locale,
    'appVersion': appVersion,
    'platform': platform ?? legalPlatform(),
    'acceptedAtMs': acceptedAtMs,
  };
}

/// The acceptance made at C06, kept on this phone until the server has it.
abstract final class PendingLegalAcceptance {
  /// Written before the code is sent, so the acceptance exists the moment
  /// she taps.
  static Future<void> write(LegalAcceptance acceptance) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        kLegalPendingKey,
        jsonEncode(acceptance.toJson()),
      );
    } catch (_) {
      // Nothing to do: without the pending record the launch check finds no
      // server record and asks her again, which is the safe direction.
    }
  }

  static Future<LegalAcceptance?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        kLegalPendingKey,
      );
      if (raw == null) return null;
      return LegalAcceptance.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> erase() async {
    try {
      await (await SharedPreferences.getInstance()).remove(kLegalPendingKey);
    } catch (_) {}
  }
}

/// Where an acceptance is recorded and read back.
abstract class LegalAcceptanceStore {
  /// Records [acceptance] for the signed-in account. Throws when the server
  /// did not confirm.
  Future<void> record(LegalAcceptance acceptance);

  /// Whether [uid] has accepted the versions in force. Throws when it cannot
  /// be known (no connection).
  Future<bool> hasCurrent(String uid);
}

/// In memory, for tests and for a build with no back end.
class InMemoryLegalAcceptanceStore implements LegalAcceptanceStore {
  final Map<String, LegalAcceptance> recorded = <String, LegalAcceptance>{};

  /// The uid [record] writes against. Tests set it.
  String uid = 'me';

  @override
  Future<void> record(LegalAcceptance acceptance) async {
    recorded[uid] = acceptance;
  }

  @override
  Future<bool> hasCurrent(String uid) async =>
      recorded[uid]?.isCurrent ?? false;
}

/// What the launch check, and the check after C07, found.
enum LegalStatus {
  /// The server has her acceptance of the versions in force.
  accepted,

  /// It does not: she has to agree again, or delete her account.
  needsAgreement,

  /// It could not be told (no connection). Asked again next time.
  unknown,
}

/// Sends a pending acceptance if there is one, else asks the server whether
/// [uid] has accepted the versions in force.
///
/// A pending acceptance of older versions is dropped, not sent: the server
/// would refuse it, and she has not seen the current text.
Future<LegalStatus> reconcileLegalAcceptance({
  required LegalAcceptanceStore store,
  required String uid,
}) async {
  final pending = await PendingLegalAcceptance.read();
  if (pending != null && pending.isCurrent) {
    try {
      await store.record(pending);
      await PendingLegalAcceptance.erase();
      return LegalStatus.accepted;
    } catch (_) {
      // Kept for the next try. She tapped agree; the record is owed.
      return LegalStatus.unknown;
    }
  }
  if (pending != null) await PendingLegalAcceptance.erase();
  try {
    return await store.hasCurrent(uid)
        ? LegalStatus.accepted
        : LegalStatus.needsAgreement;
  } catch (_) {
    return LegalStatus.unknown;
  }
}
