# Own Hub — browse-and-test plan

Date: 2026-09-22 · Status: in progress

## What the owner asked for

1. Turn authentication and account creation off with a flag, and open the app straight onto Home.
2. Be able to browse every part of the app without an account — meals, workouts, community, the
   coach side, how a coach builds a portfolio, how a woman browses coaches, and everything else.
3. Before that: plan it (this file), QA it (the QA report next to this file), fix what is broken.

## Where things stood (measured, not assumed)

Two read-only surveys of `lib/routing/app_router.dart` and a tap-everything crawler (every control on
every screen, tapped once) showed that the screens are built but much of the running app is a shell:

| Area | State before this work |
|---|---|
| Entry | The app always opened on sign-up (C01). The only role was trainee, so the coach side could not be reached. |
| Eat | Logging works and E01 shows it. T01's meal card never reflects Eat; the after-log screen (E04) loads before the log lands. |
| Workouts | The mid-set screen is always "goblet squat, set 2 of 3". Sets never advance; finishing never counts toward the week; T01, R01, P01 disagree on the week. |
| Community | Nothing can be posted. Likes, saves, follows, comments, joins, filters, report and mute are not wired. |
| Coach portfolio | Adding sections works; every editor (cover, look, offers, method, results, media) drops her edits; Publish is disabled. |
| Browse coaches | The directory is hard-wired to "unavailable", the coach profile to "nothing written", packages to none. Nothing can be paid for or enquired about. |
| Coach desk and clients | No enquiry ever arrives, the client list is always empty, planner edits are dropped, "Publish the plan" (W08) opens a "not built" page. |
| Coached life (G) | Always shows prototype content; most screens have no way in. |
| Cycle | Mostly works. Home's cycle card never appears. |
| Admin console (Z) | Reachable only by a deep link. |
| Placeholders | W08, B12, X02, K22, H06, T08 are in the route table but open "not built". |
| Across the app | Screens are drawn once from shared data, so after "back" they show stale content. Community avatars of other women act as HER role switch. The coach side has no way back to the trainee side. Back buttons have no name for screen readers. Selection on chips and choices is not announced. |

## The plan

### Phase 0 — foundations (main thread)
- **`Feature.accountRequired`, off.** Boots to Home (T01) as a guest who holds both roles. Sign-up still
  exists to be looked at; it is simply not a gate. Recorded in the flags test so switching it back on
  before release is a visible change. *(Done.)*
- **Redraw on change.** One app-wide change signal; every routed screen redraws when shared state
  changes, so nothing is stale after "back".
- **Testing aids (only while no account is required):** "Your profile" in the role switcher, the
  switcher on the coach side too, and an **All screens** index that opens any of the 161 screens —
  including sign-up, onboarding and the admin console.
- **Strings:** a locked helper so several workers can add English + Arabic strings without
  overwriting each other (the translation files are generated).
- **Accessibility fixes found by the crawler:** named back buttons; selection announced on chips,
  segments and chosen cards. *(Done.)*

### Phase 1 — make each feature actually work (parallel workers, one area each)
| Worker | Owns | Must prove with journey tests |
|---|---|---|
| A | Today, Train, Progress | Start a session → log sets that advance → rest → finish → the week count, points and progress agree on T01, R01, P01, R10. |
| B | Eat | Log by type, by plate and from a recipe → E01 and T01's meal card show it → undo works → week plan and grocery list. |
| C | Community | Write a text post → it is in the feed, on her profile and opens as a post → like, save, comment, follow, join a group, report, mute, filters. |
| D | Coach setup, portfolio, marketplace | Coach fills basics/packages → builds and edits her page (every editor saves) → publishes → as a trainee, finds her in the directory → opens the page → packages → test payment or enquiry reaches the coach. |
| E | Coach desk, planning, coached life | Enquiry arrives on the coach desk → accept → she is a client → plan a month → publish (W08) → the client sees the plan, trains it, logs a planned meal, chats, gets a weekly review. Runs after D. |
| F | Cycle, account, assistant, admin, sign-up | Cycle card on Home after setup; notifications and profile show real state; assistant explains it is not connected yet; admin console reachable and its forms save; every sign-up/onboarding screen reachable from the All screens index. |

Rules for every worker: reuse the existing domain code; no invented people, reviews or figures (the
coach directory shows coaches created in this session, plus the sample rows the codebase already
has); payment uses a clearly labelled **test** provider only while no account is required (Paymob is
not connected); keep all 3,468 existing tests green; Arabic and English both.

### Phase 2 — verification (main thread)
1. The crawler again: no tap throws, no tap lands on a placeholder, and every "no visible effect"
   is either explained or fixed.
2. The full test suite and the analyzer.
3. On the iPhone simulator, in English and Arabic: walk each journey above and screenshot it.
4. Write `02-QA-REPORT.md` next to this file: what was tested, what was found, what was fixed, what
   is still not possible without an outside service (payment, SMS, ID check, the assistant's model),
   and a short guide to testing by hand.

## Before any public release
Switch `Feature.accountRequired` back ON (`lib/domain/flags/feature_flags.dart`), and the test
payment provider and the All screens index disappear with it.
