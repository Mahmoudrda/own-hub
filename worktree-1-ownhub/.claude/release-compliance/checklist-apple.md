# Own Hub: Apple App Store requirements (checked 6 Oct 2026)

**Short version.** Five things block approval today:

1. **No legal links in the app.** All four links in `app/lib/config/legal_links.dart` are empty strings: privacy policy, terms, support and delete-account.
2. **The website still has placeholders.** `site/config.json` sets `baseUrl` to `https://ownhub.example`, and the privacy, terms and delete-account pages show 10 `[to be completed: ...]` markers.
3. **App Review has no way past the Egyptian national ID check.** I found no reviewer path in `functions/`.
4. **Guideline 5.1.1(ix) applies.** The app needs sensitive data (ID card and selfie), so Apple expects a company account, not an individual one.
5. **The privacy declarations don't fully match the data.** Pregnancy and the face match should probably be declared as Sensitive Info, and the ID photos as Photos or Videos.

Launch flags as shipped (`feature_flags.dart` lines 188 to 216): accountRequired on; community, coachApp, assistant, payments and marketplace off. Items below that only apply to the dark features are marked **[LATER]**.

Severity labels: **R** = Apple can reject the build, **L** = legal liability, **BP** = best practice.

---

## A. Blocking now

**A1. Privacy policy linked in App Store Connect and inside the app (5.1.1(i))** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage. Quote: "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner." The policy must list all data, its uses, third parties, retention and deletion, and how to withdraw consent.
- **Why it applies:** `LegalLinks.privacyPolicy == ''`. `privacy_view.dart:375` hides the link when the value is empty, so the release build has no in-app policy at all.
- **Check:** fill in `legal_links.dart` (or assert `LegalLinks.allSet` in release). Open the link from C09b, the privacy centre and Settings on a device.

**A2. No placeholder content or empty websites (2.1(a))** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#app-completeness. Quote: "placeholder text, empty websites, and other temporary content should be scrubbed before submission."
- **Why it applies:**
  - `site/config.json` `baseUrl` is `https://ownhub.example`.
  - `site/privacy` still has 7 `[to be completed]` markers: the Personal Data Protection Centre permit, cross-border transfers, the video-call vendor and its region, the response window, and the regulator contact.
  - `site/terms` has 2 (liability cap and the court that hears disputes). `site/delete-account` has 2.
- **Check:** `grep -r "to be completed" site/` must return nothing. Then deploy to the real domain.

**A3. Support URL with real contact details** · R
- **Source:** https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information. The Support URL "must lead to actual contact information". Guideline 1.2 also asks for "Published contact information".
- **Why it applies:** `LegalLinks.support` is empty. When it is empty, `app_router.dart:2274` drops the "talk to a human" option.
- **Check:** `site/support` shows an email, plus a phone number and address where Egyptian law requires them. Its URL goes in App Store Connect and in `legal_links.dart`.

**A4. A working demo account, the backend live, and specific Review Notes (2.1(a), 2.3.1(a))** · R
- **Sources:**
  - https://developer.apple.com/app-store/review/guidelines/#app-completeness: "include demo account info (and turn on your back-end service!)"
  - https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information: the demo account "must not expire"; notes can be up to 4000 bytes.
- **Why it applies:** sign-in is a phone code (OTP), and the gate is an Egyptian national ID plus selfie that no reviewer can pass. Rejection is close to certain without a path through.
- **Check:**
  - Add a Firebase Auth test phone number with a fixed code, and seed that account server-side as already verified (a woman, adult).
  - Its `beginIdentityCheck` should return the verified result without touching the ID pipeline. Keep it to that one uid and record it in the audit log.
  - Review Notes should explain the women-only reason, the steps (O03, O05, phone, code, C09b consent, ID, selfie, C13), and that images are never stored.
  - Attach a screen recording of a real verification on a test device so the reviewer can see the flow they skip.
  - Nothing like this exists today: grepping `functions/` for "review", "demo" and "test phone" found nothing.

