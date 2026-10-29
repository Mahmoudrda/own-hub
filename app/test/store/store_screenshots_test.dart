// The store screenshot sets, rendered from the real app.
//
// Nine screens in English and nine in Arabic, in three sizes:
//
//   play       1080x1920 (9:16, inside Play's 2:1 rule, promotion-eligible)
//   apple-6.3  1206x2622 (the 6.3" Dynamic Island size Apple now requires)
//   apple-6.9  1320x2868 (the 6.9" size)
//
// 01 is a branded frame with coach Rahma Mohsen: a frame of her own video on
// the app's linen and petrol, laid out here so Flutter shapes the Arabic.
// 02 to 09 are the real app: Home with its one next step, today's session and
// the same session finished, Eat with her usual plates, Rahma's recipes, You,
// a chat with a coach, and the coach's plan on Home. Every PNG is opaque RGB
// with no alpha channel, as App Store Connect requires; the encoder is below,
// so no tool is needed.
//
// It runs the real `OwnHubApp` with the real fonts, the owner's art and the
// shipped feature flags, with ONE change for this harness only:
// `accountRequired` is off, so the product screens open without a verified
// account. Nothing in lib/ is changed by it. Every piece of data on screen is
// put there the way a woman would put it there, by tapping, and none of it is
// a real person's: no phone number, and the only names are Rahma's own on her
// frame and the made-up coach. The coach, her plan and the chat are a
// synthetic fixture behind the fake repository the coaching tests use.
// Shots 10 to 14 show coaching with payments on, as the release ships: Find
// a coach, a coach's profile (live sessions first), My coach with its Pay
// button, the payment instructions and a coach's plan in Train. The payment is
// a fake behind the fake payments repository, with a made-up InstaPay
// address.
//
// In the normal suite it renders every set and fails on any exception or
// overflow, writing nothing. To write the PNGs, give it a folder (docs/ lives
// in the main checkout and is not committed):
//
//   cd app
//   OWNHUB_SCREENSHOTS_DIR=/path/to/docs/release/launch-pack/screenshots \
//     flutter test test/store/store_screenshots_test.dart
//
// which writes {play,apple-6.3,apple-6.9}/{en,ar}/01-rahma.png and so on. The
// Rahma frame reads its photo from OWNHUB_RAHMA_PHOTO, or from
// docs/release/screenshots/rahma/rahma-01.png beside the app folder.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/payments_switch.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/meal_images.dart';
import 'package:own_hub/features/eat/presentation/recipe_labels.dart';
import 'package:own_hub/features/payments/data/payments_hub.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart'
    show StartingProgrammes;
import 'package:own_hub/features/train/domain/my_plan.dart' show MyPlan;
import 'package:own_hub/features/today/presentation/today_cards.dart'
    show weekdayLabel;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/hand_marks.dart';
import 'package:own_hub/ui/hand/tilt_parallax.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/private_coaching/chat/chat_support.dart' show line, rel;
import '../features/private_coaching/support/fake_coaching_repository.dart'
    show FakeCoachingRepository, Feed;
import '../features/private_coaching/support/fixtures.dart' show coach, sub;
import '../features/payments/support/fake_payments_repository.dart'
    show FakePaymentsRepository;
import '../helpers/pause_menu.dart' show finishEarly;
import '../qa/round1/font_harness.dart';

/// One store size: the folder it is written to, its pixels, its density, and
/// the status bar and home indicator insets of the phone it stands for.
class _DeviceSet {
  const _DeviceSet(this.folder, this.physical, this.dpr, this.top, this.bottom);
  final String folder;
  final Size physical;
  final double dpr;
  final double top;
  final double bottom;
}

const List<_DeviceSet> _sets = <_DeviceSet>[
  // A 16:9 Android phone at 2.625x (411x731 points).
  _DeviceSet('play', Size(1080, 1920), 2.625, 24, 0),
  // iPhone 6.3" at 3x (402x874 points).
  _DeviceSet('apple-6.3', Size(1206, 2622), 3, 62, 34),
  // iPhone 6.9" at 3x (440x956 points).
  _DeviceSet('apple-6.9', Size(1320, 2868), 3, 62, 34),
];

