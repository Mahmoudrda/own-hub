// E03 — Say it. Implements P0-LOG-08.
//
// From TEST-CASES.csv: "Transcript shown before saving so a misheard word is
// visible. Interface stays in the app's voice; speech input accepts dialect."
//
// **This file runs in Arabic by default**, because that is the configuration
// the case is about: a woman reading the app's own chrome and speaking
// Egyptian dialect into it. Running it in English would test a pairing the case
// does not describe, and would need the food pack to carry cross-locale aliases
// it does not have yet (see `eat_sample_library.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/say_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);

/// Egyptian dialect, as she would actually say it.
const String _dialect = 'كشري و بيض';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('ar'),
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

SayItView _sayIt({
  String? transcript,
  MealRepository? repository,
  LogCommandBus? bus,
  ValueChanged<LogHandle>? onLogged,
}) {
  return SayItView(
    constraints: DietaryConstraints.none,
    repository: repository,
    bus: bus,
    now: _lunchtime,
    initialTranscript: transcript,
    onLogged: onLogged,
    onClose: () {},
    onTypeInstead: () {},
  );
}

void main() {
  group('P0-LOG-08 — the transcript is shown before saving', () {
    testWidgets('her words are on screen before anything is written', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_sayIt(transcript: _dialect)));
      await tester.pumpAndSettle();

      expect(find.text('سمعنا ده'), findsOneWidget);
      expect(find.text(_dialect), findsOneWidget);
      expect(find.text('يبقى هنضيف'), findsOneWidget);
    });

    testWidgets('the dialect resolves into two editable rows', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_sayIt(transcript: _dialect)));
      await tester.pumpAndSettle();

      expect(find.text('طبق كشري'), findsOneWidget);
      expect(find.text('بيض مسلوق'), findsOneWidget);
      // Sizes are adjustable here exactly as on E02.
      expect(find.text('وسط'), findsOneWidget);
    });

    testWidgets('confirming writes it, after the undo window', (tester) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();
      final handles = <LogHandle>[];

      await tester.pumpWidget(
        _host(
          _sayIt(
            transcript: _dialect,
            repository: repository,
            bus: bus,
            onLogged: handles.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ضيفيه'));
      await tester.pump();

      expect(handles, hasLength(1));
      expect(repository.writes, isEmpty, reason: 'inside the undo window');

      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes, hasLength(1));
      expect(repository.writes.single.added, hasLength(2));
      // The spine's enum, unchanged — voice is a `source`.
      expect(repository.writes.single.added.first.source, MealSource.voice);
      expect(repository.writes.single.added.first.origin, MealOrigin.voice);

      bus.dispose();
    });

    testWidgets('with no transcript there is nothing to confirm', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository();

      await tester.pumpWidget(_host(_sayIt(repository: repository)));
      await tester.pumpAndSettle();

      // No transcript card at all — the screen does not invent one.
      expect(find.text(_dialect), findsNothing);
      expect(find.text('يبقى هنضيف'), findsNothing);

      // And the confirm button does nothing, so she cannot save unheard words.
      await tester.tap(find.text('ضيفيه'));
      await tester.pump(const Duration(seconds: 6));
      expect(repository.writes, isEmpty);
    });

    testWidgets('removing a misheard row keeps the rest loggable', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();

      await tester.pumpWidget(
        _host(_sayIt(transcript: _dialect, repository: repository, bus: bus)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ضيفيه'));
      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes.single.added, hasLength(1));
      expect(repository.writes.single.added.single.foodId, 'koshari_bowl');

      bus.dispose();
    });
  });

  group('the interface stays in the app\'s voice while the speech is dialect', () {
    testWidgets(
      'her words are hers; everything around them is the dictionary',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(_host(_sayIt(transcript: _dialect)));
        await tester.pumpAndSettle();

        // Her words, as spoken.
        expect(find.text(_dialect), findsOneWidget);
        // The chrome, from the ARB.
        expect(find.text('سمعنا ده'), findsOneWidget);
        expect(find.text('يبقى هنضيف'), findsOneWidget);
        expect(find.text('We heard this'), findsNothing);
      },
    );

    testWidgets('the layout mirrors', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_sayIt(transcript: _dialect)));
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('سمعنا ده'))),
        TextDirection.rtl,
      );
    });

    testWidgets('numbers stay Western in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_sayIt(transcript: _dialect)));
      await tester.pumpAndSettle();

      // The figures are on the rows now, each computed from the size that row
      // has selected. The footer button used to carry "696" — the total of the
      // prototype's koshari-and-two-eggs sentence — whatever the recogniser
      // had heard, which is what this assertion used to read.
      expect(find.textContaining('540'), findsOneWidget);
      expect(find.textContaining('٥٤٠'), findsNothing);
    });

    testWidgets('does not overflow at the largest text size', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_sayIt(transcript: _dialect), textScale: 1.6),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the screen reads in English too', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_sayIt(), locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('We heard this'), findsOneWidget);
      expect(find.text('Say it again'), findsOneWidget);
    });
  });

  group('tier 2 is off, so refusal is a real path', () {
    testWidgets('tapping the microphone refuses clearly and offers typing', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_sayIt()));
      await tester.pumpAndSettle();

      expect(find.text('قوليها تاني'), findsOneWidget);

      await tester.tap(find.text('قوليها تاني'));
      await tester.pumpAndSettle();

      // No spinner. A reason, and the keyboard.
      expect(
        find.text('محتاجين الميكروفون عشان نسمع أكلتي إيه.'),
        findsOneWidget,
      );
      expect(find.text('قولي أو اكتبي أكلتي إيه'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('P1-RULE-09', () {
    testWidgets('confirming a transcript raises no dialog', (tester) async {
      _phone(tester);
      final bus = LogCommandBus();

      await tester.pumpWidget(_host(_sayIt(transcript: _dialect, bus: bus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ضيفيه'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('تراجعي'), findsOneWidget);

      bus.dispose();
    });
  });
}
