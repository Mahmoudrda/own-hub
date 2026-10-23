// The camera plugin writes each photo to a temporary file before E12 reads it.
// Whatever path a shot takes, no such file stays on the phone: a failed shot,
// closing the camera and every start sweep the plugin's folders.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/data/meal_camera.dart';

void main() {
  late Directory root;
  late Directory pictures;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meal_camera_sweep');
    pictures = await Directory('${root.path}/camera/pictures')
        .create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File touch(Directory folder, String name) =>
      File('${folder.path}/$name')..writeAsBytesSync(const [0xFF, 0xD8]);

  test('the names the plugin writes, and nothing else', () {
    expect(
      isCameraLeftover('CAP_0F8FAD5B-D9CB-469F-A165-70867728950E.jpg'),
      isTrue,
    );
    expect(
      isCameraLeftover('CAP_0F8FAD5B-D9CB-469F-A165-70867728950E.heif'),
      isTrue,
    );
    expect(isCameraLeftover('CAP1234567890.jpg'), isTrue);
    expect(isCameraLeftover('CAP-1234567890.jpg'), isTrue);
    expect(
      isCameraLeftover('REC_0F8FAD5B-D9CB-469F-A165-70867728950E.mp4'),
      isFalse,
    );
    expect(isCameraLeftover('own_hub_clip.mp4'), isFalse);
    expect(isCameraLeftover('CAP_notes.txt'), isFalse);
    expect(isCameraLeftover('photo.jpg'), isFalse);
  });

  test(
    'a start sweeps every photo the plugin left, on either platform',
    () async {
      final ios = touch(
        pictures,
        'CAP_0F8FAD5B-D9CB-469F-A165-70867728950E.jpg',
      );
      final android = touch(root, 'CAP4815162342.jpg');
      final other = touch(root, 'workout_clip.mp4');
      final folder = await Directory('${root.path}/CAP123.jpg').create();

      final removed = await sweepCameraLeftovers(
        folders: () async => [pictures, root, root],
      );

      expect(removed, 2);
      expect(ios.existsSync(), isFalse);
      expect(android.existsSync(), isFalse);
      expect(other.existsSync(), isTrue, reason: 'not a camera photo');
      expect(folder.existsSync(), isTrue, reason: 'only files are deleted');
    },
  );

  test(
    'a folder that is missing or unreadable is skipped, never thrown',
    () async {
      final missing = Directory('${root.path}/nowhere');
      expect(await sweepCameraLeftovers(folders: () async => [missing]), 0);
      expect(
        await sweepCameraLeftovers(
          folders: () async => throw const FileSystemException('no'),
        ),
        0,
      );
    },
  );

  test(
    'the folders include the plugin picture folder under the system temp',
    () async {
      final folders = await cameraTempFolders();
      expect(
        folders.map((f) => f.path),
        contains('${Directory.systemTemp.path}/camera/pictures'),
      );
    },
  );
}
