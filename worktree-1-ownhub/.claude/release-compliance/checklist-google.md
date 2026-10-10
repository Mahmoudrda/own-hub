# Own Hub: Google Play requirements checklist (research as of 2026-10-06)

## What blocks submission now (from the code)

These are things the code shows today, not general policy.

1. **The in-app privacy link and the deletion web link are blank.** `app/lib/config/legal_links.dart` has all four URLs set to `''`, and `site/config.json` has `baseUrl: "https://ownhub.example"`. `privacy_view.dart:375` hides the privacy row while the link is empty, so the shipped app has no in-app privacy link. That is a rejection under the User Data policy, and the Data safety deletion URL would also be empty.
2. **The privacy policy still has 7 `[to be completed]` markers.** They are in `site/privacy/index.html`: the PDPC permit, the video-call vendor, transfer countries, the response window and others. `site/delete-account/index.html` has 2. The policy is also marked "Draft pending review by a licensed Egyptian lawyer".
3. **The app has no "not a medical device" disclaimer anywhere.** It is in neither `app_en.arb` nor the privacy page; only the terms page has it. Google's Health policy requires it in the store description, plus a "consult a healthcare professional" reminder.
4. **Reviewers have no way in.** A Play reviewer has no Egyptian ID, may be a man, and is probably outside Egypt. The app needs a working demo account: a Firebase test phone number with a fixed code, plus a server-side account that is already verified. I found no reviewer or demo path in `functions/identity`. The implementation report also says the C12 reviewer button was not built, though that is the woman-reviewer fallback, not a store demo account.
5. **The account type is a risk.** If Mahmoud's account is personal, he needs a closed test with 12 testers for 14 days before he can apply for production. Declaring any **Medical** health category (for example "Reproductive and Sexual Health" for pregnancy and postpartum) may also trigger the rule that health apps "such as Medical apps" need an **organisation** account with a D-U-N-S number.
6. **The Data safety draft has gaps.** `app/android/play-data-safety.txt` leaves out age and sex derived from the ID, and anything analytics sends if a real sink replaces `DebugPrintAnalyticsSink`.

**Already compliant:**
- targetSdk and compileSdk are 36.
- The camera is the only permission requested. Media, storage, audio and c2dm permissions are removed, so no Photo & Video declaration is needed.
- The in-app delete flow exists (`your_data_sheet.dart`, `app_router.dart:2218`).
- The camera consent screen comes before capture.
- Assistant, payments, community and coachApp are all `false` in `FeatureFlags.shipped`.
- `accountRequired` is `true`.

---

## Requirements

### A. Developer account and release gates

**A1. Testing requirement for new personal accounts**
- **Requirement:** Personal accounts created after 13 Nov 2023 must run a closed test with at least 12 testers opted in continuously for 14 days, then apply for production access. The application form asks about the test, the audience and readiness, and review takes up to about 7 days.
- **Source:** https://support.google.com/googleplay/android-developer/answer/14151465
- **Why it applies:** Mahmoud Reda is the publisher. If he holds a personal account, Production stays locked until this is done.
- **How to check:** Play Console > Dashboard > "Apply for production". Recruit 12 women testers (Egypt, Google accounts) at least 3 weeks before launch. Each tester must get past the women-only check, or use test accounts.
- **Severity:** rejection (Production is blocked)

**A2. Account type: organisation and D-U-N-S**
- **Requirement:** Financial, health ("Health apps, such as Medical apps and Human Subjects Research apps"), VPN and government apps must use an organisation account. Organisation accounts need a free D-U-N-S number and are not subject to A1.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/13634885, https://support.google.com/googleplay/android-developer/answer/10788890
- **Why it applies:** Own Hub is Health & Fitness. Pregnancy and postpartum features may be read as Medical (see C2).
- **How to check:** Keep the Health declaration to the Health & Fitness subcategories, or register a company and get a D-U-N-S number. An organisation account also helps the Egypt PDPL controller position.
- **Severity:** rejection if Medical is declared on a personal account

