# Own Hub: App Store and Google Play launch checklist (6 Oct 2026)

**Verdict: not ready to submit.** The code is close: about 4 code items are left, plus asset and doc fixes. The long poles are owner-side:
1. **The entity decision.** It sets the account type on both stores. Apple 5.1.1(ix) says apps that need sensitive data "should be submitted by a legal entity", and this app takes a national ID, biometrics and pregnancy data.
2. **Counsel and the PDPC filing**, due 31 Oct / 1 Nov.
3. **The domain and mailboxes**, which unblock LegalLinks and the site.
4. **Google's 14-day closed test** with 12 or more testers, if the Play account is personal.

On a personal Play account the earliest Play production date is about 3 weeks after a signed build reaches closed testing.

## 1. What the stores require (official sources)

| Topic | Requirement | Source |
|---|---|---|
| Play account types | Personal or organisation. An organisation needs a D-U-N-S number (free, can take up to 30 days), and its payments-profile name and address must match D&B. Contact details are verified by one-time code. | support.google.com/googleplay/android-developer/answer/13628312 |
| Play registration | US$25 one-time fee. Government ID and a credit card in your legal name may be required. New personal accounts must prove access to an Android device through the Play Console mobile app. | .../answer/6112435 |
| Play closed test (personal accounts created after 13 Nov 2023) | "Closed test ... minimum of 12 testers who have been opted in continuously for at least 14 days", then Dashboard > Apply for production. Review "usually takes seven days or less". Production stays disabled until then. | .../answer/14151465 |
| Android developer verification | Play registers "99% of apps" automatically. Protections start 30 Sep 2026 in Brazil, Indonesia, Singapore and Thailand only, and expand globally in 2027. Egypt is not affected yet. It matters later for APKs sent over WhatsApp. | developer.android.com/developer-verification |
| Apple enrollment | Apple Account with 2FA. Individual: legal name, shown as seller. Organisation: a legal entity (no DBAs), D-U-N-S, a work email on the org domain, a working website. US$99 a year. | developer.apple.com/programs/enroll/ |
| Apple, regulated or sensitive apps | 5.1.1(ix): apps "that require sensitive user information should be submitted by a legal entity ... not by an individual developer". | developer.apple.com/app-store/review/guidelines/ |
| Play target API | Since 31 Aug 2026, new apps and updates must target API 36. An extension to 1 Nov 2026 is available. | developer.android.com/google/play/requirements/target-sdk |
| Play 16 KB pages | Required for apps targeting 35+. Updates are blocked from 1 Feb 2027. AGP 8.5.1+ aligns by default. | developer.android.com/guide/practices/page-sizes |
| Apple SDK | Builds must use Xcode 26+ and the iOS 26 SDK (since 28 Apr 2026), and target iOS 13+ (since 9 Sep 2026). | developer.apple.com/news/upcoming-requirements/ |
| Play App Signing | New apps are enrolled automatically. You keep the upload key, and Google can reset a lost one. Copy the app-signing SHA-1/SHA-256 from Play Console into Firebase and other API providers. | .../answer/9842756 |
| Firebase, Android | Phone auth needs the SHA-1, and Play Integrity needs the SHA-256, of the signing certificate. App Check Play Integrity: link the Cloud project in Play Console > App integrity and register the SHA-256 in Firebase App Check. | firebase.google.com/docs/auth/android/phone-auth, /docs/app-check/android/play-integrity-provider |
| Firebase, iOS | App Check App Attest: register the app in App Check, add the App Attest capability, set the entitlement to production. | firebase.google.com/docs/app-check/ios/app-attest-provider |
| Apple screenshots | 1 to 10 per size, no alpha. The spec page now lists **"iPhone with Dynamic Island (medium display)" 1179x2556 or 1206x2622 as the required size**. 1320x2868 is accepted for the large-display row. | developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications |
| Play assets | Icon 512x512, 32-bit PNG, 1 MB max. Feature graphic 1024x500, no alpha. Screenshots: 2 to 8, 320 to 3840 px, and "the maximum dimension ... can't be more than twice as long as the minimum dimension". Promotion needs 4 or more at 1080 px or above. Short description is 80 characters. | .../answer/9866151 |
| Privacy policy | Apple 5.1.1(i): a link in App Store Connect and inside the app, covering retention, deletion and revoking consent. Play: an active, public, non-geofenced URL, not a PDF. "The entity named in the ... store listing must appear in the privacy policy". | Apple guidelines; Play .../answer/10144311 |
| Consent | Apple 5.1.1(ii): consent, plus an easy way to withdraw it. Play prominent disclosure: shown in the app, needs an affirmative action, and navigating away is not consent. | same |
| Account deletion | Apple: started in the app, a full delete (deactivation is not enough). Phone, email or chat flows are allowed only for highly regulated industries. Play: an in-app path **and** a web resource that names the app or developer. Retention must be disclosed. | developer.apple.com/support/offering-account-deletion-in-your-app/, .../answer/13327111 |
| Play Data safety | Required for every app. Ephemeral means "only stored in memory ... no longer than necessary". Service providers are not "sharing". | .../answer/10787469 |
| Apple App Privacy | Sensitive Info covers "pregnancy or childbirth information ... biometric data". Data sent and then discarded at once is not "collected". Data collected by third-party SDKs counts. | developer.apple.com/app-store/app-privacy-details/ |
| Play Health apps declaration | Mandatory for all apps. Categories include Activity & fitness, Nutrition & weight, Period tracking. An app that is not a medical device must say "not a medical device and does not diagnose, treat, cure, or prevent" in its description and tell users to consult a professional. | .../answer/14738291, .../answer/16679511 |
| Apple medical | 1.4.1: remind users to check with a doctor. | Apple guidelines |
| Reviewer access | Apple 2.1(a): a demo account with the back end on, and no placeholder text or empty websites. 2.3.1(a): no hidden or dormant features, and new functionality described "with specificity" in Review Notes. Play App access: up to 5 instruction sets; say if there is an OTP or MFA. | Apple guidelines; .../answer/9859455 |
| Apple age rating | Ratings are 4+/9+/13+/16+/18+. The questionnaire covers Age Assurance and Health or Wellness. "Override to Higher Age Rating" is required when the EULA minimum age is above the calculated rating. | developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/ |
| DSA trader | Must be declared even when the app is not distributed in the EU. Egypt-only distribution means non-trader. | developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/ |
| Export compliance | `ITSAppUsesNonExemptEncryption=NO` when only exempt or OS encryption (HTTPS) is used. | developer.apple.com/forums/thread/121183 (Apple docs summary) |
| Agreements, tax, banking | Free apps are covered by the Program License Agreement. The Paid Apps Agreement, tax and banking are needed only for paid apps or in-app purchases. | developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements |
| Availability | App Store: Pricing and Availability > Specific Countries or Regions. Leave "all future countries" unticked. | .../manage-availability-for-your-app-on-the-app-store |
| Testing | TestFlight: 100 internal testers, 10,000 external. External testing needs Beta App Review. Builds last 90 days. Play internal testing: 100 testers. | .../overview-of-testflight; .../answer/9845334 |
| Gradual release | Apple phased release (7 days, 1% to 100%) is for **updates only**. Play staged rollout is "only ... for app updates, not when publishing an app for the first time". | .../release-a-version-update-in-phases; .../answer/6346149 |

