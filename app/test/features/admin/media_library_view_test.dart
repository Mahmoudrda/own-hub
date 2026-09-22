// Z10 — Media library.
//
// The design note: "Bulk upload, then linked by filename to the ids the CSV
// named. The list leads with files linked to nothing, because those are the ones
// that will break a row at validation."
//
// So the assertion that matters is the ordering of attention: unlinked first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/media_bundle.dart';
import 'package:own_hub/features/admin/domain/media_picker.dart';
import 'package:own_hub/features/admin/presentation/admin_widgets.dart';
import 'package:own_hub/features/admin/presentation/media_library_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

const MediaBundle _bundle = MediaBundle([
  MediaFile(name: 'goblet_squat.mp4', bytes: 12000000, kind: MediaKind.video),
  MediaFile(name: 'koshari.jpg', bytes: 240000, kind: MediaKind.picture),
]);

/// Deliberately different figures from [_bundle]. A size column that ignored
/// its argument — or that kept rendering the byte count — could pass one of
/// these two and not both.
const MediaBundle _otherBundle = MediaBundle([
  MediaFile(name: 'hip_hinge.mp4', bytes: 3400000, kind: MediaKind.video),
  MediaFile(name: 'om_ali.jpg', bytes: 840000, kind: MediaKind.picture),
]);

void main() {
  testWidgets('it names itself and offers the upload', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(const MediaLibraryView()));
    await tester.pumpAndSettle();

    expect(find.text('Media library'), findsOneWidget);
    expect(find.text('Upload videos and pictures'), findsOneWidget);
  });

  group('the filter', () {
    testWidgets('it offers all four of the states the design names', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(const MediaLibraryView(bundle: _bundle)));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unlinked'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
    });

    testWidgets('it opens on Unlinked, because that is what will break', (
      tester,
    ) async {
      // The design's `segmented([...], 1)`, and its note: "The list leads with
      // files linked to nothing, because those are the ones that will break a
      // row at validation."
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const MediaLibraryView(
            bundle: _bundle,
            referenced: {'goblet_squat.mp4'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('koshari.jpg'), findsOneWidget);
      expect(find.text('goblet_squat.mp4'), findsNothing);
    });

    testWidgets('All shows the linked file the opening view hid', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const MediaLibraryView(
            bundle: _bundle,
            referenced: {'goblet_squat.mp4'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('goblet_squat.mp4'), findsOneWidget);
      expect(find.text('koshari.jpg'), findsOneWidget);
    });

    testWidgets('Videos and Photos narrow by kind', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(const MediaLibraryView(bundle: _bundle)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      expect(find.text('goblet_squat.mp4'), findsOneWidget);
      expect(find.text('koshari.jpg'), findsNothing);

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('koshari.jpg'), findsOneWidget);
      expect(find.text('goblet_squat.mp4'), findsNothing);
    });
  });

  group('the size column says a size, not a byte count', () {
    // It read "12,000,000" for a release, because there was no MB and no KB in
    // either dictionary. Both exist now, and so does `File` for the header that
    // had to say `Name`.

    testWidgets('a clip is megabytes and a still is kilobytes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(const MediaLibraryView(bundle: _bundle)));
      await tester.pumpAndSettle();

      expect(find.text('File'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('12 MB'), findsOneWidget);
      expect(find.text('240 KB'), findsOneWidget);
      expect(
        find.text('12,000,000'),
        findsNothing,
        reason: 'the raw byte count was the compromise, not the design',
      );
    });

    testWidgets('different files give different figures', (tester) async {
      // The control on the test above: a column rendering a constant would
      // pass it.
      _phone(tester);
      await tester.pumpWidget(
        _host(const MediaLibraryView(bundle: _otherBundle)),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 MB'), findsOneWidget);
      expect(find.text('840 KB'), findsOneWidget);
    });

    testWidgets('the unit reads in Arabic, with Western digits', (
      tester,
    ) async {
      // P0-A11Y-01: the unit is translated, the number never is.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const MediaLibraryView(bundle: _bundle),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12 ميجابايت'), findsOneWidget);
      expect(find.text('240 كيلوبايت'), findsOneWidget);
      expect(find.text('١٢ ميجابايت'), findsNothing);
    });
  });

  group('uploading', () {
    testWidgets('uploading is one tap', (tester) async {
      _phone(tester);
      var uploads = 0;

      await tester.pumpWidget(
        _host(MediaLibraryView(onUpload: () => uploads++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload videos and pictures'));
      await tester.pumpAndSettle();

      expect(uploads, 1);
    });

    testWidgets('the action is offered in a word too', (tester) async {
      _phone(tester);
      var uploads = 0;

      await tester.pumpWidget(
        _host(MediaLibraryView(onUpload: () => uploads++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();

      expect(uploads, 1);
    });

    testWidgets('with no picker behind it, nothing is offered as live', (
      tester,
    ) async {
      // The whole point of the seam. `pubspec.yaml` has no file picker, so an
      // upload control that looked ready would be the lie `id_capture.dart`
      // refuses to ship — and a tap that silently does nothing is how staff
      // conclude the console is broken rather than unfinished.
      _phone(tester);
      var uploads = 0;

      await tester.pumpWidget(
        _host(
          MediaLibraryView(
            picker: const UnavailableMediaPicker(),
            onUpload: () => uploads++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminUnavailableAction), findsOneWidget);

      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload videos and pictures'));
      await tester.pumpAndSettle();

      expect(
        uploads,
        0,
        reason: 'nothing can be picked, so nothing pretends it can',
      );
    });

    testWidgets('the disabled state is visible, not only inert', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const MediaLibraryView(picker: UnavailableMediaPicker())),
      );
      await tester.pumpAndSettle();

      final dimmed = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AdminUnavailableAction),
          matching: find.byType(Opacity),
        ),
      );
      expect(dimmed.opacity, AdminUnavailableAction.disabledOpacity);
    });

    testWidgets('an available picker leaves the upload live', (tester) async {
      _phone(tester);
      var uploads = 0;

      await tester.pumpWidget(
        _host(MediaLibraryView(onUpload: () => uploads++)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminUnavailableAction), findsNothing);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(uploads, 1);
    });
  });

  testWidgets('files linked to nothing lead the list', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const MediaLibraryView(
          bundle: _bundle,
          referenced: {'goblet_squat.mp4'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not linked to anything yet'), findsOneWidget);
    expect(find.text('koshari.jpg'), findsOneWidget);
  });

  testWidgets('a linked file is not reported as unlinked', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const MediaLibraryView(
          bundle: _bundle,
          referenced: {'goblet_squat.mp4', 'koshari.jpg'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not linked to anything yet'), findsNothing);
  });

  testWidgets('an empty bundle claims no files it does not have', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(const MediaLibraryView()));
    await tester.pumpAndSettle();

    expect(find.text('Not linked to anything yet'), findsNothing);
    expect(find.text('koshari.jpg'), findsNothing);
  });

  testWidgets('the unlinked count is Western digits under ar', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const MediaLibraryView(bundle: _bundle),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('٢'), findsNothing);
  });

  testWidgets('it mirrors in Arabic at the largest text size', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const MediaLibraryView(bundle: _bundle),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ارفعي مقاطع وصورًا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it raises no dialog', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(const MediaLibraryView(bundle: _bundle)));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
