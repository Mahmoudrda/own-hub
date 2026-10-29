import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/payments_switch.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/domain/approved_media.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/portfolio_media.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart'
    show TrainingGoal, TrainingLevel, TrainingPlace;
import 'package:own_hub/features/private_coaching/domain/setup_prefill.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_card.dart'
    show CoachPhoto;
import 'package:own_hub/features/private_coaching/presentation/member/coach_image.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_labels.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_portfolio_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/find_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/join_coach_sheet.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_chip_row.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// A value that replays its latest state to each new listener.
class Feed<T> {
  Feed(this._value);

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast(
    sync: true,
  );

  set value(T next) {
    _value = next;
    _changes.add(next);
  }

  void fail(Object error) => _changes.addError(error);

  Stream<T> watch() => Stream<T>.multi((controller) {
    controller.add(_value);
    final sub = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = sub.cancel;
  });
}

/// The reads and writes the member screens use; anything else is a mistake.
class MemberRepo implements CoachingRepository {
  MemberRepo({this.uid = 'me'});

  @override
  String? uid;

  final coaches = Feed<List<CoachProfile>>(const <CoachProfile>[]);
  final packages = <String, Feed<List<CoachPackage>>>{};
  final media = <String, Feed<List<ApprovedMedia>>>{};
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  final Map<String, CoachingFailure> failWith = <String, CoachingFailure>{};
  Intake? lastIntake;
  Map<String, Object?>? lastConsent;
  int packageWatches = 0;

  List<String> get callNames => <String>[for (final c in calls) c.$1];

  void _record(String name, Map<String, Object?> args) {
    calls.add((name, args));
    final failure = failWith[name];
    if (failure != null) throw failure;
  }

  @override
  Stream<List<CoachProfile>> watchPublishedCoaches() => coaches.watch();

  @override
  Stream<CoachProfile?> watchCoach(String coachUid) => coaches.watch().map(
    (list) => list.where((c) => c.uid == coachUid).firstOrNull,
  );

  @override
  Stream<List<CoachPackage>> watchPackages(
    String coachUid, {
    bool onlyActive = true,
  }) {
    packageWatches++;
    return packages
        .putIfAbsent(coachUid, () => Feed<List<CoachPackage>>(<CoachPackage>[]))
        .watch();
  }

  @override
  Stream<List<ApprovedMedia>> watchApprovedMedia(String coachUid) => media
      .putIfAbsent(coachUid, () => Feed<List<ApprovedMedia>>(<ApprovedMedia>[]))
      .watch();

  @override
  Future<void> reportCoachProfile({
    required String coachUid,
    required String reason,
    String note = '',
    required String locale,
  }) async => _record('reportCoachProfile', {
    'coachUid': coachUid,
    'reason': reason,
    'note': note,
    'locale': locale,
  });

