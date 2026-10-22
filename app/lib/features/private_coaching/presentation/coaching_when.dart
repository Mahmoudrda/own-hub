/// One way to write a moment in coaching: "Sat 24 Oct, 18:00" in English,
/// the same moment with Arabic day and month names and AM or PM markers.
/// Western digits in both.
library;

import '../../../domain/format/date_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../events/domain/cairo_time.dart';

/// Monday as Egyptians say it.
const String egyptianMonday = '\u0627\u0644\u0627\u062A\u0646\u064A\u0646';

bool _ar(AppL10n l10n) => l10n.localeName.startsWith('ar');

String _weekday(AppL10n l10n, int weekday) => switch (weekday) {
  DateTime.monday => _ar(l10n) ? egyptianMonday : l10n.mon,
  DateTime.tuesday => l10n.tue,
  DateTime.wednesday => l10n.wed,
  DateTime.thursday => l10n.thu,
  DateTime.friday => l10n.fri,
  DateTime.saturday => l10n.sat,
  _ => l10n.sun,
};

DateTime _at(DateTime instant, bool cairo) =>
    cairo ? toCairo(instant) : instant.toLocal();

/// "Sat 24 Oct". Cairo's calendar when [cairo] is set, else the phone's.
String coachDayLabel(AppL10n l10n, DateTime instant, {bool cairo = false}) {
  final d = _at(instant, cairo);
  final month = monthName(l10n, d.month);
  return '${_weekday(l10n, d.weekday)} ${d.day} '
      '${_ar(l10n) || month.length <= 3 ? month : month.substring(0, 3)}';
}

/// "18:00" in English, a 12-hour clock with AM or PM markers in Arabic.
String coachClockLabel(AppL10n l10n, DateTime instant, {bool cairo = false}) {
  final d = _at(instant, cairo);
  final m = d.minute.toString().padLeft(2, '0');
  if (!_ar(l10n)) return '${d.hour.toString().padLeft(2, '0')}:$m';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:$m ${d.hour < 12 ? l10n.am : l10n.pm}';
}

/// ", " in English, the Arabic comma in Arabic.
String coachListSep(AppL10n l10n) => _ar(l10n) ? '\u060C ' : ', ';

/// "Sat 24 Oct, 18:00".
String coachWhen(AppL10n l10n, DateTime instant, {bool cairo = false}) =>
    '${coachDayLabel(l10n, instant, cairo: cairo)}'
    '${coachListSep(l10n)}'
    '${coachClockLabel(l10n, instant, cairo: cairo)}';
