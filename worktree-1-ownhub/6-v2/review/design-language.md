# v2 design language — pink, Material 3, minimal

The owner asked for an app that feels smooth, doable, animated, fun, lovely, girly, pink and minimal,
in Google's visual style. This is the spec the build follows. Accessibility rules from Phase 1 are
kept: body text never below 16px, Arabic set 2px larger with more line height, touch targets 44px and
up, Western digits kept in order inside right-to-left text.

## Colour — Material 3 roles, pink family

Seeded from the Phase 1 rose so the brand does not change identity, then completed into full M3 roles.

| Role | Hex | Used for |
|---|---|---|
| primary | `#B4526E` | Primary buttons, active nav icon, focus rings |
| onPrimary | `#FFFFFF` | Text on primary |
| primaryContainer | `#FFD9E3` | Nav active pill, tonal buttons, my chat bubble |
| onPrimaryContainer | `#4A1C2E` | Headings, text on primaryContainer |
| primaryDim | `#A8455F` | Text-only buttons, small icons on surface |
| secondaryContainer | `#F5E3E8` | Quiet fills |
| tertiary | `#4F7359` | Progress, success, "counted", coach-safe green |
| tertiaryContainer | `#DDEDE1` | Sage cards: confirmations, protective messages |
| amber / amberContainer | `#C1802F` / `#FBEBD6` | Personal bests, waiting states, coach queue |
| error / errorContainer | `#A84A4A` / `#FBE0E0` | Destructive only. Never used for a missed day |
| surface | `#FFF8F9` | App background (warm pink-white) |
| surfaceLowest / Container / High | `#FFFFFF` / `#FBEAEF` / `#F6E3E9` | Cards, filled fields, headers |
| onSurface | `#241A1E` | Body text |
| onSurfaceVariant | `#6B5C61` | Secondary text, inactive icons |
| outlineVariant | `#EBDCDF` | Borders and dividers |
| inverseSurface / inverseOnSurface | `#37292E` / `#FFECF0` | Snackbars, video screens, lock screen |

**Contrast, measured** (WCAG 2.1, normal text needs 4.5:1):

| Pairing | Colours | Ratio | AA |
|---|---|---|---|
| Body text | `#241A1E` on `#FFF8F9` | 16.15:1 | pass |
| Body text on card | `#241A1E` on `#FFFFFF` | 16.91:1 | pass |
| Secondary text | `#6B5C61` on `#FFF8F9` | 6.02:1 | pass |
| White on primary | `#FFFFFF` on `#B4526E` | 4.80:1 | pass |
| Heading on primaryContainer | `#4A1C2E` on `#FFD9E3` | 10.88:1 | pass |
| Text button | `#A8455F` on `#FFF8F9` | 5.45:1 | pass |
| White on tertiary | `#FFFFFF` on `#4F7359` | 5.34:1 | pass |
| Text on tertiaryContainer | `#1E3826` on `#DDEDE1` | 10.48:1 | pass |
| White on error | `#FFFFFF` on `#A84A4A` | 5.61:1 | pass |
| Amber on amberContainer | `#C1802F` on `#FBEBD6` | 2.81:1 | FAIL |
| Snackbar text | `#FFECF0` on `#37292E` | 12.18:1 | pass |
| Nav label inactive | `#6B5C61` on `#FFF1F4` | 5.75:1 | pass |
| Nav label active | `#4A1C2E` on `#FFD9E3` | 10.88:1 | pass |

**Pink without sugar.** The pink carries the surfaces and the containers; saturation stays low on
anything large, and the one strong pink is reserved for the single primary action per screen. Girly
comes from warmth, roundness and generous space, not from decoration.

## Type — Rubik, Latin and Arabic in one family

Rubik is served by Google Fonts with a full Arabic set, so both scripts share one voice and one
vertical rhythm, and the whole family is embedded (12 subset files, ~340 KB) so nothing needs the network.

