// The app's deletion manifest and the server's are the same list.
//
// `contracts/deletion_manifest.json` drives `functions/account/manifest.py`,
// which refuses to load if a row has no action. This test holds the Dart side
// to it: every Dart row is a JSON row (number, path and method name) and every
// JSON row is a Dart row. A row added on one side only is the exact omission
// the manifest exists to make visible.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/deletion_manifest.dart';

void main() {
  final json = jsonDecode(
    File('../contracts/deletion_manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final rows = (json['rows'] as List).cast<Map<String, dynamic>>();

  String key(int number, String path, String method) => '$number|$path|$method';

  final fromJson = {
    for (final r in rows)
      key(r['number'] as int, r['path'] as String, r['method'] as String),
  };
  final fromDart = {
    for (final r in kDeletionManifest) key(r.number, r.path, r.method.name),
  };

  test('every Dart row is a server row', () {
    expect(fromDart.difference(fromJson), isEmpty);
  });

  test('every server row is a Dart row', () {
    expect(fromJson.difference(fromDart), isEmpty);
  });

  test('every Storage prefix the server purges is named by a row', () {
    // functions/account/deletion.py is the code that empties the buckets.
    // A prefix it purges that no row names is a deletion the manifest, and
    // so the deletion sheet, never mentions.
    final source = File('../functions/account/deletion.py').readAsStringSync();
    final tuple = RegExp(r'STORAGE_PREFIXES\s*=\s*\(([^)]*)\)')
        .firstMatch(source);
    expect(tuple, isNotNull, reason: 'STORAGE_PREFIXES not found');
    final prefixes = [
      for (final m in RegExp(r'"([^"]+)"').allMatches(tuple!.group(1)!))
        m.group(1)!.replaceAll(RegExp(r'/$'), ''),
    ];
    expect(prefixes, isNotEmpty);
    final storageRows = [
      for (final r in rows)
        if ((r['path'] as String).startsWith('Storage ')) r['path'] as String,
    ];
    for (final prefix in prefixes) {
      expect(
        storageRows.any((path) => path.contains('$prefix/**')),
        isTrue,
        reason: '$prefix is purged by the server but named by no row',
      );
    }
  });

  test('the same count, numbered the same way', () {
    expect(kDeletionManifest, hasLength(rows.length));
    expect(
      kDeletionManifest.map((r) => r.number).toList(),
      rows.map((r) => r['number']).toList(),
    );
  });
}
