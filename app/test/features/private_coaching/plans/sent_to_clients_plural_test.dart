import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final ar = lookupAppL10n(const Locale('ar'));

  test('English says client for one and clients for the rest', () {
    expect(en.nPluralOneSentToNClient(1), 'Sent to 1 client');
    expect(en.nPluralOneSentToNClient(2), 'Sent to 2 clients');
    expect(en.nPluralOneSentToNClient(12), 'Sent to 12 clients');
  });

  test('Arabic agrees at one, two, three to ten, and eleven and up', () {
    expect(ar.nPluralOneSentToNClient(1), 'اتبعتت لعميلة واحدة');
    expect(ar.nPluralOneSentToNClient(2), 'اتبعتت لعميلتين');
    expect(ar.nPluralOneSentToNClient(3), 'اتبعتت لـ 3 عميلات');
    expect(ar.nPluralOneSentToNClient(10), 'اتبعتت لـ 10 عميلات');
    expect(ar.nPluralOneSentToNClient(11), 'اتبعتت لـ 11 عميلة');
    expect(ar.nPluralOneSentToNClient(100), 'اتبعتت لـ 100 عميلة');
  });
}
