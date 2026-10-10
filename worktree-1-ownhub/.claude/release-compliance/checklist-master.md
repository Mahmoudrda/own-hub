# Own Hub master compliance checklist

Built 6 Oct 2026 from the Apple, Google Play and Egyptian law research reports, with key facts re-checked in the worktree. Worktree: `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding`. In the checks below, `$W` stands for that path. The onboarding changes on branch `onboarding/2026-10-06` are uncommitted, so every in-app check applies to that uncommitted flow.

**Severity.** **R** means a store can reject or remove the app. **L** means legal liability (fines, prison, civil claims). **BP** means best practice.

**Status (6 Oct).** **OPEN** means not done. **PARTIAL** means some parts exist. **MET** means it is in place now and needs to be kept that way.

**IDs.**
- OWN items are the owner's own requirements. Each one points to the APL, GPL and LAW items behind it.
- When Apple and Google share a requirement, it appears once, under APL, with both sources.
- **[LATER]** items only apply when a feature that is off at launch gets turned on: community, coachApp, assistant, payments or marketplace.

**What I re-checked in the worktree today:**
- `legal_links.dart` still has 4 empty URLs.
- There are 16 `[to be completed]` hits under `site/`:
  - privacy 7, terms 2, delete-account 2, `config.json` 1, `_build/build.py` 4.
  - I could not confirm whether the AR pages carry them as well.
- No Terms or Privacy acceptance is recorded anywhere: grepping `app/lib` and `functions` for termsVersion, privacyVersion or acceptTerms finds nothing.
- Data export is not built:
  - `your_data_sheet.dart:27` says "there is no export yet".
  - `site/index.html:127` says the same.
- The privacy and terms pages have no statement about AI or AI training.
- Crashlytics turns on at boot in release builds (`firebase_boot.dart:150`), before any consent.
- The C12 reviewer button was not built (implementation report, line 3). A reviewer is offered from C10b on the third failed try. The video-call vendor has not been chosen.

---

## OWN: the owner's requirements

### OWN-01 · Privacy policy in EN and AR, true to what the app does · R + L · OPEN
- **Sources:**
  - Apple 5.1.1(i): https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage
  - Google User Data: https://support.google.com/googleplay/android-developer/answer/10144311
  - PDPL Law 151/2020 Arts. 2, 3, 14 and 15: https://eg.andersen.com/wp-content/uploads/2025/06/Law-No.-151-OF-2020.pdf
  - Consumer Law 181/2018 Art. 5 (Arabic): https://eg.andersen.com/wp-content/uploads/2025/07/Law-No.-181-of-2018.pdf
- **What it requires:**
  - A public HTML page, not geofenced and not a PDF.
  - It is linked in App Store Connect, in Play Console and inside the app.
  - It names the developer entity shown on both store listings and gives a privacy contact.
  - It covers every data type, purpose, third party, transfer country, retention period, deletion, consent withdrawal and the reply window for data requests.
  - The EN and AR versions say the same thing, and the Arabic text prevails.
- **Known problems:**
  - Seven placeholders: PDPC permit, transfer countries and mechanism, video vendor and its region, reply window, regulator contact.
  - §10 says "No access to … microphone", but the woman-reviewer path is a video call (LAW I-01).
  - There is no AI section (see OWN-07).
  - The keyed ID hash is described as if it were not personal data (LAW I-02).
  - The waitlist retention period conflicts with the 3-year rule for keeping marketing consent records (LAW-09).
- **How an auditor checks:**
  1. `grep -rn "to be completed" $W/site` returns nothing, including `site/ar/`.
  2. `site/config.json` `baseUrl` is not `https://ownhub.example`.
  3. `app/lib/config/legal_links.dart`: `privacyPolicy` is a real https URL.
  4. On a release build, the policy opens from the C09b consent screen, the privacy centre (`privacy_view.dart:375` hides the row when the link is empty) and Settings.
  5. Compare each section of `site/privacy/index.html` and `site/ar/privacy/index.html` with:
     - `app/ios/Runner/PrivacyInfo.xcprivacy`
     - `app/android/play-data-safety.txt`
     - `functions/account/deletion_manifest.json`
     - `functions/identity/config.py` (regions, `CONSENT_VERSION`, `HEALTH_CONSENT_VERSION`, `MIN_AGE`)
  6. The developer name on both store listings appears in both language versions of the policy.
  7. App Store Connect > App Privacy > Privacy Policy URL, and Play Console > App content > Privacy policy, are both set to the live URL.
  8. `RELEASE_BASE_URL=<real> bash $W/app/tool/release_preflight.sh` passes.
- **Related:** APL-04, APL-10, GPL-04, LAW-03, LAW-04, LAW-07.

### OWN-02 · Terms of service in EN and AR · L (R if not linked) · PARTIAL
- **Sources:**
  - Apple 1.2 and 5.1.1 (the terms must be reachable in the app).
  - CPL Arts. 5 and 28 (Andersen link above).
  - E-signature Law 15/2004: https://www.wipo.int/wipolex/en/legislation/details/13546
- **What it requires:**
  - Terms v2.0 exists in both languages: `site/terms` and `site/ar/terms`.
  - Two placeholders remain: §13 liability cap and §15 governing court.
  - Add a clause that the Arabic text prevails.
  - Show the publisher's identity, address and registration, or have counsel confirm an individual publisher is exempt (CPL-01).
  - Counsel must confirm §13 survives CPL Art. 28, which voids clauses that reduce the supplier's obligations.
  - Keep §4 ("not medical advice") and §3 (women-only and 18+, sex read from the ID).
  - Coaches are described as independent professionals (§12).
  - The identity rule: Mahmoud Reda is the publisher and data controller, Rahma Mohsen is founder and brand face. The two are never mixed.
