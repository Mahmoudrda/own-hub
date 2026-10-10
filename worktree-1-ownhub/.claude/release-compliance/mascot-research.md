# Own Hub mascot: where it helps, how it behaves, how to build it

I edited nothing. Everything below comes from reading the worktree at `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app`, the repo docs (`/Users/mahmoudreda/ownhub/BUILD-BRIEF.md`, `DECISIONS.md`, `6-v2/flutter/HANDOFF.md`), the local Flutter SDK (3.47.4 stable) and the web sources cited at the end.

## 0. Codebase facts that shape the mascot

- **Motion is almost absent, and that is deliberate.** Only one file in `lib/` creates an `AnimationController`: `lib/ui/hand/draw_on.dart` (`DrawOn` and `HandPressable`). All motion is one-shot and short: `HandMotion.draw` is 420 ms and `settle` is 260 ms (`lib/theme/hand_tokens.dart`). The comment there says marks should be "short, so it reads as a hand, not a loader".
- **How the pumpAndSettle constraint is handled now:**
  1. No spinners. Busy states are named in words: C12 "names each step instead of showing a bare spinner" (`test/features/signup/checking_view_test.dart:53`), and C07 shows "Checking your code". Several tests assert `CircularProgressIndicator` finds nothing.
  2. The only live clocks, R09 `resting_view.dart:28-33` and G07 `rest_between_sets_view.dart:23-27`, take an `autoStart` flag. Layout tests pass false. Countdown tests drive the clock with explicit `pump(duration)` calls, because "a live one-second tick never lets `pumpAndSettle` settle".
  3. `DrawOn` builds its delay into the controller instead of using a `Timer`, because "a timer still pending when a widget test ends fails that test" (`draw_on.dart:44-46`).
  4. The one exception is `coach/presentation/certificate_camera_view.dart:163`, a `CircularProgressIndicator`. Its test avoids `pumpAndSettle` there (`coach_onboarding_test.dart:382`).
  5. There is no `test/flutter_test_config.dart`, so tests run with animations on. Only `test/qa/round1/r1_64_containment_test.dart` sets `disableAnimations`.
  - **Design consequence:** the mascot has no infinite loops at all. Every movement is a bounded one-shot of 1.2 s or less, so `pumpAndSettle` settles on its own, with no test-mode switch and no `autoStart` workaround.
- **Bug found (affects the mascot and the existing hand layer):** `handMotionOff()` (`draw_on.dart:12-15`) reads only `disableAnimations || accessibleNavigation`. In this Flutter version, `MediaQueryData.disableAnimations` reflects Android's "Remove animations" only. The SDK docs say: "On iOS, reduced motion is exposed separately via `dart:ui.AccessibilityFeatures.reduceMotion` and does not set this flag" (`flutter/lib/src/widgets/media_query.dart:663-669`). So today the draw-on marks ignore iOS Reduce Motion. The fix is to also read `View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion`.
- **Rules a mascot could break:**
  - BUILD-BRIEF §2: weeks not days, no streak, undo not confirmation.
  - HANDOFF rule 17: "no tour, no overlay and no tutorial mode". The C04 tour is now the one sanctioned exception, drawn as an inline coach card and not a spotlight (`demo_chrome.dart:107-110`).
  - D27: every screen already carries one or two of the owner's illustrations; the sensitive screens stay calm; never the same picture twice.
  - Amber is caution, red is reserved (`being_checked_view.dart`). Sage means "done, not won" (`HandInk.done`).
  - R10 is "the one celebration", and confetti lives nowhere else (`finished_view.dart:4`).
  - D31: health data stays on the phone.
- **The figure rule (`lib/ui/hand/art_marks.dart:66-79`).** Every drawn woman has "a plain circle for a head: no face, no hair, no covering" and a single flat colour, because whether hair is covered "is hers to decide". **So the mascot must not be a woman.** A face on a woman would break this rule and would also read as Rahma.
- **Identities already in the product:** Rahma (real coach, voice of programmes, recipes and the E11 letter) and "Sara", the human coach the assistant hands off to ("Ask Sara instead", `ask_view.dart`). The mascot must look like neither, and must not look like the assistant.

