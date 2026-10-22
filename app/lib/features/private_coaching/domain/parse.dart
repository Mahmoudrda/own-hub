/// Defensive readers for documents that come off the wire. A wrong type or a
/// missing field gives the empty value, never an exception.
library;

typedef Json = Map<String, Object?>;

Json? asMap(Object? value) {
  if (value is! Map) return null;
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String readString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

String? readStringOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int readInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  return fallback;
}

int? readIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  return null;
}

bool readBool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

/// A time as the data layer hands it over: a [DateTime], an ISO string or
/// milliseconds since the epoch. Always UTC.
DateTime? readTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  return null;
}

List<String> readStrings(Object? value) => value is List
    ? <String>[
        for (final item in value)
          if (item is String) item,
      ]
    : const <String>[];

List<Json> readMaps(Object? value) => value is List
    ? <Json>[for (final item in value) ?asMap(item)]
    : const <Json>[];

/// Wire strings kept only when [allowed] holds them, in their order.
List<String> readKnown(Object? value, Iterable<String> allowed) {
  final set = allowed.toSet();
  return <String>[
    for (final item in readStrings(value))
      if (set.contains(item)) item,
  ];
}

/// An enum with a name on the wire.
mixin WireEnum on Enum {
  String get wire;
}

/// The value of [values] named [value] on the wire, or null for a name this
/// build does not know (or anything that is not text).
T? enumFromWire<T extends WireEnum>(List<T> values, Object? value) {
  if (value is! String) return null;
  for (final v in values) {
    if (v.wire == value) return v;
  }
  return null;
}
