// The tier tabs on Train show the same facts under the tabs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/tier_facts.dart';
import 'package:own_hub/features/train/presentation/tier_tabs.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

const _facts = TierFacts(
  moves: 8,
  setsPerMove: 4,
  repsLabel: '10',
  restSeconds: 70,
  estimatedMinutes: 40,
  versusOwn: TierDelta(sets: 1, restSeconds: -20, moves: 2, minutes: 5),
);

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('the facts sit under the tabs, with what changed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const TierTabs(selected: TrainingLevel.intermediate, facts: _facts),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('8 moves · 4 × 10 · 70 s rest · About 40 min'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Compared with your level: 1 more set · 20 s less rest · '
        '2 more moves · 5 min longer',
      ),
      findsOneWidget,
    );
    final tabs = tester.getRect(find.text('Intermediate')).bottom;
    final line = tester
        .getRect(find.byKey(const ValueKey('tier-facts-line')))
        .top;
    expect(line, greaterThan(tabs));
  });

  testWidgets('without facts the tabs stand alone', (tester) async {
    await tester.pumpWidget(
      _host(const TierTabs(selected: TrainingLevel.beginner)),
    );
    expect(find.byKey(const ValueKey('tier-facts-line')), findsNothing);
  });

  testWidgets('a negative step reads as less, in Arabic too', (tester) async {
    const less = TierFacts(
      moves: 6,
      setsPerMove: 3,
      repsLabel: '10',
      restSeconds: 90,
      estimatedMinutes: 30,
      versusOwn: TierDelta(sets: -2, restSeconds: 50, moves: -3, minutes: -10),
    );
    await tester.pumpWidget(
      _host(
        const TierTabs(selected: TrainingLevel.beginner, facts: less),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'مقارنة بمستواك: مجموعتين أقل · راحة أطول بـ50 ثانية · '
        '3 حركات أقل · أقصر بـ10 دقايق',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