**A5. Sensitive data needs a legal entity as the account holder (5.1.1(ix))** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage. Quote: apps "that require sensitive user information should be submitted by a legal entity that provides the services, and not by an individual developer."
- **Why it applies:** national ID front and back, a selfie face match, and pregnancy and cycle data.
- **Check:** the developer account should be an Organization (it needs a D-U-N-S number). That entity is the publisher on the Mahmoud Reda side; Rahma Mohsen must never be the seller or developer name (see C3). If it stays an individual account, expect a 5.1.1(ix) rejection.

**A6. Privacy nutrition labels must be complete and match the privacy manifest and policy** · R and L
- **Sources:**
  - https://developer.apple.com/app-store/app-privacy-details/. "Collect" means data sent off the device and kept longer than needed for the real-time request. Data from third-party SDKs counts. You must update the answers when practices change.
  - Sensitive Info explicitly includes pregnancy and biometric data.
- **Why it applies:**
  - `ios/Runner/PrivacyInfo.xcprivacy` declares DeviceID, PhoneNumber, UserID, HealthFitness, OtherUserContent, OtherDataTypes and CrashData.
  - It declares no **SensitiveInfo**, although the health backup can include pregnancy and life stage, and the selfie is face-matched (biometric).
  - The ID photos and selfie fit **Photos or Videos** better than "Other User Content".
  - Apple uses **Health** and **Fitness** as separate labels in App Store Connect.
- **Check:**
  - In App Store Connect: Health, Fitness, Sensitive Info (pregnancy, biometric), Photos or Videos, Phone Number, User ID, Device ID, Crash Data and Other Data. All linked except Device ID and Crash Data. None used for tracking.
  - Add the SensitiveInfo and PhotosorVideos types to the manifest.
  - Make the three sources say the same thing: run Xcode Archive, then Organizer, then Generate Privacy Report.
  - When analytics replaces the debug sink, add **Product Interaction**.

---

## B. Privacy and technical submission rules

**B1. Privacy manifest and required-reason APIs (rejection code ITMS-91053 since 1 May 2024)** · R
- **Sources:**
  - https://developer.apple.com/news/upcoming-requirements/
  - https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api (codes such as CA92.1 for UserDefaults and C617.1 for file timestamps)
- **Why it applies:** `NSPrivacyAccessedAPITypes` is empty for the app target, which is fine only if no Dart or Swift code in the target calls those APIs itself.
- **Check:** run the privacy report on an archive. Read Apple's warning email after uploading to TestFlight, and confirm there are no ITMS-91053 or 91055 errors.

**B2. Signatures and manifests for third-party SDKs** · R
- **Source:** https://developer.apple.com/support/third-party-SDK-requirements/. The list includes FirebaseAuth, Core, CoreInternal, Crashlytics, Firestore, Installations, GoogleDataTransport, GoogleUtilities, GTMSessionFetcher, abseil, BoringSSL, gRPC, leveldb, nanopb, Promises, Flutter and url_launcher.
- **Why it applies:** all of these are in the Pods through pubspec.
- **Check:** keep the pod versions current (`pod outdated`). Confirm each `.xcframework` in `ios/Pods` is signed and ships its own `PrivacyInfo.xcprivacy`.

**B3. Xcode 26 and the iOS 26 SDK (from 28 April 2026)** · R
- **Source:** https://developer.apple.com/news/upcoming-requirements/
- **Check:** `xcodebuild -version` is 26 or higher on the build machine. The deployment target is 15.5, which already meets the iOS 13 minimum.

**B4. App Tracking Transparency** · R if done wrong
- **Source:** https://developer.apple.com/app-store/user-privacy-and-data-use/. Tracking means linking her data with other companies' data for ads, or sharing with data brokers. You may not gate features on tracking consent.
- **Why it applies:** there is no ad or tracking SDK, and `NSPrivacyTracking` is false. Do not add the ATT prompt.
- **Check:** keep the tracking answer at No in App Store Connect. Re-check when the analytics vendor is chosen: it must be first-party or a processor that does no cross-app linking.

