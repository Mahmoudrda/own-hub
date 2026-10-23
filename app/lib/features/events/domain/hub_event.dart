/// One event the owner runs: a class online, or a meet-up somewhere with a name.
///
/// The document is `events/{id}` and its shape is fixed by
/// `firebase/firestore.rules` (`validEvent`). Everything in it is about the
/// event. Nothing is about a woman: her seat is a separate document,
/// `events/{id}/attendees/{uid}`, that only the server writes and only she
/// (and the owner) can read. `seatsTaken` is a count the server keeps; the
/// app never writes it.
///
/// Times are UTC instants here and Cairo wall-clock time on screen; see
/// `cairo_time.dart`.
library;

import 'package:meta/meta.dart';

import 'cairo_time.dart';

/// A Google Maps link, the only kind of address an event may carry. The same
/// hosts, in the same shape, as `validEvent` in `firestore.rules`.
final RegExp _mapsUrl = RegExp(
  r'^https://((maps\.google\.com|maps\.app\.goo\.gl)([/?#]\S*)?'
  r'|goo\.gl/maps([/?#]\S*)?'
  r'|www\.google\.com/maps([/?#]\S*)?)$',
);

bool isAllowedMapsUrl(String? url) =>
    url != null && url.length <= 500 && _mapsUrl.hasMatch(url);

final RegExp _pictureName = RegExp(
  r'^[a-z0-9][a-z0-9_-]{0,80}\.(webp|jpg|jpeg)$',
);
final RegExp _clipName = RegExp(r'^[a-z0-9][a-z0-9_-]{0,80}\.mp4$');

bool isEventPictureName(String name) => _pictureName.hasMatch(name);
bool isEventClipName(String name) => _clipName.hasMatch(name);

abstract final class EventMediaLimits {
  static const int pictures = 6;
  static const int clips = 2;
}

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
    this.imageFiles = const [],
    this.videoFiles = const [],
    this.locationAddress,
    this.locationUrl,
    this.seatsTaken = 0,
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

  /// A name, for an event in person: "Zamalek ladies gym".
  final String? placeName;

  /// The street address of [placeName], as the owner wrote it.
  final String? locationAddress;

  /// A Google Maps link for the place; see [isAllowedMapsUrl].
  final String? locationUrl;

  /// Seats she can reserve. Without a number nobody can: the server refuses a
  /// reservation on an event with no seats set.
  final int? capacity;

  /// Seats reserved so far. Kept by the server and never written from here.
  final int seatsTaken;

  /// A picture from the media library, under `content/events/{id}/`.
  final String? coverFile;

  /// More pictures from the same folder, at most
  /// [EventMediaLimits.pictures].
  final List<String> imageFiles;

  /// Short clips from the same folder, at most [EventMediaLimits.clips].
  final List<String> videoFiles;

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

  /// Seats left, never below zero; null when the owner set no limit.
  int? get seatsLeft {
    final c = capacity;
    return c == null ? null : (c - seatsTaken).clamp(0, c);
  }

  bool get isFull => seatsLeft == 0;

  static String _path(String id, String file) => 'content/events/$id/$file';

  /// The pictures to page through: the cover first, then the rest, each once.
  List<String> get picturePaths => [
    for (final f in <String>{
      if (coverFile != null && coverFile!.isNotEmpty) coverFile!,
      ...imageFiles,
    })
      _path(id, f),
  ];

  List<String> get videoPaths => [for (final f in videoFiles) _path(id, f)];

  HubEvent copyWith({EventStatus? status, int? seatsTaken}) => HubEvent(
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
    imageFiles: imageFiles,
    videoFiles: videoFiles,
    locationAddress: locationAddress,
    locationUrl: locationUrl,
    seatsTaken: seatsTaken ?? this.seatsTaken,
    status: status ?? this.status,
  );

  /// The document body, with [DateTime]s for the data layer to turn into
  /// timestamps. Exactly the keys `validEvent` allows, no more, and never
  /// `seatsTaken`: the rules refuse an update that changes it.
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
    'locationAddress': mode == EventMode.place ? locationAddress : null,
    'locationUrl': mode == EventMode.place ? locationUrl : null,
    'capacity': capacity,
    'coverFile': coverFile,
    'imageFiles': imageFiles,
    'videoFiles': videoFiles,
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

    List<String> names(String key, bool Function(String) allowed, int max) {
      final v = data[key];
      if (v is! List) return const [];
      return [
        for (final n in v)
          if (n is String && allowed(n)) n,
      ].take(max).toList();
    }

    final capacity = data['capacity'];
    final taken = data['seatsTaken'];
    final mapsUrl = text('locationUrl');
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
      imageFiles: names(
        'imageFiles',
        isEventPictureName,
        EventMediaLimits.pictures,
      ),
      videoFiles: names('videoFiles', isEventClipName, EventMediaLimits.clips),
      locationAddress: text('locationAddress'),
      locationUrl: isAllowedMapsUrl(mapsUrl) ? mapsUrl : null,
      seatsTaken: taken is int && taken > 0 ? taken : 0,
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
      _same(other.imageFiles, imageFiles) &&
      _same(other.videoFiles, videoFiles) &&
      other.locationAddress == locationAddress &&
      other.locationUrl == locationUrl &&
      other.seatsTaken == seatsTaken &&
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
    Object.hashAll(imageFiles),
    Object.hashAll(videoFiles),
    locationAddress,
    locationUrl,
    seatsTaken,
    status,
  );
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The ones still to come, soonest first.
List<HubEvent> upcomingOf(Iterable<HubEvent> events, DateTime now) => [
  for (final e in events)
    if (e.status == EventStatus.published && e.isUpcoming(now)) e,
]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
