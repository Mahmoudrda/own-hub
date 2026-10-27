# DRAFT FOR COUNSEL: InstaPay payments, client and coach terms

Written 27 October 2026. Not legal advice. This file is for counsel and for the owner. Do not publish it.

## Status

- This is the legal wording behind the InstaPay payment feature, collected in one place so counsel can read it as one document. The same clauses, in English and Egyptian Arabic, are already in the website sources (`site/_build/pages_en.py` and `pages_ar.py`) and in the generated pages `site/privacy.html`, `terms.html`, `coach-terms.html`, `support.html`, `delete-account.html` and their `ar/` twins. **They are built but not deployed.** The owner runs `site/_build/deploy.sh` only after counsel has read them and the points in section H are decided.
- The feature is live in the next release, with a server off-switch (`config/payments.enabled`). The steps in section 12 of `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` must be done before the app is submitted.
- This text replaces the "Own Hub sells the coaching and receives the price" model of decision D63 and decision D61, as the work order WO-10j3 states. Now the member pays the coach directly by InstaPay and Own Hub never holds the money. D63's rates (15 percent, and 8 percent for a client the coach brought with her own invite code) become a fee the coach owes Own Hub. D64 (the 12-month rule) is kept as a coach duty.
- The Arabic on the site is Egyptian, feminine address, Western digits. Counsel should confirm the Arabic as well as the English. Where the two differ, the Arabic prevails (as the pages already say).

## A. Client terms (clauses now in Terms of Use, sections 2, 3, 9, 11, 14 and 15)

- **A1. No money held.** Own Hub does not hold, receive or move money. The member pays the coach's own InstaPay address from her bank app.
- **A2. What Own Hub does.** It shows who to pay and how much, records the payment, asks the coach to confirm that it arrived, and decides a dispute.
- **A3. Check the name.** The member is told to check that the name her bank shows is her coach's before she sends. Own Hub cannot undo an InstaPay transfer. A transfer to a wrong account is for the member's bank; Own Hub does not decide such cases.
- **A4. No check can prove a payment.** Proof is the member's transaction number and optional bank screenshots. Sending a false proof is a breach of the Terms. It is recorded as a strike. Two proven false proofs in 90 days end her ability to pay this way. Fraud may be reported to the authorities and the evidence kept for that.
- **A5. Access before the coach confirms.** Short, bounded access (at most 7 days or the first package week, whichever is shorter) may be given while a proof is checked. It ends if no payment is found.
- **A6. Refund.** Once in the first 14 days. The coach has 3 days to answer. After that Own Hub decides. Own Hub does not move refund money; the coach sends it back by InstaPay and records it.
- **A7. Service problem.** If the coach does not deliver, the member can open a service problem. Own Hub decides on the evidence it holds (sessions, messages, check-ins), may order a full or partial refund, and may strike the coach.
- **A8. Record.** The payment record a member can download is not a tax invoice.

## B. Coach terms (clauses now in Coach Terms, sections 5, 6 and 9)

- **B1. Paid directly.** A member pays the coach's InstaPay address. The coach keeps the address and account name exactly as her bank shows them. A new address takes effect after 24 hours, needs a fresh sign-in and a code sent to her phone. Members with a payment waiting are told.
- **B2. Confirm honestly.** The coach checks her own bank for the exact amount and transaction number, then confirms, or says it has not arrived and attaches her bank's list for that day. Silence for 48 hours brings a reminder; at 72 hours Own Hub reviews it, and the member may get short access meanwhile.
- **B3. Strikes and suspension.** A claim of non-payment that her own statement contradicts is a strike. Two strikes in 90 days suspend her ability to take payments. Staff decide, with a written reason, and two staff agree before a suspension. Current clients are not cut off.
- **B4. The fee.** 15 percent of the price for a client who found her in the app, 8 percent for a client she brought with her own invite code, fixed when the coaching first starts. It is owed when the client's package becomes active, not when she taps confirm. A monthly statement; she pays Own Hub by InstaPay and records it. More than 30 days late: no new clients; current clients are never cut off. No automatic debit.
- **B5. Refunds.** As A6; ignoring a staff refund decision ends her ability to take payments.
- **B6. Stay on Own Hub (D64).** While she coaches a client she met through Own Hub, and for 12 months after the last coaching on Own Hub ends, she may not coach her or take payment from her outside Own Hub. It does not apply to clients she brought with her own invite code. A confirmed breach is a warning and a charge of 3 months of Own Hub's share; a second is a suspension. Proportionality note for counsel: a charge of three months of Own Hub's share is meant as a fair estimate of the lost fee, not as a punishment.
- **B7. Tax.** She is responsible for her own tax status and for any invoice she must issue.
- **B8. Records and reporting.** Payment records and dispute evidence are kept. Fraud may be reported to the authorities.
- **Price note.** The price she sets is the price the member pays, plus a few extra piasters (0.01 to 0.99) that make the amount match only that payment. Those piasters go to the coach and are shown to the member ("pay exactly 500.37").

