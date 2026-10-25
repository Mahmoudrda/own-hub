# Own Hub emotional redesign: implementation guide for the coding agent

Written 26 Oct 2026 for the release after 1.1.0. Owner brief: push the app further toward emotional design, on top of the simplification already built (one screen, one purpose). No screen was changed while writing this guide.

Read first: `docs/plan/RELEASE-2-PLAN.md` (sections 2 and 3), `docs/plan/FREE-LAUNCH-COACHING-PLAN.md` sections 15 and 16, and `.claude/CLAUDE.md` owner rules. This guide does not repeat what they decide. It adds the feeling layer.

## 1. What this is, and what must not change

**Goal.** A woman opens Own Hub and feels calm, capable and looked after, and is a little delighted at the right moments. She never feels judged, rushed or watched. Emotion comes from reliability and clarity first, then from motion, touch, colour, words and small rewards on top.

**Fixed points the owner loves. Do not redesign them:**
1. The workout video player and the way workouts play (R07 set screen clip, R09 rest, clip frame, playback rules in `videos-inside-the-app`). Only wrap them in the same shell, tokens and transitions as the rest.
2. The Events area (T09 list, event detail, Reserve). Keep its structure and cards. It may take the shared tokens and motion, nothing structural.

**Constraints that stay (owner rules and earlier decisions):**
- The simplification budgets hold: at most one filled primary per screen state, at most 5 other controls above the fold (shared top bar and tab bar excluded), at most 4 hero figures. `app/test/qa/screen_budget_test.dart`, `app/test/qa/one_primary_action_test.dart` and the small-screen and large-text sweeps must stay green. Emotional additions never add a control.
- The kitten is removed from the app (owner, 25 Oct). Do not bring a mascot or character back. Delight comes from drawn marks, motion, colour and words. The shared mark is `app/lib/ui/hand/moment.dart`.
- Palette: Linen `#FCF8F2`, Petrol `#1A5D74`, Pale Pink `#F4BEBB`; pink leads, petrol is the hint (DECISIONS D49). Tokens in `6-v2/src/tokens.mjs` and `app/lib/theme/app_tokens.dart`.
- No guilt, no loss words near streaks ("lose", "break", "miss", "at risk"), nothing decided by chance, nothing ranks women, competition only with her own past (D37 to D41).
- Egyptian Arabic and English as equals, feminine address, Western digits, no em dashes in product copy. Strings go through `app/tool/add_strings.py`. Right-to-left is first class.
- Never weaken women-only verification or legal consent records. Brand voice and face is Rahma Mohsen; publisher is Mahmoud Reda; never mix the two.
- No AI comments or planning markdown in code; no AI attribution lines in commits. Commit only when the owner says so; never push to main without the owner's explicit OK.

## 2. Sources and what was taken from each

