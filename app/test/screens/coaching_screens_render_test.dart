// Draws every private coaching screen to a PNG at a real phone size (390x844
// logical px, text scale 1.0, light theme) in English and Arabic, with the real
// fonts and the app theme, so a person can look at each one. A few Arabic shots
// are repeated at text scale 2.0.
//
// Off by default so the normal suite stays fast. To draw them:
//
//   cd app && OWNHUB_COACHING_SHOTS=1 lockf -k /tmp/ownhub-flutter-test.lock \
//     ~/development/flutter/bin/flutter test test/screens/coaching_screens_render_test.dart
//
// PNGs go to .claude/feature-briefs/coaching-shots/{en,ar}/NN-name.png, or to
// OWNHUB_COACHING_SHOTS_DIR when that is set. Any FlutterError on a screen
// (a RenderFlex overflow included) fails that screen's test by name.
@Tags(<String>['qa'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_application_draft.dart';
import 'package:own_hub/app_state/coach_client_notes.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/private_coaching/domain/approved_media.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/portfolio_media.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/application_status_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_flow_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_intro_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_review_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_list_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_home_card.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/from_your_coach_section.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_application_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_data.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_photo.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/media_add_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/package_edit_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/packages_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/portfolio_edit_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/portfolio_media_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/client_detail_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/clients_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/coach_desk_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_image.dart'
    show CoachImageBytes;
import 'package:own_hub/features/private_coaching/presentation/member/coach_labels.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_portfolio_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/find_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/join_coach_sheet.dart'
    show levelLabel;
import 'package:own_hub/features/private_coaching/presentation/plans/schedule_session_sheet.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_meal_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_workout_view.dart';
import 'package:own_hub/features/train/domain/workout_library.dart'
    show AuthoredProgramme;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../features/private_coaching/apply/support/apply_support.dart'
    show MemoryPhotoStore, RecordingRepository, draftApplication, testTools;
import '../features/private_coaching/desk/desk_support.dart' as dk;
import '../features/private_coaching/plans/plans_support.dart' as pl;
import '../features/private_coaching/support/fake_coaching_repository.dart';
import '../helpers/exercise_library_fixture.dart';
import '../qa/round1/font_harness.dart';
import '../store/store_screenshots_test.dart' show encodeOpaquePng;

final bool _enabled = Platform.environment['OWNHUB_COACHING_SHOTS'] == '1';
final String _outDir =
    Platform.environment['OWNHUB_COACHING_SHOTS_DIR'] ??
    '/Users/mahmoudreda/ownhub/.claude/feature-briefs/coaching-shots';

/// Local noon-ish on the day the fixtures share.
final DateTime _now = DateTime(2026, 10, 24, 12, 30);
final DateTime _deskNow = dk.kDeskNow;

late final List<Uint8List> _pictures;

// ---------------------------------------------------------------- plumbing

Future<void> _loadIconFont() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent
          .path;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  await loader.load();
}

/// A soft gradient with a simple figure, so the pictures read as pictures.
Future<Uint8List> _swatch(Color a, Color b) async {
  const size = 240.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, size, size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [a, b]),
  );
  final figure = Paint()..color = const Color(0xB3FFFFFF);
  canvas.drawCircle(const Offset(120, 86), 34, figure);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 130, 100, 130),
      const Radius.circular(40),
    ),
    figure,
  );
  final image = await recorder.endRecording().toImage(240, 240);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

class _Ctx {
  _Ctx(this.tester, this.lang) : l10n = lookupAppL10n(Locale(lang));

  final WidgetTester tester;
  final String lang;
  final AppL10n l10n;
  final List<VoidCallback> _later = <VoidCallback>[];

  bool get ar => lang == 'ar';

  /// The words of one language.
  String t(String en, String arabic) => ar ? arabic : en;

  /// Runs after the screen is taken off the tree.
  void later(VoidCallback f) => _later.add(f);
}

class _Step {
  const _Step(this.file, this.action, {this.pages = 1});

  final String file;
  final Future<void> Function(_Ctx c) action;
  final int pages;
}

class _Shot {
  const _Shot(
    this.file,
    this.build, {
    this.steps = const <_Step>[],
    this.pages = 1,
    this.scale = 1,
    this.langs = const <String>['en', 'ar'],
  });

  final String file;
  final Future<Widget> Function(_Ctx c) build;
  final List<_Step> steps;

  /// How many screens down to draw (the first is the top).
  final int pages;
  final double scale;
  final List<String> langs;
}

Widget _host(Widget child, String lang, double scale) {
  final locale = Locale(lang);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
    home: child,
  );
}

Future<void> _settle(WidgetTester tester) async {
  Future<void> pump() async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
    } catch (_) {
      // A looping animation never settles; the exception check below still
      // sees any real error.
    }
  }

  await pump();
  for (var pass = 0; pass < 2; pass++) {
    final images = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in images) {
        try {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    });
    await pump();
  }
}

Future<void> _write(WidgetTester tester, String lang, String name) async {
  final element = find.byType(MaterialApp).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final file = File('$_outDir/$lang/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(
      encodeOpaquePng(rgba!.buffer.asUint8List(), image.width, image.height),
    );
    image.dispose();
  });
}

/// Moves the first vertical list that can move down by most of a screen.
Future<bool> _pageDown(WidgetTester tester) async {
  for (final e in find.byType(Scrollable).evaluate()) {
    final position = ((e as StatefulElement).state as ScrollableState).position;
    if (position.axis != Axis.vertical) continue;
    if (position.maxScrollExtent <= position.pixels + 1) continue;
    position.jumpTo(
      math.min(
        position.pixels + position.viewportDimension * 0.85,
        position.maxScrollExtent,
      ),
    );
    await _settle(tester);
    return true;
  }
  return false;
}