## C. Dispute process (one paragraph for the Terms or a help page, if counsel wants it written out)

When a member sends proof, the coach is asked to confirm. A reminder goes at 48 hours. At 72 hours without an answer, or at once if the coach says it has not arrived, the payment goes to Own Hub staff, who aim to decide within two working days (owner target). Staff look at, in order: the unique amount and reference; the transaction number; what the screenshots show and how well they match; flags such as a reused number or picture; the timeline; each party's dispute history; and, if still unclear, a bank statement line from both parties with other lines hidden. The decision is recorded with a written reason. A decision to suspend a coach needs two staff. A woman reviews any dispute that holds a woman's private data.

## D. Retention proposal (owner decision 12.4; the site states these numbers)

- Payment records (amount, reference, transaction number, status, steps, notes, coach fee statements): for the period the law requires. On account deletion, kept without the person's name for that period, then deleted. Counsel to name the period (tax and commercial records).
- Payment screenshots and the text read from them: deleted 90 days after the payment is settled or its dispute is closed; deleted at once with the account.
- Strikes: counted over 90 days for the two-strike rule; the decision itself stays with the payment record.

## E. Questions for counsel

1. Is governing, but not touching, peer-to-peer InstaPay payments outside payment-service regulation in Egypt (Central Bank rules)? Does recording a payment, showing the payee, and holding a dispute process change that?
2. Can Own Hub lawfully receive its fee from coaches by InstaPay, and what registration (commercial register, tax card, company) is needed first? Is the fee subject to VAT?
3. Is the 12-month rule, with its penalty of three months of Own Hub's share, enforceable (Civil Code, Art. 224 on penalty clauses)?
4. Strike and suspension wording, and procedural fairness (notice, a chance to reply, a written reason).
5. Refund and withdrawal rules (14 days) under the Consumer Protection Law, for a service that may already be partly delivered.
6. Retention periods for payment records and screenshots under Law 151/2020 and tax law.
7. Legal basis for processing payment records, screenshots and strikes (the site says Article 6, point 4); Google Cloud Vision (European Union endpoint) as a processor; any cross-border transfer permit needed for it.
8. Is a lower-amount acceptance "in writing in the app" binding on the coach and the member?
9. Wording for reporting fraud to the authorities and keeping evidence for that.
10. Does a future optional "help improve receipt reading" (keeping extracted text fields, not pictures) need explicit written consent text? (It is not in the app or on the site now.)
11. Terms section 3 says a woman aged 18 to 20 lacks full contractual capacity until 21. She can now pay a coach. Is she bound by the payment and refund clauses, and does she need anything extra?
12. Terms section 15 limits what Own Hub owes "because you pay Own Hub nothing". Members now pay coaches, not Own Hub. Is the wording still right, and is Own Hub a party to the coaching contract between member and coach?
13. The privacy policy (section 12) says a material change, such as collecting something new, needs the member's agreement in the app. Payment data is new. Is re-acceptance required for existing members, and for existing coaches (Coach Terms v1)?
14. Does the PDPC filing (due before 31 October 2026) need to name payment and financial data, Cloud Vision for receipts, and the strike records?
15. Strikes and suspensions are decided by a person with a written reason. But the receipt checks (amount, recipient, status, time, reused number or picture, signs of editing) automatically decide whether short access starts (a green result gives it at once, an amber one after 24 hours), and a coach's "not received" claim is rejected automatically if her own bank list shows the payment. Are these outcomes automated decisions under Law 151/2020, and what must the policy say about them and about a person's right to have one reviewed?

## F. Questions for Apple and Google

See `docs/owner/PAYMENTS-STORE-POLICY.md` (section 5).

## G. Claims in the published text that must match the shipped build

Each row is a sentence on the site that is only true if the build does it. Check each one before `deploy.sh`. "Verified" means read in code on 27 October 2026.

