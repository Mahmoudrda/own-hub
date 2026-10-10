# Brag Plan: Own Hub

## What is this app?
Own Hub is a women-only fitness app for Egypt — quiet home workouts, food logged in
the portions she actually serves, a cycle tracker that stays hers, and a community
only ID-verified women can enter. Bilingual Arabic/English, right-to-left throughout.

## The angle
The product's whole character is **restraint**. It has no streaks, no calorie
countdowns, no leaderboards, no weight-loss claims and no red failure states —
those are forbidden in the code and enforced by tests. So the video is not a
launch ad; it is a **quiet feature tour**. Nine features, one idea per beat,
generous holds, every claim backed by a real screen. The restraint *is* the pitch.

The organising visual idea: one phone sits on the right for the whole tour and
never leaves. Only the screen inside it changes. Nothing whips, nothing flashes,
nothing counts down. The video behaves the way the app behaves.

## Hook (first 2-3 seconds)
The app icon and wordmark land, then the product's own welcome headline, verbatim:
**"A room full of women training like you."** No claim, no number, no urgency —
the line the app already opens with. Scene 2 then shows that exact line living on
the real welcome screen, so the title card and the product visibly rhyme.

## Key moments (the middle)
- The three "Short ones that still count" tiles — 10 min / 15 min / 20 min — arriving
  one by one, then a soft ring halo landing on the real **2/3 week** ring in the
  screenshot. A ring that counts sessions, not days.
- The protein bar filling on the Eat scene while the line "No countdown, no red
  numbers" sits beside it. The bar fills and stops. It carries no target number,
  because the app's screenshot does not show one.
- The cycle screen leading with **her** control: "You choose what to log. You can
  change or delete it any time," beside the verbatim settings line "Off by default.
  Coaching never requires it."
- Progress: "Measured against your own history only" — the app's real personal-bests
  line, which is the closest thing the product has to an anti-leaderboard statement.

## Outro / punchline
The phone shows the app's own finished screen — "That's Tuesday done" — the one
reward moment the product allows itself. Then the phone clears and the wordmark
lands with the welcome screen's second line: **"Quiet workouts for home, food you
already cook, and a community only women can enter."**

## User flow worth showing
Entry → verification → the day. The tour follows the real order a woman meets the
product in: the gate (women only, ID checked, photos deleted), Today (what to do
now), then the four places she spends time (Train, Eat, My cycle, Progress), then
the two rooms other people are in (Community, Coaching), then what she controls
(Privacy), then the session she finished. Eleven of the twelve captured screens
are real app captures on an iPhone 17; nothing is mocked up.

## Tone
- Preset: `app-store`
- Creative direction: quiet product tour for a product whose selling point is that it does not shout
- Interpretation: clean slide-and-fade reveals, 0.45s entrances and long settled
  holds; one headline and one supporting line per beat; no hard cuts, no zooms, no
  aggressive type. Confidence comes from how much room each idea gets, not from pace.

## Format: landscape — 1920x1080
## Duration: 39.28 seconds (caller-approved override of the skill's 15-25s law — nine features need the room)

## Visual identity (from the project)
Source of truth: `app/lib/theme/app_tokens.dart` (generated from `6-v2/src/tokens.mjs`).

- Background: `#FFF8F9` (surface — a warm off-white, never pure white)
- Accent: `#B4526E` (primary) / `#A8455F` (primaryDim, used for small accent text)
- Text: `#241A1E` (onSurface) headlines, `#6B5C61` (onSurfaceVariant) body
- Support: `#4F7359` tertiary (done/progress), `#8A5A17` amber (attention, never alarm),
  `#F8E1E7` primarySoft panels, `#FFD9E3` primaryContainer, `#DDEDE1` tertiaryContainer
- Display font: Rubik 700 — Body font: Rubik 400/500 (shipped TTFs from `app/assets/fonts/`)
- Strongest visual element: the 36 transparent 600px illustrations in `assets/art/3.0x/`,
  which are the app's own artwork — `dance` and `strong_arms` literally appear inside
  the Community and finished screens, so reusing them ties the video to the product.

## Share copy (draft)
Own Hub is a women-only fitness app for Egypt. Quiet home workouts, food in the
portions you actually serve, a cycle that stays yours, and a room only verified
women can enter. No streaks, no countdowns, no leaderboard.

## Audio direction
- Role: warm, low, steady bed — sparse professional accents
- Music: `happy-beats-business-moves-vol-12-by-ende-dot-app.mp3` ("steady and clean" —
  the most restrained of the five bundled tracks; the energetic vol-1 would misrepresent the product)
- Music treatment: starts at 0, volume 0.26 (below the 0.3-0.4 normal bed, because the
  brand is quiet), 1.2s fade in, 3.0s fade out under the outro wordmark