- **How an auditor checks:**
  1. `grep -n "to be completed" $W/site/terms/index.html $W/site/ar/terms/index.html` returns nothing.
  2. Read §1, §3, §4, §6, §13, §15 and §17 in both languages.
  3. `legal_links.dart` `terms` is set.
  4. The Terms link opens from the C06 phone screen and from Settings.

### OWN-03 · She accepts the Terms and Privacy Policy in one easy step, and it is recorded · L (R for the link) · OPEN
- **Sources:**
  - Law 15/2004 (above).
  - PDPL Arts. 2, 6 and 15.
  - CMS summary of the Executive Regulations: https://cms.law/en/int/legal-updates/egypt-s-pdpl-executive-regulations-issued-one-year-compliance-countdown-begins
  - Google prominent disclosure (10144311): moving on or auto-dismissing is not consent.
- **Current state:**
  - The C06 phone screen shows only `byJoiningYouAgreeToTheOwn` ("By joining you agree to the Own Hub rules.", `app_en.arb:3173`).
  - That line has no link, no record, and does not mention the US.
  - The phone number reaches Firebase Auth in the US before any consent screen.
  - Terms §1 is browse-wrap ("By downloading or using…"), the weakest form.
- **What it requires:**
  - On C06, before the code is sent: links to the Terms and the Privacy Policy, a line saying the phone number is processed by Google Firebase in the US, and one affirmative button ("Agree and continue").
  - On the server, record `{uid, termsVersion, privacyVersion, locale, appVersion, timestamp}` the same way C09b capture consent is stored.
  - When either document's version goes up, ask again.
  - Keep the sensitive-data consents separate, as the PDPC guidance requires. The one-step acceptance covers the Terms and Privacy only:
    - The ID and biometric consent stays on C09b.
    - The health backup keeps its own opt-in.
- **How an auditor checks:**
  1. `grep -rn "termsVersion\|privacyVersion\|TERMS_VERSION" $W/app/lib $W/functions` finds the client constant, the callable and a Firestore write.
  2. `firebase/firestore.rules` lets clients write that acceptance record but not rewrite it.
  3. On a device, C06 shows both links and the US line, and no SMS is sent before the tap.
  4. The acceptance document exists in Firestore with the correct versions and locale.
  5. A test changes the terms version and confirms she is asked again.
- **Related:** LAW-03 (US transfer consent before transfer).

### OWN-04 · No trackers, analytics or crash reporting before consent where consent is needed · L (R if the labels mismatch) · PARTIAL
- **Sources:**
  - PDPL Arts. 2 and 6.
  - Cybercrime Law 175/2018 Art. 25: https://eg.andersen.com/wp-content/uploads/2025/06/Law-No.-175-of-2018-Concerning-Information-Technology-Crimes.pdf
  - Apple 5.1.1(ii) and ATT: https://developer.apple.com/app-store/user-privacy-and-data-use/
  - Google Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- **Current state:**
  - Crashlytics is turned on in release at boot (`app/lib/app_state/firebase_boot.dart:150`, via `crashCollectionFor(release: kReleaseMode)`), before C06 and before any consent. It sends no user ID or custom keys, but the installation ID is personal data.
  - The analytics debug sink is wired only `if (kDebugMode)` (`app/lib/main.dart:43`).
  - The privacy policy says "No analytics software" (`site/privacy/index.html:409`).
  - There are no ad SDKs, `NSPrivacyTracking` is false, and the site footer claims no cookies or scripts.
- **What it requires:**
  - Either turn Crashlytics on only after the C06 acceptance plus a toggle in the privacy centre, or get written counsel sign-off for a legitimate-interest basis with disclosure. Gating it on consent is the recommended option.
  - An off switch for crash reports in the privacy centre (Apple 5.1.1(ii)).
  - Before any real analytics sink ships: a consent step, a privacy update (§10), the Product Interaction label on Apple, and App activity on Google.
  - Cycle and health fields never reach analytics.
  - App Check is not a tracker, but it is disclosed.
  - No ATT prompt; the tracking answer stays No.
- **How an auditor checks:**
  1. Read `firebase_boot.dart:140-160`. Collection may only be enabled after a stored consent flag.
  2. The native default is off: `FirebaseCrashlyticsCollectionEnabled` false in `ios/Runner/Info.plist`, and the `firebase_crashlytics_collection_enabled` meta-data false in `android/app/src/main/AndroidManifest.xml`.
  3. Run `grep -rn "AnalyticsSink\|kDebugMode" $W/app/lib/main.dart`.
  4. Run the G9 test `cycle_no_analytics_call_sites_test.dart` and an allow-list test on `analytics_gateway.dart`.
  5. Check `site/_headers` CSP. Opening the site in a browser makes no third-party requests and sets no cookies.
  6. Use a proxy on a fresh install with a release build: there is no `firebase-settings.crashlytics.com` or `crashlyticsreports` traffic before consent.

### OWN-05 · She can export her data · L · OPEN
- **Sources:**
  - PDPL Art. 2 (the right to obtain her data).
  - Baker McKenzie on the reply deadline (6 working days, unconfirmed): https://connectontech.bakermckenzie.com/egypt-important-data-protection-update/
- **Current state:**
  - Not built: `app/lib/features/account/presentation/your_data_sheet.dart:27` says "there is no export yet".
  - `site/index.html:127` admits it.
  - Terms §6 promises a copy by email.
- **What it requires:**
  - An in-app "Download my data" that builds from the same source as deletion (`functions/account/deletion_manifest.json` and `app/lib/features/account/domain/deletion_manifest.dart`). It covers:
    - server data (account, verification outcome, training logs, health backup if she opted in)
    - on-device data (cycle, weight, life stage), exported locally
  - Machine-readable JSON plus a readable summary, in EN and AR.
  - Until it ships, an email request route on `site/support` with the reply window filled in.
  - Counsel to confirm whether an emailed copy satisfies Art. 2 (LAW-04).
