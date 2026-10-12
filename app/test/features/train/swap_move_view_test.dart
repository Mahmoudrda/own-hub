// R05 — Swap a move.
//
// Two taps, and the list stays visible behind the sheet. The swap must reach the
// session and never the plan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/swap_move_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('offers same-muscle alternatives over the visible list', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SwapMoveView()));
    await tester.pumpAndSettle();

    expect(find.text('Swap this move'), findsOneWidget);
    expect(find.text('Same muscles, quieter on the floor.'), findsOneWidget);
    expect(find.text('No standing, nothing to hold'), findsOneWidget);
    expect(find.text('One leg at a time, holds the weight'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the workout stays visible behind the sheet', (tester) async {
    // The whole reason this is a sheet: she can see what she is changing.
    await tester.pumpWidget(_host(const SwapMoveView()));
    await tester.pumpAndSettle();

    expect(find.text('Legs and glutes'), findsOneWidget);
    expect(find.text('3 × 12 · bodyweight'), findsOneWidget);
  });

  testWidgets('swapping records against the session, and never the plan', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    MoveAlternative? chosen;

    await tester.pumpWidget(
      _host(
        SwapMoveView(
          repository: repository,
          onSwapped: (alternative) => chosen = alternative,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Swap it'));
    await tester.pumpAndSettle();

    expect(repository.swaps, hasLength(1));
    expect(repository.swaps.single.from, 'goblet_squat');
    expect(repository.swaps.single.to, 'glute_bridge');
    expect(chosen?.exerciseId, 'glute_bridge');
    // A swap is for today. Nothing was logged and no plan was touched.
    expect(repository.flushes, isEmpty);
  });

  testWidgets('choosing the other candidate changes what is swapped in', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();

    await tester.pumpWidget(_host(SwapMoveView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Step-back lunge').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Swap it'));
    await tester.pumpAndSettle();

    expect(repository.swaps.single.to, 'step_back_lunge');
  });

  testWidgets('candidates come from data, not from the widget', (tester) async {
    await tester.pumpWidget(
      _host(
        const SwapMoveView(
          alternatives: [
            MoveAlternative(
              exerciseId: 'wall_sit',
              name: 'Wall sit',
              reason: 'Nothing to hold',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wall sit'), findsOneWidget);
    expect(find.text('No standing, nothing to hold'), findsNothing);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const SwapMoveView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('غيّري الحركة دي'), findsOneWidget);
    expect(find.text('نفس العضلات، وأهدى على الأرض.'), findsOneWidget);
    expect(find.text('غيّريها'), findsOneWidget);
    expect(find.text('Swap it'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SwapMoveView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
