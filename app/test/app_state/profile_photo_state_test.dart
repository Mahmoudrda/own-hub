// Her profile photo: what is kept, what is dropped, and what changes when
// something goes wrong (which is nothing).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/app_state/profile_photo_state.dart';

import '../helpers/profile_photo_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory picks;
  late ProfilePhotoState state;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('own_hub_docs_');
    picks = Directory.systemTemp.createTempSync('own_hub_picks_');
    state = ProfilePhotoState.instance
      ..reset()
      // Nothing here may sweep the shared system temp folder: other test
      // processes keep their own picker files there.
      ..pickerFolders = (() async => [])
      ..directory = (() async => docs);
  });

  tearDown(() {
    state.reset();
    docs.deleteSync(recursive: true);
    picks.deleteSync(recursive: true);
  });

  List<String> kept() => docs
      .listSync()
      .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .toList();

  group('redrawing the picture', () {
    test('comes out 512 x 512 and carries no metadata chunk', () async {
      final original = withMetadata(await twoToneImage(800, 600));
      // The input really does carry what a camera picture carries.
      expect(pngChunkNames(original), containsAll(<String>['tEXt', 'eXIf']));

      final out = await renderProfilePhoto(
        original,
        const ui.Rect.fromLTWH(100, 0, 600, 600),
      );

      expect(await sizeOf(out), const ui.Size(512, 512));
      final names = pngChunkNames(out);
      expect(names.first, 'IHDR');
      expect(names.last, 'IEND');
      expect(names, contains('IDAT'));
      for (final metadata in ['tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME']) {
        expect(names, isNot(contains(metadata)), reason: metadata);
      }
    });

    test('keeps exactly the square she chose', () async {
      final original = await twoToneImage(800, 600);

      final right = await renderProfilePhoto(
        original,
        const ui.Rect.fromLTWH(400, 0, 400, 400),
      );
      expect(await pixelAt(right, 20, 256), 0xFF0000FF);
      expect(await pixelAt(right, 490, 256), 0xFF0000FF);

      final left = await renderProfilePhoto(
        original,
        const ui.Rect.fromLTWH(0, 0, 400, 400),
      );
      expect(await pixelAt(left, 20, 256), 0xFFFF0000);

      final middle = await renderProfilePhoto(
        original,
        const ui.Rect.fromLTWH(100, 0, 600, 600),
      );
      expect(await pixelAt(middle, 20, 256), 0xFFFF0000);
      expect(await pixelAt(middle, 490, 256), 0xFF0000FF);
    });

    test(
      'refuses a crop outside the picture and a file that is no picture',
      () {
        expect(
          () async => renderProfilePhoto(
            await twoToneImage(100, 100),
            const ui.Rect.fromLTWH(500, 500, 50, 50),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          renderProfilePhoto(
            Uint8List.fromList(<int>[1, 2, 3, 4]),
            const ui.Rect.fromLTWH(0, 0, 2, 2),
          ),
          throwsA(anything),
        );
      },
    );
  });

  group('setting a photo', () {
    test('keeps only the redrawn PNG and deletes the picker copy', () async {
      final picker = FakePhotoPicker(
        picks,
        bytes: withMetadata(await twoToneImage(400, 300)),
      );
      state.picker = picker;
      var bumps = 0;
      AppChanges.instance.addListener(() => bumps++);

      final outcome = await state.change(
        PhotoSource.gallery,
        crop: (_) async => const ui.Rect.fromLTWH(50, 0, 300, 300),
      );

      expect(outcome, ProfilePhotoOutcome.saved);
      expect(picker.asked, [PhotoSource.gallery]);
      expect(state.hasPhoto, isTrue);
      expect(bumps, greaterThan(0));
      // The picker's file is gone; only one file of hers is in the folder.
      expect(File(picker.handedOut.single).existsSync(), isFalse);
      expect(picks.listSync(), isEmpty);
      expect(kept(), hasLength(1));
      expect(kept().single, startsWith('own_hub_profile_photo_'));
      expect(kept().single, endsWith('.png'));
      // What is on disk is what is shown, and it is clean.
      final onDisk = File(state.path!).readAsBytesSync();
      expect(onDisk, state.bytes);
      expect(await sizeOf(onDisk), const ui.Size(512, 512));
      expect(pngChunkNames(onDisk), isNot(contains('eXIf')));
      expect(pngChunkNames(onDisk), isNot(contains('tEXt')));
    });

    test('a new photo replaces the old file under a new name', () async {
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );
      Future<ProfilePhotoOutcome> set() => state.change(
        PhotoSource.camera,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
      );

      await set();
      final first = state.path;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await set();

      expect(state.path, isNot(first));
      expect(kept(), hasLength(1));
      expect(File(first!).existsSync(), isFalse);
    });

    test('backing out at the picker changes nothing', () async {
      state.picker = FakePhotoPicker(picks, cancels: true);

      final outcome = await state.change(
        PhotoSource.camera,
        crop: (_) async => fail('the crop must not open'),
      );

      expect(outcome, ProfilePhotoOutcome.cancelled);
      expect(state.hasPhoto, isFalse);
      expect(kept(), isEmpty);
    });

    test(
      'backing out at the crop keeps the old photo and deletes the pick',
      () async {
        final fake = FakePhotoPicker(
          picks,
          bytes: await twoToneImage(300, 300),
        );
        state.picker = fake;
        await state.change(
          PhotoSource.camera,
          crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
        );
        final before = state.path;
        final beforeBytes = state.bytes;

        final outcome = await state.change(
          PhotoSource.gallery,
          crop: (_) async => null,
        );

        expect(outcome, ProfilePhotoOutcome.cancelled);
        expect(state.path, before);
        expect(state.bytes, beforeBytes);
        expect(kept(), hasLength(1));
        expect(picks.listSync(), isEmpty);
      },
    );

    test('a refused camera says denied and changes nothing', () async {
      state.picker = FakePhotoPicker(
        picks,
        error: const ProfilePhotoPermissionDenied(),
      );

      final outcome = await state.change(
        PhotoSource.camera,
        crop: (_) async => fail('the crop must not open'),
      );

      expect(outcome, ProfilePhotoOutcome.denied);
      expect(state.hasPhoto, isFalse);
      expect(kept(), isEmpty);
    });

    test('a picker error says failed and changes nothing', () async {
      state.picker = FakePhotoPicker(
        picks,
        error: PlatformException(code: 'x'),
      );

      final outcome = await state.change(
        PhotoSource.gallery,
        crop: (_) async => fail('the crop must not open'),
      );

      expect(outcome, ProfilePhotoOutcome.failed);
      expect(state.hasPhoto, isFalse);
    });

    test('a file that is no picture says failed, keeps the old photo and deletes the pick', () async {
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );
      await state.change(
        PhotoSource.camera,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
      );
      final before = state.path;
      final broken = FakePhotoPicker(
        picks,
        bytes: Uint8List.fromList(<int>[9, 9, 9, 9]),
      );
      state.picker = broken;

      final outcome = await state.change(
        PhotoSource.gallery,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 2, 2),
      );

      expect(outcome, ProfilePhotoOutcome.failed);
      expect(state.path, before);
      expect(kept(), hasLength(1));
      expect(File(broken.handedOut.single).existsSync(), isFalse);
    });

    test('a crop that throws says failed', () async {
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );

      final outcome = await state.change(
        PhotoSource.gallery,
        crop: (_) async => throw const FormatException('cannot decode'),
      );

      expect(outcome, ProfilePhotoOutcome.failed);
      expect(state.hasPhoto, isFalse);
      expect(picks.listSync(), isEmpty);
    });
  });

  group('removing and loading', () {
    test('remove deletes the file and tells the screens at once', () async {
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );
      await state.change(
        PhotoSource.camera,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
      );
      expect(kept(), hasLength(1));
      var bumps = 0;
      AppChanges.instance.addListener(() => bumps++);

      final done = state.remove();
      // Before the file is gone, the photo is already out of memory.
      expect(state.hasPhoto, isFalse);
      expect(bumps, greaterThan(0));
      await done;

      expect(kept(), isEmpty);
    });

    test('load finds the photo from an earlier run and nothing else', () async {
      state.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );
      await state.change(
        PhotoSource.camera,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
      );
      final saved = state.bytes;
      final path = state.path;
      File('${docs.path}/unrelated.txt').writeAsStringSync('keep me');
      state.reset();
      state.directory = () async => docs;
      state.pickerFolders = (() async => []);
      expect(state.hasPhoto, isFalse);

      await state.load();

      expect(state.path, path);
      expect(state.bytes, saved);
      await state.remove();
      expect(File('${docs.path}/unrelated.txt').existsSync(), isTrue);
    });

    test('load with no file, or an empty one, means no photo', () async {
      await state.load();
      expect(state.hasPhoto, isFalse);

      File('${docs.path}/own_hub_profile_photo_1.png').writeAsBytesSync([]);
      await state.load();
      expect(state.hasPhoto, isFalse);
    });

    test('remove with no photo is harmless', () async {
      await state.remove();
      expect(state.hasPhoto, isFalse);
    });
  });
}
