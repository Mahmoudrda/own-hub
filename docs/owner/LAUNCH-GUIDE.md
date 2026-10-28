# Own Hub launch guide

> Reference copy of the launch guide, saved 23 Oct 2026. Many steps below are already done (commit, Firebase deploy, dashboard, website, build 424738 uploaded). What is left, with dates, is in [OWNER-TODO.md](OWNER-TODO.md). The phase two plan for the coding agent is [docs/plan/RELEASE-2-PLAN.md](../plan/RELEASE-2-PLAN.md).

## Release 1.1.0: what to run (28 Oct 2026)

Final state of 1.1.0, checked 28 Oct 2026. Run each block from `~/ownhub`. Each code block holds one command. Run the steps in order.

**Payments stay OFF in 1.1.0.** The app has every payment screen: the coach Payments inbox, the three decisions (I received it, Not received, Different amount), refunds and service problems, cancel payment, the monthly fee statement with Mark fee as paid, the payment-record image, taps on payment notifications, and the "Turn on payment alerts" card. Payment notifications reach only the phones that turned that card on. While payments are off, members see "Free for now".

Do not set `config/payments.enabled` until all four gates are met. The full list is in [OWNER-TODO.md](OWNER-TODO.md), section "Payments by InstaPay".
- Counsel has signed off the payment texts (`docs/owner/INSTAPAY-TERMS-DRAFTS.md`).
- A real two-phone InstaPay transfer has passed.
- The Apple and Google payment-policy check is done.
- `coachingConfig/receivingAccounts.instapay` has `address` and `holderName` filled in. Fill it before the first monthly statement, or the statement shows no pay-to address.

**What's new (App Store Connect, English)**
- Send photos, short videos and voice notes to your coach in chat.
- Your coach can send a plan for several weeks and a meal plan, ready in Train and Eat.
- A one-minute weekly check-in goes straight to your coach.
- Safer calorie targets: no target is shown when you should check in with your coach or a doctor first.
- Say what you ate, then check the words before you log them.
- Read your InBody sheet with the camera for a macro suggestion. It is read on your phone, and the photo is not kept.
- Try your first workout without making an account.
- A walking session, for the days you want to move gently.
- A warm finish after each workout.
- Short sounds during your workout. You can turn them off in Profile.
- Cooked lentils are now in the food list.

**What's new (Arabic)**
- ابعتي صور وفيديوهات ورسايل صوتية لمدربتك في الشات.
- مدربتك تقدر تبعتلك برنامج تمرين لكذا أسبوع وخطة أكل، وتلاقيها جاهزة في تمرين وأكل.
- تقييم أسبوعي سريع في دقيقة بيوصل لمدربتك.
- أهداف سعرات أأمن، ومفيش هدف بيظهر لو محتاجة تتابعي مع مدربتك أو دكتورة الأول.
- سجّلي أكلك بصوتك، وراجعي الكلام قبل ما يتسجّل.
- صوّري ورقة الـ InBody واخدي اقتراح للماكروز. التطبيق بيقرا الورقة على موبايلك، والصورة مش بتتحفظ.
- جرّبي أول تمرين من غير ما تعملي حساب.
- جلسة مشي للأيام اللي تحبي تتحركي فيها براحة.
- ختام دافي بعد كل تمرين.
- أصوات خفيفة وإنتي بتتمرني، وتقدري تقفليها من البروفايل.
- أضفنا العدس المطبوخ لقائمة الأكل.

1. Disk: the iOS build needs about 8 GB free.
```bash
df -h /
```
2. Listen to the sound preview before the build. Sounds are on by default, so you and Rahma should hear the mix first. A change means a new build. The file is `/private/tmp/claude-501/-Users-mahmoudreda-ownhub/d1ee3614-0346-4787-9e01-c3e33b801d7d/scratchpad/own_hub_sounds_preview.m4a`. It is a scratch file. If it has gone, ask the coding agent to make it again.
3. Indexes. Wait until the console shows all of them as Enabled before step 4.
```bash
firebase deploy --only firestore:indexes --project own-hub
```
4. Expiry policies.
```bash
bash firebase/ops/ttl-policies.sh
```
5. Rules and storage. The chat-media storage rules read Firestore, so answer yes if the CLI asks to let the Storage rules service read Firestore. The rules changed again for the payment-alert opt-in, so deploy them even if you did this earlier today.
```bash
firebase deploy --only firestore:rules,storage --project own-hub
```
6. Storage service-agent grant. Run it after step 5. If the CLI asked and you answered yes, the grant is already in place and you can skip this. If you are not sure, check IAM first.
```bash
gcloud projects add-iam-policy-binding own-hub --member="serviceAccount:service-681714989950@gcp-sa-firebasestorage.iam.gserviceaccount.com" --role="roles/firebaserules.firestoreServiceAgent"
```
7. Staff dashboard. It has not changed since its first deploy on 23 Oct, so deploy it only if you have not deployed it since then. Then re-add the pre-approved numbers with the 18+ tick.
```bash
npx wrangler pages deploy admin-web --project-name ownhub-reviewers
```
8. Apple Developer: App ID `com.ownhub.fitness`, tick Associated Domains and regenerate the store profile. Do this before the build.
9. Build the iPhone app. It runs every check first and stops if one fails.
```bash
cd ~/ownhub/app && export PATH="$HOME/development/flutter/bin:$PATH" && RELEASE_BASE_URL=https://own-hub.app bash tool/release_preflight.sh && bash tool/build_ios.sh
```
10. Upload `app/build/ios/ipa/own_hub.ipa` with Transporter. Then run the Crashlytics symbols command that the build script prints.
11. TestFlight, on a real iPhone. Only a phone proves these:
- Eat: say a meal, change one word, then log it. Note how long the words take to appear.
- Sounds: run a workout with the Silent switch on, then off, and once with music playing in another app.
- InBody: read a real sheet, not a sample.
- Guest first workout: start one without signing in.
- The 1.0 checks still apply: the screen stays on during a workout, and one buzz when the rest ends.
12. App Store Connect, version 1.1.0, manual release.
- **Build:** the one from step 10.
- **What's new:** the two lists above.
- **Screenshots:** upload the nine files in `docs/release/launch-pack/screenshots/apple-6.9/en`, then `/ar`, in name order (01-rahma to 09-coach-plan, dated 27 Oct, 1320 x 2868). Do not use the names in step 6 of the 1.0 section, because they do not match these files.
- **Description:** not written for 1.1.0 yet. Do not paste `docs/release/appstore-listing.md` (it says no coaching). The 1.0 text in this guide is old. See OWNER-TODO.
- **App Privacy:** nothing new to tick. Voice logging and the InBody reader add no data type, and the Audio Data answer stays. Follow `docs/release/launch-pack/app-store-privacy-answers.md` (28 Oct). Tick the payment rows only when payments switch on.
- **Review notes:** not ready. `docs/release/review-notes.md` is still the 23 Oct text. It says there are no payments and that payments cannot be turned on remotely, and the box in the 1.0 section says the same. Ask the coding agent to update the notes for 1.1.0, within 4,000 characters, before you paste them.
- **Version release:** manually. Submit only when the description and the review notes are ready.
13. After Apple approves, and BEFORE you press Release, deploy the functions:
```bash
firebase deploy --only functions --project own-hub
```
> The functions carry the new content id `lentils_cooked`, the payment push ids and topics, the InBody consent text and the payments code. Check-ins start the first Friday at 09:00 Cairo time after this deploy, and build 1.0.0 cannot show them. If the functions deploy earlier, build 1.0.0 users get check-in cards that their app hides.

14. Press Release in App Store Connect.
15. Website, in the same window as step 14. The privacy page must go live with this release, because it now describes voice logging and the InBody reader. The same site build also carries the payment sections, which counsel has not signed. Decide first (OWNER-TODO, "Website: a decision for you"). Run the dry run before you press Release, then the real deploy with step 14. **The website and the app release go out together, never one without the other:** the privacy page that is live today has no InstaPay text, so a store reviewer or a member would meet payment screens that the site does not describe. And never set `config/payments.enabled` to true until the corrected privacy page, terms and coach terms (English and Arabic) are live. The site text was checked against the code on 28 October; counsel's open points are in `docs/owner/INSTAPAY-TERMS-DRAFTS.md`.
```bash
bash site/_build/deploy.sh https://own-hub.app --dry-run
```
```bash
bash site/_build/deploy.sh https://own-hub.app
```
16. Rahma's coach web app is a separate product and is not part of this release. Its steps are in OWNER-TODO.

*Not in 1.1.0 / known*

