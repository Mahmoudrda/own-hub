// Deleting her account leaves no recipe cache behind.
//
// The cached remote library and the time it was last checked live under
// their own preference keys, beside the snapshot. The recipes are public
// content, but the keys are still something this phone kept from her
// account: a signed-in, verified session is the only one that can fetch
// them. A deleted account leaves nothing behind, so both keys go with the
// rest of the handset stores.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/features/eat/data/recipe_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the local erase removes the recipe cache and its check time', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kRecipeCacheKey: '{"version":7}',
      kRecipeCheckKey: '2026-10-01T08:00:00.000Z',
      'unrelated.key': 'kept',
    });

    await const ThisPhoneWipe().clearPersistence();
    // The erases are not awaited by the wipe, on purpose; let them finish.
    await pumpEventQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kRecipeCacheKey), isFalse);
    expect(prefs.containsKey(kRecipeCheckKey), isFalse);
    expect(prefs.getString('unrelated.key'), 'kept');
  });

  test('deleting everything on this phone reaches the recipe keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kRecipeCacheKey: '{"version":7}',
      kRecipeCheckKey: '2026-10-01T08:00:00.000Z',
    });

    await deleteEverythingOnThisPhone();
    await pumpEventQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kRecipeCacheKey), isFalse);
    expect(prefs.containsKey(kRecipeCheckKey), isFalse);
  });
}
