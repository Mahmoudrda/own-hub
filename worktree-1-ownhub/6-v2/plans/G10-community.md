# G10 — Community

Screens: **M01** Feed · **M02** Post & comments · **M03** Create · **M04** Groups · **M05** Group ·
**M06** Group goal · **M07** Member profile · **M08** Report/block/mute sheet · **M09** Reels ·
**M10** Explore · **M11** Add a follow-up · **M12** Follow-up thread · **M13** Stories · **M14**
Activity · **M15** Saved · **M16** Record · **M17** Community, day one (**a state, not a route**).

Fixed inputs obeyed verbatim: `DECISIONS.md` (D1 — everything ships; D2 — Firebase + R2),
`SCHEMA-SPINE.md` §1–§8 including **C9–C12**, `flutter/HANDOFF.md` rules 1–17,
`plans/RECONCILIATION.md` (not re-litigated), `BUILD-BRIEF.md` §2/§3/§4/§6 (§0 ignored per D1).

**The one architectural decision.** A post is written **once**, to one document, whatever the author's
follower count. Feeds are assembled at read time by `array-contains-any` over a **bounded audience-key
set** the reader already holds. There is no timeline collection, no per-follower copy, and no code path
whose write count is a function of an audience size. That is C9, and it is load-bearing for every number
below.

**Cost at §3's numbers: ≈ $28/month** (Firestore $14.5 · Functions $3 · R2+CDN+transcode $10.5) at
35,000 DAU / 100k MAU. The same media served from Firebase Storage would be **≈ $708/month**.

---

## 1. Data model, against the spine

### 1.1 Spine §8 collections — used verbatim, extended only inside my own

```
posts/{postId}                                   owner G10
posts/{postId}/comments/{commentId}              owner G10
posts/{postId}/likes/{uid}                       owner G10   ← extension inside posts/**
followGraph/{uid}                                owner G10   ← the parent doc, extension
followGraph/{followerUid}/following/{followeeUid}
followGraph/{followeeUid}/followers/{followerUid}
groups/{groupId}
groups/{groupId}/members/{uid}
groups/{groupId}/challenges/{challengeId}        owner G10   ← extension inside groups/**
groups/{groupId}/challenges/{cid}/parts/{uid}    owner G10   ← extension inside groups/**
publicProfiles/{uid}                             NEW TOP-LEVEL — requested, OQ-1
users/{uid}/saved/{postId}                       NEW, under G8's ruleset — requested, OQ-2
reports/{reportId}                               owner G7 — I create only, never read
```

### 1.2 `posts/{postId}` — fields

