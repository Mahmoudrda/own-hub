# Own Hub: what you need to do

Updated 29 October 2026. Only steps you do yourself are listed; everything the coding agent builds is in [docs/plan/RELEASE-2-PLAN.md](../plan/RELEASE-2-PLAN.md). Full reference (every command and App Store Connect input): [LAUNCH-GUIDE.md](LAUNCH-GUIDE.md).

## Already done

- [x] iPhone build **1.0.0 (424738)** built and signed for the App Store: `~/ownhub/app/build/ios/ipa/own_hub.ipa`.
- [x] Firebase deployed on 23 Oct: indexes (3 unused deleted), Firestore and storage rules, all 88 functions. Release 1.1.0 needs a new deploy (below).
- [x] Staff dashboard deployed (Cloudflare Pages `ownhub-reviewers`, security headers live).
- [x] Website deployed on 23 Oct (`own-hub.app`, drawings and coaching privacy sections). The site build has changed since then; see the website decision below.
- [x] Code committed and pushed on `feat/motivation-2026-10-13`. The 1.1.0 code is commit `3d186f4`, pushed.
- [x] Decisions D62 (guest first workout), D63 (coach pays: 15%, 8% for invited clients), D64 (12-month rule for app clients) recorded in `DECISIONS.md` and the release 2 plan.

## Release 1.1.0 with payments ON (owner decision 28 Oct 2026, written 29 Oct 2026)

**This section replaces the order in "Release 1.1.0: do these in order" and the "stays OFF" gates in "Payments by InstaPay" below.** You decided on 28 October that the next release ships with InstaPay payments and online coaching ON. Do these steps in this exact order, from `~/ownhub`. Tick a step only when it is done. The code is written for this plan; nothing here is deployed yet.

**Two dates first.**
- [ ] **Before 31 October 2026 (the day after tomorrow): the PDPC filing.** Controller licence, sensitive-data licence, transfer-abroad permit. Say in it that Own Hub now keeps payment records, receipt screenshots, a coach's national ID number and signed agreement copy, and that Google Cloud Vision (EU) reads receipts. A lawyer can file for you; filing in time is what counts. Details: step 1 of "This week (1.0 items)" below and `docs/owner/INSTAPAY-TERMS-DRAFTS.md` section G.
- [ ] **Before the first coach signs: a lawyer reads the Coach Agreement** (`site/coach-agreement.html`, PDFs `site/coach-agreement.pdf` and `site/ar/coach-agreement.pdf`, questions in `docs/owner/LAWYER-PACK.md` section 11). The conversion fee, the agreed compensation, the hold and the commission wording are `[COUNSEL]` items. You can ship the app first; no coach should accept the agreement in production until the lawyer has read it.

