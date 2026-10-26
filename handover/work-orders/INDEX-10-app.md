# INDEX-10-app: InstaPay governed payments, app, staff dashboard and compliance side

Source of truth: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` (read all of it, section 13 overrides 4.1, 4.2 and 10). The server orders (WO-10a, 10b, 10c, 10d-server, 10l-server, 10m, 10n, 10o, 10p) are written by another agent. Where an app order needs a server fact that is not in spec section 6, it is written in the contract below and marked UNVERIFIED. Gemini: before starting WO-10d0, run `ls handover/work-orders | grep WO-10` and compare the server orders with the contract below. If a name or field differs, change ONLY `app/lib/features/instapay/data/instapay_callables.dart` and the `fromMap` of the model in WO-10d0 (every other order reads those two files). Write each difference to `handover/QUESTIONS.md`.

## Order of work (dependency order)

| order | file | what | depends on |
|---|---|---|---|
| 1 | WO-10d0-app-data-layer-and-flag | `Feature.instapayPayments`, models, `InstapayRepository`, Firestore and fake implementations, callable names, failure type, money text, saved sender handle store | server 10a, 10b |
| 2 | WO-10d-app-coach-setup | PAY7: coach InstaPay address, account name, one-time code, 24 hour delay; entry from the coach space | 10d0, server 10d |
| 3 | WO-10e1-pay1-payment-screen | PAY1: who to pay, exact amount, copy buttons, reference, three steps, countdown; entry from H05 | 10d0, 10d (InstapayHub) |
| 4 | WO-10e2-receipt-parser | pure Dart reader of OCR text: invariants, synonym lists, card-message detection, never throws | 10d0 |
| 5 | WO-10e3-picker-crop-redact-ocr | add `google_mlkit_text_recognition`, multi-image picker, crop, black-out brush, on-device OCR service | 10e2 |
| 6 | WO-10e4-pay2-submit-proof-offline | PAY2: autofilled summary, sender handle, send, offline queue | 10e1, 10e3 |
| 7 | WO-10e5-pay3-status-and-pay6-add-proof | PAY3 timeline and PAY6 add proof after a dispute | 10e4 |
| 8 | WO-10f1-coach-inbox-pay4 | PAY4: inbox, auto-open of a single waiting payment, "I received it", "A client paid me" | 10d0, 10d |
| 9 | WO-10f2-coach-decision-pay5 | PAY5: not received (with her own statement screenshot), different amount, auto-confirm toggle | 10f1 |
| 10 | WO-10g-refunds-and-service-dispute | PAY8: client refund request and service problem, coach record refund | 10e5, 10f1 |
| 11 | WO-10h1-coach-statement-pay9 | PAY9: monthly statement, "Mark fee as paid" | 10f1 |
| 12 | WO-10h2-payment-record-pay10 | PAY10: draw and save or share the payment record as an image | 10e5 |
| 13 | WO-10i1-admin-disputes-logic | staff dashboard pure logic: evidence summary of the 7 items, recommended decision, reason rule, second-reviewer state | server 10b, 10o |
| 14 | WO-10i2-admin-disputes-tab | the "Disputes" tab, strikes list, address-change alerts, fee overview | 10i1 |
| 15 | WO-10j1-notification-texts | every push text EN and AR, the new kinds, tap routing | 10d0, 10f1 |
| 16 | WO-10j2-privacy-and-site | privacy policy, terms and coach terms in `site/_build`, EN and AR | none |
| 17 | WO-10j3-store-answers-and-terms-drafts | App Store privacy answers, Play data safety, manifest, DRAFT FOR COUNSEL texts | 10j2 |
| 18 | WO-10k1-test-program | every test of spec sections 7, 13.9, 13.10 as a file list with test names | all above |
| 19 | WO-10k2-manual-script-and-fixtures | the two-phone transfer script and the fixtures folder spec | 10k1 |
| 20 | WO-10q-store-compliance | Apple 3.1 and Google Payments policy reading, risks, review-notes paragraph, questions | none |

WO-10q and WO-10j2 have no code dependency and can be done first by a different agent.

## The contract the app orders rely on (server facts; each item UNVERIFIED until compared with WO-10a and WO-10b)

Money: the unit is PIASTERS everywhere in the new feature (`amountPiasters`, int). 500.37 EGP is 50037. The existing app uses whole pounds (`priceFinalEgp`); never mix them. Display with `egpText` (WO-10d0).

Firestore documents the app reads (never writes): `payments/{paymentId}` with the fields of spec section 2, in camelCase: `clientUid, coachUid, packageId, amountPiasters, reference, addressSnapshot{address, accountName}, status, createdAt, expiresAt, accessUntil, riskOutcome (green|amber|red|null), reasons[], proof{txnNumber, screenshotPaths[], submittedAt, paidAtClaimed}, coachDecision{confirmedAt, notReceivedAt, reasonCode, differentAmountPiasters}, dispute{openedBy, openedAt, staffDecision, decidedAt, reasonText}, refund{requestedAt, txnNumber, amountPiasters, recordedAt}, feePiasters`; subcollection `payments/{paymentId}/events/{eventId}` with `{at, by, from, to, note}`; `coachPayoutProfiles/{coachUid}` UNVERIFIED name for the coach address block `{address, accountName, pendingAddress, pendingAccountName, effectiveAt, status, autoConfirm}`; `feeStatements/{coachUid_YYYY-MM}` UNVERIFIED `{month, lines[{paymentId, amountPiasters, feePiasters, status}], totalFeePiasters, status, paidTxn}`. Status wire values: `awaiting_payment, proof_submitted, confirmed, expired, cancelled, coach_not_received, in_review, resolved_paid, resolved_unpaid, different_amount, refund_requested, refunded, refund_denied, service_dispute`.

Callables (spec section 6 names; request fields are this app's assumption). Every request carries `idempotencyKey` (client generated, 24 hex) and `locale`:
- `create_payment {subId, packageId}` -> `{paymentId, reference, amountPiasters, expiresAt, status}`
- `submit_payment_proof {paymentId, txnNumber, paidAtClaimed, senderHandle, screenshotPaths[], phoneReading{}, addEvidence}` -> `{status, riskOutcome, reasons[]}`. NAME CLASH: an older callable of the same name takes `subId` (`functions/main.py:2145`, used by `CoachingRepository.submitPaymentProof`). Do not extend the old shape. The app sends `paymentId`; the server must branch or rename. Question Q1.
- `coach_confirm_payment {paymentId, bankSmsPath?}`; `coach_mark_not_received {paymentId, reasonCode, note, searchedTick, statementPath}`; `coach_mark_different_amount {paymentId, amountPiasters, acceptLower}`; `coach_report_payment {subId, txnNumber}`; `client_confirm_coach_report {paymentId, accept}`
- `set_coach_instapay_address {step: request|verify, address, accountName, otp}` -> `{effectiveAt}`
- `request_refund {paymentId, reasonCode, note}`; `record_refund {paymentId, amountPiasters, txnNumber}`. NAME CLASH: a staff callable `record_refund {subId,...}` exists (`functions/main.py:2208`, called by `admin-web/coaching.js:661`). Question Q2.
- `open_service_dispute {paymentId, reasonCode, note}`
- Staff: `staff_resolve_payment {paymentId, decision, reason, amountPiasters?}`, `staff_set_coach_payment_status {coachUid, status, reason}`.

Storage: client uploads each screenshot to `payment-proofs/{paymentId}/{idempotencyKey}-{n}.png` (PNG, not JPEG: the phone redraws the picture with the hidden lines and `dart:ui` writes PNG; rules from WO-10a must allow `image/png`) in the personal bucket (`FirebaseBoot.personalMedia`) before calling `submit_payment_proof`.

Push kinds (generic text, no amounts, payload is the kind only, as `functions/coaching/push.py` says): client `instapayReminder, instapayConfirmed, instapayNotReceived, instapayReviewStarted, instapayReviewDecided, instapayRefundRecorded, instapayCoachReported`; coach `instapayProofSent, instapayCoachReminder, instapayDisputeOpened, instapayCoachReviewDecided, instapayStatementReady, instapayAddressChanged`.

## Cross-agent questions (put each in handover/QUESTIONS.md with the file and line you saw)
- Q1 `submit_payment_proof` name clash (above). Q2 `record_refund` name clash; the dashboard order WO-10i2 does not use it.
- Q3 Not in spec section 6 but needed by the screens: a callable to mark a fee statement paid (`mark_fee_statement_paid {statementId, txnNumber}`), one to switch auto-confirm (`set_auto_confirm {enabled}`), staff list and detail callables (`list_payment_disputes {state, after}`, `get_payment_evidence {paymentId}`), `list_coach_payment_flags`, `list_address_change_alerts`, `list_fee_statements`. The app and dashboard orders name them in `instapay_callables.dart` and `admin-web/disputes.js`; the server agent must add them or give the real names.
- Q4 Two-staff approval: the server enforces it (`staff_set_coach_payment_status` returns `{status: "waiting_second_reviewer"}`); the dashboard only shows it.
- Q5 The OCR phone reading is a hint. The server re-reads (spec 13.3). The field `phoneReading` is stored for staff, never trusted.

## Decisions taken in these orders (owner may change; each is one line to change)
1. The Dart flag `Feature.instapayPayments` is added by WO-10d0 (not by WO-10p). Its parent is `marketplace`, NOT `payments` (`payments` ships false, so a child of it could never open). WO-10p only adds the server switch `config/payments.enabled` and the read of it; tell that agent.
2. Coach confirm in 2 taps from the notification: the push stays kind-only; tapping `instapayProofSent` opens PAY4, which opens the detail sheet by itself when exactly one payment is waiting; the second tap is "I received it".
3. Lock screen text has no amounts (spec 8 default). Spec 13.12 item 8 (amount and transaction number for the coach) is shown on screen inside PAY4 after she opens it.
4. The review-notes box is 3,961 of 4,000 characters (`docs/release/review-notes.md`); WO-10q names what to cut.
5. PAY screens are pushed with `MaterialPageRoute` like the other private-coaching screens, with no new id in `appRoutes` (adding one means editing the generator `6-v2/src/inventory.mjs`, which this release does not need). The ids PAY1..PAY10 are constants in `instapay_screens.dart` (WO-10d0).
6. Staff disputes with a woman's private data go to the `womanReviewer` claim; the tab is NOT hidden by `PAYMENTS_LIVE` (spec 10: disputes stay resolvable when the switch is off).

## Controls budget per screen (limit: 1 filled primary, at most 5 other controls above the fold at 390x844; chrome and tab bar not counted)
PAY1 4 other + 1 primary; PAY2 4 + 1; PAY3 2 + 1 (state dependent, max 1 primary); PAY4 list 3 + 1 (sheet 3 + 1); PAY5 4 + 1; PAY6 3 + 1; PAY7 3 + 1; PAY8 3 + 1; PAY9 3 + 1; PAY10 2 + 1. Each order shows its own count and its test.

## Findings that changed the plan (verified in the code on 27 Oct 2026)
1. The phone OCR package is not in `pubspec.yaml` (only `google_mlkit_face_detection 0.15.1` and `google_mlkit_commons 0.13.0`). WO-10e3 adds `google_mlkit_text_recognition`. ML Kit v2 reads Latin script and digits; I believe it has no Arabic model (UNVERIFIED, WO-10e3 step 1 shows the command). So the phone reading is a hint for Latin text; Arabic-only receipts are amber on the phone and the server decides.
2. The app opens no screen from a remote push today (`NotificationTaps` handles local reminders only; `push_registration.dart` only watches the approval push). WO-10j1 adds `PaymentPushTaps`; without it "2 taps from the notification" is false.
3. The app already holds an InstaPay address pattern: `CoachingRails.accountPattern['instapay'] = ^[a-z0-9._-]{3,40}@instapay$` (`coaching_contract.dart` line 514). PAY7 uses it, so a coach cannot save a phone number.
4. `Outbox` (`app/lib/data/sync/outbox.dart`) is built for Firestore field writes and has no instance in `lib`; the offline proof queue is a new small class (`pending_proofs.dart`, WO-10e4) keyed by the idempotency key.
5. `profile_photo_crop.dart` crops squares only; PAY2's hide and crop step is new (WO-10e3), using the `RepaintBoundary`/`toImage` pattern of `share_progress_view.dart`.
6. Two callable names clash with older callables (`submit_payment_proof`, `record_refund`): Q1, Q2.
7. The review-notes box is 3,961 of 4,000 characters and opens with "No ads and no purchases": WO-10q names the cuts and the exact paragraph. Every store-policy conclusion is NOT VERIFIED with Apple or Google; the two main risks are Apple 3.1.3(d) limiting person-to-person services to real-time ones, and Google's 1:1 exemption requiring the service not to be replayable (saved plans and chat). The fallback is the server switch.
8. The existing dashboard tests assert the exact coaching tab lists (`logic.test.mjs` 619-629), so the new tab uses its own list in `disputes-logic.js` and does not touch `COACHING_TABS` or `PAYMENTS_LIVE`.

## Dependency note
Every screen order (10e1 to 10h2) also needs WO-10d-app, which creates `InstapayHub`, `payment_text.dart` and the test host `instapay_host.dart`. Do 10d0, then 10d-app, then the rest in the table order.

## UNVERIFIED tally
Counted per order (each order ends with its own line): 10d0 3, 10d-app 4, 10e1 4, 10e2 1, 10e3 7, 10e4 4, 10e5 4, 10f1 3, 10f2 3, 10g 1, 10h1 1, 10h2 0, 10i1 1, 10i2 3, 10j1 4, 10j2 5, 10j3 3, 10k1 4, 10k2 2, 10q 3 (+ all policy conclusions, "not verified with Apple/Google" by design). Total in the orders: 60. Plus the contract items in this file (the whole "contract" section is UNVERIFIED until compared with the server orders).
