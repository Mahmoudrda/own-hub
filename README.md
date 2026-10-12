# Own Hub

A women-only fitness app for Egypt: quiet home workouts, food she already cooks, a cycle-aware week,
and a space only verified women can enter. Flutter on iOS and Android, Arabic and English as equals,
one custom hand-drawn design language on both platforms, and a Firebase backend in Frankfurt
(europe-west3).

This file is the onboarding guide. Read it top to bottom on your first day; every section ends with
the files to open next.

- Website: https://own-hub.app (Arabic at /ar/)
- Contact: info@own-hub.app (privacy), support@own-hub.app (support)
- Firebase project: `own-hub`
- Store ids: `com.ownhub.app` on both stores, the iPhone widget is `com.ownhub.app.OwnHubWidgets`,
  the App Group is `group.com.ownhub.app`, the Apple team is `NC94DG55XR`

---

## Contents

1. [The product in one page](#1-the-product-in-one-page)
2. [Day one: get it running](#2-day-one-get-it-running)
3. [Where everything is](#3-where-everything-is)
4. [How the app works](#4-how-the-app-works)
5. [The backend](#5-the-backend)
6. [The admin console: content without an app update](#6-the-admin-console-content-without-an-app-update)
7. [Releasing](#7-releasing)
8. [Keeping the bill small](#8-keeping-the-bill-small)
9. [Rules the code enforces](#9-rules-the-code-enforces)
10. [Traps newcomers fall into](#10-traps-newcomers-fall-into)

---

## 1. The product in one page

**Who it is for.** Women in Egypt, 18 and over, often training at home on a budget Android phone,
around family. Membership is women-only and checked once against the national ID card.

**What a member does.**

| Tab | What it is |
|---|---|
| Today (Home) | This week's count of sessions against her target, today's workout, a meal, the cycle card if she turned it on, upcoming events if the owner turned them on |
| Train | A short session she can do quietly at home. One tap per set, five seconds of undo, no confirmation dialogs |
| Eat | Add what she ate in one tap or by typing ("koshari and tea"), Rahma's recipe book, a week of dinners, a grocery list, allergy guard |
| Progress | Weeks trained, milestones, personal bests, her body measurements (kept on the phone only), and her shareable progress card |
| My cycle | Symptoms she notes today shape the suggestion. Never an inferred phase. Severe symptoms bring medical guidance instead of a workout |

**What it refuses to do.** No ranking of women, no daily streaks (progress counts weeks, not days),
no calorie countdowns, no weight-loss claims, no red "you failed" states. These are product rules,
not taste, and tests enforce them (section 9).

**What is built but switched off.** The community, the coach app and marketplace, coached plans,
payments, the assistant and voice logging. All are written and tested, and all are off in the
shipped flags until their back ends and moderation exist (section 4.7).

**People.** Rahma Mohsen founded the brand and wrote the recipe book; Mahmoud Reda publishes the app
(the store accounts are personal, not a company).

---

## 2. Day one: get it running

### 2.1 Tools

| Tool | Version | Used for |
|---|---|---|
| Flutter / Dart | 3.47.4 stable / 3.13.3 | the app |
| Xcode | 26 or later (App Store Connect refuses older since April 2026) | iPhone builds, on a Mac |
| Android SDK | 36 (compileSdk and targetSdk 36, minSdk 24), JDK 17 | Android builds |
| Node | 22 | the generators in `6-v2/src`, the rules tests, Wrangler for the website |
| Python | 3.12 virtualenv in `functions/.venv` | Cloud Functions, their tests, the owner tools |
| JDK 21 | | the Firebase emulators (rules tests) |
| firebase-tools and gcloud | current | deploys and owner scripts |

### 2.2 Files you need that are not in git

These hold keys or project config and are gitignored on purpose. Ask the owner for them.

| File | Without it |
|---|---|
| `app/android/app/google-services.json` | Android builds fail (the google-services plugin is applied) |
| `app/ios/Runner/GoogleService-Info.plist` | iPhone builds fail; one release test fails |
| `app/android/key.properties` and the upload keystore (`~/keys/ownhub-upload.jks`, alias `upload`) | A release Android build stops with an error. It never falls back to the debug key |

`app/lib/firebase_options.dart` **is** committed. Never commit the three files above, a `.p8`, a
`.p12`, a keystore or any `.env`; the `.gitignore` already refuses them.

### 2.3 First run

```sh
cd app
flutter pub get
flutter run                                   # debug build, talks to production Firebase
flutter run --dart-define=OWNHUB_LOCALE=ar    # force Arabic
```

The shipped flags require a verified account, so a fresh install opens on the welcome screen (C01)
and every product screen sits behind sign-up and the ID check. **To walk every screen without an
account, use the tests**, which build the app with every feature on and no account required:

```sh
flutter test test/journeys                    # whole features, walked as a member would
OWNHUB_QA_REPORT=/tmp/crawl.tsv flutter test test/qa/tap_crawler_test.dart   # opens every screen
```

Useful `--dart-define` values (debug and profile builds only unless noted):

| Define | What it does |
|---|---|
| `OWNHUB_EMULATOR_HOST=127.0.0.1` (or `10.0.2.2` on the Android emulator) | Auth, Firestore and Functions go to the local emulators on the ports in `firebase.qa-emulator.json` |
| `OWNHUB_APP_CHECK_DEBUG_TOKEN=<token>` | App Check debug token. Register it in Firebase console > App Check first, or every server call answers `app_check_missing` |
| `OWNHUB_ANALYTICS_DEBUG=true` | Sends usage events to Firebase DebugView, still only after the consent switch is on |
| `ADMIN_BUILD=true` | Includes the admin console (never in a release build) |
| `APP_VERSION=1.0.0+…` | The version recorded beside every consent. The build scripts set it |

### 2.4 Tests

```sh
cd app
flutter analyze            # strict; the generated l10n files are excluded
flutter test               # about 5,200 tests; one needs GoogleService-Info.plist

cd ../functions
python3.12 -m venv .venv && .venv/bin/pip install -r requirements.txt pytest
.venv/bin/python -m pytest # about 1,230 tests: functions, the website build, the waitlist

cd ..
firebase emulators:start --config firebase.emulator.json --only firestore,auth --project own-hub
cd test/rules && npm ci && npm test   # about 340 security-rules tests, in another terminal
```

Notable test folders in `app/test`:

| Folder | What it proves |
|---|---|
| `journeys/` | end-to-end features as a member walks them |
| `release/` | consent gates, privacy guards, the build scripts, store disclosures |
| `qa/` | the tap crawler, the large-text sweep, regression rounds |
| `routing/analytics_events_test.dart` | every usage event fires where it should, with nothing personal |
| `product_rules_test.dart`, `i18n_guard_test.dart`, `nav_reachability_test.dart` | the product rules, translation parity, that every screen can be reached |
| `store/store_screenshots_test.dart` | renders the store screenshots from the real app (section 7.4) |

---

## 3. Where everything is

| Path | What it is | Ships? |
|---|---|---|
| `app/` | The Flutter app | yes |
| `functions/` | Python Cloud Functions (2nd gen, europe-west3). `main.py` lists every function | deployed |
| `firebase/` | `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `storage.library.rules`, and `ops/` scripts | deployed |
| `firebase.json` | Project config: rules, indexes, both storage buckets, the functions codebase | config |
| `firebase.emulator.json` / `firebase.qa-emulator.json` | Emulator ports for the rules tests / for running the app against emulators | dev |
| `site/` | The public website: static HTML, no JavaScript, English and Arabic. Built by `site/_build/build.py` from `config.json` and `pages_en.py` / `pages_ar.py` | Cloudflare Pages |
| `6-v2/` | The design source and generators: screen inventory, design tokens, the Arabic dictionary | generates app code |
| `test/rules/` | The Firestore rules suite (Node), run against the emulator | dev |
| `contracts/` | Shared contracts (deletion manifest, identity contract) tested from both the app and the functions | tests |
| `scripts/privacy_scan` | Scans Firestore, Storage and logs for anything that looks like a national ID or an image | ops |

### 3.1 Inside `app/lib`

| Folder | What it holds |
|---|---|
| `main.dart` | The launch sequence (section 4.1) |
| `routing/app_router.dart` | Every screen builder, the gates, the shared repositories. Large on purpose: navigation edges are written as literal `goTo(context, 'R07')` calls so a test can prove every screen is reachable |
| `routing/app_routes.dart` | **Generated.** 185 screens across 17 flows |
| `features/<area>/` | One folder per area, each with `domain/` (rules, models), `presentation/` (screens), sometimes `data/` (Firebase readers) |
| `app_state/` | App-wide services: Firebase boot, the phone's own store (`local_persistence.dart`), the cloud copy (`cloud_store.dart`), consent, analytics, crash reports, remote features, the recipe and workout library syncs, reminders, the iPhone widget sync |
| `domain/` | Cross-cutting rules with tests: analytics gateway, feature flags, the undo bus, rewards (weeks, never streaks), safety tags, life-stage policy |
| `ui/` | The component kit (`app_button`, `app_card`, `app_scaffold`, `app_toggle`...) and `ui/hand/`, the hand-drawn layer including the kitten |
| `theme/` | `app_tokens.dart` is **generated**; `hand_tokens.dart`, `hand_theme.dart`, `app_art.dart` are hand-written |
| `l10n/` | **Generated** strings: `app_en.arb`, `app_ar.arb` and the `AppL10n` class |
| `config/` | `legal_links.dart` (the four public pages and the privacy mailbox), `team_contact.dart`, `care_links.dart`, `admin_build.dart` |

### 3.2 Screen ids

Every screen has an id from `6-v2/src/inventory.mjs`, and its route is `/<flow>/<id>`, for example
`/train/r07`. The letter tells you the area:

| Letter | Area | In the store build? |
|---|---|---|
| C | Sign-up and the women-only ID check (C01 to C16, C09b, C10b) | yes |
| O | First-run questions (O01 to O05) | yes |
| T | Today / Home (T01 to T09) | yes (T09 needs the events switch) |
| R | Train (R01 to R13) | yes |
| E | Eat (E01 to E11) | yes (E03 "say it" is off) |
| P | Progress (P01 to P05) | yes |
| Y | My cycle (Y01 to Y14) | yes |
| A | Account: notifications, profile, privacy, safety (A01 to A04) | yes |
| Z | Admin console (Z01 to Z18) | admin builds only |
| G, M, H, K, B, W, X | Coached life, community, coach marketplace, coach app, coach brand, coach planning, assistant | built, switched off |

---

## 4. How the app works

### 4.1 Launch (`app/lib/main.dart`)

1. A release build refuses to start if any of the four public page addresses is empty
   (`config/legal_links.dart`).
2. Her data is read from the phone before the first frame, so Home is drawn from what she did.
3. Consent choices (crash reports, usage statistics) and the kitten setting are read.
4. Firebase starts (`app_state/firebase_boot.dart`). It can never stop the app from opening.
5. Her verification state is read, with a five-second limit and an offline fallback.
6. The app is drawn. After the first frame: the recipe library, the remote feature switch and the
   workout library are refreshed (each at most once a day).

### 4.2 Gates, in order (`routing/app_router.dart`)

- **Build gate:** admin screens exist only in debug or admin builds, never in release.
- **Feature gate:** a screen whose feature flag is off cannot be opened, even by a deep link.
- **Verification gate:** with `accountRequired` on, a signed-out phone goes to C01, an account
  waiting for a reviewer to C14, an unverified account to the consent screen C09b. Sign-up,
  first-run questions, account and admin screens are open before verification.
- **Camera gate:** no camera opens before her consent to the ID check is recorded on the server.

### 4.3 Sign-up and the women-only check

1. C01 welcome, C02 language, C03 what's inside, C04 the tour ("look around first": the real screens
   with a sample week, nothing can be saved), C05 join.
2. C06 her Egyptian mobile number (+20 only). She accepts the terms and privacy policy here, and is
   offered the "Help improve Own Hub" switch.
3. C07 the six-digit SMS code (Firebase phone sign-in). "Send it again" waits 30 seconds after each
   code, because every SMS is billed.
4. C09b consent to the ID check, recorded by the `record_consent` function.
5. C10 the front of the ID card, C10b the back, C11 a selfie with a liveness challenge.
6. C12 the server checks it (`verify_identity`): text recognition of the card (Cloud Vision, EU
   endpoint), the 13th digit of the national ID number (the women-only gate, no face-based gender
   guessing), a duplicate check against a keyed hash of the ID number, liveness, and a face match.
   The images exist only in memory for that one call and are never stored.
7. C13 "You're in" (the `verified` claim is minted), or C14 waiting for a woman reviewer, or a retake.
8. C15 is the niqab path: a woman reviewer instead of the camera, by phone within 72 hours.

**Store reviewers and the owner** sign in with test phone numbers and are let through the ID check
by the allow-list secrets `store-reviewer-phones` / `store-reviewer-uids` (section 5.4). Fill them
only while a review is open; an account let through keeps its `verified` claim afterwards.

### 4.4 Her data: the phone first, the cloud second

- Everything she does is saved on the phone first (one JSON snapshot, `app_state/local_persistence.dart`),
  so the app works offline and opens instantly.
- When she is signed in and verified, `app_state/cloud_store.dart` copies it to Firestore under
  `users/{uid}/…`, with document ids made from dates so a retry never duplicates. Merging is
  "union by id, the phone wins, nothing is removed".
- **Health data stays on the phone** (cycle, check-ins, measurements and weight, life stage,
  allergies) unless she turns on the health backup. That records a separate consent, and the rules
  refuse health writes without it. Turning it off withdraws the consent and deletes the cloud copy.
- Logging uses a five-second undo bus (`domain/logging/log_command_bus.dart`): an undone action
  never reaches storage.

### 4.5 Usage statistics and crash reports

Both are **off until she turns them on**, separately, and the SDKs are disabled natively until then.

- Every event goes through `domain/analytics/analytics_gateway.dart`. Keys and values are closed
  enums, so sending a phone number, a weight, a recipe title or any typed text does not compile.
- 31 events fire in the store build: the tour, each sign-up step, each ID-check outcome (never why),
  the first workout and meal, sets, early finishes, meals, the weekly target, reminders, code
  resends, language, the kitten switch, a return after a quiet week, a copy-of-my-data request and
  sharing the progress card. Their Firebase names are in `analyticsEventWireNames`.
- No user id is ever set, there is no advertising identifier on either platform, and cycle data
  never reaches analytics (a test guards each of these).

### 4.6 Content libraries that update without an app release

| Library | Read from | Cached on the phone as | Refreshed |
|---|---|---|---|
| Recipes | `meta/recipes` (version), then `recipeIndex/en_v{N}` and the recipe documents | `own_hub.recipes` | at most once a day, verified accounts only |
| Workout programmes | `meta/workouts`, then `workoutLibrary/v{N}` | `own_hub.workouts` | at most once a day |
| Events | `events` where `status == 'published'` | in memory | at most once an hour, only when the events switch is on |
| Feature switches (events on, any part off) | `meta/features` | | each launch |

Rahma's 39 bundled recipes and the bundled day-one workout are always the floor: a remote library
can add and replace, never remove them. One invalid recipe or programme makes every phone refuse
the whole new version and keep the previous one, so the console checks with the same code first.

### 4.7 Feature flags (`domain/flags/feature_flags.dart`)

**Every feature has its own flag, and so does every new one.** Each thing a woman can do is a
`Feature`: the big areas (Today, Train, Eat, Progress, My cycle) and the parts inside them (recipes,
the week plan, the grocery list, the share card, the workout library, the cycle calendar and so on).
A new feature gets a new `Feature`, with a parent if it lives inside another, a line in
`FeatureFlags.shipped`, and its screens in `lib/routing/screen_features.dart`. It arrives off and is
switched on when it is ready. `test/domain/flags/every_feature_has_a_switch_test.dart` fails the
build when a screen has no switch, a feature is missing from the shipped list, or a switch opens
nothing.

- `FeatureFlags.shipped` is what the stores get: sign-up, verification and the account gate on, with
  Today, Train, Eat, Progress, My cycle, the privacy centre and every part inside them. The
  community, the coach side, the marketplace, payments and the assistant are off. Nothing in the
  launch is paid.
- Flags have parents; switching one off switches off everything inside it. A screen opens only when
  its flow's switch and its own switch are both on.
- **The server can stop a broken part without a release.** `meta/features` holds `{name: false}`
  for any feature whose `serverMayTurnOff` is true, and every member's app takes it at her next
  launch. It can switch on only `events`; `true` on anything else just lifts an earlier stop. It can
  never switch off sign-up, verification, the account gate, Home or the privacy centre. In the
  console (Z14), "For every member" holds these stops; the switches above it change only the phone
  in your hand.
- A control that leads into a part that can be stopped is drawn only while
  `AppRouter.screenIsOn` is true for its screen. `r2_19_no_dark_edges_test.dart` switches each part
  off in turn and fails on any door left behind.
- Turning the community or coaching on needs an app update, plus the `communityLive()` /
  `coachLive()` switches in both storage and Firestore rules and `COACH_APP_LIVE` in the functions.

### 4.8 Strings and the two languages

- Arabic is polished Egyptian Arabic (owner decision, 2026-10-12): warm, educated Cairene, never
  street slang, addressed to a woman (feminine second person). Legal and consent wording (the
  camera consent, the woman-reviewer consent, the pledge, the health-backup consent, the terms line
  on `C06`, the legal update sheet, the medical disclaimer) stays in Modern Standard Arabic, because
  each is a recorded agreement with a version number. Western digits in both languages. No em
  dashes in product copy.
- **All strings are generated.** The dictionary is `6-v2/i18n/` (English source to Arabic), and a
  string's getter name comes from the first seven words of its English text.
- To add strings, write a JSON file and run the helper. It takes a lock, merges, regenerates and
  prints each getter name:

```json
{ "strings": { "Share my card": "مشاركة بطاقتي" },
  "parameterised": { "{weight} kg": { "placeholders": { "weight": { "type": "String" } } } } }
```

```sh
cd app && python3 tool/add_strings.py strings.json
```

- Changing an existing English string changes its getter name: edit the source in
  `6-v2/i18n/msa/*.json` (or `ar-extra.json`), run `node 6-v2/src/merge-i18n.mjs`,
  `node 6-v2/src/build-flutter.mjs`, then `flutter gen-l10n` in `app/`, and rename the references.

### 4.9 Look and feel

- Colours, type, radii and motion are generated from `6-v2/src/tokens.mjs` into
  `app/lib/theme/app_tokens.dart` (`node 6-v2/src/build-flutter.mjs`). Rubik for everything,
  La Belle Aurore and Aref Ruqaa for the hand-written notes. Light theme only.
- `ui/hand/` draws the hand-made marks: underlines, circled figures, ruled lines, cut-paper cards
  (three tight corners and one loose one) and the kitten mascot. Every mark respects Reduce Motion.
- The website copies the same palette, type weights (400, 500, 600) and cut corners
  (`site/assets/site.css`).

---

## 5. The backend

### 5.1 Functions (`functions/main.py`)

Every callable checks, in order: App Check (enforced, `config.ENFORCE_APP_CHECK = True`), sign-in,
and the sign-in provider (members: phone only; staff: phone or password).

| Purpose | Functions |
|---|---|
| Consent and legal records | `record_legal_acceptance`, `record_consent`, `record_health_consent`, `record_pledge` |
| The ID check | `start_verification`, `verify_identity` |
| Woman-reviewer queue | `request_review`; reviewers use `list_verification_flags`, `get_review_contact`, `schedule_verification_review`, `decide_verification_flag`; `expire_stale_reviews` runs hourly |
| Owner console | `admin_dashboard`, `admin_logs` (admin claim, phone sign-in, every read logged) |
| Account deletion | `delete_account`, and `resume_account_deletions` every 15 minutes |
| Website waitlist | `join_waitlist` (public HTTP, no App Check: honeypot, 50 attempts per address a day, 5,000 new entries a day) |
| Dormant | the two community counters, the four coaching callables |

Memory is 512 MiB for every function except `verify_identity` (1 GiB, for the face model). At most
5 instances per function, 20 for `verify_identity`, 1 for the public waitlist. OpenCV loads only in
the verification calls.

### 5.2 Who may read and write what (`firebase/firestore.rules`)

Claims are minted by the server, never read from documents:

| Claim | Means | Set by |
|---|---|---|
| `verified` | passed the women-only check; opens the product | `verify_identity`, a reviewer's decision, or the store-reviewer allow-list |
| `admin` | writes the content library, events and `meta`; reads the library | `functions/tools/grant_admin.py` only |
| `womanReviewer` | may work the review queue (checked in functions) | `functions/tools/grant_reviewer.py` |
| `coachV`, `tier` | dormant | |

- A member writes only her own documents under `users/{uid}`, and only from a phone sign-in.
- The content library (`exercises`, `foods`, `programs`, `recipes`, `recipeIndex`, `meta`,
  `workoutLibrary`) is read by verified members and admins, written by admins. A recipe write also
  needs `allergenReviewedBy` set and different from `authoredBy` (two people check allergens).
- Members read only published events. Server-only collections (verification records, the ID hash
  registry, the waitlist, the console's logs) are closed to every client.

### 5.3 Storage

| Bucket | Holds | Rules |
|---|---|---|
| `own-hub-personal` (Frankfurt) | her own media when the community or coaching is on; exports | `firebase/storage.rules`. There is no path for ID images at all |
| `own-hub.firebasestorage.app` (us-east1) | the content library's pictures and clips, `content/{collection}/{docId}/{file}` | `firebase/storage.library.rules`: signed-in read, admin write, under 200 MB |

### 5.4 Secrets (Secret Manager, project `own-hub`)

| Secret | For |
|---|---|
| `nid-hash-pepper` | the keyed hash of ID numbers |
| `store-reviewer-phones`, `store-reviewer-uids` | the store-review allow-lists (empty except during a review) |
| `waitlist-ip-key` | the keyed hash of website visitors' addresses |
| `flag-webhook-url` | optional chat alert when a review is requested |

Opening and closing a store review:

```sh
printf '+201000000001\n+201000000002\n' | gcloud secrets versions add store-reviewer-phones --data-file=- --project=own-hub
printf '\n' | gcloud secrets versions add store-reviewer-phones --data-file=- --project=own-hub   # close
```

### 5.5 Deploying the backend

There is no `.firebaserc`; always pass `--project own-hub`. The Firebase CLI deploys Python
functions from a virtualenv inside `functions/`: recent versions use `functions/.venv` (the one the
tests use), older ones `functions/venv`, and the error names the one it wants. If neither exists,
make one once:

```sh
cd functions && python3.12 -m venv venv && venv/bin/pip install -r requirements.txt && cd ..
```

```sh
firebase deploy --only firestore:indexes --project own-hub     # first; wait until they are READY
firebase deploy --only firestore:rules --project own-hub
firebase deploy --only storage --project own-hub
firebase deploy --only functions --project own-hub
bash firebase/ops/ttl-policies.sh                              # automatic deletion; --list to check
bash firebase/ops/reviewer-secrets.sh                          # creates the empty allow-lists once
```

If a deploy fails with "Failed to list functions", run it again with `--debug` and read
`firebase-debug.log`; `firebase login --reauth` fixes an expired login.

---

## 6. The admin console: content without an app update

The console (screens Z01 to Z18) is how the owner adds recipes, workout programmes and events that
reach every member's phone **without a new app release**. It lives inside a special build of the
app on the owner's phone.

### 6.1 Getting in (once)

1. **Register an App Check debug token**: Firebase console > App Check > Apps > the Android or iOS
   app > Manage debug tokens > Add. Keep the token private; anyone holding it passes App Check.
2. **Build the admin app** (a profile build with the console; it refuses to make a release build):

```sh
cd app
OWNHUB_APP_CHECK_DEBUG_TOKEN=<token> bash tool/admin_access.sh build   # Android APK in build/admin/
adb install -r build/admin/own-hub-admin-*.apk
# or, with an iPhone or Android phone connected by cable:
OWNHUB_APP_CHECK_DEBUG_TOKEN=<token> bash tool/admin_access.sh run
```

3. **Sign in** in the admin app with the owner's own phone number (the console accepts phone sign-in
   only). To also use the member side, let the account through the ID check once with the
   store-reviewer allow-list (section 5.4), then empty the list.
4. **Grant the admin claim** with owner credentials, then sign out and back in:

```sh
gcloud auth application-default login
bash tool/admin_access.sh grant <uid>        # the uid is in Firebase console > Authentication
bash tool/admin_access.sh check <uid>        # or: revoke <uid>
```

5. Open the console from Profile (A02) > Admin.

### 6.2 The screens

| Id | Screen | What it does |
|---|---|---|
| Z01 | Content library | The start page: counts per collection, rows missing a safety tag first, doors to everything below |
| Z02, Z04, Z06, Z07 | Exercises, foods, recipes, programmes | Lists with filters; add or open a row |
| Z03, Z05, Z12, Z13 | Edit an exercise, a food, a recipe, a programme | Forms with the same checks the member app uses |
| Z08, Z09 | Bulk import, import check | CSV import, all or nothing (choosing a file is not wired in this build) |
| Z10 | Media library | Every uploaded picture and clip |
| Z11 | Export | One CSV per collection, copied to the clipboard. Never member data |
| Z14 | Feature flags | Changes this phone only, for this run, except `events`, which every member's phone reads |
| Z15 | Dashboard | Members, open reviews and the oldest one's age, verification outcomes, waitlist, deletions, events, content counts. Counts only, names nobody |
| Z16 | Logs | Decisions, reviews, deletions, waitlist and errors per day, and who opened the console |
| Z17, Z18 | Events, edit an event | Draft, publish, cancel |

Saving writes the server first, then the console's local copy; without a connection it says
"Saved on this phone only". There is no delete: set a recipe or programme back to draft, or cancel
an event, to hide it. The console loads the library and the media register once per run, so
restart it after uploading pictures.

### 6.3 Add a recipe

1. Upload its photo first (on a computer with owner credentials). Pictures are resized to WebP:

```sh
cd app && bash tool/admin_access.sh upload-media recipes <recipeId> ~/Pictures/ful.jpg
```

2. In the console: Z01 > Recipes > Add. Fill the id (the same `<recipeId>`), the English and Arabic
   names, minutes, ingredients, allergens (`none` is an answer; blank is refused), diet tags, the
   photo file name the upload printed (for example `ful.webp`), the author, **"Allergens checked
   by" (a different person)**, the four macros or none, the method in Arabic (one step per line)
   and English, and one of the book's four sections.
3. Turn on "Show this recipe to members" and save. One save writes the recipe, a new recipe index and
   a new `meta/recipes` version.
4. Members' phones pick it up within a day. Rahma's 39 book recipes are bundled in the app and are
   changed only with an app update.

### 6.4 Add a workout programme

1. Make sure every exercise you need exists (Z02), each with its contraindication tags from this
   list: `high_impact`, `jumping`, `deep_knee_flexion`, `loaded_twisting`, `pelvic_floor_load`,
   `breath_hold_valsalva`, `prone_position`, `supine_load`, `overhead_load`, `wrist_load`, or `none`.
2. Z01 > Programmes > Add. Fill the id, names, weeks, days a week, session length, quiet, equipment.
3. In the sessions editor add each session: titles in both languages, minutes, who it is written for
   (nothing right now, after a birth, pregnant, a knee, back or shoulder), and its moves (sets, reps
   or a hold, rest, notes and a safety note in both languages).
4. Turn on "Show this programme to members" and save. Publishing refuses a session for pregnancy or
   after a birth that contains a move tagged `pelvic_floor_load`, `high_impact`, `jumping`,
   `supine_load` or `breath_hold_valsalva`.
5. Members see it in the workout library (R11) within a day; it lists only sessions that suit her
   life stage.

### 6.5 Create an event

1. Once only: Z14 > switch `events` on. This writes `meta/features` and every member's phone shows
   events from its next launch.
2. Z17 > Add. Titles in both languages (required), descriptions, start and end in Cairo time
   (`2026-11-01 18:30`), online with an `https://` link or in a place with its name, an optional
   capacity (shown, never counted). Save as a draft.
3. For a cover picture: the form shows the event id; upload under it, restart the console, pick the
   file:

```sh
cd app && bash tool/admin_access.sh upload-media events <eventId> cover.png
```

4. Publish. Members see it on Home (the next one) and in the events list within an hour. Cancel
   hides it.

### 6.6 What still needs an app update

UI text and translations; every feature flag except `events`; the legal links, team contact and care
links; design, illustrations, fonts and the kitten; Rahma's book and letter; the food pack used for
typing meals (foods saved in the console do not reach members yet); the day-one workout and the
first-run programmes; milestones, awards and tiers; the validation rules themselves.

Backend-only changes (no app update): verification thresholds, the review time limit and the caps
in `functions/identity/config.py` (redeploy the functions), the store-review allow-lists (Secret
Manager), the rules (deploy).

---

## 7. Releasing

### 7.1 Versions and build numbers

The version name comes from `app/pubspec.yaml` (`1.0.0`). The build number is set by the scripts as
the minutes since 1 January 2026 UTC, so it always goes up and both stores accept every new upload.
`BUILD_NUMBER=… bash tool/…` overrides it.

### 7.2 Building

```sh
cd app
bash tool/build_release.sh     # Android: the Play bundle (.aab) and split APKs, obfuscated
bash tool/build_ios.sh         # iPhone, on a Mac: the .ipa, checks first, prints how to upload
RELEASE_BASE_URL=https://own-hub.app bash tool/release_preflight.sh   # the gate before any submission
```

`build_ios.sh` stops with the fix in one sentence when App Store Connect would refuse the build
(Xcode older than 26, no Firebase config, no team, empty public pages), refuses an archive that
contains the advertising identifier, and uploads crash symbols. Upload the `.ipa` with the
Transporter app or from Xcode's Organizer. Both scripts print the Crashlytics symbol upload; keep
`build/symbols/` for as long as a build is installed anywhere.

### 7.3 Never hand out a universal APK

`flutter build apk --release` without `--split-per-abi` produces ONE file carrying machine code for
all three CPU families Android runs on. A phone runs exactly one of them, so two of the three are
dead weight on every handset that receives the file:

| in the universal APK | |
|---|---|
| the whole file | 98.9 MB |
| arm64-v8a, what every phone since about 2015 runs | 29.6 MB |
| armeabi-v7a, only for a 32-bit handset | 24.3 MB |
| x86_64, only for an emulator | 32.2 MB |
| **dead weight on any one phone** | **56.5 MB** |

Play splits the bundle per device, so a Play install is about 42 MB. An APK sent over WhatsApp is the
whole file, which is how a build often reaches someone in Egypt. Send `app-arm64-v8a-release.apk`.
The preflight fails when the only APK in the output is the universal one.

### 7.4 Store screenshots

They are rendered from the real app, 8 screens in English and Arabic at three sizes (Play 1080x1920,
Apple 6.3" and 6.9"):

```sh
cd app
OWNHUB_SCREENSHOTS_DIR=$HOME/ownhub/docs/release/launch-pack/screenshots flutter test test/store/store_screenshots_test.dart
```

### 7.5 The website

```sh
cd site && python3 _build/build.py                          # rebuilds site/ for the domain in config.json
site/_build/deploy.sh https://own-hub.app --dry-run          # builds a clean copy and checks it
npx wrangler login                                           # once
site/_build/deploy.sh https://own-hub.app                    # publishes to Cloudflare Pages
```

Every value on the legal pages (names, mailboxes, providers, dates, the permit) lives in
`site/config.json`. `functions/waitlist/join.py` `SITE_ORIGIN` must equal its `baseUrl` (a test holds
them together); redeploy `join_waitlist` after changing it. Mail is on Zoho: do not turn on
Cloudflare Email Routing, which would replace Zoho's MX records.

---

## 8. Keeping the bill small

At launch nearly all of the bill is the SMS for sign-in codes. The settings that keep it safe are in
the consoles, not the code:

- **Authentication > Settings > SMS region policy: allow Egypt only.** This is the main protection
  against SMS fraud, where bots request codes to premium numbers at your expense.
- **A billing budget with alerts** (for example 25, 50 and 100 USD) on the billing account.
- **Play Integrity quota**: ask for an increase in Play Console before 2,000 daily users (the default
  is 10,000 checks a day).
- **Cloud Vision quota cap** (APIs & Services > Quotas), for example 5,000 requests a day.
- **Artifact Registry cleanup policy** for old function images, in the functions' region (without
  `--location` it sets one for us-central1, where nothing runs):
  `firebase functions:artifacts:setpolicy --location europe-west3 --days 3 --force --project own-hub`.
- Keep minimum instances at 0 and never turn on BigQuery streaming export for Analytics.

What the code already does: the recipe and workout libraries are read at most once a day; the ID
check is capped per account, per day and globally before any paid call; the waitlist stops touching
the database for an address once it is over its daily limit; functions are sized to what they do.

---

## 9. Rules the code enforces

These came from research and legal checks. Breaking one is a defect, not a variation; most have a
test that fails.

1. A prescribed value is never a result: entries start empty.
2. A coach's message never changes a plan; only publishing does.
3. Weeks, not days. No daily streak counter, ever. Rest weeks repair a missed week.
4. Cycle suggestions follow symptoms she noted today, never an inferred phase.
5. Severe symptoms replace the workout with medical guidance.
6. Face blur is on by default for any uploaded image.
7. ID and selfie images are deleted after the check; only the result is kept.
8. No face-based gender classification. The gate is the ID number's 13th digit.
9. Undo, never a confirmation: no `showDialog` or `AlertDialog` for logging.
10. The assistant selects; it never generates.
11. Nothing is ranked by weight, weight lost, or followers.
12. Setup asks one thing per screen, with a step bar (`AppStepBar`) and the count in the title. Her
    setup and the coach's setup both work this way; a screen that asks several questions at once
    is a defect.
13. Everything ships free. A paid plan, when it exists, adds new things; it never takes away what
    members already use.

Also: the console never reads member data; no API key in the app; analytics carries nothing
personal; body figures never leave the phone unless she chooses (the weight switch on her progress
card is off every time).

**Code style.** Library-level `///` comments that explain why, with references to decision and spec
ids (D12, P0-EAT-01). Generators are run, never hand-edited. Navigation edges are literal
`goTo(context, 'ID')` calls.

---

## 10. Traps newcomers fall into

1. **Generated files.** Never edit `app/lib/theme/app_tokens.dart`, `app/lib/routing/app_routes.dart`,
   `app/lib/l10n/*` or `6-v2/flutter/*` by hand. Adding a screen means a line in
   `6-v2/src/inventory.mjs`, its markup in the matching `6-v2/src/screens-*.mjs`, regenerating,
   a builder in `app_router.dart`, and its switch in `lib/routing/screen_features.dart`.
2. **`*.md` is gitignored** except this README and `app/assets/art/LICENCE.md`. So are `docs/` and
   `*.xlsx`. Planning notes live on the owner's machine, not in git.
3. **App Check is enforced on every server call.** A debug or profile build needs a registered debug
   token; a store build needs App Attest (iOS) and Play Integrity (Android) registered in Firebase.
   The symptom is `app_check_missing`.
4. **Claims take up to an hour to reach the phone.** Sign out and back in after granting one.
5. **The console library loads once per run.** Restart it after uploading media.
6. **One invalid recipe or programme blocks the whole library update** on every phone. The console
   pre-checks with the same code; do not bypass it by writing to Firestore by hand.
7. **Emulator ports differ** between `firebase.json` (9099/8080/5001), `firebase.emulator.json`
   (9098/8088, rules tests) and `firebase.qa-emulator.json` (9299/8288/5101, the app).
8. **Store-review allow-lists stay empty** except during a review. An account let through keeps its
   `verified` claim.
9. **A real phone number must never be a Firebase test number.** A test number signs in with a fixed
   code and no SIM, so anyone who knows the code is that account.
10. **Privacy declarations follow the SDKs.** Adding an SDK that collects data means updating
    `ios/Runner/PrivacyInfo.xcprivacy`, `android/play-data-safety.txt` and the store answers.
11. **Two ways to move.** `goTo(context, 'X01')` pushes, for a link inside a screen, so back returns
    to it. `goToTab` is only for the bottom bar: it opens the tab with everything above Home closed,
    so tabs never pile up. Write `goTo` with a literal id: `nav_reachability_test` reads those
    literals to prove every screen can be reached.
12. **Wrap long lists, not every row.** `AppScaffold` scrolls a plain column, and each hand-drawn
    surface already has its own `RepaintBoundary` so a scroll does not re-ink it. A list that can grow
    without bound (a chat, a feed) belongs in a `ListView.builder`.