**Release timing.** After the functions deploy, apps older than this build cannot submit a coach application (the server now refuses coach terms version 1). Release the app close to the functions deploy. Also new in this deploy: the daily job `purge_legal_holds`, the `legalHolds` collection and `legal-hold/` storage prefix (server-only, a deleted coach's signed agreement kept 5 years), and a new Firestore index (coachPrivate: agreement.status, agreement.uploadedAt); wait for it to show Enabled.

**Ask Apple first (recommended).** In App Store Connect (Contact Us, or a pre-submission question) send questions 1 to 5 of `docs/owner/PAYMENTS-STORE-POLICY.md` section 5. A rejection on guideline 3.1.3(d) is the main risk of this release. It costs days, not a build (see the last step).

**Steps, in order**
1. [ ] **Check the repo is the release code.** Commit and tests are done by the coding agent; the build must contain the 1.1.0 payment, hold, agreement and chat-screening work. Do not deploy anything from a dirty tree you have not looked at.
2. [ ] **Indexes.** Wait until the console shows all of them Enabled before the next step.
```bash
firebase deploy --only firestore:indexes --project own-hub
```
3. [ ] **Expiry policies.**
```bash
bash firebase/ops/ttl-policies.sh
```
4. [ ] **Firestore rules and storage rules.** Answer yes if the CLI asks to let the Storage rules service read Firestore. If you are not sure, run the IAM grant in LAUNCH-GUIDE step 6.
```bash
firebase deploy --only firestore:rules,storage --project own-hub
```
5. [ ] **Functions.** This is BEFORE the app, not after Apple approves (the order in LAUNCH-GUIDE step 13 is replaced), because the reviewer's account needs the payment code on the server. Side effect, accepted: build 1.0.0 users get the weekly check-in cards that their app hides (LAUNCH-GUIDE step 13 note). Deploy the functions and the rules within minutes of each other.
```bash
firebase deploy --only functions --project own-hub
```
6. [ ] **Staff dashboard** (the switch, the commission and hold views, the agreement check, and the contact-sharing reports are in it). Then re-add the pre-approved numbers with the 18+ tick.
```bash
npx wrangler pages deploy admin-web --project-name ownhub-reviewers
```
7. [ ] **Website.** The corrected privacy page (29 Oct entry: coach ID number, signed copy, receipts, chat screening), the coach terms and the Coach Agreement must be live BEFORE you submit and before the switch goes on, because Apple reads the privacy URL during review. Dry run first, then the real deploy.
```bash
bash site/_build/deploy.sh https://own-hub.app --dry-run
```
```bash
bash site/_build/deploy.sh https://own-hub.app
```
8. [ ] **Own Hub's receiving InstaPay account.** Firebase console, Firestore, collection `coachingConfig`, document `receivingAccounts`: set the map field `instapay` to `{ address: <Own Hub's InstaPay address>, holderName: <the name on that account> }`. Without it a coach's commission bill shows no pay-to address. Then open `coachingConfig/instapay` (if the document exists) and make sure it does not set `feeBpsInvite` to 800: the invite rate is 750 (7.5%) in the code, and a leftover override would silently charge 8%.
9. [ ] **Seed the App Review demo coach and a coaching waiting for payment.** The script is `functions/tools/seed_review_coaching.py`. Order: (a) after the functions deploy, sign in once in the app with the review phone number so the account exists, and read its uid in Firebase console, Authentication; (b) run `cd functions && GOOGLE_CLOUD_PROJECT=own-hub .venv/bin/python -m tools.seed_review_coaching --client-uid <the review account's uid> --project own-hub --i-am-the-owner`. It prints every document, then writes: the demo coach "Own Hub Review Coach" (published but not accepting clients, so members can see her profile and cannot ask to join), a package with 2 live sessions, and a request accepted and waiting for payment for that uid. It creates no payment: the reviewer's Pay now creates it. The demo InstaPay address is `ownhub-review-demo@instapay`, which cannot receive money. Payments must be on (step 10) for the Pay button. The request waits 30 days: seed within a day of submitting, and seed again if review has not started after 3 weeks (or if the review account is deleted and signs up again, with its new uid).
10. [ ] **Turn payments on.** In the staff dashboard, use the payments switch (it writes `config/payments.enabled` = true). Do this before you submit, so the reviewer sees the payment screens. Build 1.0.0 has no payment screens; this is closed in the server: with the switch on, a 1.0.0 member who asks a coach gets `app_update_needed` ("Update Own Hub to ask this coach"), and when a coach accepts an old request from a 1.0.0 member she gets `client_update_needed` and the member gets a push to update. Such a request stays open and lapses after 72 hours. The minimum build is `MIN_APP_BUILD` in `functions/coaching/common.py`.
    - **Note, coach agreement gate.** After the functions deploy, every coach's NEW (non-renewal) requests are refused until she accepts agreement v2 in 1.1.0 and staff verify her signed copy (a 1.0.0 coach sees a generic error). With the counsel-first rule (top of this file) new-client coaching is closed from the deploy until both happen.
    - **Note, the site first.** The site (coach-agreement page and PDFs, privacy page) must be deployed before you submit and before the switch goes on. `own-hub.app/coach-agreement` is a 404 today.
    - **Note, testing from `flutter run`.** A debug build sends appBuild 0 and is refused while payments are on. For an Android or iOS smoke run pass `--dart-define=APP_VERSION=1.1.0+999999`.
