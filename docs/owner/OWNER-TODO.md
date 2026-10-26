# Own Hub: what you need to do

Updated 23 October 2026. Only steps you do yourself are listed; everything the coding agent builds is in [docs/plan/RELEASE-2-PLAN.md](../plan/RELEASE-2-PLAN.md). Full reference (every command and App Store Connect input): [LAUNCH-GUIDE.md](LAUNCH-GUIDE.md).

## Already done

- [x] iPhone build **1.0.0 (424738)** built and signed for the App Store: `~/ownhub/app/build/ios/ipa/own_hub.ipa`.
- [x] Firebase deployed: indexes (3 unused deleted), Firestore and storage rules, all 88 functions.
- [x] Staff dashboard deployed (Cloudflare Pages `ownhub-reviewers`, security headers live).
- [x] Website deployed (`own-hub.app`, drawings and coaching privacy sections).
- [x] Code committed and pushed on `feat/motivation-2026-10-13`.
- [x] Decisions D62 (guest first workout), D63 (coach pays: 15%, 8% for invited clients), D64 (12-month rule for app clients) recorded in `DECISIONS.md` and the release 2 plan.

## This week

### 1. Before 31 October 2026: file with the data protection regulator (most urgent)
- [ ] On the Personal Data Protection Center (PDPC) portal, log in through Digital Egypt with your national ID, and file for:
  - a **controller licence** (Own Hub processes members' personal data);
  - a **sensitive-data licence** (health data, and the selfie-to-ID face match);
  - a **transfer-abroad licence or permit** (Google Cloud and Vertex AI in Frankfurt, PostHog in the United States, Crashlytics).
- [ ] The regulator has 90 working days to decide: filing before the deadline is what matters. A lawyer can file for you.
- Why: the grace period of Law 151/2020 and Decree 816/2025 ends on 31 October 2026 (some sources say 1 November). Processing sensitive data or sending data abroad without a licence carries prison and fines of EGP 500k to 5m.

### 2. App Store Connect (while Apple reviews 1.0)
- [ ] Make sure build **424738** was delivered with Transporter and is selected on the 1.0 page.
- [ ] **App Privacy** (can be edited without a new build), add or update:
  - Contact Info > **Name**: linked, not tracking, App Functionality. A woman who applies to coach gives her full name for the review; a member who asks to join a coach may give her first name, which only that coach sees.
  - Identifiers > **Device ID**: also "PostHog's anonymous id, only with her consent to usage statistics".
  - Usage Data > **Product Interaction**: "Google Analytics and PostHog (hosted in the United States), only if she turns on Help improve Own Hub".
  - User Content > **Emails or Text Messages**: linked, not tracking, App Functionality (coach chat).
- [ ] **Header and Search Results** images (optional, PNG): `~/ownhub/.claude/handoff-store-pass/store-creatives/`
  - Header: `header-en-3840x1646.png` (English), `header-ar-3840x1646.png` (Arabic).
  - Search Results: `search-en-3840x2560.png`, `search-ar-3840x2560.png`.
- [ ] **Screenshots** if a slot is still empty: the size folder that matches the slot in `~/ownhub/.claude/handoff-store-pass/screenshots-upload/` (`1206x2622` for "iPhone with Dynamic Island (medium display)", or `1179x2556`, `1290x2796`, `1284x2778`), 9 files per language, in name order.
- [ ] If Apple asks about the reviewer account: the test number must be in the `store-reviewer-phones` secret and in Firebase "Phone numbers for testing" with its code.
- [ ] Review notes: the notifications sentence was corrected on 23 Oct (`docs/release/review-notes.md`: reminders are scheduled on the phone; the server sends only the check result and generic coaching alerts). If App Store Connect still lets you edit the notes, paste the new box; if not, use it for the next version.
- Note: the store description cannot change while 1.0 is in review. The corrected wording for the next version is in `docs/release/launch-pack/store-listing-copy.md`.

### 3. Deploy the corrected website (after the 23 Oct legal text fixes are finished)
- [ ] In the Apple developer portal, App ID `com.ownhub.fitness`, tick Associated Domains, regenerate the store profile, then `app/tool/build_ios.sh`.
- [ ] Paste the SHA-256 of the Play App Signing key (Play Console, Setup, App signing) and of the upload key into `site/.well-known/assetlinks.json`, then redeploy the site. Until then Android opens these links in the browser (the /join page), not the app.
- [ ] Read the changed privacy policy, terms and coach terms in English and Arabic, then deploy:
```bash
~/ownhub/site/_build/deploy.sh https://own-hub.app --dry-run
```
```bash
~/ownhub/site/_build/deploy.sh https://own-hub.app
```

### 4. Check the dashboard signed in
- [ ] Open https://ownhub-reviewers.pages.dev in your normal Chrome or Safari, sign in as the reviewer, open Verification, then Coaches (an application photo and a certificate PDF), then Portfolio photos. If something stays blank, roll back in Cloudflare (Pages, `ownhub-reviewers`, Deployments) and send the console line that starts with "Refused to".

### 5. Console settings for security and cost (step 3 of the launch guide)
- [ ] SMS sign-in to Egypt only (biggest bill risk):
```bash
curl -X PATCH -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "X-Goog-User-Project: own-hub" -H "Content-Type: application/json" "https://identitytoolkit.googleapis.com/admin/v2/projects/own-hub/config?updateMask=smsRegionConfig" -d '{"smsRegionConfig":{"allowlistOnly":{"allowedRegions":["EG"]}}}'
```
- [ ] Budget alert (replace `BILLING_ID`, find it with `gcloud billing accounts list`):
```bash
gcloud billing budgets create --billing-account=BILLING_ID --display-name=own-hub --budget-amount=100USD --threshold-rule=percent=0.5 --threshold-rule=percent=0.9
```
- [ ] Cleanup of old server images, expired data and deleted files:
```bash
firebase functions:artifacts:setpolicy --location europe-west3 --days 1 --project own-hub
```
```bash
bash ~/ownhub/firebase/ops/ttl-policies.sh
```
```bash
gcloud storage buckets update gs://own-hub-personal --clear-soft-delete
```
- [ ] Firebase console, Authentication, Settings, Authorized domains: remove `localhost`.
- [ ] Google Cloud console, Credentials: restrict each API key (Android: package `com.ownhub.app` with both SHA-1s; iOS: bundle `com.ownhub.fitness`; browser: `own-hub.app`, `ownhub-reviewers.pages.dev`, `own-hub.firebaseapp.com`; Firebase APIs only). Test sign-in on the phone and the dashboard right after.
- [ ] App Check: once the new build is live and the metrics show verified traffic, press Enforce for Cloud Firestore and Cloud Storage.
- [ ] Cloudflare: turn on the access policy for preview deployments of `ownhub-reviewers`; consider Cloudflare Access with email codes in front of the dashboard.

### 6. Crash symbols
```bash
cd ~/ownhub/app && firebase crashlytics:symbols:upload --app=1:681714989950:ios:02417d9df27fbcf2fbd12f build/symbols/1.0.0+424738-ios
```

### 7. Ten minutes on your iPhone (TestFlight, build 424738)
- [ ] Screen stays on during a workout; one buzz when rest ends with the app open.
- [ ] Notifications: allow them, set training days, skip one: a friendly note arrives the next day.
- [ ] ID screen is covered in the app switcher.
- [ ] As a coach, an upright photo stays upright after approval.
- [ ] Profile, Become a coach opens the application; Train, Find a coach opens.

### 8. Google Play: start the account now (it takes weeks)
- [ ] Create the developer account at play.google.com/console/signup. An **organisation** account (needs a free D-U-N-S number) likely avoids the rule for new **personal** accounts: a closed test with at least 12 testers for 14 days in a row before you can publish.
- [ ] Then follow "Google Play, step by step" in [LAUNCH-GUIDE.md](LAUNCH-GUIDE.md) (create the app, internal test, Firebase fingerprints, App content, listing, closed test, production in Egypt).
- [ ] Reviewer account: Google needs it working at all times, so keep the reviewer number in the `store-reviewer-phones` secret and use a number and code that are hard to guess (not 0001 or 123456).

## Before paid coaching opens

- [ ] **Form a company** (commercial registration, tax card, business bank account); move the Apple developer account to it and open Google Play as an organisation. Apple asks that apps with health data come from a legal entity; payment providers and the consumer law need the registration and tax card.
- [ ] Appoint and register a data protection officer (required for a company).
- [ ] Sign data processing terms with Google Cloud and PostHog; keep a record of processing (PDPC templates); write a breach plan (regulator within 72 hours, members within 3 working days) and name who is on call.
- [ ] Choose the licensed payment provider (Paymob or Fawry), including installments (valU, Sympl).
- [ ] Get written releases from Rahma (name, image, welcome video, recipe book) and from the woman in the exercise clips.
- [ ] Rahma confirms the allergens of her 39 recipes (allergen sign-off sheet) and the plan, tags and load ladder.
- [ ] Ask your lawyer (the full list is in the release 2 plan, section 3.9 A4):
  - Does "Own Hub sells, coach is a contractor, Own Hub keeps 15% from the payout" avoid the Central Bank payment-facilitation rules?
  - When does the 14-day withdrawal start for coaching, and can a refund be reduced for sessions already held?
  - Withholding tax on coach payouts (3% or 5%), and the VAT threshold on gross turnover.
  - Will the 12-month rule and the 3-month penalty (D64) hold, and can it be taken from payouts?
  - Women-only service and Penal Code Art. 161 bis; Media Regulator Decree 26/2020; where coaching on pregnancy, postpartum or allergies becomes medical advice.

## Open decisions (release 2 plan, section 4)

- [ ] 4. Will Rahma record or approve end-of-workout lines?
- [ ] 5. Retention periods (proposed: chat 12 months after the coaching ends; intake 30 days after; rejected applications 6 months; reports and blocks 2 years; unused pre-approved numbers 90 days).
- [ ] 6. Paid coaching store model: packages built around live one-to-one calls (outside payment allowed) or in-app purchase and Play Billing.
- [ ] 7. When to form the company and move the store accounts.
- [ ] 8. Who may approve new members: women reviewers only, or administrators too (today the code lets an administrator approve; the privacy policy now says so).

## Phase two (release 2)

- Hand [docs/plan/RELEASE-2-PLAN.md](../plan/RELEASE-2-PLAN.md) to the coding agent. Its section 6 is the order of work: the PDPC filing (you), the coach health-flag safety fix and the consent fixes first, then one clear next step on Home and Train, fewer steps to the first workout (D62), the live workout and warm moments, the coaching screens and the coach price text (D63), then the payments-phase work (fees D63, the rule D64, guarantees) once counsel and the payment provider are ready.

## Where things are

| What | Where |
|---|---|
| This list | `docs/owner/OWNER-TODO.md` |
| Full launch guide (commands, App Store Connect inputs, Google Play, security sign-off) | `docs/owner/LAUNCH-GUIDE.md` |
| Release 2 plan for the coding agent | `docs/plan/RELEASE-2-PLAN.md` |
| Owner decisions D1 to D64 | `DECISIONS.md` (on this Mac only) |
| App Store header and search images | `.claude/handoff-store-pass/store-creatives/` (this Mac only) |
| Screenshots in every iPhone size | `.claude/handoff-store-pass/screenshots-upload/` (this Mac only) |
| Original App Store screenshots | `docs/release/launch-pack/screenshots/apple-6.9/` |
| Google Play icon, feature graphic, screenshots | `docs/release/launch-pack/` |
| Reference screenshots from top apps | `.claude/feature-briefs/references/app-store/` (this Mac only) |
