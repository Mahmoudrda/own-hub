// The driver half of `integration_test/demo_drive_test.dart`.
//
// Only here so the walk can be run in PROFILE mode. `flutter test` builds the
// app in debug, and a debug build plus a screen recording of a 1320x2868
// display is enough, together, to run this machine out of memory mid-take —
// the app is killed and the walk stops halfway.
//
//   flutter drive --profile \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/demo_drive_test.dart -d <udid>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
