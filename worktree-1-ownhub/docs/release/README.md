# Release readiness, status and index

**23 September 2026.** The owner cut the scope of the first release after these documents were last
written. They have all been rewritten against `FeatureFlags.shipped` and the current source.

## The one-line answer

**The release is now a small, honest app, and that is a much better place to be submitting from.**
She opens it and it is hers: Home, Train, Eat, My cycle, Progress and her own data, with no account,
no server and nothing sent anywhere. The store forms got dramatically simpler. What still stops a
submission is a short list of controls that open a "Switched off" panel, and four things only the
owner can do. The full list is `compliance-inventory.md` section 11.

## What the first release is

| On | Off, because each needs a back end that does not exist |
|---|---|
| Today (Home), Train, Eat, My cycle, Progress, the privacy centre | Accounts, sign-up, verification, the entire community, the entire coach and coaching side, the marketplace, payments, the assistant, and the admin console |

Three consequences run through every document in this folder:

1. **There is no account**, so there is no sign-up, no login and no reviewer credentials. Apple's
   account-deletion requirement, 5.1.1(v), applies to apps that support account creation and is not
   triggered here. The app still offers "delete everything on this phone" from Profile, and it
   really deletes, including the stored document.
2. **There is no user-generated content**, so Apple 1.2 and Play's UGC policy are not triggered, the
   IARC user-interaction answers are all "no", and the age rating gets simpler. We do not claim
   moderation this release does not need.
3. **There is no payment of any kind**, so there is no in-app purchase question and no
   external-payment argument to make.

## What changed in the app since the last revision

| | Then | Now |
|---|---|---|
| Scope | The whole product, gated behind an account | Six features on, everything else dark. `FeatureFlags.shipped` is the authority |
| The front door | `C01`, Welcome, then sign-up and an ID check nobody could pass | `T01`, Home. There is no door |
| The tab bar | Four tabs, including Community | **Three tabs: Home, Train and Eat.** `tabsFor` drops any tab whose feature is off |
| Persistence | None. Closing the app lost everything | **One JSON document on the handset**, written debounced and on pause, read before the first frame, erased on deletion. `lib/app_state/local_persistence.dart` and `app_snapshot.dart` |
| In-app deletion | A row that did nothing | Profile, Your data, a sheet that explains, and a wipe that clears every store and the stored document |
| Dependencies | 6 | 8, plus one dev tool: `shared_preferences`, `url_launcher`, and `flutter_launcher_icons`. Both new plugins ship their own iOS privacy manifests |
| The app icon | Did not exist | `assets/icon/icon-1024.png`, a typographic monogram generated from the brand, with the iOS and Android icon sets generated from it. **A placeholder the owner may replace** |
| In-app policy and terms links | Impossible, the app could not open a URL | Rows exist on `A03`, drawn as soon as `lib/config/legal_links.dart` has addresses |
| Testing scaffolding | Gated on the account flag | Gated on `kDebugMode`, because the account flag now ships off. Proved by test and by the preflight |
| Backend | None | **Still none**, and now deliberately so for a whole release rather than by accident |

---

## 1. The documents

| File | What it is | State |
|---|---|---|
| `compliance-inventory.md` | What the app actually does: the flag shape, dependencies, permissions, data, SDKs, accounts and deletion, money, encryption, AI, user content, age. **The source of truth the rest derive from.** It also records what is built and switched off, so the next release does not start from nothing. Section 11 is the blocker list | Current |
| `privacy-policy.md` | Draft for legal review. Part A is this release: nothing is collected, everything stays on her phone. Part B is the day a server is connected | Draft, needs a lawyer |
| `terms.md` | Draft for legal review, written for a release with no account, no community, no coaching and no payments. Section 12 parks the clauses that arrive with those | Draft, needs a lawyer |
| `delete-account.md` | The public page. It explains that there is nothing on our side, and how the in-app deletion works | Draft |
| `play-listing.md` | Every Play Console field, paste-ready, English and Arabic, with Data safety and the IARC questionnaire answered question by question | Current |
| `appstore-listing.md` | Every App Store Connect field, same, with App Privacy and the age rating answered question by question | Current |
| `review-notes.md` | Much shorter than it was. There is nothing a reviewer cannot reach, so it is one paste-ready notes box and a short list of what the app deliberately does not do | Current |
| `tester-invite.md` | The recruitment message for Play's 14 day, 12 tester closed test, and five things to try that the release can actually do | Current |
| `build-environment.md` | The toolchain as installed, the three new dependencies, and what is deliberately not in the build | Current |
| `release-checklist.md` | Run it the morning you submit. Four gates specific to this app, then the generic phase 8 | Current |

All store copy in these files is written with **no em dashes and no en dashes**, in English and in
Arabic, matching the rule the app's own copy follows.

---

## 2. What is already correct in the project