- **How an auditor checks:**
  1. Settings > "Download everything, or delete your account" > Download, on a release build.
  2. The file covers every collection in `deletion_manifest.json` plus the local stores.
  3. A test asserts that every manifest entry is in the export.
  4. `site/index.html:127` and Terms §6 are updated to match.

### OWN-06 · She can delete her account and data, in the app and on the web · R + L · PARTIAL
- **Sources:**
  - Apple: https://developer.apple.com/support/offering-account-deletion-in-your-app/
  - Google: https://support.google.com/googleplay/android-developer/answer/13327111
  - PDPL Art. 2.
- **Current state:**
  - The in-app flow exists:
    - `your_data_sheet.dart`
    - `callable_deletion_transport.dart`
    - `functions/account/deletion.py`
    - router at `app_router.dart:2218`
  - The web page exists (`site/delete-account` and `site/ar/delete-account`). It is a mailto request, confirmed by phoning her number.
  - Two placeholders remain, one of them the reply window (line 94).
  - `LegalLinks.deleteAccount` is empty.
  - The ID hash is "closed, not deleted" (line 115). This must be disclosed in privacy retention.
- **How an auditor checks:**
  1. On a release device, delete the account. Then confirm the Auth user, the Firestore documents, any Storage objects, and the health backup are gone, and the NID hash is closed as disclosed.
  2. The screen states how long deletion takes.
  3. `functions/account/deletion.py` covers every entry in `deletion_manifest.json`, and its test passes.
  4. `grep "to be completed" $W/site/delete-account/index.html $W/site/ar/delete-account/index.html` returns nothing.
  5. The deletion page loads without the app.
  6. Play Console > Data safety > Data deletion URL is set.
  7. The retention text matches between the delete page and privacy §6.
  8. **[LATER]** Extend the manifest for community posts, coach plans and portfolios.

### OWN-07 · We do not train AI on her data, and we say so truthfully · L · OPEN (true today, but never stated)
- **Sources:**
  - PDPL Art. 3 (purpose limitation), and the Executive Regulations on AI training (Shalakany): https://shalakany.com/wp-content/uploads/2025/12/New-Executive-Regulations-for-Egypts-Personal-Data-Protection-Law-.pdf
  - Gemini API terms (the free tier uses prompts for improvement, with human review): https://ai.google.dev/gemini-api/terms
  - Vertex AI training restriction and zero data retention: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/vertex-ai-zero-data-retention
  - Apple 5.1.2(i) (third-party AI): https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
  - Google, July 2026 (third-party AI is covered by User Data): https://support.google.com/googleplay/android-developer/answer/17134731
- **Current state:**
  - The privacy and terms pages say nothing about AI.
  - The assistant is off (`Feature.assistant: false`).
  - `AssistantRequest` carries no uid (`app/lib/features/assistant/domain/assistant_provider.dart`).
  - ID images go to Cloud Vision in the EU.
- **What it requires:**
  - A new privacy §3.8 in EN and AR: "We never use your data to train AI, ours or anyone's."
  - Cloud Vision is used only to read the ID card, and under Google Cloud terms it is not used for training. Counsel or the DPA must confirm this.
  - Before the assistant is turned on:
    - Use Vertex AI in europe-west3 on a paid account, with the training restriction and zero data retention (abuse-logging exception requested).
    - Accept the DPA.
    - Add a separate opt-in naming Google, a transfer impact assessment, and an update to the nutrition label and Data safety.
    - Never use a free-tier key.
  - The assistant sees only her question and the catalogue: no name, number, ID, cycle or health data.
- **How an auditor checks:**
  1. `grep -n -i "train\|AI\|الذكاء" $W/site/privacy/index.html $W/site/ar/privacy/index.html` finds the statement.
  2. `grep -rn "uid\|cycle\|health" $W/app/lib/features/assistant/domain/assistant_provider.dart` shows no personal fields in the request.
  3. Cloud console > Vertex AI > data governance settings, and the DPA acceptance evidence, are on file.
  4. The feature flag shows the assistant is off.

### OWN-08 · No claims about things the app does not have (listing, site, in-app copy, screenshots) · R + L · OPEN
- **Sources:**
  - Apple 2.3.1, 2.3.3, 2.3.4, 2.3.7, 2.3.8, 2.3.12 and 1.1.6: https://developer.apple.com/app-store/review/guidelines/#accurate-metadata
  - Apple 2.1(a), no placeholder content: https://developer.apple.com/app-store/review/guidelines/#app-completeness
  - Google metadata: https://support.google.com/googleplay/android-developer/answer/9898842
  - Google misrepresentation: https://support.google.com/googleplay/android-developer/answer/9888689
  - CPL Arts. 1 and 9.
  - Supreme Council for Media Regulation (SCMR) Decision 9/2025: https://www.tamimi.com/news/what-you-need-to-know-about-egypts-new-advertising-rules/
- **Claims to verify against the shipped build:**
  - "Women only".
  - "Photos never stored" (`functions/identity/store.py` stores no images; Cloud Logging must not log payloads).
  - "Or by a woman reviewer on a short video call" (`site/index.html:57`): the vendor isn't chosen and the C12 reviewer button was not built.
  - "No access to microphone" (privacy:410).
  - "No analytics software" (privacy:409).
  - "90 seconds".
  - "Processed in Frankfurt" (the phone number goes to the US).
  - No fat-loss or cycle-syncing outcome promises.
  - Never "accurate" cycle predictions, and never "treats", "cures" or "medically designed".
  - No "#1" or "best", and no unattributed testimonials.
- **Screenshots** show only shipped screens in EN and AR, from a release build with launch flags. There are no community, coach, assistant or payments screens.
- **How an auditor checks:**
  1. Grep for claims across `$W/site/**/*.html`, `$W/app/lib/l10n/app_en.arb` and `app_ar.arb`, the store description drafts and the screenshots.
  2. Map each claim to code (file:line) or delete it.
  3. Run `grep -rn "to be completed" $W/site` and check the Apple 2.1 placeholder scrub.
  4. App Store Connect and Play Console listing text read against this list.
  5. Rahma's social posts are checked against the same claim list (LAW-12).

