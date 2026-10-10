# Flutter handoff

What a Flutter team needs to build this, and what is deliberately not decided here. Generated files in
this folder come from the same source as the mockup, so they cannot drift from the screens.

| File | What it is |
|---|---|
| `app_tokens.dart` | Colour roles, type scale, radii and motion durations, generated from `src/tokens.mjs`. |
| `app_routes.dart` | One route per screen, generated from the screen inventory. |
| `app_en.arb` / `app_ar.arb` | Every UI string in English and Modern Standard Arabic, generated from the translation dictionary. |

## Shape of the app

- **Flutter 3.x, Material 3** (`useMaterial3: true`). The design is Material by construction:
  navigation bar with a pill indicator, top app bars, filled/tonal/outlined/text buttons, chips,
  bottom sheets, snackbars.
- **Fonts:** Rubik for both scripts (`pubspec.yaml` asset, weights 400/500/600/700). Arabic renders
  two points larger with more line height — wrap body styles in a locale-aware helper rather than
  hard-coding sizes per screen.
- **Icons:** Material Symbols Rounded. The mockup embeds the SVGs; in Flutter use the
  `material_symbols_icons` package or ship the same SVGs with `flutter_svg`.
- **Localisation:** `flutter_localizations` + ARB files, `supportedLocales: [en, ar]`,
  `Directionality` follows the locale. Arabic is **Modern Standard Arabic**, readable by any Arabic
  speaker, addressed to a woman in the second person feminine. Directional icons must mirror — the
  list is in `i18n.mjs` (`RTL_CSS`): back, forward, chevrons, send, play, skip, swap.
- **Numbers stay Western** (`+20 100 555 0132`, `1,800 EGP`) inside Arabic text. Set
  `textDirection: TextDirection.ltr` on isolated numeric spans, as the mockup does.

## State the screens assume

One shared store; the mockup keeps it in memory, production will not.

| Record | Fields the screens read |
|---|---|
| Profile | goal, days, session length, place, equipment, allergies, dietary preferences, language |
| Verification | result, method, date, reviewer path; never the ID images |
| Cycle setup | mode (dates+symptoms / symptoms only), context flags, adaptation toggles, sharing switches |
| Period entry | start, end or still-bleeding, edited-at |
| Daily check-in | date, energy, cramps, appetite, sleep, bloating, bleeding — all nullable, per day |
| Weekly goal | sessions target, counted weeks, rest weeks banked, current run |
| Workout log | session id, assignment version, per-set actual weight/reps, skipped flag, duration |
| Meal log | slot, item, servings, time, source (planned / search / voice / photo) |
| Coaching relationship | coach, subscription dates, service hours, status, sharing choices |
| Plan | version, draft/published, dated workout and meal assignments, approved alternatives |
| Review | due date, answers, coach response, linked plan revision |
| Conversation | messages, attachment references, send/read state |
| **Post** | author, group, kind (photo / reel / story / best), media refs, blur flag, caption, counts, parent post |
| **Follow-up** | parent post id, media ref, blur flag, caption, taken-at, cost summary (sessions, counted weeks) |
| **Follow graph** | follower, followee, created-at — counts only, never a ranking |
| **Portfolio** | coach, version, published flag, ordered blocks, theme |
| **Portfolio block** | id, type, order, visible flag, per-type payload |
| **Portfolio theme** | seed colour, type pairing, corner radius scale |
| **Client result** | coach, client, consent state, consented-at, withdrawn-at, media refs, blur flag, numbers, quote |
| **Ad creative** | portfolio ref, format (feed / story / reel-cover), headline, body, CTA, media ref |
| **Split** | coach, name, cycle length (3–7 days), ordered day slots (session template ref or rest), carry-approved-substitutions flag |
| **Assessment** | coach, client, taken-at, stage, birth type, clearance flag + date, avoid list, pain/injury notes, screening items (pass / modify / refer), baseline measures |
| **Re-assessment** | parent assessment, taken-at, per-measure before/after, unresolved referrals |

Rules the UI depends on, which belong in the domain layer rather than the widgets:

1. A prescribed value is never a result. Actual entries start empty.
2. A plan revision applies to future dates; a running session and existing logs keep their version.
3. Logging twice on the same planned meal corrects the log; a second helping is a separate action.
4. Suggestions come from today's check-in, never from an inferred cycle phase.
5. Severe symptoms suppress the training suggestion and show the support state.
6. Sharing switches are independent, default off, and revoke the coach's derived panels when turned off.
7. Undo windows are five seconds; there are no confirmation dialogs for logging.
8. **Face blur defaults to on** for every uploaded image, in the community and in coach media alike,
   and is applied on-device before upload. Turning it off is an explicit per-image action.
9. **A follow-up always belongs to a parent post.** It never creates a standalone before-and-after,
   and it can only be attached by the author of the parent post.
10. **A client result is publishable only while consent is active.** Withdrawal hides it immediately
    and everywhere, including from already-rendered ad creatives.
11. **Follower counts are displayed, never ranked.** Nothing in the product sorts women by followers,
    weight lifted, or weight lost.
12. **A split is a template, not a plan.** Applying one writes dated assignments onto a client's month;
    editing the split afterwards never reaches back into a plan that has already been published.
13. **The assessment is the only source of a client's constraints.** The `avoid` list and allergies that
    the coach's planning screens display must come from here or from the client's own intake — never be
    entered directly on a coach screen, or the two will disagree.
14. **A screening outcome of `refer` is not a failure state.** It suppresses matching exercises from
    assignment and stays visible on re-assessment until it is cleared.
15. **Saving a re-assessment never edits a published plan**, for the same reason a chat message never
    does. It records; the coach then revises and publishes.
16. **First-run screens are states, not routes.** `T06`, `E09`, `M17` (client) and `K24`, `W11`, `B14`
    (coach) are the day-one renderings of Home, Eat, Community, coach Today, Clients and the portfolio.
    In Flutter they are branches inside those same routes, chosen when the underlying collection is
    empty — not separate destinations. Do not add navigation to them.
17. **The empty state is the onboarding.** There is no tour, no overlay and no tutorial mode anywhere
    in this product. Each empty state states what will appear, why it is empty, and offers the single
    smallest action that starts it. If a future screen can be empty, it needs one of these before it
    ships.

## The portfolio block model

The coach page is an ordered list of blocks, not a template. Flutter should render it from data so a
new block type never requires a new screen.

```jsonc
{
  "version": 4,
  "published": true,
  "theme": { "seed": "#B4526E", "type": "calm", "corners": "soft" },
  "blocks": [
    { "id": "b1", "type": "cover",   "visible": true,
      "payload": { "layout": "text-over-photo", "media": "m1", "overlay": 0.62,
                   "headline": "…", "subline": "…" } },
    { "id": "b2", "type": "about",   "visible": true,  "payload": { "paragraphs": ["…"] } },
    { "id": "b3", "type": "method",  "visible": true,
      "payload": { "steps": [ { "title": "…", "body": "…" } ] } },
    { "id": "b4", "type": "offers",  "visible": true,
      "payload": { "offers": [ { "name": "…", "price": 1800, "currency": "EGP",
                                 "lines": ["…"], "badge": "most-picked" } ] } },
    { "id": "b5", "type": "results", "visible": true, "payload": { "resultIds": ["r1"] } },
    { "id": "b6", "type": "video",   "visible": false, "payload": { "media": "m7" } }
  ]
}
```

Block types the builder offers: `cover`, `about`, `method`, `offers`, `results`, `testimonials`,
`video`, `gallery`, `certificates`, `faq`, `availability`, `freebie`, `numbers`, `cta`. A type may
appear more than once. `visible: false` hides a block without discarding its payload. Reordering is a
change to the array only. The client-facing coach profile (`H02`) renders exactly this list — there is
no second, hand-built layout to keep in sync.

**Theme:** `seed` drives a Material 3 `ColorScheme.fromSeed`; `type` selects a text-theme pairing;
`corners` scales `AppRadius`. Validate contrast on the seed before accepting it — the builder promises
it will not let a coach pick unreadable text.

## Screens

`app_routes.dart` lists every screen with its flow. Suggested structure: one feature folder per flow
(`signup`, `onboarding`, `today`, `train`, `eat`, `cycle`, `coached`, `progress`, `community`,
`coaching`, `account`, `coach-setup`, `coach`, `coachbrand`, `coachplan`), each with `presentation/`,
`domain/`, `data/`.

## What is simulated in the mockup, and must be built for real