| Claim on the site | Where | Status |
|---|---|---|
| Two strikes in 90 days; 14-day refund window; 3 days for the coach to answer; 72 hours to staff review; 7 days at most of provisional access; 24 hours for a new address; 30 days late for the fee | privacy 3.18, terms 9, coach terms 9 | Verified in `functions/payments/model.py` (`LIMITS`) |
| Fee 15 percent and 8 percent | coach terms 6 | Verified as defaults (`feeBpsMarketplace` 1500, `feeBpsInvite` 800). The owner can override them in `coachingConfig/instapay`. If she does, change the coach terms before deploying |
| The server reads a screenshot with Google Cloud Vision in the European Union | privacy 3.8, 3.18, section 4 | Verified: `functions/payments/ocr.py` reuses the ID check's `VisionOcr` (EU endpoint) |
| The app reads the receipt on the phone, and the member can hide lines and crop; only that copy leaves the phone, never the original | privacy 3.18, section 10 | NOT verified: the screen (WO-10e3) was not in `app/lib` when this was written |
| Payment screenshots are deleted 90 days after settlement or dispute close, and with the account; payment records are kept without the name for the legal period, then deleted | privacy section 6, delete-account page | NOT built: WO-10a3. `functions/account/deletion.py` still handles the old `paymentProofs` collection and the `payment-proofs/{uid}/` path |
| A fingerprint of each picture is kept so one picture is not used twice | privacy 3.18 | Spec 13.3 step 5; confirm in the build |
| No amount, reference, transaction number or screenshot goes to statistics or crash reports | privacy 3.18 | A test is planned in WO-10k1; confirm it exists |
| Payment push messages are one general line with no amount or name | privacy 3.11 | WO-10j1 (texts checked: no digits, no dashes, 90 characters at most) |
| A woman reviews any dispute that holds a woman's private data; two staff agree before a suspension | privacy 3.18, coach terms 9 | Owner staffing decision 12.4; two-staff rule is WO-10o |
| The receipt checks decide whether short access starts (green at once, amber after 24 hours); a mismatch goes to a person at Own Hub | privacy 3.18 "Checks" | Partly verified: provisional access is in `functions/payments/proof.py`; the green and amber rules are WO-10l and WO-10m. Confirm that no check ever ends a coaching on its own |
| A coach's "not received" claim is checked against the bank list she attaches and rejected if it shows the payment | privacy 3.18 "Checks" | NOT built: WO-10n |
| Staff look at a coach's first three payments, address changes and fee statements | privacy 3.18 "Who sees it" | `firstPaymentsStaffVisible` is 3 in `payments/model.py`; address-change alerts and fee statements in the staff dashboard (WO-10i) |
| A member can give her own InstaPay address so her receipts can be matched | privacy 3.18 "What we keep" | Spec 13.12 item 3; confirm in the app (WO-10e) |
| The fee is owed when the package becomes active, not when the coach taps confirm | coach terms 9 | Spec 13.1; confirm in WO-10c |
| A new address needs a fresh sign-in and a phone code | coach terms 9 | WO-10d-server; confirm |

Left out on purpose: the optional "Help improve receipt reading" line from the work order. The app has no such string, and the site must not describe a choice the app does not show.

## H. Decisions the owner (with counsel) must make before the website is deployed

1. **Re-acceptance.** The app keeps `kTermsVersion = 3` and `kPrivacyVersion = 3`; the site test `functions/tests/test_site_build.py::test_the_policy_and_terms_are_version_3` pins "Version 3.0". They are not bumped. If counsel says payment data is a material change that needs a new acceptance, the app constants, the page version labels and that test must change together, and existing coaches must accept the new Coach Terms.
2. **Home page and waitlist.** `site/_build/pages_en.py` and `pages_ar.py` (home page, about line 204) still say coaching is "free for now". `test_site_build.py` line 602 asserts that sentence, so it is unchanged. Whoever owns that test must change both together. The app itself stays free; the sentence about coaching is what is stale.
3. **Sign-off.** Do not run `site/_build/deploy.sh` until counsel has read the six policy pages and this file. Run `deploy.sh https://own-hub.app --dry-run` first. Deploy the site in the same window as the app submission, so the policy matches what the stores see.
4. **Numbers.** Confirm the fee rates, the 90-day screenshot period, the strike rule, the two-working-day target, and who the dispute reviewers are (spec 12.4 to 12.6).
