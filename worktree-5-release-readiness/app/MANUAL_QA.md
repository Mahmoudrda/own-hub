# MANUAL_QA — ID capture, selfie and consent

Everything in the identity check that a unit test on a laptop cannot reach.
The automated side lives in `test/features/signup/` and covers the JPEG budget,
the frame measurements, the evidence shredding, the state machine and the
screens. What follows needs a hand, a card and four handsets.

Run every row in **both locales**. Arabic is not a translation pass here: the
capture screens are laid out RTL, the guidance pill flips, and the permission
sheet comes from a different file.

## Devices

| Ref | Device | Why this one |
| --- | --- | --- |
| A1 | Low-end Android, 2GB RAM, Android 10, e.g. Redmi 9A / Galaxy A04 | The frame loop and ML Kit share one weak CPU. This is where the preview stutters or the analysis falls behind. |
| A2 | Mid-range Android, Android 13 or 14, e.g. Redmi Note 12 | The phone most Egyptian women in this product actually hold. |
| I1 | Oldest supported iPhone and iOS version | BGRA path, oldest Metal preview, oldest camera stack. |
| I2 | Current iPhone | The path everyone demos on, so the one least likely to be broken and most likely to hide a bug on A1. |

## Before anything

1. Put a real Egyptian national ID card in front of you. Not a photocopy and
   not a picture on a screen: the lamination is the point of half these tests.
2. Build in release (`flutter run --release`). The debug build prints the frame
   budget and the liveness outcome to the console and runs the analysis loop
   slower; neither is what she gets.

---

## 1. Consent, before any camera

| # | Step | Expected |
| --- | --- | --- |
| 1.1 | Reach C09b from C09. | "Before the camera opens" with four bullets. No camera permission prompt has appeared yet. |
| 1.2 | Read every bullet in Arabic (RTL). | Google Cloud is named and nothing else is. "outside Egypt" is present. The one way keyed hash sentence is present. "Nothing you photograph is kept" is present, and so is the short video call. Amazon Web Services and any retention window must NOT appear: consent to something that is not happening has to be withdrawn and taken again. Nothing is clipped at the screen edge. |
| 1.3 | Set the system font to the largest size and reopen. | Nothing is clipped; the screen scrolls. A clipped disclosure is a disclosure that was not made. |
| 1.4 | Tap "I agree, start the camera". | The consent record is written, THEN C10 opens. Check Firestore: `users/{uid}/consents/{kCaptureConsentVersion}` exists with a server timestamp. |
| 1.5 | Turn on airplane mode, then tap "I agree, start the camera". | She stays on C09b. The camera does NOT open. The button becomes tappable again. No consent record is written. |
| 1.6 | Tap "I would rather not". | C15, the woman reviewer path. No camera permission prompt at any point. |
| 1.7 | Kill the app after 1.4 and relaunch into the flow. | The recorded consent is found and she is not asked again for the same version. |
| 1.8 | Change `kCaptureConsentVersion` in a scratch build and relaunch. | She is asked again. A consent record against superseded wording must not count. |

## 2. Camera permission

| # | Step | Expected |
| --- | --- | --- |
| 2.1 | First run, tap agree on C09b. | iOS sheet reads the `NSCameraUsageDescription` sentence: it names both sides of the card, one selfie, and that the photographs are deleted. In Arabic it reads the `ar.lproj` string, not English. **This is the one to check first on iOS: if `ar.lproj/InfoPlist.strings` is not in the Xcode target the sheet silently falls back to English and nothing else fails.** |
| 2.2 | Deny the permission. | C10 shows the unavailable state and does not spin. The shutter is disabled. There is a way out to the woman reviewer. |
| 2.3 | Go to system settings, grant the camera, return to the app. | The camera opens. She does not have to restart the app or begin the sign-up again. |
| 2.4 | Anywhere in the flow, watch for a photo library prompt. | There is never one. If a library prompt appears, something added a picker and it must be removed. |
| 2.5 | Android: check the app's permission list in system settings. | Camera only. No storage, no photos and videos. |

