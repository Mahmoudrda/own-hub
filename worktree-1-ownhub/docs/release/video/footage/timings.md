# Own Hub — launch video footage

Screen recording of the real app being used on the iPhone 17 Pro Max simulator
(`04852D18-AA25-4FD6-996E-488DECDACA1C`), captured at **1320 × 2868**. Real
taps, real transitions, real animations — nothing is a mockup and nothing is
composited.

Shot against `e8b0059`, on a clean install: the setup questions, the day-one
Home, the four bodyweight floor moves of the first session, and the payoff line
naming her real day.

- `demo.mov` — the raw take, 148.09 s, h264, variable frame rate.
- `00-setup.mp4` … `09-home-again.mp4` — one clip per scene, cut from it at
  native resolution (1320 × 2868), no scaling and no re-framing, re-encoded to
  h264 at a constant 30 fps so frame numbers and seconds agree.

Every clip starts and ends on a settled screen. Nothing in them shows a failed
tap, an error banner or a frozen frame; each was sampled frame by frame to
check.

## This is the full product, not the shipping subset

The walk runs with `AppRouter.featureFlags = FeatureFlags.everything`, and that
is a deliberate decision rather than a test default: the film has a community
beat and a coaching beat, both features are built and tested and waiting only on
a backend, and a film cut to the first release's six features would lose the
product's identity. It makes this a **product film rather than a store
preview**.

So four things on camera are not in the first release, and that is intended:
the bottom bar carries a **Community** tab (clips 01, 05, 06, 08, 09), setup
question four says "Only you and your coach ever see this" (clip 00), day-one
Home carries a "Beginners group" row (clip 01), and the finished screen offers
"Share the squat with your group" (clip 04). Privacy's four switches (clip 08)
are the same: with the shipping six features that screen has no switches at
all, because every one of them answers "who else sees this".

## How the app was driven

`app/integration_test/demo_drive_test.dart` walks the app with real pointer
events. It changes no production code.

Three things in it are worth knowing before re-recording:

1. Gestures are dispatched as **device** pointer events, not through
   `tester.tap`. The live test binding paints a large blue crosshair over every
   `TestBindingEventSource.test` pointer, and it lands on the button being
   pressed, in shot.
2. The take is captured with the walk **built as the app's own entry point**
   and launched by `simctl`, not through `flutter test`. With a `flutter test`
   session attached the app is force-quit part way through whenever the screen
   is being recorded. The same file still runs under
   `flutter test integration_test/demo_drive_test.dart -d <udid>`.
3. `--dart-define=OWNHUB_LOCALE=en`, because launched by hand the app follows
   the simulator's language and this device is set to Arabic.

The status bar is overridden for a clean look, and the time in it is set to the
minute the take starts rather than to Apple's 9:41: `status_bar override`
**freezes** the bar, the app prints its own clock on Home, and 9:41 above a
meal row reading "5:20 PM" is one frame contradicting itself. As shot the two
agree to the minute.

## The clips

Tap offsets are **seconds from that clip's own first frame**, measured from the
video itself: each is the first frame on which the pressed control moves. They
are good to about ±0.05 s. `x, y` is where the finger lands, in **pixels** of
the 1320 × 2868 frame.

### 00-setup.mp4 — 8.43 s

A clean install asks her, which it never used to. Question three — "How much
time do you really have?", the one whose subtitle says it becomes her weekly
goal — four days a week and thirty minutes a session. Then question four, what
the programme has to train around. Then her four answers read back: "Days a
week: 4 · Minutes a session: 30 · At a ladies-only gym", over a programme that
promises four moves on the floor.

Paced faster than the rest of the film on purpose: it is an opening montage.

| at | tap | x, y |
|---|---|---|
| **0.79** | Days a week · "4" | 816, 1272 |
| **1.96** | Minutes a session · "30" | 1128, 1524 |
| **3.27** | "Continue" | 660, 2478 |
| **4.72** | "A knee, back or shoulder" | 366, 1920 |
| **6.04** | "Continue" | 660, 2478 |

### 01-home.mp4 — 5.07 s

Home on day one: "Your training, week by week", nothing logged, nothing
invented, and the weekly rule stated without a number because she set the
number a moment ago. She starts, and the day opens — fifteen minutes, four
moves, quiet, no equipment, floor.

| at | tap | x, y |
|---|---|---|
| **2.50** | "Start day 1" | 702, 1020 |

