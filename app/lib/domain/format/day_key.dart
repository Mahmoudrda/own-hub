/// Calendar day ids, rendered as text.
///
/// The fourth member of the family that starts with `clock_label.dart`,
/// `weight_label.dart` and `number_label.dart`, and it exists for the same
/// reason they do: a day id is a **value**, not copy. There is nothing in
/// "2026-09-19" to translate.
///
/// ## Why this is not `DateFormat`
///
/// The same reason `countLabel` is not `NumberFormat`. `P0-A11Y-01` requires
/// Western numerals in Arabic, and `intl` switches to Eastern digits under an
/// Arabic locale — so a day id formatted by `intl` would read "٢٠٢٦-٠٩-١٩"
/// under `ar` and stop matching the `^\d{4}-\d{2}-\d{2}$` id it is supposed to
/// be. A document id that changes with the reader's language is not an id.
///
/// ## Why the local calendar fields, and never `toUtc()`
///
/// `DECISIONS.md` D17: the day is the day it was **for her**. Reading
/// `moment.year/month/day` takes the calendar date off the phone she is
/// holding; converting to UTC first would file a Gulf woman's 01:00 Monday
/// session under Sunday. See [WeekKey.of], which makes the same choice for the
/// same reason.
///
/// ## These ids sort
///
/// Zero-padded `yyyy-MM-dd` compares lexicographically in chronological order,
/// and several call sites depend on exactly that —
/// `progress_repository.dart`'s "newest first by `dateKey`" is a plain string
/// sort. That is also why a slug like `day-2` must never reach a date field:
/// `'day-2'` compares **greater than** any `'2026-…'`, so one mockup id would
/// pin itself above every real best she ever set.
library;

/// The `yyyy-MM-dd` document id for [moment]'s calendar day.
///
/// Zero-padded on every component, including the year, so the string is always
/// exactly ten characters and always sorts.
String dayKey(DateTime moment) =>
    '${moment.year.toString().padLeft(4, '0')}-'
    '${moment.month.toString().padLeft(2, '0')}-'
    '${moment.day.toString().padLeft(2, '0')}';
