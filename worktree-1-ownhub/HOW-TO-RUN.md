# Own Hub — how to open, run and build it

Everything below was verified on this machine, not assumed.

| | |
|---|---|
| Flutter | 3.47.4 (stable), Dart SDK `^3.13.3` |
| Xcode | 26.3 ✓ |
| Android SDK | 36.0.0 ✓ |
| App id, both stores | `com.ownhub.app` (`DECISIONS.md` D9) |
| Display name | Own Hub |
| Flutter binary | `~/development/flutter/bin/flutter` |

**Flutter is not on your shell's `PATH` by default.** Either prefix commands, or add it once:

```sh
export PATH="$HOME/development/flutter/bin:$PATH"
```

The app lives in `app/`. Run every command below from there.

---

## 1. The fastest way to see it

```sh
cd app
flutter run
```

Pick the iPhone simulator when prompted. That is the whole thing — no Firebase project, no API keys,
no signing. Every repository has a working in-memory fake, so the app runs end to end offline.

**Open any screen directly.** Screens are addressed by the same ids the design and the plans use:

```sh
flutter run --route /signup/c08    # "Which one are you?" — train / coach / both
flutter run --route /train/r01     # Train, with the bottom navigation
flutter run --route /train/r09     # Resting, with the countdown running
```

The full list of 161 routes is generated into `app/lib/routing/app_routes.dart`. An unrecognised
route falls back to the first screen rather than a blank page.

---

## 2. Opening it in Xcode

1. `open app/ios/Runner.xcworkspace`
   *(There is no `Podfile` in this project, so `Runner.xcodeproj` opens fine too. Use the workspace —
   it is what `flutter build` uses, and it stays correct if a plugin adds CocoaPods later.)*
2. Top-left device selector → choose an **iPhone simulator** (iPhone 17 Pro is installed).
3. Press **▶ Run**.

**For a physical iPhone, one extra step.** Signing is set to Automatic but **no development team is
configured**, which is correct for a fresh checkout and is the thing that will stop you:

1. Select the **Runner** project in the left sidebar → **Runner** target → **Signing & Capabilities**.
2. Set **Team** to your Apple ID / developer team.
3. Xcode will provision `com.ownhub.app` automatically.

If Xcode shows stale or missing generated files, run `flutter build ios --simulator --debug` once from
`app/` and reopen — that regenerates `ios/Flutter/Generated.xcconfig`.

---

## 3. Opening it in Android Studio

1. **Open** → choose the **`app/`** folder (not `app/android/` — open the Flutter project so the Dart
   tooling loads).
2. Let Gradle sync.
3. Choose a device and press **▶ Run**.

There is **no Android emulator configured on this machine yet** (`flutter emulators` lists only the
iOS one). Create one in Android Studio → Device Manager, or verify the build without a device:

```sh
flutter build apk --debug      # currently succeeds — this is how Android is verified here
```

Android `namespace` and `applicationId` are both `com.ownhub.app`; `minSdk`/`targetSdk` follow the
Flutter defaults.

---

## 4. Checking it is healthy

```sh
flutter analyze     # expect: No issues found!
flutter test        # expect: All tests passed  (476 tests)
```

Both are green as of this writing. Treat either going red as a blocker, not a warning — the test
suite is the gate this project is built around.

---

## 5. Changing text

**Never edit `app/lib/l10n/*.arb` or `app_l10n*.dart` by hand.** They are generated, and your edit
will be overwritten.

Source of truth is the dictionary under `6-v2/i18n/`:

```sh
node 6-v2/src/merge-i18n.mjs      # msa/*.json + ar-extra.json -> ar.json
node 6-v2/src/build-flutter.mjs   # -> ARB, and syncs into app/lib automatically
cd app && flutter gen-l10n        # -> AppL10n
```

`build-flutter.mjs` copies its output into `app/lib/` itself and tells you when the ARB changed. That
copy used to be manual, and forgetting it failed silently — `gen-l10n` would re-read the stale file
and a corrected string would appear uncorrected.

English and Arabic must stay at exact parity; a test enforces it.

---

## 6. What still needs plugging in

The app is complete as a client. Everything below is a **service**, and each one currently has a
working fake so the app runs and is testable without it.