### OWN-09 · Protection from being sued (legal shield) · L · OPEN
This is an umbrella item. It closes only when every LAW item marked L is closed or signed off by a licensed Egyptian lawyer (LAW-20), and these are in place:
- the PDPC licence or permit filings (LAW-01, LAW-02, LAW-03)
- the women-only legal basis and wording (LAW-14)
- health disclaimers (APL-12)
- Rahma's image and content licence (APL-11)
- a decision on whether to form a legal entity (APL-01, LAW-06)
- the breach runbook (LAW-05)
- processor contracts (LAW-08)
- liability limits that survive CPL Art. 28 (OWN-02)
- the coach agreement (LAW-15)

**How an auditor checks:** a signed counsel memo covering the LAW-20 list is filed, and every L item below shows MET or SIGNED-OFF.

### OWN-10 · Google Play and App Store compliance · R · OPEN
Umbrella item: every APL and GPL item marked R is MET. Gate order:
1. APL-01 (entity)
2. OWN-01, OWN-02 and OWN-06 (links and site)
3. APL-03 (reviewer access)
4. APL-04 and GPL-04 (privacy declarations)
5. APL-08 (age rating) and GPL-06 (target audience)
6. GPL-08 (health declaration)
7. APL-12 (disclaimer)
8. LAW-14 (Egypt-only storefront)
9. APL-14 and APL-15 (store business declarations)
10. GPL-03 (16 KB)
11. OWN-08 (listing)

### OWN-11 · Release readiness · R · OPEN
**How an auditor checks:**
1. The onboarding branch `onboarding/2026-10-06` has been reviewed and committed. It is uncommitted today.
2. `flutter analyze` is clean and `flutter test` is green. The known Tuesday-date failure in `test/qa/round1/r1_defects_test.dart` R1-12a is fixed or explained.
3. `RELEASE_BASE_URL=<real domain> bash $W/app/tool/release_preflight.sh` passes with no "na" rows.
4. `grep -rn "to be completed" $W/site` is empty. `config.json` `baseUrl` is real. The site is deployed.
5. `LegalLinks.allSet` is true; a release-build assertion is recommended.
6. Release builds succeed on both platforms (`app/tool/build_release.sh`), with Xcode 26 (APL-07) and an AAB that passes 16 KB (GPL-03).
7. The reviewer account works on a clean device on both stores (APL-03).
8. Every OWN item is MET, the OWN-09 counsel sign-off is on file, and the PDPC filing has been made before 31 Oct / 1 Nov 2026 (LAW-01).
9. A TestFlight upload produces no ITMS-91053 or 91055 emails. If the Play account is personal, the closed test is complete (GPL-01).

---

## APL: Apple, and requirements shared by both stores

**APL-01 · Account held by a legal entity, not an individual (both stores) · R + L · OPEN**
- **Sources:**
  - Apple 5.1.1(ix): https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage
  - Google organisation accounts: https://support.google.com/googleplay/android-developer/answer/13634885
  - Google account information: https://support.google.com/googleplay/android-developer/answer/10788890
  - PDPL Art. 8 (DPO for a legal entity).
- **Why:** the app processes the national ID, the selfie face match, and pregnancy and cycle data.
- **Check:**
  - Apple Developer > Membership shows Organization, with a D-U-N-S number.
  - Play Console > Account details shows Organisation.
  - The seller and developer name is the Mahmoud Reda entity, or the "Own Hub" trade name. Rahma Mohsen never appears.
  - If the accounts stay personal: expect a 5.1.1(ix) rejection, and see GPL-01.

**APL-02 · Support URL with real contact details (both stores) · R · OPEN**
- **Sources:** https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information and Apple 1.2.
- **Status:** `LegalLinks.support` is empty, so `app_router.dart:2274` drops "talk to a human". The current contact is a personal Gmail address.
- **Check:**
  - `site/support` and `site/ar/support` show an email, plus the phone and address where CPL-01 requires them.
  - The URL is set in App Store Connect and in Play Console > Store settings > contact details.
  - `legal_links.dart` `support` is set.

**APL-03 · Reviewer demo account, live backend, Review Notes (both stores) · R · OPEN**
- **Sources:**
  - Apple 2.1(a): https://developer.apple.com/app-store/review/guidelines/#app-completeness
  - Apple 2.3.1(a).
  - Google app access: https://support.google.com/googleplay/android-developer/answer/9859455
- **Why:** no reviewer can pass phone OTP plus an Egyptian ID plus a selfie. Nothing in `functions/identity` provides a reviewer path.
- **What to build:**
  - A Firebase Auth test number (+20) with a fixed code.
  - One uid pre-seeded server-side as verified (woman, adult). `beginIdentityCheck` returns the verified result for that uid only, and the event is written to the audit log.
  - The account must not expire, and App Check must work on reviewer devices.
- **Review Notes (4000 bytes or less):**
  - The women-only reason and the flow: O03, O05, C06, code, C09b, ID, selfie, C12, C13.
  - Images are never stored.
  - The dormant features (see APL-13).
  - Attach a screen recording of a real verification.
- **Check:**
  - `grep -rn -i "review\|demo" $W/functions/identity` finds the gated path.
  - App Store Connect > App Review Information and Play Console > App content > App access are filled in.
  - A clean install with the test number reaches C13.

**APL-04 · Privacy nutrition labels match the manifest and the policy · R + L · PARTIAL**
- **Source:** https://developer.apple.com/app-store/app-privacy-details/
- **Status:** `app/ios/Runner/PrivacyInfo.xcprivacy` lacks SensitiveInfo (pregnancy, biometric face match) and PhotosorVideos (ID images and selfie).
- **Check, in App Store Connect:**
  - Declare: Health, Fitness, Sensitive Info, Photos or Videos, Phone Number, User ID, Device ID, Crash Data, Other Data.
  - Tracking is No.
  - Add Product Interaction when analytics ships.
