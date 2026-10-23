// Home shows what the tier she is looking at holds, and it changes when she
// switches Beginner, Intermediate and Advanced.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/tier_facts.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/features/train/presentation/tier_tabs.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

const _splits = ['split_3day', 'split_4day', 'split_5day'];

TierFacts _facts(
  TrainingLevel viewed,
  TrainingLevel own, {
  int mins = 45,
  String family = 'split_4day',
}) {
  String id(TrainingLevel t) =>
      t == TrainingLevel.beginner ? family : '${family}_${t.wireName}';
  AuthoredSession cut(TrainingLevel t) =>
      scaleSession(StartingProgrammes.programme(id(t))!.sessions.first, mins);
  return TierFacts.of(cut(viewed), own: cut(own), isOwnLevel: viewed == own)!;
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(), child: child),
  ),
);

/// Home with the tier tabs wired the way the router wires them: the tab sets
/// the viewed tier and the facts are worked out again from it.
Widget _home(
  ValueNotifier<TrainingLevel> viewed, {
  TrainingLevel own = TrainingLevel.beginner,
  int? sessionMinutes = 45,
  String family = 'split_4day',
}) => ValueListenableBuilder<TrainingLevel>(
  valueListenable: viewed,
  builder: (context, tier, _) => TodayView(
    repository: InMemoryTodayRepository(
      day: InMemoryTodayRepository.defaultDay(date: _tuesday),
    ),
    mealRepository: InMemoryMealRepository(),
    now: _tuesday,
    sessionMinutes: sessionMinutes,
    tierTabs: TierTabs(selected: tier, onChanged: (t) => viewed.value = t),
    tierFacts: _facts(tier, own, family: family),
    onStartSession: () {},
    onRecall: () {},
    onOpenMeal: () {},
    onOpenPlate: () {},
    onOpenWeek: () {},
    onOpenCycle: () {},
    onAsk: () {},
    onNotifications: () {},
    onSelectTab: (_) {},
  ),
);

/// The start of the facts line for [f], as Home words it.
String _prefix(TierFacts f) =>
    '${f.moves} moves · ${f.setsPerMove} × ${f.repsLabel} · '
    '${f.restSeconds} s rest · About ';

String _line(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('tier-facts-line'))).data!;

