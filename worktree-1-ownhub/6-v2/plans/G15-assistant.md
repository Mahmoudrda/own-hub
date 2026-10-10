# G15 — The assistant

**Screens (5):** `X01` Ask · `X02` When it will not answer · `X03` What it can and cannot do ·
`K26` Plan draft · `K27` Meal draft.

**Owns:** the Cloud Function `assistantAsk` / `assistantDraft`, the tool registry, the guardrail
classifier, and `assistantQuota/{uid}`. **Writes no woman's data and no coach's data, anywhere.**

Written against `DECISIONS.md` (D1 — the assistant ships; `BUILD-BRIEF.md` §0 ignored),
`BUILD-BRIEF.md` §2/§3/§4/§7, `SCHEMA-SPINE.md` §1–§8, `flutter/HANDOFF.md` §"The assistant" and
rules 1–17, `plans/RECONCILIATION.md`, and the bundled Anthropic documentation
(`claude-api` skill: `shared/tool-use-concepts.md`, `shared/prompt-caching.md`,
`typescript/claude-api/{README,tool-use}.md`). API shapes below are verified against those files,
not recalled.

**Rejection-contract map** — 1 data model §1 · 2 call path + cost per screen §2 · 3 state machines §3 ·
4 offline §4 · 5 owned rules + enforcement point §5 · 6 security rules as code + the Function's auth
check §6 · 7 interface to other groups §7 · 8 test rows §8 · 9 open questions §10. Scalability gate
§9. Cost ceiling §2.4.

**Four decisions everything else follows from:**

| # | Decision | Why |
|---|---|---|
| D1 | **The Function never writes Firestore on the assistant's behalf.** It returns a validated payload; the *owning group's* existing service performs the write on the author's device, after her tap. | One writer per collection (spine §2). It makes "the assistant stores nothing" (spine §8) literally true and makes rule 2 unbreakable: there is no server path from a model token to a published plan. |
| D2 | **The model returns IDs and a template key. It never returns a number.** Every quantity on screen is looked up from the local library pack by `exerciseId` / `foodId`. | Rule 10 becomes *structural*: an invented quantity is unrenderable, because no field on the wire can carry one. A prose-level guard would be a prompt instruction, which the brief forbids. |
| D3 | **The cheap classifier runs first and the expensive model is never called on a medical question.** | X02 is the most important screen: it must refuse, not hedge. It also cuts the per-interaction cost of the refusal path by 97% (§2.2). |
| D4 | **The subject (whose context is read) is bound at the Function from `request.auth`, never from a tool argument.** | A model cannot pivot to another woman's data, because no tool takes a uid. |

---

## 1. Data model

### 1.1 What is NOT stored, and why

This is the first table on purpose. Spine §8: *"The assistant stores nothing."*

| Not stored | Where it would have gone | Why not |
|---|---|---|
| The question, the answer, the conversation | `users/{uid}/assistantThreads/*` | PDPL data minimisation. A question like *"my knee hurts on squats"* is health data the product has no purpose for once answered. It also creates a disclosure surface (A02 export, a coach view) that X02's promise — *"Nothing was logged and nothing was shared"* — would then be false about. The conversation lives in memory for the lifetime of the X01 route and is discarded on pop. |
| Any transcript of tool calls or model output | Cloud Logging | Logs are a copy. Only `{requestId, uid, route, verdict, usage{}, latencyMs, libVersion}` is logged — no free text, ever. |
| Her name, photos, weight, measurements, ID result, phone, cycle data, check-ins | the model payload | §5 rule P3. `lifeStage` is *also* excluded: it reaches the model only as derived tokens inside `avoid[]` (`high_impact`, `deep_knee_flexion`), so the clinical fact never travels while the constraint still applies. |
| `uid` | the model payload | Used server-side for authz and quota; stripped before the API call. Anthropic receives no identifier that maps to a woman. |
| A drafted plan or meal week | any G15 collection | D1. `K26` lands in `plans/{clientUid}/versions/{vN}` with `status:'draft'` via **G2's** `PlanDraftService.create`; `K27` lands in **G14's** `coaches/{coachUid}/mealDrafts/{draftId}` (§7, requested). Both are the *author's* own draft collection, per spine §8. |

### 1.2 The one collection G15 owns

`assistantQuota/{uid}` — **NO CLIENT ACCESS, Function-only.** Not under `users/**`, so it is not part
of her document and never appears in an export of her content.

| Field | Type | Notes |
|---|---|---|
| `dayKey` | string `yyyy-MM-dd` | device-local day at the moment of the call (G8 `AppClock.dayKey()`) |
| `count` | int | `FieldValue.increment(1)` inside the same transaction that reads it |
| `draftCount` | int | coach route, separate ceiling |
| `expireAt` | timestamp | +48 h; Firestore TTL policy deletes the document |

> **Named deviation, flagged not hidden (§9 Q1).** Spine §8 says the assistant stores *nothing*. This
> document stores a **count**, never content. Without it, any signed-in handset can loop the endpoint
> and the §2.4 bill is unbounded — the cost hole that the "no key in the bundle" rule closes on
> extraction but not on abuse. Deterministic id, TTL-deleted, no query, no index. Spine owner to
> confirm the wording, not the mechanism.

### 1.3 Fields G15 requires from other groups (requests, not additions)