final String? _outDir = Platform.environment['OWNHUB_SCREENSHOTS_DIR'];

/// The morning every set is rendered on: a Monday at half past nine, so the
/// two breakfasts below land under Breakfast and Home names the same day in
/// every run, whatever hour the harness is started at.
final DateTime pinnedMorning = DateTime(2026, 10, 12, 9, 30);

Future<void> _loadIconFont() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) {
    throw StateError('MaterialIcons font not found at ${file.path}');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  await loader.load();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// Lets the owner's art decode, then draws it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var pass = 0; pass < 2; pass++) {
    final images = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in images) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pumpAndSettle();
  }
}

Future<void> _open(WidgetTester tester, String id, {Object? arguments}) async {
  _nav(tester).pushNamed(appRoutes[id]!.name, arguments: arguments);
  await _settle(tester);
}

Future<void> _home(WidgetTester tester) async {
  _nav(tester).popUntil((route) => route.isFirst);
  await _settle(tester);
}

Future<void> _shoot(
  WidgetTester tester,
  _DeviceSet set,
  String lang,
  String name,
) async {
  expect(
    tester.takeException(),
    isNull,
    reason: '${set.folder}/$lang/$name threw',
  );
  final dir = _outDir;
  if (dir == null) return;
  final element = find.byType(MaterialApp).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    expect(image.width, set.physical.width.toInt());
    expect(image.height, set.physical.height.toInt());
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final file = File('$dir/${set.folder}/$lang/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(
      encodeOpaquePng(rgba!.buffer.asUint8List(), image.width, image.height),
    );
    image.dispose();
  });
}

/// A PNG with colour type 2 (RGB, 8 bits), so there is no alpha channel for a
/// store to refuse. [rgba] is premultiplied, as `rawRgba` gives it, and any
/// pixel that is not fully opaque is laid over white.
@visibleForTesting
Uint8List encodeOpaquePng(Uint8List rgba, int width, int height) {
  final rowBytes = width * 3 + 1;
  final raw = Uint8List(rowBytes * height);
  var o = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 0; // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final white = 255 - rgba[i + 3];
      raw[o++] = (rgba[i] + white).clamp(0, 255);
      raw[o++] = (rgba[i + 1] + white).clamp(0, 255);
      raw[o++] = (rgba[i + 2] + white).clamp(0, 255);
    }
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // colour type: RGB, no alpha
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder()
    ..add(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typed = <int>[...type.codeUnits, ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(typed)
      ..add((ByteData(4)..setUint32(0, _crc32(typed))).buffer.asUint8List());
  }

  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder(level: 6).convert(raw));
  chunk('IEND', const <int>[]);
  return out.takeBytes();
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

AppL10n _l10n(WidgetTester tester) =>
    AppL10n.of(tester.element(find.byType(Navigator).first));

Future<void> _tapText(WidgetTester tester, String text) async {
  final hit = find.text(text).hitTestable();
  expect(hit, findsWidgets, reason: 'nothing on screen reads "$text"');
  await tester.tap(hit.first);
  await _settle(tester);
}

/// Shoots the screen in both languages from the same state, and leaves it in
/// English, the language the driving taps are written in.
Future<void> _shootBoth(
  WidgetTester tester,
  _DeviceSet set,
  String name,
) async {
  final locale = LocaleScope.of(tester.element(find.byType(MaterialApp)));
  for (final lang in const ['en', 'ar']) {
    locale.value = Locale(lang);
    await _settle(tester);
    await _shoot(tester, set, lang, name);
  }
  locale.value = const Locale('en');
  await _settle(tester);
}

/// Reads Rahma's book off the asset bundle in real time, then hands the
/// finished book to Eat the way the app's own loader does.
Future<void> _loadRecipeBook(WidgetTester tester) async {
  final book = await tester.runAsync(
    () => EatAppState.instance.recipeSync.load(),
  );
  expect(book?.recipes, isNotEmpty);
  EatAppState.instance.ensureRecipeBook(library: _Loaded(book!));
  await tester.pump();
  expect(EatAppState.instance.recipeBook.recipes, isNotEmpty);
}

