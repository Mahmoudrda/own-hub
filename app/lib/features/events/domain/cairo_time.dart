/// Event times, in Cairo, whatever the phone is set to.
///
/// An event happens at one moment for everybody. The owner types it in Cairo
/// time, it is stored as a UTC instant, and every member reads it back in
/// Cairo time with "Cairo time" beside it. Showing it in the phone's own zone
/// would be right for a reminder and wrong here: a woman visiting Dubai should
/// still read the time the gym opens its doors in Zamalek.
///
/// Egypt moves its clocks (summer time came back in 2023), so the offset is
/// not a constant: it comes from the IANA database the `timezone` package
/// already ships for training reminders.
///
/// Digits are Western in both languages (`P0-A11Y-01`), which is why nothing
/// here goes through `intl`.
library;

import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const String kEventTimeZone = 'Africa/Cairo';

bool _loaded = false;

tz.Location _cairo() {
  if (!_loaded) {
    tz_data.initializeTimeZones();
    _loaded = true;
  }
  return tz.getLocation(kEventTimeZone);
}

final RegExp _typed = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})$');

/// `2026-11-05 18:30`, read as Cairo wall-clock time, as a UTC instant.
///
/// Null for anything else, including a date that does not exist (31 April)
/// and Eastern Arabic digits, which the form refuses rather than misreads.
DateTime? parseCairo(String text) {
  final m = _typed.firstMatch(text.trim());
  if (m == null) return null;
  final parts = [for (var i = 1; i <= 5; i++) int.parse(m.group(i)!)];
  final [year, month, day, hour, minute] = parts;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59) return null;
  final local = tz.TZDateTime(_cairo(), year, month, day, hour, minute);
  if (local.year != year || local.month != month || local.day != day) {
    return null;
  }
  return local.toUtc();
}

/// The same instant on Cairo's wall clock.
DateTime toCairo(DateTime instant) =>
    tz.TZDateTime.from(instant.toUtc(), _cairo());

String _two(int n) => n.toString().padLeft(2, '0');

/// `2026-11-05 18:30`, the form's own format, for opening an event to edit.
String formatCairo(DateTime instant) {
  final c = toCairo(instant);
  return '${c.year.toString().padLeft(4, '0')}-${_two(c.month)}-${_two(c.day)} '
      '${_two(c.hour)}:${_two(c.minute)}';
}

/// `2026-11-05`, Cairo's calendar day of [instant].
String cairoDay(DateTime instant) => formatCairo(instant).substring(0, 10);

/// `18:30`, Cairo's clock at [instant].
String cairoClock(DateTime instant) => formatCairo(instant).substring(11);

/// `DateTime.monday` to `DateTime.sunday` in Cairo at [instant].
int cairoWeekday(DateTime instant) => toCairo(instant).weekday;
