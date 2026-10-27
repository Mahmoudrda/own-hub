import test from "node:test";
import assert from "node:assert/strict";
import * as D from "./disputes-logic.js";

const NOW = Date.parse("2026-10-27T12:00:00Z");
const hoursAgo = (n) => new Date(NOW - n * 3600000).toISOString();

test("tabs and sections follow the claim, never the payments switch", () => {
  assert.deepEqual(D.DISPUTE_TABS, ["disputes", "fees"]);
  assert.deepEqual(D.disputeTabsFor({ womanReviewer: true }), ["disputes"]);
  assert.deepEqual(D.disputeTabsFor({ admin: true }), ["disputes", "fees"]);
  assert.deepEqual(D.disputeTabsFor({ finance: true }), ["fees"]);
  assert.deepEqual(D.disputeTabsFor({ womanReviewer: true, finance: true }), ["disputes", "fees"]);
  assert.deepEqual(D.disputeTabsFor({}), []);
  assert.deepEqual(D.disputeTabsFor(undefined), []);
  assert.deepEqual(D.sectionsFor({ womanReviewer: true }), ["queue", "flags", "address"]);
  assert.deepEqual(D.sectionsFor({ admin: true }), ["flags", "address", "switch"]);
  assert.deepEqual(D.sectionsFor({ finance: true }), []);
  assert.ok(!D.sectionsFor({ admin: true }).includes("queue"), "admins are refused the queue by the server");
  assert.ok(!D.sectionsFor({ womanReviewer: true }).includes("switch"));
  assert.equal(D.canSeeFees({ finance: true }), true);
  assert.equal(D.canSeeFees({ admin: true }), true);
  assert.equal(D.canSeeFees({ womanReviewer: true }), false);
});

test("pounds writes piasters", () => {
  assert.equal(D.pounds(50037), "500.37 EGP");
  assert.equal(D.pounds(50000), "500 EGP");
  assert.equal(D.pounds(5), "0.05 EGP");
  assert.equal(D.pounds("x"), "");
  assert.equal(D.pounds(null), "");
  assert.equal(D.pounds(undefined), "");
});

test("reason bounds: decisions and suspensions 10 to 500, the switch 5 to 300, spaces do not count", () => {
  assert.equal(D.reasonOk("a".repeat(9)), false);
  assert.equal(D.reasonOk("a".repeat(10)), true);
  assert.equal(D.reasonOk("a".repeat(500)), true);
  assert.equal(D.reasonOk("a".repeat(501)), false);
  assert.equal(D.reasonOk("   short   "), false);
  assert.equal(D.reasonOk(" ".repeat(20)), false);
  assert.equal(D.reasonOk(undefined), false);
  assert.equal(D.reasonOk("abcd", D.REASON_RULES.switch), false);
  assert.equal(D.reasonOk("abcde", D.REASON_RULES.switch), true);
  assert.equal(D.reasonOk("a".repeat(301), D.REASON_RULES.switch), false);
});

test("outcomes depend on the kind of case", () => {
  assert.deepEqual(D.outcomesFor("not_received", "in_review"), ["resolved_paid", "resolved_unpaid"]);
  assert.deepEqual(D.outcomesFor("proof_red", "in_review"), ["resolved_paid", "resolved_unpaid"]);
  assert.deepEqual(D.outcomesFor(null, "coach_not_received"), ["resolved_paid", "resolved_unpaid"]);
  assert.deepEqual(D.outcomesFor("silent_proof_submitted", "proof_submitted"), ["resolved_paid", "resolved_unpaid"]);
  for (const kind of ["service", "refund", "refund_not_received", "silent_refund_requested", "silent_service_dispute"]) {
    assert.deepEqual(D.outcomesFor(kind, "in_review"), ["refund_owed", "no_refund"], kind);
  }
  assert.deepEqual(D.outcomesFor(null, "refund_requested"), ["refund_owed", "no_refund"]);
  assert.equal(D.effectiveKind({ dispute: { kind: "service" } }, { kind: "x" }), "service");
  assert.equal(D.effectiveKind({}, { kind: "silent_refund_requested" }), "silent_refund_requested");
  assert.equal(D.effectiveKind({ status: "coach_not_received" }, {}), "not_received");
  assert.equal(D.effectiveKind({}, {}), null);
  assert.equal(D.outcomeLabel("no_refund", "refund_not_received"), "The refund did arrive");
  assert.equal(D.outcomeLabel("no_refund", "service"), "No refund is owed");
  assert.equal(D.outcomeLabel("resolved_paid", null), "The payment counts");
});