| What | Faked by today | What to plug in |
|---|---|---|
| Phone sign-in | `FakeAuthRepository` | Firebase Phone Auth. Six-digit code is fixed by the provider (D2a) |
| ID verification | `FakeVerificationRepository` | The provider contract, behind a Cloud Function — **the client must never be able to verify itself** |
| All reads and writes | `InMemory*Repository` | Firestore. Rules and indexes are written and tested in `firebase/` |
| Camera / ID capture | `UnavailableCaptureService` | Platform camera, plus the permission copy that is still missing |
| Locale preference | `InMemoryLocalePreference` | Device persistence |
| The content library (Z01–Z13) | `InMemoryContentRepository`, seeded with 56 rows | Firestore, behind the same interface — no screen changes |
| Choosing a CSV, uploading media | `UnavailableTextSource`, `UnavailableMediaPicker` | `file_picker`, **plus a bytes channel beside `MediaFile`** — it carries name/size/kind, not content, so nothing reaches Cloud Storage yet |

Three rules that constrain how these are wired, and are not negotiable:

- **The Claude API key never ships in the app.** The assistant calls Claude from a Cloud Function. A
  key in the bundle is extractable by anyone who downloads it.
- **Never send phone number, name, ID result, weight, photos, or cycle data to Amplitude.** Cycle data
  never reaches analytics under any circumstance.
- **ID and selfie images are deleted after verification**; only the result is kept. C13 states this to
  her face, so it has to be true.

`firebase/firestore.rules` is written against one principle worth knowing before you edit it: rules
**OR** across matching blocks, so a specific rule cannot revoke a broader grant. `users/{uid}` has
exactly one ruleset, and a test asserts that.

---

## 6b. Running the security rules (needs one install you have to do)

`firebase.json` now exists and points at the rules and indexes, so the emulator is configured. **It
cannot start yet**, and the reason is worth knowing: the Firestore emulator is a Java process, and this
machine has no Java runtime. Until that changes, **no rule in this project has ever been executed** —
they are asserted as text by `firestore_rules_test.dart`, which can prove a line is present and cannot
prove it allows or denies anything.

That is the single largest verification gap in the project. It is also why `P0-DEL-01` — "delete my
account and nothing survives" — is marked NOT COVERED rather than passing.

To close it:

```bash
brew install --cask temurin      # or any JDK 11+
npm install -g firebase-tools
firebase emulators:start --project demo-own-hub
```

The `demo-` prefix matters: a project id starting with `demo-` runs entirely locally, needs no real
Firebase project and no credentials, and cannot touch production data.

Two things are still missing after that, and neither is a config change:

- **`functions/` does not exist.** The account-deletion callable, the notification writer and the
  `getCycleProjection` reader are all specified and none is written. `P0-DEL-01` needs the first one.
- **No rules tests exist.** With the emulator running, `@firebase/rules-unit-testing` is the tool; the
  cases to write first are in `6-v2/plans/G9-cycle.md` §6 ("a coach with an active, fully shared
  relationship attempting a direct `get` on `users/{client}/cycle/current` **must fail**") and G7 §6.

## 7. Where things are

```
app/lib/
  domain/          rules that must hold everywhere (logging, identity, training)
  features/<x>/
    domain/        repository interface + its in-memory fake
    presentation/  the screens
  routing/         app_router.dart, app_routes.dart (generated)
  ui/              the shared component kit
  l10n/            generated — do not edit
6-v2/
  i18n/            the dictionary (edit here)
  src/             the generators
  plans/           G1–G15, the feature plans
  tests/           acceptance suites and findings
DECISIONS.md       owner decisions D1–D11, and what is still open
PHASES.md          the three-phase build plan
```

Start with `DECISIONS.md`, then `6-v2/SCHEMA-SPINE.md`. They are authoritative; where a plan
disagrees with them, they win.

**`OPEN-QUESTIONS.md`** is the short list of everything waiting on the owner — decisions, installs and
unauthored content — with what was done meanwhile in each case. Read it before assuming a screen that
shows less than the mockup is unfinished; in most cases it is withholding a figure rather than missing
one.