11. [ ] **Build the iPhone app.** Version 1.1.0. It runs every check and stops if one fails. First tick Associated Domains for `com.ownhub.fitness` and regenerate the store profile (LAUNCH-GUIDE step 8), and listen to the sound preview (step 2).
```bash
cd ~/ownhub/app && export PATH="$HOME/development/flutter/bin:$PATH" && RELEASE_BASE_URL=https://own-hub.app bash tool/release_preflight.sh && bash tool/build_ios.sh
```
12. [ ] **Upload** `app/build/ios/ipa/own_hub.ipa` with Transporter, then run the Crashlytics symbols command that the build script prints.
13. [ ] **Check on TestFlight, on a real iPhone, with the switch on.** Only a phone proves these.
   - Sign in with the review account. Profile > My coach: the demo coach is waiting for payment; the payment instructions (InstaPay address, exact amount, reference) and the receipt upload open. Fix the screen names in `docs/release/review-notes.md` if they differ.
   - The pay screen says "Pay [coach]" and never "buy", "unlock", "subscribe", "wallet", "balance".
   - The two-phone test (P12): a small real InstaPay transfer from one team phone to a coach phone, with the reference in the note; upload the receipt; the coach confirms; the coach pays the 15% (or 7.5%) bill and records it; staff confirm in the dashboard. Also let one bill pass 7 days in a test account (or move the clock on the emulator) and check the hold and its release.
   - Chat: a phone number, an email, "whatsapp 0100..." and an Instagram handle are blocked with a reason; a workout line such as "3 x 12, 60 kg, rest 90 sec" is not.
   - The coach sheet shows no "See her proof"; the coach never sees the client's receipt.
   - Eat voice logging, sounds, the InBody reader, the guest first workout (LAUNCH-GUIDE step 11).
14. [ ] **App Store Connect, version 1.1.0, manual release.** Build from step 12. Paste: the description, promotional text, subtitle, keywords and What's New from `docs/release/appstore-listing.md` (English and Arabic; have a native Egyptian speaker read the coaching and payment lines); the review-notes box from `docs/release/review-notes.md` with the real test number and code (under 4,000 characters); the screenshots regenerated for the final build (nine per language, including the payment instructions); the App Privacy answers from `docs/release/launch-pack/app-store-privacy-answers.md` (18 types, tick Payment Info, Other Financial Info and Purchase History now). Age rating: Messaging or chat Yes, limited (`appstore-listing.md` section 6).
15. [ ] **Submit.**
16. [ ] **Press Release only after Apple approves.** The server side is already live from steps 2 to 10.

**If Apple rejects (guideline 3.1.1 or 3.1.3 on the payment flow).** You do not need a new build.
1. Reply in the Resolution Center with the 3.1.3(d) reading (`PAYMENTS-STORE-POLICY.md` sections 2 and 4) and ask for a call if needed; or accept the rejection and use the fallback.
2. Fallback: in the staff dashboard turn the payments switch OFF (`config/payments.enabled` = false). The app then shows "Free for now" on coach cards and the pay entry disappears. Coaching itself, chat and plans keep working free. Before you flip it, open the dashboard and confirm or resolve the payments that are waiting, so no member has paid a coach whose access then looks free; the commission bills already issued stay owed.
3. Resubmit the same build with new review notes (`review-notes.md`, delete the PAYMENTS and TO SEE IT lines). If Apple also objects to the InstaPay sentences in the description, delete those two lines in App Store Connect (no build needed).
4. Then ask Apple the questions in `PAYMENTS-STORE-POLICY.md` section 5 before you turn the switch on again.

**After release.** Re-run the checks in `docs/release/release-checklist.md`; watch the dashboard Fees tab for coaches on hold; empty the `store-reviewer-phones` secret when the review closes; send Google the three Play questions (6 to 8) before any Android payments release.

**Known gaps to remember (as of 29 Oct).** The live-session minimum, the coach-agreement gate, the marketing-video card, the commission bills and the hold are built. What is still open is in the steps above and in the owner tracks.

