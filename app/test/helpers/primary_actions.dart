// One emphasis per screen (§15, Von Restorff): at most one filled primary
// action may be live in any screen state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/app_big_button.dart';
import 'package:own_hub/ui/app_button.dart';

/// Filled [AppButton]s and [AppBigButton]s that are on screen and enabled.
int filledPrimaryActions(WidgetTester tester) {
  var count = 0;
  for (final element in find.byType(AppButton).evaluate()) {
    final button = element.widget as AppButton;
    if (button.variant == AppButtonVariant.filled &&
        button.onPressed != null &&
        _onScreen(tester, element)) {
      count++;
    }
  }
  for (final element in find.byType(AppBigButton).evaluate()) {
    if (_onScreen(tester, element)) count++;
  }
  return count;
}

bool _onScreen(WidgetTester tester, Element element) {
  final box = element.renderObject;
  return box is RenderBox && box.hasSize && box.attached;
}

void expectAtMostOnePrimaryAction(WidgetTester tester, {String? where}) {
  expect(
    filledPrimaryActions(tester),
    lessThanOrEqualTo(1),
    reason: '${where ?? 'this screen'}: one emphasised action per state (§15)',
  );
}