| Collection | Field | For | Owner |
|---|---|---|---|
| `exercises/{exerciseId}` | `primaryMuscle`, `equipment[]`, `quiet`, `floorOnly`, `minutes`, `contraindications[]` | `search_exercise_library` filtering | content pipeline / G4 |
| `foods/{foodId}` | `allergens[]`, `dietTags[]`, `sizes[{id,label,grams}]`, `kcal`, `proteinG`, `costEGP`, **`verified`** | `search_food_library`; `verified:false` rows are never returned, so K27 offers a dish without totals rather than with invented ones | content pipeline / G5 (already G5's open Q10) |
| `assessments/{assessmentId}` | `avoid[]`, `screening[].outcome` | the avoid list applied **before** selection (HANDOFF r13, r14) | G14 |
| `plans/{uid}/assignments/{date}` | `workout.approvedAlternatives[]` | `propose_swap` candidate set ("already approved by Sara") | G2 |

---

## 2. Call path and cost, per screen

### 2.1 Where it runs

```
Flutter ──callable(App Check + ID token)──► Cloud Functions gen2 (europe-west1)
                                              │  auth ▸ quota ▸ payload allowlist
                                              ├─► Claude Haiku 4.5   (guardrail, always)
                                              └─► Claude Opus 5      (only if verdict == in_scope)
                                                    │ tools: library search (server-local pack)
                                                    ▼
                                            validated payload ──► device ──► her tap ──► G2/G4/G14 write
```

**The key never ships in the app** (§7 of the brief). `ANTHROPIC_API_KEY` is a Secret Manager secret
bound to the two functions (`defineSecret('ANTHROPIC_API_KEY')`); it is not in Remote Config (client-
readable), not in `firebase_options.dart`, not in an env file in the bundle. An APK is a zip: anything
in it is public.

### 2.2 Models, parameters, and cost per interaction

Verified against the bundled docs: Opus 5 is `$5 / $25` per MTok, 1M context, thinking **on by
default** (`{type:"adaptive"}`), `output_config.effort` `low`→`max`, cache minimum **512 tokens**.
Haiku 4.5 is `$1 / $5`, 200K, takes `{type:"enabled", budget_tokens:N}` **and errors on
`output_config.effort`** — so the classifier sends neither (no thinking, no effort field). Cache
minimum on Haiku 4.5 is **4096 tokens**, so the 400-token classifier prefix is deliberately *not*
cached — a `cache_control` marker there would be a pure write premium with zero reads.

| Route | Model | Params | Stream? |
|---|---|---|---|
| Guardrail | `claude-haiku-4-5` | `max_tokens: 64`, `output_config.format` (enum verdict), no `thinking`, no `effort` | no |
| X01 answer | `claude-opus-5` | `thinking:{type:"adaptive"}`, `output_config:{effort:"low", format: AnswerSchema}`, `max_tokens: 4000` | no |
| K26 / K27 draft | `claude-opus-5` | `thinking:{type:"adaptive"}`, `output_config:{effort:"high", format: DraftSchema}`, `max_tokens: 32000`, `eager_input_streaming:true` on every tool | **yes** (128K-class outputs require streaming; a 30-day draft would otherwise risk an HTTP timeout) |

Effort is **pinned per route, never varied per request** — a change to `effort` or `thinking`
invalidates the messages cache (and, on some models, tools+system too).

**Cached prefix** (identical bytes for every woman, because §1.1 removed everything per-user from it —
data minimisation and cache hit rate are the same property here):

| Block | Tokens | `cache_control` |
|---|---|---|
| `tools` — frozen array, sorted by name | ~1,500 | — (renders first) |
| `system` — role, refusal policy, template catalogue, the 124-move compact catalogue | ~4,300 | `{"type":"ephemeral"}` on the **last** system block |
| `messages` — her question, her equipment, her avoid list | ~60 | none (varies per request; a marker here would write an entry nobody reads) |

Order is `tools` → `system` → `messages`. The 4,100-food library is **not** in the prefix — it is
behind `search_food_library`; only the 124 moves are small enough to inline.

| Screen | Firestore | Haiku call | Opus call | Turns | Cost / interaction |
|---|---|---|---|---|---|
| `X01` in-scope question | 1 read + 1 write (quota txn) | 1 (~400 in / 8 out) | 1 conversation | 2 (tool + answer) | **$0.020** |
| `X01` → `X02` medical/unsafe | same | 1 | **0 — never made** | 0 | **$0.0005** |
| `X02` model-side refusal (slipped the classifier) | same | 1 | 1, `stop_reason:"refusal"` | 1 | ≤ $0.010 |
| `X03` | **0** | 0 | 0 | 0 | **$0.00** — static screen, works offline |
| `K26` 30-day plan draft | 2 reads (assessment, split) + quota | 1 | 1 | ~6 | **$0.22** |
| `K27` 7-day meal draft | 1 read (assessment) + quota | 1 | 1 | ~4 | **$0.08** |

X01 working: cached read 2 × 5,800 tok @ $0.50/MTok = $0.0058; uncached 780 tok @ $5 = $0.0039;
output 370 tok (incl. adaptive thinking at low effort) @ $25 = $0.0093; classifier $0.0005.

### 2.3 Monthly cost at §3's numbers (35,000 DAU)

Stated assumption, because none exists in the brief (§9 Q2): **15% of DAU open X01 on an active day,
1.4 questions each** → 7,350/day → **220,000 questions/month**; 8% of them are medical or unsafe.

| Line | Volume / month | Cost |
|---|---|---|
| Guardrail classifier, every question | 220,000 | $110 |
| X01 full interactions | 202,400 × $0.019 | $3,846 |
| Refused before the expensive call | 17,600 × $0 | $0 |
| `K26` plan drafts | 3,000 × $0.22 | $660 |
| `K27` meal drafts | 3,000 × $0.08 | $240 |
| Functions gen2 (226k invocations, draft compute) | — | ~$3 |
| Firestore quota transactions | 226k r + 226k w | ~$0.55 |
| **Assistant total** | | **≈ $4,860 / month** |

**This is the finding that matters.** `RECONCILIATION.md` §3 puts *all* infrastructure at $75–95/month
and names ID verification ($2.6k–8.5k) as the largest line. At the adoption above, **the assistant is
the second-largest operating cost in the product — ~50× the entire Firebase and CDN bill.** Said here
rather than at the end, as §3 of the brief requires.

### 2.4 Cost ceiling at 100k MAU, and what happens when it is exceeded

**Enforced ceiling: $5,000/month.** 100k MAU *is* the 35k DAU above, so the uncapped figure is the
figure. Two caps and a four-step ladder, all server-side, all Remote Config (`kill_switches.assistant`,
`assistant_daily_cap`, `assistant_draft_cap`, `assistant_budget_state` — registered in **G8's** key
registry, §7):

| Cap | Value | Enforced at |
|---|---|---|
| Per woman, per day | 5 questions | `assistantQuota` transaction, before any model call |
| Per coach, per day | 6 drafts | same |

| Spend | State | Behaviour |
|---|---|---|
| < 70% | `normal` | as specified |
| 70% | `tighten` | `assistant_daily_cap` 5 → 3. The screen says she has reached today's questions and offers *Ask Sara instead* — which X01 already presents as a first-class action, not a fallback. |
| 85% | `deferDrafts` | K26/K27 move to the **Message Batches API (50% cheaper)**; the draft is not interactive, so the screen shows "your draft will be ready shortly" and G8's push delivers it. Client questions unaffected. |
| 100% | `off` | `kill_switches.assistant = true`. X01's entry point is replaced by *Ask Sara*; **X03 stays readable** (it is static and needs no call), so the honest description of the feature survives the feature being off. |

**No auto-downgrade of the model.** Sonnet 5 ($2/$10) would cost ≈$0.008/question → ≈$1,750/month, and
Haiku 4.5 would serve pure library lookups at ≈$0.004. Both are owner decisions about answer quality,
not something this plan takes silently (§9 Q3).

---

## 3. State machines

### 3.1 The conversation (X01 / X02) — 9 states

```
        idle ──ask──► classifying ──in_scope──► grounding ⇄ (≤4 tool turns) ──► answering ──► answered
          ▲               │                         │                              │            │
          │               ├─medical/severe/unsafe──►│                              │         ask again
          │               │                    refused (X02)                       │            │
          │               ├─classifier error──► unavailable                        │            ▼
          │               └─quota exceeded────► capped                     refused (X02) ◄──stop_reason
          └────────────────── pop route / no signal ──► offline ◄───────────────────────────────┘
```

| From | Event | To | Effect | Screen |
|---|---|---|---|---|
| `idle` | send | `classifying` | callable invoked; input disabled; typing indicator | X01 |
| `classifying` | verdict `in_scope` | `grounding` | Opus call opens; ≤4 tool iterations, hard cap | X01 |
| `classifying` | `medical_diagnostic` \| `severe_symptom` \| `unsafe_request` \| `emergency` | `refused` | **no Opus call**; §3.2 | **X02** |
| `classifying` | classifier error / timeout | `unavailable` | **fail closed** — never fall through to Opus; generic unavailable + *Ask Sara* | X01 |
| `classifying` | `count >= cap` | `capped` | *Ask Sara instead* | X01 |
| `grounding` | tool result has zero rows | `answering` | `answerKey: assistantNothingFound` — **returns nothing rather than inventing one** | X01 |
| `grounding` | `stop_reason == "tool_use"`, iteration 5 | `answering` | loop capped; answers with what it has or `assistantNothingFound` | X01 |
| `grounding`/`answering` | `stop_reason == "refusal"` | `refused` | §3.2 | **X02** |
| `grounding`/`answering` | `stop_reason == "max_tokens"` | `unavailable` | never render a truncated pick list | X01 |
| `answering` | validated payload | `answered` | picks rendered; numbers looked up locally (D2) | X01 |
| any | connectivity lost | `offline` | §4 | X01 |
| `answered` | pop the route | `idle` | **conversation discarded** (§1.1) | — |

### 3.2 The refusal path — 5 states, and it is a path, not a dialog

```
  detected ──► classified ──► routed ──► escalated ──► closed
   (server)     (category)    (X02)     (Y11 or H06)   (idle)
```

| State | Owner | Behaviour |
|---|---|---|
| `detected` | Haiku verdict, **or** Opus `stop_reason:"refusal"` with `stop_details.category` | Two independent detectors. `stop_details` is populated **only** on a refusal — it is `null` for every other stop reason, so it is always guarded before it is read. |
| `classified` | Function | `medical_diagnostic` → X02 copy A · `severe_symptom` → copy B, which is HANDOFF rule 5's medical-guidance state · `emergency` → copy B with the care route promoted above the fold · `unsafe_request` ("something intense despite my injury") → copy C |
| `routed` | X02 | Refusal sentence, then *"This needs a doctor, not an app"*, then **Find care near you** (`Y11`) and **Message Sara** (`H06`). Never a hedge, never a partial answer, never a "but generally…". |
| `escalated` | G9 / G11 | Y11 is G9's medical-guidance screen; H06 is G11's conversation. Both are ordinary routes — nothing about the refusal is special-cased downstream. |
| `closed` | X02 | The card *"What I did with that message"*: nothing logged, nothing shared. True by construction (§1.1), not by copy. |

**Server-side fallbacks are deliberately OFF.** Opus 5 supports `fallbacks` with beta
`server-side-fallback-2026-07-01`, which re-runs a declined request on another model inside the same
call. This product *wants* the refusal. Routing around it would defeat X02, so the parameter is not
sent. Recorded so that a future engineer does not "fix" the refusal rate by enabling it.

### 3.3 The draft (K26 / K27) — 5 states

`composing` → `grounded` (avoid list + allergens applied, then selection) → `validated` (every id
exists in the pack; every quantity resolvable) → `held` (payload on the coach's device, nothing
written) → `opened` (she taps *Open in my planner*; **G2/G14** writes the draft) | `discarded`.

There is no transition out of `held` that reaches `PUBLISHED`. That transition belongs to G2's
`PlanPublisher.publish` and is reachable only from a coach's explicit publish tap (G2 §3.1).

---

## 4. Offline behaviour

It needs a live call. That is stated, not worked around.

| Screen | No signal | What the UI does |
|---|---|---|
| `X01` | cannot work | Composer disabled with a stated reason — *"Asking needs a connection."* No spinner, no queue, **no retry-on-reconnect of a question she may no longer be asking.** The *Ask Sara instead* button stays **enabled**: G11's messages are `users`-adjacent and offline-writable, so the human path works on a microbus and the machine path does not. That inversion is the honest one. |
| `X02` | reachable | If a refusal was already rendered, it stays; the **Find care** and **Message Sara** routes are local navigations and work offline. Y11's content is bundled. |
| `X03` | **fully works** | Static content, zero calls. The screen that explains the boundaries is the one that never needs the network — deliberate, and it is what stays visible when `kill_switches.assistant` is on. |
| `K26` / `K27` | cannot start | *"Drafting needs a connection."* A draft already `held` on the device survives backgrounding and **can be opened into the planner offline** for `K27` (G14's local write) but **not** for `K26` (`plans/**` is server-authored, spine §5) — K26's *Open in my planner* queues the intent in G8's local sqflite outbox and states that it will land when she is back. |

**Nothing the assistant produces is ever part of the offline write queue**, because the assistant
writes nothing (D1). The queued item is always the *owning group's* command.

`serverDegraded` (G8 §6.3) is distinct from `offline` and shows G8's `ErrorPresenter` copy plus
*Ask Sara*, never a raw error.

---

## 5. The §2 rules G15 owns, and the exact enforcement point

| Rule | Enforcement point — schema-level or server-side, never a prompt |
|---|---|
| **10 — selects, never generates** | **(a)** Every tool carries `strict: true`, `additionalProperties: false`, and a complete `required` list, so arguments are schema-valid by construction. **(b)** The response is constrained by `output_config.format` to `{answerKey: <enum of ARB keys>, picks: [{kind, id, sourceLabel}], escalate: bool}` with `additionalProperties:false` — **there is no field on the wire that can carry a number or a free-text ingredient.** **(c)** `AssistantResponseValidator.validate()` on the server drops any `id` absent from the versioned library manifest; zero surviving picks → `assistantNothingFound`. **(d)** The device renders every quantity from the local pack row keyed by that id (D2). A hallucinated `foodId` yields no row, therefore no gram. |
| **10 — no publish tool** | The registry is a frozen `const TOOLS` of exactly the names in §7.1, asserted by a unit test on `Object.keys`, a CI grep for `publish` in the tool module, and — the part code review cannot forget — **the function's service account has no IAM permission to invoke G2's publisher and no write permission on `plans/**`**. A prompt injection that says "publish it" reaches an endpoint it cannot call. |
| **2 — a message never changes a plan; publishing does** | D1: the Function returns a payload. The only write path is a coach tap on K26/K27 → `PlanDraftService.create` → `status:'draft'`. G2's state machine has no auto-publish edge (G2 §3.1). |
| **5 — severe symptoms replace the suggestion with medical guidance** | The Haiku verdict is `severe_symptom` **before** any suggestion is composed, and that verdict short-circuits the Opus call entirely (§3.2). The suggestion is not generated and then suppressed; it is never generated. |
| **4 — suggestions follow logged symptoms, never an inferred phase** | Cycle data is not in the payload allowlist (§1.1). The assistant cannot infer a phase from data it does not receive. `X03` states this, and it is true because of the allowlist, not because of the copy. |
| **P3 (PDPL) — data minimisation** | `AssistantPayloadSchema` is a `strict` JSON Schema with `additionalProperties:false`, validated **server-side after assembly and before the HTTP call**. The assembler is a pure function with no access to the user document; it takes a typed `AssistantSubject` carrying only the allowlisted fields. A denylist scan (`name`, `weight`, `kg`, `cycle`, `period`, `nationalId`, `photo`, `uid`) runs over the serialised body in debug and in CI. |
| **Brief guardrail — the word "AI" is off-screen** | The product name is **the assistant**. A CI lint fails the build if `\bAI\b`, `A\.I\.`, or `ذكاء اصطناعي` appears as a token in `app_en.arb` / `app_ar.arb` or in any `answerKey` template. Enforced in the dictionary, not in review. |
| **17 — the empty state is the onboarding** | X01 with no conversation shows what it can be asked (three example questions drawn from X03's "It can" list) and the *Ask Sara* action. No tour, no overlay. |

---

## 6. Security rules as code, and the Function's auth check

### 6.1 `firestore.rules` — G15's fragment

Per spine §2, the `users/{uid}` ruleset is authored **once, by G8**. G15 supplies no `match /users/{uid}`
block at all; it requires no field there. Its own paths:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    // ── G15's only collection: Function-only, never a client ──
    // Reads are billed and counts are cost control; a client that can write this
    // can mint itself unlimited model calls. Denied outright, both directions.
    match /assistantQuota/{uid} {
      allow read, write: if false;
    }

    // ── Assertions G15 makes about paths it does NOT own ──
    // These grant nothing (absence of allow IS denial); they exist so that the
    // emulator suite proves the assistant cannot reach them, and so a reviewer
    // who later adds a permissive block above must explain themselves.
    match /plans/{uid}/versions/{version} { allow write: if false; }   // G2 · rule 2
    match /plans/{uid}/assignments/{date} { allow write: if false; }   // G2 · rule 2
    match /users/{uid}/sessions/{sid}     { allow write: if false; }   // G4 owns the only writer
    match /users/{uid}/meals/{day}        { allow write: if false; }   // G5 owns the only writer
    match /users/{uid}/cycle              { allow read:  if false; }   // C12 · never, sharing or not
    match /users/{uid}/periods/{day}      { allow read:  if false; }   // C12

    // ── Requested from G14 (§7): the coach's own meal-draft collection ──
    match /coaches/{coachUid}/mealDrafts/{draftId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == coachUid
                         && request.auth.token.role == 'coach'
                         && !request.resource.data.keys().hasAny(
                              ['published','publishedAt','status'])   // a draft cannot describe itself as published
                         && request.resource.data.days.size() <= 7;
    }
  }
}
```

Negative tests G15 supplies to the emulator suite: any client read of `assistantQuota/*`; any client
write of it; a coach writing another coach's `mealDrafts`; a `mealDrafts` document carrying
`published: true`; a client (non-coach role) writing `mealDrafts`; a `cycle` read from any path
reachable by the assistant's service account.

### 6.2 The Cloud Function's auth check

Functions gen2, TypeScript, `@anthropic-ai/sdk`. Every gate is before the first token is spent.

```typescript
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import Anthropic from '@anthropic-ai/sdk';

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY'); // Secret Manager. Never in RC, never in the bundle.

export const assistantAsk = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,          // Play Integrity / App Attest. A stolen ID token alone is not enough.
    consumeAppCheckToken: true,     // replay protection
    secrets: [ANTHROPIC_API_KEY],
    serviceAccount: 'assistant-runner@…',  // read-only on Firestore; NO write, NO functions.invoker on the publisher
    timeoutSeconds: 60,
    maxInstances: 40,               // a hard fleet ceiling on concurrent spend
  },
  async (req) => {
    // 1. Identity. No anonymous, no App Check bypass.
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'sign-in required');
    if (!req.app) throw new HttpsError('failed-precondition', 'app-check required');

    // 2. Claims — G1's custom claims, zero document reads (G8 §6.2 convention).
    const t = req.auth!.token as Claims;
    if (t.vexp && t.vexp < Date.now()) throw new HttpsError('permission-denied', 'stale-claims');

    // 3. Subject binding (D4). The subject is derived here and NEVER from a tool argument.
    const subject = req.data.route === 'coach'
      ? await bindCoachSubject(uid, t, req.data.clientUid)   // below
      : { kind: 'self' as const, uid };

    // 4. Quota, transactionally, before any spend.
    await consumeQuota(subject, req.data.route);             // throws 'resource-exhausted' at the cap

    // 5. Kill switch (Remote Config server-side, G8's registry).
    if (await killed('assistant')) throw new HttpsError('unavailable', 'assistant-off');

    // 6. Payload allowlist — PDPL. Throws before the HTTP call if anything else is present.
    const payload = AssistantPayloadSchema.parse(await assemblePayload(subject, req.data.question));

    // 7. Guardrail first (D3). Fail CLOSED: any error here means no expensive call.
    const verdict = await classify(payload.question);        // claude-haiku-4-5
    if (verdict.category !== 'in_scope') return refusal(verdict);   // → X02, zero Opus tokens

    return await answer(payload);                            // claude-opus-5, §7.1 tools only
  },
);

// A coach may draft only for a client she actually coaches, and only from data that client shares.
async function bindCoachSubject(coachUid: string, t: Claims, clientUid?: string) {
  if (t.role !== 'coach') throw new HttpsError('permission-denied', 'not-a-coach');
  if (!clientUid) throw new HttpsError('invalid-argument', 'client-required');
  const rel = await db.doc(`relationships/${relId(coachUid, clientUid)}`).get();
  if (!rel.exists || rel.get('status') !== 'active')
    throw new HttpsError('permission-denied', 'no-active-relationship');   // G11
  if (rel.get('sharing.logs') !== true)
    throw new HttpsError('permission-denied', 'not-shared');               // HANDOFF r6, default OFF
  return { kind: 'client' as const, uid: clientUid, coachUid };
  // Note: sharing.cycle is never consulted, because cycle data is not in the allowlist at all (C12).
}
```

**The four properties this buys:** the key is never on a handset; a signed-in attacker still needs a
genuine app attestation; a compromised prompt runs under a service account that cannot write; and a
coach cannot reach a woman who has not both accepted her and turned the switch on.

---

## 7. Interface to the other groups

### 7.1 The tool registry — six names, two frozen sets, and no seventh

`strict: true`, `additionalProperties: false`, complete `required` on every one. Sorted by name so the
prefix bytes are deterministic (an unsorted tool array is a silent cache invalidator).

| Tool | Route | Input (all required) | Returns | Enforced server-side before returning |
|---|---|---|---|---|
| `get_client_context` | both | `{}` — **empty by design** (D4) | goal, days, sessionLength, place, equipment[], avoid[], allergies[], dietary[], approvedAlternatives[] | subject bound at the Function; cycle, weight, name, photos unreachable |
| `search_exercise_library` | both | `equipment[]`, `quiet`, `maxMinutes`, `bodyArea`, `excludeExerciseIds[]`, `limit` | rows from the **124-move** pack | avoid[] and `screening.refer` items removed **before** ranking (HANDOFF r13, r14) |
| `search_food_library` | both | `query`, `slot`, `excludeAllergens[]`, `dietTags[]`, `maxCostEGP`, `limit` | verified Egyptian food rows | **allergens excluded server-side**, not by prompt; `verified:false` rows never returned |
| `propose_swap` | client | `fromExerciseId`, `toExerciseId`, `reasonKey` | a validated proposal | both ids must exist; `to` must be in `approvedAlternatives` or pass the avoid filter. **Returns; does not write** — see the conflict below |
| `draft_plan` | coach | `days[{dayIndex, kind, exerciseIds[]}]`, `cycleLength` | a validated draft payload | every id exists; avoid[] applied before selection; **no `publish` field exists in the schema** |
| `draft_meal_week` | coach | `days[{dayIndex, slots{breakfast,lunch,dinner,snack}: foodIds[]}]` | a validated draft payload | allergens and dietTags applied before selection; unverified foods carry no totals |

> **Conflict with `HANDOFF.md`, named rather than worked around (§9 Q4).** HANDOFF's table says
> `propose_swap` *"writes a today-only swap"* and `draft_plan` *"writes a draft"*. The spine's
> ownership table gives `users/{uid}/sessions/*` to **G4 alone** and `plans/**` to **G2 alone**, and
> G4's design puts pre-flush swaps in a *local draft* that Firestore never sees before her tap. A
> writing tool would make two writers for one field — a rejected plan by spine §2. **Resolution: the
> tools propose; G4's `SwapService.apply()` and G2's `PlanDraftService.create()` write.** X01's screen
> already shows this — the *Swap* control routes to `R05`, G4's swap screen. The HANDOFF sentence
> should be amended to "proposes".

### 7.2 Consumes

| From | What | Failure mode |
|---|---|---|
| **G4** | the 124-move bundled pack + `libraryVersion`; `SwapService.apply()`; `R05` as the swap destination | pack stale ⇒ the Function validates against its own copy of the same version and drops unknown ids; never invents |
| **G5** | the foods/recipes pack, `allergens[]`, `dietTags[]`, `verified`; `MealLogService` for a logged portion | `allergens[]` missing ⇒ **fail closed**: the food route returns nothing and routes to Sara, matching G5's own allergy posture |
| **G14** | `assessments/{id}.avoid[]`, `screening[]`, `coaches/**/splits/*`; **requested:** `coaches/{coachUid}/mealDrafts/{draftId}` + a `MealPlanDraftService.create()` | no assessment ⇒ K26 refuses to draft rather than drafting without constraints (HANDOFF r13) |
| **G2** | `PlanDraftService.create` (the K26 destination, already in G2 §3.1); `assignments.approvedAlternatives` | — |
| **G11** | `relationships/{relId}.status` + `sharing` for the coach authz check; `H06` as the *Ask Sara* destination | no active relationship ⇒ `permission-denied`, before any spend |
| **G1** | custom claims `{verified, vexp, role, adult}` | stale claims ⇒ refuse |
| **G9** | **nothing.** Cycle is not read, shared or not | — |
| **G7** | `privacy.shareWithCoach` posture; A02 deletion — G15 has one row: delete `assistantQuota/{uid}` | — |
| **G8** | the callable scaffolding, App Check, `ErrorPresenter`, connectivity, `AnalyticsGateway.emit()` (enum-typed — a free-text property is a compile error, so the question can never reach Amplitude); **requested RC keys:** `kill_switches.assistant`, `assistant_daily_cap`, `assistant_draft_cap`, `assistant_budget_state`, `assistant_model` | RC unfetched ⇒ bundled defaults, feature on, caps at their conservative values |

### 7.3 Publishes

Nothing to Firestore. To the app: `AssistantAnswer`, `AssistantRefusal`, `AssistantDraft` — three
immutable value objects, each carrying `libVersion` so a pick can never be rendered against a
different pack than the one it was selected from.

### 7.4 What it may **not** call

**G2's `PlanPublisher.publish` / the `publishStartingPlan` callable.** Enforced three ways: no tool
exposes it; the assistant module may not import G2's publisher (CI import-graph assertion); and the
service account lacks `roles/cloudfunctions.invoker` on it. Publishing stays a human act.

---

## 8. Test cases

Rows in the exact 10-column format of `tests/TEST-CASES.csv`
(`id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope`).
**The CSV is not edited by this plan** — these rows are for whoever owns `scripts/build_testcases.py`.

**Already in the suite and accountable to G15:** `P1-RULE-02` (K26 drafts, never publishes),
`P1-RULE-05` (severe symptoms), `P1-RULE-10` (selects, never generates; no publish tool).
`P1-RULE-10` bundles two distinct failures into one row, so it is split below into two rows that each
fail for exactly one reason.

```csv
P1-RULE-10A,P1,Product rule guard,"X01,K27",App built and running,"Stub the food library so the requested dish is absent, then ask for the portion of that dish; capture the full response payload and the rendered screen","No gram, kcal or portion appears anywhere. The response schema carries no numeric field, the pick list is empty, and the screen shows the nothing-found state. FAILS if any quantity is rendered that did not come from a food library row.",The assistant can never invent a quantity,both,Post-MVP
P1-RULE-10B,P1,Product rule guard,"X01,K26,K27",App built and running,"Enumerate the deployed tool registry for both routes; grep the assistant module for publish; inspect the service account's IAM bindings","Exactly six tool names exist across the two routes and none of them publishes. No import path reaches G2's publisher. The service account has no invoker role on it and no write permission on plans/**. FAILS if a seventh tool, a publish field, or a write binding appears.",There is deliberately no publish tool,both,Post-MVP
P0-ASK-01,P0,Assistant — a grounded answer with its source,X01,"Verified account, plan published, knee on the avoid list",Ask a knee-safe alternative for today's squat,"Two moves appear, each carrying its source chip (her plan or the 124-move library). Every move id exists in the bundled pack. Sets and reps are read from the pack, not from the model response.",The assistant selects and never generates,both,Post-MVP
P0-ASK-02,P0,Assistant — a move that does not exist,X01,App built and running,Ask for a move that is not in the 124-move library,"It returns nothing and says so, and offers Ask Sara. No move is described, named or approximated.",The assistant selects and never generates,both,Post-MVP
P0-ASK-03,P0,Assistant — a swap changes today only,"X01,R05",Session assigned for today,Accept a proposed swap then inspect the published plan,"The swap lands in the local session draft via G4, today only. plans/** is byte-identical. The assistant's own call wrote nothing.",A message never changes a plan — publishing does,both,Post-MVP
P0-ASK-04,P0,Assistant — it refuses a medical question,"X01,X02",App built and running,Ask a diagnostic question about pain and bleeding; capture the outbound API calls,"The refusal state renders with a route to care and to her coach. No hedge, no partial answer. Exactly one model call was made — the classifier — and the expensive model was never invoked.",The assistant refuses medical questions,both,Post-MVP
P0-ASK-05,P0,Assistant — severe symptoms route to medical guidance,"X02,Y11",App built and running,Ask about a severe symptom,"Medical guidance and the route to care replace any suggestion. No workout or meal is suggested at any point, including before the refusal renders.",Severe symptoms replace the workout suggestion,both,Post-MVP
P0-ASK-06,P0,Assistant — a model-side refusal is handled explicitly,X02,"Classifier stubbed to pass, model stubbed to return stop_reason refusal",Send a question that the model itself declines,"stop_reason is read before content. The refusal state renders with stop_details.category mapped to the right copy. No content block is parsed or displayed. No crash and no empty bubble.",Refusals are handled as refusals,both,Post-MVP
P0-ASK-07,P0,Assistant — no signal,X01,Airplane mode,Open X01 and attempt to ask,"The composer is disabled with a stated reason. No spinner, no queued question, nothing retried on reconnect. Ask Sara stays enabled and works offline.",Never a silent failure and never an endless spinner,both,Post-MVP
P0-ASK-08,P0,Assistant — the daily cap,X01,Daily cap set to 2,Ask three questions in one day,"The third is refused before any model call, with the cap explained and Ask Sara offered. The quota transaction shows exactly two model invocations.",Cost control is enforced server-side,both,Post-MVP
P0-ASK-09,P0,Assistant — the avoid list is applied before selection,K26,"Coach with an active client whose assessment says no deep knee bends",Draft a 30-day plan,"No excluded move appears anywhere in the draft. Instrumentation shows the avoid list was applied to the candidate set before ranking, not filtered from a finished draft.",The assessment is the only source of constraints,both,Post-MVP
P0-ASK-10,P0,Assistant — allergies applied first and unverified foods carry no totals,K27,"Client with a nut allergy; one candidate dish has verified:false",Draft a meal week,"No dish containing the allergen is offered at any stage. The unverified dish either does not appear or appears with no totals at all. No total is ever computed by the model.",The assistant can never invent a quantity,both,Post-MVP
P0-ASK-11,P0,Assistant — a draft is a draft,"K26,K27",Draft produced,"Open the draft in the planner, then inspect the client's published plan and her app","The plan version is created with status draft. The client sees no change. Nothing is published until a separate, explicit publish action by the coach.",A message never changes a plan — publishing does,both,Post-MVP
P0-ASK-12,P0,Assistant — PDPL payload allowlist,"X01,X03","Account with a name, weight, photos and cycle data recorded",Ask any question while capturing the outbound HTTPS body,"The body contains only the question, locale, equipment, avoid, allergies, dietary and session constraints. It contains no name, photo, weight, measurement, ID result, cycle data, phone number or uid. FAILS on any other field.",PDPL data minimisation,both,Post-MVP
P0-ASK-13,P0,Assistant — the API key never ships,"X01,K26",Release APK and IPA built,"Unzip the APK and the IPA and grep every asset, string table, native library and Remote Config default for an Anthropic key prefix","No key is present in any artefact. All model calls originate from the Cloud Function. FAILS if a key or a direct api.anthropic.com call exists in the app.",The API key never ships in the app,both,Post-MVP
P0-ASK-14,P0,Assistant — the endpoint rejects what it should,X01,App built and running,"Call the callable with no auth; then with a valid token but no App Check token; then replay a used App Check token","All three are rejected before any model call. Errors are unauthenticated, failed-precondition and failed-precondition respectively. Zero tokens are spent in all three cases.",The backend is the security boundary,both,Post-MVP
P0-ASK-15,P0,Assistant — a coach cannot reach a client she does not coach,K26,"Coach A, client of coach B",Request a draft for coach B's client,"Rejected with permission-denied before any model call. The same call with an active relationship but sharing switched off is also rejected.",Sharing switches are independent and default off,both,Post-MVP
P0-ASK-16,P0,Assistant — the cached prefix is actually being read,X01,Two identical-prefix requests within the TTL,Ask two questions in succession and read usage from both responses,"The second response reports cache_read_input_tokens greater than zero covering the whole shared prefix. FAILS if it stays zero, which means something in the prefix varies per request.",Cost control depends on a stable prefix,both,Post-MVP
P0-ASK-17,P0,Assistant — the guardrail fails closed,X01,Classifier stubbed to time out,Ask an ordinary in-scope question,"The expensive model is never called. An unavailable state renders with Ask Sara. FAILS if a classifier failure falls through to the main model.",A guardrail failure must never open the gate,both,Post-MVP
P0-ASK-18,P0,Assistant — the word AI is absent,"X01,X02,X03,K26,K27",App built and running,"Scan both ARB dictionaries and every answer template for the standalone token AI, A.I. and the Arabic equivalent","No occurrence in English or Arabic, on screen or in any template. The feature is called the assistant everywhere.",Do not call anything AI until it has shipped,both,Post-MVP
P2-RTL-X01,P2,Arabic RTL rendering,X01,Language set to Arabic,Open X01 (Ask) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-X01,P2,Large text / accessibility,X01,OS font size set to largest,Open X01 (Ask) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-X02,P2,Arabic RTL rendering,X02,Language set to Arabic,Open X02 (When it will not answer) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-X02,P2,Large text / accessibility,X02,OS font size set to largest,Open X02 (When it will not answer) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-X03,P2,Arabic RTL rendering,X03,Language set to Arabic,Open X03 (What it can and cannot do) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-X03,P2,Large text / accessibility,X03,OS font size set to largest,Open X03 (What it can and cannot do) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-K26,P2,Arabic RTL rendering,K26,Language set to Arabic,Open K26 (Plan draft) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K26,P2,Large text / accessibility,K26,OS font size set to largest,Open K26 (Plan draft) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-RTL-K27,P2,Arabic RTL rendering,K27,Language set to Arabic,Open K27 (Meal draft) in Arabic,"Mirrored layout, no clipped or overlapping text, directional icons flipped, Western numerals preserved.",,both,Post-MVP
P2-TXT-K27,P2,Large text / accessibility,K27,OS font size set to largest,Open K27 (Meal draft) at maximum system text size,"No text truncated mid-sentence, no control pushed off screen, no overlap. Touch targets stay at least 44pt.",,both,Post-MVP
P2-OFF-X01,P2,Offline behaviour,X01,Airplane mode,Attempt the primary action on X01 with no network,"Refused with a clear message naming the connection. Never a silent failure, never an endless spinner, never a queued question.",,both,Post-MVP
P2-ERR-X01,P2,Server error handling,X01,Backend returns a 500,Trigger the primary action on X01 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. No partial answer rendered.,,both,Post-MVP
P2-OFF-X02,P2,Offline behaviour,X02,Airplane mode,Open X02 from an already-rendered refusal with no network,"The refusal copy and both routes stay usable. Find care and Message Sara are local navigations and work offline.",,both,Post-MVP
P2-ERR-X02,P2,Server error handling,X02,Backend returns a 500 on the classifier,Ask a question against a failing backend,"Fails closed: the unavailable state, never a fall-through to an answer. No raw exception text.",,both,Post-MVP
P2-OFF-K26,P2,Offline behaviour,K26,Airplane mode,Attempt to produce and then open a draft on K26 with no network,"Drafting is refused with a stated reason. A held draft opened into the planner queues the intent and says so. Never a silent failure.",,both,Post-MVP
P2-ERR-K26,P2,Server error handling,K26,Backend returns a 500,Request a draft on K26 against a failing backend,A human-readable error naming the problem and the recovery. No partial draft is shown or written.,,both,Post-MVP
P2-OFF-K27,P2,Offline behaviour,K27,Airplane mode,Attempt to produce and then open a draft on K27 with no network,"Drafting is refused with a stated reason. A held draft opens into the meal planner locally and syncs later. Never a silent failure.",,both,Post-MVP
P2-ERR-K27,P2,Server error handling,K27,Backend returns a 500,Request a draft on K27 against a failing backend,A human-readable error naming the problem and the recovery. No partial draft is shown or written.,,both,Post-MVP
```

**38 rows: 2 P1 (the split of `P1-RULE-10`), 18 P0, 18 P2** — RTL and large text for all five screens,
offline and server-error for the four that make a call. `X03` needs neither, because it makes none.

---

## 9. Scalability gate

| Gate | G15 |
|---|---|
| **Unbounded collection scan** | None. Three document `get`s by deterministic id (`assistantQuota/{uid}`, `assessments/{id}`, `relationships/{relId}`) and zero `.where()` anywhere in this group. The libraries are read from the bundled pack, never from Firestore — 0 library reads per interaction, per the spine's "difference between 7 reads a day and 40". |
| **Fan-out write that grows with followers** | None. G15 performs **zero writes** other than one quota increment on one document keyed by her own uid. Nothing is copied anywhere (C9 is not even reachable from here). |
| **Unindexed hot-path query** | No query exists. Composite indexes required: **none**. One **single-field index exemption** is requested for `assistantQuota.expireAt`'s sibling fields — not needed, in fact, since the document has four scalar fields and no map; recorded so the deployment check has an explicit "nothing here" answer. |
| **A migration to reach 100k MAU** | None. The per-call cost is flat in user count; the quota document is per-user and TTL-deleted; the cached prefix is shared fleet-wide precisely *because* it carries nothing per-user, so the hit rate improves as traffic grows rather than degrading. The one thing that does not scale linearly is **money**, which is why §2.4 makes the ceiling an architectural component with a designed degrade ladder, not a monitoring alert. |
| **Peak (19:00–23:00 Cairo, 40% of traffic)** | 7,350 questions/day → 2,940 in 4 h → **0.2 calls/s fleet-wide**, against `maxInstances: 40` and 60 s timeouts. Firestore load is 0.2 transactions/s spread across distinct per-uid documents: no hotspot, no monotonic key. Anthropic rate limits, not Firebase, are the binding constraint at 10× this — flagged as Q7. |

**Read/write budget impact (spine §4):** +0.06 reads and +0.06 writes per active day (quota, on the
15% of days she asks). The typical day stays at ~7 reads. G15 is the cheapest group in the product on
Firestore and by far the most expensive on third-party spend.

---

## 10. Open questions

| # | Question | Why it matters | My working assumption |
|---|---|---|---|
| Q1 | **Spine §8 says the assistant stores nothing; `assistantQuota` stores a count.** | Literal compliance would leave the endpoint uncapped, which is a real money hole at §2.3's numbers. | Build it as §1.2 — count only, no content, Function-only, TTL-deleted — and amend the spine sentence to "stores nothing *about her question*". **Spine owner.** |
| Q2 | **Nobody has stated an adoption rate.** §2.3's whole figure rests on 15% of DAU × 1.4 questions. At 40% it is **$11,700/month**; at 5% it is $1,600. | It is the difference between the assistant being a rounding error and being the largest line after ID verification. | Ship with the caps in §2.4 and instrument adoption from day one (an enum-typed count, never the question). **Owner + G8.** |
| Q3 | **Opus 5, or a cheaper model?** HANDOFF specifies `claude-opus-5` for answers. Sonnet 5 is ≈60% cheaper per question, Haiku 4.5 ≈80% for pure lookups. | ~$3.8k/month of the bill sits on this one line. | Opus 5 as specified. **This plan does not downgrade a model to save money — that is the owner's call, not an implementer's**, and it should be made on measured answer quality against a held-out set of real Egyptian questions. |
| Q4 | **HANDOFF says `propose_swap` and `draft_plan` *write*; the spine says one writer per collection.** | Two writers for `sessions`/`plans` is a rejected plan by spine §2, and it would put a model token on the write path to a woman's log. | The tools propose; G4 and G2 write (§7.1). HANDOFF's wording should change to "proposes". **Spine owner + G4 + G2.** |
| Q5 | **`coaches/{coachUid}/mealDrafts/{draftId}` has no owner.** Spine §8 gives G14 the coach's planning tools but names no meal-draft collection, and `users/{uid}/mealPlans/*` is G5's and the *client's*. | K27 has nowhere to land, and a coach writing into a client's `mealPlans` would be a second writer. | Requested from **G14**, with the rules in §6.1. If G14 declines, K27 holds the draft on-device only and the coach re-creates it in the planner by hand — a materially worse screen. |
| Q6 | **Free prose, or only selected templates?** This plan ships `answerKey` (an enum of ARB template keys) with **no free-text field at all**, which makes rule 10 and the "every string through localisation" rule automatic. | A free `note` field is where an invented quantity or an un-localised English sentence would re-enter. Structured outputs cannot express `pattern` or `maxLength`, so a prose guard must be a server-side regex, which is weaker than not having the field. | Templates only at launch; if the answers read as wooden in testing, add a digit-free, locale-checked `note` **and** the server-side scan. **Owner, after the first Arabic review.** |
| Q7 | **Anthropic rate limits and the org/workspace tier are unknown.** Caches are isolated per workspace, and cache reads do not count toward input rate limits on this model. | At 10× the assumed adoption the binding constraint stops being Firebase. It also decides whether the coach drafts need their own workspace (and therefore their own cache entry). | One workspace, one prefix, 5-minute TTL — continuous traffic keeps it warm, so the 1-hour TTL's doubled write price buys nothing. **Owner to confirm the tier before launch.** |
| Q8 | **May an unverified or pending-review woman use the assistant?** G1's contract keeps training and recipes open to her; only community waits. | Every unverified caller is real money, and it is an abuse surface the verification gate would otherwise have closed. | Allowed, at a **reduced cap of 2/day**, because refusing would contradict G1's published routing rule. **Owner + G1.** |
| Q9 | **Who reviews the Arabic the templates produce?** MSA, second-person feminine, Western numerals inside Arabic text. | The assistant is the only surface where a *selection* still composes a sentence. A wrong register here reads worse than a wrong colour. | The existing dictionary process (`i18n/ar.json` → generator), never a hand-edited ARB. **Owner-track, listed in the runbook.** |
| Q10 | **X02's `Find care near you` routes to `Y11`, which is G9's screen, and G9 owns cycle.** | X02 must work for a woman who has never turned My Cycle on. | `Y11`'s care content must be reachable without cycle setup. **G9 to confirm**; if not, X02 needs its own care destination. |