| Source | Used for | Not adopted |
|---|---|---|
| Vxplore, Medium, "Emotional Design in Mobile UX" (26 May 2025) | Norman's three levels as the frame; micro-interactions, empathic errors, personal onboarding, motion never delays the task | Colour-meaning claims (blue means trust): weak and culture-bound |
| GoMage, "The Role of Emotional Design in Successful Apps and Websites, 2026" | Four levers: familiarity, hierarchy, feedback, calm tone; consistency lowers stress; ethics: say what an action does | Its ecommerce conversion numbers: not transferable |
| Coderio, "Emotional Design in 2026" | Per-journey feeling sentence; response-time ladder; error rules; permission timing; accessibility as emotion; measurement and the 0 to 3 audit | None; the most useful of the three |
| YouTube 2TlIg3VokY8, uxpeak, "The UX Psychology Behind Apps People Can't Stop Using" | Smart defaults, endowed progress, reciprocity (value before ask), IKEA effect (let her make something first) | Loss aversion with countdowns and "I'll risk it" dismissals; price anchoring tricks. They conflict with the no-guilt rules |
| YouTube PDcQJOPby1k, Kole Jain, "5 SaaS UI/UX mistakes that scream you vibe code" | Visual QA checklist: one icon set, no decorative emoji, deliberate palette, no repeated metrics, no dead cards, overflow menus | Web dashboard and pricing page advice |
| Earlier video studies (see FREE-LAUNCH plan sections 15 and 16): Tim Gabe LXX_qOA5D8E, Wyatt Feaster MVOpq3WRnbo, Jason Lee Rk6t9Uq1y9M, John Kim f-Ar8mwm3kQ | Peak-end, goal gradient, completion drive, honest rewards (already decided); animation quality pass and tilt-responsive motion (section 16) | Anything already listed as rejected there |
| Norman, *Emotional Design* (visceral, behavioural, reflective); Walter, *Designing for Emotion* (functional, reliable, usable, pleasurable) | The structure of this guide | |
| Platform guidance: Apple Human Interface Guidelines (Motion, Haptics, Accessibility), Material 3 motion, WCAG 2.2 | Motion durations and easing families, haptic discipline, reduced motion, contrast | |

Figures quoted in the sources are the authors' claims, not verified for Own Hub. Measure before believing any of them (section 11).

Note on the two newest videos: the first is persuasion psychology, the second web SaaS polish. Neither is about fitness emotional design. Only the points listed above are used.

## 3. The emotional brief

One sentence per journey: the feeling to create, and the feeling to avoid. Write these on the design review page and test against them.

| Journey | Feel | Avoid |
|---|---|---|
| First open and onboarding | Welcomed, safe, already making progress | Interrogated, sold to, stuck in a form |
| ID and women-only check | Protected ("this keeps the space women-only") | Suspected, waiting in the dark |
| Home, every day | A calm, clear "today is ready for you" | A dashboard of demands |
| Starting a workout | Capable and unhurried | Pressure, a long setup |
| Mid-workout | Focused, in rhythm, supported | Distracted, unsure what to tap |
| Finishing a workout | Proud, warm, one real celebration | Hollow confetti, fake numbers, a nag |
| Logging food | Easy and judgment free | Counting, guilt, homework |
| Rest day and missed days | Permitted, welcomed back | Behind, scolded, tracked |
| Progress | Seeing herself get stronger | Ranking, comparing, shame |
| Events | Belonging, something to look forward to | FOMO |
| Coaching | Held by a real person | Handed to a system |
| Errors and waiting | Told the truth, kept safe, one next step | Blamed, lost work |

Brand voice: warm, plain, a little playful, never childish, never clinical. Say what happened, say what happens next. Use the verbs she would use. Arabic is spoken Egyptian in an everyday register that a woman in Cairo uses with a friend, but not slang, not teen chat, not forced jokes (owner feedback 25 Oct: earlier lines were too casual and cutesy and were removed). When unsure, choose the plainer line, or no line.

## 4. Principles (each is a rule the agent can test)

**Visceral (first glance)**
1. **Calm surface.** Linen ground, generous space, one emphasised element per screen. Clutter reads as anxiety. Audit: squint test, the eye lands on one thing.
2. **Drawn, not decorated.** Keep the hand-drawn art language (`app/lib/ui/hand/`). One icon family, no decorative emoji in UI chrome (emoji only where she types them). Remove any card that does nothing and any metric shown twice.
3. **Colour with intent.** Pink fills the one primary; petrol is for links, icons and data; sage only for a real achievement. Never decorate with an extra accent colour. Keep text contrast at WCAG AA or better, including on pink.

