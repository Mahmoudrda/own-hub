# Compliance inventory, Own Hub 1.0.0+1

**Rewritten 23 September 2026, for the smaller first release.** Everything here was read out of
`lib/domain/flags/feature_flags.dart`, `pubspec.yaml`, `pubspec.lock`,
`android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Runner/PrivacyInfo.xcprivacy`
and the Dart source. Nothing here is a plan or an intention.

This file is the source of truth for the privacy policy, the App Store privacy label and the Play
Data safety form, and **all four must say the same thing.**

---

## Read this first: what the first release is

`FeatureFlags.shipped` in `lib/domain/flags/feature_flags.dart` is the authority, and it is short.

| Switched on | Screens |
|---|---|
| `today` | Home, the day, the week, the first-week states |
| `train` | The programme, the workout player, the library, the summary |
| `eat` | The day, the plates, typing a meal, the recipes |
| `cycle` | My cycle, the calendar, check-ins, cycle settings and sharing |
| `progress` | The week, personal bests, milestones, private measurements |
| `privacyCentre` | Her profile, her privacy switches, the safety centre, "Your data" |

| Switched off | Why, in one line |
|---|---|
| `accountRequired`, `signUp`, `verification` | An account needs somewhere to live, and verification needs an identity provider |
| `community` and its four children | Moderation means a person and a queue, not a list in memory |
| `coachApp`, `coachPlanning`, `coachPortfolio`, `coachedLife` | Coaching needs two real accounts |
| `marketplace`, `payments` | And money that moves, through a contracted rail |
| `assistant` | A model behind a server function |
| `adminConsole` | It is for the people who run the product, and it is compiled out of a release build |

Every one of them is off for the same reason rather than for taste: **it needs a back end that does
not exist.** None of it is deleted, none of it is untested, and turning one back on is one line.

**What that makes the app.** She installs it, opens it, and she is on Home. There is no front door
to pass. The bar at the bottom carries **three tabs, Home, Train and Eat**, because `tabsFor` in
`lib/ui/app_nav_bar.dart` drops any tab whose feature is off, and Community was the fourth. My cycle
and Progress are reached from Home and from her profile. Nothing she does leaves the handset, and
what she does is written to the handset so it is still there tomorrow.

### How "off" is enforced, not just declared

| Mechanism | Where | What it does |
|---|---|---|
| Flag gate on every route | `AppRouter.onGenerateRoute`, via `featureForFlow` | A screen whose flow is off renders `FeatureOff` instead of itself, even from a deep link |
| Parent flags | `Feature.parent`, `FeatureFlags.isOn` | A child of an off feature is off. There is no reachable orphan |
| Ungated by design | the `account` and `onboarding` flows | A flag flip must never trap a woman inside an app she cannot leave. Her privacy centre and her deletion are not a feature to toggle |
| The console is compiled out | `AppRouter.resolvesInThisBuild` | In a release build every `admin` route returns null, which is the same answer a typo gets |
| Testing aids need a debug build | `AppRouter.testingAidsAllowed`, which is `kDebugMode && !featureFlags.isOn(Feature.accountRequired)` | The index of every screen, the printed sign-in code and the test payment rail cannot exist in a release binary. No flag and no runtime switch can turn them back on |

`test/release_readiness_test.dart` asserts all five, and `tool/release_preflight.sh` repeats the two
that can be read from source.

---

## 1. Dependencies

Complete. There is nothing in `pubspec.yaml` that is not in this table.

### Shipped in the binary

| Package | Version | What it does here | Network? | Device data? |
|---|---|---|---|---|
| `flutter` | SDK | The framework | no | no |
| `flutter_localizations` | SDK | Arabic and English, including right to left | no | the device locale, on device |
| `intl` | any | Date and message formatting. `NumberFormat` is banned product wide so an Arabic build never renders Eastern Arabic digits | no | the device locale |
| `meta` | any | `@immutable` on domain types, so domain code stays testable with no widget tree | no | no |
| `crypto` | any | sha1, for deterministic content ids on meal items, plates and grocery lines. **Not a security boundary and not transport encryption** | no | no |
| **`shared_preferences`** | **^2.3.0, resolved 2.5.5** | **New.** The one place anything she does is written. One JSON document, one key, on her own handset | **no** | writes and reads the platform preference store |
| **`url_launcher`** | **^6.3.2, resolved 6.3.2** | **New.** Hands a URL to the platform browser. Used by three rows and nothing else: privacy policy, terms, support | no, it opens a browser rather than fetching | no |
| `cupertino_icons` | ^1.0.8 | Icon font | no | no |
| **`home_widget`** | **^0.10.0, resolved 0.10.0** | **New.** Writes the widget payload to the App Group `group.com.ownhub.app` and asks iOS to redraw the widgets. Also opens the screen a widget tap names | no | writes one key to the App Group's UserDefaults |

