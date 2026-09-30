// ignore_for_file: avoid_print
//
// R3-07. The scrim stops a finger. Does it stop a screen reader?
//
// The three scrim screens were fixed by moving the scrim inside
// `Scaffold.body`, which is the right fix for the finger: the nav bar is laid
// out below `body` and can no longer be covered. But a scrim is two promises,
// not one — "you cannot touch what is behind this" and "what is behind this is
// not part of the page" — and only the first was measured, by
// `r1_49d_tabs_finger_test.dart`.
//
// So this asks the inverse question that no round has asked: which controls can
// a woman using TalkBack or VoiceOver still activate on these screens while a
// sighted woman cannot, and what happens when she does.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';
import '../round1/r1_55_large_text_sweep_test.dart' show shippingScreens;

/// Every render object on screen that is a full-window pointer absorber: an
/// opaque `GestureDetector` filling the view, or a `ModalBarrier`.
///
/// An opaque absorber terminates hit testing, so anything behind it is not in
/// the path at all. That makes "is a scrim in the path" the exact test for "a
/// finger here is eaten".
Set<RenderObject> _absorbers(WidgetTester t) {
  final out = <RenderObject>{};
  void take(Element el) {
    final ro = el.renderObject;
    if (ro is RenderBox && ro.hasSize) out.add(ro);
  }

  for (final el in find
      .byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.behavior == HitTestBehavior.opaque &&
            w.onTap != null,
      )
      .evaluate()) {
    final ro = el.renderObject;
    // >= 600 rather than >= 800 on purpose: the fix moved these scrims inside
    // `Scaffold.body`, so a scrim that used to be 844 tall is now about 784.
    // A detector written against the old geometry sees none of them.
    if (ro is RenderBox && ro.hasSize && ro.size.width >= 380 &&
        ro.size.height >= 600) {
      take(el);
    }
  }
  for (final el in find.byType(ModalBarrier).evaluate()) {
    take(el);
  }
  return out;
}

/// True when a finger at the centre of [rect] is swallowed before it can reach
/// whatever is drawn there.
bool _fingerEaten(WidgetTester t, Rect rect, Set<RenderObject> absorbers) {
  if (absorbers.isEmpty) return false;
  final result = HitTestResult();
  t.binding.hitTestInView(
    result,
    rect.center * t.view.devicePixelRatio,
    t.view.viewId,
  );
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderBox && absorbers.contains(target)) {
      // The absorber itself is legitimately tappable (it dismisses).
      final box = target.localToGlobal(Offset.zero) & target.size;
      if (box.width - rect.width < 1 && box.height - rect.height < 1) {
        return false;
      }
      return true;
    }
  }
  return false;
}

