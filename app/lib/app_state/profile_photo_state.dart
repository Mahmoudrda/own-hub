/// Her profile photo, kept on this phone and nowhere else.
///
/// The picture is chosen from the camera or her photos, cropped to a square by
/// her, then drawn again at 512 x 512 and written as a PNG. Drawing it again is
/// what drops everything the original carried: the PNG encoder writes the
/// pixels and no camera, date or location data. Only that PNG is kept, in the
/// app's documents folder. The file the picker hands back is read once and
/// deleted, whatever happens next, and so is anything else the picker left in
/// the app's cache folder (Android copies the full picture there).
///
/// Nothing here touches the network. The photo is not a document, not a
/// storage object and not something she can turn on a backup for. A backup of
/// the whole phone made by the phone itself can still hold a copy made before
/// it was deleted; Delete everything and signing in as a different woman both
/// remove it from this phone (`ThisPhoneWipe`).
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_changes.dart';

/// The side of the square the photo is kept at.
const int kProfilePhotoSide = 512;

/// The longest side of the picture the crop sheet works on. A bigger camera
/// frame is drawn smaller first, so the sheet never holds it in full.
const int kProfilePhotoPickSide = 2048;

const String _filePrefix = 'own_hub_profile_photo_';
const String _fileSuffix = '.png';
const String _partSuffix = '.part';

enum PhotoSource { camera, gallery }

/// What happened when she tried to set a photo.
enum ProfilePhotoOutcome {
  /// The new photo is on the phone and showing.
  saved,

  /// She backed out at the picker or the crop. Nothing changed.
  cancelled,

  /// The phone would not let Own Hub use the camera. Nothing changed.
  denied,

  /// The picture could not be read or drawn. Nothing changed.
  failed,
}

/// The phone refused the camera or the photos.
class ProfilePhotoPermissionDenied implements Exception {
  const ProfilePhotoPermissionDenied();
}

/// Hands back the path of the picture she picked, or null when she backed out.
/// The file is the picker's own copy, and the state deletes it.
abstract class ProfilePhotoPicker {
  Future<String?> pick(PhotoSource source);
}

/// The system picker. On iOS the photo library opens in the out-of-process
/// picker and on Android in the system photo picker, so neither needs a library
/// permission; the camera uses the permission the app already has.
class SystemProfilePhotoPicker implements ProfilePhotoPicker {
  const SystemProfilePhotoPicker();

  static const Set<String> _denied = <String>{
    'camera_access_denied',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_restricted',
  };

  @override
  Future<String?> pick(PhotoSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        // False, so iOS does not ask for the photo library to read the
        // picture's metadata. It is dropped anyway.
        requestFullMetadata: false,
      );
      return file?.path;
    } on PlatformException catch (e) {
      if (_denied.contains(e.code)) throw const ProfilePhotoPermissionDenied();
      rethrow;
    }
  }
}

class ProfilePhotoState extends ChangeNotifier {
  ProfilePhotoState._();

  static final ProfilePhotoState instance = ProfilePhotoState._();

  /// Replaced in tests, so nothing touches the platform.
  ProfilePhotoPicker picker = const SystemProfilePhotoPicker();

  /// The folder the photo lives in. Replaced in tests.
  Future<Directory> Function() directory = getApplicationDocumentsDirectory;

  /// The folders the picker leaves its own copies in. In a [strict] folder
  /// only files the picker names (`image_picker_*`, `scaled_*`) are touched;
  /// in the app's own cache folder any picture file is, because nothing else
  /// of Own Hub's keeps pictures loose there. Replaced in tests.
  Future<List<({Directory dir, bool strict})>> Function() pickerFolders =
      _systemPickerFolders;

  static Future<List<({Directory dir, bool strict})>>
  _systemPickerFolders() async {
    final folders = <({Directory dir, bool strict})>[];
    try {
      folders.add((dir: await getTemporaryDirectory(), strict: false));
    } catch (_) {}
    folders.add((dir: Directory.systemTemp, strict: true));
    if (Platform.isAndroid) {
      try {
        for (final dir
            in await getExternalStorageDirectories(
                  type: StorageDirectory.pictures,
                ) ??
                const <Directory>[]) {
          folders.add((dir: dir, strict: true));
        }
      } catch (_) {}
    }
    return folders;
  }

