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
  locationAddress,
  locationUrl,
  capacity,
  imageFiles,
  videoFiles,
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

  /// Fewer seats than are already reserved, or no limit at all while seats are
  /// reserved.
  capacityBelowSeats,

  /// Not a Google Maps link.
  badMapsLink,

  /// More pictures or clips than an event may carry.
  tooMany,

  /// A file name the rules would refuse.
  badFile,
}

/// The limits in `validEvent`, in one place.
abstract final class EventLimits {
  static const int title = 120;
  static const int description = 2000;
  static const int link = 500;
  static const int placeName = 120;
  static const int locationAddress = 300;
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
    this.locationAddress = '',
    this.locationUrl = '',
    this.capacity = '',
    this.seatsTaken = 0,
    this.coverFile,
    this.imageFiles = const [],
    this.videoFiles = const [],
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
    locationAddress: event.locationAddress ?? '',
    locationUrl: event.locationUrl ?? '',
    capacity: event.capacity?.toString() ?? '',
    seatsTaken: event.seatsTaken,
    coverFile: event.coverFile,
    imageFiles: event.imageFiles,
    videoFiles: event.videoFiles,
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
  final String locationAddress;
  final String locationUrl;
  final String capacity;

  /// Seats already reserved, kept by the server. The form can only read it.
  final int seatsTaken;
  final String? coverFile;
  final List<String> imageFiles;
  final List<String> videoFiles;

  static final RegExp _https = RegExp(r'^https://\S{3,500}$');
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
        text(
          EventField.locationAddress,
          locationAddress,
          EventLimits.locationAddress,
        );
        final u = locationUrl.trim();
        if (u.isNotEmpty && !isAllowedMapsUrl(u)) {
          out[EventField.locationUrl] = EventProblem.badMapsLink;
        }
    }

    void files(
      EventField field,
      List<String> names,
      int max,
      bool Function(String) allowed,
    ) {
      if (names.length > max) {
        out[field] = EventProblem.tooMany;
      } else if (!names.every(allowed)) {
        out[field] = EventProblem.badFile;
      }
    }

    files(
      EventField.imageFiles,
      imageFiles,
      EventMediaLimits.pictures,
      isEventPictureName,
    );
    files(
      EventField.videoFiles,
      videoFiles,
      EventMediaLimits.clips,
      isEventClipName,
    );

    final c = capacity.trim();
    if (c.isNotEmpty) {
      final n = _whole.hasMatch(c) ? int.tryParse(c) : null;
      if (n == null || n < 1 || n > EventLimits.capacity) {
        out[EventField.capacity] = EventProblem.badCapacity;
      } else if (n < seatsTaken) {
        out[EventField.capacity] = EventProblem.capacityBelowSeats;
      }
    } else if (seatsTaken > 0) {
      out[EventField.capacity] = EventProblem.capacityBelowSeats;
    }
    return out;
  }

  /// The event, or null while [problems] is not empty.
  HubEvent? toEvent({required String id, required EventStatus status}) {
    if (problems().isNotEmpty) return null;
    final c = capacity.trim();
    final address = locationAddress.trim();
    final maps = locationUrl.trim();
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
      locationAddress: mode == EventMode.place && address.isNotEmpty
          ? address
          : null,
      locationUrl: mode == EventMode.place && maps.isNotEmpty ? maps : null,
      capacity: c.isEmpty ? null : int.parse(c),
      coverFile: coverFile,
      imageFiles: imageFiles,
      videoFiles: videoFiles,
      status: status,
    );
  }
}
