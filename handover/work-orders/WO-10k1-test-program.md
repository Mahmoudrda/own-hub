# WO-10k1: the test program (every test of spec sections 7, 13.9 and 13.10)
Depends on: all app, dashboard and compliance orders of this series (10d0 to 10j3); the server orders for the server rows
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` sections 7, 10, 13.9, 13.10; `app/test/qa/screen_budget_test.dart` lines 90-140; `app/test/helpers/control_counter.dart` (exports `countControlsAboveFold`); `app/test/features/instapay/support/instapay_host.dart`; `app/tool/e2e_coaching.sh` lines 1-30; `ls test/rules` (the Firestore rules tests live there; UNVERIFIED layout)

## Why
The feature is live, so nothing ships unless every case the spec lists has a named test that fails when the rule breaks. This order is the map: for each item of the spec, the file, the test name and which work order writes it. The few tests that belong to no screen (the switch, the source guards, the state matrix, the tap counts, deletion) are written here in full.

## Final result
1. The coverage table below, complete, with an owner order for every row.
2. Five new app test files written here: `instapay_states_matrix_test.dart`, `tap_count_test.dart`, `switch_off_test.dart`, `source_guards_test.dart`, `deletion_test.dart`.
3. The table copied into `handover/QUESTIONS.md` under "Payments test map" for the server agent to confirm its file and test names (names in the server rows are PROPOSED here and are the server orders' to fix).
Run at the end: `cd app && flutter test test/features/instapay test/release test/domain/flags`, `cd functions && venv/bin/python -m pytest tests -q -k payment`, `cd admin-web && node --test`, rules tests as the repo runs them.

## The coverage table
Layer: S server pytest, R Firestore rules, T storage rules, A app, D dashboard, M manual, E emulator end to end.
### Spec section 7
| # | spec | layer | file | test name | written by |
|---|---|---|---|---|---|
| 1 | 7.1 every legal transition | S | functions/tests/test_payments_state_machine.py | `test_every_legal_transition` | server 10b |
| 2 | 7.1 every illegal transition rejected | S | same | `test_every_illegal_transition_is_refused` | server 10b |
| 3 | 7.1 idempotency | S | same | `test_same_key_makes_one_payment` | server 10b |
| 4 | 7.1 expiry and late proof within 7 days | S | same | `test_expires_after_24h_late_proof_accepted_within_7_days` | server 10c |
| 5 | 7.1 48 and 72 hour escalation, fake clock | S | functions/tests/test_payments_scheduled.py | `test_48h_reminder_and_72h_in_review` | server 10c |
| 6 | 7.2 reused txn number | S | functions/tests/test_payments_fraud.py | `test_reused_transaction_number_is_rejected` | server 10m |
| 7 | 7.2 reused screenshot hash | S | same | `test_reused_image_hash_flags_red` | server 10l |
| 8 | 7.2 wrong, partial, over amount | S | same | `test_wrong_partial_over_amount` | server 10m |
| 9 | 7.2 address change delay and notices | S | same | `test_address_change_waits_24h_and_notifies` | server 10d |
| 10 | 7.2 coach strikes and suspension | S | functions/tests/test_payments_strikes.py | `test_two_strikes_in_90_days_suspend` | server 10o |
| 11 | 7.2 client strikes | S | same | `test_client_two_strikes_remove_method` | server 10o |
| 12 | 7.2 rate limits (3 requests a day, 3 disputes a month, 5 uploads) | S | functions/tests/test_payments_limits.py | `test_rate_limits` | server 10b |
| 13 | 7.3 client cannot confirm | S | functions/tests/test_payments_roles.py | `test_client_cannot_confirm` | server 10b |
| 14 | 7.3 coach cannot activate without a record | S | same | `test_coach_cannot_activate_without_record` | server 10b |
| 15 | 7.3 reviewer cannot edit amounts | S+R | same + test/rules | `test_reviewer_cannot_edit_amount`, `payments: no client or staff write` | server 10a/10b |
| 16 | 7.3 no cross-coach reading | R | test/rules | `payments: another coach cannot read` | server 10a |
| 17 | 7.3 no phone number leak | S | test_payments_roles.py | `test_no_phone_in_any_payment_payload` | server 10b |
| 18 | 7.4 storage rules for proofs | T | test/rules (storage) | `payment-proofs: parties and staff only` | server 10a |
| 19 | 7.4 no analytics event carries payment data | A | app/test/features/instapay/source_guards_test.dart | `no analytics call in the instapay feature` | here |
| 20 | 7.4 deletion keeps pseudonymised record | S | test_payments_privacy.py | `test_deletion_pseudonymises_record_deletes_screenshots` | server 10a |
| 21 | 7.4 export includes own payments | S | same | `test_export_includes_own_payments` | server 10a |
| 22 | 7.5 widget tests every screen state, EN and AR, 390x844, 375x667, 200% | A | app/test/features/instapay/instapay_states_matrix_test.dart | `matrix` | here |
| 23 | 7.5 budget tests | A | each screen's test file | `budget ...` | 10d-app to 10h2 |
| 24 | 7.5 pay path at most 4 taps | A | tap_count_test.dart | `pay path is 4 taps` | here |
| 25 | 7.5 coach confirm 2 taps from the notification | A | same | `coach confirm is 2 taps from the notification` | here |
| 26 | 7.6 e2e pay, proof, confirm, active | E | functions/tools/e2e_payments.py | `journey_pay_confirm` | server 10b |
| 27 | 7.6 pay, not received, review, resolved paid / unpaid | E | same | `journey_dispute_paid`, `journey_dispute_unpaid` | server 10n |
| 28 | 7.6 refund | E | same | `journey_refund` | server 10b |
| 29 | 7.6 fee statement totals | E | same | `journey_fee_statement` | server 10c |
| 30 | 7.7 manual two-phone transfer | M | handover/work-orders/WO-10k2-manual-script-and-fixtures.md | the script | WO-10k2 |
| 31 | 10 switch off leaves every existing screen unchanged | A | switch_off_test.dart | `switch off hides every payment entry` | here |
| 32 | 10 switch off mid payment: open payments readable and resolvable | S+A | test_payments_killswitch.py + switch_off_test.dart | `test_open_payments_resolvable_when_off`, `status screen still reads when off` | server 10p + here |
### Spec section 13.9 (each case)
| # | case | layer | file | test name | by |
|---|---|---|---|---|---|
| 33 | failed or pending status screenshot is RED | S, A | test_payments_receipt_checks.py; receipt_reader_test.dart | `test_failed_status_red`; `failed or pending status is red` | server 10l; 10e2 |
| 34 | transfer to another account showing the coach's name | S | test_payments_receipt_checks.py | `test_same_name_other_address_is_red_or_amber` | server 10l |
| 35 | same screenshot for two coaches | S | test_payments_fraud.py | `test_same_image_two_coaches_flags_red` | server 10l |
| 36 | cropped screenshot hiding the amount | S, A | same; receipt_reader_test.dart | `test_cropped_amount_hidden_is_amber`; `each invariant missing on its own is amber` | server 10l; 10e2 |
| 37 | language the OCR does not read | S, A | same | `test_unreadable_language_amber`; amber variant | server 10l; 10e2 |
| 38 | dark mode or high contrast screenshot | S | same | `test_dark_mode_fixture_reads` | server 10l |
| 39 | very long names | A, S | receipt_reader_test.dart; same | `a long name and a masked name still match`; `test_long_name` | 10e2; server 10l |
| 40 | two payments with the same amount at once (unique piasters) | S | test_payments_amounts.py | `test_unique_piaster_collision_rejected_at_creation` | server 10m |
| 41 | coach changes address after proof (snapshot wins) | S | test_payments_fraud.py | `test_snapshot_wins_after_address_change` | server 10d |
| 42 | coach suspended between payment and confirmation | S | test_payments_strikes.py | `test_suspension_does_not_hurt_open_client` | server 10o |
| 43 | pays after the request expired (7 days) | S | test_payments_state_machine.py | (row 4) | server 10c |
| 44 | coach confirms then disputes (final unless reopened) | S | same | `test_confirmation_is_final_unless_staff_reopen` | server 10b |
| 45 | service dispute after a green payment | S, A | same; refund_request_view_test.dart | `test_service_dispute_after_green`; `service mode calls openServiceDispute` | server 10b; 10g |
| 46 | staff disagreement (second reviewer) | S, D | test_payments_strikes.py; disputes-logic.test.mjs | `test_suspension_needs_two_staff`; `approvalState` | server 10o; 10i1 |
| 47 | kill switch off mid-dispute | S | test_payments_killswitch.py | `test_disputes_resolvable_when_off` | server 10p |
| 48 | offline submission | A | pending_proofs_test.dart; proof_view_test.dart | `no signal queues the proof`; `add then flush sends with the stored key` | 10e4 |
| 49 | clock skew (server clock rules) | S | test_payments_state_machine.py | `test_phone_time_is_only_a_claim` | server 10b |
| 50 | daylight saving (UTC storage) | S, A | same; status_view_test.dart | `test_dst_stored_utc`; `timeline lists events in order in Cairo time` | server 10b; 10e5 |
| 51 | double tap (idempotency) | S, A | row 3; proof_view_test.dart | `send calls the repository once with the same key on a second tap` | server 10b; 10e4 |
| 52 | reused txn by a different client: RED and both reported | S | test_payments_fraud.py | `test_reused_txn_other_client_red_and_reported` | server 10m |
| 53 | image bombs and oversize rejected before OCR | S, A | test_payments_receipt_checks.py; redact_view_test.dart | `test_oversized_rejected_before_ocr`; `decodeCapped returns null for garbage bytes` | server 10l; 10e3 |
### Spec section 13.10
| # | requirement | layer | file | test name | by |
|---|---|---|---|---|---|
| 54 | a unit test per deterministic check with fixtures | S, A | test_payments_receipt_checks.py; receipt_reader_test.dart | one test per check (amount, name or address, status phrase, time window, txn format) | server 10l; 10e2 |
| 55 | OCR accuracy: 95 percent of real fixtures GREEN | S | test_payments_ocr_accuracy.py | `test_real_fixtures_95_percent_green` | server 10l (fixtures: WO-10k2) |
| 56 | no real fixture is RED | S | same | `test_no_real_fixture_red` | server 10l |
| 57 | tamper heuristics only change the score | S | test_payments_tamper.py | `test_tamper_never_blocks_alone` | server 10m |
| 58 | coach statement auto-reject state-machine test | S, A | test_payments_nonreceipt.py; coach_rules_test.dart | `test_statement_with_payment_rejects_claim`; `statementShowsPayment ...` | server 10n; 10f2 |
| 59 | OCR latency under 10 seconds (phone and server) | S, M | test_payments_ocr_load.py; manual script step 9 | `test_ocr_latency_under_10s` | server 10l; WO-10k2 |
| 60 | screenshots stored privately, hashed, stripped, removed on schedule | S, T | test_payments_privacy.py | `test_screenshots_private_hashed_stripped_and_swept` | server 10a/10c |
| 61 | Arabic and English strings: Western digits, no em dash | A | source_guards_test.dart | `instapay strings have no em dash and no Arabic-Indic digit` | here |
| 62 | dashboard logic | D | admin-web/disputes-logic.test.mjs | (WO-10i1 list) | 10i1 |
| 63 | store declarations | A | app/test/release/store_disclosures_test.dart | `payments: ... are declared` | 10j3 |
| 64 | push texts calm and generic | S | functions/tests/test_instapay_push_texts.py | `test_text_is_generic_and_calm` | 10j1 |

## Files to edit or create (written here)
| path | create or edit | what changes |
|---|---|---|
| app/test/features/instapay/instapay_states_matrix_test.dart | create | row 22 |
| app/test/features/instapay/tap_count_test.dart | create | rows 24, 25 |
| app/test/features/instapay/switch_off_test.dart | create | rows 31, 32 |
| app/test/features/instapay/source_guards_test.dart | create | rows 19, 61 |
| app/test/features/instapay/deletion_test.dart | create | pending queue cleared |
| handover/QUESTIONS.md | edit | the map for the server agent |

## Steps
1. File `app/test/features/instapay/source_guards_test.dart` (create):
```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  final files = _dart('lib/features/instapay');

  test('no analytics call in the instapay feature', () {
    for (final f in files) {
      final s = f.readAsStringSync();
      expect(s.contains('analytics.track'), isFalse, reason: f.path);
      expect(s.contains('AnalyticsGateway'), isFalse, reason: f.path);
      expect(s.contains('Crashlytics'), isFalse, reason: f.path);
    }
  });

  test('the app never writes a payment: no set, update or add on Firestore', () {
    for (final f in files) {
      final s = f.readAsStringSync();
      expect(RegExp(r"\.(set|update|add|delete)\(").hasMatch(s) && s.contains('collection('), isFalse, reason: f.path);
    }
  });

  test('instapay source has no em dash', () {
    for (final f in files) {
      expect(f.readAsStringSync().contains('—'), isFalse, reason: f.path);
    }
  });

  test('instapay strings have no em dash and no Arabic-Indic digit', () {
    final arb = File('lib/l10n/app_ar.arb').readAsStringSync();
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    // the keys come from the strings of this series; list them once, from the JSON files
    final marker = ['InstaPay', 'إنستا باي'];
    for (final line in arb.split('\n').where((l) => marker.any(l.contains))) {
      expect(RegExp(r'[٠-٩]').hasMatch(line), isFalse, reason: line);
      expect(line.contains('—'), isFalse, reason: line);
    }
    for (final line in en.split('\n').where((l) => l.contains('InstaPay'))) {
      expect(line.contains('—'), isFalse, reason: line);
    }
  });

  test('no screen prints a raw server reason code', () {
    for (final f in files.where((f) => f.path.contains('presentation'))) {
      final s = f.readAsStringSync();
      expect(RegExp(r"Text\([^)]*\.reason").hasMatch(s), isFalse, reason: f.path);
    }
  });
}
```
2. File `app/test/features/instapay/tap_count_test.dart` (create). Arrange: `FakeInstapayRepository` with one `awaitingPayment` payment (`address` and `amountPiasters` set); a `MyCoachView` for a subscription in `awaitingPayment` with `onPay` wired to push `PaymentView(repository: fake, onIHavePaid: ...)`. Test `pay path is 4 taps`: count taps with a helper `var taps = 0; Future<void> tap(Finder f) async { await tester.tap(f); taps++; await tester.pumpAndSettle(); }`; sequence: `tap(find.byKey(ValueKey('pay-now')))`, `tap(copy-amount)`, `tap(copy-address)`, `tap(i-have-paid)`; assert `taps == 4` and that the callback ran. Test `coach confirm is 2 taps from the notification`: count 1 for the notification (`PaymentPushTaps.open(key, 'instapayProofSent')`), pump, assert `look-for` text is visible (sheet opened by itself, no tap), tap `received` (tap 2); assert `fake.calls.last.$1 == 'coachConfirm'` and `taps == 2`.
3. File `app/test/features/instapay/switch_off_test.dart` (create). `setUp`: `AppRouter.featureFlags = AppRouter.featureFlags.with_({Feature.instapayPayments: false})`; `tearDown` restores. Tests: `switch off hides every payment entry`: (a) `MyCoachView(onPay: null, onSeePayment: null)` with a subscription in `awaitingPayment` shows neither `pay-now` nor `see-payment`; (b) `CoachSpaceView(instapayOn: false, ...)` shows no "My InstaPay address" or "Payments" row (use the `coach_fake.dart` helpers); (c) `PaymentPushTaps.open(key, 'instapayProofSent')` pushes nothing (navigator `canPop` stays false); (d) `Feature.instapayPayments` with `FeatureFlags.shipped.with_({marketplace: false}).isOn(...)` is false (parent off turns it off). `status screen still reads when off`: with the flag off, pump `PaymentStatusView(paymentId:'p1', repository: fake)` directly (opened from an old route) and assert the status word still shows (the screen itself does not check the flag; only entries do, spec 10). Also the existing `test/qa/screen_budget_test.dart` is run unchanged as the "every existing screen unchanged" check.
4. File `app/test/features/instapay/deletion_test.dart` (create): `SharedPreferences.setMockInitialValues({})`, `Directory.systemTemp.createTempSync()`; `PendingProofs(dir: tmp).add(proof, [Uint8List(3)])`; call the "Delete everything" function found in WO-10e4 step 3 (its name is recorded in `handover/QUESTIONS.md` by that order); assert `PendingProofs(dir: tmp).all()` is empty and the file is gone. If that function was not found, write the test as `skip: 'WO-10e4: delete-everything hook not found, see QUESTIONS.md'` and keep the skip visible in the report.
5. File `app/test/features/instapay/instapay_states_matrix_test.dart` (create). One file, a map of state builders and four loops:
```dart
final builders = <String, Widget Function(FakeInstapayRepository)>{
  'PAY1 open': (r) => PaymentView(subId: 's', packageId: 'pk', repository: r, onIHavePaid: (_) {}),
  'PAY2 first payment': (r) => ProofView(payment: kAwaiting, repository: r, onSent: (_, {required queued}) {}),
  'PAY2 evidence': (r) => ProofView(payment: kNotReceived, addEvidence: true, repository: r, onSent: (_, {required queued}) {}),
  for (final s in PaymentStatus.values)
    'PAY3 ${s.wire}': (r) => PaymentStatusView(paymentId: 'p1', repository: r, onAction: (_, __) {}),
  'PAY4 waiting': (r) => CoachPaymentsView(repository: r),
  'PAY5 not received': (r) => CoachDecisionView(payment: kProof, mode: DecisionMode.notReceived, repository: r),
  'PAY5 different amount': (r) => CoachDecisionView(payment: kProof, mode: DecisionMode.differentAmount, repository: r),
  'PAY7 edit': (r) => InstapayAddressView(repository: r),
  'PAY8 refund': (r) => RefundRequestView(payment: kConfirmed, kind: ProblemKind.refund, repository: r),
  'PAY8 service': (r) => RefundRequestView(payment: kConfirmed, kind: ProblemKind.service, repository: r),
  'PAY9 unpaid': (r) => FeeStatementView(repository: r),
  'PAY10 record': (r) => PaymentRecordView(payment: kConfirmed, onShare: (_, __, ___) async {}),
};
```
Define `kAwaiting`, `kProof`, `kNotReceived`, `kConfirmed` as `Payment(...)` constants with address `rahma.m@instapay` / `Rahma M.`, amount 50037, reference `OH-4821`, `createdAt` and `expiresAt` set. For `PAY3 <status>`, set the repository payments to a payment with that status before pumping (`r.setPayments([kConfirmed.copyWithStatus(s)])`: write a tiny test helper `Payment withStatus(Payment p, PaymentStatus s)` in the test file that rebuilds the constructor). Loops: `for locale in ['en','ar'] for size in [phone, smallPhone] for scale in [1.0, 2.0]`: pump with `host(child, lang:, scale:)`, `pumpAndSettle`; `expect(tester.takeException(), isNull)`; at (390x844, scale 1.0) also `expect(countControlsAboveFold(tester, includeChrome: false), lessThanOrEqualTo(5))` and `expect(filledPrimaryActions(tester), lessThanOrEqualTo(1))`. Test name: `'$name, $locale, ${size}, x$scale'`. UNVERIFIED: `Payment` has no `copyWith`; the helper rebuilds it. ~14+14+... about 40 states x 8 combinations = 320 tests; if the run exceeds 4 minutes, tag the file `@Tags(['qa'])` like `screen_budget_test.dart` and run it with `flutter test --tags qa`.
6. Copy the three tables above into `handover/QUESTIONS.md` under "Payments test map". Run the full command list of "Final result" and paste the real counts into the report.

## Strings to add
None.

## Tests to add or change
The five files above. Their test names are the ones in the table (rows 19, 22, 24, 25, 31, 32, 61) plus `no screen prints a raw server reason code`, `the app never writes a payment`, `instapay source has no em dash`, and the deletion test.
Run: `cd app && flutter test test/features/instapay`

## Verify
- `cd app && flutter test test/features/instapay` ends `All tests passed!` (skips are listed in the report).
- `cd app && dart analyze test/features/instapay` ends `No issues found!`
- every row of the table has an existing test file or a named server order; no row says "TBD".

## Do not
- Do not weaken a budget or delete a test to make the matrix pass: fix the screen.
- Do not use real names, phone numbers or account digits in any fixture.
- Do not hide a skipped test: report it.

## Done checklist
- [ ] five files written and green; the map copied to QUESTIONS.md
- [ ] the final command list run and counts reported

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10k2).

UNVERIFIED in this order: 4 (`test/rules` layout, `Payment` has no copyWith, the delete-everything function name, server test file names are proposals).