## Release 1.1.0: do these in order (28 Oct 2026) (SUPERSEDED by the section above)

Each command is in [LAUNCH-GUIDE.md](LAUNCH-GUIDE.md), section "Release 1.1.0". Payments were planned to stay off; the 28 Oct decision puts them ON (section above).

- [ ] **Check the status of 1.0.** Build 424738 is not recorded as approved here. Check App Store Connect before you submit 1.1.0.
- [ ] **Decide the website** (see below).
- [ ] **Listen to the sound preview**, you and Rahma, before the build (LAUNCH-GUIDE step 2).
- [ ] **Deploy Firebase and the dashboard** (LAUNCH-GUIDE steps 3 to 7). Deploy the rules even if you did it earlier today.
- [ ] **Tick Associated Domains** for `com.ownhub.fitness` and regenerate the store profile, before the build (step 8).
- [ ] **Build, upload and check on TestFlight** (steps 9 to 11).
- [ ] **1.1.0 description and review notes: written 29 Oct** (`docs/release/appstore-listing.md`, `docs/release/review-notes.md`), for payments ON. Read the OWNER TO CONFIRM list in the review notes before pasting.
- [ ] **Submit** in App Store Connect with manual release (step 12).
- [ ] **After Apple approves and before Release**, deploy the functions (step 13). Then press Release (step 14).
- [ ] **Deploy the website** in the same window as Release (step 15).
- [ ] **Before 1.1.0 is final:** a native Egyptian Arabic read of the 21 new strings (voice logging and the InBody reader), and the dietitian check of the food golden table (only 1 of 252 foods is verified against USDA so far) and of the pregnancy and lactation calories.

### Website: a decision for you

Counsel has not signed the payment texts. The privacy page must go live with 1.1.0, because it now describes voice logging and the InBody reader. The same site build also carries the payment sections. Choose one and tick it:
- [ ] **(a)** Get counsel's sign-off on the payment sections first, then deploy the site with the release.
- [ ] **(b)** Deploy the site with the release anyway. The payment sections of the privacy policy will then be live before payments are on.

Either way the website and the app release go out together, never one without the other. The privacy page that is live today has no InstaPay text, so the corrected privacy page, terms and coach terms must be live before `config/payments.enabled` is ever set to true.

### Description and review notes: SUPERSEDED, written 29 Oct for payments ON (the two lines below describe the old state)

- [ ] **App Store description.** The 1.1.0 screenshots include coach chat and coach plan, so the description must mention coaching. `docs/release/appstore-listing.md` says "no coaching", and `docs/release/launch-pack/store-listing-copy.md` predates voice logging, the InBody reader and payments. Ask the coding agent for the 1.1.0 description before you paste.
- [ ] **Review notes.** `docs/release/review-notes.md` is still the 23 Oct text. It says there are no payments and that payments cannot be turned on remotely. Ask the coding agent to update it for 1.1.0 (under 4,000 characters).

## This week (1.0 items)

