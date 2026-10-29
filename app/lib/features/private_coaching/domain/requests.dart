/// The bodies of the small callables, in one place so a test can hold them to
/// the contract's `requestKeys`.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'coach_application.dart';
import 'coaching_contract.dart';
import 'parse.dart';
import 'session_link.dart';
import 'subscription.dart';

abstract final class CoachingRequests {
  static Json updateProfile({
    String? headline,
    String? approachText,
    String? photoPath,
    bool? acceptingClients,
    bool? autoAccept,
    int? maxActiveClients,
  }) => <String, Object?>{
    'headline': ?headline?.trim(),
    'approachText': ?approachText?.trim(),
    'photoPath': ?photoPath,
    'acceptingClients': ?acceptingClients,
    'autoAccept': ?autoAccept,
    'maxActiveClients': ?maxActiveClients,
  };

  static Json payoutChange(CoachPayoutAccount account) => account.toMap();

  /// What she ticked on the request form: the version and a hash of each text
  /// as she read it, so the record shows which words she agreed to. The
  /// InBody tick exists only when she attached her numbers.
  static Json requestConsent({
    required String shareText,
    required String transferText,
    String? inbodyText,
    required String appVersion,
  }) => <String, Object?>{
    'version': 2,
    'shareHash': sha256.convert(utf8.encode(shareText)).toString(),
    'transferHash': sha256.convert(utf8.encode(transferText)).toString(),
    if (inbodyText != null)
      'inbodyHash': sha256.convert(utf8.encode(inbodyText)).toString(),
    if (appVersion.isNotEmpty) 'appVersion': appVersion,
  };

  /// Her tick on the chat rules: the version and a hash of the words she saw.
  static Json acceptChatRules({
    required String rulesText,
    required String locale,
    required String appVersion,
  }) => <String, Object?>{
    'version': 1,
    'textHash': sha256.convert(utf8.encode(rulesText)).toString(),
    'locale': locale,
    if (appVersion.isNotEmpty) 'appVersion': appVersion,
  };

  static Json requestCoaching({
    required String coachUid,
    required String packageId,
    required Intake intake,
    required Json consent,
    required String locale,
    String clientName = '',
    String? inviteCode,
    required int appBuild,
  }) => <String, Object?>{
    'appBuild': appBuild,
    'coachUid': coachUid,
    'packageId': packageId,
    'intake': intake.toRequest(),
    'consent': consent,
    'locale': locale,
    'clientName': clientName,
    'inviteCode': ?inviteCode,
  };

  static Json respond({
    required String subId,
    required bool accept,
    CoachDeclineReason? declineReason,
  }) => <String, Object?>{
    'subId': subId,
    'decision': accept ? 'accept' : 'decline',
    if (!accept) 'reason': (declineReason ?? CoachDeclineReason.other).wire,
  };

  static Json cancelRequest(String subId) => <String, Object?>{'subId': subId};

  static Json endMine(String subId, String? reason) => <String, Object?>{
    'subId': subId,
    'reason': ?reason?.trim(),
  };

  static Json cancellation(String subId, String? reason) => <String, Object?>{
    'subId': subId,
    'reason': ?reason?.trim(),
  };

  static Json scheduleSession({
    required String subId,
    required DateTime startsAt,
    required int minutes,
    required String link,
  }) => <String, Object?>{
    'subId': subId,
    'startsAt': wireTime(startsAt),
    'minutes': minutes,
    'link': link,
  };

  static Json respondSession({
    required String subId,
    required String sessionId,
    required bool confirm,
  }) => <String, Object?>{
    'subId': subId,
    'sessionId': sessionId,
    'decision': confirm ? 'confirm' : 'decline',
  };

  static Json markDone(String subId, String sessionId) => <String, Object?>{
    'subId': subId,
    'sessionId': sessionId,
  };

  static Json signupRole(String role) => <String, Object?>{'role': role};
}
