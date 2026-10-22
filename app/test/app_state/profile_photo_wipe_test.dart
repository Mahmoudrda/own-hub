// Deleting everything, and a different woman signing in, both take her profile
// photo off the phone.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/profile_photo_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/profile_photo_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory picks;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    docs = Directory.systemTemp.createTempSync('own_hub_docs_');
    picks = Directory.systemTemp.createTempSync('own_hub_picks_');
    ProfilePhotoState.instance
      ..reset()
      // Nothing here may sweep the shared system temp folder: other test
      // processes keep their own picker files there.
      ..pickerFolders = (() async => [])
      ..directory = (() async => docs)
      ..picker = FakePhotoPicker(picks, bytes: await twoToneImage(300, 300));
    await ProfilePhotoState.instance.change(
      PhotoSource.camera,
      crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
    );
  });

  tearDown(() {
    ProfilePhotoState.instance.reset();
    docs.deleteSync(recursive: true);
    picks.deleteSync(recursive: true);
  });

  test('the photo counts as something of hers that remains', () {
    expect(ProfilePhotoState.instance.hasPhoto, isTrue);
    expect(nothingOfHersRemains, isFalse);
  });

  test('the phone wipe removes the photo from memory and from disk', () async {
    expect(docs.listSync(), hasLength(1));

    await const ThisPhoneWipe().clearPersistence();
    // Gone from the screens in the same breath.
    expect(ProfilePhotoState.instance.hasPhoto, isFalse);
    await pumpEventQueue();

    expect(docs.listSync(), isEmpty);
    expect(nothingOfHersRemains, isTrue);
  });

  test('a different account signing in drops it as well', () async {
    await const ThisPhoneWipe(
      keepsOwner: true,
      keepsSignUp: true,
    ).clearPersistence();
    await pumpEventQueue();

    expect(ProfilePhotoState.instance.hasPhoto, isFalse);
    expect(docs.listSync(), isEmpty);
  });

  test('delete everything on this phone removes it', () async {
    await deleteEverythingOnThisPhone();
    await pumpEventQueue();

    expect(ProfilePhotoState.instance.hasPhoto, isFalse);
    expect(docs.listSync(), isEmpty);
  });
}
