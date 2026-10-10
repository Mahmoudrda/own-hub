Note: claude-sonnet-5[1m] (the safety classifier) was unavailable (timed out) when reviewing this subagent's work. Please carefully verify the subagent's actions and output before acting on them.

I've built every MUST item in the plan except one sub-part (the reviewer button on C12, below). Nothing is committed; all changes are in the worktree on `onboarding/2026-10-06`. `flutter analyze` is clean. The full `flutter test` run has 4702 passing and 1 failing. That failure is `test/qa/round1/r1_defects_test.dart` "R1-12a R12 names today, not Tuesday". It fails because today is a Tuesday, it failed the same way before I changed anything (baseline 4627 pass, 1 fail), and I didn't touch that file.

I haven't built the app onto a simulator or taken the EN/AR screenshots the plan asks for. I also haven't compiled the Android settings code. Both still need doing before release.

## Tap counts (launch flags: account required, community and coach off)

| Goal | Before | Now | Path |
|---|---|---|---|
| First workout running | 17 taps, 21 screens | **9 taps (8 in the app + camera permission), 13 screens** | C01 → O03 → O05 → C06 → C07 (no tap) → C09b → camera Allow → C10/C10b (auto) → C11 Done → C12 → C13 "Start day 1" → R03 Start → R07 |
| First meal logged | | **10** | C13 "Go to Home" → "Tell us one thing you eat" (now opens Eat with one-tap starter plates) → Log |
| Meal plan seen | | **9** | C13 "Go to Home" → "Plan this week's dinners" → E07 |
| Cycle set up | | **about 13** | Home "Track my cycle" → Y01 → dates → Save |
| Coach first action | | unchanged | The coach app is off at launch. With it on, the path is C07 → C08 → C09 → C09b → camera → C13 → "set up my profile" link (shown only to coaches) → K01. The rest of the coach flow is LATER. |

## Status by item

**Block A (stop losing women)**
- **A1, done with one part skipped.** C12 has no Continue button, no fake 72% ring, the ticks say what really happened, a "Taking longer than usual" line appears after 20 seconds, and back is blocked. The "indeterminate ring" is a still hourglass, not a spinner: the codebase has no spinners anywhere, and a looping animation would hang the journey tests.
  - **Skipped: the "Check me another way" button while the check runs.** The server's `request_review` does not check for an automatic check still in progress, so a pass and a review request could overwrite each other.
- **A2, done.** `asciiDigits` now lives in `lib/features/signup/domain/digits.dart` (the auth repository re-exports it), and C06 uses it, so Arabic keyboard digits light the button.
- **A3, done.** C06 and C07 each say why a send or a code failed, keep her input, and announce the line to screen readers. C07 has an "Edit number" link, and an expired code moves focus to "Send it again".
- **A4, done.** C07 waits for the next screen to be chosen and shows "Checking your code", so a second tap can't push twice. The fake sample number is gone, and both platforms show the platform-neutral sentence.
- **A5, done.** A camera that can't start shows a message card instead of a dead frame. If she turned access off: "Open settings", and the camera is tried again when she comes back. Otherwise: "Try again". Both offer "Check me another way", which drops any photos already taken and opens C15. The Android side is a small `MethodChannel` added to `MainActivity.kt`, but I haven't compiled it.
- **A6, done, built differently.** I didn't add `CallFailureKind.network`, because about eight other screens switch on that enum and would all change behaviour. Instead a new `isNetworkCallFailure` check returns `LivenessStart.offline`. C10b keeps her photos with a "Try again" button, and offers the reviewer from the third failed try.
- **A7, done.** The phone row is forced left-to-right. The Arabic buttons now read "إرسال الرمز" and "إعادة إرسال الرمز", changed in `6-v2/i18n/msa/05.json`.
- **A8, done.** The untappable "Tap to read" line is gone from C09.
- **A9, done.** The gate comment now says the gate ships on.

