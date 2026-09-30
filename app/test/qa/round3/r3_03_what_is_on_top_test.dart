// ignore_for_file: avoid_print
//
// R3-03. For every control R3-02 says a finger cannot reach, name the thing
// that is sitting on it.
//
// "Unreachable" on its own is not a defect: a scrim exists to eat taps meant
// for what is behind it, and a row scrolled under a nav bar is reachable the
// moment she scrolls. The defect is the third case — something invisible, or
// something that is not drawn over the control at all, taking the tap. So this
// prints the hit-test path at the control's own centre, topmost first, and
// whether a scroll rescues it.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

bool _interactive(Widget w) =>
    w is IconButton ||
    w is InkWell ||
    w is TextButton ||
    w is ElevatedButton ||
    w is OutlinedButton ||
    w is FilledButton ||
    w is Switch ||
    w is Checkbox ||
    w is TextField;

String _text(Element e) {
  final labels = <String>[];
  void collect(Element child) {
    final w = child.widget;
    if (w is Text && (w.data ?? '').trim().isNotEmpty) {
      labels.add(w.data!.replaceAll('\n', ' '));
    } else if (w is Icon && w.icon != null) {
      labels.add('icon:${w.icon!.codePoint}');
    }
    if (labels.length < 3) child.visitChildren(collect);
  }

  e.visitChildren(collect);
  return labels.isEmpty ? '(no text)' : labels.take(3).join(' / ');
}

/// The widget types on the hit-test path at [at], topmost first.
List<String> _onTopOf(WidgetTester t, Offset at) {
  final result = HitTestResult();
  t.binding.hitTestInView(result, at * t.view.devicePixelRatio, t.view.viewId);
  final out = <String>[];
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    // The widget that created this render object, if the tree can say.
    final creator = target.debugCreator;
    var name = target.runtimeType.toString();
    if (creator is DebugCreator) {
      name = '${creator.element.widget.runtimeType}';
    }
    if (out.isEmpty || out.last != name) out.add(name);
    if (out.length >= 14) break;
  }
  return out;
}

void main() {
  useShippingApp();

  const suspects = <String>['T02', 'T05', 'R05', 'R08', 'Y01', 'P01', 'A02'];

  for (final loc in <String>['en', 'ar']) {
    testWidgets('what is on top, $loc', (t) async {
      phone(t);

      for (final id in suspects) {
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        if (t.takeException() != null) {
          print('=== $id $loc: THREW ===');
          continue;
        }

        final barriers = find.byType(ModalBarrier).evaluate().length;
        print('=== $id $loc   ModalBarriers=$barriers ===');

        for (final el in find
            .byWidgetPredicate(_interactive, skipOffstage: true)
            .evaluate()
            .toList()) {
          final ro = el.renderObject;
          if (ro is! RenderBox || !ro.hasSize || ro.size.isEmpty) continue;
          final rect = ro.localToGlobal(Offset.zero) & ro.size;
          if (!rect.overlaps(const Offset(0, 0) & Size(390, 844))) continue;
          final self = find.byElementPredicate((e) => e == el);
          if (self.hitTestable().evaluate().isNotEmpty) continue;

          print('  BLOCKED ${el.widget.runtimeType}  ${rect.center}  '
              '${_text(el)}');
          print('    on top: ${_onTopOf(t, rect.center).join(" < ")}');

          // Would a scroll rescue it?
          var rescued = false;
          try {
            await t.ensureVisible(self);
            await settle(t);
            rescued = self.hitTestable().evaluate().isNotEmpty;
          } catch (e) {
            rescued = false;
            print('    ensureVisible: ${'$e'.split('\n').first}');
          }
          print('    scroll rescues it? $rescued');
          // Restore the screen for the next control.
          await boot(t, locale: Locale(loc));
          nav(t).pushNamed(appDestinations[id]!.name);
          await settle(t);
          t.takeException();
        }
      }
    });
  }
}