**Behavioural (while she uses it)**
4. **Every action is answered.** A touch is acknowledged in about 0.1 s (pressed state), the result is confirmed within about 1 s, and a task longer than that shows honest progress (ladder in section 5.6).
5. **Forgiving by default.** Undo for the last set and the last food (already built), nothing she typed is lost on error, destructive actions live in an overflow menu with a confirmation that says what will happen.
6. **Defaults that read as a recommendation.** Preselect the likely choice (last used, her plan, her usual breakfast). Button copy states the payoff ("Start, 4 moves ready") where it is true.
7. **Progress that starts ahead.** Wherever a meter shows (onboarding, first week, plan), count what she already did, never start at zero. Close the loop (week marks, set bar, "one more and this week counts"; already in section 15, extend to onboarding).
8. **Value before ask.** She meets the app, and trains once, before she is asked for an account (owner decision D62). Show a real preview of a result, then "keep this". Never blur a result behind a wall.

**Reflective (what she remembers)**
9. **One peak, one good ending.** R10 is the peak of every session; a quiet, kind ending closes every other flow (saved, done, welcome back). Fix the low points before adding highs.
10. **Make it hers.** Let her name things and choose (her goal, her days, her plan name, a colour accent from the palette, her profile picture) so leaving feels like leaving her own thing. Greet her by first name where known; otherwise no name, never "You".

## 5. Foundations to build or tighten

All motion uses `app/lib/ui/hand/motion.dart` (`HandTiming`) and is off under `handMotionOff`. Prefer composing the existing pieces: `spring_pop.dart`, `draw_on.dart`, `stagger_in.dart`, `paper_confetti.dart`, `finish_wipe.dart`, `tilt_parallax.dart`, `page_transition.dart`, `skeleton.dart`, `hand_swap.dart`, `launch_splash.dart`, and `moment.dart`. Add a new piece only when none fits.

### 5.1 Motion tokens
Starting values, to be tuned on a real mid-range Android and an iPhone. Put them in one place (`HandTiming`) and reference them by name; no magic numbers in screens.

| Token | Duration | Use |
|---|---|---|
| `press` | 80 to 120 ms | pressed state on any tap, scale 0.97 or tint |
| `quick` | 150 to 200 ms | toggles, chips, small reveals |
| `base` | 250 to 300 ms | sheets, cards entering, page transitions |
| `emphasis` | 400 to 500 ms | the one hero moment on a screen |
| `moment` | 700 to 1200 ms | a drawn tick, a count-up; plays once |
| stagger step | 40 to 60 ms per item, at most 6 items | lists arriving |

Easing: entering decelerates (ease-out), leaving accelerates (ease-in), a spring only for a "pop" of a mark. Never loop an animation on a screen where she is reading or doing a set. Every animation plays once, can be skipped by a tap where it blocks anything, and never delays the next task. Motion that carries information (progress, state change) is kept in reduced-motion mode as a simple fade or static state.

### 5.2 Haptics (`app/lib/app_state/haptics.dart`)
Haptics confirm, they never decorate. Always paired with a visual, off when the phone's haptics are off, and one per moment.
| Moment | Haptic |
|---|---|
| Set logged | light impact |
| Last set done, session finished | medium impact (the existing finish moment) |
| Personal best (call `bigMoment`, which is defined and never used today) | one firm pattern, once per session |
| Food logged, Undo available | selection tick |
| Error needing action | one warning notification pattern |
| Everything else | none |

### 5.3 Sound (owner decision 26 Oct: the app is alive with sound, not silent)
Sound is on by default and is part of the first pass. It answers her actions and celebrates her wins, the way haptics do, and always pairs with a visual and usually a haptic.

**Sound palette.** One small family of warm, soft, organic sounds that fits the hand-drawn brand: paper, wood, a soft chime, a gentle marimba or kalimba, a muted pop. No game bleeps, no sirens, no harsh sine tones. Every sound is short (under 1.2 s; the session peak up to 2 s), quiet in level (peak around -12 dBFS, loudness consistent across all files), and tuned in one key so sounds layered together never clash. A rising pair means success, a falling soft pair means "undone", never a buzzer.

