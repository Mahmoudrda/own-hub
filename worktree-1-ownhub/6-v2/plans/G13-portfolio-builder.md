# G13 — The coach's portfolio builder

**Screens: B01–B14 (14).** `coachbrand` flow. Owner of `coaches/{coachUid}/portfolio/*`,
`results/*`, `ads/*`, and two flagged extensions (`media/*`, `insights/*`).

Inputs treated as fixed: `DECISIONS.md` (D1 — all 161 screens ship; D2 Firebase; D9 `com.ownhub.app`),
`BUILD-BRIEF.md` §2/§3/§4/§6 (§0 ignored per D1), `SCHEMA-SPINE.md` §1–§8 incl. C10/C11,
`flutter/HANDOFF.md` "The portfolio block model" + rules 1–17, `plans/RECONCILIATION.md`,
`tests/TEST-CASES.csv` (206 rows, **zero coverage of B01–B14** — the only B reference is
`P1-RULE-06`'s screen list), `src/screens-coachbrand.mjs`, `src/screens-firstrun.mjs` (B14).

**The one sentence this group is accountable for:** the page is an ordered list of blocks rendered
from data, the client-facing profile (`H02`, G11) renders *that same list through the same widget*,
and nothing a coach types can produce unreadable text or publish a woman's photo she has not
currently consented to.

---

## 0. The six commitments, mapped to where they are kept

| Commitment | Kept by | Section |
|---|---|---|
| Ordered list of blocks; a new type never needs a new screen | `blocks[]` + `BlockRegistry` + one `PortfolioView` | §1.2, §1.3, §7.1 |
| H02 renders exactly this list | `PortfolioView` is exported *to* G11; G11 owns chrome only | §7.1 |
| Seed/type/corners theme, contrast validated before acceptance | `ThemeValidator` + `OverlayFloor` + server re-check | §1.4 |
| C10 — consent checked at READ time, never copied at publish | portfolio holds `resultIds` only; rule + object-existence gate | §1.6, §3.2, §6 |
| C11 — blur on by default, on-device before upload | `CoachMediaPolicy` → G8's `MediaUploadGateway` | §5 |
| B14 is a state, not a route | `PortfolioHome` branch on `blocks.isEmpty` | §3.1, §10 Q9 |
| Versioning — editing never changes what clients see | `draft` / `v{NNNN}` / `live`, publish is the only writer of `live` | §1.1, §3.1 |

---

## 1. Data model

### 1.1 Collections — spine paths verbatim, plus two flagged extensions

```
coaches/{coachUid}/portfolio/{versionId}      SPINE §8. versionId ∈ 'draft' | 'live' | 'v0007'
coaches/{coachUid}/results/{resultId}         SPINE §8. two writers, disjoint key sets (§6)
coaches/{coachUid}/ads/{adId}                 SPINE §8
coaches/{coachUid}/offers/{offerId}           SPINE §8 — writes owned by G12; B06 authors THROUGH it (Q1)
coaches/{coachUid}/media/{mediaId}            EXTENSION, G13 — B13 has no home in the spine (Q2)
coaches/{coachUid}/insights/{yyyy-MM-dd}      EXTENSION, G13, FUNCTION-WRITE ONLY — B12 (Q2)
coaches/{coachUid}/insights/summary           EXTENSION, G13, FUNCTION-WRITE ONLY — B12 reads THIS, 1 read
```

Both extensions sit **inside `coaches/{coachUid}`**, which the spine §7 permits ("extend only inside
its own collections") but which is shared with G12 and G14 — see the composition hazard in §6.

**`portfolio/{versionId}`**

| Field | Type | Notes |
|---|---|---|
| `version` | int | monotonic, starts at 1. `draft` carries the version it *would* publish as |
| `published` | bool | `true` only on `live` and on `v{NNNN}` snapshots; always `false` on `draft` |
| `theme` | map | `{ seed:'#RRGGBB', type:'calm'\|'strong'\|'soft', corners:'sharp'\|'soft'\|'round' }` |
| `validator` | map | `{ v:int, at:ts, contrastLevel:0.0\|0.5\|1.0 }` — Function-written, proof the theme passed |
| `blocks` | array | ordered; **order is array index**, there is no `order` field to drift |
| `blockCount` | int | denormalised for B01's "6 sections" without parsing the array |
| `draftRev` | int | increments per save; the two-device guard (§4) |
| `draftDeviceId` | string | K8 single-writer guard on the embedded array |
| `publishedAt`, `publishedFrom` | ts, int | on `live`/`v{NNNN}` only: when, and from which draftRev |
| `hidden` | bool | coach unpublished the page without deleting it (§3.1 state `hidden`) |
| `schemaV`, `updatedAt`, `clientWrittenAt`, `opId` | — | K3, binding on every write |

Size: 40 blocks × 8 KB cap = 320 KB ceiling against Firestore's 1 MiB. `blockCount ≤ 40`,
`payload ≤ 8 KB` and `media ids ≤ 12 per block` are enforced in rules *and* in `BlockValidator`.

**`media/{mediaId}`** — `{ kind:'photo'|'video', cdnPath, poster?, w, h, bytes, durationSec?,
blurApplied:bool (always true), facesBlurred:int, state (§3.3), usedBy:[string ≤40],
clientResultId?, createdAt, moderation:{state, at?} }`. `usedBy` is what makes "delete refuses while
in use" and withdrawal purge bounded and cheap.

**`insights/summary`** — `{ last30:[{d, views, opens, enquiries}] (fixed 30), totals:{...},
sectionAttention:{ blockId → pct } (≤40 keys), updatedAt }`. Fixed-length array, Function-written
nightly + on demand. **This is G6's `recent8` correction applied before it can become a bug:** a
30-document range read is 30 reads, not 1.

### 1.2 The block envelope

```jsonc
{ "id": "b7",            // nanoid(8), stable across reorder — analytics and diffs key on it
  "type": "method",      // one of the 14; a type may repeat any number of times
  "visible": true,       // false hides; the payload is retained untouched
  "payload": { }         // per-type, schema below
}
```

Reordering = a permutation of the array and nothing else. Hiding = one boolean. Deleting = removal
with a 5-second undo (§5, rule 9). `id` is never reused within a portfolio.

`BlockRegistry` maps `type → (validator, editor route, renderer widget, l10n label)`. **Adding a
15th type is a registry entry plus a widget — no route, no screen, no migration** (K11: readers
tolerate unknown types by skipping them, so an old build never crashes on a new type).

### 1.3 Full payload schema, per type

All strings are localised-neutral user content (never passed through `l10n`; the *chrome* is).
All lengths are grapheme clusters, enforced by `BlockValidator` and re-checked server-side.

| # | `type` | Payload | Limits / rules |
|---|---|---|---|
| 1 | `cover` | `{ layout:'text-over-photo'\|'photo-above'\|'no-photo', media:mediaId?, focal:{x,y}, overlay:double, headline:str, subline:str }` | headline ≤64, subline ≤80, `overlay` ∈ [`OverlayFloor.minAlpha`, 0.9] (§1.4); `media` required unless `no-photo`; `MarketingClaimPolicy` applies to both strings |
| 2 | `about` | `{ paragraphs:[str] , portrait:mediaId? }` | ≤4 paragraphs, each ≤400 |
| 3 | `method` | `{ steps:[{title:str, body:str}], numbered:bool }` | 1–8 steps, title ≤40, body ≤200 |
| 4 | `offers` | `{ offerIds:[str], display:'cards'\|'list', showSpotsLeft:bool, snapshot:[OfferSnapshot] }` | ≤6 ids; **`snapshot` is Function-written at publish only** and is `null` on `draft` (§1.7) |
| 5 | `results` | `{ resultIds:[str], display:'strip'\|'stack', showNumbers:bool }` | ≤12 ids. **ids only — no media, no quote, no consent flag. C10** |
| 6 | `testimonials` | `{ items:[{ quote:str, attribution:str, resultId?:str }] }` | ≤8; quote ≤240; attribution ≤40; if `resultId` is present the item is consent-gated exactly like a result; a free-text testimonial may not carry a full name (moderation, Q7) |
| 7 | `video` | `{ media:mediaId, poster:mediaId?, caption:str, autoplay:false }` | caption ≤120; `autoplay` is a constant false — low-data mode and G4's `VideoPolicy` own playback |
| 8 | `gallery` | `{ mediaIds:[str], layout:'grid'\|'carousel', aspect:'1:1'\|'4:5' }` | ≤12 ids |
| 9 | `certificates` | `{ certIds:[str], showCheckedDate:bool }` | ids into `coaches/{coachUid}.verifiedCerts` (G12). **No free text** — a coach cannot type a certificate she does not hold; an id whose cert is not `verified` is dropped at render |
| 10 | `faq` | `{ items:[{q:str, a:str}] }` | ≤10; q ≤100, a ≤400 |
| 11 | `availability` | `{ showSpotsLeft:bool, showReplyWindow:bool, hours:[{day:0-6, from:'HH:mm', to:'HH:mm'}], tz:'Africa/Cairo' }` | ≤7 rows; spots-left and reply window are *read* from `coaches/{coachUid}` (G12) at render, never copied |
| 12 | `freebie` | `{ title:str, body:str, media:mediaId?, deliver:'inapp-message'\|'download', assetId?:str }` | title ≤60, body ≤200. **No email/phone capture field exists** (PDPL, spine §6) |
| 13 | `numbers` | `{ stats:[{ value:str, label:str, source:'manual'\|'derived' }] }` | ≤4; value ≤12, label ≤32. `MarketingClaimPolicy` rejects weight-loss and timeline claims, and any label that is a ranking (rule 11) |
| 14 | `cta` | `{ label:str, action:'message'\|'offer'\|'freebie'\|'external', offerId?:str, url?:str }` | label ≤24; `url` must be `https://`, no `javascript:`/`data:`, host on the moderation allowlist (Q7) |

**B03's grid shows 12 tiles** (`How I work … Ask me`) because `cover` and `about` are already on the
starter page; the registry holds all 14 and B03 lists every type not currently capped out.

### 1.4 Theme, and how contrast is computed and enforced

`theme = { seed, type, corners }`. Nothing else. The rendered scheme is derived, never stored.

| Knob | Derivation |
|---|---|
| `seed` | `ColorScheme.fromSeed(seedColor: seed, brightness: b, contrastLevel: c)` |
| `type` | `calm` / `strong` / `soft` → three `TextTheme` pairings built **from Rubik only** (weight, size, tracking, line height). A second typeface would break Arabic parity unless it is Arabic-capable — Q6 |
| `corners` | `sharp ×0.5`, `soft ×1.0`, `round ×1.6` applied to `AppRadius.{xs,sm,md,lg,xl}`. `full` never scales — a pill stays a pill |

**`ThemeValidator.validate(seed) → ThemeValidation`** — domain layer, no widget may construct a
`PortfolioTheme` except through `PortfolioTheme.validated()`, whose constructor is private.

1. For `brightness ∈ {light, dark}` and `contrastLevel ∈ [0.0, 0.5, 1.0]` **in that order**, build the
   scheme and test the pair set. The first `contrastLevel` that passes both brightnesses is recorded
   in `validator.contrastLevel`. This is the "nudge, not block" mechanism: a coach's colour is
   *raised* to legibility before it is ever refused.
2. **Ratio** = WCAG 2.1: linearise each sRGB channel (`c ≤ 0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4`),
   `L = 0.2126R + 0.7152G + 0.0722B`, `ratio = (Lmax + 0.05) / (Lmin + 0.05)`.
3. **Thresholds, stated exactly** (the token scale is `app_tokens.dart`):

   | Threshold | Applies to |
   |---|---|
   | **3.0:1** | `display` 32/600 and `headline` 26/600 only — the only two styles that meet WCAG "large text" (≥24 px, or ≥18.66 px **bold**; 600 is not treated as bold) |
   | **4.5:1** | every other text style, including `titleL` 20/600 and `titleM` 17/600 — deliberately stricter than implementers usually assume |
   | **3.0:1** | non-text: chip and card outlines, icon strokes, the progress track, focus rings (WCAG 1.4.11) |

4. **Pair set (14), all composed by block widgets:** `onPrimary/primary`, `onPrimaryContainer/primaryContainer`,
   `onSecondaryContainer/secondaryContainer`, `onTertiary/tertiary`, `onTertiaryContainer/tertiaryContainer`,
   `onSurface/surface`, `onSurface/surfaceContainer`, `onSurfaceVariant/surface`,
   `onSurfaceVariant/surfaceContainer`, `onError/error`, `primary/surface` (link/price text),
   `outline/surface` (non-text), `outlineVariant/surfaceContainer` (non-text), `onSurface/primaryContainer`
   (the numbered step badge in B07, which is the pair `fromSeed` does *not* guarantee).
   `fromSeed` guarantees the canonical on-pairs by tone distance; the last three are ours and are
   where a seed actually fails.
5. **Photo overlay — `OverlayFloor.minAlpha(image, textColor, scrim)`.** The cover, the ad and the
   gallery caption put text on a photograph, which is the real readability risk and the one a colour
   validator misses. Decode a 32×32 thumbnail of **the region under the text box only**, take the
   **90th-percentile** relative luminance `Lp` (90th, not mean: one blown-out sky ruins a headline),
   composite `L' = (1−α)·Lp + α·L(scrim)`, and solve for the smallest `α` in 0.01 steps where
   `ratio(L(text), L') ≥ 4.5`. B04's "Darken the photo" slider is **clamped to that α as its
   minimum**, the disabled region is drawn, and the value is recomputed and raised when the photo,
   the layout or the headline length changes. If `α = 0.9` still fails, the validator refuses the
   layout and offers `photo-above` — the one case where the builder says no.
6. **Enforcement points.**

   | Where | What |
   |---|---|
   | `PortfolioTheme.validated()` (domain) | the only constructor; an invalid theme is unrepresentable |
   | `BlockValidator.cover()` (domain) | rejects `overlay < OverlayFloor.minAlpha` |
   | `PortfolioPublisher.publish()` (domain) | refuses to queue an intent whose theme has no current `ThemeValidation` |
   | `publishPortfolio` Function (server, **authoritative**) | re-runs the identical algorithm; a tampered client cannot publish an unvalidated theme |
   | `contrast_test.dart` + `contrast.test.ts` | both read one shared fixture, `test/fixtures/contrast_vectors.json`, so the Dart and Node implementations cannot drift |
   | golden test | the six curated seeds in B05 (`#B4526E #4F7359 #8A5A17 #4A5B8C #7A4A7E #2F6E6A`) are asserted to pass at `contrastLevel 0.0` in both brightnesses; a palette edit that breaks one fails the build |

### 1.5 Media, storage and CDN layout

| Layer | Path | Policy |
|---|---|---|
| Local, pre-upload | app sandbox | blurred on device first (§5); referenced by `mediaId` so a block renders offline |
| Storage / R2 | `coach-media/{coachUid}/{mediaId}/{variant}` | `variant ∈ orig, 1600, 800, 400, poster`. **Public read** — this is the one difference from G8's private `user-media/{uid}/**` and it needs G8's rules block (§6, §7.3) |
| Client result media | `coach-media/{coachUid}/results/{resultId}/{mediaId}` | written by the consent Function from her own blurred media; **deleted on withdrawal** |
| CDN | `cdn.<domain>/p/{coachUid}/v{NNNN}.json` (immutable, `max-age=31536000`) · `…/p/{coachUid}/live.json` (`max-age=60, s-maxage=86400`, purged by URL on every change) · `…/r/{coachUid}/{resultId}.json` (same, purged on withdrawal) · images/video content-addressed and immutable | G8's convention: **public, content-addressed, immutable URLs, never signed** — signed URLs collapse the cache hit rate the $0-egress architecture depends on (RECONCILIATION §2) |

### 1.6 Client results and consent

```jsonc
{ "clientUid": "…", "relationshipId": "…", "requestedAt": ts,
  "consentState": "requested|granted|declined|withdrawn|expired|revoked|orphaned",
  "consentedAt": ts?, "withdrawnAt": ts?, "expiresAt": ts?,
  "scope":  { "photos": true, "numbers": true, "quote": true, "faceVisible": false },
  "mediaIds": ["…"],            // CLIENT-written — she picks the pictures
  "quote": "…",                 // CLIENT-written, ≤240
  "numbers": { "plankSec": {"from":20,"to":75} },   // FUNCTION-written from her own bests
  "blurred": true, "order": int, "schemaV": 1 }
```

Three properties that are the whole point, each enforced somewhere that is not a widget:

1. **The coach cannot author a result.** She creates it in `requested` with no media, no numbers and
   no quote; rules reject a coach write to `mediaIds`, `quote`, `numbers`, `scope`, `consentState`.
2. **Numbers are derived, never typed.** `deriveResultNumbers` Function reads
   `users/{clientUid}/bests/*` and `weeks/*` **with the client's approval inside the consent sheet**,
   so a coach cannot invent "12 weeks, 20 kg down". Weight and weight-lost are excluded by the
   allowlist of derivable measures (rule 11 / C7).
3. **`consentState` is read, never copied.** No portfolio, ad, CDN page object or analytics record
   contains it. §3.2 is the lifecycle; §6 is the rule that reads it at read time.

### 1.7 Offers — reference, not copy, until publish

B06 authors an offer; `coaches/{coachUid}/offers/{offerId}` is the canonical record and the spine
assigns its **writes to G12**. Resolution (§7.2, Q1): **G12 owns the collection and exposes
`OfferRepository.upsert(OfferDraft)`; B06 calls it.** The `offers` block stores `offerIds` +
display options only.

At publish, `publishPortfolio` resolves each id into an immutable `snapshot` inside
`v{NNNN}`/`live`. Two reasons, both load-bearing: a stranger's read stays **one object** instead of
1 + N, and **editing a live offer's price does not silently change a published page** — which is
rule 2 applied to money. B11's "your price change applies to new clients only" is then true by
construction, provided G11 stores the agreed price on the relationship (§7.1).

Results are deliberately **not** snapshotted. Price is the coach's own data; a client's face is not.

### 1.8 Ads

`ads/{adId} = { portfolioRef:{version}, format:'feed'|'story'|'reel-cover', headline ≤64, body ≤120,
cta, media:mediaId?, resultId?, state (§3.4), claimCheck:{v, at, pass}, exports:[{at, deviceId}] ≤20 }`.

**An ad is data, not a bitmap.** It is composed at render time from the theme, the media and — if
`resultId` is set — the live result. That is the only way HANDOFF rule 10's "including inside
already-rendered ad creatives" can be literally true. A flattened PNG is produced **only at export**,
after a fresh consent check, and each export is recorded (§3.4, §10 Q5 for the honest limit).

### 1.9 Indexes, and the exemptions that are part of the ruleset

```jsonc
// merged into G8's single firestore.indexes.json
{ "indexes": [
    { "collectionGroup": "results", "queryScope": "COLLECTION_GROUP",
      "fields": [ {"fieldPath":"clientUid","order":"ASCENDING"},
                  {"fieldPath":"consentState","order":"ASCENDING"},
                  {"fieldPath":"requestedAt","order":"DESCENDING"} ] }
  ],
  "fieldOverrides": [
    // Rule 11 / C7, pre-empted: insights must never become a coach leaderboard.
    { "collectionGroup": "insights", "fieldPath": "views",     "indexes": [] },
    { "collectionGroup": "insights", "fieldPath": "enquiries", "indexes": [] },
    { "collectionGroup": "insights", "fieldPath": "totals",    "indexes": [] },
    // Block payloads are free-form user content; auto-indexing every member of a
    // 40-element array is both waste and an accidental query surface.
    { "collectionGroup": "portfolio", "fieldPath": "blocks",   "indexes": [] },
    { "collectionGroup": "results",   "fieldPath": "numbers",  "indexes": [] }
  ] }
```

One composite, on a cold path (a client's consent inbox), on ids and an enum. Nothing on the hot
path needs an index: every hot read is a document get by a deterministic id, or a CDN GET.

---

## 2. Query per screen — index, cost, and how a stranger's read is cached

Population assumptions, stated: 100k MAU → 35,000 client DAU (§3). **2,000 coaches, ~900 coach-DAU.**
Marketplace: 12% of client DAU opens 1.4 coach profiles → **≈5,900 published-portfolio views/day**
(177k/month). Firestore `europe-west1` at $0.06/100k reads, $0.18/100k writes.

| Screen | Query | Index | Reads / open | Writes | Notes |
|---|---|---|---|---|---|
| **B01** hub | `get portfolio/draft` + `get portfolio/live` (cache-first) + `get insights/summary` | doc id | **3 cold, 0 warm** | 0 | `blockCount`, `version`, `publishedAt` all denormalised; no array parsing |
| **B02** canvas | in-memory from B01's draft | — | **0** | 1 per debounced save (2 s idle, coalesced) | whole-document rewrite, K8 single-writer |
| **B03** add section | `BlockRegistry` (compile-time) | — | **0** | 1 (same debounced save) | |
| **B04** cover editor | draft in memory + `media/{id}` from B13's cached page | — | **0** | 1 save (+1 media doc on a new upload) | overlay floor computed on device |
| **B05** look | none — theme is on the draft | — | **0** | 1 save | contrast computed locally, ~0.2 ms for 14 pairs × 3 levels |
| **B06** offers | `coaches/{coachUid}/offers` limit 6 | auto single-field | **≤6 cold, 0 warm** | 1 offer upsert + 1 draft save | via G12's repository |
| **B07** method | in memory | — | **0** | 1 save | |
| **B08** results | `coaches/{coachUid}/results` `orderBy(order)` limit 50 | auto | **≤50 cold (typ. 4)** | 1 per request/reorder | collection is capped at 50 (§9) |
| **B09** ad | `get ads/{adId}` + the referenced `media`/`result` | doc id | **≤3** | 1 | export adds 1 |
| **B10** preview | **0** — renders the draft already in memory through `PortfolioView` | — | **0** | 0 | identical widget tree to H02 |
| **B11** publish | `get portfolio/live` (for the diff) | doc id | **1 (warm 0)** | **1 queued intent** → Function writes 3 docs | diff is derived, never stored |
| **B12** insights | `get insights/summary` | doc id | **1** | 0 | fixed 30-element array — deliberately not a 30-doc range read |
| **B13** media | `coaches/{coachUid}/media` `orderBy(createdAt desc)` limit 30 | auto single-field | **≤30 cold** | 1 per upload | paged, never unbounded |
| **B14** state | the same `get portfolio/draft` as B01, which returned nothing | — | **0 extra** | 0 | it is a branch, not a screen |
| **H02** (G11, my data) | **CDN `GET /p/{coachUid}/live.json` + N × `/r/{coachUid}/{id}.json`** | — | **0 Firestore on hit** | 1 batched beacon | see below |

### How a published portfolio is cached — the load-bearing answer

A published portfolio is read by strangers, so it must not be a Firestore read at all.

| Layer | Mechanism | Effect |
|---|---|---|
| Render target | `publishPortfolio` writes `p/{coachUid}/v{NNNN}.json` (immutable, `max-age=31536000, immutable`) **and** `p/{coachUid}/live.json` (`max-age=60, s-maxage=86400`) to R2 | one object per view |
| Invalidation | purge-by-URL (deterministic, known URLs) on publish, rollback, hide and **every consent withdrawal**; the purge set is `live.json` + ≤50 `ads/*.json` + the one `r/{id}.json` — bounded by the coach's own content, never by followers | correctness without a short TTL |
| Consent | `live.json` carries `resultIds` only; each result is its **own** object whose *existence* is the read-time gate. Withdrawal deletes the object → 404 → the renderer omits the block item, never a placeholder | C10 holds on the cached path |
| Fallback | CDN 5xx/timeout → Firestore `portfolio/live` (1 read) + `results` gated by rule (`consentState == 'granted'`, evaluated on the document being read, **zero extra reads**) | correctness identical on both paths |
| App cache | `PublishedPortfolioReader` keeps a 60-second in-process entry + an ETag; H01→H02→back is 0 requests | marketplace browsing is free |

**Cost at the §3 numbers.**

| Line | Volume / day | Monthly |
|---|---|---|
| Firestore reads (coach-side + 2% CDN-miss fallback) | ≈ 4.0k | 120k → **$0.07** |
| Firestore writes (draft saves 2.2k, insights 3.0k, publishes ~1.0k, media 0.24k, consent 0.2k) | ≈ 6.7k | 200k → **$0.36** |
| Functions (publish 340, purge ~60, derive/render) | ≈ 500 invocations | ~15k → **free tier** |
| R2 storage (2,000 coaches × ~25 MB) | 50 GB | **$0.75** |
| CDN egress (5,900 views × ~1.2 MB ≈ 7 GB/day) | 212 GB | **$0** (Cloudflare/R2, per D2 and G4/G8) |
| **G13 total** | | **≈ $1.20 / month at 100k MAU** |

Against §3's per-active-day allowance, G13 adds **≈0.11 reads and ≈0.17 writes per client active
day** (entirely the stranger-view beacon and fallback) plus a separate, far smaller coach-side load.
It does not move the envelope; RECONCILIATION §3's point stands — the money is in verification, SMS
and Amplitude, not here. Peak (40% in 4 h): 0.16 profile views/s and <0.1 Firestore ops/s.

---

## 3. State machines

### 3.1 Portfolio lifecycle — 7 states

| State | Meaning | Screens |
|---|---|---|
| `empty` | no `draft`, no `live` | **B14** (a branch of B01) |
| `draft` | draft exists, never published | B01 shows "Not published yet", B02 |
| `queued` | publish intent queued (offline, or in flight) | B11 → B01 banner |
| `live` | `live` exists, `draft.draftRev == live.publishedFrom` | B01 "Live · version N" |
| `liveDirty` | live exists **and** the draft diverges | B01 "Live · 3 unpublished changes" |
| `hidden` | `live.hidden == true`; coach took the page down herself | B01 "Not visible", H02 → G11's not-found state |
| `suspended` | moderation removed it; editable, not publishable | B01 banner + reason |

| From → To | Trigger | Guard |
|---|---|---|
| `empty → draft` | first block added | — |
| `draft/liveDirty → queued` | B11 Publish | theme validated · all blocks valid · claim check passed · every `mediaId` in `live` state · every `offerId` resolves · every `resultId` currently `granted` |
| `queued → live` | Function succeeds | version = `live.version + 1`; **server re-validates everything above** |
| `queued → liveDirty/draft` | Function rejects, or coach cancels while queued | reason surfaced on B11; nothing published |
| `live → liveDirty` | any draft save | `draftRev++` |
| `live → live` (rollback) | B11 "restore version 3" | writes a **new** version whose content is v3's; history is append-only, never rewound |
| `live → hidden` / `hidden → live` | coach hides / shows | purge `live.json` both ways |
| `any → suspended` | moderation | Function-only |

**Editing cannot change what a client sees** because `draft` is a different document and the only
writer of `live` is the publish Function. Same shape as rule 2 for plans.

### 3.2 Consent lifecycle (C10 / rule 10)

| State | Set by | Publishable? |
|---|---|---|
| `requested` | coach (B08) | no |
| `granted` | **client only**, in her consent sheet | **yes, while this is the current value** |
| `declined` | client | no |
| `withdrawn` | client, any time | no — and purge fires |
| `expired` | Function, 14 days with no answer (Q4) | no |
| `revoked` | moderation Function | no |
| `orphaned` | `onAccountDelete(uid)` from G1 | no — treated as withdrawn, purge fires |

```
none ─create─▶ requested ─client grants─▶ granted ─client withdraws─▶ withdrawn (terminal)
                   │  └─client declines─▶ declined (terminal)         ▲
                   └─14d no answer─▶ expired (terminal)   moderation ─┘
                                             granted ─account deleted─▶ orphaned (terminal)
```

**The read-time predicate, in one place:**
`ResultVisibility.isPublishable(r) => r.consentState == 'granted' && (r.expiresAt == null || now < r.expiresAt)`.
Called by `PublishedPortfolioReader.resolve()`, by the rules (`resource.data.consentState ==
'granted'`), and by the render Function. **It is never called at publish time and its answer is never
stored.**

**Withdrawal propagation, in order** (`onResultConsentChanged`, ≤30 s p95):

1. Transaction: `consentState = withdrawn`, `withdrawnAt`, and `usedBy` cleared on every media doc.
2. Delete `coach-media/{coachUid}/results/{resultId}/**` from R2/Storage.
3. Delete `r/{coachUid}/{resultId}.json`; re-render `live.json` (the id drops out of the block);
   mark every ad with `resultId == r` **`stale`** and re-render its object without the media.
4. Purge-by-URL: `live.json`, `r/{id}.json`, each affected `ads/*.json`. Bounded set, ≤52 URLs.
5. Notify the coach (why it changed) and record the audit row; if `exports` is non-empty, tell her
   plainly that copies already downloaded are outside the app (§10 Q5).

Firestore rules make step 1 sufficient on its own: even if 2–4 fail, no client can read the result.

### 3.3 Media item — 8 states

`local → blurring → blurredLocal → queued → uploading → live → purging → purged`, with
`rejected(moderation)` reachable from `live` and `failed` from `uploading` (retry, then a rejected
row per G8's convention). **Nothing leaves `blurredLocal` without `blurApplied == true`** — the
upload gateway throws otherwise. A block referencing a `blurredLocal` item renders it from disk, so
building a page offline looks finished, not broken (§4).

### 3.4 Ad creative — 5 states

`draft → ready` (claim check passed) `→ exported` (a flattened file exists off-platform) ·
`ready|exported → stale` (source result withdrawn, or the portfolio republished with a changed
theme) · `→ rejected` (moderation). A `stale` ad cannot be exported again until re-checked; the
in-app render is already correct because it composes from live data.

---

## 4. Offline behaviour — she may be building her page on a microbus

| Action | Offline? | Behaviour |
|---|---|---|
| Add / reorder / hide / delete a block | **yes** | local sqflite draft + Firestore `set(merge:false)` on `portfolio/draft` (whole-document, K8 single-writer). Full opacity + `SyncBadge` (G8's convention) |
| Edit any payload, theme, method, FAQ | **yes** | same debounced save |
| Capture a photo/video, blur it | **yes** | ML Kit / Vision run on device (§4 platform table). File stays local, `media` doc is created in `blurredLocal`, upload queued |
| Author an offer (B06) | **yes** | queued through G12's repository; the offer block holds the id immediately |
| Preview (B10) | **yes** | draft + local media; the result block renders **"results appear when you're online"**, never a stale copy — it cannot check consent, so it does not guess |
| **Publish (B11)** | **queued intent, never a local "live"** | mirrors G2's O05. B11 says *"it will publish when you're back online"*; the intent carries `draftRev`, is cancellable while queued, and the Function re-validates on arrival |
| Ask a client for a result (B08) | queued | she sees the request when the write lands |
| **Export an ad (B09)** | **refused** | "we check her consent before it leaves the app." A stale-consent export is the one irreversible action in this group |
| Insights (B12) | last synced summary, dated | no spinner |
| Consent withdrawal by a client, offline | queued | **the copy must not say "immediately"** while it is queued — G7's recorded honest limit applies verbatim here |

**Conflict — two devices.** The draft is one document holding an embedded array, so Firestore cannot
merge it (K8, G4's `sets` problem). Guard: `draftDeviceId` + `draftRev`. A save whose `draftRev` is
not `live-in-doc + 1` is rejected by the rules; B02 shows *"this page was edited on your other
phone"* with **Take over** (adopts the server draft) or **Keep mine** (writes a new `draftRev` from
the local copy). No silent overwrite, no lost sections.

**Idempotency (C1).** `portfolio/draft`, `portfolio/live`, `insights/{date}` and
`insights/summary` are deterministic ids. `mediaId`, `resultId`, `adId` are minted once by
`DocIds`-style client UUIDs and reused on every retry. The publish intent is keyed
`{coachUid, version}` — a replayed publish targets the same `v{NNNN}` and collapses, it does not
mint version 5.

---

## 5. §2 / HANDOFF rules G13 owns, with the exact domain class and method

| Rule | Owned here as | Enforcement point (never a widget) |
|---|---|---|
| **§2-6 / C11** blur on by default, on device, before upload | `CoachMediaPolicy.blurRequired(MediaDraft) → bool` (true unless the in-shot client's result has `scope.faceVisible == true`) | resolution here; the *boundary* is **G8's `MediaUploadGateway.upload()`**, which throws `BlurNotAppliedError`. **G13 adds no second upload path.** B13's toggle writes the per-image exception only |
| **§2-11 / C7** nothing ranked | `MarketingClaimPolicy.check(text)` + the `insights` field-overrides in §1.9 | a `numbers` stat or headline that ranks, or any index that would let coaches be sorted by views, is rejected at authoring **and** absent from the deployed index config |
| **HANDOFF-2** publishing changes what clients see; editing never does | `PortfolioPublisher.publish(coachUid) → PublishIntent` | the only producer of a `live` write; `live` is Function-write-only in the rules |
| **HANDOFF-10 / C10** publishable only while consent is active | `ResultVisibility.isPublishable(result, now)` | called by `PublishedPortfolioReader.resolve()`, by the render Function, and mirrored in the security rule. Never called at publish time |
| **HANDOFF-16** B14 is a state | `PortfolioHome` branches on `blocks.isEmpty` | **no `/coachbrand/b14` route is registered** — see Q9, `app_routes.dart` currently declares one |
| **HANDOFF-17** the empty state is the onboarding | B14 itself: names the three starter sections, states nothing is decided for her, no tour, no overlay | widget test asserts no coach-mark/overlay widget exists in the flow |
| **§2-9** undo, not confirmation | deleting a block / a media item routes through **G3's `LogCommandBus`** with a 5 s undo | the documented exemption applies to **consent withdrawal**, which does confirm — it is destructive and another woman's photograph, exactly like G7's block/delete |
| **§2-3 / C6** weeks, not days | `BlockValidator` + G8's `noStreak()` | B12 shows rates ("7 in 100 ask") and 30 dated buckets. **No consecutive-day field exists** in `insights`, so "live 14 days in a row" is unstorable |
| **Marketing claims** (B09's on-screen promise) | `MarketingClaimPolicy.check()` — ar + en patterns for weight-loss claims, timelines ("in 30 days"), medical claims | runs on cover/ad/numbers/testimonial text at authoring **and** again in the publish Function; a failure blocks publish with the offending span highlighted |

Rules 1, 4, 5, 7, 8, 12–15 belong to other groups. G13 consumes, and violates none.

---

## 6. Security rules, as code

> **A composition hazard the spine names for `users/{uid}` applies verbatim to `coaches/{coachUid}`,
> and nobody has claimed it.** G12 (root, offers), G13 (portfolio, results, ads, media, insights) and
> G14 (splits) all match under `coaches/{coachUid}`. Firestore ORs `allow` across blocks, so one
> permissive `allow update` from any of the three defeats the others — including the guard that keeps
> a coach from writing her own `verifiedCerts` or her own `consentState`. **One author, one block,
> global invariants AND-ed outside, group slices OR-ed inside**, exactly as G8 did for `users`.
> G13 supplies the fragment below as a *requirement*; G8 (or G12) composes. See Q3.

```js
// fragment for the single composed coaches/{coachUid} block. Zero get() calls:
// a rules get() is a billed read on every public profile view.
function signedIn()   { return request.auth != null; }
function isSelf(uid)  { return signedIn() && request.auth.uid == uid; }
function isCoachRole(){ return signedIn() && request.auth.token.role == 'coach'; }
function changed()    { return request.resource.data.diff(resource.data).affectedKeys(); }
function keys()       { return request.resource.data.keys(); }
function freshStamp() { return request.resource.data.updatedAt == request.time; }
function noStreak()   { return !keys().hasAny(['streak','streakDays','dayStreak','daysStreak',
                          'dailyStreak','currentStreak','consecutiveDays','daysInARow','missedDays']); }

match /coaches/{coachUid} {

  // ─────────── portfolio ───────────
  match /portfolio/{versionId} {

    // Anyone — signed in or not, client or coach — may read the live page.
    // Historic versions and the draft are hers alone.
    allow read: if (versionId == 'live'
                    && resource.data.published == true
                    && resource.data.hidden != true)
                || isSelf(coachUid);

    function draftShape() {
      return request.resource.data.published == false
          && request.resource.data.blocks.size() <= 40
          && request.resource.data.blockCount == request.resource.data.blocks.size()
          && request.resource.data.theme.keys().hasOnly(['seed','type','corners'])
          && request.resource.data.theme.seed.matches('^#[0-9A-Fa-f]{6}$')
          && request.resource.data.theme.type    in ['calm','strong','soft']
          && request.resource.data.theme.corners in ['sharp','soft','round']
          && !keys().hasAny(['validator','publishedAt','publishedFrom'])   // server-only
          && noStreak() && freshStamp();
    }

    // She writes ONE document: the draft. Nothing else, ever.
    allow create: if isSelf(coachUid) && isCoachRole() && versionId == 'draft'
                  && draftShape() && request.resource.data.draftRev == 1;
    allow update: if isSelf(coachUid) && isCoachRole() && versionId == 'draft'
                  && draftShape()
                  && request.resource.data.draftRev == resource.data.draftRev + 1;  // two-device guard
    allow delete: if false;

    // 'live' and 'v0007' are Function-written only — the default deny covers it,
    // stated here because it is the line that makes versioning mean anything.
  }

  // ─────────── client results — two writers, disjoint keys (C10) ───────────
  match /results/{resultId} {

    function isTheClient() { return signedIn() && request.auth.uid == resource.data.clientUid; }
    function coachKeys()   { return ['order','requestedAt','relationshipId','updatedAt',
                                     'clientWrittenAt','opId','schemaV']; }
    function clientKeys()  { return ['consentState','consentedAt','withdrawnAt','scope',
                                     'mediaIds','quote','blurred','updatedAt',
                                     'clientWrittenAt','opId']; }

    // READ TIME, every time. Nothing is copied at publish time, so this single
    // predicate is the whole of C10 on the Firestore path.
    allow read: if resource.data.consentState == 'granted'
                || isSelf(coachUid)
                || isTheClient();

    // She asks; she cannot answer for the client.
    allow create: if isSelf(coachUid) && isCoachRole()
                  && request.resource.data.consentState == 'requested'
                  && request.resource.data.clientUid is string
                  && !keys().hasAny(['mediaIds','quote','numbers','scope',
                                     'consentedAt','withdrawnAt'])
                  && freshStamp();

    allow update: if (isSelf(coachUid) && changed().hasOnly(coachKeys()))
                  || (isTheClient()
                      && changed().hasOnly(clientKeys())
                      && request.resource.data.consentState
                           in ['granted','declined','withdrawn']
                      && request.resource.data.clientUid == resource.data.clientUid
                      && request.resource.data.mediaIds.size() <= 6);

    // 'numbers', 'expiresAt', 'revoked' and 'orphaned' are Function-only:
    // absent from both key lists, therefore denied to both parties.
    allow delete: if false;                  // withdrawal is a state, and an audit row
  }

  // ─────────── ads ───────────
  match /ads/{adId} {
    allow read:   if isSelf(coachUid);                 // the RENDERED ad is public; the doc is not
    allow write:  if isSelf(coachUid) && isCoachRole()
                  && request.resource.data.format in ['feed','story','reel-cover']
                  && !keys().hasAny(['claimCheck','state','exports'])   // server-only
                  && freshStamp();
  }

  // ─────────── her media library ───────────
  match /media/{mediaId} {
    allow read:  if isSelf(coachUid);
    allow write: if isSelf(coachUid) && isCoachRole()
                 && request.resource.data.blurApplied == true          // C11, at the door
                 && request.resource.data.kind in ['photo','video']
                 && !keys().hasAny(['moderation'])
                 && freshStamp();
  }

  // ─────────── insights ───────────
  match /insights/{docId} {
    allow read:  if isSelf(coachUid);       // her numbers are hers; never queryable across coaches
    allow write: if false;                  // Function-only; a coach cannot inflate her own views
  }
}
```

**Storage** — one block to add to G8's `storage.rules` (§9.2), because coach media is the only
public media in this product:

```js
match /coach-media/{coachUid}/{p=**} {
  allow read:  if true;                                        // a published page is public
  allow write: if request.auth != null && request.auth.uid == coachUid
               && request.auth.token.role == 'coach'
               && request.resource.metadata.blurApplied == 'true'      // C11
               && request.resource.size < 60 * 1024 * 1024;            // video headroom
}
match /coach-media/{coachUid}/results/{p=**} {
  allow read:  if true;
  allow write: if false;                    // consent Function copies; withdrawal deletes
}
```

**Emulator tests shipped with the fragment:** a stranger reads `live` (**allows**); a stranger reads
`draft` (**denies**); a stranger reads `v0006` (**denies**); a coach writes `live` (**denies**); a
coach writes another coach's draft (**denies**); a coach writes `mediaIds`/`quote`/`numbers`/
`consentState` on a result (**denies**); a client writes `order` on a result (**denies**); a stranger
reads a `withdrawn` result (**denies**) and a `granted` one (**allows**); a client writes another
client's result (**denies**); a media doc with `blurApplied:false` (**denies**); a coach writes
`insights` (**denies**); a draft save with a stale `draftRev` (**denies**); a `blocks` array of 41
(**denies**); a `streak` key anywhere in the fragment (**denies**); a second
`match /coaches/{coachUid}` block present in the deployed file (**fails the build**).

---

## 7. Interface to the other groups

### 7.1 G11 — the group that renders my output (the important one)

| Direction | Contract |
|---|---|
| **I publish** | `PortfolioView(portfolio: PublishedPortfolio, mode: render\|preview)` — a widget, not a spec. It renders the block list and nothing else: no app bar, no follow button, no footer |
| **I publish** | `PublishedPortfolioReader.watch(coachUid) → Stream<PortfolioState>` — CDN-first, Firestore fallback, 60 s in-process cache, consent resolved at read |
| **I publish** | `PortfolioState ∈ { loading, live(p), hidden, notBuilt, unavailable }`. **G11 must render `hidden`/`notBuilt` as its own state** — H02 for a coach with no page is not an error |
| **G11 owns** | the chrome around it: back/share/favourite, the avatar row, follow, rating, the footer CTAs to H03/H06, and the enquiry event |
| **The guarantee** | there is **one** renderer. `single_renderer_test.dart` asserts no other widget in the tree builds a coach-profile layout, and B10 preview instantiates the same `PortfolioView` with `mode: preview`. This is what makes "no second hand-built layout to keep in sync" a test rather than a promise |
| **I require** | on relationship acceptance, G11 **copies the agreed price onto the relationship** and never dereferences the live offer. Without this, B11's "your price change applies to new clients only" is false |
| **I require** | G11 routes the client's consent request (notification → `ResultConsentSheet`, which I provide) and gives me `relationshipId` + an `isActiveClient(coachUid, clientUid)` predicate so B08 cannot request a result from a stranger |
| **I require** | the marketplace list (H01) sorts by **none of** views, enquiries, followers, or any `insights` field (rule 11). My index exemptions make it impossible; G11 should not want to |

### 7.2 G12 — coach app, root document and offers

| Direction | Contract |
|---|---|
| I require | `OfferRepository.upsert(OfferDraft) / delete(offerId)` — B06 is the authoring surface, G12 owns the collection (spine §8). **Offers are currently authored in three unreconciled places: K04, B06 and K18** (`review/ux-review-pass-2.md`:205) — one must win. Q1 |
| I require | `coaches/{coachUid}.verifiedCerts[]` with `{certId, name, body, verifiedAt, state}`; the `certificates` block renders **only** `state == 'verified'` |
| I require | `acceptingClients`, `spotsLeft`, `serviceHours`, `replyWindowHours` readable at render for the `availability` block — read, never copied |
| I publish | `portfolioLive:{version, at}` to be written **by my publish Function** onto the coach root, or, if G12 prefers an untouched root, a `portfolioState` mirror it owns. Q3 |
| I publish | `PortfolioHome` (B01) as the K07 destination, and `PortfolioEmptyState` (B14) for K24/W11's "Work on my page" |

### 7.3 G8 — platform

| I require | Why |
|---|---|
| the `coach-media/**` Storage block (§6) | coach media is the only public media; `user-media/{uid}/**` is `isSelf`-read and cannot serve H02 |
| `MediaUploadGateway` to accept a `CoachMediaScope` (public bucket + R2 mirror) | so G13 adds **no second upload path** and rule 6's chokepoint stays one function |
| my fragment composed into the single `coaches/{coachUid}` ruleset, and my `fieldOverrides` merged into `firestore.indexes.json` | §6, §1.9 |
| `syncQueue` intent type `publishPortfolio{coachUid, version, draftRev}` | §4 |
| ~26 new strings in `i18n/msa/` — publish/queued/rollback/consent/withdrawal/contrast vocabulary | I must not invent Arabic and no widget may hardcode it |
| `AnalyticsProp` additions: `block_type` (enum of 14), `portfolio_action` (enum), `ad_format` (enum) | all closed enums, no free text (spine §6) |
| Remote Config: `portfolio_block_types_enabled`, `portfolio_max_blocks`, `ad_claim_patterns_version` | roll a block type out or off without a store release |

### 7.4 Others

| Group | Contract |
|---|---|
| **G7** | `MediaBlurPolicy.resolve()` is the default resolver I compose with; **consent withdrawal must be reachable from the client's privacy surface (A03), not only from a notification** — a woman who wants her photo down should not have to find the coach's page. Q8. `onAccountDelete(uid)` → my `orphanResults(uid)` hook |
| **G6** | `deriveResultNumbers` reads `users/{clientUid}/bests/*` and `weeks/*` through G6's `BestsRepository`, with an allowlist that **excludes weight and weight-lost** (C7) |
| **G10** | a client's follow-up media she selects for a result is community media she already posted (already blurred, already uploaded). I read it via `PostsRepository.mediaForConsent(clientUid)` and copy only what she ticks |
| **G14** | none. Splits and assessments never appear on a public page |
| **Content/moderation** | ad and page review before a creative is exported or a page is published for the first time (the B09 banner is a staffing promise, like the Safety Centre's) |

---

## 8. Test cases G13's screens need

`tests/TEST-CASES.csv` covers **none** of B01–B14. These rows are in its exact 10-column format
(`id,priority,journey,screens,precondition,steps,expected,rule_protected,platform,scope`) and are
**not** written into the file — appending is the suite owner's call (Q10 names the id-collision risk
with the other Stage-2 agents writing rows in parallel).

```csv
P0-PORT-01,P0,Portfolio — day one is a state,B14,"Coach verified, no portfolio document exists",Open K07 > My portfolio,"B14 renders inside the B01 route: dashed placeholder, the three starter sections, no tour and no overlay. No /coachbrand/b14 destination is registered and nothing navigates to one.",HANDOFF rules 16 and 17,both,Post-MVP
P0-PORT-02,P0,Portfolio — a page is a list of blocks,"B01,B02,B03,B04,B07",Empty portfolio,Add a cover > add How I work > add a second How I work > edit both > drag to reorder > hide one,"Every change is an edit to the blocks array. Order is array order. A type appears twice without complaint. The hidden block keeps its payload and is absent from preview.","The page is data, not a template",both,Post-MVP
P0-PORT-03,P0,Portfolio — editing never changes what a client sees,"B02,B04,B06,B11,B10,H02","Published at version 3; a client has H02 open",Edit the cover headline and change an offer price; do not publish; reload H02,"H02 still renders version 3 byte-identical, including the old price. The draft is invisible to everyone but the coach.",HANDOFF rule 2 applied to the portfolio,both,Post-MVP
P0-PORT-04,P0,Portfolio — publish shows a derived diff and keeps history,"B11,B01","Live v3 and a diverged draft",Open Publish > read what changed > publish version 4 > then restore version 3,"The diff is computed from v3 versus the draft and is not stored anywhere. v4 is immutable, v3 is retained, and restoring writes a NEW version rather than rewinding history. The live CDN object is purged so the next stranger read is current.",,both,Post-MVP
P0-PORT-05,P0,Portfolio — H02 renders exactly this list,"B10,H02","Portfolio with 9 blocks, two of one type, one hidden",Preview as a client then open H02 from a different account,"Both use the same PortfolioView over the same document. The hidden block appears in neither. A code search finds no second coach-profile layout.","One renderer, no drift",both,Post-MVP
P0-PORT-06,P0,Theme — a coach cannot choose unreadable text,B05,Builder open,Select each of the six seeds; then attempt a custom near-white seed,"Every accepted theme passes all 14 role pairs at 4.5:1, and 3:1 for display/headline and non-text. A failing seed is retried at contrastLevel 0.5 then 1.0 and only refused if it still fails, with the nearest passing seed offered. The publish Function refuses a theme with no validation stamp.",The builder will not let her pick text a client cannot read,both,Post-MVP
P0-PORT-07,P0,Theme — the photo overlay has a computed floor,B04,Cover block with a bright photo,Drag the darken slider to zero > replace the photo with a brighter one,"The slider stops at the minimum alpha that reaches 4.5:1 against the headline and the disabled region is visible. Replacing the photo recomputes the floor and raises the current value if it is now too low. If even 0.9 fails the layout is refused and photo-above is offered.",,both,Post-MVP
P0-PORT-08,P0,Portfolio — building with no signal,"B02,B04,B13,B11",Airplane mode,Add two sections > edit text > capture and blur a photo > tap Publish,"Every edit renders at full opacity with the queued glyph. Blur runs on device. Publish is queued as an explicit cancellable intent whose copy does not claim the page is live, and it fires on reconnect at the version it was queued at.",Offline-first; no silent failure,both,Post-MVP
P0-PORT-09,P0,Portfolio — two phones cannot silently overwrite a page,B02,"Same coach signed in on two devices, both with the draft open",Edit on phone A > edit on phone B > save on B,"B is refused on the stale draftRev and shows 'edited on your other phone' with Take over or Keep mine. No section is lost and no save is silently discarded.",,both,Post-MVP
P0-PORT-10,P0,Portfolio — a stranger's read costs no Firestore read,"H02",Published portfolio,Open H02 as a signed-out-of-marketplace stranger with a cold cache,"The page is served from the CDN object. Firestore read count for the view is zero. A forced CDN failure falls back to one document read and renders identically.",,both,Post-MVP
P0-CONSENT-01,P0,Client result — she agrees in the app,B08,Coach with an active client,Ask a client for a result > open the request as the client,"The coach's document is created in state requested with no media, no numbers and no quote. Only the client can grant, and she chooses the pictures, the numbers and the sentence. Blur is on unless she turns it off for her own face.",Consent before publication,both,Post-MVP
P0-CONSENT-02,P0,Client result — withdrawal hides it everywhere,"B08,B09,H02","A published portfolio and a published ad both referencing result r1",Client withdraws consent > reload H02 and the ad,"Within one propagation cycle r1 is gone from H02, from the results block and from the ad creative, and its CDN objects return 404. The ad is marked stale. Nothing had been copied at publish time.",HANDOFF rule 10 / spine C10,both,Post-MVP
P0-CONSENT-03,P0,Client result — checked at read time,"H02,B08","Result granted, then withdrawn while a stranger has the page cached",Withdraw and immediately re-read every surface,"The next read omits it; the cached copy is invalidated by an explicit purge of a known URL. No consentState value exists inside any portfolio or ad document.",,both,Post-MVP
P0-CONSENT-04,P0,Client result — the photos and the numbers are hers,B08,Client granted numbers only,"Coach attempts to attach a photo, type a number, or edit the quote","All three are refused by the security rules, not only by the UI. Numbers are derived by a Function from her own logged bests, and weight and weight-lost are not derivable at all.","Rule 11, and consent scope",both,Post-MVP
P0-CONSENT-05,P0,Client result — withdrawal offline is described honestly,B08,Client withdraws with no signal,Withdraw in airplane mode then reconnect,"The app says the withdrawal applies when she is back online. No screen claims immediate removal while the write is queued. On reconnect the propagation completes.","Revokes immediately cannot be true offline",both,Post-MVP
P0-CONSENT-06,P0,Client result — a deleted account takes its consent with it,B08,"Client with a live published result deletes her account",Run account deletion,"The result moves to orphaned, its media is purged, and it disappears from the page and from every ad. The coach is told why.",,both,Post-MVP
P0-ADS-01,P0,Ad — her look in three sizes,"B09,B13",Published portfolio,Design a feed post then switch to story and reel cover,"All three inherit seed, type and corners with no rebuilding. The creative is composed from data; no flattened bitmap is stored as the source of truth.",,both,Post-MVP
P0-ADS-02,P0,Ad — export re-checks consent at the moment of export,B09,Ad referencing a consented result,Export offline; then export after the client withdraws,"Offline export is refused with the reason stated. After withdrawal the export is refused and the ad shows stale. The screen states plainly that a file already downloaded is outside the app.",HANDOFF rule 10 and its honest limit,both,Post-MVP
P0-ADS-03,P0,Ad — the claim rules are enforced not just displayed,B09,Ad editor open,"Write a headline promising 10 kg in 30 days, in English and in Arabic","Both are rejected at authoring with the offending span marked, and the publish Function rejects them again if the client is bypassed.","No weight-loss promises and no timelines",both,Post-MVP
P1-RULE-12,P1,Product rule guard,"B08,B09,B10,H02",App built and running,"Grep every portfolio, live and ad document for a copied consent flag or result content; then withdraw one consent and re-read every surface","No consentState, consentedAt, media or quote is stored inside any portfolio or ad document — the results block holds ids only. Every render resolves the result live and is refused unless consent is currently active. Withdrawal removes it from the page, the ads and the CDN.",HANDOFF rule 10 / spine C10: publishable only while consent is active,both,Post-MVP
P1-RULE-13,P1,Product rule guard,"B02,B03,B10,H02",App built and running,Search the codebase for a second coach-profile layout and add a 15th block type behind a flag,"H02 and B10 both render PortfolioView over the same block list; no hand-built coach-profile widget tree exists. A new type is a registry entry and a widget — no new route, no new screen, no migration, and an older build skips it without crashing.","The page is an ordered list of blocks rendered from data",both,Post-MVP
P2-RTL-B01,P2,Arabic RTL,B01,App language set to Arabic,Open B01 and inspect every row,"Layout mirrors, directional icons flip, numerals stay Western and isolated, nothing is clipped at the largest string.",,both,Post-MVP
P2-RTL-B02,P2,Arabic RTL,B02,App language set to Arabic,Open B02 and drag to reorder,"Layout mirrors and the drag handle sits on the correct side; reorder still writes the same array order regardless of direction.",,both,Post-MVP
P2-RTL-B03,P2,Arabic RTL,B03,App language set to Arabic,Open the add-a-section sheet,"The 3-column grid mirrors and every type label is translated; no English leaks.",,both,Post-MVP
P2-RTL-B04,P2,Arabic RTL,B04,App language set to Arabic,Open the cover editor,"The overlay gradient and the text block mirror; the slider direction follows the locale.",,both,Post-MVP
P2-RTL-B05,P2,Arabic RTL,B05,App language set to Arabic,Open Your look,"Swatches, type cards and corner cards mirror; the selected state stays on the same option after a language switch.",,both,Post-MVP
P2-RTL-B06,P2,Arabic RTL,B06,App language set to Arabic,Open What I offer,"Prices render Western digits inside Arabic text with correct isolation; the currency sits on the correct side.",,both,Post-MVP
P2-RTL-B07,P2,Arabic RTL,B07,App language set to Arabic,Open How I work,"Step badges mirror and the numerals stay Western.",,both,Post-MVP
P2-RTL-B08,P2,Arabic RTL,B08,App language set to Arabic,Open Client results,"The result strip mirrors; the consent copy is translated and the blur badge is visible on every item.",,both,Post-MVP
P2-RTL-B09,P2,Arabic RTL,B09,App language set to Arabic,Open the ad designer in all three formats,"The creative mirrors and the claim banner is translated; the exported file matches the on-screen composition.",,both,Post-MVP
P2-RTL-B10,P2,Arabic RTL,B10,App language set to Arabic,Preview as a client,"Every block mirrors exactly as H02 does; preview and H02 are pixel-identical for the same data.",,both,Post-MVP
P2-RTL-B11,P2,Arabic RTL,B11,App language set to Arabic,Open Publish,"The change list is translated with correct plurals; version numbers stay Western.",,both,Post-MVP
P2-RTL-B12,P2,Arabic RTL,B12,App language set to Arabic,Open insights,"Bars fill from the correct edge and percentages stay Western digits.",,both,Post-MVP
P2-RTL-B13,P2,Arabic RTL,B13,App language set to Arabic,Open Your media,"The grid mirrors, durations stay Western, and the blur toggle label is translated.",,both,Post-MVP
P2-RTL-B14,P2,Arabic RTL,B14,"App language set to Arabic, empty portfolio",Open the portfolio,"The empty state mirrors and all three starter rows are translated.",,both,Post-MVP
P2-TXT-B01,P2,Large text,B01,OS text size at maximum,Open B01,"Nothing is clipped or truncated to meaninglessness; the funnel numbers and their labels both stay visible.",,both,Post-MVP
P2-TXT-B02,P2,Large text,B02,OS text size at maximum,Open B02,"Block rows grow and remain draggable; the hide control keeps a 48dp target.",,both,Post-MVP
P2-TXT-B03,P2,Large text,B03,OS text size at maximum,Open the add-a-section sheet,"Tiles reflow to fewer columns rather than clipping labels.",,both,Post-MVP
P2-TXT-B04,P2,Large text,B04,OS text size at maximum,Open the cover editor,"The headline preview wraps rather than truncating, and the overlay floor is recomputed for the taller text box.",,both,Post-MVP
P2-TXT-B05,P2,Large text,B05,OS text size at maximum,Open Your look,"Type cards and corner cards grow without overlapping.",,both,Post-MVP
P2-TXT-B06,P2,Large text,B06,OS text size at maximum,Open What I offer,"Offer lines wrap; the price stays on screen.",,both,Post-MVP
P2-TXT-B07,P2,Large text,B07,OS text size at maximum,Open How I work,"Step bodies wrap and the badge stays circular.",,both,Post-MVP
P2-TXT-B08,P2,Large text,B08,OS text size at maximum,Open Client results,"Consent status text stays fully readable; no status is truncated to an ambiguous word.",,both,Post-MVP
P2-TXT-B09,P2,Large text,B09,OS text size at maximum,Open the ad designer,"The creative's own text does not scale with OS text size (it is artwork); the surrounding chrome does.",,both,Post-MVP
P2-TXT-B10,P2,Large text,B10,OS text size at maximum,Preview as a client,"Blocks reflow exactly as H02 does at the same setting.",,both,Post-MVP
P2-TXT-B11,P2,Large text,B11,OS text size at maximum,Open Publish,"The change list scrolls; the publish button is never pushed off screen.",,both,Post-MVP
P2-TXT-B12,P2,Large text,B12,OS text size at maximum,Open insights,"Labels and percentages stay paired and legible.",,both,Post-MVP
P2-TXT-B13,P2,Large text,B13,OS text size at maximum,Open Your media,"The grid reflows; the blur row stays fully readable.",,both,Post-MVP
P2-TXT-B14,P2,Large text,B14,"OS text size at maximum, empty portfolio",Open the portfolio,"The three starter rows and the note stay readable and the primary action stays reachable.",,both,Post-MVP
P2-OFF-B02,P2,Offline behaviour,B02,Airplane mode,Reorder and hide sections with no network,"Saves locally and queues; the rows render at full opacity with the queued glyph. Never a spinner and never a failure for something that will sync.",,both,Post-MVP
P2-ERR-B02,P2,Server error handling,B02,Backend returns a 500,Save a reorder against a failing backend,"A human-readable error naming the problem and the recovery, with an inline retry. The local draft is not corrupted.",,both,Post-MVP
P2-OFF-B03,P2,Offline behaviour,B03,Airplane mode,Add a section with no network,"The section appears immediately and queues.",,both,Post-MVP
P2-ERR-B03,P2,Server error handling,B03,Backend returns a 500,Add a section against a failing backend,"Readable error with retry; the block is kept locally, not discarded.",,both,Post-MVP
P2-OFF-B04,P2,Offline behaviour,B04,Airplane mode,Edit the cover and change the photo with no network,"Text queues and the new photo renders from the local blurred file; the overlay floor is still computed on device.",,both,Post-MVP
P2-ERR-B04,P2,Server error handling,B04,Backend returns a 500,Save the cover against a failing backend,"Readable error with retry; the edit survives.",,both,Post-MVP
P2-OFF-B05,P2,Offline behaviour,B05,Airplane mode,"Change seed, type and corners with no network","The whole page restyles immediately and the change queues; contrast validation runs locally.",,both,Post-MVP
P2-ERR-B05,P2,Server error handling,B05,Backend returns a 500,Save the theme against a failing backend,"Readable error with retry; the chosen theme is not silently reverted.",,both,Post-MVP
P2-OFF-B06,P2,Offline behaviour,B06,Airplane mode,Write a new offer with no network,"The offer is held locally and the block shows it; publishing is refused until it syncs, with the reason stated.",,both,Post-MVP
P2-ERR-B06,P2,Server error handling,B06,Backend returns a 500,Save an offer against a failing backend,"Readable error with retry; no half-written offer is referenced by a block.",,both,Post-MVP
P2-OFF-B07,P2,Offline behaviour,B07,Airplane mode,Add and reorder method steps with no network,"Saves locally and queues.",,both,Post-MVP
P2-ERR-B07,P2,Server error handling,B07,Backend returns a 500,Save steps against a failing backend,"Readable error with retry; the steps survive.",,both,Post-MVP
P2-OFF-B08,P2,Offline behaviour,B08,Airplane mode,Ask a client for a result with no network,"The request queues and is described as not yet sent. No result is shown as consented while the request is queued.",,both,Post-MVP
P2-ERR-B08,P2,Server error handling,B08,Backend returns a 500,Send a consent request against a failing backend,"Readable error with retry. No result document is left in a state that could be rendered.",,both,Post-MVP
P2-OFF-B09,P2,Offline behaviour,B09,Airplane mode,Design an ad and attempt to export it,"Designing works offline; export is refused with the consent reason, not a generic network error.",,both,Post-MVP
P2-ERR-B09,P2,Server error handling,B09,Backend returns a 500,Save the ad against a failing backend,"Readable error with retry; the draft creative is kept.",,both,Post-MVP
P2-OFF-B11,P2,Offline behaviour,B11,Airplane mode,Publish with no network,"Queued as an explicit cancellable intent. The copy does not say the page is live. B01 shows the queued state until it lands.",,both,Post-MVP
P2-ERR-B11,P2,Server error handling,B11,Publish Function returns an error,Publish a portfolio the server rejects,"The reason is named — invalid theme, failed claim check, withdrawn result or missing media — and points at the block. Nothing is published and the draft is untouched.",,both,Post-MVP
P2-OFF-B13,P2,Offline behaviour,B13,Airplane mode,Add a photo and a video with no network,"Both are blurred on device, appear immediately in the library and upload when signal returns.",,both,Post-MVP
P2-ERR-B13,P2,Server error handling,B13,Storage returns an error,Upload media against a failing backend,"Readable error with retry; the local file is kept and no unblurred file is ever retried.",,both,Post-MVP
```

**Totals: 22 P0/P1 + 14 RTL + 14 TXT + 10 OFF + 10 ERR = 70 rows**, covering all 14 screens and
every writing screen (B02, B03, B04, B05, B06, B07, B08, B09, B11, B13 — B01, B10, B12 and B14 do
not write). `P1-RULE-06`'s existing row already names B13; these rows do not duplicate it.

---

## 9. Scalability gate — self-check, stated

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | Every query is bounded by construction: `media` limit 30 paged; `results` limit 50 and the collection is capped at 50 per coach (a 51st request is refused, with archive-an-old-one offered); `offers` limit 6; `ads` capped at 50; `blocks` capped at 40 inside one document; `insights` is read as **one** summary document, never a 30-document range. The only collection-group query (`results` by `clientUid`) is indexed, equality-filtered, and on a cold path |
| **Fan-out write that grows with followers** | **PASS** | G13 writes nothing per viewer and nothing per follower. Publishing writes **exactly 3 documents + 2 CDN objects regardless of audience**. Withdrawal purges a set bounded by *the coach's own* content (1 page + ≤50 ads + 1 result ≤ 52 URLs), not by how many women have seen it. Views are read-path events, aggregated at the edge and flushed as **one** write per coach per 5 active minutes — an audience of a million is the same write volume as an audience of ten |
| **Unindexed query on a hot path** | **PASS** | The hot path (a stranger opening H02) is a CDN GET and executes **no Firestore query at all**; the fallback is a document get by deterministic id. Coach-side reads are document gets plus two single-field-ordered, limited collection reads. One composite index exists, declared in §1.9, and it is not on a hot path |
| **Migration needed to reach 100k MAU** | **PASS** | No counter needs sharding: the busiest document is `insights/{date}`, and at an implausible 50,000 views/day for one coach the edge aggregator still writes ≤1,440 times/day = 0.017 writes/s against Firestore's ~1/s soft ceiling. No document grows without bound — `blocks` ≤ 40, `last30` is fixed-length, `sectionAttention` ≤ 40 keys, `exports` ≤ 20, `usedBy` ≤ 40. Version history is append-only in *separate* documents, so it never inflates the read. Deterministic ids mean no key redistribution. Schema evolution is additive (K11) and unknown block types are skipped, so a 15th type ships without touching a stored document |

**Budget:** ≈ **$1.20/month at 100k MAU** (§2), against RECONCILIATION §3's ≈$75–95 infrastructure
total. The two figures worth watching are R2 storage as coach video accumulates (linear, ~$0.015/GB)
and Cloudflare purge-API call volume, not Firestore.

---

## 10. Open questions — named, because silence is a defect

| # | Question | Blocked on | Consequence if unresolved |
|---|---|---|---|
| **Q1** | **Offers are authored in three unreconciled places — K04, B06 and K18** (`review/ux-review-pass-2.md`:205), and the spine gives the collection's writes to G12 while B06 is a G13 screen. I have assumed: one collection, G12-owned, `OfferRepository` as the single write path, B06 as the authoring UI | G12 + spine owner | two screens writing the same field is a rejected plan under spine §2 — this must be settled before implementation, not during |
| **Q2** | Two extensions I added inside `coaches/{coachUid}`: **`media/*`** (B13 has no home in the spine at all) and **`insights/{date}` + `insights/summary`** (B12 likewise). Ratify or relocate | spine owner | B13 and B12 are unimplementable as specified without somewhere to store their data |
| **Q3** | **Who authors the single `coaches/{coachUid}` ruleset?** G12, G13 and G14 all match under it, so the OR-composition hazard the spine documents for `users/{uid}` applies here and nobody has claimed it. Also: may my publish Function write `portfolioLive` onto G12's root document? | G8 / G12 | one permissive `allow update` from any of the three groups silently defeats the consent guard and the certificate guard. This is the same defect class G2 found, one collection over |
| **Q4** | Does a consent **expire**? I have specified a 14-day expiry on an unanswered *request*, and **no expiry on a granted consent**. A standing "yes" that outlives the coaching relationship is an owner/legal call, not an engineering one | owner + legal | a result from a 2026 client still on a page in 2029 with no re-confirmation |
| **Q5** | **The honest limit, recorded rather than hidden:** withdrawal is immediate *inside the product*. A creative a coach already exported and posted to Instagram cannot be recalled by us. The export screen says so and every export is logged so the coach can be told whom to take down — but the consent copy the client reads must not promise more than the product can do | owner (copy) | the app would be making a promise it cannot keep about another woman's photograph — the most damaging possible version of this feature |
| **Q6** | `type: calm\|strong\|soft` is implemented as three **Rubik-only** pairings, because a Latin-only display face would silently break Arabic. If the owner wants genuinely different typefaces, we need three Arabic-capable pairs (Cairo, Tajawal, Almarai) and a licence decision | owner | either weaker visual differentiation than B05 implies, or an Arabic page in a fallback font |
| **Q7** | Moderation of coach-authored content: the `cta` external URL allowlist, testimonial attributions (a full name is another person's data), and whether the **first** publish is reviewed before it is public. B09's banner already promises "we check every ad" — that is a staffing commitment, exactly like the Safety Centre's | owner | an unreviewed public page with an off-platform link is the one surface in this product a bad actor would target |
| **Q8** | Should a client be able to **withdraw from A03 (Privacy)** as well as from the request notification? I have specified that she should; the surface is G7's | G7 | a woman who wants her photo down has to find the coach's page to do it |
| **Q9** | **`app_routes.dart` declares `/coachbrand/b14`** — and `/today/t06`, `/eat/e09`, `/community/m17`, `/coach/k24`, `/clients/w11`. HANDOFF rule 16 says all six are **states, not routes**. The generated routes file contradicts the rule it ships beside | generator owner (G8) | an implementer builds six destinations the product says must not exist; it looks correct and is a rule violation |
| **Q10** | The suite's `scope` column (`MVP` / `Post-MVP`) is **stale under D1**, which withdrew the cut. I used `Post-MVP` to match the existing coach rows. Also, P1 ids are a shared namespace and several Stage-2 agents are writing rows in parallel — my `P1-RULE-12/13` may collide | suite owner | either two tests with one id, or a scope column that no longer means anything |
| **Q11** | B12's funnel needs an **enquiry** event that fires on H06/H03, which are G11's screens, and view/dwell beacons that fire on H02, also G11's. I have specified the beacon contract; G11 must emit it | G11 | B12 renders zeros and the one number that tells a coach whether her page works is missing |
| **Q12** | Does the published portfolio render in the **viewer's** brightness, or always in its own light scheme? I default to the viewer's and validate both, which is stricter; the owner may prefer a coach's page to look identical to everyone | owner | either a coach's page ignores a woman's dark-mode preference, or two women see different-looking pages |
