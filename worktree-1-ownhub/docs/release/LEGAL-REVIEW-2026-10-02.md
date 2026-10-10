# Own Hub, pre-counsel legal review of the Privacy Policy and Terms of Use

**Date:** 2 October 2026
**Prepared for:** the Egyptian lawyer who signs off the launch documents, and the publisher, Mahmoud Reda.
**Reviewed:** `privacy-policy.md` and `terms.md` (both "redrafted 23 September 2026"), and the third
source document `delete-account.md`, all in this folder, against the code in
`.claude/worktrees/release-readiness` (`app/`, `functions/`, `firebase/`).
**Current text for counsel (6 October 2026):** the Privacy Policy and Terms of Use version 3.0, in
English and Arabic, built from `site/_build/pages_en.py` and `site/_build/pages_ar.py` to
`site/privacy/`, `site/terms/` and `site/delete-account/` (and the same under `site/ar/`). They
supersede `privacy-policy.proposed.md` and `terms.proposed.md`, which still describe review by video
call and partner gyms. The section references below point at those superseded drafts and are kept as
a record of what was found on 2 October.

> **I am not a lawyer, and this is not legal advice.** This is a pre-counsel review. It collects the
> facts from the code, the text of the laws and the store policies, and marks what a source confirms
> and what is uncertain, so that an Egyptian lawyer can decide quickly. Every legal conclusion here
> needs that lawyer's sign-off. The English texts of Egyptian law cited below are unofficial
> translations. The Arabic text in the Official Gazette is authoritative.

---

## 0. The finding that matters most

