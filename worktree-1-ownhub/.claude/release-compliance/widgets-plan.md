# Own Hub iOS widgets: research and build plan

Scope: I read the code on branch `onboarding/2026-10-06` and edited no files. Every external claim has a primary-source URL. Apple pages were fetched on 2026-10-06. Where no primary source exists I say UNVERIFIED, or name the non-Apple source.

**Short answer.** Yes, it is buildable. Write the widgets in SwiftUI in a Widget Extension, and share data through the App Group `group.com.ownhub.app` using `home_widget` 0.10.0.

**Recommendation.** Two widgets:
- **Your week**: systemSmall, accessoryCircular, accessoryRectangular and accessoryInline.
- **Today**: systemMedium.

They show only:
- this week's session count against her target;
- a status for today;
- whether a meal is logged today.

They never show cycle, life stage, weight, measurements, kcal, allergies or the programme title. No interactive buttons in v1.

---

## 1. Can a Flutter app ship iOS widgets, and what is required

**Widgets must be native.** The `home_widget` README says: "HomeWidget does **not** allow writing Widgets with Flutter itself. It still requires writing the Widgets with native code." (https://github.com/ABausG/home_widget/blob/main/packages/home_widget/README.md). WidgetKit views can't use UIKit wrappers either: "Widgets can't use UIKit or AppKit views wrapped with UIViewRepresentable" (https://developer.apple.com/documentation/widgetkit/swiftui-views).

**Requirements**

| Need | Detail | Source |
|---|---|---|
| Widget Extension target | File > New > Target > Widget Extension. Untick "Include Live Activity" and "Include Configuration App Intent". Use a `StaticConfiguration` with `kind`, a `TimelineProvider` and content | https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension |
| Swift / SwiftUI | `placeholder(in:)` (synchronous), `getSnapshot` (`context.isPreview`), `getTimeline` plus a reload policy (`atEnd`, `after(_:)`, `never`) | same page; https://developer.apple.com/documentation/widgetkit/timelineprovider/placeholder(in:) ; https://developer.apple.com/documentation/widgetkit/timelinereloadpolicy/atend |
| App Group | Entitlement `com.apple.security.application-groups`, format `group.<name>`, on **both** Runner and the extension. "You need to register app groups for iOS" | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups ; https://developer.apple.com/documentation/xcode/configuring-app-groups |
| Data sharing | `UserDefaults(suiteName:)` "to access settings you share… between your app and an app extension". On the Dart side, `home_widget` writes through `HomeWidget.setAppGroupId` and `saveWidgetData` | https://developer.apple.com/documentation/foundation/userdefaults/init(suitename:) ; https://docs.page/abausg/home_widget/setup/ios |
| Reload from the app | `WidgetCenter.reloadTimelines(ofKind:)` or `reloadAllTimelines()`. On the Dart side, `HomeWidget.updateWidget(iOSName:)`, where `iOSName` must equal `kind`. Reloads made while the app is in the foreground do not count against the 40 to 70 per day budget | https://developer.apple.com/documentation/widgetkit/widgetcenter/reloadtimelines(ofkind:) ; https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date ; https://docs.page/abausg/home_widget/usage/update-widget |
| Package | `home_widget` 0.10.0, published 2026-09-17. Needs Flutter ≥3.38.1 (we have 3.47.4). iOS 14 minimum. Supports both SPM and CocoaPods | https://pub.dev/api/packages/home_widget ; https://raw.githubusercontent.com/ABausG/home_widget/main/packages/home_widget/ios/home_widget.podspec |
| UIScene | The app uses `SceneDelegate: FlutterSceneDelegate`. `home_widget` has supported UIScene since 0.9.3 ("FEAT: Support UIScene Lifecycle (#423)"). It reads `scene(_:openURLContexts:)` and `willConnectTo` | https://github.com/ABausG/home_widget/blob/main/packages/home_widget/CHANGELOG.md ; https://docs.flutter.dev/release/breaking-changes/uiscenedelegate |

**Minimum iOS per family**

| Family | Minimum |
|---|---|
| systemSmall, systemMedium, systemLarge | iOS 14 (https://developer.apple.com/documentation/widgetkit/widgetfamily/systemsmall) |
| accessoryCircular, accessoryRectangular, accessoryInline | iOS 16 (https://developer.apple.com/documentation/widgetkit/widgetfamily/accessorycircular) |
| systemExtraLarge | iPadOS and macOS only, so it does not apply: the app is iPhone-only, `TARGETED_DEVICE_FAMILY = 1` (https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralarge) |
| `containerBackground(for:)` | iOS 17 (https://developer.apple.com/documentation/swiftui/view/containerbackground(for:alignment:content:)) |
| Interactive `Button(intent:)` | iOS 17 (https://developer.apple.com/documentation/swiftui/button/init(_:intent:)-7urde) |

Without `containerBackground`, Xcode overlays a warning on the widget during development (https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background).

**Deployment target.** Flutter's docs say the extension's minimum should match Runner: "matches in both Runner and ShareExtension" (https://docs.flutter.dev/platform-integration/ios/app-extensions). Apple's archived guide allows them to differ (https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html). Plan:
- Set the extension to **15.5**, the same as Runner and the Podfile.
- Gate the accessory families with `if #available(iOSApplicationExtension 16.0, *)`.
- Gate `containerBackground` behind an iOS 17 availability helper.

**Signing**
- **Bundle id.** The extension id must start with the parent's: use `com.ownhub.app.OwnHubWidgets`. Google's codelab says: "The bundle identifier for your widget must use the parent app's bundle identifier as the prefix" (https://codelabs.developers.google.com/flutter-home-screen-widgets, a Google source, not Apple). No current Apple doc page states this rule, so it is UNVERIFIED as Apple documentation.
- **Profiles.** It needs its own App ID with the App Groups capability and its own provisioning profile. That per-target requirement is UNVERIFIED from Apple docs; it is standard Xcode behaviour.
- **Team ID.** The repo has none yet. `ios/ExportOptions.plist` still holds `YOUR_TEAM_ID` and `DEVELOPMENT_TEAM` is not set in the pbxproj. This is already owner action #2 in `docs/release/compliance-inventory.md`.

## 2. Which families fit, and what they show (from the real code)

**What actually exists on the phone today**

- **`AppRouter.todayRepository.day`** (`lib/features/today/domain/today_day.dart`) is the useful source:
  - `DayState` is one of dayOne, nothingDone, inProgress, done, recalled, restDay.
  - `WeekProgress(sessionsLogged, sessionsTarget)`. The target is her O03 answer (2 to 4) through `OnboardingState._applyWeeklyTarget`.
  - `mealLoggedAt`.
  - `date`.
  - It is restored before `runApp` by `LocalPersistence`.
- **Today's workout is not hers yet.**
  - `trainRepository.day` is null, so `sessionTitle` is null on T01.
  - R03 starts `sampleWorkoutDay(...)`.
  - Programme titles can reveal life stage: the router comment cites "Postpartum rebuild". So the widget only ever says "Today's workout" generically.
- **The meal plan is seeded with the sample for everyone.** `mealRepository` is created with `sampleMealPlan(...)` in `app_router.dart` ~6072, and `MealPlan.dinners` has no "she chose this" flag. Showing "Tonight: X" would present a sample as her plan, so it is deferred. To add it later, E07 must record that she chose or swapped a dinner.
- **Kept out of the widget entirely:**
  - Cycle (`CycleAppState`, `cycleRepository`).
  - `Intake.lifeStage` (pregnant, postpartum).
  - Measurements and weight (`measurementsRepository`).
  - Allergies.
  - kcal and protein.
  - Level and tier.

  This holds even with privacySensitive: the data never reaches the App Group, so it cannot leak through the redaction setting, a screenshot or a wrong family.
- **Product rule "weeks, not days"** (`lib/domain/week/week_key.dart`, `today_day.dart`):
  - No daily streak and no "missed" count.
  - Nothing in red.
  - Western digits in Arabic (`lib/domain/format/number_label.dart`, P0-A11Y-01). Swift must use `String(n)`, not a localized `NumberFormatter`.

**Families**

| Widget (kind) | Family | Shows |
|---|---|---|
| `OwnHubWeek`, "Your week" | systemSmall | Brand mark, "This week", `done of target` as segments (like `app_week_segments.dart`), the today status line |
| | accessoryCircular | Gauge `done/target`, with the number in the centre |
| | accessoryRectangular | "Own Hub" plus "This week, 1 of 3" |
| | accessoryInline | "1 of 3 this week" |
| `OwnHubToday`, "Today" | systemMedium | Week segments, today status, meal line. Three tap targets via `Link` |
| Not offered | systemLarge | Not enough genuine data, and an empty-looking large widget invites a 4.2 "minimum functionality" judgement |

**Lock screen**
- The week count is not on the forbidden list, but it is still marked `.privacySensitive()` on every accessory family.
- So if she turns off Settings > Face ID & Passcode > ALLOW ACCESS WHEN LOCKED, WidgetKit shows the placeholder (https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension, section "Hide sensitive content").
- Do **not** set `com.apple.developer.default-data-protection = NSFileProtectionComplete`. It would blank the widget whenever the phone is locked (same page), and the payload contains nothing sensitive by design.

**States**

| Situation | What the widget shows |
|---|---|
| Not signed in, not verified, waiting on a reviewer, after sign-out or deletion (`AppRouter.isVerified == false`) | State `closed`: brand plus "Open Own Hub to start". No numbers. Verification status is not revealed |
| Demo tour (C04) | Never written. The tour uses sample repositories under `DemoScope` that refuse writes (`lib/app_state/demo_mode.dart`). The sync reads only the `AppRouter` singletons, and only when verified |
| Gallery preview (`context.isPreview`) and `placeholder(in:)` | The layout with empty segments and "Your week shows here". No fabricated figures, in line with the codebase's removal of prototype numbers |
| Day rollover | Payload carries `dayKey` and `weekId`. The timeline adds an entry at next local midnight (today line becomes "Open Own Hub for today") and at next ISO Monday 00:00 (`Calendar(identifier: .iso8601)`, count resets to 0 of target). Policy `.atEnd` |

**Copy.** New strings go through `tool/add_strings.py`. Arabic is MSA, addressed to a woman, with Western digits.

| Key | EN | AR |
|---|---|---|
| widgetWeekName | Your week | أسبوعكِ |
| widgetWeekDescription | Sessions this week, at a glance. Nothing about your cycle or body. | تمارين هذا الأسبوع في لمحة. لا شيء عن دورتكِ أو جسمكِ. |
| widgetTodayName | Today | اليوم |
| widgetTodayDescription | Today's workout and meal, one tap away. | تمرين اليوم ووجبتكِ، على بُعد لمسة. |
| thisWeekDoneOfTarget (exists) | This week, {done} of {target} | هذا الأسبوع، {done} من {target} |
| widgetInlineWeek | {done} of {target} this week | {done} من {target} هذا الأسبوع |
| widgetA11yWeek | Sessions this week: {done} of {target} | تمارين هذا الأسبوع: {done} من {target} |
| widgetDayOne | Your first session is ready | تمرينكِ الأول جاهز |
| widgetNothingDone | Today's workout is ready | تمرين اليوم جاهز |
| widgetInProgress | Today is under way | يومكِ بدأ |
| sessionDone (exists) | Session done | اكتمل التمرين |
| widgetRecalled | Session logged | سُجِّل التمرين |
| restDay (exists) | Rest day | يوم راحة |
| widgetMealLogged | A meal is logged today | سجّلتِ وجبة اليوم |
| widgetLogMeal | Log a meal | سجّلي وجبة |
| widgetStale | Open Own Hub for today | افتحي Own Hub ليومكِ |
| widgetClosed | Open Own Hub to start | افتحي Own Hub للبدء |
| widgetEmptyPreview | Your week shows here | سيظهر أسبوعكِ هنا |

## 3. Deep links

**Tap targets in SwiftUI**
- `widgetURL` covers the whole widget, one per hierarchy: "If multiple views have widgetURL modifiers, the behavior is undefined" (https://developer.apple.com/documentation/swiftui/view/widgeturl(_:)).
- `Link` gives extra targets. Apple's newer page allows `Link` in systemSmall, accessoryRectangular and larger (https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity). The older "Creating a widget extension" page says medium and larger; the two pages conflict.
- Plan: small and accessory widgets use `widgetURL` only. Medium uses `widgetURL` plus `Link`s.

**URLs.** Use `ownhub://widget?homeWidget=1&to=T01`, with `to` one of `T01`, `R03`, `P01`, `E01`. `home_widget` only treats a URL as a widget click when it has a `homeWidget` query item (https://docs.page/abausg/home_widget/features/detect-clicks).

**Dart side.** New `lib/app_state/widget_links.dart`:
- Cold start: `HomeWidget.initiallyLaunchedFromHomeWidget()`, awaited after the first frame.
- Warm: the `HomeWidget.widgetClicked` stream.
- Map `to` through a **whitelist** `{T01,R03,P01,E01}` to `appDestinations[id]!.name`.
- Then `AppRouter.navigatorKey!.currentState!.pushNamed(name)`.
- Skip if the top route already has that name. Never `pushNamedAndRemoveUntil`: a tap mid-workout (R07) must not destroy the live session.

Because it goes through `onGenerateRoute`, the existing guards all apply unchanged: the verification gate (`verificationGate`, which sends to C01, C14 or C09b), feature flags, the release-mode admin compile-out, and the consent-before-lens rule.

**Turn off Flutter's built-in deep linking.** Set `FlutterDeepLinkingEnabled` to `NO` in Runner `Info.plist`.
- Built-in linking is on by default since Flutter 3.27.
- Flutter says "If you're using third-party plugins to handle deep links… Flutter's default deeplink handler will break these plugins" (https://docs.flutter.dev/cookbook/navigation/set-up-universal-links ; https://docs.flutter.dev/ui/navigation/deep-linking).
- Left on, `ownhub://widget?...` would also be pushed as a route and land on `onUnknownRoute`.
- Nothing in `tool/`, `test/` or `integration_test/` uses URL deep links today; I grepped for `openurl`, `ownhub://` and `FlutterDeepLinking`.

**Register the scheme.** Add `ownhub` as a second entry in Runner `CFBundleURLTypes`. Keep the existing reversed-client-id entry that Firebase phone auth needs.

**Device test to run.** Check that the Firebase reCAPTCHA return still completes sign-in with `FlutterDeepLinkingEnabled=NO`. I expect it to, because firebase_auth handles that URL itself, but I have not verified it.

## 4. Localization, RTL, fonts, appearance, accessibility

**Language follows her in-app choice, not the device.** C02 and `LocaleScope` can differ from the device language, so Dart writes **already-localized strings** from `AppL10n` in her chosen locale, plus `lang: "ar"|"en"`. Swift then sets:
- `.environment(\.layoutDirection, lang == "ar" ? .rightToLeft : .leftToRight)` (https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection)
- `.environment(\.locale, Locale(identifier: lang))`

Only the strings shown before any data exists need a String Catalog in the extension (`Localizable.xcstrings`, en and ar): the gallery name and description via `configurationDisplayName` and `description`, which are localized keys (https://developer.apple.com/documentation/swiftui/widgetconfiguration/configurationdisplayname(_:)-4v9q), plus the empty preview. Apple's statement that widgets read the extension's own String Catalog is UNVERIFIED; it is standard bundle behaviour. Do not call reload on locale change: "For cases such as… system locale changes, don't request a timeline reload from your app" (https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date). Do call it when her **in-app** language changes, from the `_locale` listener in `main.dart`.

**Fonts**
- Copy `assets/fonts/Rubik-400.ttf` and `Rubik-600.ttf` (OFL, and Rubik covers both scripts) into the extension's resources and list them in the extension `Info.plist` `UIAppFonts` (https://developer.apple.com/documentation/bundleresources/information-property-list/uiappfonts). The widget-specific requirement comes only from the home_widget docs (https://docs.page/abausg/home_widget/features/custom-fonts).
- Use `Font.custom("Rubik", size:, relativeTo:)` so Dynamic Type scales.
- HIG: "If you use a custom font, do so sparingly" and keep text ≥11 pt (https://developer.apple.com/design/human-interface-guidelines/widgets).
- Hand layer: at most one hand underline as a vector asset. No La Belle Aurore or Aref Ruqaa text in a widget.

**Light and dark.** The app is light-only (`recipe_book_tokens.dart` notes there is no `darkTheme`). The widget must still support both: "Support light and dark appearances" (HIG). Use an asset-catalog colour set:
- Light: surface `#FFF8F9`, ink `#241A1E`, primary `#A24661`.
- Dark: surface near `#37292E` (inverseSurface), text `#FFECF0`.

**Tinted and accented modes**
- Wrap the segments and gauge in `.widgetAccentable()` (https://developer.apple.com/documentation/swiftui/view/widgetaccentable(_:)).
- Read `widgetRenderingMode`, since the lock screen is vibrant (https://developer.apple.com/documentation/widgetkit/widgetrenderingmode).
- Support Always-On through `isLuminanceReduced` (https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances).
- Margins: 16 pt standard, smaller on the lock screen (HIG).

**Accessibility**
- Set `.accessibilityLabel(widgetA11yWeek)` on the gauge and segments.
- Combine each row into one element.
- No meaning carried by colour alone.
- Check XXL Dynamic Type in both languages with SwiftUI previews.

## 5. Store and legal impact

**Extension privacy manifest.** Required: "the bundle that includes the executable… needs to include a privacy manifest" (https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). That a widget `.appex` counts as such a bundle is my inference. Contents:
- `NSPrivacyTracking` false.
- No collected types.
- `NSPrivacyAccessedAPICategoryUserDefaults` with reason **1C8F.1**, the App Group reason. CA92.1 explicitly does not permit data "accessible to other apps" (https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

**Runner manifest**
- After `flutter pub get`, check whether `home_widget` 0.10.0 ships a `PrivacyInfo.xcprivacy` declaring 1C8F.1. Unverified: it is not in the local pub cache yet.
- If it does not, add 1C8F.1 to `ios/Runner/PrivacyInfo.xcprivacy` `NSPrivacyAccessedAPITypes`.
- Side finding: the Runner manifest comment says `shared_preferences declares NSUserDefaults CA92.1`, but the plugin's real manifest (`shared_preferences_foundation-2.5.7`) declares **1C8F.1**. `build-environment.md` is correct; fix the comment.

**App Privacy labels: no change.** "Data that is processed only on device is not 'collected'" (https://developer.apple.com/app-store/app-privacy-details/). The widget sends nothing.

**Review guidelines** (https://developer.apple.com/app-store/review/guidelines/)
- 2.5.16: "Widgets, extensions, and notifications should be related to the content and functionality of your app." Satisfied.
- 4.4: extensions "may not include marketing, advertising, or in-app purchases." Avoid "Join", "Upgrade" or promo copy.
- 2.5.18: no ads in widgets.
- 4.2 is the reason for not shipping an empty Large widget.

**Docs to change**

`docs/release/review-notes.md`: add a WIDGETS paragraph:
> WIDGETS: Long-press the Home Screen, tap +, search "Own Hub". "Your week" (small and Lock Screen) and "Today" (medium) show this week's session count and today's status from data on the phone. They never show cycle, pregnancy, weight or health data. Tapping opens Today, the workout, Progress or Eat. Before sign-in they show only "Open Own Hub to start".

`docs/release/compliance-inventory.md`:
- New rows for the extension target, its privacy manifest, the App Group, and the `ownhub` URL scheme.
- Owner rows: App Group registration, extension App ID, profiles.

`docs/release/release-checklist.md` and `tool/release_preflight.sh`, new checks:
- extension `PrivacyInfo.xcprivacy` is present and in the pbxproj;
- 1C8F.1 is declared;
- both entitlements contain `group.com.ownhub.app`.

`docs/release/delete-account.md`: no structural change. The App Group key is cleared inside `clearPersistence`. Add one line naming it.

`docs/release/appstore-listing.md`: optional description line, and a widget screenshot later.

**Privacy policy** (`site/_build/pages_en.py` §3.5 `c-training` ~line 474, `pages_ar.py` same section). Not strictly required, since nothing new is collected, but it matches the policy's "stays on your phone" promises. Add after the §3.5 paragraph:
- EN: "If you add an Own Hub widget to your Home Screen or Lock Screen, it shows how many sessions you have done this week, whether today's workout is done and whether you have logged a meal, and nothing else. The widget reads this from your phone. It never shows your cycle, pregnancy or postpartum stage, weight, measurements or allergies, and nothing is sent anywhere. Signing out or deleting your account clears it."
- AR: "إذا أضفتِ أداة Own Hub إلى الشاشة الرئيسية أو شاشة القفل، فإنها تعرض عدد التمارين التي أنجزتِها هذا الأسبوع، وما إذا أنجزتِ تمرين اليوم وسجّلتِ وجبة، ولا شيء غير ذلك. تقرأ الأداة هذه المعلومات من هاتفكِ. لا تعرض أبدًا دورتكِ أو مرحلة الحمل أو ما بعد الولادة أو وزنكِ أو قياساتكِ أو حساسيتكِ تجاه الأطعمة، ولا يُرسَل منها شيء إلى أي مكان. يؤدي تسجيل الخروج أو حذف حسابكِ إلى مسحها."
- The policy is v3.0. Decide whether this is a minor update logged in the version history (line ~815) or a re-acceptance under M1. Owner and legal call. Confirm the Arabic term for "widget" (أداة) with the MSA reviewer.

## 6. Build plan

**New files**

| Path | Content |
|---|---|
| `ios/OwnHubWidgets/OwnHubWidgetsBundle.swift` | `@main WidgetBundle { WeekWidget(); TodayWidget() }` |
| `ios/OwnHubWidgets/WidgetPayload.swift` | `Codable` struct for the JSON below. Reads `UserDefaults(suiteName: "group.com.ownhub.app")?.string(forKey: "ownhub.widget.v1")`. Any decode failure gives `.closed` |
| `ios/OwnHubWidgets/Provider.swift` | `TimelineProvider`. Entries for now, next midnight and next ISO Monday. `.atEnd` |
| `ios/OwnHubWidgets/WeekWidget.swift` | kind `OwnHubWeek`. `.supportedFamilies` = `[.systemSmall]`, plus the accessory families under `#available(iOSApplicationExtension 16.0, *)`. `.privacySensitive()` on accessory content |
| `ios/OwnHubWidgets/TodayWidget.swift` | kind `OwnHubToday`, `[.systemMedium]`. `widgetURL` plus `Link`s |
| `ios/OwnHubWidgets/Views/*.swift` | `WeekSegments`, `StatusLine`, `BrandMark`; `View.widgetBackground()` helper (`containerBackground` on iOS 17, else `.background`); `#Preview`s for EN/AR × light/dark × each family |
| `ios/OwnHubWidgets/Info.plist` | `NSExtension` > `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`. `UIAppFonts` = Rubik-400.ttf, Rubik-600.ttf. `CFBundleShortVersionString $(FLUTTER_BUILD_NAME)`, `CFBundleVersion $(FLUTTER_BUILD_NUMBER)` |
| `ios/OwnHubWidgets/OwnHubWidgets.xcconfig` | `#include "../Flutter/Generated.xcconfig"`, so the versions match Runner. Do not include the Pods xcconfig. The rule that versions must match is a precaution; I found no Apple source for it |
| `ios/OwnHubWidgets/OwnHubWidgets.entitlements` | `com.apple.security.application-groups` = `[group.com.ownhub.app]` |
| `ios/OwnHubWidgets/PrivacyInfo.xcprivacy` | As in §5 |
| `ios/OwnHubWidgets/Assets.xcassets` | Colour sets (light and dark), mark, accent |
| `ios/OwnHubWidgets/Localizable.xcstrings` | en and ar: gallery name, description, empty preview |
| `ios/OwnHubWidgets/Fonts/Rubik-400.ttf`, `Rubik-600.ttf` | Copies of `assets/fonts/*` |
| `lib/app_state/home_widget_sync.dart` | The writer (below) |
| `lib/features/today/domain/widget_projection.dart` | Pure `WidgetProjection.build({required TodayDay day, required bool open, required AppL10n l10n, required String lang, required DateTime now}) -> Map<String, Object?>` |
| `lib/app_state/widget_links.dart` | Tap handling (§3) |

**Payload** (one JSON string, key `ownhub.widget.v1`):

```json
{"v":1,"state":"open|closed","lang":"ar","dayKey":"2026-10-06","weekId":"2026-W41","done":1,"target":3,
 "today":"nothingDone","meal":true,
 "s":{"title":"…","week":"هذا الأسبوع، 1 من 3","weekFresh":"هذا الأسبوع، 0 من 3","inline":"…","a11y":"…",
      "status":"…","meal":"…","stale":"…","closed":"…"}}
```

Allow-listed fields only. There are no free-text fields from her data.

**Xcode project** (`ios/Runner.xcodeproj/project.pbxproj`). Create the target with Xcode's File > New > Target rather than hand-editing. The resulting entries:
- `PBXNativeTarget "OwnHubWidgetsExtension"` (`com.apple.product-type.app-extension`).
- Its build configurations:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.ownhub.app.OwnHubWidgets`
  - `IPHONEOS_DEPLOYMENT_TARGET = 15.5`
  - `TARGETED_DEVICE_FAMILY = 1`
  - `CODE_SIGN_ENTITLEMENTS = OwnHubWidgets/OwnHubWidgets.entitlements`
  - `INFOPLIST_FILE`
  - `SWIFT_VERSION = 5.0`
  - base configuration `OwnHubWidgets.xcconfig`
- Runner gets a `PBXTargetDependency` and a `PBXCopyFilesBuildPhase "Embed Foundation Extensions"` (dstSubfolderSpec 13).
- Build-phase order:
  - Flutter: "Drag Embed Foundation Extensions above Run Script" (https://docs.flutter.dev/platform-integration/ios/app-extensions).
  - If the "Cycle inside Runner" error appears, move "Thin Binary" to the bottom (https://docs.page/abausg/home_widget/setup/ios).
- Add the App Groups capability to Runner too.

**Risk.** Xcode 26 may create file-system-synchronized groups and raise `objectVersion` above 54. Run `pod install` afterwards (CocoaPods 1.17.0 is in Podfile.lock) and confirm it still parses the project.

**The extension needs no Pods or SPM link.** It reads UserDefaults directly. Linking `home_widget` into the extension is only needed for interactive widgets (https://docs.page/abausg/home_widget/features/interactive-widgets).

**Changed files**

| File | Change |
|---|---|
| `pubspec.yaml` | `home_widget: ^0.10.0`, with a comment in the file's style: what it writes, that it stays on the phone, and that the manifest reason is 1C8F.1 |
| `ios/Runner/Runner.entitlements` | Add `com.apple.security.application-groups` = `group.com.ownhub.app` |
| `ios/Runner/Info.plist` | `FlutterDeepLinkingEnabled` = false. Second `CFBundleURLTypes` entry with scheme `ownhub` |
| `ios/Runner/PrivacyInfo.xcprivacy` | 1C8F.1 if home_widget ships no manifest. Fix the CA92.1 comment |
| `lib/main.dart` | After `LocalPersistence.instance.start()`: `HomeWidgetSync.instance.start()`, iOS only, a no-op in tests like `LocalPersistence`. In `_OwnHubAppState`: `_locale` listener triggers a sync, and a post-frame `WidgetLinks.start(navigatorKey)` |
| `lib/app_state/account_data.dart` | `ThisPhoneWipe.signOut` and `clearPersistence` call `HomeWidgetSync.instance.clear()`, which saves null for the key, then `updateWidget` for both kinds. The router's ordinary sign-out (~line 5428) reaches it through `ThisPhoneWipe().signOut()` |
| `lib/routing/app_router.dart` | After `watchVerificationToken` changes `isVerified`, call `AppChanges.bump()` (if not already) so the widget opens or closes. No new screens |

**`HomeWidgetSync` behaviour**
- Listens to `AppChanges` with a 400 ms debounce, mirroring `LocalPersistence`.
- Writes on `paused`, so the widget is current when she leaves the app.
- `open = AppRouter.isVerified && AppRouter.signedInUid != null`.
- Builds the projection. Writes and calls `HomeWidget.updateWidget(iOSName: 'OwnHubWeek')` and `'OwnHubToday'` **only if the JSON changed**.
- `HomeWidget.setAppGroupId('group.com.ownhub.app')` once.
- Has a `WidgetStore` seam: a `HomeWidgetStore` and a `FakeWidgetStore` for tests.
- Every call is guarded in try/catch, like `LocalPersistence`, so it can never take the app down.

**Not in v1: interactive widgets.**
- "On a locked device, buttons and toggles are inactive" (https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).
- Logging from a widget needs a background Dart isolate.
- It would bypass the 5-second undo bus (`LogCommandBus`), against §2 rule 9.
- T03's doc already forbids an iOS extension writing outside the app's store.

**Tests**
- `test/features/today/widget_projection_test.dart`:
  - each `DayState` gives the right status key;
  - `closed` when not verified or signed out;
  - `weekFresh` is 0 of target;
  - Arabic output uses Western digits only (regex `[٠-٩]` must not match);
  - no daily count anywhere.
- `test/app_state/widget_privacy_guard_test.dart`:
  - For every `LifeStage` and with cycle set up or not, the encoded payload contains no `cycle`, `period`, `pregnan`, `postpartum`, `weight`, `kcal` or `allerg`, and no programme or session title.
  - An `analyzer` parse (same approach as `cycle_no_analytics_call_sites_test.dart`) proves `widget_projection.dart` and `home_widget_sync.dart` import nothing from `features/cycle`, `cycle_state`, measurements or `intake.dart`.
- `test/app_state/home_widget_sync_test.dart`, with the fake store and `fake_async`:
  - debounced writes;
  - no write when unchanged;
  - reload called for both kinds;
  - `clear()` on sign-out and deletion;
  - the demo tour never writes.
- `test/routing/widget_links_test.dart`:
  - whitelist mapping;
  - unknown `to` or a missing `homeWidget` is ignored;
  - an unverified tap resolves to C01 through `onGenerateRoute`;
  - no push when already on top.
- `test/release/ios_widget_config_test.dart`, file assertions:
  - both entitlements contain `group.com.ownhub.app`;
  - Info.plist has `FlutterDeepLinkingEnabled` false and the `ownhub` scheme;
  - the extension manifest has 1C8F.1;
  - pbxproj has `com.ownhub.app.OwnHubWidgets` and deployment target 15.5 on every target.
- Run the existing suite through `tool/release_preflight.sh`.

**Compile checks**
- `flutter build ios --debug --no-codesign`. The extension is embedded in Runner, so it is compiled too.
- Also `xcodebuild -workspace ios/Runner.xcworkspace -scheme OwnHubWidgetsExtension -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
- Visual check: SwiftUI previews in EN/AR, light/dark, tinted, at the largest Dynamic Type size.
- On a simulator: add each widget, deep-link with `xcrun simctl openurl booted "ownhub://widget?homeWidget=1&to=R03"`, and run sign-out then deletion to confirm the widget returns to "Open Own Hub to start".

**Owner actions** (cannot be done in code)
1. Team ID: fill `ios/ExportOptions.plist` and set `DEVELOPMENT_TEAM` for both targets. This is already owner item #2.
2. Register App Group `group.com.ownhub.app` in the Developer portal (https://developer.apple.com/documentation/xcode/configuring-app-groups).
3. Create App ID `com.ownhub.app.OwnHubWidgets` and enable App Groups on it and on `com.ownhub.app`.
4. Provisioning profiles for both IDs, or Xcode automatic signing once the Team is set.
5. Legal and MSA sign-off on the policy paragraph, and decide whether it bumps v3.0.
6. Decide whether "Tonight's dinner" belongs on the Today widget. It needs E07 to record a dinner she chose.
7. Optional: widget screenshots for the listing.

**Unresolved points from sources**
- Apple's two pages conflict on whether `Link` works in systemSmall.
- No Apple page states the extension bundle-id prefix rule, the per-target profile requirement, or that extensions need their own `UIAppFonts`.
- Not checked yet: whether home_widget 0.10.0 ships a privacy manifest, and whether the Firebase reCAPTCHA return still works with `FlutterDeepLinkingEnabled` off. Both need a check once the package is added.