## 2. Current state: new findings beyond the compliance judge

1. **The keystore exists, it is just not in this worktree.** `~/keys/ownhub-upload.jks` is there (alias `upload`). `key.properties` exists only in `/Users/mahmoudreda/ownhub/.claude/worktrees/release-readiness/app/android/key.properties`. The preflight FAIL is a copy step, not "create a keystore".
2. **The Firebase config files are missing in the onboarding worktree.** Neither `app/android/app/google-services.json` nor `app/ios/Runner/GoogleService-Info.plist` exists there (both are gitignored). Both exist in the release-readiness worktree. The Android build applies `com.google.gms.google-services`, so it will fail without the file.
3. **The Play screenshot harness renders 1080x2400.** `app/test/store/store_screenshots_test.dart:46` and `docs/release/launch-pack/screenshots/{en,ar}` use that size, and 2400 is more than twice 1080, which breaks Play's 2:1 rule. Also, the `en/` folder is empty. The older `docs/release/screenshots/play-phone` set is valid (1080x1920, no alpha, plus a 1024x500 feature graphic) but predates the account flow.
4. **The Apple screenshots may not fill the required slot.** The only set is `apple-6.9` (1320x2868, English only). Apple's spec page now marks the 6.1" medium Dynamic Island size (1179x2556 or 1206x2622) as required. Make that set too, and an Arabic set.
5. **`docs/release/review-notes.md` is stale.** It says "no account, no sign-in ... no network code ... Data Not Collected". Pasting it would be a 2.3.1 misrepresentation.
6. **The store listing still promises a video call.** `launch-pack/store-listing-copy.md` (EN and AR) says "a short video call with a woman reviewer", but there is no vendor (judge item 8). The C14/C15 review-v1 strings say the same.
7. **The App Check and phone-auth console wiring is not done.** Release builds use `AndroidPlayIntegrityProvider` and `AppleAppAttestWithDeviceCheckFallbackProvider` (`firebase_boot.dart:204-207`), and the entitlement is set to production. Still needed:
   - the Play app-signing and upload SHA-1/SHA-256 in Firebase;
   - the Cloud project linked in Play Console;
   - App Attest registration with the Team ID.

   Without these, Play-installed builds will fail OTP or callables.
