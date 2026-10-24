import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/account/data/callable_consent_choice_store.dart';

void main() {
  test('the body carries the purpose, the choice and the current version', () {
    expect(
      consentChoicePayload(
        'analytics',
        true,
        locale: 'ar',
        appVersion: '1.1.0',
      ),
      {
        'purpose': 'analytics',
        'granted': true,
        'consentVersion': 2,
        'locale': 'ar',
        'appVersion': '1.1.0',
      },
    );
    expect(consentChoicePayload('crash', false, appVersion: ''), {
      'purpose': 'crash',
      'granted': false,
      'consentVersion': 1,
    });
  });

  test('the versions match the analytics key the phone stores', () {
    expect(kChoiceConsentVersions['analytics'], 2);
  });
}