- Train is not week-aware yet: there is no week content.
- Coaching intake has no breastfeeding or trimester question, and the server's flagged-stages list does not include breastfeeding.
- Reviewers cannot open a reported chat file. The owner and counsel decide whether they may.
- K07 is over the control budget. Reported only.
- The 21 new Arabic strings for voice logging and the InBody reader need a native read.
- Not yet checked on a real phone: voice speed, the Silent switch, sound mixing, the InBody reader on a real sheet, and receipt photo reading (payments).
- The food golden table: only 1 of the 252 foods is independently verified against USDA. The dietitian check is pending.
- An end-to-end test that uses `blob.patch()` fails on the emulator only.
- Owner only, all listed in OWNER-TODO: the PDPC filing before 31 Oct 2026 (now with payment records), the Android assetlinks SHA-256 fingerprints, the Apple Associated Domains profile, the dietitian check of the pregnancy and lactation calories, and Rahma's allergen sign-off.
- Payments: built, and off (see the top of this section).

> Version 1.0.0, with coaching · updated 23 Oct 2026 · only what is left to do

New in this build: private coaching (free for now) and the gym improvements. Coaches apply in the app, Own Hub's woman reviewer approves them in the dashboard, coaches build a portfolio with packages and checked photos, members find a coach and ask to join, and the two chat and share workout and meal plans that show in Train, Eat and Home. Payments stay switched off. Below, in order: commit, deploy Firebase, the dashboard and the website, upload the build, a short phone check, App Store Connect, submit. Tick a step when it is done; the ticks stay in this browser.

*Where it stands*

## This build at a glance

- **App tests:** All app tests passed (about 8,630), analyze clean, release preflight 83 passed and 0 failed. All 98 screens fit iPhone SE, iPhone 8, iPhone X and small Android sizes in English and Arabic.
- **Server and rules:** Server tests 3,367 passed. Database rules 446 and storage rules 32 passed. Dashboard 72 passed.
- **Coaching journey:** Coach and client journeys run on the local Firebase emulators: 30 passed, 1 skipped (payouts, off while payments are off). Then driven by hand on the Android emulator in English and Arabic: apply, approve, portfolio, find a coach, ask to join, accept, chat, workout and meal plans, a session, end. The bugs found were fixed and covered by tests.
- **iPhone build:** Version 1.0.0, build **424738** (23 Oct). Signed for the App Store: push and App Attest set to production, no advertising identifier.
- **Code:** Committed and pushed on `feat/motivation-2026-10-13` (691bbe9, 178b0dc, then the release 2 plan commits). Never main.

*Good to know*

## Before you submit

- **Before 31 October 2026: file with the data protection regulator.** Egypt's data protection law grace period ends on 31 October. On the Personal Data Protection Center portal (log in through Digital Egypt with your national ID), file for a controller licence, a sensitive-data licence (health data and the face match) and a transfer-abroad permit (Frankfurt for Firebase and Vertex AI, the United States for PostHog). Since 1.1.0, also file for the payment records and receipt screenshots, which Google Cloud Vision (European Union) reads (see OWNER-TODO, step 1). The regulator has 90 working days to decide, so filing on time is what counts. A lawyer can file for you. Details are in the release 2 plan, section 3.9.
- **Form a company before paid coaching.** Apple asks that apps handling health data come from a legal entity, and payments and the consumer law need a commercial registration and tax card. Then move the Apple account and open Google Play as an organisation.
- **Coaching is live and free.** Packages show their price as "when payments open" with a "Free for now" badge. Turning payments on later needs your legal steps (lawyer on the payment model, the data protection licence, tax) and one switch on the server (`config/payments.enabled`). The payment screens are already in 1.1.0 and stay off until then.
- **Rahma joins like every coach:** she applies in the app (Profile, Become a coach), and a woman reviewer approves her in the dashboard's Coaches tab. Then she builds her portfolio and packages, and her photos show after the reviewer checks them.
- **Before-and-after photos** are shown to members only after a coach confirms her client agreed in writing and Own Hub's woman reviewer approves each one. The original is deleted; only a copy without location data stays.
- **Chat carries text, photos, short videos (up to 30 seconds) and voice notes**, between a member and the coach she joined. Phone numbers, payment details and links are blocked in text. The first voice note or video with sound asks for the microphone (iPhone) or the record-audio permission (Android). Staff read a chat only after one of them reports it.
- **The screen-awake code** compiled on iPhone and Android, but only a real iPhone proves the screen stays on during a workout: check it in step 7.
- **Security round done.** One serious hole was found and closed: anyone signed in by phone could get verified by naming a reviewer who had "auto-pass people I know" on. Now that only puts her request in that reviewer's queue. The full list of what was checked is in Security sign-off. Step 3 has the console settings only you can switch on.
- **Notifications are written for her.** AI wrote 240 casual lines in English and Egyptian Arabic. Her phone picks one by what she did (the day after a training day she skipped gets a warm fresh-start note, never guilt), fills in her next workout, a food she logs or the move of her new best, and learns which tone she opens. Nothing about it leaves her phone and it costs nothing to run.
- **Android.** Google Play has its own 8 steps in Google Play, step by step. A new personal developer account needs a 14-day closed test with 12 or more testers before it can publish, so start the account now even while Apple reviews.
- **Release 2.** The next release plan is in the repo at `docs/plan/RELEASE-2-PLAN.md` (pushed to `feat/motivation-2026-10-13`), ready for a coding agent.
- **Older phones.** The app installs on iPhone 6s and the first iPhone SE and later (iOS 15.5 or newer) and on Android 7 or newer. All 98 screens were drawn at iPhone SE, iPhone 8, iPhone X and small Android sizes in English and Arabic with no layout error.

*Step by step*

## From your Mac to the App Store

> Tick each step as you finish it. The ticks are saved in this browser only.

### [ ] Commit everything and push the branch

*Where:* Terminal. This is your OK to commit: nothing is committed yet.

This commits coaching, the gym improvements, the security fixes, the tailored notifications, the Firebase cost changes and the cleanup. The handoff folder under `.claude/` is not in git. It pushes the branch, never main.

```bash
cd ~/ownhub && git status --short | head -30
git -C ~/ownhub add -A
git -C ~/ownhub commit -m "Private coaching (free, payments off), gym improvements, security round, tailored notifications, cost and cleanup"
git -C ~/ownhub push origin feat/motivation-2026-10-13
```

### [ ] Deploy Firebase: indexes, then rules and storage, then functions

*Where:* Terminal, in ~/ownhub

Coaching needs the new indexes, rules and server functions. Deploy in this order, because the functions need the indexes. Run `firebase login` first if it says you are not signed in.

```bash
cd ~/ownhub && firebase deploy --only firestore:indexes --project own-hub
```

> If it asks whether to delete indexes that are in the console but not in the file: answer **Yes** only if the list holds nothing but these three, removed because no screen uses them (every index costs on each write): `relationships (coachUid, status, lastActivityAt)`, `relationships (coachUid, status, createdAt)`, `posts (authorUid, createdAt)`. If it lists anything else, answer **No**. New indexes take a few minutes to build; wait until the console shows them as Enabled.

```bash
cd ~/ownhub && firebase deploy --only firestore:rules,storage --project own-hub
```

```bash
cd ~/ownhub && firebase deploy --only functions --project own-hub
```

> The functions deploy takes several minutes. If one function fails with a quota or "try again" message, run the same command again.

### [ ] Switch on the console settings for security and cost

*Where:* Terminal, Firebase console, Google Cloud console, Cloudflare

These live in the consoles, not in the code, so only you can set them. Sign in once: `gcloud auth login`.

**SMS to Egypt only.** Phone sign-in is the biggest bill risk: attackers can make Firebase send codes to expensive numbers abroad. This allows Egyptian numbers only:

```bash
curl -X PATCH -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "X-Goog-User-Project: own-hub" -H "Content-Type: application/json" "https://identitytoolkit.googleapis.com/admin/v2/projects/own-hub/config?updateMask=smsRegionConfig" -d '{"smsRegionConfig":{"allowlistOnly":{"allowedRegions":["EG"]}}}'
```

**A budget alert** by email at half and at 90% of 100 USD a month (find your billing account id with `gcloud billing accounts list` and replace `BILLING_ID`):

```bash
gcloud billing budgets create --billing-account=BILLING_ID --display-name=own-hub --budget-amount=100USD --threshold-rule=percent=0.5 --threshold-rule=percent=0.9
```

**Old server images and expired data cleaned up automatically** (old function builds are kept forever otherwise; deleted files are otherwise kept and billed for 7 days):

```bash
firebase functions:artifacts:setpolicy --location europe-west3 --days 1 --project own-hub
bash ~/ownhub/firebase/ops/ttl-policies.sh
gcloud storage buckets update gs://own-hub-personal --clear-soft-delete
```

- **Authorized domains:** Firebase console, Authentication, Settings, Authorized domains: remove `localhost`.
- **API keys:** Google Cloud console, APIs and Services, Credentials. Restrict each key: the Android key to package `com.ownhub.app` with the SHA-1 of your upload key and of Play App Signing; the iOS key to bundle `com.ownhub.fitness`; the browser key to `own-hub.app`, `ownhub-reviewers.pages.dev` and `own-hub.firebaseapp.com`; and each to the Firebase APIs only. Sign in on your phone and on the dashboard right after: a wrong restriction stops sign-in, and removing it fixes it.
- **App Check:** the server functions already refuse calls without it. Once the new build is live, open Firebase console, App Check, APIs: when Cloud Firestore and Cloud Storage show nearly all requests verified, press **Enforce** on both. Under Apps, delete debug tokens you no longer use, and keep the admin test APK on your own phone only.
- **Staff accounts:** as few as possible, each with its own long password. Two-step sign-in for staff needs a dashboard change first, so do not switch it on yet.
- **Cloudflare:** Pages, `ownhub-reviewers`, Settings: turn on the access policy for preview deployments. Better still, put Cloudflare Access (free for up to 50 people) with email codes in front of the dashboard, so a stolen password alone is not enough.