**A3. Developer identity, contact info and package registration**
- **Requirement:**
  - Verified legal name, address, email and phone.
  - The public developer name may differ from the legal name.
  - All Play packages had to be registered for Android developer verification by 30 Sep 2026. Unregistered apps risk removal.
  - The sideloading-side protection starts in BR, ID, SG and TH, and goes global in 2027.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/10840893, https://support.google.com/googleplay/android-developer/answer/16984799, https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html
- **Why it applies:** It is a new app, `com.ownhub.app`.
- **How to check:**
  - Play Console Home > identity verification is complete, and the package shows as registered.
  - The ID verified must be Mahmoud's.
  - Public developer name: use "Own Hub", not "Rahma Mohsen" (see F2).
- **Severity:** rejection or removal

**A4. Target API level**
- **Requirement:** From 31 Aug 2026, new apps and updates must target API 36.
- **Sources:** https://developer.android.com/google/play/requirements/target-sdk, https://support.google.com/googleplay/android-developer/answer/11926878
- **How to check:** `targetSdk = 36` in `app/android/app/build.gradle.kts`. This is met, and `tool/release_preflight.sh` checks it.
- **Severity:** rejection

**A5. 16 KB page size**
- **Requirement:** From 1 Nov 2025, new apps and updates targeting Android 15+ must support 16 KB page sizes.
- **Sources:** https://developer.android.com/guide/practices/page-sizes, https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html
- **Why it applies:** Flutter, ML Kit face detection and camerax all ship native `.so` files.
- **How to check:** Upload the AAB, then App bundle explorer > "16 KB" compatibility. Alternatively run `zipalign -c -P 16` or the Android Studio APK Analyzer on the release bundle.
- **Severity:** rejection

**A6. App access for reviewers**
- **Requirement:** "Provide an active demo account, login information, and all other resources needed for Google Play to review your app". Use App access > Sign-in details, and the "Any other instructions" field for OTP or multi-factor login.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/9859455, https://support.google.com/googleplay/android-developer/answer/10788890
- **Why it applies:** Login needs phone OTP, then a national ID and a selfie. A reviewer cannot pass that.
- **How to check:**
  - Add a Firebase Auth test phone number (+20…) with a fixed 6-digit code.
  - Pre-seed that user in Firestore as `verified`, server-side, so ID and selfie are skipped. Keep App Check working on reviewer devices.
  - Write instructions in EN: what the ID gate is and why the reviewer is let through. Optionally attach a screen recording of the real ID and selfie flow.
  - No reviewer path exists in `functions/identity` today.
- **Severity:** rejection ("unable to access app")

**A7. Content rating (IARC)**
- **Requirement:** Every app must complete the questionnaire. Unrated apps are removed, and the July 2026 update says unrated apps are no longer permitted.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/9898843, https://support.google.com/googleplay/android-developer/answer/9859655, https://support.google.com/googleplay/android-developer/answer/17134731
- **How to check:** Play Console > App content > Content rating. Answer accurately, with no UGC or chat at launch because community is off. Redo it when community, the assistant or coach chat turns on.
- **Severity:** rejection

**A8. Target audience: 18+ and Restrict Minor Access**
- **Requirement:** Declare the target age groups. Adults-only apps can enable "Restrict Minor Access" so users under 18 cannot find or download the app. No child-appealing listing art.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/9867159, https://support.google.com/googleplay/android-developer/answer/9893335
- **Why it applies:** The policy says 18+, and verification rejects anyone under 18.
- **How to check:** App content > Target audience = 18+ only, so the Families policy does not apply. Turn on Restrict Minor Access.
- **Severity:** rejection if mis-declared, otherwise best practice

### B. User data

**B1. Privacy policy**
- **Requirement:**
  - The URL must be in the Play Console field and also reachable in the app.
  - It must be public, not geofenced, and not a PDF.
  - It must name the developer and a privacy contact, cover all data types, secure handling, and retention and deletion.
  - "The entity named in the app's Google Play store listing must appear in the privacy policy."
- **Source:** https://support.google.com/googleplay/android-developer/answer/10144311
- **How to check:**
  - Fill in `LegalLinks.privacyPolicy` and the real `baseUrl`, and deploy the site.
  - Clear the 7 TODO markers in `site/privacy/index.html`.
  - The policy must name whatever the public developer name is, alongside Mahmoud Reda.
  - Run `RELEASE_BASE_URL=… bash tool/release_preflight.sh`.
