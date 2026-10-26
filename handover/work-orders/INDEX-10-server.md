# INDEX-10-server: InstaPay governed payments, SERVER side

Source of truth: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` (13 overrides 4.1, 4.2, 10; 13.13 overrides the template parts of 13.3 and 13.12). Written 27 Oct 2026. The app, dashboard and compliance orders are in `INDEX-10-app.md`. Nothing here was run: all code in these orders is unexecuted and each order ends with the tests that prove it. All money is integer PIASTERS (500.37 EGP = 50037).

## Order of work (the dependency order of the code; it differs from the spec's section 11 list only because the server code needs 10m and 10l before 10b)

| # | file | summary | depends on |
|---|---|---|---|
| 1 | `WO-10a-payments-rules.md` | Firestore rules (parties read, nobody writes), storage note, 6 indexes, rules tests and storage tests | none |
| 2 | `WO-10a2-payments-model-and-states.md` | `functions/payments/` package: refusal codes, limits, the transition table as code (`states.TRANSITIONS`), event writer, idempotency, push texts EN and Egyptian Arabic, kill-switch read, test helpers | none |
| 3 | `WO-10a3-payments-deletion-export-retention.md` | account deletion keeps a pseudonymised record and drops pictures, export carries her payments, weekly screenshot retention | 10a2 |
| 4 | `WO-10m-amount-reference-risk.md` | unique piaster amount with lock documents, `OH-XXXXXX` reference, tamper score, GREEN/AMBER/RED `decide` | 10a2 |
| 5 | `WO-10l-server-receipt-checks.md` | OCR adapter (Cloud Vision, already installed), the pure invariant checks of 13.3/13.12/13.13, fixtures, image gate | 10m |
| 6 | `WO-10b-state-machine-create-cancel-activation.md` | `create_payment`, `cancel_payment`, access grant/end, hook into `request_coaching`/`respond_coaching_request` (`instapay` flag) | 10a, 10a2, 10m |
| 7 | `WO-10d-server-coach-address-setup.md` | `set_coach_instapay_address` (handle not phone, fresh sign-in, 24 hour delay, alerts, notices), `set_coach_payment_options` | 10b |
| 8 | `WO-10b2-proof-and-coach-confirm.md` | `submit_instapay_proof` (images, checks, outcome, bounded access, auto-confirm), `coach_confirm_payment`, fee owed at activation | 10b, 10l |
| 9 | `WO-10b3-different-amount-report-autoconfirm.md` | different amount, top-up, "a client paid me", client answer, auto-confirm toggle | 10b2 |
| 10 | `WO-10b4-refunds-disputes-staff.md` | refunds, service dispute, party image, staff queue/evidence (7 items + recommendation)/resolve | 10b3 |
| 11 | `WO-10n-coach-non-receipt-evidence.md` | coach "not received" with ticked search and statement picture, auto-reject when her statement shows the payment, add evidence | 10b4, 10l |
| 12 | `WO-10o-strikes-suspensions-flags.md` | strikes (90 days), client auto-pause, coach flag, dispute-rate flag, two-staff suspension, flags list | 10b4, 10n |
| 13 | `WO-10c-scheduled-functions-and-fees.md` | `expire_payments`, `escalate_silent_payments`, `generate_fee_statements`, fee paid/confirm/list, overdue | 10o, 10d-server |
| 14 | `WO-10p-kill-switch-and-release-gating.md` | `set_payments_enabled`, owner tool, gating tests (switch off leaves open payments resolvable) | all above |

Run each order's own test command before starting the next. Every callable name is added to `CALLABLES` in `functions/tests/test_entrypoints.py` by its order.

## Answers to the app agent's questions (INDEX-10-app.md Q1 to Q5)
- Q1 and Q2 (name clashes): the older callables `submit_payment_proof` and `record_refund` exist in `functions/main.py` (lines about 2151 and 2214). The new ones are named **`submit_instapay_proof`** and **`record_instapay_refund`**. Every other new name is free (checked with grep).
- Q3: `mark_fee_statement_paid` is `record_fee_payment`; `set_auto_confirm` is `set_auto_confirm_green`; `list_payment_disputes` is `staff_list_payment_queue`; `get_payment_evidence` is `staff_get_payment_evidence`; `list_coach_payment_flags` and `list_address_change_alerts` are both `staff_list_payment_flags` (returns `{flagged, alerts}`); `list_fee_statements` exists (finance or admin, totals only). Extra callables: `confirm_fee_payment`, `cancel_payment`, `client_respond_different_amount`, `deny_refund`, `get_payment_image`, `add_payment_evidence`, `set_coach_payment_options`, `set_payments_enabled`.
- Q4: two-staff suspension: `staff_set_coach_payment_status` answers `{status: "awaiting_second_approval"}` after the first approval, `"suspended"` after the second (different staff), `"active"` after a lift.
- Q5: `phoneReading` (an object up to about 2 KB) is accepted by `submit_instapay_proof`, stored under `payments/{id}/staff/review`, never trusted.

## The authoritative server contract (the app maps its assumptions to this; change only `instapay_callables.dart` and the models' `fromMap`)

Images do NOT go through storage. The phone sends the (already cropped and hidden) screenshots as base64 PNG or JPEG inside the callable (`images`, 1 to 3 per call, 5 per payment, 5 MB each after the server's limit). The storage rules stay closed to phones (WO-10a). The server re-encodes, strips metadata and writes `payment-proofs/{paymentId}/client-N.jpg` itself.

Documents the app reads (`payments/{id}`; money fields are piasters): `clientUid, coachUid, subId, packageId, baseAmountPiasters, amountPiasters, reference, addressSnapshot{address, accountName}, status, statusAt, createdAt, expiresAt, lateUntil, proof{txnNumber, screenshotCount, submittedAt, imageFlags[]}, outcome ("green"|"amber"|"red"|null), reasons[] (codes), access{state: "none"|"provisional"|"full", until}, amberUntil, coachDecision{confirmedAt, notReceivedAt, reasonCode, differentAmountPiasters, acceptLower, receivedPiasters, autoConfirmed}, coachReport{txnNumber, reportedAt, clientAnswer}, dispute{kind, openedBy, openedAt, staffDecision, decidedAt, refundOwedPiasters, refundDueAt, serviceFacts}, refund{requestedAt, coachDueAt, txnNumber, amountPiasters, recordedAt, partial, deniedReason, overpayment}, overpaidPiasters, feePiasters, feeBps, feeState ("owed"|"disputed"|"settled"|"waived"), topUpOf, staffVisible`. Timeline: `payments/{id}/events/{id}` = `{at, from, to, role ("client"|"coach"|"staff"|"system"), actor, code}`. The staff reason text is never in the payment or its events.
App assumption to server name: `riskOutcome` is `outcome`; `accessUntil` is `access.until`; event `by` is `role`; event `note` is `code`.
Coach block: `coachPaymentProfiles/{coachUid}` (not `coachPayoutProfiles`): `address, accountName, pending{address, accountName, requestedAt, effectiveAt}, autoConfirmGreen, allowLongFirst, cleanConfirmed, paymentsConfirmed, disputesLost, status`. Standing of any woman: `paymentStanding/{uid}`: `clientStrikes, coachStrikes, clientSuspended, coachSuspended, coachFlagged, feeOverdue, senderHandle, otherPayerCount`. Statements: `feeStatements/{coachUid}__{YYYY-MM}`: `coachUid, year, month, lines[{paymentId, reference, basePiasters, feePiasters, feeState, owedAt}], totalDuePiasters, disputedPiasters, settledPiasters, waivedPiasters, status ("open"|"paid_claimed"|"paid"), generatedAt, dueAt, payTo{address, holderName}`. Kill switch: `config/payments` = `{enabled, updatedAt, updatedBy}` (readable by any signed-in account; a missing document means OFF).
`coaches/{uid}.instapayReady` (bool) is what shows the pay button; `subscriptions/{id}` waits in `awaiting_payment` (no `payTo`, no payment code) when InstaPay is on.

Callables (request -> answer). Every refusal is a code in the HttpsError message:
- `create_payment {subId, idempotencyKey (8 to 64 of A-Za-z0-9_-), topUpOf?}` -> `{paymentId, amountPiasters, reference, address, accountName, expiresAt, status}`
- `cancel_payment {paymentId}` -> `{status}`
- `submit_instapay_proof {paymentId, idempotencyKey, amountPiasters, images[], txnNumber?, paidAtClaimed?, senderHandle?, otherPayerOk?, phoneReading?}` -> `{paymentId, status, outcome, reasons[], retry}`
- `coach_confirm_payment {paymentId, receivedPiasters?}`; `coach_mark_not_received {paymentId, reasonCode, note, searched: true, images[]}`; `coach_mark_different_amount {paymentId, receivedPiasters, acceptLower}`; `client_respond_different_amount {paymentId, decision: "agree"|"dispute"}`; `coach_report_payment {subId | reference, txnNumber}`; `client_confirm_coach_report {paymentId, answer: "yes"|"no"}`; `set_auto_confirm_green {enabled}`
- `add_payment_evidence {paymentId, images[], note?}`; `get_payment_image {paymentId, path}` -> `{imageB64}`
- `request_refund {paymentId}`; `deny_refund {paymentId, reasonCode}`; `record_instapay_refund {paymentId, txnNumber, amountPiasters, kind: "refund"|"overpayment"}`; `open_service_dispute {paymentId, note?}`
- `set_coach_instapay_address {address, accountName}` (needs a phone sign-in from the last 5 minutes: the app re-authenticates with a fresh SMS code first; there is no `step`/`otp` field) -> `{status: "active"|"pending", effectiveAt}`; `set_coach_payment_options {allowLongFirst}`
- Staff (woman reviewer, no admin): `staff_list_payment_queue {after?}`, `staff_get_payment_evidence {paymentId, withImages?}`, `staff_resolve_payment {paymentId, outcome, reason, proofFalse?, refundPiasters?}` with `outcome` in `resolved_paid, resolved_unpaid, no_refund, refund_owed, reopen`. Staff or admin: `staff_set_coach_payment_status {coachUid, action: "suspend"|"lift", reason}`, `staff_list_payment_flags {}`. Finance or admin: `confirm_fee_payment {statementId}`, `list_fee_statements {status?, after?}`. Coach: `record_fee_payment {statementId, txnNumber}`. Admin: `set_payments_enabled {enabled, reason}`.
- Scheduled: `expire_payments` (hourly), `escalate_silent_payments` (30 minutes), `generate_fee_statements` (the 1st, 06:00 Cairo), `payments_retention` (weekly).

Push kinds (generic, no amounts; payload `{kind}`), all defined in `functions/payments/notices.py`: client `instapayReminder, instapayConfirmed, instapayNotReceived, instapayDifferentAmount, instapayCoachReported, instapayReviewStarted, instapayReviewDecided, instapayRefundRecorded, instapayAddressChanged, instapayAccessEndsSoon, instapayPaused`; coach `instapayProofSent, instapayCoachReminder, instapayConfirmedByClient, instapayDisputeOpened, instapayCoachReviewDecided, instapayRefundRequested, instapayStatementReady, instapayFeeOverdue, instapaySuspended`. The app's list in INDEX-10-app is the same names plus the extra ones here; texts are server-side.

## Where each spec rule lives (so nothing is dropped)
- 1 roles, 2 record: 10a (rules), 10a2 (fields documented), 10b (create), 10b4 (staff).
- 3 states: 10a2 `TRANSITIONS` with a test for every pair; moves in 10b to 10c.
- 4.1 coach falsely says not paid: 10n (reason code, note, ticks, 48/72 hours in 10c, provisional access 10b2/10c, strike 10o).
- 4.2 fake or reused proof: 10b2 (unique txn registry, image hash and perceptual hash, window, amount), 10l/10m (checks, outcomes), strikes 10o.
- 4.3 amounts: 10b3 (partial, lower accepted in writing, top-up, overpayment refund 10b4). 4.4 address: 10d-server, 10b (snapshot). 4.5 paid without proof: 10b3 and 72 hours in 10c. 4.6 idempotency: 10a2 and every callable. 4.7 expiry and late proof: 10c and 10b2.
- 4.8 refunds: 10b4 (14 days, once, 3 days to answer, partial, ends the package; staff "refund owed"). 4.9 service problem: 10b4. 4.10 wrong person: no server action by design (app text).
- 4.11 coach not ready: 10b, 10d. 4.12 limits: 10b (3 a day, max amount), 10b4 (3 disputes a month), 10b2 (5 screenshots, 5 MB), amount limits UNVERIFIED (see below).
- 4.13 fee and statement: 10b2 (owed at activation), 10c (statements, paid, overdue). 4.14 leaving: record and reference only (no code). 4.15 privacy: 10a (rules), 10a3 (deletion, export, retention), no analytics events carry payment data (none are written by this server). 4.16 receipts: app (PAY10). 4.17 time: UTC stored, Cairo for months (10c). 4.18 offline: idempotent submit (10b2).
- 7 tests: every order has its tests; the end-to-end emulator run and the manual transfer are in the app agent's 10k orders.
- 8 notifications: 10a2 (texts), sent by 10b to 10c.
- 10 gating: 10p. 12 owner and counsel steps: below.
- 13.1 reasons to lie removed: fee at activation (10b2), bounded provisional access (10b2, 10c), claim never ends access (10n), first payment shortest package and first 3 payments staff visible (10b). 13.2 unique amount: 10m. 13.3: image gate and invariants 10l, uniqueness 10b2, tamper score 10m (double compression UNVERIFIED: no library), outcome 10m. 13.4: 10b2, auto-confirm 10b2/10b3, amber 24 hours 10c. 13.5: 10n, strikes 10o, dispute rate 10o. 13.6: 10b4. 13.7: strikes keyed to the woman (10o). 13.9: each case has a named test (screen of a failed transfer, cropped, unreadable language, long names, collisions, address changed after proof, suspension in between, late payment, confirmation final unless reopened, service dispute after green, second reviewer, kill switch mid-dispute, offline/double tap, clock skew, reused number by another client, oversized uploads). 13.12 and 13.13: 10l.

## Deployment order (spec 12 and the project's notes)
1. `functions` (all new callables and schedulers), 2. `firebase/storage.rules` (comment only), `firebase/firestore.rules` and `firebase/firestore.indexes.json` (wait for the 6 indexes to build), 3. staff dashboard, 4. the owner creates the switch once: `GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.set_payments_switch on` only AFTER the two-phone transfer test; until then a missing document means OFF and the app shows "Free for now", 5. the app last. Add TTL on `paymentIdempotency.expireAt` (UNVERIFIED: add it to `firebase/firestore.indexes.json` `fieldOverrides` with `"ttl": true` and run `bash firebase/ops/ttl-policies.sh`).

## Owner and counsel items that these orders cannot settle (the flag stays off until done)
Fee percentages (defaults 15 and 8 from D63 in `coachingConfig/instapay`), the maximum package price against the Central Bank InstaPay limits (placeholder 20000 EGP, UNVERIFIED), bank address suffixes beyond `@instapay` (UNVERIFIED), when a fee counts as 30 days late (30 days after the statement), retention of screenshots (90 days) and records (5 years), both placeholders pending counsel, who the woman reviewers are, the real two-phone transfer, the live Vision accuracy on real receipts (the live test is skipped until the owner supplies receipts), and the Apple/Google reading in WO-10q.

## Not built here (named so nobody assumes it)
The staff dashboard screens (app agent 10i), every phone screen and the phone-side OCR (app agent 10e), JPEG double-compression detection (no library installed), automatic card-digit redaction on the server (the phone hides lines before sending; the server stores only the re-encoded picture it was given), automatic reconciliation with any bank, automatic fee debit, and the refresh of open fee statements after a disputed line is settled (the line state changes; the statement totals refresh when the owner confirms it or on the next month's run).

## UNVERIFIED tally (this agent's orders)
24 occurrences: 10a 2, 10a2 1, 10a3 6, 10m 2, 10l 4 (Vision enabled for `own-hub`, Vision accuracy, latency, real receipts), 10b 1, 10b2 1, 10b4 1, 10d-server 3 (bank suffixes, reauth `auth_time`, test helper signature), 10c 1, 10p 1. Each is next to the command that verifies it.
