// C04, the tour before sign-up: the real screens with a sample week.
//
// What matters here is that each stop IS the product's own screen, that the
// sample is labelled on every one of them, that the way in is always on
// screen, and that every real action asks her to join instead of doing
// anything. Run with the shipping flags, set explicitly.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/cycle/presentation/cycle_hub_view.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/presentation/rahma_recipe_view.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/features/eat/presentation/week_plan_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view.dart';
import 'package:own_hub/features/signup/demo/demo_sample.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_stops.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// The first release: the gate closed, the product's own features on, the
/// community, the coach app and the assistant off.
final FeatureFlags _launch = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.accountRequired: true,
  Feature.signUp: true,
  Feature.verification: true,
  Feature.today: true,
  Feature.train: true,
  Feature.eat: true,
  Feature.progress: true,
  Feature.cycle: true,
  Feature.privacyCentre: true,
});

late RecipeBook _book;

/// The real screen each stop must be, in order.
const List<Type> _stopTypes = [
  TodayView,
  WorkoutDayView,
  MidSetView,
  RecipesView,
  WeekPlanView,
  CycleHubView,
  ProgressView,
];

Future<DemoSample> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  int initialStop = 0,
  bool waiting = false,
  VoidCallback? onJoin,
  VoidCallback? onLeave,
  VoidCallback? onSignIn,
  ValueChanged<int>? onStopViewed,
  void Function(DemoJoinSource source, int stop)? onJoinFrom,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final sample = DemoSample.build(now: DateTime(2026, 10, 6, 10), book: _book);
  addTearDown(sample.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        // A fresh tour every time, even within one test.
        child: LookAroundView(
          key: UniqueKey(),
          sample: sample,
          initialStop: initialStop,
          waiting: waiting,
          onJoin: onJoin,
          onLeave: onLeave ?? () {},
          onSignIn: onSignIn,
          onStopViewed: onStopViewed,
          onJoinFrom: onJoinFrom,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sample;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A control on the stop itself, never on the tour's own card or bar.
Finder _onStop(Finder finder) => find.descendant(
  of: find.byWidgetPredicate((w) => _stopTypes.contains(w.runtimeType)),
  matching: finder,
);

void main() {
  late FeatureFlags saved;

  setUpAll(() async {
    _book = await SeededRecipeLibrary(
      readAsset: (path) async => File(path).readAsString(),
    ).load();
  });

  setUp(() {
    saved = AppRouter.featureFlags;
    AppRouter.featureFlags = _launch;
  });
  tearDown(() => AppRouter.featureFlags = saved);

  group('the stops are the real screens', () {
    testWidgets('seven stops, each the product widget, then the end card', (
      tester,
    ) async {
      await _pump(tester);
      for (var i = 0; i < _stopTypes.length; i++) {
        expect(
          find.byType(_stopTypes[i]),
          findsOneWidget,
          reason: 'stop ${i + 1}',
        );
        expect(find.text('${i + 1} of 7'), findsOneWidget);
        await _tap(tester, find.text('Next'));
      }
      expect(find.text('That is Own Hub'), findsOneWidget);
      expect(find.text('Make it mine'), findsOneWidget);
      expect(find.text('See the tour again'), findsOneWidget);
      for (final type in _stopTypes) {
        expect(find.byType(type), findsNothing);
      }
    });

    testWidgets('the badge and the way in are on every stop and the end', (
      tester,
    ) async {
      await _pump(tester);
      for (var i = 0; i <= _stopTypes.length; i++) {
        expect(find.text('Sample · nothing is saved'), findsOneWidget);
        expect(find.text('Join Own Hub'), findsOneWidget);
        expect(find.byTooltip('Leave the tour'), findsOneWidget);
        if (i < _stopTypes.length) await _tap(tester, find.text('Next'));
      }
    });

    testWidgets('Home is the sample day, without a programme that does not '
        'exist', (tester) async {
      await _pump(tester);
      expect(find.text('Legs and glutes'), findsOneWidget);
      expect(find.text('This week, 1 of 3'), findsOneWidget);
      expect(find.textContaining('Week 3'), findsNothing);
      expect(find.text('My cycle'), findsOneWidget);
    });

    testWidgets('the player starts on the first set of the first move', (
      tester,
    ) async {
      await _pump(tester, initialStop: 2);
      expect(find.text('Glute bridge'), findsOneWidget);
      expect(find.text('Move 1 of 4'), findsOneWidget);
      // The heading, and the first row of the set list under it.
      expect(find.text('1 of 3'), findsNWidgets(2));
      expect(find.text('2 of 3'), findsOneWidget);
    });

    testWidgets('the week plan says it is a sample, and promises no swap', (
      tester,
    ) async {
      await _pump(tester, initialStop: 4);
      expect(
        find.text('A sample week of five dinners. Join to plan your own.'),
        findsOneWidget,
      );
      expect(find.textContaining('logged before'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('nothing switched off is drawn', (tester) async {
      await _pump(tester);
      for (var i = 0; i < _stopTypes.length; i++) {
        expect(find.text('Community'), findsNothing);
        expect(find.byTooltip('Ask something'), findsNothing);
        await _tap(tester, find.text('Next'));
      }
    });
  });

  group('moving through the tour', () {
    testWidgets('Next and Back walk the stops', (tester) async {
      await _pump(tester);
      expect(find.text('1 of 7'), findsOneWidget);
      expect(find.text('Back'), findsNothing, reason: 'the first stop');

      await _tap(tester, find.text('Next'));
      expect(find.text('2 of 7'), findsOneWidget);
      expect(find.text("Today's workout"), findsOneWidget);

      await _tap(tester, find.text('Back').first);
      expect(find.text('1 of 7'), findsOneWidget);
      expect(find.byType(TodayView), findsOneWidget);
    });

    testWidgets('the bottom bar moves between stops', (tester) async {
      await _pump(tester);
      await _tap(tester, _onStop(find.text('Train')));
      expect(find.byType(WorkoutDayView), findsOneWidget);
      expect(find.text('2 of 7'), findsOneWidget);

      await _pump(tester);
      await _tap(tester, _onStop(find.text('Eat')));
      expect(find.byType(RecipesView), findsOneWidget);
      expect(find.text('4 of 7'), findsOneWidget);

      await _tap(tester, _onStop(find.text('Home')));
      expect(find.byType(TodayView), findsOneWidget);
    });

    testWidgets('the screens own links move the tour too', (tester) async {
      await _pump(tester);
      await _tap(tester, find.text('My cycle'));
      expect(find.byType(CycleHubView), findsOneWidget);

      await _pump(tester);
      await _tap(tester, find.text('This week, 1 of 3'));
      expect(find.byType(ProgressView), findsOneWidget);

      await _pump(tester, initialStop: 3);
      await _tap(tester, find.text("This week's plan and list"));
      expect(find.byType(WeekPlanView), findsOneWidget);
    });

    testWidgets('system back walks back a stop, then leaves', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final sample = DemoSample.build(book: _book);
      addTearDown(sample.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Text('front door'),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => LookAroundView(sample: sample, initialStop: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 of 7'), findsOneWidget);

      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('1 of 7'), findsOneWidget);

      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(LookAroundView), findsNothing);
      expect(find.text('front door'), findsOneWidget);
    });

    testWidgets('"See the tour again" starts over', (tester) async {
      await _pump(tester, initialStop: 7);
      await _tap(tester, find.text('See the tour again'));
      expect(find.text('1 of 7'), findsOneWidget);
    });
  });

  group('the exits', () {
    testWidgets('Join, Make it mine and sign in each call out once', (
      tester,
    ) async {
      var joined = 0;
      var left = 0;
      var signedIn = 0;
      await _pump(
        tester,
        onJoin: () => joined++,
        onLeave: () => left++,
        onSignIn: () => signedIn++,
      );
      await _tap(tester, find.text('Join Own Hub'));
      expect(joined, 1);
      await _tap(tester, find.byTooltip('Leave the tour'));
      expect(left, 1);

      await _pump(
        tester,
        initialStop: 7,
        onJoin: () => joined++,
        onSignIn: () => signedIn++,
      );
      await _tap(tester, find.text('Make it mine'));
      expect(joined, 2);
      await _tap(tester, find.text('I already have an account'));
      expect(signedIn, 1);
    });

    testWidgets('a woman waiting on her check is sent back to it', (
      tester,
    ) async {
      var back = 0;
      await _pump(tester, waiting: true, onJoin: () => back++);
      expect(find.text('Back to my check'), findsOneWidget);
      expect(find.text('Join Own Hub'), findsNothing);

      await _tap(tester, find.text('Count it'));
      expect(
        find.text('The app opens as soon as your check is done.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('Back to my check').last);
      expect(back, 1);

      await _pump(tester, waiting: true, initialStop: 7);
      expect(find.text('I already have an account'), findsNothing);
    });
  });

  group('the funnel, handed out and never reported here', () {
    testWidgets('each stop she reaches, once, from the first', (tester) async {
      final viewed = <int>[];
      await _pump(tester, onStopViewed: viewed.add);
      expect(viewed, [0]);
      for (var i = 0; i < _stopTypes.length; i++) {
        await _tap(tester, find.text('Next'));
      }
      await _tap(tester, find.text('See the tour again'));
      expect(viewed, [0, 1, 2, 3, 4, 5, 6, 7, 0]);

      // A tab that is already the stop moves nothing and counts nothing.
      await _tap(tester, _onStop(find.text('Home')));
      expect(viewed, [0, 1, 2, 3, 4, 5, 6, 7, 0]);
    });

    testWidgets('which Join she tapped, and on which stop', (tester) async {
      final joins = <(DemoJoinSource, int)>[];
      var joined = 0;
      void record(DemoJoinSource source, int stop) => joins.add((source, stop));

      await _pump(
        tester,
        initialStop: 1,
        onJoin: () => joined++,
        onJoinFrom: record,
      );
      await _tap(tester, find.text('Join Own Hub'));

      await _pump(
        tester,
        initialStop: 2,
        onJoin: () => joined++,
        onJoinFrom: record,
      );
      await _tap(tester, find.text('Done · 12 reps'));
      await _tap(tester, find.text('Join Own Hub').last);

      await _pump(
        tester,
        initialStop: 7,
        onJoin: () => joined++,
        onJoinFrom: record,
      );
      await _tap(tester, find.text('Make it mine'));

      expect(joins, [
        (DemoJoinSource.bar, 1),
        (DemoJoinSource.sheet, 2),
        (DemoJoinSource.end, 7),
      ]);
      expect(joined, 3, reason: 'each one still joins');
    });
  });

  group('every real action asks her to join', () {
    // Stop, then the control. Each one is a real action on the real screen.
    final triggers = <(int, String, Finder Function())>[
      (0, 'count the walk', () => find.text('Count it')),
      (0, 'log from memory', () => _onStop(find.text('I already did it'))),
      (0, 'the meal', () => find.text('Breakfast')),
      (0, 'a plate', () => find.text('Ful and baladi')),
      (0, 'notifications', () => find.byTooltip('Notifications')),
      (0, 'her profile', () => find.bySemanticsLabel('Your profile')),
      (0, 'her first week', () => find.text('Your first week')),
      (1, 'start', () => find.text("Start, everything's ready")),
      (1, 'already did it', () => _onStop(find.text('I already did it'))),
      (1, 'a move', () => find.text('Glute bridge')),
      (1, 'more', () => _onStop(find.byTooltip('More'))),
      (2, 'log a set', () => find.text('Done · 12 reps')),
      (2, 'log the move', () => find.text('I did all 3 sets')),
      (2, 'pause', () => find.byTooltip('Pause')),
      (2, 'change the set', () => find.text('Change')),
      (3, 'another recipe', () => find.text('Koshari, portioned')),
      (3, 'another of hers', () => find.text('Pancakes')),
      (3, 'search', () => find.byTooltip('Search recipes')),
      (3, 'her letter', () => find.text('A message from Rahma')),
      (4, 'a dinner', () => find.text('Molokhia with chicken')),
      (4, 'rearrange', () => find.byTooltip('Rearrange the week')),
      (4, 'the grocery list', () => find.text('See the grocery list')),
      (5, 'check in', () => find.text('How are you feeling?')),
      (5, 'settings', () => find.byTooltip('Cycle settings')),
      (5, 'the calendar', () => find.text('Calendar')),
      (5, 'patterns', () => find.text('Patterns')),
      (6, 'milestones', () => find.text('Milestones')),
      (6, 'bests', () => find.text('Bests')),
      (6, 'her first week', () => find.text('Your first week')),
      (6, 'rest week', () => find.text('What a rest week covers')),
      (6, 'tier slip', () => find.text('If a tier slips')),
    ];

    for (final (stop, what, finder) in triggers) {
      testWidgets('stop ${stop + 1}: $what', (tester) async {
        final sample = await _pump(tester, initialStop: stop);
        final title = DemoStop.values[stop].title(
          lookupAppL10n(const Locale('en')),
        );

        await _tap(tester, finder().first);
        expect(find.text('Join to make this yours'), findsOneWidget);
        expect(
          find.text('Join Own Hub'),
          findsNWidgets(2),
          reason: 'the bar and the sheet',
        );

        await _tap(tester, find.text('Keep looking'));
        expect(find.text('Join to make this yours'), findsNothing);
        expect(find.text(title), findsWidgets, reason: 'still on the stop');
        expect(find.byType(_stopTypes[stop]), findsOneWidget);
        expect(sample.train.sessions, isEmpty);
        expect(sample.train.flushes, isEmpty);
        expect(sample.meal.writes, isEmpty);
      });
    }

    testWidgets('counting the walk leaves the sample day as it was', (
      tester,
    ) async {
      final sample = await _pump(tester);
      await _tap(tester, find.text('Count it'));
      await _tap(tester, find.text('Keep looking'));
      expect(find.text('Count it'), findsOneWidget);
      expect(sample.today.day.walkToCount, isTrue);
      expect(sample.refusals.count, 0, reason: 'nothing was even tried');
    });

    testWidgets('the sheet opens once, however many things ask', (
      tester,
    ) async {
      await _pump(tester, initialStop: 2);
      await _tap(tester, find.text('Done · 12 reps'));
      expect(find.text('Join to make this yours'), findsOneWidget);
    });

    testWidgets('the sheet joins', (tester) async {
      var joined = 0;
      await _pump(tester, onJoin: () => joined++);
      await _tap(tester, find.text('Count it'));
      await _tap(tester, find.text('Join Own Hub').last);
      expect(joined, 1);
      expect(find.text('Join to make this yours'), findsNothing);
    });
  });

  group("Rahma's first recipe", () {
    testWidgets('opens in full, still labelled, and back returns to the tour', (
      tester,
    ) async {
      await _pump(tester, initialStop: 3);
      final first = firstBookRecipe(_book)!;
      await _tap(tester, find.text(first.titleEn));

      expect(find.byType(RahmaRecipeView), findsOneWidget);
      expect(find.text('Sample · nothing is saved'), findsOneWidget);
      expect(find.text('Join Own Hub'), findsOneWidget);

      await _tap(tester, find.byIcon(Icons.share));
      expect(find.text('Join to make this yours'), findsOneWidget);
      await _tap(tester, find.text('Keep looking'));

      await _tap(tester, find.byTooltip('Back').first);
      expect(find.byType(RahmaRecipeView), findsNothing);
      expect(find.byType(RecipesView), findsOneWidget);
    });
  });

  group('the recipes stop', () {
    testWidgets('the bundled seed loads in the tour', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      // No book handed in: the tour reads the seed on the phone itself.
      final sample = DemoSample.build(now: DateTime(2026, 10, 6, 10));
      addTearDown(sample.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: LookAroundView(
            sample: sample,
            initialStop: DemoStop.recipes.index,
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && sample.book == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();

      expect(sample.book, isNotNull);
      expect(firstBookRecipe(sample.book), isNotNull);
      expect(
        find.text(
          'Home cooking you already know, written by coach Rahma Mohsen. '
          'Open the first recipe to see one in full.',
        ),
        findsOneWidget,
      );
    });
  });

  group('in Arabic, and at large text', () {
    testWidgets('lays out right to left', (tester) async {
      await _pump(tester, locale: const Locale('ar'));
      expect(find.text('عيّنة · لا يُحفظ شيء'), findsOneWidget);
      expect(find.text('انضمّي إلى Own Hub'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('الرئيسية، يومكِ في لمحة'))),
        TextDirection.rtl,
      );
    });

    testWidgets('Progress is named to her, in the feminine', (tester) async {
      await _pump(tester, locale: const Locale('ar'), initialStop: 6);
      expect(find.text('تقدّمكِ'), findsWidgets);
      expect(find.text('تقدّمك'), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('no stop overflows at twice the text size, '
          '${locale.languageCode}', (tester) async {
        for (var stop = 0; stop <= _stopTypes.length; stop++) {
          await _pump(
            tester,
            locale: locale,
            textScale: 2.0,
            initialStop: stop,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'stop ${stop + 1} at 2.0',
          );
        }
      });
    }
  });
}
