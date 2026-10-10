# Release checklist, run this the morning you submit

Phase 8 of `flutter-store-release-guide.md`, adapted to this project and to the smaller first
release. **Nothing here is optional.**

---

## 0. The four gates that are specific to this app

Do these first. If any one of them fails, stop: nothing further in this list matters.

### 0.1 The shipping shape is the shipping shape

```bash
sed -n '/static const FeatureFlags shipped/,/});/p' app/lib/domain/flags/feature_flags.dart
```

Six features on: `today`, `train`, `eat`, `progress`, `cycle`, `privacyCentre`. Everything else off,
including `accountRequired`, `signUp`, `verification`, `adminConsole`, the whole community, the whole
coach and coaching side, `marketplace`, `payments` and `assistant`.

`test/release_readiness_test.dart` asserts this shape opens on Home with no Community tab and no
testing index, and `flutter test` covers it. **If that test is failing, the release is a different
product from the one these documents describe.**

### 0.2 No testing surface is reachable in the shipping build

The preflight now proves the first three from source and from the artifact, so this is a confirmation
walk rather than a search.

- [ ] Install the exact artifact you are uploading and walk it. **Profile must have no "All screens"
      row.**
- [ ] You cannot reach the admin console (`Z01` to `Z13`) or the feature-flag switchboard (`Z14`) by
      any tap, and a deep link naming one opens Home. In a release build those routes resolve to
      nothing at all.
- [ ] **Nothing anywhere says "test", "no money moves", "not connected in this build" or "not in this
      build yet".** Search the running app, not the source. `compliance-inventory.md` section 11
      names the five places this release can still reach.
- [ ] Nothing opens the "Switched off" panel. That panel is internal state and it is written in
      English only.

### 0.3 Every screenshot comes from the current build

The visual language was rebuilt and the release is a different shape. **The bar at the bottom has
three tabs: Home, Train and Eat.**

- [ ] English and Arabic phone screenshots for Play, from the release build.
- [ ] English and Arabic 6.9-inch screenshots for App Store Connect, from the same build.
- [ ] 512 by 512 Play icon and 1024 by 500 Play feature graphic, and the 1024 App Store icon with no
      alpha. The 1024 master is at `app/assets/icon/icon-1024.png` and the app icon sets are
      generated from it.
- [ ] Arabic captures are from the Arabic build, right to left. `--dart-define=OWNHUB_LOCALE=ar`.
- [ ] No frame shows four tabs, a Community tab, a sign-up screen, a coach, a price or the assistant.

### 0.4 The four public URLs are live, and in the code

- [ ] `https://<domain>/privacy`
- [ ] `https://<domain>/terms`
- [ ] `https://<domain>/support`
- [ ] `https://<domain>/delete-account`

Each one opened **from a phone browser**, in English and Arabic, with no login, no geo-block and no
cookie wall hiding the text. Then put all four into `app/lib/config/legal_links.dart` and rebuild:
until they are there, the app draws no privacy policy row, no terms row and no support row, and
`tool/release_preflight.sh` fails. A broken support URL is among the top three first-submission
failures.

---

## 1. The code blockers

`compliance-inventory.md` section 11 lists fourteen things in the code. Do not start the rest of this
checklist until each is fixed or the screen behind it is hidden. The ones that decide the submission:

- [ ] **The language row works**, or the app follows the device locale. Today Profile, then Language,
      opens the "Switched off" panel, and the app is pinned to English.
- [ ] **No control opens the "Switched off" panel.** Four do today: "Ask something" and "Beginners
      group" on Home, "Share" on the finished-session screen, and "My coach" in Profile.
- [ ] **The severe cycle day has no dead buttons.** "Find care near you" and "Read NHS guidance"
      currently answer with "not connected in this build", and the second is no longer even true.
- [ ] **Naming an allergy does not empty the Eat tab**, or the allergy question is not asked in this
      release.
- [ ] **The Safety Centre and the privacy switches describe this release**, not the community.

---

## 2. Automated

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd app
bash tool/release_preflight.sh

