// The counter behind the screen budgets, on small synthetic trees.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart'
    show PlusButton;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/app_list_item.dart';
import 'package:own_hub/ui/app_segmented.dart';
import 'package:own_hub/ui/app_stat_hero.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:own_hub/ui/language_switch.dart';

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

  testWidgets('a row and its own plus are one control', (tester) async {
    expect(
      await _count(tester, [
        _row(
          'Koshari',
          trailing: PlusButton(label: 'Add', onPressed: () {}),
        ),
      ]),
      1,
    );
  });

  testWidgets('a plus in a row with no tap is a control of its own', (
    tester,
  ) async {
    expect(
      await _count(tester, [
        AppListItem(
          title: 'Koshari',
          trailing: PlusButton(label: 'Add', onPressed: () {}),
        ),
      ]),
      1,
    );
  });

  testWidgets('a plus outside a row is a control of its own', (tester) async {
    expect(
      await _count(tester, [
        _row('Koshari'),
        PlusButton(label: 'Add', onPressed: () {}),
      ]),
      2,
    );
  });

  testWidgets('plus rows still group, and a plain trailing button does not', (
    tester,
  ) async {
    expect(
      await _count(tester, [
        _row(
          'a',
          trailing: PlusButton(label: 'Add', onPressed: () {}),
        ),
        _row(
          'b',
          trailing: PlusButton(label: 'Add', onPressed: () {}),
        ),
        _row(
          'c',
          trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        ),
      ]),
      2,
    );
  });

  testWidgets('includeChrome: false leaves the top bar out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              AppChrome(inStrip: true),
              TextButton(onPressed: () {}, child: const Text('x')),
            ],
          ),
        ),
      ),
    );
    final withChrome = countControlsAboveFold(tester);
    expect(withChrome, greaterThan(1));
    expect(countControlsAboveFold(tester, includeChrome: false), 1);
  });

  testWidgets('the caret handle after a tap is not a control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(controller: TextEditingController())),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 500));
    expect(countControlsAboveFold(tester), 1);
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
