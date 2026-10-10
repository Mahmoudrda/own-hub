# Build environment, Own Hub

**Recorded 23 September 2026**, by running the commands below on the machine that builds this app.
Guide reference: Phase 3.1. If a build breaks somewhere else, compare against this first.

## Toolchain, as installed today

| | Version | How it was read |
|---|---|---|
| Flutter | **3.47.4**, stable channel | `flutter --version`. Framework revision `9584c6713b`, 2026-09-10 |
| Flutter engine | hash `0e228ec8c8d2abc9fcf1d053e8a40665bb859ec7`, revision `06a2e2a110`, 2026-09-03 | `flutter --version` |
| Dart | **3.13.3**, stable, `macos_arm64` | `dart --version` |
| DevTools | 2.60.0 | `flutter --version` |
| Xcode | **26.3**, build `17C529` | `xcodebuild -version` |
| iOS SDK | **26.2** (`iphoneos26.2`), simulator `iphonesimulator26.2` | `xcodebuild -showsdks` |
| Swift | 6.2.4, swift-driver 1.127.15 | `swift --version` |
| macOS | 15.6, build `24G84` | `sw_vers` |
| Android Gradle Plugin | **9.1.0** | `android/settings.gradle.kts`, `com.android.application` version |
| Gradle wrapper | **9.3.1** (`gradle-9.3.1-all.zip`) | `android/gradle/wrapper/gradle-wrapper.properties` |
| Kotlin Android plugin | **2.4.0** | `android/settings.gradle.kts` |
| Java source, target, jvmTarget | **17** | `android/app/build.gradle.kts` |

**Xcode 26.3 clears Apple's hard gate.** Since 28 April 2026 App Store Connect refuses any upload not
built with Xcode 26 and the iOS 26 SDK, and that is enforced at upload, before review.

**AGP 9.1.0 is far above the 8.5.1 floor** the guide names for 16 KB page alignment.

## Two things about this machine that will bite

**Flutter is not on the non-interactive PATH.** Every shell command has to start with:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

**There is no Java runtime on the PATH.** `java -version` returns "Unable to locate a Java Runtime".
Gradle finds a JDK through Android Studio, so `flutter build appbundle` works, but the guide's bundle
verification shells out to `java -jar bundletool.jar` and that will fail here until a JDK 17 is
installed and on the PATH. `tool/release_preflight.sh` deliberately reads the bundle's signature and
its library alignment without a JDK, for exactly this reason.

## Dependencies

Three packages are new since the last revision of this file, and each one is here for a reason that
is worth keeping written down.

| Package | Where | Why |
|---|---|---|
| **`shared_preferences` ^2.3.0**, resolved 2.5.5 | dependency | The app's only persistence. One JSON document under one key on the handset, written debounced and on pause, read once before `runApp`. Chosen over `path_provider` plus a file because a file store needs the file-timestamp APIs Apple covers by its required-reason rules, which would mean hand-authoring `PrivacyInfo.xcprivacy`; this package ships its own manifest declaring `NSPrivacyAccessedAPICategoryUserDefaults`, reason `1C8F.1`. See `lib/app_state/local_persistence.dart` |
| **`url_launcher` ^6.3.2**, resolved 6.3.2 | dependency | Hands an address to the platform browser, with `LaunchMode.externalApplication`. Used by three rows and nothing else: privacy policy, terms and support, and only once `lib/config/legal_links.dart` has addresses. It is not a network client and the app has no in-app browser. `url_launcher_ios` 6.4.2 ships a privacy manifest declaring nothing collected and no accessed APIs |
| **`flutter_launcher_icons` ^0.14.4** | **dev** dependency | Generated `ios/Runner/Assets.xcassets/AppIcon.appiconset` and every `android/app/src/main/res/mipmap-*` from `assets/icon/icon-1024.png`, with `remove_alpha_ios: true` and a white adaptive background. It never runs at runtime and is not in the binary. Re-run with `dart run flutter_launcher_icons` after replacing the master |

The rest are unchanged: `flutter`, `flutter_localizations`, `intl`, `meta`, `crypto`,
`cupertino_icons`, and the dev set `flutter_test`, `fake_async`, `analyzer`, `flutter_lints`.

**Neither new dependency adds a network path, a permission or a tracker**, which is what makes the
"nothing collected" answer on both store forms still true. `compliance-inventory.md` section 3 is the
long form of that argument.

## Platform targets

