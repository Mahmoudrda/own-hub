/// Z18's fields, checked the way `firestore.rules` will check them.
///
/// The rules are the boundary and refuse a bad event whatever the app sends.
/// This exists so the owner hears what is wrong beside the field she typed it
/// in, before a save that would only come back as "permission denied".
library;

import 'package:meta/meta.dart';

import 'cairo_time.dart';
import 'hub_event.dart';

enum EventField {
  titleEn,
  titleAr,
  descriptionEn,
  descriptionAr,
  startsAt,
  endsAt,
  link,
  placeName,
  capacity,
}

enum EventProblem {
  /// Blank where the rules need a value.
  required,

  /// Longer than the rules allow.
  tooLong,

  /// Not `2026-11-05 18:30`.
  badTime,

  /// The end is not after the start.
  endBeforeStart,

  /// Not an `https://` link.
  badLink,

  /// Not a whole number above zero.
  badCapacity,
}

/// The limits in `validEvent`, in one place.
abstract final class EventLimits {
  static const int title = 120;
  static const int description = 2000;
  static const int link = 500;
  static const int placeName = 120;
  static const int capacity = 100000;
}

@immutable
class EventDraft {
  const EventDraft({
    this.titleEn = '',
    this.titleAr = '',
    this.descriptionEn = '',
    this.descriptionAr = '',
    this.startsAt = '',
    this.endsAt = '',
    this.mode = EventMode.online,
    this.link = '',
    this.placeName = '',
    this.capacity = '',
    this.coverFile,
  });

  /// The form opened on a stored event.
  factory EventDraft.of(HubEvent event) => EventDraft(
    titleEn: event.titleEn,
    titleAr: event.titleAr,
    descriptionEn: event.descriptionEn,
    descriptionAr: event.descriptionAr,
    startsAt: formatCairo(event.startsAt),
    endsAt: formatCairo(event.endsAt),
    mode: event.mode,
    link: event.link ?? '',
    placeName: event.placeName ?? '',
    capacity: event.capacity?.toString() ?? '',
    coverFile: event.coverFile,
  );

  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;

  /// Cairo wall-clock text, `2026-11-05 18:30`.
  final String startsAt;
  final String endsAt;
  final EventMode mode;
  final String link;
  final String placeName;
  final String capacity;
  final String? coverFile;

  static final RegExp _https = RegExp(r'^https://[^ ]{3,500}$');
  static final RegExp _whole = RegExp(r'^\d+$');

  /// Every problem, by field. Empty means [toEvent] will succeed.
  Map<EventField, EventProblem> problems() {
    final out = <EventField, EventProblem>{};
    void text(
      EventField field,
      String value,
      int max, {
      bool required = false,
    }) {
      final v = value.trim();
      if (required && v.isEmpty) {
        out[field] = EventProblem.required;
      } else if (v.length > max) {
        out[field] = EventProblem.tooLong;
      }
    }

    text(EventField.titleEn, titleEn, EventLimits.title, required: true);
    text(EventField.titleAr, titleAr, EventLimits.title, required: true);
    text(EventField.descriptionEn, descriptionEn, EventLimits.description);
    text(EventField.descriptionAr, descriptionAr, EventLimits.description);

    final start = parseCairo(startsAt);
    final end = parseCairo(endsAt);
    if (startsAt.trim().isEmpty) {
      out[EventField.startsAt] = EventProblem.required;
    } else if (start == null) {
      out[EventField.startsAt] = EventProblem.badTime;
    }
    if (endsAt.trim().isEmpty) {
      out[EventField.endsAt] = EventProblem.required;
    } else if (end == null) {
      out[EventField.endsAt] = EventProblem.badTime;
    } else if (start != null && !end.isAfter(start)) {
      out[EventField.endsAt] = EventProblem.endBeforeStart;
    }

    switch (mode) {
      case EventMode.online:
        final l = link.trim();
        if (l.isEmpty) {
          out[EventField.link] = EventProblem.required;
        } else if (!_https.hasMatch(l)) {
          out[EventField.link] = EventProblem.badLink;
        }
      case EventMode.place:
        text(
          EventField.placeName,
          placeName,
          EventLimits.placeName,
          required: true,
        );
    }

    final c = capacity.trim();
    if (c.isNotEmpty) {
      final n = _whole.hasMatch(c) ? int.tryParse(c) : null;
      if (n == null || n < 1 || n > EventLimits.capacity) {
        out[EventField.capacity] = EventProblem.badCapacity;
      }
    }
    return out;
  }

  /// The event, or null while [problems] is not empty.
  HubEvent? toEvent({required String id, required EventStatus status}) {
    if (problems().isNotEmpty) return null;
    final c = capacity.trim();
    return HubEvent(
      id: id,
      titleEn: titleEn.trim(),
      titleAr: titleAr.trim(),
      descriptionEn: descriptionEn.trim(),
      descriptionAr: descriptionAr.trim(),
      startsAt: parseCairo(startsAt)!,
      endsAt: parseCairo(endsAt)!,
      mode: mode,
      link: mode == EventMode.online ? link.trim() : null,
      placeName: mode == EventMode.place ? placeName.trim() : null,
      capacity: c.isEmpty ? null : int.parse(c),
      coverFile: coverFile,
      status: status,
    );
  }
}
