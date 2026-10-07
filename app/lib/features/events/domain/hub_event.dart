/// One event the owner runs: a class online, or a meet-up somewhere with a name.
///
/// The document is `events/{id}` and its shape is fixed by
/// `firebase/firestore.rules` (`validEvent`). Everything in it is about the
/// event. Nothing is about a woman: v1 has no "interested", no RSVP and no
/// attendee list, so there is nothing for a member's phone to write and
/// nothing about her for anyone to read.
///
/// Times are UTC instants here and Cairo wall-clock time on screen; see
/// `cairo_time.dart`.
library;

import 'package:meta/meta.dart';

import 'cairo_time.dart';

enum EventMode {
  online,
  place;

  static EventMode? fromWire(Object? wire) =>
      values.where((v) => v.name == wire).firstOrNull;
}

/// Draft is the owner's working copy, published is what members read, and
/// cancelled takes it off every member's list. The rules let a member read
/// `published` only.
enum EventStatus {
  draft,
  published,
  cancelled;

  static EventStatus? fromWire(Object? wire) =>
      values.where((v) => v.name == wire).firstOrNull;
}

@immutable
class HubEvent {
  const HubEvent({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.startsAt,
    required this.endsAt,
    required this.mode,
    required this.status,
    this.descriptionEn = '',
    this.descriptionAr = '',
    this.link,
    this.placeName,
    this.capacity,
    this.coverFile,
  });

  final String id;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;

  /// UTC.
  final DateTime startsAt;

  /// UTC. Always after [startsAt]; the rules refuse anything else.
  final DateTime endsAt;

  final EventMode mode;

  /// `https://…`, for an online event.
  final String? link;

  /// A name, for an event in person. "Zamalek ladies gym" is enough; nobody is
  /// asked for a street address, and the app never shows a map.
  final String? placeName;

  /// Places, when the owner set a limit. Shown, never counted against: there
  /// is no sign-up in v1.
  final int? capacity;

  /// A picture from the media library, under `content/events/{id}/`.
  final String? coverFile;

  final EventStatus status;

  /// The title in the language she reads the app in.
  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;

  /// The description in her language, or the other one when hers is empty.
  String description(String languageCode) {
    final mine = languageCode == 'ar' ? descriptionAr : descriptionEn;
    if (mine.trim().isNotEmpty) return mine;
    return languageCode == 'ar' ? descriptionEn : descriptionAr;
  }

  /// Not over yet at [now]. An event that has started and not finished is
  /// still on her list: she may be joining late.
  bool isUpcoming(DateTime now) => endsAt.isAfter(now.toUtc());

  /// The Storage path of the cover, or null. Always under `content/events/`,
  /// which is the one place `storage.library.rules` lets an admin write.
  String? get coverPath => coverFile == null || coverFile!.isEmpty
      ? null
      : 'content/events/$id/$coverFile';

  HubEvent copyWith({EventStatus? status}) => HubEvent(
    id: id,
    titleEn: titleEn,
    titleAr: titleAr,
    descriptionEn: descriptionEn,
    descriptionAr: descriptionAr,
    startsAt: startsAt,
    endsAt: endsAt,
    mode: mode,
    link: link,
    placeName: placeName,
    capacity: capacity,
    coverFile: coverFile,
    status: status ?? this.status,
  );

  /// The document body, with [DateTime]s for the data layer to turn into
  /// timestamps. Exactly the keys `validEvent` allows, no more.
  Map<String, Object?> toDocument() => <String, Object?>{
    'titleEn': titleEn,
    'titleAr': titleAr,
    'descriptionEn': descriptionEn,
    'descriptionAr': descriptionAr,
    'startsAt': startsAt.toUtc(),
    'endsAt': endsAt.toUtc(),
    'timeZone': kEventTimeZone,
    'mode': mode.name,
    'link': mode == EventMode.online ? link : null,
    'placeName': mode == EventMode.place ? placeName : null,
    'audience': 'all',
    'capacity': capacity,
    'coverFile': coverFile,
    'status': status.name,
  };

  /// Null when the document is not an event this build can show. A member's
  /// list skips it rather than failing whole.
  static HubEvent? fromDocument(String id, Map<String, Object?> data) {
    final starts = data['startsAt'];
    final ends = data['endsAt'];
    final mode = EventMode.fromWire(data['mode']);
    final status = EventStatus.fromWire(data['status']);
    final titleEn = data['titleEn'];
    final titleAr = data['titleAr'];
    if (starts is! DateTime || ends is! DateTime) return null;
    if (mode == null || status == null) return null;
    if (titleEn is! String || titleAr is! String) return null;
    if (!ends.isAfter(starts)) return null;
    String? text(String key) {
      final v = data[key];
      return v is String && v.trim().isNotEmpty ? v : null;
    }

    final capacity = data['capacity'];
    return HubEvent(
      id: id,
      titleEn: titleEn,
      titleAr: titleAr,
      descriptionEn: text('descriptionEn') ?? '',
      descriptionAr: text('descriptionAr') ?? '',
      startsAt: starts.toUtc(),
      endsAt: ends.toUtc(),
      mode: mode,
      link: text('link'),
      placeName: text('placeName'),
      capacity: capacity is int && capacity > 0 ? capacity : null,
      coverFile: text('coverFile'),
      status: status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HubEvent &&
      other.id == id &&
      other.titleEn == titleEn &&
      other.titleAr == titleAr &&
      other.descriptionEn == descriptionEn &&
      other.descriptionAr == descriptionAr &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt &&
      other.mode == mode &&
      other.link == link &&
      other.placeName == placeName &&
      other.capacity == capacity &&
      other.coverFile == coverFile &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
    id,
    titleEn,
    titleAr,
    descriptionEn,
    descriptionAr,
    startsAt,
    endsAt,
    mode,
    link,
    placeName,
    capacity,
    coverFile,
    status,
  );
}

/// The ones still to come, soonest first.
List<HubEvent> upcomingOf(Iterable<HubEvent> events, DateTime now) => [
  for (final e in events)
    if (e.status == EventStatus.published && e.isUpcoming(now)) e,
]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
