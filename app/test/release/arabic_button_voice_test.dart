// R1-P24 and A7: the Arabic buttons speak in one voice.
//
// A button is either her own words in the first person ("أنا مدرِّبة، أريد
// إعداد ملفي"), a neutral verbal noun ("الموافقة وإرسال الرمز"), or "let us"
// ("لنبدأ"). None of them gives the app an order as if it were a woman
// ("أدخليني", "أنشئي ملفي") or orders the team in the plural ("أرسلوا"). And an
// exercise is named for what the body does, not by a literal "dead insect".

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final ar = _arb('ar');

  test('the pledge button invites rather than orders the app', () {
    expect(ar['iAgreeLetMeIn'], 'أوافق، لنبدأ');
  });

  test('the coach button is in her own words', () {
    expect(ar['imACoachSetUpMyProfile'], 'أنا مدرِّبة، أريد إعداد ملفي');
  });

  test('the number screen button is neutral, and the line quoting it agrees',
      () {
    expect(ar['agreeAndSendMeACode'], 'الموافقة وإرسال الرمز');
    expect(
      ar['byTappingAgreeAndSendMeA'] as String,
      contains('«الموافقة وإرسال الرمز»'),
    );
  });

  test('no button orders the app or the team', () {
    for (final key in [
      'iAgreeLetMeIn',
      'imACoachSetUpMyProfile',
      'agreeAndSendMeACode',
      'byTappingAgreeAndSendMeA',
      // The coach's own way on from C13 and K05 (R1-P16, R1-P15): addressed
      // to her, about her profile, never an order to the app.
      'setUpMyCoachProfile',
      'addPayoutLater',
      'iAgreeToTheseThreeRules',
    ]) {
      final value = ar[key] as String;
      expect(value, isNot(contains('أدخليني')), reason: key);
      expect(value, isNot(contains('أنشئي')), reason: key);
      expect(value, isNot(contains('أرسلوا')), reason: key);
    }
  });

  test('the dead bug is described, not translated word for word', () {
    expect(ar['deadBug'], isNot(contains('الحشرة')));
    expect(ar['deadBug'], 'رفع الذراع والساق المتقابلتين على الظهر');
  });
}
