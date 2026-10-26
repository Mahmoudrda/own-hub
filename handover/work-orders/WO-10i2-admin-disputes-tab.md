# WO-10i2: staff dashboard, the Disputes tab
Depends on: WO-10i1; server list and evidence callables (INDEX Q3)
Size: L
Reads first: `admin-web/coaching.js` lines 1-30, 56-100, 130-165 and 780-870 (the Reports tab is the closest pattern); `admin-web/app.js` lines 44-60 (`h`), 125-141 (`TAB_NAMES`, `setBadge`), 2113-2125, 2150-2175, 2182-2210; `admin-web/index.html` lines 24-36 and 225-232; `admin-web/headers.test.mjs`

## Why
Staff need one place to decide payment disputes with the evidence side by side, the timers, a recommended decision, a typed reason, and a visible "waiting for a second reviewer" for suspensions. Strikes, address-change alerts and fee statements are read-only lists. Nothing on this tab can edit an amount.

## Final result
A new tab "Disputes" (shown to `womanReviewer` and `admin`, whatever the payments switch says). Inside it a row of four chips: Disputes, Strikes and flags, Address changes, Fee statements.
- Disputes: a list sorted by decision target. Each row: reference, amount, status, "target 29 Oct 14:30" (red text when overdue). Opening a row shows the case:
  1. the seven evidence items (label, coloured badge ok/warn/bad/missing, text) in the spec order;
  2. the screenshots of both sides (client's and coach's) in place, with "Try again" on a failed load;
  3. the three timers;
  4. "Recommended: {decision}. {why}";
  5. a decision group (radio buttons: the three decisions), a textarea "Reason (required)", and the button "Send decision";
  6. a box for the coach: "Suspend this coach's payments" with its own reason; if a suspension is pending: "Waiting for a second reviewer." or, for the second person, "A colleague asked to suspend this coach. Approve or decline." with "Approve" and "Decline".
- Strikes and flags: coaches and clients with strikes in 90 days, the dispute rate (flag when over 10 percent across 10 or more payments), suspended status.
- Address changes: coach, old and new address, time, "takes effect at"; a reviewer can open the coach.
- Fee statements: month, coach, total fee, status (open, marked paid, paid, late). Read only here. Confirming that a coach's fee arrived is the owner's step in the money tabs and needs a callable that is not in spec section 6 (INDEX Q3); a later order adds the button.
The audit log is the case timeline in the case view (events with who and when); there is no delete button anywhere.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| admin-web/disputes.js | create | `mountDisputes(ctx)` |
| admin-web/index.html | edit | tab button and panel |
| admin-web/app.js | edit | tab list, names, claims, loading |
| admin-web/disputes-logic.test.mjs | edit | one test for the wiring constants |
| admin-web/headers.test.mjs | no change | confirm it still passes (the page policy allows `data:` images) |

## Steps
1. File `admin-web/index.html`. Anchor: the line `<button role="tab" id="tab-reports" ...` (line 34). Add after it:
```html
    <button role="tab" id="tab-disputes" aria-controls="panel-disputes" aria-selected="false" tabindex="-1" type="button" hidden><span>Disputes</span><span class="tab-badge" id="badge-disputes" hidden></span></button>
```
Anchor: the closing `</section>` of `panel-reports` (line 229). Add after it:
```html

    <section id="panel-disputes" role="tabpanel" aria-labelledby="tab-disputes" hidden>
      <div id="disputes-root"></div>
    </section>
```
2. File `admin-web/app.js`.
   a. Line 8 area, add `import { mountDisputes } from "./disputes.js";` and below it `import * as D from "./disputes-logic.js";`. Next to `let coaching = null;` (line 40) add `let disputes = null;`.
   b. `TAB_NAMES` (line 131): add `disputes: "Disputes",`.
   c. `TABS` (line 2117): insert `"disputes"` after `"reports"`.
   d. Replace `allowedTabs` (line 2120) by:
```js
const allowedTabs = () => TABS.filter((t) =>
  (!L.COACHING_TABS.includes(t) || L.coachingTabsFor(claims).includes(t)) &&
  (!D.DISPUTE_TABS.includes(t) || D.disputeTabsFor(claims).includes(t)));
```
   e. `applyClaims` (line 2122): after the `for (const t of L.COACHING_TABS)` line add `for (const t of D.DISPUTE_TABS) $(`tab-${t}`).hidden = !allowed.has(t);`.
   f. After `ensureCoaching` (line 2161) add:
