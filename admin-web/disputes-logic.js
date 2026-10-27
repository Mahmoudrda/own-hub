import { coachingMessage, flagLabel } from "./logic.js";

// Payment disputes, coach payment flags, fee statements and the payments switch.
// Pure functions; no DOM. The server decides who may do what: the claims here only decide what is shown.

export const DISPUTE_TABS = ["disputes", "fees"];
export const TAB_LABELS = { disputes: "Disputes", fees: "Fee statements" };

export const SECTIONS = ["queue", "flags", "address", "switch"];
export const SECTION_LABELS = { queue: "Disputes", flags: "Coach flags", address: "Address changes", switch: "Payments switch" };

// Queue, evidence and decisions: women reviewers only. Flags and suspensions: reviewers and admins. The switch: admins.
export function sectionsFor(claims) {
  const c = claims ?? {};
  const out = [];
  if (c.womanReviewer) out.push("queue");
  if (c.womanReviewer || c.admin) out.push("flags", "address");
  if (c.admin) out.push("switch");
  return out;
}

export const canSeeFees = (claims) => !!(claims?.finance || claims?.admin);

export function disputeTabsFor(claims) {
  const out = [];
  if (sectionsFor(claims).length) out.push("disputes");
  if (canSeeFees(claims)) out.push("fees");
  return out;
}

/* money, times, words */

export function pounds(piasters) {
  const n = Number(piasters);
  if (piasters === null || piasters === "" || !Number.isFinite(n)) return "";
  const a = Math.abs(n);
  const whole = Math.floor(a / 100), rest = a % 100;
  const sign = n < 0 ? "-" : "";
  return rest === 0 ? `${sign}${whole} EGP` : `${sign}${whole}.${String(rest).padStart(2, "0")} EGP`;
}