## 3. Card capture, front and back

| # | Step | Expected |
| --- | --- | --- |
| 3.1 | Hold the card flat and steady in the guide, in normal indoor light. | It photographs itself within about a second. Time it: if it takes more than 3 seconds on A2, `CardFrameGate.minSharpness` is too high. |
| 3.2 | Same, on A1. | Same behaviour. Watch the preview for stutter. If the preview drops frames while measuring, raise `_analysisInterval`. |
| 3.3 | Move the card while framed. | "Hold the card still". It does not fire. |
| 3.4 | Take the card out of the frame and point at a table. | "Move a little closer". It does not fire on an empty guide. |
| 3.5 | Stand under a ceiling light so it reflects off the lamination. | "Tilt the card to cut the glare". **Most likely threshold to be wrong. If it never appears, lower `CardFrameGate.maxGlare`; if it appears on a correctly lit card, raise it.** |
| 3.6 | A dim room, roughly one lamp. | "There is not enough light" and not "hold the card still". Light must be reported before blur. |
| 3.7 | Hold the BACK of the card up on the front pass. | "Show the front of the card". This is ML Kit finding no printed face. |
| 3.8 | Put your own face in shot beside the card on the front pass. | "Only one face in the frame". |
| 3.9 | Tap "Take it myself" while the frame is blurry. | It captures anyway. Her override is deliberate: she can see the card and we can only see a number. |
| 3.10 | Complete the front, then the back. | The back pass says "Turn the card over" and "back of the card", and opens the rear camera again. |
| 3.11 | Tilt the phone to landscape during capture. | The captured frame is still upright. The capture orientation is locked to portrait. |
| 3.12 | Debug build, watch the console after each capture. | No "capture out of budget" line. If it appears, the device ignored `ResolutionPreset.high` and `frameByteCeiling` needs revisiting for that handset. |

## 4. The liveness challenge

The sequence comes from `start_verification` and is different every time. Run
this section at least four times so you see several orders.

| # | Step | Expected |
| --- | --- | --- |
| 4.1 | Open C11. | The headline reads "Step 1 of N" with N from the server, and the prompt pill shows that step's sentence. The Done button is visibly disabled and stays disabled for the whole challenge: the shutter is not hers while the server is asking. |
| 4.2 | Follow each prompt. | One frame per step, taken about 1.2 seconds after the prompt appears. The counter advances. At the end it moves to C12 on its own. |
| 4.3 | Count the prompts against the frames. | Exactly one frame per step. The server matches frame n against step n, so a mismatch fails the whole check with nothing on screen to explain it. Check the debug console for one capture line per step. |
| 4.4 | During a `blink` step, close your eyes and hold. | The prompt does NOT change to a framing correction. An earlier build nagged "hold still" on closed eyes, which made the blink step impossible to complete. |
| 4.5 | Move out of frame mid-challenge, then come back. | The framing correction replaces the prompt, the counter stays on the same step, and the dwell restarts when you are back. No step is skipped and no step is failed. |
| 4.6 | Have a second person stand behind you. | "Only one face in the frame". No frame is taken while it shows. |
| 4.7 | Hold the phone far away, then very close. | "Move a little closer", then "Move back a little". |
| 4.8 | **Front camera direction check.** Watch whether the guidance reacts at all to your face on each device. | If the front camera reports NO face on a device where the rear camera works, the ML Kit rotation compensation for the front lens is wrong. See `_rotation()` in `camera_capture_service.dart`: the front lens ADDS the device rotation and the rear lens subtracts it, and that asymmetry is the first thing to check. |
| 4.9 | Start the challenge, then wait past `expiresInSec` before finishing. | She reaches C12 and is sent back to retake rather than being told she failed. Nothing is submitted against a dead session. |
| 4.10 | Both locales, every prompt. | Each of the four prompts appears in Arabic as MSA, right to left, and never in English on an Arabic build. |