test("decisionPayload sends only what the server reads", () => {
  const ok = { paymentId: "p1", outcome: "resolved_paid", reason: "  Her bank list shows the transfer.  ", kind: "not_received", status: "in_review" };
  assert.deepEqual(D.decisionPayload(ok), { paymentId: "p1", outcome: "resolved_paid", reason: "Her bank list shows the transfer." });
  assert.throws(() => D.decisionPayload({ ...ok, reason: "too short" }), /Write the reason/);
  assert.throws(() => D.decisionPayload({ ...ok, reason: "x".repeat(501) }), /Write the reason/);
  assert.throws(() => D.decisionPayload({ ...ok, paymentId: "" }), /No payment/);
  assert.throws(() => D.decisionPayload({ ...ok, outcome: "" }), /Pick a decision/);
  assert.throws(() => D.decisionPayload({ ...ok, outcome: "refund_owed", amountPiasters: 100 }), /Pick a decision/, "a refund is not a way to settle a payment dispute");
  assert.throws(() => D.decisionPayload({ ...ok, outcome: "reopen" }), /Pick a decision/);
});

test("proofFalse is sent only for unpaid decisions on a claim or a red proof", () => {
  const base = { paymentId: "p1", reason: "The receipt was edited.", status: "in_review", proofFalse: true };
  assert.equal(D.decisionPayload({ ...base, outcome: "resolved_unpaid", kind: "not_received" }).proofFalse, true);
  assert.equal(D.decisionPayload({ ...base, outcome: "resolved_unpaid", kind: "proof_red" }).proofFalse, true);
  assert.equal("proofFalse" in D.decisionPayload({ ...base, outcome: "resolved_unpaid", kind: "silent_proof_submitted" }), false);
  assert.equal("proofFalse" in D.decisionPayload({ ...base, outcome: "resolved_paid", kind: "not_received" }), false);
  assert.equal("proofFalse" in D.decisionPayload({ ...base, proofFalse: false, outcome: "resolved_unpaid", kind: "not_received" }), false);
});

test("a refund is always the whole payment and never typed", () => {
  const base = { paymentId: "p1", outcome: "refund_owed", reason: "Nothing was delivered.", kind: "service", status: "in_review" };
  assert.deepEqual(D.decisionPayload({ ...base, amountPiasters: 50037 }), { paymentId: "p1", outcome: "refund_owed", reason: "Nothing was delivered.", refundPiasters: 50037 });
  assert.throws(() => D.decisionPayload({ ...base, amountPiasters: undefined }), /amount is missing/);
  assert.throws(() => D.decisionPayload({ ...base, amountPiasters: 0 }), /amount is missing/);
  assert.throws(() => D.decisionPayload({ ...base, amountPiasters: 10.5 }), /amount is missing/);
  const noRefund = D.decisionPayload({ ...base, outcome: "no_refund", amountPiasters: 50037 });
  assert.equal("refundPiasters" in noRefund, false);
});