- **Check, on the build:** add the two types to the manifest, then Xcode Archive > Generate Privacy Report. All three sources must agree, and agree with OWN-01 and GPL-04.

**APL-05 · Required-reason APIs and third-party SDK signatures · R · UNVERIFIED**
- **Sources:**
  - https://developer.apple.com/news/upcoming-requirements/
  - https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api
  - https://developer.apple.com/support/third-party-SDK-requirements/
- **Check:**
  - The archive privacy report.
  - The TestFlight upload email has no ITMS-91053 or 91055.
  - `pod outdated`.
  - Each `.xcframework` in `ios/Pods` is signed and ships a `PrivacyInfo.xcprivacy`.

**APL-06 · Consent before the camera, camera purpose strings, a visible recording state, data minimisation (both stores) · R + L · MET, re-verify on the new flow**
- **Sources:**
  - Apple 5.1.1(ii), (iii) and (v), and 2.5.14.
  - Google prominent disclosure (10144311).
  - PDPL Art. 12 (written consent for sensitive data).
- **Status:**
  - C09b `ConsentView` (`app/lib/features/signup/presentation/consent_view.dart`) records uid, version and timestamp before the camera opens, and a decline path exists.
  - `NSCameraUsageDescription` is in `Info.plist` (EN) and `ios/Runner/ar.lproj/InfoPlist.strings`.
  - The health backup is off by default, with its own consent (`HEALTH_CONSENT_VERSION`, `config.py:639`).
- **Check:**
  - `kCaptureConsentVersion` equals `CONSENT_VERSION = 1` (`functions/identity/config.py:634`).
  - In the value-first flow, C09b cannot be skipped and comes before any upload. "Continue" on O03 or O05 never counts as consent.
  - C10, C10b and C11 show an obvious live-camera state.

**APL-07 · Xcode 26 and the iOS 26 SDK · R · UNVERIFIED**
- **Source:** https://developer.apple.com/news/upcoming-requirements/
- **Check:** `xcodebuild -version` reports 26 or higher on the build machine.

**APL-08 · Age rating 18+ under the 2025 system · R · OPEN**
- **Source:** https://developer.apple.com/news/?id=ks775ehf
- **Check:**
  - In App Store Connect: answer Medical/Wellness honestly and declare Age Assurance (the ID check).
  - Set the rating to 18+ to match `MIN_AGE = 18` (`functions/identity/config.py:114`).

**APL-09 · Third-party sharing disclosed (Google Cloud, video vendor) · R + L · OPEN**
- **Source:** Apple 5.1.2(i) and (vi): https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
- **Check:** privacy §4 and §5 and the C09b bullets name Google Cloud (Frankfurt, `europe-west3`), Firebase Auth (US) and the video-call vendor with its region.

**APL-10 · Health data rules (both stores) · R + L · PARTIAL**
- **Sources:**
  - Apple 5.1.3: https://developer.apple.com/app-store/review/guidelines/#health-and-health-research
  - Google: https://support.google.com/googleplay/android-developer/answer/16926792
- **Check:**
  - No health fields in analytics (G9 test).
  - The health backup goes to Firestore, never iCloud or CloudKit, and is opt-in.
  - HealthKit and Health Connect are not used.
  - Health data is never used for advertising, employment or insurance.

**APL-11 · Rights to the brand and to Rahma's likeness; no impersonation (both stores) · R + L · OPEN**
- **Sources:**
  - Apple 5.2.1 and 4.1(c): https://developer.apple.com/app-store/review/guidelines/#intellectual-property
  - Google: https://support.google.com/googleplay/android-developer/answer/9888374
  - Google: https://support.google.com/googleplay/android-developer/answer/16341334
- **Check:**
  - A signed image-rights and content licence from Rahma Mohsen to the publisher entity is on file.
  - The developer name is never Rahma.
  - Terms §1 and Privacy §1 say: Mahmoud Reda as publisher and controller, Rahma Mohsen as founder and brand.

**APL-12 · Health disclaimer and "check with your doctor" (both stores) · R · PARTIAL**
- **Sources:**
  - Apple 1.4.1: https://developer.apple.com/app-store/review/guidelines/#physical-harm
  - Google: https://support.google.com/googleplay/android-developer/answer/16679511
- **Status:**
  - The cycle and pregnancy strings exist: `cycleDatesAreEstimatesThisFeatureIs`, `day1WasNotWrittenForPregnancy`, `thisNeedsADoctorNotAnApp`.
  - The "not a medical device" line is missing from `app_en.arb`. It is only in the Terms.
- **Check:**
  - The EN and AR store descriptions include: "not a medical device and does not diagnose, treat, cure, or prevent any medical condition" and "consult a healthcare professional".
  - The same line appears in the app: About, the cycle and life-stage screens, and O03 when pregnant or after a birth is chosen.
  - Run `grep -n -i "medical device" $W/app/lib/l10n/app_*.arb`.

**APL-13 · Dormant features declared; admin and testing aids unreachable · R · PARTIAL**
- **Source:** Apple 2.3.1(a) and 2.5.2.
- **Check:**
  - `FeatureFlags.shipped` (`app/lib/domain/flags/feature_flags.dart:186-216`): `accountRequired` true; community, coachApp, assistant, payments and marketplace false.
  - `adminConsole` is false and `testingAidsAllowed` is false in release.
  - Review Notes mention the dormant features.
  - No remote-config switch turns a feature on without a reviewed build.

**APL-14 · EU Digital Services Act (DSA) trader status · R · OPEN**
- **Source:** https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- **Check:** App Store Connect > Business > DSA. With Egypt-only availability, declare not a trader.