**B5. Consent and the right to withdraw it (5.1.1(ii)); purpose strings; data minimization (5.1.1(iii)); no forced personal data (5.1.1(v))** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage
- **Why it applies:** this covers the ID, the selfie, the health backup, analytics and Crashlytics.
- **Check:**
  - C09b consent is shown before the camera opens.
  - The health backup is off by default, with its own consent and its own off switch.
  - `NSCameraUsageDescription` is present in EN and AR (`ios/Runner/*.lproj/InfoPlist.strings`).
  - Review Notes justify the ID requirement as core functionality (women-only safety).
  - Crashlytics and analytics need a way to opt out in the privacy centre.

**B6. Telling her when the app records (2.5.14)** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#software-requirements. Explicit consent and a clear visual indicator for any camera use.
- **Check:** the C10, C10b and C11 capture screens show an obvious live-camera state, and C09b consent comes before them.

**B7. Data use and sharing, including third parties and AI (5.1.2(i), (ii) and (vi))** · R and L
- **Source:** https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing. Quote: "clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission." Point (vi) says data from camera face-mapping may not be used for marketing.
- **Why it applies:**
  - ID images go to Google Cloud processing, and the human reviewer fallback uses a video-call vendor that the policy doesn't name yet.
  - **[LATER]** The assistant is planned on Gemini Flash (`assistant_provider.dart`).
- **Check:**
  - The policy and C09b name Google Cloud and the video vendor.
  - Before the assistant flag is turned on, add a separate opt-in screen naming Google Gemini.
  - The assistant must never send health data without that consent. `AssistantRequest` already carries no uid.

**B8. Health data (5.1.3)** · R and L
- **Source:** https://developer.apple.com/app-store/review/guidelines/#health-and-health-research. No advertising or data mining use. No personal health data in iCloud. Don't write false data to HealthKit.
- **Why it applies:** cycle, weight and pregnancy data. HealthKit is not used today.
- **Check:** no health fields in analytics events (enforce with an allow-list test in `analytics_gateway.dart`). The health backup goes to Firestore, not to an iCloud or CloudKit container.

**B9. In-app account deletion (5.1.1(v))** · R
- **Source:** https://developer.apple.com/support/offering-account-deletion-in-your-app/. Delete the whole account and its data (deactivating is not enough), make the option easy to find, and tell her how long it takes. Content she posted counts too.
- **Why it applies:** the deletion feature exists: `your_data_sheet.dart`, `callable_deletion_transport.dart` and `functions/account/deletion.py`. But `webDeletionUrl` falls back to the empty `LegalLinks.deleteAccount`.
- **Check:**
  - On a release build: Settings, then "Download everything, or delete your account", then delete. Confirm the Auth user, the Firestore documents, Storage and the NID hash are gone. Keep the hash only if retaining it is disclosed (for example, to stop one card being reused).
  - Show how long deletion takes.
  - **[LATER]** For community posts, coach plans and portfolios, extend `deletion_manifest.json`.

**B10. Sign-in rules (4.8)** · BP for now
- **Source:** https://developer.apple.com/app-store/review/guidelines/#login-services
- **Why it applies:** phone OTP is first-party, so Sign in with Apple is not required.
- **Check:** if Google or Facebook login is ever added, Sign in with Apple (or an equivalent) must be added with it, and deletion must revoke the Apple token.

**B11. Encryption export answer** · R if the plist key is wrong; L
- **Sources:**
  - https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
  - https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- **Why it applies:** Info.plist has `ITSAppUsesNonExemptEncryption = false`. Firestore's gRPC uses BoringSSL, a standard TLS stack, not proprietary encryption, so "exempt" is the normal answer.
- **Check:** confirm the App Store Connect questionnaire matches the plist. France documentation is not needed for this app category.

---

## C. Content, safety and metadata

**C1. Age rating under the 2025 system (2.3.6)** · R if mis-rated
- **Sources:**
  - https://developer.apple.com/news/?id=ks775ehf: new 13+, 16+ and 18+ ratings; answers were required by 31 January 2026; "you can set a higher age rating after you respond".
  - https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
  - https://developer.apple.com/app-store/review/guidelines/ (2.3.6)