void main() {
  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  testWidgets('Home shows the facts line, and the minutes it replaces', (
    tester,
  ) async {
    _phone(tester);
    final viewed = ValueNotifier(TrainingLevel.beginner);
    await tester.pumpWidget(_host(_home(viewed)));
    await tester.pumpAndSettle();

    expect(
      _line(tester),
      startsWith(
        _prefix(_facts(TrainingLevel.beginner, TrainingLevel.beginner)),
      ),
    );
    expect(_line(tester), endsWith(' min'));
    // "45 min" would sit beside "About 35 min", two answers for one session.
    expect(find.text('45 min'), findsNothing);
    expect(find.text('This is your level'), findsOneWidget);
    expect(
      find.text('Compared with your level', findRichText: false),
      findsNothing,
    );
  });

  for (final family in _splits) {
    testWidgets('$family: the facts line changes when the tier tab changes', (
      tester,
    ) async {
      _phone(tester);
      final viewed = ValueNotifier(TrainingLevel.beginner);
      await tester.pumpWidget(_host(_home(viewed, family: family)));
      await tester.pumpAndSettle();
      final lines = <String>[_line(tester)];

      for (final tab in ['Intermediate', 'Advanced']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        lines.add(_line(tester));
      }

      expect(lines.toSet(), hasLength(3), reason: '$lines');
      for (final (i, tier) in TrainingLevel.values.indexed) {
        expect(
          lines[i],
          startsWith(
            _prefix(_facts(tier, TrainingLevel.beginner, family: family)),
          ),
          reason: '$family $tier',
        );
      }
      // Back to her own level: the same line as at the start.
      await tester.tap(find.text('Beginner'));
      await tester.pumpAndSettle();
      expect(_line(tester), lines.first);
    });
  }

  testWidgets('it says what changed against the level she set', (tester) async {
    _phone(tester);
    final viewed = ValueNotifier(TrainingLevel.beginner);
    await tester.pumpWidget(_host(_home(viewed)));
    await tester.pumpAndSettle();

    String deltaText() => tester
        .widget<Text>(find.byKey(const ValueKey('tier-facts-delta')))
        .data!;

    for (final (tab, tier) in [
      ('Intermediate', TrainingLevel.intermediate),
      ('Advanced', TrainingLevel.advanced),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final delta = _facts(tier, TrainingLevel.beginner).versusOwn!;
      expect(deltaText(), startsWith('Compared with your level: '));
      if (delta.restSeconds != 0) {
        expect(
          deltaText(),
          contains(
            '${delta.restSeconds.abs()} s '
            '${delta.restSeconds < 0 ? 'less' : 'more'} rest',
          ),
        );
      }
      if (delta.sets != 0) {
        expect(
          deltaText(),
          contains(delta.sets > 0 ? 'more set' : 'sets less'),
        );
      }
      expect(find.text('This is your level'), findsNothing);
    }
  });

  testWidgets('it reads the other way round for a woman at Advanced', (
    tester,
  ) async {
    _phone(tester);
    final viewed = ValueNotifier(TrainingLevel.advanced);
    await tester.pumpWidget(_host(_home(viewed, own: TrainingLevel.advanced)));
    await tester.pumpAndSettle();
    expect(find.text('This is your level'), findsOneWidget);

    await tester.tap(find.text('Beginner'));
    await tester.pumpAndSettle();
    final delta = tester
        .widget<Text>(find.byKey(const ValueKey('tier-facts-delta')))
        .data!;
    final facts = _facts(
      TrainingLevel.beginner,
      TrainingLevel.advanced,
    ).versusOwn!;
    expect(delta, startsWith('Compared with your level: '));
    expect(facts.isEmpty, isFalse);
    if (facts.restSeconds != 0) {
      expect(
        delta,
        contains(
          '${facts.restSeconds.abs()} s '
          '${facts.restSeconds < 0 ? 'less' : 'more'} rest',
        ),
      );
    }
    expect(facts.sets, lessThanOrEqualTo(0));
  });

  testWidgets('without facts Home shows the minutes as before', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        TodayView(
          repository: InMemoryTodayRepository(
            day: InMemoryTodayRepository.defaultDay(date: _tuesday),
          ),
          mealRepository: InMemoryMealRepository(),
          now: _tuesday,
          sessionMinutes: 45,
          onSelectTab: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tier-facts-line')), findsNothing);
    expect(find.textContaining('45 min'), findsOneWidget);
  });

  testWidgets('Reduce Motion swaps the facts at once', (tester) async {
    _phone(tester);
    final viewed = ValueNotifier(TrainingLevel.beginner);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _home(viewed),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = _line(tester);

    await tester.tap(find.text('Advanced'));
    await tester.pump();
    await tester.pump();
    // One frame later the old line is gone, not fading out beside the new one.
    expect(find.byKey(const ValueKey('tier-facts-line')), findsOneWidget);
    expect(_line(tester), isNot(before));
  });

  testWidgets('the Arabic facts keep Western digits and read right to left', (
    tester,
  ) async {
    _phone(tester);
    final viewed = ValueNotifier(TrainingLevel.intermediate);
    await tester.pumpWidget(_host(_home(viewed), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    final line = _line(tester);
    final f = _facts(TrainingLevel.intermediate, TrainingLevel.beginner);
    expect(line, contains('راحة ${f.restSeconds} ثانية'));
    expect(line, contains('${f.setsPerMove} مجموعات × ${f.repsLabel}'));
    expect(line, contains('حركات'));
    for (final eastern in ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩']) {
      expect(line.contains(eastern), isFalse, reason: eastern);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 2.0 text the facts wrap and nothing overflows', (
    tester,
  ) async {
    _phone(tester);
    final viewed = ValueNotifier(TrainingLevel.advanced);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: _home(viewed),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tier-facts-line')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