8. **There is no APNs key**, which the Info.plist comment admits. Every iOS sign-in, including the reviewer's, goes through a reCAPTCHA web view.
9. **Analytics only prints to the debug log** (`DebugPrintAnalyticsSink`, `main.dart:55`), so nothing is sent. "App activity: not collected" is true today. If a real sink is ever added, both forms must change.
10. **Ready today:**
    - targetSdk and compileSdk 36, minSdk 24, R8 on, release refuses the debug key
    - iOS deployment target 15.5, iPhone-only, portrait, Xcode 26.3 / iOS 26.2 SDK
    - `ITSAppUsesNonExemptEncryption=false`; camera is the only permission
    - icon master `assets/icon/icon-1024.png` (real brand mark, no alpha); adaptive icon set
    - privacy manifest types match the preflight (Health, Fitness, SensitiveInfo, PhotosorVideos, and others; Tracking false)
    - `version: 1.0.0+1`; bundle and application id `com.ownhub.app`
    - community, coachApp and assistant are off
    - store listing copy in EN/AR exists, with the medical disclaimer, within length limits

## 3. Launch checklist, in timeline order

Status key: **READY** = done. **MISSING (code)** = repo, asset or doc work Claude can do. **OWNER ACTION** = only Mahmoud, counsel or a console can do it.

### Phase 0: decisions and accounts (this week, 6 to 10 Oct). This is the critical path.

| # | Item | Status | Where | Next step |
|---|---|---|---|---|
| 0.1 | Entity decision: individual or company | OWNER ACTION | config.json `legalEntity` | Decide with counsel. A company means org accounts and D-U-N-S (up to 30 days), but it clears Apple 5.1.1(ix) and skips Play's closed-test rule. Individual is faster on paper but carries 5.1.1(ix) rejection risk. |
| 0.2 | Egyptian counsel, PDPC filing, Google Cloud DPA, breach runbook | OWNER ACTION | pdpc.gov.eg; `firebase/ops/` | File before 31 Oct. Ask counsel whether a closed test with real IDs (0.8) may run before the licence. |
| 0.3 | Domain and role mailboxes (privacy@, support@) | OWNER ACTION | config.json `baseUrl` (now `ownhub.example`), `contactPrivacy`/`contactSupport` (personal Gmail) | Buy the domain and host the site (the `_headers` file suits Cloudflare Pages). Create the mailboxes. Fill in `hostingProvider` and `emailProvider`. An org Apple account also needs an email on this domain and a working website. |
| 0.4 | D-U-N-S number (company route only) | OWNER ACTION | dnb.com / Apple D-U-N-S lookup | Request it today. The name and address must match the Google payments profile exactly. |
| 0.5 | Apple Developer Program enrollment | OWNER ACTION | developer.apple.com/programs/enroll | Use a 2FA Apple Account in the correct legal name. Pay $99. Note the **Team ID**. |
| 0.6 | Google Play Console registration | OWNER ACTION | play.google.com/console | Check whether the account already exists. Pay $25, verify ID and contact details, verify the Android device in the Play Console app. Check the "developer verification" banner and register `com.ownhub.app` if Play asks. |
| 0.7 | Rahma image and content licence to the publisher | OWNER ACTION | counsel | Sign it before upload. App Store Connect asks whether the app "contains third-party content". Rahma is never the seller or the privacy contact. |
| 0.8 | Recruit 12+ closed testers (women with Google accounts on Android) | OWNER ACTION | `launch-pack/pilot-checklist.xlsx` | Use the ~30-woman pilot. Opt them in on day 1 and keep them opted in for 14 days. |