### 02-session.mp4 — 5.07 s

The day's session: glute bridge, step-back lunge, hip thrust hold, dead bug.
She starts it and lands mid-set on move one of four.

| at | tap | x, y |
|---|---|---|
| **2.51** | "Start, everything's ready" | 702, 2478 |

### 03-mid-set.mp4 — 5.57 s

Mid-set. "3 × 12 · bodyweight" set large, and under it the truth rather than a
borrowed history: "No history for this move yet. What you log today is what the
next one is measured against." One tap logs the set and the rest clock starts
itself, counting down from 0:38 with "Set 1 saved · 12 reps · Undo" above it.

| at | tap | x, y |
|---|---|---|
| **2.56** | "Done · 12 reps" | 660, 2403 |

### 04-finish.mp4 — 12.27 s

Finishing. Back from the rest clock to the next set, then the whole move logged
at once — the list returns with it struck off — then finish, landing on **"That's
Thursday done"**: her day, the week ring at 1 of 4 with the next circle drawn in
rose, +30 points, a personal best. The last four seconds hold that line.

| at | tap | x, y |
|---|---|---|
| **1.87** | "I'm ready, next set" | 660, 2478 |
| **4.95** | "I did all 3 sets, log them" | 660, 2655 |
| **8.12** | "Finish here" | 660, 2655 |

### 05-tabs.mp4 — 5.07 s

The bottom bar. Home — now reading "This week, 1 of 4", her own answer — to
Eat: the tab marker, the icon and the pen line under the name all move
together.

| at | tap | x, y |
|---|---|---|
| **2.32** | "Eat" in the bottom bar | 1146, 2730 |

### 06-eat.mp4 — 9.57 s

Eat, with nothing logged yet. One tap on "Log" beside the koshari bowl writes
it: the day card fills in — the slot she is actually in ticked, protein 18 of
95 g, about 540 kcal — plus +5 points and one undo bar. The section under it is
headed for the same hour, "Dinner, your usual", and claims no habit beside it.
The clip holds through the whole five-second window; at **7.43** the bar loses
its Undo, on its own, with no confirm anywhere.

| at | tap | x, y |
|---|---|---|
| **2.28** | "Log" (koshari bowl) | 978, 1245 |

### 07-cycle.mp4 — 13.87 s

My cycle, the daily check-in. Three chips — low energy, moderate cramps, less
hungry — then Save. The hub comes back carrying "A gentler option today",
labelled "App suggestion", with what she logged spelled out under it and both
answers offered: View option, or Keep mine.

| at | tap | x, y |
|---|---|---|
| **2.06** | Energy · "Low" | 243, 1074 |
| **4.46** | Cramps · "Moderate" | 816, 1338 |
| **6.84** | Appetite · "Less hungry" | 243, 1602 |
| **9.44** | "Save check-in" | 660, 2478 |

### 08-privacy.mp4 — 5.37 s

Privacy. "Show my personal bests" is switched on: the switch is seen moving,
grey to rose, knob crossing.

| at | tap | x, y |
|---|---|---|
| **2.36** | "Show my personal bests" switch | 1188, 1428 |

### 09-home-again.mp4 — 6.77 s

Straight off Privacy to Home, and rest.

| at | tap | x, y |
|---|---|---|
| **2.35** | "Home" in the bottom bar | 210, 2688 |

## Where each clip sits in `demo.mov`

For re-cutting, or cutting differently.

| clip | in | out |
|---|---|---|
| 00-setup | 17.28 | 25.72 |
| 01-home | 31.92 | 37.02 |
| 02-session | 39.12 | 44.22 |
| 03-mid-set | 46.52 | 52.12 |
| 04-finish | 54.10 | 66.40 |
| 05-tabs | 74.87 | 79.97 |
| 06-eat | 82.17 | 91.75 |
| 07-cycle | 109.12 | 123.01 |
| 08-privacy | 133.02 | 138.42 |
| 09-home-again | 140.12 | 146.92 |

The driver prints a `DEMOMARK|<ms>|…` timeline as it walks. For this take,
**video seconds = driver milliseconds ÷ 1000 + 5.39**, calibrated on 24 presses
spread across the walk and accurate to ±0.03 s end to end.

The gaps between clips are getting places: leaving setup, coming off the
celebration, setting My cycle up, and the two screens opened by name rather
than by tapping (`Y03`, because on a fresh install Home has no cycle row until
she has set it up, and `A02`).
