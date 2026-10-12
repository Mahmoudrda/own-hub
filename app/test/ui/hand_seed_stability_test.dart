// A card's sketch must not depend on the name of a Dart type.
//
// Release builds are obfuscated, which renames types: anything seeded from
// `runtimeType.toString()` would be drawn one way in debug and another in each
// release. These tests pin the seed to names written down as literals.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_card.dart';
import 'package:own_hub/ui/hand/hand.dart';

class _QuietlyNamedA extends StatelessWidget {
  const _QuietlyNamedA();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _EntirelyDifferentName extends StatelessWidget {
  const _EntirelyDifferentName();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _Named extends StatelessWidget implements HandSeedName {
  const _Named();
  @override
  String get handSeedName => 'Row';
  @override
  Widget build(BuildContext context) => const SizedBox();
}

Future<int> _seedOf(WidgetTester tester, List<Widget> children) async {
  late int seed;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) {
          seed = handSeedForChildren(context, children, 0);
          return const SizedBox();
        },
      ),
    ),
  );
  return seed;
}

void main() {
  testWidgets('two unnamed widgets seed the same, whatever they are called', (
    tester,
  ) async {
    final a = await _seedOf(tester, const [_QuietlyNamedA(), Text('Hi')]);
    final b = await _seedOf(tester, const [
      _EntirelyDifferentName(),
      Text('Hi'),
    ]);
    expect(a, b, reason: 'a renamed type must not redraw the card');
    expect(handSeedNameOf(const _QuietlyNamedA()), kHandSeedFallbackName);
  });

  testWidgets('the seed is built from literal names, as debug drew it', (
    tester,
  ) async {
    final seed = await _seedOf(tester, const [
      Text('Your week'),
      Row(children: []),
      AppCard(children: []),
    ]);
    // What the old runtimeType-based seed produced in debug for these
    // children, written out by hand: screen, salt, count, then name and text.
    expect(
      seed,
      handSeed(<Object?>[null, 0, 3, 'Text', 'Your week', 'Row', 'AppCard']),
    );
  });

  testWidgets('a widget that names itself is seeded by that name', (
    tester,
  ) async {
    final named = await _seedOf(tester, const [_Named()]);
    final row = await _seedOf(tester, const [Row(children: [])]);
    expect(named, row);
  });

  test('every app widget that sits in a card names itself literally', () {
    expect(handSeedNameOf(AppButton('Go', onPressed: () {})), 'AppButton');
    expect(handSeedNameOf(const Center(child: SizedBox())), 'Center');
    expect(handSeedNameOf(const Align(child: SizedBox())), 'Align');
    expect(handSeedNameOf(const Expanded(child: SizedBox())), 'Expanded');
  });

  test('the seed source never reads a type name', () {
    // A guard against the old line coming back.
    for (final path in [
      'lib/ui/app_card.dart',
      'lib/ui/hand/hand_seed_name.dart',
    ]) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('runtimeType'),
        isFalse,
        reason: '$path must not seed from runtimeType',
      );
    }
  });
}
