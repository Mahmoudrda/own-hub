/// Picking a photo for the application: resized and recompressed on the phone,
/// checked by its first bytes, never sent before she presses Send.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../../../../app_state/profile_photo_state.dart'
    show PhotoSource, ProfilePhotoPermissionDenied;
import '../../domain/coaching_contract.dart';

/// The longest side a photo is drawn at before it is kept, and its JPEG
/// quality. A certificate stays readable at this size.
const int kApplyPhotoSide = 1600;
const int kApplyPhotoQuality = 85;

/// The picture she chose, ready to keep.
class PickedPhoto {
  const PickedPhoto(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;
}

/// The picture is not a JPEG or a PNG, is empty, or is too big.
class ApplyPhotoInvalid implements Exception {
  const ApplyPhotoInvalid();
}

/// `image/jpeg` or `image/png` from the first bytes, or null for anything
/// else. The file's name is never trusted.
String? sniffImageType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  return null;
}

/// Checks [bytes] and names their type; throws [ApplyPhotoInvalid].
PickedPhoto checkPickedPhoto(Uint8List bytes) {
  final type = sniffImageType(bytes);
  if (type == null ||
      bytes.isEmpty ||
      bytes.length > CoachingLimits.uploadMaxBytes) {
    throw const ApplyPhotoInvalid();
  }
  return PickedPhoto(bytes, type);
}

abstract class ApplyPhotoPicker {
  /// Null when she backs out. Throws [ProfilePhotoPermissionDenied] when the
  /// phone refuses the camera and [ApplyPhotoInvalid] for a file that cannot
  /// be used.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class SystemApplyPhotoPicker implements ApplyPhotoPicker {
  const SystemApplyPhotoPicker();

  static const Set<String> _denied = <String>{
    'camera_access_denied',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_restricted',
  };

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: kApplyPhotoSide.toDouble(),
        maxHeight: kApplyPhotoSide.toDouble(),
        imageQuality: kApplyPhotoQuality,
        // False, so iOS does not ask for the photo library to read metadata.
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      if (_denied.contains(e.code)) throw const ProfilePhotoPermissionDenied();
      rethrow;
    }
    if (file == null) return null;
    try {
      return checkPickedPhoto(await file.readAsBytes());
    } finally {
      // The picker's own copy is not kept.
      try {
        await File(file.path).delete();
      } catch (_) {}
    }
  }
}
