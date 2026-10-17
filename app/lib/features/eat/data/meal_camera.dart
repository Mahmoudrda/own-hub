/// The rear camera on E12, and nothing more than a camera.
///
/// The ID screens' camera (`camera_capture_service.dart`) measures every frame
/// for blur, glare and faces. A plate needs none of that: she frames it, she
/// presses the shutter. So this opens the rear lens with no image stream and
/// no detector, and keeps only the two rules that matter for any photograph
/// this app takes:
///
///  * **The size is chosen at the lens.** `captureResolution` is the same
///    preset the ID photos use: 1280 pixels on the long edge, which is what
///    the meal server needs and less (it re-encodes to 768). There is no JPEG
///    encoder in the app to shrink a bigger one, and `frame_budget.dart`
///    explains why one is not added.
///  * **The file the plugin writes is read and deleted in one `finally`.**
///    `package:camera` has no in-memory shutter, so for a few milliseconds the
///    photo is a file in the app's temporary folder. Then it is bytes in
///    memory, held by E12 alone, and the path is never stored or passed on.
///    Nothing goes to the gallery, and the app never asks for the photo
///    library.
///  * **Nothing is left behind on any path.** A shutter that fails after the
///    plugin has written its file hands back no path to delete, and a delete
///    can fail. So a failed photo, closing the camera and every start of the
///    app sweep the plugin's temporary folder for its photo files
///    ([sweepCameraLeftovers]).
///
/// A photo that is not a JPEG (some phones can be set to HEIC) is refused
/// here rather than sent, because the server reads JPEG.
library;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, MissingPluginException;
import 'package:flutter/widgets.dart';

import '../../signup/data/cover_fit_viewfinder.dart';
import '../../signup/data/frame_budget.dart';

/// Why the camera cannot be shown.
enum MealCameraProblem {
  /// She turned camera access off. She can turn it back on in Settings.
  permissionDenied,

  /// This phone has no rear camera.
  noCamera,

  /// The camera would not start, or this build has none (a test, a desktop).
  unavailable,
}

/// Opens the camera for one visit to E12.
abstract class MealCamera {
  Future<MealCameraSession> open();
}

/// One run of the lens, owned by the screen that opened it.
abstract class MealCameraSession {
  /// Null while the camera is live.
  MealCameraProblem? get problem;

  /// The live picture, filling whatever box it is given.
  Widget buildPreview();

  /// Takes one photo and hands back its JPEG bytes, or null when no readable
  /// JPEG came out of the shutter.
  Future<Uint8List?> takePhoto();

  /// Releases the lens. Safe to call twice, never throws.
  Future<void> close();
}

/// The real camera, over `package:camera`.
class PluginMealCamera implements MealCamera {
  PluginMealCamera({Future<List<CameraDescription>> Function()? lenses})
    : _lenses = lenses ?? availableCameras;

  final Future<List<CameraDescription>> Function() _lenses;

  @override
  Future<MealCameraSession> open() async {
    final List<CameraDescription> lenses;
    try {
      lenses = await _lenses();
    } on CameraException catch (error) {
      return _ClosedSession(problemOf(error));
    } on MissingPluginException {
      return const _ClosedSession(MealCameraProblem.unavailable);
    } catch (_) {
      return const _ClosedSession(MealCameraProblem.unavailable);
    }

    final lens = lenses
        .where((camera) => camera.lensDirection == CameraLensDirection.back)
        .firstOrNull;
    if (lens == null) return const _ClosedSession(MealCameraProblem.noCamera);

    final controller = CameraController(
      lens,
      captureResolution,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      // A flash on a plate is glare on the food; a lamp is better, and the
      // screen says so.
      await controller.setFlashMode(FlashMode.off);
    } on CameraException catch (error) {
      await _quietly(controller.dispose);
      return _ClosedSession(problemOf(error));
    } catch (_) {
      await _quietly(controller.dispose);
      return const _ClosedSession(MealCameraProblem.unavailable);
    }
    return _LensSession(controller);
  }

  /// A plugin error in E12's terms. The permission codes differ per platform
  /// and plugin version, so this reads the code loosely, as the ID camera
  /// does.
  @visibleForTesting
  static MealCameraProblem problemOf(CameraException error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') ||
        code.contains('permission') ||
        code.contains('restricted')) {
      return MealCameraProblem.permissionDenied;
    }
    if (code.contains('notfound') || code.contains('nocamera')) {
      return MealCameraProblem.noCamera;
    }
    return MealCameraProblem.unavailable;
  }
}