- **Severity:** rejection

**B2. Prominent disclosure and consent**
- **Requirement:** For data she may not expect to be collected:
  - Show the disclosure in-app, during normal use, before collection.
  - Say what data is collected and how it is used. It cannot live only in the privacy policy.
  - Require affirmative action. Navigating away or auto-dismissal does not count as consent.
- **Source:** https://support.google.com/googleplay/android-developer/answer/10144311
- **Why it applies:**
  - ID and selfie go to Google Cloud.
  - The ID number is hashed.
  - Sex and age are derived from the ID.
  - Health backup is opt-in.
  - Crashlytics.
- **How to check:**
  - The C09b "I agree, start the camera" screen has the five disclosure bullets before the camera opens. Check it is not skippable in the new value-first flow, and that the consent comes before any upload.
  - The health-backup consent sheet is separate.
  - Never treat "Continue" on O03 or O05 as consent.
- **Severity:** rejection

**B3. Data safety form**
- **Requirement:** Must be accurate and complete, including SDK collection (Firebase). Service providers do not count as sharing. Data processed ephemerally may be excluded. It also has the deletion questions and URL.
- **Source:** https://support.google.com/googleplay/android-developer/answer/10787469
- **How to check:** Use `app/android/play-data-safety.txt` and add:
  - Personal info > Other info for age and sex derived from the ID, if stored as verification results.
  - Name, if C-flow collects a display name.
  - App activity / analytics, if a non-debug analytics sink ships.
  - In-app messages, later, when coach chat or community turns on.

  Also:
  - Cross-check it against the privacy policy and the iOS `PrivacyInfo.xcprivacy`.
  - Photos "processed ephemerally" is only true if Cloud Function memory is the only place the images exist. Confirm Cloud Logging never records the image payloads.
- **Severity:** rejection, or enforcement on a mismatch

**B4. Account deletion in-app and via a web link**
- **Requirement:**
  - A readily discoverable in-app path.
  - A web page where users can request deletion without the app. It must load without error and feature deletion prominently.
  - Delete all associated data. Disclose what is kept and why.
  - Deactivating or freezing an account does not count.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/13327111, https://support.google.com/googleplay/android-developer/answer/10144311
- **How to check:**
  - The in-app flow is there.
  - `site/delete-account` and `site/ar/delete-account` exist but the URL is not set. Fill `LegalLinks.deleteAccount`, deploy, and put the URL in Data safety > Data deletion.
  - Clear the 2 TODOs on that page.
  - The "what is kept" section (keyed ID hash, for example) must also appear in the privacy policy retention section.
- **Severity:** rejection

**B5. Sensitive data handling**
- **Requirement:** HTTPS, and never publicly disclose government ID numbers. July 2026 clarification: third-party AI integrations are covered by the User Data policy, including limited use, disclosure and consent.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/10144311, https://support.google.com/googleplay/android-developer/answer/17134731
- **How to check:**
  - The ID number is stored only as an HMAC (Secret Manager key).
  - Firestore rules in `firebase/` deny client reads of verification records.
  - Image data never reaches Crashlytics or logs.
- **Severity:** legal liability, or rejection

**B6. Permissions: camera only**
- **Requirement:** Request only the permissions you need. `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` need a declaration unless the system photo picker is used.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/16558241, https://support.google.com/googleplay/android-developer/answer/14115180
- **How to check:**
  - The manifest has CAMERA only, with `tools:node="remove"` on the others.
  - Verify the merged manifest of the release AAB: `bundletool dump manifest`.
  - Camera is not a restricted permission and needs no declaration.
- **Severity:** rejection if extra permissions leak in

**B7. SMS and call-log verification**
- **Requirement:** OTP must not use `READ_SMS` or `READ_CALL_LOG`. Use the SMS Retriever or Digital Credentials API (July 2026).
- **Source:** https://support.google.com/googleplay/android-developer/answer/17134731
- **How to check:** `app_code_field.dart` already avoids `READ_SMS`. Firebase phone auth uses the Retriever.
- **Severity:** rejection if it regresses

### C. Health

