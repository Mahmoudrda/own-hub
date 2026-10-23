/// Firestore values as plain Dart, so the domain models never see a plugin
/// type: a `Timestamp` becomes a UTC `DateTime`, maps and lists are copied.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

Object? firestorePlain(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        if (entry.key is String)
          entry.key as String: firestorePlain(entry.value),
    };
  }
  if (value is List) return <Object?>[for (final v in value) firestorePlain(v)];
  return value;
}
