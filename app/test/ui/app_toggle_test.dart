// The switch.
//
// Phase 2's settings screens are mostly rows of these, and several of them
// govern who can see a woman's cycle data — so "which way is on" has to be
// unambiguous, announced, and correct in both reading directions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_toggle.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Scaffold(body: Center(child: child)),
  );
}

AnimatedAlign _knobAlign(WidgetTester tester) => tester.widget<AnimatedAlign>(
  find.descendant(
    of: find.byType(AppToggle),
    matching: find.byType(AnimatedAlign),
  ),
);

void main() {
  group('it looks like the design says', () {
    testWidgets('the track is the prototype size, to the pixel', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppToggle(value: false)));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppToggle)), const Size(52, 32));
    });

    testWidgets('on and off differ by position, not only by colour', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppToggle(value: false)));
      await tester.pumpAndSettle();
      expect(_knobAlign(tester).alignment, AlignmentDirectional.centerStart);

      await tester.pumpWidget(_host(const AppToggle(value: true)));
      await tester.pumpAndSettle();
      expect(_knobAlign(tester).alignment, AlignmentDirectional.centerEnd);
    });
  });

  group('it mirrors in Arabic', () {
    testWidgets('the knob is placed directionally, so RTL flips it', (
      tester,
    ) async {
      // Asserted by TYPE rather than by pixel position: AlignmentDirectional
      // mirrors by construction, a raw Alignment silently does not. Pinning the
      // type is what stops someone "simplifying" this to Alignment.centerRight
      // and leaving every switch in the product unmirrored for Arabic readers.
      await tester.pumpWidget(
        _host(const AppToggle(value: true), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(_knobAlign(tester).alignment, isA<AlignmentDirectional>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('and renders at the same size', (tester) async {
      await tester.pumpWidget(
        _host(const AppToggle(value: false), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppToggle)), const Size(52, 32));
    });
  });

  group('tapping', () {
    testWidgets('reports the flipped value, not the current one', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(AppToggle(value: false, onChanged: changes.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(changes, [true]);
    });

    testWidgets('anywhere on the track counts, not just the knob', (
      tester,
    ) async {
      // She is tapping a 52×32 target one-handed. Requiring the 16px knob
      // would make the off state harder to turn on than the on state is to
      // turn off.
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(AppToggle(value: false, onChanged: changes.add)),
      );
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byType(AppToggle));
      // The far end of the track, away from where the knob sits when off.
      await tester.tapAt(Offset(box.right - 4, box.center.dy));
      await tester.pumpAndSettle();
      expect(changes, [true]);
    });

    testWidgets('does nothing when there is no handler', (tester) async {
      await tester.pumpWidget(_host(const AppToggle(value: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('assistive technology', () {
    testWidgets('is told the state, not left to infer it from colour', (
      tester,
    ) async {
      // Matched by declared property rather than by position — the same
      // approach the nav bar test uses, and for the same reason: there are
      // several Semantics ancestors and .first/.last picks a framework wrapper.
      Future<bool?> declaredToggle(bool value) async {
        await tester.pumpWidget(_host(AppToggle(value: value)));
        await tester.pumpAndSettle();
        final nodes = find
            .descendant(
              of: find.byType(AppToggle),
              matching: find.byType(Semantics),
            )
            .evaluate()
            .map((e) => (e.widget as Semantics).properties)
            .where((p) => p.toggled != null);
        return nodes.isEmpty ? null : nodes.first.toggled;
      }

      expect(await declaredToggle(true), isTrue);
      expect(await declaredToggle(false), isFalse);
    });

    testWidgets('a disabled switch still announces its state', (tester) async {
      // "Off" and "you may not change this" are different facts, and a woman
      // reading with a screen reader needs both.
      await tester.pumpWidget(_host(const AppToggle(value: true)));
      await tester.pumpAndSettle();

      final props = find
          .descendant(
            of: find.byType(AppToggle),
            matching: find.byType(Semantics),
          )
          .evaluate()
          .map((e) => (e.widget as Semantics).properties)
          .firstWhere((p) => p.toggled != null);

      expect(props.toggled, isTrue);
      expect(props.enabled, isFalse);
    });

    testWidgets('carries a label when it stands alone', (tester) async {
      await tester.pumpWidget(
        _host(const AppToggle(value: false, semanticLabel: 'Blur faces')),
      );
      await tester.pumpAndSettle();

      final props = find
          .descendant(
            of: find.byType(AppToggle),
            matching: find.byType(Semantics),
          )
          .evaluate()
          .map((e) => (e.widget as Semantics).properties)
          .firstWhere((p) => p.label != null);

      expect(props.label, 'Blur faces');
    });
  });
}
