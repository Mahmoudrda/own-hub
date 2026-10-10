# UI/UX review — pass 1 on the built v2

The reviewer agent could not run (the account hit its session limit), so this review was done in this
session against the built screens: 87 rendered at 2× and checked mechanically for clipping, link
integrity, contrast and type size, then read screen by screen against the owner's direction — smooth,
doable, animated, fun, lovely, girly, pink, minimal, Google's visual style.

## Verdict

The product is buildable as drawn. The riskiest parts are not visual: Egyptian-Arabic food parsing,
the ID-verification integration and moderation staffing. The design direction holds together because
the pink carries surfaces rather than decoration, and because celebration is rationed to one screen.

## What was measured

| Check | Result |
|---|---|
| Screens rendered | 87 of 87, no render errors |
| Navigation links | 0 broken targets, 0 dead-end screens |
| Content clipped inside the phone frame | 6 screens found → all fixed |
| Text below the 12px floor | 14 instances (placeholder labels) → all raised |
| Text contrast (13 pairings) | 12 passed AA; amber on its container failed at 2.81:1 → darkened to `#8A5A17` |
| Reachable by tapping from the first screen | 85 of 87; T04 and T05 are Monday scenarios, reachable from the chapter list |

## Issues found and fixed

1. **Progress overflowed by 305px.** Three list rows became a three-tile row, the tier rule became a
   single line, and the week strip merged with the eight-week history. [fixed]
2. **Community feed overflowed by 99px.** Photo height 150 → 100, post spacing tightened, one filter
   chip dropped, copy trimmed. [fixed]
3. **Today overflowed by 36px.** The greeting became one line carrying the level pill, which also put
   her tier on the home screen where it answers "what is my level?" without a tap. [fixed]
4. **Settings, Eat and the quiet-week screen clipped by 3–29px.** Row padding and body gaps tightened. [fixed]
5. **The code screen had no way forward** — the auto-check left no tappable continue. Added. [fixed]
6. **The coach path had no entry from sign-up.** "I'm a coach — set up my profile" now leads from the
   verified screen into coach setup. [fixed]
7. **The follow-along video and the voice box were unreachable** by tapping. Wired from the Train hub
   and from the microphone in the one box. [fixed]
8. **The lock-screen nudge was unreachable.** It is now opened from the notifications list, which is
   also where someone would go to turn it off. [fixed]
9. **Placeholder labels sat at 11px.** Raised to 12px. [fixed]
10. **Amber failed contrast on its own container.** Darkened; personal bests and coach queues keep
    the colour and now pass AA. [fixed]

## Kept deliberately, with reasons

- **Five labelled tabs at 12px labels.** Material's own navigation label size is 12px, and five 78px
  targets fit 390px. The alternative costs a tap on meal logging.
- **A status bar drawn inside each frame.** It is the existing wireframe vocabulary from Phase 1 and
  the team reads the mockups that way; on a real device the system draws it.
- **Calories still visible per item.** Removing them entirely would break weight-loss users; what was
  removed is the daily countdown that turns going over into failure.

## Risks worth a decision before build

1. **Egyptian-Arabic speech to food items** is the hardest thing in the product. Ship typing first
   (same box, same parser), add voice when the accuracy is real on Egyptian dialect.
2. **Walk detection** needs Health Connect on Android and HealthKit on iOS, with a permission screen
   that is not drawn yet because it is a system dialog. Treat as "soon after", not launch.
3. **Face blur** must run on-device before upload, or the promise is false the moment a photo leaves
   the phone.
4. **Video on Egyptian mobile data** — the download-for-offline row is the mitigation, and it needs a
   real CDN budget.
5. **ID verification** is a contract and a licence, not a sprint: Valify or uqudo, a data-processing
   agreement, and PDPC registration before launch.
6. **Moderation** promises an hour. That is a staffing commitment, and the Safety Centre states it on
   screen — change the copy or fund the rota.

## Still open, for the next pass

- Empty states for a first-week user (no history, no plates, no bests) are implied but not drawn.
- Error states for a failed verification and a declined payment are named in copy but not drawn.
- The Arabic right-to-left mirror of each screen is specified in the type rules but only demonstrated
  on the language screen and the voice screen.
