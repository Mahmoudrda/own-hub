// One count for the whole of joining: "1 of 3 · Your week", "2 of 3 · Your
// number", "3 of 3 · Quick check". It replaced "Step 1 of 2" and "Step 2 of 2",
// which promised the end two screens before the identity check.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/app_step_progress.dart';

void main() {
  test('English', () async {
    final l10n = await AppL10n.delegate.load(const Locale('en'));
    expect(
      [for (final p in SignupPhase.values) signupPhaseLabel(l10n, p)],
      ['1 of 3 · Your week', '2 of 3 · Your number', '3 of 3 · Quick check'],
    );
  });

  test('Arabic, with Western digits', () async {
    final l10n = await AppL10n.delegate.load(const Locale('ar'));
    final labels = [
      for (final p in SignupPhase.values) signupPhaseLabel(l10n, p),
    ];
    expect(labels, [
      '1 من 3 · أسبوعك',
      '2 من 3 · رقمك',
      '3 من 3 · تحقق سريع',
    ]);
    for (final label in labels) {
      expect(label, isNot(matches(RegExp('[٠-٩]'))));
    }
  });
}