export function cairoStamp(iso) {
  if (typeof iso !== "string" || Number.isNaN(Date.parse(iso))) return "";
  return new Intl.DateTimeFormat("en-GB", { timeZone: "Africa/Cairo", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(iso));
}

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

// Server text is shown as text only, but it is also kept short: a long value is cut.
export function clip(text, max = 300) {
  const t = String(text ?? "");
  return t.length > max ? `${t.slice(0, max)}...` : t;
}

// Any value the server sends, as one plain line. Never HTML.
export function show(v, depth = 0) {
  if (v === null || v === undefined || v === "") return "";
  if (typeof v === "string") return clip(v);
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  if (Array.isArray(v)) return clip(v.map((x) => show(x, depth + 1)).filter(Boolean).join(", "));
  if (typeof v === "object") {
    if (depth >= 2) return "";
    return clip(Object.entries(v).map(([k, x]) => { const s = show(x, depth + 1); return s === "" ? null : `${k}: ${s}`; }).filter(Boolean).join("; "));
  }
  return "";
}

/* reasons and payloads */

export const REASON_RULES = {
  decision: [10, 500],
  suspend: [10, 500],
  switch: [5, 300],
};

export function reasonOk(reason, [min, max] = REASON_RULES.decision) {
  if (typeof reason !== "string") return false;
  const n = [...reason.trim()].length;
  return n >= min && n <= max;
}

const needReason = (reason, rule) => {
  if (!reasonOk(reason, rule)) throw new Error(`Write the reason (at least ${rule[0]} characters).`);
  return reason.trim();
};

const REFUND_KINDS = ["service", "refund", "refund_not_received", "silent_refund_requested", "silent_service_dispute", "silent_refund_denied"];
const REFUND_STATUSES = ["refund_requested", "service_dispute", "refund_denied"];
const STRIKE_KINDS = ["not_received", "proof_red"];

// The kind the server will see: the dispute's own, else the queue row's, else what the status implies.
export function effectiveKind(evidence, row) {
  const own = evidence?.dispute?.kind ?? row?.kind ?? null;
  if (own) return own;
  return (evidence?.status ?? row?.status) === "coach_not_received" ? "not_received" : null;
}

export const isRefundCase = (kind, status) => REFUND_KINDS.includes(kind) || REFUND_STATUSES.includes(status);

// Money questions end in "refund owed" or "no refund". Everything else ends in "paid" or "unpaid".
export function outcomesFor(kind, status) {
  return isRefundCase(kind, status) ? ["refund_owed", "no_refund"] : ["resolved_paid", "resolved_unpaid"];
}

const OUTCOME_LABELS = {
  resolved_paid: "The payment counts",
  resolved_unpaid: "No payment found",
  refund_owed: "A refund is owed to the client",
  no_refund: "No refund is owed",
};

export function outcomeLabel(outcome, kind) {
  if (kind === "refund_not_received") {
    if (outcome === "no_refund") return "The refund did arrive";
    if (outcome === "refund_owed") return "The refund is still owed";
  }
  return OUTCOME_LABELS[outcome] ?? "";
}

// Whether the "her proof was false" tick is offered (the server records a client strike only then).
export const canMarkProofFalse = (outcome, kind) => outcome === "resolved_unpaid" && STRIKE_KINDS.includes(kind);

// The body of staff_resolve_payment. A refund is always the whole payment: the dashboard never types an amount.
export function decisionPayload({ paymentId, outcome, reason, kind, status, amountPiasters, proofFalse }) {
  if (!paymentId) throw new Error("No payment is open.");
  if (!outcomesFor(kind, status).includes(outcome)) throw new Error("Pick a decision.");
  const body = { paymentId, outcome, reason: needReason(reason, REASON_RULES.decision) };
  if (proofFalse === true && canMarkProofFalse(outcome, kind)) body.proofFalse = true;
  if (outcome === "refund_owed") {
    if (!Number.isInteger(amountPiasters) || amountPiasters < 1) throw new Error("The payment amount is missing. Refresh and try again.");
    body.refundPiasters = amountPiasters;
  }
  return body;
}

// action is "suspend" (the first request, or the second approval) or "lift".
export function suspendPayload(coachUid, action, reason) {
  if (!coachUid) throw new Error("No coach is open.");
  if (action !== "suspend" && action !== "lift") throw new Error("Pick an action.");
  return { coachUid, action, reason: needReason(reason, REASON_RULES.suspend) };
}

export function switchPayload(enabled, reason) {
  if (typeof enabled !== "boolean") throw new Error("Pick on or off.");
  return { enabled, reason: needReason(reason, REASON_RULES.switch) };
}

export function confirmFeePayload(statementId) {
  if (!statementId) throw new Error("No statement is open.");
  return { statementId };
}

/* the queue */

export const REVIEW_TARGET_HOURS = 48;

const STATUS_TEXT = {
  in_review: "In review",
  coach_not_received: "Coach says it did not arrive",
  proof_submitted: "Waiting for the coach",
  refund_requested: "Refund asked",
  service_dispute: "Service problem",
  refund_denied: "Refund refused",
  resolved_paid: "Paid (staff decision)",
  resolved_unpaid: "Not paid (staff decision)",
  confirmed: "Confirmed",
  refunded: "Refunded",
};
const plain = (s) => show(s).replace(/_/g, " ");
export const statusText = (s) => STATUS_TEXT[s] ?? plain(s);

const KIND_TEXT = {
  not_received: "Coach says it did not arrive",
  proof_red: "The proof did not pass the checks",
  service: "Service problem",
  refund: "Refund question",
  refund_not_received: "Client says the refund never came",
  different_amount: "Coach says a different amount arrived",
};
export function kindText(kind) {
  if (!kind) return "";
  if (kind.startsWith("silent_")) return "Nobody answered in time";
  return KIND_TEXT[kind] ?? kind.replace(/_/g, " ");
}

// Longest wait first, then the higher risk score. A row past the target is marked.
export function sortQueue(items) {
  return [...items].sort((a, b) => (b.waitingHours ?? 0) - (a.waitingHours ?? 0) || (b.riskScore ?? 0) - (a.riskScore ?? 0));
}

export function queueSummary(p) {
  const hours = Number(p?.waitingHours) || 0;
  const overdue = hours >= REVIEW_TARGET_HOURS;
  return {
    paymentId: p?.paymentId,
    title: `${show(p?.reference)}  ${pounds(p?.amountPiasters)}`.trim(),
    status: statusText(p?.status),
    kind: kindText(p?.kind),
    waiting: `Waiting ${hours} hours${overdue ? ` (target ${REVIEW_TARGET_HOURS})` : ""}`,
    overdue,
    escalated: p?.lane === "escalated",
    firstPayments: p?.staffVisible === true,
  };
}

/* the case */

const ORDER = [
  ["amount", "Unique amount and reference"],
  ["txn", "Transaction number"],
  ["ocr", "Reading of the screenshots"],
  ["flags", "Template and uniqueness flags"],
  ["timeline", "Timeline"],
  ["history", "Coach and client dispute history"],
  ["statement", "Bank statement lines"],
];
export const EVIDENCE_ORDER = ORDER.map(([id]) => id);

const REPEAT_FLAGS = ["txnReused", "sameImage", "nearImage"];
const FLAG_TEXT = { txnReused: "Transaction number already used", sameImage: "Same picture as another payment", nearImage: "Looks like another payment's picture" };
const flagWords = (f) => FLAG_TEXT[f] ?? flagLabel(f);

// Always seven items, always in the order of spec 13.6: { id, label, level: ok | warn | bad | missing, text }.
export function evidenceSummary(e) {
  const ev = e ?? {};
  const item = (id, level, text) => ({ id, label: ORDER.find(([k]) => k === id)[1], level, text: clip(text, 600) });
  const out = [];

  const a = ev["1_amountAndReference"];
  out.push(a ? item("amount", "ok", `${pounds(a.amountPiasters)}, reference ${show(a.reference)}`) : item("amount", "missing", "Not available"));

  const t = ev["2_transactionNumber"];
  out.push(t?.txnNumber ? item("txn", "ok", `${show(t.txnNumber)} (${show(t.digits)} digits)`) : item("txn", "missing", "No transaction number"));

  const o = ev["3_ocr"] ?? {};
  const colour = ev.clientProof?.outcome;
  const cs = ev.coachStatement;
  if (o.clientChecks || cs || colour) {
    const parts = [`Client's receipt: ${show(colour) || "unknown"}`];
    if (o.riskScore !== undefined && o.riskScore !== null) parts.push(`risk score ${show(o.riskScore)}`);
    if (o.clientChecks) parts.push(`checks ${show(o.clientChecks)}`);
    if (cs) parts.push(`coach's own bank list: ${show(cs)}`);
    const found = cs?.amountFound || cs?.txnFound;
    const level = found || colour === "red" ? "bad" : colour === "green" ? "ok" : "warn";
    out.push(item("ocr", level, parts.join(". ")));
  } else out.push(item("ocr", "missing", "No screenshot was read"));

  const f = ev["4_flags"];
  if (f) {
    const names = [...new Set([...(Array.isArray(f.reasons) ? f.reasons : []), ...(Array.isArray(f.imageFlags) ? f.imageFlags : [])])].map(String);
    const level = names.some((n) => REPEAT_FLAGS.includes(n)) ? "bad" : names.length ? "warn" : "ok";
    out.push(item("flags", level, names.map(flagWords).join(", ") || "No flags"));
  } else out.push(item("flags", "missing", "Not available"));

  const tl = Array.isArray(ev["5_timeline"]) ? ev["5_timeline"] : [];
  const last = tl[tl.length - 1];
  out.push(last ? item("timeline", "ok", `${tl.length} events, last: ${statusText(last.to)}${cairoStamp(last.at) ? ` on ${cairoStamp(last.at)}` : ""}`) : item("timeline", "missing", "No events"));

  const h = ev["6_history"];
  if (h) {
    const c = h.coach ?? {}, cl = h.client ?? {};
    const level = (c.strikes ?? 0) > 0 || (cl.strikes ?? 0) > 0 || (c.disputesLost ?? 0) > 0 ? "warn" : "ok";
    out.push(item("history", level, `Coach: ${c.disputesLost ?? 0} disputes lost, ${c.paymentsConfirmed ?? 0} payments confirmed, ${c.strikes ?? 0} strikes. Client: ${cl.strikes ?? 0} strikes`));
  } else out.push(item("history", "missing", "Not available"));

  const req = ev["7_statementRequest"];
  const bits = [req ? `Requested: ${show(req)}` : "", ev.addedEvidence ? "Pictures or notes were added after the dispute began" : ""].filter(Boolean);
  out.push(bits.length ? item("statement", "ok", bits.join(". ")) : item("statement", "missing", "Not requested"));
  return out;
}

// The audit trail of the payment: who moved it where, and when.
export function timelineRows(e) {
  const tl = Array.isArray(e?.["5_timeline"]) ? e["5_timeline"] : [];
  return tl.map((x) => ({
    when: cairoStamp(x?.at),
    text: `${plain(x?.from) || "start"} to ${plain(x?.to)}, by ${show(x?.role) || "the system"}${x?.code ? ` (${show(x.code)})` : ""}`,
  }));
}

const WHY_TEXT = {
  statement_contradicts_claim: "The coach's own bank list shows this payment.",
  proof_reused: "The proof uses a picture or transaction number seen before.",
  green_proof_no_statement: "Every automatic check passed and the coach sent no bank list.",
  green_proof_coach_silent: "Every automatic check passed and the coach did not answer.",
  refund_unconfirmed: "The coach says she refunded. The client says it never came.",
  sessions_delivered: "Sessions were delivered.",
  nothing_delivered: "No sessions were delivered.",
  ask_for_bank_statement_line: "Not enough to suggest an answer. A bank statement line from both sides would settle it.",
};

// The server's suggestion. Only an outcome this case may use is marked.
export function recommendation(e, kind) {
  const r = e?.recommended ?? {};
  const allowed = outcomesFor(kind, e?.status);
  const outcome = allowed.includes(r.outcome) ? r.outcome : null;
  const why = WHY_TEXT[r.why] ?? "";
  return { outcome, text: outcome ? `Suggested: ${outcomeLabel(outcome, kind)}. ${why}` : why };
}

// What the screen says about a decision that already exists. A refund decision leaves the payment in
// review, so the case comes back to the queue and must show that someone decided.
export function decidedNote(e, kind) {
  const d = e?.dispute ?? {};
  if (!d.staffDecision) return "";
  if (d.staffDecision === "refund_owed") {
    const due = cairoStamp(d.refundDueAt);
    return `A refund of ${pounds(d.refundOwedPiasters)} was already decided.${due ? ` Due by ${due}.` : ""}`;
  }
  return `Staff already decided: ${outcomeLabel(d.staffDecision, kind) || plain(d.staffDecision)}.`;
}

// The server takes a case over inside the decision; this says so before staff send it.
export function takeoverNote(status, row) {
  if (status === "coach_not_received") return "Sending a decision takes this over from the coach's claim.";
  if (row?.lane === "escalated") return "The system hands it to staff when you decide.";
  return "";
}

export function decisionNotice(res, outcome) {
  if (outcome === "refund_owed") return "Decision sent. The payment stays in review while the refund is owed.";
  return `Decision sent. The payment is now: ${statusText(res?.status)}.`;
}

// The pictures the server sent, as data URLs; the server bounds how many there are, so none is left out.
// Anything that is not plain base64 is dropped.
export function evidenceImages(e) {
  const map = e?.images && typeof e.images === "object" ? e.images : {};
  return Object.entries(map).flatMap(([path, b64]) => {
    if (typeof b64 !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(b64)) return [];
    const name = String(path).split("/").pop() ?? "";
    return [{ side: name.startsWith("coach-") ? "coach" : "client", src: `data:image/jpeg;base64,${b64}` }];
  });
}

/* coach flags and the two-staff suspension */

export const PROPOSAL_DAYS = 7;
const FLAG_REASON_TEXT = { twoStrikes: "Two strikes in 90 days", disputeRate: "Too many lost disputes" };

// A suspension proposal is stale after seven days: the server starts a new one.
export function freshProposal(alert, now = Date.now()) {
  if (!alert || alert.type !== "suspend" || alert.closed) return null;
  const at = Date.parse(alert.at);
  if (Number.isNaN(at) || now > at + PROPOSAL_DAYS * 86400000) return null;
  return { at: alert.at, approvals: Array.isArray(alert.approvals) ? alert.approvals.length : 0 };
}

// mine: { [coachUid]: proposal.at } for the proposals this person made in this browser session.
export function suspensionState({ coachSuspended, coachFlagged }, proposal, mineAt) {
  if (coachSuspended) return { kind: "suspended", action: "lift", button: "Lift suspension", text: "Her payments are suspended. One reviewer can lift it." };
  if (proposal && mineAt === proposal.at) {
    return { kind: "waiting", action: null, text: "Awaiting second approval. You asked for this, so a different staff member must approve it." };
  }
  if (proposal) {
    return { kind: "approve", action: "suspend", button: "Approve suspension", text: "Awaiting second approval. A colleague asked to suspend her payments. Write your own reason to approve, or leave it." };
  }
  if (coachFlagged) return { kind: "none", action: "suspend", button: "Ask to suspend", text: "A second reviewer must approve before it takes effect. Her current clients are not cut off." };
  return { kind: "none", action: null, text: "" };
}

export function flagRows(data, mine = {}, now = Date.now()) {
  const alerts = Array.isArray(data?.alerts) ? data.alerts : [];
  const proposals = new Map();
  for (const a of alerts) {
    const p = a.coachUid ? freshProposal(a, now) : null;
    if (p) proposals.set(a.coachUid, p);
  }
  const rows = new Map();
  for (const f of Array.isArray(data?.flagged) ? data.flagged : []) rows.set(f.uid, f);
  for (const uid of proposals.keys()) if (!rows.has(uid)) rows.set(uid, { uid });
  return [...rows.values()].map((f) => {
    const proposal = proposals.get(f.uid) ?? null;
    const reasons = [FLAG_REASON_TEXT[f.flagReason] ?? (f.coachFlagged ? "Flagged" : ""), f.coachSuspended && "Suspended", f.clientSuspended && "Client paused"].filter(Boolean);
    return {
      uid: f.uid,
      reasons,
      flaggedAt: cairoStamp(f.flaggedAt),
      strikes: `Coach strikes ${f.coachStrikes ?? 0}, client strikes ${f.clientStrikes ?? 0}`,
      proposal,
      state: suspensionState(f, proposal, mine[f.uid]),
    };
  });
}

export function addressRows(data) {
  return (Array.isArray(data?.alerts) ? data.alerts : []).filter((a) => a.type === "addressChange").map((a) => ({
    id: a.id,
    uid: a.coachUid ?? null,
    changed: cairoStamp(a.at),
    effective: cairoStamp(a.effectiveAt),
    first: a.firstTime === true,
  }));
}

/* fee statements */

export const FEE_FILTERS = ["", "paid_claimed", "open", "paid"];
export const FEE_FILTER_LABELS = { "": "All", paid_claimed: "Coach says she paid", open: "Not paid yet", paid: "Paid" };

export function feeRow(s, now = Date.now()) {
  const due = Date.parse(s?.dueAt);
  const late = s?.status !== "paid" && !Number.isNaN(due) && due < now;
  const status = s?.status === "paid" ? "Paid" : s?.status === "paid_claimed" ? "Coach says she paid" : late ? "Late" : "Open";
  const month = MONTHS[(Number(s?.month) || 0) - 1];
  return {
    id: s?.statementId,
    title: `${month ?? ""} ${s?.year ?? ""}`.trim(),
    coach: show(s?.coachUid),
    status,
    late,
    canConfirm: s?.status === "paid_claimed" || s?.status === "open",
    claimed: s?.status === "paid_claimed",
    lines: [
      ["Fee due", pounds(s?.totalDuePiasters)],
      ["In dispute", Number(s?.disputedPiasters) ? pounds(s.disputedPiasters) : ""],
      ["Settled", Number(s?.settledPiasters) ? pounds(s.settledPiasters) : ""],
      ["Waived", Number(s?.waivedPiasters) ? pounds(s.waivedPiasters) : ""],
      ["Due by", cairoStamp(s?.dueAt)],
      ["Her transfer number", show(s?.claimedTxn)],
      ["Paid on", cairoStamp(s?.paidAt)],
    ].filter(([, v]) => v),
  };
}

export const feeBadge = (items) => items.filter((s) => s?.status === "paid_claimed").length;

/* the payments switch */

// enabled: true, false, or undefined while unknown. A missing document is off on the server.
export function switchText(enabled) {
  if (enabled === true) return "Payments are on. Clients can start new InstaPay payments.";
  if (enabled === false) return "Payments are off. No new payment can start. Payments already made can still be confirmed, refunded and decided.";
  return "The current setting could not be read.";
}

/* errors */

export const PAYMENT_ERROR_TEXT = {
  same_staff: "A different staff member must do this. You already did your part.",
  illegal_transition: "That payment can not take this decision now. Refresh the list.",
  payment_not_found: "That payment is gone. Refresh the list.",
  reason_required: "Write the reason (at least 10 characters).",
  wrong_status: "Refresh and try again. It changed.",
  staff_is_subject: "You cannot decide your own case.",
  payments_off: "Payments are switched off.",
};

export function paymentMessage(e) {
  const reason = String(e?.details?.reason ?? e?.message ?? "").trim();
  return PAYMENT_ERROR_TEXT[reason] ?? coachingMessage(e);
}
