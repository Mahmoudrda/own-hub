# WO-10j3: App Store and Play privacy answers, the manifest, and the drafts for counsel
Depends on: WO-10j2 (same facts), WO-10e3 (the ML Kit package is in)
Size: M
Reads first: `app/ios/Runner/PrivacyInfo.xcprivacy` lines 1-70 and 195-215; `app/android/play-data-safety.txt` lines 1-60, 129-150; `docs/release/launch-pack/app-store-privacy-answers.md` lines 1-60; `app/test/release/store_disclosures_test.dart` lines 1-70; `app/tool/release_preflight.sh` lines 80-95; `DECISIONS.md` D61, D63, D64

## Why
The three store declarations and the privacy policy must change together or the stores can reject the update (the answers file itself says so). With InstaPay payments the app now keeps financial information about a woman (payment records, transaction numbers, a payment address) and payment screenshots. Counsel must also see the legal wording as one document, clearly marked as a draft. Nothing here is verified with Apple or Google; the Apple labels are the conservative reading.

## Final result
- The privacy manifest declares three more data types: Payment Info, Other Financial Info, Purchase History (all linked to her, not tracking, App Functionality).
- The Play data safety text has a new "Financial info" block and updated Photos, Messages and Purchase lines.
- The App Store answers file has a new accuracy-pass paragraph, three table rows and the new summary line.
- `docs/release/launch-pack/instapay-terms-drafts.md` holds the client and coach terms drafts, marked DRAFT FOR COUNSEL, with the questions for counsel.
- The release test and the preflight script check the new manifest entries so they cannot be dropped.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/ios/Runner/PrivacyInfo.xcprivacy | edit | three data types and the explaining comment |
| app/android/play-data-safety.txt | edit | Financial info, Photos, Messages, Purchases |
| docs/release/launch-pack/app-store-privacy-answers.md | edit | paragraph, rows, summary |
| app/test/release/store_disclosures_test.dart | edit | one test |
| app/tool/release_preflight.sh | edit | three checks |
| docs/release/launch-pack/instapay-terms-drafts.md | create | drafts for counsel |

