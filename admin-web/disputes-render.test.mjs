import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { mountPaymentsDesk } from "./disputes.js";

/* A small stand-in for the page: h() works like the dashboard's own, on plain objects. */

class El {
  constructor(tag) { this.tag = tag; this.attrs = {}; this.text = ""; this.children = []; this.on = {}; this.isConnected = true; this.value = ""; }
  replaceChildren(...kids) { this.children = kids.flat().map((k) => (typeof k === "string" ? textNode(k) : k)); }
}
const textNode = (text) => Object.assign(new El("#text"), { text });

function h(tag, props = {}, ...children) {
  const el = new El(tag);
  for (const [k, v] of Object.entries(props)) {
    if (v === false || v == null) continue;
    if (k === "text") el.text = v;
    else if (k === "vars") el.attrs.style = JSON.stringify(v);
    else if (k.startsWith("on")) { assert.equal(typeof v, "function", `${k} must be a function`); el.on[k.slice(2)] = v; }
    else el.attrs[k] = v === true ? "" : String(v);
  }
  el.replaceChildren(...children.flat().filter((c) => c != null));
  return el;
}

const all = (el, out = []) => { out.push(el); el.children.forEach((c) => all(c, out)); return out; };
const own = (el) => el.text;
const textOf = (el) => all(el).map(own).join(" ");
const find = (root, pred) => all(root).find(pred);
const button = (root, label) => find(root, (n) => n.tag === "button" && textOf(n).trim() === label);
const tick = () => new Promise((r) => setTimeout(r, 0));

const TAGS = new Set(["div", "p", "h2", "h3", "ul", "li", "span", "strong", "button", "label", "input", "textarea", "fieldset", "legend", "figure", "img", "#text"]);
const ATTRS = new Set(["class", "type", "id", "for", "rows", "maxlength", "role", "aria-label", "aria-pressed", "aria-busy", "aria-live", "name", "value", "checked", "disabled", "src", "alt", "style"]);

function harness({ claims, responses, tab = "disputes", sw = true }) {
  let current = claims;
  const roots = { "disputes-root": new El("div"), "fees-root": new El("div") };
  const calls = [], notices = [], badges = [];
  const ctx = {
    h,
    $: (id) => roots[id],
    call: async (name, data) => { calls.push([name, data]); const r = responses[name]; if (!r) throw new Error(`no answer for ${name}`); return typeof r === "function" ? r(data) : r; },
    notice: (t, ok) => notices.push([t, !!ok]),
    askDialog: async () => "yes",
    setEmpty: (el, o) => el.replaceChildren(h("strong", { text: o.title }), o.hint ? h("p", { text: o.hint }) : null),
    skeletons: () => [],
    setBadge: (t, n) => badges.push([t, n]),
    getState: () => ({ tab, claims: current }),
    readSwitch: async () => sw,
  };
  return { desk: mountPaymentsDesk(ctx), roots, calls, notices, badges, setClaims: (c) => { current = c; } };
}

const EVIL = '<img src=x onerror=alert(1)>';
const SCRIPT = "<script>alert(1)</script>";
const IMG_B64 = "iVBORw0KGgo=";

const hostileCase = () => ({
  status: "in_review",
  "1_amountAndReference": { amountPiasters: 50037, reference: EVIL },
  "2_transactionNumber": { txnNumber: SCRIPT, digits: 9 },
  "3_ocr": { clientChecks: { note: EVIL }, riskScore: 5, coachStatement: { note: SCRIPT, amountFound: false } },
  "4_flags": { flags: {}, reasons: [EVIL], imageFlags: [] },
  "5_timeline": [{ from: "in_review", to: SCRIPT, role: EVIL, code: SCRIPT, at: "2026-10-26T10:00:00Z" }],
  "6_history": { coach: { paymentsConfirmed: 3, disputesLost: 0, strikes: 0 }, client: { strikes: 0 } },
  "7_statementRequest": EVIL,
  addedEvidence: { x: EVIL },
  dispute: { kind: "not_received", clientNote: `${EVIL} ${SCRIPT}` },
  clientProof: { outcome: "amber", reasons: [EVIL] },
  recommended: { outcome: "resolved_paid", why: EVIL },
  images: { "payment-proofs/p1/client-a-1.jpg": IMG_B64, "payment-proofs/p1/coach-b-1.jpg": EVIL, "payment-proofs/p1/client-c-2.jpg": `${IMG_B64}" onerror="alert(1)` },
});

const queueAnswer = { items: [{ paymentId: "p1", lane: "review", status: "in_review", kind: "not_received", amountPiasters: 50037, reference: EVIL, waitingHours: 60, riskScore: 3, staffVisible: true }], next: null };