**Proposed character (internal code name only, never shown):** an ink drop, the dot of the reader's pen and the dot every Arabic letter carries. It is drawn in the existing hand layer's rose ink (`HandInk.ink`) with `inkPath` and `handSeed`. It has two dot eyes, a one-stroke mouth and two single nib strokes for arms, and it sits on the pencil baseline (`handMarkBaseline`). It has no gender, hair, skin, clothes or lettering. It belongs to the Annotated Edition idea that "only the hand arrives": it is a doodle in the margin, not a co-host. It has no name on screen.

## 1. Placement map

Sizes are logical points. The ceiling is 72, always smaller than the owner's 92 pt art strip on the same screen. "Animates" always means one-shot, bounded and skipped under reduced motion.

| Screen / moment | Mascot does | Why it helps | Size | Animates |
|---|---|---|---|---|
| **C01 Welcome** | **wave**, once, beside "Show me around" (لخذيني في جولة is not used; the existing key `showMeAround` reads "خذيني في جولة") | A warm first second before any ask. It points at the low-commitment path (pull, not push: NN/g). | 56 | Yes, ~900 ms, **once per install** (local flag) |
| **C04 tour, `DemoCoachCard`** | Sits at the card's start edge. **point** toward the real screen below on Home, Workout day, Player, Recipes, Week plan and Progress. **Absent on the Cycle stop.** | Gives the card a guide without an overlay; the screen under it "stays hers to tap". | 40 | One point gesture on each stop change (`replayKey` = stop) |
| **C04 end card** ("That is Own Hub") | **cheer** (small), beside the `HandUnderline` heading | Closes the tour. | 56 | Once per tour run |
| C05 join sheet | None | A decision sheet. Cuteness here is a nudge. | n/a | n/a |
| C06 phone | None | Structural form screen (HandLevel.structural: "forms stay exact"). | n/a | n/a |
| **C07 code, busy state only** | **think**, static, beside "Checking your code" | Gives the wait a face without a spinner. | 32 | No (static frame) |
| C08 role, C09 why we check | None | C09 is "the riskiest screen in the product". A cartoon beside a request for a national ID reads as making light of it. | n/a | n/a |
| **C09b consent** (optional, default off in v1) | **comfort** (hand on chest, a sincere-promise gesture in Egypt), static, beside the "deleted when the check finishes" line only, never near the agree button | Reassurance on deletion. Placing it near consent would be a persuasion pattern on a PDPL consent act. | 32 | **No** |
| **C10 / C10b / C11 cameras** | Never inside the viewfinder. On C11 only, in the instruction strip outside the frame, it can demonstrate the current `LivenessStep` (`faceCentre`, `turnLeft`, `turnRight`, `blink`) with its eyes. | A wordless demo of "look to your left" helps first-time and low-literacy users. The frame stays clear for ML Kit and for her. | 32 | One-shot per step change. **Directions follow her body/camera, never RTL mirroring.** |
| **C12 checking** | Pose follows each named step: **think** (reading card), **point** (matching), **cheer**-lite (done). Error states: none. | Turns each named step into a visible state. Honest progress, not a loader. | 56 | One-shot per step, no loop |
| **C13 You're in** | **cheer**, beside the greeting, after the heading lands | The payoff moment. | 72 | Yes, ≤1.2 s, once |
| **C14 waiting for a reviewer** | **wait**: settles and sits, eyes soft, sage tint | Calm waiting. Never "sleep" (implies ignored) and never sad (C14 "must never read as a rejection"). | 56 | Settle once (~600 ms), then still |
| C15 woman reviewer | None | A real woman is the reviewer; a cartoon undercuts the human promise. | n/a | n/a |
| C16 pledge | None | Rules about treating each other; serious tone. | n/a | n/a |
| O01–O05 intake | None | Forms. O04 life stage is sensitive. O05 is Rahma's programme. | n/a | n/a |
| **T01 in its day-one state (T06)** | **point** at the single first action (start the first session) | Rule 17 says the empty state is the onboarding; this marks the smallest action. | 40 | One point on first render; **gone after her first log** |
| T04 after a quiet week | Optional **wave** ("welcome back"), never sad or comforting | A sad mascot after a missed week is the Duolingo guilt pattern. T04 "has no failure state". | 40 | Once per Monday notice (already seen-once by ISO-week key) |
| T08 first week done | Small **cheer** holding a sage tick | Quiet completion. The confetti stays R10's. | 40 | Once |
| R07 mid-set, R09 resting, G07 | None | Training focus; the phone is often on the floor. R09 already schedules frames. | n/a | n/a |
| **R10 finished** | **cheer** in sage, beside the week circles, starting after `HandTick` (delay ≥600 ms) | Supports the one celebration. | 56 | Full cheer for the first 3 finished sessions and the session that completes the week. Otherwise **nod** (≤500 ms). |
| R13 move logged, E02–E04 meal log, G11 | None | Frequent actions: Apple HIG keeps animation minimal for repeated interactions. The undo bar owns this moment. | n/a | n/a |
| **Client day-one empty states** (E09, R11 library empty, M17 when community ships) | **point** toward the empty-state action, replacing nothing (the art stays) | Rule 17. Gives the first action a hand. | 32 | One-shot, first view only |
| Coach, payout, admin empty states (K24, W11, B14, Z*) | None | `AppEmptyState` itself says decoration on "no earnings yet" is "decoration pretending to be meaning". | n/a | n/a |
| Errors, offline, "Nothing was decided" | None | Errors must be read. A character beside them trivialises the message, and these states are explicit, not loaders. | n/a | n/a |
| **Account deletion** (`your_data_sheet.dart`) | **Never** | A sad mascot at deletion is confirmshaming. The sheet explains and acts in one step. | n/a | n/a |
| **Cycle Y01–Y14** (and the tour's Cycle stop) | **Never** | Health data privacy (D31; the Flo FTC case is why women distrust cycle apps). Y11 severe symptoms are medical. A character reacting to her symptoms is an emotional judgement on health data. | n/a | n/a |
| Progress P01–P04 | None (P04 especially) | Body data, rule 11 (nothing ranked by weight). | n/a | n/a |
| Rahma content (E05/E06/E11, O05, recipes) | **Never** | Her voice and her work. A mascot there would appear to speak for her. | n/a | n/a |
| Community, coaching H*, chat, G13/G14 | None | Real women talk there. | n/a | n/a |
| Assistant X01–X03 | **Never** | It must not become the assistant's face (NN/g anthropomorphism risks: misplaced trust, assumed memory). | n/a | n/a |
| Push notifications, home widget, lock screen T03 | **Never** | This is how Duo's guilt reaches people. | n/a | n/a |

## 2. Behaviour rules

1. **It never speaks.** No speech bubbles and no first-person lines. All copy stays in the app's plain voice, in the ARB (the i18n guard already forbids Arabic literals in `lib/`). The mascot is decorative: wrapped in `ExcludeSemantics`, no label, no tap (the hand-layer rule: "a mark is decoration… takes no tap, and is not read out").
2. **Tone:** calm, kind, a little wry. Emotional range is idle, glad and attentive only. Never sad, disappointed, pleading, sleepy or angry. Colour is rose ink, with sage for done and comfort. Never amber, never red.
3. **Rahma:** the mascot is a drawing on the page, not a person. It never appears on her content, beside her name or photo, or in her programmes. It never quotes her, and it never stands in for Sara or the assistant.
4. **Frequency caps:**
   - At most one mascot per screen.
   - At most one animated appearance per app session after sign-up.
   - Per-moment caps as in the table: C01 once per install; tour once per stop per run; T06 until the first log; R10 full cheer three times plus week-complete, otherwise a nod; T04 once per ISO week.
   - Counters live in the existing local snapshot (`shared_preferences`, one JSON document) and are never synced.
5. **Dismissal:** it never blocks, overlays or interrupts, so there is nothing to close. A switch in A02 Profile and settings turns it off everywhere, and it is off automatically under reduced motion except as a static frame. Proposed strings:
   - EN "Show the ink drawing" / AR "إظهار رسمة الحبر"
   - Sub-line EN "It appears on a few screens and never says anything." / AR "تظهر في شاشات قليلة ولا تقول شيئًا."
6. **RTL:** mirror the pose geometry under `TextDirection.rtl`, the way `ArrowPainter` and `HandNote` tilt already do, so "point forward" points left in Arabic and the wave uses the leading arm. **Exception:** physical demonstrations (C11 `turnLeft`/`turnRight`) follow her body as seen in the front camera and are never flipped by text direction. The mascot has no lettering, so nothing needs translating.
7. **Copy examples next to mascot moments.** These are app voice, feminine address as in the existing ARB, no em dashes:
   - C14: EN "Your check is with a woman from Own Hub. You can close the app, we will tell you when it opens." / AR "طلبكِ لدى سيدة من Own Hub. يمكنكِ إغلاق التطبيق، وسنخبركِ عندما يُفتح لكِ."
   - T06: EN "Start here. Your first session is short." / AR "ابدئي من هنا. جلستكِ الأولى قصيرة."
   - C09b: EN "Both photos are deleted when the check finishes." / AR "تُحذف الصورتان فور انتهاء التحقق."
   - T04: EN "Welcome back. Your weeks are safe." / AR "أهلًا بعودتكِ. أسابيعكِ محفوظة."

## 3. Animation technology

| | Rive | Lottie | Pure Flutter (CustomPainter + one AnimationController) |
|---|---|---|---|
| Binary | Native `rive_native` libraries per ABI. One earlier upgrade alone added ~1.8 MB per arm64 APK (librive_text.so). Measure with `--analyze-size`. | Pure Dart. Adds AOT code (estimate: a few hundred KB) plus 10–100 KB of JSON per animation. | ~15–25 KB of Dart (estimate), **0 assets** |
| Runtime | GPU renderer, cheap per frame. Needs `RiveNative.init()` at startup; Impeller caveats noted in the package docs. | Parses JSON layers and redraws per frame. Has `renderCache` for energy at the cost of memory. | Paths precomputed once per pose; per frame only a few transforms. Repaint-only, no rebuild. |
| Authoring | The Rive editor only. A `.riv` file cannot be generated by us. **Disqualifying: we have no operator.** | After Effects/Bodymovin, or hand-written JSON (possible but painful) | In code, using the existing `inkPath`, `handSeed`, `HandInk`, `HandMotion` |
| Style fit | A new visual language | A new visual language, no seeded wobble | Identical ink to every other mark |
| Offline | Bundled, fine | Bundled, fine | Fine |
| Tests | Drives frames itself; needs care | `repeat` defaults to true, so it loops and hangs `pumpAndSettle` unless you pass your own controller | One-shot controller; settles; goldens are deterministic (seeded) |
| Reduce motion / RTL | Manual / Transform | Manual / Transform | Set `value = 1`; `Directionality`-aware painters already exist |

**Recommendation: pure Flutter.** Implementation rules:

1. Files: `lib/ui/hand/mascot/` containing `MascotPose` (enum), `Mascot` (StatefulWidget with `SingleTickerProviderStateMixin`) and `MascotPainter extends CustomPainter` with `super(repaint: animation)`. Passing `repaint:` means each frame is a repaint with no rebuild.
2. **One controller per mascot.** A pose change runs `controller.forward(from: 0)` and lerps the previous pose's parameters to the target with `HandMotion.pen`. Durations: point/wave ≤900 ms, cheer ≤1200 ms, nod ≤500 ms, settle 600 ms.
3. **No `repeat()`, no `Timer`, no periodic blink.** A blink is folded into the arrival at t≈0.7. A source guard in the style of `product_rules_test.dart` fails on `.repeat(`, `Timer(` or `Ticker(` under `lib/ui/hand/mascot/`.
4. **Motion gate:** `mascotStill(context) = handMotionOff(context) || View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion || !TickerMode.valuesOf(context).enabled || setting off`. When still, set `controller.value = 1` (final pose drawn, nothing scheduled). Overlay already disables tickers for routes covered by another route (`overlay.dart:420`), and frames stop when the app is backgrounded, so a one-shot can never run off-screen for long.
5. `RepaintBoundary` around the `CustomPaint` so the host card does not repaint. No `Opacity` widget and no `saveLayer`: fade by paint alpha (Flutter performance guide). `shouldRepaint` compares pose, seed and direction only.
6. Cache the part `Path`s per (pose, size, direction, seed). Per frame, only apply `canvas.save/translate/rotate/scale` to about 6 parts.
7. Frame budget: mascot paint ≤0.5 ms on the UI thread and ≤1 ms raster on a low-end Android in profile mode. The whole frame must stay inside 16 ms at 60 Hz, or 8 ms at 120 Hz.
8. Tests:
   - pump, then `pumpAndSettle()`, then `expect(binding.hasScheduledFrame, false)`.
   - Same check with `FakeAccessibilityFeatures(disableAnimations: true)` and with `reduceMotion: true`: the first frame is already the final pose.
   - EN/AR goldens per pose.
   - A semantics test that the mascot adds no node.
   - A placement guard that it never builds under cycle (Y*), P04, account deletion, assistant or Rahma screen ids, via `ScreenScope`.

## 4. Pose set and moving parts

There are six parts and seven animated floats in total:
- Body: one closed `inkPath` drop. Animated by `squash` (scaleY about the baseline) and `tilt`.
- Eyes: two dots. Animated by `eyeOpen` (scaleY, for blinks) and `lookX`.
- Mouth: one stroke. Animated by `mouthCurve`.
- Arms: two tapered strokes. Animated by `armLead` and `armTrail` angles.
- Prop, used only for cheer and success: the existing `TickPainter`, in sage.

| Pose | Parameters | Where used |
|---|---|---|
| idle/rest | neutral; the final frame of every pose | everywhere it appears |
| wave | armLead swings ±25° twice, small tilt | C01, T04 |
| point | armLead extends toward the target (mirrored in RTL), lookX toward it | C04 stops, C12 matching, T06, empty states |
| cheer | squash then stretch, both arms up, sage tick drawn on | C13, R10, C04 end, T08 |
| nod | squash 0.95 then back | later R10s |
| think | lookX up/aside, mouth flat, armTrail to the "chin" | C07 busy, C12 reading |
| wait | settles lower, eyes half-soft, sage hatch beneath | C14 |
| comfort | armLead to chest, gentle smile, static | C09b (optional) |
| look-left / look-right / blink | eyes only; physical direction, not mirrored | C11 instruction strip |

## Sources

- Flutter performance best practices: https://docs.flutter.dev/perf/best-practices
- Measuring app size: https://docs.flutter.dev/perf/app-size
- MediaQueryData.disableAnimations: https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html
- TickerMode: https://api.flutter.dev/flutter/widgets/TickerMode-class.html
- `pumpAndSettle` (10-minute default timeout; source in `flutter_test/lib/src/widget_tester.dart:695` of the local SDK): https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html
- Rive package: https://pub.dev/packages/rive
- Rive Flutter runtime: https://rive.app/docs/runtimes/flutter/flutter
- Rive size issues: https://github.com/rive-app/rive-flutter/issues/367 and https://github.com/rive-app/rive-flutter/issues/274
- Lottie: https://pub.dev/packages/lottie
- flutter_svg (no animation support; vector_graphics precompile): https://pub.dev/packages/flutter_svg
- Apple HIG, Motion: https://developer.apple.com/design/human-interface-guidelines/motion
- Material 3 motion: https://m3.material.io/styles/motion/overview/how-it-works (the page did not render for me, so nothing above is quoted from it)
- NN/g: https://www.nngroup.com/articles/onboarding-tutorials/ , https://www.nngroup.com/articles/mobile-tutorials/ , https://www.nngroup.com/articles/mobile-instructional-overlay/ , https://www.nngroup.com/articles/anthropomorphism/
- Duolingo guilt design (the "5 to 8% more effective" re-engagement figure is attributed to Duolingo, via these secondary sources): https://medium.com/@Jason-Han/the-architecture-of-guilt-how-duolingo-weaponized-negative-emotion-to-build-a-design-system-a1ea491e7813 , https://chantellemarcelle.com/duolingo-growth-marketing-case-study/
- Finch, no-punishment design: https://slate.com/technology/2026/09/finch-app-self-care-wellness-review.html , https://koi-calm.app/blog/self-care-pet-apps
- Headspace characters and the Ebb breathing guide: https://raw.studio/blog/how-headspace-designs-for-mindfulness/ , https://blush.design/blog/post/headspace-mindfulness-app
- Flo FTC order: https://www.ftc.gov/news-events/news/press-releases/2021/06/ftc-finalizes-order-flo-health-fertility-tracking-app-shared-sensitive-health-data-facebook-google

**Two caveats.** The binary-size figures for Lottie and for the pure-Flutter mascot are estimates; measure both with `flutter build apk --analyze-size`. The Apple HIG page was summarised by a fetch tool, so check the wording before quoting it.