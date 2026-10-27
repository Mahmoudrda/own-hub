# Store privacy answers for InstaPay payments (App Store and Google Play)

Written 27 October 2026. Not verified with Apple or Google: the labels below are the conservative reading. Nothing here says Apple or Google approved anything.

Why it matters: the privacy manifest, the Play data safety form, the App Store privacy answers and the website privacy policy (section 3.18) must change together, or a store can reject the update. The facts behind all four are the same: a member pays her coach directly by InstaPay; Own Hub never holds the money; it keeps a payment record, the transaction number she gives, and the redacted bank screenshots she may send.

## 1. App Store Connect, App Privacy (the owner does this by hand)

Add three data types. For each: linked to her, not used for tracking, purpose App Functionality only.

| Category | Data type | What it is in Own Hub |
|---|---|---|
| Financial Info | **Payment Info** | A coach's InstaPay address and account name (set in the payments setting). A member's own InstaPay address, only if she saves one so her receipts can be matched |
| Financial Info | **Other Financial Info** | The amount, reference code, transaction number, status and steps of a payment between a member and her coach, and the coach's monthly fee statement. Own Hub never holds the money |
| Purchases | **Purchase History** | The list of a member's payments for coaching |

Changed rows:

- **Photos or Videos** now also covers the redacted bank screenshots a member sends as payment proof (stored privately; the original never leaves her phone).
- **Emails or Text Messages**: the notes and reasons a member or coach writes in a payment dispute are kept with the payment record.
- In the sentence "Leave every other box empty ...", remove "purchases, financial info" from the list of empty boxes.
- In the final summary, **Data Linked to You** now also lists Financial Info (Payment Info, Other Financial Info) and Purchases (Purchase History).
- Do not tick "Used for tracking" for any of them. Never describe payment data as part of analytics or crash reports (it is not).

Privacy Policy URL stays `https://own-hub.app/privacy`; check it shows section 3.18 before you submit.

## 2. Google Play, Data safety (the owner does this by hand)

Add a **Financial info** block.

| Play type | What it is | Collected | Shared | Required | Purpose |
|---|---|---|---|---|---|
| User payment info | A coach's InstaPay address and account name; a member's own address if she saves one | Yes | No | Optional for a member; required for a coach who takes payments | App functionality; Fraud prevention, security and compliance |
| Purchase history | A member's payments to her coaches (package, amount, reference, status, times) | Yes | No | Required for the payment feature | App functionality; Fraud prevention, security and compliance |
| Other financial info | Transaction number a member gives, amounts and steps of a payment, a coach's monthly fee statement | Yes | No | Required for the payment feature | App functionality; Fraud prevention, security and compliance |

Notes for the form:

- "Shared: No". Google Cloud Vision reads a payment screenshot for us as a service provider (European Union endpoint). This is processing on our behalf, not sharing. UNVERIFIED with Google: confirm that reading, and confirm the Cloud Vision processor and region with counsel.
- Data is encrypted in transit. A member or coach can ask for deletion (in the app, Profile, Your data, Delete everything, or on `https://own-hub.app/delete-account`). Say that payment records are kept without the person's name for the period the law requires (owner decision 12.4).
- **Photos**: add "bank screenshots sent as payment proof, with the lines she hid left hidden; the original never leaves her phone; stored privately; deleted 90 days after the payment is settled or its dispute closes (UNVERIFIED: owner decision 12.4). Optional."
- **Messages**: add "the notes and reasons written in a payment dispute are kept with the payment record."
- Remove the old sentence in the working copy that says "No payments exist in this version".

## 3. Exact changes for the app builder (not made here; `app/` is not touched by this document)

These are the work order WO-10j3 steps 1, 2, 4 and 5, with the corrections found on 27 October. The coding agent that owns `app/` makes them.

1. `app/ios/Runner/PrivacyInfo.xcprivacy`: after the `NSPrivacyCollectedDataTypePhotosorVideos` dict add three dicts, each in the same shape, with `NSPrivacyCollectedDataTypeLinked` true, `NSPrivacyCollectedDataTypeTracking` false and the single purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`:
   - `NSPrivacyCollectedDataTypePaymentInfo`
   - `NSPrivacyCollectedDataTypeOtherFinancialInfo`
   - `NSPrivacyCollectedDataTypePurchaseHistory`

   UNVERIFIED: that these are Apple's exact key spellings (written from the published list of collected data types). Check with Apple's "Describing data use in privacy manifests" page, then run `plutil -lint app/ios/Runner/PrivacyInfo.xcprivacy` (must print `OK`). Add to the comment block at the top: PaymentInfo (coach InstaPay address and account name, a member's own address if saved); OtherFinancialInfo (amount, reference, transaction number, status, steps, fee statement; Own Hub never holds the money); PurchaseHistory (a member's payments for coaching); and that PhotosorVideos also covers the redacted payment screenshots.
2. `app/android/play-data-safety.txt`: add the "Financial info" block (section 2 above, in the file's own layout) before the line `Photos and videos`; append the payment-proof sentence to the Photos entry and the dispute-note sentence to the Messages block; **replace** the line "No payments exist in this version: no payment info, purchase history or financial info is collected." (in the coaching block, about line 113), which is now false; add an "Updated 27 October 2026" line.
3. `app/test/release/store_disclosures_test.dart`: one test that the manifest contains the three type strings and the safety text contains "Financial info" and "User payment info" (use the variable names the file already uses).
4. `app/tool/release_preflight.sh`: three `check` lines for the three manifest entries. The preflight total then goes up by three; update the number wherever `docs/owner/LAUNCH-GUIDE.md` quotes it.
5. Working copies in `docs/release/` (gitignored, local only): `docs/release/launch-pack/app-store-privacy-answers.md` should get the same paragraph, rows and summary as section 1 above. It is not changed here.

## 4. Check after the changes

- `plutil -lint app/ios/Runner/PrivacyInfo.xcprivacy` prints `OK`.
- `cd app && flutter test test/release` passes.
- `grep -c "Financial info" app/android/play-data-safety.txt` is at least 1.
