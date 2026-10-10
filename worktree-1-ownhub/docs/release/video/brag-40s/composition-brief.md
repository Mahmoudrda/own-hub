# Hyperframes Composition Brief: Own Hub

## Objective
A 45-second vertical launch film for Own Hub, a women-only fitness app for Egypt, cut from real screen recordings of the shipping app playing inside a drawn device.

## Output
- Composition directory: `docs/release/video/brag-40s/composition/`
- Rendered video: `docs/release/video/brag-40s/brag.mp4`
- Format: vertical, 1080x1920, 30fps, 45.000s, 1350 frames

## Source material
- **Footage**: `assets/footage/` — nine of the ten clips from `docs/release/video/footage/`, native 1320x2868, 30fps CFR, no audio track. Tap offsets and pixel coordinates come from that folder's `timings.md`.
- **Stills**: `assets/screens/` — four captures at 1206x2622 for the beats that were not filmed: `20-why-we-check`, `21-community`, `30-about-phases`, `24-her-plan`.

## Copy that must appear verbatim
- "We read your national ID card." / "The card itself says you are a woman." / "We never guess from your face."
- "Your logs, your weight, your photos." / "They never leave your phone."
- "Four questions. Then the week is yours."
- "Training by cycle phase is not supported by the evidence."
- "You are paying a person, not a subscription." / "She keeps 80%."

## Creative direction
- Tone: polished. Controlled imperfection inside a highly disciplined premium interface.
- Avoid: gradients, glow, drop shadows, neon, stock-fitness clichés, generic SaaS language, em dashes and en dashes, ratings, download counts, testimonials, named people, prices other than the 80% split, medical claims, "AI", "powered by", anything that ranks women.

## Visual identity
- Paper `#FFF8F9` - Ink `#241C1F` - Rose `#B4526E` - Sage `#4E6A5A`
- Rubik 400/500/600 (local TTF), La Belle Aurore 400 for one- and two-word annotations only

## Hyperframes implementation
Monolithic standalone composition. One paused GSAP timeline registered at `window.__timelines["main"]` after `document.fonts.ready`.

**The device** is drawn in CSS: a 652x1385 body in ink, 74px outer radius, a 1.5px `rgba(255,248,249,0.15)` hairline rim inset 3px, three side buttons protruding 5px, and a tight contact shadow. Nothing branded. The screen is a 624x1357 window at 60px radius, which is both sources' aspect, so nothing is ever cropped. The device carries **no `data-start`**: a `<video data-start>` may not sit inside a plain timed ancestor, so its visibility is driven by GSAP opacity instead of by a clip window.

**The shots** are fifteen media clips inside the screen — eleven `<video>` (all `muted`; `lint` errors otherwise) and four `<img>` — each timed with `data-start` / `data-duration` / `data-media-start`. Hard cuts, no dissolves: with live footage a cut reads as an edit. The stills are held genuinely still, with no push.

**The tap rings** are twelve divs positioned from `timings.md` pixel coordinates, mapped by 624/1320 across and 1357/2868 down. Each fires 0.06s before the frame on which the pressed control moves: in over 0.14s to full, then out over 0.34s while expanding to 1.3x. They carry hard paper outlines inside and out (zero blur) so they read on paper and on a rose primary button alike. They are animated purely by GSAP, with no clip window of their own.

**Thirteen text clips** sit above the rule at y=442; each band fades over the last 0.30s of its beat. Hand marks are SVG paths drawn with `strokeDashoffset`, using a `2L / 3L` dash pattern so `vector-effect: non-scaling-stroke` cannot leave a tail visible before the draw.

## Audio
- `assets/music/bed.mp3`, from happy-beats-business-moves-vol-12 (109.96 BPM), trimmed to 45.2s with gain and fades baked in by ffmpeg so the render needs no automation lane.
- Four SFX: `drop_002` (0.10), `switch2` (30.56), `bong_001` (33.25), `drop_001` (42.56).
- Beat locks: strong cues at 17.47s and 42.56s; beat grid at 4.91, 19.66, and 38.73 / 39.29 / 40.38.