  @override
  Future<({String subId, SubscriptionStatus status})> requestCoaching({
    required String coachUid,
    required String packageId,
    required Intake intake,
    required Map<String, Object?> consent,
    required String locale,
    String clientName = '',
    String? inviteCode,
  }) async {
    lastConsent = consent;
    _record('requestCoaching', {
      'coachUid': coachUid,
      'packageId': packageId,
      'clientName': clientName,
      'inviteCode': ?inviteCode,
    });
    lastIntake = intake;
    return (subId: 'sub1', status: SubscriptionStatus.requested);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

CoachProfile coach(
  String uid,
  String name, {
  List<String> specialties = const <String>['strength'],
  List<String> where = const <String>['home'],
  int clients = 0,
  int? monthly,
}) => CoachProfile(
  uid: uid,
  displayName: name,
  headline: 'Headline of $name',
  languages: const <String>['ar', 'en'],
  specialties: specialties,
  trainsWhere: where,
  published: true,
  fromMonthlyEgp: monthly,
  acceptingClients: true,
  badges: const <String>['verifiedCoach'],
  yearsExperience: 6,
  replyHours: 12,
  approach: 'Slow and steady plans.',
  stats: CoachStats(clientsCoached: clients),
  certificates: const <PublicCertificate>[
    PublicCertificate(title: 'Level 3 Trainer', issuer: 'REPs', year: 2019),
  ],
  testimonials: const <PublicTestimonial>[
    PublicTestimonial(text: 'Very patient and clear.', from: 'Mona'),
  ],
);

CoachPackage pkg(String id, int price, {int days = 28, bool active = true}) =>
    CoachPackage(
      id: id,
      title: 'Package $id',
      description: 'Plan and chat',
      includes: const <String>['Weekly plan'],
      durationDays: days,
      liveSessionsPerMonth: 2,
      priceFinalEgp: price,
      active: active,
    );

Widget host(Widget child, {String lang = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(Locale(lang)),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: child,
    );

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

MemberRepo seeded() {
  final repo = MemberRepo();
  repo.coaches.value = <CoachProfile>[
    coach('c1', 'Zeina', clients: 500, monthly: 1200),
    coach('c2', 'Amal', clients: 1, monthly: 1300),
    coach(
      'c3',
      'Basma',
      specialties: const <String>['mobility'],
      monthly: 1200,
    ),
    coach(
      'c4',
      'Dina',
      clients: 900,
      where: const <String>['gym'],
      monthly: 1000,
    ),
  ];
  repo.packages['c1'] = Feed<List<CoachPackage>>(<CoachPackage>[
    pkg('a', 1800),
    pkg('b', 2400, days: 56),
  ]);
  repo.packages['c2'] = Feed<List<CoachPackage>>(<CoachPackage>[
    pkg('a', 1300),
  ]);
  repo.packages['c3'] = Feed<List<CoachPackage>>(<CoachPackage>[
    pkg('a', 1200),
  ]);
  repo.packages['c4'] = Feed<List<CoachPackage>>(<CoachPackage>[
    pkg('a', 1000),
  ]);
  return repo;
}

double topOf(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

Widget portfolio(
  MemberRepo repo, {
  bool preview = false,
  String lang = 'en',
  double scale = 1,
  List<String> allergies = const <String>[],
  List<ApprovedMedia> media = const <ApprovedMedia>[],
  BlockService? blocks,
}) => host(
  CoachPortfolioView(
    blocks: blocks,
    coach: coach('c2', 'Amal'),
    packages: <CoachPackage>[pkg('a', 2000)],
    media: media,
    repository: repo,
    preview: preview,
    declaredAllergies: allergies,
  ),
  lang: lang,
  scale: scale,
);

Future<void> tapText(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Report and Block live behind the "..." in the top bar.
Future<void> tapMenuRow(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> openJoin(WidgetTester tester) async {
  await tapText(tester, find.text('Ask to join'));
  await tester.pumpAndSettle();
}

/// Fills every question; [yesAt] answers yes to that health question.
Future<void> fillJoin(
  WidgetTester tester, {
  int? yesAt,
  bool pregnancyFood = true,
}) async {
  await tapText(tester, find.text('Get stronger'));
  await tapText(tester, find.text('Beginner'));
  await tapText(tester, find.text('3'));
  await tapText(tester, find.text('At home'));
  for (var i = 0; i < CoachingEnums.healthQuestions.length; i++) {
    await tapText(
      tester,
      yesAt == i ? find.text('Yes').at(i) : find.text('No').at(i),
    );
  }
  if (pregnancyFood) {
    await tapText(
      tester,
      find.text('No').at(CoachingEnums.healthQuestions.length),
    );
    await tapText(
      tester,
      find.text('No').at(CoachingEnums.healthQuestions.length + 1),
    );
  }
}

Future<void> tickConsents(WidgetTester tester, {bool doctor = false}) async {
  final boxes = find.byType(CheckboxListTile);
  final count = tester.widgetList(boxes).length;
  for (var i = doctor ? 0 : (count - 2); i < count; i++) {
    if (!doctor && i < count - 2) continue;
    await tapText(tester, boxes.at(i));
  }
}

/// Words Apple's 3.1.3(d) reading rules out of what a member sees.
final RegExp _storeBannedWords = RegExp(
  r'\b(buy|unlock|gift|wallet|subscribe|subscription|renews?)\b',
  caseSensitive: false,
);

void main() {
  setUp(() => CoachImageBytes.lookup = (path) async => null);
  tearDown(CoachImageBytes.reset);

  // The budget question is asked once a payment can be started.
  final savedFlags = AppRouter.featureFlags;
  void moneyIsLive() {
    AppRouter.featureFlags = savedFlags.with_(<Feature, bool>{
      Feature.instapayPayments: true,
      Feature.marketplace: true,
    });
    PaymentsSwitch.enabled = true;
    addTearDown(() {
      PaymentsSwitch.resetForTest();
      AppRouter.featureFlags = savedFlags;
    });
  }

  testWidgets('with nothing to pay, H01 asks two questions and no budget', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: seeded())));
    await tester.pump();
    final l10n = AppL10n.of(tester.element(find.byType(FindCoachView)));
    expect(find.text(l10n.twoQuickQuestionsThenTheCoachesWho), findsOneWidget);
    expect(find.text(l10n.yourBudgetForAMonth), findsNothing);
    await tester.tap(find.text('Get stronger'));
    await tester.pump();
    await tester.tap(find.text('At home'));
    await tester.pump();
    // Two answers are enough to match, with no budget chip in the way.
    expect(find.text('Your best matches'), findsOneWidget);
    expect(find.text(l10n.matchedOnYourTwoAnswersOnlyThen), findsOneWidget);
  });

  testWidgets('H01 starts on the goal and place she gave in setup', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      host(
        FindCoachView(
          repository: seeded(),
          initialGoal: 'stronger',
          initialPlace: 'home',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Your best matches'), findsOneWidget);
    // Still hers to change.
    await tester.tap(find.text('At the gym'));
    await tester.pump();
    expect(find.text('Your best matches'), findsOneWidget);
  });

  testWidgets('matches: best fit first, ties A to Z, never by clients', (
    tester,
  ) async {
    moneyIsLive();
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: seeded())));
    await tester.pump();
    await tester.tap(find.text('Get stronger'));
    await tester.pump();
    await tester.tap(find.text('At home'));
    await tester.pump();
    await tester.tap(find.text('Under EGP 1,500'));
    await tester.pump();
    // Zeina 9, Amal 9 (tie, A to Z although Zeina has 500 clients), Dina 6,
    // Basma 5.
    final heading = topOf(tester, find.text('Your best matches'));
    final allHeading = topOf(tester, find.text('All coaches A to Z'));
    final ys = <double>[
      for (final n in <String>['Amal', 'Zeina', 'Dina', 'Basma'])
        topOf(tester, find.text(n).first),
    ];
    expect(ys, orderedEquals(<double>[...ys]..sort()));
    expect(ys.first > heading && ys.last < allHeading, isTrue);
    final az = <double>[
      for (final n in <String>['Amal', 'Basma', 'Dina', 'Zeina'])
        topOf(tester, find.text(n).last),
    ];
    expect(az, orderedEquals(<double>[...az]..sort()));
    expect(az.first > allHeading, isTrue);
  });

