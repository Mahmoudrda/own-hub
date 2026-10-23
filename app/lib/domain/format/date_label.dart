/// Calendar dates as words, in her language, with Western digits.
///
/// Not `DateFormat`: `intl` switches to Eastern digits under `ar`
/// (`P0-A11Y-01`). Month names come from the dictionary.
library;

import '../../l10n/app_l10n.dart';

String monthName(AppL10n l10n, int month) => switch (month) {
  1 => l10n.january,
  2 => l10n.february,
  3 => l10n.march,
  4 => l10n.april,
  5 => l10n.may,
  6 => l10n.june,
  7 => l10n.july,
  8 => l10n.august,
  9 => l10n.september,
  10 => l10n.october,
  11 => l10n.november,
  _ => l10n.december,
};

/// "October 2026" / "أكتوبر 2026".
String monthYearLabel(AppL10n l10n, int year, int month) =>
    l10n.monthYear(monthName(l10n, month), '$year');

/// "12 October 2026" / "12 أكتوبر 2026".
String dayMonthYearLabel(AppL10n l10n, DateTime date) => l10n.dayMonthYear(
  '${date.day}',
  monthName(l10n, date.month),
  '${date.year}',
);
