// Stands in for the audio plugin so a test can count what would have played.

import 'package:own_hub/app_state/feel_prefs.dart';
import 'package:own_hub/app_state/sound.dart';

class FakeSoundBackend implements SoundBackend {
  final List<String> loaded = <String>[];
  final List<String> played = <String>[];

  /// The played files by bare name, `set_done_2` and so on.
  List<String> get names => [
    for (final file in played)
      file.split('/').last.replaceAll('.wav', ''),
  ];

  @override
  Future<void> load(Iterable<String> bundleKeys) async =>
      loaded.addAll(bundleKeys);

  @override
  Future<void> play(String bundleKey) async => played.add(bundleKey);
}

/// Puts a recording backend in, with sound allowed and her first touch seen,
/// and returns it. Pair with [tearDownFakeSound].
FakeSoundBackend setUpFakeSound({bool touched = true}) {
  final backend = FakeSoundBackend();
  FeelPrefs.instance.debugReset();
  AppSound.debugUse(backend, touched: touched);
  AppSound.enabled = () => FeelPrefs.instance.sounds;
  return backend;
}

void tearDownFakeSound() {
  FeelPrefs.instance.debugReset();
  AppSound.debugReset();
}