  testWidgets('all coaches are shown A to Z before any answer', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: seeded())));
    await tester.pump();
    expect(find.text('Your best matches'), findsNothing);
    final ys = <double>[
      for (final n in <String>['Amal', 'Basma', 'Dina', 'Zeina'])
        topOf(tester, find.text(n)),
    ];
    expect(ys, orderedEquals(<double>[...ys]..sort()));
  });

  testWidgets('once the server opens payments, cards and portfolio price', (
    tester,
  ) async {
    moneyIsLive();
    expect(coachingPaymentsOn, isTrue);
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: seeded())));
    await tester.pump();
    expect(find.textContaining('From EGP'), findsWidgets);
    expect(find.text('Free for now'), findsNothing);
    await tester.pumpWidget(portfolio(MemberRepo()));
    expect(find.text('EGP 2,000'), findsOneWidget);
    expect(find.textContaining('taxes and fees'), findsOneWidget);
    // 3.1.3(d): the live one-to-one video sessions come before the price.
    final live = find.byKey(const ValueKey('package-live-a'));
    expect(
      (tester.widget<Text>(live)).data,
      '2 live one-to-one video sessions a month',
    );
    expect(
      topOf(tester, live),
      lessThan(topOf(tester, find.text('EGP 2,000'))),
    );
    expect(find.textContaining(_storeBannedWords), findsNothing);
    await openJoin(tester);
    // The join sheet no longer promises it is free, and names the sessions.
    expect(find.text('Free while Own Hub opens coaching'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(JoinCoachForm),
        matching: find.text('2 live one-to-one video sessions a month'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining(_storeBannedWords), findsNothing);
  });

  testWidgets('from line uses the cheapest package per 28 days', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: seeded())));
    await tester.pump();
    // Payments are off: every card says so rather than quoting a price.
    expect(find.text('Free for now'), findsWidgets);
    expect(find.textContaining('From EGP'), findsNothing);
    expect(formatEgp(1234567), '1,234,567');
  });

  testWidgets('the directory opens no packages listener per coach', (
    tester,
  ) async {
    phone(tester);
    final repo = seeded();
    await tester.pumpWidget(host(FindCoachView(repository: repo)));
    await tester.pump();
    expect(find.text('Amal'), findsOneWidget);
    expect(repo.packageWatches, 0);
  });

  testWidgets('empty state when no coach is published', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: MemberRepo())));
    await tester.pump();
    expect(find.text('Coaches are joining. Check back soon.'), findsOneWidget);
    expect(find.text('Your best matches'), findsNothing);
  });

  testWidgets('offline state offers a retry that reloads', (tester) async {
    phone(tester);
    final repo = MemberRepo();
    await tester.pumpWidget(host(FindCoachView(repository: repo)));
    repo.coaches.fail(const CoachingFailure(CoachingRefusal.unreachable));
    await tester.pump();
    expect(
      find.text(
        'We could not load the coaches. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    repo.coaches.value = <CoachProfile>[coach('c2', 'Amal')];
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Amal'), findsOneWidget);
  });

  testWidgets('loading state shows before the first answer', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(FindCoachView(repository: MemberRepo())));
    expect(find.bySemanticsLabel('Loading coaches'), findsOneWidget);
    await tester.pump();
  });

  testWidgets('tapping a card opens that coach', (tester) async {
    phone(tester);
    String? opened;
    await tester.pumpWidget(
      host(FindCoachView(repository: seeded(), onOpenCoach: (u) => opened = u)),
    );
    await tester.pump();
    await tapText(tester, find.text('Basma'));
    expect(opened, 'c3');
  });

  testWidgets('portfolio shows the final price and Ask to join', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(portfolio(MemberRepo()));
    // Payments are off: a member sees no price and no payment wording.
    expect(find.textContaining('EGP'), findsNothing);
    expect(find.textContaining('payments open'), findsNothing);
    expect(find.text('Free while Own Hub opens coaching'), findsNothing);
    expect(find.text('Free for now'), findsOneWidget);
    expect(find.textContaining('taxes and fees'), findsNothing);
    expect(find.text('Ask to join'), findsOneWidget);
    expect(find.text('Level 3 Trainer'), findsOneWidget);
    expect(find.text('Booking opens soon'), findsNothing);
  });

  testWidgets('no testimonials: the reviews block is not drawn', (
    tester,
  ) async {
    phone(tester);
    final base = coach('c2', 'Amal');
    await tester.pumpWidget(
      host(
        CoachPortfolioView(
          coach: CoachProfile(
            uid: base.uid,
            displayName: base.displayName,
            headline: base.headline,
            languages: base.languages,
            specialties: base.specialties,
            trainsWhere: base.trainsWhere,
            published: true,
            acceptingClients: true,
            approach: base.approach,
            testimonials: const <PublicTestimonial>[],
          ),
          packages: <CoachPackage>[pkg('a', 2000)],
          media: const <ApprovedMedia>[],
          repository: MemberRepo(),
          preview: false,
          declaredAllergies: const <String>[],
        ),
      ),
    );
    expect(find.text('What members say'), findsNothing);
    expect(find.text('Very patient and clear.'), findsNothing);
  });

  testWidgets('with a testimonial the block is drawn', (tester) async {
    phone(tester);
    await tester.pumpWidget(portfolio(MemberRepo()));
    await tester.scrollUntilVisible(
      find.text('What members say'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('What members say'), findsOneWidget);
    expect(find.text('Very patient and clear.'), findsOneWidget);
  });

  testWidgets('report writes once with the contract keys and thanks her', (
    tester,
  ) async {
    phone(tester);
    final repo = MemberRepo();
    await tester.pumpWidget(portfolio(repo));
    await tapMenuRow(tester, 'Report this profile');
    await tester.tap(find.text('Spam or advertising'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'sells outside');
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(repo.callNames, <String>['reportCoachProfile']);
    expect(repo.calls.single.$2['reason'], 'spam');
    expect(repo.calls.single.$2['note'], 'sells outside');
    expect(repo.calls.single.$2['coachUid'], 'c2');
    expect(find.text('Thank you. We will look at this.'), findsOneWidget);
  });

  testWidgets('Block is in the menu, asks first and blocks the coach', (
    tester,
  ) async {
    phone(tester);
    final blocks = InMemoryBlockService(selfUid: 'me');
    await tester.pumpWidget(portfolio(MemberRepo(), blocks: blocks));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(blocks.isBlocked('c2'), isFalse);
    await tester.tap(find.widgetWithText(AppButton, 'Block'));
    await tester.pumpAndSettle();
    expect(blocks.isBlocked('c2'), isTrue);
    expect(blocks.blocks().single.source, BlockSource.profile);
  });

  testWidgets(
    'no menu on a coach own page; without a block list it holds Report only',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(portfolio(MemberRepo()));
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Report this profile'), findsOneWidget);
      expect(find.text('Block'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        portfolio(
          MemberRepo(uid: 'c2'),
          blocks: InMemoryBlockService(selfUid: 'c2'),
        ),
      );
      expect(find.byTooltip('More options'), findsNothing);
    },
  );

  testWidgets('a failed report keeps the sheet and says so', (tester) async {
    phone(tester);
    final repo = MemberRepo()
      ..failWith['reportCoachProfile'] = const CoachingFailure(
        CoachingRefusal.unreachable,
      );
    await tester.pumpWidget(portfolio(repo));
    await tapMenuRow(tester, 'Report this profile');
    await tester.tap(find.text('Spam or advertising'));
    await tester.pump();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(
      find.text('We could not send your report. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Thank you. We will look at this.'), findsNothing);
  });

  testWidgets('preview shows the banner and hides Report and Ask to join', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(portfolio(MemberRepo(), preview: true));
    expect(find.text('This is how members see you'), findsOneWidget);
    // Only the coach sees the price her package will have.
    expect(find.text('EGP 2,000 when payments open'), findsOneWidget);
    expect(find.text('Report this profile'), findsNothing);
    expect(find.text('Ask to join'), findsNothing);
  });

  testWidgets('a coach viewing her own page cannot join or report it', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(portfolio(MemberRepo(uid: 'c2')));
    expect(find.text('Ask to join'), findsNothing);
    expect(find.text('Report this profile'), findsNothing);
  });

  testWidgets('inactive packages are not listed', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      host(
        CoachPortfolioView(
          coach: coach('c2', 'Amal'),
          packages: <CoachPackage>[
            pkg('a', 2000),
            pkg('b', 900, active: false),
          ],
        ),
      ),
    );
    expect(find.text('Package a'), findsOneWidget);
    expect(find.text('Package b'), findsNothing);
  });

  group('ask to join', () {
    testWidgets('an unfinished form sends nothing and says what is missing', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      await tapText(tester, find.text('Send request'));
      expect(repo.callNames, isEmpty);
      expect(
        find.text('Answer every question and tick the boxes at the end.'),
        findsOneWidget,
      );
    });

    testWidgets('Send request stays disabled until everything is answered', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      final send = find.widgetWithText(AppButton, 'Send request');
      bool enabled() => tester.widget<AppButton>(send).onPressed != null;
      // No health question starts answered.
      expect(find.byType(AppChip), findsWidgets);
      expect(enabled(), isFalse);
      await fillJoin(tester);
      expect(enabled(), isFalse);
      await tickConsents(tester);
      expect(enabled(), isTrue);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.text('You can see it under My coach.'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('opens on the answers she gave in setup, never on health', (
      tester,
    ) async {
      final intake = AppRouter.intakeRepository;
      intake.reset();
      await intake.merge(
        goal: TrainingGoal.buildMuscle,
        place: TrainingPlace.ladiesGym,
        days: 4,
        level: TrainingLevel.intermediate,
      );
      intake.markSetupDone();
      addTearDown(intake.reset);
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      final form = tester.widget<JoinCoachForm>(find.byType(JoinCoachForm));
      expect(form.setupAnswers, (
        goal: 'buildMuscle',
        level: 'intermediate',
        days: 4,
        place: 'gym',
      ));
      final send = find.widgetWithText(AppButton, 'Send request');
      // The four chips are already hers; the health questions, her life stage
      // and her eating history are still empty, so nothing can be sent.
      expect(tester.widget<AppButton>(send).onPressed, isNull);
      for (var i = 0; i < CoachingEnums.healthQuestions.length + 2; i++) {
        await tapText(tester, find.text('No').at(i));
      }
      await tickConsents(tester);
      expect(tester.widget<AppButton>(send).onPressed, isNotNull);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.callNames, <String>['requestCoaching']);
      // She changed nothing and the request carries what setup said.
      expect(repo.lastIntake?.goal, 'buildMuscle');
      expect(repo.lastIntake?.place, 'gym');
      expect(repo.lastIntake?.daysPerWeek, 4);
      expect(repo.lastIntake?.level, 'intermediate');
    });

    testWidgets('with setup not finished, nothing is carried over', (
      tester,
    ) async {
      final intake = AppRouter.intakeRepository;
      intake.reset();
      await intake.merge(goal: TrainingGoal.buildMuscle);
      addTearDown(intake.reset);
      phone(tester);
      await tester.pumpWidget(portfolio(MemberRepo()));
      await openJoin(tester);
      expect(
        tester.widget<JoinCoachForm>(find.byType(JoinCoachForm)).setupAnswers,
        noSetupAnswers,
      );
    });

    testWidgets('consents are required', (tester) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      await fillJoin(tester);
      await tapText(tester, find.text('Send request'));
      expect(repo.callNames, isEmpty);
    });

    testWidgets('a yes needs the doctor tick before it can be sent', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      await fillJoin(tester, yesAt: 1);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      await tickConsents(tester);
      await tapText(tester, find.text('Send request'));
      expect(repo.callNames, isEmpty);
      await tapText(tester, find.byType(CheckboxListTile).first);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.callNames, <String>['requestCoaching']);
    });

    testWidgets('sends the request with no price and shows the reply time', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(
        portfolio(repo, allergies: <String>['peanuts', 'tree_nuts']),
      );
      await openJoin(tester);
      expect(find.text('Free while Own Hub opens coaching'), findsOneWidget);
      // Take one allergy off her list.
      await tapText(tester, find.text('Peanuts'));
      await fillJoin(tester);
      await tester.enterText(find.byType(TextField).last, 'Knee is sore');
      await tickConsents(tester);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.callNames, <String>['requestCoaching']);
      final consent = repo.lastConsent!;
      expect(consent['version'], 2);
      expect(consent['shareHash'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(consent['transferHash'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(consent['shareHash'], isNot(consent['transferHash']));
      final args = repo.calls.single.$2;
      expect(args['coachUid'], 'c2');
      expect(args['packageId'], 'a');
      expect(args.keys, containsAll(<String>['coachUid', 'packageId']));
      expect(find.text('Request sent'), findsOneWidget);
      expect(find.text('Amal usually replies within 12 hours'), findsOneWidget);
      final intake = repo.lastIntake!;
      expect(intake.allergies, <String>['tree_nuts']);
      expect(intake.goal, 'stronger');
      expect(intake.daysPerWeek, 3);
    });

    testWidgets('the name field starts with her first name and is sent', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SingleChildScrollView(
              child: JoinCoachForm(
                repository: repo,
                coach: coach('c2', 'Amal'),
                package: pkg('a', 2000),
                firstName: 'Mona',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Mona'), findsOneWidget);
      await fillJoin(tester);
      await tickConsents(tester);
      await tester.enterText(find.byType(TextField).first, 'Mo');
      await tester.pumpAndSettle();
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.calls.single.$2['clientName'], 'Mo');
    });

    testWidgets('the name can be left empty', (tester) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      await fillJoin(tester);
      await tickConsents(tester);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.calls.single.$2['clientName'], '');
    });

    for (final (refusal, text) in <(CoachingRefusal, String)>[
      (
        CoachingRefusal.alreadyRequested,
        'You already asked to join this coach.',
      ),
      (
        CoachingRefusal.coachUnavailable,
        'This coach is not taking new clients right now.',
      ),
      (CoachingRefusal.appUpdateNeeded, 'Update Own Hub to ask this coach'),
      (
        CoachingRefusal.unreachable,
        'We could not send your request. Try again.',
      ),
    ]) {
      testWidgets('refusal ${refusal.code} is explained', (tester) async {
        phone(tester);
        final repo = MemberRepo()
          ..failWith['requestCoaching'] = CoachingFailure(refusal);
        await tester.pumpWidget(portfolio(repo));
        await openJoin(tester);
        await fillJoin(tester);
        await tickConsents(tester);
        await tapText(tester, find.text('Send request'));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
        expect(find.text('Request sent'), findsNothing);
      });
    }

    testWidgets('the two new questions must be answered before Send', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      final send = find.widgetWithText(AppButton, 'Send request');
      bool enabled() => tester.widget<AppButton>(send).onPressed != null;

      await fillJoin(tester, pregnancyFood: false);
      await tickConsents(tester);
      expect(enabled(), isFalse);

      await tapText(
        tester,
        find.text('No').at(CoachingEnums.healthQuestions.length),
      );
      expect(enabled(), isFalse);

      await tapText(
        tester,
        find.text('No').at(CoachingEnums.healthQuestions.length + 1),
      );
      expect(enabled(), isTrue);
    });

    testWidgets('Pregnant shows the doctor tick and sends lifeStage', (
      tester,
    ) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      final send = find.widgetWithText(AppButton, 'Send request');
      bool enabled() => tester.widget<AppButton>(send).onPressed != null;

      await fillJoin(tester, pregnancyFood: false);
      await tapText(tester, find.text('Pregnant'));
      await tapText(
        tester,
        find.text('No').at(CoachingEnums.healthQuestions.length + 1),
      );
      expect(
        find.text('I will check with my doctor before I start'),
        findsOneWidget,
      );
      await tickConsents(tester);
      expect(enabled(), isFalse);
      await tapText(tester, find.byType(CheckboxListTile).first);
      expect(enabled(), isTrue);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.lastIntake!.lifeStage, 'pregnant');
      expect(repo.lastIntake!.eatingHistory, isFalse);
    });

    testWidgets('eating history yes is sent', (tester) async {
      phone(tester);
      final repo = MemberRepo();
      await tester.pumpWidget(portfolio(repo));
      await openJoin(tester);
      await fillJoin(tester, pregnancyFood: false);
      await tapText(
        tester,
        find.text('No').at(CoachingEnums.healthQuestions.length),
      );
      await tapText(
        tester,
        find.text('Yes').at(CoachingEnums.healthQuestions.length),
      );
      expect(
        find.text('I will check with my doctor before I start'),
        findsOneWidget,
      );
      await tickConsents(tester);
      await tapText(tester, find.byType(CheckboxListTile).first);
      await tapText(tester, find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.lastIntake!.eatingHistory, isTrue);
    });
  });

  group('results and photos', () {
    final items = <ApprovedMedia>[
      const ApprovedMedia(
        id: 't1',
        kind: MediaKind.transformation,
        weeks: 12,
        note: 'Three sessions a week.',
        beforePath: 'coach-public/c2/media/t1_before.jpg',
        afterPath: 'coach-public/c2/media/t1_after.jpg',
      ),
      const ApprovedMedia(
        id: 'f1',
        kind: MediaKind.feedback,
        text: 'She made training feel doable.',
        from: 'Nour',
        imagePath: 'coach-public/c2/media/f1_image.jpg',
      ),
      const ApprovedMedia(
        id: 'p1',
        kind: MediaKind.photo,
        caption: 'My studio',
        imagePath: 'coach-public/c2/media/p1_image.jpg',
      ),
    ];

    setUp(() {
      CoachImageBytes.reset();
      CoachImageBytes.lookup = (path) async => null;
    });
    tearDown(CoachImageBytes.reset);

    testWidgets('shows transformations, feedback and the gallery', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(portfolio(MemberRepo(), media: items));
      await tester.pump();
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Over 12 weeks'), findsOneWidget);
      expect(
        find.text("Shared with her client's written consent"),
        findsOneWidget,
      );
      expect(find.text('She made training feel doable.'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.bySemanticsLabel('My studio'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
    });

    testWidgets('a photo opens full screen and closes', (tester) async {
      phone(tester);
      var asked = <String>[];
      CoachImageBytes.lookup = (path) async {
        asked = <String>[...asked, path];
        return null;
      };
      await tester.pumpWidget(portfolio(MemberRepo(), media: items));
      await tester.pump();
      await tapText(tester, find.bySemanticsLabel('My studio'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(asked, contains('coach-public/c2/media/p1_image.jpg'));
    });

    testWidgets('loaded bytes are fetched once per path', (tester) async {
      phone(tester);
      var fetches = 0;
      CoachImageBytes.lookup = (path) async {
        fetches++;
        return Uint8List(0);
      };
      expect(await CoachImageBytes.load('coach-public/c2/a.jpg'), isNotNull);
      expect(await CoachImageBytes.load('coach-public/c2/a.jpg'), isNotNull);
      expect(await CoachImageBytes.load('coach-docs/c2/a.jpg'), isNull);
      expect(fetches, 1);
    });

    testWidgets(
      'a small avatar asks for photo_s.jpg and falls back to photo.jpg',
      (tester) async {
        expect(
          CoachImageBytes.smallPhotoOf('coach-public/c2/photo.jpg'),
          'coach-public/c2/photo_s.jpg',
        );
        expect(
          CoachImageBytes.smallPhotoOf('coach-public/c2/media/a.jpg'),
          isNull,
        );
        expect(CoachImageBytes.smallPhotoOf('coach-docs/c2/photo.jpg'), isNull);

        final asked = <String>[];
        CoachImageBytes.lookup = (path) async {
          asked.add(path);
          return path.endsWith('photo_s.jpg') ? Uint8List(1) : Uint8List(2);
        };
        final small = await CoachImageBytes.load(
          'coach-public/c2/photo_s.jpg',
          fallback: 'coach-public/c2/photo.jpg',
        );
        expect(small, hasLength(1));
        expect(asked, ['coach-public/c2/photo_s.jpg']);

        asked.clear();
        CoachImageBytes.reset();
        CoachImageBytes.lookup = (path) async {
          asked.add(path);
          if (path.endsWith('photo_s.jpg')) {
            throw FirebaseException(
              plugin: 'storage',
              code: 'object-not-found',
            );
          }
          return Uint8List(2);
        };
        final full = await CoachImageBytes.load(
          'coach-public/c3/photo_s.jpg',
          fallback: 'coach-public/c3/photo.jpg',
        );
        expect(full, hasLength(2));
        expect(asked, [
          'coach-public/c3/photo_s.jpg',
          'coach-public/c3/photo.jpg',
        ]);
        // A timeout is not a missing file: no second try.
        asked.clear();
        CoachImageBytes.lookup = (path) async {
          asked.add(path);
          throw TimeoutException('slow');
        };
        expect(
          await CoachImageBytes.load(
            'coach-public/c4/photo_s.jpg',
            fallback: 'coach-public/c4/photo.jpg',
          ),
          isNull,
        );
        expect(asked, ['coach-public/c4/photo_s.jpg']);
      },
    );

    testWidgets(
      'CoachPhoto loads the small copy, the header loads the full one',
      (tester) async {
        final asked = <String>[];
        CoachImageBytes.lookup = (path) async {
          asked.add(path);
          return null;
        };
        const url = 'coach-public/c2/photo.jpg';
        await tester.pumpWidget(
          host(const CoachPhoto(name: 'Amal', photoUrl: url)),
        );
        await tester.pump();
        expect(asked, ['coach-public/c2/photo_s.jpg', url]);
        asked.clear();
        CoachImageBytes.reset();
        CoachImageBytes.lookup = (path) async {
          asked.add(path);
          return null;
        };
        await tester.pumpWidget(
          host(const CoachPhoto(name: 'Amal', photoUrl: url, full: true)),
        );
        await tester.pump();
        expect(asked, [url]);
      },
    );

    testWidgets('the picture cache keeps 150 images', (tester) async {
      var fetches = 0;
      CoachImageBytes.lookup = (path) async {
        fetches++;
        return Uint8List(1);
      };
      for (var i = 0; i < 150; i++) {
        await CoachImageBytes.load('coach-public/c$i/photo_s.jpg');
      }
      for (var i = 0; i < 150; i++) {
        await CoachImageBytes.load('coach-public/c$i/photo_s.jpg');
      }
      expect(fetches, 150);
    });

    testWidgets('no media: no sections for members, a note in preview', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(portfolio(MemberRepo()));
      expect(find.text('Results'), findsNothing);
      expect(find.text('Photos'), findsNothing);
      await tester.pumpWidget(portfolio(MemberRepo(), preview: true));
      expect(
        find.text(
          'Nothing approved yet. Photos and results show here after Own Hub checks them.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('preview shows every approved item', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        portfolio(MemberRepo(), media: items, preview: true),
      );
      await tester.pump();
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Report this profile'), findsNothing);
    });

    testWidgets('only approved documents with public files are read', (
      tester,
    ) async {
      expect(
        ApprovedMedia.fromMap('x', {'kind': 'photo', 'status': 'pending'}),
        isNull,
      );
      expect(
        ApprovedMedia.fromMap('x', {'kind': 'photo', 'status': 'approved'}),
        isNull,
      );
      expect(
        ApprovedMedia.fromMap('x', {
          'kind': 'photo',
          'status': 'approved',
          'publicPaths': {'image': 'coach-public/c2/media/x_image.jpg'},
        }),
        isNotNull,
      );
    });

    testWidgets('live view builds from the streams', (tester) async {
      phone(tester);
      final repo = MemberRepo();
      repo.coaches.value = <CoachProfile>[coach('c2', 'Amal')];
      repo.media['c2'] = Feed<List<ApprovedMedia>>(items);
      repo.packages['c2'] = Feed<List<CoachPackage>>(<CoachPackage>[
        pkg('a', 2000),
      ]);
      await tester.pumpWidget(
        host(LiveCoachPortfolioView(coachUid: 'c2', repository: repo)),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Amal'), findsOneWidget);
      expect(find.text('Free for now'), findsOneWidget);
      expect(find.text('Results'), findsOneWidget);
    });
  });

  for (final lang in <String>['en', 'ar']) {
    testWidgets('screens fit at text scale 2.0 ($lang)', (tester) async {
      moneyIsLive();
      phone(tester);
      final repo = seeded();
      await tester.pumpWidget(
        host(FindCoachView(repository: repo), lang: lang, scale: 2),
      );
      await tester.pump();
      final l10n = AppL10n.of(tester.element(find.byType(FindCoachView)));
      await tapText(tester, find.text(l10n.getStronger));
      await tapText(tester, find.text(l10n.atHome));
      await tapText(tester, find.text(l10n.underEgpN('1,500')));
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(FindCoachView))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await tester.pumpWidget(
        portfolio(
          repo,
          lang: lang,
          scale: 2,
          media: const <ApprovedMedia>[
            ApprovedMedia(
              id: 't1',
              kind: MediaKind.transformation,
              weeks: 12,
              note: 'Three sessions a week.',
              beforePath: 'coach-public/c2/b.jpg',
              afterPath: 'coach-public/c2/a.jpg',
            ),
            ApprovedMedia(
              id: 'p1',
              kind: MediaKind.photo,
              caption: 'My studio',
              imagePath: 'coach-public/c2/p.jpg',
            ),
          ],
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tapText(tester, find.text(l10n.askToJoin));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.sendRequest), findsOneWidget);
    });
  }
}
