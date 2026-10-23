// Only web pages and mail addresses may be handed to the phone.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/open_link.dart';

void main() {
  test('https and mailto pass', () {
    expect(externalLinkAllowed('https://own-hub.app/privacy'), isTrue);
    expect(externalLinkAllowed('HTTPS://own-hub.app'), isTrue);
    expect(externalLinkAllowed('mailto:help@own-hub.app?subject=Hi'), isTrue);
  });

  test('every other scheme is refused', () {
    for (final url in [
      'http://own-hub.app',
      'tel:123',
      'sms:123',
      'file:///etc/hosts',
      'javascript:alert(1)',
      'intent://x#Intent;end',
      'own-hub.app/privacy',
      '',
    ]) {
      expect(externalLinkAllowed(url), isFalse, reason: url);
    }
  });
}
