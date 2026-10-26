# InstaPay payments inside Own Hub: governed peer-to-peer spec

Written 26 Oct 2026. Owner decision: this release ships InstaPay payments. The client pays the coach's own InstaPay address directly. Own Hub never holds, receives or moves the money. The app governs the process: it shows who to pay and how much, records the payment, makes the coach confirm receipt, runs disputes through staff, and keeps a trail. This changes the earlier plan (payments after counsel and a licensed provider, D63 and D64 in `DECISIONS.md`). The build ships behind a feature flag `Feature.instapayPayments`, default off, which the owner turns on only after the owner steps in section 12 are done. This is not legal advice; counsel confirms the legal points listed in section 12 before the flag is on.

Fixed facts: InstaPay has no connection I know of that lets an app see that a payment arrived in a person's account. So the app can never prove a payment by itself. Everything below limits fraud and makes disputes decidable; it cannot make fraud impossible. Say this plainly in the coach and client terms.

## 1. Roles and what each can do
| Role | Can | Cannot |
|---|---|---|
| Client | start a payment, copy the address and amount, submit proof (transaction number, optional screenshot), see status, raise "coach did not deliver", ask a refund within the withdrawal window, download a payment record | confirm her own payment, edit amount or address, see the coach's phone number |
| Coach | save her InstaPay address and account name, confirm "I received it", mark "not received" with a reason, mark "received a different amount", record a refund, see her payments and the monthly fee statement | activate a package without a payment record, change an address without the delay in 4.4, see a client's phone number |
| Staff (reviewer) | open the dispute queue, see all evidence, decide, record the decision with a reason, suspend a coach's payments | move money, edit amounts, delete a record (records are append-only) |
| Own Hub servers | run every state change in callable functions, enforce rules, send notifications, keep the audit log | accept any client write that changes status |