### [ ] Deploy the staff dashboard

*Where:* Terminal

The dashboard gains the Coaches tab (applications and Portfolio photos) and Reports. Payment tabs stay hidden while payments are off. It now also sends its security headers (the new `admin-web/_headers`): it cannot be framed by another site and loads scripts only from Google. The "auto-pass people I know" box is gone from reviewer settings.

```bash
cd ~/ownhub && npx wrangler pages deploy admin-web --project-name ownhub-reviewers
```

> Only an account with the `womanReviewer` claim sees and decides coach applications and portfolio photos. Admin-only accounts do not see the photos.

> **Check it right after deploying** (the new security headers were tested on the sign-in page only): sign in as the reviewer, open Requests, then Coaches with an application's photo and a certificate PDF, then Portfolio photos. If something stays blank, the browser console shows a line starting "Refused to"; roll back with one click in Cloudflare, Pages, `ownhub-reviewers`, Deployments, and tell me what it says.

### [ ] Deploy the website (privacy, terms, coach terms)

*Where:* Terminal, in ~/ownhub

The privacy policy, terms and home page now cover coaching, and there is a new coach terms page (`/coach-terms` and `/ar/coach-terms`) that the app links to. Read the coaching sections (3.15, 3.16) in both languages, then deploy.

```bash
open ~/ownhub/site/privacy.html ~/ownhub/site/ar/privacy.html ~/ownhub/site/coach-terms.html
```

```bash
find ~/ownhub/site -name .DS_Store -delete
~/ownhub/site/_build/deploy.sh https://own-hub.app --dry-run
```

```bash
~/ownhub/site/_build/deploy.sh https://own-hub.app
```

### [ ] Upload the build

*Where:* Transporter (Mac App Store, free)

The build is ready: `~/ownhub/app/build/ios/ipa/own_hub.ipa` (52.8 MB, version 1.0.0, build 424738). Keep the folder `~/ownhub/app/build/symbols/1.0.0+424738-ios` as long as this build is installed anywhere.

```bash
open ~/ownhub/app/build/ios/ipa
```

Open Transporter, sign in with your Apple ID, drag `own_hub.ipa` in, press **Deliver**. Then send the crash-report symbols for this build (needs `firebase login`):

```bash
cd ~/ownhub/app && firebase crashlytics:symbols:upload --app=1:681714989950:ios:02417d9df27fbcf2fbd12f build/symbols/1.0.0+424738-ios
```

> The native crash symbols (dSYMs) were not sent, because the Crashlytics upload tool is not on this Mac. Optional: zip `~/ownhub/app/build/ios/archive/Runner.xcarchive/dSYMs` and drop it on Firebase console, Crashlytics, the iOS app, dSYMs.

> To build it again yourself (for example after changing something): `cd ~/ownhub/app && export PATH="$HOME/development/flutter/bin:$PATH" && RELEASE_BASE_URL=https://own-hub.app bash tool/release_preflight.sh && bash tool/build_ios.sh`. It runs every check first and stops if one fails.

### [ ] Ten minutes on your iPhone

*Where:* TestFlight, the new build

Every flow was tested on the Mac (see the numbers above), but only a real iPhone proves these. Install the new build from TestFlight once Apple has processed it:

- **Screen stays on:** start a workout and leave the phone down longer than your auto-lock time. It must not lock. After you finish, auto-lock works again.
- **Rest buzz:** log a set and wait out the rest with the app open: one buzz.
- **Coaching:** Profile, Become a coach: the application opens and saves a draft. Train, Find a coach: the list opens (it is empty until a coach is approved).
- **The basics:** sign in, log a meal, open a recipe, reserve and cancel an event seat, switch the language from any page.
- **Notifications:** allow notifications and pick your training days. Skip one: the next day a short, friendly note arrives (no counts, no guilt). Tap it.
- **ID screens:** on the ID card screen, swipe to the app switcher: the screen is covered. On Android a screenshot there is blocked.
- **Coach photo:** as a coach, take an upright photo with the camera; after the reviewer approves it, it is still upright and has no location in it.
- **An older iPhone** (an iPhone X, 8 or SE), if you or someone near you has one: open Home, Train and a workout.

### [ ] Update App Store Connect

*Where:* App Store Connect, Own Hub

- **Build:** pick **424738** (version 1.0.0), not 422836 or 423812.
- **App Privacy:** add **Name** (Contact Info) and **Emails or Text Messages** (User Content), both linked, not tracking, App Functionality. The full table is below.
- **Age rating:** Messaging or chat is now Yes, and user content now includes coach portfolios. Both answers are below; the rating stays 18+.
- **Description:** paste the new one below (it adds a Coaching section), in English and Arabic.
- **App Review Information, Notes:** paste the new notes box below with your test number and code.

### [ ] Reviewer test account (skip if done)

*Where:* Firebase console, then Terminal

- Firebase console, own-hub, Authentication, Sign-in method, Phone, "Phone numbers for testing": your test number and its fixed 6-digit code.
- Put the same number in the server allow-list (international format, no spaces; replace the example):

```bash
printf '+201000000002\n' | gcloud secrets versions add store-reviewer-phones --data-file=- --project=own-hub
```

### [ ] Submit for review

*Where:* App Store Connect, the 1.0 version page

- No red warnings, then **Add for Review** and **Submit**. Review usually takes 1 to 3 days. Release is manual.
- If Apple rejects it, send me the message and I will fix the cause and write the reply.

### [ ] Rahma and the first coaches

*Where:* The app, then the dashboard

