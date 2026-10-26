# WO-10i1: staff dashboard, the pure logic for payment disputes
Depends on: server WO-10b (`staff_resolve_payment`, `staff_set_coach_payment_status`) and WO-10o (strikes); INDEX Q3 (list and evidence callables)
Size: M
Reads first: `admin-web/logic.js` lines 1030-1050 (`coachingTabsFor`), 1068-1080 (`appendPage`), 1149-1200 (`coachingMessage`); `admin-web/logic.test.mjs` lines 1-10 and 617-630; `admin-web/package.json`; spec 13.5, 13.6, 4.1, 4.13

## Why
Staff decide disputes from evidence. The one-screen summary must always show the same seven items in the same order (spec 13.6), a simple recommended decision, and refuse to send a decision without a typed reason. Suspending a coach needs a second reviewer, and no reviewer decides her own case. All of this is pure functions in a new file so it is tested without a browser and so the existing `logic.js` and its tests stay untouched. The tab must NOT depend on `PAYMENTS_LIVE`: disputes stay resolvable when the payments switch is off (spec 10).

## Final result
A new module `admin-web/disputes-logic.js` with the functions below, and `admin-web/disputes-logic.test.mjs` run by `node --test admin-web`. No screen yet (WO-10i2).

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| admin-web/disputes-logic.js | create | the functions |
| admin-web/disputes-logic.test.mjs | create | the tests |