**APL-15 · Encryption export, review contact, device family, Sign in with Apple · R if wrong · MET, re-verify**
- **Sources:**
  - https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
  - Apple 4.8.
- **Check:**
  - `ITSAppUsesNonExemptEncryption` is false in `Info.plist`, and the App Store Connect questionnaire matches.
  - The App Review contact phone is in +20 format.
  - `TARGETED_DEVICE_FAMILY = 1` (iPhone only).
  - Sign in with Apple is not needed while login is phone OTP only. Re-check if any social login is added.

**APL-16 · [LATER] User-generated content: community, coach chat, coach portfolios (both stores) · R + L**
- **Sources:**
  - Apple 1.2 and 1.2.1: https://developer.apple.com/app-store/review/guidelines/#user-generated-content
  - Apple news: https://developer.apple.com/news/?id=d75yllv4 and https://developer.apple.com/news/?id=a233fmpw
  - Google: https://support.google.com/googleplay/android-developer/answer/9876937 and https://support.google.com/googleplay/android-developer/answer/12923286
  - Cybercrime Law Arts. 25 and 26.
- **Check:** before the flags turn on:
  - A pre-publication filter, report (`report_copy.dart`) and block (`safety_sheet_view.dart`).
  - A moderation queue with an SLA, and in-app community terms.
  - Coach image consent (`lib/features/coachbrand/domain/consent.dart`).
  - Redo IARC, the age rating and Data safety.

**APL-17 · [LATER] Payments for coaching and the marketplace (both stores) · R + L**
- **Sources:**
  - Apple 3.1.1 and 3.1.3(d): https://developer.apple.com/app-store/review/guidelines/#payments
  - Google: https://support.google.com/googleplay/android-developer/answer/9858738
  - CPL Arts. 37 to 41 (distance contracts, 14-day withdrawal).
- **Check:**
  - Live one-to-one sessions may use Paymob or Fawry.
  - Digital plans, recipes and the marketplace use StoreKit and Play Billing.
  - Information before the contract, written confirmation, and the withdrawal and refund flow.
  - Update the metadata and the deletion flow for subscriptions.
  - Egypt's eligibility for Google alternative billing is not verified.

**APL-18 · [LATER] AI assistant (both stores) · R + L**
- **Sources:**
  - Apple 5.1.2(i), 1.4.1 and 2.1.
  - Google AI content: https://support.google.com/googleplay/android-developer/answer/13985936, https://support.google.com/googleplay/android-developer/answer/14094294 and https://support.google.com/googleplay/android-developer/answer/16353813
  - Gemini terms: no medical advice.
- **Check:**
  - An opt-in naming Google.
  - In-app report and flag buttons on answers (`ask_view.dart`, `plan_draft_view.dart`).
  - `safety_classifier.dart` refuses medical questions.
  - `UnavailableAssistantProvider` is never visible.
  - Labels and Data safety are updated.
  - The vendor setup follows OWN-07.

---

## GPL: Google Play only

**GPL-01 · Closed test with 12 testers for 14 days (personal accounts only) · R · CONDITIONAL**
- **Source:** https://support.google.com/googleplay/android-developer/answer/14151465
- **Check:** Play Console > Dashboard > "Apply for production" is unlocked. If the account is personal: 12 women testers, continuously opted in for 14 days, started at least 3 weeks before launch. Not needed for an organisation account (APL-01).

**GPL-02 · Developer identity verification and package registration · R · UNVERIFIED**
- **Sources:**
  - https://support.google.com/googleplay/android-developer/answer/10840893
  - https://support.google.com/googleplay/android-developer/answer/16984799
  - https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html
- **Check:**
  - Play Console Home: identity is verified (Mahmoud's or the entity's), and `com.ownhub.app` is registered (the deadline was 30 Sep 2026).
  - The public developer name appears in `site/privacy` in both languages (10144311).

**GPL-03 · Target API 36 and 16 KB page size · R · targetSdk MET, 16 KB UNVERIFIED**
- **Sources:**
  - https://developer.android.com/google/play/requirements/target-sdk
  - https://developer.android.com/guide/practices/page-sizes
- **Check:**
  - `targetSdk = 36` in `app/android/app/build.gradle.kts` (the preflight checks this).
  - Play Console > App bundle explorer > 16 KB shows compatible. Or run `zipalign -c -P 16`, or `app/tool/elf_align.py`, on the release AAB.

**GPL-04 · Data safety form · R · PARTIAL**
- **Source:** https://support.google.com/googleplay/android-developer/answer/10787469
- **Check:** `app/android/play-data-safety.txt` adds:
  - age and sex derived from the ID (Personal info > Other)
  - name, if collected
  - App activity, if analytics ships
- Also:
  - The "photos processed ephemerally" claim needs Cloud Logging to hold no image payloads.
  - The deletion URL is set (OWN-06).
  - The form matches APL-04 and OWN-01.

**GPL-05 · Permissions: camera only, and no SMS or call-log access · R if it regresses · MET**
- **Sources:**
  - https://support.google.com/googleplay/android-developer/answer/16558241
  - https://support.google.com/googleplay/android-developer/answer/17134731
- **Check:**
  - `bundletool dump manifest` on the release AAB lists only CAMERA, plus the removed permissions marked `tools:node="remove"` in `app/android/app/src/main/AndroidManifest.xml`.
  - There is no READ_SMS or READ_CALL_LOG; Firebase uses the SMS Retriever (`app_code_field.dart`).

**GPL-06 · Content rating (IARC) and target audience 18+ with Restrict Minor Access · R · OPEN**
- **Sources:**
  - https://support.google.com/googleplay/android-developer/answer/9898843
  - https://support.google.com/googleplay/android-developer/answer/9867159
  - https://support.google.com/googleplay/android-developer/answer/9893335
- **Check:** Play Console > App content:
  - Content rating is complete, with no UGC or chat at launch.
  - Target audience is 18+ only, and Restrict Minor Access is on.