class _Loaded implements RecipeLibrary {
  _Loaded(this.book);
  final RecipeBook book;
  @override
  Future<RecipeBook> load() => SynchronousFuture(book);
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUpAll(() async {
    await loadAppFonts();
    await _loadIconFont();
    // No accelerometer plugin under `flutter test`: the art stays still.
    TiltParallax.source = () => const Stream.empty();
  });

  test('the encoder writes an RGB PNG with no alpha channel', () {
    final png = encodeOpaquePng(
      Uint8List.fromList(const <int>[10, 20, 30, 255, 0, 0, 0, 0]),
      2,
      1,
    );
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    // IHDR: width 2, height 1, bit depth 8, colour type 2 (RGB).
    final ihdr = ByteData.sublistView(png, 16, 29);
    expect(ihdr.getUint32(0), 2);
    expect(ihdr.getUint32(4), 1);
    expect(ihdr.getUint8(8), 8);
    expect(ihdr.getUint8(9), 2);
    // The CRC of an empty IEND chunk is a known constant.
    expect(png.sublist(png.length - 4), const <int>[0xAE, 0x42, 0x60, 0x82]);
  });

  for (final set in _sets) {
    testWidgets('store screenshots ${set.folder}, English and Arabic', (
      tester,
    ) async {
      await _render(tester, set, savedFlags);
    });

    testWidgets('store frame with Rahma ${set.folder}, English and Arabic', (
      tester,
    ) async {
      await _renderRahma(tester, set);
    });
  }
}

Future<void> _renderRahma(WidgetTester tester, _DeviceSet set) async {
  tester.view.physicalSize = set.physical;
  tester.view.devicePixelRatio = set.dpr;
  final inset = FakeViewPadding(
    top: set.top * set.dpr,
    bottom: set.bottom * set.dpr,
  );
  tester.view.padding = inset;
  tester.view.viewPadding = inset;
  addTearDown(tester.view.reset);

  // The photo is only needed to write the PNGs; the normal suite lays the
  // frame out on a plain pink block, which is enough to catch an overflow.
  Uint8List? photo;
  if (_outDir != null) {
    final path =
        Platform.environment['OWNHUB_RAHMA_PHOTO'] ??
        '../docs/release/screenshots/rahma/rahma-01.png';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'no photo of Rahma at $path');
    photo = file.readAsBytesSync();
  }

  for (final lang in const ['en', 'ar']) {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(lang),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(Locale(lang)),
        home: _RahmaFrame(lang: lang, photo: photo),
      ),
    );
    await _settle(tester);
    await _shoot(tester, set, lang, '01-rahma');
  }
}

/// The brand frame: a headline naming her, one true line under it, and a frame
/// of her own video. Only what the app has is claimed: she is a coach, and the
/// recipes in Eat are hers.
class _RahmaFrame extends StatelessWidget {
  const _RahmaFrame({required this.lang, required this.photo});