## 2. The payment record (server, Firestore `payments/{paymentId}`)
Fields: `clientUid`, `coachUid`, `packageId`, `amountEgp` (integer piasters or whole pounds, one rule everywhere), `reference` (code like OH-4821, unique, 6 characters from a set without look-alikes), `addressSnapshot` (the coach's InstaPay address and account name at the moment of payment), `status`, `createdAt`, `expiresAt`, `proof` (`txnNumber`, `screenshotPath`, `screenshotHash`, `submittedAt`, `paidAtClaimed`), `coachDecision` (`confirmedAt`, or `notReceivedAt` plus `reasonCode`, or `differentAmountEgp`), `dispute` (`openedBy`, `openedAt`, `evidence` lists, `staffDecision`, `decidedBy`, `decidedAt`, `reason`), `refund` (`requestedAt`, `txnNumber`, `recordedAt`), `idempotencyKey`, `feeEgp` (what Own Hub is owed for this payment, set at confirmation), and an append-only `events` subcollection (one document per state change: who, when, from, to, note). Direct client or coach writes to `payments` are denied by `firestore.rules`; only callable functions write. Add rules tests.

## 3. States and transitions (all by callable functions)
`awaiting_payment` -> `proof_submitted` -> `confirmed` (package active). Side paths: `awaiting_payment` -> `expired`; `awaiting_payment` -> `cancelled` (client); `proof_submitted` -> `coach_not_received` -> `in_review` -> `resolved_paid` (package active) or `resolved_unpaid` (package not active); `proof_submitted` -> `different_amount` -> (`confirmed` at the coach's stated amount if the client agrees, else `in_review`); `confirmed` -> `refund_requested` -> `refunded` or `refund_denied` (-> `in_review`); `confirmed` -> `service_dispute` -> `in_review`. Every transition writes an event and sends the notifications in section 9. A package is active only in `confirmed` or `resolved_paid`.

## 4. Cases and the exact rule for each
### 4.1 The coach falsely says she was never paid
- She must pick a reason code (not seen in my account, wrong amount, wrong name, paid by someone else, other) and add a note. Silence is not allowed to block: if she does not answer within 48 hours of the proof, she gets a reminder, and at 72 hours the payment goes to `in_review` automatically.
- The client then sees "Your coach says it has not arrived" and a button "Add proof". She can add her bank's transaction screenshot and the time. Staff review within two working days (owner sets the target).
- Staff decide using: matching transaction number format and date, the reference code in the transfer note, the amount, the account name shown on the client's receipt compared with the coach's saved name, and, if still unclear, ask both parties for a bank statement line (they can black out other lines). Outcome is recorded with a reason. `resolved_paid` activates the package and records a strike against the coach if the claim was false; two strikes suspend her ability to take payments.
- Provisional access (owner decision 12.6; default yes): if the coach is silent for 48 hours, the client gets access from then until the review ends. If staff then find no payment, access ends and the client is told kindly.

### 4.2 The client sends a fake or reused proof
- The transaction number is required. The screenshot is optional evidence, never proof. Nothing activates a package without the coach's confirmation or a staff decision.
- Transaction numbers are unique across all payments; a reused number is rejected with "This transaction number was already used". A screenshot hash (of the re-encoded image) that matches any earlier payment raises a flag for staff and is shown to the coach.
- The date and time claimed must fall inside the payment window. The amount typed must equal the package amount.
- The coach is the check: she sees her own bank. If the proof is fake she taps "not received" and 4.1 applies in her favour. A client who submits proof that staff find false gets a strike; two strikes remove her ability to pay by this method.

### 4.3 Wrong amount, partial payment, overpayment
The coach can mark "received a different amount" and enter it. The client sees the difference and can pay the rest (new reference) or cancel. Overpayment is the coach's to refund (recorded under 4.8). The package never starts on a partial payment unless the coach explicitly accepts the lower amount in writing in the app.

### 4.4 Wrong or changed address, and account takeover
- The coach enters her InstaPay address and the account holder name exactly as her bank shows it. The client sees "You will pay Rahma M. (name as shown by your bank)" and is told to check that the name appears on the bank's confirmation screen before sending. InstaPay transfers cannot be reversed by the app.
- The address is validated by format (letters, digits, @ and the bank suffix pattern; the agent verifies the exact format rules before coding).
- Changing the address needs re-sign-in, a one-time code to her phone, and takes effect after 24 hours. Pending payments keep their `addressSnapshot`. All clients with a pending payment get a notice, and staff see an alert on every change.

### 4.5 The client paid but never submitted proof
The coach can start from her side: "A client paid me" with the reference code or the client's name from her list and the transaction number. The client gets a notice to confirm "yes I paid". Once both match, it becomes `confirmed`. If the client does not answer in 72 hours it goes to staff.

### 4.6 Duplicate and repeated actions
Every create and submit call carries an idempotency key; a double tap or an offline retry never makes two payments. One open payment per client and package at a time. Two proofs with the same transaction number are rejected.

### 4.7 Expiry and late payment
A payment request lasts 24 hours and shows a countdown. After that it is `expired`, but a proof submitted within 7 days of the request is still accepted (the client paid late). The price shown is the one at creation. If the coach changed the package price meanwhile, the old price holds for open payments.

### 4.8 Refunds and the withdrawal window
The coach refunds by sending money back by InstaPay and records it (transaction number, amount, time). Rules: within the 14 day window in `docs/plan/RELEASE-2-PLAN.md` section 3.10 the client can ask for a refund once; the coach has 3 days; no answer goes to staff; staff may decide a refund is owed. Partial refunds are allowed after sessions were delivered (the coach enters the amount, staff check on dispute). A package ends when a refund is recorded. Own Hub does not move refund money. A coach who ignores a staff refund decision loses payment privileges.

### 4.9 The coach takes the money and does not deliver
Client can open "Service problem" from the package. Evidence the app already holds helps staff: sessions delivered, messages, check-ins answered. Staff decide a full or partial refund and strike the coach. Verified reviews appear only after a confirmed payment.

### 4.10 A claim that the transfer went to the wrong person
Own Hub cannot recover money sent to a wrong account. The app only reduces the risk: copy buttons, the name check in 4.4, a clear warning. The client is told to contact her bank immediately. Staff do not adjudicate third-party transfers.

### 4.11 Coach not set up, suspended or unapproved
A package can be bought only if the coach is approved, has a confirmed address and is not suspended from payments. Otherwise the package shows "Message the coach" instead of a pay button. Existing clients are not cut off when a coach is suspended; staff decide per client.

### 4.12 Limits and abuse
Per-transaction and per-day amount limits of InstaPay: the agent must look up the current Central Bank limits and set the maximum package price below them (UNVERIFIED). Rate limits: at most 3 payment requests per client per day, 3 disputes per client per month, 5 screenshot uploads per payment. Screenshots: image only, at most 5 MB, re-encoded, metadata stripped.

### 4.13 Own Hub's fee (D63) and the fee statement
When a payment is `confirmed` or `resolved_paid`, the server computes the fee owed (percentage set by the owner, stored in config, not in the app) and adds it to the coach's monthly statement. The statement shows each payment, the fee and the total, and is generated on the first of the month. The coach pays Own Hub's fee by InstaPay to the Own Hub address and records it; the owner confirms in the dashboard. A coach more than 30 days late cannot take new clients (existing clients are never cut off). The owner must be able to receive this income legally (section 12). Do not build automatic debiting.

### 4.14 Leaving the platform (D64)
Off-platform payments cannot be detected. The reference code, the record and the coach terms are the controls. The app never shows a client's contact details to a coach. The terms (counsel-approved) carry the 12-month rule.

### 4.15 Privacy and data
Transaction numbers and screenshots are financial data about a woman. Store them in a private path (`payment-proofs/{paymentId}/`), readable only by the two parties and staff during a dispute, with storage rules and tests. Never log them to analytics. Retention period decided with counsel; on account deletion keep the record pseudonymised for the period the law requires, delete screenshots earlier (decision 12.4). Update the privacy policy (EN and Egyptian Arabic), App Store privacy answers and Play data safety. Payment records are never shared with other coaches.

### 4.16 Receipts
The client can download a payment record (PDF or image) showing amount, date, coach name, reference and status. It says it is not a tax invoice. The coach issues her own invoice if she needs one.

### 4.17 Time, language, accessibility
All times shown in Cairo time; storage in UTC. Amounts in Western digits with "EGP"/"جنيه". Every screen in English and Egyptian Arabic (feminine address, no em dashes, no guilt wording). Dispute messages are calm and factual. Every control labelled for screen readers; text scaling to 200%.

### 4.18 Offline and failures
A proof submitted offline queues and sends later with the same idempotency key. A server error never loses what she typed. The status screen refreshes on open and on push.

## 5. Screens (each within the control budgets: one filled primary, at most 5 other controls above the fold)
| Id | Screen | Primary action |
|---|---|---|
| PAY1 | Package payment: amount, coach name as shown by her bank, address with copy button, reference code with copy button, three numbered steps, countdown | "I have paid" |
| PAY2 | Submit proof: transaction number field, optional screenshot, time paid | "Send to coach" |
| PAY3 | Status: a timeline of the events with plain words; what happens next; the one action that fits the state | varies |
| PAY4 | Coach payment inbox (in the coach space): waiting payments first, each with "I received it" and "Not received" in the detail | "I received it" |
| PAY5 | Coach decision sheet: not received reasons, different amount | "Send" |
| PAY6 | Client "Add proof" after a dispute | "Send" |
| PAY7 | Coach InstaPay setup: address, account name, the 24 hour delay explained | "Save" |
| PAY8 | Refund request (client) and refund record (coach) | "Send" / "Record refund" |
| PAY9 | Coach monthly statement | "Mark fee as paid" |
| PAY10 | Payment record download | "Save" |
Staff dashboard (admin-web): dispute queue with evidence side by side, the timers (48 h, 72 h, two working days), decision buttons with required reason, strikes list, address change alerts, fee statements overview, audit log. Nothing here edits an amount.

## 6. Server (functions/payments/)
Callables: `create_payment`, `submit_payment_proof`, `coach_confirm_payment`, `coach_mark_not_received`, `coach_mark_different_amount`, `coach_report_payment`, `client_confirm_coach_report`, `set_coach_instapay_address` (with the OTP and 24 hour delay), `request_refund`, `record_refund`, `open_service_dispute`, `staff_resolve_payment`, `staff_set_coach_payment_status`, `generate_fee_statements` (scheduled), `expire_payments` (scheduled), `escalate_silent_payments` (scheduled, the 48 and 72 hour rules). Every callable checks identity, role, current status, App Check, and writes an event. Rules and storage rules deny direct writes. Python tests for every transition, including each illegal one.

## 7. Tests that must exist before the flag is turned on
1. State machine: every legal transition, every illegal one rejected, idempotency, expiry, late proof within 7 days, the 48 and 72 hour escalations with a fake clock.
2. Fraud: reused transaction number, reused screenshot hash, wrong amount, partial and over payment, address change delay and notices, coach strikes and suspension, client strikes, rate limits.
3. Roles: a client cannot confirm, a coach cannot activate without a record, a reviewer cannot edit amounts, no cross-coach reading, no phone number leak.
4. Privacy: storage rules for proofs, no analytics events carry payment data, deletion keeps the pseudonymised record, export includes the client's own payments.
5. App: widget tests for every screen state in English and Arabic at 390x844 and 375x667 and 200% text, budget tests, tap counts (pay: at most 4 taps from package to "I have paid"; coach confirm: 2 taps from the notification).
6. End to end on the emulator suite: pay, proof, confirm, active; pay, not received, review, resolved either way; refund; fee statement totals.
7. Manual: a real small InstaPay transfer between two team phones, with the reference code in the note, through every screen on iPhone and Android.

## 8. Notifications (exact text goes in the work order, EN and Egyptian Arabic)
Client: payment created reminder (once, at 12 hours), coach confirmed, coach says not received, review started, review decided, refund recorded. Coach: client sent proof, 48 hour reminder, dispute opened, review decided, fee statement ready. Calm lines only; no loss or guilt words; no amounts in the lock-screen text if the owner decides (default: no amounts).

## 9. Not in this release
Card payments, Fawry, installments, automatic fee debit, holding funds, automatic reconciliation with any bank, partial instalment plans, group payments.

## 10. Release gating
`Feature.instapayPayments` and a server config switch must both be on. While off the app shows "Free for now" exactly as today, so the 1.1.0 build is safe if the legal steps are not finished. Add a test that the flag off leaves every existing screen unchanged.

## 11. Work orders to write (WO-10a to 10k, same template as `handover/00-WORK-ORDER-TEMPLATE.md`)
10a data model, rules and storage rules with tests; 10b state machine functions; 10c scheduled functions and fee statements; 10d coach address setup and OTP delay; 10e client payment screens PAY1 to PAY3, PAY6; 10f coach inbox and decisions PAY4, PAY5; 10g refunds and service disputes PAY8; 10h receipts and statement PAY9, PAY10; 10i staff dashboard dispute queue; 10j notifications, strings, privacy text and store answers; 10k test program and manual script. Order: 10a, 10b, 10d, 10e, 10f, 10c, 10g, 10h, 10i, 10j, 10k.

## 12. Owner and counsel steps (the flag stays off until these are done)
1. Tax: Rahma and any coach receiving payments needs her own tax status; Own Hub needs a way to receive its fee income lawfully (commercial registration and tax card, or the company).
2. Counsel confirms: that governing but not touching peer-to-peer payments is not a regulated payment service in Egypt; the coach terms including the 12-month rule (D64) and the strike and suspension rules; the dispute process wording; the refund and withdrawal rules; retention periods for payment records and screenshots; the privacy policy changes.
3. Confirm Apple and Google rules for this payment flow in the app (coaching delivered as a service) and add notes to the review text.
4. Decide retention (12.4), the fee percentage (12.5), provisional access after 48 hours of coach silence (12.6, default yes), staff dispute target (default two working days), who the dispute reviewers are (a woman reviewer for any dispute with a woman's private data).
5. Look up the current InstaPay transaction and daily limits and set the maximum package price below them.
6. Do a real transfer test with two phones before turning the flag on.
