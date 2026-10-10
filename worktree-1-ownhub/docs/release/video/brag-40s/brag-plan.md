# Brag Plan: Own Hub

## What is this app?
Own Hub is a women-only fitness app for Egypt: membership is verified from a national ID card rather than guessed, personal data stays on the phone, setup is four questions, training adapts to symptoms she reports instead of to a calendar, and coaching is bought from a real woman who keeps 80% of the fee.

## The angle
Most fitness apps say "for women". This one can show what that costs to build, and now it shows the app being *used*: a real screen recording of the real product, taps and all. Four questions and she is training. Five true, checkable claims, each one answered by a real screen.

## Hook (first 2-3 seconds)
Paper, ink type, nothing else. "Women only." lands alone at 0.10. Then "Checked, not guessed." under a hand-drawn wobbly line. The device rises under it at 1.05.

## Format: vertical - 1080x1920, 30fps
## Duration: 45.000 seconds (owner-approved extension from 40s for the live footage and the new setup beat)

## Source material
- **Live**: ten screen recordings of the real app on the simulator, 1320x2868 at 30fps CFR, in `docs/release/video/footage/`. Tap offsets and pixel coordinates from that folder's `timings.md`.
- **Still**: four captures at 1206x2622 for the beats that were not filmed.

## The device
Drawn in CSS, 652x1385, ink `#241C1F`, 74px radius, 14px bezel, hairline rim, three side buttons, tight contact shadow. The screen is 624x1357, which is both captures' aspect, so nothing is ever cropped. Centred, paper on all four sides.

## Tap indicator
A rose ring, 78px, appearing 0.06s before the frame on which the pressed control moves and fading over half a second. Hard paper outlines inside and out, zero blur, so it reads on paper and on a rose primary button alike. Positioned from the pixel coordinates in `timings.md`, mapped by 624/1320 across and 1357/2868 down.

## Visual identity
- Paper `#FFF8F9` - Ink `#241C1F` - Rose `#B4526E` - Sage `#4E6A5A`
- Rubik 400/500/600; La Belle Aurore for one- and two-word annotations only
- Hatching, fine ink hairlines, four wobbly hand marks. No gradients.

## Audio
- `assets/music/bed.mp3`, from happy-beats-business-moves-vol-12 (109.96 BPM), trimmed to 45.2s, gain 0.30, 1.8s fade in, 2.9s fade out from 42.2s.
- Four SFX only: hook line (0.10), the set logged (30.56), the session finished (33.25), the wordmark (42.56).
- Beat locks: strong cues at 17.47s (the evidence line) and 42.56s (the wordmark). Beat grid at 4.91, 19.66 and the 38.73 / 39.29 / 40.38 coaching sequence.
- No audio-reactive treatment: it would fight the restraint.

## Storyboard

| # | beat | in - out | source | on-screen text |
|---|---|---|---|---|
| 1 | Hook | 0.00 - 2.70 | still `20-why-we-check` | "Women only." / "Checked, not guessed." |
| 2 | The card | 2.70 - 7.50 | still `20-why-we-check` | "We read your national ID card." / "The card itself says you are a woman." / "We never guess from your face." |
| 3 | The room | 7.50 - 9.40 | still `21-community` | "Faces arrive blurred." (sage) |
| 4 | Privacy | 9.40 - 12.80 | **live** `08-privacy` | "Your logs, your weight, your photos." / "They never leave your phone." |
| 5 | Setup | 12.80 - 17.20 | **live** `00-setup` x2 | "Four questions. Then the week is yours." |
| 6 | Not phases | 17.20 - 21.30 | still `30-about-phases` | "Training by cycle phase is not supported by the evidence." / "Symptoms are." |
| 7 | How she feels | 21.30 - 24.70 | **live** `07-cycle` | "So it asks how you feel." |
| 8 | Then you choose | 24.70 - 28.10 | **live** `07-cycle` | "Then you choose." / "her call" |
| 9 | One tap | 28.10 - 32.30 | **live** `02-session`, `03-mid-set` | "One tap logs the set." |
| 10 | Done | 32.30 - 34.80 | **live** `04-finish` | none; the screen says "That's Thursday done" |
| 11 | Meals | 34.80 - 38.50 | **live** `05-tabs`, `06-eat` | "Meals in the size you actually serve." |
| 12 | Coaching | 38.50 - 42.55 | still `24-her-plan` | "Real coaches. Real plans." / "You are paying a person, not a subscription." / "She keeps 80%." |
| 13 | Own Hub | 42.55 - 45.00 | **live** `09-home-again` | "Own Hub" (hand underline) / "Arabic and English." |

Nine live beats, four still. The stills are held still: no fake push, no fake motion.

## The twelve taps

| at | beat | control |
|---|---|---|
| 11.56 | privacy | "Show my personal bests" switch |
| 13.59 | setup | Days a week "4" |
| 14.76 | setup | Minutes a session "30" |
| 21.91 | cycle | Energy "Low" |
| 24.31 | cycle | Cramps "Moderate" |
| 25.54 | cycle | "Save check-in" |
| 29.01 | session | "Start, everything's ready" |
| 30.56 | mid-set | "Done · 12 reps" |
| 32.92 | finish | "Finish here" |
| 35.62 | tabs | the Eat tab |
| 36.88 | eat | "Log" beside the koshari bowl |
| 42.80 | home | the Home tab |

Every ring lands while its beat's headline is settled on screen.

## Share copy (draft)
Own Hub is a women-only fitness app for Egypt. Membership is read off a national ID card, not guessed from a face. Four questions and she is training.
