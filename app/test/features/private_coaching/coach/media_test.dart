import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/portfolio_media.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_photo.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_image.dart'
    show CoachImageBytes;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/theme/app_tokens.dart';

import 'coach_fake.dart';
import '../support/fixtures.dart';

Widget _host(Widget child, Locale locale, double scale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: child,
);

Future<CoachImage?> _chooser(BuildContext _) async =>
    CoachImage(Uint8List.fromList([1, 2, 3]));

Future<CoachRepo> _open(
  WidgetTester tester, {
  List<PortfolioMedia> media = const [],
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  final repo = CoachRepo()
    ..coaches.value = [coach('me', 'Coach Sara')]
    ..media.value = media;
  tester.view.physicalSize = const Size(390, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _host(
      CoachSpaceView(repository: repo, imageChooser: _chooser),
      locale,
      scale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.photo_library_outlined));
  await tester.pumpAndSettle();
  return repo;
}

PortfolioMedia _m(
  String id,
  MediaKind kind, {
  MediaStatus status = MediaStatus.pending,
  String reason = '',
  bool needsConsent = false,
}) => PortfolioMedia(
  id: id,
  kind: kind,
  status: needsConsent ? MediaStatus.needsConsent : status,
  reason: reason,
  weeks: 8,
  from: 'Mona',
  text: 'She changed my week.',
);

void main() {
  group('MediaDraft', () {
    test('a transformation needs both photos, weeks and the tick', () {
      const ok = MediaDraft.transformation(
        beforePath: 'a',
        afterPath: 'b',
        consentPath: 'c',
        weeks: 8,
        clientConsentPublic: true,
      );
      expect(ok.problems(), isEmpty);
      expect(ok.toRequest(), {
        'kind': 'transformation',
        'beforePath': 'a',
        'afterPath': 'b',
        'consentPath': 'c',
        'weeks': 8,
        'clientConsentPublic': true,
      });
      const noTick = MediaDraft.transformation(
        beforePath: 'a',
        afterPath: 'b',
        consentPath: 'c',
        weeks: 8,
        clientConsentPublic: false,
      );
      expect(noTick.problems(), ['clientConsentPublic']);
      const noRelease = MediaDraft.transformation(
        beforePath: 'a',
        afterPath: 'b',
        consentPath: '',
        weeks: 8,
        clientConsentPublic: true,
      );
      expect(noRelease.problems(), ['consentPath']);
    });

    test('feedback and photo requests carry the server field names', () {
      expect(
        const MediaDraft.feedback(
          text: 'She changed my whole week.',
          from: 'Mona',
          imagePath: 'p',
        ).toRequest(),
        {
          'kind': 'feedback',
          'text': 'She changed my whole week.',
          'from': 'Mona',
          'imagePath': 'p',
        },
      );
      expect(const MediaDraft.photo(path: 'g', caption: 'Me').toRequest(), {
        'kind': 'photo',
        'path': 'g',
        'caption': 'Me',
      });
      expect(const MediaDraft.feedback(text: 'short', from: '').problems(), [
        'text',
        'from',
      ]);
    });

    test('a document parses; an unknown kind does not', () {
      expect(PortfolioMedia.fromMap('x', {'kind': 'poster'}), isNull);
      expect(
        PortfolioMedia.fromMap('y', {
          'kind': 'transformation',
          'status': 'needsConsent',
        })!.needsConsent,
        isTrue,
      );
      final m = PortfolioMedia.fromMap('x', {
        'kind': 'transformation',
        'status': 'rejected',
        'reason': 'unclear',
        'weeks': 6,
      })!;
      expect(m.status, MediaStatus.rejected);
      expect(m.reason, 'unclear');
    });
  });

  group('Photos and results', () {
    testWidgets('lists items with their status words', (tester) async {
      await _open(
        tester,
        media: [
          _m('1', MediaKind.transformation),
          _m('2', MediaKind.feedback, status: MediaStatus.approved),
          _m(
            '3',
            MediaKind.transformation,
            status: MediaStatus.rejected,
            reason: 'unclear',
          ),
          _m('4', MediaKind.transformation, needsConsent: true),
        ],
      );
      expect(find.text("Waiting for Own Hub's check"), findsOneWidget);
      expect(find.text('Shown on your portfolio'), findsOneWidget);
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('The photo was not clear enough.'), findsOneWidget);
      expect(find.text("Needs your client's consent"), findsOneWidget);
    });

    testWidgets('confirming consent calls the server for that item', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        media: [_m('4', MediaKind.transformation, needsConsent: true)],
      );
      await tester.tap(find.text('Add her written agreement'));
      await tester.pumpAndSettle();
      expect(repo.uploads, ['transformations:image/jpeg']);
      expect(repo.calls.last.$1, 'confirmMediaConsent');
      expect(repo.calls.last.$2, {
        'mediaId': '4',
        'consentPath': 'coach-docs/me/transformations/f1.jpg',
      });
    });

    testWidgets('remove asks first, then removes', (tester) async {
      final repo = await _open(tester, media: [_m('1', MediaKind.feedback)]);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(repo.callNames, isNot(contains('removePortfolioMedia')));
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(repo.calls.last.$1, 'removePortfolioMedia');
      expect(repo.calls.last.$2, {'mediaId': '1'});
    });

    testWidgets('at 30 items nothing more can be added', (tester) async {
      await _open(
        tester,
        media: [for (var i = 0; i < 30; i++) _m('$i', MediaKind.feedback)],
      );
      expect(find.text('Add a transformation'), findsNothing);
      expect(
        find.text('You have 30 items. Remove one to add another.'),
        findsOneWidget,
      );
    });

    testWidgets('a transformation uploads three pictures, then sends', (
      tester,
    ) async {
      final repo = await _open(tester);
      await tester.tap(find.text('Add a transformation'));
      await tester.pumpAndSettle();

      const consent =
          'My client agreed in writing that Own Hub members may see these '
          'photos';
      final send = find.widgetWithText(AppButton, 'Send for Own Hub\'s check');
      // Without the client's consent it cannot be sent at all.
      expect(tester.widget<AppButton>(send).onPressed, isNull);
      await tester.tap(find.text(consent));
      await tester.pumpAndSettle();
      // The tick alone is not enough: her written agreement is needed too.
      expect(tester.widget<AppButton>(send).onPressed, isNull);
      expect(
        find.text("A picture of your client's written agreement"),
        findsOneWidget,
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Choose a photo').first);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<AppButton>(send).onPressed, isNotNull);
      await tester.tap(find.text('Send for Own Hub\'s check'));
      await tester.pumpAndSettle();

      expect(repo.uploads, [
        'transformations:image/jpeg',
        'transformations:image/jpeg',
        'transformations:image/jpeg',
      ]);
      final call = repo.calls
          .singleWhere((c) => c.$1 == 'addPortfolioMedia')
          .$2;
      expect(call['kind'], 'transformation');
      expect(call['beforePath'], 'coach-docs/me/transformations/f1.jpg');
      expect(call['afterPath'], 'coach-docs/me/transformations/f2.jpg');
      expect(call['consentPath'], 'coach-docs/me/transformations/f3.jpg');
      expect(call['weeks'], 8);
      expect(call['clientConsentPublic'], isTrue);
      expect(
        find.text('Sent. Own Hub checks every photo before members see it.'),
        findsOneWidget,
      );
    });

    testWidgets('feedback goes to testimonials, a photo to gallery', (
      tester,
    ) async {
      final repo = await _open(tester);
      await tester.tap(find.text('Add feedback'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'She changed my whole week.',
      );
      await tester.enterText(find.byType(TextField).at(1), 'Mona');
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Send for Own Hub's check"));
      await tester.pumpAndSettle();
      expect(repo.uploads.single, 'testimonials:image/jpeg');
      final fb = repo.calls.singleWhere((c) => c.$1 == 'addPortfolioMedia').$2;
      expect(fb['imagePath'], 'coach-docs/me/testimonials/f1.jpg');
      expect(fb['from'], 'Mona');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a photo of you or your work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Send for Own Hub's check"));
      await tester.pumpAndSettle();
      expect(repo.uploads.last, 'gallery:image/jpeg');
      expect(
        repo.calls.where((c) => c.$1 == 'addPortfolioMedia').last.$2['path'],
        'coach-docs/me/gallery/f2.jpg',
      );
    });

    testWidgets('a refusal from the server is said, nothing claims success', (
      tester,
    ) async {
      final repo = await _open(tester);
      repo.failWith['addPortfolioMedia'] = const CoachingFailure(
        CoachingRefusal.unreachable,
      );
      await tester.tap(find.text('Add a photo of you or your work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Send for Own Hub's check"));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'We could not reach Own Hub. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Sent.'), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('${locale.languageCode} at text scale 2.0', (tester) async {
        await _open(
          tester,
          media: [
            _m('1', MediaKind.transformation, needsConsent: true),
            _m('2', MediaKind.feedback),
          ],
          locale: locale,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        for (final label in [
          Icons.compare_outlined,
          Icons.format_quote_outlined,
          Icons.add_a_photo_outlined,
        ]) {
          await tester.tap(find.byIcon(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
        }
      });
    }
  });

  group('the server\'s real fields', () {
    test('a waiting transformation reads her own files and her consent', () {
      final at = DateTime.utc(2026, 10, 20, 9);
      final m = PortfolioMedia.fromMap('t1', {
        'kind': 'transformation',
        'status': 'needsConsent',
        'beforePath': 'coach-docs/c/transformations/b.jpg',
        'afterPath': 'coach-docs/c/transformations/a.jpg',
        'clientConsentPublic': true,
        'consent': {'at': at, 'termsVersion': 1},
      })!;
      expect(m.beforePath, 'coach-docs/c/transformations/b.jpg');
      expect(m.afterPath, 'coach-docs/c/transformations/a.jpg');
      expect(m.beforeFile, m.beforePath);
      expect(m.clientConsentPublic, isTrue);
      expect(m.consentAt, at);
      expect(m.needsConsent, isTrue);
    });

    test('an approved item shows its public copies', () {
      final m = PortfolioMedia.fromMap('p1', {
        'kind': 'photo',
        'status': 'approved',
        'imagePath': null,
        'publicPaths': {'image': 'coach-public/c/media/p1_image.jpg'},
      })!;
      expect(m.imageFile, 'coach-public/c/media/p1_image.jpg');
      expect(m.publicPaths, {'image': 'coach-public/c/media/p1_image.jpg'});
    });

    test('a rejection keeps its reason', () {
      final m = PortfolioMedia.fromMap('x', {
        'kind': 'feedback',
        'status': 'rejected',
        'reason': 'no_consent',
      })!;
      expect(m.reason, 'no_consent');
    });
  });

  group('thumbnails', () {
    final asked = <String>[];
    setUp(() {
      asked.clear();
      CoachImageBytes.reset();
      CoachImageBytes.lookup = (path) async {
        asked.add(path);
        return null;
      };
    });
    tearDown(CoachImageBytes.reset);

    testWidgets('she sees her photos before confirming consent', (
      tester,
    ) async {
      await _open(
        tester,
        media: [
          const PortfolioMedia(
            id: 't1',
            kind: MediaKind.transformation,
            status: MediaStatus.needsConsent,
            weeks: 8,
            beforePath: 'coach-docs/me/transformations/b.jpg',
            afterPath: 'coach-docs/me/transformations/a.jpg',
          ),
          const PortfolioMedia(
            id: 'p1',
            kind: MediaKind.photo,
            status: MediaStatus.approved,
            publicPaths: {'image': 'coach-public/me/media/p1_image.jpg'},
          ),
        ],
      );
      expect(
        asked,
        containsAll(<String>[
          'coach-docs/me/transformations/b.jpg',
          'coach-docs/me/transformations/a.jpg',
          'coach-public/me/media/p1_image.jpg',
        ]),
      );
      expect(find.text('Add her written agreement'), findsOneWidget);
    });

    testWidgets('a member never loads a private file', (tester) async {
      expect(await CoachImageBytes.load('coach-docs/me/a.jpg'), isNull);
      expect(asked, isEmpty);
    });
  });
}
