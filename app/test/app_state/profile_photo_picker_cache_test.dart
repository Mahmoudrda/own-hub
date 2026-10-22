// The picker's own copies of her picture (Android copies the whole picture
// into the cache folder) never stay behind, and a big camera frame is drawn
// smaller before the crop sheet sees it.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/profile_photo_state.dart';

import '../helpers/profile_photo_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory picks;
  late Directory cache;
  late Directory strictTemp;
  late ProfilePhotoState state;

  const uuid = '3f2b8c1e-9d4a-4e6b-8a1c-0d5e7f9a2b34';

  void plantPickerCopies() {
    File('${cache.path}/scaled_IMG_1.jpg').writeAsBytesSync([1]);
    File('${cache.path}/image_picker_9.png').writeAsBytesSync([1]);
    File('${cache.path}/IMG_2.JPG').writeAsBytesSync([1]);
    Directory('${cache.path}/$uuid').createSync();
    File('${cache.path}/$uuid/IMG_3.jpg').writeAsBytesSync([1]);
    Directory('${cache.path}/image_picker77').createSync();
    File('${cache.path}/image_picker77/anything.bin').writeAsBytesSync([1]);
    File('${strictTemp.path}/image_picker_abc.jpg').writeAsBytesSync([1]);
  }

  void plantOthers() {
    File('${cache.path}/notes.txt').writeAsStringSync('keep');
    Directory('${cache.path}/libCachedImageData').createSync();
    File('${cache.path}/libCachedImageData/a.jpg').writeAsBytesSync([1]);
    Directory('${cache.path}/mixed-$uuid').createSync();
    final mixed = Directory('${cache.path}/$uuid-data')..createSync();
    File('${mixed.path}/a.jpg').writeAsBytesSync([1]);
    File('${strictTemp.path}/other_app.png').writeAsBytesSync([1]);
  }

  List<String> names(Directory dir) =>
      dir
          .listSync()
          .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList()
        ..sort();

  setUp(() {
    docs = Directory.systemTemp.createTempSync('own_hub_docs_');
    picks = Directory.systemTemp.createTempSync('own_hub_picks_');
    cache = Directory.systemTemp.createTempSync('own_hub_cache_');
    strictTemp = Directory.systemTemp.createTempSync('own_hub_strict_');
    state = ProfilePhotoState.instance
      ..reset()
      ..directory = (() async => docs)
      ..pickerFolders = (() async => [
        (dir: cache, strict: false),
        (dir: strictTemp, strict: true),
      ]);
  });

  tearDown(() {
    state.reset();
    for (final dir in [docs, picks, cache, strictTemp]) {
      dir.deleteSync(recursive: true);
    }
  });

  test(
    'setting a photo clears every copy the picker left in the cache',
    () async {
      plantPickerCopies();
      plantOthers();
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );

      final outcome = await state.change(
        PhotoSource.gallery,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
      );

      expect(outcome, ProfilePhotoOutcome.saved);
      expect(names(cache), [
        '$uuid-data',
        'libCachedImageData',
        'mixed-$uuid',
        'notes.txt',
      ]);
      expect(names(strictTemp), ['other_app.png']);
      expect(File('${cache.path}/$uuid-data/a.jpg').existsSync(), isTrue);
    },
  );

  test('backing out and a failed pick clear them as well', () async {
    plantPickerCopies();
    state.picker = FakePhotoPicker(picks, bytes: await twoToneImage(300, 300));
    await state.change(PhotoSource.gallery, crop: (_) async => null);
    expect(names(cache), isEmpty);
    expect(names(strictTemp), isEmpty);

    plantPickerCopies();
    state.picker = FakePhotoPicker(
      picks,
      bytes: Uint8List.fromList(<int>[9, 9, 9]),
    );
    final outcome = await state.change(
      PhotoSource.gallery,
      crop: (_) async => const ui.Rect.fromLTWH(0, 0, 2, 2),
    );
    expect(outcome, ProfilePhotoOutcome.failed);
    expect(names(cache), isEmpty);
  });

  test('delete everything clears them too', () async {
    plantPickerCopies();
    await state.erase();
    expect(names(cache), isEmpty);
    expect(names(strictTemp), isEmpty);
  });

  test('opening the app clears copies left by a run that was killed', () async {
    plantPickerCopies();
    await state.load();
    await state.sweeping;
    expect(names(cache), isEmpty);
  });

  group('a big picture', () {
    test('is drawn at most 2048 on its long side before the crop', () async {
      final big = await twoToneImage(4000, 3000);
      final reduced = await reduceProfilePhotoSource(big);
      expect(await sizeOf(reduced), const ui.Size(2048, 1536));
      // The halves are where they were.
      expect(await pixelAt(reduced, 100, 700), 0xFFFF0000);
      expect(await pixelAt(reduced, 1900, 700), 0xFF0000FF);
    });

    test('a small one is left as it is', () async {
      final small = await twoToneImage(800, 600);
      expect(await reduceProfilePhotoSource(small), same(small));
    });

    test('the crop sheet is handed the reduced picture', () async {
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(4096, 2048),
      );
      ui.Size? seen;
      await state.change(
        PhotoSource.gallery,
        crop: (picture) async {
          seen = await sizeOf(picture);
          return const ui.Rect.fromLTWH(0, 0, 1024, 1024);
        },
      );
      expect(seen, const ui.Size(2048, 1024));
      expect(state.hasPhoto, isTrue);
    });
  });

  test('load skips and deletes a half-written file', () async {
    final good = await twoToneImage(64, 64);
    File('${docs.path}/own_hub_profile_photo_1.png').writeAsBytesSync(good);
    File('${docs.path}/own_hub_profile_photo_2.png.part').writeAsBytesSync([7]);

    await state.load();

    expect(state.path, endsWith('own_hub_profile_photo_1.png'));
    expect(state.bytes, good);
    expect(names(docs), ['own_hub_profile_photo_1.png']);
  });
}