test("suspend, lift, switch and fee payloads", () => {
  assert.deepEqual(D.suspendPayload("c1", "suspend", " Two lost disputes this month. "), { coachUid: "c1", action: "suspend", reason: "Two lost disputes this month." });
  assert.deepEqual(D.suspendPayload("c1", "lift", "She explained and sent proof."), { coachUid: "c1", action: "lift", reason: "She explained and sent proof." });
  assert.throws(() => D.suspendPayload("", "suspend", "long enough reason"), /No coach/);
  assert.throws(() => D.suspendPayload("c1", "approve", "long enough reason"), /Pick an action/);
  assert.throws(() => D.suspendPayload("c1", "suspend", "short"), /Write the reason/);
  assert.deepEqual(D.switchPayload(false, " Bank problem "), { enabled: false, reason: "Bank problem" });
  assert.throws(() => D.switchPayload("no", "Bank problem"), /Pick on or off/);
  assert.throws(() => D.switchPayload(false, "abc"), /Write the reason/);
  assert.throws(() => D.switchPayload(true, "x".repeat(301)), /Write the reason/);
  assert.deepEqual(D.confirmFeePayload("s1"), { statementId: "s1" });
  assert.throws(() => D.confirmFeePayload(""), /No statement/);
});

test("evidenceSummary always returns the seven items in order", () => {
  const full = {
    "1_amountAndReference": { amountPiasters: 50037, reference: "OH-4821" },
    "2_transactionNumber": { txnNumber: "123456789", digits: 9 },
    "3_ocr": { clientChecks: { amountFound: true }, riskScore: 5, coachStatement: null },
    "4_flags": { flags: {}, reasons: [], imageFlags: [] },
    "5_timeline": [{ from: "awaiting_payment", to: "proof_submitted", role: "client", at: "2026-10-26T10:00:00Z" }],
    "6_history": { coach: { paymentsConfirmed: 12, disputesLost: 0, strikes: 0 }, client: { strikes: 0 } },
    "7_statementRequest": null,
    clientProof: { outcome: "green" },
  };
  for (const input of [undefined, null, {}, full]) {
    const items = D.evidenceSummary(input);
    assert.deepEqual(items.map((i) => i.id), D.EVIDENCE_ORDER);
    assert.equal(items.length, 7);
  }
  assert.ok(D.evidenceSummary({}).every((i) => i.level === "missing"));
  const levels = Object.fromEntries(D.evidenceSummary(full).map((i) => [i.id, i.level]));
  assert.deepEqual(levels, { amount: "ok", txn: "ok", ocr: "ok", flags: "ok", timeline: "ok", history: "ok", statement: "missing" });
  assert.match(D.evidenceSummary(full)[0].text, /500\.37 EGP, reference OH-4821/);
});

test("evidenceSummary levels", () => {
  const level = (e, id) => D.evidenceSummary(e).find((i) => i.id === id).level;
  assert.equal(level({ "4_flags": { reasons: ["txnReused"] } }, "flags"), "bad");
  assert.equal(level({ "4_flags": { reasons: [], imageFlags: ["sameImage"] } }, "flags"), "bad");
  assert.equal(level({ "4_flags": { reasons: ["templateUnknown"] } }, "flags"), "warn");
  assert.equal(level({ clientProof: { outcome: "red" } }, "ocr"), "bad");
  assert.equal(level({ clientProof: { outcome: "amber" } }, "ocr"), "warn");
  assert.equal(level({ coachStatement: { amountFound: true } }, "ocr"), "bad");
  assert.equal(level({ "6_history": { coach: { strikes: 1 }, client: {} } }, "history"), "warn");
  assert.equal(level({ "6_history": { coach: {}, client: { strikes: 1 } } }, "history"), "warn");
  assert.equal(level({ addedEvidence: { client_1: {} } }, "statement"), "ok");
  assert.match(D.evidenceSummary({ "4_flags": { reasons: ["txnReused"] } })[3].text, /Transaction number already used/);
});

