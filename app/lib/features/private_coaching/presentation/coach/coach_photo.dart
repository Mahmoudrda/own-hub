/// Choosing her coach photo: camera or her photos, cropped to a square and
/// drawn again as a PNG. It reuses the profile photo pieces but never touches
/// the photo that stays on this phone.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import '../../../../app_state/profile_photo_state.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_sheet.dart';
import '../../../../ui/profile_photo_crop.dart';

/// Hands back the picture to upload, or null when she backs out. May throw
/// [ProfilePhotoPermissionDenied]. A test replaces it.
typedef CoachPhotoChooser = Future<Uint8List?> Function(BuildContext context);

/// The system picker, then the crop sheet.
Future<Uint8List?> chooseCoachPhoto(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final source = await showAppSheet<PhotoSource>(
    context: context,
    children: [
      Builder(
        builder: (sheet) => AppListItem(
          title: l10n.takeAPhoto,
          leading: const Icon(Icons.photo_camera_outlined),
          onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
        ),
      ),
      Builder(
        builder: (sheet) => AppListItem(
          title: l10n.chooseFromYourPhotos,
          leading: const Icon(Icons.photo_library_outlined),
          onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
        ),
      ),
    ],
  );
  if (source == null || !context.mounted) return null;
  String? picked;
  try {
    picked = await const SystemProfilePhotoPicker().pick(source);
    if (picked == null || !context.mounted) return null;
    final original = await reduceProfilePhotoSource(
      await File(picked).readAsBytes(),
    );
    if (!context.mounted) return null;
    final square = await showProfilePhotoCrop(context, original);
    if (square == null) return null;
    return await renderProfilePhoto(original, square);
  } finally {
    // The picker's own copy carries camera and place data; it is never kept.
    if (picked != null) {
      try {
        final file = File(picked);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

/// A picture for her portfolio: the bytes and how to upload them.
class CoachImage {
  const CoachImage(this.bytes, {this.contentType = 'image/jpeg'});

  final Uint8List bytes;
  final String contentType;
}

/// Hands back the picture to upload, or null when she backs out. May throw
/// [ProfilePhotoPermissionDenied]. A test replaces it.
typedef CoachImageChooser = Future<CoachImage?> Function(BuildContext context);

const Set<String> _deniedCodes = <String>{
  'camera_access_denied',
  'camera_access_restricted',
  'photo_access_denied',
  'photo_access_restricted',
};

/// Camera or her photos, scaled down and kept as a JPEG. No crop: results
/// photos are not square. The server draws every image again, so nothing the
/// camera wrote survives, and the picker's own copy is deleted here.
Future<CoachImage?> chooseCoachImage(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final source = await showAppSheet<ImageSource>(
    context: context,
    children: [
      Builder(
        builder: (sheet) => AppListItem(
          title: l10n.takeAPhoto,
          leading: const Icon(Icons.photo_camera_outlined),
          onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
        ),
      ),
      Builder(
        builder: (sheet) => AppListItem(
          title: l10n.chooseFromYourPhotos,
          leading: const Icon(Icons.photo_library_outlined),
          onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
        ),
      ),
    ],
  );
  if (source == null) return null;
  String? picked;
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    picked = file.path;
    return CoachImage(await file.readAsBytes());
  } on PlatformException catch (e) {
    if (_deniedCodes.contains(e.code)) {
      throw const ProfilePhotoPermissionDenied();
    }
    rethrow;
  } finally {
    if (picked != null) {
      try {
        final f = File(picked);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