- Identity verification (Valify or uqudo SDK), including the woman-reviewer queue.
- Push notifications and the one-a-day meal nudge with a lock-screen action.
- Walk and workout detection via Health Connect and HealthKit.
- Voice notes: recording, upload, playback, and Arabic transcription for food logging.
- **On-device face blur before upload**, for community posts, follow-ups and coach media.
- **Video capture and playback for reels and stories**, with a 24-hour expiry job for stories.
- **The follow-up prompt**, scheduled from the age of a woman's earliest post.
- **Consent requests for client results**, including withdrawal that propagates to published ads.
- **The four-week re-assessment reminder**, scheduled from the date of the last assessment.
- Payments (card, mobile wallet, Fawry) and coach payouts.
- Video delivery with download-for-offline and low-data mode.
- Moderation queue and the one-hour response promise.

## The assistant (post-launch feature)

The in-app assistant is **grounded selection, not generation**. It picks from the 124-move video
library and the verified Egyptian food library and cannot invent an exercise, an ingredient or a
quantity. The research reason is specific: LLMs that draft recipes and amounts at runtime invent
quantities, while selection from a verified store cannot. Screens: `X01`, `X02`, `X03` (client),
`K26`, `K27` (coach).

**Where it runs.** Flutter calls *your* backend; the backend calls Claude. **The API key never ships
in the app** — an extractable key is a billing and abuse hole. Dart has no official Anthropic SDK, so
the backend uses the SDK for whatever language you pick (Python/TypeScript/Go/Java/Ruby/C#/PHP) or
raw HTTP against `POST https://api.anthropic.com/v1/messages` with headers `x-api-key`,
`anthropic-version: 2023-06-01`, `content-type: application/json`.

**Models.** `claude-opus-5` for answers and plan drafting ($5 / $25 per MTok input/output, 1M
context). `claude-haiku-4-5` for the cheap pre-flight guardrail classifier ($1 / $5, 200K). Send
`thinking: {type: "adaptive"}` and set `output_config: {effort: "low"}` for ordinary lookups,
`"high"` for a 30-day draft. Stream any request that can produce a long draft.

**Grounding is enforced by the tool schema, not by the prompt.** Every tool carries `strict: true`
with `additionalProperties: false` and a full `required` list, so arguments are schema-valid and can
only reference IDs that exist:

| Tool | Returns | Why it exists |
|---|---|---|
| `search_exercise_library` | move IDs from the 124-move library, filtered by equipment, quiet, minutes, body area | the only way a move can be suggested |
| `search_food_library` | verified food items with verified macros, allergens excluded server-side | the only way a quantity can be stated |
| `get_client_context` | goal, days, equipment, avoid list, allergies, coach-approved alternatives | constraints applied **before** selection |
| `propose_swap` | writes a today-only swap | changes one session, never the plan |
| `draft_plan` / `draft_meal_week` | writes a **draft** | a coach opens and publishes it herself |

**There is no publish tool.** Publishing is the human act that changes a plan — the same rule the
rest of this product enforces. Do not add one.

**Guardrails.** Run the Haiku classifier first; if the request is medical, diagnostic, or unsafe
("give me something intense despite my injury"), do not call the main model — return the `X02` state.
Also check `stop_reason` before reading `content`: on a policy decline it is `"refusal"`, with a
category in `stop_details`. Guardrails reduce programming errors; they cannot diagnose an injury or
replace clinical judgement, and the copy on `X02` says so.

**Caching.** The library catalogue and the system prompt are the stable prefix — put
`cache_control: {"type": "ephemeral"}` on the last block of it and keep the user's question after it.
Render order is `tools` -> `system` -> `messages`; any byte change in the prefix invalidates
everything after. Verify with `usage.cache_read_input_tokens` — if it stays zero, something in the
prefix is varying per request.

**Data minimisation (PDPL).** Send only the question, equipment and the avoid list. Never the name,
photos, weight, ID result, or cycle data — cycle data reaches the assistant only if she turns on
sharing, and `X03` states exactly this.

**Naming.** The brief's guardrail is *"do not call anything AI unless that feature has shipped"*, so
the in-product name is **Assistant** and the word "AI" is absent from every screen. Revisit that with
the owner before launch if it should change.

## Not decided here

Backend, database, auth provider, analytics, media hosting, and the moderation tooling. The mockup
states the rules the interface promises; the platform choices are yours.
