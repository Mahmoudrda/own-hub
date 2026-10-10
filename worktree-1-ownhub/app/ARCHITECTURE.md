# Architecture — Own Hub

Decisions for the Flutter application, each with the reason it was made and the source it was checked
against. Written **before** the implementation, and verified against official documentation rather
than recalled patterns.

Read `../DECISIONS.md` (owner decisions, authoritative), then `../BUILD-BRIEF.md` §2 (the eleven
non-negotiable product rules), then `../6-v2/SCHEMA-SPINE.md` (the fixed data layout) and
`../6-v2/plans/RECONCILIATION.md` (how fifteen feature plans reconcile).

---

## 1. Layers

Flutter's official architecture guide recommends two broad layers, with a third that is optional:

- **UI layer** — views and view models. *"Views are the primary method of rendering UI, and shouldn't
  contain any business logic."* Views and view models are one-to-one, and a paired view + view model
  is what the guide calls a feature.
- **Data layer** — repositories and services. Repositories are *"the source of truth for your model
  data"* and own caching, retries, error handling and app-wide lifecycle state. Services *"wrap API
  endpoints… they hold no state."*
- **Domain layer** — use-cases. Officially optional; the guide says to *"add use-cases only when
  needed."*

We use all three. **The domain layer is justified here by the guide's own three criteria**, not in
spite of them. The guide says to add use-cases when the logic (a) merges data from multiple
repositories, (b) is exceedingly complex, or (c) is reused by different view models. The §2 rules meet
all three:

| Rule | Why it cannot live in a view model |
|---|---|
| Rule 9 — five-second undo, never a confirmation | Logging happens in Today, Train, Eat and Community. Four view models sharing one rule means four chances to implement it differently. One `LogCommandBus` means one. |
| Rule 3 — weeks, not days | Week counting merges sessions **and** meals **and** the rest-week ledger: three repositories. |
| Rule 1 — a prescribed value is never a result | Enforced by *type*, not by check: `PrescribedSet` has no `actual` fields, so no widget can pre-fill one. |
| Rule 11 — nothing is ranked | Enforced by the absence of an ordering, plus index exemptions. |

So: **the eleven rules live in `domain/`, each with a test.** A view model may not restate a rule, and
a widget may never contain one.

> Source: [Flutter — Guide to app architecture](https://docs.flutter.dev/app-architecture/guide)

## 2. State management

**MVVM**, as the official guide recommends. View models hold presentation state and expose *commands*
to the view. This is the pattern the guide names, and it keeps UI logic testable without widgets.

No third-party state-management package is adopted without a specific reason recorded here. The
product's state is mostly per-screen plus a small amount of app-wide state, and the guide places
app-wide lifecycle state in repositories, which is where ours goes.

## 3. Folder structure — feature-first

The official guide does not mandate one, but it defines a *feature* as a view/view-model pair, and
our fifteen plans are organised by feature group. So:

```
lib/
  features/<flow>/        one per flow: signup, onboarding, today, train, eat,
    presentation/         progress, account, cycle, community, coaching, coached,
    domain/               assistant, coach, coach-setup, coachbrand, coachplan
    data/
  domain/                 cross-cutting rules that belong to no single feature
  data/                   repositories and services shared across features
  routing/                generated route table + the router
  theme/                  generated design tokens
  l10n/                   generated ARB + AppL10n
```

This matches `HANDOFF.md`'s suggested structure, so the mockup, the plans and the code all divide the
product the same way.

## 4. Firestore security rules — one ruleset per root, authored centrally

**Checked, because the entire design depends on it.** Firestore evaluates overlapping match
statements such that *"the access is allowed if **any** of the conditions is `true`"*. A more specific
rule **cannot revoke** what a broader one granted; there is no deny.

The consequence is not stylistic. If each feature group wrote its own `match /users/{uid}` block, one
permissive `allow update` anywhere would defeat every sibling denial — including the server-only guard
on `verification.status`, which is the line that makes this a women-only product. Three groups writing
`coaches/{coachUid}` creates the identical hazard.

Therefore: **`users/{uid}` and `coaches/{coachUid}` each have exactly one ruleset**, composed
centrally. Feature groups supply field-level *requirements*; global invariants are AND-ed **outside**
the OR-ed per-group slices. An unauthorised-write test proves it.

> Source: [Firestore — Structuring security rules](https://firebase.google.com/docs/firestore/security/rules-structure)

## 5. Indexing — exemptions are load-bearing, not housekeeping

Firestore automatically indexes every field, **including each non-array subfield of a map and the
elements of arrays** (ascending, descending and array-contains). An exemption *"overrides the
database-wide automatic index settings"*, and an exempted field cannot use automatic indexes.

So rule 11 — *nothing is ranked by weight, weight lost, or followers* — is enforced at the storage
layer only if the exemptions exist. Without them, `sets.actualWeight`, `measurements.weightKg` and
`followerCount` **are** queryable no matter what the code says, and the rule is false in production
while appearing true in review.

**Single-field index exemptions are deployment artifacts in `firestore.indexes.json`, not optional
tuning**, and a post-deploy check must assert that the forbidden query fails.

> Source: [Firestore — Index overview](https://firebase.google.com/docs/firestore/query-data/index-overview)

## 6. Offline — the defaults are not enough, and that is why the constraints exist

Documented behaviour: local changes are queued and synchronised on reconnect; listeners fire from the
cache while offline with `fromCache` distinguishing the source; the default cache is 100 MB, with
`CACHE_SIZE_UNLIMITED` available. **For multiple changes to the same document, it is *"last write
wins"*** — and that is the only conflict strategy the documentation offers.

Three consequences, which are exactly the spine's constraints:

1. **Last-write-wins loses data** for anything two devices can touch. Meal slots therefore merge with
   `arrayUnion`, and counters use `FieldValue.increment` (C3, C4).
2. **The docs do not document idempotency on retry**, so a replayed write can duplicate. Every
   document a woman writes offline has a **deterministic id** — date, ISO week, or exercise — so a
   replay collides instead of duplicating (C1). Increments additionally travel with a deterministic
   award id inside the same transaction, because an increment is commutative but *not* idempotent.
3. **No API is documented for cancelling a queued write.** The five-second undo therefore lives in a
   **local draft** that has not yet been handed to Firestore — not in Firestore's queue. Undo before
   the flush simply discards the draft; there is nothing to cancel.

Offline persistence is enabled with an unbounded cache. Logging never requires signal.

> Source: [Firestore — Access data offline](https://firebase.google.com/docs/firestore/manage-data/enable-offline)

## 7. Generated code is never hand-edited

Design tokens, the route table, the ARB files and the test suite are generated from `../6-v2/`. A hand
edit is silently discarded at the next regeneration, so a CI step re-runs the generators and fails on
any diff. See `README.md` → *Generated files*.

## 8. What this buys

Each rule has exactly one enforcement point, in a layer that can be tested without a widget, a device
or a network. When QA asks "where is rule 9 enforced?", the answer is a class name — not a search.
