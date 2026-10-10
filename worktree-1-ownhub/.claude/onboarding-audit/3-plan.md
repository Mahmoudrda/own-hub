# Own Hub onboarding plan: value first, gate intact

Verdict: this follows the judge. Show her what the app does and let her build her week first. Then ask for her number and the ID check, so she has something of her own to protect. The whole-app gate, the C09b consent, the niqab and decline paths and the 684 tests all stay. Today it is **17 taps and 21 screens** from install to a running workout. The target is **9 taps (8 in the app plus the camera prompt) and 13 screens**.

---

## 1. Research findings (2024 to 2026), with sources

**Time to value and deferring the account**
- Apple's HIG says to get people to content fast, defer sign-in, ask for permissions in context and let people skip optional setup. https://developer.apple.com/design/human-interface-guidelines/onboarding
- Appcues and Luke Wroblewski describe "gradual engagement": let people use the app before asking for an account. Cited figures: 21% of users open an app once, and 71% churn within 90 days. The exception is apps that need an account to work, which is Own Hub's case (the women-only gate). So we move value in front of the gate rather than removing it. https://www.appcues.com/blog/gradual-engagement-mobile-app-first-screen
- Duolingo puts the first lesson before the account. Teardowns credit the delayed sign-up with about a 20% DAU lift, through the endowed-progress effect: an account wall converts better after she has invested something. https://www.appcues.com/blog/best-user-onboarding-examples · https://goodux.appcues.com/blog/duolingo-user-onboarding · https://relaunch.ai/blog/duolingo-onboarding-teardown-7-b-tests-behind-their-9-conver.html
- Several 2025 to 2026 roundups make the same points: under 5 screens before the first win, every forced sign-up wall leaks users, and the first "win" should come within about 60 seconds. https://www.designstudiouiux.com/blog/mobile-app-onboarding-best-practices/ · https://uxcam.com/blog/10-apps-with-great-user-onboarding/

**Personalization that feels like value (fitness and health)**
- Fitbod opens with "why are you here", then goal, experience and equipment. It ends on a projection of what three months could look like. https://www.theappfuel.com/examples/fitbod_onboarding · https://www.revenuecat.com/blog/growth/why-your-onboarding-experience-might-be-too-short
- Noom's email gate button says "See my results", so the account ask is framed as getting her result. Our "Save my week and join" copies that framing. https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel
- Ladder uses a two-minute quiz, then a "welcome workout". Nike Training Club asks for days per week, intensity and equipment, then recommends the first workout. https://www.garagegymreviews.com/ladder-app-review · https://anirban218.medium.com/abs-like-ronaldo-custom-workouts-anywhere-alright-nike-sign-me-up-8034ce336a14
- Flo validates each answer as she gives it, but its 55-step flow is criticised for delaying use. Take the reassurance, not the length. https://screensdesign.com/apps/flo-period-pregnancy-tracker/ · https://medium.com/@b.saisriya0501/design-critique-flo-app-d6950e80ba16
- MyFitnessPal shows a personal number right after the questions, and social features come after the core value. https://uxcam.com/blog/10-apps-with-great-user-onboarding/
- Strava gives one primary action (record) and leaves clubs and the social side for later. Users who complete a meaningful action on day one are cited as retaining at 2 to 3 times the rate of others. https://uxcam.com/blog/10-apps-with-great-user-onboarding/ · https://yukaichou.com/gamification-analysis/first-major-win-state-onboarding-design/

**Tutorials, empty states and checklists**
- NN/g: skip onboarding where you can. Deck-of-cards tutorials did not improve task success, and users who read them rated tasks as harder. Customisation in onboarding is fine when it changes the content. https://www.nngroup.com/articles/mobile-app-onboarding/ · https://www.nngroup.com/articles/mobile-tutorials/
- Empty states should say what to do next and show a sample. Checklists help, and a pre-checked first item (endowed progress) raises completion. https://userpilot.com/blog/onboarding-experience/ · https://www.appcues.com/blog/user-onboarding
- Named steps from the start help users build a picture of the process. https://www.nngroup.com/articles/4-principles-reduce-cognitive-load/

**Permission priming and denial**
- Explain the permission in context before the system prompt. Use soft buttons, and only ask at launch if the core function needs it. https://www.dogtownmedia.com/the-ask-when-and-how-to-request-mobile-app-permissions-camera-location-contacts/ · https://icons8.com/blog/articles/mobile-ux-design-user-permissions/
- Android: after two denials the system dialog stops appearing. Degrade gracefully, never block the screen, and "don't link to system settings in an effort to convince the user". So the reviewer route has to be equal to the Settings route, offered once and never nagged. https://developer.android.com/training/permissions/requesting

