# Test cases — written before the code, on purpose

`TEST-CASES.csv` is the machine-readable suite. Columns:
`id, priority, journey, screens, precondition, steps, expected, rule_protected, platform, scope`

**Regenerate with `python3 6-v2/scripts/build_testcases.py`.** Do not hand-edit the CSV: the
generator rebuilds it from the screen inventory *and* merges the rows each feature-group plan
specifies, so a hand edit is silently discarded on the next run.

## Why this exists before any Dart is written

This product's behaviour comes from cited research and a legal check, not taste. The risk is not that
an implementer writes a bug — it is that an implementer writes something perfectly reasonable that
quietly violates a rule the product exists to keep. A daily streak, a pre-filled "actual" value, an
unblurred upload, a retained ID image, a calorie countdown: each is a normal thing to build, and each
breaks this product.

So the **P1 tier is written to fail when a rule is violated.** Those are the tests that protect the
product from its own implementers. If a rule genuinely needs to change, that is an owner decision
recorded in `DECISIONS.md` — and the research changes first.

The suite is also written **before** the implementation it covers, so that tests cannot be shaped to
fit whatever code happened to get written.

## Where the cases come from

| Source | Count |
|---|---|
| Generated from the screen inventory (state coverage, journeys) | 204 |
| Specified by the fifteen feature-group plans in `../plans/` | 388 |
| **Total** | **592** — 146 P0, 36 P1, 410 P2 |

A planning agent writes the cases its own screens need, in this exact CSV shape, inside its plan. The
generator extracts, validates and merges them. Two safeguards run on every build:

- **Id collisions are remapped, never dropped.** Three groups once numbered their rule guards from 12
  because each was told to continue after the existing eleven without being given a range; silently
  dropping the losers deleted six real guards from a suite that still looked complete. Every remap is
  printed.
- **Superseded cases are replaced.** `P1-RULE-10` became `10A`/`10B` because one test that can fail
  for two unrelated reasons cannot tell you which one broke.

## Priorities

- **P0 — the journeys that *are* the product**, including failure and recovery: verification in all
  four outcomes, every logging path, week counting and rest-week repair, the day-one states, offline,
  Arabic RTL, account deletion, consent withdrawal, the assistant's refusal.
- **P1 — one guard per non-negotiable rule**, each written so it fails on violation.
- **P2 — state coverage per screen**: Arabic RTL and large text for every screen, plus offline and
  server-error handling for every screen that writes.
- **P3 — deliberately deferred and not written:** animation timing, deep-link edge cases, locale
  switching mid-session, tablet layouts. Listed so the omission is a decision rather than an oversight.

## The `scope` column

Historical. It once separated a proposed MVP cut from what came later; `DECISIONS.md` **D1 withdrew
that cut**, so every feature ships and every row is in scope. The column is retained only so existing
tooling does not break — **do not filter on it.**

## Definition of done

**Every P0 and P1 case must be an executable Flutter test** — widget or integration — not a document
someone has read. P2 may be a mix of golden tests and a manual checklist. QA executes all of them per
platform, in both languages, and records pass/fail. An iOS row is *untested* until it has run on a
simulator; it is never "passing by parity".