# once the public site is live
RELEASE_BASE_URL=https://<domain> bash tool/release_preflight.sh
```

Every line must read **PASS**. A `SKIP` is only acceptable for the URL checks before the site exists,
and the site must exist before you touch either console.

### What the script checks that it did not before

| Check | Why it is there |
|---|---|
| **Testing affordances need a debug build** | It reads `AppRouter.testingAidsAllowed` from source and requires `kDebugMode && !featureFlags.isOn(Feature.accountRequired)`. The account flag used to be what separated a testing build from a real one, and it cannot be any more: this release ships with it off. It also checks that the screen index and the printed sign-in code are both gated on that getter, and that no state class keys a test rail off the flag alone |
| **The admin console is compiled out** | It requires `resolvesInThisBuild` in the router, and `flutter test test/release_readiness_test.dart` proves a release build resolves none of `Z01` to `Z14` and that a deep link naming one opens the front door |
| **The bundle's own signature** | Read from the built `.aab`, by the name of the signature block, because Gradle names it after the key alias. A debug fallback is `META-INF/ANDROIDD.RSA`, so the check can say "signed with the DEBUG key" instead of trusting that a keystore exists. It is read from the file rather than from `keytool`, because `keytool` needs a JDK and a check that silently passes when a tool is missing is worse than no check |
| **The widget extension's manifest and App Group** | `ios/OwnHubWidgets/PrivacyInfo.xcprivacy` exists and is in the Xcode project, both manifests declare UserDefaults `1C8F.1`, and both entitlements files carry `group.com.ownhub.app`. A missing manifest on the extension bundle is a refused upload |
| **16 KB page alignment** | Also read from the built `.aab`, over every 64-bit native library. The app now ships plugins, so there is something to inspect and the check is real |

Both bundle checks report **SKIP** when no `app-release.aab` has been built. Build one before you
trust them.

### As of the last run

27 passed, 4 failed, 1 skipped. `flutter analyze` is clean and the whole test suite passes. The four
failures are all owner actions: the missing keystore, the resulting debug-signed bundle, the Team ID
placeholder, and the four empty legal links.

### Two checks the script does not do

```bash
# the shipping flag shape, from section 0.1
grep -n 'Feature.accountRequired: false' app/lib/domain/flags/feature_flags.dart

# signing material in history
git log --all --name-only --pretty=format: | grep -E '\.jks$|\.keystore$|\.p8$|\.p12$|key\.properties' | sort -u
```

The second command must print nothing. If it prints anything, that material is in the history and has
to be rotated, not just deleted.

---

## 3. Verify the artifacts themselves

```bash
# Android: signed with the release key, not the debug key
unzip -p build/app/outputs/bundle/release/app-release.aab 'META-INF/*.RSA' | keytool -printcert | head -5

# Android: target SDK, version code, package
java -jar bundletool.jar dump manifest --bundle=build/app/outputs/bundle/release/app-release.aab \
  | grep -E 'targetSdkVersion|versionCode|versionName|package='

# Android: confirm no INTERNET permission while the app still has no backend
java -jar bundletool.jar dump manifest --bundle=build/app/outputs/bundle/release/app-release.aab \
  | grep -i 'uses-permission' || echo "no permissions declared, as expected"

