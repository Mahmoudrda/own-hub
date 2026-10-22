// QA crawler: every control on every screen, tapped once.
//
// Boots the real app (OwnHubApp — its locale and role scopes included), opens
// each routed screen on top of Home through the real router, finds every node
// a screen reader could activate (a semantics node with a tap action), and
// taps them one at a time on a freshly opened screen. Each tap is recorded as
// what it visibly did: opened another screen, went back, opened a sheet or a
// dialog, offered undo, changed what the page says or what is selected — or
// threw, landed on a placeholder, or did nothing anyone could see.
//
// It fails only on what is never acceptable — an exception, or a tap that
// lands on "not built yet" — and writes the full log to the file named by the
// OWNHUB_QA_REPORT environment variable, so the rest can be read by a person.
@Tags(['qa'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/screen_scope.dart';

String? _top(WidgetTester t) {
  final scopes = t.widgetList<ScreenScope>(find.byType(ScreenScope)).toList();
  return scopes.isEmpty ? null : scopes.last.screenId;
}

/// What the page says and what is selected, toggled or checked on it.
String _state(WidgetTester t) {
  final out = StringBuffer();
  for (final n in find.semantics.byPredicate((_) => true).evaluate()) {
    final d = n.getSemanticsData();
    out
      ..write(d.label)
      ..write('|')
      ..write(d.value)
      ..write('|')
      ..write(d.flagsCollection.isSelected)
      ..write(d.flagsCollection.isToggled)
      ..write(d.flagsCollection.isChecked)
      ..write(';');
  }
  return out.toString();
}

String _labelOf(SemanticsNode n) {
  final d = n.getSemanticsData();
  final parts = [d.label, d.tooltip, d.hint].where((s) => s.trim().isNotEmpty);
  final s = parts.join(' / ').replaceAll('\n', ' ');
  return s.isEmpty
      ? '(unlabelled)'
      : (s.length > 60 ? '${s.substring(0, 60)}…' : s);
}

Future<void> _settle(WidgetTester t) async {
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {
    // A long animation is not a defect here; the crawl moves on.
  }
}

/// Home, with [route] opened on top of it.
Future<bool> _open(WidgetTester t, String route) async {
  await t.pumpWidget(OwnHubApp(key: UniqueKey()));
  await _settle(t);
  t.state<NavigatorState>(find.byType(Navigator).first).pushNamed(route);
  await _settle(t);
  return t.takeException() == null;
}

const _skip = {
  'Home',
  'Train',
  'Community',
  'Eat',
  'Insights',
  'Today',
  'Clients',
  'Chats',
  'Earnings',
  'Back',
  'ارجعي',
};

/// Rows on the old demo coach screens that open a screen coaching no longer
/// routes (K05 getting paid, K04 offers). Both screens are dark in this
/// release (payments, the portfolio flag), so no woman can tap them.
const _retiredDoors = {'K17', 'B06'};

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  final log = StringBuffer();
  final hard = <String>[];

  final flows = <String, List<String>>{};
  for (final e in appDestinations.entries) {
    flows.putIfAbsent(e.value.flow, () => []).add(e.key);
  }

  for (final flow in flows.keys) {
    testWidgets('crawl $flow', (tester) async {
      // Everything on, and no account required — the state the owner tests.
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        for (final f in Feature.values) f: f != Feature.accountRequired,
      });
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      for (final id in flows[flow]!) {
        final route = appDestinations[id]!.name;
        if (!await _open(tester, route)) {
          hard.add('$id OPEN threw');
          log.writeln('$id\tOPEN\tEXCEPTION');
          continue;
        }
        final count = find.semantics
            .byAction(SemanticsAction.tap)
            .evaluate()
            .length;
        log.writeln('$id\t—\tSCREEN\t$count tappable');

        for (var i = 0; i < count; i++) {
          await _open(tester, route);
          final nodes = find.semantics
              .byAction(SemanticsAction.tap)
              .evaluate()
              .toList();
          if (i >= nodes.length) break;
          final node = nodes[i];
          final label = _labelOf(node);
          if (_skip.contains(label) && id != 'T01' && id != 'K07') continue;

          if (node.getSemanticsData().flagsCollection.isTextField) {
            // A field takes focus and the keyboard; that is its whole job.
            log.writeln('$id\t$i\tFIELD\t$label');
            continue;
          }
          final topBefore = _top(tester);
          final stateBefore = _state(tester);
          String outcome;
          try {
            tester.semantics.tap(
              find.semantics.byPredicate((n) => n.id == node.id),
            );
            await tester.pump();
            await _settle(tester);
            final err = tester.takeException();
            final topAfter = _top(tester);
            if (err != null) {
              outcome = 'EXCEPTION\t${'$err'.split('\n').first}';
            } else if (find.byType(NotBuiltYet).evaluate().isNotEmpty) {
              outcome = 'NOT-BUILT';
            } else if (find.byType(FeatureOff).evaluate().isNotEmpty) {
              outcome = 'FEATURE-OFF';
            } else if (find.byType(BottomSheet).evaluate().isNotEmpty) {
              outcome = 'SHEET';
            } else if (find.byType(Dialog).evaluate().isNotEmpty ||
                find.byType(AlertDialog).evaluate().isNotEmpty) {
              outcome = 'DIALOG';
            } else if (topAfter != topBefore) {
              outcome = topAfter == 'T01' && topBefore != 'T01'
                  ? 'BACK'
                  : 'NAV\t$topAfter';
            } else if (find.byType(SnackBar).evaluate().isNotEmpty) {
              outcome = 'SNACK';
            } else {
              outcome = _state(tester) == stateBefore
                  ? 'NO-VISIBLE-EFFECT'
                  : 'CHANGED';
            }
          } catch (e) {
            outcome = 'EXCEPTION\t${'$e'.split('\n').first}';
          }
          // Let any undo window close, so no timer outlives the screen.
          await tester.pump(const Duration(seconds: 6));
          tester.takeException();
          if (outcome.startsWith('EXCEPTION') ||
              (outcome.startsWith('NOT-BUILT') &&
                  !_retiredDoors.contains(id))) {
            hard.add('$id [$label] $outcome');
          }
          log.writeln('$id\t$i\t$outcome\t$label');
        }
      }
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  }

  tearDownAll(() {
    final path = Platform.environment['OWNHUB_QA_REPORT'];
    if (path != null) File(path).writeAsStringSync(log.toString());
  });

  test('no tap anywhere throws or lands on a placeholder', () {
    expect(hard, isEmpty, reason: hard.join('\n'));
  });
}