**Identity verification (trust and safety, KYC)**
- KYC drop-off comes from unexplained camera asks, hard-to-follow liveness instructions and broken expectations. Auto-capture with one button works best. https://kycaid.com/blog/reduce-user-drop-off-kyc-verification-ux/
- Bumble verifies everyone before they can swipe, with a human review team behind it. Own Hub's model of mandatory, women-only and a human fallback is the same pattern. https://bumble.com/en/the-buzz/the-end-of-catfishing-introducing-photo-verification
- Waiting for review without a time estimate drives abandonment. ID.me states "usually within 24 hours". https://help.id.me/hc/en-us/articles/4543221181463-How-long-ID-me-document-review-takes

**Habit hook**
- The Hook model is trigger, action, variable reward, then investment. The investment (her week, her logs) loads the next trigger. https://www.productplan.com/glossary/hook-model · https://growthmethod.com/hooked-model/
- Yu-kai Chou warns the Hook model can create compulsion. That fits our existing no-streak, weeks-not-days rule. https://yukaichou.com/gamification-analysis/hook-model-octalysis-habit-addiction/

**Arabic, RTL and MENA**
- Broken RTL in forms reads as low credibility. Egypt uses Western digits in apps, but Arabic keyboards type Arabic-Indic digits, which is exactly the C06 bug. https://contentech.com/the-complete-guide-to-app-localization-for-mena-what-to-fix-what-to-build-and-what-to-avoid/ · https://gtelocalize.net/arabic-website-localization/
- WhatsApp reaches about 90% of internet users in Egypt, so the coach invite link should be a WhatsApp share. https://www.askyazi.com/articles/whatsapp-penetration-across-africa-statistics-by-country

