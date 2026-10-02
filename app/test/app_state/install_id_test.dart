// S12: the install id is random, created once, survives a restart and goes
// with her data; the operation id is a fresh uuid v4 per attempt.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/install_id.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('created once, 32 hex characters, then the same', () async {
    await InstallId.erase();
    final first = await InstallId.read();
    expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(await InstallId.read(), first);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kInstallIdKey), first);
  });

  test('erasing it makes the next one different', () async {
    await InstallId.erase();
    final first = await InstallId.read();
    await InstallId.erase();
    expect(await InstallId.read(), isNot(first));
  });

  test('operation ids are uuid v4 and never repeat', () {
    final ids = <String>{for (var i = 0; i < 200; i++) newOperationId()};
    expect(ids, hasLength(200));
    for (final id in ids) {
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
}