**Cue map** (each cue is an id in one table; screens ask for the id, never a file):
| Cue | Moment | Character |
|---|---|---|
| `tap` | primary button press, tab change | tiny soft tick, almost felt |
| `setDone` | set logged (M3) | short warm pop, pitch rises a step per set in the workout, resets next move |
| `restStart` / `restTick` / `restEnd` | rest timer (M4) | soft whoosh; last 3 seconds three gentle ticks; a clear but kind chime at the end |
| `sessionDone` | R10 peak (M5) | the one rich cue: short rising phrase with a soft shimmer |
| `personalBest` | a real best | the same phrase with one extra bright note |
| `weekClosed` | week goal reached (M6) | slow warm chord |
| `foodLogged` | meal added (M8) | soft wooden tap; `undo` a gentle reverse of it |
| `milestone` | real milestone (M9) | short chime |
| `verified` | women-only check approved (M10) | calm welcoming two-note |
| `saved` | any saved confirmation (M1) | tiny pop |
| `message` | coach message arrives in the app | soft two-note |
| `error` | needs her attention | one low soft note, never harsh, never repeated |
| `welcome` | first open (M2) | a short warm phrase, once ever |

**The chosen sound set and how to stay legally clean (owner asked for a safe choice)**
- **Make every sound from scratch by synthesis, in a script committed to the repo** (`tools/make_sounds.py`, numpy only, writes the files to `app/assets/sounds/`). No samples, no stock libraries, no AI music services, no recordings of other apps. Then the owner owns the copyright outright, there is no licence to track, no attribution, no takedown risk, and the files can be regenerated. Keep the script and a one-page provenance note (author, date, "synthesised from sine and noise generators") as the evidence.
- **Palette: warm mallet tones.** A soft marimba or kalimba voice (sine plus a quiet second and fourth harmonic, fast attack of about 5 ms, exponential decay), a muted wooden tap (short filtered noise burst), and a gentle air shimmer (filtered noise, slow swell) for celebrations. This reads calm, human and healthy, close to wellness apps, and far from arcade sounds.
- **Key and notes:** one pentatonic family in C major (C, D, E, G, A) so any two cues sound consistent together. `tap` = a 3 ms-attack tick at E6, very quiet. `setDone` = one mallet note, G4 to A4 to C5 to D5 to E5 by set number, 250 ms. `restEnd` = E5 then G5, 500 ms. `sessionDone` = C5, E5, G5, C6 rising, last note held 900 ms with the shimmer. `personalBest` = the same phrase plus a bright E6 at the end. `weekClosed` = a slow C major chord (C4, E4, G4) with swell, 1.4 s. `foodLogged` = wooden tap at A3 plus a soft D5. `undo` = the same two notes in reverse. `verified` = G5 then C6, 600 ms. `saved` = a single soft C6 pop, 150 ms. `message` = D5 then A5. `error` = one low soft A3 tone with a slow decay, never repeated. `welcome` = C5, G5, E5, C6 slow, once ever.
- **Avoid lookalikes:** do not copy the pitch pattern, timbre or rhythm of any famous app, OS or brand sound (Apple's system tones, Duolingo's correct chime, Slack, Netflix, Mastercard, Intel). Keep the cues short and simple and check by ear that none is a recognisable jingle. Do not use a melody the owner or a lawyer could mistake for an existing song; these are four or fewer notes of a standard scale, which is not protectable.
- **Product rules that keep her safe:** no sound on any screen that records or plays her own voice, coach audio, or video; no high-frequency or sudden loud sound; loudness normalised to about -16 LUFS integrated with a true-peak ceiling of -3 dBFS; no sound repeats faster than 400 ms; every cue has a visual and a Profile switch; nothing plays when her phone is in Silent mode or in a call.
- **Store and privacy:** sounds are bundled assets, so no network use, no permission, no privacy disclosure change, and no data collected. They do not need an age-rating or content declaration. Health claims: no sound or line claims a medical effect.
- **Sign-off:** the owner and Rahma listen to the exported set (the agent publishes a single preview page or an `.m4a` mix) and approve before release. This is not legal advice; if the owner wants certainty, a lawyer can confirm the provenance note in one short review.