test("recommendation shows the server's suggestion, only when this case may use it", () => {
  const r = D.recommendation({ status: "in_review", recommended: { outcome: "resolved_paid", why: "green_proof_no_statement" } }, "not_received");
  assert.equal(r.outcome, "resolved_paid");
  assert.match(r.text, /Suggested: The payment counts\. Every automatic check passed/);
  const none = D.recommendation({ recommended: { outcome: null, why: "ask_for_bank_statement_line" } }, "not_received");
  assert.equal(none.outcome, null);
  assert.match(none.text, /bank statement line/);
  const wrongKind = D.recommendation({ recommended: { outcome: "refund_owed", why: "nothing_delivered" } }, "not_received");
  assert.equal(wrongKind.outcome, null);
  assert.equal(D.recommendation(undefined, null).text, "");
});

test("timeline rows read as sentences", () => {
  const rows = D.timelineRows({ "5_timeline": [{ from: "in_review", to: "resolved_paid", role: "staff", code: "staff_resolved_paid", at: "2026-10-26T10:00:00Z" }] });
  assert.equal(rows.length, 1);
  assert.match(rows[0].text, /in review to resolved paid, by staff \(staff_resolved_paid\)/);
  assert.deepEqual(D.timelineRows({}), []);
});

test("evidenceImages keeps plain base64 as jpeg data URLs and drops anything else", () => {
  const out = D.evidenceImages({ images: {
    "payment-proofs/p1/client-ab-1.jpg": "AAAA",
    "payment-proofs/p1/coach-cd-1.jpg": "BBBB==",
    "payment-proofs/p1/client-ef-2.jpg": 'x" onerror="alert(1)',
    "payment-proofs/p1/client-gh-3.jpg": "data:text/html,<script>",
    "payment-proofs/p1/client-ij-4.jpg": 5,
  } });
  assert.deepEqual(out, [
    { side: "client", src: "data:image/jpeg;base64,AAAA" },
    { side: "coach", src: "data:image/jpeg;base64,BBBB==" },
  ]);
  assert.deepEqual(D.evidenceImages({}), []);
  assert.deepEqual(D.evidenceImages(undefined), []);
});

test("the queue sorts the longest wait first and marks what is past the target", () => {
  const rows = D.sortQueue([
    { paymentId: "a", waitingHours: 3, riskScore: 9 },
    { paymentId: "b", waitingHours: 60, riskScore: 0 },
    { paymentId: "c", waitingHours: 3, riskScore: 40 },
  ]);
  assert.deepEqual(rows.map((r) => r.paymentId), ["b", "c", "a"]);
  const s = D.queueSummary({ paymentId: "b", reference: "OH-4821", amountPiasters: 50037, status: "in_review", kind: "silent_proof_submitted", lane: "escalated", waitingHours: 60, staffVisible: true });
  assert.equal(s.title, "OH-4821  500.37 EGP");
  assert.equal(s.overdue, true);
  assert.equal(s.escalated, true);
  assert.equal(s.firstPayments, true);
  assert.equal(s.kind, "Nobody answered in time");
  assert.match(s.waiting, /Waiting 60 hours \(target 48\)/);
  assert.equal(D.queueSummary({ waitingHours: 5 }).overdue, false);
});

test("a suspension needs two different staff: the one who asked cannot approve", () => {
  const proposal = { at: hoursAgo(2), approvals: 1 };
  const flagged = { coachFlagged: true };
  assert.deepEqual(D.suspensionState({}, null, undefined), { kind: "none", action: null, text: "" });
  assert.equal(D.suspensionState(flagged, null, undefined).action, "suspend");
  assert.equal(D.suspensionState(flagged, null, undefined).button, "Ask to suspend");
  const mine = D.suspensionState(flagged, proposal, proposal.at);
  assert.equal(mine.kind, "waiting");
  assert.equal(mine.action, null, "no button for the person who asked");
  assert.match(mine.text, /Awaiting second approval/);
  const other = D.suspensionState(flagged, proposal, undefined);
  assert.equal(other.kind, "approve");
  assert.equal(other.action, "suspend");
  assert.equal(other.button, "Approve suspension");
  const newerProposal = D.suspensionState(flagged, { ...proposal, at: hoursAgo(1) }, proposal.at);
  assert.equal(newerProposal.kind, "approve", "a marker from an older proposal does not count");
  assert.deepEqual([D.suspensionState({ coachSuspended: true }, null, undefined).kind, D.suspensionState({ coachSuspended: true }, null, undefined).action], ["suspended", "lift"]);
});