### Dev only, never in the shipped binary

`flutter_test`, `fake_async` (controls time so the five second undo window is tested without
sleeping), `analyzer` (parses Dart source for the guard test that proves the cycle feature contains
no analytics call site), `flutter_lints`, and **`flutter_launcher_icons` ^0.14.4, new**, which
generated the iOS and Android icon sets from the 1024 master and never runs at runtime.

### The two new plugins both ship their own iOS privacy manifest

This matters, because Apple aggregates the app's manifest with every framework's manifest, and a
required-reason API with no declared reason is refused at upload.

| Plugin | Version | What its `PrivacyInfo.xcprivacy` declares |
|---|---|---|
| `shared_preferences_foundation` | 2.5.7 | No tracking, no tracking domains, no collected data types, and one accessed API: `NSPrivacyAccessedAPICategoryUserDefaults` with reason **`1C8F.1`**, accessing information from the same app |
| `url_launcher_ios` | 6.4.2 | No tracking, no tracking domains, no collected data types, no accessed API types |
| `home_widget` | 0.10.0 | **Ships no manifest.** It writes the widget payload to the App Group through UserDefaults, so `ios/Runner/PrivacyInfo.xcprivacy` declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason **`1C8F.1`** itself |

### The Home Screen and Lock Screen widgets

| Item | Where | What it is |
|---|---|---|
| Widget extension target `OwnHubWidgetsExtension` | `ios/OwnHubWidgets/`, bundle id `com.ownhub.app.OwnHubWidgets`, iOS 15.5, iPhone only | Two widgets: "Your week" (small, and Lock Screen circular, rectangular, inline) and "Today" (medium). SwiftUI only, no pods, no Flutter, no network code |
| Extension privacy manifest | `ios/OwnHubWidgets/PrivacyInfo.xcprivacy` | No tracking, no collected data types, UserDefaults reason `1C8F.1` |
| App Group `group.com.ownhub.app` | both entitlements files | The only channel between app and widget. Holds one JSON string: open or closed, language, day and week ids, sessions done and target, today's state, meal logged, and the sentences to show. Never cycle, life stage, weight, measurements, kcal, allergies or a programme title (`lib/features/today/domain/widget_projection.dart`) |
| URL scheme `ownhub` | `ios/Runner/Info.plist` | `ownhub://widget?homeWidget=1&to=T01\|R03\|P01\|E01`, mapped through a whitelist and pushed through the router, so the verification gate applies. `FlutterDeepLinkingEnabled` is off |
| App Privacy labels | App Store Connect | No change. The widget reads data already on the phone and sends nothing |

`shared_preferences` was chosen over a file under the application support directory for exactly this
reason: a file store needs the file-timestamp APIs Apple covers by its required-reason rules, so it
would mean hand-authoring and maintaining `PrivacyInfo.xcprivacy` in this repository, and getting it
wrong is a refused upload rather than a note in review.

### Bundled assets

| Asset | Licence | Shipped? |
|---|---|---|
| Rubik, four weights, the whole interface in both scripts | SIL OFL 1.1 | **The licence text is not bundled.** See section 11 |
| La Belle Aurore, the Latin hand face | SIL OFL 1.1 | Text at `assets/fonts/OFL-LaBelleAurore.txt`, registered in `main.dart` |
| Aref Ruqaa, the Arabic hand face | SIL OFL 1.1 | Text at `assets/fonts/OFL-ArefRuqaa.txt`, registered in `main.dart` |
| `assets/art/`, illustrations at 1x, 2x and 3x | Owner's own artwork | yes |
| **`assets/icon/icon-1024.png` and `icon-foreground.png`** | Owner's own | **New.** A typographic monogram generated from the brand. The iOS `AppIcon.appiconset` and every Android `mipmap-*` are generated from it and are in the tree. It is a placeholder the owner may replace |

**Nothing in this table talks to a network.** That is why sections 3 and 4 are empty.

---

## 2. Permissions