  String? _path;
  Uint8List? _bytes;

  /// Where her photo is, or null when she has none.
  String? get path => _path;

  /// The photo itself, ready to draw. Held in memory so a changed photo shows
  /// at once and the screens that draw it never read a file.
  Uint8List? get bytes => _bytes;

  bool get hasPhoto => _bytes != null;

  /// Finds the photo from an earlier run. Called once at boot; a missing or
  /// unreadable file simply means no photo.
  Future<void> load() async {
    try {
      final dir = await directory();
      final files = await _photoFiles(dir);
      File? newest;
      for (final file in files) {
        // A half-written file from a kill is never a photo.
        if (file.path.endsWith(_partSuffix)) {
          try {
            await file.delete();
          } catch (_) {}
          continue;
        }
        if (newest == null || file.path.compareTo(newest.path) > 0) {
          newest = file;
        }
      }
      if (newest == null) return;
      final read = await newest.readAsBytes();
      if (read.isEmpty) return;
      _path = newest.path;
      _bytes = read;
      _changed();
    } catch (_) {
      // No photo is a fine answer. It must never stop the app opening.
    } finally {
      // A copy the picker left behind when the app was closed mid-way. Once
      // the photo is showing, and not waited for.
      _sweeping = _clearPickerCopies();
    }
  }

  Future<void> _sweeping = Future<void>.value();

  /// The clean-up [load] started, for tests to wait on.
  @visibleForTesting
  Future<void> get sweeping => _sweeping;

  /// Picks, crops, redraws and keeps. [crop] shows her the crop UI and returns
  /// the square, in the picture's own pixels, or null if she backs out.
  Future<ProfilePhotoOutcome> change(
    PhotoSource source, {
    required Future<ui.Rect?> Function(Uint8List picture) crop,
  }) async {
    String? picked;
    try {
      picked = await picker.pick(source);
      if (picked == null) return ProfilePhotoOutcome.cancelled;
      final original = await reduceProfilePhotoSource(
        await File(picked).readAsBytes(),
      );
      final square = await crop(original);
      if (square == null) return ProfilePhotoOutcome.cancelled;
      final png = await renderProfilePhoto(original, square);
      await _keep(png);
      return ProfilePhotoOutcome.saved;
    } on ProfilePhotoPermissionDenied {
      return ProfilePhotoOutcome.denied;
    } catch (_) {
      return ProfilePhotoOutcome.failed;
    } finally {
      await _discardPicked(picked);
      await _clearPickerCopies();
    }
  }

  /// Deletes her photo. The screens redraw at once; the file follows.
  Future<void> remove() async {
    _forget();
    await _deleteFiles();
    await _clearPickerCopies();
  }

  /// [remove], for the wipe: the in-memory photo is gone before the first
  /// await, so nothing can draw it again while the file is being deleted.
  Future<void> erase() => remove();

  /// Forgets the photo in memory only, and puts the test seams back.
  @visibleForTesting
  void reset() {
    _path = null;
    _bytes = null;
    picker = const SystemProfilePhotoPicker();
    directory = getApplicationDocumentsDirectory;
    pickerFolders = _systemPickerFolders;
  }

  void _forget() {
    if (_bytes == null && _path == null) return;
    _path = null;
    _bytes = null;
    _changed();
  }

  void _changed() {
    notifyListeners();
    AppChanges.bump();
  }

  /// A new name each time, so nothing that caches by path can show the old
  /// picture. Written beside its final name and renamed once whole, so a kill
  /// half way never leaves a broken photo.
  Future<void> _keep(Uint8List png) async {
    final dir = await directory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final name = '$_filePrefix$stamp$_fileSuffix';
    final part = File('${dir.path}/$name$_partSuffix');
    await part.writeAsBytes(png, flush: true);
    final finalFile = await part.rename('${dir.path}/$name');
    _path = finalFile.path;
    _bytes = png;
    _changed();
    await _deleteFiles(except: finalFile.path);
  }