**GPL-07 · Store listing in EN and AR · BP (R for the disclosure line) · OPEN**
- **Sources:**
  - https://support.google.com/googleplay/android-developer/answer/9898842
  - https://support.google.com/googleplay/android-developer/answer/13393723
- **Check:**
  - Title "Own Hub", 30 characters or fewer, no emoji.
  - The first line says: for women in Egypt aged 18+, verified with a national ID.
  - The disclaimer from APL-12 is included.
  - An AR (MSA) listing is added.

**GPL-08 · Health apps declaration, and the risk of falling under "Medical" · R · OPEN**
- **Sources:**
  - https://support.google.com/googleplay/android-developer/answer/14738291
  - https://support.google.com/googleplay/android-developer/answer/13634885
- **Check:**
  - Play Console > App content > Health apps: Activity and Fitness, Nutrition and Weight Management, Period Tracking.
  - Pregnancy and postpartum are framed as fitness adaptations "with your doctor's clearance", not Reproductive and Sexual Health. If unsure, publish from an organisation account (APL-01).
  - Not verified: how Google classifies these features.

---

## LAW: Egypt

**LAW-01 · PDPC licence or permit before the grace period ends on 31 Oct / 1 Nov 2026 (25 days away) · L · OPEN**
- **Sources:**
  - Law 151/2020 Arts. 1 and 26, and Decree 816/2025.
  - Amereller: https://amereller.com/publication/the-egyptian-personal-data-protection-regime-what-you-need-to-know-ahead-of-31-october-2026/
  - Chambers: https://chambers.com/articles/a-first-look-at-egypt-s-personal-data-protection-executive-regulations
- **Check:**
  - Proof of filing on pdpc.gov.eg, with the portal status recorded.
  - The permit number and expiry are filled in at `site/privacy/index.html:107` and in the AR version.
  - Counsel decides whether an individual can hold the permit or a company is needed.

**LAW-02 · Sensitive-data licence and written explicit consent (biometric face match, health backup) · L · PARTIAL**
- **Sources:** PDPL Arts. 1 and 12. Art. 41 penalties: EGP 500k to 5M and/or prison.
- **Check:**
  - The licence covers biometric and health data.
  - Consent records: C09b (OWN-03 and APL-06) and `record_health_consent` in `functions/identity`.
  - The consent request is in Arabic and separate from the Terms.

**LAW-03 · Cross-border transfer licence, transfer impact assessment, and consent before the transfer · L · OPEN**
- **Sources:**
  - PDPL Arts. 14 to 16. Art. 42 penalties.
  - Shalakany (link in OWN-07).
- **Destinations:**
  - Frankfurt (`config.py:47`, `europe-west3`)
  - Cloud Vision EU (`config.py:55`)
  - Firebase Auth, US
  - the video vendor (to be decided)
  - [LATER] Gemini or Vertex
- **Check:**
  - A transfer impact assessment exists for each country.
  - `site/privacy/index.html:316` names the countries and the transfer mechanism.
  - The US transfer consent comes on C06, before the SMS is sent (OWN-03).

**LAW-04 · Data subject rights and the reply window · L · PARTIAL**
- **Sources:** PDPL Art. 2, and Baker McKenzie (6 working days, fees capped).
- **Check:**
  - `site/privacy/index.html:378` and `site/delete-account/index.html:94` give "6 working days" once counsel confirms.
  - Requests are free.
  - Covered by OWN-05 (export) and OWN-06 (deletion).
  - Consent can be withdrawn in the privacy centre.

**LAW-05 · Breach notification within 72 hours, and a breach register · L · OPEN**
- **Source:** PDPL Art. 7.
- **Check:** a runbook exists under `$W/firebase/ops` or a docs folder, with: owner, PDPC template, the 72-hour clock, the EN and AR user message within 3 working days, and the register.

**LAW-06 · DPO or personal liability; choosing a legal entity · L · OPEN**
- **Source:** PDPL Art. 8.
- **Check:**
  - If a company is formed: a registered DPO, published in privacy §1.
  - If not: counsel confirms that Mahmoud is personally liable.
- **Related:** APL-01.

**LAW-07 · Purpose limits, retention periods and records of processing · L · PARTIAL**
- **Source:** PDPL Art. 3.
- **Check:**
  - A records-of-processing document and consent log.
  - Privacy §6 retention matches the code: 180 days for review cases, enforced by a TTL policy in Firestore; the NID hash after deletion is disclosed.
  - Cloud Logging retention is set.

**LAW-08 · Processor contracts (Google DPA, SMS route, video vendor) · L · OPEN**
- **Sources:** PDPL Arts. 4 and 5; https://cloud.google.com/terms/data-processing-addendum
- **Check:** evidence of DPA acceptance from Cloud console > IAM & Admin > Settings, and the vendor contract is filed.

**LAW-09 · Waitlist marketing consent · L · OPEN**
- **Source:** PDPL Arts. 17 and 18.
- **Check:**
  - `functions/waitlist` and privacy §3.7 show prior consent, sender identity and an opt-out.
  - The 180-day auto-delete is squared with the rule to keep consent records for 3 years.

**LAW-10 · 18+ gate, including 16 and 17 year olds holding ID cards · L · MET, keep tested**
- **Sources:** PDPL Arts. 1 and 12; Constitution Art. 80.
- **Check:** `MIN_AGE = 18` (`functions/identity/config.py:114`), plus a test that a 17-year-old ID number is refused in `functions/tests`. Terms §3 and privacy §2 both say 18+.

**LAW-11 · Arabic text and supplier identity · L · PARTIAL**
- **Source:** CPL Art. 5.
- **Check:**
  - EN and AR exist for site, app and terms.
  - The Arabic-prevails clause is added.
  - Address and registration are shown, or counsel confirms an exemption.
  - She accepts in her own locale, and the locale is stored (OWN-03).

