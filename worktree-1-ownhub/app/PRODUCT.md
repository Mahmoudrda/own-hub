# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Women in Egypt who want to train, most often at home and sometimes in a ladies-only gym. They use the
app in **Arabic and English roughly equally** — neither is a translation of the other.

A second audience arrives with Phase 3: **women coaches**, who build programmes and portfolios and work
with clients inside the same app. Membership is women-only in both roles.

## Product Purpose

Help a woman train consistently, week to week, on her own terms: quiet home workouts she can do without
disturbing a household, food she already cooks rather than a diet she has to adopt, training that adapts
to her cycle, a community she can trust, and women coaches when she wants one.

Success is that she keeps coming back because it fits her life — not because a counter told her she
would lose something.

## Positioning

- **Women only, and checked.** Members are verified against a national ID; the ID and selfie images are
  deleted after the check, and she is told so.
- **It refuses the category's pressure tools.** No ranking of women against each other, no daily
  streaks, no calorie countdowns, no weight-loss claims, no red "you failed" states. Progress counts
  **weeks, not days**, and a missed day is never marked.
- **Cycle-aware by design**, with that data private by default and never visible to a coach.
- **Arabic and English are equals**, not a primary language and a translation.

## Operating Context

- A personal phone — frequently a budget Android handset, also iPhone.
- Used at home, often quietly, around family and neighbours; also in ladies-only gyms.
- Logging is fast and one-handed: tap, say it, or type it; undo instead of confirmation dialogs.
- Right-to-left Arabic and left-to-right English in the same product; the language can change at any time.

## Capabilities and Constraints

- **Flutter, one codebase, shipping to iOS and Android.** The app uses **one custom brand design
  language on both platforms**. It does not switch to Material or Cupertino styling per OS — "adaptive"
  above records that both platforms' conventions (safe areas, back gestures, text scaling, touch
  targets) apply, not that the look changes by platform.
- **Light theme only.** There is no dark mode today.
- **161 built screens** across sign-up, onboarding, today, train, eat, cycle, progress, account,
  community, coaching, portfolio, planning, the assistant and an admin console.
- **Feature flags** gate every Phase 3 flow; `account` and `onboarding` can never be switched off.
- **Colour and type tokens are generated** from `6-v2/src/tokens.mjs` into
  `lib/theme/app_tokens.dart`. Anything hand-written must live in its own files or regeneration
  erases it.
- **Numbers are Western digits in both languages.**
- **No backend is connected yet**; data is held in memory. Firebase wiring is a separate, pending step.
- **3,468 automated tests** cover behaviour and product rules; visual work must keep them green.

## Brand Commitments

- **Name:** Own Hub.
- **Logo:** the rose-filled square carrying the meditating-figure mark, with the name "Own Hub". The
  owner confirmed this is the mark to keep. It is not to be redrawn or replaced.
- **Palette:** the existing brand colours are binding. Their proportions and layering may change; the
  hues may not be replaced.
- **Icons:** the existing icon set stays. It may be framed or accented, never swapped for another library.
- **Illustrations:** the 57 owner-supplied illustrations in `assets/art/` are the product's artwork.
- **Voice:** calm, plain and specific. It explains rather than warns, never blames, never shouts.

## Evidence on Hand

- **No real users, testimonials, reviews, metrics or customer names exist.** None may be invented.
- **No content library is authored yet** — exercises, foods, recipes and programmes are empty.
- The owner's illustrations (`assets/art/`) and the written store copy and legal drafts
  (`docs/release/`) are real.
- **Never show a figure that is not hers.** A number invented for a mockup, shown as if it were her
  data, is the defect this product works hardest to remove.

## Product Principles

1. **She is never ranked or compared.** Nothing orders women by body, followers or results.
2. **Weeks, not days.** Consistency is measured kindly; there is no streak to lose and no failure mark.
3. **Only her own numbers.** If a value is not real, it is withheld rather than invented.
4. **Her body, her data, her control.** Privacy is the default; sharing is always her choice.
5. **Both languages are first-class.** Nothing may work, read or look better in one than the other.

## Accessibility & Inclusion

- Readable at large system text sizes; contrast is never traded for decoration.
- Generous touch targets; nothing decorative intercepts a tap.
- Screen-reader semantics intact; decorative artwork is hidden from assistive technology.
- Reduced-motion preferences respected.
- Every layout, mark and gesture must work correctly in right-to-left Arabic.
