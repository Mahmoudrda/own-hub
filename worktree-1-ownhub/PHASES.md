# Build phases — Own Hub

161 screens, both roles, split into three phases. The split is by **dependency and
demonstrability**, not by screen count: each phase ends with something you can open on a phone and
judge, and nothing in a later phase is required for an earlier one to work.

Every phase ends green: `flutter analyze` clean, `flutter test` passing, both platforms building.

---

## Phase 1 — She can get in, and she can train

**42 screens.** The vertical spine. Everything else in the product sits on top of this, so it is built
first and proven end to end before anything is built beside it.

| Flow | Screens | |
|---|---|---|
| Sign-up & verification | C01–C16 | 16 |
| Setup & starting programme | O01–O05 | 5 |
| Today & logging | T01–T08 | 8 |
| Train & the workout player | R01–R13 | 13 |

**Also in phase 1, because nothing works without it:** the repository layer, the auth abstraction, the
Firestore wiring, and the fakes that let all of it be tested without a live project.

**Done when:** a woman can install the app, verify she is a woman, answer the setup questions, receive
a starting programme, open today's session, and log a set in one tap — offline, in Arabic or English,
on either platform. The P0 verification and logging cases become executable tests.

**What it proves:** the whole architecture in one slice — auth → security rules → repository →
offline queue → view model → screen → test. If this pattern is right, the remaining 119 screens are
repetition rather than invention.

**Owner dependencies:** the six-digit code decision (D-pending), a Firebase project on a billing
account, and the ID-verification provider contract. The app is built against a fake provider until
that contract exists, so the build is never blocked by it.

---

## Phase 2 — Her whole day, and her privacy

**31 screens.** Completes the solo experience, including the most sensitive data in the product and
the legal obligations attached to it.

| Flow | Screens | |
|---|---|---|
| Eat & food logging | E01–E09 | 9 |
| Progress & rewards | P01–P04 | 4 |
| Profile, privacy & Safety Centre | A01–A04 | 4 |
| My Cycle | Y01–Y14 | 14 |

**Done when:** she can log a meal by typing, speaking or tapping her usual; her week counts and a rest
week repairs a missed one; she can see her progress, export her data, and delete her account such that
nothing survives. Cycle is private by default and never reaches analytics.

**Why here and not phase 1:** Eat and Progress depend on the logging and week machinery phase 1
builds. Cycle depends on the daily check-in. Deletion depends on every collection existing, which is
why it cannot be done earlier — a deletion manifest written before the collections exist is a
manifest that silently misses some.

**Owner dependencies:** allergen and diet tags on the food library, and contraindication tags on every
exercise. Without them the safety guards are decorative — they are content, and they are on the
critical path.

---

## Phase 3 — Everything involving another person

**88 screens.** The social and commercial half. Largest by count, and deliberately last because it is
the part most exposed to decisions that are still open.

| Flow | Screens | |
|---|---|---|
| Community | M01–M17 | 17 |
| Coaching marketplace & coached life | H01–H06, G01–G17 | 23 |
| Coach application | K01–K06, K07–K25 | 13 |
| Portfolio builder | B01–B14 | 14 |
| Coach planning tools | W-flow | 16 |
| The assistant | X01–X03, K26, K27 | 5 |

**Done when:** a woman can find a coach, pay her, be coached; a coach can build her own page, design
splits and meal plans, assess a client and publish a plan; the community works with blur on by
default; and the assistant answers from the libraries or refuses.

**Why last:** two open questions can reshape it. If Apple classifies coaching as digital content, the
80/20 split is arithmetically impossible on iPhone and the payment flows change shape. And the
assistant is a ~$4,860/month line whose model choice is still undecided. Building this first would
mean building it twice.

**Note on phase 1:** the first-week arc (T07) has two steps that live in Community. They are built in
phase 1 and route to screens that say "not built yet" until phase 3 — honest, and preferable to
special-casing the arc twice.

---

## Sequence inside a phase

Same order every time, because it is the order that catches mistakes early:

1. **Repository interface and its fake** — the feature becomes testable before any UI exists.
2. **Domain rules** with their tests, from `6-v2/plans/`.
3. **View models**, tested without widgets.
4. **Screens**, matched against the prototype.
5. **The P0 cases for that flow** become executable tests.
6. **Firestore rules and indexes** for the collections touched, extended and re-verified.

The build stays green at every step. A phase is not finished while anything is red.


---

## Status on 6 October 2026

All three phases are built. Release 2 (D28) is the launch build: sign-up and verification are on,
and everything involving another person stays behind its flag. Engineering is finished on
`council/2026-10-02`.

**Tests:**
- 4,628 app tests.
- 893 backend tests.
- 289 database rules tests.
- 11 storage rules tests.

**Builds:**
- Android release builds compile.
- iPhone release builds compile.

**What is left is not code:**
- the store accounts and the 14-day closed test;
- the lawyer and the data protection permit;
- the pilot and the women reviewers;
- Rahma's allergen sign-off;
- then deploy and submit.

The ordered list is the "Your steps" tab in `docs/release/OWN-HUB-BEFORE-PROD.xlsx`.