### Android

**`android/app/src/main/AndroidManifest.xml` declares no `<uses-permission>` at all. Not one.**
There is a `<queries>` entry for `PROCESS_TEXT`, which the Flutter engine adds and which is not a
permission.

`android.permission.INTERNET` appears only in the `debug` and `profile` manifests, the stock Flutter
entries that let hot reload talk to the tooling. **A release bundle carries no internet permission.**

`shared_preferences_android` needs no permission: the preference file is inside the app's own private
storage. `url_launcher_android` needs none either; it hands an intent to the system.

### iOS

**`ios/Runner/Info.plist` contains no `NS*UsageDescription` key of any kind**, because nothing in the
app requests a permission. No camera, no photo library, no microphone, no location, no contacts, no
calendar, no HealthKit, no motion, no tracking, and no notification registration.

### What each permission would need behind it

| Permission | Today | The feature that would justify it |
|---|---|---|
| `INTERNET` (Android) | **not declared in release** | Any backend call, whenever one lands |
| `NSCameraUsageDescription` | absent | ID and selfie capture, and community photos. Both features are off |
| `NSPhotoLibraryUsageDescription` | absent | A community post from the gallery. Off |
| `NSMicrophoneUsageDescription` | absent | Voice meal logging, and community voice notes. Neither is wired |
| Notification permission | **asked in context only** | Two opt-in uses, each asked when she taps its button and never at launch: "Tell me when I'm in" on C14 (one push, firebase_messaging, token in `users/{uid}/devices`), and training reminders offered once on R10 after her first finished session and changed or turned off in A01 (scheduled on the phone with flutter_local_notifications, nothing leaves the device). Android declares POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED; no exact-alarm permission |
| `NSUserTrackingUsageDescription` | absent | **must stay absent.** The product does no tracking and shows no ads |
| `READ_EXTERNAL_STORAGE`, `QUERY_ALL_PACKAGES`, `READ_PHONE_STATE`, `AD_ID`, background location | absent | **must stay absent.** Each one triggers a Play policy form and often a rejection |

**A purpose string and the package that needs it must land in the same change.** iOS terminates an
app that opens the camera with no usage string, and that is an instant rejection.

---

## 3. Data sent off the device

**None. The app has no way to send anything.**

Provable rather than asserted:

* `pubspec.yaml` carries no `http`, no `dio`, no `firebase_*`, no `cloud_firestore`, no `supabase`,
  no `grpc` and no `web_socket_channel`.
* There is no `HttpClient`, no `Socket`, no `WebSocket`, no `NetworkImage`, no `Image.network` and no
  WebView anywhere under `lib/`.
* The app defines no `MethodChannel` or `EventChannel` of its own.
* The release Android manifest requests no internet permission.
* `url_launcher` is in the build, and it is not a network client. `lib/app_state/open_link.dart` is
  the only file that calls it, three rows call that, and it opens the address in **the platform
  browser** with `LaunchMode.externalApplication`. The app fetches nothing, renders no remote
  content, and has no in-app browser. Those rows are drawn only when `lib/config/legal_links.dart`
  has an address, so the app never shows a control that opens nothing.
* The only other URL strings under `lib/` are citations inside doc comments and two literal `'https'`
  scheme checks used to **reject** an unsafe URL in a coach's portfolio block, which is off anyway.

### What is stored, and where

**This is the one thing that changed since the last revision, and it changed on purpose.** Until it
existed, closing the app lost the session she had just logged, the meal she had just recorded, her
cycle, her settings and her language. An app that forgets the week is not a fitness app.

| | |
|---|---|
| The files | `lib/app_state/local_persistence.dart` and `lib/app_state/app_snapshot.dart` |
| Where it goes | The handset's own preference store: `NSUserDefaults` on iOS, the app's private `SharedPreferences` file on Android. Inside the app sandbox, readable by nothing else |
| How much | **One JSON document under one key**, `own_hub.snapshot`. The plugin prefixes it with `flutter.` on the platform side |
| What is in it | `schema`, `savedAt`, and ten sections: `today`, `progress`, `train`, `meals`, `eat`, `cycle`, `privacy`, `dietary`, `intake`, `language` |
| What is deliberately not in it | Content that ships with the app, such as the workout and food libraries. A meal or a set still inside its five second undo window, because it was never written. Where she was standing: the month she had scrolled to, the session she was midway through |
| When it writes | On `AppChanges`, debounced by 400 ms, and immediately on `paused` and `detached` |
| When it reads | Once, in `main()`, before `runApp`, so the first screen she sees is already hers |
| When it is erased | When she deletes everything. See section 5 |
| If it is corrupt | A missing, empty, truncated, foreign or older document restores nothing and the app opens on its defaults. Decoding is separate from applying, so there is no half-restored store, and `restore` never throws |

