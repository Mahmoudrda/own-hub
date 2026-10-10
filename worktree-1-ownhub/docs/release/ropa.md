# Own Hub, record of processing activities and transfer assessment

Local working document. Not published, not in the repository. Built on 6 October 2026 from the code
(`contracts/deletion_manifest.json`, `functions/identity/config.py`, `functions/waitlist/join.py`,
`firebase/firestore.indexes.json`, `firebase/ops/ttl-policies.sh`) and from the published privacy
policy version 3.0, sections 3, 4 and 6. A lawyer confirms the bases and the periods.

**Controller:** Mahmoud Reda, an individual publishing Own Hub in his own name, who also acts as data
protection officer. Contact: the privacy mailbox in `site/config.json`.
**Permit:** not yet issued by the Personal Data Protection Centre. Sensitive data (health, face
match) and transfers abroad both need it.
**Data subjects:** women in Egypt aged 18 or over who sign up; people who join the website waitlist;
people who write to the mailbox. No children: under 18 is refused at the check.

---

## 1. Processing activities

| # | Activity | Data | Where it lives | Basis (PDPL) | Retention | How it ends |
|---|---|---|---|---|---|---|
| 1 | Account and sign-in | phone number, IP address and device details at sign-in | Firebase Authentication (US) | contract, Art. 6(2) | until account deletion | deleted last in `delete_account` (manifest row 29) |
| 2 | Account data | account id, language, settings, setup answers, eating preferences | Firestore `users/{uid}`, `eatPrefs` (europe-west3) | contract | until deletion | recursive delete (rows 1, 13) |
| 3 | Legal acceptance and consent records | versions accepted, language, app version, time; each separate consent | `users/{uid}/consents` | legal obligation, Art. 6(3); ER Art. 2 | until deletion | group hook (row 10) |
| 4 | Women-only check | ID card and selfie images, name, birth date, raw ID number | memory of the `verify_identity` function only (europe-west3), Cloud Vision EU endpoint | explicit written consent, Art. 12; sensitive (biometric) | never stored, discarded when the check ends | not written anywhere |
| 5 | Check result and review case | outcome, reason codes, score bands, attempt number, dates | `verificationJobs`, `verification_flags` | explicit consent, Art. 12 | 180 days after the decision (`DECIDED_RECORD_RETENTION_DAYS`) | TTL `expireAt`; group hook on deletion (rows 22, 39) |
| 6 | Selfie liveness session | session id, server-chosen steps | `verificationSessions` | explicit consent | 5 minutes (`CHALLENGE_TTL_SEC`) | TTL `expiresAt`; hook (row 41) |
| 7 | One card, one account | keyed code (HMAC) of the ID number; pepper in Secret Manager | `nidRegistry` | explicit consent; legitimate rights, Art. 6(4) | while the account exists, then closed with no end date | closed on deletion (row 23). **Open:** no end date; see section 4 |
| 8 | Fraud signals | failed attempts per ID code; scrambled installation id with last codes tried | `verificationBehaviour`, `verificationInstalls` | legitimate rights | 180 days after the last attempt (`SIGNAL_RETENTION_DAYS`) | TTL (rows 42, 43) |
| 9 | Reviewer access log | which reviewer opened which case, when; `reviewerBypass` entries | `verificationReviewAccess` | legal obligation (record of access) | 1 year (`ACCESS_LOG_RETENTION_DAYS`) | TTL (row 44) |
| 10 | Cost ledger | per-uid spend counter, operation ids | `verificationLedger/{uid}` | contract | until deletion | hook (row 40) |
| 11 | Review by a woman | request and route; number looked up at the moment of contact | `verification_flags`, Auth | consent, Art. 2 | as row 5 | as row 5 |
| 12 | Training and meals | workouts, sets, bests, meals, plates, plans, weekly goals | `users/{uid}/weeks, sessions, meals, bests, mealPlans, splits` | contract | until deletion | recursive delete |
| 13 | Health backup, only if turned on | cycle, periods, check-ins, measurements, weight, life stage, allergies | `users/{uid}/cycle, periods, checkins, measurements, private` | explicit written consent, Art. 12; sensitive (health) | until she turns backup off or deletes | turning off deletes the cloud copy; recursive delete |
| 14 | Push notifications | device token | `users/{uid}/devices` | contract | until deletion | recursive delete (row 8) |
| 15 | Technical security | App Check installation id, Play Integrity or App Attest verdicts | Google, global; Apple | legitimate rights, Art. 6(4) | Google's own period | not linked to the account |
| 16 | Selfie guidance | ML Kit device model, OS, app version, installation id, performance events | Google, global | legitimate rights | Google's own period | not linked |
| 17 | Crash reports, only if allowed | error, device, OS, app version, memory, installation id | Firebase Crashlytics, global | consent, Art. 2 | 90 days | Google deletes; turning off deletes waiting reports (row 28) |
| 18 | Server logs | outcomes and reason codes, never phone, ID number or uid beside an outcome | Cloud Logging `_Default` | legitimate rights | 30 days | bucket retention |
| 19 | Deletion record | state and dates only | `deletionRequests/{uid}` | legal obligation (proof of erasure), ER Art. 3 and 14 | published: 3 years. **Open:** no TTL in code yet | retained (row 31) |
| 20 | Waitlist | phone or email, language, consent, date, keyed IP code | `waitlist` | consent, Art. 2 and 17 | 180 days at most | TTL; deleted once messaged |
| 21 | Waitlist consent proof | keyed contact code, wording version, language, date | `waitlistConsentProof` | legal obligation, Art. 18 | 3 years after the last message (180 days plus 3 years from joining) | TTL |
| 22 | Waitlist abuse limit | keyed IP code, attempt count | `waitlistRate` | legitimate rights | 2 days | TTL |
| 23 | Support and rights requests | message, email address | the mailbox (Gmail today) | contract; legal obligation for rights requests | 1 year after the conversation ends | manual |
| 24 | Data export | the copy she asks for | sent by email as a password-protected file | legal obligation, Art. 2 | not kept after sending | manual |

