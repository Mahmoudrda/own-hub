# HyperFrames Composition Brief: Own Hub

## Objective
A 39-second quiet feature tour of Own Hub covering nine features in the order the
brand brief sets, built entirely from the app's own screens, artwork, colours and copy.

## Output
- Composition directory: `docs/release/video/composition/`
- Rendered video: `docs/release/video/brag.mp4`
- Format: landscape — 1920x1080, 30fps
- Duration: 39.28s (caller-approved override of the 15-25s creative law: nine features)

## Source Material
- Project root: `/Users/mahmoudreda/womens-fitness-app-wireframe/app`
- Primary files read: `lib/theme/app_tokens.dart` (colour + type tokens), `lib/l10n/app_en.arb`
  (all user-facing English copy), `lib/features/**/presentation/*.dart` (screen structure),
  `assets/art/3.0x/*.webp` (36 illustrations), `assets/fonts/Rubik-{400,500,600,700}.ttf`
- Product name: **Own Hub**
- Strongest claim: "A room full of women training like you"
- Key UI to recreate: nothing is recreated. **Eleven real iPhone 17 captures** are shown
  inside one persistent device frame: `welcome`, `today`, `train`, `eat`, `cycle`,
  `progress`, `community`, `coaching`, `coach`, `profile`, `finished`.
- Copy that must appear verbatim:
  - "A room full of women training like you"
  - "Both images are deleted after the check. We keep the result, nothing else."
  - "Nothing shouting."  /  "Not feeling it today?"
  - "Say or type what you ate"  /  "No countdown, no red numbers."
  - "Off by default. Coaching never requires it."
  - "Measured against your own history only"  /  "Nobody sees this."
  - "Faces arrive blurred, and nothing here leaves the room."
  - "Every coach here is a verified woman."
  - "Your ID and selfie were deleted after the check. Only the result is kept."
  - "That's Tuesday done."
  - "Quiet workouts for home, food you already cook, and a community only women can enter."

## Creative Direction
- Tone preset: `app-store`
- Creative direction: quiet product tour for a product whose selling point is that it does not shout
- Interpretation: 0.45s slide-and-fade entrances, long settled holds, one idea per beat.
- Angle: the product's character is restraint, so the edit is restrained. One phone
  enters at 3.82s and does not leave until 34.92s; only the screen inside it changes.
- Hook: icon + wordmark + the app's own welcome headline, no claim and no number.
- Outro: the app's own "That's Tuesday done" screen, then the wordmark.
- Avoid:
  - Generic SaaS language, hype, urgency, any imperative like "crush" or "transform"
  - **Any leaderboard, rank, streak, countdown, red failure state or weight-loss claim**
  - **Any number in the video's own typography.** Figures may only appear inside a
    screenshot, where they were really captured.
  - Abstract filler visuals; unrelated visual redesign

## Visual Identity
- Background: `#FFF8F9` surface, with a soft `#F8E1E7` radial wash behind the phone
- Text: `#241A1E` headlines, `#6B5C61` body, `#A8455F` eyebrow accents
- Accent: `#B4526E` primary; `#4F7359` tertiary; `#8A5A17` amber (attention, never alarm)
- Display font: Rubik 700 (local `assets/fonts/Rubik-700.ttf`, `@font-face` in file)
- Body font: Rubik 400/500 (local TTFs)
- Visual references: the app icon lotus glyph; the 36 transparent illustrations;
  the app's 20px/28px card radii and its soft pink card surfaces

## Storyboard
`brag-plan.md` is the creative contract. Scene summary (beat-snapped, 109.96 BPM):

1. Own Hub — 0.00-3.82 — icon, wordmark, "A room full of women training like you"
2. Women only — 3.82-7.64 — phone enters with the welcome screen; deletion promise
3. Today — 7.64-10.93 — today screen; "Nothing shouting."
4. Train — 10.93-14.73 — train screen; three time tiles; ring halo; "Not feeling it today?"
5. Eat — 14.73-18.56 — eat screen; three food tiles; protein bar fills, no number
6. My cycle — 18.56-21.84 — cycle screen; "Off by default. Coaching never requires it."
7. Progress — 21.84-25.11 — progress screen; "Measured against your own history only"
8. Community — 25.11-28.38 — community screen; faces arrive blurred
9. Coaching — 28.38-31.65 — coaching screen, then the coach's desk
10. Privacy — 31.65-34.92 — profile screen; two real rows; the deletion line
11. Outro — 34.92-39.28 — finished screen, then illustration arc + wordmark

## Audio
- Audio role: warm low bed with sparse professional accents
- Audio arc: fade in over 1.2s, hold flat and quiet throughout (no swells), fade out
  over the final 3.0s under the wordmark
- Music: `assets/music/bed.mp3` (happy-beats-business-moves-vol-12 by ende.app), volume 0.26
- Music treatment: volume automation for both fades; never ducked, never boosted
- Music cue guidance: bundled preset at
  `~/.claude/skills/brag/assets/music/cues/happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json`
  (tempo 109.96, beat 0.5456s, preset window 0-25s). Beats past 25s extrapolated on the
  same grid and verified with `npx hyperframes beats`.
  **Strong-cue locks (3):** 13.11s ring halo, 17.47s protein bar full, 22.93s personal-bests row.
  **Beat-grid runs:** 11.46/12.02/12.55 (Train tiles), 15.29/15.84/16.38 (Eat tiles),
  22.37/22.93/23.46 (Progress rows), 32.19/32.74 (Privacy rows).
- Audio-reactive treatment: subtle — radial wash opacity and phone shadow depth follow
  music RMS at low amplitude. No waveform, equalizer, particles or pulsing type.
- Audio-coupled moments:
  - Phone arrival (3.82) — soft drop
  - Train tiles + ring halo — beat grid, then one glass accent on the strong cue
  - Eat tiles + bar fill — beat grid, then one soft click as the bar settles
  - Progress rows — beat grid, one glass accent on the strongest cue in the track
  - Privacy rows — beat grid
  - Outro wordmark — one soft bell
- SFX selection guidance: `interface/drop_001-003` for card and headline arrivals,
  `impact/impactGlass_light_001-002` for the two delicate landings, `ui/click1` for
  the bar, `interface/bong_001` for the wordmark. **All well below the app-store preset's
  0.65-0.75** — cap SFX at 0.50 — because the brand does not tap loudly. No stingers,
  no whooshes, no risers, nothing that sounds like a target being hit.
- SFX analysis guidance: `~/.claude/skills/brag/assets/sfx/sfx-analysis.md` — prefer
  low high-frequency-risk files throughout, since every cue here is a polished repeat.
- Audio files: copied into `composition/assets/music/` and `composition/assets/sfx/`

## HyperFrames Instructions
Built to the `hyperframes-core` contract: standalone root (no `<template>`), one paused
GSAP timeline registered on `window.__timelines["ownhub"]` after the build, root sized
by `data-width`/`data-height` with `width/height: 100%`, `data-duration` on the root,
`class="clip"` + `data-start`/`data-duration` on timed elements, no CSS initial transform
paired with a GSAP tween on the same property, no `crossorigin` on media, every `<audio>`
with an `id`, no clip element tweened with `autoAlpha`/`visibility`, `@font-face` to the
shipped local Rubik TTFs, no render-time clock, no unseeded random, no `repeat: -1`.
`npx hyperframes check` must pass with zero findings before render.
