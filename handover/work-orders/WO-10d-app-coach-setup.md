# WO-10d-app: PAY7, the coach's InstaPay address
Depends on: WO-10d0; server WO-10d-server (`set_coach_instapay_address`)
Size: M
Reads first: `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart` lines 60-90 and 190-215; `app/lib/ui/app_field.dart` lines 23-70; `app/lib/ui/app_scaffold.dart` lines 201-260; `app/test/features/private_coaching/member/member_browse_test.dart` lines 181-198 (the host pattern); `app/lib/routing/coaching_wiring.dart` lines 60-64; spec sections 4.4 and 13.12 item 7

## Why
A client can only pay the right woman if the address and name she sees are the coach's own, exactly as her bank shows them. A changed address is the way an account is taken over, so a change needs a fresh sign-in, a one-time code and a 24 hour wait. The receipt of a transfer to a phone-number address would show that number to the client, so only an `@` handle is allowed.

## Final result
Coach space (K18) gets one more row, "My InstaPay address". It opens PAY7, top to bottom:
1. Top bar: title "Your InstaPay address", back arrow.
2. A tonal card: "Clients pay you directly. Own Hub never holds the money." / "العميلات بيدفعولك على طول. Own Hub مابتمسكش الفلوس أبدًا." Below it, when she has an address, two plain lines: the address and the account name; when a change is waiting, a third line "Your new address starts working at {time}." / "العنوان الجديد هيشتغل الساعة {time}."
3. Field "InstaPay address" with helper "Use your @ address, not a phone number. A phone number would show on every client's receipt." / "استخدمي عنوان فيه @، مش رقم تليفون. الرقم هيظهر في إيصال كل عميلة."
4. Field "Account name, exactly as your bank shows it".
5. A note (sage): "A new address starts working after 24 hours. Clients with a payment waiting keep paying the old one, and we tell them." / "العنوان الجديد بيشتغل بعد 24 ساعة. العميلات اللي عندهم دفع مستني بيكملوا على العنوان القديم، وهنقولهم."
6. Footer, the one primary: "Send me a code" / "ابعتيلي كود".
After the code is sent, the two fields become read-only text, a field "Code" appears (6 digits) and the primary becomes "Confirm" / "أكّدي". Success shows the pending line (point 2) and the screen stays open.
Controls above the fold: back arrow, 2 fields (3 others) + 1 primary. In the code step: back, code field (2 others) + 1 primary. Budget test below.

## Files to edit or create
| path | create or edit | what changes in one line |
|---|---|---|
| app/lib/features/instapay/data/instapay_hub.dart | create | the one place a screen gets the repository (real, or a test override) |
| app/lib/features/instapay/domain/instapay_rules.dart | create | `validInstapayHandle`, `validAccountName`, `looksLikePhone` |
| app/lib/features/instapay/presentation/payment_text.dart | create | `paymentFailureText` used by every PAY screen |
| app/lib/features/instapay/presentation/instapay_address_view.dart | create | PAY7 |
| app/lib/features/private_coaching/presentation/coach/coach_space_view.dart | edit | the new row |
| app/test/features/instapay/support/instapay_host.dart | create | `host`, `phone`, `smallPhone` for every instapay test |
| app/test/features/instapay/instapay_address_view_test.dart | create | PAY7 tests |
| app/test/features/instapay/instapay_rules_test.dart | create | rule tests |