**C1. Health apps declaration**
- **Requirement:** Every app must complete Policy > App content > Health apps, including apps on closed tracks.
- **Source:** https://support.google.com/googleplay/android-developer/answer/14738291
- **How to check:** Declare Activity and Fitness, Nutrition and Weight Management, and Period Tracking. Decide on pregnancy and postpartum (see C2). Health Connect is not used: no dependency and no permission.
- **Severity:** rejection

**C2. Medical category and account type risk**
- **Requirement:** Reproductive and Sexual Health sits under **Medical** in the declaration, and Medical apps need an organisation account (A2).
- **Sources:** https://support.google.com/googleplay/android-developer/answer/14738291, https://support.google.com/googleplay/android-developer/answer/13634885
- **Why it applies:** Life stage covers pregnancy and postpartum training plans.
- **How to check:** Position these as fitness adaptations ("with your doctor's clearance"), not reproductive-health management. If unsure, publish from an organisation account.
- **Severity:** rejection

**C3. Disclaimer**
- **Requirement:** Non-regulated health apps must say in the app description that the app is "not a medical device and does not diagnose, treat, cure, or prevent any medical condition", and remind users to consult a healthcare professional.
- **Source:** https://support.google.com/googleplay/android-developer/answer/16679511
- **How to check:**
  - Add it to the EN and AR store descriptions.
  - Add it in-app as best practice, for example on the cycle and life-stage screens and in About.
  - It is currently missing from `app_en.arb`.
- **Severity:** rejection

**C4. Health misinformation and misleading claims**
- **Requirement:** No claims that contradict medical consensus or could cause harm.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/16679511, https://support.google.com/googleplay/android-developer/answer/9888689
- **How to check:**
  - Recipe and workout copy should make no fat-loss or cycle-syncing outcome promises.
  - The "images never stored" claim must be literally true, including Cloud Vision request logging. Vision does not retain images, but check the function logs.
- **Severity:** rejection

**C5. Health data use limits**
- **Requirement:** Sensitive health data must not be used for employment or insurance decisions, or for unauthorised social sharing (April 2026 reminder). Do not collect health data that is not essential.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/16926792, https://support.google.com/googleplay/android-developer/answer/16679511
- **How to check:** The G9 test (`cycle_no_analytics_call_sites_test.dart`) shows no cycle data reaches analytics. Keep health backup opt-in.
- **Severity:** legal liability

### D. Features that are off at launch (needed before turning them on)

**D1. AI-generated content (assistant, Gemini Flash)**
- **Requirement:**
  - Chatbot-style generative apps must include "in-app user reporting or flagging features ... without needing to exit the app".
  - They must prevent harmful output, including self-harm and dangerous activity.
  - User Data rules apply to third-party AI, with disclosure and consent before sending her data to Gemini.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/13985936, https://support.google.com/googleplay/android-developer/answer/14094294, https://support.google.com/googleplay/android-developer/answer/16353813, https://support.google.com/googleplay/android-developer/answer/17134731
- **How to check:**
  - `Feature.assistant: false`, so not required for v1.
  - Before enabling it, add a flag button on answers and drafts (`ask_view.dart`, `plan_draft_view.dart`).
  - Add an AI data disclosure and update Data safety.
  - Keep `safety_classifier.dart` and medical refusals.
- **Severity:** rejection when enabled

**D2. User-generated content (community and coach chat)**
- **Requirement:**
  - Users accept terms before posting.
  - Define objectionable content.
  - Have in-app report and block, plus ongoing moderation.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/9876937, https://support.google.com/googleplay/android-developer/answer/12923286
- **How to check:**
  - community and coachApp are `false` for v1.
  - `report_copy.dart` and `safety_sheet_view.dart` exist for later.
  - Coach portfolios (public profiles) are UGC too.
  - Redo IARC and Data safety (in-app messages, photos and videos) at that point.
- **Severity:** rejection when enabled

**D3. Payments (coaching and marketplace)**
- **Requirement:**
  - Digital content and subscriptions, explicitly including fitness, must use Google Play Billing.
  - Physical services such as gym memberships are exempt.
  - Alternative billing exists only in eligible countries through enrolment. I could not confirm that Egypt is eligible.