- Music cue guidance: bundled preset read from
  `brag/assets/music/cues/happy-beats-business-moves-vol-12-...music-cues.json`.
  Tempo 109.96 BPM, beat interval 0.5456s. Preset window is 0-25s; beats past 25s are
  extrapolated on the same grid and confirmed against `npx hyperframes beats`.
  Strong cues targeted: **13.11s** (Train tiles complete + ring halo), **17.47s**
  (protein bar full), **22.93s** (personal-bests row). Scene cut at **18.56s**
  (Eat → My cycle) also lands on a 0.99 strong beat.
  Beat-grid windows: Train tiles 11.46/12.02/12.55; Eat tiles 15.29/15.84/16.38;
  Progress rows 22.37/22.93/23.46; Privacy rows 32.19/32.74.
- Audio-reactive treatment: subtle — the warm radial wash behind the phone and the
  phone's shadow depth breathe with music RMS. No waveform, no equalizer, no pulsing type.
- SFX posture: sparse and soft. One `interface/drop_*` per feature reveal at 0.42-0.50,
  two `impact/impactGlass_light_*` for the ring halo and the personal-best chip,
  one `ui/click1` for the protein bar, one `interface/bong_001` at 0.40 for the wordmark.
  Every cue well below the app-store preset's 0.65-0.75, because this brand does not tap loudly.
- Audio-coupled moments: Train tiles (beat grid), Eat tiles + bar fill, Progress rows,
  Privacy rows, outro wordmark
- Restraint rule: **no success stinger, no whoosh, no riser, no drum fill on a cut.**
  Nothing may sound like a reward for hitting a target — the product deliberately has no targets.

## Hard rules held to (from BRAND.md)
- No leaderboard, no rank, no streak, no weight-loss claim anywhere in the video.
- **Every number on screen comes from a screenshot** and is never re-typed as large
  video copy: `2/3 week`, `10/15/20 min`, `540/410/156 kcal`, `18/22/13 g protein`,
  `Under 2,000 EGP`, `+30 points`, `2 of 3`, `Week 3 of 8`, `32 min`, `0 of 4`,
  `Level 1` all stay inside their own screenshots where they were captured. The
  video's own typography states no figure at all.
- Women training, not bodies being judged: every illustration used shows a woman
  moving, resting or eating. None shows a body being measured or compared.

## Storyboard

Cut times are snapped to the music's beat grid (109.96 BPM).

### Scene 1 — Own Hub — 0.00 → 3.82s (3.82s)
Centred. App icon mark (the lotus glyph from the real icon, redrawn as SVG in primary
`#B4526E`) scales up, wordmark "Own Hub" beneath it, then the headline
**"A room full of women training like you"** (verbatim, welcome screen).
No phone yet — the frame is calm and empty.
Sequential/interaction: none.
Audio intent: the bed establishes, nothing else.
Audio-coupled idea: none — the opening is deliberately unscored.
Music: low warm bed fading in.
Transition mood: soft → Scene 2

### Scene 2 — Women only, and checked — 3.82 → 7.64s (3.82s)
The headline from Scene 1 reappears *inside* a phone that slides in from the right —
the real welcome screen. Left column: `stretch_seated` illustration, eyebrow
"WOMEN ONLY", headline **"Every member checked"**, line **"Both images are deleted
after the check. We keep the result, nothing else."** (verbatim, why-we-check screen).
Sequential/interaction: the phone arrives once and then stays for the whole tour.
Audio intent: one soft arrival, then quiet.
Audio-coupled idea: soft `drop_002` as the phone lands.
Transition mood: clean slide → Scene 3

### Scene 3 — Today — 7.64 → 10.93s (3.29s)
Phone screen crossfades to `today.png`. Left: `trainers` illustration, eyebrow "TODAY",
headline **"One screen, and what is on it today"**, line **"Nothing shouting."**
Sequential/interaction: screen crossfade only.
Audio intent: settle.
Audio-coupled idea: `drop_001` on the headline.
Transition mood: clean → Scene 4

### Scene 4 — Train — 10.93 → 14.73s (3.80s)
Phone crossfades to `train.png`. Left: eyebrow "TRAIN", headline **"Quiet workouts
you can do at home"**, then three tiles arrive one by one, each an illustration plus
the screenshot's own label: `plank` / "10 min · Floor only", `dumbbells` / "15 min ·
Quiet", `squat_weights` / "20 min · Dumbbells". A soft pink halo then lands over the
real **2/3 week** ring in the screenshot. Footnote pill: **"Not feeling it today?"**
(verbatim) with the line "A gentler option, based on your check-in."
Sequential/interaction: **yes** — three tiles on consecutive beats 11.46/12.02/12.55.
Audio intent: three soft taps, then one delicate landing.
Audio-coupled idea: `drop_001/2/3` per tile; `impactGlass_light_001` on the halo at 13.11 (strong cue).
Transition mood: clean → Scene 5