## Steps
1. File `admin-web/disputes-logic.js` (create). Full content (plain ES module like `logic.js`; times in Cairo through `Intl`, money in piasters):
```js
// Payment disputes: what staff see and may send. Pure; no DOM.

export const DISPUTE_TABS = ["disputes"];

// Women reviewers and admins. Finance is not a dispute role. NOT gated by the
// payments switch: disputes stay resolvable when it is off (spec 10).
export function disputeTabsFor(claims) {
  const c = claims ?? {};
  return c.admin || c.womanReviewer ? [...DISPUTE_TABS] : [];
}

export const DISPUTE_SECTIONS = ["queue", "strikes", "addresses", "fees"];
export const DISPUTE_SECTION_LABELS = {
  queue: "Disputes", strikes: "Strikes and flags", addresses: "Address changes", fees: "Fee statements",
};

export const MIN_REASON = 15;
export const DECISIONS = ["paid", "unpaid", "request_statement"];
export const DECISION_LABELS = {
  paid: "The payment counts",
  unpaid: "No payment found",
  request_statement: "Ask both for a bank statement line",
};

export function pounds(piasters) {
  const n = Number(piasters);
  if (!Number.isFinite(n)) return "";
  const whole = Math.trunc(n / 100), rest = Math.abs(n % 100);
  return rest === 0 ? `${whole} EGP` : `${whole}.${String(rest).padStart(2, "0")} EGP`;
}

export function reasonOk(reason) {
  return typeof reason === "string" && reason.trim().length >= MIN_REASON && reason.trim().length <= 500;
}

// The body of staff_resolve_payment. Throws a plain Error with a staff sentence.
export function decisionPayload(paymentId, decision, reason) {
  if (!paymentId) throw new Error("No payment is open.");
  if (!DECISIONS.includes(decision)) throw new Error("Pick a decision.");
  if (!reasonOk(reason)) throw new Error(`Write the reason (at least ${MIN_REASON} characters).`);
  return { paymentId, decision, reason: reason.trim() };
}

export function suspendPayload(coachUid, reason) {
  if (!coachUid) throw new Error("No coach is open.");
  if (!reasonOk(reason)) throw new Error(`Write the reason (at least ${MIN_REASON} characters).`);
  return { coachUid, status: "suspend", reason: reason.trim() };
}

// Spec 13.5: a rate over 10 percent across 10 or more payments flags her. Owner-tunable.
export function disputeRate(lost, total) {
  const l = Number(lost) || 0, t = Number(total) || 0;
  return t > 0 ? l / t : 0;
}
export function flagged(lost, total, threshold = 0.1, minPayments = 10) {
  return (Number(total) || 0) >= minPayments && disputeRate(lost, total) > threshold;
}

const ORDER = [
  ["amount", "Unique amount and reference"],
  ["txn", "Transaction number and bank format"],
  ["ocr", "Reading of both screenshots"],
  ["flags", "Template and uniqueness flags"],
  ["timeline", "Timeline and notifications"],
  ["history", "Coach and client dispute history"],
  ["statement", "Bank statement lines"],
];
export const EVIDENCE_ORDER = ORDER.map(([id]) => id);

// Always seven items, always in the order of spec 13.6.
// Each: { id, label, level: "ok" | "warn" | "bad" | "missing", text }.
export function evidenceSummary(e) {
  const ev = e?.evidence ?? {};
  const item = (id, level, text) => ({ id, label: ORDER.find(([k]) => k === id)[1], level, text });
  const out = [];

  const a = ev.amountAndReference;
  out.push(a ? item("amount", a.noteSeenOnReceipt ? "ok" : "warn",
    `${pounds(a.amountPiasters)}, reference ${a.reference}${a.noteSeenOnReceipt ? ", reference seen on the receipt" : ", reference not seen on the receipt"}`)
    : item("amount", "missing", "Not available"));

  const t = ev.txn;
  out.push(t?.number ? item("txn", t.formatOk ? "ok" : "warn",
    `${t.number}${t.bankFormat ? ` (${t.bankFormat})` : ""}${t.formatOk ? "" : ", format not recognised"}`)
    : item("txn", "missing", "No transaction number"));

  const o = ev.ocr;
  if (o?.client || o?.coach) {
    const parts = [];
    if (o.client) parts.push(`client ${Math.round((o.client.matchScore ?? 0) * 100)} percent`);
    if (o.coach) parts.push(`coach ${Math.round((o.coach.matchScore ?? 0) * 100)} percent`);
    const lvl = o.riskOutcome === "green" ? "ok" : o.riskOutcome === "red" ? "bad" : "warn";
    out.push(item("ocr", lvl, `${parts.join(", ")}; outcome ${o.riskOutcome ?? "unknown"}${o.reasons?.length ? `: ${o.reasons.join(", ")}` : ""}`));
  } else out.push(item("ocr", "missing", "No screenshot was read"));

  const f = ev.flags;
  if (f) {
    const bad = [f.imageReused && "image reused", f.txnReused && "transaction number reused"].filter(Boolean);
    const warn = [f.templateUnknown && "unknown template", (f.tamperScore ?? 0) >= 0.5 && "tamper score high"].filter(Boolean);
    out.push(item("flags", bad.length ? "bad" : warn.length ? "warn" : "ok", [...bad, ...warn].join(", ") || "No flags"));
  } else out.push(item("flags", "missing", "Not available"));

  const tl = ev.timeline ?? [];
  out.push(tl.length ? item("timeline", "ok", `${tl.length} events, last: ${tl[tl.length - 1].to}`) : item("timeline", "missing", "No events"));

  const h = ev.history;
  if (h) {
    const c = h.coach ?? {}, cl = h.client ?? {};
    const lvl = flagged(c.lost, c.total) || (cl.strikes ?? 0) >= 1 ? "warn" : "ok";
    out.push(item("history", lvl, `coach lost ${c.lost ?? 0} of ${c.total ?? 0}, client strikes ${cl.strikes ?? 0}`));
  } else out.push(item("history", "missing", "Not available"));

  const s = ev.statement;
  out.push(s ? item("statement", s.client || s.coach ? "ok" : "warn",
    `client ${s.client ? "sent" : "not sent"}, coach ${s.coach ? "sent" : "not sent"}`)
    : item("statement", "missing", "Not requested"));
  return out;
}

// A simple rule set (spec 13.6). A suggestion only; staff must still type the reason.
export function recommend(e) {
  const ev = e?.evidence ?? {};
  if (ev.flags?.coachStatementShowsPayment) {
    return { decision: "paid", why: "The coach's own statement shows this payment. A strike will be recorded for her." };
  }
  if (ev.flags?.imageReused || ev.flags?.txnReused || ev.ocr?.riskOutcome === "red") {
    return { decision: "unpaid", why: "The proof contradicts the payment (reused image or number, or a deterministic mismatch)." };
  }
  if (ev.ocr?.riskOutcome === "green") {
    return { decision: "paid", why: "Every deterministic check passed." };
  }
  return { decision: "request_statement", why: "The evidence is not enough. Ask both sides for a bank statement line, other lines hidden." };
}

// Due times (spec 4.1). Returns [{ id, label, due, overdue }] sorted by due.
export function timers(t, now = Date.now()) {
  const rows = [
    ["coach48", "Coach reminder (48 hours)", t?.coachDeadline48],
    ["escalate72", "Auto review (72 hours)", t?.escalate72],
    ["review", "Staff decision target", t?.reviewDue],
  ];
  return rows.filter(([, , d]) => d).map(([id, label, d]) => ({ id, label, due: d, overdue: Date.parse(d) < now }))
    .sort((x, y) => Date.parse(x.due) - Date.parse(y.due));
}

export function sortDisputes(items, now = Date.now()) {
  const due = (x) => { const d = x?.timers?.reviewDue; return d ? Date.parse(d) : Infinity; };
  return [...items].sort((a, b) => due(a) - due(b));
}

// What the second-reviewer box says. The server enforces it; this only words it.
export function approvalState(pending, myUid) {
  if (!pending) return { kind: "none" };
  if (pending.requestedBy === myUid) return { kind: "waiting", text: "Waiting for a second reviewer." };
  return { kind: "approve", text: "A colleague asked to suspend this coach. Approve or decline." };
}

export const PAYMENT_ERROR_TEXT = {
  wrong_status: "Refresh and try again. The payment changed.",
  staff_is_subject: "You cannot decide your own case.",
  reason_required: "Write the reason.",
  waiting_second_reviewer: "Waiting for a second reviewer.",
  already_decided: "Someone already decided this.",
};

export function paymentMessage(e) {
  const reason = e?.details?.reason ?? e?.message;
  if (PAYMENT_ERROR_TEXT[reason]) return PAYMENT_ERROR_TEXT[reason];
  if (/unavailable|deadline/.test(e?.code ?? "")) return "Own Hub can not be reached. Check the internet and try again.";
  return e?.message && !/^functions\//.test(e.message) ? e.message : "Something went wrong. Try again.";
}

export function cairoStamp(iso) {
  if (typeof iso !== "string" || Number.isNaN(Date.parse(iso))) return "";
  return new Intl.DateTimeFormat("en-GB", { timeZone: "Africa/Cairo", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(iso));
}
```
2. File `admin-web/disputes-logic.test.mjs` (create). Header: `import test from "node:test"; import assert from "node:assert/strict"; import * as D from "./disputes-logic.js";` then the tests in the table.

