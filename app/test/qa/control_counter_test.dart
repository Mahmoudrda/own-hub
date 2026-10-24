// The counter behind the screen budgets, on small synthetic trees.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/app_list_item.dart';
import 'package:own_hub/ui/app_segmented.dart';
import 'package:own_hub/ui/app_stat_hero.dart';
import 'package:own_hub/ui/hand/hand.dart';

import '../helpers/control_counter.dart';

Future<int> _count(WidgetTester tester, List<Widget> children) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Column(children: children)),
      ),
    ),
  );
  return countControlsAboveFold(tester);
}

AppListItem _row(String t, {Widget? trailing}) =>
    AppListItem(title: t, trailing: trailing, onTap: () {});

void main() {
  testWidgets('a button is one control', (tester) async {
    expect(
      await _count(tester, [
        TextButton(onPressed: () {}, child: const Text('a')),
      ]),
      1,
    );
  });

  testWidgets('an icon button is one control', (tester) async {
    expect(
      await _count(tester, [
        IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
      ]),
      1,
    );
  });

  testWidgets('a pressable is one control', (tester) async {
    expect(
      await _count(tester, [
        HandPressable(
          onTap: () {},
          builder: (_, _) =>
              const SizedBox(height: 40, width: 100, child: Text('a')),
        ),
      ]),
      1,
    );
  });

  testWidgets('adjacent rows are one control', (tester) async {
    expect(
      await _count(tester, [
        _row('a'),
        const SizedBox(height: 8),
        _row('b'),
        _row('c'),
      ]),
      1,
    );
  });

  testWidgets('a button between rows splits the list in two', (tester) async {
    expect(
      await _count(tester, [
        _row('a'),
        TextButton(onPressed: () {}, child: const Text('x')),
        _row('b'),
      ]),
      3,
    );
  });

  testWidgets('a trailing button in a row counts on its own', (tester) async {
    expect(
      await _count(tester, [
        _row(
          'a',
          trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ),
      ]),
      2,
    );
  });

  testWidgets('a trailing pressable in a row counts on its own', (
    tester,
  ) async {
    expect(
      await _count(tester, [
        _row(
          'a',
          trailing: HandPressable(
            onTap: () {},
            builder: (_, _) => const SizedBox(width: 40, height: 40),
          ),
        ),
      ]),
      2,
    );
  });

  testWidgets('a link inside a tappable card counts on its own', (
    tester,
  ) async {
    expect(
      await _count(tester, [
        HandPressable(
          onTap: () {},
          builder: (_, _) => Column(
            children: [
              const Text('Today'),
              InkWell(onTap: () {}, child: const Text('Change')),
            ],
          ),
        ),
      ]),
      2,
    );
  });

  testWidgets('a bare InkWell is one control, not two', (tester) async {
    expect(
      await _count(tester, [
        InkWell(onTap: () {}, child: const SizedBox(height: 40, width: 100)),
      ]),
      1,
    );
  });

  testWidgets('segments are one control', (tester) async {
    expect(
      await _count(tester, [
        AppSegmented(
          items: const ['a', 'b'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
      ]),
      1,
    );
  });

  testWidgets('a switch is one control', (tester) async {
    expect(await _count(tester, [Switch(value: false, onChanged: (_) {})]), 1);
  });

  testWidgets('chips are one control each', (tester) async {
    expect(
      await _count(tester, [
        ActionChip(label: const Text('a'), onPressed: () {}),
        ChoiceChip(label: const Text('b'), selected: false, onSelected: (_) {}),
        FilterChip(label: const Text('c'), selected: false, onSelected: (_) {}),
      ]),
      3,
    );
  });

  testWidgets('a plain chip is not a control', (tester) async {
    expect(await _count(tester, [const Chip(label: Text('a'))]), 0);
  });

  testWidgets('a text field is one control', (tester) async {
    expect(await _count(tester, [const TextField()]), 1);
  });

  testWidgets('a heading between rows splits the list in two', (tester) async {
    expect(
      await _count(tester, [_row('a'), const Text('Heading'), _row('b')]),
      2,
    );
  });

  testWidgets('a pressable among lazily built rows counts on its own', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: TextButton(onPressed: () {}, child: const Text('x')),
              ),
              SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) => i == 1
                    ? HandPressable(
                        onTap: () {},
                        builder: (_, _) => const SizedBox(height: 40),
                      )
                    : _row('r$i'),
              ),
            ],
          ),
        ),
      ),
    );
    // The button, the first row, the pressable, the last row.
    expect(countControlsAboveFold(tester), 4);
  });

  group('hero figures', () {
    Future<void> pumpHero(WidgetTester tester, AppStatHero hero) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: hero)));

    testWidgets('count one per figure, not one per digit', (tester) async {
      await pumpHero(
        tester,
        AppStatHero(
          hero: AppStat(value: '2 of 3', label: 'Sessions this week'),
          others: [
            AppStat(value: '32', label: 'Minutes'),
            AppStat(value: '12', label: 'Sets'),
          ],
        ),
      );
      expect(countHeroFigures(tester), 3);
    });

    testWidgets('ignore labels and anything outside the hero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppStatHero(
                  hero: const AppStat(value: '5', label: 'Sessions'),
                ),
                const Text('Next time: 14 kg'),
              ],
            ),
          ),
        ),
      );
      expect(countHeroFigures(tester), 1);
    });

    testWidgets('read Arabic-Indic digits too', (tester) async {
      await pumpHero(
        tester,
        AppStatHero(
          hero: AppStat(value: '٢ من ٣', label: 'تمارين'),
        ),
      );
      expect(countHeroFigures(tester), 1);
    });
  });
}