**Rules**
- Respect the phone: obey the silent switch and the system volume; use the ambient audio category so the app mixes with her own music or podcast and never stops it or ducks it for a tap sound (workout music matters). In Silent mode, play nothing and keep the visuals and haptics.
- A Profile switch "Sounds" (on by default) and a second "Haptics". Both survive reinstall in local settings. Reduce-motion does not turn sound off; a separate system accessibility choice does not either; only her switch does.
- Never play sound while the camera or a coach voice or video clip is playing, and never on top of the exercise video's own audio (the clips stay as they are). Pause cues during phone calls.
- Latency: preload the cue set at launch into memory (short files, few hundred KB in total) and play with a low-latency player, so `setDone` lands within about 50 ms of the tap. Audit on a mid-range Android.
- One sound per moment; layered cues are composed once, not stacked at runtime. Rate limit: the same cue at most once per 400 ms.
- Not on every list scroll, keyboard tap, toggle or error repeat. Restraint is what makes the wins feel big.
- Sources: record, generate or commission original sounds, or license royalty-free with a written licence that allows commercial app use; keep the licence and the source in `app/assets/sounds/README` style notes outside product copy. No copied sounds from other apps.
- Arabic and English share the same sounds (no spoken words in cues). Egypt use: many women train with others around, so the Profile switch is one tap from Home's You tab and the first-run explains it in one line.
- Tests: a cue table test (every id has a file, a length cap, a loudness note), a settings test (off means silent), and a test that no cue plays under `handMotionOff` incorrectly (sound is independent of motion).
- Implementation: add one audio dependency (a low-latency one such as `audioplayers` or `just_audio`, chosen by the agent after checking maintenance and Android and iOS latency) behind a single `AppSound` service in `app/lib/app_state/`, mirroring `haptics.dart`. Do not call the package from screens.

### 5.4 Surfaces and depth
Cards sit on Linen with a soft paper-like edge already used by the hand art; one elevation level for cards and one for sheets. Large friendly radius family (already in tokens). Keep the grain and the hand-drawn underline marks; do not add gradients, glass or glows. The one filled pink button gets the strongest contrast on every screen.

### 5.5 Type and numbers
Rubik for Latin and Arabic, as now. Hero figures are large and calm, with tabular numerals so counts do not jitter. Arabic line height is generous (check at 200% text). Use Western digits in both languages.

### 5.6 Response-time ladder (Coderio)
| Wait | Pattern |
|---|---|
| under 0.1 s | feels instant, no indicator |
| about 0.1 to 1 s | pressed state, then result |
| 200 to 500 ms of real work | optimistic update or a pending state; never a frozen button |
| 1 to 10 s | skeleton or a determinate step list that names real operations; no fake waits (D39) |
| over 10 s | release her, keep working in the background, notify on completion |
Field target: interactions 200 ms or less at p75 on a mid-range Android; over 500 ms is a defect.

### 5.7 State design (replaces bare spinners and flat empties)
- **Empty:** a small drawn illustration from the existing art set, one warm line saying what will appear here and the single next step. No extra buttons beyond that step.
- **Loading:** skeletons that match the final layout (`skeleton.dart`), never a bare spinner on a main screen.
- **Error:** keep her work, say the plain cause, give one next step, no blame, no codes. Read the copy aloud: if it would sound cold to a friend, rewrite it.
- **Offline:** say what still works ("your workout is saved on this phone"), sync quietly later.
- **Success:** a drawn tick via `Moment` or a one-line confirmation. Never a modal for a small success.
- **Permission asks:** only at the moment the purpose is obvious, with one sentence on what it protects her from or gives her (notifications after the first finished session, camera when she taps the camera).

