// Counts the controls a woman can press in the viewport, for the screen
// budgets. The rules:
//
//  * A control is a button, icon button, switch, chip, text field, list row or
//    pressable that has a tap handler, or a bare InkWell or GestureDetector
//    with one.
//  * The plumbing a control builds for itself (the InkWell inside a pressable,
//    the private button inside an IconButton) is the control, not a second
//    one. It is plumbing when nothing but framework wrappers sit between it
//    and the first tappable widget above it. Anything laid out in between (a
//    Row, a Column, a Stack) is the control's content, so a link or a trailing
//    button inside a tappable card or row counts on its own.
//  * The segments of one AppSegmented are one control.
//  * Rows of AppListItem that sit next to each other in one list are one
//    control. A button, a heading or any other widget between them splits the
//    list in two. Plain gaps (an empty SizedBox) do not.
//  * A row and its own trailing PlusButton (the "+" that adds that row's food)
//    are one control (owner decision, 24 Oct 2026): the row is the thing she
//    taps, and the "+" is its shortcut.
//  * The tab bar is not counted. The chrome (her picture and the language
//    switch) is, unless a caller asks for it to be left out; the screen
//    budgets always leave it out (owner decision, see kChromeCounts).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart'
    show PlusButton;
import 'package:own_hub/ui/app_list_item.dart';
import 'package:own_hub/ui/app_nav_bar.dart';
import 'package:own_hub/ui/app_segmented.dart';
import 'package:own_hub/ui/app_stat_hero.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:own_hub/ui/language_switch.dart';

bool _isLeaf(Widget w) =>
    w is ButtonStyleButton ||
    w is IconButton ||
    w is Switch ||
    (w is ActionChip && w.onPressed != null) ||
    (w is InputChip && (w.onPressed != null || w.onSelected != null)) ||
    (w is ChoiceChip && w.onSelected != null) ||
    (w is FilterChip && w.onSelected != null) ||
    w is TextField ||
    w is AppListItem ||
    (w is HandPressable && w.onTap != null);

bool _isTapSurface(Widget w) =>
    (w is InkWell && w.onTap != null) ||
    (w is GestureDetector && w.onTap != null);

bool _isControl(Widget w) => _isLeaf(w) || _isTapSurface(w);

bool _isContent(Widget w) =>
    w is Flex || w is Wrap || w is Stack || w is SliverMultiBoxAdaptorWidget;

bool _inNavBar(Element e) => _hasAncestor(e, (w) => w is AppNavBar);

bool _inChrome(Element e) =>
    _hasAncestor(e, (w) => w is AppChrome || w is LanguageSwitchButton);

bool _hasAncestor(Element e, bool Function(Widget) test) {
  var found = false;
  e.visitAncestorElements((a) {
    if (test(a.widget)) found = true;
    return !found;
  });
  return found;
}

/// Whether [e] is built by the control above it rather than being its own.
bool _isPlumbing(Element e) {
  var content = false;
  var plumbing = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    // A row with no tap handler is not a control, so what it holds is.
    if (w is AppListItem && w.onTap == null) return true;
    if (_isControl(w)) {
      plumbing = !content;
      return false;
    }
    if (_isContent(a.widget)) content = true;
    return true;
  });
  return plumbing;
}

/// Whether [e] belongs to the caret handle a TextField shows after a tap: part
/// of the text field, not a control of its own.
bool _inSelectionHandle(Element e) => _hasAncestor(
  e,
  (w) => w.runtimeType.toString().contains('SelectionHandle'),
);

/// Whether [e] is the "+" of a row, which is that row's own control.
bool _isRowAdd(Element e) {
  var inPlus = false;
  var inRow = false;
  e.visitAncestorElements((a) {
    if (a.widget is PlusButton) inPlus = true;
    // Only a row she can tap folds its "+" in; a row with no tap handler
    // leaves the "+" as its one control.
    final w = a.widget;
    if (inPlus && w is AppListItem && w.onTap != null) inRow = true;
    return !inRow;
  });
  return inRow;
}

bool _isGap(Widget w) => w is SizedBox && w.child == null;

bool _isRowSlot(Element slot) {
  var e = slot;
  for (var i = 0; i < 6; i++) {
    if (e.widget is AppListItem) return true;
    final children = <Element>[];
    e.visitChildren(children.add);
    if (children.length != 1) return false;
    e = children.single;
  }
  return false;
}

/// The first slot of the run of adjacent rows that [row] belongs to, or null
/// when it is not in a list.
Element? _runOf(Element row) {
  Element? slot;
  Element? parent;
  var child = row;
  row.visitAncestorElements((a) {
    if (a.widget is Flex || a.widget is SliverMultiBoxAdaptorWidget) {
      slot = child;
      parent = a;
      return false;
    }
    child = a;
    return true;
  });
  if (parent == null) return null;
  Element? runStart;
  Element? found;
  parent!.visitChildren((c) {
    if (_isGap(c.widget)) return;
    if (_isRowSlot(c)) {
      runStart ??= c;
    } else {
      runStart = null;
    }
    if (identical(c, slot)) found = runStart;
  });
  return found;
}

/// How many hit-testable controls sit in the viewport, not counting the tab
/// bar.
int countControlsAboveFold(WidgetTester tester, {bool includeChrome = true}) {
  final finder = find
      .byElementPredicate((e) => _isControl(e.widget))
      .hitTestable();
  var count = 0;
  final groups = <Element>{};
  for (final e in finder.evaluate()) {
    if (_inNavBar(e)) continue;
    if (!includeChrome && _inChrome(e)) continue;
    final w = e.widget;
    if (_isPlumbing(e)) continue;
    if (_isRowAdd(e) || _inSelectionHandle(e)) continue;
    if (w is HandPressable) {
      Element? seg;
      e.visitAncestorElements((a) {
        if (a.widget is AppSegmented) seg = a;
        return seg == null;
      });
      if (seg != null) {
        if (groups.add(seg!)) count++;
        continue;
      }
    }
    if (w is AppListItem) {
      final run = _runOf(e);
      if (run != null && !groups.add(run)) continue;
    }
    count++;
  }
  return count;
}

final _digit = RegExp(r'[0-9\u0660-\u0669]');

/// How many figures the hero area carries: every text holding a digit inside
/// an [AppStatHero], or inside [within] when a screen draws its own hero.
int countHeroFigures(WidgetTester tester, {Finder? within}) {
  final area = within ?? find.byType(AppStatHero);
  var count = 0;
  for (final e
      in find.descendant(of: area, matching: find.byType(Text)).evaluate()) {
    final text = e.widget as Text;
    if (_digit.hasMatch(text.data ?? text.textSpan?.toPlainText() ?? '')) {
      count++;
    }
  }
  return count;
}
