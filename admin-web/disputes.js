import * as D from "./disputes-logic.js";
import { appendPage } from "./logic.js";

// The payment tabs: Disputes (queue, coach flags, address changes, payments switch) and Fee statements.
// `ctx` carries the dashboard's own helpers. Every word from the server goes in through `text`, never as markup.
export function mountPaymentsDesk(ctx) {
  const { h, $, call, notice, askDialog, setEmpty, skeletons, setBadge, getState, readSwitch } = ctx;
  const claims = () => getState().claims ?? {};
  const fail = (e) => notice(D.paymentMessage(e));

  const freshQueue = () => ({ items: [], next: null, loaded: false, failed: false, paging: false, openId: null, row: null, detail: null, images: null, pick: "", reason: "", proofFalse: false });
  const freshFlags = () => ({ data: null, loaded: false, failed: false, reasons: {} });
  const desk = { section: "", q: freshQueue(), fl: freshFlags(), sw: { enabled: undefined, loaded: false, reason: "" } };
  const fees = { items: [], next: null, status: "attention", loaded: false, failed: false, paging: false, seq: 0, reasons: {} };
  let picsBox = null;
  // Suspension requests this person made, by her account and then by coach: { [account]: { [coachUid]: proposal.at } }.
  // It outlives release(): leaving the tab must not turn her own request into one she may approve.
  const mine = {};
  const mineFor = () => (mine[claims().user_id ?? claims().sub ?? ""] ??= {});

  async function busy(btn, fn) {
    if (btn) btn.disabled = true;
    try { return await fn(); } catch (e) { fail(e); return undefined; } finally { if (btn?.isConnected) btn.disabled = false; }
  }

  const loading = (root) => root.replaceChildren(h("ul", { class: "list", "aria-busy": "true" }, skeletons(3)));

  function emptyBox(opts) {
    const box = h("div", { class: "empty-state" });
    setEmpty(box, opts);
    return box;
  }

  function failedBox(what, retry) {
    return emptyBox({ title: `${what} could not be loaded.`, hint: "Check your internet connection and try again.", art: "plug", action: { label: "Try again", onclick: retry } });
  }

  const kv = (label, value) => (value ? h("div", { class: "kv" }, h("span", { class: "k", text: label }), h("span", { class: "v", text: value })) : null);

  function reasonBox({ id, label, value, onInput }) {
    const box = h("textarea", { id, rows: 3, maxlength: "500", oninput: (ev) => onInput(ev.target.value) });
    box.value = value ?? "";
    return [h("label", { for: id, text: label }), box];
  }

  /* Disputes tab */

  async function loadDisputes({ quiet = false } = {}) {
    const secs = D.sectionsFor(claims());
    if (!secs.length) return;
    if (!secs.includes(desk.section)) desk.section = secs[0];
    if (quiet) {
      if (secs.includes("queue")) await loadQueue({ quiet: true });
      return;
    }
    await loadSection(desk.section);
  }

  function loadSection(section) {
    if (section === "queue") return loadQueue();
    if (section === "switch") return loadSwitch();
    return loadFlags();
  }

  function renderDisputes() {
    const root = $("disputes-root");
    const secs = D.sectionsFor(claims());
    if (!secs.length) { root.replaceChildren(); return; }
    const body = { queue: queueBody, flags: flagsBody, address: addressBody, switch: switchBody }[desk.section]();
    root.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Payment disputes" }),
        h("p", { class: "about", text: "Decide from the evidence. Nothing here can change what a client paid." })),
      h("div", { class: "chips", role: "group", "aria-label": "Section" },
        secs.map((s) => h("button", { class: "chip", type: "button", "aria-pressed": String(desk.section === s), onclick: () => switchSection(s) }, D.SECTION_LABELS[s]))),
      body);
  }

  function switchSection(s) {
    desk.section = s;
    desk.q.openId = null;
    if ((s === "flags" || s === "address") && desk.fl.loaded) { renderDisputes(); return undefined; }
    loading($("disputes-root"));
    return loadSection(s);
  }

  /* the queue and the case */

  async function loadQueue({ quiet = false, more = false } = {}) {
    const q = desk.q;
    if (more && q.paging) return;
    if (!q.loaded && !quiet) loading($("disputes-root"));
    q.paging = more;
    if (more) renderDisputes();
    try {
      const data = await call("staff_list_payment_queue", more && q.next ? { after: q.next } : {});
      if (q !== desk.q) return;
      q.items = more ? appendPage(q.items, data.items ?? [], (x) => x.paymentId) : (data.items ?? []);
      q.next = data.next ?? null;
      q.loaded = true;
      q.failed = false;
    } catch (e) {
      if (q !== desk.q) return;
      if (!quiet) fail(e);
      if (!q.loaded) q.failed = true;
    } finally { q.paging = false; }
    setBadge("disputes", q.items.length, "waiting");
    if (quiet && (q.openId || getState().tab !== "disputes")) return;
    renderDisputes();
  }

  function queueBody() {
    const q = desk.q;
    if (q.openId) return caseView();
    if (q.failed && !q.loaded) return failedBox("The disputes", () => loadQueue());
    if (!q.items.length) return emptyBox({ title: "No payments are waiting for you.", hint: "A payment the coach says did not arrive, or a service problem, appears here.", art: "settle" });
    return h("div", {},
      h("ul", { class: "list" }, D.sortQueue(q.items).map((p, i) => {
        const s = D.queueSummary(p);
        return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
          h("div", { class: "item-head" }, h("div", { class: "who" },
            h("div", { class: "name", text: s.title }),
            h("div", { class: "meta" },
              h("span", { class: "badge", text: s.status }),
              s.kind ? h("span", { class: "badge", text: s.kind }) : null,
              s.firstPayments ? h("span", { class: "badge known", text: "One of her first payments" }) : null),
            h("div", { class: s.overdue ? "field-error" : "meta", text: s.waiting }))),
          h("div", { class: "actions" }, h("button", { class: "btn primary", type: "button", onclick: (ev) => openCase(ev.currentTarget, p) }, "Open")));
      })),
      q.next ? h("div", { class: "actions" }, h("button", { class: "btn", type: "button", "aria-busy": String(q.paging), disabled: q.paging, onclick: () => loadQueue({ more: true }) }, q.paging ? "Loading..." : "Load more")) : null);
  }

  async function openCase(btn, row) {
    await busy(btn, async () => {
      const detail = await call("staff_get_payment_evidence", { paymentId: row.paymentId });
      Object.assign(desk.q, { openId: row.paymentId, row, detail, images: null, pick: "", reason: "", proofFalse: false });
      renderDisputes();
      loadPictures(row.paymentId);
    });
  }

  async function loadPictures(id) {
    const q = desk.q;
    q.images = "loading";
    drawPictures();
    try {
      const res = await call("staff_get_payment_evidence", { paymentId: id, withImages: true });
      if (q !== desk.q || q.openId !== id) return;
      q.images = D.evidenceImages(res);
    } catch {
      if (q !== desk.q || q.openId !== id) return;
      q.images = "failed";
    }
    drawPictures();
  }

  function drawPictures() {
    if (!picsBox?.isConnected) return;
    const imgs = desk.q.images;
    if (imgs === "loading" || imgs === null) { picsBox.replaceChildren(h("p", { class: "muted", text: "Loading pictures..." })); return; }
    if (imgs === "failed") {
      picsBox.replaceChildren(h("p", { class: "field-error", text: "The pictures could not be loaded." }),
        h("button", { class: "btn ctl", type: "button", onclick: () => loadPictures(desk.q.openId) }, "Try again"));
      return;
    }
    if (!imgs.length) { picsBox.replaceChildren(h("p", { class: "muted", text: "No pictures were sent." })); return; }
    picsBox.replaceChildren(...imgs.map((img) => h("div", {},
      h("span", { class: "flabel", text: img.side === "coach" ? "Coach's picture" : "Client's picture" }),
      h("figure", { class: "proof-fig" }, h("img", { class: "proof-img", src: img.src, alt: img.side === "coach" ? "Coach's bank list" : "Client's receipt" })))));
  }

  const LEVEL_CLASS = { ok: "badge sage", warn: "badge known", bad: "badge flag", missing: "badge" };

  function caseView() {
    const q = desk.q;
    const d = q.detail ?? {};
    const kind = D.effectiveKind(d, q.row);
    const status = d.status ?? q.row?.status;
    const outcomes = D.outcomesFor(kind, status);
    const rec = D.recommendation(d, kind);
    const amount = d["1_amountAndReference"]?.amountPiasters;
    const sum = D.queueSummary(q.row);
    const note = d.dispute?.clientNote;
    const decided = D.decidedNote(d, kind);
    const takeover = D.takeoverNote(status, q.row);

    const extras = h("div", {});
    const drawExtras = () => {
      extras.replaceChildren(...[
        D.canMarkProofFalse(q.pick, kind)
          ? h("label", { class: "radio" }, h("input", { type: "checkbox", checked: q.proofFalse, onchange: (ev) => { q.proofFalse = ev.target.checked; } }), " Her proof was false. Record a strike for her.")
          : null,
        q.pick === "refund_owed"
          ? h("p", { class: "muted", text: `Refund owed: ${D.pounds(amount)}, the full payment. Part refunds are not decided here.` })
          : null].filter(Boolean));
    };
    drawExtras();

    picsBox = h("div", { class: "snapshot" });
    queueMicrotask(drawPictures);

    return h("div", { class: "card" },
      h("button", { class: "btn ctl", type: "button", onclick: () => { q.openId = null; picsBox = null; renderDisputes(); } }, "Back to the list"),
      h("h3", { text: sum.title }),
      h("p", { class: "about", text: [sum.kind, sum.status].filter(Boolean).join(". ") }),
      h("p", { class: sum.overdue ? "field-error" : "muted", text: sum.waiting }),
      note ? h("p", { class: "about" }, h("strong", { text: "Client's note: " }), h("span", { text: D.clip(note, 500) })) : null,
      decided ? h("p", { class: "field-error", text: decided }) : null,
      h("ul", { class: "list" }, D.evidenceSummary(d).map((it) => h("li", { class: "item" },
        h("span", { class: LEVEL_CLASS[it.level] ?? "badge", text: it.level }),
        h("strong", { text: ` ${it.label}: ` }), h("span", { text: it.text })))),
      h("span", { class: "flabel", text: "Pictures" }),
      picsBox,
      h("span", { class: "flabel", text: "Timeline" }),
      h("div", {}, D.timelineRows(d).map((r) => h("div", { class: "kv" }, h("span", { class: "k", text: r.when }), h("span", { class: "v", text: r.text })))),
      rec.text ? h("p", { class: "about", text: rec.text }) : null,
      h("fieldset", { class: "group" }, h("legend", { text: "Decision" }), outcomes.map((o) => h("label", { class: "radio" },
        h("input", { type: "radio", name: "dp-pick", value: o, checked: q.pick === o, onchange: () => { q.pick = o; drawExtras(); } }),
        ` ${D.outcomeLabel(o, kind)}${rec.outcome === o ? " (suggested)" : ""}`))),
      extras,
      reasonBox({ id: "dp-reason", label: "Reason (required, at least 10 characters)", value: q.reason, onInput: (v) => { q.reason = v; } }),
      takeover ? h("p", { class: "muted", text: takeover }) : null,
      h("div", { class: "actions" }, h("button", { class: "btn primary", type: "button", onclick: (ev) => decide(ev.currentTarget, { kind, status, amount, decided }) }, "Send decision")));
  }

  async function decide(btn, { kind, status, amount, decided }) {
    const q = desk.q;
    let body;
    try { body = D.decisionPayload({ paymentId: q.openId, outcome: q.pick, reason: q.reason, kind, status, amountPiasters: amount, proofFalse: q.proofFalse }); } catch (e) { notice(e.message); return; }
    const pick = await askDialog({
      title: "Send this decision?",
      body: `${D.outcomeLabel(body.outcome, kind)}. Only a different staff member can reopen it afterwards.${decided ? ` ${decided}` : ""}`,
      actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: "Send decision", kind: "primary" }],
    });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      const res = await call("staff_resolve_payment", body);
      notice(D.decisionNotice(res, body.outcome), true);
      q.items = q.items.filter((x) => x.paymentId !== q.openId);
      q.openId = null;
      picsBox = null;
      renderDisputes();
      loadQueue({ quiet: true });
    });
  }

  /* coach flags, suspensions, address changes */

  async function loadFlags() {
    const fl = desk.fl;
    if (!fl.loaded) loading($("disputes-root"));
    try {
      const data = await call("staff_list_payment_flags", {});
      if (fl !== desk.fl) return;
      fl.data = data;
      fl.loaded = true;
      fl.failed = false;
    } catch (e) {
      if (fl !== desk.fl) return;
      fail(e);
      if (!fl.loaded) fl.failed = true;
    }
    renderDisputes();
  }

  function flagsBody() {
    const fl = desk.fl;
    if (fl.failed && !fl.loaded) return failedBox("The coach flags", loadFlags);
    if (!fl.loaded) return h("ul", { class: "list", "aria-busy": "true" }, skeletons(3));
    const rows = D.flagRows(fl.data, mineFor());
    if (!rows.length) return emptyBox({ title: "No coach is flagged.", hint: "A coach with two strikes in 90 days, or too many lost disputes, appears here.", art: "settle" });
    return h("ul", { class: "list" }, rows.map((r, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
      h("div", { class: "item-head" }, h("div", { class: "who" },
        h("div", { class: "name", text: "Account" }),
        h("div", { class: "meta", text: r.uid }),
        h("div", { class: "meta" }, r.reasons.map((t) => h("span", { class: "badge", text: t })),
          r.proposal ? h("span", { class: "badge known", text: "Awaiting second approval" }) : null))),
      kv("Strikes in 90 days", r.strikes),
      kv("Flagged", r.flaggedAt),
      r.state.text ? h("p", { class: "muted", text: r.state.text }) : null,
      r.state.action
        ? [reasonBox({ id: `fl-${i}`, label: "Reason (required, at least 10 characters)", value: fl.reasons[r.uid], onInput: (v) => { fl.reasons[r.uid] = v; } }),
           h("div", { class: "actions" }, h("button", { class: r.state.action === "lift" ? "btn" : "btn quiet-danger", type: "button", onclick: (ev) => setStatus(ev.currentTarget, r) }, r.state.button))]
        : null)));
  }

  const STATUS_DONE = {
    awaiting_second_approval: "Waiting for a second reviewer.",
    suspended: "Her payments are suspended.",
    active: "Her payments are open again.",
  };

  async function setStatus(btn, row) {
    const fl = desk.fl;
    let body;
    try { body = D.suspendPayload(row.uid, row.state.action, fl.reasons[row.uid]); } catch (e) { notice(e.message); return; }
    const lift = body.action === "lift";
    const pick = await askDialog({
      title: lift ? "Lift this suspension?" : row.state.kind === "approve" ? "Approve this suspension?" : "Ask to suspend this coach's payments?",
      body: lift ? "She can take new payments again." : "It stops new payments only. Her current clients are not cut off. It takes two different staff members.",
      actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: row.state.button, kind: lift ? "" : "danger" }],
    });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      try {
        const res = await call("staff_set_coach_payment_status", body);
        notice(STATUS_DONE[res?.status] ?? "Done.", true);
        delete fl.reasons[row.uid];
        const data = await call("staff_list_payment_flags", {});
        if (fl !== desk.fl) return;
        fl.data = data;
        if (res?.status === "awaiting_second_approval") mineFor()[row.uid] = D.flagRows(data).find((x) => x.uid === row.uid)?.proposal?.at;
        renderDisputes();
      } catch (e) {
        if (e?.message === "same_staff" && row.proposal) { mineFor()[row.uid] = row.proposal.at; renderDisputes(); }
        throw e;
      }
    });
  }

  function addressBody() {
    const fl = desk.fl;
    if (fl.failed && !fl.loaded) return failedBox("The address changes", loadFlags);
    if (!fl.loaded) return h("ul", { class: "list", "aria-busy": "true" }, skeletons(3));
    const rows = D.addressRows(fl.data);
    if (!rows.length) return emptyBox({ title: "No address changes.", hint: "A coach who changes her InstaPay address appears here.", art: "settle" });
    return h("ul", { class: "list" }, rows.map((r) => h("li", { class: "item" }, h("div", { class: "who" },
      h("div", { class: "name", text: "Coach account" }),
      h("div", { class: "meta", text: r.uid ?? "" }),
      h("div", { class: "meta" }, r.first ? h("span", { class: "badge", text: "First address" }) : h("span", { class: "badge known", text: "Changed" })),
      kv("Changed", r.changed),
      kv("Takes effect", r.effective)))));
  }

  /* the payments switch (admin) */

  async function loadSwitch() {
    const sw = desk.sw;
    try { sw.enabled = await readSwitch(); } catch { sw.enabled = undefined; }
    sw.loaded = true;
    renderDisputes();
  }

  function switchBody() {
    const sw = desk.sw;
    const targets = sw.enabled === true ? [false] : sw.enabled === false ? [true] : [false, true];
    return h("div", { class: "card" },
      h("h3", { text: "New InstaPay payments" }),
      h("p", { role: "status", "aria-live": "polite", text: D.switchText(sw.enabled) }),
      reasonBox({ id: "sw-reason", label: "Reason (required, at least 5 characters)", value: sw.reason, onInput: (v) => { sw.reason = v; } }),
      h("div", { class: "actions" }, targets.map((on) => h("button", { class: on ? "btn primary" : "btn quiet-danger", type: "button", onclick: (ev) => flipSwitch(ev.currentTarget, on) }, on ? "Turn payments on" : "Turn payments off"))));
  }

  async function flipSwitch(btn, on) {
    const sw = desk.sw;
    let body;
    try { body = D.switchPayload(on, sw.reason); } catch (e) { notice(e.message); return; }
    const pick = await askDialog({
      title: on ? "Turn payments on?" : "Turn payments off?",
      body: on ? "Clients can start new InstaPay payments again."
        : "No client can start a new payment. Payments already made can still be confirmed, refunded and decided.",
      actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: on ? "Turn on" : "Turn off", kind: on ? "primary" : "danger" }],
    });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      const res = await call("set_payments_enabled", body);
      sw.enabled = res?.enabled === true;
      sw.reason = "";
      notice(sw.enabled ? "Payments are on." : "Payments are off.", true);
      renderDisputes();
    });
  }

  /* Fee statements tab */

  async function loadFees({ quiet = false, more = false } = {}) {
    if (!D.canSeeFees(claims()) || (more && fees.paging)) return;
    const status = fees.status;
    const seq = ++fees.seq;
    if (!fees.loaded && !quiet) loading($("fees-root"));
    fees.paging = more;
    if (more) renderFees();
    try {
      const data = await call("list_fee_statements", { ...(status ? { status } : {}), ...(more && fees.next ? { after: fees.next } : {}) });
      if (seq !== fees.seq) return;
      fees.items = D.holdFirst(more ? appendPage(fees.items, data.items ?? [], (x) => x.statementId) : (data.items ?? []));
      fees.next = data.next ?? null;
      fees.loaded = true;
      fees.failed = false;
    } catch (e) {
      if (seq !== fees.seq) return;
      if (!quiet) fail(e);
      if (!fees.loaded) fees.failed = true;
    } finally { if (seq === fees.seq) fees.paging = false; }
    if (status === "attention") setBadge("fees", D.feeBadge(fees.items), "to confirm");
    if (quiet && getState().tab !== "fees") return;
    renderFees();
  }

  function renderFees() {
    const root = $("fees-root");
    if (!D.canSeeFees(claims())) { root.replaceChildren(); return; }
    root.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Coach fee statements" }),
        h("p", { class: "about", text: "A coach owes Own Hub a fee on each confirmed payment, due in 3 days. Not confirmed by you after 7 days, her account is put on hold (listed first). Confirm the fee once the money is in the Own Hub InstaPay account and the hold ends by itself. If her I-paid claim did not check out, reject it with a reason." })),
      h("div", { class: "chips", role: "group", "aria-label": "Status" },
        D.FEE_FILTERS.map((s) => h("button", { class: "chip", type: "button", "aria-pressed": String(fees.status === s), onclick: () => filterFees(s) }, D.FEE_FILTER_LABELS[s]))),
      feesBody());
  }

  function filterFees(s) {
    fees.status = s;
    fees.items = [];
    fees.next = null;
    fees.loaded = false;
    return loadFees();
  }

  function feesBody() {
    if (fees.failed && !fees.loaded) return failedBox("The fee statements", () => loadFees());
    if (!fees.loaded) return h("ul", { class: "list", "aria-busy": "true" }, skeletons(3));
    if (!fees.items.length) return emptyBox({ title: "No statements here.", hint: "A bill is made when a payment is confirmed.", art: "settle" });
    return h("div", {},
      h("ul", { class: "list" }, fees.items.map((s, i) => {
        const r = D.feeRow(s);
        return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
          h("div", { class: "item-head" }, h("div", { class: "who" },
            h("div", { class: "name", text: r.title }),
            h("div", { class: "meta" }, h("span", { class: r.late ? "badge flag" : r.claimed ? "badge known" : "badge", text: r.status })),
            kv("Coach account", r.coach),
            r.lines.map(([k, v]) => kv(k, v)))),
          r.canReject
            ? reasonBox({ id: `fee-reason-${i}`, label: "If it did not arrive: the reason (required, at least 10 characters)", value: fees.reasons[s.statementId], onInput: (v) => { fees.reasons[s.statementId] = v; } })
            : null,
          r.canConfirm
            ? h("div", { class: "actions" },
                h("button", { class: r.claimed ? "btn primary" : "btn", type: "button", onclick: (ev) => confirmFee(ev.currentTarget, s, r) }, "Confirm the fee arrived"),
                r.canReject ? h("button", { class: "btn quiet-danger", type: "button", onclick: (ev) => rejectFee(ev.currentTarget, s) }, "Reject the claim") : null)
            : null);
      })),
      fees.next ? h("div", { class: "actions" }, h("button", { class: "btn", type: "button", "aria-busy": String(fees.paging), disabled: fees.paging, onclick: () => loadFees({ more: true }) }, fees.paging ? "Loading..." : "Load more")) : null);
  }

  async function rejectFee(btn, s) {
    let body;
    try { body = D.rejectFeePayload(s.statementId, fees.reasons[s.statementId]); } catch (e) { notice(e.message); return; }
    await busy(btn, async () => {
      await call("reject_fee_claim", body);
      notice("Claim rejected. She has been asked to check her bill.", true);
      delete fees.reasons[s.statementId];
      fees.items = fees.items.filter((x) => x.statementId !== s.statementId);
      if (fees.status === "attention") setBadge("fees", D.feeBadge(fees.items), "to confirm");
      renderFees();
      loadFees({ quiet: true });
    });
  }

  async function confirmFee(btn, s, r) {
    let body;
    try { body = D.confirmFeePayload(s.statementId); } catch (e) { notice(e.message); return; }
    const pick = await askDialog({
      title: "Confirm this fee?",
      body: `${D.pounds(s.totalDuePiasters)} for ${r.title}. Only confirm once the money is in the Own Hub InstaPay account.${r.claimed ? "" : " She has not said she paid yet."}`,
      actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: "Confirm", kind: "primary" }],
    });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      await call("confirm_fee_payment", body);
      notice("Fee confirmed.", true);
      fees.items = fees.items.filter((x) => x.statementId !== s.statementId);
      if (fees.status === "attention") setBadge("fees", D.feeBadge(fees.items), "to confirm");
      renderFees();
      loadFees({ quiet: true });
    });
  }

  /* entry points for the dashboard */

  function load(tab, opts) {
    if (tab !== "fees") return loadDisputes(opts);
    if (!opts?.quiet) { desk.q = freshQueue(); picsBox = null; } // an open case and its pictures do not stay behind on the other tab
    return loadFees(opts);
  }

  // Leaving the tab or signing out drops the screenshots and everything read about the women.
  function release() {
    desk.q = freshQueue();
    desk.fl = freshFlags();
    desk.sw = { enabled: undefined, loaded: false, reason: "" };
    Object.assign(fees, { items: [], next: null, loaded: false, failed: false, paging: false, reasons: {}, seq: fees.seq + 1 });
    picsBox = null;
  }

  return { load, release };
}
