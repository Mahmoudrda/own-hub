import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/presentation/coaching_when.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  // 24 Oct 2026 is a Saturday.
  final at = DateTime(2026, 10, 24, 18);

  test('English: weekday, day, month and 24-hour clock', () async {
    final l10n = await AppL10n.delegate.load(const Locale('en'));
    expect(coachWhen(l10n, at), 'Sat 24 Oct, 18:00');
  });

  test(
    'Arabic: 12-hour clock with the AM or PM marker, Western digits',
    () async {
      final l10n = await AppL10n.delegate.load(const Locale('ar'));
      final text = coachWhen(l10n, at);
      expect(text, contains('6:00 ${l10n.pm}'));
      expect(text, contains('24'));
      expect(RegExp(r'[٠-٩]').hasMatch(text), isFalse);
    },
  );
}