## Steps
1. File `PrivacyInfo.xcprivacy`. Anchor: the `<dict>` that holds `NSPrivacyCollectedDataTypePhotosorVideos` (about line 198-209). Add three sibling `<dict>` blocks after it, each identical in shape to that block with the type string changed:
```xml
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypePaymentInfo</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<true/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
			</array>
		</dict>
```
then the same with `NSPrivacyCollectedDataTypeOtherFinancialInfo` and `NSPrivacyCollectedDataTypePurchaseHistory`. In the comment block at the top (the list that starts about line 29, `LINKED ... purpose AppFunctionality`), add after the `OtherDataTypes` item:
```
	    - PaymentInfo: a coach's InstaPay address and account name (set
	      in the payments setting), and a member's own InstaPay address if she
	      saves one to match her receipts.
	    - OtherFinancialInfo: the amount, reference code, transaction number,
	      status and steps of a payment between a member and her coach, and the
	      coach's monthly fee statement. Own Hub never holds the money.
	    - PurchaseHistory: the list of a member's payments for coaching.
	    - PhotosorVideos (above) also covers the redacted bank screenshots a
	      member sends as payment proof. The original never leaves the phone.
```
UNVERIFIED: that Apple's manifest key spellings are exactly `NSPrivacyCollectedDataTypePaymentInfo`, `NSPrivacyCollectedDataTypeOtherFinancialInfo`, `NSPrivacyCollectedDataTypePurchaseHistory`; check with `grep -rn "PaymentInfo\|OtherFinancialInfo\|PurchaseHistory" ~/Library/Developer/Xcode 2>/dev/null | head -3` or Apple's "Describing data use in privacy manifests" page. Then validate with `plutil -lint app/ios/Runner/PrivacyInfo.xcprivacy` (must print `OK`).
2. File `app/android/play-data-safety.txt`. (a) Header: add a line to the "Updated" paragraph: `Updated 27 October 2026: payments by InstaPay between a member and her coach (Financial info block; Photos, Messages and Purchases lines changed).` (b) Anchor: the line `Photos and videos` (line 129). Insert before it a new block:
```
Financial info
  - User payment info
      A coach's InstaPay address and account name, and a member's own InstaPay
      address if she saves one to match her receipts. Collected, stored on our
      servers (Frankfurt), not ephemeral, linked. Optional for a member; required
      for a coach who takes payments. Own Hub never holds the money.
      Purpose: App functionality; Fraud prevention, security and compliance.
  - Purchase history
      The member's payments to her coaches (package, amount, reference, status,
      times). Linked. Required for the payment feature. Purpose: App functionality;
      Fraud prevention, security and compliance.
  - Other financial info
      The transaction number a member gives, the amounts and steps of a
      payment, and a coach's monthly fee statement. Linked. Purpose: App
      functionality; Fraud prevention, security and compliance.
  Shared with third parties: No. Google Cloud Vision reads a payment screenshot
  for us as a service provider (UNVERIFIED: confirm processor status and region).
  Never sent to analytics or crash reports.

```
(c) In the `Photos` entry (line 130), append: `Also, for a payment proof: the member's bank screenshots, with the lines she hid left hidden (the original never leaves her phone), stored privately, read by our server, deleted 90 days after the payment is settled or its dispute closes (UNVERIFIED: owner decision 12.4). Optional. Purpose: App functionality; Fraud prevention, security and compliance.` (d) In the `Messages` block (line 79) append: `The notes and reasons a member or coach writes in a payment dispute are kept with the payment record.`
3. File `docs/release/launch-pack/app-store-privacy-answers.md`. (a) Insert as the first paragraph under the title (before `**Accuracy pass, 23 October 2026`):
```
**Payments check, 27 October 2026 (InstaPay between a member and her coach; Own Hub holds no money).** Three new data types and one changed row. Add **Payment Info** (Financial Info): a coach's InstaPay address and account name, and a member's own address if she saves one. Add **Other Financial Info**: payment amounts, reference, transaction number and status, and the coach's fee statement. Add **Purchase History** (Purchases): the member's payments for coaching. All three: linked, not tracking, App Functionality. **Photos or Videos** now also covers the redacted bank screenshots sent as payment proof. The manifest has the three new entries (`NSPrivacyCollectedDataTypePaymentInfo`, `...OtherFinancialInfo`, `...PurchaseHistory`) and `android/play-data-safety.txt` has a Financial info block. The Apple labels are the conservative reading and are not verified with Apple. The summary now reads: Data Linked to You adds Financial Info (Payment Info, Other Financial Info) and Purchases (Purchase History).
```
(b) In "Tick these data types, and nothing else" table add rows `| Financial Info | **Payment Info** and **Other Financial Info** |` and `| Purchases | **Purchase History** |`; and in the sentence "Leave every other box empty: ..., purchases, financial info, ..." remove `purchases, financial info,`. (c) In the per-type table add three rows in the same columns as the others (copy the style): Payment Info, Other Financial Info, Purchase History with the descriptions of step 1, `**Yes**`, `**No**`, `App Functionality`. (d) In the final summary list change `- **Data Linked to You:** Contact Info (Name, Phone Number), Health & Fitness, ...` by adding `Financial Info (Payment Info, Other Financial Info), Purchases (Purchase History), `.
4. File `app/test/release/store_disclosures_test.dart`. Add inside the `'the iOS privacy manifest declares what an account collects'` group a test (copy the helper the neighbours use; the file declares a function at line about 15 that checks a type is declared, linked and AppFunctionality):
```dart
    test('payments: Payment Info, Other Financial Info and Purchase History are declared', () {
      for (final t in ['PaymentInfo', 'OtherFinancialInfo', 'PurchaseHistory']) {
        expect(manifest, contains('NSPrivacyCollectedDataType$t'), reason: '$t missing');
      }
      expect(safety, contains('Financial info'));
      expect(safety, contains('User payment info'));
    });
```
(UNVERIFIED variable names `manifest` and `safety`: read lines 1-40 of the test file and use the names it uses.)
5. File `app/tool/release_preflight.sh`. After the line `check "privacy manifest declares Fitness" ...` (line 93) add three lines in the same form:
```sh
check "privacy manifest declares PaymentInfo" "grep -q '<string>NSPrivacyCollectedDataTypePaymentInfo</string>' ios/Runner/PrivacyInfo.xcprivacy"
check "privacy manifest declares OtherFinancialInfo" "grep -q '<string>NSPrivacyCollectedDataTypeOtherFinancialInfo</string>' ios/Runner/PrivacyInfo.xcprivacy"
check "privacy manifest declares PurchaseHistory" "grep -q '<string>NSPrivacyCollectedDataTypePurchaseHistory</string>' ios/Runner/PrivacyInfo.xcprivacy"
```
Note the preflight count was 83: it becomes 86 (`.claude/CLAUDE.md` mentions "preflight 83/0"; update the owner docs that quote the number: `grep -rn "83" docs/owner/LAUNCH-GUIDE.md | head -3`).
6. File `docs/release/launch-pack/instapay-terms-drafts.md` (create). Title line and first line: `# DRAFT FOR COUNSEL: InstaPay payments, client and coach terms`. Then these sections, in English (the Arabic of the same clauses is on the site, WO-10j2; counsel confirms the Arabic as well):
   - `## Status` : "Draft written 27 Oct 2026 for counsel. Not legal advice. The flag stays off until counsel signs section 12 of the spec. This text replaces D61 and the Own-Hub-is-the-seller model of D63: Own Hub no longer sells the coaching or receives the price. The member pays the coach directly by InstaPay. D63's rates (15 percent and 8 percent of the price) now become a fee the coach owes Own Hub."
   - `## A. Client terms (clauses to add to the Terms, section 9)`: A1 Own Hub does not hold, receive or move money; the client pays the coach's own InstaPay address. A2 What Own Hub does: shows the payee and amount, records the payment, asks the coach to confirm, decides disputes. A3 Check the name before sending; transfers cannot be undone by Own Hub. A4 No check can prove a payment; proof is the client's transaction number and optional screenshots; false proof is a breach, recorded as a strike, two in 90 days end the ability to pay this way; fraud may be reported to the authorities and evidence kept. A5 Access: short, bounded access may be given before the coach confirms; it ends if no payment is found. A6 Refund: once in the first 14 days; the coach has 3 days; then Own Hub decides; Own Hub does not move refund money. A7 Service problem: Own Hub decides on evidence it holds (sessions, messages, check-ins), may order a full or partial refund and strike the coach. A8 The record is not a tax invoice.
   - `## B. Coach terms (clauses to add to the Coach Terms, section 9)`: B1 paid directly; address rules (24 hours, sign-in, code). B2 confirm honestly; the 48 and 72 hour rules; provisional access. B3 strikes and suspension; two staff for a suspension; a written reason; existing clients not cut off. B4 the fee: owed at activation; monthly statement; 30 day rule; no automatic debit. B5 refunds. B6 the 12 month rule (D64) with the penalty (3 months of Own Hub's share) and its proportionality note. B7 tax: she is responsible for her own tax status and invoices. B8 records and reporting of fraud.
   - `## C. Dispute process wording` (one paragraph: reminders at 48 hours, review at 72, staff target two working days, evidence list of spec 13.6, decision with reason, second reviewer for suspensions, a woman reviews any dispute holding a woman's private data).
   - `## D. Retention proposal` : payment records for the legal period then pseudonymised; screenshots 90 days after settlement; strikes 90 days for the rule; owner decision 12.4.
   - `## E. Questions for counsel` (numbered): 1 Is governing but not touching peer-to-peer InstaPay payments outside payment-service regulation in Egypt? 2 Can Own Hub lawfully receive its fee by InstaPay, and what registration (commercial register, tax card) is needed? 3 Is the 12 month rule and its penalty enforceable (Civil Code Art. 224)? 4 Strike and suspension wording and procedural fairness. 5 Refund and withdrawal rules (14 days) under consumer law. 6 Retention periods for payment records and screenshots under Law 151/2020 and tax law. 7 Basis for processing payment records and screenshots; Cloud Vision as a processor and cross-border transfer. 8 Is a lower-amount acceptance "in writing in the app" binding? 9 Reporting fraud to the authorities: wording. 10 Does the optional "help improve receipt reading" need explicit consent text?
   - `## F. Questions for Apple and Google` : see WO-10q (list only, link to the file `handover/work-orders/WO-10q-store-compliance.md`).

## Strings to add
None.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| store_disclosures_test.dart | `payments: Payment Info, Other Financial Info and Purchase History are declared` | as step 4 |
| (command) | `the manifest is valid` | `plutil -lint app/ios/Runner/PrivacyInfo.xcprivacy` prints `OK` |
| (command) | `preflight` | `cd app && bash tool/release_preflight.sh 2>&1 | tail -5` shows the three new checks passing (UNVERIFIED: the script may need a built release; if it fails on unrelated checks, run only the grep lines) |
Run: `cd app && flutter test test/release`

## Verify
- `cd app && flutter test test/release` ends `All tests passed!`
- `grep -c "Financial info" app/android/play-data-safety.txt` is at least 1; `grep -c "Payments check, 27 October" docs/release/launch-pack/app-store-privacy-answers.md` is 1.

## Do not
- Do not tick "Used for tracking". Do not add Financial Info to analytics or crash descriptions.
- Do not publish the drafts: `instapay-terms-drafts.md` is for counsel only, and carries DRAFT FOR COUNSEL in its first line.
- Do not claim the labels are verified with Apple or Google.

## Done checklist
- [ ] manifest, Play text, App Store answers, test, preflight, drafts file

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10q).

UNVERIFIED in this order: 3 (manifest key spellings, test variable names, preflight can run standalone).