| | Value | Where it is set, and why |
|---|---|---|
| Android `applicationId` and `namespace` | `com.ownhub.app` | `android/app/build.gradle.kts`. Not `com.example.*`, which both stores reject |
| Android `compileSdk` | **36** | Pinned explicitly, not inherited from a Flutter default that can move |
| Android `targetSdk` | **36** | Play requires new apps and updates to target Android 16 since 31 August 2026 |
| Android `minSdk` | **24** | Android 7.0. Also the `min_sdk_android` the icon generator was given |
| R8 and resource shrinking | **on** | `isMinifyEnabled = true`, `isShrinkResources = true`, with `android/app/proguard-rules.pro` |
| iOS bundle id | `com.ownhub.app` | `ios/Runner.xcodeproj/project.pbxproj` |
| iOS deployment target | **15.0** | `IPHONEOS_DEPLOYMENT_TARGET` |
| `TARGETED_DEVICE_FAMILY` | **"1"**, iPhone only | iPad was declared once and never tested. Apple tests what you declare |
| Orientation | Portrait only | `UISupportedInterfaceOrientations` in `ios/Runner/Info.plist` |
| Export compliance | `ITSAppUsesNonExemptEncryption` = `false` | Correct today: `package:crypto` is sha1 for deterministic ids, not transport encryption |
| App icon | `assets/icon/icon-1024.png` | A typographic monogram generated from the brand. `[OWNER: a placeholder you may replace]` |

## Release signing

`android/app/build.gradle.kts` reads `android/key.properties` when it exists and **falls back to the
debug key when it does not**. That keeps `flutter build` working on a machine with no keystore, which
is every machine until the owner runs `keytool`. It also means a release build produced today is
debug signed, and Play rejects a debug signed upload.

**The preflight now reads this from the artifact rather than from the filesystem.** It looks at the
name of the signature block inside the `.aab`, because Gradle names it after the key alias: a debug
fallback is `META-INF/ANDROIDD.RSA`, and an upload key called "upload" is `META-INF/UPLOAD.RSA`. As
of the last run it reports the bundle signed with the debug key, which is the truth.

## Build commands

```bash
export PATH="$HOME/development/flutter/bin:$PATH"

# Android, the artifact you upload
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android

# Android, for device testing only, never upload this
flutter build apk --release --obfuscate --split-debug-info=build/symbols/android

# iOS, needs a real signing identity and a filled-in ios/ExportOptions.plist
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios \
  --export-options-plist=ios/ExportOptions.plist

# the app in Arabic, for screenshots
flutter run --dart-define=OWNHUB_LOCALE=ar
```

**Keep `build/symbols/*` and `build/app/outputs/mapping/release/mapping.txt`.** The mapping file goes
into Play Console under the release's deobfuscation field. Without it every obfuscated crash report
is unreadable.

**`ios/ExportOptions.plist` still contains the placeholder `YOUR_TEAM_ID`.** The iOS build command
above cannot produce an uploadable IPA until that is replaced with the real Team ID from
developer.apple.com, Membership.

## Suite size, and the last clean run

| | Today |
|---|---|
| Dart files under `lib/` | 457 |
| Screen ids declared in `lib/routing/app_routes.dart` | 175 |
| Screens that have a builder in `lib/routing/app_router.dart` | 165. The rest render an honest "not built yet" placeholder |
| Test files under `test/` | 270 |
| `test(...)` and `testWidgets(...)` cases | about 3,556 |

**`flutter analyze` is clean and the whole suite passes**, run through `tool/release_preflight.sh` on
a quiet tree on 23 September 2026. The preflight as a whole reported 27 passed, 4 failed, 1 skipped;
all four failures are owner actions, not code.

## Disk

A full Android release build plus an iOS build is enough to fill this machine. `app/build` is
currently **3.5 GB**, and the boot volume shows **3.8 GB free of 228 GB**. That is tight enough to
matter: when the disk fills, every shell command fails with ENOSPC, including the ones that would
free space. Check `df -h` first when builds start failing for no visible reason.

```bash
rm -rf app/build            # always safe, regenerable
```

## Not in the build, and why

Recorded so each absence is a decision rather than an oversight. Every line here is a fact about
`pubspec.yaml` and the source, not a plan.

* **No backend of any kind.** No `firebase_core`, no auth, no Firestore, no `http`, no `dio`, no
  WebSocket client. Nothing in the app can make a network call, and the release Android manifest
  declares no internet permission.
* **No crash reporting.** Neither Crashlytics nor Sentry. The guide calls a crash during review the
  largest single rejection bucket, so this should land before submission, but it needs a Firebase or
  Sentry project to exist first, and it would change both store privacy answers on the day it lands.
* **No analytics SDK.**
* **No camera, no image picker, no speech package.** ID capture and selfie capture therefore cannot
  run, and "Say it" meal logging cannot hear anything. Both features are switched off for this
  release anyway.
* **No notification plugin.** Nothing schedules or delivers a reminder, so the notifications screen
  cannot do the one thing it is for.
* **No share plugin.** Nothing can open an OS share sheet, which is why three controls in Eat say so.
* **No database.** `sqflite`, `hive`, `isar` and `path_provider` are all absent. Persistence is
  `shared_preferences` and one JSON document, on purpose: see the dependency table above.
* **No `flutter_native_splash`.** Not configured and not needed for this release.
* **Plugins with native code now exist**, so the 16 KB page-alignment check has something to inspect
  and it runs for real. As of the last preflight, every 64-bit library in the bundle is aligned.
