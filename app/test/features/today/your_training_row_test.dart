// Home's "Your training" row: one line of her split and level, and a tap that
// opens the quick sheet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/features/train/presentation/training_quick_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _home({
  VoidCallback? onChangeTraining,
  String? trainingLine,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: TodayView(
    repository: InMemoryTodayRepository(
      day: InMemoryTodayRepository.defaultDay(date: _tuesday),
    ),
    mealRepository: InMemoryMealRepository(),
    now: _tuesday,
    onChangeTraining: onChangeTraining,
    trainingLine: trainingLine,
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

void main() {
  const row = ValueKey('today-your-training');

  testWidgets('no callback, no row', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_home());
    await tester.pumpAndSettle();
    expect(find.byKey(row), findsNothing);
  });

  testWidgets('the row shows her answers in one line and a tap calls back', (
    tester,
  ) async {
    _phone(tester);
    var taps = 0;
    final line = trainingSummaryLine(
      await _en(),
      Intake.defaults.copyWith(
        days: 4,
        goal: TrainingGoal.buildMuscle,
        level: TrainingLevel.intermediate,
      ),
    );
    expect(line, 'Split · 4 days · Intermediate');
    await tester.pumpWidget(
      _home(onChangeTraining: () => taps++, trainingLine: line),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your training'), findsOneWidget);
    expect(find.text('Split · 4 days · Intermediate'), findsOneWidget);
    await tester.tap(find.byKey(row));
    expect(taps, 1);
  });
}

Future<AppL10n> _en() => AppL10n.delegate.load(const Locale('en'));
