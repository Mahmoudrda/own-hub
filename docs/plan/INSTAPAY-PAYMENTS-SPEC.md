# InstaPay payments inside Own Hub: governed peer-to-peer spec

Written 26 Oct 2026. Owner decision: this release ships InstaPay payments. The client pays the coach's own InstaPay address directly. Own Hub never holds, receives or moves the money. The app governs the process: it shows who to pay and how much, records the payment, makes the coach confirm receipt, runs disputes through staff, and keeps a trail. This changes the earlier plan (payments after counsel and a licensed provider, D63 and D64 in `DECISIONS.md`). UPDATE 27 Oct (owner): this ships LIVE in the next release. The flag `Feature.instapayPayments` is ON in the release build, with a server-side kill switch (`config/payments.enabled`) the owner can turn off instantly. The owner and counsel steps in section 12 must be finished before the app is submitted, because the feature is live. Section 13 (anti-fraud and screenshot verification) overrides sections 4.1, 4.2 and 10 wherever they differ. This is not legal advice; counsel confirms the legal points listed in section 12 before the flag is on.

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
`Feature.instapayPayments` is on in the release; the server kill switch `config/payments.enabled` is the off button. If the switch is off, the app shows "Free for now" exactly as today. Add a test that the switch off leaves every existing screen unchanged, and a test that turning it off mid-payment leaves open payments readable and resolvable.

## 11. Work orders to write (WO-10a to 10k, same template as `handover/00-WORK-ORDER-TEMPLATE.md`)
10a data model, rules and storage rules with tests; 10b state machine functions; 10c scheduled functions and fee statements; 10d coach address setup and OTP delay; 10e client payment screens PAY1 to PAY3, PAY6; 10f coach inbox and decisions PAY4, PAY5; 10g refunds and service disputes PAY8; 10h receipts and statement PAY9, PAY10; 10i staff dashboard dispute queue; 10j notifications, strings, privacy text and store answers; 10k test program and manual script. Order: 10a, 10b, 10m, 10l, 10d, 10e, 10f, 10n, 10c, 10g, 10h, 10o, 10i, 10j, 10p, 10k.