**None of that is collection.** Under both stores' definitions, data that stays on the device and
never reaches the developer or a third party is **not collected**. There is no code path from this
document to anywhere else: nothing reads it but the app, nothing uploads it, nothing copies it to a
server of ours, and no analytics library exists to sample it.

| Category, in store vocabulary | This release | The day a backend lands |
|---|---|---|
| Contact info: phone number, name | **not collected.** There is no sign-up and no name field on the shipping path | Collected, linked, not tracking |
| Identifiers: account id, device record | **not collected.** There is no account | Collected, linked, not tracking |
| Health and fitness: workouts, sets, meals, weekly goal, measurements, **cycle days and symptoms** | **not collected.** Written to her own handset and nowhere else | Collected, linked, not tracking, **never sent to analytics** |
| User content: posts, comments, photos | **not collected.** The community is off and there is no camera | Collected, linked, not tracking |
| Sensitive info: national ID, date of birth | **not collected.** Verification is off | Read inside a server function, only the outcome retained |
| Usage data | **not collected** | Only if an analytics SDK is added, and none is |
| Diagnostics, crash logs | **not collected** | Only if a crash reporter is added, and none is |
| Location, financial info, contacts, calendar, files, browsing history, purchases | **not collected** | Not collected |

---

## 4. Third-party SDKs that receive data

**None.** No analytics, no crash reporting, no ads, no auth provider, no payment provider, no AI
provider, no attribution SDK. The two new packages are platform wrappers: one writes to the device's
own preference store, the other hands a URL to the device's own browser. Neither has a server.

`lib/domain/analytics/analytics_gateway.dart` defines an analytics vocabulary: a closed event enum,
a closed property enum, and values that can only be a flag, a token or a bucketed range, with no free
text field anywhere. **It is instantiated zero times.** Not even the null sink is constructed.

The repository root holds `firebase.json`, `firebase/firestore.rules` and `firebase/storage.rules`.
**The app carries no Firebase SDK and cannot reach any of it.** They are design references the Dart
types mirror, not a data flow.

---

## 5. Accounts, sign-in, and deletion

### There is no account

`Feature.accountRequired`, `Feature.signUp` and `Feature.verification` are all off. `main.dart`
opens the app on `T01`, Home. No phone number is asked for, no code is sent, no password exists, and
nothing identifies the handset. **A reviewer needs no credentials, because there is nothing to sign
in to.**

The sign-up screens are still in the binary and still tested. They are not a door anyone walks
through: every `signup` route renders `FeatureOff`.

### What that means for Apple 5.1.1(v)

Apple's account-deletion requirement applies to **apps that support account creation**. This one does
not, so the guideline is not triggered. Say that plainly in the review notes rather than leaving a
reviewer to work it out.

### She can still delete everything, and it is worth describing

| | |
|---|---|
| Where | Profile (`A02`), the **Your data** row. It opens a sheet, not a screen |
| What the sheet says | That deleting takes away her meals, workouts, measurements, cycle, posts and answers, that it happens at once and cannot be brought back; that **this build keeps everything on this phone, so deleting clears the phone, and nothing of hers is held anywhere else**; and that downloading a copy is not built, so there is no button for it |
| One step, not two | The sheet explains, and the button under the explanation does the thing. Asking again would be a second confirmation of a decision she has already read the consequences of |
| What runs | `deleteEverythingOnThisPhone()` in `lib/app_state/account_data.dart`, in the documented order: sign out, terminate Firestore (a no-op, there is none), clear persistence, purge local measurements, destroy the photo store key (a no-op, there is no camera) |
| The snapshot goes first | `clearPersistence` calls `LocalPersistence.erase()` **before** it empties the stores, and the cancellation of any pending write is synchronous. Without that, everything she deleted would be back the next time she opened the app |
| It cannot be held hostage | The platform removal is not awaited. A store that is slow, wedged or missing still leaves every store empty, and the screen still says so |
| Afterwards | The navigation stack is popped to the first route and she is told, in her own language: "Your data is gone. The app is back to its first day." |
| Proved by | `nothingOfHersRemains` in the same file, which the journey test asserts |