| Field | Type | Writer | Why it exists |
|---|---|---|---|
| `authorUid` | string | client (== uid) | spine §8 |
| `authorCard` | `{name, avatarRef, verified:bool}` | client at create; Function on rename | **the feed renders 10 posts with 10 reads.** `users/{uid}` is `allow get: if isSelf(uid)` (G8 §9.1) — a viewer *cannot* read another woman's user doc, ever. Without this snapshot the feed is 10 posts + 10 profile reads |
| `groupId` | string? | client | spine §8 |
| `kind` | `'photo'\|'reel'\|'story'\|'best'` | client | spine §8 |
| `media[]` | `[{url, thumbUrl, w, h, durMs?, posterUrl?}]` ≤10 | client | R2 CDN URLs, §7 |
| `blurApplied` | bool | client | C11 evidence, per object |
| `blurOptOut` | `{by:'author', at:ts}?` | client | rule 6: turning it off is an explicit per-image action, and it is *recorded* |
| `caption` | string ≤2200 | client | |
| `topics[]` | ≤5 of an enum (`postpartum`,`quiet`,`ramadan`,`beginner`,`walking`) | client | M10's chips; an enum, never free tags |
| `parentPostId` | string? | client | **HANDOFF 9** — a follow-up always belongs to a parent |
| `cost` | `{sessions:int, countedWeeks:int}?` | client at compose | M11/M12 "what it cost her". **Two ints, both exempt from indexing.** No weight field exists to put here |
| `audienceKeys[]` | `['a:{authorUid}']` or `['a:{authorUid}','g:{groupId}']` | client, rules-validated | **the whole feed design.** Size ≤2, always — this is the field that makes fan-out-on-read one query |
| `visibility` | `'live'\|'author_hidden'\|'hidden_pending'\|'removed'` | author (first two), moderator Admin SDK (last two) | moderation without deleting evidence |
| `createdAt` | ts == `request.time` | client, rules-pinned | ordering; never a client clock |
| `expiresAt` | ts? | client, rules-pinned to +24h for `kind=='story'` | **Firestore TTL policy** — stories expire with no sweeper |
| `counts` | `{likes:int, comments:int}` | **Function only** | forgeable if client-written (G6's argument, adopted) |
| `followUpCount`, `latestFollowUpAt` | int, ts | Function | M12's strip without a count query |
| `schemaV` | int | client | K-conventions |

`postId` = client UUID minted once at compose (C1 — a retried publish targets the same document).

### 1.3 The other documents

| Path | Id | Fields | Writer |
|---|---|---|---|
| `posts/{id}/comments/{cid}` | client UUID, minted once (C1) | `authorUid, authorCard, postAuthorUid, body ≤1000, createdAt, schemaV` | client |
| `posts/{id}/likes/{uid}` | **= uid** (C1, idempotent by construction) | `postAuthorUid, createdAt` | client |
| `followGraph/{uid}` | = uid | `followingKeys[≤300], groupKeys[≤10], hiddenAuthors[≤200], updatedAt` | **Function** (`arrayUnion`/`arrayRemove` — both idempotent, so an at-least-once trigger retry is free) |
| `followGraph/{uid}/following/{other}` | = other uid | `createdAt` | client |
| `followGraph/{uid}/followers/{follower}` | = follower uid | `createdAt` | **Function mirror** — one writer, so the two sides cannot drift |
| `groups/{gid}` | slug | `name, kind, memberCount, topics[], blurb, createdAt` | content pipeline; `memberCount` Function |
| `groups/{gid}/members/{uid}` | **= uid** | `joinedAt, muteUntil?` | client |
| `groups/{gid}/challenges/{cid}` | slug | `titleKey, target, total, perWoman, startsAt, endsAt, shards?` | Function |
| `.../challenges/{cid}/parts/{uid}` | **= uid** | `done, of, creditedSessionIds[≤20]` | Function |
| `publicProfiles/{uid}` | = uid | `nameLower, name, avatarRef, verified, bio, joinedMonth, followerCount, followingCount, postCount, storyUntil?` | **Function**, from G7's `PublicProfileProjection.build()` |
| `users/{uid}/saved/{postId}` | **= postId** | `kind, thumbUrl, authorUid, savedAt` | client |

**`publicProfiles` contains only women whose `privacy.profileVisible == true`.** The projection Function
*deletes* the document when she turns it off. That is what makes `allow list` safe for Explore without
rules being able to inspect a `where` clause — a non-discoverable woman is not in the collection to
find. Her posts keep rendering from `authorCard`; her profile page shows the not-available state.

### 1.4 What must never exist, and the mechanism

| Forbidden | Rule | Made impossible by |
|---|---|---|
| A timeline / inbox collection | C9 | no such path is declared, and `firestore.rules` ends in G8's default deny — a fan-out write has nowhere to land |
| Ordering by follower count, likes, members, sessions | Rule 11 / C7 | **single-field index exemptions** on `publicProfiles.followerCount/followingCount/postCount`, `posts.counts`, `posts.cost`, `groups.memberCount`, `challenges.total` (§6.3). Firestore auto-indexes every field; absence of a composite index is *not* sufficient — that is G4/G6's finding, applied here |
| Any weight / weight-lost value in community | Rule 11 | no field of that type exists in any G10 document; `cost` is `hasOnly(['sessions','countedWeeks'])` in rules |
| A posting streak | Rule 3 / C6 | `noStreak()` is AND-ed into every G10 write; I add `postStreak`, `postingStreak`, `daysPosted` to G8's ban list (request, §7) |
| A "who liked this" roster | rule 11 in spirit | `likes` has `allow list` only when the query is constrained to the reader's own posts |
| A group member roster | harassment surface | `members` has `allow list: if false`; the count comes from the group doc |

---

## 2. The query for every screen — index and cost at §3's numbers

**Assumptions, stated.** 35,000 DAU. **Community-active = 40% of DAU = 14,000/day** (Community is one
tab of five; this is the planning figure and `community_feed_opened` measures it after launch). Peak =
40% of the day in 4 hours = **2.4× the average hour**. Firestore regional `europe-west1`, G8's prices:
**$0.03/100k reads, $0.09/100k writes**. `kAudienceChunk = 30` (the documented `array-contains-any`
limit; it was 10 before Nov 2023 — `P0-COM-16` asserts the chunker against whatever the deployed SDK
enforces, so a lower limit costs money, not correctness).

### 2.1 The feed — the query the whole plan stands on

```dart
// FeedQueryFactory.page(keys, cursor)   — keys = followGraph/{uid}.followingKeys + groupKeys
for (final chunk in keys.chunked(kAudienceChunk))     // p50: 1 chunk, p95: 2, hard cap 10
  db.collection('posts')
    .where('audienceKeys', arrayContainsAny: chunk)   // ≤30 values
    .where('visibility', isEqualTo: 'live')
    .orderBy('createdAt', descending: true)
    .startAfter([cursor]).limit(10);                  // merged k-way client-side, trimmed to 10
```

| Property | Value |
|---|---|
| Index | **composite: `audienceKeys` CONTAINS, `visibility` ASC, `createdAt` DESC** |
| Reads | **10 per chunk per page.** p50 = 10, p95 = 20 |
| Writes caused by a post | **exactly 1**, for 0 followers or 100,000 (C9) |
| Cost of a woman with 100k followers posting | one document write, $0.0000009 |
| Ordering | `createdAt` only. There is no score, no engagement weight, nothing rankable |
| Offline | Firestore persistence serves the last page at full fidelity; the same query re-runs from cache |
| Empty | `followingKeys` and `groupKeys` both empty → **M17 renders** (§3.7) |

**Why not `in` on `authorUid`:** identical cost, but it cannot express "the groups she joined" in the
same query, so the feed would be two queries and two merge cursors. `audienceKeys` puts a group and an
author in the same key space — one query, one index, one cursor.

**Why the reader holds the keys and not the writer:** `followGraph/{uid}` is written when **she**
follows or joins — O(1) per *her* action. The forbidden shape is writing to N documents when **she
posts**. The distinction is the whole of C9 and is stated here so no implementer "optimises" it back.

### 2.2 Every screen

| Screen | Query | Index | Reads / open | Writes |
|---|---|---|---|---|
| **M01** feed | §2.1 + `followGraph/{uid}` (1, then cached) | composite 1 | 11 first / 10 next page | 0 |
| **M01** stories rail | `posts` where `audienceKeys` CONTAINS-ANY chunk, `kind=='story'`, `expiresAt > now`, limit 20 | composite 5 | ≤20, cached 5 min | 0 |
| **M02** post + comments | post passed in memory from M01 (**0**); `comments` orderBy `createdAt` desc limit 10 | single-field auto | 10 | 1 per comment; 1 per like |
| **M03** create | none — her groups come from `followGraph/{uid}` (cached) | — | 0 | 0 (writes happen at publish, §3.1) |
| **M04** groups | yours: from `groupKeys` (cached) + `groups` get ×N (≤10, cached 24 h); suggested: `groups` where `kind in [...]` orderBy `createdAt` limit 8 | single-field auto | ≤8 | join = 1 (+1 Fn) |
| **M05** group | `groups/{gid}` (1) + open challenge (1) + `posts` where `groupId==`, `visibility=='live'` orderBy `createdAt` desc limit 10 | composite 6 | 12 | 0 |
| **M06** group goal | challenge doc (cached from M05) + `parts/{uid}` | doc get | 1 | 0 |
| **M07** member profile | `publicProfiles/{uid}` (1) + `posts` where `authorUid==`, `kind==`, orderBy `createdAt` desc limit 12 | composite 4 | 13 | follow = 1 (+1 Fn) |
| **M08** sheet | none | — | 0 | block 1 (G7) · report 1 (G7) · mute 1 |
| **M09** reels | `posts` where `kind=='reel'`, `visibility=='live'`, orderBy `createdAt` desc limit 10 | composite 2 | 10/page | 0 |
| **M10** explore | grid: `posts` where `topics` CONTAINS chip, `visibility=='live'`, orderBy `createdAt` desc limit 18. search: `publicProfiles` where `nameLower >= q`, `< q+`, limit 20; groups likewise; **moves = G8's local FTS5, 0 reads** | composite 7 + single-field | 18 | 0 |
| **M11** add a follow-up | `posts` where `authorUid==me`, `parentPostId==null`, orderBy `createdAt` desc limit 10 | composite 4 | 10 | 0 |
| **M12** follow-up thread | parent (1) + `posts` where `parentPostId==`, orderBy `createdAt` asc limit 10 | composite 3 | ≤11 | 1 per publish |
| **M13** stories viewer | media prefetched by the rail query | — | 0 | 0 (seen-state is **local sqflite**, 0 writes) |
| **M14** activity | 3 constrained collection-group queries, limit 10 each: `likes` where `postAuthorUid==me`; `comments` where `postAuthorUid==me`; `followGraph/{me}/followers` orderBy `createdAt` desc | CG 8, CG 9, single-field | ≤30, cache-first | 0 |
| **M15** saved | `users/{uid}/saved` orderBy `savedAt` desc limit 18 — **the thumbnail is denormalised, so 0 post reads** | single-field auto | 18 | 1 per save |
| **M16** record | none | — | 0 | 0 |
| **M17** day one | `followGraph/{uid}` (the same read M01 makes) + suggested groups limit 3 | single-field | 4 | 0 |

**M14 has no notification documents by design.** The obvious build writes one `notifications` doc per
like — that is a write per like, on the hottest path in the product, and it is the fan-out mistake
wearing a different hat. Assembling Activity from three constrained reads at open costs **0 writes** and
~30 reads on 0.4 opens/day. The one exception is the **follow-up prompt**, which must survive the app
being closed: it is a single G7 `notifications` doc written by a Cloud Task (§3.6).

### 2.3 Cost, added up

| Line | Per community-active day | /day (14,000) | /month | $ |
|---|---|---|---|---|
| Reads | ≈ **90** | 1.26 M | 37.8 M | **$11.34** |
| Writes (client) | ≈ **6.8** (5 likes, 0.6 comments, 0.12 posts, 0.3 saves, 0.2 follows, rest) | 95 k | 2.9 M | **$2.61** |
| Writes (Function: counters, mirrors, feedKeys) | ≈ **1.7** | 24 k | 0.7 M | **$0.63** |
| Rules `get()` on like/comment/follow creates | ≈ 5.6 billed reads | 78 k | 2.4 M | **$0.72** |
| Functions (≈95 k invocations/day) | | 2.9 M | | **≈ $3** |
| R2 storage (yr-1 average ~150 GB) + class A/B ops | | | | **≈ $4** |
| Reel transcode (Cloud Run ffmpeg, ~120/day) | | | | **≈ $2.5** |
| **CDN egress ≈ 5.9 TB/month** | | | | **$0 (R2 + Cloudflare)** |
| **G10 total** | | | | **≈ $25–30/month** |

**Peak:** 504k reads and 48k writes in the 19:00–23:00 window → **35 reads/s, 3.3 writes/s**, spread
across millions of documents. Nowhere near a per-document ceiling. The two documents that *can* get hot
are handled in §2.4.

**Egress, because it is the money.** 5.9 TB/month (feed images 1.26 TB, grids 0.25 TB, stories 1.76 TB,
reels 2.6 TB). On Firebase Storage at $0.12/GB that is **$708/month**; on R2 + Cloudflare it is **$0**.
G4 §8.3 wrote "user media (community photos, voice notes) stays on Firebase Storage — small volume".
**At 100k MAU that sentence is wrong by $708/month** and I am correcting it rather than inheriting it:
community media goes to R2 behind Cloudflare on the same public, content-addressed, immutable terms the
video library uses (§7, OQ-3).

### 2.4 Against the §4 read budget — said plainly

Spine §4 budgets **~8 reads per active day** for the whole product and measured a typical day at ~7.
**G10 does not fit inside it and cannot be made to.** A community tab that renders 25 posts a day is a
read surface; the honest figures are ~90 reads per *community-active* day, which lifts the product's
blended day to ~7 + (0.4 × 90) ≈ **43 reads/active day**.

That is a 5× increase on a line that costs **$11/month**. The §3 budget line worth defending is egress
($708 vs $0), not reads ($11 vs $2.50). **Recommendation: re-baseline spine §4 to "≈8 reads/day for the
training loop, ≈90 per community-active day"** — explicitly, the way RECONCILIATION §3 re-baselined
writes, so "we went over and it was fine" never becomes a habit.

Three things keep it at 90 rather than 400, and all three are requirements:

| Requirement | Without it |
|---|---|
| `authorCard` denormalised onto every post | +10 reads per feed page, and impossible anyway — `users/{uid}` is self-read-only |
| Saved tiles and story media denormalised | M15 is 18 reads instead of 36; M13 is 0 instead of 20 |
| **No snapshot listeners anywhere in community.** Cache-first, explicit pull-to-refresh, 5-minute staleness on the stories rail | a live listener on a feed re-reads on every write by anyone she follows — the standard way this bill goes to $500 |

### 2.5 Hot documents

| Document | Risk | Mitigation |
|---|---|---|
| A viral post's `counts` | >1 write/s | counts are **recomputed absolutely** (`count()` aggregation, 1 read per 1,000 likes) by a **coalesced Cloud Task named `recount:{postId}:{10s bucket}`** — a named task is deduped by Cloud Tasks, so 500 likes in a minute cause ≤6 recomputes. Absolute assignment is idempotent by construction, so an at-least-once retry cannot double-count and a lost update self-heals |
| A large group's `challenge.total` | 4,210 members | `shards: 10` above 1,000 members; the screen sums 10 sub-docs (10 reads, on a screen opened 0.05×/day) |
| `groups/{gid}.memberCount` | join storms | increment bound to the member doc's `counted` flag in one transaction (C4: an increment never travels alone) |

---

## 3. State machines

### 3.1 Publish pipeline — `PostPublishService` (11 states)

The single most consequential machine in the group: it is where rule 6, C11 and offline all meet.

| State | Entered when | UI (M03/M16) | Exit |
|---|---|---|---|
| `composing` | camera or picker returns | editor | → `blurring` on Post |
| `blurring` | always, before anything else | "Blurring faces" ≤2 s photo | → `blurReady` / `blurFailed` / `blurSkipped` |
| `blurFailed` | `FaceBlurChannel` unavailable or `facesFound == 0` with blur on | explicit choice: manual region, retry, or a recorded per-image opt-out | → `blurReady` or `composing` |
| `blurSkipped` | she took the explicit per-image opt-out | the opt-out is stamped into `blurOptOut` | → `blurReady` |
| `blurReady` | pixels are baked, original never written to disk outside the sandbox | Post enabled | → `undoWindow` |
| `undoWindow` | 5 s, via G8's `OfflineWriteQueue` | snackbar with Undo, **no dialog** (rule 9) | → `uploading` / `composing` on undo (0 writes) |
| `uploading` | ticket + presigned PUT per object | progress on her own card only | → `transcoding` (reel) / `publishing` |
| `transcoding` | reel only, Cloud Run ffmpeg | "Finishing your reel" | → `publishing` / `failed` |
| `publishing` | **now** the `posts` document is created | | → `live` |
| `failed` | upload or transcode exhausted retries | inline Retry, draft kept | → `uploading` |
| `live` | document exists | in feed | → `author_hidden` / `removed` / deleted |

**The deliberate exception to "write immediately".** Everywhere else in this product the write lands
first and syncs later. Here the document is created **last**, after the bytes are at the CDN, because a
post document whose `media[0].url` 404s is a broken card in *other women's* feeds — a failure she cannot
see and cannot fix. Offline, the whole draft lives in sqflite and renders **in her own feed and profile
at full opacity with G8's `cloud_queue` badge** (§4). `postId` is minted once, so the replay is
idempotent (C1).

### 3.2 Media object — `MediaTicket` (5 states)

`requested → presigned (15 min TTL) → uploaded → verified (hash + size + declared blur) → live`,
with `expired` and `rejected` terminals. The ticket is issued by a callable with App Check enforced;
`rejected` fires when the uploaded bytes' SHA-256 does not match the declared hash.

### 3.3 Story lifecycle (4 states)

`live → expiring (<1 h, ring dimmed) → expired (TTL deletes the document) → purged (R2 object deleted
by the TTL-delete trigger)`. No scheduler, no sweep: Firestore's TTL policy on `expiresAt` is the
mechanism. A **reported** story is copied to a moderation hold before expiry, which is OQ-11.

### 3.4 Moderation visibility (4 states, moderator-owned)

`live → hidden_pending` (on a report of a class that hides on sight) `→ removed` or `→ live` (restored).
Set via Admin SDK only. The feed query filters `visibility == 'live'`, so hiding takes effect on the
next page load everywhere at once — no fan-out, no purge. `author_hidden` is the fifth value and belongs
to her, not to a moderator.

### 3.5 Group membership (5 states)

`notMember → member → muted(until)` (M08's "mute for a week": still a member, her posts still count for
the challenge, the group's posts drop out of her feed via `groupKeys`) `→ member`, plus `left` and
`removedByModerator`. Mute is `members/{uid}.muteUntil`; the Function removes the key from
`followGraph/{uid}.groupKeys` and restores it when it lapses.

### 3.6 Follow-up prompt (4 states)

`none → scheduled` (a **named Cloud Task** `followup:{uid}:{postId}` at `firstPostAt + 8 weeks`, so
there is no scheduler and no sweep) `→ prompted` (one G7 `notifications` doc, deterministic id
`followup:{postId}`) `→ answered | dismissed`. Bounded: one task per woman per parent post, ever.

### 3.7 Community tab render state (HANDOFF 16) — **M17 is not a route**

```dart
switch (CommunityTabState.from(feedKeys, firstPage)) {
  case dayOne:    return const CommunityDayOne();   // M17, a branch inside the Community route
  case joinedOnly:return const FeedEmptyButJoined(); // groups joined, nobody has posted yet
  case ready:     return FeedList(...);
  case offlineCold: return const FeedOfflineCold(); // no cache, no signal
}
```
`app_routes.dart` gets **no M17 entry**. `P0-COM-03` asserts that the back button from the Community tab
in the day-one state exits the tab, never "back to the feed".

### 3.8 Follow button (M07/M09/M14) — 5 renderings

`self` (no button) · `notFollowing` · `pendingLocal` (optimistic, offline) · `following` ·
`unavailable` (blocked in either direction — renders exactly as "not available", never as "blocked",
per G7 §6.1).

---

## 4. Offline behaviour

Conforms to G8 §7 verbatim: full-opacity optimistic render, trailing `cloud_queue` glyph,
`l10n.syncQueued`, no blocking spinner, no "failed to save" for anything that will sync, no
confirmation dialog for a reversible action.

| Action | Offline? | Idempotency | What she sees |
|---|---|---|---|
| Like / unlike | **yes** | doc id **= her uid** — a replay is the same document | heart fills at once; the count is the server's and converges |
| Comment | **yes** | `commentId` from `DocIds`, minted once | comment appears with the queued glyph |
| Save / unsave | **yes** | doc id = `postId` | instant; private anyway |
| Follow / unfollow | **yes** | doc id = the other uid | button flips; her follower's count and the mirror land on sync |
| Join / leave a group | **yes** | doc id = her uid | **"Joined" is immediate; the group's posts join her feed when `followGraph` rebuilds server-side.** The copy must say so — this is the one place where an offline action has a visible lag, and hiding it would read as a bug |
| Publish a post / reel / story / follow-up | **queued, not created** | `postId` minted once | the card renders in her feed and profile as hers, badged; §3.1 explains why the document waits |
| Block | **yes** (G7) | doc id = blocked uid | takes effect locally at once against the local filter |
| Report | **queued, and explicitly not sent** (G7 §4) | | "Not sent yet. It will send when you have signal, and the hour starts then." **Never** "a moderator is reading it" |
| Read the feed | **yes** | — | last cached page at full fidelity; media that was never fetched shows the offline tile, never a spinner |
| Reels / stories | **no media** | — | explicit offline state. Community media is **not** downloaded for offline: it is other women's bodies, and a local cache of it is a privacy liability, not a feature |
| **Low-data mode** (G8's `devices/{id}.lowDataMode`, §3 launch requirement) | | | images at 320 w until tapped, **no autoplay**, reels require a tap, stories do not prefetch, upload deferred to Wi-Fi with a visible "waiting for Wi-Fi" row |

Conflict policy: every G10 counter is either an absolute recompute (`counts`, `followerCount`) or an
`arrayUnion`-guarded increment (`challenges`, `memberCount`). **No read-modify-write counter exists in
this group**, and no increment travels alone (C4 as corrected by G6).

---

## 5. §2 rules I own, and the exact enforcement point (domain layer, never a widget)

| Rule | Class.method that enforces it | Mechanism |
|---|---|---|
| **6** Face blur on by default, on-device, before upload | `CommunityMediaDraft.create()` → `BlurPipeline.apply()` | the constructor is private; the only factory calls `MediaBlurPolicy.resolve()` (G7) for the default and `FaceBlurChannel.blur()` (G8) for the pixels. **A draft with `blurApplied == false` cannot be constructed** without a `BlurDecision.explicitOptOut(mediaId, at)` token, which is minted only by the per-image switch and is written into `blurOptOut`. Upload then passes G8's `MediaUploadGateway`, which throws `BlurNotAppliedError`. Two gates, both in domain |
| **6** (video) | `ReelBlurExporter.export()` | detection per sampled frame (15 fps) with box smoothing across frames; the exported file *is* the blurred file. The source clip is never uploaded and never written outside the sandbox |
| **11** Nothing ranked by followers, weight or weight lost | `FeedQueryFactory` · `ExploreQueryFactory` · `FollowerCount` · `index_allowlist_test.dart` | every factory takes an `Ordering` enum with exactly one value, `newestFirst`. `FollowerCount` is a value object that **does not implement `Comparable`** and has no `>` operator, so a ranking cannot be written in Dart; the index exemptions (§6.3) mean it cannot be written in a query either |
| **11** (the cost card) | `FollowUpCost.from(rewards, weeklyGoal)` | returns exactly `{sessions, countedWeeks}`; there is no constructor parameter that could carry a weight. Rules re-assert it with `hasOnly` |
| **HANDOFF 9** A follow-up belongs to a parent, attachable only by the parent's author | `FollowUpComposer.attachTo(parentPostId)` → `FollowUpPolicy.assertOwnParentAndNotItselfAFollowUp()` | throws `NotYourPostError` / `NestedFollowUpError`. Re-asserted in rules with a `get()` on the parent, because a domain check alone is a client-side check |
| **HANDOFF 9** never a standalone before-and-after | `FollowUpThreadView` | renders the **chain** (parent → follow-ups), and its constructor requires a `FollowUpChain` whose every element shares one `authorUid`. Two women cannot be placed side by side because the widget cannot be given two authors |
| **9** Undo, not confirmation | `PostPublishService.enqueue(undo: 5s)`, `LikeCommand`, `SaveCommand` | like, save, follow and publish raise **no dialog**. Deleting a post and blocking may confirm — G7's documented exemption for destructive non-logging actions, restated here so QA does not read it as a violation |
| **3 / C6** Weeks, not days | `WriteIntentValidator` (G8) + rules `noStreak()` | I add `postStreak`, `postingStreak`, `daysPosted`, `activeDays` to G8's single ban list (request, §7) |
| **8** No face-gender classification | consumption only | I call `FaceBlurChannel.blur()`, the only symbol the channel exposes. I add `lib/features/community/**` to G1's `lint_no_face_gender.sh` scope |
| **C9** Fan-out on read | `FeedQueryFactory` + `fanout_guard_test.dart` | a test asserts that publishing a post with 5,000 followers produces **exactly one** document write, by counting writes against the emulator |
| **C11** No unblurred image reaches storage | `MediaTicketService.issue()` (Cloud Function) | refuses a ticket unless the draft declares `blurApplied` or a recorded opt-out; App Check enforced. **Honest limit:** a server cannot prove an image is blurred by looking at it, so this is an attested boundary plus App Check plus moderation — stated rather than implied (OQ-6) |
| **10** A client result is publishable only while consent is active | `ResultEmbedGate.check()` at **read** time | if a coach's result or ad is rendered in a community surface, its `consentState` is read then, never copied at publish (C10) |
| **17** The empty state is the onboarding | §5.1 | |

### 5.1 Empty states (HANDOFF 17 — "if a future screen can be empty, it needs one of these")

| Screen | Empty rendering | The one smallest action |
|---|---|---|
| M01 | **M17** | join one group |
| M01, joined but silent | "Nobody has posted here yet today" | post the first thing |
| M04 | never empty (curated groups ship with the app) | — |
| M05 | "This group is new" | post |
| M07 (hers) | "Nothing here yet — what you post shows here" | create |
| M07 (another woman, profile off) | "Not available" — identical to the blocked rendering, by design | — |
| M09 | "No reels yet" | record |
| M10 | "Nothing matches that" | clear the chip |
| M12 | n/a (a thread has a parent by definition) | — |
| M14 | "Nothing yet. This fills with women, not numbers." | — |
| M15 | "Only you can see what you save" + how to save | — |

---

## 6. Security rules, as code, against the spine's paths

G8's helpers (`signedIn`, `isSelf`, `changed`, `keys`, `freshStamp`, `noStreak`, `isVerified`,
`pledgeAccepted`, `canEnterCommunity`) and G7's `notBlockedBy()` are **in scope and are not redefined
here** — a second definition is a merge conflict, not a convenience. Per the spine amendment, G8 alone
authors `match /users/{uid}`; §6.2 is the requirement I hand them. Everything below is top-level and
mine to author, the way `reports/**` is G7's.

```js
// ───────────────────────── G10 — community ─────────────────────────
function member()      { return canEnterCommunity(); }        // verified AND pledge current
function mine(d)       { return signedIn() && d.authorUid == request.auth.uid; }
function memberOf(gid) {
  return exists(/databases/$(database)/documents/groups/$(gid)/members/$(request.auth.uid));
}
function postDoc(pid)  { return get(/databases/$(database)/documents/posts/$(pid)).data; }

// C9 made structural: audienceKeys is ['a:<me>'] or ['a:<me>','g:<a group I am in>'].
// Size <= 2 for every post ever written. There is no shape here that grows with an audience.
function audienceOk() {
  let d = request.resource.data;
  return d.audienceKeys.size() >= 1 && d.audienceKeys.size() <= 2
      && d.audienceKeys[0] == 'a:' + request.auth.uid
      && (d.audienceKeys.size() == 1
          || (d.audienceKeys[1] == 'g:' + d.groupId && memberOf(d.groupId)));
}

// HANDOFF 9: a follow-up belongs to a parent, only its author may attach one,
// and a follow-up may not itself be a parent (no chains of chains).
function followUpOk() {
  let d = request.resource.data;
  return !('parentPostId' in d)
      || (postDoc(d.parentPostId).authorUid == request.auth.uid
          && !('parentPostId' in postDoc(d.parentPostId))
          && d.kind == 'photo');
}

// Rule 11 restated at the door: the cost card is two integers and nothing else.
function costOk() {
  let d = request.resource.data;
  return !('cost' in d)
      || (d.cost.keys().hasOnly(['sessions','countedWeeks'])
          && d.cost.sessions is int && d.cost.countedWeeks is int);
}

match /posts/{postId} {
  allow get, list: if member();
  allow create: if member() && mine(request.resource.data) && noStreak()
    && request.resource.data.createdAt == request.time
    && request.resource.data.kind in ['photo','reel','story','best']
    && request.resource.data.visibility == 'live'
    && request.resource.data.counts.likes == 0
    && request.resource.data.counts.comments == 0
    && request.resource.data.blurApplied is bool
    && request.resource.data.media.size() <= 10
    && request.resource.data.caption.size() <= 2200
    && request.resource.data.topics.size() <= 5
    && (request.resource.data.kind != 'story'
        || request.resource.data.expiresAt == request.time + duration.value(24, 'h'))
    && audienceOk() && followUpOk() && costOk()
    && keys().hasOnly(['authorUid','authorCard','groupId','kind','media','blurApplied',
                       'blurOptOut','caption','topics','parentPostId','cost','audienceKeys',
                       'visibility','createdAt','expiresAt','counts','schemaV']);
  // She may edit her words or hide her own post. counts, followUpCount, authorCard refresh
  // and moderation visibility are Admin SDK only — a client-writable count is forgeable (G6).
  allow update: if member() && mine(resource.data)
    && changed().hasOnly(['caption','visibility','updatedAt','schemaV'])
    && request.resource.data.visibility in ['live','author_hidden']
    && freshStamp();
  allow delete: if member() && mine(resource.data);

  match /comments/{commentId} {
    allow get, list: if member();
    allow create: if member() && mine(request.resource.data)
      && request.resource.data.createdAt == request.time
      && request.resource.data.body.size() <= 1000
      && request.resource.data.postAuthorUid == postDoc(postId).authorUid
      && notBlockedBy(request.resource.data.postAuthorUid)   // she cannot reach a woman who blocked her
      && keys().hasOnly(['authorUid','authorCard','postAuthorUid','body','createdAt','schemaV']);
    allow update: if false;                                   // no edits: moderation needs a stable record
    allow delete: if member()
      && (mine(resource.data) || resource.data.postAuthorUid == request.auth.uid);
  }

  match /likes/{likeUid} {
    allow get:    if isSelf(likeUid);
    allow list:   if false;                                   // no "who liked this" roster
    allow create: if isSelf(likeUid) && member()
      && request.resource.data.postAuthorUid == postDoc(postId).authorUid
      && notBlockedBy(request.resource.data.postAuthorUid)
      && request.resource.data.createdAt == request.time
      && keys().hasOnly(['postAuthorUid','createdAt']);
    allow update: if false;
    allow delete: if isSelf(likeUid);
  }
}

// M14 Activity. Because the rule references resource.data.postAuthorUid, Firestore REJECTS any
// query that is not provably constrained to her own posts — the filter is enforced by the engine,
// not by the client's good manners. This is what lets Activity cost 0 writes.
match /{path=**}/likes/{likeUid} {
  allow list: if member() && resource.data.postAuthorUid == request.auth.uid;
}
match /{path=**}/comments/{commentId} {
  allow list: if member() && resource.data.postAuthorUid == request.auth.uid;
}
// There must be NO other collection-group wildcard in this file. In particular no
// `match /{path=**}/members/{uid}` — one would let anyone enumerate every group a woman is in.

match /followGraph/{uid} {
  allow get:   if isSelf(uid);                 // her audience keys + hidden authors
  allow write: if false;                       // Function only: arrayUnion/arrayRemove, idempotent

  match /following/{otherUid} {
    allow get:    if isSelf(uid) || isSelf(otherUid);   // "do I follow her" / "does she follow me"
    allow list:   if isSelf(uid) && request.query.limit <= 50;
    allow create: if isSelf(uid) && member() && otherUid != uid
      && notBlockedBy(otherUid)
      && request.resource.data.createdAt == request.time
      && keys().hasOnly(['createdAt']);
    allow update: if false;
    allow delete: if isSelf(uid);
  }
  // Written by the mirror Function only, so the two directions cannot drift.
  match /followers/{followerUid} {
    allow get:    if isSelf(uid) || isSelf(followerUid);
    allow list:   if isSelf(uid) && request.query.limit <= 50;   // her follower list is hers alone
    allow write:  if false;
  }
}

match /groups/{groupId} {
  allow get, list: if member();
  allow write:     if false;                   // curated content pipeline; memberCount is a Function

  match /members/{uid} {
    allow get:    if isSelf(uid);
    allow list:   if false;                    // 4,210 women are not a roster to scrape
    allow create: if isSelf(uid) && member()
      && request.resource.data.joinedAt == request.time
      && keys().hasOnly(['joinedAt','muteUntil','schemaV']);
    allow update: if isSelf(uid) && changed().hasOnly(['muteUntil','updatedAt']) && freshStamp();
    allow delete: if isSelf(uid);
  }
  match /challenges/{challengeId} {
    allow get, list: if member();
    allow write:     if false;
    match /parts/{uid} { allow get: if isSelf(uid); allow list, write: if false; }
  }
}

// Contains ONLY women with privacy.profileVisible == true — the projection Function deletes the
// document when she turns it off. That is what makes `list` safe: rules cannot inspect a where
// clause, so a non-discoverable woman must not be in the collection at all.
match /publicProfiles/{uid} {
  allow get:   if member();
  allow list:  if member() && request.query.limit <= 30;
  allow write: if false;
}
```

### 6.1 What a blocked woman can and cannot see — exactly

B blocks A. A is "blocked"; B is "the blocker".

| A can | A cannot |
|---|---|
| Everything outside community, unchanged — her own logs, plans, libraries | Comment on B's posts (`notBlockedBy` in rules, server-enforced) |
| See the room she was always in: community is **one open room for verified women**, not per-post ACLs | Like B's posts (same rule, same read) |
| Post, and be seen by everyone except B | Follow B (same rule) |
| Read a group B is also in | Message B (G11's path, same predicate) |
| Learn nothing: every blocked surface renders the ordinary **"not available"**, never "you are blocked" | Learn that she is blocked — `blockedBy` is `read: if false` for everyone including its owner (G7) |

| B sees | B does not see |
|---|---|
| Her feed with A's posts filtered out — client-side, against `followGraph/{B}.hiddenAuthors` | A's posts, comments, likes or follow, anywhere in her surfaces |
| A's profile as "not available" | Any notification caused by A |

**The honest limit, stated rather than discovered.** Blocking is a **contact and experience** boundary,
not a confidentiality one. Every post in this room was already readable by every verified woman; a block
does not retro-classify it. G7 is explicit that a feed must denormalise exclusion rather than evaluate
`notBlockedBy()` per document (that would be one billed read per post per page — the way a rules bill
becomes the largest line item), so the list-path filter is client-side over a Function-maintained
`hiddenAuthors` array, while the **single-document paths and every write that reaches another woman are
rules-enforced**. A modified client could therefore still *fetch* room content it could already read
before the block; it could not contact, follow or comment. **`hiddenAuthors` is symmetric and never
surfaced in any UI**, which weakens G7's "she cannot learn she was blocked" from absolute to
"unobservable through the product" — G7 must ratify this (OQ-2), and the alternative (a server-rendered
feed Function) is priced there.

### 6.2 What I hand G8 for the one `users/{uid}` ruleset

```js
// G10's requirement — G8 merges; I do not author inside match /users/{uid}.
match /saved/{postId} {
  allow get, list:    if isSelf(uid);
  allow create, delete: if isSelf(uid) && canEnterCommunity() && noStreak()
    && keys().hasOnly(['kind','thumbUrl','authorUid','savedAt','updatedAt','schemaV']);
  allow update: if false;
}
```
Plus: add `postStreak`, `postingStreak`, `daysPosted`, `activeDays` to `noStreak()`'s ban list. **I ask
for no slice on the `users/{uid}` document itself** — every piece of G10 reader state lives in
`followGraph/{uid}`, inside my own collection, precisely so the OR-composition problem stays closed.

### 6.3 `firestore.indexes.json` — G10's additions

```jsonc
{
  "indexes": [
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "audienceKeys", "arrayConfig": "CONTAINS" },
      { "fieldPath": "visibility",  "order": "ASCENDING" },
      { "fieldPath": "createdAt",   "order": "DESCENDING" } ] },          // 1 feed
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "kind",       "order": "ASCENDING" },
      { "fieldPath": "visibility", "order": "ASCENDING" },
      { "fieldPath": "createdAt",  "order": "DESCENDING" } ] },           // 2 reels
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "parentPostId", "order": "ASCENDING" },
      { "fieldPath": "createdAt",    "order": "ASCENDING" } ] },          // 3 follow-up thread
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "authorUid", "order": "ASCENDING" },
      { "fieldPath": "kind",      "order": "ASCENDING" },
      { "fieldPath": "createdAt", "order": "DESCENDING" } ] },            // 4 profile grid + tabs
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "audienceKeys", "arrayConfig": "CONTAINS" },
      { "fieldPath": "kind",         "order": "ASCENDING" },
      { "fieldPath": "expiresAt",    "order": "ASCENDING" } ] },          // 5 stories rail
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "groupId",    "order": "ASCENDING" },
      { "fieldPath": "visibility", "order": "ASCENDING" },
      { "fieldPath": "createdAt",  "order": "DESCENDING" } ] },           // 6 group feed
    { "collectionGroup": "posts", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "topics",     "arrayConfig": "CONTAINS" },
      { "fieldPath": "visibility", "order": "ASCENDING" },
      { "fieldPath": "createdAt",  "order": "DESCENDING" } ] },           // 7 explore chips
    { "collectionGroup": "likes", "queryScope": "COLLECTION_GROUP", "fields": [
      { "fieldPath": "postAuthorUid", "order": "ASCENDING" },
      { "fieldPath": "createdAt",     "order": "DESCENDING" } ] },        // 8 activity
    { "collectionGroup": "comments", "queryScope": "COLLECTION_GROUP", "fields": [
      { "fieldPath": "postAuthorUid", "order": "ASCENDING" },
      { "fieldPath": "createdAt",     "order": "DESCENDING" } ] }         // 9 activity
  ],
  "fieldOverrides": [
    // Rule 11 / C7, made structural. Firestore auto-indexes EVERY field, so without these the
    // query `publicProfiles orderBy followerCount desc` simply works and rule 11 is false in the
    // deployed project however careful the Dart is. Absence of a composite index is not enough.
    { "collectionGroup": "publicProfiles", "fieldPath": "followerCount",  "indexes": [] },
    { "collectionGroup": "publicProfiles", "fieldPath": "followingCount", "indexes": [] },
    { "collectionGroup": "publicProfiles", "fieldPath": "postCount",      "indexes": [] },
    { "collectionGroup": "posts",          "fieldPath": "counts",         "indexes": [] },
    { "collectionGroup": "posts",          "fieldPath": "cost",           "indexes": [] },
    { "collectionGroup": "groups",         "fieldPath": "memberCount",    "indexes": [] },
    { "collectionGroup": "challenges",     "fieldPath": "total",          "indexes": [] }
  ]
}
```
**Checked at deploy, not assumed** (G8's convention): a post-deploy assertion runs
`publicProfiles orderBy followerCount desc limit 1` and **requires it to fail**. `P1-COM-01` is that test.

### 6.4 Emulator tests shipped with these rules

Unauthenticated read of `posts`; a verified-but-pledge-stale account reading `posts`; a post whose
`audienceKeys` names a group she is not in; a post with 3 audience keys; a client write to
`posts.counts`; a follow-up attached to another woman's post; a follow-up of a follow-up; a `cost` map
carrying `weightKg`; a `postStreak` key; a `likes` collection-group list without the `postAuthorUid`
filter; a `members` list; a second `match /users/{uid}` block appearing in the deployed file.

---

## 7. Media: R2 + Cloudflare, and what is signed

Following G4 §8.3 and G8 §2-11 as settled in RECONCILIATION §2: **public, content-addressed, immutable
URLs — not signed URLs**, because a per-request signature collapses the edge cache hit rate that the
$0-egress line depends on.

| Leg | Mechanism |
|---|---|
| **Write** | `createMediaTicket(kind, sha256, bytes, blurApplied)` callable → **one-time presigned R2 PUT**, 15-minute TTL, App Check enforced, `canEnterCommunity()` checked server-side. Signing on the **write** leg costs nothing at the edge and is where G8's "signed URLs for user-generated media" is right |
| **Read** | `https://cdn.<domain>/m/{postId}/{sha256}/{variant}.{ext}`, `Cache-Control: public, max-age=31536000, immutable`. Identical URL for every viewer → one edge object, near-100% hit rate, **$0 egress** |
| Key shape | `{postId}/{sha256}` rather than bare `{sha256}`: content addressing alone would make two women who post identical bytes share one object, and deleting one post would break the other |
| Variants | produced **on device** (1080 w feed, 320 w grid, AVIF/WebP) so there is no server image-transform bill; reels transcode to one 540p H.264 + poster on Cloud Run ffmpeg |
| Delete | post delete / moderation `removed` / account deletion → Function deletes the R2 keys by prefix **and** issues a CDN purge for those exact URLs |
| Firebase Storage | still holds community **voice notes** under `user-media/{uid}/**` (small, G8's rules already cover it). Photos and video do not go there — that is the $708/month line |

**The honest limit (OQ-3).** A public immutable URL is a *capability URL*: anyone holding the link can
fetch the object without being a verified woman. High-entropy paths (a 256-bit hash) make it
unguessable, and the media is face-blurred by default, but a deliberately leaked link is viewable. The
alternative — a Cloudflare Worker validating a signed cookie on a path prefix, which preserves the cache
key and therefore the hit rate — is buildable and costs roughly **$0.30/million requests plus CPU (≈
$20–40/month at this volume)**. This is an owner decision about a promise, not an engineering
preference, and it must be made **before the CDN contract is signed**.

---

## 8. Interface to the other groups

### 8.1 What G10 consumes

| From | Path / API | Use |
|---|---|---|
| G1 | Auth claims `verified`, `vexp`, `pledgeV` → `canEnterCommunity()` | **the room's door.** Zero reads — G1's explicit reason for a claim over a rules `get()` was "it would double the cost of every community read at 100k MAU" |
| G1 | `VerificationGate.capabilitiesFor()` | the pending/rejected renderings of the Community tab |
| G7 | `MediaBlurPolicy.resolve()` | the blur default; I never read `privacy.blurFacesDefault` directly |
| G7 | `PublicProfileProjection.build()` + `privacy.profileVisible` | the source of `publicProfiles/{uid}`; off ⇒ the document is deleted |
| G7 | `users/{uid}/blocks/*`, `blockedBy/*` mirror | `hiddenAuthors`; feed exclusion denormalised, per G7's explicit instruction |
| G7 | `ReportService.file()` and the `reports/{reportId}` create contract | M08. I create, never read. The one-hour promise is G7's and the copy is theirs |
| G7 | `users/{uid}/notifications/*` write contract (deterministic id, `bodyKey`+`args`, `expiresAt`) | **one** community notification kind: the follow-up prompt |
| G8 | `MediaUploadGateway`, `FaceBlurChannel.blur()`, `OfflineWriteQueue`, `SyncStatusScope`/`SyncBadge`, `DocIds`, `AppClock`, `ErrorPresenter`, `AnalyticsGateway.emit()`, `lowDataMode`, `AppTheme`/`l10n`/`DirectionalIcon` | everything platform |
| G4 | `R10` share intent `{exerciseId, actualWeight, actualReps}` | M03's "a personal best" card. **Numbers she lifted, never a scale weight** — `BestPostPayload` has no field for one |
| G4 | `users/{uid}/sessions/{id}` completion (read-only trigger) | group-challenge credit |
| G6 | `rewards.sessionsLogged`, `weeklyGoal.countedWeeks` (her own doc, at compose time) | M11/M12's cost card. **G6 pays nothing for posting** — `AwardTable` has no key for it, by design; I do not ask for one |
| G3 | the `users/{uid}/firstWeek/arc` tick command | T07 steps 4 (`joinGroup`) and 5 (`followUp`). G3 §7 names the collection but not the symbol — OQ-9 |
| G11 | `relationships/**` | the `Coach` label inside M02's comments |
| G13 | `coaches/**/results/*.consentState` | read-time consent check on any result embedded in a community surface (C10) |

### 8.2 What G10 publishes

| Published | Consumers | Contract |
|---|---|---|
| `posts/**`, `groups/**`, `followGraph/**`, `publicProfiles/**` | G11 (coach profile embeds a feed), G7 (deletion manifest) | the paths above, verbatim |
| `CommunityShare.share(intent)` | G4 (R10), G6 (a milestone) | takes an intent, returns a composed draft on M03. **The caller writes nothing** |
| `CommunityArcTicker` | G3 | ticks `joinGroup` and `followUp` through G3's command, never by writing `firstWeek/arc` |
| `GroupChallengeCredit` | — | a Function on session completion; stores "a session happened", never a weight (M06's own copy) |
| `FeedReadModel` | G11 | so the coach app renders a feed without a second implementation |

### 8.3 What I require

| From | What |
|---|---|
| **Spine owner** | ratify `publicProfiles/{uid}` and `users/{uid}/saved/*` as G10-owned (OQ-1, OQ-2); record the `posts` field extensions in §1.2 |
| **G8** | merge §6.2's `saved` block; add my 4 keys to `noStreak()`; deploy §6.3's indexes **and exemptions**; ~40 new `i18n/msa` strings (post, follow, followers, following, blur, mute, report, story, reel, follow-up, "waiting for Wi-Fi", the M17 copy) — I must not invent Arabic |
| **G7** | ratify `hiddenAuthors` (OQ-2); add the `followup` notification kind to `notify.kinds`; emit the `publicProfiles` projection on a privacy change; add my 5 collections + the R2 prefix to the deletion manifest |
| **G7 deletion** | her `followers/*` mirrors live in **other women's** subtrees. Deleting them is O(her follower count) — a **paged batch job**, not a synchronous step. A dangling `a:{uid}` key in a follower's `followingKeys` is inert (the query returns nothing), so the wipe is eventual and the manifest must say so |
| **G4 / G8** | ratify that community media reads use the same public immutable content-addressed URLs as the library (OQ-3), and correct G4 §8.3's "user media stays on Firebase Storage" |
| **G3** | the symbol for the arc tick command (OQ-9) |

---

## 9. Test cases — rows for `tests/TEST-CASES.csv`

Format is the file's exact 10 columns. **I have not edited the CSV.** 77 rows: 18 P0, 9 P1, 50 P2.
`scope` is `MVP` because D1 makes "MVP" the single shipping scope; the five existing `Post-MVP` rows
should be re-stamped by whoever owns the file, and the column is stale vocabulary, not a scope decision
I am making (OQ-10).

```csv
P0-COM-01,P0,Community — the feed is groups and follows,"M01,M04","Verified, pledged, member of one group and following two women",Open Community > pull to refresh > scroll one page,"Posts from her groups and the women she follows appear, newest first. No post from anyone else appears. There is no public timeline anywhere in the tab.",C9 + the feed is not a public timeline,both,MVP
P0-COM-02,P0,Community — publishing writes one document,"M03,M01",Author with 5000 followers seeded in the emulator,Publish one photo post > count the Firestore document writes the publish caused,"Exactly one document is written, plus its media objects. No per-follower document exists anywhere. The same count holds for 0 followers and for 5000.",Spine C9: fan-out on read never on write,both,MVP
P0-COM-03,P0,Community — day one is a state not a route,M17,"Verified account, no groups joined, following nobody",Open the Community tab > press the system back button,"M17 renders inside the Community route. Back exits the tab; it never returns to an empty feed. No M17 entry exists in app_routes.dart.",HANDOFF 16: first-run screens are states,both,MVP
P0-COM-04,P0,Follow-up — only the parent's author may attach,"M11,M12","Two accounts, A has a post, B is signed in",As B attempt to attach a follow-up to A's post via the UI and then directly against the API,"Not offered in the UI, and refused by security rules with permission-denied. The domain throws NotYourPostError.",HANDOFF 9: a follow-up belongs to its parent,both,MVP
P0-COM-05,P0,Follow-up — never a standalone before-and-after,"M11,M12",A has one post 8 weeks old,Add a follow-up picture > open the resulting post,"It renders as one woman's chain over time (Week 1 / Week 4 / Now) with one author. There is no surface anywhere that places two different women side by side, and the follow-up has no existence apart from its parent.",HANDOFF 9,both,MVP
P0-COM-06,P0,Blur — a photo post uploads blurred,"M03,M16",Blur switch untouched,Take a photo with a face > publish > inspect the object at the CDN URL and in R2,"The stored bytes are already blurred. No unblurred object exists at any point in the pipeline. blurApplied is true on the post document.",Rule 6 + spine C11,both,MVP
P0-COM-07,P0,Blur — a reel exports blurred on Android,"M16,M09",Android device with ML Kit face detection,Record a 30-second reel with a face visible > publish > download the published file and step through it,"Every frame containing a face is blurred in the published file. The source clip is never uploaded and never written outside the app sandbox.",Rule 6 on video,android,MVP
P0-COM-08,P0,Blur — a reel exports blurred on iOS,"M16,M09",iOS device using the Vision framework,Record a 30-second reel with a face visible > publish > download the published file and step through it,"Identical result to the Android path. Where the export is slower than the Android device the progress state is explicit; it never publishes an unblurred file to meet a deadline.",Rule 6 on video,ios,MVP
P0-COM-09,P0,Blur — turning it off is explicit and recorded,"M03,M16",Blur on by default,Turn blur off for one image > publish > inspect the post document,"The opt-out applies to that image only. blurOptOut records who and when. The next composition starts with blur on again.",Rule 6: turning it off is an explicit per-image action,both,MVP
P0-COM-10,P0,Like offline then reconnect,"M01,M02",Airplane mode,Like a post > like it again > re-enable the network,"Exactly one like exists. The count converges to the server's value and never double-counts. The like document id is her uid so the replay is the same document.",Spine C1 + C4,both,MVP
P0-COM-11,P0,Comment offline,M02,Airplane mode,Write a comment > re-enable the network,"The comment shows immediately at full opacity with the queued glyph, syncs once, and no duplicate appears. No blocking spinner and no failure message.",G8 offline contract,both,MVP
P0-COM-12,P0,Publish offline holds the media locally,"M03,M01",Airplane mode,Compose a photo post > publish > inspect other accounts > re-enable the network,"Her own feed and profile show the post badged as waiting. No post document exists for anyone else until the media upload completes. Nothing appears in another woman's feed pointing at a missing object.",Media-before-document ordering,both,MVP
P0-COM-13,P0,Block — what she can and cannot see,"M08,M01,M02,M07","A and B both verified, B blocks A",As A: open the feed > open B's profile > attempt to comment on and like B's post > attempt to follow B,"A never sees B in her surfaces and every blocked surface reads 'not available'. Comment, like and follow are refused by security rules, not merely hidden. Nothing anywhere tells A she has been blocked.",G7 blocking contract,both,MVP
P0-COM-14,P0,Report from a post — queued offline,"M08,A04",Airplane mode,Report a post > read the state shown,"Says it is not sent yet and that the hour starts when it sends. It is never rendered as 'a moderator is reading it'. It sends once on reconnect.",G7 §4: a queued report is not a filed report,both,MVP
P0-COM-15,P0,A story expires after 24 hours,"M13,M01",A story posted 24 hours ago,Wait past the TTL > refresh the rail > request the media URL directly,"The story is gone from the rail and from the feed, its document is deleted by the TTL policy, and its R2 object is purged. No sweeper job runs.",Stories are 24 hours,both,MVP
P0-COM-16,P0,Feed chunking above the audience-key limit,M01,Following 95 women and in 6 groups,Open the feed and page twice,"Every followed author's recent posts are reachable. The client chunks the keys at the SDK's documented array-contains-any limit and merges; no author is silently dropped, and the read count is 10 per chunk per page.",The feed cost is bounded and unbiased,both,MVP
P0-COM-17,P0,An unverified or pledge-stale account cannot enter,"M01,C16","Verified account whose pledge version is below the Remote Config floor",Attempt to read the feed and to publish,"Both refused by rules. The tab shows the pledge state, not an error. Re-accepting the pledge and refreshing the claim restores access.",C5 + G1's claim gate,both,MVP
P0-COM-18,P0,Removing a post removes it everywhere,"M01,M02,M15,M07","A post that is saved by another woman and visible in a group feed",Author deletes the post > refresh feed / saved / profile / group,"It disappears from every surface on the next load, including the saved grid which shows the not-available tile. Its media objects are deleted from R2 and purged from the CDN.",Deletion is not a hide,both,MVP
P1-COM-01,P1,Product rule guard,"M01,M07,M10",App deployed with its index configuration,Run a query ordering publicProfiles by followerCount and posts by counts.likes against the deployed project,"Both queries FAIL because the single-field index exemptions exist. Absence of a composite index is not sufficient and is not what this test checks.",Rule 11: nothing ranked by followers,both,MVP
P1-COM-02,P1,Product rule guard,"M11,M12",App built and running,Compose a follow-up and inspect every field the cost card can carry in domain and in rules,"Only sessions and counted weeks can be written. No weight or weight-lost field exists in any community document, and the rules reject a cost map with any other key.",Rule 11 + spine C7,both,MVP
P1-COM-03,P1,Product rule guard,"M01,M03,M12",App built and running,"Post, comment, gain a follower and complete a follow-up, then read rewards.points",No points are awarded for any social action. AwardTable has no key for posting or following and no code path pays for one.,Reward economy is not social (G6),both,MVP
P1-COM-04,P1,Product rule guard,"M01,M03,M07,M14","Search the community schema, domain, rules and UI",Grep for a consecutive-day counter of any kind and attempt to write postStreak into a post,"No such field or surface exists, and the write is rejected by noStreak().",Rule 3 / spine C6,both,MVP
P1-COM-05,P1,Product rule guard,"M03,M16",App built and running,Attempt to upload community media by any path other than MediaUploadGateway and with blurApplied false,"There is no other path: the R2 PUT requires a ticket, the ticket requires the attestation, and the gateway throws BlurNotAppliedError. App Check is enforced on the ticket callable.",Rule 6 / spine C11,both,MVP
P1-COM-06,P1,Product rule guard,"M16,M03",App built and running,Grep the community feature and the platform channel for any face classification symbol,"FaceBlurChannel exposes blur() and nothing else. ML Kit and Vision are used for detection only. No gender or attribute classification call exists.",Rule 8: no AI face-gender classification,both,MVP
P1-COM-07,P1,Product rule guard,"M11,M12",App built and running,Attempt to create a follow-up of a follow-up and a follow-up on another woman's post,"Both refused in domain and in rules. A chain is always one woman and always one level deep.",HANDOFF 9,both,MVP
P1-COM-08,P1,Product rule guard,"M01,M02,M03,M15",App built and running,Like / save / follow / publish and watch for dialogs,"No confirmation dialog appears for any of them. Publishing offers a five-second undo before the upload starts. Deleting a post and blocking may confirm, which is the documented exemption for destructive non-logging actions.",Rule 9: undo not confirmation,both,MVP
P1-COM-09,P1,Product rule guard,"M01,M03",Emulator with the deployed rules,Search the deployed rules and the schema for any collection that could hold a copy of a post for a follower,"No timeline or inbox collection exists, and the default deny means a fan-out write has nowhere to land. Publishing writes exactly one document.",Spine C9,both,MVP
P2-RTL-M01,P2,Arabic RTL,M01,Interface language set to Arabic,Open M01 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M02,P2,Arabic RTL,M02,Interface language set to Arabic,Open M02 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M03,P2,Arabic RTL,M03,Interface language set to Arabic,Open M03 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M04,P2,Arabic RTL,M04,Interface language set to Arabic,Open M04 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M05,P2,Arabic RTL,M05,Interface language set to Arabic,Open M05 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M06,P2,Arabic RTL,M06,Interface language set to Arabic,Open M06 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M07,P2,Arabic RTL,M07,Interface language set to Arabic,Open M07 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M08,P2,Arabic RTL,M08,Interface language set to Arabic,Open M08 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M09,P2,Arabic RTL,M09,Interface language set to Arabic,Open M09 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. The action rail sits on the correct side.",,both,MVP
P2-RTL-M10,P2,Arabic RTL,M10,Interface language set to Arabic,Open M10 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M11,P2,Arabic RTL,M11,Interface language set to Arabic,Open M11 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, and the then/now pair reads right to left.",,both,MVP
P2-RTL-M12,P2,Arabic RTL,M12,Interface language set to Arabic,Open M12 and inspect layout and directional icons,"Mirrored layout, MSA copy, and the follow-up strip runs right to left with its arrows mirrored.",,both,MVP
P2-RTL-M13,P2,Arabic RTL,M13,Interface language set to Arabic,Open M13 and inspect layout and directional icons,"Mirrored layout, MSA copy, and the story progress bars fill right to left.",,both,MVP
P2-RTL-M14,P2,Arabic RTL,M14,Interface language set to Arabic,Open M14 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M15,P2,Arabic RTL,M15,Interface language set to Arabic,Open M15 and inspect layout and directional icons,"Mirrored layout, MSA copy, Western numerals in isolated spans, directional icons flipped. No clipped or overlapping text.",,both,MVP
P2-RTL-M16,P2,Arabic RTL,M16,Interface language set to Arabic,Open M16 and inspect layout and directional icons,"Mirrored layout, MSA copy, and the camera rail sits on the correct side with the mode chips mirrored.",,both,MVP
P2-RTL-M17,P2,Arabic RTL,M17,Interface language set to Arabic,Open the Community tab on a day-one account in Arabic,"Mirrored layout, MSA copy, and the three suggested groups read correctly. No clipped or overlapping text.",,both,MVP
P2-TXT-M01,P2,Largest OS text size,M01,OS text size at maximum,Open M01,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M02,P2,Largest OS text size,M02,OS text size at maximum,Open M02,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M03,P2,Largest OS text size,M03,OS text size at maximum,Open M03,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M04,P2,Largest OS text size,M04,OS text size at maximum,Open M04,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M05,P2,Largest OS text size,M05,OS text size at maximum,Open M05,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M06,P2,Largest OS text size,M06,OS text size at maximum,Open M06,"Nothing is clipped or truncated to meaninglessness. The shared total and the progress copy both stay readable.",,both,MVP
P2-TXT-M07,P2,Largest OS text size,M07,OS text size at maximum,Open M07,"Nothing is clipped or truncated to meaninglessness. The three stat columns wrap rather than overlap.",,both,MVP
P2-TXT-M08,P2,Largest OS text size,M08,OS text size at maximum,Open M08,"Nothing is clipped or truncated to meaninglessness. The sheet scrolls rather than hiding an option.",,both,MVP
P2-TXT-M09,P2,Largest OS text size,M09,OS text size at maximum,Open M09,"Nothing is clipped or truncated to meaninglessness. The caption truncates with a tap to expand, never silently.",,both,MVP
P2-TXT-M10,P2,Largest OS text size,M10,OS text size at maximum,Open M10,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M11,P2,Largest OS text size,M11,OS text size at maximum,Open M11,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M12,P2,Largest OS text size,M12,OS text size at maximum,Open M12,"Nothing is clipped or truncated to meaninglessness. The cost card wraps rather than truncating the numbers.",,both,MVP
P2-TXT-M13,P2,Largest OS text size,M13,OS text size at maximum,Open M13,"Nothing is clipped or truncated to meaninglessness. The overlay card stays inside the safe area.",,both,MVP
P2-TXT-M14,P2,Largest OS text size,M14,OS text size at maximum,Open M14,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M15,P2,Largest OS text size,M15,OS text size at maximum,Open M15,"Nothing is clipped or truncated to meaninglessness. Buttons stay tappable at 48 dp and no row collapses.",,both,MVP
P2-TXT-M16,P2,Largest OS text size,M16,OS text size at maximum,Open M16,"Nothing is clipped or truncated to meaninglessness. The camera controls stay reachable with one thumb.",,both,MVP
P2-TXT-M17,P2,Largest OS text size,M17,OS text size at maximum,Open the Community tab on a day-one account,"Nothing is clipped or truncated to meaninglessness. All three suggested groups stay visible without scrolling past the explanation.",,both,MVP
P2-OFF-M02,P2,Offline behaviour,M02,Airplane mode,Attempt the primary action on M02 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M02,P2,Server error handling,M02,Backend returns a 500,Trigger the primary action on M02 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M03,P2,Offline behaviour,M03,Airplane mode,Attempt the primary action on M03 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M03,P2,Server error handling,M03,Backend returns a 500,Trigger the primary action on M03 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M04,P2,Offline behaviour,M04,Airplane mode,Attempt the primary action on M04 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M04,P2,Server error handling,M04,Backend returns a 500,Trigger the primary action on M04 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M05,P2,Offline behaviour,M05,Airplane mode,Attempt the primary action on M05 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M05,P2,Server error handling,M05,Backend returns a 500,Trigger the primary action on M05 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M07,P2,Offline behaviour,M07,Airplane mode,Attempt the primary action on M07 with no network,"Either completes locally and queues, or is refused with a clear message. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M07,P2,Server error handling,M07,Backend returns a 500,Trigger the primary action on M07 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M08,P2,Offline behaviour,M08,Airplane mode,Attempt the primary action on M08 with no network,"Block takes effect locally at once. The report queues and says it has not sent yet. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M08,P2,Server error handling,M08,Backend returns a 500,Trigger the primary action on M08 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M11,P2,Offline behaviour,M11,Airplane mode,Attempt the primary action on M11 with no network,"The follow-up is held as a local draft badged as waiting, and publishes on reconnect. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M11,P2,Server error handling,M11,Backend returns a 500,Trigger the primary action on M11 against a failing backend,A human-readable error naming the problem and the recovery. No raw exception text. State is not corrupted.,,both,MVP
P2-OFF-M16,P2,Offline behaviour,M16,Airplane mode,Record and attempt to publish with no network,"Blur still runs on device and the clip is held locally with an explicit waiting state. Never a silent failure, never an endless spinner.",,both,MVP
P2-ERR-M16,P2,Server error handling,M16,Backend returns a 500,Trigger the publish on M16 against a failing backend,A human-readable error naming the problem and the recovery. The recorded clip is not lost. No raw exception text.,,both,MVP
```

---

## 10. Scalability gate — self-check, stated

| Gate | Result | Evidence |
|---|---|---|
| **Unbounded collection scan** | **PASS** | Every query carries a `limit` and an index: feed 10/chunk, comments 10, activity 10×3, explore 18, profile 12, stories 20, search 20. `members` and `likes` cannot be listed at all except constrained to her own posts. Stories are bounded by a TTL, not a sweep. The only unbounded iteration is the account-deletion batch over a woman's own follower mirrors, which is a one-off job, not a client query |
| **Per-user fan-out write that grows with followers** | **PASS** | Publishing writes **one** document, always. `audienceKeys` has at most 2 elements for any post. The only reader-side state (`followGraph/{uid}`) is written when *she* follows or joins — O(1) per her own action, never per her audience. `P0-COM-02` and `P1-COM-09` assert it against the emulator |
| **Unindexed query on a hot path** | **PASS** | Nine composite indexes declared (§6.3), one per query shape. No hot-path query relies on an automatic single-field index except `comments` by `createdAt` and `saved` by `savedAt`, both of which have one. The rules `get()` calls sit on the *write* path (like, comment, follow, post create), never on a list |
| **A design needing migration to reach 100k MAU** | **PASS** | No document grows without bound: `followingKeys` ≤300, `groupKeys` ≤10, `hiddenAuthors` ≤200, `creditedSessionIds` ≤20, `media` ≤10, `topics` ≤5. No counter needs sharding except the group challenge, which ships with the shard count as a field from day one. Deterministic ids mean no key redistribution. Story expiry is a TTL policy, not a job to rewrite |

**Verdict: passes all four.** The one number that is deliberately over a stated budget is reads per
active day (§2.4), which is a **$11/month** decision, disclosed here rather than at the end, with the
recommendation to re-baseline spine §4 rather than contort the design.

---

## 11. Open questions — named, because silence is a defect

| # | Question | Why it matters | Who decides |
|---|---|---|---|
| **OQ-1** | **`publicProfiles/{uid}` is a new top-level collection not in the spine.** It exists because `users/{uid}` is `allow get: if isSelf(uid)` — without it, no woman can render another woman's name, and M07 is unbuildable. | It is the only path outside `posts/**`, `groups/**`, `followGraph/**` that I claim. | Spine owner ratifies; G7 owns the projection that fills it |
| **OQ-2** | **`users/{uid}/saved/*` and `followGraph/{uid}.hiddenAuthors`.** Saved needs a block inside G8's ruleset (§6.2). `hiddenAuthors` is a client-readable mirror of blocks in both directions, which weakens G7's "she can never learn she was blocked" from absolute to unobservable-through-the-product. | The alternative is a server-rendered feed Function: +2.9M invocations/month (≈$3) and the loss of the offline feed cache. | G7 ratifies; G8 merges |
| **OQ-3** | **Public immutable CDN URLs are capability URLs.** A leaked link is fetchable by anyone, verified or not. Gating with a Cloudflare Worker + signed cookie preserves the cache key and costs ≈$20–40/month. | It is the women-only promise versus the $0-egress line, and it must be settled **before the CDN contract**. | Owner |
| **OQ-4** | **On-device reel blur on a budget Android handset.** Per-frame detection plus re-encode at 540p may exceed real time on the p50 device. | If a 60-second reel takes 3 minutes to export, women will turn blur off — which is a rule-6 failure by user experience rather than by code. Named mitigations: 540p capture, 15 fps sampling with tracking, background export with a notification. The measurement has not been taken. | Build measures on a real device before committing reels to the launch set |
| **OQ-5** | **Visible follower counts** are still open in `DECISIONS.md`. | The screens display them. I ship the display behind Remote Config `community_show_follower_counts`; the *ranking* prohibition is unconditional either way and is enforced by index exemptions. | Owner |
| **OQ-6** | **Blur cannot be proved server-side.** A server cannot look at an image and know a face was blurred. Enforcement is: domain constructor + `MediaUploadGateway` + attested ticket + App Check + moderation. | This is an honest limit on C11, and the QA sheet should not claim more. | Recorded, not resolved |
| **OQ-7** | **Are all groups open?** Every group in M04/M17 is joinable by any verified woman, so "Postpartum rebuild" is readable by anyone in the room. No private or secret group exists in the screens. | If a private group is wanted, the feed's `audienceKeys` design still holds, but reads need a membership check and the cost model changes. | Owner |
| **OQ-8** | **Voice notes in the community** (M02's composer, M03's "a voice note") are unowned. No group has planned recording, storage, playback or moderation of audio; G5 owns voice only for food logging. | A whole content type with no moderation story is a safety gap, not a missing feature. | Owner + G7; I hold the surface |
| **OQ-9** | **G3's arc tick command has no published symbol.** G3 §7 says community ticks `joinGroup` and `followUp` "through my command" but does not name it. | T07 steps 4 and 5 and therefore T08 depend on it. D1 makes this reachable; it must not fail on a missing symbol. | G3 names it |
| **OQ-10** | **The `scope` column's vocabulary is stale post-D1.** Five rows still say `Post-MVP`. | Whoever filters the suite on `scope == 'MVP'` will silently skip five rule guards, two of which are mine. | Suite owner re-stamps |
| **OQ-11** | **A reported story can expire before a moderator reads it.** A 24-hour TTL versus a one-hour response promise that only holds during staffed hours. | Evidence disappears exactly when it matters. Proposal: a reported story is copied to a server-side moderation hold for 30 days, which has PDPL implications. | G7 + owner |
| **OQ-12** | **Screenshots.** M03 says screenshots are "against the pledge". Android can set `FLAG_SECURE`; iOS cannot prevent them. | §4 forbids shipping one platform a capability the other silently lacks. **Recommendation: do not set `FLAG_SECURE`** — the copy promises a norm, not a mechanism, and a one-sided block would imply a guarantee iOS cannot keep. | Owner confirms the copy stands |
| **OQ-13** | **The `array-contains-any` limit is 30 today and was 10 before Nov 2023.** | If the deployed SDK enforces 10, the feed's chunk count triples and reads rise from 10 to 30 for a woman following 90 women. It is a cost variance, not a correctness one; `P0-COM-16` pins the behaviour. | Verified at build time against the SDK actually pinned |
