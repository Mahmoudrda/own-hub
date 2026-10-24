import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_stat_hero.dart';

Widget _host(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  double scale = 1,
}) => MaterialApp(
  theme: buildTheme(const Locale('en')),
  builder: (context, c) => Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
  ),
  home: Scaffold(body: SizedBox(width: 300, child: child)),
);

void main() {
  final stat = AppStatHero(
    hero: const AppStat(value: '42', label: 'minutes'),
    others: const [
      AppStat(value: '12', label: 'sets'),
      AppStat(value: '3', label: 'records'),
      AppStat(value: '1,240', label: 'kcal'),
    ],
  );

  testWidgets('shows the hero and its figures', (tester) async {
    await tester.pumpWidget(_host(stat));
    for (final t in ['42', 'minutes', '12', '3', '1,240', 'kcal']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('RTL and the largest text do not overflow', (tester) async {
    await tester.pumpWidget(_host(stat, dir: TextDirection.rtl, scale: 2));
    expect(tester.takeException(), isNull);
  });

  test('a fourth small figure is refused', () {
    expect(
      () => AppStatHero(
        hero: const AppStat(value: '1', label: 'a'),
        others: List.filled(4, const AppStat(value: '1', label: 'b')),
      ),
      throwsAssertionError,
    );
  });
}