### Scene 5 — Eat — 14.73 → 18.56s (3.83s)
Phone crossfades to `eat.png`. Left: eyebrow "EAT", headline **"Say or type what you
ate"** (verbatim placeholder), line **"In the size you actually serve."** Three food
illustrations arrive (`bowl_salad`, `toast_egg`, `platter_grill`), then a protein bar
fills — labelled "Protein", carrying **no number** — under the verbatim caption
**"No countdown, no red numbers."**
Sequential/interaction: **yes** — three tiles on beats 15.29/15.84/16.38; bar fills 16.93 → 17.47.
Audio intent: three soft taps, one quiet confirmation as the bar settles.
Audio-coupled idea: `drop_*` per tile; `ui/click1` at 17.47 (strong cue) as the bar completes.
Transition mood: clean; the cut itself lands on the 18.56s strong beat → Scene 6

### Scene 6 — My cycle — 18.56 → 21.84s (3.28s)
Phone crossfades to `cycle.png`. Left: `rest_floor` illustration, eyebrow "MY CYCLE",
headline **"Yours, and private by default"**, line **"Off by default. Coaching never
requires it."** (verbatim, cycle settings).
Sequential/interaction: screen crossfade only. This is the beat that carries the
product's character, so it gets stillness rather than motion.
Audio intent: quietest moment in the video.
Audio-coupled idea: `drop_001`, softest instance.
Transition mood: soft → Scene 7

### Scene 7 — Progress — 21.84 → 25.11s (3.27s)
Phone crossfades to `progress.png`. Left: `strong_arms` illustration, eyebrow
"PROGRESS", headline **"Measured against your own history only"** (verbatim, personal
bests), then two rows arrive: "Counted weeks" and "Personal bests", then a chip
**"Nobody sees this."** (verbatim, body-privately screen).
Sequential/interaction: **yes** — rows on beats 22.37/22.93/23.46.
Audio intent: two soft taps and one delicate chime — the only "achievement" sound in
the video, and it is attached to privacy, not to a score.
Audio-coupled idea: `impactGlass_light_002` at 22.93 (strongest cue in the track).
Transition mood: clean → Scene 8

### Scene 8 — Community — 25.11 → 28.38s (3.27s)
Phone crossfades to `community.png`. Left: `dance` illustration — the same artwork
that appears inside that very screen — eyebrow "COMMUNITY", headline **"A room only
verified women can enter"**, line **"Faces arrive blurred, and nothing here leaves
the room."** (verbatim, community screen).
Sequential/interaction: the illustration matches the one inside the phone, and a
faint connecting line draws between them.
Audio intent: warm, unhurried.
Audio-coupled idea: `drop_002`.
Transition mood: clean → Scene 9

### Scene 9 — Coaching — 28.38 → 31.65s (3.27s)
Phone crossfades to `coaching.png`, then to `coach.png` at 30.01 (the coach's own desk,
including a real empty state with one of the 36 illustrations doing its actual job).
Left: `lunge_warrior` illustration, eyebrow "COACHING", headline **"Real women, with
checked certificates"**, line **"Every coach here is a verified woman."** (verbatim).
Sequential/interaction: two screens inside one beat — the member's view, then the coach's.
Audio intent: one tap on the second screen.
Audio-coupled idea: `drop_003` on the coach-screen swap.
Transition mood: clean → Scene 10

### Scene 10 — Privacy — 31.65 → 34.92s (3.27s)
Phone crossfades to `profile.png`. Left: `yoga_mat` illustration, eyebrow "PRIVACY",
headline **"What you show is yours to set"**, then two rows arrive, both verbatim from
the real screen: "Privacy — Who sees your profile and wins" and "Safety Centre —
Reports, blocked members, help". Closing line: **"Your ID and selfie were deleted
after the check. Only the result is kept."** (verbatim, privacy screen).
Sequential/interaction: **yes** — rows on beats 32.19/32.74.
Audio intent: two quiet taps.
Audio-coupled idea: `drop_001`, `drop_002`.
Transition mood: soft → Scene 11

### Scene 11 — That's Tuesday done — 34.92 → 39.28s (4.36s)
Phone crossfades to `finished.png` — the app's own reward screen — and holds for ~1.6s
with the line **"That's Tuesday done."** (verbatim). Then the phone and left column
clear, a gentle arc of seven illustrations fans out behind centre (`running`,
`bowl_green`, `dumbbells`, `fruit_basket`, `spin_bike`, `pancakes`, `boxing_gloves`),
and the icon + wordmark **Own Hub** lands with the welcome screen's second line:
**"Quiet workouts for home, food you already cook, and a community only women can enter."**
Sequential/interaction: the arc fans out over 0.9s, staggered.
Audio intent: the bed fades under a single soft bell.
Audio-coupled idea: `interface/bong_001` at 0.40 volume as the wordmark settles.
Music: 3.0s fade to silence, ending with the frame.

**Music mood for this video:** steady, warm and low — deliberately the least energetic bundled track.
**Audio summary:** a quiet bed that never swells, eleven soft interface taps matched to
real motion, two delicate glass accents on the two moments the product itself treats as
gentle wins, and one bell under the wordmark. Nothing in the mix sounds like a target being hit.