- **Why it applies:** health and wellness topics, plus medical or treatment information on pregnancy, postpartum and cycle pain. `functions/identity/config.py` has `MIN_AGE = 18`.
- **Check:**
  - Answer the Medical/Wellness and in-app controls questions honestly.
  - Declare "Age Assurance": the ID check verifies age.
  - Then set the rating higher, to **18+**, to match `MIN_AGE`.
  - **[LATER]** Community means answering yes to user-generated content, messaging and possibly social media (13+).

**C2. Accurate metadata, screenshots and the "no false claims" rules (2.3.1, 2.3.3, 2.3.4, 2.3.7, 2.3.8, 2.3.12, 1.1.6)** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#accurate-metadata
- **Why it applies:** the dark features (community, coach, assistant) must not appear in screenshots or the description. Claims like "images never stored", "women only" and "90 seconds" must be true.
- **Check:**
  - Screenshots show real in-app screens in EN and AR, not just the welcome or login screen.
  - The name is 30 characters or fewer.
  - No price or other app names in the metadata.
  - "What's New" lists the real changes.
  - Every metadata claim can be traced to code: for example, `bothImagesAreDeletedAfterTheCheck` against `functions/identity/store.py`, which stores no images.

**C3. Rights to the brand and to Rahma's likeness (5.2.1, 4.1(c))** · R and L
- **Source:** https://developer.apple.com/app-store/review/guidelines/#intellectual-property. Quote: "Apps should be submitted by the person or legal entity that owns or has licensed the intellectual property"; and "Authorization must be provided upon request."
- **Why it applies:** Rahma Mohsen's face, name and recipes appear in the app and metadata, while the publisher is the Mahmoud Reda entity.
- **Check:** get a signed image-rights and content licence from Rahma to the publisher entity, ready to upload if Apple asks. The seller and developer name is the publisher only; Rahma is never named as developer.

**C4. Medical accuracy and doctor reminders (1.4.1)** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#physical-harm. Quote: "Apps should remind users to check with a doctor in addition to using the app and before making medical decisions." Accuracy claims must be backed by disclosed methodology.
- **Why it applies:** cycle predictions, pregnancy and postpartum programmes, nutrition.
- **Check:**
  - Already present: `cycleDatesAreEstimatesThisFeatureIs` ("not diagnosis or contraception"), `day1WasNotWrittenForPregnancy`, `thisNeedsADoctorNotAnApp`.
  - Add a general "check with your doctor" line in onboarding (O03 when pregnant or after a birth is chosen), the description and the terms.
  - Never call the cycle forecast "accurate".

**C5. Discrimination and gender-restricted access (1.1.1)** · R or removal; L
- **Sources:**
  - https://developer.apple.com/app-store/review/guidelines/#objectionable-content: discriminatory content about gender, "particularly if the app is likely to humiliate, intimidate, or harm."
  - Precedent: https://www.abc.net.au/news/2026-09-11/giggle-v-tickle-app-founder-denied-high-court-appeal/107142432. The Giggle app lost a discrimination case in Australia; its appeal was refused in September 2026.
- **Why it applies:** the app restricts access by sex, read from the ID card's sex field (`functions/identity/arabic.py`, `decisions.py` returning `REJECTED_NOT_ELIGIBLE`).
- **Check:**
  - Make storefront availability **Egypt only** at launch, to avoid jurisdictions like Australia and the EU.
  - Review Notes state the safety reason (a women-only training space in Egypt).
  - Rejection copy stays neutral and respectful.
  - Have counsel confirm this is lawful under Egyptian law.

**C6. Minimum functionality and iPad support (4.2, 2.4.1)** · BP
- **Source:** https://developer.apple.com/app-store/review/guidelines/
- **Why it applies:** `TARGETED_DEVICE_FAMILY = 1` (iPhone only), so no iPad screenshots are needed. Portrait only.
- **Check:** confirm App Store Connect lists no iPad. The launch build works fully after verification: train, eat, cycle and progress all work offline.