```js
function ensureDisputes() {
  disputes ??= mountDisputes({
    h, $, call, notice, askDialog, setEmpty, skeletons, setBadge,
    getState: () => ({ tab: state.tab, claims, personalStorage }),
  });
  return disputes;
}
```
   g. `primeBadges` (line 2170): add `if (D.disputeTabsFor(claims).length && state.tab !== "disputes") ensureDisputes().load({ quiet: true });`
   h. `showTab` (line 2205): after the `if (L.COACHING_TABS.includes(name))` pair add `if (name === "disputes") ensureDisputes().load(); else disputes?.release();`.
   (UNVERIFIED: the `state.tab` guard in `showTab` is `else coaching?.release();` on its own line; keep both lines as written so coaching still releases.)
3. File `admin-web/disputes.js` (create). Full content:
```js
import { ref as storageRef, getBytes } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-storage.js";
import * as D from "./disputes-logic.js";

const FILE_MAX_BYTES = 8 * 1024 * 1024;

// The Disputes tab. `ctx` carries the dashboard's helpers, as for the coaching tabs.
export function mountDisputes(ctx) {
  const { h, $, call, notice, askDialog, setEmpty, skeletons, setBadge, getState } = ctx;
  const fail = (e) => notice(D.paymentMessage(e));
  const st = { section: "queue", items: [], loaded: false, failed: false, openId: null, detail: null, reason: "", pick: "", suspendReason: "", other: [], otherLoaded: false };
  const urls = new Map();

  async function busy(btn, fn) {
    if (btn) btn.disabled = true;
    try { return await fn(); } catch (e) { fail(e); return undefined; } finally { if (btn?.isConnected) btn.disabled = false; }
  }

  const readAsDataUrl = (blob) => new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result);
    r.onerror = () => reject(r.error);
    r.readAsDataURL(blob);
  });

  async function imageUrl(path) {
    if (urls.has(path)) return urls.get(path);
    const bytes = await getBytes(storageRef(getState().personalStorage, path), FILE_MAX_BYTES);
    const url = await readAsDataUrl(new Blob([bytes], { type: path.endsWith(".png") ? "image/png" : "image/jpeg" }));
    urls.set(path, url);
    return url;
  }

  function picture(img) {
    const box = h("figure", { class: "proof-fig" }, h("p", { class: "muted", text: "Loading picture..." }));
    const load = async () => {
      try { box.replaceChildren(h("img", { src: await imageUrl(img.path), alt: `${img.side} screenshot`, class: "proof-img" })); }
      catch { box.replaceChildren(h("p", { class: "field-error", text: "The picture could not be loaded." }), h("button", { class: "btn ctl", type: "button", onclick: load }, "Try again")); }
    };
    load();
    return h("div", {}, h("span", { class: "flabel", text: img.side === "coach" ? "Coach's picture" : "Client's picture" }), box);
  }

  function root() { return $("disputes-root"); }

  async function load({ quiet = false } = {}) {
    if (!st.loaded && !quiet) root().replaceChildren(h("ul", { class: "list", "aria-busy": "true" }, skeletons(3)));
    try {
      const data = await call("list_payment_disputes", { state: "open" });
      st.items = D.sortDisputes(data.items ?? []);
      st.loaded = true;
      st.failed = false;
    } catch (e) {
      if (!quiet) fail(e);
      if (!st.loaded) st.failed = true;
    }
    setBadge("disputes", st.items.length, "open");
    if (!quiet || getState().tab === "disputes") render();
  }

  function render() {
    const r = root();
    if (st.failed && !st.loaded) {
      const box = h("div", { class: "empty-state" });
      r.replaceChildren(box);
      setEmpty(box, { title: "The disputes could not be loaded.", hint: "Check your internet connection and try again.", art: "plug", action: { label: "Try again", onclick: () => load() } });
      return;
    }
    const chips = h("div", { class: "chips", role: "group", "aria-label": "Section" },
      D.DISPUTE_SECTIONS.map((s) => h("button", { class: "chip", type: "button", "aria-pressed": String(st.section === s), onclick: () => switchSection(s) }, D.DISPUTE_SECTION_LABELS[s])));
    r.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Payment disputes" }),
        h("p", { class: "about", text: "Decide from the evidence. Nothing here can change an amount." })),
      chips,
      st.section === "queue" ? (st.openId ? caseView() : queueList()) : otherList());
  }

  async function switchSection(s) {
    st.section = s; st.openId = null; st.other = []; st.otherLoaded = false;
    render();
    if (s === "queue") return;
    const name = { strikes: "list_coach_payment_flags", addresses: "list_address_change_alerts", fees: "list_fee_statements" }[s];
    try { st.other = (await call(name, {})).items ?? []; } catch (e) { fail(e); }
    st.otherLoaded = true;
    render();
  }

  function queueList() {
    if (!st.items.length) {
      const box = h("div", { class: "empty-state" });
      setEmpty(box, { title: "No open disputes.", hint: "A payment a coach says did not arrive, or a service problem, appears here.", art: "settle" });
      return box;
    }
    return h("ul", { class: "list" }, st.items.map((p, i) => {
      const due = p.timers?.reviewDue;
      const late = due && Date.parse(due) < Date.now();
      return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
        h("div", { class: "item-head" }, h("div", { class: "who" },
          h("div", { class: "name", text: `${p.reference}  ${D.pounds(p.amountPiasters)}` }),
          h("div", { class: "meta" }, h("span", { class: "badge known", text: p.status }),
            due ? h("span", { class: late ? "field-error" : "", text: `Target ${D.cairoStamp(due)}` }) : null))),
        h("div", { class: "actions" }, h("button", { class: "btn primary", type: "button", onclick: (ev) => openCase(ev.currentTarget, p.paymentId) }, "Open")));
    }));
  }

  async function openCase(btn, id) {
    await busy(btn, async () => {
      st.detail = await call("get_payment_evidence", { paymentId: id });
      st.openId = id; st.reason = ""; st.pick = ""; st.suspendReason = "";
      render();
    });
  }

  function caseView() {
    const d = st.detail ?? {};
    const rec = D.recommend(d);
    const me = getState().claims?.uid ?? "";
    const approval = D.approvalState(d.pendingApproval, me);
    const reason = h("textarea", { id: "dp-reason", rows: 3, maxlength: "500", oninput: (ev) => { st.reason = ev.target.value; } });
    reason.value = st.reason;
    const suspend = h("textarea", { id: "dp-suspend", rows: 2, maxlength: "500", oninput: (ev) => { st.suspendReason = ev.target.value; } });
    suspend.value = st.suspendReason;
    return h("div", { class: "card" },
      h("button", { class: "btn ctl", type: "button", onclick: () => { st.openId = null; render(); } }, "Back to the list"),
      h("h3", { text: `${d.reference}  ${D.pounds(d.amountPiasters)}` }),
      h("ul", { class: "list" }, D.evidenceSummary(d).map((it) => h("li", { class: "item" },
        h("span", { class: `badge ${it.level === "ok" ? "known" : it.level === "bad" ? "bad" : ""}`, text: it.level }),
        h("strong", { text: ` ${it.label}: ` }), h("span", { text: it.text })))),
      h("div", { class: "snapshot" }, (d.images ?? []).map(picture)),
      h("div", { class: "snapshot" }, h("span", { class: "flabel", text: "Timers" }),
        D.timers(d.timers).map((t) => h("div", { class: "kv" }, h("span", { class: "k", text: t.label }), h("span", { class: `v${t.overdue ? " field-error" : ""}`, text: D.cairoStamp(t.due) })))),
      h("p", { class: "about", text: `Recommended: ${D.DECISION_LABELS[rec.decision]}. ${rec.why}` }),
      h("fieldset", {}, h("legend", { text: "Decision" }), D.DECISIONS.map((x) => h("label", { class: "radio" },
        h("input", { type: "radio", name: "dp-pick", value: x, checked: st.pick === x, onchange: () => { st.pick = x; } }), ` ${D.DECISION_LABELS[x]}`))),
      h("label", { for: "dp-reason", text: "Reason (required)" }), reason,
      h("div", { class: "actions" }, h("button", { class: "btn primary", type: "button", onclick: (ev) => decide(ev.currentTarget) }, "Send decision")),
      h("div", { class: "snapshot" }, h("span", { class: "flabel", text: "Coach payments" }),
        approval.kind === "none"
          ? [h("label", { for: "dp-suspend", text: "Reason to suspend (required)" }), suspend,
             h("div", { class: "actions" }, h("button", { class: "btn quiet-danger", type: "button", onclick: (ev) => suspendCoach(ev.currentTarget, d.coach?.uid) }, "Suspend this coach's payments"))]
          : approval.kind === "waiting"
            ? h("p", { class: "muted", text: approval.text })
            : [h("p", { class: "muted", text: approval.text }),
               h("div", { class: "actions" },
                 h("button", { class: "btn primary", type: "button", onclick: (ev) => approve(ev.currentTarget, d, true) }, "Approve"),
                 h("button", { class: "btn", type: "button", onclick: (ev) => approve(ev.currentTarget, d, false) }, "Decline"))]));
  }

  async function decide(btn) {
    let body;
    try { body = D.decisionPayload(st.openId, st.pick, st.reason); } catch (e) { notice(e.message); return; }
    await busy(btn, async () => {
      await call("staff_resolve_payment", body);
      notice("Decision sent.", true);
      st.items = st.items.filter((x) => x.paymentId !== st.openId);
      st.openId = null;
      render();
      load({ quiet: true });
    });
  }

  async function suspendCoach(btn, uid) {
    let body;
    try { body = D.suspendPayload(uid, st.suspendReason); } catch (e) { notice(e.message); return; }
    const pick = await askDialog({ title: "Suspend this coach's payments?", body: "A second reviewer must approve before it takes effect. Her current clients are not cut off.",
      actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: "Ask for approval", kind: "danger" }] });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      const res = await call("staff_set_coach_payment_status", body);
      notice(res?.status === "waiting_second_reviewer" ? "Waiting for a second reviewer." : "Done.", true);
      st.detail = await call("get_payment_evidence", { paymentId: st.openId });
      render();
    });
  }

  async function approve(btn, d, yes) {
    await busy(btn, async () => {
      await call("staff_set_coach_payment_status", { coachUid: d.coach?.uid, status: yes ? "approve" : "decline", approvalId: d.pendingApproval?.id, reason: st.suspendReason || "second reviewer" });
      notice(yes ? "Approved." : "Declined.", true);
      st.detail = await call("get_payment_evidence", { paymentId: st.openId });
      render();
    });
  }

  function otherList() {
    if (!st.otherLoaded) return h("ul", { class: "list", "aria-busy": "true" }, skeletons(3));
    if (!st.other.length) {
      const box = h("div", { class: "empty-state" });
      setEmpty(box, { title: "Nothing to show.", hint: "", art: "settle" });
      return box;
    }
    return h("ul", { class: "list" }, st.other.map((x) => h("li", { class: "item" }, h("div", { class: "who" },
      h("div", { class: "name", text: x.title ?? x.coachName ?? x.month ?? "" }),
      h("div", { class: "meta", text: x.text ?? "" })))));
  }

  return { load, release: () => urls.clear() };
}
```
4. File `admin-web/disputes-logic.test.mjs`: add one test `the wiring list is just disputes` asserting `D.DISPUTE_TABS` equals `["disputes"]` and `D.DISPUTE_SECTIONS` has 4 entries.
5. Run `cd admin-web && node --test` and open the dashboard locally with `cd admin-web && python3 -m http.server 8099` and the emulator config: UNVERIFIED how the dashboard is run locally (`grep -n "http.server\|emulator" docs/owner/LAUNCH-GUIDE.md admin-web/config.example.js`). Use the chrome-devtools MCP: open the page, take a snapshot, check console and network errors.