### 5.8 Microcopy rules
Predict the outcome before the tap ("Start, 4 moves ready", "Save this workout"). Say what an action does and what follows. One idea per line. No exclamation marks except real wins, no jokes in errors or safety, no guilt phrasing. Test every string in EN and AR at 200% text, and read both aloud.

## 6. The moments catalog (the animation set that replaces the kitten)

Each moment has a trigger, a motion, a haptic, a sound cue (section 5.3) and a reduced-motion fallback. The sound for each moment is the cue with the matching name (M3 `setDone`, M4 rest cues, M5 `sessionDone` or `personalBest`, M6 `weekClosed`, M8 `foodLogged`, M9 `milestone`, M10 `verified`, M1 `saved`, M2 `welcome`). Build as a small library on top of `moment.dart` so every screen uses the same grammar.

| ID | Trigger | Motion | Haptic | Reduced motion |
|---|---|---|---|---|
| M1 Tick | any "saved or done" confirmation | stroke draws on, small spring pop, 700 ms | none | static tick |
| M2 Welcome | first open | hand art draws in, one line fades up, 600 ms | none | static |
| M3 Set done | each set logged | set bar segment fills, number settles, 200 ms | light | segment fills instantly |
| M4 Rest ring | rest timer | ring drains smoothly; last 3 seconds gentle tick | none | numeric countdown only |
| M5 Session peak (R10) | session finished | staged reveal: hero figure counts up, week marks close, one tick, paper confetti only for a real best or a first session, 1.6 to 2 s total, tap to skip | medium, plus firm on a best | final state with no motion |
| M6 Week closed | the week reaches its goal | the week strip marks fill in order, one soft line of text | light | static |
| M7 Welcome back | first open after days away | quiet greeting line and the plan ready, no counts of missed days | none | static |
| M8 Food logged | meal added | row slides in, calorie ring eases to its new value, Undo chip for 5 s | selection | value updates |
| M9 Milestone | a real milestone is earned (honest, hers) | drawn mark with her number, once | light | static |
| M10 Verified | women-only check approved | tick draws on over the Linen ground, calm line "You're in" | light | static |
| M11 Pull and arrival | content arriving on lists | stagger in 40 to 60 ms steps, at most 6 | none | no stagger |
| M12 Tilt | optional light parallax on the Home hero art only | tilt-responsive, subtle | none | off |

Rules: at most one M-moment per screen state; none on R07 mid-set, R09, Progress charts or error states; every moment plays once per trigger and is never replayed on scroll.

## 7. Screen by screen

Each entry adds the feeling layer. Structure and control budgets come from the existing plan and must not grow.

**Onboarding and sign-up (O*, C*)**
- Endowed progress: the step counter counts the first answer as done, so it never starts at zero. Count only real steps.
- Value before ask: the first workout (guest, D62) comes before the account. End it with "Keep this workout" (R10) as the single primary.
- IKEA effect: let her pick her goal, days and a plan name before the account step; the account step reads "keep what I made".
- One calm hand-drawn hero per screen (M2 on the first), one line, one Continue. Transitions use `page_transition.dart`.
- ID and women-only check: explain in one sentence what it protects her from, show honest steps that name real operations (D39), and end with M10. Never leave her waiting without a status line.

**Home (T01)**
- Greeting by first name (or none) and one line that fits the time of day and her plan; the Today card is the visual centre with the one filled Start. Add a quiet drawn hero that changes with the week phase (rest, training day, week done) instead of data.
- M7 when she returns; M6 when the week closes; nothing else. No streak numbers in a loud style; keep the streak she controls as a quiet line.
- The week strip is a calm row; tapping opens You. Entering uses M11 once per session, not on every visit.

**Train (R01, R02, R03)**
- R01 opens on today. Plan building stays one tap away. Explore keeps one Filter.
- R03 leads with a summary line and the move list on Linen cards. Each move shows the existing clip thumbnail; keep the video frame as is.
- Start copy states the payoff ("Start, 6 moves"). The first-gym guide stays once.