**C7. Dormant features compiled into the binary (2.3.1(a), 2.5.2)** · R if found
- **Source:** https://developer.apple.com/app-store/review/guidelines/#accurate-metadata. Quote: "Don't include any hidden, dormant, or undocumented features."
- **Why it applies:** community, coach, assistant and payments are in the binary but switched off. The planned remote-config flag would switch them on without a new review.
- **Check:**
  - Mention in Review Notes that these features are present but switched off.
  - Turn each one on only in a build submitted with notes describing it, not by remote config alone.
  - The admin console and testing aids (Z14) must be unreachable in release: `adminConsole` is false and `testingAidsAllowed` is false when the account is required. Verify with a release build.

**C8. EU Digital Services Act trader status** · R, as a block on distribution
- **Source:** https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/. Every developer must declare a status, even when not selling in the EU.
- **Check:** in App Store Connect, under Business, then App Information, then the Digital Services Act section: with Egypt-only availability, declare not a trader (or trader if EU sale is planned, which needs a verified address, phone and email).

**C9. Developer contact and code of conduct** · BP
- **Source:** https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- **Check:** App Review contact with a phone number in `+20` format, reachable during review (they may call about the ID gate).

---

## D. [LATER] Before turning on community, coach, assistant or payments

**D1. User-generated content (1.2, updated 6 Feb 2026 and 8 Jun 2026)** · R
- **Sources:**
  - https://developer.apple.com/app-store/review/guidelines/#user-generated-content: content filtering, reporting with timely responses, blocking, published contact details. Developers must remove violating content, and Apple may ask for a compliance plan.
  - https://developer.apple.com/news/?id=d75yllv4: random or anonymous chat is covered by 1.2.
  - https://developer.apple.com/news/?id=a233fmpw: developer responsibility paragraph added.
- **Why it applies:** `features/community` (posts, video, voice notes).
- **Check:** the filter runs before a post goes live; reporting (`report_copy.dart`) reaches a moderation queue with an SLA; blocking works; terms and community standards are in the app. Voice notes stay off until moderation exists, which matches the flag comment.

**D2. Creator content: coach portfolios (1.2.1, 1.2.1(a))** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#user-generated-content
- **Check:** coach content is moderated like user posts. The age restriction is met because the age check verifies 18+.

**D3. Payments for coaching (3.1.1, 3.1.3(d), 3.1.3 intro)** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#payments
  - 3.1.3(d): real-time one-to-one services between two people (fitness training is named) may use other payment methods.
  - "One-to-few and one-to-many real-time services must use in-app purchase."
  - Digital content such as plans, programmes, premium recipes (`recipeTiering`) and the marketplace must use IAP under 3.1.1.
  - Outside the US storefront, the app may not point users to outside payment.
- **Check:** if `payments` or `marketplace` goes live, sort products into live one-to-one sessions (Paymob or Fawry allowed) and everything else (StoreKit). Update 2.3.2 metadata to say what is paid, and adjust account deletion for subscriptions.

**D4. AI assistant (5.1.2(i), 1.4.1, 2.3.1)** · R
- **Source:** https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
- **Check:**
  - Explicit opt-in naming Google Gemini before the first request.
  - Answers about medical topics are refused (the `safety_classifier.dart` design).
  - Add Gemini to the policy and the nutrition label.
  - Don't ship `UnavailableAssistantProvider` visibly. It is hidden today because `assistant` is false; showing it would fail 2.1 completeness.

---

## Priority order before the first submission

A5 (company account), A2 and A3 (finish the site, fix the domain, fill `legal_links.dart`), A1, A6 and B1 (privacy declarations in sync), A4 (reviewer account and notes), C1 (18+), C5 (Egypt-only storefront), C3 (Rahma licence), C8 (DSA declaration), B9 (deletion check on a device), then C2 (screenshots).

One caveat: the onboarding changes from earlier today in the worktree (branch `onboarding/2026-10-06`) are still uncommitted, so the flow behind A4 and B5 is the uncommitted version.

Files referenced:
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/config/legal_links.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/site/config.json`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/ios/Runner/PrivacyInfo.xcprivacy`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/ios/Runner/Info.plist`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/domain/flags/feature_flags.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/account/presentation/your_data_sheet.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/functions/identity/config.py`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/functions/identity/decisions.py`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/app_state/debug_analytics_sink.dart`