### Phase 1: code and content (about 4 days, in parallel with Phase 0)

| # | Item | Status | Where | Next step |
|---|---|---|---|---|
| 1.1 | M1 and M3 to M16 from the implementation report | READY (uncommitted) | branch `onboarding/2026-10-06`, 173 changed paths | Owner reviews, then commits (no push without approval). |
| 1.2 | LegalLinks values | MISSING (code), blocked on 0.3 | `app/lib/config/legal_links.dart` (all 4 empty, `privacyEmail` is Gmail) | Fill in from the domain. A release build throws until this is done. |
| 1.3 | Site values (22 empty) and draft banners | OWNER ACTION, then MISSING (code) | `site/config.json`, `release:false` | Counsel supplies the values. Rebuild with `site/_build/build.py`, remove the banners, deploy, then run the preflight with `RELEASE_BASE_URL`. |
| 1.4 | Remaining "video call" promises | MISSING (code) | C14/C15 review-v1 strings; `store-listing-copy.md` EN/AR | Bump the review-consent version and reword to "a woman from Own Hub reviews and contacts you, up to 72h". Fix both listings. |
| 1.5 | Xcode privacy report | MISSING (code) | Xcode > Archive > Generate Privacy Report | Compare it line by line with `PrivacyInfo.xcprivacy`, `play-data-safety.txt` and privacy section 3. |
| 1.6 | Deploy TTL policies and functions, including the reviewer allow-list | MISSING (code/deploy) | `firebase/ops/ttl-policies.sh`, `functions/` | Deploy to `own-hub`. Create Secret Manager `store-reviewer-uids` and leave it empty. |
| 1.7 | Rewrite the review notes for the account build | MISSING (code) | `docs/release/review-notes.md` (stale) | Cover: test number and code; the account is approved through the server allow-list (no client bypass); that community, coach and assistant code is off and cannot be enabled without a new review; why ID is required; the not-a-medical-device line. Keep it under 4000 bytes. Also align `play-app-access.md` with the M13 allow-list. |
| 1.8 | Play screenshots | MISSING (code) | `store_screenshots_test.dart:46` | Change the size to 1080x1920 (9:16, also promotion-eligible). Render EN and AR, 4 to 8 each, from the build being uploaded. |
| 1.9 | Apple screenshots | MISSING (code) | `docs/release/screenshots/` | Add a 1206x2622 (or 1179x2556) set. Keep the 1320x2868 set. Make EN and AR, no alpha. |
| 1.10 | Play 512x512 icon | MISSING (code) | from `assets/icon/icon-1024.png` | Export a 512 PNG under 1 MB. The feature graphic 1024x500 is READY. |
| 1.11 | Copy the local build inputs into this worktree | MISSING (setup) | from the `release-readiness` worktree | Copy `key.properties`, `google-services.json` and `GoogleService-Info.plist`. All are gitignored; never commit them. Back up `~/keys/ownhub-upload.jks` and its passwords offline (OWNER). |
| 1.12 | iOS Team ID | OWNER ACTION, blocked on 0.5 | `ios/ExportOptions.plist` (`YOUR_TEAM_ID`), `DEVELOPMENT_TEAM` in the pbxproj (unset) | Paste the Team ID; the preflight then passes. |

### Phase 2: builds and Firebase wiring (once 0.5, 0.6 and 1.11 are done)