## 12. Owner and counsel steps (the flag stays off until these are done)
1. Tax: Rahma and any coach receiving payments needs her own tax status; Own Hub needs a way to receive its fee income lawfully (commercial registration and tax card, or the company).
2. Counsel confirms: that governing but not touching peer-to-peer payments is not a regulated payment service in Egypt; the coach terms including the 12-month rule (D64) and the strike and suspension rules; the dispute process wording; the refund and withdrawal rules; retention periods for payment records and screenshots; the privacy policy changes.
3. Confirm Apple and Google rules for this payment flow in the app (coaching delivered as a service) and add notes to the review text.
4. Decide retention (12.4), the fee percentage (12.5), provisional access after 48 hours of coach silence (12.6, default yes), staff dispute target (default two working days), who the dispute reviewers are (a woman reviewer for any dispute with a woman's private data).
5. Look up the current InstaPay transaction and daily limits and set the maximum package price below them.
6. Do a real transfer test with two phones before turning the flag on.

## 13. Anti-fraud and screenshot verification (live release; overrides 4.1, 4.2, 10)

Principle: make honest use take almost no effort, make cheating pointless or detectable, and keep the damage of any one successful cheat small. No check can prove a payment, because only the coach's bank knows the truth; so the design removes the reasons to lie and ties every account to a verified identity.

### 13.1 Remove the reasons to lie (the strongest control)
- **A coach lies about non-receipt only to dodge the Own Hub fee or to refuse service.** Fix both: the fee (D63) is owed when the client's package becomes active, not when the coach taps confirm; and a package that was activated by a green proof (13.4) cannot be deactivated by the coach's claim alone, only by a staff decision. So denying receipt gains her nothing.
- **A client fakes proof only to get service without paying.** Fix: green proof gives short, bounded access (at most 7 days or the first package week, whichever is shorter) until the coach confirms or the 72 hour escalation completes; after the coach confirms, access continues. A forged proof therefore buys at most a week, and the account is tied to a verified identity (13.7).
- **Cap the exposure:** a new client's first payment can only be for the shortest package (the coach can allow longer); a coach's first 3 payments are always staff-visible.

### 13.2 A unique amount and a reference on every payment (no hassle for honest users)
- Every payment request has a unique amount in piasters, for example 500.37 instead of 500.00 (the extra piasters, 0.01 to 0.99, go to the coach and are shown clearly: "pay exactly 500.37"). Both the coach's bank SMS and the client's receipt then show an amount that matches only this payment. The app copies the exact amount to the clipboard.
- The reference code goes in the transfer note when the bank allows a note (UNVERIFIED: the agent checks which banks' InstaPay screens have a note field and writes the exact steps for each; if not supported the unique amount carries the weight).
- Result: a coach cannot say "I do not know which payment this is"; a client cannot reuse one transfer for two packages; staff decide by one searchable number.

### 13.3 Screenshot processing pipeline (client side, automatic, one tap for her)
Flow for her: she taps "I have paid", picks her bank screenshot (one tap, photo picker). The app reads it on the phone (OCR) and fills the transaction number, amount, time and beneficiary for her to confirm; she taps "Send". No typing in the normal case.
Checks, in this order, run on the phone first (instant feedback) and again on the server (the authority):
1. **Image sanity:** screenshot-like dimensions for a phone display, no camera EXIF, no editing-software tags, creation time not before the request and not in the future; size and type limits; metadata stripped before storing.
2. **OCR extraction:** on-device text recognition (ML Kit text recognition or the platform's own; the agent checks which is already in `pubspec.yaml` and licensing, UNVERIFIED), Arabic and English, Arabic-Indic and Western digits normalised; the server re-runs OCR with its own engine (the agent verifies availability of a server OCR in `functions/`, for example Cloud Vision or Tesseract with `ara+eng`; Google Vertex is currently blocked for this project, so confirm Cloud Vision is not also blocked, UNVERIFIED).
3. **Field match (deterministic):** amount equals the unique amount to the piaster; beneficiary account name or InstaPay address fuzzy-matches the coach's `addressSnapshot`; a success status phrase appears (for example "تمت بنجاح" or "Successful", per bank templates); date and time fall between the request creation and now; the transaction number matches the format for that bank.
4. **Template match:** each bank app draws its receipt the same way. The owner supplies 3 real receipts from each major bank (at least CIB, NBE, Banque Misr, QNB, Banque du Caire, plus the InstaPay app itself); the agent stores their layout fingerprints (relative positions of the labelled fields, colours of the success banner, fonts) as test fixtures and a template table. A screenshot whose layout matches no known template is "unknown bank" and goes to amber, not red.
5. **Uniqueness:** the transaction number must be new across all payments; the re-encoded image hash and a perceptual hash (reuse `functions/coaching/` `dhash`) must not match any earlier payment's image; a near match is red.
6. **Tamper heuristics (a score only, never a rejection):** JPEG double compression, error-level differences around the amount and number fields, font or digit-shape inconsistencies in those fields, copy-paste seams, mismatched status bar clock versus the claimed time. These add to the risk score and prioritise staff review; they never block an honest client by themselves because they give false alarms.
7. **Outcome:** GREEN (all deterministic checks pass, no flags), AMBER (one deterministic field unreadable or unknown template: she gets one friendly retry, "we could not read the amount, please pick a clearer screenshot or type the transaction number"), RED (a deterministic mismatch such as a wrong amount, a reused transaction number or image, or a name that does not match: no access; she is told what did not match and can add her bank's transaction history instead; goes to staff).
Be honest in the terms and the code comments: a skilled forger can still make an image that passes pixels. That is why 13.1, 13.2, 13.5 and 13.7 exist.

### 13.4 What each outcome does for the user (no hassle)
- **GREEN:** the coach sees "Paid, matches your records" with the unique amount and transaction number; the package is active for the bounded period; she confirms with one tap (or the coach may turn on "auto-confirm green payments", which confirms them at once and still lets her flag within 48 hours; default off for a new coach, offered after 3 clean payments).
- **AMBER:** the coach sees a yellow "please check your bank" card with the exact amount; no access until she confirms or 24 hours pass with no objection.
- **RED:** no access; staff queue; the client is told calmly and can add evidence.

### 13.5 Make a false "not received" costly and detectable
- To mark "not received" the coach must: tick "I searched my bank for amount 500.37 and transaction number X"; attach a screenshot of her own bank's transaction list for that day (OCR'd). If the OCR of her screenshot contains the expected amount or transaction number, the system rejects her claim automatically and shows "This payment appears in your statement". If her list cannot be read, it goes to staff with both images.
- A lost dispute is an automatic strike; two strikes in 90 days suspend her ability to take payments; a suspension is a staff decision recorded with a reason. Dispute rate (lost disputes over payments) is tracked per coach and shown to staff; a rate over a threshold (for example 10 percent over 10 or more payments, owner-tunable) flags her account.
- Because the fee is owed from activation (13.1), a false claim also does not save her the fee; the fee statement lists it as "disputed, pending" and is settled on the decision.
- Client strikes work the same: a proven false proof is a strike; two strikes remove InstaPay payments for that client and are reported in the terms as a breach.

### 13.6 Evidence staff use, in this order
1. unique amount and reference; 2. transaction number and its format for the bank; 3. OCR fields of both sides' screenshots and their match score; 4. template and uniqueness flags; 5. timeline of events and notifications; 6. the coach's and the client's dispute history; 7. a request for a bank statement line (other lines blacked out) from both parties. The dashboard shows a one-screen evidence summary with these seven items, a recommended decision from a simple rule set, and requires a typed reason. Two staff approve any decision that suspends a coach.

### 13.7 Identity makes strikes real
Every client and coach is a phone-verified, ID and selfie checked woman (women-only verification). Strikes and suspensions attach to that identity, so a new account does not wipe a record. The terms say fraud may be reported to the authorities and that evidence is kept for that purpose (counsel confirms wording; retention per 4.15). Do not weaken the verification.

### 13.8 Keeping it light for honest users
- Client: pay in her bank app, return, pick the screenshot, confirm the filled fields, send. Typing is only the fallback.
- Coach: one notification, one tap. Auto-confirm for trusted clients and green proofs.
- No extra screens for green payments beyond PAY1 to PAY3 and PAY4.
- No waiting for staff in the normal case.

### 13.9 Additional cases to cover (each needs a test)
Screenshot of a failed or pending transfer (status text not success: RED with a clear message); transfer made to a different account that happens to show the coach's name; the same screenshot sent for two coaches; a cropped screenshot hiding the amount; a screenshot in a language the OCR does not read; a dark mode or high contrast screenshot; very long names; two payments with the same amount at the same time (the unique piasters prevent clashes: reject collisions at creation); coach changes the address after a client's proof was OCR-matched to the old snapshot (the snapshot wins); the coach is suspended between payment and confirmation (the client is still protected); the client pays after the request expired (accepted within 7 days if every check passes); a coach confirms and later disputes (confirmation is final unless staff reopen); a client claims the coach never delivered after a green payment (service dispute 4.9); staff decision disagreement (second reviewer); a kill switch turned off mid-dispute (disputes continue to be resolvable); offline submission; clock skew on the phone (the server clock is the authority; the phone time is only a claim); daylight saving (Egypt changes; store UTC); a proof submitted twice by double tap (idempotency); reused transaction number by a different client (RED and both reported to staff); and image bombs and oversized uploads (rejected before OCR).

### 13.10 Tests specific to this section
Unit tests for each deterministic check with fixtures; a fixture folder of receipts per bank (real, owner supplied, with account details blacked out) plus synthetic bad ones (edited amount, edited name, reused image, cropped, wrong status); OCR accuracy test: at least 95 percent of the real fixtures reach GREEN; false-positive test: no real fixture is RED; tamper heuristics tests assert they only change the score; a state machine test for the coach's statement auto-reject; a load test of the OCR function for latency under 10 seconds on a mid-range phone and on the server; privacy tests that screenshots are stored privately, hashed, metadata stripped, and removed on the schedule in 4.15.

### 13.11 Work orders added
WO-10l receipt OCR and screenshot checks (on phone and server); WO-10m risk score, outcomes and unique amount allocation; WO-10n coach non-receipt evidence flow and auto-reject; WO-10o strikes, suspensions and dispute-rate flags; WO-10p kill switch and release gating. Order after 10b: 10m, 10l, 10n, 10o, then 10p last.

### 13.12 What a real receipt shows (analysed from the owner's HSBC via InstaPay sample, 27 Oct) and what changes
The sample's first screen shows: the title "Approved Transaction", "Your transaction was successful", the amount (100 EGP), "From" the sender's InstaPay handle with the bank logo and the last 4 digits of her account, "To Instapay" with the recipient's name partly masked with stars and her InstaPay address (here a mobile number), and a collapsed "More Details" section. It does NOT show the transaction number or the date and time. The recipient's name is masked, so a full-name comparison is impossible. Therefore:
1. **Two screenshots are required for GREEN:** (a) the receipt screen, and (b) the same receipt with "More Details" expanded (transaction number, date and time), or the bank's SMS or app notification that carries the transaction number and time. The picker accepts several images at once, so it is still one selection step. If only (a) is sent the result is AMBER and the app says, in plain words, "Please also add the screenshot with More Details open" with a small drawn example.
2. **Recipient match uses what is visible:** the recipient's InstaPay address or phone on the receipt must equal the coach's `addressSnapshot`; the visible part of the masked name (for example the first name) must match the start of her saved account name, and the number of masked segments should match; if the receipt shows the full name it must match fully.
3. **Sender match:** at her first payment the client saves her own InstaPay handle (one field, shown once). The "From" handle on every later receipt must equal it. A different sender is AMBER ("someone else paid"), allowed once with her confirmation, since a family member may pay.
4. **Status match:** accept the bank's success phrases per template: "Your transaction was successful", "Approved Transaction", "تمت العملية بنجاح" and equivalents; a pending, failed or declined phrase is RED. The agent builds the phrase list from the real fixtures.
5. **Time match:** the time in More Details (or SMS) must be between the request creation and now; the phone's status bar clock in the screenshot (2:32 in the sample) is read as an extra check against the claimed time, never alone.
6. **Template:** the InstaPay result screen (white background, green check illustration, purple Home button, "POWERED BY" footer) is a known template; each bank's own app has its own. The agent adds the owner's receipts as fixtures with names, phone numbers and account digits blacked out before anything is committed. The original image the owner sent is not stored in the repo.
7. **Privacy catch for the product:** an InstaPay address that is a mobile number reveals that phone number to the other side on the receipt. The coach setup (PAY7) must require an @instapay handle, not a phone number, and tell her why; the client setup suggests the same for her own address. The spec's rule "a coach never sees a client's phone number" holds only if clients use handles; if she pays from a phone-number address, warn her once before her first payment.
8. **Coach side:** her notification shows the exact unique amount and the transaction number read from the client's screenshot, so she can search her bank or SMS for that number. The coach may also add her own bank SMS screenshot when confirming (optional) to strengthen the record.
Everything else in section 13 stays.

### 13.13 Bank formats differ: do not depend on per-bank templates (owner, 27 Oct)
The owner cannot supply every bank's receipts or SMS, and the SMS sample shows why: it is a card-purchase alert ("credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre") with no transaction number, no recipient and no time, and it is not an InstaPay transfer at all. So the checks must work without knowing each bank. This overrides the template parts of 13.3 step 4 and 13.12 item 6.
1. **The core invariants carry the decision, not the layout.** GREEN needs, found anywhere on the image by generic search: a success phrase (a list of English and Arabic phrases, matched loosely); the exact unique amount (any of "570.37", "570,37", "٥٧٠٫٣٧" normalised); the coach's address or phone or the visible start of her name; and a transaction number or a time in the window. Labels are found by synonym lists ("Transaction ID", "Transaction number", "Reference", "RRN", "رقم العملية", "رقم المرجع", "الرقم المرجعي") and by shape (a 10 to 20 digit number near such a label). No bank logo or colour is needed.
2. **Unknown layout is AMBER, never RED.** If the invariants cannot all be found, she gets one friendly retry and the option "add the screenshot with details open" or typing the transaction number; the coach then confirms from her own bank. Only a deterministic contradiction is RED (a different amount, a failed or pending status, a reused number or image).
3. **Wrong kind of message is recognised.** Card-purchase alerts, balance messages and login notifications ("has been used for", "available limit", "OTP") are not transfer proofs: the app says "This looks like a card message, not an InstaPay transfer receipt. Please send the transfer receipt." (EN and Egyptian Arabic). A bank SMS is only a supporting item: it can confirm amount and date but cannot make a payment GREEN on its own.
4. **The coach's own bank is the real check.** The unique amount and the transaction number are exactly what she searches for in her bank or SMS. That does not depend on any template, so it is the main safety net, and the pipeline above only decides how much to ask of her.
5. **Learn from use, with consent.** When staff resolve a payment, they label the outcome. With the client's consent (a clear, optional line at first payment, off by default if counsel advises) the extracted fields, not the image, are kept to improve the phrase and label lists. The owner does not need to collect receipts up front: launch with the generic rules and the InstaPay app's own result screen and HSBC sample as fixtures, then add fixtures as real payments arrive. Remove "3 receipts per bank" from the launch requirements; keep it as a nice-to-have.
6. **Privacy of what clients upload.** A bank SMS can show card digits, balances and limits. Before upload the app offers a crop and a black-out brush with the sensitive lines pre-highlighted when it can find them, and after OCR the server keeps only the extracted fields and a redacted copy, never the original, unless a dispute needs it (then it is kept in the private path under 4.15). Say this in one line on the proof screen.
7. **Tests:** synthetic fixtures for each invariant being missing one at a time (must be AMBER), contradictory (must be RED), a card-purchase alert (must say it is the wrong message), an Arabic receipt, a dark-mode receipt, an SMS only (never GREEN), and the two real samples. Parser must never throw on garbage input.
