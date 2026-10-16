// Deleting her account leaves no exercise library behind: not the cached
// catalogue, not the time it was checked, not the clips kept on the phone,
// not the move she last opened.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/features/train/data/exercise_library_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/exercise_library_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ExerciseLibraryState.instance.reset());

  test(
    'the local erase removes the catalogue, its check time and the clips',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kExerciseLibraryCacheKey: '{"version":3}',
        kExerciseLibraryCheckKey: '2026-10-14T08:00:00.000Z',
        'unrelated.key': 'kept',
      });
      final media = FakeExerciseMedia();
      ExerciseLibraryState.instance
        ..media = media
        ..openExerciseId = 'goblet_squat';

      await const ThisPhoneWipe().clearPersistence();
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kExerciseLibraryCacheKey), isFalse);
      expect(prefs.containsKey(kExerciseLibraryCheckKey), isFalse);
      expect(prefs.getString('unrelated.key'), 'kept');
      expect(media.erased, isTrue);
      expect(ExerciseLibraryState.instance.openExerciseId, isNull);
    },
  );
}
