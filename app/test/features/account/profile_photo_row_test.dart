// A02 — the Profile photo row: add, change and remove, and what each failure
// says. The picker is a fake that hands back a file in a temp folder.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/profile_photo_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/account/presentation/profile_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/profile_photo_fixture.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host({Locale locale = const Locale('en'), double textScale = 1.0}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: ProfileView(
          dietaryRepository: InMemoryDietaryProfileRepository(),
          firstName: 'Mai',
        ),
      ),
    ),
  );
}

/// File and image work finishes on real time, its continuations in the test's
/// fake time: alternate the two until [done] holds (or, with no [done], a short
/// fixed spell). A busy machine slows the real half, so the wait is on the
/// outcome, not on a count of turns.
Future<void> settleIo(WidgetTester tester, {bool Function()? done}) async {
  final turns = done == null ? 25 : 600;
  for (var i = 0; i < turns; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (done != null && done()) break;
  }
  // Let the notice slide in.
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory docs;
  late Directory picks;
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff;
    docs = Directory.systemTemp.createTempSync('own_hub_docs_');
    picks = Directory.systemTemp.createTempSync('own_hub_picks_');
    ProfilePhotoState.instance
      ..reset()
      ..directory = (() async => docs)
      // The picker's cache folders are real disk work; not part of this test.
      ..pickerFolders = (() async => []);
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    ProfilePhotoState.instance.reset();
    docs.deleteSync(recursive: true);
    picks.deleteSync(recursive: true);
  });

  Future<void> hasPhoto(WidgetTester tester) async {
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

  testWidgets('A02 carries the row, with the one sentence under it', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('Profile photo'), findsOneWidget);
    expect(
      find.text(
        'Your photo is kept on this phone and never uploaded by Own Hub. Only you see it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('with no photo the sheet offers camera and photos, not remove', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();

    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from your photos'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
  });

  testWidgets('with a photo the sheet says Change and offers Remove', (
    tester,
  ) async {
    _phone(tester);
    await hasPhoto(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-avatar-photo')), findsOneWidget);

    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();

    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsOneWidget);
  });

  testWidgets(
    'Remove photo deletes it and the header goes back to the initial',
    (tester) async {
      _phone(tester);
      await hasPhoto(tester);
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await settleIo(
        tester,
        done: () =>
            docs.listSync().isEmpty &&
            find.text('Your photo was removed.').evaluate().isNotEmpty,
      );

      expect(ProfilePhotoState.instance.hasPhoto, isFalse);
      expect(docs.listSync(), isEmpty);
      expect(find.byKey(const ValueKey('app-avatar-photo')), findsNothing);
      expect(find.text('Your photo was removed.'), findsOneWidget);
    },
  );

  testWidgets('backing out at the picker changes nothing and says nothing', (
    tester,
  ) async {
    _phone(tester);
    final fake = FakePhotoPicker(picks, cancels: true);
    ProfilePhotoState.instance.picker = fake;
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(fake.asked, [PhotoSource.camera]);
    expect(ProfilePhotoState.instance.hasPhoto, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refused camera shows a plain message and changes nothing', (
    tester,
  ) async {
    _phone(tester);
    ProfilePhotoState.instance.picker = FakePhotoPicker(
      picks,
      error: const ProfilePhotoPermissionDenied(),
    );
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not open the camera'), findsOneWidget);
    expect(ProfilePhotoState.instance.hasPhoto, isFalse);
  });

  testWidgets('a picker failure shows a plain message', (tester) async {
    _phone(tester);
    ProfilePhotoState.instance.picker = FakePhotoPicker(
      picks,
      error: PlatformException(code: 'invalid_image'),
    );
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from your photos'));
    await tester.pumpAndSettle();

    expect(
      find.text('That photo could not be used. Please try another one.'),
      findsOneWidget,
    );
    expect(ProfilePhotoState.instance.hasPhoto, isFalse);
  });

  testWidgets('adding a photo end to end: pick, crop sheet, set', (
    tester,
  ) async {
    _phone(tester);
    late Uint8List original;
    await tester.runAsync(() async => original = await twoToneImage(800, 600));
    ProfilePhotoState.instance.picker = FakePhotoPicker(picks, bytes: original);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from your photos'));
    await settleIo(
      tester,
      done: () => find.text('Fit your photo').evaluate().isNotEmpty,
    );

    expect(find.text('Fit your photo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-photo-use')));
    await settleIo(
      tester,
      done: () => find.text('Your photo is set.').evaluate().isNotEmpty,
    );

    expect(ProfilePhotoState.instance.hasPhoto, isTrue);
    expect(find.byKey(const ValueKey('app-avatar-photo')), findsOneWidget);
    expect(find.text('Your photo is set.'), findsOneWidget);
    expect(picks.listSync(), isEmpty);
  });

  testWidgets('reads right to left in Arabic and fits at text scale 2', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(locale: const Locale('ar'), textScale: 2.0));
    await tester.pumpAndSettle();

    expect(find.text('صورة البروفايل'), findsOneWidget);
    await tester.tap(find.text('صورة البروفايل'));
    await tester.pumpAndSettle();

    expect(find.text('ضيفي صورة'), findsOneWidget);
    expect(find.text('اختاري من صورك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
