// Her photo on the avatar: shown on her own picture, never on another
// woman's, and the initial still there when there is no photo.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/profile_photo_state.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_avatar.dart';

import '../helpers/profile_photo_fixture.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  late Directory docs;
  late Directory picks;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('own_hub_docs_');
    picks = Directory.systemTemp.createTempSync('own_hub_picks_');
    ProfilePhotoState.instance
      ..reset()
      // Nothing here may sweep the shared system temp folder: other test
      // processes keep their own picker files there.
      ..pickerFolders = (() async => [])
      ..directory = (() async => docs);
  });

  tearDown(() {
    ProfilePhotoState.instance.reset();
    docs.deleteSync(recursive: true);
    picks.deleteSync(recursive: true);
  });

  Future<void> setPhoto(WidgetTester tester) async {
    await tester.runAsync(() async {
      ProfilePhotoState.instance.picker = FakePhotoPicker(
        picks,
        bytes: await twoToneImage(300, 300),
      );
      await ProfilePhotoState.instance.change(
        PhotoSource.gallery,
        crop: (_) async => const ui.Rect.fromLTWH(0, 0, 300, 300),
      );
    });
  }

  testWidgets('shows the initial when there is no photo', (tester) async {
    await tester.pumpWidget(
      _host(const AppAvatar(firstName: 'Mai', roles: UserRoles.trainee)),
    );
    await tester.pumpAndSettle();

    expect(find.text('M'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-avatar-photo')), findsNothing);
  });

  testWidgets('shows her photo instead of the initial once she has one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const AppAvatar(firstName: 'Mai', roles: UserRoles.trainee)),
    );
    await setPhoto(tester);
    await tester.pump();

    expect(find.byKey(const ValueKey('app-avatar-photo')), findsOneWidget);
    expect(find.text('M'), findsNothing);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('app-avatar-photo')),
    );
    expect(image.image, isA<ResizeImage>());
  });

  testWidgets(
    'is still announced as her profile, and the photo adds no label',
    (tester) async {
      await setPhoto(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const AppAvatar(firstName: 'Mai', roles: UserRoles.trainee)),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Your profile'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('goes back to the initial when the photo is removed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const AppAvatar(firstName: 'Mai', roles: UserRoles.trainee)),
    );
    await setPhoto(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-avatar-photo')), findsOneWidget);

    await tester.runAsync(ProfilePhotoState.instance.remove);
    await tester.pump();

    expect(find.byKey(const ValueKey('app-avatar-photo')), findsNothing);
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('never puts her photo on another woman\'s avatar', (
    tester,
  ) async {
    await setPhoto(tester);
    await tester.pumpWidget(
      _host(const AppAvatar(firstName: 'Sara', size: 40, isSelf: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-avatar-photo')), findsNothing);
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('falls back to the initial if the picture cannot be drawn', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Bytes that are not a picture: only reachable if the file was damaged.
      docs.listSync().whereType<File>().forEach((f) => f.deleteSync());
      File('${docs.path}/own_hub_profile_photo_1.png')
          .writeAsBytesSync([1, 2, 3]);
      await ProfilePhotoState.instance.load();
    });
    await tester.pumpWidget(
      _host(const AppAvatar(firstName: 'Mai', roles: UserRoles.trainee)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('M'), findsOneWidget);
    tester.takeException();
  });
}