| Style | Size / line-height / weight | Used for |
|---|---|---|
| display | 32 / 40 / 600 | One per screen, the question or the win |
| headline | 26 / 33 / 600 | Screen titles |
| title large | 20 / 26 / 600 | Card titles, tab titles |
| title medium | 17 / 23 / 600 | List rows |
| title small | 15 / 20 / 600 | Labels above data |
| body | 16 / 24 / 400 | Everything she has to read |
| body medium | 15 / 22 / 400 | Secondary lines |
| nav | 12 / 16 / 500 | Navigation labels only (Material's own label-medium) |

Arabic renders 2px larger with roughly 1.28× line height. Numerals stay Western and isolated so
prices and phone numbers keep their order inside RTL text.

## Shape, space, elevation

- Radii: 8 (chips inside cards), 12 (small), 16 (list rows, media), 20 (cards), 28 (bottom sheets,
  big confirm button), 999 (buttons, chips, pills, nav indicator).
- Phone frame 390 × 844; side margin 16px; 12px between cards; 24px between sections.
- Elevation is mostly tonal: cards sit on surfaceLowest against a surface background with a 1px
  outlineVariant border. Real shadows only on sheets (`0 8px 24px rgba(36,26,30,.12)`), the snackbar
  and the lock-screen notification.
- Touch targets: 44px minimum, 48px for icon buttons, 56px for primary actions.

## Icons

Material Symbols Rounded, weight 400, embedded as SVG paths (Apache-2.0) so they work offline. Filled
variant marks the active navigation item, outlined everywhere else. 124 icons are bundled.

## Components

- **Navigation bar** — 5 client tabs (Home, Train, Community, Eat, Coaching), 4 coach tabs. Active
  item gets a 56×32 `primaryContainer` pill behind a filled icon, label 12px. Five labelled tabs fit
  390px at 78px each.
- **Top app bar** — 64px, 48px lead icon, title 17/600. Close (×) for modals, back (←) for pushes.
- **Buttons** — filled (primary, 56px), tonal (secondary actions), outlined (alternatives), text
  (tertiary, 44px). One filled button per screen, in the bottom third.
- **Big confirm** — 84px, 26px radius, two lines: what will be saved, and what happens next. Only for
  logging a set.
- **Cards** — outlined by default; filled for quiet grouping; sage for anything protective or
  confirming; amber for waiting or a win; tonal pink for an offer.
- **Chips** — 40–44px pills; selected takes primaryContainer with a 1.5px primary border. Chips are
  how values are changed, ahead of steppers and keyboards.
- **Bottom sheets** — 28px top radius, drag handle, scrim `rgba(36,26,30,.45)`. Default for anything
  short: swap a move, change a set, report, "I already did it".
- **Snackbar** — inverseSurface, 5-second undo, replaces confirmation dialogs everywhere.
- **Fields** — filled, 60px, label inside, 2px primary border on focus, error text under.
- **Progress** — linear bars for goals, segment bars for the week, conic rings for timers and
  percentages.

## Motion

Durations: 150ms (press), 220ms (chips, snackbar), 320ms (screen push, sheet), 460ms (celebration).
Easing: `cubic-bezier(.2,0,0,1)` for entering, `cubic-bezier(.3,0,.8,.15)` for exiting,
`cubic-bezier(.34,1.56,.64,1)` for anything that should feel pleased with itself.

| Moment | Animation |
|---|---|
| Screen push | Slide 24px + fade, 320ms |
| Tab switch | Cross-fade 220ms; the nav pill slides between tabs |
| Bottom sheet | Slide up 320ms, scrim fades 220ms |
| Set logged | Button scale 0.98 → 1, check mark springs in, rest ring starts |
| Meal logged | Slot fills, protein bar animates to its new width over 460ms, snackbar slides up |
| Points | Count up from the old total, 460ms |
| Level bar | Fills to the new percentage, 460ms, after the points land |
| Week segment | Fills when a session is saved |
| Tier change | The tier name cross-fades once; no fanfare on a slip |
| Finish screen | The single confetti burst in the product, 900ms, once |
| Press states | Every tappable dims 4% for 150ms |
| Reduced motion | All of the above become instant; nothing is lost |

Haptics: a light tap on set logged and meal logged, a double tap on a personal best, nothing else.

## Fun and lovely, without infantilising

- The app is warm because it is specific: "Two more sessions and the week counts", not "You've got this!".
- Celebration is rationed: one confetti screen, one milestone toast, nothing on routine actions.
- Nothing is ever red because she missed something. Red is for destructive actions only.
- No baby-talk, no exclamation marks in system copy, no emoji in the interface.
- Illustration is line-drawn and simple; photography is food and movement, never a body being judged.