test("proposals older than seven days are stale", () => {
  assert.deepEqual(D.freshProposal({ type: "suspend", at: hoursAgo(24), approvals: ["a1"] }, NOW), { at: hoursAgo(24), approvals: 1 });
  assert.equal(D.freshProposal({ type: "suspend", at: hoursAgo(24 * 8), approvals: ["a1"] }, NOW), null);
  assert.equal(D.freshProposal({ type: "suspend", closed: true, at: hoursAgo(1) }, NOW), null);
  assert.equal(D.freshProposal({ type: "addressChange", at: hoursAgo(1) }, NOW), null);
  assert.equal(D.freshProposal(null, NOW), null);
});

test("flagRows joins proposals to flags and lists a proposal whose coach is no longer flagged", () => {
  const at = hoursAgo(3);
  const data = {
    flagged: [
      { uid: "c1", coachFlagged: true, flagReason: "twoStrikes", flaggedAt: hoursAgo(5), coachStrikes: 2, clientStrikes: 0 },
      { uid: "c2", coachSuspended: true, coachStrikes: 3 },
      { uid: "k1", clientSuspended: true, clientStrikes: 2 },
    ],
    alerts: [
      { id: "suspend__c1", type: "suspend", coachUid: "c1", at, approvals: ["h1"] },
      { id: "suspend__c9", type: "suspend", coachUid: "c9", at, approvals: ["h2"] },
      { id: "a1", type: "addressChange", coachUid: "c1", at, effectiveAt: hoursAgo(-21), firstTime: false },
    ],
  };
  const rows = D.flagRows(data, { c1: at }, NOW);
  assert.deepEqual(rows.map((r) => r.uid), ["c1", "c2", "k1", "c9"]);
  assert.deepEqual(rows[0].reasons, ["Two strikes in 90 days"]);
  assert.equal(rows[0].state.kind, "waiting");
  assert.equal(rows[1].state.action, "lift");
  assert.equal(rows[2].state.action, null, "a paused client has no coach action");
  assert.deepEqual(rows[2].reasons, ["Client paused"]);
  assert.equal(rows[3].state.kind, "approve");
  assert.equal(D.flagRows({}, {}, NOW).length, 0);
  assert.equal(D.flagRows(undefined).length, 0);
  const addresses = D.addressRows(data);
  assert.equal(addresses.length, 1);
  assert.equal(addresses[0].uid, "c1");
  assert.equal(addresses[0].first, false);
});

test("fee statements: late, claimed, and what can be confirmed", () => {
  const base = { statementId: "s1", coachUid: "c1", year: 2026, month: 9, totalDuePiasters: 12550, disputedPiasters: 0, settledPiasters: 0, waivedPiasters: 100, dueAt: hoursAgo(24) };
  const open = D.feeRow({ ...base, status: "open" }, NOW);
  assert.equal(open.title, "September 2026");
  assert.equal(open.status, "Late");
  assert.equal(open.late, true);
  assert.equal(open.canConfirm, true);
  assert.deepEqual(open.lines.map(([k]) => k), ["Fee due", "Waived", "Due by"]);
  assert.equal(D.feeRow({ ...base, status: "open", dueAt: hoursAgo(-24) }, NOW).status, "Open");
  const claimed = D.feeRow({ ...base, status: "paid_claimed", claimedTxn: "TX1234567" }, NOW);
  assert.equal(claimed.status, "Coach says she paid");
  assert.equal(claimed.claimed, true);
  assert.ok(claimed.lines.some(([k, v]) => k === "Her transfer number" && v === "TX1234567"));
  const paid = D.feeRow({ ...base, status: "paid", paidAt: hoursAgo(1) }, NOW);
  assert.equal(paid.status, "Paid");
  assert.equal(paid.late, false);
  assert.equal(paid.canConfirm, false);
  assert.equal(D.feeBadge([{ status: "paid_claimed" }, { status: "open" }, { status: "paid_claimed" }]), 2);
  assert.deepEqual(D.FEE_FILTERS, ["", "paid_claimed", "open", "paid"]);
});

