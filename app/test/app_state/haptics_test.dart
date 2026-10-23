// D40 and D48: four moments, four strengths, behind a switch.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String?>[];
  final saved = AppHaptics.enabled;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String?);
          }
          return null;
        });
  });
  tearDown(() => AppHaptics.enabled = saved);

  test('each moment has its own strength', () async {
    AppHaptics.enabled = () => true;
    await AppHaptics.play(HapticMoment.setLogged);
    await AppHaptics.play(HapticMoment.actionDone);
    await AppHaptics.play(HapticMoment.sessionFinished);
    await AppHaptics.play(HapticMoment.bigMoment);
    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  test('switched off, nothing is felt', () async {
    AppHaptics.enabled = () => false;
    await AppHaptics.play(HapticMoment.bigMoment);
    expect(calls, isEmpty);
  });
}