**Workout (R07, R09, R10): keep the player and the flow**
- R07: keep the clip, the move name, "Set 2 of 3" and the one big figure. Add only M3 on Done and the set bar. No decoration on this screen, no tilt, no extra text.
- R09: ring (M4), "+30 s", one filled "I'm ready". The up-next move shows its thumbnail so the rest feels purposeful.
- R10 (the peak, M5): hero figure counts up (off under reduced motion), at most 3 stats, one warm line chosen from the existing lines (owner-approved Rahma lines pending), 5-second Undo of the last set stays. Confetti only for a real best or a first session. A guest sees "Keep this workout" first. "Remove session" is not offered here (owner decision 6).
- Haptics per section 5.2. Share is a quiet icon.

**Eat (E01, E02)**
- Calorie ring eases to the new value (M8). Meals are calm rows with one "+". Repeat plate is one tap with Undo.
- Judgment-free copy: no "over", no red. A day under target is not a failure; say what she ate, not what she should have. Empty meal rows show one drawn plate and "Add breakfast".
- AI photo scanning shows honest steps while reading the photo, and a calm line when it is unavailable (the Google approval is pending).

**You and Progress (P01)**
- Progress is a calm weekly chart plus 3 figures. Celebrate the shape of her effort ("sessions this week"), compare only with her own last week. M9 for a real milestone only. Never rank, never show a sad state.
- Activities list newest first, each with its small drawn mark by type.
- Settings behind the gear stay a plain grouped list; no motion beyond press states.

**Events (T09): keep as is**
- Only apply shared tokens: press state, M11 arrival, the Reserve confirmation as M1. Keep the card layout, picture-first, date, tap to detail. No new controls.

**Coaching (H01 to H05, chat)**
- Replace bare spinners with skeletons and a human line ("Finding coaches near your goals"). A new message arrives with a soft slide-in. "Held by a real person": show the coach's face and first name wherever she speaks to her. Empty chat shows one warm line and the coach's photo.
- No gamification inside coaching; the plan is the coach's.

**Notifications and widget**
- Calm lines only (the playful tone was removed 25 Oct). One notification at most per situation per day, at hours she chose. A widget shows today's plan only, never counts of what she missed.

**Errors, offline, empty, first-run states**
- Apply 5.7 everywhere. Audit every screen for a bare spinner, a bare "Something went wrong", or a dead end.

## 8. Accessibility and performance (part of the emotion)

- Reduced motion: every moment has a static fallback; information-carrying motion becomes a fade. Test with the phone setting on.
- Contrast: AA at least for all text including on Pale Pink; check pressed and disabled states.
- Text scaling to 200% in EN and AR without clipping (existing sweeps); touch targets at least 44 pt; semantics labels on every icon-only control and on moments ("Saved").
- Performance: no animation may drop frames on a mid-range Android; use `RepaintBoundary` around moving marks; limit confetti particles; avoid layout-changing animations; precache art. Measure with the profile build on a real device, not the simulator.
- The six common failures to fix in the pipeline: low contrast, missing labels, empty buttons, unlabeled images, missing language, small targets.

## 9. Guardrails (never cross)

- Sound never startles, never plays on an error loop, never overrides her silent switch or her own music.
- No loss framing, countdowns, "I'll risk it" dismissals, fake scarcity, fake waits, random rewards, rankings, or numbers she did not earn.
- No mascot, character or pet. No dark patterns in consent, deletion or cancel flows.
- Emotional features never replace reliability: if a flow is not fast, correct and forgiving, fix that first.
- Do not copy another app's brand, art, names or sounds. Patterns only.

## 10. Work packages for the coding agent

Order matters. One review and one commit per package; all existing suites stay green.