test("the switch text covers on, off and unknown", () => {
  assert.match(D.switchText(true), /Payments are on/);
  assert.match(D.switchText(false), /Payments are off/);
  assert.match(D.switchText(undefined), /could not be read/);
});

test("paymentMessage maps reasons and never shows a raw functions/ code", () => {
  assert.match(D.paymentMessage({ message: "same_staff" }), /different staff member/);
  assert.match(D.paymentMessage({ message: "illegal_transition" }), /can not take this decision/);
  assert.equal(D.paymentMessage({ message: "staff_is_subject" }), "You cannot decide your own case.");
  assert.equal(D.paymentMessage({ details: { reason: "payment_not_found" }, message: "x" }), D.PAYMENT_ERROR_TEXT.payment_not_found);
  assert.match(D.paymentMessage({ code: "functions/unavailable", message: "functions/unavailable" }), /can not be reached/);
  assert.doesNotMatch(D.paymentMessage({ code: "functions/internal", message: "functions/internal" }), /functions\/internal$/);
});

test("cairoStamp ignores bad input", () => {
  assert.equal(D.cairoStamp(undefined), "");
  assert.equal(D.cairoStamp("x"), "");
  assert.match(D.cairoStamp("2026-10-27T10:30:00Z"), /27 Oct/);
});

test("show keeps server values short and plain", () => {
  assert.equal(D.show(undefined), "");
  assert.equal(D.show(["a", 2, null, true]), "a, 2, true");
  assert.equal(D.show({ a: 1, b: { c: 2 }, d: "" }), "a: 1; b: c: 2");
  assert.equal(D.show("x".repeat(400)).length, 303);
});

test("decided, takeover and notice texts", () => {
  assert.equal(D.decidedNote({}, null), "");
  assert.equal(D.decidedNote({ dispute: { kind: "service" } }, "service"), "");
  assert.match(D.decidedNote({ dispute: { staffDecision: "refund_owed", refundOwedPiasters: 50037, refundDueAt: "2026-11-03T10:00:00Z" } }, "service"), /A refund of 500\.37 EGP was already decided\. Due by 3 Nov/);
  assert.equal(D.decidedNote({ dispute: { staffDecision: "no_refund" } }, "refund_not_received"), "Staff already decided: The refund did arrive.");
  assert.match(D.takeoverNote("coach_not_received", {}), /takes this over from the coach's claim/);
  assert.match(D.takeoverNote("in_review", { lane: "escalated" }), /system hands it to staff/);
  assert.equal(D.takeoverNote("in_review", { lane: "review" }), "");
  assert.match(D.decisionNotice({ status: "in_review" }, "refund_owed"), /stays in review while the refund is owed/);
  assert.equal(D.decisionNotice({ status: "refunded" }, "no_refund"), "Decision sent. The payment is now: Refunded.");
  assert.equal(D.decisionNotice({ status: "resolved_paid" }, "resolved_paid"), "Decision sent. The payment is now: Paid (staff decision).");
});

test("evidenceImages never leaves a picture out", () => {
  const images = Object.fromEntries(Array.from({ length: 12 }, (_, i) => [`payment-proofs/p/client-t-${i}.jpg`, "AAAA"]));
  assert.equal(D.evidenceImages({ images }).length, 12);
});