### 1. Before 31 October 2026: file with the data protection regulator (most urgent)
- [ ] On the Personal Data Protection Center (PDPC) portal, log in through Digital Egypt with your national ID, and file for:
  - a **controller licence** (Own Hub processes members' personal data);
  - a **sensitive-data licence** (health data, and the selfie-to-ID face match);
  - a **transfer-abroad licence or permit** (Google Cloud and Vertex AI in Frankfurt, PostHog in the United States, Crashlytics).
- [ ] Say in the filing that Own Hub now also keeps **payment and financial records** (payment records, transaction numbers, bank screenshots sent as proof, a coach's InstaPay address, strikes) and that **Google Cloud Vision (European Union)** reads those screenshots. Give your lawyer `docs/owner/INSTAPAY-TERMS-DRAFTS.md` section G.
- [ ] The regulator has 90 working days to decide: filing before the deadline is what matters. A lawyer can file for you.
- Why: the grace period of Law 151/2020 and Decree 816/2025 ends on 31 October 2026 (some sources say 1 November). Processing sensitive data or sending data abroad without a licence carries prison and fines of EGP 500k to 5m.

### 2. App Store Connect (the 1.0 page)
- [ ] Make sure build **424738** was delivered with Transporter and is selected on the 1.0 page.
- [ ] **App Privacy** (can be edited without a new build), add or update:
  - Contact Info > **Name**: linked, not tracking, App Functionality. A woman who applies to coach gives her full name for the review; a member who asks to join a coach may give her first name, which only that coach sees.
  - Identifiers > **Device ID**: also "PostHog's anonymous id, only with her consent to usage statistics".
  - Usage Data > **Product Interaction**: "Google Analytics and PostHog (hosted in the United States), only if she turns on Help improve Own Hub".
  - User Content > **Emails or Text Messages**: linked, not tracking, App Functionality (coach chat).
- [ ] **Header and Search Results** images (optional, PNG): `~/ownhub/.claude/handoff-store-pass/store-creatives/`
  - Header: `header-en-3840x1646.png` (English), `header-ar-3840x1646.png` (Arabic).
  - Search Results: `search-en-3840x2560.png`, `search-ar-3840x2560.png`.
- [ ] **Screenshots** if a slot is still empty: the size folder that matches the slot in `~/ownhub/.claude/handoff-store-pass/screenshots-upload/` (`1206x2622` for "iPhone with Dynamic Island (medium display)", or `1179x2556`, `1290x2796`, `1284x2778`), 9 files per language, in name order. Google Play: `play-1080x1920` in the same place (8 per language, PNG). Screenshots 07 to 09 show coaching, so make sure the store description mentions it too (`docs/release/appstore-listing.md` still says "no coaching" in its old 1.0 text).
- [ ] If Apple asks about the reviewer account: the test number must be in the `store-reviewer-phones` secret and in Firebase "Phone numbers for testing" with its code.
- [ ] Review notes: the notifications sentence was corrected on 23 Oct (`docs/release/review-notes.md`: reminders are scheduled on the phone; the server sends only the check result and generic coaching alerts). If App Store Connect still lets you edit the notes, paste the new box; if not, use it for the next version.
- Note: the store description cannot change while 1.0 is in review. For 1.1.0, see the description item above.

### 3. Website (see the decision above)
- [ ] Read the changed privacy policy, terms and coach terms in English and Arabic before you deploy. They are built but not deployed. The commands are in LAUNCH-GUIDE, Release 1.1.0, step 15.
- [ ] Hold until the website decision above is made.
- [ ] Paste the SHA-256 of the Play App Signing key (Play Console, Setup, App signing) and of the upload key into `site/.well-known/assetlinks.json`, then redeploy the site. Until then Android opens these links in the browser (the /join page), not the app.

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
- [ ] App Check: once the new build is live and the metrics show verified traffic, press Enforce for Cloud Firestore and Cloud Storage. The payment functions check App Check themselves; this step is for the two databases.
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

## Payments by InstaPay: built in 1.1.0 (the "OFF" gates here are SUPERSEDED on 28 Oct 2026: payments ship ON; P2 counsel sign-off, P5, P6, P7 and P12 are still the right checklist, now before the first real payment, not before the switch)

Payments are built into 1.1.0 but stay off. The member pays the coach's own InstaPay address; Own Hub never holds the money. Your off-switch is `config/payments.enabled` on the server (the document `config/payments`; if it is missing, payments are off). While it is off, the app shows "Free for now". The full rules are in `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` section 12. Do not set the switch until P2, P5, P6, P7 and P12 are done.

- [ ] **P1. Before 31 October 2026: PDPC filing.** See step 1 above (payment data and Google Cloud Vision added).
- [ ] **P2. Counsel sign-off.** Give counsel `docs/owner/INSTAPAY-TERMS-DRAFTS.md` (clauses, questions, and the table of claims that must match the build), and the six built pages: `site/privacy.html`, `terms.html`, `coach-terms.html` and their `ar/` twins. Counsel also decides whether existing members and coaches must accept the new terms again (the app's terms and privacy version numbers are 3 and are not changed yet). The payment texts are not signed, so the website decision above applies.
- [ ] **P3. Decide the numbers** (spec 12.4 to 12.6): how long payment records and screenshots are kept (the site says 90 days for screenshots), the fee rates (the site says 15% and 7.5%), whether a coach silent for 48 hours gives the member short access (default yes), the staff review target (default two working days), and which women review disputes.
- [ ] **P4. InstaPay limits.** Look up the current InstaPay per-transfer and daily limits and set the maximum package price below them (the code has a placeholder of 20,000 EGP).
- [ ] **P5. Apple and Google payment rules.** Read `docs/owner/PAYMENTS-STORE-POLICY.md`. Recommended: ask Apple in a pre-submission question (questions 1 to 5) before you submit; ask Google (questions 6 to 8) before the Play release. Check the review-notes paragraph there against the real build, and make the cuts it lists.
- [ ] **P6. Store privacy answers, and a new build.** The app's privacy file and the Play data safety file do not declare payment data yet. So turning payments on needs a new build with those changes (the coding agent's work order WO-10j3), then the store answers. In App Store Connect add Payment Info, Other Financial Info and Purchase History. In Google Play add the Financial info block. Exact lists: `docs/owner/PAYMENTS-STORE-ANSWERS.md`. With the switch off, tick nothing for payments.
- [ ] **P7. Company, tax, the fee and the receiving account.** Rahma and any coach who is paid needs her own tax status. Own Hub needs a lawful way to receive its fee from coaches (commercial registration and tax card, or the company; see "Before paid coaching opens"). The first monthly fee statement is made on the 1st of the month after the first confirmed payment, so have this settled before then. The InstaPay address for Own Hub's fee goes in `coachingConfig/receivingAccounts.instapay` (`address` and `holderName`). Fill it before that first statement, or the statement shows no pay-to address. The fee owed is only collected by the coach paying it to you and recording it.
- [ ] **P8. Firebase Storage rules need permission to read Firestore.** The storage rules for chat media and payment proofs look up documents in Firestore. When you deploy the storage rules, the Firebase CLI asks whether to grant the role "Firebase Rules Firestore Service Agent" to the Firebase Storage service account (an account ending `@gcp-sa-firebasestorage.iam.gserviceaccount.com`, here `service-681714989950@gcp-sa-firebasestorage.iam.gserviceaccount.com`). Answer yes. If it is not asked, in Google Cloud console, IAM, tick "Include Google-provided role grants", find that account and add the role of that name. Without it, those storage reads fail even though the rules look right. Check IAM first: it may already be granted. This is the same grant as step 5 and 6 of the 1.1.0 release.
- [ ] **P9. Android and iPhone links.** Paste the SHA-256 of the Play App Signing key and the upload key into `site/.well-known/assetlinks.json`, and tick Associated Domains for `com.ownhub.fitness` and regenerate the store profile (step 8 of the 1.1.0 release). Coach invite links need both.
- [ ] **P10. Order of work.** The release order is in LAUNCH-GUIDE, Release 1.1.0, steps 1 to 16. The switch is not one of those steps. Set `config/payments.enabled` only after the gates above, the two-phone test (P12), and after the corrected privacy page, terms and coach terms are live on the website (the site and the app release go out together). Whether Apple's reviewers need payments switched on to test the app is not settled. Ask it in the P5 questions before you submit.
- [ ] **P11. App Check.** Enforce it for Firestore and Storage only after the new build is live and the console shows verified traffic (step 5 above).
- [ ] **P12. Real transfer test.** Two team phones, a small real InstaPay transfer with the reference code in the note, through every payment screen on iPhone and Android (spec section 7, item 7). Before the test, both phones must turn on "Turn on payment alerts" in the app, or they get no payment notifications. Check that receipt photos are read. Do not set `config/payments.enabled` until this passes.
- [ ] **P13. Receipts for the reader.** Send the coding agent a few real bank receipts (name, phone and account digits hidden) when you have them. They are test samples, not a launch requirement.

## Before paid coaching opens

These apply before you switch payments on (the payments section above), not after.

- [ ] **Form a company** (commercial registration, tax card, business bank account); move the Apple developer account to it and open Google Play as an organisation. Apple asks that apps with health data come from a legal entity; payment providers and the consumer law need the registration and tax card.
- [ ] Appoint and register a data protection officer (required for a company).
- [ ] Sign data processing terms with Google Cloud and PostHog; keep a record of processing (PDPC templates); write a breach plan (regulator within 72 hours, members within 3 working days) and name who is on call.
- [ ] ~~Choose the licensed payment provider (Paymob or Fawry)~~: replaced on 27 Oct. Members pay coaches directly by InstaPay and Own Hub holds no money. A licensed provider and installments (valU, Sympl) are a later release, if ever.
- [ ] Get written releases from Rahma (name, image, welcome video, recipe book) and from the woman in the exercise clips.
- [ ] Rahma confirms the allergens of her 39 recipes (allergen sign-off sheet) and the plan, tags and load ladder.
- [ ] Ask your lawyer (the full list is in the release 2 plan, section 3.9 A4):
  - Does "the member pays the coach directly by InstaPay, Own Hub handles no money and records and governs the payment" stay outside the Central Bank payment-service rules? (The full counsel list is in `docs/owner/INSTAPAY-TERMS-DRAFTS.md` section E; it replaces the old "Own Hub sells, keeps 15% from the payout" question.)
  - When does the 14-day withdrawal start for coaching, and can a refund be reduced for sessions already held?
  - Withholding tax on coach payouts (3% or 5%), and the VAT threshold on gross turnover.
  - Will the 12-month rule and the 3-month penalty (D64) hold? (Own Hub no longer pays coaches out, so nothing can be taken from payouts: the coach pays Own Hub's fee herself.)
  - Women-only service and Penal Code Art. 161 bis; Media Regulator Decree 26/2020; where coaching on pregnancy, postpartum or allergies becomes medical advice.

## Rahma's coach web app (separate product, not in the app release)

Its own folder is `~/rahma-coach`, with local git only (not pushed). It is live on Cloudflare Pages at https://rahma-coach.pages.dev, with D1 (EU) and Workers AI, and no R2. Its secrets are in `~/rahma-coach-secrets.txt` (mode 600). Keep that file private.

Set it up in this order:
- [ ] **1.** Attach your subdomain in the Cloudflare dashboard: Workers & Pages, `rahma-coach`, Custom domains.
- [ ] **2.** Set the allowed hosts. This replaces the whole list. Put your final domain in place of `<final-host>`. Keep `rahma-coach.pages.dev` in the list only if you want it.
```bash
printf %s "<final-host>" | npx wrangler pages secret put ALLOWED_HOSTS --project-name rahma-coach
```
- [ ] **3.** Deploy.
```bash
cd ~/rahma-coach && bash scripts/deploy.sh
```
- [ ] **4.** Rahma opens the final domain on her phone, enters the setup code, and registers her passkey with Face ID. Do not register on `rahma-coach.pages.dev`.
- [ ] **5.** Delete the setup code, then run step 3 again.
```bash
npx wrangler pages secret delete SETUP_CODE --project-name rahma-coach
```

Before it holds real client data, all of these must be done:
- [ ] Rahma tests the InBody reader on 20 real sheets. Only synthetic sheets have been tested so far. She confirms every scan on the confirm screen.
- [ ] Rahma blind-reviews the Arabic of the AI drafts.
- [ ] An Egyptian lawyer reviews the consent text (marked DRAFT), and the PDPC filing covers the web app.
- [ ] Accept Cloudflare's data-processing agreement. Egypt's data law enforcement starts around 31 Oct 2026.
- [ ] Rahma checks the recipe calories. The web app computes them from the food rows, and four recipes differ from the printed recipe book: cheese cake 377 vs 187, lahma bel basal 596 vs 401, shakshuka 366 vs 248, ful and ta'amiya 552 vs 434.

Cost: expected 0 dollars a month. To check usage, open the Cloudflare dashboard, Workers AI. The free tier gives 10,000 neurons a day; one meal draft uses about 85.

- [ ] Delete the dev export and the scratch folder, which are no longer needed. Run these yourself:
```bash
rm ~/Downloads/rahma-coach-export-2026-10-28.json
```
```bash
rm -r ~/ownhub/.claude/tmp-ocr-sheets
```

## Open decisions (release 2 plan, section 4)

- [ ] 4. Will Rahma record or approve end-of-workout lines?
- [ ] 5. Retention periods (proposed: chat 12 months after the coaching ends; intake 30 days after; rejected applications 6 months; reports and blocks 2 years; unused pre-approved numbers 90 days).
- [x] 6. Paid coaching store model: decided 27 Oct. Packages built around live one-to-one sessions, paid directly to the coach by InstaPay, no in-app purchase. The store reading and the fallback are in `docs/owner/PAYMENTS-STORE-POLICY.md`; step P5 asks the stores.
- [ ] 7. When to form the company and move the store accounts.
- [ ] 8. Who may approve new members: women reviewers only, or administrators too (today the code lets an administrator approve; the privacy policy now says so).
- [ ] Can reviewers open a chat that a member reported? Today they cannot. The owner and counsel decide.

## Phase two (release 2)

- Hand [docs/plan/RELEASE-2-PLAN.md](../plan/RELEASE-2-PLAN.md) to the coding agent. Its section 6 is the order of work: the PDPC filing (you), the coach health-flag safety fix and the consent fixes first, then one clear next step on Home and Train, fewer steps to the first workout (D62), the live workout and warm moments, the coaching screens and the coach price text (D63), then the InstaPay payments (built in 1.1.0 and off; spec `docs/plan/INSTAPAY-PAYMENTS-SPEC.md`: fees D63, the rule D64, disputes, refunds), which goes live only after the steps in "Payments by InstaPay" (P1 to P13).

## Where things are

| What | Where |
|---|---|
| This list | `docs/owner/OWNER-TODO.md` |
| Release 1.1.0 commands and order | `docs/owner/LAUNCH-GUIDE.md`, section "Release 1.1.0" |
| Full launch guide (commands, App Store Connect inputs, Google Play, security sign-off) | `docs/owner/LAUNCH-GUIDE.md` |
| Release 2 plan for the coding agent | `docs/plan/RELEASE-2-PLAN.md` |
| InstaPay payments spec | `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` |
| Terms drafts, questions and claims table for counsel | `docs/owner/INSTAPAY-TERMS-DRAFTS.md` |
| Apple and Google payment rules, risks, review-notes paragraph | `docs/owner/PAYMENTS-STORE-POLICY.md` |
| App Store and Play privacy answers for payments (only when payments switch on) | `docs/owner/PAYMENTS-STORE-ANSWERS.md` |
| App Store and Play privacy answers for 1.1.0 | `docs/release/launch-pack/app-store-privacy-answers.md` |
| Review notes for App Review (23 Oct text, needs the 1.1.0 update) | `docs/release/review-notes.md` |
| Sound preview for 1.1.0 | the scratch path in LAUNCH-GUIDE, step 2 |
| Rahma's coach web app (local folder, not pushed) | `~/rahma-coach` |
| Rahma's coach web app secrets (keep private) | `~/rahma-coach-secrets.txt` |
| Owner decisions D1 to D64 | `DECISIONS.md` (on this Mac only) |
| App Store header and search images | `.claude/handoff-store-pass/store-creatives/` (this Mac only) |
| Screenshots in every iPhone size | `.claude/handoff-store-pass/screenshots-upload/` (this Mac only) |
| Original App Store screenshots | `docs/release/launch-pack/screenshots/apple-6.9/` |
| Google Play icon, feature graphic, screenshots | `docs/release/launch-pack/` |
| Reference screenshots from top apps | `.claude/feature-briefs/references/app-store/` (this Mac only) |