- Rahma opens Profile, **Become a coach**, and fills the 8 steps (photo, education, certificates, specialties, feedback, a transformation with her client's written consent, how she coaches, terms).
- A woman reviewer opens the dashboard, **Coaches**, approves her (tick the certificates she checked), then approves her photos under **Portfolio photos**.

#### Approving Rahma, tap by tap

Before anything: Rahma must already be a verified woman (she passed the check, so her account is verified), and the person who approves her must be a DIFFERENT woman reviewer. The server refuses a reviewer who tries to decide her own application (`functions/coaching/applications.py` `decide`, `refuse_if_subject`).

1. Rahma, on her phone: Profile, Become a coach. Fill the 8 steps and send. The status screen says it is being checked.
2. The reviewer opens the dashboard (https://ownhub-reviewers.pages.dev) and signs in. The Coaches tab shows a number when an application waits.
3. Coaches, tap Rahma's application. Look at the profile photo, then open each certificate file. A certificate that is unreadable or not hers: tick nothing for it.
4. Tick the certificate or certificates you checked. The Approve button stays grey until at least one is ticked ("To approve, tick at least one certificate you checked").
5. Optional: write a note to her. Tap Approve. Rahma gets a notification and her coach access starts.
6. Portfolio photos tab: open her photos, approve each one that shows only her or people who agreed in writing. A rejection needs a reason from the list.
7. Rahma, on her phone: on the status screen tap Open coach space. She sees My coach space (K18). Her page shows to members only once she has turned on one package.
Other statuses: "Needs changes" sends her back to the steps with the reasons; "Reject" lets her apply again after 30 days.
- Rahma opens **My coaching** in Profile: she adds packages (start from a template), saves workout and meal plans as templates to reuse for every client, and sees requests on her desk.
- **Auto-accept is on for every coach at first:** a member who asks to join, with no "yes" to the health questions, starts at once while the coach has room. To read every request first, turn auto-accept off in the coach space. A request then waits on her desk; tapping it shows the member's answers before Accept or Decline.
- Other coaches do the same. Members find them under Train, **Find a coach**.

### [ ] After Apple's review

*Where:* Terminal

iPhone only: empty the reviewer allow-list after approval.

```bash
printf '\n' | gcloud secrets versions add store-reviewer-phones --data-file=- --project=own-hub
```

**If you publish on Google Play too, skip this step:** Google needs the reviewer account working at all times. Keep the number in the secret and instead make sure the test number and its code are hard to guess (not 0001 or 123456). If you stay on iPhone only: empty the secret with the command above and delete the test number in Firebase, Authentication, Sign-in method, Phone, "Phone numbers for testing", then add it back before each new submission.

### [ ] Meal camera: when Google answers the appeal

*Where:* Terminal

Google's Trust & Safety flag still blocks the model call, so a scan shows "not available right now" and nothing breaks. When it is lifted, measure accuracy and cost on 10 of your own meal photos and send me the output:

```bash
cd ~/ownhub/functions && .venv/bin/python -I tools/eval_meal_scan.py PATH_TO_YOUR_PHOTOS
```

### [ ] Meal pictures (painting at night)

*Where:* This Mac

```text
pgrep -fl meal-images-loop.sh
ls ~/.claude/jobs/ownhub-meal-images/meals/*.webp | wc -l
```

> If the first line prints nothing, start it again: `nohup ~/ownhub/.claude/handoff-store-pass/meal-images-loop.sh >/dev/null 2>&1 &`. When 301 are done, install them with `cd ~/ownhub/app && python3 -I tool/install_meal_images.py --from ~/.claude/jobs/ownhub-meal-images/meals` and ship them in the next update.

### [ ] Before payments can open

*Where:* You and a lawyer

- A lawyer confirms Own Hub selling the programme and paying coaches as contractors (Central Bank rules), the client and coach terms, and keeping the 15% out of the client's view.
- Data protection (PDPL): licence, data protection officer, cross-border transfer permit.
- Tax: VAT, e-receipts and withholding with an accountant.
- Apple: move the developer account to the company.
- Then set `config/payments.enabled` on the server. The payment screens are already in 1.1.0. The order of these steps is in OWNER-TODO, section Payments by InstaPay.

*Android*

## Google Play, step by step

> You have not started on Play yet. Checked against Google's own help pages on 23 Oct 2026; menu names move, so use the Play Console search box if one does not match.

### [ ] Create the Google Play developer account

*Where:* play.google.com/console/signup

- **Organisation or personal:** if Own Hub is a registered company, open an **organisation** account. It needs a free D-U-N-S number (can take up to 30 days; the name and address must match Dun & Bradstreet) and it shows the company to the public. A new **personal** account must first run a closed test with **at least 12 testers for 14 days in a row** before it can publish (step 7).
- One-time fee **US$25** (no prepaid cards). Google may ask for your ID and a card in your legal name, and a personal account verifies an Android phone with the Play Console app.

> Plan on 4 to 5 weeks in total for a personal account: verification, App content, the 14-day test, the production-access review (about 7 days) and the first review (up to 7 days).

### [ ] Create the app

*Where:* Play Console, Home, Create app

- App name: `Own Hub: Fitness for Women` (26 of 30). Default language: English (United States). App, Free.
- Contact email: an inbox you read every day. Tick the Developer Program Policies, US export laws and Play App Signing.

### [ ] Build the Android bundle and upload it to internal testing

*Where:* Terminal, then Play Console, Test and release, Internal testing

The script signs with your key in `app/android/key.properties` and sets a new build number by itself.

```bash
cd ~/ownhub/app && export PATH="$HOME/development/flutter/bin:$PATH" && bash tool/build_release.sh
```

- Upload `app/build/app/outputs/bundle/release/app-release.aab` to **Internal testing**, Create new release. The first upload turns on Play App Signing: Google keeps the app signing key and your keystore becomes the upload key. Back up the keystore and its passwords offline.
- Run the `firebase crashlytics:symbols:upload` line the script prints, and keep the `build/symbols` folder and `mapping.txt`.
- Add yourself and a few people as internal testers (up to 100 emails). Internal testing is the fast track and needs no App content yet.

### [ ] Connect Firebase to the Play signing key

*Where:* Play Console, Protected with Play (or App integrity), then Firebase

- Copy the **SHA-1** and **SHA-256** of both the **App signing key** and the **Upload key**.
- Firebase console, Project settings, Your apps, `com.ownhub.app`, **Add fingerprint**: add all four. Without them, phone sign-in fails for people who installed from Play.
- Play Console, Play Integrity API, **Link Cloud project**: choose own-hub (you must be an Owner of the project yourself).
- Firebase, App Check, Apps, the Android app: Play Integrity, with the app signing SHA-256. Turn on enforcement only after the metrics show verified traffic.
- Stop handing out the separate APK once App Check is enforced: Google does not recognise it, so it will be refused.

### [ ] Fill in App content

*Where:* Play Console, Policy and programs, App content

| Item | Answer |
|---|---|
| Privacy policy | `https://own-hub.app/privacy` |
| App access | All or some functionality is restricted. Add the reviewer test number and its code (the same one as Apple's, in the `store-reviewer-phones` secret) and paste the reviewer notes. Google needs this account to work **at all times**, so keep the number in the secret while the app is live, and use a number and code that are hard to guess. |
| Ads | No |
| Content rating (IARC) | Violence, sex, language, drugs, gambling, horror: No. Users can interact: **Yes** (1:1 text chat with the coach she joined). User content shown to others: **Yes** (approved coach portfolios, moderated and reportable). Location sharing: No. Digital purchases: No. Unrestricted internet: No. |
| Target audience | 18 and over only; tick Restrict minor access |
| News, COVID-19, Government app | No, No, No |
| Data safety | Collects data: Yes. Encrypted in transit: Yes. Deletion: Yes, `https://own-hub.app/delete-account`. Shared with third parties: No. Data types from `app/android/play-data-safety.txt`: name, phone number, user ID, other info (the ID code), fitness, health (optional), other in-app messages (coach chat), photos (ID and selfie not stored; coach pictures stored; the meal photo read once and not stored), app interactions, other user content, crash logs, diagnostics, device ID, approximate location. Include PostHog usage statistics (only with her consent) under app interactions. |
| Financial features | My app doesn't provide any financial features |
| Health apps | Activity and fitness, Nutrition and weight management, Period tracking. Not a medical device. Both descriptions must keep the line that the app is not a medical device and does not diagnose or treat anything. |
| Advertising ID | No |
| Account deletion | In the app: Profile, Your data, Delete everything. Web: `https://own-hub.app/delete-account` |
| Permissions | No photo and video declaration (the app uses the system photo picker). `RECORD_AUDIO` is declared for voice notes in the coaching chat (asked at the first hold, never at launch) and goes in Data safety. The rest-timer alarm uses `SCHEDULE_EXACT_ALARM`, which needs no form; answer only the declarations Play lists after the upload. |

### [ ] Store listing in English and Arabic

*Where:* Play Console, Grow users, Store presence, Main store listing

- Short description (80) and full description (4000): from `docs/release/launch-pack/store-listing-copy.md` (Play short description, 76 of 80). Add a sentence about coaching in both languages before pasting.
- Icon 512 x 512: `docs/release/launch-pack/play-icon-512.png`. Feature graphic 1024 x 500: `docs/release/launch-pack/feature-graphic.png`.
- Phone screenshots (2 to 8): `docs/release/launch-pack/screenshots/play/en` and `/ar`. No tablet screenshots needed.
- Category: Health and Fitness. Website `https://own-hub.app`. Add the Arabic translation and its screenshots.

### [ ] Closed test with 12 or more testers for 14 days (personal accounts)

*Where:* Play Console, Test and release, Closed testing

- Create the closed track, country Egypt, testers by email list or Google Group, then roll out the same bundle. The opt-in link appears once the track is published.
- Invite 15 to 20 women so at least 12 stay opted in for 14 days in a row. Each opts in with the Google account on her phone and passes the real ID check (the functions are already deployed).
- After 14 days: Dashboard, **Apply for production**. Review usually takes 7 days or less.

### [ ] Release to production in Egypt

*Where:* Play Console, Test and release, Production

- Countries: Egypt only. Create new release with the bundle and the English and Arabic "What's new".
- Staged rollout, for example 20%, then widen it with Update rollout. Review takes up to 7 days.
- Before submitting, check the Play files against 1.1.0. `docs/release/play-listing.md` is already updated (28 Oct). The reviewer notes in `docs/release/review-notes.md` are still the 23 Oct text, so ask the coding agent to update them for 1.1.0 first (see the 1.1.0 section, step 12).

*Checked before this build*

## Security sign-off

> Checked against the OWASP mobile standard (MASVS 2), the OWASP API Top 10 (2023), Firebase's own security checklist and the Cloudflare and Apple rules, then against the code. No check can promise an app is never attacked; this is what was looked at and what it found.

| Area | What was checked | Result |
|---|---|---|
| Women-only gate | Every way to get verified | **Fixed:** naming a reviewer with "auto-pass people I know" verified anyone. It now only queues the request for her. The test-number list holds a placeholder that matches nobody. |
| Server functions | All 88: sign-in, App Check, staff rights, input checks, other people's data | Every call from the app or the dashboard needs sign-in and App Check (refused without it). The one public address, the website waitlist, takes 4 KB at most and 50 tries per address a day. Every id a caller sends is checked against her own data. Staff rights are read from the sign-in token. Limits on every function. |
| Database rules | Every collection and file path | **Fixed:** four old coach paths, an unused assessments path, community lists and reports from non-phone accounts were closed or tightened. 446 rule tests and 32 storage tests pass. |
| Photos and files | Upload size, type, location data, image bombs | **Fixed:** location data is now stripped on the phone before a coach photo uploads (the photo stays upright). The server re-encodes every image, caps its size before reading it, and allows only JPEG, PNG and WebP. |
| The app on the phone | Backups, network, logs, links, screenshots, debug leftovers | **Fixed:** ID and selfie screens are hidden from screenshots and the app switcher; links open only if https or email; the session link is checked in chat too. Release builds block plain HTTP, are obfuscated, log nothing personal and cannot be pointed at a test server. |
| Staff dashboard | Sign-in, page content, headers | **Fixed:** the live dashboard sent no security headers (it is on Cloudflare, the headers were only in the Firebase file). It now does. Server text is never inserted as HTML. |
| Libraries | Every Dart, Python and npm package against the OSV database | **Fixed:** the server's certificate list (certifi) had compromised roots; now 2026.10.19. 164 Dart packages clean. One npm warning is in test tooling only, never shipped. |
| Secrets | The repository and its full history | No key, password or service account file was ever committed. The Firebase keys in the app are public by design and get restricted in step 3. |
| AI | Meal photo answers, notifications | The meal model's answer is checked against a strict shape and clamped. Notification lines are chosen on the phone; nothing is sent to any AI service. |

**Still open, on purpose or for later:**

- Two-step sign-in for staff: the dashboard needs a small change before it can be switched on. Until then: few staff, long passwords, Cloudflare Access (step 3).
- On iPhone, a full device backup to iCloud includes the app's on-phone data (Apple encrypts it). Android backups exclude it.
- Rate limits on chat messages, reports and coach uploads (today: one active coaching per chat, capped item counts, blocking and reporting).
- Egypt's data protection law (PDPL) applies from 1 November 2026: the licence, the data protection officer and the permit for data stored in Frankfurt need your lawyer.

*Copy into App Store Connect*

## App Store Connect inputs

> The descriptions below are the ones submitted with 1.0. Do not use them for 1.1.0, and do not use `docs/release/launch-pack/store-listing-copy.md` either: both predate voice logging, the InBody reader and payments (see the 1.1.0 section, step 12). The 23 Oct corrections in that file (a woman reviewer can also do the women-only check; the answers a member sends to a coach do leave her phone) must be in the 1.1.0 description too. The App Privacy table below is current for 1.0: it already includes a member's first name to her coach and PostHog. For 1.1.0, follow `docs/release/launch-pack/app-store-privacy-answers.md`.

Every field, in the order App Store Connect asks for it. Values in a grey box copy with the button. Short values are in the tables. Anything the docs cannot know is marked `[OWNER: ...]`. Counts show characters used against Apple's limit, recounted with Python on 22 Oct from the local release docs.

> The app record already exists (the TestFlight upload needed it), so the New App form is not repeated here. The values below match `docs/release/appstore-listing.md`, `launch-pack/store-listing-copy.md`, `launch-pack/app-store-privacy-answers.md` and `review-notes.md`, which agree with each other, apart from the review notes box (see its count). Wording of Apple's screens is from memory of the site; follow the on-screen label if it differs.

### 1. App Information

> App Store Connect, Own Hub, General, App Information

| Field | Value | Note |
|---|---|---|
| Name | `Own Hub: Fitness for Women` 26 / 30 |  |
| Subtitle | `Verified women only, in Egypt` 29 / 30 | Tight: 1 character spare. |
| Primary category | Health & Fitness |  |
| Secondary category | Lifestyle | Do not choose Medical: it brings a much higher review bar. |
| Content rights | No third-party content that needs rights | Fonts are SIL OFL, nutrition tables are public USDA data. [OWNER: confirm you hold the rights to Rahma Mohsen's recipes, photos and exercise videos, in writing; if not, answer Yes and be ready to show the licence] |
| License Agreement | Apple's standard EULA | Leave the default unless counsel supplies one. |
| Privacy Policy URL | `https://own-hub.app/privacy` | Live page. Round 2 changed sections 3.5, 3.11 and 10 and the 21 Oct history entry; deploy it first (step 5). |
| Privacy Choices URL | empty | Not needed. |

**Age rating** Edit next to Age Rating. Answer each question as below, then choose **18+** where Apple offers a higher rating than calculated. The app refuses anyone under 18 at sign-up.

| Question | Answer | Note |
|---|---|---|
| Violence of any kind (cartoon, realistic, graphic) | None |  |
| Sexual content or nudity, suggestive themes | None | Exercise demonstrations are clothed and instructional. |
| Profanity or crude humour | None |  |
| Horror or fear themes | None |  |
| Alcohol, tobacco or drug use or references | None |  |
| Medical or treatment information | Infrequent or Mild | The cycle screen and severe-pain day point her to care. The answer sheet says "None" is also defensible; the older listing says Infrequent. Infrequent is the safer one, and the 18+ choice makes the tier the same either way. |
| Health or wellness topics | Yes | Fitness, nutrition, period tracking. |
| Simulated gambling, gambling, contests, loot boxes | None / No |  |
| Unrestricted web access | No | The app only opens its own privacy, terms and support pages. |
| User-generated content shared with others | Yes, limited | Approved coaches' public portfolios (each photo checked by Own Hub's woman reviewer first, reportable by members), and the opt-in dish. No community. Only an opt-in dish she chooses to share (off by default, no name) which the Own Hub team reviews before other members see it, and event seat bookings (not shown to others). The sheet gives no plain yes or no; Yes is the cautious reading and costs nothing because the rating is set to 18+. |
| Messaging or chat | Yes | Text, photos, short videos and voice notes, between a member and the coach she joined. Phone numbers, payment details and links are blocked in text; report and block are in every chat; staff read a chat only after a report. |
| Advertising | No |  |
| Parental controls | No |  |
| Age assurance (if asked) | Yes | Age is read from the national ID number at sign-up, and under 18 is refused. |

> Coaching adds chat and coach portfolios, which is why two answers above changed. The rating stays 18+.

### Localizable information: Arabic

> Same page. Open the language menu, choose Add Language, Arabic, then fill:

| Field | Value | Note |
|---|---|---|
| Name | `Own Hub: لياقة للستات` 21 / 30 | The Latin wordmark stays on purpose. [OWNER: confirm, or supply the Arabic wordmark] |
| Subtitle | `للستات بس، بعد التحقق` 21 / 30 | Egyptian Arabic, as the store-listing copy. |
| Privacy Policy URL | `https://own-hub.app/ar/privacy` | The Arabic page. |

### 2. Pricing and Availability

> App Store Connect, Own Hub, General, Pricing and Availability

| Field | Value | Note |
|---|---|---|
| Price | Free (the $0.00 tier) | No in-app purchases, no subscription, no price shown anywhere in the app. |
| Availability | Egypt only | The terms say Own Hub is offered in Egypt. [OWNER: confirm Egypt only; add other countries only after counsel confirms, because of the data-transfer rules] |
| Pre-orders | Off | Not used for 1.0. |
| Mac and Vision availability | Off if shown | The app is iPhone only (`TARGETED_DEVICE_FAMILY = 1`). Do not offer iPad. |

### 3. App Privacy

> App Store Connect, Own Hub, App Privacy, Get Started or Edit

| Field | Value | Note |
|---|---|---|
| Privacy Policy URL | `https://own-hub.app/privacy` | Also shown here. |
| Do you or your third-party partners collect data from this app? | Yes, we collect data from this app |  |
| Used to track you? | No, for every type | No advertising identifier, no App Tracking Transparency prompt. |

Tick exactly these types. Every one is **not used for tracking**. Never tick Product Personalisation, Developer's Advertising, Third-Party Advertising or Other Purposes.

| Category | Data type | Linked to her? | Tracking? | Purpose | What it is |
|---|---|---|---|---|---|
| Contact Info | **Name** | Yes | No | App Functionality | A woman who applies to coach gives her full name for the review (never shown to members). A member who asks to join a coach may give her first name, which only that coach sees. |
| Contact Info | **Phone Number** | Yes | No | App Functionality | Sign-in by SMS code. |
| Health & Fitness | **Health** | Yes | No | App Functionality | Cycle dates, check-ins, measurements, weight, allergies. Sent only if she turns on "Back up my health data" (off by default); optional data is still declared. |
| Health & Fitness | **Fitness** | Yes | No | App Functionality | Workouts, sessions and meals saved to her account. Her answers to the post-session and Friday questions stay on the phone: nothing added. |
| Sensitive Info | **Sensitive Info** | Yes | No | App Functionality | Pregnancy or postpartum stage (with health backup only) and the face match during the ID check; no face measurement is stored. |
| User Content | **Emails or Text Messages** | Yes | No | App Functionality | The chat between a member and the coach she joined, stored in Frankfurt, readable by the two of them. |
| User Content | **Photos or Videos** | Yes | No | App Functionality | Coach applicants' pictures (profile, documents, feedback screenshots, before-and-after photos with the client's written consent), stored and checked by the woman reviewer; approved items are shown to members as re-encoded copies without location data. Also the ID card photos and selfie, and the meal photo when she chooses to analyse a meal. Her profile photo is not part of this row: it stays on the phone and is never collected. Read once by our server or Google Cloud Vertex AI in Frankfurt and never stored. Not storing them does not exempt them from being declared. Also the photos and short videos a member or her coach sends in their chat, stored in Frankfurt, readable by the two of them, kept until the account is deleted. |
| User Content | **Audio Data** | Yes | No | App Functionality | Voice notes (and the sound of a video) a member or her coach sends in their chat, stored in Frankfurt, readable by the two of them, kept until the account is deleted. |
| Identifiers | **User ID** | Yes | No | App Functionality | The account id her data is kept under. |
| Identifiers | **Device ID** | Yes | No | App Functionality and Analytics | Firebase installation id and App Attest; with her consent to usage statistics, the Google Analytics instance id and PostHog's anonymous id. |
| Usage Data | **Product Interaction** | No | No | Analytics | Only if she turns on "Help improve Own Hub": Google Analytics and PostHog (hosted in the United States). Screen ids and steps; never health, cycle or anything she typed. |
| Location | **Coarse Location** | No | No | Analytics | Derived by Google Analytics from the masked IP, same consent. The app reads no location. |
| Diagnostics | **Crash Data** | No | No | App Functionality | Firebase Crashlytics, only if she allows it. |
| Diagnostics | **Performance Data** | No | No | App Functionality | Google ML Kit while it guides the selfie camera. |
| Other Data | **Other Data Types** | Yes | No | App Functionality | Her national ID number as a one-way keyed code; her event seat (id, time, status; removed on cancel or account deletion); the opt-in shared dish (names, items with grams, figures, with a keyed marker made from her account that Own Hub can match back to her until she deletes her account) and the 30-day repeat-photo cache (a fingerprint plus foods and grams; no photo); the coach application text, the public coach portfolio, and the intake a member sends a coach (its health answers are under Health). Declare these here, not under "Other User Content": the app's privacy manifest declares Other Data Types, and the repo's release test keeps `OtherUserContent` out of the manifest, so App Store Connect and the manifest stay the same. |

Leave every other box empty: email address, physical address, precise location, contacts, browsing and search history, purchases, financial info, advertising data, other usage data, other diagnostic data.

> **Coaching adds two types:** Name (coach applicants only) and Emails or Text Messages (the chat). No payment info, purchases or financial info are collected: payments are off.

> Personal follow-up answers ("How do you feel today?", the Friday review) stay on the phone, are not in the backup and are never in statistics. They are not collected, so nothing is added for them. The summary on the store page should read: Linked to You: Contact Info (Name, Phone Number), Health & Fitness, Sensitive Info, User Content, Identifiers, Other Data. Not Linked to You: Location, Usage Data, Diagnostics. Used to Track You: none. Click **Publish**.

### 4. Version 1.0 page

> App Store Connect, Own Hub, iOS App, 1.0 Prepare for Submission. Start with English (U.S.), then switch the language menu to Arabic.

### English (U.S.)

**Promotional text** 154 / 170

```text
Women only, checked once with your ID. Train on a 3, 4 or 5 day split, log food, find recipes and see your progress. Your health notes stay on your phone.
```

**Description** 3931 / 4000 Plain text: asterisks and hashes show literally, so there are none. No mention of Android or Google Play. Round 2 added the three splits, one place to log food, Insights and the share card.

```text
Own Hub is a fitness app for women in Egypt, and only for women. Every member is checked once when she joins, so the space you train in really is women only.

HOW THE WOMEN-ONLY CHECK WORKS
• Sign up with your Egyptian mobile number and a code sent by SMS.
• Photograph your Egyptian national ID card and take a short live selfie. The app reads your age and sex from your ID number and checks that your selfie matches the card.
• The photos of your card and your face are never stored. They're checked, then discarded. We keep only the result, plus a one-way code made from your ID number so one card can't open two accounts.
• If the automatic check can't decide, or you'd rather not use the camera, you can ask a woman from Own Hub to review your case. She contacts you by phone within 72 hours. Nothing is recorded.
• Own Hub is for women aged 18 and over.

YOUR HEALTH DATA STAYS ON YOUR PHONE
• Whatever you note about your body stays on your phone: daily check-ins, measurements, weight, pregnancy or postpartum stage and allergies.
• They leave it only if you turn on "Back up my health data", which stays off until you choose it.
• Your workouts and meals are saved to your account, so losing your phone doesn't lose them.
• There are no ads and no tracking, and your health data is never sold or used for marketing.

TRAIN
• Three splits, for 3, 4 or 5 days a week. Customise one into your own plan, kept on your phone, or build your own workout from scratch.
• A guided workout player with a rest timer that starts by itself.
• Short demo videos for many moves, and a swap when the machine is taken or you don't have the equipment.
• After a session, a short question about how you feel can hold your next weights steady, and your answers stay on your phone.
• Gentle reminders on the days you choose, and friendly nudges at most once a day, never at night.

EAT
• 50 Egyptian recipes you already know, 39 by Rahma Mohsen and 11 from Own Hub, with calories, protein, carbs and fat per serving.
• 252 Egyptian foods, with the allergens listed for each.
• One place to log food and find recipes: Eat has Log, Recipes and Plan.
• Log a meal by typing it in your own words, or in one tap from your usual plates.
• Photograph your plate to get an estimate of what is on it. You check and change every item before anything is logged. The photo is sent once for the estimate and is not stored.
• A week of dinners, and a shopping list that builds itself.
• Pick what you can't eat from 16 allergens. If the app can't tell whether a dish is safe, it won't say it is.

EVENTS
• Events from Own Hub, with photos, Cairo time and a map link. Reserve a seat, or cancel it.

HOW YOU FEEL
• Say how you feel each day, and get a plan that listens to your body.
• On a day you tell the app you are in severe pain, it stops suggesting a workout and points you toward care.
• Delete what you noted about your body on its own, at any time.

COACHING
• Find a coach checked by Own Hub, see her results and packages, and ask to join. Coaching is free for now.
• Chat with your coach and get workout and meal plans from her in Train and Eat.
• Coaches apply in the app; Own Hub's woman reviewer checks every coach and every photo.

PROGRESS
• Insights: a body map, your progress, your personal bests and a 7-day food summary, plus body measurements nobody else sees.
• Share a card of a finished workout if you like. It is made on your phone and sent only if you tap Share.

IN ARABIC AND ENGLISH
• The whole app works in Egyptian Arabic and in English, your choice.

FREE
• Own Hub is free, with no ads and no in-app purchases.
• Delete your account and your data from inside the app at any time.

Own Hub is not a medical device and does not diagnose, treat, cure or prevent any medical condition. Check with a doctor before starting a new exercise programme or making medical decisions, especially if you are pregnant, postpartum or injured.
```

**Keywords** 100 / 100 Comma separated, no spaces after commas. Words already in the name and subtitle are indexed for free, so women, fitness, verified and Egypt are left out.

```text
workout,home workout,wellbeing,period,meal,recipes,egyptian,ladies,gym,private,health,diet,nutrition
```

| Field | Value | Note |
|---|---|---|
| Support URL | `https://own-hub.app/support` | A real page, not a mailto. |
| Marketing URL | `https://own-hub.app` | Optional; the site home exists. |
| What's New | not shown | Apple hides it on a first version. The Google Play text is in the Play step. |

### Arabic

**Promotional text** 159 / 170

```text
للستات بس، بعد تحقق مرة واحدة ببطاقتك. اتمرني بسبليت 3 أو 4 أو 5 أيام، وسجّلي أكلك وشوفي وصفاتك في مكان واحد، وتابعي تقدّمك. ملاحظاتك الصحية بتفضل على موبايلك.
```

**Description** 3289 / 4000

```text
Own Hub تطبيق لياقة للستات في مصر، وللستات بس. بنتأكد من كل عضوة مرة واحدة لما تنضم، عشان المكان اللي بتتمرني فيه يفضل للستات بجد.

إزاي بنتأكد
• سجّلي برقم موبايلك المصري وكود بيوصلك في رسالة.
• صوّري بطاقة الرقم القومي وخدي سيلفي قصيرة. التطبيق بيعرف سنك ونوعك من الرقم القومي، وبيتأكد إن السيلفي بتاعتك شبه صورة البطاقة.
• صور البطاقة والوش مش بتتحفظ أبدًا. بتتفحص وبعدين بتتمسح. بنحتفظ بالنتيجة بس، وبكود ماينفعش يرجع لرقمك القومي، عشان البطاقة الواحدة ماتفتحش حسابين.
• لو الفحص الأوتوماتيك ماقدرش يحسم، أو مش عايزة تستخدمي الكاميرا، تقدري تطلبي إن ست من Own Hub تراجع حالتك. هتكلمك في التليفون خلال 72 ساعة، ومفيش حاجة بتتسجّل.
• Own Hub للستات من 18 سنة وطالع.

بياناتك الصحية بتفضل على موبايلك
• اللي بتكتبيه عن جسمك، وتسجيلاتك اليومية، وقياساتك، ووزنك، ومرحلة الحمل أو بعد الولادة، والحساسية، كله بيفضل على موبايلك.
• مش بيخرج منه غير لو شغّلتي «انسخي بياناتي الصحية احتياطي»، وده مقفول لحد ما تختاريه بنفسك.
• تمارينك ووجباتك بتتحفظ في حسابك، عشان ماتضيعش لو موبايلك ضاع.
• مفيش إعلانات ولا تتبع. بياناتك الصحية عمرها ما بتتباع ولا بتتستخدم في تسويق.

التمرين
• تلات خطط سبليت لـ 3 أو 4 أو 5 أيام في الأسبوع. عدّلي واحدة منها لخطتك الخاصة وهتتحفظ على موبايلك، أو اعملي تمرينك من الأول.
• مشغّل تمارين بيمشي معاكي خطوة بخطوة، ومؤقت راحة بيبدأ لوحده.
• فيديوهات قصيرة لحركات كتير، وبدّلي الحركة لو الجهاز مشغول أو مش عندك الأداة.
• اعملي تمرينك بنفسك، أو عدّلي تمرين قبل ما تبدئي، واحفظيه في «تمريناتي».
• بعد التمرين، سؤال قصير عن إحساسك ممكن يثبّت أوزانك الجاية، وإجاباتك بتفضل على موبايلك.
• تذكيرات لطيفة في الأيام اللي تختاريها، وتنبيهات ودودة مرة في اليوم على الأكتر، ومفيش إشعارات بالليل.

الأكل
• 50 وصفة من الأكل المصري اللي تعرفيه، 39 منها من رحمة محسن و11 من Own Hub، وقدام كل وصفة السعرات والبروتين والكربوهيدرات والدهون للحصة.
• 252 أكلة مصرية، والحساسية مكتوبة قدام كل أكلة.
• مكان واحد تسجّلي فيه أكلك وتلاقي وصفاتك: الأكل فيه سجل ووصفات وخطة.
• سجّلي وجبتك بكلامك، أو بلمسة من أطباقك المعتادة.
• صوّري طبقك وخدي تقدير للي فيه. إنتي بتراجعي وبتعدّلي كل عنصر قبل ما أي حاجة تتسجّل، والصورة بتتبعت مرة واحدة للتقدير ومابتتحفظش.
• عشا الأسبوع كله، وليستة مشتريات بتتعمل لوحدها.
• اختاري اللي ماينفعش تاكليه من 16 نوع حساسية. التطبيق مش هيقول على طبق إنه آمن لو مش متأكد.

الفعاليات
• فعاليات من Own Hub بصور ووقت القاهرة ولينك للخريطة. احجزي مكانك، أو ألغي الحجز.

إحساسك
• قولي كل يوم إنتي حاسة بإيه، وخدي خطة بتسمع لجسمك.
• في اليوم اللي تقولي فيه إنك تعبانة جامد، التطبيق بيبطّل يقترح تمرين وبيوجّهك تكشفي.
• امسحي اللي كتبتيه عن جسمك لوحده في أي وقت.

الكوتشينج
• لاقي مدرّبة اتراجعت من Own Hub، شوفي نتايجها وباقاتها، واطلبي تنضمي لها. الكوتشينج ببلاش دلوقتي.
• اتكلمي مع مدرّبتك وخدي منها خطط تمارين وأكل في التمرين والأكل.
• المدرّبات بيقدّموا من التطبيق، وست من Own Hub بتراجع كل مدرّبة وكل صورة.

تقدّمك
• إحصائياتك: خريطة للجسم، وتقدّمك، وأحسن أرقامك، وملخص أكلك لآخر 7 أيام، وقياسات جسمك اللي محدش غيرك بيشوفها.
• شاركي بطاقة تمرين خلّصتيه لو حابة. بتتعمل على موبايلك ومابتتبعتش إلا لو دوستي على «مشاركة».

بالمصري والإنجليزي
• التطبيق كله بالعربي المصري وبالإنجليزي.

ببلاش
• Own Hub ببلاش، من غير إعلانات ولا مشتريات جوه التطبيق.
• امسحي حسابك وبياناتك من جوه التطبيق في أي وقت.

Own Hub مش جهاز طبي، ومش بيشخّص أو بيعالج أو بيمنع أي حالة طبية. اسألي دكتورك قبل ما تبدئي برنامج تمارين جديد أو تاخدي أي قرار طبي، خصوصًا لو حامل أو بعد الولادة أو عندك إصابة.
```

**Keywords** 87 / 100 Same rule: no spaces after commas.

```text
تمارين,تمارين منزلية,عافية,الدورة,وصفات,وجبات,مصر,سيدات,رياضة,صحة,خصوصية,رجيم,جيم,تغذية
```

| Field | Value | Note |
|---|---|---|
| Support URL | `https://own-hub.app/ar/support` |  |
| Marketing URL | `https://own-hub.app/ar/` |  |

### Same for both languages

| Field | Value | Note |
|---|---|---|
| Version | `1.0.0` | From `app/pubspec.yaml` (`1.0.0+1`). The build number is set by `tool/build_ios.sh` from the clock unless you pass `BUILD_NUMBER`. |
| Build | Choose the build you uploaded in step 6 | Click Add Build and pick the newest one, once it has finished processing. Do not pick 422836: that was the first build, from before round 2. |
| Copyright | `2026 Mahmoud Reda` | [OWNER: use your legal entity name instead if you have one] |
| Routing App Coverage File | none | Leave empty. |
| Version release | Manually release this version | You press release after approval. |

### App Review Information

| Field | Value | Note |
|---|---|---|
| Sign-in required | Yes (tick it) |  |
| User name | [OWNER: the Apple test number, for example +20 10 0000 0002] | Must also be in the `store-reviewer-phones` secret as `+201000000002` (see the reviewer step above). |
| Password | [OWNER: its fixed 6-digit code] | The Firebase test code for that number. |
| Contact first name | [OWNER: first name] | The answer sheet lists Mahmoud Reda. |
| Contact last name | [OWNER: last name] |  |
| Contact phone | [OWNER: a number answered during review, with +20; Apple does call] |  |
| Contact email | [OWNER: an inbox read every day] |  |
| Attachment | none |  |

**Notes** 3975 / 4000 From `docs/release/review-notes.md`, counted with a 12-character number and a 6-digit code in the two `[OWNER]` spots. It now covers coaching.

```text
Own Hub is a free fitness app for women in Egypt, and only for women: home workouts, meals and recipes, private period tracking and progress. No ads and no purchases.

FIRST LAUNCH
1. After the logo, a short "Take a deep breath" screen: tap Skip or wait four seconds.
2. The first setup question opens over Home. Tap "Skip setup" to reach Home.
Home, Train, Eat and the recipes work without an account. Nothing is saved to our servers until she signs in.

SIGN IN WITH THE TEST ACCOUNT
1. On Home, tap "Sign in or join" at the top.
2. Continue past the welcome card to the phone number screen.
3. Enter [OWNER: 10 0000 0002] after +20 and tap "Agree and send me a code".
4. Enter [OWNER: code]. This is a Firebase test number: no SMS is sent and the code is fixed.

WHY THERE IS AN ID CHECK
Each member proves once, at sign-up, that she is a woman aged 18 or over: she photographs her Egyptian national ID card and takes a live selfie. Our own server reads sex and age from the ID number and matches the selfie to the card photo. The photos are deleted when the check ends and are never stored. If the check cannot decide, or she prefers not to use the camera, a woman from Own Hub reviews her case and contacts her by phone within 72 hours.

A reviewer cannot pass that check, so this test number is on a server-side allow-list that we keep empty outside review, and the account was approved on our server before submission. The app has no bypass or hidden code. If you delete the account and sign in again with the same number, the ID screens appear once: photograph any card and follow the selfie prompts.

NEW IN THIS VERSION
Tabs: Home, Train, Eat, Events, Insights. Train: three splits (3, 4 or 5 days) she can customise into her own plan, kept on the phone, or build her own workout. On every move of the three splits: a personal best, weight steps that fit the equipment, a plate helper for barbell moves and a note per move. She can open the history of one move and fix a logged set. Eat: Log, Recipes and Plan. Insights: progress and bests.
Coaching (applications and portfolios): Profile > Become a coach opens an 8-step application for verified women; Own Hub's reviewer approves it; approved coaches build a public portfolio; members browse under Find a coach, can ask to join a coach for free and chat with her in text. No payments in this version.
Events: published by Own Hub, with Cairo time and a map link. A verified member can reserve and cancel a seat; the test account is verified. Event reminders are scheduled on the phone.
Meal photos: on Eat, "Scan your meal with the camera" (verified members, after a one-time consent sheet). The photo is sent once to Google Cloud Vertex AI in Frankfurt to estimate the foods and is never stored. She checks every item before anything is logged.
Profile photo: camera or system picker (no photo-library permission); it stays on the phone. Share card: made on the phone; nothing is sent unless she taps Share.

NOT IN THIS VERSION
Community, the AI assistant, payments and paid coaching are switched off by flags compiled into this build and cannot be turned on remotely. Joining a coach is free.

HEALTH
Cycle, measurements, pregnancy or postpartum stage and allergies stay on the phone unless she turns on "Back up my health data", which is off by default. Own Hub is not a medical device and does not diagnose or treat anything.

Widgets ("Your week", "Today") show session counts only, never health data.

DELETING DATA
In the app: the avatar on Home > Your data > Delete everything. It deletes the account and its data on our servers and clears the phone. On the web: https://own-hub.app/delete-account

Permissions: the camera (ID check; meal, profile and coach-application photos when she chooses), the microphone (only when she holds the mic button in a coaching chat to record a voice note, or records a video with sound for her coach), notifications (only after she sets reminders; all scheduled on the phone), and motion (to tilt a few illustrations). No tracking, no ads, no advertising ID. Usage statistics and crash reports are off until she turns them on.
```

### 5. Export compliance

> App Store Connect, the build row, or the question after upload

| Field | Value | Note |
|---|---|---|
| Info.plist key | `ITSAppUsesNonExemptEncryption` = `false` | Set in `app/ios/Runner/Info.plist`. Apple therefore skips the question, and the new build should not show "Missing Compliance". |
| If it asks anyway | Encryption: only standard HTTPS provided by iOS. No proprietary or non-standard algorithms. Exempt. | No documents to upload, no ECCN or CCATS number. The only crypto in the code is a hash for document ids, not to protect data. |

### 6. Screenshots

> Same 1.0 page, Previews and Screenshots, per language

| Field | Value | Note |
|---|---|---|
| Size | 6.9-inch iPhone, `1320 x 2868` portrait | Also accepted as 6.9-inch: `1290 x 2796`. Apple scales it for smaller phones; this is the only iPhone size required. No iPad set. |
| How many | 9 (allowed 1 to 10) | The same 9 screens, in the same order, in English and in Arabic. The Arabic set is captured with the app set to Arabic so it is right to left. |
| Where they are | `~/ownhub/docs/release/launch-pack/screenshots/apple-6.9/en` and `/ar` | Upload in file-name order. Real captures only: a frame showing a screen the app does not have is rejected. |
| App Preview video | Skip for 1.0 | Optional. |

1. `01-home`, Home.
2. `02-split`, the split choice.
3. `03-workout`, the live workout.
4. `04-eat`, Eat.
5. `05-meal-check`, the meal camera result.
6. `06-recipe`, a recipe.
7. `07-share`, the workout share card.
8. `08-events`, Events.
9. `09-insights`, Insights.

> **check:** when this guide was written, both folders still held the 8 files from 17 Oct (`01-welcome` to `08-tour-checkin`) and none of the nine names above, so the new set was not on disk yet. The captions above come from the file names; open each picture to confirm what it shows. The old welcome and tour frames show a tour the app no longer opens on and must not be uploaded. Before you upload, run this: it lists both folders, which must hold exactly the nine names, and then prints 36 if every file is 1320 x 2868.

```bash
cd ~/ownhub/docs/release/launch-pack/screenshots/apple-6.9 && ls en ar && sips -g pixelWidth -g pixelHeight en/*.png ar/*.png | grep -cE "pixel(Width: 1320|Height: 2868)"
```

*For Rahma's filming day*

## Moves to film for the three splits

The library has 79 filmed moves and no cardio at all. Where a move in her splits is not filmed, the closest filmed move stands in under that move's own clip. These 13 moves have only a stand-in, so they are the ones to film. Every other line in her splits uses a filmed move as she wrote it.

| Coach's move | Stand-in the app shows now | Where | To film |
|---|---|---|---|
| Treadmill (20 to 30 min) | Mountain climbers clip, named "Treadmill" | 4 day D4, 5 day D5 | A short treadmill loop |
| Elliptical | Mountain climbers clip, named "Elliptical" | 5 day D3 | A short elliptical loop |
| Leg extensions | Pendulum squat | 3 day D2, 4 day D2, 5 day D1 | Leg extension |
| Hack squat | Seated leg press | 5 day D1 | Hack squat |
| Leg adduction (adduction machine, "Add") | Dumbbell sumo squat | 3 day D2, 4 day D2, 5 day D1, 5 day D4 | Adduction machine |
| Leg abduction (abduction machine) | Side-lying clamshell | 3 day D3, 4 day D3 | Abduction machine |
| Side kicks | Side-lying clamshell | 4 day D2 | Side kicks |
| Wall sit | Bodyweight squat with arm swing (reps, not a hold) | 3 day D2 | Wall sit, as a hold |
| Walking lunges, lunges | Dumbbell reverse lunge | 3 day D3, 4 day D3, 5 day D1 | Walking lunge |
| Toe touches | Reach crunch | 3 day D3, 5 day D5 | Toe touch |
| Hollow hold | Flutter kicks (held) | 3 day D3, 5 day D1 | Hollow hold |
| Leg raises | Flutter kicks (held) | 4 day D4 | Leg raise |
| Alternating leg switches | Lying bicycle legs | 5 day D5 | Alternating leg switch |

### Two things for Rahma to say

- 5 day D4 "(abduction/add)": does it mean abduction, adduction or both? The app reads it as adduction only. If it means both, a second move is added (the side-lying clamshell stands in for abduction).
- Cardio: until real treadmill and elliptical clips exist, each is a 10 minute block shown with the mountain climbers clip. It also shares that move's history and "Last time" value with the real mountain climbers.

> Film them the way the first 79 were filmed, then add each one in the dashboard's Exercises tab with its safety tags. The app only shows a move once it has a clip, so nothing breaks while filming is pending. A closing stretch is added to every day (the app needs one as the last move); it is not one of her moves. Full list: `.claude/handoff-store-pass/splits-to-film.md`.

*For Rahma*

## Allergen lists for her 39 book recipes

> Rahma must confirm each list below. The allergy filter trusts signed recipes, so a missing allergen here could reach a woman who avoids it. These lists were derived on 20 Oct, after her 19 Oct sign-off. Anything wrong or missing should be told to you so the recipe data can be corrected before launch.

| Recipe | Arabic name | Allergens listed |
|---|---|---|
| BBQ Burger | برجر باربكيو | gluten, milk, soy |
| Bagel | بيجل | eggs, gluten, milk, sesame |
| Banana pudding | بودينج الموز | gluten, milk |
| Btates bel lahma | بطاطس باللحمة | milk |
| Buffalo sweet Wings | أجنحة بافلو سويت | celery, mustard |
| Cheese cake | تشيز كيك | gluten, milk, soy |
| Chia Pudding | بودينج الشيا | milk |
| Chicken Pizza | بيتزا فراخ | eggs, gluten, milk, sesame, soy |
| Chicken Ranch Salad | سلطة فراخ رانش | celery, eggs, gluten, milk, mustard, soy |
| Chicken lemon | فراخ بالليمون | celery, sesame |
| Club Sandwich | كلوب ساندويتش | gluten, milk, sesame, soy |
| Coconut apple Pudding | بودينج جوز الهند والتفاح | coconut, milk |
| Cookies with shay blabn | كوكيز مع شاي بلبن | milk, peanuts |
| Cottage Freshy salad | سلطة جبنة قريش فريش | gluten, milk, sesame, soy |
| Creamy cottage cheese | جبنة قريش كريمي | eggs, gluten, milk, sesame, soy |
| Crepe | كريب | eggs, gluten, milk |
| Egg Pizza | بيتزا البيض | eggs, gluten, milk, soy |
| Fattah | فتة | gluten, milk |
| Fool & Ta3mya | فول وطعمية | fava, gluten, sesame |
| French toast | فرنش توست | eggs, gluten, milk, soy |
| Hwawshi | حواوشي | celery, gluten, milk, mustard |
| Ice cream | آيس كريم | milk |
| Kebda Meal | وجبة كبدة | celery, gluten, milk, sesame, soy |
| Lahma bel basl | لحمة بالبصل | celery, gluten, mustard |
| Lazy Cake | كيكة الكسالى | eggs, gluten, milk |
| Lazy Ranch Fries | بطاطس رانش للكسالى | celery, gluten, milk, mustard |
| Makrona Bashmel | مكرونة بشاميل | celery, gluten, milk |
| Oven Tender Chicken | فراخ طرية في الفرن | celery, mustard |
| Overnight oats | شوفان بايت | gluten, milk, sulphites, tree_nuts |
| Pancakes | بان كيك | eggs, gluten, milk |
| Pizza toast | توست بيتزا | gluten, milk, sesame, soy |
| Potato w Eggs | بطاطس بالبيض | eggs |
| Shakshoka | شكشوكة | eggs, gluten |
| Shrimp white sauce pasta | مكرونة جمبري بالوايت صوص | celery, crustaceans, gluten, milk |
| Simple oat meal | شوفان بسيط | gluten, milk |
| Steak Meal | وجبة ستيك | milk |
| Tuna Wrap | راب تونة | celery, fish, gluten, mustard, soy |
| Yummy Egg Sandwich | ساندويتش بيض يجنن | eggs, gluten, milk, soy |
| shorbt 3ads | شوربة عدس | celery, gluten, milk, soy |

Updated 22 Oct 2026 for Own Hub 1.0.0, round 2. Production commands are yours to run.