/// Draws the screen as it stands, then each page further down.
Future<void> _draw(
  WidgetTester tester,
  String lang,
  String name,
  int pages,
) async {
  await _write(tester, lang, name);
  for (var i = 1; i < pages; i++) {
    if (!await _pageDown(tester)) break;
    await _write(tester, lang, '$name-${String.fromCharCode(97 + i)}');
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  const inset = FakeViewPadding(top: 94, bottom: 68);
  tester.view.padding = inset;
  tester.view.viewPadding = inset;
  addTearDown(tester.view.reset);
}

Future<void> _run(
  WidgetTester tester,
  _Shot shot,
  String lang,
  String number,
  List<String> stepNumbers,
) async {
  _phone(tester);
  CoachImageBytes.lookup = (path) async =>
      _pictures[path.hashCode.abs() % _pictures.length];
  addTearDown(CoachImageBytes.reset);
  CoachClientNotes.instance.reset();
  final c = _Ctx(tester, lang);
  final problems = <String>[];

  void check(String name) {
    final error = tester.takeException();
    if (error != null) problems.add('$name: $error');
  }

  final widget = await shot.build(c);
  await tester.pumpWidget(_host(widget, lang, shot.scale));
  await _settle(tester);
  await _draw(tester, lang, '$number-${shot.file}', shot.pages);
  check(shot.file);
  for (var i = 0; i < shot.steps.length; i++) {
    final step = shot.steps[i];
    await step.action(c);
    await _settle(tester);
    await _draw(tester, lang, '${stepNumbers[i]}-${step.file}', step.pages);
    check(step.file);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  for (final f in c._later) {
    f();
  }
  if (problems.isNotEmpty) {
    fail(
      'FlutterError on screen ${shot.file} [$lang]:\n${problems.join('\n')}',
    );
  }
}

// ----------------------------------------------------------------- fixtures

CoachProfile _coach(
  _Ctx c,
  String uid,
  String en,
  String ar, {
  List<String> specialties = const <String>['strength', 'fatLoss'],
  List<String> where = const <String>['home', 'gym'],
  bool accepting = true,
  int clients = 14,
  int? from = 1150,
  bool published = true,
}) => CoachProfile(
  uid: uid,
  displayName: c.t(en, ar),
  headline: c.t('Strength coach for busy women', 'مدربة قوة للستات المشغولة'),
  governorate: 'cairo',
  languages: const <String>['ar', 'en'],
  specialties: specialties,
  trainsWhere: where,
  approach: c.t(
    'I build slow, steady plans around your week, then check in often so '
        'nothing feels like too much.',
    'بعمل خطط هادية وثابتة على مقاس أسبوعك، وبتابع معاكي كتير عشان '
        'مفيش حاجة تبقى تقيلة عليكي.',
  ),
  yearsExperience: 6,
  replyHours: 12,
  badges: const <String>['verifiedCoach'],
  stats: CoachStats(clientsCoached: clients, plansShared: 40, sessionsDone: 90),
  fromPriceEgp: from,
  acceptingClients: accepting,
  published: published,
  certificates: const <PublicCertificate>[
    PublicCertificate(
      title: 'Level 3 Personal Trainer',
      issuer: 'REPs',
      year: 2019,
    ),
    PublicCertificate(
      title: 'Nutrition coaching',
      issuer: 'Precision',
      year: 2021,
    ),
  ],
  testimonials: <PublicTestimonial>[
    PublicTestimonial(
      text: c.t(
        'Very patient and clear. I finally stuck with it.',
        'صبورة وواضحة جدا. أخيرا قدرت أكمل.',
      ),
      from: c.t('Mona', 'منى'),
    ),
  ],
);

CoachPackage _package(
  _Ctx c,
  String id,
  int price, {
  int days = 28,
  bool active = true,
  int sessions = 2,
  String? title,
}) => CoachPackage(
  id: id,
  title: title ?? c.t('Strong in 4 weeks', 'قوية في ٤ أسابيع'),
  description: c.t(
    'A plan made for you, daily chat and live video sessions.',
    'خطة مخصوصة ليكي، شات كل يوم وجلسات فيديو مباشرة.',
  ),
  includes: <String>[
    c.t('Weekly plan', 'خطة أسبوعية'),
    c.t('Daily chat', 'شات يومي'),
    c.t('Live video sessions', 'جلسات فيديو مباشرة'),
  ],
  durationDays: days,
  liveSessionsPerMonth: sessions,
  sessionMinutes: 30,
  checkInsPerWeek: 2,
  priceFinalEgp: price,
  active: active,
);

List<PortfolioMedia> _myMedia(_Ctx c) => <PortfolioMedia>[
  PortfolioMedia(
    id: 'm1',
    kind: MediaKind.transformation,
    status: MediaStatus.approved,
    weeks: 12,
    note: c.t('Three sessions a week.', 'تلات حصص في الأسبوع.'),
    beforePath: 'coach-public/me/t1-before.png',
    afterPath: 'coach-public/me/t1-after.png',
    createdAt: DateTime(2026, 10, 1),
  ),
  PortfolioMedia(
    id: 'm2',
    kind: MediaKind.transformation,
    status: MediaStatus.pending,
    weeks: 8,
    beforePath: 'coach-public/me/t2-before.png',
    afterPath: 'coach-public/me/t2-after.png',
    createdAt: DateTime(2026, 10, 20),
  ),
  PortfolioMedia(
    id: 'm3',
    kind: MediaKind.transformation,
    status: MediaStatus.needsConsent,
    weeks: 16,
    beforePath: 'coach-public/me/t3-before.png',
    afterPath: 'coach-public/me/t3-after.png',
  ),
  PortfolioMedia(
    id: 'm4',
    kind: MediaKind.photo,
    status: MediaStatus.rejected,
    reason: c.t('The picture shows another person.', 'الصورة فيها شخص تاني.'),
    caption: c.t('Group class', 'حصة جماعية'),
    imagePath: 'coach-public/me/p1.png',
  ),
  PortfolioMedia(
    id: 'm5',
    kind: MediaKind.photo,
    status: MediaStatus.approved,
    caption: c.t('At the studio', 'في الاستوديو'),
    imagePath: 'coach-public/me/p2.png',
  ),
  PortfolioMedia(
    id: 'm6',
    kind: MediaKind.feedback,
    status: MediaStatus.approved,
    text: c.t(
      'Sara changed how I train. Very patient.',
      'سارة غيرت طريقة تمريني. صبورة جدا.',
    ),
    from: c.t('Mona', 'منى'),
  ),
  PortfolioMedia(
    id: 'm7',
    kind: MediaKind.feedback,
    status: MediaStatus.pending,
    text: c.t('Clear plans, quick replies.', 'خطط واضحة وردود سريعة.'),
    from: c.t('Nour', 'نور'),
  ),
];

List<ApprovedMedia> _approved(_Ctx c) => <ApprovedMedia>[
  ApprovedMedia(
    id: 'a1',
    kind: MediaKind.transformation,
    weeks: 12,
    note: c.t('Three sessions a week.', 'تلات حصص في الأسبوع.'),
    beforePath: 'coach-public/c2/a1-before.png',
    afterPath: 'coach-public/c2/a1-after.png',
  ),
  ApprovedMedia(
    id: 'a2',
    kind: MediaKind.transformation,
    weeks: 8,
    beforePath: 'coach-public/c2/a2-before.png',
    afterPath: 'coach-public/c2/a2-after.png',
  ),
  ApprovedMedia(
    id: 'a3',
    kind: MediaKind.feedback,
    text: c.t(
      'Very patient and clear. I finally stuck with it.',
      'صبورة وواضحة جدا. أخيرا قدرت أكمل.',
    ),
    from: c.t('Mona', 'منى'),
  ),
  ApprovedMedia(
    id: 'a4',
    kind: MediaKind.feedback,
    text: c.t('Quick replies every day.', 'ردود سريعة كل يوم.'),
    from: c.t('Nour', 'نور'),
  ),
  for (var i = 0; i < 4; i++)
    ApprovedMedia(
      id: 'g$i',
      kind: MediaKind.photo,
      caption: c.t('Session $i', 'حصة $i'),
      imagePath: 'coach-public/c2/g$i.png',
    ),
];

CoachApplication _application(
  ApplicationStatus status, {
  Map<String, String> reasons = const <String, String>{},
  String note = '',
  DateTime? decided,
}) => CoachApplication.fromMap(<String, Object?>{
  ...draftApplication().toMap(),
  'status': status.wire,
  'reasons': reasons,
  'note': note,
  'decidedAt': ?decided?.toIso8601String(),
});

/// The finished application with every photo a local picture in [store].
Future<CoachApplication> _applicationWithPhotos(MemoryPhotoStore store) async {
  final base = draftApplication();
  Future<String> photo(int i) =>
      store.save(_pictures[i % _pictures.length], 'image/png');
  return base.copyWith(
    personal: base.personal.copyWith(photoPath: await photo(0)),
    certificates: <CoachCertificate>[
      CoachCertificate(
        id: 'cert-1',
        title: base.certificates.first.title,
        issuer: base.certificates.first.issuer,
        year: base.certificates.first.year,
        path: await photo(1),
        mime: 'image/png',
      ),
    ],
    transformations: <CoachTransformation>[
      CoachTransformation(
        beforePath: await photo(2),
        afterPath: await photo(3),
        weeks: 12,
        note: 'Twelve weeks.',
        clientConsent: true,
      ),
    ],
  );
}

Future<(CoachApplicationDraft, MemoryPhotoStore)> _draft(
  _Ctx c, {
  int? step,
}) async {
  final store = MemoryPhotoStore();
  final draft = CoachApplicationDraft.forTest()..store = store;
  final app = await c.tester.runAsync(() => _applicationWithPhotos(store));
  draft.update(app!, step: step);
  return (draft, store);
}

PrivateCoachingState _coachState(_Ctx c, FakeCoachingRepository repo) {
  final state = PrivateCoachingState.forTest();
  state.start(repo, isCoach: true, now: () => _deskNow);
  c.later(state.stop);
  return state;
}

Future<CoachSpaceData> _spaceData(_Ctx c, FakeCoachingRepository repo) async {
  final data = CoachSpaceData(repo);
  c.later(data.dispose);
  await c.tester.pump();
  return data;
}

/// A coach with a published page, two packages and a gallery.
FakeCoachingRepository _coachRepo(_Ctx c, {bool empty = false}) {
  final repo = FakeCoachingRepository(uid: 'me');
  repo.coaches.value = <CoachProfile>[
    _coach(c, 'me', 'Coach Sara', 'كوتش سارة', clients: empty ? 0 : 14),
  ];
  repo.coachPrivate.value = const CoachPrivateSummary(
    fullName: 'Sara Hassan Ali',
    payoutRail: 'instapay',
    payoutAccount: 'sara.h@instapay',
    payoutHolderName: 'Sara Hassan Ali',
    owedEgp: 3450,
    paidEgp: 9200,
  );
  repo.application.value = _application(ApplicationStatus.approved);
  if (!empty) {
    repo.packages['me'] = Feed<List<CoachPackage>>(<CoachPackage>[
      _package(c, 'p1', 1150),
      _package(
        c,
        'p2',
        2100,
        days: 56,
        sessions: 4,
        title: c.t('Eight week reset', 'ريست ٨ أسابيع'),
      ),
      _package(c, 'p3', 900, active: false, title: c.t('Starter', 'بداية')),
    ]);
    repo.packagePrices.value = const <String, int>{
      'p1': 1000,
      'p2': 1850,
      'p3': 780,
    };
    repo.myMedia.value = _myMedia(c);
  }
  return repo;
}

// ---------------------------------------------------------------- desk data

DateTime _ago(int days, [int hours = 0]) =>
    _deskNow.subtract(Duration(days: days, hours: hours));

const List<(String, String)> _names = <(String, String)>[
  ('Mona Ali', 'منى علي'),
  ('Nour Hassan', 'نور حسن'),
  ('Dina Samir', 'دينا سمير'),
  ('Salma Adel', 'سلمى عادل'),
  ('Hana Mostafa', 'هنا مصطفى'),
  ('Yasmine Fathy', 'ياسمين فتحي'),
  ('Rana Khaled', 'رنا خالد'),
  ('Laila Ahmed', 'ليلى أحمد'),
  ('Farida Magdy', 'فريدة مجدي'),
  ('Mariam Tarek', 'مريم طارق'),
  ('Jana Ibrahim', 'جنى إبراهيم'),
  ('Aya Hesham', 'آية هشام'),
];

/// A coach's desk: [clients] active women, a few chats, requests and a
/// session today.
FakeCoachingRepository _deskRepo(_Ctx c, {int clients = 12}) {
  final repo = FakeCoachingRepository(uid: 'me');
  final subs = <Subscription>[
    dk.deskSub(
      'r1',
      status: SubscriptionStatus.requested,
      name: c.t('Salma Adel', 'سلمى عادل'),
      createdAt: _ago(1),
      intake: dk.deskIntake(health: true, ack: true),
    ),
    dk.deskSub(
      'r2',
      status: SubscriptionStatus.requested,
      name: c.t('Farida Magdy', 'فريدة مجدي'),
      createdAt: _ago(0, 3),
      intake: dk.deskIntake(),
    ),
  ];
  final rels = <Relationship>[];
  for (var i = 0; i < clients; i++) {
    final name = c.ar ? _names[i % 12].$2 : _names[i % 12].$1;
    final id = 'c$i';
    subs.add(
      dk.deskSub(
        id,
        name: name,
        startsAt: _ago(3 + i * 2),
        endsAt: i == 3 || i == 9
            ? _deskNow.add(Duration(days: 3 + i % 2))
            : _deskNow.add(Duration(days: 12 + i * 2)),
        nextSessionAt: i == 0 ? _deskNow.add(const Duration(hours: 3)) : null,
        intake: i == 1 ? dk.deskIntake(health: true, ack: true) : null,
      ),
    );
    if (i == 11) continue;
    rels.add(
      dk.deskRel(
        'u$id',
        lastAt: i == 2 || i == 5 ? _ago(11) : _ago(0, i + 1),
        sender: i == 2 || i == 5 ? 'me' : null,
        unread: i == 1 || i == 4 ? 1 + i % 3 : 0,
        text: c.t(
          i.isEven ? 'Done today!' : 'See you Thursday',
          i.isEven ? 'خلصت النهاردة!' : 'نتقابل الخميس',
        ),
      ),
    );
  }
  repo.coachSubs.value = subs;
  repo.relationships.value = rels;
  return repo;
}

// -------------------------------------------------------------------- chats

ChatMessage _msg(
  String id,
  String sender,
  DateTime at, {
  MessageType type = MessageType.text,
  String text = '',
  bool hidden = false,
  bool pending = false,
  String? planName,
  String? sessionId,
  DateTime? startsAt,
  int? minutes,
  String? recipeId,
}) => ChatMessage(
  id: id,
  senderUid: sender,
  type: type,
  text: text,
  createdAt: pending ? null : at,
  pending: pending,
  hidden: hidden,
  planName: planName,
  sessionId: sessionId,
  startsAt: startsAt,
  minutes: minutes,
  recipeId: recipeId,
);

Future<Widget> _thread(_Ctx c) async {
  final repo = FakeCoachingRepository(uid: 'me');
  const rel = 'c1__me';
  final yesterday = DateTime(2026, 10, 23, 18, 40);
  repo.messages[rel] = Feed<List<ChatMessage>>(<ChatMessage>[
    _msg(
      'm1',
      'c1',
      yesterday,
      text: c.t(
        'Welcome Mona! Here is how we start this week.',
        'أهلا يا منى! ده اللي هنبدأ بيه الأسبوع ده.',
      ),
    ),
    _msg(
      'm2',
      'me',
      yesterday.add(const Duration(minutes: 12)),
      text: c.t('Thank you, I am excited!', 'شكرا، متحمسة جدا!'),
    ),
    _msg(
      'm3',
      'c1',
      yesterday.add(const Duration(minutes: 30)),
      type: MessageType.workoutPlan,
      planName: c.t('Strength week 1', 'قوة الأسبوع الأول'),
    ),
    _msg(
      'm4',
      'c1',
      DateTime(2026, 10, 24, 9, 5),
      type: MessageType.mealPlan,
      planName: c.t('A simple week of meals', 'أسبوع وجبات بسيط'),
    ),
    _msg(
      'm5',
      'c1',
      DateTime(2026, 10, 24, 9, 6),
      type: MessageType.recipe,
      recipeId: 'koshari',
    ),
    _msg(
      'm6',
      'c1',
      DateTime(2026, 10, 24, 10),
      type: MessageType.session,
      sessionId: 's1',
      startsAt: DateTime(2026, 10, 25, 18),
      minutes: 45,
    ),
    _msg(
      'm7',
      'me',
      DateTime(2026, 10, 24, 12, 10),
      text: c.t('Did the first workout this morning.', 'عملت أول تمرين الصبح.'),
    ),
    _msg(
      'm8',
      'c1',
      DateTime(2026, 10, 24, 12, 20),
      text: c.t('That is wonderful, well done.', 'جميل جدا، برافو عليكي.'),
    ),
    _msg(
      'm9',
      'me',
      DateTime(2026, 10, 24, 12, 25),
      text: c.t('Call me on 01012345678', 'كلميني على 01012345678'),
      hidden: true,
    ),
    _msg(
      'm10',
      'me',
      _now,
      text: c.t('Can we move the session?', 'ينفع نأجل الجلسة؟'),
      pending: true,
    ),
  ]);
  repo.otherReadAt[rel] = Feed<DateTime?>(DateTime(2026, 10, 24, 12, 15));
  repo.sessions['sub1'] = Feed<List<LiveSession>>(<LiveSession>[
    LiveSession(
      id: 's1',
      status: SessionStatus.proposed,
      startsAt: DateTime(2026, 10, 25, 18),
      minutes: 45,
      link: 'https://meet.google.com/abc-defg-hij',
      proposedBy: 'c1',
    ),
  ]);
  return ChatThreadView(
    repository: repo,
    relId: rel,
    myUid: 'me',
    person: ChatPerson(
      uid: 'c1',
      name: c.t('Coach Sara', 'كوتش سارة'),
      subtitle: c.t('Your coach', 'مدربتك'),
    ),
    otherIsCoach: true,
    subId: 'sub1',
    recipeTitleOf: (_) => c.t('Koshari bowl', 'طبق كشري'),
    now: () => _now,
  );
}

// ----------------------------------------------------------- client screens

CoachPlan _workoutPlan(_Ctx c) => CoachPlan(
  id: 'w1',
  kind: PlanKind.workout,
  coachUid: 'coach1',
  coachName: c.t('Sara', 'سارة'),
  name: c.t('Strength week 1', 'قوة الأسبوع الأول'),
  workout: pl.workoutPlan(),
  publishedAt: DateTime.utc(2026, 10, 24, 6),
);

CoachPlan _mealPlan(_Ctx c) => CoachPlan(
  id: 'm1',
  kind: PlanKind.meal,
  coachUid: 'coach1',
  coachName: c.t('Sara', 'سارة'),
  name: c.t('A simple week of meals', 'أسبوع وجبات بسيط'),
  meal: pl.mealBody(),
  publishedAt: DateTime.utc(2026, 10, 24, 6),
);

Widget _scrolled(Widget child) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

Future<void> _tapText(_Ctx c, String text, {int at = 0}) async {
  final finder = find.text(text);
  await c.tester.ensureVisible(finder.at(at));
  await c.tester.pump();
  await c.tester.tap(finder.at(at));
  await c.tester.pump();
}

// -------------------------------------------------------------- the screens

final List<_Shot> _shots = <_Shot>[
  // Apply
  _Shot(
    'apply-intro',
    (c) async =>
        ApplyIntroView(isVerifiedWoman: true, hasDraft: false, onStart: () {}),
  ),
  for (final s in const <(int, String)>[
    (1, 'personal'),
    (2, 'education'),
    (3, 'certificates'),
    (4, 'specialties'),
    (5, 'feedback'),
    (6, 'transformations'),
    (7, 'approach'),
    (8, 'terms'),
  ])
    _Shot('apply-step-${s.$1}-${s.$2}', (c) async {
      final (draft, store) = await _draft(c, step: s.$1);
      return ApplyFlowView(
        draft: draft,
        tools: testTools(store),
        initialStep: s.$1,
        now: _now,
      );
    }, pages: 2),
  _Shot('apply-review', (c) async {
    final (draft, _) = await _draft(c);
    return ApplyReviewView(
      draft: draft,
      repository: RecordingRepository(),
      now: _now,
    );
  }, pages: 3),
  _Shot(
    'status-submitted',
    (c) async => ApplicationStatusView(
      application: _application(ApplicationStatus.submitted),
      now: _now,
    ),
  ),
  _Shot(
    'status-needs-changes',
    (c) async => ApplicationStatusView(
      application: _application(
        ApplicationStatus.needsChanges,
        reasons: const <String, String>{
          'personal': 'unclear',
          'certificates': 'unverifiable',
          'payout': 'missing',
          'education': 'other',
        },
        note: c.t(
          'Please add a clearer photo of your face.',
          'من فضلك ضيفي صورة أوضح لوشك.',
        ),
      ),
      now: _now,
      onEditSection: (_) {},
      onSendAgain: () {},
    ),
    pages: 2,
  ),
  _Shot(
    'status-approved',
    (c) async => ApplicationStatusView(
      application: _application(
        ApplicationStatus.approved,
        decided: DateTime(2026, 10, 20, 12),
      ),
      now: _now,
      onOpenCoachSpace: () {},
    ),
  ),
  _Shot(
    'status-rejected',
    (c) async => ApplicationStatusView(
      application: _application(
        ApplicationStatus.rejected,
        decided: DateTime(2026, 10, 20, 12),
      ),
      now: _now,
    ),
  ),

  // Coach space
  _Shot('coach-space', (c) async {
    final repo = _coachRepo(c);
    final state = _coachState(c, _deskRepo(c));
    return CoachSpaceView(
      repository: repo,
      coaching: state,
      onPreviewPortfolio: (_) {},
      onOpenDashboard: () {},
      onOpenChats: () {},
    );
  }, pages: 2),
  _Shot('coach-application', (c) async {
    final repo = _coachRepo(c);
    return CoachApplicationView(data: await _spaceData(c, repo));
  }, pages: 2),
  _Shot('portfolio-edit', (c) async {
    final repo = _coachRepo(c);
    return PortfolioEditView(data: await _spaceData(c, repo));
  }, pages: 2),
  _Shot('packages', (c) async {
    final repo = _coachRepo(c);
    return PackagesView(data: await _spaceData(c, repo));
  }, pages: 2),
  _Shot('package-edit', (c) async {
    final repo = _coachRepo(c);
    final data = await _spaceData(c, repo);
    return PackageEditView(data: data, package: _package(c, 'p1', 1150));
  }, pages: 3),
  _Shot('package-new', (c) async {
    final repo = _coachRepo(c);
    return PackageEditView(data: await _spaceData(c, repo));
  }, pages: 2),
  _Shot('photos-and-results', (c) async {
    final repo = _coachRepo(c);
    return PortfolioMediaView(data: await _spaceData(c, repo));
  }, pages: 3),
  _Shot(
    'add-transformation',
    (c) async {
      final repo = _coachRepo(c);
      final data = await _spaceData(c, repo);
      return MediaAddView(
        data: data,
        kind: MediaKind.transformation,
        imageChooser: (_) async =>
            CoachImage(_pictures[2], contentType: 'image/png'),
      );
    },
    steps: <_Step>[
      _Step('add-transformation-filled', (c) async {
        await _tapText(c, c.l10n.chooseAPhoto);
        await _tapText(c, c.l10n.chooseAPhoto);
        await c.tester.enterText(
          find.byType(TextField).first,
          c.t('Three sessions a week.', 'تلات حصص في الأسبوع.'),
        );
        await c.tester.pump();
      }, pages: 2),
    ],
  ),

  // Coach desk
  _Shot('desk-today', (c) async {
    final state = _coachState(c, _deskRepo(c));
    await c.tester.pump();
    return CoachDeskView(state: state, now: () => _deskNow);
  }, pages: 3),
  _Shot('clients-list', (c) async {
    final state = _coachState(c, _deskRepo(c));
    await c.tester.pump();
    return ClientsView(state: state, now: () => _deskNow);
  }, pages: 3),
  _Shot('client-detail', (c) async {
    final repo = _deskRepo(c);
    repo.messages[dk.relOf('uc1')] = Feed<List<ChatMessage>>(<ChatMessage>[
      ChatMessage(
        id: 'p1',
        senderUid: 'me',
        type: MessageType.workoutPlan,
        planId: 'p1',
        planName: c.t('Strength week 1', 'قوة الأسبوع الأول'),
        createdAt: _ago(1),
      ),
    ]);
    repo.sessions['c1'] = Feed<List<LiveSession>>(<LiveSession>[
      LiveSession(
        id: 's1',
        status: SessionStatus.confirmed,
        startsAt: _deskNow.add(const Duration(days: 2, hours: 5)),
        minutes: 45,
        link: 'https://meet.google.com/abc-defg-hij',
      ),
    ]);
    final state = _coachState(c, repo);
    await c.tester.pump();
    return ClientDetailView(
      subId: 'c1',
      state: state,
      now: () => _deskNow,
      onOpenChat: (_) {},
      onShareWorkout: (_) {},
      onShareMeal: (_) {},
      onScheduleSession: (_) {},
    );
  }, pages: 3),

  // Chat
  _Shot('chat-list', (c) async {
    Relationship rel(String id, String who, String text, int min, int unread) =>
        Relationship(
          id: '${who}__me',
          coachUid: who,
          clientUid: 'me',
          status: RelationshipStatus.active,
          chatOpen: true,
          activeSubId: 'sub$id',
          lastMessageAt: _now.subtract(Duration(minutes: min)),
          lastMessage: LastMessage(
            text: text,
            senderUid: who,
            at: _now.subtract(Duration(minutes: min)),
          ),
          unreadFor: unread > 0 ? <String, int>{'me': unread} : const {},
        );
    final names = <String, String>{
      'c1': c.t('Coach Sara', 'كوتش سارة'),
      'c2': c.t('Coach Amal', 'كوتش أمل'),
      'c3': c.t('Coach Dina', 'كوتش دينا'),
    };
    return ChatListView(
      relationships: <Relationship>[
        rel('1', 'c1', c.t('Well done today!', 'برافو عليكي النهاردة!'), 12, 2),
        rel('2', 'c2', c.t('See you Thursday', 'نتقابل الخميس'), 60 * 26, 0),
        rel(
          '3',
          'c3',
          c.t('Sent you a meal plan', 'بعتلك خطة أكل'),
          60 * 24 * 5,
          0,
        ),
      ],
      myUid: 'me',
      personOf: (uid) => ChatPerson(uid: uid, name: names[uid] ?? uid),
      onOpen: (_) {},
      now: () => _now,
    );
  }),
  _Shot('chat-thread', _thread, pages: 2),

  // Plans
  _Shot(
    'share-workout',
    (c) async {
      final repo = FakeCoachingRepository(uid: 'coach1');
      return ShareWorkoutView(
        repository: repo,
        subscription: pl.sub(),
        clientName: c.t('Mai', 'مي'),
        splits: <AuthoredProgramme>[pl.split()],
      );
    },
    steps: <_Step>[
      _Step('share-workout-split-chosen', (c) async {
        await c.tester.tap(find.byKey(const ValueKey('workout-split-0')));
        await c.tester.pump();
      }, pages: 2),
    ],
  ),
  _Shot('share-meal-plan', (c) async {
    final repo = FakeCoachingRepository(uid: 'coach1');
    return ShareMealPlanView(
      repository: repo,
      subscription: pl.sub(allergies: <String>['Sesame']),
      catalog: pl.catalog(),
      clientName: c.t('Mai', 'مي'),
      existing: CoachPlan(
        id: 'm1',
        kind: PlanKind.meal,
        name: c.t('Week one', 'الأسبوع الأول'),
        meal: pl.mealBody(),
      ),
    );
  }, pages: 2),
  _Shot('schedule-session-sheet', (c) async {
    final repo = FakeCoachingRepository(uid: 'coach1');
    return _SheetHost(
      open: (context) => showScheduleSessionSheet(
        context: context,
        repository: repo,
        subscription: pl.sub(),
        sessions: const <LiveSession>[],
        clientName: c.t('Mai', 'مي'),
        now: () => DateTime.utc(2026, 10, 24, 12),
      ),
    );
  }),

  // Member side
  _Shot(
    'find-coach-quiz',
    (c) async {
      final repo = FakeCoachingRepository();
      repo.coaches.value = <CoachProfile>[
        _coach(c, 'c2', 'Coach Amal', 'كوتش أمل', from: 1200),
        _coach(
          c,
          'c3',
          'Coach Basma',
          'كوتش بسمة',
          specialties: const <String>['beginners', 'mobility'],
          where: const <String>['gym'],
          from: 1800,
          clients: 3,
        ),
        _coach(
          c,
          'c4',
          'Coach Dina',
          'كوتش دينا',
          specialties: const <String>['muscleGain'],
          where: const <String>['home'],
          from: 1300,
          clients: 40,
        ),
        _coach(
          c,
          'c5',
          'Coach Zeina',
          'كوتش زينة',
          specialties: const <String>['strength'],
          where: const <String>['home', 'gym'],
          from: 2600,
          accepting: false,
        ),
      ];
      for (final u in <String>['c2', 'c3', 'c4', 'c5']) {
        repo.packages[u] = Feed<List<CoachPackage>>(<CoachPackage>[
          _package(c, '${u}a', u == 'c3' ? 1800 : 1200),
        ]);
      }
      return FindCoachView(repository: repo);
    },
    steps: <_Step>[
      _Step('find-coach-results', (c) async {
        await _tapText(c, goalLabel(c.l10n, 'stronger'));
        await _tapText(c, placeLabel(c.l10n, 'home'));
        await _tapText(c, budgetLabel(c.l10n, 'under1500'));
      }, pages: 2),
    ],
    pages: 1,
  ),
  _Shot(
    'coach-portfolio',
    (c) async {
      final repo = FakeCoachingRepository();
      return CoachPortfolioView(
        coach: _coach(c, 'c2', 'Coach Amal', 'كوتش أمل'),
        packages: <CoachPackage>[
          _package(c, 'a', 2000),
          _package(
            c,
            'b',
            1150,
            sessions: 0,
            title: c.t('Chat only', 'شات فقط'),
          ),
        ],
        media: _approved(c),
        repository: repo,
      );
    },
    pages: 4,
    steps: <_Step>[
      _Step('ask-to-join', (c) async {
        // Back to the top, then open the sheet and answer every question.
        final list = find
            .byType(Scrollable)
            .evaluate()
            .map(
              (e) => ((e as StatefulElement).state as ScrollableState).position,
            );
        for (final p in list) {
          if (p.axis == Axis.vertical) p.jumpTo(0);
        }
        await c.tester.pump();
        await _tapText(c, c.l10n.askToJoin);
        await c.tester.pump(const Duration(milliseconds: 400));
        await _tapText(c, goalLabel(c.l10n, 'stronger'));
        await _tapText(c, levelLabel(c.l10n, 'beginner'));
        await _tapText(c, '3');
        await _tapText(c, placeLabel(c.l10n, 'home'));
        for (var i = 0; i < CoachingEnums.healthQuestions.length; i++) {
          await _tapText(c, c.l10n.no, at: i);
        }
      }, pages: 3),
      _Step('request-sent', (c) async {
        final boxes = find.byType(CheckboxListTile);
        final count = c.tester.widgetList(boxes).length;
        for (var i = count - 2; i < count; i++) {
          await c.tester.ensureVisible(boxes.at(i));
          await c.tester.pump();
          await c.tester.tap(boxes.at(i));
          await c.tester.pump();
        }
        await _tapText(c, c.l10n.sendRequest);
      }),
    ],
  ),
  _Shot('coach-portfolio-preview', (c) async {
    return CoachPortfolioView(
      coach: _coach(c, 'me', 'Coach Sara', 'كوتش سارة'),
      packages: <CoachPackage>[_package(c, 'a', 1150)],
      media: _approved(c),
      preview: true,
      repository: FakeCoachingRepository(uid: 'me'),
    );
  }, pages: 2),
  _Shot('my-coach', (c) async {
    final repo = FakeCoachingRepository(uid: 'client1');
    repo.coaches.value = <CoachProfile>[
      _coach(c, 'coach1', 'Coach Sara', 'كوتش سارة'),
    ];
    repo.sessions['sub1'] = Feed<List<LiveSession>>(<LiveSession>[
      LiveSession(
        id: 'p',
        status: SessionStatus.proposed,
        startsAt: DateTime.utc(2026, 10, 28, 15),
        minutes: 45,
        link: 'https://meet.google.com/abc-defg-hij',
        proposedBy: 'coach1',
      ),
      LiveSession(
        id: 'c',
        status: SessionStatus.confirmed,
        startsAt: DateTime.utc(2026, 10, 24, 10),
        minutes: 30,
        link: 'https://meet.google.com/abc-defg-hij',
      ),
    ]);
    return MyCoachView(
      repository: repo,
      subscription: pl.sub(),
      plans: <CoachPlan>[_workoutPlan(c), _mealPlan(c)],
      hasUnread: true,
      now: () => DateTime.utc(2026, 10, 24, 12),
      onMessage: () {},
      onOpenPlan: (_) {},
      onBlock: () {},
      onJoin: (_) {},
    );
  }, pages: 3),
  _Shot('coach-plan-workout', (c) async {
    return CoachPlanView(
      plan: _workoutPlan(c),
      exercises: sampleExerciseLibrary().exercises,
      onStartWorkout: (_) {},
    );
  }, pages: 3),
  _Shot('coach-plan-meal', (c) async {
    return CoachPlanView(
      plan: _mealPlan(c),
      catalog: pl.catalog(),
      constraints: const DietaryConstraints(allergies: <String>{'sesame'}),
      onOpenRecipe: (_) {},
      onLog: (_, _) {},
    );
  }, pages: 3),
  _Shot('home-coach-card', (c) async {
    return _scrolled(
      CoachHomeCard(
        workout: _workoutPlan(c),
        nextSession: LiveSession(
          id: 'c',
          status: SessionStatus.confirmed,
          startsAt: DateTime.utc(2026, 10, 28, 15),
        ),
        hasUnread: true,
        doneThisWeek: 1,
        onStartWorkout: (_, _) {},
      ),
    );
  }),
  _Shot('eat-from-your-coach', (c) async {
    return _scrolled(
      FromYourCoachSection(
        plan: _mealPlan(c),
        now: DateTime.utc(2026, 10, 24, 12),
        catalog: pl.catalog(),
        constraints: const DietaryConstraints(allergies: <String>{'sesame'}),
        onLog: (_, _) {},
        onOpenRecipe: (_) {},
        onOpenPlan: () {},
      ),
    );
  }, pages: 2),

  // Empty states
  _Shot('empty-coach-space', (c) async {
    final repo = _coachRepo(c, empty: true);
    return CoachSpaceView(
      repository: repo,
      coaching: _coachState(c, FakeCoachingRepository(uid: 'me')),
      onPreviewPortfolio: (_) {},
      onOpenDashboard: () {},
      onOpenChats: () {},
    );
  }, pages: 2),
  _Shot('empty-packages', (c) async {
    return PackagesView(data: await _spaceData(c, _coachRepo(c, empty: true)));
  }),
  _Shot('empty-photos-and-results', (c) async {
    return PortfolioMediaView(
      data: await _spaceData(c, _coachRepo(c, empty: true)),
    );
  }),
  _Shot('empty-desk-today', (c) async {
    final state = _coachState(c, FakeCoachingRepository(uid: 'me'));
    await c.tester.pump();
    return CoachDeskView(state: state, now: () => _deskNow);
  }),
  _Shot('empty-clients', (c) async {
    final state = _coachState(c, FakeCoachingRepository(uid: 'me'));
    await c.tester.pump();
    return ClientsView(state: state, now: () => _deskNow);
  }),
  _Shot('empty-chat-list', (c) async {
    return ChatListView(
      relationships: const <Relationship>[],
      myUid: 'me',
      personOf: (uid) => ChatPerson(uid: uid, name: uid),
      onOpen: (_) {},
      now: () => _now,
    );
  }),
  _Shot('empty-find-coach', (c) async {
    return FindCoachView(repository: FakeCoachingRepository());
  }),
  _Shot('empty-my-coach', (c) async => NoCoachView(onFind: () {})),

  // Text scale 2.0, Arabic only
  _Shot(
    'chat-thread-scale2',
    _thread,
    scale: 2,
    pages: 3,
    langs: const <String>['ar'],
  ),
  _Shot(
    'desk-today-scale2',
    (c) async {
      final state = _coachState(c, _deskRepo(c));
      await c.tester.pump();
      return CoachDeskView(state: state, now: () => _deskNow);
    },
    scale: 2,
    pages: 3,
    langs: const <String>['ar'],
  ),
  _Shot(
    'coach-portfolio-scale2',
    (c) async {
      return CoachPortfolioView(
        coach: _coach(c, 'c2', 'Coach Amal', 'كوتش أمل'),
        packages: <CoachPackage>[_package(c, 'a', 2000)],
        media: _approved(c),
        repository: FakeCoachingRepository(),
      );
    },
    scale: 2,
    pages: 4,
    langs: const <String>['ar'],
  ),
];

/// A blank page that opens a sheet over itself once it is up.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.open});

  final Future<void> Function(BuildContext context) open;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await _loadIconFont();
    _pictures = <Uint8List>[
      await _swatch(const Color(0xFFF4BEBB), const Color(0xFF1A5D74)),
      await _swatch(const Color(0xFFE8A6A2), const Color(0xFF3B7C92)),
      await _swatch(const Color(0xFF1A5D74), const Color(0xFFF4BEBB)),
      await _swatch(const Color(0xFFD9B8A0), const Color(0xFF2F6B7F)),
      await _swatch(const Color(0xFFF0D2CF), const Color(0xFF527F8F)),
    ];
  });

  // Numbers follow the list: a screen, then the steps drawn from it.
  var n = 0;
  String two(int v) => v.toString().padLeft(2, '0');
  for (final shot in _shots) {
    final number = two(++n);
    final steps = <String>[];
    for (final _ in shot.steps) {
      steps.add(two(++n));
    }
    for (final lang in shot.langs) {
      testWidgets(
        'coaching screen ${shot.file} [$lang]',
        (tester) async {
          // Shadows on for the picture; the test binding checks the switch is
          // back to its default when each test ends.
          debugDisableShadows = false;
          try {
            await _run(tester, shot, lang, number, steps);
          } finally {
            debugDisableShadows = true;
          }
        },
        skip: !_enabled,
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