## Steps
1. File `app/lib/features/instapay/data/instapay_hub.dart` (create):
```dart
library;

import '../../../app_state/firebase_boot.dart';
import 'firestore_instapay_repository.dart';
import 'instapay_repository.dart';

/// Where a screen gets the repository. Tests set [override].
class InstapayHub {
  static InstapayRepository? override;
  static InstapayRepository? get repository =>
      override ?? (FirebaseBoot.isReady ? FirestoreInstapayRepository() : null);
}
```
2. File `app/lib/features/instapay/domain/instapay_rules.dart` (create). The pattern is the one the app already holds for this rail: `CoachingRails.accountPattern['instapay']` in `app/lib/features/private_coaching/domain/coaching_contract.dart` line 514, `^[a-z0-9._-]{3,40}@instapay$`, compared in lower case (verified in the file). UNVERIFIED against the live InstaPay rules (spec 4.4): ask the owner to read the InstaPay app's "create address" screen; if the real rule differs, change only this file and the contract constant.
```dart
library;

final RegExp _handle = RegExp(r'^[a-z0-9._-]{3,40}@instapay$');
final RegExp _phoneLike = RegExp(r'^[+0-9٠-٩\s-]{8,}$');

String _trim(String s) => s.trim();

/// True for `name@instapay`. A phone number is never a valid handle here.
bool validInstapayHandle(String raw) {
  final s = _trim(raw);
  return !_phoneLike.hasMatch(s) && _handle.hasMatch(s.toLowerCase());
}

bool looksLikePhone(String raw) => _phoneLike.hasMatch(_trim(raw));

/// 2 to 60 characters with at least one letter (Latin or Arabic).
bool validAccountName(String raw) {
  final s = _trim(raw);
  return s.length >= 2 &&
      s.length <= 60 &&
      RegExp(r'[A-Za-zء-ي]').hasMatch(s);
}
```
3. File `app/lib/features/instapay/presentation/payment_text.dart` (create). The reason codes are the server's (UNVERIFIED, compare with WO-10b): add a line per code the server really sends.
```dart
library;

import '../../../l10n/app_l10n.dart';
import '../data/instapay_repository.dart';

/// A calm sentence for a refusal. Never the raw code.
String paymentFailureText(AppL10n l10n, PaymentFailure f) {
  if (f.unreachable) return l10n.weCouldNotReachOwnHubCheck;
  return switch (f.reason) {
    'recent_login_required' => l10n.pleaseSignInAgainThenTryOnceMore,
    'otp_wrong' || 'otp_expired' => l10n.theCodeIsNotRightTryAgain,
    'bad_handle' => l10n.thatDoesNotLookLikeAnInstapayAddress,
    'rate_limited' => l10n.tooManyTriesPleaseWaitAWhile,
    'wrong_status' => l10n.thisPaymentChangedRefreshAndTryAgain,
    _ => l10n.weCouldNotDoThatTryAgainInAMoment,
  };
}
```
The getter names above are placeholders; use the names printed by `add_strings.py` (step 6) and fix this file. `weCouldNotReachOwnHubCheck` exists already (used in `coach_text.dart`).
4. File `app/lib/features/instapay/presentation/instapay_address_view.dart` (create). Full content:
```dart
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../data/instapay_hub.dart';
import '../data/instapay_local_store.dart';
import '../data/instapay_repository.dart';
import '../domain/instapay_models.dart';
import '../domain/instapay_rules.dart';
import 'payment_text.dart';

/// PAY7: the coach's InstaPay address.
class InstapayAddressView extends StatefulWidget {
  const InstapayAddressView({super.key, this.repository, this.onBack});
  final InstapayRepository? repository;
  final VoidCallback? onBack;

  @override
  State<InstapayAddressView> createState() => _InstapayAddressViewState();
}

class _InstapayAddressViewState extends State<InstapayAddressView> {
  final _address = TextEditingController();
  final _name = TextEditingController();
  final _otp = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String _error = '';
  DateTime? _startsAt;
  late final String _key = InstapayLocalStore.newKey();

  InstapayRepository? get _repo => widget.repository ?? InstapayHub.repository;

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  bool get _formOk =>
      validInstapayHandle(_address.text) && validAccountName(_name.text);

  Future<void> _primary() async {
    final l10n = AppL10n.of(context);
    final repo = _repo;
    if (repo == null || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (!_codeSent) {
        await repo.requestAddressChange(
          address: _address.text.trim(),
          accountName: _name.text.trim(),
          key: _key,
        );
        if (mounted) setState(() => _codeSent = true);
      } else {
        final at = await repo.verifyAddressChange(
          otp: _otp.text.trim(),
          key: '$_key-v',
        );
        if (mounted) {
          setState(() {
            _startsAt = at;
            _codeSent = false;
            _otp.clear();
          });
        }
      }
    } on PaymentFailure catch (f) {
      if (mounted) setState(() => _error = paymentFailureText(l10n, f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clock(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final repo = _repo;
    final ready = _codeSent ? _otp.text.trim().length == 6 : _formOk;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.yourInstapayAddress,
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      children: [
        AppCard(
          variant: AppCardVariant.tonal,
          children: [
            Text(l10n.clientsPayYouDirectlyOwnHubNeverHolds, style: AppText.bodyM),
            if (repo != null)
              StreamBuilder<CoachAddress?>(
                stream: repo.watchMyAddress(),
                builder: (context, snap) {
                  final a = snap.data;
                  if (a == null || a.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.address, textDirection: TextDirection.ltr, style: AppText.titleM),
                      Text(a.accountName, style: AppText.bodyM),
                    ],
                  );
                },
              ),
            if (_startsAt != null)
              Text(l10n.yourNewAddressStartsWorkingAtTime(_clock(_startsAt!)), style: AppText.bodyM),
          ],
        ),
        if (!_codeSent) ...[
          AppField(
            controller: _address,
            label: l10n.instapayAddress,
            hint: 'name@instapay',
            helper: looksLikePhone(_address.text)
                ? l10n.thatDoesNotLookLikeAnInstapayAddress
                : l10n.useYourAddressNotAPhoneNumber,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
          ),
          AppField(
            controller: _name,
            label: l10n.accountNameExactlyAsYourBankShowsIt,
            onChanged: (_) => setState(() {}),
          ),
          AppSageNote(l10n.aNewAddressStartsWorkingAfter24Hours),
        ] else
          AppField(
            controller: _otp,
            label: l10n.code,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() {}),
          ),
        if (_error.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(_error, style: AppText.bodyM.copyWith(color: AppColors.error)),
          ),
      ],
      footer: [
        AppButton(
          _codeSent ? l10n.confirm : l10n.sendMeACode,
          onPressed: (!ready || _busy || repo == null) ? null : () => unawaited(_primary()),
        ),
      ],
    );
  }
}
```
UNVERIFIED: `AppSageNote(String)` positional constructor (it is called `AppSageNote(l10n.membersCanAskToJoinYourPackages)` in `coach_space_view.dart` line about 238, so yes), `AppField` param names (read in `app_field.dart` lines 27-60: `label, hint, helper, errorText, keyboardType, textDirection, onChanged, controller`), and `l10n.confirm`, `l10n.code` may already exist (step 6 tells you which to drop).
5. File `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart`. Add the imports (top of file, with the other imports):
```dart
import '../../../../domain/flags/feature_flags.dart';
import '../../../../routing/app_router.dart' show AppRouter;
import '../../../instapay/presentation/instapay_address_view.dart';
```
UNVERIFIED: importing `app_router.dart` into a coaching view may create an import cycle that the project forbids. Run `grep -n "app_router.dart" app/lib/features/private_coaching/presentation/coach/*.dart`. If no other coach view imports it, use instead a constructor parameter: add `this.instapayOn = false` to `CoachSpaceView`, and in `app_router.dart` at the `'K18'` builder (about line 4983) pass `instapayOn: AppRouter.featureFlags.isOn(Feature.instapayPayments)`. Use the parameter route; it is the one the codebase uses (callbacks and values come in through the constructor).
Parameter route, exact edits. In class `CoachSpaceView` constructor (about line 30) add `this.instapayOn = false,` and the field `final bool instapayOn;`. In `app_router.dart` the K18 builder `CoachSpaceView(repository: repository,` (about line 4986) add the line `instapayOn: AppRouter.featureFlags.isOn(Feature.instapayPayments),` (the file is `AppRouter`'s own, so it is `featureFlags.isOn(...)`; check `grep -n "featureFlags.isOn" app/lib/routing/app_router.dart | head -3`).
6. Same file `coach_space_view.dart`. Anchor: the `_nav(` call whose title is `l10n.myPackages` (about line 192). Add directly after that `_nav(...)` call:
```dart
              if (widget.instapayOn)
                _nav(
                  title: l10n.myInstapayAddress,
                  subtitle: l10n.whereClientsSendYourFee,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => _push(const InstapayAddressView()),
                ),
```
And add the import `import '../../../instapay/presentation/instapay_address_view.dart';` (remove the other two imports of step 5).
7. File `app/test/features/instapay/support/instapay_host.dart` (create):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget host(Widget child, {String lang = 'en', double scale = 1}) => MaterialApp(
  locale: Locale(lang),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(Locale(lang)),
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: c!,
  ),
  home: child,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390x844 at 3.0
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1125, 2001); // 375x667 at 3.0
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}
```

## Strings to add
File `app/tool/_wo10d_strings.json` (delete after). Run `cd app && python3 tool/add_strings.py tool/_wo10d_strings.json` (it regenerates and runs `flutter gen-l10n`); use the getters it prints. Before running, for each key run `grep -n '"KEY"' 6-v2/i18n/ar-extra.json 6-v2/i18n/ar.json` and DROP from the JSON any key already present (the tool overwrites existing Arabic). `{time}` needs a `parameterised` block: `{"Your new address starts working at {time}.": {"description": "When the coach's new InstaPay address starts.", "placeholders": {"time": {"type": "String", "example": "14:30"}}}}`.
| English (key) | Egyptian Arabic |
|---|---|
| My InstaPay address | عنوان إنستا باي بتاعي |
| Where clients send your fee | فين العميلات بيحوّلولك فلوسك |
| Your InstaPay address | عنوان إنستا باي بتاعك |
| Clients pay you directly. Own Hub never holds the money. | العميلات بيدفعولك على طول. Own Hub مابتمسكش الفلوس أبدًا. |
| Your new address starts working at {time}. | العنوان الجديد هيشتغل الساعة {time}. |
| InstaPay address | عنوان إنستا باي |
| Use your @ address, not a phone number. A phone number would show on every client's receipt. | استخدمي عنوان فيه @، مش رقم تليفون. الرقم هيظهر في إيصال كل عميلة. |
| That does not look like an InstaPay address. It looks like name@instapay. | ده مش شكل عنوان إنستا باي. شكله اسم@instapay. |
| Account name, exactly as your bank shows it | اسم الحساب زي ما البنك بيعرضه بالظبط |
| A new address starts working after 24 hours. Clients with a payment waiting keep paying the old one, and we tell them. | العنوان الجديد بيشتغل بعد 24 ساعة. العميلات اللي عندهم دفع مستني بيكملوا على العنوان القديم، وهنقولهم. |
| Send me a code | ابعتيلي كود |
| Code | الكود |
| Confirm | أكّدي |
| The code is not right. Try again. | الكود مش مظبوط. جرّبي تاني. |
| Please sign in again, then try once more. | سجّلي دخول تاني وبعدين جرّبي مرة كمان. |
| Too many tries. Please wait a while. | محاولات كتير. استني شوية. |
| This payment changed. Refresh and try again. | الدفع ده اتغيّر. حدّثي الصفحة وجرّبي تاني. |
| We could not do that. Try again in a moment. | ماقدرناش نعمل كده. جرّبي تاني كمان شوية. |

## Tests to add or change
| file | test name | arrange, act and assert |
|---|---|---|
| instapay_rules_test.dart | `handle accepts name@bank and refuses phone numbers` | `validInstapayHandle('rahma.m@instapay')` true; `'RAHMA@InstaPay'` true; `'01012345678'`, `'+201012345678'`, `'٠١٠١٢٣٤٥٦٧٨'`, `'rahma'`, `'@instapay'`, `'rahma@cib'` all false |
| same | `account name needs letters` | `'Rahma M.'` true; `'12'`, `''`, `' '` false; a 61 character name false |
| instapay_address_view_test.dart | `the primary is off until both fields are valid` | pump `InstapayAddressView(repository: fake)` in `host`; button disabled; type `rahma@instapay` and `Rahma M.`; button enabled |
| same | `send code then confirm calls the repository twice with two keys` | enter fields, tap "Send me a code"; `fake.calls.first.$1 == 'requestAddressChange'`; the code field appears and the two fields vanish; enter `123456`, tap "Confirm"; `calls.last.$1 == 'verifyAddressChange'` |
| same | `a refusal shows a calm sentence` | `fake.failNext = const PaymentFailure('recent_login_required')`; tap send; the sign-in-again sentence is shown; no raw code text |
| same | `budget at 390x844 and 375x667, EN and AR, 200 percent` | for each combination `countControlsAboveFold(tester, includeChrome: false) <= 5` and `filledPrimaryActions(tester) == 1` (imports `test/helpers/control_counter.dart`, `test/helpers/primary_actions.dart`); the layout test also expects no `tester.takeException()` |
| same | `a phone number in the address field warns` | type `01012345678`; the helper text equals the "does not look like an InstaPay address" sentence |
Run: `cd app && flutter test test/features/instapay`

## Verify
- `cd app && dart analyze lib/features/instapay lib/features/private_coaching/presentation/coach lib/routing/app_router.dart` ends `No issues found!`
- `cd app && flutter test test/features/instapay test/features/private_coaching/coach` ends `All tests passed!`
- `cd app && flutter test test/qa/screen_budget_test.dart` still passes (the K18 row does not add to a budgeted screen).

## Do not
- Do not accept a phone number as an address. Do not store anything on the phone: the address lives on the server.
- Do not show the address change as done: the server says when it starts.
- Do not touch `packages_view.dart` or the old receiving-account code.
- No em dashes in any string.

## Done checklist
- [ ] hub, rules, text mapper, PAY7, the K18 row (behind `instapayOn`)
- [ ] strings added; getters in `payment_text.dart` fixed to the printed names
- [ ] tests pass in EN and AR at 200 percent

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10e2).

UNVERIFIED in this order: 4 (handle format rule, import cycle check, `AppField` and `AppSageNote` signatures, `featureFlags.isOn` call form).