**LAW-12 · No misleading or health-advertising claims · L · OPEN**
- **Sources:**
  - CPL Arts. 1 and 9.
  - SCMR Decision 9/2025.
  - Chambers advertising guide: https://practiceguides.chambers.com/practice-guides/advertising-marketing-2025/egypt
  - Constitution Art. 18.
- **Check:**
  - The OWN-08 claim audit, applied to the store, the site and Rahma's social posts.
  - Paid partnerships are disclosed.
  - Before/after images are not misleading.
  - The wording stays "fitness and wellbeing".

**LAW-13 · Cybercrime: security measures, protecting ID data, logs · L · PARTIAL**
- **Sources:**
  - Law 175/2018 Arts. 1, 2, 24 and 29.
  - Google sensitive data (10144311).
- **Check:**
  - `firebase/firestore.rules` and `storage.rules` deny client reads of verification records.
  - `ENFORCE_APP_CHECK = True` (`config.py`).
  - The NID is stored only as an HMAC with its key in Secret Manager (`functions/identity/dedupe.py`, `nid.py`).
  - No image payloads in Crashlytics or in Cloud Logging (`functions/identity/logs.py`).
  - Counsel decides whether the 180-day service-provider log rule (Art. 2) applies.

**LAW-14 · Women-only rule: legal basis, disclosure and wording (both stores) · L + R · PARTIAL**
- **Legal sources:**
  - Constitution Arts. 9, 11, 53, 57, 59, 84 and 93, in `/Users/mahmoudreda/ownhub/.claude/release-compliance/egypt-constitution-2019.txt`.
  - Penal Code 161 bis: https://www.eipr.org/sites/default/files/reports/pdf/towards_an_equality_and_anti-discrimination_law_in_egypt_criteria_and_guidelines_1.pdf
  - CEDAW Art. 4(1): https://www.ohchr.org/en/instruments-mechanisms/instruments/convention-elimination-all-forms-discrimination-against-women
- **Store sources:**
  - Apple 1.1.1: https://developer.apple.com/app-store/review/guidelines/#objectionable-content
  - Google: https://support.google.com/googleplay/android-developer/answer/9878810
  - Australian precedent (the Giggle app case): https://www.abc.net.au/news/2026-09-11/giggle-v-tickle-app-founder-denied-high-court-appeal/107142432
- **Check:**
  - Storefront availability is Egypt only on both stores.
  - The listing discloses the restriction before download.
  - Sex is read from the ID digit only (`functions/identity/nid.py`), never guessed from the face.
  - Rejection copy is neutral: check `decisions.py` `REJECTED_NOT_ELIGIBLE` and its strings.
  - Wording is "made for women's safety and privacy", never anything that disparages men.
  - The niqab and woman-reviewer routes work.
  - Counsel approves the EN and AR framing used in Terms §3, `weReadYourNationalIdCardThe` and the store description.

**LAW-15 · Medical liability positioning and the coach agreement · L · PARTIAL**
- **Sources:**
  - Law 13/2025: https://eg.andersen.com/law-no-13-of-2025/
  - Labour Law 14/2025 Art. 5: https://www.loc.gov/item/global-legal-monitor/2025-07-25/egypt-labor-law-updated
- **Check:**
  - Terms §4 ("not medical advice") and the `day1WasNotWrittenForThe` gate are kept.
  - A coach agreement in which coaches warrant their qualifications, do not diagnose, and are independent contractors (Terms §12).
  - Counsel rules on whether contracting only women coaches and reviewers is lawful.

**LAW-16 · One card, one account (fake accounts) · BP · MET**
- **Source:** Law 175/2018 Art. 24.
- **Check:** the dedupe tests for `functions/identity/dedupe.py` pass.

**LAW-17 · Counsel sign-off list (the gate for OWN-09) · L · OPEN**

A licensed Egyptian lawyer confirms in writing:
1. The PDPC route (individual or company) and the filings due before 31 Oct / 1 Nov 2026.
2. Whether in-memory biometric matching needs a sensitive-data licence.
3. The US phone-number transfer basis, and whether consent on C06 is enough.
4. The Executive Regulations' article numbers, the 6-day reply window, and fees.
5. Whether a copy sent by email meets Art. 2.
6. Retention: 180-day review records, waitlist versus 3 years, the NID hash after deletion, cybercrime logs.
7. The women-only framing, Penal Code 161 bis, and Labour Law 14/2025.
8. CPL Art. 5 registration, the Arabic-prevails clause, and Art. 28 against Terms §13.
9. Click-wrap evidence under Law 15/2004.
10. Crashlytics running before consent.
11. Health positioning under SCMR 9/2025 and Law 13/2025.
12. The AI vendor terms.
13. The governing court for Terms §15 (the Economic Courts are a candidate).

**How an auditor checks:** a dated memo is on file, and each answer is reflected in the site, the app and this checklist.

---

## Not verified
- The AR site pages' placeholder count, and whether AR copies of the claims match EN line by line.
- Pod signing, required-reason API use, 16 KB alignment, the Xcode version, and Play account type and verification status. These need a build machine or console access.
- How Google classifies the pregnancy and postpartum features; Egypt's eligibility for alternative billing; the PDPC portal status; the Executive Regulations' article numbers.

**Key files**
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/config/legal_links.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/app_state/firebase_boot.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/main.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/account/presentation/your_data_sheet.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/consent_view.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/l10n/app_en.arb`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/l10n/app_ar.arb`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/domain/flags/feature_flags.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/ios/Runner/PrivacyInfo.xcprivacy`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/ios/Runner/Info.plist`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/android/play-data-safety.txt`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/android/app/src/main/AndroidManifest.xml`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/tool/release_preflight.sh`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/functions/identity/config.py`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/functions/account/deletion.py`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/functions/account/deletion_manifest.json`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/firebase/firestore.rules`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/config.json`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/index.html`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/privacy/index.html`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/terms/index.html`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/delete-account/index.html`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/ar/`