/// `K02`: her certificate photo, from the camera to a woman reviewer.
///
/// Two steps, in this order, and the second is what makes it count:
///
///  1. the photo goes to `coach-docs/{uid}/{credential}-{time}.jpg` in the
///     personal bucket. `storage.rules` lets only her write there (an image or a
///     PDF, under 10 MB) and only her and an admin read it;
///  2. `submit_coach_certificate` records it at
///     `coaches/{uid}/certificates/{id}` as `uploaded`. The rules let no client
///     write that path, so the state can only be moved on by a reviewer.
///
/// A photo that did not reach the bucket is never shown as sent, and a failure
/// is reported to her rather than queued: `K02`'s row says "Uploaded,
/// checking" only after both steps answered.
library;

import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../app_state/firebase_boot.dart';

/// Callable name, identical on both sides.
const String kSubmitCoachCertificateCallable = 'submit_coach_certificate';

/// Where her photo goes. The time keeps two photos of one credential apart and
/// makes a retry of the same photo land on the same record.
String certificateMediaRef({
  required String coachUid,
  required String credentialId,
  required DateTime at,
}) => 'coach-docs/$coachUid/$credentialId-${at.millisecondsSinceEpoch}.jpg';

/// What `submit_coach_certificate` takes.
Map<String, Object> certificatePayload({
  required String credentialId,
  required String mediaRef,
}) => <String, Object>{'credentialId': credentialId, 'mediaRef': mediaRef};

/// Why a certificate did not go.
enum CertificateUploadFailure {
  /// No connection, or the server did not answer.
  unreachable,

  /// The server refused it: the coach side is closed, or she is not verified.
  refused,
}

class CertificateUploadException implements Exception {
  const CertificateUploadException(this.failure);
  final CertificateUploadFailure failure;

  @override
  String toString() => 'CertificateUploadException(${failure.name})';
}

/// Sends a certificate photo and records it. Returns the record's id.
abstract class CertificateUploader {
  Future<String> upload({
    required String mediaRef,
    required String credentialId,
    required Uint8List jpeg,
  });
}

class FirebaseCertificateUploader implements CertificateUploader {
  FirebaseCertificateUploader({
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _storage = storage ?? FirebaseBoot.personalMedia,
       _functions = functions ?? FirebaseBoot.functions;

  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  @override
  Future<String> upload({
    required String mediaRef,
    required String credentialId,
    required Uint8List jpeg,
  }) async {
    try {
      await _storage
          .ref(mediaRef)
          .putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    } on FirebaseException catch (error) {
      throw CertificateUploadException(
        error.code == 'unauthorized'
            ? CertificateUploadFailure.refused
            : CertificateUploadFailure.unreachable,
      );
    }
    final callable = _functions.httpsCallable(
      kSubmitCoachCertificateCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    try {
      final result = await callable.call<Object?>(
        certificatePayload(credentialId: credentialId, mediaRef: mediaRef),
      );
      final data = result.data;
      final id = data is Map ? data['certificateId'] : null;
      if (id is! String || id.isEmpty) {
        throw const CertificateUploadException(
          CertificateUploadFailure.unreachable,
        );
      }
      return id;
    } on FirebaseFunctionsException catch (error) {
      throw CertificateUploadException(switch (error.code) {
        'failed-precondition' ||
        'permission-denied' ||
        'invalid-argument' ||
        'resource-exhausted' => CertificateUploadFailure.refused,
        _ => CertificateUploadFailure.unreachable,
      });
    }
  }
}