function assertSafe(root) {
  for (const n of all(root)) {
    assert.ok(TAGS.has(n.tag), `unexpected tag ${n.tag}`);
    for (const [k, v] of Object.entries(n.attrs)) {
      assert.ok(ATTRS.has(k), `unexpected attribute ${k}`);
      assert.doesNotMatch(v, /<|onerror|alert\(/i, `${k} carries server text`);
    }
    if (n.tag === "img") assert.match(n.attrs.src, /^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/);
    for (const k of Object.keys(n.on)) assert.ok(["click", "input", "change"].includes(k), `unexpected listener ${k}`);
  }
}

test("the new modules never build markup from text", () => {
  for (const file of ["disputes.js", "disputes-logic.js"]) {
    const src = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.doesNotMatch(src, /innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function/, file);
    assert.doesNotMatch(src, /—/, `${file} has an em dash`);
  }
});

test("a case full of hostile server text renders as plain text only", async () => {
  const t = harness({ claims: { womanReviewer: true }, responses: { staff_list_payment_queue: queueAnswer, staff_get_payment_evidence: () => hostileCase() } });
  await t.desk.load("disputes");
  const list = t.roots["disputes-root"];
  assert.ok(textOf(list).includes(EVIL), "the reference is shown as text");
  assertSafe(list);
  await button(list, "Open").on.click({ currentTarget: button(list, "Open") });
  await tick();
  const view = t.roots["disputes-root"];
  const shown = textOf(view);
  for (const s of [EVIL, SCRIPT]) assert.ok(shown.includes(s), `${s} is on the page as text`);
  assertSafe(view);
  const imgs = all(view).filter((n) => n.tag === "img");
  assert.equal(imgs.length, 1, "only the plain base64 picture is shown");
  assert.equal(imgs[0].attrs.src, `data:image/jpeg;base64,${IMG_B64}`);
});

test("flags and fee statements with hostile text render as plain text only", async () => {
  const flags = harness({ claims: { womanReviewer: true }, responses: {
    staff_list_payment_queue: { items: [], next: null },
    staff_list_payment_flags: {
      flagged: [{ uid: EVIL, coachFlagged: true, flagReason: SCRIPT, flaggedAt: SCRIPT, coachStrikes: 2, clientStrikes: 0 }],
      alerts: [{ id: SCRIPT, type: "addressChange", coachUid: EVIL, at: "2026-10-26T10:00:00Z", effectiveAt: SCRIPT, firstTime: true }],
    },
  } });
  await flags.desk.load("disputes");
  const chips = () => all(flags.roots["disputes-root"]).filter((n) => n.attrs["aria-pressed"] !== undefined);
  assert.deepEqual(chips().map(textOf).map((s) => s.trim()), ["Disputes", "Coach flags", "Address changes"]);
  await chips()[1].on.click();
  await tick();
  assert.ok(textOf(flags.roots["disputes-root"]).includes(EVIL));
  assertSafe(flags.roots["disputes-root"]);
  await chips()[2].on.click();
  await tick();
  assert.ok(textOf(flags.roots["disputes-root"]).includes(EVIL));
  assertSafe(flags.roots["disputes-root"]);

  const fee = harness({ claims: { finance: true }, tab: "fees", responses: { list_fee_statements: { items: [
    { statementId: SCRIPT, coachUid: EVIL, year: 2026, month: 9, status: "paid_claimed", totalDuePiasters: 12550, claimedTxn: SCRIPT, dueAt: "2026-10-01T00:00:00Z" },
  ], next: null } } });
  await fee.desk.load("fees");
  assert.ok(textOf(fee.roots["fees-root"]).includes(SCRIPT));
  assertSafe(fee.roots["fees-root"]);
  assert.deepEqual(fee.badges.at(-1), ["fees", 1]);
});

test("a decision is not sent without a reason, and is sent once there is one", async () => {
  const sent = [];
  const t = harness({ claims: { womanReviewer: true }, responses: {
    staff_list_payment_queue: queueAnswer,
    staff_get_payment_evidence: () => hostileCase(),
    staff_resolve_payment: (body) => { sent.push(body); return { status: "resolved_unpaid", outcome: body.outcome }; },
  } });
  await t.desk.load("disputes");
  await button(t.roots["disputes-root"], "Open").on.click({ currentTarget: button(t.roots["disputes-root"], "Open") });
  await tick();
  const view = () => t.roots["disputes-root"];
  const send = () => button(view(), "Send decision").on.click({ currentTarget: button(view(), "Send decision") });

  await send();
  assert.match(t.notices.at(-1)[0], /Pick a decision/);
  const radios = all(view()).filter((n) => n.tag === "input" && n.attrs.type === "radio");
  assert.deepEqual(radios.map((r) => r.attrs.value), ["resolved_paid", "resolved_unpaid"]);
  radios[1].on.change();
  assert.ok(textOf(view()).includes("Her proof was false"), "the strike tick is offered for an unpaid decision on a claim");
  await send();
  assert.match(t.notices.at(-1)[0], /Write the reason/);
  assert.equal(sent.length, 0);

  find(view(), (n) => n.tag === "textarea").on.input({ target: { value: "The receipt was edited after the transfer." } });
  find(view(), (n) => n.tag === "input" && n.attrs.type === "checkbox").on.change({ target: { checked: true } });
  await send();
  await tick();
  assert.deepEqual(sent, [{ paymentId: "p1", outcome: "resolved_unpaid", reason: "The receipt was edited after the transfer.", proofFalse: true }]);
  assert.match(t.notices.at(-1)[0], /Decision sent/);
});

test("a refund case offers refund outcomes and sends the whole payment", async () => {
  const sent = [];
  const refundCase = { ...hostileCase(), status: "in_review", dispute: { kind: "service" }, recommended: { outcome: "refund_owed", why: "nothing_delivered" } };
  const t = harness({ claims: { womanReviewer: true }, responses: {
    staff_list_payment_queue: { items: [{ ...queueAnswer.items[0], kind: "service", reference: "OH-1" }], next: null },
    staff_get_payment_evidence: () => refundCase,
    staff_resolve_payment: (body) => { sent.push(body); return { status: "in_review", outcome: body.outcome }; },
  } });
  await t.desk.load("disputes");
  await button(t.roots["disputes-root"], "Open").on.click({ currentTarget: button(t.roots["disputes-root"], "Open") });
  await tick();
  const view = () => t.roots["disputes-root"];
  const radios = all(view()).filter((n) => n.tag === "input" && n.attrs.type === "radio");
  assert.deepEqual(radios.map((r) => r.attrs.value), ["refund_owed", "no_refund"]);
  assert.ok(textOf(view()).includes("(suggested)"));
  radios[0].on.change();
  assert.ok(textOf(view()).includes("Refund owed: 500.37 EGP, the full payment"));
  assert.equal(all(view()).filter((n) => n.attrs.type === "number" || n.attrs.type === "text").length, 0, "no amount can be typed");
  find(view(), (n) => n.tag === "textarea").on.input({ target: { value: "Nothing was delivered to her." } });
  await button(view(), "Send decision").on.click({ currentTarget: button(view(), "Send decision") });
  await tick();
  assert.deepEqual(sent, [{ paymentId: "p1", outcome: "refund_owed", reason: "Nothing was delivered to her.", refundPiasters: 50037 }]);
});

test("two staff: the one who asks sees a wait, the other sees Approve", async () => {
  const at = new Date().toISOString();
  let proposal = null;
  const answers = {
    staff_list_payment_flags: () => ({ flagged: [{ uid: "c1", coachFlagged: true, flagReason: "twoStrikes", coachStrikes: 2 }], alerts: proposal ? [proposal] : [] }),
    staff_set_coach_payment_status: (body) => {
      if (!proposal) { proposal = { id: "suspend__c1", type: "suspend", coachUid: "c1", at, approvals: ["h1"] }; return { status: "awaiting_second_approval" }; }
      return { status: "suspended" };
    },
  };
  const first = harness({ claims: { womanReviewer: true, user_id: "u1" }, responses: answers });
  await first.desk.load("disputes");
  await first.desk.load("disputes");
  const chip = all(first.roots["disputes-root"]).find((n) => n.attrs["aria-pressed"] !== undefined && textOf(n).trim() === "Coach flags");
  await chip.on.click();
  await tick();
  const view = () => first.roots["disputes-root"];
  assert.ok(button(view(), "Ask to suspend"));
  await button(view(), "Ask to suspend").on.click({ currentTarget: button(view(), "Ask to suspend") });
  assert.match(first.notices.at(-1)[0], /short|reason|Write/i, "a reason is needed first");
  find(view(), (n) => n.tag === "textarea").on.input({ target: { value: "Two lost disputes in a month." } });
  await button(view(), "Ask to suspend").on.click({ currentTarget: button(view(), "Ask to suspend") });
  await tick();
  assert.equal(first.notices.at(-1)[0], "Waiting for a second reviewer.");
  assert.equal(button(view(), "Ask to suspend"), undefined);
  assert.equal(button(view(), "Approve suspension"), undefined, "she cannot approve her own request");
  assert.ok(textOf(view()).includes("You asked for this"));

  const second = harness({ claims: { admin: true }, responses: answers });
  await second.desk.load("disputes");
  assert.deepEqual(all(second.roots["disputes-root"]).filter((n) => n.attrs["aria-pressed"] !== undefined).map((n) => textOf(n).trim()), ["Coach flags", "Address changes", "Payments switch"]);
  const approve = button(second.roots["disputes-root"], "Approve suspension");
  assert.ok(approve, "a colleague can approve");
  find(second.roots["disputes-root"], (n) => n.tag === "textarea").on.input({ target: { value: "I read the same cases." } });
  await approve.on.click({ currentTarget: approve });
  await tick();
  assert.equal(second.notices.at(-1)[0], "Her payments are suspended.");
});

test("the server's same_staff refusal turns the button into a wait", async () => {
  const at = new Date().toISOString();
  const t = harness({ claims: { womanReviewer: true }, responses: {
    staff_list_payment_flags: { flagged: [{ uid: "c1", coachFlagged: true }], alerts: [{ id: "suspend__c1", type: "suspend", coachUid: "c1", at, approvals: ["h1"] }] },
    staff_set_coach_payment_status: () => { throw Object.assign(new Error("same_staff"), { code: "functions/failed-precondition" }); },
  } });
  await t.desk.load("disputes");
  const chip = all(t.roots["disputes-root"]).find((n) => n.attrs["aria-pressed"] !== undefined && textOf(n).trim() === "Coach flags");
  await chip.on.click();
  await tick();
  const view = () => t.roots["disputes-root"];
  find(view(), (n) => n.tag === "textarea").on.input({ target: { value: "Same reviewer again." } });
  await button(view(), "Approve suspension").on.click({ currentTarget: button(view(), "Approve suspension") });
  await tick();
  assert.match(t.notices.at(-1)[0], /different staff member/);
  assert.equal(button(view(), "Approve suspension"), undefined);
});

test("the switch needs a reason and a confirm, and shows the answer the server gave", async () => {
  const sent = [];
  const t = harness({ claims: { admin: true }, sw: true, responses: {
    staff_list_payment_flags: { flagged: [], alerts: [] },
    set_payments_enabled: (body) => { sent.push(body); return { enabled: body.enabled }; },
  } });
  await t.desk.load("disputes");
  const chip = all(t.roots["disputes-root"]).find((n) => n.attrs["aria-pressed"] !== undefined && textOf(n).trim() === "Payments switch");
  await chip.on.click();
  await tick();
  const view = () => t.roots["disputes-root"];
  assert.ok(textOf(view()).includes("Payments are on"));
  assert.equal(button(view(), "Turn payments on"), undefined, "only the opposite action is offered");
  await button(view(), "Turn payments off").on.click({ currentTarget: button(view(), "Turn payments off") });
  assert.match(t.notices.at(-1)[0], /Write the reason/);
  assert.equal(sent.length, 0);
  find(view(), (n) => n.tag === "textarea").on.input({ target: { value: "Bank outage" } });
  await button(view(), "Turn payments off").on.click({ currentTarget: button(view(), "Turn payments off") });
  await tick();
  assert.deepEqual(sent, [{ enabled: false, reason: "Bank outage" }]);
  assert.ok(textOf(view()).includes("Payments are off"));
});

test("a fee is confirmed only after the confirm step, and leaves the list", async () => {
  const sent = [];
  const t = harness({ claims: { finance: true }, tab: "fees", responses: {
    list_fee_statements: () => ({ items: [{ statementId: "s1", coachUid: "c1", year: 2026, month: 9, status: "paid_claimed", totalDuePiasters: 12550, dueAt: "2026-10-01T00:00:00Z" }].filter((s) => !sent.length), next: null }),
    confirm_fee_payment: (body) => { sent.push(body); return { status: "paid" }; },
  } });
  await t.desk.load("fees");
  const root = t.roots["fees-root"];
  assert.deepEqual(all(root).filter((n) => n.attrs["aria-pressed"] !== undefined).map((n) => textOf(n).trim()), ["All", "Coach says she paid", "Not paid yet", "Paid"]);
  await button(root, "Confirm the fee arrived").on.click({ currentTarget: button(root, "Confirm the fee arrived") });
  await tick();
  assert.deepEqual(sent, [{ statementId: "s1" }]);
  assert.equal(button(root, "Confirm the fee arrived"), undefined);
  assert.deepEqual(t.badges.at(-1), ["fees", 0]);
});

test("each tab loads only for the claims that may use it", async () => {
  const t = harness({ claims: { womanReviewer: true }, responses: {} });
  await t.desk.load("fees");
  assert.equal(t.calls.length, 0, "a reviewer has no fee statements");
  const none = harness({ claims: {}, responses: {} });
  await none.desk.load("disputes");
  assert.equal(none.calls.length, 0);
  const admin = harness({ claims: { admin: true }, responses: { staff_list_payment_flags: { flagged: [], alerts: [] } } });
  await admin.desk.load("disputes", { quiet: true });
  assert.equal(admin.calls.length, 0, "an admin has no queue to count");
});

test("her own request stays a wait after she leaves the tab, and is not inherited by a colleague", async () => {
  const at = new Date().toISOString();
  let proposal = null;
  const t = harness({ claims: { womanReviewer: true, user_id: "u1" }, responses: {
    staff_list_payment_flags: () => ({ flagged: [{ uid: "c1", coachFlagged: true }], alerts: proposal ? [proposal] : [] }),
    staff_set_coach_payment_status: () => { proposal = { id: "suspend__c1", type: "suspend", coachUid: "c1", at, approvals: ["h1"] }; return { status: "awaiting_second_approval" }; },
  } });
  const view = () => t.roots["disputes-root"];
  const toFlags = async () => {
    await t.desk.load("disputes");
    const chip = all(view()).find((n) => n.attrs["aria-pressed"] !== undefined && textOf(n).trim() === "Coach flags");
    await chip.on.click();
    await tick();
  };
  await toFlags();
  find(view(), (n) => n.tag === "textarea").on.input({ target: { value: "Two lost disputes in a month." } });
  await button(view(), "Ask to suspend").on.click({ currentTarget: button(view(), "Ask to suspend") });
  await tick();
  assert.ok(textOf(view()).includes("You asked for this"));

  t.desk.release();
  await toFlags();
  assert.ok(textOf(view()).includes("You asked for this"), "still her own request after release()");
  assert.equal(button(view(), "Approve suspension"), undefined);

  t.desk.release();
  t.setClaims({ womanReviewer: true, user_id: "u2" });
  await toFlags();
  assert.ok(button(view(), "Approve suspension"), "a different account on the same page may approve");
});

test("the case says when a refund was already decided and when sending takes the case over", async () => {
  const decided = { ...hostileCase(), status: "in_review", dispute: { kind: "service", staffDecision: "refund_owed", refundOwedPiasters: 50037, refundDueAt: "2026-11-03T10:00:00Z" }, recommended: { outcome: null, why: "ask_for_bank_statement_line" } };
  const t = harness({ claims: { womanReviewer: true }, responses: {
    staff_list_payment_queue: { items: [{ ...queueAnswer.items[0], kind: "service", reference: "OH-2" }, { ...queueAnswer.items[0], paymentId: "p2", status: "coach_not_received", kind: null, reference: "OH-3" }], next: null },
    staff_get_payment_evidence: (b) => (b.paymentId === "p1" ? decided : { ...hostileCase(), status: "coach_not_received", dispute: undefined }),
  } });
  await t.desk.load("disputes");
  const opens = () => all(t.roots["disputes-root"]).filter((n) => n.tag === "button" && textOf(n).trim() === "Open");
  await opens()[0].on.click({ currentTarget: opens()[0] });
  await tick();
  assert.match(textOf(t.roots["disputes-root"]), /A refund of 500\.37 EGP was already decided\. Due by 3 Nov/);
  button(t.roots["disputes-root"], "Back to the list").on.click();
  await opens()[1].on.click({ currentTarget: opens()[1] });
  await tick();
  assert.ok(textOf(t.roots["disputes-root"]).includes("takes this over from the coach's claim"));
});

test("every picture the server sends is shown", async () => {
  const many = { ...hostileCase(), images: Object.fromEntries(Array.from({ length: 9 }, (_, i) => [`payment-proofs/p1/${i % 2 ? "coach" : "client"}-t-${i}.jpg`, IMG_B64])) };
  const t = harness({ claims: { womanReviewer: true }, responses: { staff_list_payment_queue: queueAnswer, staff_get_payment_evidence: () => many } });
  await t.desk.load("disputes");
  await button(t.roots["disputes-root"], "Open").on.click({ currentTarget: button(t.roots["disputes-root"], "Open") });
  await tick();
  assert.equal(all(t.roots["disputes-root"]).filter((n) => n.tag === "img").length, 9);
});