  final String lang;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final ar = lang == 'ar';
    final width = MediaQuery.sizeOf(context).width;
    final headline = TextStyle(
      fontFamily: 'Rubik',
      fontSize: width * 0.088,
      height: 1.22,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );
    final body = TextStyle(
      fontFamily: 'Rubik',
      fontSize: width * 0.042,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.onSurfaceVariant,
    );
    final picture = photo == null
        ? const ColoredBox(color: AppColors.primarySoft)
        : Image.memory(
            photo!,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.3),
            filterQuality: FilterQuality.high,
          );
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Own Hub',
              style: body.copyWith(
                fontSize: width * 0.05,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: width * 0.07),
            Text.rich(
              TextSpan(
                style: headline,
                children: [
                  TextSpan(text: ar ? 'اتعرّفي على المدرّبة ' : 'Meet coach '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: HandUnderline(
                      color: AppColors.primary,
                      width: 4,
                      gap: 3,
                      child: Text(
                        ar ? 'رحمة محسن' : 'Rahma Mohsen',
                        style: headline.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: width * 0.03),
            Text(
              ar
                  ? 'مدرّبة وواجهة Own Hub\u200F. وصفاتها في «الأكل».'
                  : 'Coach, and the face of Own Hub. Her recipes are in Eat.',
              style: body,
            ),
            SizedBox(height: width * 0.06),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 14,
                        top: 14,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: 14,
                        bottom: 14,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: picture,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A coach, a plan and a chat, made up for the store pages: nobody's name,
/// nobody's number. Coaching is free in this build, so the subscription
/// carries no price.
class _Coaching {
  _Coaching() : repo = FakeCoachingRepository(uid: 'me');

  final FakeCoachingRepository repo;

  static const String relId = 'c1__me';

  DateTime _at(int daysAgo, int hour, int minute) => DateTime(
    pinnedMorning.year,
    pinnedMorning.month,
    pinnedMorning.day - daysAgo,
    hour,
    minute,
  );

  /// The chat as one language shows it. The text is data, so the Arabic shot
  /// has Arabic lines, not the English ones under an Arabic bar.
  List<ChatMessage> _chat(bool ar) => <ChatMessage>[
    line(
      'm1',
      'c1',
      ar
          ? 'أهلاً بيكي! قريت إجاباتك. دي خطة الأسبوع الأول، تلات تمارين.'
          : 'Welcome! I read your answers. Here is week one, three sessions.',
      at: _at(1, 18, 5),
    ),
    ChatMessage(
      id: 'm2',
      senderUid: 'c1',
      type: MessageType.workoutPlan,
      planId: 'w1',
      planKind: PlanKind.workout,
      planName: ar ? 'تلات أيام في الأسبوع' : 'Three days a week',
      createdAt: _at(1, 18, 6),
    ),
    line(
      'm3',
      'me',
      ar ? 'شكراً! هتمرّن الصبح.' : 'Thank you! I will train in the mornings.',
      at: _at(1, 18, 12),
    ),
    ChatMessage(
      id: 'm4',
      senderUid: 'c1',
      type: MessageType.audio,
      mediaPath: 'chat/$relId/voice-note.m4a',
      durationMs: 24000,
      createdAt: _at(0, 8, 40),
    ),
    line(
      'm5',
      'me',
      ar
          ? 'خلّصت اليوم الأول! رجليا تعبانة شوية.'
          : 'Done with day one! My legs are a little tired.',
      at: _at(0, 9, 5),
    ),
    line(
      'm6',
      'c1',
      ar
          ? 'الرجلين التعبانة معناها إنك اشتغلتي. اشربي مية كتير، ونتقابل '
                'الأربع.'
          : 'Tired legs mean it worked. Drink plenty of water, and see you '
                'on Wednesday.',
      at: _at(0, 9, 12),
    ),
  ];

  /// Starts the state a coached woman has: an active coaching, a published
  /// plan, and the thread open.
  void start() {
    repo.coaches.value = [coach('c1', 'Coach Nour')];
    repo.clientSubs.value = <Subscription>[
      sub(
        's1',
        SubscriptionStatus.active,
        coachUid: 'c1',
        startsAt: _at(2, 12, 0),
        endsAt: _at(-26, 12, 0),
        price: 0,
      ),
    ];
    repo.relationships.value = [rel()];
    repo.plans.value = <CoachPlan>[
      CoachPlan(
        id: 'w1',
        kind: PlanKind.workout,
        coachUid: 'c1',
        subId: 's1',
        name: 'Three days a week',
        workout: MyPlan.fork(StartingProgrammes.programme('split_3day')!),
        publishedAt: _at(1, 18, 6),
      ),
    ];
    repo.messages[relId] = Feed<List<ChatMessage>>(_chat(false));
    PrivateCoachingState.instance.start(repo, now: () => pinnedMorning);
  }

  /// Puts the chat and the coach's name in [lang].
  void speak(String lang) {
    final ar = lang == 'ar';
    repo.coaches.value = [coach('c1', ar ? 'نور' : 'Coach Nour')];
    repo.messages[relId]!.value = _chat(ar);
  }
}

/// The payments repository for the store pages: the fake the payment tests
/// use, but with a made-up coach and a made-up InstaPay address.
class _ShotPayments extends FakePaymentsRepository {
  @override
  Future<Payment> createPayment({
    required String subId,
    required String idempotencyKey,
    String? topUpOf,
  }) async => Payment(
    id: 'p1',
    clientUid: 'me',
    coachUid: 'c1',
    subId: subId,
    status: PaymentStatus.awaitingPayment,
    amountPiasters: 115037,
    reference: 'OH-4821',
    address: const CoachAddress(
      address: 'coach.nour@instapay',
      accountName: 'Coach Nour',
    ),
    createdAt: pinnedMorning.toUtc(),
    expiresAt: pinnedMorning.toUtc().add(const Duration(hours: 24)),
  );
}

/// Two made-up coaches with a package each, as the directory and a profile
/// show them. The text is data, so each language gets its own.
void _market(_Coaching c, String lang) {
  final ar = lang == 'ar';
  CoachProfile who(
    String uid,
    String name,
    String headline,
    int from,
  ) => CoachProfile(
    uid: uid,
    displayName: name,
    headline: headline,
    languages: const <String>['en', 'ar'],
    specialties: const <String>['strength', 'fatLoss'],
    trainsWhere: const <String>['home'],
    approach: ar
        ? 'خطة بسيطة على قد أسبوعك، ومتابعة معاكي في الشات.'
        : 'A simple plan around your week, and I check in with you in chat.',
    yearsExperience: 6,
    badges: const <String>['verifiedCoach'],
    stats: const CoachStats(clientsCoached: 24),
    fromMonthlyEgp: from,
    published: true,
    acceptingClients: true,
    replyHours: 12,
  );
  c.repo.coaches.value = [
    who(
      'c1',
      ar ? 'نور' : 'Coach Nour',
      ar ? 'قوّة وثبات' : 'Strength, steady',
      1150,
    ),
    who(
      'c2',
      ar ? 'سلمى' : 'Coach Salma',
      ar ? 'نزول وزن بهدوء' : 'Gentle fat loss',
      1500,
    ),
  ];
  c.repo.packages['c1'] = Feed<List<CoachPackage>>(<CoachPackage>[
    CoachPackage(
      id: 'a',
      title: ar ? 'أربع أسابيع معايا' : 'Four weeks with me',
      description: ar
          ? 'خطة تمرين على مقاسك ومتابعة أسبوعية وجلسات فيديو معايا.'
          : 'A training plan made for you, weekly check-ins and video sessions with me.',
      liveSessionsPerMonth: 4,
      sessionMinutes: 45,
      checkInsPerWeek: 2,
      priceFinalEgp: 1150,
      active: true,
    ),
  ]);
  c.repo.packages['c2'] = Feed<List<CoachPackage>>(const <CoachPackage>[]);
}

Future<void> _render(
  WidgetTester tester,
  _DeviceSet set,
  FeatureFlags savedFlags,
) async {
  {
    tester.view.physicalSize = set.physical;
    tester.view.devicePixelRatio = set.dpr;
    // The status bar (and on an iPhone the home indicator), as on a phone.
    final inset = FakeViewPadding(
      top: set.top * set.dpr,
      bottom: set.bottom * set.dpr,
    );
    tester.view.padding = inset;
    tester.view.viewPadding = inset;
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.view.reset);

    // The app's clock starts at [pinnedMorning] and moves with the test's
    // fake time, so a workout still lasts as long as it is pumped for.
    final start = tester.binding.clock.now();
    AppClock.debugNow = () =>
        pinnedMorning.add(tester.binding.clock.now().difference(start));
    addTearDown(() => AppClock.debugNow = null);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    SharedPreferences.setMockInitialValues(const <String, Object>{
      'payments.learnAsked': true,
    });
    await const ThisPhoneWipe().clearPersistence();
    AppRouter.featureFlags = FeatureFlags.shipped.with_(const {
      // This harness only. The shipped flags keep it on.
      Feature.accountRequired: false,
    });
    addTearDown(() => AppRouter.featureFlags = savedFlags);
    addTearDown(() => const ThisPhoneWipe().clearPersistence());
    addTearDown(PrivateCoachingState.instance.stop);

    // Her four setup answers are behind her, and she has answered the
    // allergy question naming nothing, which is what opens Rahma's book.
    AppRouter.intakeRepository.markSetupDone();
    await AppRouter.dietaryRepository.save(
      allergies: <AllergenTag>{},
      dietary: <DietaryTag>{},
    );

    // What `main()` reads before the first frame: the bundled programmes, the
    // index of painted meals and the table of what each move is measured on.
    StartingProgrammes.adopt(
      File(StartingProgrammes.assetPath).readAsStringSync(),
    );
    MealImages.adopt(File(MealImages.indexPath).readAsStringSync());
    await tester.runAsync(prepareMoveBests);
    addTearDown(StartingProgrammes.reset);
    addTearDown(MealImages.clear);

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _settle(tester);
      await _loadRecipeBook(tester);
      final l10n = _l10n(tester);
      final locale = LocaleScope.of(tester.element(find.byType(MaterialApp)));

      // A set logged, as she would: Done, then the rest runs by itself.
      Future<void> logSets(int sets) async {
        for (var i = 0; i < sets; i++) {
          await tester.tap(find.textContaining('Done').hitTestable().first);
          await _settle(tester);
          await tester.pump(const Duration(seconds: 75));
          await _settle(tester);
        }
      }

      // A session, started from the day's page, the given sets in, then
      // Pause > End workout > Finish and save: R10 is what is on screen after
      // it, once its 5-second Undo has gone.
      Future<void> workout({required int sets, String? finishedShot}) async {
        await _open(tester, 'R03');
        await _tapText(tester, l10n.startEverythingsReady);
        await logSets(sets);
        await finishEarly(tester);
        await _settle(tester);
        expect(WorkoutSessionState.instance.lastFinished, isNotNull);
        expect(
          WorkoutSessionState.instance.lastFinished!.sets,
          isNotEmpty,
          reason: 'the session the week counts has the sets she logged',
        );
        if (finishedShot != null) {
          await tester.pump(const Duration(seconds: 6));
          await _settle(tester);
          await _shootBoth(tester, set, finishedShot);
        }
        await _home(tester);
      }

      // Two breakfasts logged by typing them, as she would.
      for (final food in const ['ful', 'boiled eggs']) {
        await _open(tester, 'E02');
        await tester.enterText(find.byType(TextField).first, food);
        await _settle(tester);
        await _tapText(tester, l10n.addIt);
        await tester.pump(const Duration(seconds: 6));
        await _settle(tester);
        await _home(tester);
      }

      // 02. Home on the pinned Monday, before she trains: its one next step,
      // and its one Eat line counting both breakfasts. She has put away the
      // offer of a reminder, which is the "x" beside it.
      expect(find.text(weekdayLabel(l10n, pinnedMorning)), findsWidgets);
      expect(find.textContaining('kcal'), findsWidgets);
      final close = find.byIcon(Icons.close).hitTestable();
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first);
        await _settle(tester);
      }
      await _shootBoth(tester, set, '02-home');

      // 03. Today's session, as its page lists it.
      await _open(tester, 'R03');
      await _shootBoth(tester, set, '03-workout');
      await _home(tester);

      // 04. ...and the same session done, six sets in.
      await workout(sets: 6, finishedShot: '04-finished');

      // 05. Eat: the four meals, each with its one tap.
      await _open(tester, 'E01');
      await _shootBoth(tester, set, '05-eat');
      await _home(tester);

      // 06. Rahma's book, opened on her second section: the first one's PS
      // line names the period outright, and store pages are seen before
      // sign-in.
      await _open(tester, 'E05');
      final heading = find.text(l10n.rahmasRecipes);
      await tester.scrollUntilVisible(
        heading,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(
        () => Scrollable.ensureVisible(tester.element(heading.first)),
      );
      final sections = EatAppState.instance.recipeBook.sections;
      // The title is on E05 twice by design: under Rahma's book and again
      // under "From the Own Hub kitchen". The shot wants hers, the first.
      final savoury = find
          .text(
            sectionTitle(
              l10n,
              sections.firstWhere(
                (s) => s.sectionId == 'salty_fulling_breakfast',
                orElse: () => sections[1],
              ),
            ),
          )
          .first;
      await tester.scrollUntilVisible(
        savoury,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(
        () => Scrollable.ensureVisible(
          tester.element(savoury.first),
          alignment: 0.1,
        ),
      );
      await _settle(tester);
      await _shootBoth(tester, set, '06-recipes');
      await _home(tester);

      // 08 and 09. A coaching, while the week has its one session: an active
      // sub, a published plan and the thread open. The text of a chat is
      // data, so each language gets its own lines.
      final coaching = _Coaching()..start();
      await _settle(tester);
      await _open(tester, 'H06', arguments: _Coaching.relId);
      for (final lang in const ['en', 'ar']) {
        locale.value = Locale(lang);
        coaching.speak(lang);
        await _settle(tester);
        await _shoot(tester, set, lang, '08-coach-chat');
      }
      await _home(tester);
      for (final lang in const ['en', 'ar']) {
        locale.value = Locale(lang);
        coaching.speak(lang);
        await _settle(tester);
        await _shoot(tester, set, lang, '09-coach-plan');
      }
      // 14. The coach's plan in Train.
      await _open(tester, 'R01');
      for (final lang in const ['en', 'ar']) {
        locale.value = Locale(lang);
        coaching.speak(lang);
        await _settle(tester);
        await _shoot(tester, set, lang, '14-coach-plan-train');
      }
      await _home(tester);
      locale.value = const Locale('en');
      PrivateCoachingState.instance.stop();
      await _settle(tester);

      // 10 to 13. Coaching with payments on: Find a coach, her profile with
      // the live sessions first, My coach with its Pay button, then the
      // payment instructions.
      PaymentsSwitch.enabled = true;
      PaymentsHub.override = _ShotPayments();
      addTearDown(() {
        PaymentsHub.override = null;
        PaymentsSwitch.resetForTest();
      });
      final market = _Coaching();
      _market(market, 'en');
      market.repo.relationships.value = [];
      PrivateCoachingState.instance.start(
        market.repo,
        now: () => pinnedMorning,
      );
      await _settle(tester);
      Future<void> shootMarket(String name) async {
        for (final lang in const ['en', 'ar']) {
          locale.value = Locale(lang);
          _market(market, lang);
          await _settle(tester);
          await _shoot(tester, set, lang, name);
        }
        locale.value = const Locale('en');
        _market(market, 'en');
        await _settle(tester);
      }

      await _open(tester, 'H01');
      await shootMarket('10-find-a-coach');
      await _home(tester);
      await _open(tester, 'H02', arguments: 'c1');
      await shootMarket('11-coach-profile');
      await _home(tester);
      market.repo.clientSubs.value = <Subscription>[
        sub(
          's2',
          SubscriptionStatus.awaitingPayment,
          coachUid: 'c1',
          payBy: pinnedMorning.add(const Duration(days: 7)),
          price: 1150,
        ),
      ];
      await _open(tester, 'H05');
      await shootMarket('12-my-coach');
      await tester.tap(find.byKey(const ValueKey('pay-now')).hitTestable());
      await _settle(tester);
      for (final lang in const ['en', 'ar']) {
        locale.value = Locale(lang);
        await _settle(tester);
        await _shoot(tester, set, lang, '13-payment-instructions');
      }
      locale.value = const Locale('en');
      PrivateCoachingState.instance.stop();
      PaymentsHub.override = null;
      PaymentsSwitch.resetForTest();
      await _home(tester);
      await _settle(tester);

      // 07. You, after the rest of her week's sessions, so it shows what she
      // did rather than a page of zeros.
      await workout(sets: 4);
      await workout(sets: 4);
      await _open(tester, 'P01');
      await _shootBoth(tester, set, '07-you');
    } finally {
      debugDisableShadows = true;
    }
  }
}