## Strings to add
None (dashboard text is English only, as the rest of `admin-web`).

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| disputes-logic.test.mjs | `dispute tab follows the claim, not the payments switch` | `disputeTabsFor({womanReviewer:true})` equals `["disputes"]`; `({admin:true})` same; `({finance:true})` `[]`; `({})` and `undefined` `[]` |
| same | `pounds writes piasters` | `pounds(50037)` `500.37 EGP`; `pounds(50000)` `500 EGP`; `pounds(5)` `0.05 EGP`; `pounds("x")` `""` |
| same | `reason rule` | 14 characters false, 15 true, 501 false, whitespace only false |
| same | `decisionPayload refuses a missing reason, a bad decision, no payment` | three `assert.throws`; the good one returns the trimmed reason |
| same | `suspendPayload needs a coach and a reason` | |
| same | `flagged: 10 percent over 10 payments` | `flagged(2,10)` true; `flagged(1,10)` false (exactly 10 percent is not over); `flagged(3,9)` false (under 10 payments) |
| same | `evidenceSummary always returns the seven items in order` | for `undefined`, `{}`, a full object: ids equal `EVIDENCE_ORDER`; length 7; missing ones have level `missing` |
| same | `evidenceSummary levels` | image reused gives `flags` level `bad`; red outcome gives `ocr` `bad`; reference not seen gives `amount` `warn` |
| same | `recommend` | coach statement shows payment gives `paid`; reused number gives `unpaid`; green gives `paid`; nothing gives `request_statement`; order of rules: statement-shows-payment wins over red |
| same | `timers sort by due and mark overdue` | |
| same | `sortDisputes puts the soonest target first and no target last` | |
| same | `approvalState` | none; requested by me gives `waiting`; by someone else gives `approve` |
| same | `paymentMessage maps codes and never shows a raw functions/ code` | `staff_is_subject`; unavailable; unknown gives the generic sentence |
| same | `cairoStamp ignores bad input` | `""` for `undefined` and `"x"` |
Run: `cd admin-web && node --test`

## Verify
- `cd admin-web && node --test` ends with `# fail 0` and the new file's tests counted; the old `logic.test.mjs` count is unchanged.

## Do not
- Do not edit `logic.js`, `COACHING_TABS` or `PAYMENTS_LIVE` (the existing `deepEqual` assertions at `logic.test.mjs:619-629` would break).
- No function here may change an amount; there is no amount in any payload.
- Do not call a dispute decision without a reason.

## Done checklist
- [ ] module and tests; `node --test` green

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10j2).

UNVERIFIED in this order: 1 (the shape of the evidence object and the `decision` values are this order's assumption until WO-10b/10o are compared; the module reads them in one place, `evidenceSummary` and `recommend`).