void main() {
  useShippingApp();

  // Which screens draw a full-window scrim at all? Measured rather than
  // assumed, so a fourth one cannot hide.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('screens with a full-window scrim, $loc', (t) async {
      phone(t);
      final found = <String>[];
      for (final id in shippingScreens) {
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        if (t.takeException() != null) continue;

        // A GestureDetector with opaque behaviour filling the window.
        var scrims = 0;
        for (final el in find
            .byWidgetPredicate(
              (w) =>
                  w is GestureDetector &&
                  w.behavior == HitTestBehavior.opaque &&
                  w.onTap != null,
            )
            .evaluate()) {
          final ro = el.renderObject;
          if (ro is! RenderBox || !ro.hasSize) continue;
          if (ro.size.width >= 380 && ro.size.height >= 600) scrims++;
        }
        final barriers = find.byType(ModalBarrier).evaluate().length;
        if (scrims > 0 || barriers > 1) {
          found.add('$id  inlineScrims=$scrims modalBarriers=$barriers');
        }
      }
      print('=== R3-07 $loc, screens that open covered ===');
      for (final f in found) {
        print('  $f');
      }
    });
  }

  // The divergence itself.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('reachable by a screen reader, not by a finger, $loc', (
      t,
    ) async {
      phone(t);
      final s = t.ensureSemantics();
      final report = <String>[];

      for (final id in <String>['T02', 'T05', 'R05', 'R08']) {
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        if (t.takeException() != null) continue;

        final absorbers = _absorbers(t);
        final only = <({String label, Rect rect})>[];
        for (final node in tappables(t)) {
          if (node.rect.isEmpty) continue;
          if (!node.rect.overlaps(const Offset(0, 0) & Size(390, 844))) {
            continue;
          }
          if (_fingerEaten(t, node.rect, absorbers)) {
            only.add((label: node.label, rect: node.rect));
          }
        }
        report.add('$id: ${only.length} control(s) a screen reader can reach '
            'and a finger cannot');
        for (final o in only) {
          report.add('    "${o.label}"  @${o.rect.center}');
        }
      }

      print('=== R3-07 $loc ===');
      for (final line in report) {
        print('  $line');
      }
      s.dispose();
    });
  }

  // And what actually happens when she activates one.
  testWidgets('T02: a screen reader taps through the scrim', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    print('=== R3-07 T02 walk-through ===');
    print('  landed on ${topScreen(t)}');
    print('  reader can activate: '
        '${tappables(t).map((e) => e.label).join(" // ")}');

    for (final name in <String>['Start, everything', 'Lunch']) {
      await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
      final before = topScreen(t);
      final hit = await tapControl(t, RegExp(name));
      print('  "$name": activated=$hit  $before -> ${topScreen(t)}');
    }

    // The same two, with a finger at the same pixel.
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    for (final name in <String>['Start, everything', 'Lunch']) {
      await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
      final f = find.textContaining(RegExp(name));
      if (f.evaluate().isEmpty) {
        print('  "$name": not painted');
        continue;
      }
      final before = topScreen(t);
      await t.tapAt(t.getRect(f.first).center);
      await settle(t);
      t.takeException();
      print('  "$name" WITH A FINGER: $before -> ${topScreen(t)}');
    }
    s.dispose();
  });

  // The same comparison on all three scrim screens, and it does not depend on
  // guessing which render object is the scrim: activate the control the way a
  // screen reader does, then put a finger on the same pixel, and see whether
  // she lands in the same place.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('reader and finger compared, three scrim screens, $loc', (
      t,
    ) async {
      phone(t);
      final s = t.ensureSemantics();
      final diverged = <String>[];

      for (final id in <String>['T02', 'T05', 'R05']) {
        await open(t, appDestinations[id]!.name, locale: Locale(loc));
        final names = tappables(t).map((e) => e.label).toList();
        print('=== R3-07b $id $loc ===');
        for (final name in names) {
          if (name.trim().isEmpty) continue;
          // Where a screen reader goes.
          await open(t, appDestinations[id]!.name, locale: Locale(loc));
          final start = topScreen(t);
          final activated = await tapControl(t, name);
          final byReader = topScreen(t);
          t.takeException();

          // Where a finger at the same painted pixel goes.
          await open(t, appDestinations[id]!.name, locale: Locale(loc));
          final node = tappables(t).where((e) => e.label == name).toList();
          if (node.isEmpty || node.first.rect.isEmpty) continue;
          await t.tapAt(node.first.rect.center);
          await settle(t);
          t.takeException();
          final byFinger = topScreen(t);

          final mark = byReader == byFinger ? '  ' : '!!';
          print('  $mark "$name"  reader($activated): $start -> $byReader   '
              'finger: $start -> $byFinger');
          if (byReader != byFinger) {
            diverged.add('$id $loc "$name": reader -> $byReader, '
                'finger -> $byFinger');
          }
        }
      }

      print('=== R3-07b DIVERGENCES, $loc (${diverged.length}) ===');
      for (final d in diverged) {
        print('  $d');
      }
      s.dispose();
    });
  }
}