| # | Item | Status | Where | Next step |
|---|---|---|---|---|
| 2.1 | Release AAB and IPA | MISSING (code) | `app/tool/build_release.sh` (obfuscate, split-debug-info, APP_VERSION) | Build both. Keep `build/symbols` and `mapping.txt`, and upload the mapping in Play. Confirm the merged release manifest has INTERNET (it comes from the Firebase libraries) and that RECORD_AUDIO is stripped. |
| 2.2 | Preflight all green | MISSING (code) | `app/tool/release_preflight.sh` | Run with the AAB present and `RELEASE_BASE_URL` set. This covers 16 KB alignment and the signer name (should be UPLOAD). |
| 2.3 | Device smoke test, C01 to C13, EN and AR | MISSING (code) | a real Android phone and iPhone | Run the whole path, including RTL. Also run the iPhone app on an iPad in compatibility mode, because Apple reviewers often use iPads. |
| 2.4 | First upload to Play internal testing | OWNER ACTION | Play Console > Testing > Internal | This creates the Play App Signing key. |
| 2.5 | Firebase SHA fingerprints | OWNER ACTION | Firebase > Project settings > Android app | Add SHA-1 and SHA-256 of **both** the upload key and the Play app-signing key. Without them, OTP fails on Play installs. |
| 2.6 | App Check, Android | OWNER ACTION | Play Console > App integrity > Link Cloud project; Firebase App Check | Register Play Integrity with the signing SHA-256. Watch the metrics before enforcing. |
| 2.7 | App Check, iOS | OWNER ACTION | Firebase App Check (needs the Team ID); App Attest capability on the App ID | Register App Attest. |
| 2.8 | APNs auth key | OWNER ACTION | developer.apple.com > Keys (.p8), then Firebase Cloud Messaging | Upload it so iOS OTP stops falling back to reCAPTCHA. Keep the URL scheme. |
| 2.9 | Firebase Auth reviewer and test numbers; SMS region policy limited to Egypt | OWNER ACTION | Firebase > Authentication > Phone | Add 2 fictional +20 numbers with fixed codes (`play-app-access.md` Part 1). Sign in once, and put both uids in `store-reviewer-uids` **only while a review is open**. |
| 2.10 | TestFlight internal | OWNER ACTION | App Store Connect > TestFlight | Fill in the beta description and feedback email. Up to 100 internal testers, no review needed. |

### Phase 3: store consoles (start in parallel with Phase 2; both stores ask for these before releasing a test track)

| # | Item | Status | Where | Next step |
|---|---|---|---|---|
| 3.1 | Privacy policy, support and deletion URLs | OWNER ACTION, blocked on 0.3 and 1.3 | Both consoles; Play Data safety > Data deletion | Use `{baseUrl}/privacy/`, `/support/`, `/delete-account/`. The policy names Mahmoud Reda, who is the listed developer. |
| 3.2 | Play Data safety | READY (text), OWNER ACTION (enter it) | `app/android/play-data-safety.txt` | Paste after 1.5 matches. Fix the "call a woman reviewer makes" phrase if the video call is dropped. |
| 3.3 | Apple App Privacy | READY (text), OWNER ACTION (enter it) | `launch-pack/app-store-privacy-answers.md`, `PrivacyInfo.xcprivacy` | Enter it. Tracking: No. |
| 3.4 | Play Health apps declaration | OWNER ACTION | Play > App content > Health apps | Activity & fitness; Nutrition & weight management; Period tracking. Not a medical device. |
| 3.5 | Content rating | OWNER ACTION | Play IARC questionnaire; App Store Connect Age Rating | No UGC or chat; Health or Wellness: yes; Age Assurance: yes. On Apple, choose **Override to Higher Age Rating: 18+**. On Play, set Target audience to 18+ only. |
| 3.6 | Other Play App content declarations | OWNER ACTION | Play > App content | Ads: No. App access: the instructions from `play-app-access.md`. Government app: No. Financial features: None. News: No. |
| 3.7 | DSA trader status | OWNER ACTION | App Store Connect > Business | Declare non-trader (Egypt only). |
| 3.8 | Export compliance | READY | `Info.plist` `ITSAppUsesNonExemptEncryption=false` | Confirm in the first upload's compliance prompt. TLS only; `crypto` is used for sha1 ids. |
| 3.9 | Store listing EN and AR | READY (text, apart from 1.4) | `launch-pack/store-listing-copy.md` | Category Health & Fitness. Free, no ads, no in-app purchases. Add an Arabic localization in App Store Connect and Play. Copyright line: "2026 Mahmoud Reda". |
| 3.10 | Pricing and availability | OWNER ACTION | App Store Connect > Pricing and Availability; Play > Countries/regions | Free. **Egypt only**, with "future countries" unticked. |
| 3.11 | App Review contact and sign-in | OWNER ACTION | App Store Connect > App Review Information | Sign-in required: Yes. Test number and code. A phone and email answered during review. Notes from 1.7, plus a screen recording of the sign-up path. |
| 3.12 | Tax and banking | READY (not needed) | n/a | Free app with no in-app purchases: no Paid Apps Agreement and no merchant account. Revisit when coaching or payments ship. |