## 5. Interruptions

| # | Step | Expected |
| --- | --- | --- |
| 5.1 | Airplane mode ON before the challenge finishes, then let it complete. | C12 runs, the call fails, she lands on C14. The copy says a short video call is coming and that nothing she photographed was kept. She is never told she failed. Nothing needs to have reached the server, because review is a conversation and not a queue. |
| 5.2 | Turn airplane mode on mid-call (between Done and the outcome). | Same as 5.1. No crash, no spinner that never resolves. |
| 5.3 | Background the app during card capture and return. | The camera resumes or the screen reopens it. No black preview. No crash. |
| 5.4 | Force kill the app during C11 and relaunch. | No frames survive. Nothing is in the cache directory (see 6.1). She restarts the capture. |
| 5.5 | Receive a phone call during card capture. | The camera releases and recovers. |
| 5.6 | Press the close X on C10 mid-capture. | The camera is released. Check with the OS camera indicator: no green or orange dot remains. |

## 6. Rule 7, by hand

| # | Step | Expected |
| --- | --- | --- |
| 6.1 | Android: after a full capture, `adb shell run-as <pkg> ls -R cache files`. | No JPEG anywhere. `takePicture()` writes one temporary file per shot and `_readAndDelete` removes it in a `finally`; this is the check that it really does on that device. |
| 6.2 | iOS: inspect the app container after a full capture. | Same. No JPEG in tmp or Documents. |
| 6.3 | Open the device gallery after a full capture. | Nothing new. The app never saves. |
| 6.4 | After the outcome screen, check the app container again. | Still nothing. |
| 6.5 | Take a check all the way to C14. | Nothing of hers exists anywhere: no local file, and nothing in a review queue. The bundle is deleted server side for every outcome, so a woman reviewer never sees a photograph. Any UI that implies otherwise is a bug. |

## 7. Localisation and layout

| # | Step | Expected |
| --- | --- | --- |
| 7.1 | Every screen in this flow, in Arabic. | RTL layout. Guidance pill, buttons and close X on the correct side. No Latin text except the two processor names. |
| 7.2 | Every screen, largest system text size, both locales. | No overflow, no clipped sentence. |
| 7.3 | Every guidance string, both locales. | Each one appears at least once across sections 3 and 4, and reads as an instruction rather than a verdict. |

---

## Not verifiable here, and why

These are the things this worktree could not settle. Each is a specific check,
not a worry.

1. **Both callables and the region are now confirmed** with the backend worker:
   `start_verification`, `verify_identity`, `record_consent`, all in
   `europe-west3`. What is still unexercised is the round trip itself. The first
   real call is the test.
2. **Every threshold in `CardFrameGate`.** Chosen from what the metrics mean,
   not from a corpus of Egyptian ID cards photographed on Egyptian phones.
   Sections 3.1, 3.5 and 3.6 are the calibration pass.
3. **The step dwell.** 1.2 seconds is a guess at how long a woman needs to read
   a prompt in her second script and act on it. Too short and every frame
   catches her mid-move and the server rejects the challenge; too long and the
   session expires. Section 4.2 is where it gets set.
4. **The ML Kit front camera rotation.** Test 4.8. Cannot be checked without a
   handset.
5. **`refreshToken`.** An approval refreshes the ID token before C13 says
   "You're in". Since the gate is the whole app, a refresh that silently fails
   means a verified woman who cannot open anything until Firebase refreshes on
   its own within the hour. Verify on a real approval: C13, then the app, with
   no restart.
6. **The whole-app gate itself is not wired.** `lib/routing/app_router.dart`
   belongs to another worker. C14 no longer offers workouts, recipes or coach
   profiles, but nothing yet stops an unverified account reaching them by
   another route.