**Coach (supply side) onboarding**
- Superprof's flow is: register, verify qualifications, write the ad, wait. Its profile is free to create, and boosts are optional. https://www.superprof.com/blog/tutor-on-superprof/
- Coaching platforms (Trainerize's resources and others) share one onboarding sequence: welcome, a single intake, app setup, then the first deliverable (a plan the client can start now). https://resources.trainerize.com/ · https://www.fitbudd.com/academy/step-by-step-client-onboarding-checklists-for-new-coaches

**What this means for Own Hub:** personalise first, then the account, then the check. Every screen names one action. Permissions are asked just in time, and every failure has a way forward. Home's empty state is the tour. The day-2 return is driven by her own week, not a streak.

---

## 2. Target trainee flow (launch build: community and coach off)

Copy rule: no em dashes. MSA, second person feminine. Buttons spoken in her voice use the feminine imperative plus "my" (for example "جهّزي أسبوعي"), or a neutral verbal noun. They never address the app as a woman.

| # | Screen | What it says (EN / AR) | She taps | Why |
|---|---|---|---|---|
| 1 | **C01 Welcome** (now with a language toggle) | Headline: "Your training, your food, your cycle. Women only." / "تدريبكِ، وطعامكِ، ودورتكِ. للنساء فقط." Body: existing `quietWorkoutsForHomeFoodYouAlready_u7fo9`. Toggle chips "English · العربية", preselected from the phone locale. | **"Set up my week" / "جهّزي أسبوعي"** (tap 1). Text link: "I already have an account" | Says what the app does. Language is one optional tap here, so C02 drops out of the first run. |
| 2 | **O03 "Your week"** (compact mode, ungated) | Bar: "1 of 3 · Your week" / "1 من 3 · أسبوعكِ". Existing title and subtitle. Chips: days (preselected), minutes (preselected). Group "Anything we should train around?" with options Nothing right now (preselected), After a birth, Pregnant, A knee, back or shoulder. Note: "Only you see this. It stays on this phone." / "لا يرى هذا أحد سواكِ، ويبقى على هذا الهاتف." | **"See my week" / "اعرضي أسبوعي"** (tap 2) | One screen and zero required choices. Asking life stage before her first session is the safety reason. |
| 3 | **O05 Her week card** (pre-signup mode) | Kicker "Built from your answers" / "مبنيّ على إجاباتكِ". Her answers line. Programme card. Sage note: "One quick check keeps Own Hub women only. Then day 1 is yours." / "تحقّق سريع واحد يُبقي Own Hub للنساء فقط، ثم يصبح يومكِ الأول جاهزًا." | **"Save my week and join" / "احفظي أسبوعي وانضمّي"** (tap 3) | Noom-style framing. She now has something to protect. `OnboardingState.finish()` runs here. |
| 4 | **C06 Number** | Bar "2 of 3 · Your number" / "2 من 3 · رقمكِ". Phone row forced LTR. Inline error line, kept with her input. | Types the number, then "Send me a code" / AR fixed to **"إرسال الرمز"** (tap 4) | Arabic-Indic digits accepted. Errors are said out loud. |
| 5 | **C07 Code** | Bar phase 2. Auto-submits on the sixth digit, shows "Checking your code" / "جارٍ التحقّق من الرمز" while the claim is read. Link "Edit number" / "تعديل الرقم". | 0 taps | No silent wait and no double push. |
| (6) | ~~C08 role~~ | Skipped while `coachApp` is off. Role is set to trainee and `beginIdentityCheck()` runs in C07. | n/a | A one-option question is not a question. |
| 7 | **C09b One check** (C09's promise merged above the consent) | Bar "3 of 3 · Quick check" / "3 من 3 · تحقّق سريع". Title `oneCheckThenYouAreIn`. Plain bullets: `weReadYourNationalIdCardThe`, `aSelfieIsMatchedToThePhoto`, `itTakesAbout90Seconds`. Then "Before the camera opens" with **all five v1 disclosure bullets, verbatim and visible**. | **"I agree, start the camera"** (tap 5). Links: "I wear niqab, check me another way", "I would rather not" | One screen instead of two, the "own system / Google Cloud" contradiction is gone, and the consent text is unchanged, so `CONSENT_VERSION = 1` still holds. |
| 8 | OS camera prompt | n/a | Allow (tap 6) | Primed in context by step 7. |
| 9 | **C10, C10b** | Auto-capture. If the camera is unavailable, a message card replaces the dead frame (see section 5). If the network drops at the liveness start: "No connection. Your photos are still here, try again." / "لا يوجد اتصال. صوركِ ما زالت هنا، حاولي مرة أخرى." | 0 | No silent dead end. |
| 10 | **C11 Selfie** | existing | Done (tap 7) | n/a |
| 11 | **C12 Checking** | No button. Real ticks: "Both sides of your card taken" / "تم تصوير وجهَي بطاقتكِ", "Selfie taken" / "تم التقاط صورتكِ الذاتية", then spinning "Matching your selfie to your card" / "نطابق صورتكِ الذاتية مع بطاقتكِ". After 20 s: "Taking longer than usual" / "يستغرق الأمر وقتًا أطول من المعتاد". | 0 | It moves on only when the real verdict arrives. |
| 12 | **C13 You're in** (now the stack root) | Existing seal, "Your ID photo and selfie have been deleted", measured duration. | **"Start day 1" / "ابدئي اليوم 1"** (tap 8) lands on `[T01, R03]`. Text button: "Go to Home" / "الانتقال إلى الرئيسية" lands on `[T01]` | Peak moment leads to the first workout. The pledge waits until the community exists. |
| 13 | **R03** | existing | "Start, everything's ready" (**tap 9**) opens R07 | First workout running |

**Targets**
- **First workout running: 9 taps.** Screens: C01, O03, O05, C06, C07, C09b, C10, C10b, C11, C12, C13, R03, R07. About 3 to 4 minutes including the SMS and the roughly 90 s check. We state no total time on screen until analytics measures the median.
- **First meal logged: 10 taps.** C13 "Go to Home" (8), Home "Tell us one thing you eat", now rewired to E01 starter plates (9), "Log" on a plate (10).
- **First meal plan seen: 9 taps.** C13 "Go to Home" (8), Home "Plan this week's dinners" (9) opens E07: 5 preset dinners and a shopping list. Choosing a dinner: +2 taps once E07 pick mode lands (LATER).
- **Cycle set up: about 13 taps.** Home "Track my cycle" (9), Y01 Continue with dates (10), dates (2 or so), Save.

**Branches**
- "I already have an account": C06 then C07.
  - Verified with setup done: `[T01]`.
  - Verified without setup: existing O01 walk.
  - Not verified: C09b. At C13, "Start day 1" first opens O03 compact (post-signup mode), then O05 "Start day 1 now".
- **Killed after O05, before C06:** she relaunches on C01. Because `setupDone` is true, "Set up my week" opens O05 with her saved week.
- **Niqab or decline:** C15, then C14. C14 now shows her saved week ("Your week is saved · 3 days · 20 min"), so she has something she owns while she waits. An ETA and real read-only content are LATER (section 5).

---

## 3. Target coach flow

**Launch build (`coachApp` off).** Coaches must not be lost:
- MUST: on C08 (only shown when the flag is on), drop the false line "You can change this later in your profile".
- LATER, owner decision: a text link on C01, "I coach women" / "أنا أدرّب النساء", opening a one-screen interest page ("We open coaching soon. Tell us about you and we will call you.") that sends a WhatsApp message to the team. `url_launcher` is already a dependency. It needs the owner's contact number.

**When `coachApp` turns on (all LATER, and all required before flipping the flag):**

| # | Screen | Copy / action |
|---|---|---|
| 1 | C01 | "I coach women" link, which sets the intended role to coach |
| 2 | C06, C07 | as for the trainee (2 taps) |
| 3 | C08 | shown with the coach card preselected from step 1, plus Continue |
| 4 | C09b, camera, C11, C12 | as for the trainee |
| 5 | **C13 coach variant** | Primary "Set up my coach profile" / "جهّزي ملفكِ كمدرِّبة". Built by branching on `lastSignupRole`. The coach link is hidden for trainees. |
| 6 | K01 | Name, city, one line. The three rules are shown inline as a code of conduct with a checkbox, and that agreement is recorded. |
| 7 | K03 | specialties |
| 8 | K02 | **real certificate photo upload** (today `onAddCertificate` is null) |
| 9 | K04 | capacity |
| 10 | K05 | **"Add payout later" / "إضافة بيانات الدفع لاحقًا"**, so `completeSetup()` runs and the application is submitted |
| 11 | K07 desk with checklist | "Your application is with us" (pre-checked, endowed progress), "Build your first plan" (K20), "Invite a client" (WhatsApp share link carrying a pending `coachId`), "Design your page" (coachbrand) |

Target: about 16 taps to a submitted application, and 2 more to the first plan draft. Prerequisites:
- Roles and coach setup persisted locally and in Firestore.
- A role-aware `frontDoorFor`.
- `isDue` returns false for coaches.
- K02 to K05 `onBack` uses `maybePop`. This one is cheap and could be MUST now.

---

## 4. Home right after onboarding, and the day-2 hook

**Day-one Home (`today_view.dart _dayOne`), top to bottom**
1. Cover plus her echo line: the existing `daysAWeekDaysMinutesASession*` string, built from `IntakeRepository.read()`, so O05's "this is yours" carries through.
2. **Start day 1** (big, unchanged).
3. Your first week (T07 checklist, unchanged).
4. "Tell us one thing you eat", now opening **E01** (one-tap starter plates) instead of E02 typing.
5. **New:** "Plan this week's dinners" / "خطّطي لعشاء هذا الأسبوع", subtitle "Five Egyptian dinners and one shopping list" / "خمس وجبات عشاء مصرية وقائمة تسوّق واحدة". Opens E07.
6. **New:** "Track my cycle" / "تابعي دورتكِ", subtitle "Optional, and it stays on this phone" / "اختياري، ويبقى على هذا الهاتف". Opens Y01. Hidden once she sets it up or taps "Not now" / "ليس الآن".
7. Sage weekly rule (unchanged).

No tours and no overlays. The empty state is the onboarding (rule 17, NN/g).

**Day-2 hook (Hook model, inside our no-streak rules)**
- **Investment (day 1):** her week, a logged meal or session, a planned dinner.
- **Trigger (MUST, in-app):** R10 "Finished" gets a next-step card, "Next: day 2, on any day this week · {n} of {target} done" / "التالي: اليوم 2، في أي يوم من هذا الأسبوع". Its secondary action is "Plan this week's dinners". Fix R10's "Back to Today" to clear the stack.
- **Trigger (LATER, external):** after her first finished session, prime an opt-in reminder: "Want a nudge on your training days?". Only on her chosen number of days, no streak copy, weekly. Needs a local notifications plugin and the Android 13 notification permission.
- **Action:** one tap, Home "Start day 2".
- **Variable reward (honest):** the week ring filling, a different Rahma recipe surfaced on Eat, R10's real numbers. Nothing invented.

---

## 5. Verification, consent and health consent: kept, reordered, explained

- **Gate unchanged.** `gateDestination`, `behindVerification` and `openBeforeVerification` are untouched. The reorder only uses the `onboarding` flow, which is already open before verification.
- **Consent unchanged in substance.** C09b stays the only door to C10. The five v1 bullets stay verbatim and visible (`kCaptureConsentVersion = 1` matches `functions/identity/config.py CONSENT_VERSION = 1`). Any rewording is LATER and needs both versions bumped and the functions redeployed. I am not recommending hiding the cross-border processing line behind "Details": under PDPL, consent to a transfer abroad should be visible when she agrees.
- **Health consent.** Life stage answered before sign-up stays on the phone. The health backup stays a separate opt-in (A03, `record_health_consent`, `HEALTH_CONSENT_VERSION`). Nothing about it moves into onboarding. LATER: offer the backup at the first week's end, when she has something to lose.
- **Progress shown honestly.** One 3-phase label replaces "Step 1 of 2" and "Step 2 of 2".
- **Something to do while reviewed.** C14 shows her saved week (MUST). LATER: real read-only content in C04 (one playable move, three real Rahma recipes), an honest wait window once the owner sets a reviewer SLA, and a push on approval (needs `firebase_messaging`).
- **Owner decision, not code: G1.** Should a phone-verified woman waiting for a reviewer use local-only Train, Eat and Cycle? This reverses "The owner has chosen the whole-app gate" (app_router.dart:1205-1213). Present it as a decision. Do not build it.

---

## 6. Implementation list, in build order

Two rules from the repo that apply to every item:
- **Strings** are added with `python3 tool/add_strings.py strings.json` (it takes a lock and regenerates the ARB through `6-v2/src/build-flutter.mjs`). Existing Arabic is changed in its `6-v2/i18n` source and regenerated. Never hand-edit `lib/l10n/*.arb`, `app_routes.dart` or the tokens, and never run `dart format` over them.
- **Navigation edges** must stay literal `goTo(context, 'XX')` or route-id strings inside `AppRouter._built` builders. `nav_reachability_test` reads them from source, so an edge hidden in a helper function is invisible to it.

### Block A: stop losing women today (MUST, independent of the reorder)

| ID | Change | Files | Tests |
|---|---|---|---|
| A1 | **C12 has no Continue button.** Delete the `onContinue` param and its footer button. The ring becomes indeterminate. Ticks 1 and 2 mean "taken" (true), tick 3 spins. A 20 s timer shows "Taking longer than usual" text. A "Check me another way" button appears only if the server allows `request_review` while `verify_identity` is pending (check `functions/`). Wrap the screen in `PopScope(canPop:false)`. | `features/signup/presentation/checking_view.dart` (:39, :241, :262-279); `routing/app_router.dart:1167` (remove `onContinue`) | `checking_view_test`: no `AppButton` while `VerificationChecking`; after 20 s (fakeAsync) the "longer" text appears; back gesture blocked |
| A2 | **Arabic-Indic digits on C06.** Move `asciiDigits` into the domain layer (for example `features/signup/domain/digits.dart`, re-exported from `firebase_auth_repository.dart`) and use it in `_digits`. | `phone_number_view.dart:79`; `firebase_auth_repository.dart:121` | `phone_number_view_test`: typing `٠١٠١٢٣٤٥٦٧٨` enables Send and sends `+201012345678` |
| A3 | **C06 and C07 error lines.** Map each `AuthFailure` to an inline `Semantics(liveRegion)` line and keep her input: invalidNumber, network, tooManyAttempts (reuse `tooManyTriesWaitAMinuteThen`), invalidCode, codeExpired (focus "Send it again"), unknown. Add the "Edit number" link on C07. | `phone_number_view.dart:100-102`; `code_view.dart:126-129`; new strings (section 7) | One widget test per failure, each with a fake repository that throws it |
| A4 | **C07 awaits confirmation.** Change `onConfirmed` to `Future<void> Function()?`, hold `_checking`, show "Checking your code". Remove the hard-coded `'+20 100 555 0132'` fallback. Show the platform-neutral sentence `itChecksItselfTheMomentTheSixth_1pr5i` on both platforms (subscribing to auto-retrieval is LATER). | `code_view.dart:116-132`; `app_router.dart` C07 builder | `code_view_test`: a second tap during the check does not push twice |
| A5 | **Camera unavailable card.** `CaptureScaffold` renders `CaptureUnavailable`. For permissionDenied: "Open Settings" (iOS through `url_launcher` `app-settings:`; Android through a tiny MethodChannel in `MainActivity` opening `ACTION_APPLICATION_DETAILS_SETTINGS`), then restart the session on resume. "Check me another way" sets `pendingReviewPath = ReviewPath.declined` and opens `C15`. Other reasons: "Try again" plus the reviewer option. | `widgets/capture_scaffold.dart`; `id_capture_view.dart:160-174`; `selfie_capture_view.dart`; `app_router.dart` C10/C10b/C11 builders (new `onAskReviewer: … goTo(context, 'C15')`); `android/app/src/main/.../MainActivity.kt` | `capture_views_test`: one per reason; the button is never a disabled dead end |
| A6 | **Network blip is a retry, not a review.** Add `CallFailureKind.network` (callable codes `unavailable` and `deadline-exceeded`; check how the provider wraps errors) and `LivenessStart.offline`. The C10b router case shows the offline notice with "Try again", keeps the evidence, counts retries, and offers C15 after 2 failures. | `domain/review_request.dart:102-175`; `data/identity_check.dart:38-143`; `app_router.dart:1090-1095` | `capture_pipeline_test` / `verification_submission_test`: `unavailable` gives offline, not C15; the third failure offers the reviewer |
| A7 | **RTL and voice.** Wrap the phone row in `Directionality(ltr)`. Arabic: `sendMeACode` becomes "إرسال الرمز", `sendItAgain` becomes "إعادة إرسال الرمز". | `phone_number_view.dart:130-166`; i18n source | `phone_number_view_test`: in Arabic, +20 is visually left of the field |
| A8 | **C09 contradiction.** Remove `checkedByOwnHubsOwnSystemYour` (the untappable "Tap to read" line). | `why_we_check_view.dart:99-102` | `why_we_check_view_test` updated |
| A9 | **Stale gate comment.** Say `accountRequired` ships on. | `app_router.dart:537-540` | n/a |

### Block B: value first (MUST)

| ID | Change | Files | Tests |
|---|---|---|---|
| B1 | `OnboardingState`: add `bool beforeSignup` (set by C01, cleared at C06 send and on sign-out). `isDue` is **unchanged**: pre-signup setup marks `setupDone`, so the existing logic already skips the walk after verification. | `app_state/onboarding_state.dart` | `onboarding_due_test`: new case, setup done before sign-up means not owed after verification |
| B2 | `IntakeStepScaffold`: optional `titleOverride` (phase label); hide Skip when `onSkip == null` and hide X when `onClose == null`. `ScheduleView`: `includeLifeStage` param adding the LifeStage group (the 4 existing keys, preselected from the repo, written by the same `merge`) and the "stays on this phone" note. | `onboarding/presentation/intake_step_scaffold.dart`, `schedule_view.dart` (reuse the `LifeStageView` option list) | `schedule_view_test`: compact mode writes days, minutes and lifeStage; no Skip or X |
| B3 | `StartingProgramView`: `beforeSignup` mode with `onSaveAndJoin`. Kicker "Built from your answers", sage note, no "Start tomorrow". **In all modes**, hide "Pick a different program" when `catalogue.length < 2`. | `starting_program_view.dart` | `starting_program_view_test` |
| B4 | **Router reorder.** `C01.onGetStarted` sets `beforeSignup` and calls `goTo(context, intakeRepository.setupDone ? 'O05' : 'O03')` (both literals). In the O03 builder, beforeSignup means compact mode, `onContinue` goes to `goTo(context,'O05')`, and `onSkip`/`onClose` are null. In the O05 builder, beforeSignup means `onSaveAndJoin` runs `OnboardingState.instance.finish()` then `goTo(context,'C06')`. | `app_router.dart` C01, O03, O05 builders | new `test/journeys/value_first_signup_test.dart`: C01, O03, O05, C06 with no gate interference, intake saved, weekly target applied |
| B5 | **Skip C08 when `!offerCoach`.** In `C07.onConfirmed` for the not-verified case: if the coach app is on, `goTo(context,'C08')`. Otherwise set `lastSignupRole = SignupRole.trainee`, set the RoleScope, call `beginIdentityCheck()` and `goTo(context,'C09b')`. | `app_router.dart:940-971` | `setup_after_signup_test` and `flag_aware_promises_test` updated |
| B6 | **Merge C09 into C09b for the first run.** `ConsentView` gets an optional header (title plus 3 plain bullets) and an `onNiqabPath` link. The disclosure bullets stay verbatim. The C09 route stays as the gate re-entry screen (`gateDestination` unchanged). | `consent_view.dart`; `app_router.dart` C09b builder (`onNiqabPath: … goTo(context,'C15')`) | `consent_view_test`: header and niqab link present; agree still writes a v1 record before `onAgreed` |
| B7 | **C13 as the root, leading to Start day 1.** C12 `onVerified`, C14 `onApproved` and C15 `onAlreadyVerified` use `pushNamedAndRemoveUntil(C13)`. `YoureInView` gets `onStartDay1` and `onGoHome`, with the primary label chosen by flag: community off gives `startDay1` and community on keeps `readTheThreeRules` → C16. In the router: setupDone means `[T01, R03]`, otherwise `enteredFromSignup = true` then `goTo(context,'O03')` compact. The coach link shows only for coach or both roles. | `youre_in_view.dart:104-115`; `app_router.dart:1160-1290` | `youre_in_view_test`; `setup_after_signup_test`: back from R03 reaches T01 and never C12 or the camera |
| B8 | **One phase label.** `signupPhaseLabel(l10n, phase)` in `ui/app_step_progress.dart` (dictionary strings only, Western digits). Used on O03/O05 (beforeSignup), C06, C07 and C09b. Remove `step1Of2` and `step2Of2` use. | `app_step_progress.dart`, `phone_number_view.dart:113`, `code_view.dart:152`, `consent_view.dart` | `i18n_guard_test` passes; label tests in both locales |
| B9 | **C01 rewrite.** Language toggle: extract `LanguageView`'s write logic (`localePreference.write` plus `LocaleScope.value`) into a shared helper. New headline while community is off; primary "Set up my week". | `welcome_view.dart`; `language_view.dart` | `welcome_view_test`: the toggle switches locale live and persists |
| B10 | **Pregnancy and postpartum honesty (safety).** When `lifeStage` is pregnant or postpartum, R03 shows a card before Start with "I have my doctor's OK, start" and "Not today". Copy is in section 7 and needs owner review. | `train/presentation/workout_day_view.dart` (R03), router R03 builder passes `intakeRepository.read().lifeStage` | `train_honesty_test`: card shown only for those two stages |

### Block C: Home and the hook (MUST)

| ID | Change | Files | Tests |
|---|---|---|---|
| C1 | Echo line on day one. Extract `_herAnswers` from O05 into a shared `herAnswersLine(l10n, intake)`. TodayView takes an `Intake?`. | `today_view.dart:498-642`; `starting_program_view.dart`; router T01 | `first_run_journey_test` |
| C2 | "Tell us one thing you eat" goes to E01, not E02. | `app_router.dart:1413` | `eat_journey_test`: one tap from Home to a starter Log |
| C3 | "Plan this week's dinners" row, `onOpenWeekPlan: … goTo(context,'E07')`. | `today_view.dart`, router T01 | `nav_reachability_test` (E07 within 2 taps of a tab) |
| C4 | "Track my cycle" row, opens `goTo(context,'Y01')`. Hidden when set up or dismissed (local pref). Y01 `onSkip` uses `maybePop` instead of pushing a second T01. | `today_view.dart`, `today_day.dart`, router T01 and Y01 (:2352-2364) | `cycle_journey_test`; **cycle no-analytics guard must stay green** |
| C5 | R10 next-step card plus "Back to Today" clears the stack (`pushNamedAndRemoveUntil` T01). | `train/presentation/finished_view.dart`; router R10 (:1675-1686) | `train_journey_test` |
| C6 | **Funnel analytics call sites.** Add `static AnalyticsGateway analytics = const AnalyticsGateway(NullAnalyticsSink())` to `AppRouter`, plus a debug-only print sink. Events: `screenViewed` for flows signup, onboarding and today only (never cycle); `signUpStarted` (C01); `intakeCompleted` (O05); `verificationSubmitted` (C12 open); `verificationDecided` with an outcome token; `sessionStarted` / `mealLogged` with `isFirstTime`. | `app_router.dart` (onGenerateRoute and the named builders) | Recording-sink journey test asserting funnel order; the cycle guard test |

### LATER (owner decision or new dependency)
- E07 pick mode ("Add to {day}" via `swapDinner`) and "Fill my week".
- A reviewed gentler session for pregnant and postpartum users.
- C14: real C04 content, an ETA, push on approval (`firebase_messaging`).
- G1 unlock decision.
- Reminder opt-in (local notifications plugin and the Android 13 permission).
- Choosing an analytics sink (Firebase Analytics needs updates to the privacy manifest and Play data safety).
- C07 Android auto-retrieval subscription.
- Rewording the disclosure (needs a version bump on both sides).
- C16 shown on first M01 open, with a recorded version.
- The whole coach list in section 3.
- The coach interest link (needs an owner contact).
- Removing the per-question Skip in the A02 walk.
- Measuring time-to-install figures and then stating one honest estimate on C01.

---

## 7. New and changed strings (EN / AR, MSA, feminine)

| Key purpose | EN | AR |
|---|---|---|
| C01 headline | Your training, your food, your cycle. Women only. | تدريبكِ، وطعامكِ، ودورتكِ. للنساء فقط. |
| C01 primary | Set up my week | جهّزي أسبوعي |
| Phase 1/2/3 | 1 of 3 · Your week / 2 of 3 · Your number / 3 of 3 · Quick check | 1 من 3 · أسبوعكِ / 2 من 3 · رقمكِ / 3 من 3 · تحقّق سريع |
| O03 note | Only you see this. It stays on this phone. | لا يرى هذا أحد سواكِ، ويبقى على هذا الهاتف. |
| O03 primary | See my week | اعرضي أسبوعي |
| O05 kicker | Built from your answers | مبنيّ على إجاباتكِ |
| O05 note | One quick check keeps Own Hub women only. Then day 1 is yours. | تحقّق سريع واحد يُبقي Own Hub للنساء فقط، ثم يصبح يومكِ الأول جاهزًا. |
| O05 primary | Save my week and join | احفظي أسبوعي وانضمّي |
| C06 invalid | That number does not look right. Check it and try again. | يبدو أن هذا الرقم غير صحيح. راجعيه ثم حاولي مرة أخرى. |
| C06 network | No connection. Your number is still here, try again when you are back online. | لا يوجد اتصال. رقمكِ ما زال هنا، حاولي مرة أخرى عند عودة الاتصال. |
| C06 unknown | We could not send the code. Try again in a moment. | تعذّر إرسال الرمز. حاولي مرة أخرى بعد قليل. |
| C07 invalid | That code did not match. Check the message and type it again. | الرمز غير مطابق. راجعي الرسالة واكتبيه مرة أخرى. |
| C07 expired | That code has expired. Ask for a new one below. | انتهت صلاحية هذا الرمز. اطلبي رمزًا جديدًا من الأسفل. |
| C07 checking / edit | Checking your code · Edit number | جارٍ التحقّق من الرمز · تعديل الرقم |
| Camera off title | Camera access is off | الوصول إلى الكاميرا مغلق |
| Camera off body | Own Hub needs the camera to read your card. You can turn it on in Settings, or a woman from Own Hub can check you another way. | يحتاج Own Hub إلى الكاميرا لقراءة بطاقتكِ. يمكنكِ تشغيلها من الإعدادات، أو تتحقّق منكِ امرأة من Own Hub بطريقة أخرى. |
| Camera failed | The camera could not start. This is not about you. Try again, or a woman from Own Hub can check you another way. | تعذّر تشغيل الكاميرا، والأمر لا يتعلّق بكِ. حاولي مرة أخرى، أو تتحقّق منكِ امرأة من Own Hub بطريقة أخرى. |
| Buttons | Open Settings · Check me another way | فتح الإعدادات · التحقّق بطريقة أخرى |
| C10b offline | No connection. Your photos are still here, try again. | لا يوجد اتصال. صوركِ ما زالت هنا، حاولي مرة أخرى. |
| C12 ticks | Both sides of your card taken · Selfie taken · Matching your selfie to your card | تم تصوير وجهَي بطاقتكِ · تم التقاط صورتكِ الذاتية · نطابق صورتكِ الذاتية مع بطاقتكِ |
| C12 slow | Taking longer than usual. Your connection may be slow. You can keep waiting here. | يستغرق الأمر وقتًا أطول من المعتاد. قد يكون اتصالكِ بطيئًا، ويمكنكِ الانتظار هنا. |
| C13 secondary | Go to Home | الانتقال إلى الرئيسية |
| Home rows | Plan this week's dinners · Five Egyptian dinners and one shopping list | خطّطي لعشاء هذا الأسبوع · خمس وجبات عشاء مصرية وقائمة تسوّق واحدة |
| | Track my cycle · Optional, and it stays on this phone · Not now | تابعي دورتكِ · اختياري، ويبقى على هذا الهاتف · ليس الآن |
| R10 next | Next: day 2, on any day this week | التالي: اليوم 2، في أي يوم من هذا الأسبوع |
| R03 pregnant (owner review) | Day 1 was not written for pregnancy. Please ask your doctor before you start, and skip any move that does not feel right. | لم يُكتب اليوم الأول للحمل. يُرجى استشارة الطبيب قبل أن تبدئي، وتخطّي أي حركة لا تشعرين بالراحة معها. |
| R03 postpartum (owner review) | Day 1 was not written for the weeks after a birth. Please wait for your doctor's OK, and skip any move that does not feel right. | لم يُكتب اليوم الأول لفترة ما بعد الولادة. يُرجى انتظار موافقة الطبيب، وتخطّي أي حركة لا تشعرين بالراحة معها. |
| R03 buttons | I have my doctor's OK, start · Not today | لديّ موافقة الطبيب، لنبدأ · ليس اليوم |

Reused keys, unchanged: `oneCheckThenYouAreIn`, `weReadYourNationalIdCardThe`, `aSelfieIsMatchedToThePhoto`, `itTakesAbout90Seconds`, `iWearNiqabCheckMeAnotherWay`, `iAgreeStartTheCamera`, `iWouldRatherNot`, the five disclosure bullets, `startDay1`, `tryAgain`, `anythingWeShouldTrainAround`, the four life-stage labels, `daysAWeekDaysMinutesASession*`, `tooManyTriesWaitAMinuteThen`.

---

## 8. What must not break

- **Gate:**
  - `gateDestination`, `behindVerification` (unknown ids stay gated) and `openBeforeVerification` are unchanged.
  - `verification_gate_test`, `fresh_claim_is_truth_test`, `offline_verification_launch_test` and `exits_and_already_verified_test` stay green.
  - A returning verified woman still skips the ID check and setup (`app_router.dart:952-971`).
- **Consent:**
  - C09b is the only way to C10.
  - `consentRecorded` still guards deep links.
  - The v1 text is unchanged, so `kCaptureConsentVersion` and `CONSENT_VERSION` stay 1.
  - The niqab and decline paths still reach C15 with no selfie.
  - `signup_consent_test`, `review_consent_before_call_test` and `consent_view_test` stay green.
- **Legal and privacy:**
  - PDPL deletion stays reachable from C14 (A02).
  - The health backup remains a separate opt-in.
  - Life stage stays on the phone.
  - The cycle no-analytics AST guard stays green.
  - Crashlytics gets no user identifiers.
- **Honesty rules:**
  - C13 keeps "images deleted" and the measured duration.
  - No invented programme content and no fake counts.
  - Dark features stay hidden (`screenIsOn`).
  - No daily streaks.
- **Flags:**
  - `accountRequired=true`; coach, community, marketplace and payments stay off.
  - `testingAidsAllowed` stays false in every build.
  - C16, C08 and the coach link stay wired behind their flags, so turning them on later still works.
- **Navigation:**
  - `nav_reachability_test` and `routing_test` stay green (literal ids in builders).
  - `setup_after_signup_test` and `onboarding_journey_test` stay green. The A02 "Your training" walk is unchanged.
  - O01's `PopScope` keeps clearing `enteredFromSignup`.
  - `_firstRunStack` still opens `[C01]` for a new install, and `[T01, O01]` when `isDue`.
- **Release check:**
  - `flutter analyze` and the full `flutter test` suite (684+) pass.
  - Then build onto the iOS simulator and screenshot every new screen in EN and AR. A green suite has missed blank screens before.

## 9. Proposed success measures (once the C6 call sites have a sink)

Measure each funnel step: C01, O05, C07, C09b agree, C12 verdict, C13, R07 start, first meal, first plan opened, and the day-2 and day-7 return. Proposed starting goals, to be reset after a baseline:
- 85% from C01 to O05 saved.
- 70% from O05 to an ID check submitted.
- 60% of those reaching C13 who start R07 the same day.
- 40% returning for a second session within 7 days.

Owner decisions to put to him:
1. G1: open local-only features while a reviewer check is pending?
2. The reviewer SLA wording for C14.
3. The pregnancy and postpartum R03 copy.
4. The contact for the coach interest link.
5. Which analytics sink to use.
6. The reminder plugin.