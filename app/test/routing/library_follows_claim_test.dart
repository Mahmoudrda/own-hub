// A verified claim is what lets a phone read the exercise library, so the
// moment the claim turns true the library is asked for; a claim that was
// already true asks nothing more.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/features/train/data/exercise_library_sync.dart';
import 'package:own_hub/routing/app_router.dart';

import 'offline_verification_launch_test.dart' show FakeBackend;

class _Memory implements SnapshotStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async => value = snapshot;

  @override
  Future<void> erase() async => value = null;
}

class _Source implements ExerciseLibraryRemoteSource {
  int versionReads = 0;

  @override
  Future<int?> readVersion() async {
    versionReads++;
    return null;
  }

  @override
  Future<Map<String, Object?>?> readLibrary() async => null;
}

void main() {
  final savedBackend = AppRouter.verificationBackend;
  final savedSync = ExerciseLibraryState.instance.sync;
  late _Source source;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppRouter.forgetVerification();
    source = _Source();
    ExerciseLibraryState.instance.sync = ExerciseLibrarySync(
      source: () => source,
      cache: _Memory(),
      checks: _Memory(),
    );
  });

  tearDown(() async {
    AppRouter.verificationBackend = savedBackend;
    ExerciseLibraryState.instance.sync = savedSync;
    await AppRouter.forgetVerification();
  });

  test('a claim that turns true asks for the library', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async => true,
    );
    await AppRouter.refreshVerificationClaim();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(AppRouter.isVerified, isTrue);
    expect(source.versionReads, 1);
  });

  test('a claim that was already true asks for nothing more', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async => true,
    );
    await AppRouter.refreshVerificationClaim();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    ExerciseLibraryState.instance.sync = ExerciseLibrarySync(
      source: () => source,
      cache: _Memory(),
      checks: _Memory(),
    );
    final before = source.versionReads;
    await AppRouter.refreshVerificationClaim();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(source.versionReads, before);
  });

  test('a claim that stays false asks for nothing', () async {
    AppRouter.verificationBackend = FakeBackend(
      claim: ({bool forceRefresh = false}) async => false,
    );
    await AppRouter.refreshVerificationClaim();
    await Future<void>.delayed(Duration.zero);
    expect(source.versionReads, 0);
  });
}