Not in this build, switched off by compiled flags: community (posts, comments, reports), coaching
(coach profiles, relationships, messages, invites), the AI assistant, payments. Their manifest rows
(19, 30, 45 to 49) delete or pseudonymise anything that exists. Amplitude (row 27) is listed in the
manifest but no Amplitude SDK is in the app.

## 2. Processors

| Processor | What | Agreement to accept in the console |
|---|---|---|
| Google (Firebase, Cloud, Vision, Secret Manager, ML Kit, Crashlytics, App Check) | rows 1 to 22 | Google Cloud Data Processing Addendum; Firebase Data Processing and Security Terms |
| Apple | App Attest | Apple Developer Program License Agreement |
| Mobile operators and Google's SMS partners | sign-in codes | through Firebase |
| Website host | standard request data | to confirm when the host is named |
| Team chat service | case number and reason codes | to confirm when the service is named, or remove the alert |
| Mailbox provider | support and rights mail | consumer Gmail has no processor agreement: move to Google Workspace on the domain |

## 3. Transfer impact assessment

| Destination | Data | Why there | Safeguards | Residual risk |
|---|---|---|---|---|
| Germany / EU (europe-west3, Vision EU endpoint) | rows 2 to 14, 19 to 22 | the project's region | Google DPA, encryption in transit and at rest, no training on customer data (Service Specific Terms §18), images in memory only | low |
| United States | phone number, IP, device details (Firebase Authentication) | Authentication runs only in the US | Google DPA, encryption, consent on the sign-up screen before the number is sent | US government access requests; mitigated by data minimisation (number only) |
| Google global (includes US) | App Check, ML Kit, Crashlytics | Google does not offer a region for these | Google DPA; Crashlytics only with consent; none linked to the account | **App Check runs at first launch, before any consent screen.** ER Art. 16 asks for consent before each transfer. Fix: activate App Check after the sign-up consent, or name it on a first-run screen |
| Apple | App Attest | Apple's attestation service | Apple terms | Apple publishes no location |

The Centre has not published a list of adequate countries. Each transfer above needs the transfer
permit, and the permit application must name these destinations (ER Art. 16(4)).

## 4. Open items for the lawyer

1. **Closed ID code (row 7)** is kept with no end date, and a woman who deleted her own account cannot
   rejoin with the same card. The research recommends closing it for 3 years and letting a woman who
   deleted her own account rejoin. That needs a code change (`DELETED_ACCOUNT_MAY_REJOIN`,
   `identity/dedupe.py`, a TTL on `nidRegistry`) before the policy can say so.
2. **Deletion record (row 19)** is published as 3 years but has no `expireAt` or TTL yet.
3. **App Check before consent** (section 3).
4. **Server logs**: 30 days today; Cybercrime Law 175/2018 Art. 2 may require 180 days of identifying
   logs from a service provider.
5. **Mailbox** on consumer Gmail (section 2).
6. **Periods** in section 1 match the code. The law sets no fixed numbers; it requires a period tied to
   the purpose (PDPL Art. 3 and 4).