**There is no export.** The sheet says so in a sentence rather than offering a button that would spin
and produce nothing, which is the failure Apple 2.1 is actually about.

---

## 6. Monetization

**Nothing in this release can be bought, by anyone, in any way.**

| | |
|---|---|
| In-app purchases | **None.** No StoreKit, no Play Billing, no `in_app_purchase`, no `com.android.vending.BILLING` |
| Subscriptions | **None** |
| Payment outside the store | **None.** `Feature.payments` and `Feature.marketplace` are both off, so no checkout screen resolves and no price is shown anywhere |
| Ads | **None.** No ad SDK, no advertising identifier, no `AD_ID` permission |
| Restore purchases | Not applicable. There is nothing to restore |

**So there is no external-payment argument to make on either store, and the whole of Apple 3.1.3(d)
and Play's payments policy is out of scope for this release.** The coaching payment design exists in
the repository, in domain types with no rail behind them. Do not describe it in a store form and do
not mention it in review notes: an argument offered for a capability the binary does not have is an
invitation to go looking for it.

The answer to "does your app allow purchases" is **no**, on both consoles, without a footnote.

---

## 7. Encryption

OS-provided TLS only, and today not even that, because nothing makes a network call.
`package:crypto` provides sha1 for deterministic document ids, not to protect data in transit, and no
crypto library is bundled.

**`ITSAppUsesNonExemptEncryption = false` is therefore correct**, and it is declared in `Info.plist`.
Revisit it only if a bundled crypto library is ever added.

---

## 8. AI features

**None ships.** `Feature.assistant` is off, so `X01` renders `FeatureOff` and no composer exists.

| | |
|---|---|
| What is behind the feature | The unavailable provider, the only implementation, which throws "not implemented". The safety classifier has the same shape, deliberately with no keyword fallback, because a guardrail that is seventy percent right is worse than one that is honestly absent |
| The API key | **Absent, with nowhere to put one.** There is no key parameter, field or constructor argument anywhere in the feature. A test scans all of `lib/` for key-shaped literals, for vendor endpoints and for any name that would give a key somewhere to live, with positive and negative controls. `tool/release_preflight.sh` repeats the scan in shell |
| What the payload could not carry, even then | Her name, her weight, her measurements, her photos and **her cycle data**. None of them has a field to travel in |

**Apple Guideline 5.1.2(i)**, explicit consent before personal data reaches a third-party AI, does
not apply to this release: nothing reaches one, and the screen that would is switched off. It applies
the day a provider is attached, and the consent UI does not exist.

---

## 9. User-generated content

**There is none in this release.**

`Feature.community` is off and so are its four children, so every `community` route renders
`FeatureOff` and the Community tab is not drawn at all. There is no posting, no commenting, no
stories, no groups, no follows, no likes, no messaging, no profile another woman can see, and no
photo or video capture of any kind. The app has no camera, no gallery access and no microphone.

**Apple Guideline 1.2 is not triggered, and Play's UGC policy is not triggered.** So:

* There is no filtering obligation, because there is nothing to filter.
* There is no moderation rota to staff, because nothing is published.
* There is no report queue to build, because there is no other member to report.

**Do not claim moderation this release does not need.** A store answer or a review note describing
report flows, a moderation team or community standards would be describing a build the reviewer does
not have, and the first sentence a reviewer disproves costs the rest their credibility.

Two surfaces still reference the community and are reachable, which section 11 lists as work: the
Safety Centre (`A04`) and three of the four switches on the privacy screen (`A03`).

---

## 10. Age of audience

**Not directed at children, and intended for adults.**

**There is no age gate in the code**: no minimum-age constant, no date-of-birth field, no check and
no screen. Since there is no account and no verification in this release, there is nothing for an age
gate to attach to either. `min_age` appears once, as the name of a future remote-config key inside a
doc comment.

This is a smaller problem than it was. With no community, no coaching, no purchases and no data
leaving the phone, the release is a personal training and tracking tool, and the rating both stores
compute from an honest questionnaire is low. The **membership** rule, women only and a minimum age,
is a product and legal question for the release that reintroduces accounts. It does not block this
one, and nothing in this release claims to enforce it.

`[OWNER: the minimum age still has to be settled with an Egyptian lawyer before accounts ship, and
the number must then appear identically in the policy, the terms, the app's own gate and both age
ratings.]`