- **Source:** https://support.google.com/googleplay/android-developer/answer/9858738
- **How to check:**
  - payments, marketplace and recipeTiering are `false`.
  - Coach plans delivered in-app need Play Billing.
  - In-person coaching may be exempt.
  - No links or UI steering users to off-Play payment for digital content.
- **Severity:** rejection when enabled

### E. Store listing

**E1. Metadata**
- **Requirement:**
  - Title 30 characters or fewer.
  - No emoji or repeated symbols in the title, icon or developer name.
  - No "#1", "best" or award-style performance claims.
  - No unattributed testimonials.
  - Accurate description, no keyword stuffing.
- **Source:** https://support.google.com/googleplay/android-developer/answer/9898842
- **How to check:**
  - EN and AR listings, title "Own Hub". Add the disclaimer (C3) and the women-only and 18+ statement.
  - Screenshots must show real UI with flags as shipped, so no assistant, community or coach screens.
- **Severity:** rejection

**E2. Store listing best practices**
- **Requirement:** Localised listings, and graphics that match the app.
- **Source:** https://support.google.com/googleplay/android-developer/answer/13393723
- **How to check:** Add an AR (MSA) listing next to the EN one.
- **Severity:** best practice

### F. Identity and naming

**F1. Impersonation**
- **Requirement:** Do not imply a relationship or authorisation that does not exist through the title, developer name, icon or listing.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/9888374, https://support.google.com/googleplay/android-developer/answer/16341334
- **Why it applies:** Rahma Mohsen is the brand face, while Mahmoud holds the account.
- **How to check:** Get Rahma's written permission to use her name and image. Keep the developer name "Own Hub", and keep the privacy and terms "who we are" section as Mahmoud Reda (publisher) with Rahma Mohsen (founder and brand). Never list Rahma as the developer or legal entity.
- **Severity:** rejection, or legal liability

**F2. Developer name in the privacy policy**
- **Requirement:** The entity named on the listing must appear in the privacy policy.
- **Source:** https://support.google.com/googleplay/android-developer/answer/10144311
- **How to check:** The public developer name must match a name in `site/privacy` (EN and AR).
- **Severity:** rejection

### G. Women-only gate

**G1. Gender-restricted access**
- **Requirement:** I found no Play policy that bans or explicitly allows women-only apps. What does apply:
  - The Hate speech / Inappropriate Content policy bars content inciting hatred based on gender or gender identity.
  - Misrepresentation requires the restriction to be disclosed before download.
- **Sources:** https://support.google.com/googleplay/android-developer/answer/9878810, https://support.google.com/googleplay/android-developer/answer/9888689
- **How to check:**
  - The listing first line says the app is for women in Egypt aged 18+ and that you must verify with a national ID.
  - Rejection copy is neutral and does not demean anyone.
  - The A6 demo account lets a reviewer of any gender in.
  - Keep the woman-reviewer and niqab path.
- **Severity:** rejection if undisclosed (the listing must state the restriction), otherwise best practice

---

## What to do, in order

1. Decide the account type: personal with a 12-tester closed test, or organisation with D-U-N-S.
2. Buy and deploy the domain, then fill in `LegalLinks` and `baseUrl`.
3. Clear the privacy and delete-page TODOs.
4. Build the reviewer demo account (test phone number and a server-side pre-verified user).
5. Add the medical disclaimer to the listing and the app.
6. Update the Data safety draft.
7. Check 16 KB page size support on the AAB.
8. Fill in the Health declaration (Health & Fitness only), IARC, target audience 18+ with Restrict Minor Access, and the EN and AR listings.

**Not verified:** whether Egypt is eligible for alternative or user-choice billing, and whether the pregnancy and postpartum features would actually be classed as "Reproductive and Sexual Health". Google's pages don't settle either, so check both in Play Console when you fill in the forms.

**Files referenced:**
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/config/legal_links.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/config.json`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/privacy/index.html`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/delete-account/index.html`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/android/play-data-safety.txt`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/android/app/src/main/AndroidManifest.xml`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/tool/release_preflight.sh`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/domain/flags/feature_flags.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/assistant/domain/assistant_provider.dart`