| | State |
|---|---|
| The shipping shape | `FeatureFlags.shipped`, asserted by `test/release_readiness_test.dart`: it opens on Home, draws no Community tab and carries no testing index |
| Testing scaffolding | Cannot exist in a release binary. `testingAidsAllowed` is `kDebugMode && !accountRequired`, checked by test and by the preflight |
| The admin console | Compiled out. In a release build every `admin` route resolves to nothing, and a deep link naming one opens Home |
| Release signing | Reads a real keystore from `android/key.properties`, falling back to the debug key only when it is absent. **The keystore does not exist yet**, and the preflight now reads that fact from the built bundle |
| `compileSdk` and `targetSdk` | Pinned to 36 |
| `minSdk` | Pinned to 24 |
| R8 and resource shrinking | On, with a minimal `proguard-rules.pro` |
| 16 KB page alignment | Checked against the built `.aab`, and passing. The app ships plugins now, so the check is real |
| iOS encryption declaration | `ITSAppUsesNonExemptEncryption` is false, which is correct |
| Privacy manifests | The app's own is accurate and in the Xcode Runner target, and both new plugins carry their own |
| App icon | Master present, iOS and Android sets generated |
| Orientation and devices | Portrait only, iPhone only |
| Secrets | Keystores, provisioning profiles, `key.properties`, `.env` and both Firebase service configs are ignored by version control. The history holds none of them |
| Build health | `flutter analyze` clean, whole suite passing, on a quiet tree |
| Preflight gate | `tool/release_preflight.sh`: 27 passed, 4 failed, 1 skipped. All four failures are owner actions |

---

## 3. What the code must do before a submission

Fourteen items in `compliance-inventory.md` section 11. The three that decide it:

1. **Make the language row work**, or follow the device locale. Profile, then Language, opens the
   "Switched off" panel today, and the app is pinned to English while Arabic sits complete and
   unreachable in the binary.
2. **Stop four controls opening that panel**: "Ask something" and "Beginners group" on Home, "Share"
   on the finished-session screen, and "My coach" in Profile.
3. **Fix the severe cycle day.** Both care buttons are dead, and one of them says web links are not
   connected in this build, which stopped being true when `url_launcher` was added.

Then the smaller ones: the allergy content, the Say it screen, the Safety Centre, three of the four
privacy switches, the notifications screen, the "delete your account" subtitle, the Rubik licence,
and crash reporting.

---

## 4. Yours, and nobody else can do these

| | What | Where |
|---|---|---|
| 1 | **Generate the upload keystore.** `keytool -genkey -v -keystore ~/keys/ownhub-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`, then write `android/key.properties`. Back the file up in a password manager **and** offline | Local |
| 2 | **Fill in the Team ID** in `ios/ExportOptions.plist` | developer.apple.com, Membership |
| 3 | **Buy a domain and publish four pages**: `/privacy`, `/terms`, `/support`, `/delete-account`, in English and Arabic, then put the addresses in `app/lib/config/legal_links.dart`. Until then the app draws no policy row and the preflight fails | Static host |
| 4 | **Decide whether the generated app icon is the final one** | Local |
| 5 | **Take the screenshots from the current build**, English and Arabic. Check the bar: three tabs | Device |
| 6 | **Author an Egyptian care source** for the severe-symptom screen, or have a clinician sign off the NHS citation that ships there today | Clinical |
| 7 | **Register both developer accounts.** Apple is 99 dollars a year, Play is 25 dollars once. A personal Play account created after 13 November 2023 needs a 14 day closed test with 12 real testers per app, which is about three weeks. Start it early | Consoles |
| 8 | **Legal review** of the policy, the terms and the deletion page | Lawyer |
| 9 | **Settle the minimum age** with counsel. It does not block this release, and it blocks the one that adds accounts | Lawyer |

**Not on this list any more:** the demo account, the moderation rota, the payment provider decision,
and the "does community ship in 1.0" question. The scope decision answered the last one, and the
first three follow from it.

---

## 5. Run this before you submit

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd app
bash tool/release_preflight.sh

# once the public site is live
RELEASE_BASE_URL=https://<domain> bash tool/release_preflight.sh
```

The script is expected to fail today on the keystore, the debug-signed bundle, the Team ID and the
legal links. It is telling the truth, and it should stay red until those exist.

**It does not walk the app.** `release-checklist.md` section 0.2 is the walk, and it is where the
dead controls in section 3 above get caught.

---

## 6. Not done, and why

* **No crash reporting.** The guide calls a crash during review the largest single rejection bucket,
  and nobody would currently see one. It needs a project to exist first, and it changes both store
  privacy answers on the day it lands.
* **No physical-device testing.** Simulator and emulator only. The guide's device matrix is genuinely
  required before submission, and persistence is the newest thing in the build and the one most worth
  testing by hand: log, swipe away, reopen, delete, restart.
* **No export.** The deletion sheet says so in a sentence rather than offering a button that would
  produce nothing.
* **The allergen data is unauthored**, so naming an allergy empties the Eat tab. The guard is
  correct and fails closed; the content behind it does not exist.
* **The switched-off half of the product is still in the binary.** That is deliberate and tested:
  the crawler and the journeys build `FeatureFlags.everything`, so nothing rots while it is dark.