### Phase 4: testing gates (about 14 to 21 days)

| # | Item | Status | Where | Next step |
|---|---|---|---|---|
| 4.1 | Play closed test, 12+ testers for 14 continuous days (personal account only) | OWNER ACTION | Play > Testing > Closed | Start the day the first signed AAB is in. A tester who opts out resets nothing but no longer counts. Collect real feedback, because the production application asks about it. |
| 4.2 | Apply for production | OWNER ACTION | Play Dashboard | On day 15 or later. Review is usually 7 days or less. |
| 4.3 | TestFlight external (optional pilot on iOS) | OWNER ACTION | App Store Connect | Needs Beta App Review. Use it for the niqab and woman-reviewer route test (judge item 8). |

### Phase 5: submit and release

| # | Item | Status | Where | Next step |
|---|---|---|---|---|
| 5.1 | App Store submission | OWNER ACTION | App Store Connect | Choose "Manually release". Keep the allow-list populated until approval, then empty it. |
| 5.2 | Play production release | OWNER ACTION | Play | The first release goes to 100%, because staged rollout is not allowed on a first release. |
| 5.3 | Phased or staged rollout | READY for 1.0.1+ | both consoles | Use Apple's 7-day phased release and Play staged rollout from the first update on. |
| 5.4 | Site store buttons | MISSING (code) | `config.json` `storeUrlIos`/`storeUrlAndroid` | Fill in after approval, rebuild and deploy. |
| 5.5 | Clear `store-reviewer-uids` and log it | OWNER ACTION | Secret Manager | Right after each review closes. |

## 4. What commonly gets apps like this rejected (mapped to Own Hub)

- **Reviewer cannot get past the login, OTP or ID check** (Apple 2.1, Play App access). Covered by 1.6, 2.9 and 3.11. The reviewer also needs the server allow-list, because a test number alone stops at the ID screen.
- **Placeholder text or draft legal pages** (2.1(a)): `ownhub.example`, `[to be completed]` and the draft banners. Covered by 1.2 and 1.3.
- **Privacy policy not reachable in the app** (5.1.1(i), Play User Data). The links are wired; only the values are missing (1.2).
- **Labels that don't match the binary** (Firebase installation id, crash data, biometrics or pregnancy as Sensitive Info). Covered by 1.5, 3.2 and 3.3.
- **Advertising a feature that doesn't exist** (2.3.1, Play Misrepresentation): the video call, and showing community or coaching in screenshots. Covered by 1.4 and 1.8.
- **Dormant features** (2.3.1(a)): the community, coach and assistant code is in the binary. Name it in the Review Notes as off and not remotely switchable.
- **Asking for more data than needed** (5.1.1(iii) and (v)): a reviewer may ask why solo workouts need a government ID and a selfie. The answer goes in the Review Notes, and counsel's proportionality ruling (judge item 17) backs it.
- **Account deletion that needs a phone call or support step.** Apple allows that only for highly regulated industries. The site's delete page currently confirms by the publisher phoning her (judge item 14): change it to a reply email or SMS code.
- **Health claims without a disclaimer** (Apple 1.4.1, Play Health). The in-app line is done (M6), and both listings carry it.
- **Submitted by an individual while taking sensitive data** (5.1.1(ix)). This is decision 0.1.
- **Crash at launch on a reviewer device.** A release build throws while LegalLinks are empty, and nothing has been run on a device. Covered by 1.2 and 2.3.

Key files: `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/tool/release_preflight.sh`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/config/legal_links.dart`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/config.json`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/android/play-data-safety.txt`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/ios/ExportOptions.plist`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/test/store/store_screenshots_test.dart`, `/Users/mahmoudreda/ownhub/docs/release/review-notes.md`, `/Users/mahmoudreda/ownhub/docs/release/launch-pack/`. No app code was edited.