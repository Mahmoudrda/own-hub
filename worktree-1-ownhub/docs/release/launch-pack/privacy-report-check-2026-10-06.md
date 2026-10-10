# iOS privacy report, checked against the store answers (6 Oct 2026)

## How this was made

Xcode's Organizer report (Product > Archive > Generate Privacy Report) merges
the app's `PrivacyInfo.xcprivacy` with the manifest of every framework and
resource bundle in the archive. An archive could not be made today, for two
reasons:

- `flutter build ipa` stops with "requires a selected Development Team":
  `ios/ExportOptions.plist` still says `YOUR_TEAM_ID`, and the project has no
  `DEVELOPMENT_TEAM`.
- `xcodebuild archive CODE_SIGNING_ALLOWED=NO` stopped while fetching the Swift
  packages (Firebase now comes in through Swift Package Manager): the Mac had
  120 MB of free disk. The partial download was removed again.

So the same merge was done by reading the same manifests directly, for the
exact versions this build resolves:

- the app: `app/ios/Runner/PrivacyInfo.xcprivacy`
- CocoaPods (`app/ios/Podfile.lock`): MLKitCommon 14.0.0, MLKitFaceDetection,
  GoogleDataTransport, GoogleUtilities, GTMSessionFetcher, GoogleToolboxForMac,
  PromisesObjC, nanopb
- Flutter plugins with their own manifest: camera_avfoundation,
  firebase_messaging, flutter_local_notifications, flutter_timezone,
  shared_preferences_foundation, url_launcher_ios
- firebase-ios-sdk 12.19.0 (the version firebase_core 4.15.0 pins):
  FirebaseCore (and Internal, Extension), FirebaseInstallations, FirebaseAuth,
  Firestore (and Swift), FirebaseMessaging, Crashlytics. Storage, Functions and
  App Check ship no manifest.
- Swift packages: leveldb, grpc-binary, abseil-cpp-binary

30 manifests in all. Tracking: none of them sets `NSPrivacyTracking`.

When the Team ID is set, archive once in Xcode and generate the real report.
It should match the table below. If it does not, the table is the thing that
is wrong.

## What the merged report contains

| Data type | Declared by | Linked | Purposes in the manifests |
|---|---|---|---|
| Phone Number | app | yes | App Functionality |
| User ID | app, FirebaseAuth | yes | App Functionality |
| Device ID | app (linked); MLKit, FirebaseMessaging (not linked) | both | App Functionality; **Analytics** (MLKit) |
| Fitness | app | yes | App Functionality |
| Health | app | yes | App Functionality |
| Sensitive Info | app | yes | App Functionality |
| Photos or Videos | app | yes | App Functionality |
| Other Data Types | app (linked); MLKit, FirebaseMessaging (not linked) | both | App Functionality; **Analytics** (MLKit, Messaging) |
| Crash Data | app, Crashlytics | no | App Functionality |
| Performance Data | app; MLKit | no | App Functionality; **Analytics** (MLKit) |
| **Other Diagnostic Data** | GoogleDataTransport, MLKit, Installations, Auth, Firestore, Messaging, Crashlytics | no | **Analytics**, App Functionality |
| **Other User Content** | MLKit | no | **Analytics**, App Functionality |
| **Product Interaction** | MLKit | no | **Analytics**, App Functionality |

Required-reason APIs, all declared by the packages that use them (the app
target declares none, and touches none directly):

| API | Reasons | Declared by |
|---|---|---|
| UserDefaults | CA92.1, 1C8F.1, C56D.1 | shared_preferences, firebase_messaging, flutter_local_notifications, FirebaseCore, FirebaseAuth, Crashlytics, GoogleUtilities, GTMSessionFetcher, GoogleToolboxForMac, MLKit |
| FileTimestamp | C617.1 | GoogleUtilities, MLKit, grpc, leveldb |
| SystemBootTime | 35F9.1 | MLKit, grpc |
| DiskSpace | E174.1 | MLKit |

## Differences found

### 1. Against `ios/Runner/PrivacyInfo.xcprivacy`

The app manifest does not declare three types the SDKs declare: **Other
Diagnostic Data**, **Other User Content** (unlinked) and **Product
Interaction**. It also declares only App Functionality where ML Kit and Google
Data Transport declare **Analytics**. Apple's report shows the union, so the
App Store label has to cover these whatever the app manifest says. The source
is mostly ML Kit's own usage logging (Firelog through GoogleDataTransport) and
the Firebase SDKs' diagnostic pings.

### 2. Against `launch-pack/app-store-privacy-answers.md`

That page says to leave Performance Data, Other Diagnostic Data, Sensitive
Info and Photos empty, to tick Other User Content for the ID photos, and to
tick App Functionality only. Today's merged report disagrees with it on:

- **Photos or Videos** and **Sensitive Info**: declared by the app manifest,
  and the page says leave them empty. The ID card and selfie frames are
  declared as Photos or Videos in the manifest and in Play, but as Other User
  Content on the page.
- **Performance Data** and **Other Diagnostic Data**: declared (ML Kit,
  Firebase), and the page says leave them empty.
- **Product Interaction**: declared by ML Kit, not on the page.
- **Analytics** purpose: declared by ML Kit and Google Data Transport, and the
  page says never tick it.

This is the L3.3 problem. The page needs rewriting from the table above
before anyone fills in App Store Connect.

### 3. Against `app/android/play-data-safety.txt`

Play already lists Diagnostics ("ML Kit performance events, and the device
details sent with a crash report", purpose Analytics) and crash logs with
purpose Analytics. That is closer to the iOS SDK manifests than the App Store
page is. Two gaps: Play does not mention ML Kit's usage logging as app
interactions (Play's "App activity > App interactions"), and it says "app
activity" is not collected.

### 4. Against privacy policy v3, sections 3 and 4

Section 3 already says that ML Kit sends Google "the device model, operating
system, app version, an installation identifier and performance events", and
that crash reports and ML Kit data are never linked to her account. What it
does not name is what ML Kit's manifest adds on top: usage (Product
Interaction) and Other User Content, both unlinked, for Analytics, and the
Firebase SDKs' diagnostic pings. Counsel should decide whether "performance
events" covers that or the sentence needs widening. The policy's claims about
photos (processed in memory, never stored) are not affected: no SDK manifest
declares photos.

## What to change, in one build, so the three agree

1. Decide with counsel whether ML Kit's usage logging is disclosed or switched
   off. If it stays on: add Other Diagnostic Data, Product Interaction and
   Other User Content (not linked, Analytics) to
   `ios/Runner/PrivacyInfo.xcprivacy`, add Analytics to Device ID, Other Data
   Types and Performance Data, tick the same boxes in App Store Connect, add
   App interactions to the Play form, and widen the ML Kit sentence in
   section 3 if counsel says so.
2. Rewrite `app-store-privacy-answers.md` from the table above (L3.3), with
   Photos or Videos and Sensitive Info ticked as the manifest has them.
3. Archive with the Team ID set, generate the Organizer report, and compare it
   with this page.