**Both documents describe a different app.** They were written on 23 September for a cut-down 1.0
with no account, no server and no network code ("Own Hub collects nothing about you", "There is no
network library of any kind in it", "the released app does not even ask for permission to use the
internet"). On 24 September that 1.0 was cancelled. The build under review contains Firebase Auth,
Firestore, Cloud Functions, Cloud Storage, the camera, Google ML Kit face detection, and a deployed
identity verification backend in `europe-west3`. Almost every factual statement in Part A of the
policy, and sections 2, 3, 6, 8, 9 and 10 of the Terms, is now false for the build that will ship.
`delete-account.md`, `play-listing.md` and `appstore-listing.md` (Data safety and App Privacy answered
"Data Not Collected") have the same problem.

The documents cannot be fixed with edits. They need replacing, which is why the proposed versions
are full rewrites.

**A second fact the owner must settle first.** In the worktree code, `FeatureFlags.shipped`
(`app/lib/domain/flags/feature_flags.dart`) still has `accountRequired`, `signUp` and `verification`
set to **false**, so the build as it stands opens straight onto Home and never reaches sign-up. The
brief says the launch build has sign-up, verification and sync. The proposed documents are written for
that launch build. **The documents and the store forms must describe the binary that is actually
submitted.** If the submitted binary still has these flags off, the documents need a third version.

---

## 1. What the app really does (verified in code)

| Fact | Where it is in the code | Notes |
|---|---|---|
| Sign-up with an Egyptian phone number and an SMS code via Firebase phone auth | `app/lib/features/signup/data/firebase_auth_repository.dart`, `phone_number_view.dart` (+20) | **Firebase Authentication runs only in US data centres** (Firebase privacy page, see S10). The phone number therefore leaves for the US, not Germany. The brief's "data stored in Germany" is incomplete |
| Separate consent before the camera opens, recorded with a version | `consent_view.dart`, `functions/main.py` `record_consent`, `users/{uid}/consents/verification-v1` | Good. It is the only consent recorded anywhere in the app |
| ID front and back photographed live, read by Cloud Vision on `eu-vision.googleapis.com` | `functions/identity/config.py` `VISION_ENDPOINT`, `providers_selfhosted.py` | Google states images sent inline are "processed in memory and not persisted to disk" and not used for training (S11) |
| Live selfie with a server-issued challenge, face match by a self-hosted SFace/YuNet model in Cloud Functions, `europe-west3` | `functions/identity/faces.py`, `providers_selfhosted.py`, `functions/models/` | Biometric processing. No outside face vendor. Nothing stored |
| On-device face detection to guide the selfie camera | `pubspec.yaml` `google_mlkit_face_detection` | **Not mentioned anywhere.** ML Kit sends device info, app version, a per-installation identifier and performance events to Google (S12). Must be on the Data safety form and in the policy |
| Sex from digit 13 of the national ID number, cross-checked against the printed field. Age from the number | `functions/identity/nid.py`, `decisions.py`, `pipeline.py` | **`MIN_AGE = 18`** (`config.py` line 110). Under 18 is refused (`UNDERAGE`) |
| National ID number stored only as HMAC-SHA256 with a pepper held in Secret Manager, in `nidRegistry/{hmac}` with `{uid, pepper_version, state, createdAt}` | `functions/identity/dedupe.py`, `store.py` | The code's own comment says the 14-digit space can be brute-forced in under a minute if the pepper leaks. The pepper is the whole defence. That is correct to say, and the policy should not call the hash "impossible to reverse" |
| Also stored: verification job (outcome, reasons, flags, attempt, cost, provider ids, score bands, timestamps), flag documents with **raw liveness and match scores and the id_hmac**, per-ID failure counts (`verificationBehaviour`), a **hash of the app install id** with the last 10 ID hashes it tried (`verificationInstalls`), the cost ledger, daily counters by governorate, reviewer access log | `store.py`, `main.py` | None of this is in either document. The consent screen says "nothing is kept except a one way keyed hash of your ID number", which is not accurate |
| Woman reviewer by live video call, or in person at a partner gym | `main.py` `schedule_verification_review` (routes `video`, `gym`) | The video tool is not built in. The code says the booking "lives wherever the reviewers already keep their diary". The policy must name the call service, which will process her face and voice |
| Health data synced to Firestore `users/{uid}/...` in `europe-west3` once she is verified: sessions, meals, eatPrefs, mealPlans, check-ins, measurements, cycle, periods, notices, firstWeek, and on `users/{uid}.profile` her goal, equipment, **life stage (pregnant, postpartum, pain or injury)**, **allergies**, dietary choices, language | `app/lib/app_state/cloud_store.dart`, `cloud_documents.dart` | The first sync uploads everything she logged before she had an account. **There is no consent step for health data before this upload** |
| Cloud Storage: `own-hub-personal` bucket (Frankfurt) is referenced but unused in this release; the default bucket (content library, us-east1 per the brief) holds exercise and recipe media; `user-exports/{uid}` is readable by the owner but nothing writes it | `firebase_boot.dart`, `firebase/storage.rules` | No personal data in the US bucket, as the brief says |
| No analytics, no crash reporting, no advertising SDK, no push messaging SDK | `pubspec.yaml` | True. The deletion manifest lists Amplitude and Crashlytics rows for the future, which are not in the build |
| Permissions: Android `CAMERA` (plus `INTERNET` merged in by the Firebase plugins); iOS `NSCameraUsageDescription` | `AndroidManifest.xml`, `Info.plist` | The policy says "no camera" and "no permissions at all" |
| iOS privacy manifest declares only `DeviceID` collected | `ios/Runner/PrivacyInfo.xcprivacy` | Must be brought in line with the App Privacy answers |
| **Account deletion** | `app/lib/app_state/account_data.dart`, `account_deletion_service.dart`, `deletion_manifest.dart` | **The in-app "Delete everything" clears the phone only.** The code says so: "There is now a server copy, and this does not delete it." `requestAccountDeletion` does not exist in `functions/`, there is no real `DeletionTransport`, `users/{uid}` cannot be deleted by a client, and the Firebase Auth record (phone number) is never deleted. The sheet still says "There is no server yet, and nothing of yours is held anywhere else" |
| What deletion is designed to keep | `deletion_manifest.dart` row 23 | `nidRegistry` is "closed, not deleted" for **every** deletion, so any woman who deletes her account can never rejoin with her card. `VERIFICATION_SPEC.md` section 4 says the opposite (deleted unless banned). Counsel must pick one |
| Legal links | `app/lib/config/legal_links.dart` | **All four URLs are empty strings**, so the app shows no privacy policy, terms or deletion link |
| Severe symptom care link | `app/lib/config/care_links.dart` | Empty. The copy still reads "Read NHS guidance on period pain" |

---

## 2. Egyptian law, what the sources say

Status labels: **Confirmed** means read in the cited text. **Uncertain** means inference, a secondary
source, or conflicting sources.

### 2.1 Personal Data Protection Law No. 151 of 2020 (PDPL) and its Executive Regulations

| Point | Status | What it says | Source |
|---|---|---|---|
| The law is in force | Confirmed | Issued 13 July 2020, in force three months after publication (about 15 October 2020) | S1, issuing law Arts. 6 and 7 |
| **The Executive Regulations have been issued** | Confirmed | Ministry of Communications and IT **Decree No. 816 of 2025**, Official Gazette (Al-Waqa'i' al-Misriyya) issue 244, supplement A, **1 November 2025**. Some secondary sources give 10 November or December 2025. The Gazette date is the formal one | S2 (cover page), S3 |
| **Grace period ends about 1 November 2026** | Confirmed (date Uncertain by one day) | Issuing law Art. 6: comply "within one (1) year from the date of issuance of the Executive Regulations". Firms give 1 November or 31 October 2026. **No extension found** | S1, S3 |
| **Licence or permit before processing** | Confirmed | ER Art. 2: "The entity collecting Personal Data shall hold a License or Permit as a Controller or Processor". PDPL Art. 12: sensitive data may not be collected "except by virtue of a license issued from the Center" | S1, S2 |
| **Individuals get a Permit, not a Licence** | Confirmed | ER Art. 19 (Licence is for legal entities), Art. 22 (conditions for natural persons), Art. 37 (application: ID document, criminal record certificate, qualifications, data volume, sensitive data, retention, consent mechanism, infrastructure, security certifications). Art. 38: valid for up to one year, renewable (Art. 40) | S2 |
| Whether an ongoing consumer app can run on a Permit | **Uncertain** | ER Art. 20 describes Permits as "for a specific and temporary purpose". The PDPC may require a company and a Licence | S2 |
| Fees | Confirmed | Permit fee **exempt from 1 to 25,000 records**; 25,001 to 250,000 records EGP 10,000 to 25,000 depending on duration, halved for controller-only. Cross-border permit is 50% of the applicable fee (Art. 27). Statutory caps: EGP 2m Licence, EGP 500k Permit (PDPL Art. 26) | S1, S2 |
| **The PDPC must approve the consent mechanism** | Confirmed | ER Art. 2(3): "Approval from the ... PDPC shall be obtained for mechanisms used in Personal Data collection and for obtaining consent" | S2 |
| DPO | Confirmed | For a natural person controller the controller is "in charge of the application" of the law (PDPL Art. 8), and ER Art. 38 says the Permit holder acts "as the Data Protection Officer". Whether he must pass PDPC DPO tests is **Uncertain** | S1, S2 |
| **Sensitive data** covers health, biometric and children's data | Confirmed | PDPL Art. 1: data "which discloses psychological, mental, or physical health, or genetic, biometric or financial data". Cycle, pregnancy, postpartum, pain and injury, allergies, weight, and the face match all fall in it | S1 |
| **Explicit written consent** for sensitive data | Confirmed | PDPL Art. 12. ER Art. 14(2): "explicit written consent (in paper or electronic form)". ER Art. 14(3): data must be "essential and necessary". ER Art. 14(7): keep records of consents and deletion requests | S1, S2 |
| **Cross-border transfer** | Confirmed | PDPL Art. 14: only to a country with equal protection "and subject to obtaining a relevant License or Permit from the Center". ER Art. 16(2): obtain the data subject's consent to the transfer. ER Art. 16(4): only to the countries named in the permit. ER Art. 26: PDPC decides within 90 business days, **silence is a rejection** | S1, S2 |
| Adequate country list | **Uncertain** | None found. Whether the US (Firebase Auth) or Germany qualifies is unknown | |
| **Breach notification** | Confirmed | ER Art. 5: notify the Center within **72 hours** of becoming aware, and the data subject within **3 business days** of notifying the Center, by SMS, email or phone | S2 |
| **Response to data subject requests** | Confirmed | PDPL Art. 32: reply "within six (6) working days". Art. 2 allows a fee capped at EGP 20,000. Complaints to the Center (Art. 33), decided in 30 working days | S1 |
| Children | Confirmed | ER Art. 15: under 15 needs a guardian's written consent; 15 to 18 needs the guardian's consent. An 18+ rule avoids this | S2 |
| No small-business exemption | Confirmed | Issuing law Art. 3 excludes only personal or household use and state, media and judicial cases | S1 |
| Penalties | Confirmed | Art. 41: sensitive data without consent or outside what the law permits, at least 3 months' imprisonment and/or EGP 500,000 to 5,000,000. Art. 42: the same for cross-border breaches. Economic Courts have jurisdiction | S1 |
| PDPC portal | **Uncertain** | `pdpc.gov.eg` redirects to `portal.pdpc.gov.eg`. A May 2026 report expected launch in mid-June 2026. Whether permit applications are open today is not confirmed | S4 |

**What this means for a launch on about 4 October 2026 (my reading, for counsel to confirm):** launch
falls inside the grace period, but the app processes sensitive data (health and biometric) and
transfers it abroad (Germany and the US), and both require a PDPC permit once the grace period ends
around 1 November 2026. A permit application has a 90 business day decision window with deemed
rejection on silence. Unless an application is filed now, the app will be out of compliance about four
weeks after launch. PDPL Art. 12's licence requirement for sensitive data is in the law itself, so
whether the grace period covers it is a question only counsel can answer.

### 2.2 Consumer Protection Law No. 181 of 2018

| Point | Status | Source |
|---|---|---|
| A "supplier" is anyone in a commercial or professional activity providing a service, "including electronic or modern technological methods". Distance contracting covers sale via the Internet | Confirmed text. **Uncertain** whether a free app from an individual is in scope. Paid subscriptions almost certainly are | S5 Art. 1 |
| **Arabic is mandatory**: "All advertisements, data, documents, invoices, receipts, contracts, including digital and electronic documents, must be in Arabic". Other languages are allowed if Arabic is included | Confirmed | S5 Art. 5 |
| Before a distance contract: name, address, commercial register and tax card numbers, price including taxes, duration of periodic services, withdrawal terms. Confirmation by electronic means | Confirmed | S5 Arts. 37, 38 |
| 14-day withdrawal right; lapses if the service is fully used, and for "software" | Confirmed text. **Uncertain** for digital subscriptions | S5 Arts. 40, 41 |
| Any clause that reduces or exempts the supplier's obligations under the law is void | Confirmed | S5 Art. 28 |
| Auto-renewal | **Uncertain**. No specific rule found | |
| Executive Regulations: PM Decree No. 822 of 2019 | Confirmed only from a search result title | S6 |

### 2.3 Electronic contracts

| Point | Status | Source |
|---|---|---|
| Electronic writing has the same evidential force as paper if the technical conditions are met (Law 15 of 2004, Arts. 15, 18) | Confirmed | S7 |
| Contracts may be concluded electronically under the Civil Code's offer and acceptance rules (Arts. 89, 90) | **Uncertain**, secondary source only | S8 |
| Click-through (click-wrap) acceptance specifically | **Uncertain**. No Court of Cassation ruling found. A browse-wrap ("by downloading or using") is weaker than a tap to agree with a link shown | |

### 2.4 Anti-Cyber and Information Technology Crimes Law No. 175 of 2018

| Point | Status | Source |
|---|---|---|
| "Service Provider" means any natural or legal person providing ICT services, "including those who process or store information" | Confirmed | S9 Art. 1 |
| Service providers must retain information system logs (user-identifying, traffic, device data) for **180 days**, and publish their name, address, contact and licensing data. Fine for breach of retention: EGP 5m to 10m (Art. 33) | Confirmed text. **Uncertain** whether it is applied to app publishers or only to telecom operators and ISPs | S9 Arts. 2, 33 |
| Art. 25: publishing images that violate privacy without consent is an offence. Art. 26: processing someone's data to link it to content contrary to public morals | Confirmed | S9 |

The 180-day duty conflicts with PDPL minimisation and with the app's design (no access logs kept
beyond Google's defaults). Counsel must say whether it applies.

### 2.5 Other

- Constitution Art. 53 prohibits discrimination on the basis of sex. Whether it reaches a private
  women-only service is **Uncertain**. Women-only gyms are common in Egypt.
- An ID card image also shows religion and address. The app does not store these, but they are read
  in memory. Counsel should say whether that is sensitive data processing in its own right.

---

## 3. Store requirements the documents must support

| Requirement | Status | Source |
|---|---|---|
| Play: privacy policy linked in Play Console **and** in the app; public, non-geofenced, not a PDF; must give developer information and a privacy contact, data types, sharing, security, and retention and deletion | Confirmed | S13 |
| Play: prominent in-app disclosure plus affirmative consent before collecting personal and sensitive data, "within the app itself", not only in a policy | Confirmed | S13 |
| Play Data safety: "collection" means data leaving the device; service providers acting on your instructions are not "sharing"; ephemeral in-memory processing is exempt | Confirmed | S14 |
| Play: in-app account deletion **and** a web deletion URL; must delete associated data; deactivation does not count; retained data must be disclosed | Confirmed | S15 |
| Play: Health apps declaration is mandatory for all apps (Activity and fitness, Nutrition and weight, Period tracking). Non-medical-device health apps must say in the store description that the app is "not a medical device and does not diagnose, treat, cure, or prevent any medical condition" | Confirmed | S16, S17 |
| Play: target age group declaration | Confirmed | S18 |
| Apple 5.1.1(i): privacy policy link in App Store Connect and in the app; what is collected, how, all uses; third parties give equal protection; retention and deletion; how to revoke consent | Confirmed | S19 |
| Apple 5.1.1(ii): consent, and an easy way to withdraw it | Confirmed | S19 |
| Apple 5.1.1(v): personal information may be required only if directly relevant to core functionality. **If the app supports account creation it must offer account deletion within the app** | Confirmed | S19, S20 |
| Apple 5.1.1(ix): apps in healthcare or that require sensitive information "should be submitted by a legal entity ... and not by an individual developer" | Confirmed. **A real review risk for an individual publisher** | S19 |
| Apple 5.1.2(vi): face data from camera APIs may not be used for marketing or data mining | Confirmed | S19 |
| Apple 5.1.3: health data not for advertising; disclose the specific health data; not stored in iCloud | Confirmed | S19 |
| Apple 1.4.1: remind users to check with a doctor | Confirmed | S19 |
| Apple App Privacy labels: data sent and immediately discarded need not be disclosed; anything derived and sent off device (the ID hash, the result) must be. Pregnancy and childbirth are "Sensitive Info" | Confirmed | S21 |
| Apple custom EULA minimum terms (acknowledgement, scope, support, warranty, product claims, IP, legal compliance, developer name and address, third-party terms, Apple as third-party beneficiary). Without a custom EULA, Apple's standard EULA applies | Confirmed | S22, S23 |
| Apple 2.1: a working demo account for review. A reviewer cannot pass a women-only ID check | Confirmed | S19 |
| Apple age ratings now include 13+, 16+, 18+, and a developer may set a higher rating than computed to match its own minimum age | Confirmed | S24 |

---

## 4. Gaps, by document

Severity:
- **Blocks launch**: launching with this unresolved risks rejection by a store or a clear breach of a
  confirmed legal requirement.
- **Should fix before launch**: real exposure or inaccuracy, but not an automatic rejection.
- **Fine to fix later**: housekeeping, or only needed when a future feature ships.

Replacement wording for every row is in the proposed files, at the section given in the last column.

### 4.1 Privacy Policy (`privacy-policy.md`)

| # | Section | Problem | Severity | Basis | Fix (section in `privacy-policy.proposed.md`) |
|---|---|---|---|---|---|
| P1 | Short version, A1 to A5, A7, A9, changes table | States the app has no server, no account, no network library, no internet permission, no camera, collects nothing, and that the store answer is "Data Not Collected". All false for the launch build | **Blocks launch** | Play User Data policy (accurate disclosure) S13; Apple 5.1.1(i) S19; PDPL Art. 2 rights depend on accurate notice | Whole document replaced. Short version |
| P2 | Section 1 | Names a "registered legal entity" and commercial register. The publisher is an individual, Mahmoud Reda. Rahma Mohsen is not mentioned, which is fine, but nothing stops a reader assuming she holds the data | **Blocks launch** | Play requires developer information S13; Apple 5.1.1(i); Apple custom EULA term 8 S23; PDPL controller transparency | §1, names Mahmoud Reda as controller and states Rahma Mohsen is not the controller |
| P3 | Part B, B1 and B2 | Verification is described as future. Missing: Cloud Vision EU endpoint, self-hosted face match, liveness challenge, HMAC with pepper, install-id hash, failure counters, scores kept in flag records, the consent record, governorate counters, ML Kit on-device. Includes "the first name you type" and "the provider's reference" which this build does not collect | **Blocks launch** | Apple 5.1.1(i) "all uses"; Play S13; PDPL Art. 12 and ER Art. 14 (purpose and necessity) | §3.2, §3.4 |
| P4 | B4 | Processor table is all placeholders and says "Today this table is empty in practice" | **Blocks launch** | Apple 5.1.1(i) third parties; Play S13; PDPL Art. 14 | §5, names Firebase Auth (US), Firestore, Functions, Secret Manager, Storage (Frankfurt; content library US), Cloud Vision (EU), App Check, ML Kit, the video call service |
| P5 | B4 transfers paragraph | No basis for transfers outside Egypt. The brief and the policy imply Germany only; Firebase Auth processes the phone number in the US | **Blocks launch** (legal, counsel to confirm timing) | PDPL Art. 14; ER Art. 16(2) consent and 16(4) named countries; ER Art. 26 S2; Firebase privacy page S10 | §6, plus an in-app transfer consent (see O4) |
| P6 | B3 health row | Lawful basis for health data is "your explicit consent, given by entering it". Typing data is not explicit written consent, and the app has **no health data consent screen** before the first sync uploads her history | **Blocks launch** | PDPL Art. 12; ER Art. 14(2), 14(7); ER Art. 2(3) PDPC approval of consent mechanism; Play prominent disclosure S13; Apple 5.1.1(ii) | §3.3 with a counsel marker; app needs a consent screen (O4) |
| P7 | B5 and B6 | Retention leaves verification results, scores, flags, fraud signals and refused applicants unstated. B6 frames the ID hash as kept "closed" after every deletion, and the code (manifest row 23) does this, while `VERIFICATION_SPEC.md` says delete unless banned. Users who delete can never rejoin, and the policy does not say so plainly | **Blocks launch** | Play account deletion: retained data must be disclosed S15; Apple 5.1.1(i) retention S19; ER Art. 14(3) necessity | §4, §4.1 (two options for counsel), §4.2 |
| P8 | A5 and B6 | Deletion: says "there is nothing on our side to delete". The launch build has server data and no server deletion (see O1) | **Blocks launch** | Apple 5.1.1(v) and deletion guidance S19, S20; Play S15; PDPL Art. 2 | §7. The text describes what the app must do; the code must catch up |
| P9 | B6 | Deletion URL is a placeholder, and `LegalLinks.deleteAccount` is empty | **Blocks launch** (Play) | Play S15 | §7, `[OWNER]` marker |
| P10 | All | The policy is not reachable from the app: every `LegalLinks` URL is an empty string | **Blocks launch** | Play S13; Apple 5.1.1(i) | Owner action, not wording |
| P11 | All | English only | **Blocks launch** (my reading; counsel to confirm whether CPL applies to a free app) | CPL Art. 5 Arabic requirement S5; consent must be informed (PDPL Art. 12) for an Arabic-speaking audience | Publish an Arabic version; counsel decides which prevails |
| P12 | A8, B8 | Minimum age "16 or 18, set by counsel". The code enforces 18 (`MIN_AGE = 18`), and `appstore-listing.md` argues against an 18+ rating | **Should fix before launch** | ER Art. 15 (under-18 needs guardian consent) S2; Apple age rating S24; Play target audience S18 | §2: 18 or over, and declare 18+ in both stores |
| P13 | B9 | Response time is a placeholder | **Should fix before launch** | PDPL Art. 32: six working days S1 | §8 |
| P14 | Not present | No breach notification commitment | **Should fix before launch** | ER Art. 5: 72 hours to the Center, 3 business days to the data subject S2 | §9 |
| P15 | Section 1 table | DPO row and PDPC registration row are placeholders | **Should fix before launch** | PDPL Art. 8; ER Art. 38 (individual permit holder is the DPO) S2 | §1 |
| P16 | B2 niqab paragraph | Says "only a woman reviews it, and the recording is not kept" but does not name the video call service, which processes her face and voice. Also asserts partner gyms; the app claims "12 partner gyms in Cairo, Giza and Alexandria", which I could not verify | **Should fix before launch** | Apple 5.1.1(i) third parties; Apple 2.3 accurate metadata; PDPL transparency | §3.2, `[OWNER]` markers |
| P17 | A9 | No way to get a copy of her data (export not built). Access is a PDPL right | **Should fix before launch** | PDPL Art. 2, Art. 32 | §8, copy by email on request |
| P18 | Not present | ML Kit telemetry undisclosed | **Should fix before launch** | ML Kit data disclosure S12; Play Data safety S14 | §3.4 |
| P19 | B1 point 3, B2 health row | "Your cycle data never goes to analytics" is true and should stay, but Apple also requires that health data is not used for advertising or data mining, and that face data is not used for marketing | **Should fix before launch** | Apple 5.1.3, 5.1.2(vi) S19 | Short version, §3.3 |
| P20 | B7 | Says the hash is "one-way" and the scramble "cannot be turned back" (also in the consent screen). With a leaked pepper the 14-digit space falls in under a minute, per the code's own note | **Fine to fix later** (wording) | Accuracy | §3.2 describes it as a keyed code with the key held separately |
| P21 | B2 user content, purchases, safety rows; B7 progress photos | Community, coaching, payments and progress photos are not in this build | **Fine to fix later** (remove now to avoid confusion) | Accuracy | §10 says they are not in this version |
| P22 | B9 | PDPC complaint channel placeholder | **Fine to fix later** | PDPL Art. 33 | §8, `[COUNSEL]` marker. The portal is at portal.pdpc.gov.eg (S4, uncertain whether live) |
| P23 | Header | Effective date placeholder | **Blocks launch** (trivial) | Play S13 | Header |

### 4.2 Terms of Use (`terms.md`)

| # | Section | Problem | Severity | Basis | Fix (section in `terms.proposed.md`) |
|---|---|---|---|---|---|
| T1 | 2, 6, 8, 10 | "This version has no account", "nothing for us to lose", "we do not have a copy of it". False for the launch build | **Blocks launch** | Accuracy; CPL Art. 28 cannot be relied on to excuse misdescription | §2, §4, §8 |
| T2 | 1, 17 | Counterparty is a "company" with a commercial register. The publisher is an individual | **Blocks launch** | Apple custom EULA term 8 (name and address) S23; CPL Art. 5 supplier details S5; Cybercrime Law Art. 2 (publish name and address) S9 | §1, §16 |
| T3 | 3 | Eligibility unresolved ("16 or 18"), and says "the app does not check". The launch build checks sex and age 18+ | **Blocks launch** | Consistency with code; ER Art. 15 | §3 |
| T4 | 1 | Acceptance by "downloading or using" (browse-wrap). At sign-up the app only says "By joining you agree to the community rules" with no link to the Terms or the Privacy Policy | **Should fix before launch** | Law 15/2004 Arts. 15, 18 S7; Civil Code Arts. 89, 90 (uncertain) S8; ER Art. 2(3) consent mechanism | §1: tap to agree with links shown. App copy change needed on C06 or C10 |
| T5 | 16 | Apple minimum terms left as an owner note | **Should fix before launch** (blocks only if a custom EULA is uploaded) | S22, S23 | §14 contains the minimum terms. Alternatively keep Apple's standard EULA |
| T6 | 4 | Medical disclaimer is good, but lacks the exact Play phrase and Apple's "check with a doctor before making medical decisions". Emergency route is generic | **Should fix before launch** | Play health policy S16; Apple 1.4.1 S19 | §5, adds the phrase and Egypt's ambulance number 123 |
| T7 | 4 owner note | Severe symptom screen cites NHS guidance and its care link is empty (`CareLinks.periodPainGuidance = ''`) | **Should fix before launch** | Apple 1.4.1 accuracy; product safety | Owner and clinical sign-off, not Terms wording |
| T8 | 5 owner note | Allergen data on dishes is not authored | **Should fix before launch** | Product safety; CPL supplier obligations | §6. The underlying data is an owner task |
| T9 | 13 | Liability limited to a figure counsel must set, and broad exclusions | **Should fix before launch** | CPL Art. 28 voids clauses reducing obligations under that law S5 | §10, no cap, explicit carve-out for consumer rights |
| T10 | 15 | Court placeholder; listing countries unresolved | **Should fix before launch** | | §13 |
| T11 | Not present | No suspension or termination rule, no complaints route | **Should fix before launch** | CPL complaint mechanism; fairness | §7, §11, §13 |
| T12 | All | English only | **Blocks launch** (see P11) | CPL Art. 5 S5 | Publish an Arabic version |
| T13 | 14 | "Continuing to use means you accept" for changes | **Fine to fix later** | Fairness; PDPL consent for new purposes | §12 |
| T14 | 12 | Table of future clauses (community, coaching, payments) in a published contract | **Fine to fix later** | Clarity | Removed |
| T15 | 9, 12 | Future paid coaching: needs CPL pre-contract information, a commercial register and tax card, the 14-day withdrawal analysis and VAT | **Fine to fix later** (before any payment) | CPL Arts. 37 to 41 S5 | §2 commits to showing price and terms first |
| T16 | 16 | Font licences not reachable in the app (no `showLicensePage` call) | **Fine to fix later** | SIL OFL 1.1 | §8, `[OWNER]` marker |

### 4.3 `delete-account.md` (the third source document)

| # | Problem | Severity | Basis |
|---|---|---|---|
| D1 | The whole page says there are no accounts and nothing to delete. For the launch build it must describe deleting the account and server data, the web route without the app, the timeline, and what survives (section 7 and 4.1 of the proposed policy give the content) | **Blocks launch** | Play S15; Apple S20 |
| D2 | Not yet published, and its URL is not in `LegalLinks` or Play Console | **Blocks launch** | Play S15 |

I did not write a proposed replacement for this file because it was not in scope; its content should
follow §7 and §4 of `privacy-policy.proposed.md`.

### 4.4 Outside the two documents, but they decide whether the documents can be true

| # | Problem | Severity | Basis |
|---|---|---|---|
| O1 | **No real account deletion.** No `requestAccountDeletion` function, no server purge of `users/{uid}` and its subcollections, `verificationJobs`, `verification_flags`, `verificationLedger`, consents, and no deletion of the Firebase Auth user. In-app "Delete everything" clears only the phone and tells her "There is no server yet" | **Blocks launch** | Apple 5.1.1(v) S19, S20; Play S15; PDPL Art. 2 |
| O2 | **Flag state** in `FeatureFlags.shipped` has sign-up and verification off. Decide the build, then make the documents and store forms match it | **Blocks launch** | Play S14, Apple S21 (forms must match behaviour) |
| O3 | **Store forms and listings** (`play-listing.md`, `appstore-listing.md`) answer "Data Not Collected" and describe no server. `PrivacyInfo.xcprivacy` declares only Device ID. Minimum for the launch build: Phone number, User ID, Health info, Fitness info, Other info (ID hash, verification result), App info and performance and device IDs (ML Kit), all linked to the user, not shared, encrypted in transit, deletion available. Apple: Contact Info (phone), Health and Fitness, Sensitive Info (pregnancy), Identifiers (User ID), Other Data | **Blocks launch** | S14, S21 |
| O4 | **No health data consent and no transfer consent** in the app. Add one screen before the first sync (and before the setup questions that ask about pregnancy, postpartum and injury), with an explicit "I agree", covering health data, the countries, and withdrawal. Record it in `users/{uid}/consents` like the verification consent | **Blocks launch** | PDPL Art. 12, ER Arts. 14, 16(2) S1, S2; Play prominent disclosure S13 |
| O5 | **Misleading in-app copy**: "Checked by a licensed Egyptian provider" (it is a self-hosted check on Google Cloud in Germany, and no provider is licensed); "Your logs, weight and photos stay on this phone"; "There is no server yet, and nothing of yours is held anywhere else"; consent screen "nothing is kept except a one way keyed hash" | **Blocks launch** for the "licensed Egyptian provider" line; **Should fix** for the rest | Apple 2.3 and 5.1.1; Play S13; PDPL transparency |
| O6 | **Individual publisher of a health and sensitive data app** | **Should fix before launch** (review risk, not certain rejection) | Apple 5.1.1(ix) S19 |
| O7 | **App Review access**: the whole app is behind the verification gate. Apple needs a demo account or approved demo mode, and 5.1.1(v) requires the ID collection to be justified as core. Explain it in the review notes | **Should fix before launch** | Apple 2.1, 5.1.1(v) S19 |
| O8 | Play Health apps declaration (Activity and fitness, Nutrition and weight, Period tracking), target audience 18+, and the non-medical-device sentence in the store description | **Blocks launch** (Play) | S16, S17, S18 |
| O9 | **Google Cloud Data Processing Addendum** acceptance for project `own-hub` should be confirmed, since the policy relies on Google as processor | **Should fix before launch** | Apple 5.1.1(i) equal protection; PDPL processor obligations |
| O10 | Firestore TTL policy on `verificationSessions.expiresAt` is a deploy-time setting (`DECISIONS_NEEDED.md` D8). Without it, the "one hour" retention in the policy is untrue | **Should fix before launch** | Accuracy of §4 |

---

## 5. Questions for the Egyptian lawyer

Only counsel can decide these. They are ordered by how much they hold up the launch.

1. **PDPC permit before launch.** The app processes sensitive data (health, cycle, pregnancy, biometric
   face match, national ID) and transfers it to Germany and the US. Can it launch on about 4 October
   2026, inside the grace period that ends around 1 November 2026, or does PDPL Art. 12's licence
   requirement for sensitive data apply now? Should the permit application be filed this week, given
   the 90 business day deemed-rejection rule (ER Art. 26)? Is the PDPC portal accepting applications?
2. **Individual or company.** Can Mahmoud Reda, as an individual, hold a Permit for an ongoing consumer
   app (ER Art. 20 calls Permits "specific and temporary"), or must he form a company and apply for a
   Licence? The same answer affects Apple 5.1.1(ix), which expects a legal entity for health and
   sensitive data apps.
3. **Lawful basis and form of consent for the national ID and the face match.** Is a separate
   in-app screen with "I agree, start the camera", recorded with a version, enough "explicit written
   consent (in paper or electronic form)" under ER Art. 14(2)? Does it need PDPC approval as a consent
   mechanism (ER Art. 2(3)) before use? Is reading the ID card (which also shows religion and address)
   and a biometric match "essential and necessary" (ER Art. 14(3)) for a women-only service, or would
   the PDPC expect a less intrusive route?
4. **Consent for health data.** Same question for training, weight, meals, allergies, cycle and
   pregnancy or postpartum answers. What wording and mechanism should the new consent screen use?
5. **Transfers abroad.** Can the US (Firebase Authentication, phone numbers only) be covered by a
   permit, or must authentication move to a provider in an acceptable country? Is the data subject's
   consent (ER Art. 16(2)) plus a permit sufficient? Does Google need its own Egyptian licence or local
   representative as processor?
6. **What survives deletion.** May the keyed ID hash be kept after a voluntary deletion to stop
   re-registration (Option B in the policy), or only for accounts removed for breaking the rules
   (Option A)? For how long? Same question for refused applications and the deletion proof record.
7. **Retention periods** for verification results and scores, fraud signals, and reviewer access logs.
8. **Cybercrime Law Art. 2.** Does the 180-day log retention duty apply to this app's publisher? If it
   does, how does it fit with PDPL minimisation?
9. **Consumer Protection Law.** Does it apply to a free app published by an individual? Is an Arabic
   version legally required, and which language prevails? What must change before paid coaching or
   subscriptions (commercial register, tax card, VAT, 14-day withdrawal, auto-renewal)?
10. **Electronic acceptance of the Terms.** Is a tap to agree with links shown at sign-up enough, and
    what record of acceptance should be kept?
11. **Liability.** What may lawfully be limited for a free health and fitness app, given CPL Art. 28?
12. **Women-only membership.** Is the women-only rule lawful as described (Constitution Art. 53), and
    what should the short written membership policy say about contested cases?
13. **Minimum age.** Confirm 18 as the minimum (the code enforces it), so the guardian consent rules in
    ER Art. 15 do not arise.
14. **Governing courts and complaint route**: which courts, and the current PDPC and Consumer
    Protection Agency complaint channels to name.

---

## 6. Sources

Egyptian law (unofficial English translations unless stated):

- S1. Law No. 151 of 2020, Personal Data Protection Law:
  https://www.acc.com/sites/default/files/program-materials/upload/Data%20Protection%20Law%20-%20Egypt%20-%20EN%20-%20MBH.PDF
- S2. Executive Regulations, MCIT Decree No. 816 of 2025, Official Gazette issue 244 (A), 1 November 2025:
  https://www.thesedonaconference.org/sites/default/files/meeting_paper/7.4%20Egypt%20Personal%20Data%20Protection%20Law%20-%20Executive%20Regulations.pdf
- S3. Shalakany, "New Executive Regulations for Egypt's Personal Data Protection Law":
  https://shalakany.com/wp-content/uploads/2025/12/New-Executive-Regulations-for-Egypts-Personal-Data-Protection-Law-.pdf
- S4. Mondaq, 14 May 2026, "Egypt Personal Data Protection Law: new compliance developments":
  https://www.mondaq.com/privacy-protection/1786854/egypt-personal-data-protection-law-new-compliance-developments
  and the PDPC portal https://portal.pdpc.gov.eg/
- S5. Law No. 181 of 2018, Consumer Protection Law:
  https://eg.andersen.com/wp-content/uploads/2025/07/Law-No.-181-of-2018.pdf
- S6. Consumer Protection Law Executive Regulations, PM Decree 822 of 2019 (search result only):
  https://site.eastlaws.com/GoogleSearch/Tash?RecID=1937298
- S7. Law No. 15 of 2004, E-Signature Law (ITIDA): https://www.itida.gov.eg/English/Documents/2.pdf
- S8. Docusign, electronic signature legality in Egypt (secondary):
  https://www.docusign.com/products/electronic-signature/legality/egypt
- S9. Law No. 175 of 2018, Anti-Cyber and Information Technology Crimes:
  https://eg.andersen.com/wp-content/uploads/2025/06/Law-No.-175-of-2018-Concerning-Information-Technology-Crimes.pdf
- Constitution of Egypt 2019, Arts. 11, 53: https://www.constituteproject.org/constitution/Egypt_2019

Google and Apple:

- S10. Firebase privacy and data processing ("Firebase Authentication processes data exclusively in the
  United States"): https://firebase.google.com/support/privacy
- S11. Cloud Vision data usage ("processed in memory and not persisted to disk"):
  https://docs.cloud.google.com/vision/docs/data-usage
- S12. ML Kit Android data disclosure: https://developers.google.com/ml-kit/android-data-disclosure
- S13. Play User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- S14. Play Data safety section: https://support.google.com/googleplay/android-developer/answer/10787469
- S15. Play account deletion requirements: https://support.google.com/googleplay/android-developer/answer/13327111
- S16. Play Health Content and Services policy: https://support.google.com/googleplay/android-developer/answer/16679511
- S17. Play Health apps declaration: https://support.google.com/googleplay/android-developer/answer/14738291
- S18. Play target audience and content: https://support.google.com/googleplay/android-developer/answer/9867159
- S19. App Store Review Guidelines (1.4.1, 2.1, 5.1.1, 5.1.2, 5.1.3): https://developer.apple.com/app-store/review/guidelines/
- S20. Apple, offering account deletion in your app: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- S21. Apple App Privacy details: https://developer.apple.com/app-store/app-privacy-details/
- S22. Apple, providing a custom licence agreement:
  https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/
- S23. Apple minimum terms for a developer EULA: https://www.apple.com/legal/internet-services/itunes/appstore/dev/minterms/
- S24. Apple age rating update (13+, 16+, 18+): https://developer.apple.com/news/?id=ks775ehf
