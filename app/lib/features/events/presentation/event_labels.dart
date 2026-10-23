/// How an event's time and place are written, in one place for Home's card,
/// `T09` and the console's list, so the three cannot disagree.
library;

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../today/presentation/today_cards.dart' show weekdayLabel;
import '../domain/cairo_time.dart';
import '../domain/hub_event.dart';

/// `Friday · 2026-11-05 · 18:30 to 20:00`, in Cairo time. An event that runs
/// past midnight names both days: `2026-11-05 22:00 to 2026-11-06 01:00`.
String eventWhen(AppL10n l10n, HubEvent event) {
  final day = weekdayLabel(l10n, toCairo(event.startsAt));
  final startDay = cairoDay(event.startsAt);
  final endDay = cairoDay(event.endsAt);
  if (startDay == endDay) {
    return '$day · $startDay · '
        '${l10n.startToEnd(cairoClock(event.startsAt), cairoClock(event.endsAt))}';
  }
  return '$day · ${l10n.startToEnd(formatCairo(event.startsAt), formatCairo(event.endsAt))}';
}

/// `Online`, or the place's name, and the places when there is a limit.
String eventWhere(AppL10n l10n, HubEvent event) {
  final where = switch (event.mode) {
    EventMode.online => l10n.online,
    EventMode.place => event.placeName ?? l10n.inPerson,
  };
  final capacity = event.capacity;
  return capacity == null
      ? where
      : '$where · ${l10n.placesCount(countLabel(capacity))}';
}

/// `Online`, or the place's name. The seats have their own line on `T09`.
String eventVenue(AppL10n l10n, HubEvent event) => switch (event.mode) {
  EventMode.online => l10n.online,
  EventMode.place => event.placeName ?? l10n.inPerson,
};