---

## What is built and switched off, so the next release does not start from nothing

None of this is deleted and none of it is untested. The crawler, the journey tests and the large-text
sweep build `FeatureFlags.everything`, so a screen that is dark in this release is still walked and
still proved rather than quietly rotting until the release that turns it on.

| Area | State in the repository | What it needs before it can ship |
|---|---|---|
| Sign-up, `C01` to `C16` | Screens built. Phone and code screens wired to a fake auth repository that accepts one code | An auth provider, and a real error path: no wrong-code, expired-code or offline sentence is wired to `C07` |
| Verification, `C09` to `C15` | Screens built. The capture service is the unavailable one, so the camera path is a dead end. The niqab route books a woman reviewer and never resolves, by design: the client cannot grant itself a result | A camera package with its usage strings, an identity provider under a data-processing agreement, and a server function that writes the result |
| Community, the `M` flow | Posting, comments, likes, saves, follows, groups, stories, report, block and mute, all built, text only, in memory | Moderation that reaches a person, a block that actually hides her (the hidden-authors set is read in five places and written in none), content filtering, and a rota |
| Coach app, planning, portfolio, coached life | Built: enquiry, accept, plan a month, publish, the client's plan, chat, weekly review | Two real accounts, and certificate checks |
| Marketplace and payments | Built as screens and domain types. The refusing provider is what the screens get | A contracted Egyptian rail, a signed webhook, and the store arguments that section 6 says to leave alone until then |
| The assistant, `X01` | Screen built, provider unavailable, no key anywhere | A model behind a server function, and the 5.1.2(i) consent UI |
| Admin console, `Z01` to `Z14` | Built, and **compiled out of a release build** | Nothing. It should stay out of the store binary |

---

## 11. What blocks a submission

### The code must do these

Ordered by how quickly a reviewer meets them. The first two are reachable from Home in under a
minute.

| # | What | Which rule it fails |
|---|---|---|
| 1 | **She cannot choose her language.** Profile, then **Language**, routes to `C02`, which is in the `signup` flow, which is off, so it renders the `FeatureOff` panel. `main.dart` pins the locale to a stored preference or to `en`, and does not read the device locale, so the app opens in English on an Egyptian handset and there is no way to change it. Arabic is complete in the binary and unreachable | Apple 2.1, a dead row. It also makes the Arabic store listing and the bilingual line in both descriptions untrue |
| 2 | **Four controls open the "Switched off" panel.** `T01`'s top bar, the "Ask something" icon, goes to `X01`. `T01`'s day-one card "Beginners group" goes to `M01`. `R10`, the finished-session screen, "Share" goes to `M03`. `A02` "My coach" goes to `H01`. Each callback is passed unconditionally by the router, and none of the four views asks the flag | Apple 2.1, non-functional buttons. Google treats it as broken functionality |
| 3 | **The `FeatureOff` panel itself is developer text, in English only**: "Switched off. This screen is built and tested; its feature flag is currently off." It is a fine internal state, and it must be unreachable in a store build, which is what fixing 1 and 2 achieves | Apple 2.1 |
| 4 | **On a severe cycle day, both care buttons are dead, and one of them now lies.** Logging severe cramps or heavy bleeding suppresses the workout, which is the right behaviour, and then offers "Find care near you", answered with "maps are not connected in this build", and "Read NHS guidance on period pain", answered with "opening web links is not connected in this build". **The second sentence is no longer true: `url_launcher` is in the build.** This is the one screen in the product where a dead control is worst | Apple 2.1, and a credibility problem on a health surface. It is also exactly the "not in this build" copy `release-checklist.md` section 0 forbids |
| 5 | **The same screen cites British NHS guidance to Egyptian women.** The care directory is `CareDirectory.bundled` and no Egyptian list is authored | Not a store rule. It is the highest-liability copy in the app, and it ships in this release because My cycle does |
| 6 | **Naming an allergy empties the Eat tab.** `A02` captures allergies, `AllergyGuard` fails closed, and **`foods.allergens[]` is unauthored**, so every dish reads as unknown and therefore unsafe. Her suggestion lists screen to nothing and every log is refused. The screens say so out loud rather than failing silently, which is the right behaviour for the wrong situation | Apple 2.1 if a reviewer names an allergy, and a product defect either way. Fix the content, not the guard |
| 7 | **`E03`, "Say it", cannot hear anything.** There is no speech package. Tapping the microphone reaches the refused state and offers the keyboard, which is honest, and it is still a feature in the shipping build that does not work | Apple 2.1. Either hide the screen for this release or author the recogniser |
| 8 | **`A04`, the Safety Centre, is about a community that does not ship.** It is reachable from Profile and offers reports, blocked members and "Talk to a human". "Report someone" answers with a notice saying to report her from her post, and there are no posts | Apple 2.1, and it is incoherent copy on the one screen that must not be |
| 9 | **Three of the four privacy switches on `A03` govern features that are off**: profile visible to members, show my personal bests, and my coach can see my logs, with face blur governing photos that cannot be taken. Only the cycle sharing row and the policy and terms rows describe this release | Apple 2.1 |
| 10 | **`A01`, Notifications, cannot notify.** There is no notification plugin in the app, nothing schedules a reminder, and the router passes no `onRequestPermission`, so the permission row has no action behind it | Apple 2.1 |
| 11 | **`A02`'s "Your data" row reads "Delete your account and everything in it"** in an app with no account. The sheet behind it is accurate; the subtitle is not | Minor, and it is the one sentence a reviewer reads before tapping the one control that matters most |
| 12 | **Rubik's OFL licence text is not bundled, and nothing in the app displays the licences that are registered.** There is no licences page, no about dialog and no `showLicensePage` call anywhere | An OFL obligation, and roughly one line of code plus one text file |
| 13 | **No crash reporting.** A crash during review is the largest single rejection bucket, and today nobody would ever see one | Apple 2.1, by consequence |
| 14 | **`lib/config/legal_links.dart` is empty**, so the in-app privacy policy, terms and support rows are not drawn at all. They exist and are correct; they are waiting on four addresses | **Apple 5.1.1** and Google's User Data policy, both of which want the policy reachable from inside the app. `tool/release_preflight.sh` fails while any of the four is blank |