  Future<void> _deleteFiles({String? except}) async {
    try {
      final dir = await directory();
      for (final file in await _photoFiles(dir)) {
        if (file.path == except) continue;
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (_) {
      // A folder that cannot be listed has nothing she can see.
    }
  }

  Future<List<File>> _photoFiles(Directory dir) async {
    final found = <File>[];
    if (!await dir.exists()) return found;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith(_filePrefix)) continue;
      if (name.endsWith(_fileSuffix) || name.endsWith(_partSuffix)) {
        found.add(entity);
      }
    }
    return found;
  }

  /// Deletes what the picker left in the cache folders: its own copies of the
  /// picture, whole or resized, with the camera and location data the original
  /// carries. Only picture files and the picker's own folders are touched.
  Future<void> _clearPickerCopies() async {
    try {
      for (final folder in await pickerFolders()) {
        try {
          if (!await folder.dir.exists()) continue;
          await for (final entity in folder.dir.list(followLinks: false)) {
            final name = entity.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last;
            try {
              if (entity is File && _isPickerFile(name, folder.strict)) {
                await entity.delete();
              } else if (entity is Directory &&
                  await _isPickerFolder(entity, folder.strict)) {
                await entity.delete(recursive: true);
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static final RegExp _pictureName = RegExp(
    r'\.(jpe?g|png|heic|heif|webp|gif)$',
    caseSensitive: false,
  );

  static bool _isPickerFile(String name, bool strict) =>
      name.startsWith('image_picker') ||
      name.startsWith('scaled_') ||
      (!strict && _pictureName.hasMatch(name));

  /// A folder the picker made: named for it, or a random id holding nothing
  /// but pictures.
  static Future<bool> _isPickerFolder(Directory folder, bool strict) async {
    final name = folder.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (name.startsWith('image_picker')) return true;
    if (strict || !_uuid.hasMatch(name)) return false;
    var any = false;
    await for (final inner in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      if (inner is Directory) continue;
      if (inner is! File) return false;
      if (!_isPickerFile(inner.uri.pathSegments.last, false)) return false;
      any = true;
    }
    return any;
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// The picker's copy of what she chose is never kept.
  Future<void> _discardPicked(String? picked) async {
    if (picked == null) return;
    try {
      final kept = _path;
      if (kept != null && picked == kept) return;
      final file = File(picked);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// [source] drawn again with its longest side at most [kProfilePhotoPickSide],
/// as PNG, or [source] itself when it is already that small. The crop sheet and
/// [renderProfilePhoto] both work on what this returns, so the square she
/// chooses lands on the same pixels.
Future<Uint8List> reduceProfilePhotoSource(Uint8List source) async {
  final codec = await ui.instantiateImageCodec(source);
  try {
    final image = (await codec.getNextFrame()).image;
    try {
      final longest = image.width > image.height ? image.width : image.height;
      if (longest <= kProfilePhotoPickSide) return source;
      final scale = kProfilePhotoPickSide / longest;
      final width = (image.width * scale).round().clamp(
        1,
        kProfilePhotoPickSide,
      );
      final height = (image.height * scale).round().clamp(
        1,
        kProfilePhotoPickSide,
      );
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.high
          ..isAntiAlias = true,
      );
      final picture = recorder.endRecording();
      final drawn = await picture.toImage(width, height);
      try {
        final data = await drawn.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const FormatException('could not encode');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        drawn.dispose();
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// Draws [source] again: the square [crop] (in the picture's pixels) at
/// [kProfilePhotoSide] x [kProfilePhotoSide], encoded as PNG.
///
/// Redrawing is the point. The result is pixels and nothing else, so no EXIF,
/// no text chunk and no location survives from the original.
Future<Uint8List> renderProfilePhoto(Uint8List source, ui.Rect crop) async {
  final codec = await ui.instantiateImageCodec(source);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final bounds = ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final from = crop.intersect(bounds);
      if (from.width < 1 || from.height < 1) {
        throw const FormatException('the crop is outside the picture');
      }
      final side = kProfilePhotoSide.toDouble();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        from,
        ui.Rect.fromLTWH(0, 0, side, side),
        ui.Paint()
          ..filterQuality = ui.FilterQuality.high
          ..isAntiAlias = true,
      );
      final picture = recorder.endRecording();
      final drawn = await picture.toImage(kProfilePhotoSide, kProfilePhotoSide);
      try {
        final data = await drawn.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const FormatException('could not encode');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        drawn.dispose();
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