| Package | Content | Acceptance |
|---|---|---|
| E0 | Land the pending kitten removal and batch A (see the Build log in the plan); confirm green suites | `flutter analyze` clean, full `flutter test` green |
| E1b | Sound: `AppSound` service, the cue table, the original sound files and licences, the Profile switches "Sounds" and "Haptics", ambient mixing and silent-switch behaviour | cue table, settings and rate-limit tests; device check of latency, mixing with music, and silent mode on iPhone and a mid-range Android |
| E1 | Foundations: motion tokens in `HandTiming`, haptics map, response-time ladder helpers, state widgets (empty, loading, error, offline) with strings in EN and AR | unit tests per token and widget; Reduce Motion golden tests |
| E2 | The moments library M1 to M12 on `moment.dart` and the existing pieces | each moment has a widget test (plays once, static fallback) and appears in `docs/ui-reference` |
| E3 | Onboarding: endowed progress, choose before account, first workout before account, verification steps | tap-count and budget tests; step counter test |
| E4 | Home: time-aware greeting, week-phase hero art, M6, M7 | one-primary and budget tests; goldens EN and AR at 375x667 and 390x844 |
| E5 | Workout: M3, M4, M5 on R07, R09, R10 with their sounds; call `bigMoment` for a real best | existing finish tests; haptic call test; no extra control |
| E6 | Eat: M8, judgment-free copy, empty and error states; scanner steps | eat tap-count tests stay at 1 and 3 |
| E7 | You, Progress, coaching, notifications states | budget tests; skeleton present on every list |
| E8 | Events and Settings: tokens only | goldens unchanged except press and arrival |
| E9 | Copy audit: EN and AR read-aloud pass; delete AI-sounding lines; test for banned words and em dashes | extend the copy-audit test |
| E10 | Measurement and audit (section 11); device evidence for haptics, Reduce Motion, Arabic at 200% text | audit sheet filled |

Reuse before writing: `ui/hand/*`, `app_state/haptics.dart`, `ui/app_sheet.dart`, `ui/app_overflow_menu.dart`, `ui/app_stat_hero.dart`, `test/helpers/control_counter.dart`. Do not edit the video player widgets except through shared tokens.

## 11. Measurement and review

Log, consent-gated, with the existing analytics gateway: task completion, drop-off by step, time to first set, error recovery rate, support contacts per journey, week-4 retention, and for moments only whether they were skipped. Ask in moderated sessions with real women (Egypt, mid-range phones, EN and AR): "how did that step feel?" with a joy or frustration rating after the first set, the first log, the first finish.

Audit rubric, 0 to 3 on seven dimensions, scored on a mid-range Android on a throttled network: cost transparency, predictability, responsiveness, error recovery, accessibility baseline, permission legitimacy, language under pressure. Release gate: no dimension below 2 on any core journey.

Visual QA checklist before each package is reviewed: one icon set, no decorative emoji, no repeated metric, no card that does nothing, one emphasised element, secondary actions in the overflow menu, EN and AR screenshots side by side.

## 12. Open decisions for the owner

1. Rahma's own end-of-workout lines (owner-approved set) for R10 and welcome-back.
2. Who creates the sounds (commissioned, generated, or licensed) and who approves the final set; Rahma should hear it before release.
3. Whether the Home hero art changes by week phase or stays one calm drawing.
4. Whether she may pick an accent from the palette (IKEA effect) or only name her plan.
5. The retention window for any new measurement events (with counsel).

## 13. Reference screens and prior art (patterns only)

Duolingo (one task per screen, mascot-free sections of its flow, forgiving streaks), Strava (one primary, preselected sport), Apple Fitness (rings and closure), Headspace and Calm (calm surfaces, breathing motion), Gentler Streak (forgiving model), Hevy (set logging). Local copies of store screenshots are in `.claude/feature-briefs/references/app-store/` (not in git). Source notes for this guide: the five sources in section 2.