## Strings to add
None (English dashboard).

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| disputes-logic.test.mjs | `the wiring list is just disputes` | as in step 4 |
| (manual) | `Disputes tab shows for a reviewer and hides for finance only` | with the Auth emulator, claims `{womanReviewer:true}` shows the tab, `{finance:true}` hides it; with the payments switch off the tab still shows |
| (manual) | `a decision cannot be sent without a reason` | click Send with empty reason: the notice "Write the reason..." and no request in the network panel |
| (manual) | `suspension shows Waiting for a second reviewer` | against the emulator functions |
Run: `cd admin-web && node --test`

## Verify
- `cd admin-web && node --test` ends `# fail 0`.
- Browser check with the devtools MCP: no console errors on loading the tab; the panel renders with the emulator.

## Do not
- Do not put an amount input anywhere. Do not add a delete button. Do not gate this tab with `PAYMENTS_LIVE`.
- Do not show a client's phone number (the server does not send it; do not add it).
- Do not change the coaching tabs' behaviour.

## Done checklist
- [ ] tab button, panel, app.js wiring, disputes.js
- [ ] node tests green; browser check done

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-10j2).

UNVERIFIED in this order: 3 (`showTab` exact lines, how the dashboard runs locally, `staff_confirm_fee` and the list callables from INDEX Q3).