**Block B (value first)**
- **B1, done, one change.** `beforeSignup` is cleared when her code is accepted, not when the code is sent, so going back from C07 to O05 still shows "Save my week and join". It is also cleared on sign-out. `isDue` is unchanged.
- **B2–B10, done.** Notes on the less obvious ones:
  - "Pick a different program" is hidden in every mode while there's only one programme.
  - The router changes cover C01, O03, O05, C07, C09b, C12, C13, C14 and C15. C13 is now the root of the stack. The community pledge (C16) still opens from C13 when the community flag is on.
  - The doctor-first card on R03 shows only for pregnant and postpartum answers, using the plan's copy, which still needs your review.

**Block C (Home and day-two hook)**
- **C1–C6, done.** One change on R10: it says "Next: session {n}, on any day this week" instead of "Next: day 2", because a fixed "day 2" would be wrong from the second session on.
- **C6:** events go nowhere in a release build and print to the console in debug. The cycle screens send nothing.

**Also MUST, from sections 3 and 5:** C14 now shows "Your week is saved" with her week, and C08 no longer says "You can change this later in your profile".

**Not built:** everything in the plan's LATER list, plus moving K02–K05's back button to `maybePop`, which the plan says only "could be MUST".

## Files
- **New:** `app/lib/features/signup/domain/digits.dart`, `app/lib/app_state/open_app_settings.dart`, `app/lib/app_state/debug_analytics_sink.dart`, `app/lib/features/onboarding/presentation/her_answers.dart`
- **Router:** `app/lib/routing/app_router.dart`
- **State, persistence and launch:**
  - `app/lib/app_state/onboarding_state.dart`
  - `app_snapshot.dart` (saves the "Not now" on the cycle row)
  - `account_data.dart` (clears it when she deletes her data)
  - `app/lib/main.dart`
- **Screens:** the signup views (welcome, language, phone number, code, role, why-we-check, consent, ID capture, selfie capture, the capture scaffold, checking, you're in, being checked); the onboarding views (step scaffold, schedule, life stage, starting programme); `today_view.dart`; `finished_view.dart`; `workout_day_view.dart`; `app/lib/ui/app_step_progress.dart`; `MainActivity.kt`
- **Strings:** 40 new, added with `tool/add_strings.py` (ARB files regenerated, never hand-edited). The two Arabic button fixes are in `6-v2/i18n/msa/05.json`.

## Tests
- **New files:** `test/journeys/value_first_signup_test.dart`, `test/journeys/day_one_home_test.dart`, `test/features/signup/liveness_offline_test.dart`, `test/ui/signup_phase_label_test.dart`
- **New cases in existing files:** checking (no button, 20-second line, back blocked), phone number (Arabic digits, `+20` on the left in Arabic, one test per failure), code (each failure, busy state, edit number), capture views (every camera failure for card and selfie, retry after Settings, offline hand-off), consent (promise above the five unchanged disclosures, record still written first), welcome (language chips), you're in, being checked, schedule, starting programme, R03 doctor card, onboarding due.
- **Updated because they encoded the old flow:** the old step labels and "Get started", the hidden "Pick a different program", the removed C09 and C08 lines, Skip now drawn only when it leads somewhere, explicit flags in my new tests (`flag_independence_test` requires this), and two QA graph tests: C09b added as a "chooses again" stop next to C09, and O05 → C06 listed as an edge that only exists after a sign-up step.
- **Still green:** `verification_gate_test`, `fresh_claim_is_truth_test`, `offline_verification_launch_test`, `exits_and_already_verified_test`, `signup_consent_test`, `review_consent_before_call_test`, `nav_reachability_test`, `routing_test`, `i18n_guard_test`, `release_readiness_test`, the cycle no-analytics guard, `onboarding_journey_test`.

## Other issues I noticed
1. The R1-12a test fails every Tuesday because it compares against the real date.
2. When the gate sends someone back to C09, the next screen (C09b) repeats C09's promise. The same happens on the coach path (C08 → C09 → C09b) when the coach app is on.
3. The server's `request_review` has no guard against an automatic check still in progress, so the two could race on her verification state.
4. Offline retries at the liveness start aren't counted as events yet.
5. `IntakeStepScaffold.totalSteps` is still 4 for the full walk opened from her profile, where O05 is effectively a fifth screen.