# iOS: built with Xcode 26 and the iOS 26 SDK
unzip -p build/ios/ipa/*.ipa 'Payload/Runner.app/Info.plist' | plutil -p - \
  | grep -iE 'DTSDKName|DTXcode|MinimumOSVersion|CFBundleShortVersionString|CFBundleVersion'
```

`DTXcode` must start with `26`, and `DTSDKName` must be `iphoneos26.x`.

**`java` is not on this machine's PATH today**, so install a JDK before you rely on `bundletool`. The
preflight's own signature check does not need one, which is why it exists.

**Also generate the iOS privacy report** from the archive: Product, Archive, then in the Organizer
right-click the archive and choose Generate Privacy Report. It must show no collected data types, and
one accessed API category, `NSPrivacyAccessedAPICategoryUserDefaults`, contributed by
`shared_preferences_foundation` with reason `1C8F.1`.

---

## 4. Manual, on a real device

- [ ] Release build installed from **the exact artifact being uploaded**: `bundletool install-apks`
      for Android, TestFlight for iOS. Not `flutter run --release`.
- [ ] **First launch on a phone that has never had the app**: it opens on Home, with no sign-up, no
      permission prompt and nothing to dismiss.
- [ ] **Persistence, which is new and is the thing most worth testing by hand.** Log a set, log a
      meal, record a period day, change a setting. Swipe the app away. Reopen it. Everything is
      there. Then force-quit mid-action and reopen: the app still opens, and the worst case is that
      the last half second is missing.
- [ ] **Delete everything**, from Profile, then Your data. The app returns to its first day, and
      **after a full restart it is still empty.** That last part is the one that catches a deletion
      that forgot the stored document.
- [ ] Airplane mode: no crash, no spinner, nothing claims to have sent anything.
- [ ] Arabic **and** English, including right-to-left layout on every screen.
- [ ] Large-font accessibility setting, and dark mode.
- [ ] Every URL in both consoles opened from a phone browser, and the three rows inside the app open
      the right pages in the system browser.
- [ ] **Read side by side and confirm they say the same thing:** the Play Data safety answers, the
      App Privacy label, `docs/release/privacy-policy.md`, and `ios/Runner/PrivacyInfo.xcprivacy`. A
      mismatch between any two is a rejection, and it is the most common one for a first app.
- [ ] Version name identical on both stores, and the build number higher than any previous upload
      anywhere, including TestFlight and internal testing.
- [ ] Review notes pasted, with every sentence true of the build being uploaded.
- [ ] The contact phone in App Review Information is one you will answer for the next 7 days.
- [ ] Nothing in the iOS binary or its metadata mentions Android or Google Play. Guideline 2.3.10.

**There is no demo account step any more.** Sign-in required is No on Apple, and App access on Play
is "all functionality available without any special access".

---

## 5. Product rules that are also review risks

- [ ] **Nothing personal reached anything.** There is no analytics SDK today, so the honest check is
      that there still is not one. Confirm with `pubspec.lock`, not from memory.
- [ ] **No model or vendor key in the binary.** Unzip the `.aab` and the `.ipa` and search every
      asset, string table and native library. The suite has a source-level test for this. Run it
      against the artifact too, not just the source.
- [ ] **No daily streak, no calorie countdown, nothing ranked by bodyweight or by followers**
      anywhere a reviewer can screenshot. These are product rules with tests behind them.
- [ ] **The cycle data never leaves the phone**, and the severe-symptom day behaves: the workout
      suggestion is withdrawn, and whatever replaces the two care buttons is honest.
- [ ] **Naming an allergy does not break the Eat tab.** Set an allergy and log a meal.

---

## 6. After submission

- Rejected? Find the **guideline number** in the Resolution Center or the policy email. That number
  is the diagnosis. Answer the specific finding and do not argue about tone.
- Many Apple 2.1 rejections are resolved by replying with exact steps and a screen recording, with
  **no new build**. The 2.1 findings this release is most likely to get are dead controls, and those
  do need a new build.
- Google's first-app rejections cluster in four places: a Data safety mismatch, a missing
  account-deletion URL, undeclared permissions, and App access instructions that did not work. Only
  the first can bite this release.
- **Never open a second developer account to dodge a rejection.** Both stores link accounts by
  device, IP, payment method and identity, and will terminate both.

---

## What only you can do

| # | What |
|---|---|
| 1 | Generate the upload keystore, write `android/key.properties`, and rebuild. Until then the bundle is debug signed and the preflight says so |
| 2 | Replace `YOUR_TEAM_ID` in `ios/ExportOptions.plist` |
| 3 | Publish the four pages and fill in `app/lib/config/legal_links.dart` |
| 4 | Capture the screenshots, English and Arabic, from the release build |
| 5 | Decide whether the generated app icon is the final one |
| 6 | Install a JDK if you want `bundletool` for section 3 |
