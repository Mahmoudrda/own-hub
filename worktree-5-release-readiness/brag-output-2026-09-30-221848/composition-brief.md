# Hyperframes Composition Brief: Own Hub

## Objective

A forty second vertical launch walkthrough for Own Hub, built from real screen
recordings of the signed release APK running on a Pixel 8 emulator.

## Output

- Composition directory: `brag-output-2026-09-30-221848/composition/`
- Rendered video: `brag-output-2026-09-30-221848/brag.mp4`
- Format: vertical — 1080x1920
- Duration: 40.25s (user passed `--duration 40`)

## Source Material

- Project root: `/Users/mahmoudreda/womens-fitness-app-wireframe/.claude/worktrees/release-readiness`
- Primary files read: `app/lib/theme/app_tokens.dart`,
  `app/lib/theme/recipe_book_tokens.dart`, `app/lib/routing/app_router.dart`,
  `app/lib/features/eat/presentation/eat_view.dart`,
  `app/lib/features/eat/presentation/recipes_view.dart`, `app/pubspec.yaml`
- Footage: `../raw/*.mp4`, recorded with `adb screenrecord` at 1080x2400 with
  Android's "show touches" on, so every tap is a real touch indicator, not a
  drawn-on dot. Trimmed to `assets/clips/s01..s15.mp4` at 648x1440, 30fps.
- Product name: Own Hub
- Strongest claim on screen: "Four short questions, then your week is ready. Skip
  any of them."
- Key UI moment to hold: Rahma's recipe card, pale pink paper with brass clips, her
  Egyptian Arabic ingredients and steps
- Copy that must appear verbatim (it is in the footage, so the captions must not
  contradict it):
  - "Built from your four answers"
  - "Rest starts itself"
  - "That's Wednesday done"
  - "Make it work for you"

## Creative Direction

- Tone preset: `app-store`
- Creative direction: a quiet product walkthrough, the app carries it
- Interpretation: one caption per beat, arriving fast and holding; slide-and-settle
  scene motion; no zoom fighting the footage; no exclamation marks
- Angle: a real build filmed on a real device, walked through the way a woman meets
  it, with every tap visible
- Hook: a finger landing on a setup answer before the name even arrives
- Outro: "Own Hub · Strength, food and rest. In Arabic and English."
- Avoid:
  - Generic SaaS language
  - Abstract filler visuals
  - Any implication of community, coaching, payments, an assistant or identity
    verification, all of which are switched off in this build
  - Em dashes in on-screen copy

## Visual Identity

- Background: `#F2E8EB` with a `#FFF8F9` warm wash top-left
- Text: `#241A1E`, secondary `#6B5C61`
- Accent: `#A24661`
- Display font: Rubik 700, bundled from `app/assets/fonts/Rubik-700.ttf`
- Body font: Rubik 400/500, same source
- Hand font: La Belle Aurore, used once on the closing card
- Visual references: the phone frame is the whole design; the background is the
  app's own canvas colour so the device reads as part of the same paper

## Storyboard

`brag-plan.md` is the creative contract. Scene summary:

1. Setup question one — 3.16s — a tap lands, "Own Hub" arrives
2. Setup question two — 2.61s — "Four short questions"
3. Setup question three — 2.09s — "Skip any of them"
4. The built plan — 2.62s — "Then your week is ready"
5. Today — 3.13s — "The day on one screen"
6. The session — 2.09s — "Fifteen minutes, four moves"
7. Mid set — 2.61s — "One tap logs the set"
8. The rest timer — 3.14s — "Rest starts itself"
9. Done — 2.09s — "That's Wednesday done"
10. Logging a meal — 2.61s — "A meal logged in one tap"
11. The recipe cards — 2.09s — "Rahma's recipe book"
12. Inside a card — 3.14s — "39 dishes in her own Arabic"
13. Progress — 2.09s — "Your week, counted"
14. My cycle — 2.09s — "Your cycle, kept private"
15. Arabic — 2.09s — "In Arabic, right to left"
16. Close — 2.60s — "Own Hub"

## Audio

- Audio role: warm bed with sparse interaction accents
- Audio arc: fades in over the first second, sits low through the walkthrough,
  lifts a touch under the recipe book, fades out under the closing card
- Music: `assets/music/bed.mp3`
  (happy-beats-business-moves-vol-9-by-ende-dot-app, 114.84 BPM)
- Music treatment: baseline 0.24, automation lane fades 0 to 0.24 over the first
  second and 0.24 to 0 across the last two seconds
- Music cue guidance: preset at `assets/music/bed.music-cues.json`. Beat grid is
  1.07 + n x 0.5225. Beat locks: built plan 7.86s (n13, 7.8625), rest timer 18.31s
  (n33, 18.3125), recipe book 28.24s (n52, 28.24), Arabic flip 35.56s (n66, 35.555).
  Every scene start sits on a grid beat.
- Audio-reactive treatment: subtle. The rose halo behind the phone breathes on the
  music's low-band energy, and nothing else.
- Audio-coupled moments:
  - Scene 1 at 1.75s — the tap on the setup answer
  - Scene 7 at 18.20s — the tap that ends the set, landing into the rest-timer cut
  - Scene 10 at 24.30s — the Log tap
  - Scene 16 at 37.95s — a soft warm impact as the name lands
- SFX selection guidance: `ui/click2.ogg` for taps (0.06s, balanced, low HF risk),
  `impact/impactSoft_medium_001.ogg` for the closing landing (0.18s, warm, low HF
  risk). Three taps in forty seconds is the whole budget.
- SFX analysis guidance: `/Users/mahmoudreda/.claude/skills/brag/assets/sfx/sfx-analysis.md`
- Audio files: copied into `composition/assets/music/` and `composition/assets/sfx/`

## Hyperframes Instructions

Requirements honoured in the build:

- Real UI throughout; fifteen of the sixteen scenes are live device footage.
- Captions sized for the reading floor: no line leaves before it can be read.
- Music and SFX present, restrained.
- Four beat-locked reveals, every other scene start on the grid.
- Audio-reactive halo driven by extracted low-band RMS.
- Local assets only; GSAP from cdn.jsdelivr.net.
- `hyperframes check` is the gate before render.