Items 1, 2 and 4 decide whether this release can be submitted. Everything from 3 to 11 is a screen
that should be hidden or finished before a reviewer taps it, and each is a small change: the flag is
already there to ask.

**A search worth running before every submission.** Every remaining "not connected in this build"
and "not in this build yet" sentence is a rejection sitting in the dictionary. Grep the ARB files for
`ThisBuild` and walk each call site. In this release the reachable ones are the two on the severe cycle day, and three in Eat: "Share" on a recipe, "See steps" on a recipe, and "Share" on the grocery list.

### The owner must do these

| # | What | Blocks |
|---|---|---|
| 1 | **Generate the upload keystore** and write `android/key.properties`. Until then release builds are debug signed, and Play refuses the upload. The preflight reads this from the built bundle and currently reports it signed with the debug key | The Android upload itself |
| 2 | **Fill in the Team ID** in `ios/ExportOptions.plist`, which still holds the placeholder | The iOS build |
| 3 | **Buy a domain and publish four live pages**: `/privacy`, `/terms`, `/support`, `/delete-account`, in English and Arabic, then fill in `lib/config/legal_links.dart` | Both consoles, and code blocker 14 above |
| 4 | **Decide whether the generated app icon is the final one.** `assets/icon/icon-1024.png` is a typographic monogram made from the brand, and it is a placeholder you may replace. Replacing it is one file and one command | Nothing today. It is your name on her home screen |
| 5 | **Capture every store screenshot from the current build**, English and Arabic | Both listings |
| 6 | **Author an Egyptian care source** to replace the NHS citation, or have a clinician sign the current copy off | Code blocker 5 |
| 7 | **Register both developer accounts.** A personal Play account created after 13 November 2023 needs a 14 day closed test with 12 real testers, per app | About three weeks of calendar time |
| 8 | **Legal review** of the policy, the terms and the deletion page | Publication |
| 9 | **Register the App Group** `group.com.ownhub.app` in the Developer portal and enable App Groups on the App ID `com.ownhub.app` | The iOS build with widgets |
| 10 | **Create the App ID** `com.ownhub.app.OwnHubWidgets` with App Groups enabled, and a provisioning profile for it, or let Xcode sign automatically once the Team ID is set on both targets | The iOS build with widgets |
| 11 | **Sign off the widget paragraph** in privacy policy section 3.5, logged as a minor update to v3.0, and the Arabic word for widget (أداة) with the MSA reviewer | Publication |