class _LensSession implements MealCameraSession {
  _LensSession(this._controller);

  final CameraController _controller;
  bool _closed = false;
  bool _taking = false;

  @override
  MealCameraProblem? get problem => null;

  @override
  Widget buildPreview() {
    final ratio = _controller.value.aspectRatio;
    final upright = ratio > 1 ? Size(1, ratio) : Size(ratio, 1);
    return CoverFitViewfinder(
      previewSize: Size(upright.width * 1000, upright.height * 1000),
      preview: CameraPreview(_controller),
    );
  }

  @override
  Future<Uint8List?> takePhoto() async {
    if (_closed || _taking) return null;
    _taking = true;
    try {
      final shot = await _controller.takePicture();
      final bytes = await _readAndDelete(shot);
      if (bytes == null) return null;
      // Not a JPEG (a phone set to HEIC): refused here, not sent.
      if (jpegSize(bytes) == null) return null;
      if (kDebugMode && !frameIsWithinBudget(bytes)) {
        debugPrint('meal photo out of budget: ${bytes.length} bytes');
      }
      return bytes;
    } catch (error) {
      if (kDebugMode) debugPrint('meal photo failed: $error');
      // The plugin may have written the photo before it failed, and handed
      // back no path to delete.
      unawaited(sweepCameraLeftovers());
      return null;
    } finally {
      _taking = false;
    }
  }

  /// Reads the plugin's temporary file and removes it, in one `finally`, so a
  /// read that throws still leaves nothing behind.
  static Future<Uint8List?> _readAndDelete(XFile shot) async {
    final file = File(shot.path);
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    } finally {
      try {
        if (file.existsSync()) await file.delete();
      } catch (error) {
        if (kDebugMode) debugPrint('could not delete the meal photo: $error');
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _quietly(_controller.dispose);
    // A shutter still finishing as the screen closed writes a file nobody
    // reads. The lens is released, so none is being written now.
    await sweepCameraLeftovers();
  }
}

class _ClosedSession implements MealCameraSession {
  const _ClosedSession(this.problem);

  @override
  final MealCameraProblem problem;

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<Uint8List?> takePhoto() async => null;

  @override
  Future<void> close() async {}
}

Future<void> _quietly(Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (kDebugMode) debugPrint('camera release failed: $error');
  }
}

/// The photo files `package:camera` writes, and nothing else: `CAP_<uuid>` on
/// iOS (`tmp/camera/pictures`), `CAP<number>` on Android (the cache folder).
final RegExp _cameraFileName = RegExp(
  r'^CAP(_[0-9A-Fa-f-]{36}|-?[0-9]+)\.(jpe?g|heic|heif)$',
  caseSensitive: false,
);

/// Whether [name] is a photo file the camera plugin writes.
@visibleForTesting
bool isCameraLeftover(String name) => _cameraFileName.hasMatch(name);

/// Where the camera plugin keeps a photo before it is read.
Future<List<Directory>> cameraTempFolders() async {
  final system = Directory.systemTemp;
  final folders = <Directory>[
    Directory('${system.path}/camera/pictures'),
    system,
  ];
  try {
    folders.add(await getTemporaryDirectory());
  } catch (_) {
    // No platform folder (a test, a desktop): the system one is all there is.
  }
  return folders;
}

/// Deletes every photo file the camera plugin left in its temporary folders,
/// from E12 or from the ID screens, which use the same plugin. Only files
/// named the way the plugin names them, never a folder and never a link.
///
/// Returns how many it deleted. Never throws: a folder it cannot read is
/// skipped, and the next start tries again.
Future<int> sweepCameraLeftovers({
  Future<List<Directory>> Function()? folders,
}) async {
  List<Directory> where;
  try {
    where = await (folders ?? cameraTempFolders)();
  } catch (_) {
    return 0;
  }
  final seen = <String>{};
  var removed = 0;
  for (final folder in where) {
    if (!seen.add(folder.absolute.path)) continue;
    try {
      if (!await folder.exists()) continue;
      await for (final entity in folder.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!isCameraLeftover(name)) continue;
        try {
          await entity.delete();
          removed++;
        } catch (error) {
          if (kDebugMode) debugPrint('could not delete a camera file: $error');
        }
      }
    } catch (_) {
      // Unreadable here; nothing to do until the next start.
    }
  }
  return removed;
}
