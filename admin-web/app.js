import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app-check.js";
import { getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";
import { getStorage, ref as storageRef, uploadBytesResumable, getBytes } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-storage.js";
import { getFunctions, httpsCallable } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-functions.js";
import { firebaseConfig, recaptchaSiteKey, functionsRegion } from "./config.js";
import * as L from "./logic.js";
import { mountCoaching } from "./coaching.js";
import { mountArt, unmountArt } from "./art.js";

const $ = (id) => document.getElementById(id);
const PLACEHOLDER = /REPLACE_WITH/;
const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
const STATUS_LABEL = { pending: "Pending", scheduled: "Call booked", approved: "Approved" };

const state = {
  rows: [],
  loaded: false,
  status: "pending",
  query: "",
  selected: new Set(),
  busy: new Set(),
  undo: null,
  undoAction: null,
  tab: "queue",
  calView: "week",
  calDay: L.cairoDayKey(new Date().toISOString()),
  settings: { firstName: "", listed: false, availability: [], slotMinutes: 15 },
  phones: [],
  phonesLoaded: false,
  reschedule: null,
  declineArmed: null,
};

let functions = null;
let storage = null;
let personalStorage = null;
let claims = {};
let coaching = null;
let undoTimer = null;
let noticeTimer = null;

function h(tag, props = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (v === false || v == null) continue;
    if (k === "class") el.className = v;
    else if (k === "text") el.textContent = v;
    else if (k === "vars") for (const [name, value] of Object.entries(v)) el.style.setProperty(name, String(value));
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat()) if (c != null) el.append(c);
  return el;
}

// The browser's own storage can be missing or blocked: every read and write is guarded.
const browserStore = {
  get(key) { try { return localStorage.getItem(key); } catch (e) { return null; } },
  set(key, value) { try { localStorage.setItem(key, value); return true; } catch (e) { return false; } },
};

const calmScroll = () => (matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth");

function notice(text, ok = false) {
  const el = $("notice");
  clearTimeout(noticeTimer);
  $("notice-text").textContent = text || "";
  el.hidden = !text;
  el.classList.toggle("ok", ok);
  if (text && ok) noticeTimer = setTimeout(() => { if ($("notice-text").textContent === text) notice(""); }, 7000);
}

function friendly(error) {
  return L.friendlyMessage(error?.code);
}

async function call(name, data = {}) {
  const result = await httpsCallable(functions, name)(data);
  return result.data;
}

function whenText(iso) {
  if (!iso) return "";
  return new Intl.DateTimeFormat([], { timeZone: L.TIMEZONE, weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(iso));
}

/* shared pieces: dialog, empty states, skeletons, tab badges */

// Resolves to the id of the button she pressed, or null when she closed the dialog.
function askDialog({ title, body, actions }) {
  const dlg = $("dialog");
  return new Promise((resolve) => {
    $("dialog-title").textContent = title;
    $("dialog-body").textContent = body;
    $("dialog-actions").replaceChildren(...actions.map((a) => h("button", {
      class: `btn ${a.kind ?? ""}`, type: "button", autofocus: a.safe === true, onclick: () => dlg.close(a.id),
    }, a.label)));
    dlg.returnValue = "";
    const done = () => { dlg.removeEventListener("close", done); resolve(dlg.returnValue || null); };
    dlg.addEventListener("close", done);
    dlg.showModal();
  });
}

// `art` names the line drawing above the title; the same one is kept across re-renders.
function setEmpty(el, { title, hint, action = null, art = null }) {
  let pic = el.querySelector(":scope > .art");
  if (pic && !art) { unmountArt(pic); pic = null; }
  if (art) pic ??= h("div", { class: "art" });
  el.replaceChildren(...[
    pic,
    h("strong", { text: title }),
    hint ? h("p", { class: "muted", text: hint }) : null,
    action ? h("button", { class: "btn", type: "button", onclick: action.onclick }, action.label) : null,
  ].filter(Boolean));
  el.hidden = false;
  if (art) mountArt(pic, art);
}

function skeletons(n = 4) {
  return Array.from({ length: n }, () => h("li", { class: "item skeleton", "aria-hidden": "true" },
    h("span", { class: "bone wide" }), h("span", { class: "bone" }), h("span", { class: "bone short" })));
}

function setBusy(list, on) {
  list.setAttribute("aria-busy", String(on));
}

const TAB_NAMES = { queue: "Verification", calendar: "Calendar", phones: "Pre-approved phones", exercises: "Exercises", events: "Events", foods: "Foods", coaches: "Coaches", payments: "Payments", refunds: "Refunds", payouts: "Payouts", reports: "Reports", settings: "Settings" };

function setBadge(tab, n, noun) {
  const el = $(`badge-${tab}`);
  const text = L.badgeText(n);
  el.textContent = text;
  el.hidden = !text;
  const btn = $(`tab-${tab}`);
  if (text) btn.setAttribute("aria-label", `${TAB_NAMES[tab]}, ${n} ${noun}`);
  else btn.removeAttribute("aria-label");
}

function problemList(box, problems) {
  box.replaceChildren(...(problems.length ? [
    h("strong", { text: problems.length === 1 ? "One thing to fix before saving:" : `${problems.length} things to fix before saving:` }),
    h("ul", {}, problems.map((p) => h("li", { text: p }))),
  ] : []));
  box.hidden = problems.length === 0;
}

/* queue */

async function loadQueue({ quiet = false } = {}) {
  if (!state.loaded && !quiet) renderQueue();
  try {
    const data = await call("list_review_queue", {});
    state.rows = L.normalizeRows(data);
    state.selected = L.pruneSelection(state.selected, state.rows);
    state.loaded = true;
    if (!quiet) notice("");
  } catch (e) {
    if (!quiet) notice(friendly(e));
    if (!state.loaded && !quiet) state.loaded = true;
  }
  if (!quiet || state.tab === "queue") renderQueue();
  setBadge("queue", L.statusCounts(state.rows).pending, "waiting");
}

function visibleRows() {
  return L.filterRows(state.rows, { status: state.status, query: state.query });
}

const QUEUE_EMPTY = {
  pending: ["No one is waiting for a decision.", "New requests show up here as soon as a woman asks to be verified."],
  scheduled: ["No calls are booked.", "When a woman books a call with you, she moves here until you approve her."],
  approved: ["No one has been approved yet.", "Women you approve appear here. You can revoke an approval from this list."],
};

function renderQueue() {
  const counts = L.statusCounts(state.rows);
  for (const chip of $("chips").querySelectorAll(".chip")) {
    const s = chip.dataset.status;
    chip.setAttribute("aria-pressed", String(s === state.status));
    chip.querySelector(".count").textContent = counts[s] ? String(counts[s]) : "";
  }
  $("queue-summary").textContent = !state.loaded ? "" : counts.pending
    ? `${counts.pending} ${counts.pending === 1 ? "woman is" : "women are"} waiting for a decision.`
    : "Everyone has been looked at.";
  const list = $("list");
  if (!state.loaded) {
    list.replaceChildren(...skeletons(3));
    setBusy(list, true);
    $("empty").hidden = true;
    $("bulk").hidden = true;
    return;
  }
  setBusy(list, false);
  const rows = visibleRows();
  list.replaceChildren(...rows.map((row, i) => card(row, i)));
  if (rows.length) {
    $("empty").hidden = true;
  } else if (state.query.trim()) {
    setEmpty($("empty"), { title: `No one matches "${state.query.trim()}" here.`, hint: "Check the spelling, or look under another heading.", art: "query", action: { label: "Clear search", onclick: () => { state.query = ""; $("search").value = ""; renderQueue(); $("search").focus(); } } });
  } else {
    setEmpty($("empty"), { title: QUEUE_EMPTY[state.status][0], hint: QUEUE_EMPTY[state.status][1], art: "loupe" });
  }
  const selectable = L.selectableUids(rows);
  $("bulk").hidden = selectable.length === 0;
  $("select-all").checked = selectable.length > 0 && selectable.every((id) => state.selected.has(id));
  const n = [...state.selected].filter((id) => selectable.includes(id)).length;
  $("approve-selected").textContent = n ? `Approve ${n} selected` : "Approve selected";
  $("approve-selected").disabled = n === 0;
}

function card(row, i) {
  const status = L.rowStatus(row);
  const approved = status === "approved";
  const busy = state.busy.has(row.uid);
  const title = row.displayName || row.phone || "Member";
  const meta = [];
  if (row.displayName && row.phone) meta.push(h("span", { class: "phone", text: row.phone }));
  if (row.scheduledFor) meta.push(`Call ${whenText(row.scheduledFor)}`);
  else if (row.requestedAt) meta.push(`Asked ${whenText(row.requestedAt)}`);

  const head = h("div", { class: "item-head" });
  if (!approved) {
    const box = h("input", {
      type: "checkbox", "aria-label": `Select ${title}`,
      onchange: () => { state.selected = L.toggleSelection(state.selected, row.uid); renderQueue(); },
    });
    box.checked = state.selected.has(row.uid);
    head.append(box);
  }
  head.append(h("div", { class: "who" },
    h("div", { class: "name", text: title }),
    h("div", { class: "meta" },
      h("span", { class: `badge ${approved ? "sage" : status === "scheduled" ? "known" : ""}`, text: STATUS_LABEL[status] }),
      row.knownReviewer ? h("span", { class: "badge known", text: "Knows you" }) : null,
      approved && L.approvedViaText(row) ? h("span", { class: "via", text: L.approvedViaText(row) }) : null),
    meta.length ? h("div", { class: "meta" }, meta.flatMap((m, k) => (k ? [" \u00b7 ", m] : [m]))) : null));
  if (approved) {
    const toggle = h("input", { type: "checkbox", role: "switch", disabled: busy, "aria-label": `Approved: ${title}. Turn off to revoke her approval.` });
    toggle.checked = true;
    toggle.addEventListener("change", () => { if (!toggle.checked) onRevoke(row.uid, title, toggle); });
    head.append(h("label", { class: "switch" }, toggle, h("span", { class: "track" }), h("span", { class: "sr", text: "Approved" })));
  }

  const el = h("li", { class: `item${state.selected.has(row.uid) ? " selected" : ""}`, vars: { "--i": Math.min(i, 8) }, "data-uid": row.uid }, head);

  if (approved) el.append(h("p", { class: "muted", text: "Turning the switch off puts her back to pending. It can take up to an hour to lock her account." }));

  if (!approved) {
    const actions = h("div", { class: "actions" },
      h("button", { class: "btn big primary", type: "button", disabled: busy, onclick: () => onApprove(row.uid) }, "Approve"),
      h("button", { class: "btn", type: "button", disabled: busy, title: "Approve her right away because you know her", onclick: () => onKnown(row.uid) }, "I know her, approve"));
    if (row.phone) {
      actions.append(
        h("a", { class: "btn", href: L.telHref(row.phone) }, "Call"),
        h("a", { class: "btn", href: L.waHref(row.phone), target: "_blank", rel: "noopener noreferrer" }, "WhatsApp"));
    }
    actions.append(h("button", { class: "btn", type: "button", "aria-expanded": String(state.reschedule === row.uid), onclick: () => { state.reschedule = state.reschedule === row.uid ? null : row.uid; renderQueue(); } }, "Change call time"));
    el.append(actions);
    const armed = state.declineArmed === row.uid;
    const reasonSel = h("select", { "aria-label": "Reason for declining", disabled: busy },
      ...L.DECLINE_REASONS.map((r) => h("option", { value: r.value, text: r.label })));
    const declineBtn = h("button", { class: `btn ${armed ? "danger" : "quiet-danger"}`, type: "button", disabled: busy, "data-decline": row.uid,
      onclick: () => onDecline(row.uid, reasonSel.value) }, armed ? `Decline ${title}` : "Decline");
    actions.append(declineBtn);
    if (armed) {
      el.append(h("div", { class: "confirm-strip", role: "group", "aria-label": `Decline ${title}` },
        h("p", { class: "muted", text: `Pick a reason, then press "Decline ${title}". She will be told her check was not passed. This is recorded with your name and can not be undone here.` }),
        reasonSel,
        h("button", { class: "btn", type: "button", onclick: () => { state.declineArmed = null; renderQueue(); } }, "Keep waiting")));
    }
    if (state.reschedule === row.uid) {
      const input = h("input", { type: "datetime-local", id: `resched-${row.uid}`, "aria-label": "New call time (Cairo time)" });
      el.append(h("div", { class: "resched" },
        h("label", { class: "inline-label", for: `resched-${row.uid}`, text: "New call time (Cairo time)" }), input,
        h("button", { class: "btn primary", type: "button", onclick: () => onReschedule(row.uid, input.value) }, "Save time")));
    }
  }
  return el;
}

/* approve and revoke: each handler has exactly one call site per callable */

async function approveOne(uid, reason) {
  return call("approve_user", { uid, reason });
}

async function approveMany(uids) {
  return call("approve_users", { uids });
}

async function revokeOne(uid) {
  return call("revoke_user", { uid });
}

async function onApprove(uid) {
  await runApproval(uid, "approve");
}

async function onKnown(uid) {
  await runApproval(uid, "knownPerson");
}

async function runApproval(uid, reason) {
  if (state.busy.has(uid)) return;
  state.busy.add(uid);
  renderQueue();
  try {
    await approveOne(uid, reason);
    startUndo([uid], "Approved.");
  } catch (e) {
    notice(friendly(e));
  } finally {
    state.busy.delete(uid);
    await loadQueue();
  }
}

async function onApproveSelected() {
  const uids = [...state.selected];
  if (!uids.length) return;
  uids.forEach((u) => state.busy.add(u));
  renderQueue();
  try {
    const result = await approveMany(uids);
    const done = result?.approved ?? [];
    const failed = result?.failed ?? [];
    state.selected = new Set();
    if (done.length) startUndo(done, `Approved ${done.length}.`);
    if (failed.length) notice(`${failed.length} could not be approved. Refresh and try again.`);
  } catch (e) {
    notice(friendly(e));
  } finally {
    uids.forEach((u) => state.busy.delete(u));
    await loadQueue();
  }
}

async function declineOne(uid, reason) {
  return call("decline_user", { uid, reason });
}

async function onDecline(uid, reason) {
  const step = L.rejectStep(state.declineArmed, uid);
  state.declineArmed = step.armed;
  if (!step.send) {
    renderQueue();
    document.querySelector(`[data-decline="${CSS.escape(uid)}"]`)?.focus();
    return;
  }
  state.busy.add(uid);
  renderQueue();
  try {
    await declineOne(uid, L.declineReason(reason));
    notice("Declined. It is recorded with your name.", true);
  } catch (e) {
    notice(friendly(e));
  } finally {
    state.busy.delete(uid);
    state.declineArmed = null;
    await loadQueue();
  }
}

async function onRevoke(uid, title, toggle) {
  const choice = await askDialog({
    title: `Revoke approval for ${title}?`,
    body: "She goes back to pending. It can take up to an hour to lock her account, until her sign-in refreshes. You can approve her again at any time.",
    actions: [{ id: "keep", label: "Keep her approved", safe: true }, { id: "revoke", label: "Revoke approval", kind: "danger" }],
  });
  if (choice !== "revoke") { toggle.checked = true; return; }
  state.busy.add(uid);
  try {
    await revokeOne(uid);
    showToast("Revoked. She is pending again. It can take up to an hour to lock her account.", null);
  } catch (e) {
    notice(friendly(e));
  } finally {
    state.busy.delete(uid);
    await loadQueue();
  }
}

async function onReschedule(uid, local) {
  const start = L.cairoLocalToIso(local);
  if (!start) { notice("Pick a date and time first."); return; }
  try {
    await call("reschedule_review", { uid, start });
    state.reschedule = null;
    notice("Time saved.", true);
  } catch (e) {
    notice(friendly(e));
  }
  await loadQueue();
}

/* undo toast */

function startUndo(uids, text, action = null) {
  state.undo = L.createUndo(uids, Date.now());
  state.undoAction = action;
  showToast(text, state.undo);
}

function showToast(text, undo) {
  clearInterval(undoTimer);
  clearTimeout(undoTimer);
  const toast = $("toast");
  $("toast-text").textContent = text;
  $("toast-undo").hidden = !undo;
  $("toast-bar").hidden = !undo;
  toast.hidden = false;
  toast.style.animation = "none";
  void toast.offsetWidth;
  toast.style.animation = "";
  if (!undo) {
    state.undo = null;
    state.undoAction = null;
    undoTimer = setTimeout(hideToast, 4000);
    return;
  }
  const tick = () => {
    const now = Date.now();
    if (!L.undoActive(state.undo, now)) { hideToast(); return; }
    toast.style.setProperty("--left", String(L.undoFraction(state.undo, now)));
  };
  tick();
  undoTimer = setInterval(tick, 100);
}

function hideToast() {
  clearInterval(undoTimer);
  clearTimeout(undoTimer);
  state.undo = null;
  state.undoAction = null;
  $("toast").hidden = true;
}

async function onUndo() {
  const undo = state.undo;
  const action = state.undoAction;
  if (!undo || !L.undoActive(undo, Date.now())) { hideToast(); return; }
  hideToast();
  try {
    if (action) await action();
    else await Promise.all(undo.uids.map((uid) => revokeOne(uid)));
    notice(action ? "Undone." : "Undone. They are pending again.", true);
  } catch (e) {
    notice(friendly(e));
  }
  if (state.tab === "phones") await loadPhones(); else await loadQueue();
}

/* calendar */

async function loadCalendar() {
  const range = L.rangeFor(state.calView, state.calDay);
  let bookings = [];
  try {
    bookings = L.normalizeRows(await call("list_schedule", { from: range.from, to: range.to }));
    notice("");
  } catch (e) {
    notice(friendly(e));
  }
  const groups = L.groupBookings(bookings, range.start, range.days);
  const today = L.cairoDayKey(new Date().toISOString());
  const fmt = (k) => new Intl.DateTimeFormat([], { timeZone: "UTC", weekday: "short", day: "numeric", month: "short" }).format(new Date(`${k}T00:00:00Z`));
  $("cal-title").textContent = state.calView === "week" ? `${fmt(range.start)} to ${fmt(L.addDays(range.start, 6))}` : fmt(range.start);
  $("cal-days").replaceChildren(...groups.map((g) => h("div", { class: `day${g.day === today ? " today" : ""}` },
    h("h3", { text: fmt(g.day) }),
    g.items.length
      ? g.items.map((b) => h("div", { class: "slot" },
          h("time", { text: L.cairoTime(b.start) }),
          h("span", { text: b.displayName || "Member" }),
          b.phone ? h("a", { class: "phone", href: L.telHref(b.phone), text: b.phone }) : null))
      : h("div", { class: "muted", text: "No calls" }))));
  for (const chip of document.querySelectorAll("[data-view]")) chip.setAttribute("aria-pressed", String(chip.dataset.view === state.calView));
}

function renderAvailability() {
  const box = $("avail");
  box.replaceChildren(...state.settings.availability.map((r, i) => {
    const day = h("select", { "aria-label": "Weekday" }, WEEKDAYS.map((d, k) => h("option", { value: String(k + 1), text: d })));
    day.value = String(r.weekday);
    day.addEventListener("change", () => { r.weekday = Number(day.value); });
    const start = h("input", { type: "time", value: r.start, "aria-label": "From" });
    start.addEventListener("change", () => { r.start = start.value; });
    const end = h("input", { type: "time", value: r.end, "aria-label": "To" });
    end.addEventListener("change", () => { r.end = end.value; });
    return h("div", { class: "avail-row" }, day, start, end,
      h("button", { class: "btn ghost", type: "button", "aria-label": "Remove these hours", onclick: () => { state.settings.availability.splice(i, 1); renderAvailability(); } }, "Remove"));
  }));
  $("slot-minutes").value = String(state.settings.slotMinutes);
}

async function loadSettings() {
  try {
    const s = await call("get_reviewer_settings", {});
    state.settings = {
      firstName: s.firstName ?? "",
      listed: !!s.listed,
      availability: (s.availability ?? []).map((r) => ({ ...r })),
      slotMinutes: s.slotMinutes ?? 15,
    };
  } catch (e) {
    notice(friendly(e));
  }
  $("first-name").value = state.settings.firstName;
  $("listed").checked = state.settings.listed;
  renderAvailability();
}

async function saveSettings(message) {
  const next = {
    ...state.settings,
    firstName: $("first-name").value.trim(),
    listed: $("listed").checked,
    slotMinutes: Number($("slot-minutes").value),
  };
  if (!L.validAvailability(next.availability)) { notice("Check your hours: each one needs a start before its end."); return; }
  try {
    await call("set_reviewer_settings", next);
    state.settings = next;
    notice(message, true);
  } catch (e) {
    notice(friendly(e));
  }
}


/* pre-approved numbers */

async function loadPhones() {
  if (!state.phonesLoaded) {
    $("phones-list").replaceChildren(...skeletons(2));
    setBusy($("phones-list"), true);
  }
  try {
    state.phones = (await call("list_preapproved_phones", {})).phones ?? [];
    state.phonesLoaded = true;
    notice("");
  } catch (e) {
    state.phonesLoaded = true;
    notice(friendly(e));
  }
  renderPhones();
}

function renderPhones() {
  const list = $("phones-list");
  setBusy(list, false);
  list.replaceChildren(...state.phones.map((p, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" }, h("div", { class: "name phone", text: p })),
      h("button", { class: "btn", type: "button", "aria-label": `Remove ${p}`, onclick: () => removePhone(p) }, "Remove")))));
  if (state.phones.length) $("phones-empty").hidden = true;
  else setEmpty($("phones-empty"), { title: "No numbers yet.", hint: "Paste the numbers above and press Add numbers. Anyone who signs in with one of them is approved at once.", art: "drawer" });
  setBadge("phones", state.phones.length, "numbers");
}

async function addPhones() {
  const phones = L.parsePhoneList($("phones-input").value);
  if (!phones.length) { notice("No valid numbers found. A number has 7 to 15 digits, with or without +."); $("phones-input").focus(); return; }
  try {
    state.phones = (await call("set_preapproved_phones", { add: phones.join(", ") })).phones ?? state.phones;
    $("phones-input").value = "";
    $("phones-preview").textContent = "";
    notice(`Added ${phones.length}.`, true);
  } catch (e) {
    notice(friendly(e));
  }
  renderPhones();
}

async function removePhone(phone) {
  try {
    state.phones = (await call("set_preapproved_phones", { remove: [phone] })).phones ?? state.phones;
    startUndo([phone], `Removed ${phone}.`, async () => {
      state.phones = (await call("set_preapproved_phones", { add: phone })).phones ?? state.phones;
    });
  } catch (e) {
    notice(friendly(e));
  }
  renderPhones();
}

/* exercises */

const ex = {
  rows: [], vocab: null, loaded: false, filter: "all", query: "",
  checked: L.parseChecked(browserStore.get(L.CHECKED_KEY)),
  form: null, sig: "", queue: [], fields: {}, showErrors: false, saving: false,
  watch: null, open: null, io: null, local: [], prefs: { rate: 1, loop: true },
};
const LABEL = (v) => String(v ?? "").replace(/_/g, " ");
const CAP = (v) => LABEL(v).replace(/^./, (c) => c.toUpperCase());
const isChecked = (id) => ex.checked.has(id);
const stateOf = (row) => L.exerciseState(row, isChecked(row.id), ex.vocab);
const reducedMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

/* exercise videos and pictures, read from the public library folder */

const exMedia = {
  videos: new L.LruCache(L.MEDIA_CACHE.videos, {
    onEvict: (url) => URL.revokeObjectURL(url),
    isPinned: (path) => (exMedia.holds.get(path) ?? 0) > 0,
  }),
  posters: new L.LruCache(L.MEDIA_CACHE.posters),
  holds: new Map(),
  pending: new Map(),
  limit: L.createLimiter(L.POSTER_CONCURRENCY),
  gen: 0,
};

function holdVideo(path) {
  exMedia.holds.set(path, (exMedia.holds.get(path) ?? 0) + 1);
}

// A released clip stays in the cache (so Previous and Next feel instant) until the cache trims it.
function releaseVideo(path) {
  const left = (exMedia.holds.get(path) ?? 0) - 1;
  if (left > 0) exMedia.holds.set(path, left);
  else exMedia.holds.delete(path);
}

function forgetVideo(path) {
  exMedia.pending.delete(`v:${path}`);
  exMedia.videos.delete(path);
}

function once(path, make) {
  let promise = exMedia.pending.get(path);
  if (!promise) {
    promise = make().finally(() => exMedia.pending.delete(path));
    exMedia.pending.set(path, promise);
  }
  return promise;
}

// Resolves to a blob URL, or null when nothing on screen wants the video any more.
function fetchVideoUrl(path) {
  const cached = exMedia.videos.get(path);
  if (cached) return Promise.resolve(cached);
  return once(`v:${path}`, async () => {
    const bytes = await getBytes(storageRef(storage, path), L.CLIP_MAX_BYTES);
    if (!exMedia.holds.get(path)) return null;
    const url = URL.createObjectURL(new Blob([bytes], { type: "video/mp4" }));
    exMedia.videos.set(path, url);
    return url;
  });
}

// Pictures travel as data URLs because the page policy allows data: images, not blob: ones.
function fetchPoster(path, skip = () => false) {
  const cached = exMedia.posters.get(path);
  if (cached) return Promise.resolve(cached);
  return once(`p:${path}`, () => exMedia.limit(async () => {
    if (skip()) return null;
    const bytes = await getBytes(storageRef(storage, path), L.POSTER_MAX_BYTES);
    const url = await readAsDataUrl(new Blob([bytes], { type: L.posterMime(path) }));
    exMedia.posters.set(path, url);
    return url;
  }));
}

// Downloads the next clip in the background so Save and next shows it at once.
function prefetchVideo(row) {
  if (!row || navigator.connection?.saveData) return;
  const front = L.orderClips(row.clips ?? [])[0];
  const path = front ? L.exerciseMediaPath(row.id, front.file) : "";
  if (!path || exMedia.videos.has(path) || exMedia.pending.has(`v:${path}`)) return;
  const gen = exMedia.gen;
  holdVideo(path);
  fetchVideoUrl(path).catch(() => {}).finally(() => {
    releaseVideo(path);
    if (gen !== exMedia.gen) forgetVideo(path);
  });
}

const clock = (s) => {
  const n = Math.max(0, Math.floor(Number.isFinite(s) ? s : 0));
  return `${Math.floor(n / 60)}:${String(n % 60).padStart(2, "0")}`;
};

function fullscreenOf(el, video) {
  const request = el.requestFullscreen || el.webkitRequestFullscreen;
  if (request) return request.call(el);
  if (video?.webkitEnterFullscreen) return video.webkitEnterFullscreen();
  return null;
}

// One clip with its own controls. Speed and loop carry over from clip to clip.
function makeSlot(ctx, first) {
  let current = first;
  let token = 0;
  let held = "";
  let video = null;
  let posterPath = "";
  let destroyed = false;
  let slowTimer = 0;
  const caption = h("figcaption", { class: "watch-cap", text: L.slotCaption(first) });
  const frame = h("div", { class: "watch-frame" });
  const bar = h("div", { class: "player-bar", hidden: true });
  const el = h("figure", { class: "watch-slot" }, caption, frame, bar);

  const release = () => { if (held) { releaseVideo(held); held = ""; } };
  const stopSlow = () => { clearTimeout(slowTimer); slowTimer = 0; };

  const say = (text, { retry = null, fresh = null, working = false } = {}) => {
    stopSlow();
    video = null;
    bar.hidden = true;
    bar.replaceChildren();
    frame.replaceChildren(...[
      working ? h("span", { class: "shimmer", "aria-hidden": "true" }) : null,
      h("p", { class: "watch-state", role: working ? "status" : "alert", text }),
      retry || fresh ? h("div", { class: "watch-retry" },
        retry ? h("button", { class: "btn", type: "button", onclick: retry }, "Retry") : null,
        fresh ? h("button", { class: "btn", type: "button", title: "Forget the copy kept on this page and download the video again", onclick: fresh }, "Try again without cache") : null) : null,
    ].filter(Boolean));
  };
  const failure = (text) => {
    const path = held;
    say(text, {
      retry: () => load(),
      fresh: () => { if (path) forgetVideo(path); load(); },
    });
  };

  const applyPoster = () => {
    if (!video || current.localUrl) return;
    const path = L.exerciseMediaPath(ctx.getId(), ctx.getPoster());
    if (!path || path === posterPath) return;
    posterPath = path;
    const target = video;
    fetchPoster(path).then((url) => { if (url && !destroyed && video === target) target.poster = url; }).catch(() => {});
  };

  const buildBar = (player) => {
    const play = h("button", { class: "btn ctl", type: "button", "aria-label": "Play" }, "Play");
    const scrub = h("input", { type: "range", min: "0", max: "1000", step: "1", value: "0", class: "scrub", "aria-label": "Position in the video" });
    const time = h("span", { class: "time", text: "0:00" });
    let dragging = false;
    const sync = () => {
      const paused = player.paused;
      play.textContent = paused ? "Play" : "Pause";
      play.setAttribute("aria-label", paused ? "Play" : "Pause");
    };
    const toggle = () => { if (player.paused) player.play().catch(() => {}); else player.pause(); };
    play.addEventListener("click", toggle);
    player.addEventListener("click", toggle);
    player.addEventListener("play", sync);
    player.addEventListener("pause", sync);
    player.addEventListener("timeupdate", () => {
      const d = player.duration;
      time.textContent = `${clock(player.currentTime)} / ${clock(d)}`;
      if (!dragging && d > 0) scrub.value = String(Math.round((player.currentTime / d) * 1000));
    });
    scrub.addEventListener("pointerdown", () => { dragging = true; });
    scrub.addEventListener("pointerup", () => { dragging = false; });
    scrub.addEventListener("input", () => {
      if (player.duration > 0) player.currentTime = (Number(scrub.value) / 1000) * player.duration;
    });
    const speeds = [0.5, 1, 2].map((rate) => {
      const b = h("button", { class: "btn ctl seg", type: "button", "aria-pressed": String(ex.prefs.rate === rate), "aria-label": `Speed ${rate} times` }, `${rate}x`);
      b.addEventListener("click", () => {
        ex.prefs.rate = rate;
        player.playbackRate = rate;
        for (const other of speedBox.children) other.setAttribute("aria-pressed", String(other === b));
      });
      return b;
    });
    const speedBox = h("div", { class: "seg-group", role: "group", "aria-label": "Speed" }, speeds);
    const loop = h("button", { class: "btn ctl", type: "button", "aria-pressed": String(ex.prefs.loop) }, "Loop");
    loop.addEventListener("click", () => {
      ex.prefs.loop = !ex.prefs.loop;
      player.loop = ex.prefs.loop;
      loop.setAttribute("aria-pressed", String(ex.prefs.loop));
    });
    const full = h("button", { class: "btn ctl", type: "button", "aria-label": "Open full screen" }, "Full screen");
    full.addEventListener("click", () => {
      if (document.fullscreenElement === el) { document.exitFullscreen?.(); return; }
      try { Promise.resolve(fullscreenOf(el, player)).catch(() => {}); } catch (e) { /* the browser refused */ }
    });
    bar.replaceChildren(
      h("div", { class: "player-row" }, play, scrub, time),
      h("div", { class: "player-row" }, speedBox, loop, full));
    bar.hidden = false;
    sync();
    return { toggle };
  };

  let api = { toggle() {} };
  const show = (url, autoplay) => {
    stopSlow();
    const player = h("video", {
      playsinline: true, loop: ex.prefs.loop, preload: "auto", src: url, tabindex: "-1",
      "aria-label": L.viewLabel(current.angle, ctx.getName()),
    });
    player.muted = true;
    player.defaultMuted = true;
    player.defaultPlaybackRate = ex.prefs.rate;
    player.playbackRate = ex.prefs.rate;
    player.addEventListener("loadedmetadata", () => { player.playbackRate = ex.prefs.rate; });
    player.addEventListener("error", () => {
      if (destroyed || video !== player) return;
      if (held) forgetVideo(held);
      failure(L.playbackErrorText(player.error?.code));
    });
    video = player;
    posterPath = "";
    frame.replaceChildren(player);
    api = buildBar(player);
    applyPoster();
    if (autoplay && !reducedMotion()) player.play().catch(() => {});
  };

  const load = async () => {
    const mine = ++token;
    stopSlow();
    if (current.localUrl) { release(); show(current.localUrl, false); return; }
    const path = L.exerciseMediaPath(ctx.getId(), current.file);
    if (!path) { say("This video has no usable file name in the library."); return; }
    if (held !== path) { release(); held = path; holdVideo(path); }
    say("Loading the video...", { working: true });
    slowTimer = setTimeout(() => {
      const note = frame.querySelector(".watch-state");
      if (!destroyed && mine === token && note) note.textContent = L.SLOW_LOAD_TEXT;
    }, L.SLOW_LOAD_MS);
    const posterFile = L.exerciseMediaPath(ctx.getId(), ctx.getPoster());
    if (posterFile) fetchPoster(posterFile).then((url) => {
      if (!url || destroyed || mine !== token || video) return;
      frame.prepend(h("img", { class: "watch-poster", src: url, alt: "" }));
    }).catch(() => {});
    let tries = 0;
    for (;;) {
      try {
        const url = await fetchVideoUrl(path);
        if (destroyed || mine !== token || !url) return;
        show(url, ctx.autoplay === true && current.autoplay === true);
        return;
      } catch (e) {
        if (destroyed || mine !== token) return;
        if (tries === 0 && L.isRetryableLoad(e, navigator.onLine !== false)) {
          tries += 1;
          await new Promise((r) => setTimeout(r, 1200));
          if (destroyed || mine !== token) return;
          continue;
        }
        failure(L.storageErrorText(e, navigator.onLine !== false).text);
        return;
      }
    }
  };

  load();
  return {
    el,
    toggle: () => api.toggle(),
    update(next) {
      current = next;
      caption.textContent = L.slotCaption(next);
      if (video) {
        video.setAttribute("aria-label", L.viewLabel(next.angle, ctx.getName()));
        applyPoster();
      }
    },
    destroy() {
      destroyed = true;
      token += 1;
      stopSlow();
      release();
      if (document.fullscreenElement === el) document.exitFullscreen?.();
      if (video) { video.pause(); video.removeAttribute("src"); video.load(); }
      el.remove();
    },
  };
}

// One player per clip, front first. Videos stay mounted while the form changes around them.
function createWatch(ctx, { heading = false } = {}) {
  const grid = h("div", { class: "watch-grid" });
  const none = h("p", { class: "muted watch-none", text: ctx.emptyText ?? "No video yet." });
  const el = h("section", { class: "watch", "aria-label": "Watch" },
    heading ? h("h3", { text: "Watch" }) : null, grid, none);
  const slots = new Map();
  let destroyed = false;
  let order = [];
  return {
    el,
    toggle() { slots.get(order[0])?.toggle(); },
    sync(items) {
      if (destroyed) return;
      const keep = new Set(items.map((i) => i.key));
      for (const [key, slot] of slots) {
        if (!keep.has(key)) { slot.destroy(); slots.delete(key); }
      }
      order = items.map((i) => i.key);
      items.forEach((item, index) => {
        const withFlag = { ...item, autoplay: index === 0 };
        const slot = slots.get(item.key);
        if (slot) slot.update(withFlag); else slots.set(item.key, makeSlot(ctx, withFlag));
      });
      const want = items.map((i) => slots.get(i.key).el);
      const have = [...grid.children];
      if (want.length !== have.length || want.some((node, i) => node !== have[i])) grid.replaceChildren(...want);
      none.hidden = items.length > 0;
    },
    destroy() {
      destroyed = true;
      for (const slot of slots.values()) slot.destroy();
      slots.clear();
      el.remove();
    },
  };
}

function dropLocals(keepUploading) {
  ex.local = ex.local.filter((l) => {
    if (keepUploading && l.uploading) return true;
    URL.revokeObjectURL(l.url);
    return false;
  });
}

function refreshWatch() {
  const f = ex.form, dock = $("ex-watch");
  if (!f || !dock) return;
  if (!ex.watch) {
    ex.watch = createWatch({
      getId: () => ex.form?.exerciseId ?? "",
      getName: () => ex.form?.name_en || ex.form?.exerciseId || "",
      getPoster: () => ex.form?.poster?.file ?? "",
      autoplay: true,
      emptyText: "No video yet. Choose one below and it shows here at once.",
    }, { heading: true });
    dock.replaceChildren(ex.watch.el);
  }
  ex.watch.sync(L.watchItems(f.clips, ex.local.filter((l) => l.form === f)));
}

function closeRowPlayer() {
  const open = ex.open;
  if (!open) return;
  ex.open = null;
  open.watch.destroy();
  open.host.hidden = true;
  open.button.setAttribute("aria-expanded", "false");
  open.button.setAttribute("aria-label", `Watch ${open.row.nameEn}`);
  open.button.textContent = "Watch";
}

function toggleRowPlayer(row, button, host) {
  const wasOpen = ex.open?.row.id === row.id;
  closeRowPlayer();
  if (wasOpen) return;
  const watch = createWatch({ getId: () => row.id, getName: () => row.nameEn, getPoster: () => row.poster?.file ?? "", autoplay: true });
  host.replaceChildren(watch.el);
  host.hidden = false;
  watch.sync(L.watchItems(row.clips, []));
  button.setAttribute("aria-expanded", "true");
  button.setAttribute("aria-label", `Hide the video of ${row.nameEn}`);
  button.textContent = "Hide";
  ex.open = { row, watch, host, button };
}

function loadThumb(img) {
  const path = L.exerciseMediaPath(img.dataset.id, img.dataset.file);
  if (!path) return;
  const gen = exMedia.gen;
  fetchPoster(path, () => gen !== exMedia.gen || !img.isConnected)
    .then((url) => { if (url && img.isConnected) img.src = url; })
    .catch(() => {});
}

function observeThumbs(thumbs) {
  ex.io?.disconnect();
  ex.io = null;
  if (typeof IntersectionObserver !== "function") { thumbs.slice(0, 12).forEach(loadThumb); return; }
  const io = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      io.unobserve(entry.target);
      loadThumb(entry.target);
    }
  }, { rootMargin: "160px" });
  ex.io = io;
  thumbs.forEach((img) => io.observe(img));
}

// Called when the Exercises tab is left: nothing keeps a video, a picture request or a local preview alive.
function releaseExerciseMedia() {
  exMedia.gen += 1;
  ex.io?.disconnect();
  ex.io = null;
  closeRowPlayer();
  if (ex.watch) { ex.watch.destroy(); ex.watch = null; }
  dropLocals(true);
  exMedia.videos.clear();
}

function readAsDataUrl(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

/* exercise list, progress and filters */

function exVisible() {
  return L.filterExercises(ex.rows, { filter: ex.filter, query: ex.query, isChecked, vocab: ex.vocab });
}

function exTodoQueue() {
  return L.filterExercises(ex.rows, { filter: "all", isChecked, vocab: ex.vocab }).filter((r) => !stateOf(r).complete).map((r) => r.id);
}

function renderOverview() {
  const counts = L.exerciseCounts(ex.rows, isChecked, ex.vocab);
  $("ex-progress-text").textContent = ex.loaded ? L.progressText(counts) : "Exercises";
  const pct = Math.round(L.progressFraction(counts) * 100);
  $("ex-meter").setAttribute("aria-valuenow", String(pct));
  $("ex-meter-fill").style.setProperty("width", `${pct}%`);
  $("ex-progress-sub").textContent = !ex.loaded ? "" : counts.total === 0 ? "No exercises yet."
    : counts.complete === counts.total ? "Every exercise is complete."
      : `${counts.tags} still need tags or your check · ${counts.video} need a video.`;
  const byKey = { tags: counts.tags, video: counts.video, complete: counts.complete, all: counts.all };
  for (const chip of $("ex-filters").querySelectorAll(".chip")) {
    const k = chip.dataset.filter;
    chip.setAttribute("aria-pressed", String(k === ex.filter));
    chip.querySelector(".count").textContent = ex.loaded ? String(byKey[k]) : "";
  }
  const todo = L.firstToReview(ex.rows, isChecked, ex.vocab);
  const next = $("ex-next");
  next.disabled = !ex.loaded || todo == null;
  next.textContent = !ex.loaded || todo != null ? "Next to review" : "All reviewed";
  if (ex.loaded) setBadge("exercises", counts.total - counts.complete, "to review");
}

const EX_EMPTY = {
  tags: ["Nothing needs tags.", "Every move has its type, pattern, muscles and safety tags chosen, and you have checked it."],
  video: ["Every exercise has a video.", "A move without a video would show up here."],
  complete: ["No exercise is complete yet.", "Finish the checklist on a move and it moves here."],
  all: ["There are no exercises yet.", "Press Add exercise to create the first one."],
};

function rowBadges(s) {
  if (s.complete) return [h("span", { class: "badge sage", text: "Complete" })];
  const out = [];
  if (s.needsVideo) out.push(h("span", { class: "badge known", text: "Needs video" }));
  if (s.needsTags) out.push(h("span", { class: "badge known", text: s.missing.every((k) => k === "checked" || k === "video") ? "Not checked yet" : "Needs tags" }));
  return out;
}

function renderExercises() {
  closeRowPlayer();
  const list = $("ex-list");
  if (!ex.loaded) {
    ex.io?.disconnect();
    list.replaceChildren(...(ex.loadFailed ? [] : skeletons(4)));
    setBusy(list, !ex.loadFailed);
    if (ex.loadFailed) setEmpty($("ex-empty"), { title: "The exercises could not be loaded.", hint: "Check your internet connection and try again.", art: "plug", action: { label: "Try again", onclick: () => loadExercises() } });
    else $("ex-empty").hidden = true;
    return;
  }
  setBusy(list, false);
  const rows = exVisible();
  const queue = rows.map((r) => r.id);
  const thumbs = [];
  list.replaceChildren(...rows.map((r, i) => {
    const s = stateOf(r);
    const hasVideo = (r.clips?.length ?? 0) > 0;
    const thumb = h("img", { class: "ex-thumb", alt: "", width: 56, height: 72, "data-id": r.id, "data-file": r.poster?.file ?? "" });
    thumbs.push(thumb);
    const inline = h("div", { class: "ex-inline", id: `ex-watch-${r.id}`, hidden: true });
    const watch = h("button", {
      class: "btn", type: "button", disabled: !hasVideo, "aria-expanded": "false", "aria-controls": `ex-watch-${r.id}`,
      "aria-label": hasVideo ? `Watch ${r.nameEn}` : `${r.nameEn} has no video yet`,
    }, "Watch");
    watch.addEventListener("click", () => toggleRowPlayer(r, watch, inline));
    return h("li", { class: "item", vars: { "--i": Math.min(i, 8) }, "data-row": r.id },
      h("div", { class: "item-head ex-head" },
        thumb,
        h("div", { class: "who" },
          h("div", { class: "name", text: r.nameEn }),
          h("div", { class: "meta" }, rowBadges(s)),
          h("div", { class: "muted", text: `${LABEL(r.kind)} · ${LABEL(r.pattern)} · ${(r.primaryMuscles ?? []).map(LABEL).join(", ") || "no muscles chosen"}` })),
        h("div", { class: "ex-actions" },
          watch,
          h("button", { class: "btn", type: "button", "aria-label": `Review ${r.nameEn}`, onclick: () => openReview(r.id, queue) }, "Review"))),
      inline);
  }));
  observeThumbs(thumbs);
  if (rows.length) {
    $("ex-empty").hidden = true;
  } else if (ex.query.trim()) {
    setEmpty($("ex-empty"), { title: `No exercise matches "${ex.query.trim()}".`, hint: "Try part of the name, or a muscle such as glutes.", art: "query", action: { label: "Clear search", onclick: () => { ex.query = ""; $("ex-search").value = ""; renderExercises(); renderOverview(); $("ex-search").focus(); } } });
  } else {
    const [title, hint] = ex.rows.length ? EX_EMPTY[ex.filter] : EX_EMPTY.all;
    setEmpty($("ex-empty"), { title, hint, art: "plot" });
  }
}

async function loadExercises({ quiet = false } = {}) {
  if (!ex.loaded && !quiet) { ex.loadFailed = false; renderOverview(); renderExercises(); }
  try {
    const data = await call("list_exercises", {});
    ex.rows = data.exercises ?? [];
    ex.vocab = data.vocab;
    ex.loaded = true;
    ex.loadFailed = false;
    if (!quiet) notice("");
  } catch (e) {
    if (!quiet) notice(friendly(e));
    if (!ex.loaded) ex.loadFailed = true;
  }
  renderOverview();
  renderExercises();
}

function setChecked(id, on) {
  if (on) ex.checked.add(id); else ex.checked.delete(id);
  browserStore.set(L.CHECKED_KEY, L.serializeChecked(ex.checked));
}

/* the review form: one exercise at a time */

const exDirty = () => Boolean(ex.form) && (L.formSignature(ex.form) !== ex.sig || ex.local.some((l) => l.uploading));
const dataSignature = (f) => L.formSignature({ ...f, checked: false });

// Asks before work is lost. Resolves to true when it is fine to leave this exercise.
async function leaveReview() {
  if (!exDirty()) return true;
  if (ex.local.some((l) => l.uploading)) {
    notice("A video is still uploading. Wait for it to finish first.");
    return false;
  }
  const name = ex.form.name_en.trim() || "this exercise";
  const choice = await askDialog({
    title: "Save your changes first?",
    body: `You changed ${name}. Saving puts the change live for members straight away.`,
    actions: [
      { id: "stay", label: "Keep editing", safe: true },
      { id: "discard", label: "Discard changes", kind: "danger" },
      { id: "save", label: "Save and continue", kind: "primary" },
    ],
  });
  if (choice === "save") return saveReview();
  return choice === "discard";
}

async function openReview(id, queue) {
  if (ex.form && !(await leaveReview())) return false;
  const row = ex.rows.find((r) => r.id === id);
  if (!row || !ex.vocab) { notice("That exercise is not in the list. Refresh the page."); return false; }
  if (!ex.form) ex.listY = window.scrollY;
  ex.form = L.formFromRow(row, true);
  ex.queue = queue ?? [id];
  ex.sig = L.formSignature(ex.form);
  ex.dataSig = dataSignature(ex.form);
  ex.showErrors = false;
  ex.idTouched = true;
  renderReview();
  window.scrollTo({ top: 0, behavior: "auto" });
  $("ex-title").setAttribute("tabindex", "-1");
  $("ex-title").focus({ preventScroll: true });
  const after = L.nextUnfinished(ex.queue, id, (other) => stateOf(ex.rows.find((r) => r.id === other) ?? {}).complete) ?? L.neighbour(ex.queue, id, 1);
  prefetchVideo(ex.rows.find((r) => r.id === after));
  return true;
}

async function openNewReview() {
  if (!ex.vocab) { notice("The exercise list has not loaded yet. Try again in a moment."); return; }
  if (ex.form && !(await leaveReview())) return;
  if (!ex.form) ex.listY = window.scrollY;
  ex.form = L.blankExercise(ex.vocab);
  ex.queue = [];
  ex.sig = L.formSignature(ex.form);
  ex.dataSig = dataSignature(ex.form);
  ex.showErrors = false;
  ex.idTouched = false;
  renderReview();
  window.scrollTo({ top: 0, behavior: "auto" });
  ex.fields.name_en?.focus?.focus();
}

async function closeReview() {
  if (!(await leaveReview())) return;
  const id = ex.form?.exerciseId;
  ex.form = null;
  renderReview();
  renderOverview();
  renderExercises();
  window.scrollTo({ top: ex.listY ?? 0, behavior: "auto" });
  document.querySelector(`[data-row="${CSS.escape(id ?? "")}"] .btn:last-child`)?.focus({ preventScroll: true });
}

function nextTarget() {
  const f = ex.form;
  if (!f || !ex.queue.length) return null;
  const done = (other) => other === f.exerciseId || stateOf(ex.rows.find((r) => r.id === other) ?? { id: other }).complete;
  return L.nextUnfinished(ex.queue, f.exerciseId, done);
}

async function stepReview(step) {
  const f = ex.form;
  if (!f) return;
  const target = L.neighbour(ex.queue, f.exerciseId, step);
  if (target) await openReview(target, ex.queue);
}

function focusField(key) {
  const entry = key === "clips" ? { box: $("ex-video-box"), focus: $("ex-file") } : ex.fields[key];
  if (!entry) return;
  entry.box?.closest("details")?.setAttribute("open", "");
  entry.box?.scrollIntoView({ behavior: calmScroll(), block: "center" });
  entry.focus?.focus({ preventScroll: true });
}

function rowOfForm() {
  const f = ex.form;
  return { id: f.exerciseId, clips: f.clips, kind: f.kind, pattern: f.pattern, primaryMuscles: f.primaryMuscles, tags: f.contraindicationTags };
}

function newField(key, label, control, { hint = null } = {}) {
  control.id = `f-${key}`;
  const err = h("p", { class: "field-error", id: `err-${key}`, hidden: true });
  control.setAttribute("aria-describedby", `err-${key}`);
  const box = h("div", { class: "field", "data-field": key }, h("label", { for: control.id, text: label }), control, hint, err);
  ex.fields[key] = { box, err, focus: control, controls: [control] };
  return box;
}

function newGroup(key, legend, help, body) {
  const err = h("p", { class: "field-error", id: `err-${key}`, hidden: true });
  const box = h("fieldset", { class: "field group", "data-field": key, "aria-describedby": `err-${key}` },
    h("legend", { text: legend }), help ? h("p", { class: "hint", text: help }) : null, body, err);
  ex.fields[key] = { box, err, focus: null, controls: [] };
  return box;
}

function textField(key, label, { rtl = false } = {}) {
  const f = ex.form;
  const input = h("input", { type: "text", value: f[key] ?? "", autocomplete: "off", dir: rtl ? "rtl" : null, lang: rtl ? "ar" : null });
  input.addEventListener("input", () => {
    f[key] = input.value;
    if (key === "name_en" && f.isNew && !ex.idTouched) {
      f.exerciseId = L.exerciseId(f.name_en, ex.rows.map((r) => r.id));
      if (ex.idInput) ex.idInput.value = f.exerciseId;
    }
    syncReview();
  });
  return newField(key, label, input);
}

function selectField(key, label, options, group = null) {
  const f = ex.form;
  const select = h("select", {}, options.map((o) => h("option", { value: o, text: CAP(o) })));
  select.value = f[key];
  const hint = group ? h("p", { class: "hint", "aria-live": "polite", text: L.hintFor(group, f[key]) }) : null;
  select.addEventListener("change", () => {
    f[key] = select.value;
    if (hint) hint.textContent = L.hintFor(group, f[key]);
    syncReview();
  });
  return newField(key, label, select, { hint });
}

function checkOption(key, token, hint = "") {
  const f = ex.form;
  const input = h("input", { type: "checkbox", "data-token": token });
  input.checked = f[key].includes(token);
  input.addEventListener("change", () => onToggle(key, token, input.checked));
  return h("label", { class: `opt${hint ? " with-hint" : ""}` }, input,
    h("span", { class: "opt-text" }, h("span", { class: "opt-name", text: CAP(token) }), hint ? h("span", { class: "opt-hint", text: hint }) : null));
}

function checkGroup(key, legend, help, tokens, hintGroup = null) {
  const body = h("div", { class: hintGroup ? "opt-list" : "opt-grid" }, tokens.map((t) => checkOption(key, t, hintGroup ? L.hintFor(hintGroup, t) : "")));
  const box = newGroup(key, legend, help, body);
  ex.fields[key].focus = body.querySelector("input");
  return box;
}

function syncGroups() {
  const f = ex.form;
  for (const key of ["primaryMuscles", "secondaryMuscles", "equipment", "contraindicationTags"]) {
    const box = ex.fields[key]?.box;
    if (!box) continue;
    for (const input of box.querySelectorAll("input[data-token]")) {
      const token = input.dataset.token;
      input.checked = f[key].includes(token);
      if (key === "secondaryMuscles") {
        input.disabled = f.primaryMuscles.includes(token);
        input.closest("label").title = input.disabled ? "Already a main muscle" : "";
      }
    }
  }
}

function onToggle(key, token, on) {
  const f = ex.form;
  if (key === "contraindicationTags" || key === "equipment") {
    f[key] = L.toggleExclusive(f[key], token, on);
  } else {
    const set = new Set(f[key]);
    if (on) set.add(token); else set.delete(token);
    f[key] = [...set];
    if (key === "primaryMuscles" && on) f.secondaryMuscles = f.secondaryMuscles.filter((m) => m !== token);
  }
  syncGroups();
  syncReview();
}

function problemsNow() {
  return L.exerciseProblems(ex.form, { taken: ex.rows.map((r) => r.id) });
}

// Everything on screen that depends on the form's values. Never rebuilds the form, so the video keeps playing.
function syncReview() {
  const f = ex.form;
  if (!f || !$("ex-review")) return;
  $("ex-title").textContent = f.name_en.trim() || (f.isNew ? "New exercise" : "Exercise");
  const items = L.exerciseChecklist(rowOfForm(), f.checked, ex.vocab);
  const list = $("ex-checklist");
  list.replaceChildren(...items.filter((i) => i.key !== "checked").map((i) => h("li", {},
    h("button", { class: `check-item${i.ok ? " ok" : ""}`, type: "button", disabled: i.ok, onclick: () => focusField({ video: "clips", kind: "kind", pattern: "pattern", muscles: "primaryMuscles", tags: "contraindicationTags" }[i.key]) },
      h("span", { class: "mark", "aria-hidden": "true", text: i.ok ? "✓" : "○" }),
      h("span", { text: i.label }),
      h("span", { class: "sr", text: i.ok ? " (done)" : " (to do, press to go there)" })))));
  const done = items.filter((i) => i.key !== "checked").every((i) => i.ok);
  const complete = done && f.checked && !f.isNew && isChecked(f.exerciseId);
  $("ex-state-badge").className = `badge ${complete ? "sage" : "known"}`;
  $("ex-state-badge").textContent = complete ? "Complete" : done ? "Not checked yet" : "Needs work";
  const dirty = exDirty();
  const changed = dataSignature(f) !== ex.dataSig;
  $("ex-status").textContent = f.isNew ? "Not saved yet." : dirty ? (changed ? "Unsaved changes." : "Not saved yet.") : "No unsaved changes.";
  const next = nextTarget();
  const nextBtn = $("ex-save-next");
  if (nextBtn) nextBtn.textContent = f.isNew ? "Add exercise" : next ? "Save and next" : "Save and finish";
  const pos = L.queuePosition(ex.queue, f.exerciseId);
  $("ex-prev").disabled = !pos || pos.index === 0;
  $("ex-next-btn").disabled = !pos || pos.index === pos.total - 1;
  if (ex.showErrors) {
    const problems = problemsNow();
    const byField = new Map();
    for (const p of problems) if (!byField.has(p.field)) byField.set(p.field, p.message);
    for (const [key, entry] of Object.entries(ex.fields)) {
      const msg = byField.get(key) ?? "";
      entry.err.textContent = msg;
      entry.err.hidden = !msg;
      entry.box.classList.toggle("invalid", Boolean(msg));
      for (const c of entry.controls) c.setAttribute("aria-invalid", String(Boolean(msg)));
    }
    const videoMsg = byField.get("clips") ?? "";
    $("err-clips").textContent = videoMsg;
    $("err-clips").hidden = !videoMsg;
    problemList($("ex-problems"), problems.map((p) => p.message));
  }
}

function videoStatus(text, bad = false) {
  const el = $("ex-upload-status");
  if (!el) return;
  el.textContent = text;
  el.classList.toggle("bad", bad);
}

function renderClipList() {
  const f = ex.form;
  const box = $("ex-clips");
  if (!box) return;
  box.replaceChildren(...(f.clips.length ? L.orderClips(f.clips).map((c) => h("li", {},
    h("strong", { text: L.angleLabel(c.angle) }), c.seconds ? ` · ${L.clipSecondsText(c.seconds)}` : "",
    h("span", { class: "muted detail-file", text: ` · ${c.file}` }))) : [h("li", { class: "muted", text: "No video yet." })]));
}

function renderReview() {
  const f = ex.form;
  const panel = $("panel-exercises");
  if (ex.watch) { ex.watch.destroy(); ex.watch = null; }
  dropLocals(false);
  ex.fields = {};
  ex.idInput = null;
  if (!f) {
    $("ex-form").replaceChildren();
    panel.classList.remove("reviewing");
    return;
  }
  panel.classList.add("reviewing");
  const v = ex.vocab;
  const angle = h("select", { id: "ex-angle", "aria-label": "Which view this video shows" }, v.angles.map((a) => h("option", { value: a, text: L.angleLabel(a) })));
  const file = h("input", { type: "file", accept: "video/mp4", id: "ex-file", "aria-describedby": "ex-upload-status", onchange: onClipChosen });
  const idInput = h("input", { type: "text", value: f.exerciseId, readonly: f.isNew ? null : true, autocomplete: "off", "aria-describedby": "err-exerciseId" });
  idInput.addEventListener("input", () => { ex.idTouched = true; f.exerciseId = idInput.value.trim(); syncReview(); });
  const idField = newField("exerciseId", "Id (lowercase letters, digits and _; it can not change after the first save)", idInput);
  ex.idInput = idInput;

  const checkedBox = h("input", { type: "checkbox", id: "f-checked" });
  checkedBox.checked = f.checked;
  checkedBox.addEventListener("change", () => { f.checked = checkedBox.checked; syncReview(); });

  const pos = L.queuePosition(ex.queue, f.exerciseId);
  const bar = h("div", { class: "review-bar" },
    h("button", { class: "btn", type: "button", onclick: closeReview }, "‹ All exercises"),
    h("div", { class: "review-where", "aria-live": "polite" },
      f.isNew ? h("strong", { text: "New exercise" }) : [h("strong", { text: pos ? `Exercise ${pos.number} of ${pos.total}` : "Exercise" }),
        pos && ex.queue.length > 1 ? h("span", { class: "muted", text: ` · ${L.progressText(L.exerciseCounts(ex.rows, isChecked, ex.vocab))}` }) : null]),
    h("div", { class: "review-nav" },
      h("button", { class: "btn", id: "ex-prev", type: "button", "aria-label": "Previous exercise", onclick: () => stepReview(-1) }, "‹ Previous"),
      h("button", { class: "btn", id: "ex-next-btn", type: "button", "aria-label": "Next exercise", onclick: () => stepReview(1) }, "Next ›")));

  const watchSide = h("aside", { class: "review-watch" },
    h("div", { class: "watch-dock", id: "ex-watch" }),
    f.isNew ? null : h("p", { class: "muted kbd-hint", text: "Space plays or pauses. Left and right arrows go to the previous or next move, when no field is selected." }));

  const checklist = h("section", { class: "card checklist" },
    h("h3", { text: "Checklist" }),
    h("ul", { id: "ex-checklist", class: "checklist-list" }),
    h("label", { class: "opt checked-opt" }, checkedBox,
      h("span", { class: "opt-text" }, h("span", { class: "opt-name", text: "I have checked this move" }),
        h("span", { class: "opt-hint", text: "Counts it as done in the progress above. Your ticks are kept in this browser only." }))));

  const main = h("div", { class: "review-main" },
    checklist,
    h("section", { class: "card" },
      h("h3", { text: "Names" }),
      textField("name_en", "Name (English)"),
      textField("name_ar", "Name (Egyptian Arabic)", { rtl: true })),
    h("section", { class: "card" },
      h("h3", { text: "The movement" }),
      selectField("kind", "Type", v.kinds, "kind"),
      selectField("pattern", "Movement pattern", v.patterns, "pattern"),
      checkGroup("primaryMuscles", "Main muscles", "The muscles this move works hardest.", v.muscles),
      checkGroup("secondaryMuscles", "Helping muscles", "Muscles that assist. A main muscle can not also be a helper.", v.muscles),
      checkGroup("equipment", "Equipment", "Pick \"none\" on its own, or the real equipment.", v.equipment)),
    h("section", { class: "card" },
      h("h3", { text: "Safety tags" }),
      checkGroup("contraindicationTags", "Tick every tag that fits this move", "Members whose plan avoids a tag will not be shown the move. Pick \"none\" only when nothing needs avoiding.", v.contraindicationTags, "tags")),
    h("section", { class: "card", id: "ex-video-box" },
      h("h3", { text: "Videos" }),
      h("ul", { class: "clip-list", id: "ex-clips" }),
      h("p", { class: "muted", text: "Choose which view the video shows, then pick an mp4 under 10 MB. It plays in the panel at once, and the picture is taken from it. Choosing a view that already has a video replaces it." }),
      h("div", { class: "upload-row" }, h("label", { class: "inline-label", for: "ex-angle", text: "View" }), angle),
      h("label", { class: "inline-label", for: "ex-file", text: "Video file (mp4)" }), file,
      h("progress", { id: "ex-progress", max: "1", value: "0", hidden: true, "aria-label": "Upload progress" }),
      h("p", { class: "upload-status", id: "ex-upload-status", role: "status" }),
      h("p", { class: "field-error", id: "err-clips", hidden: true })),
    h("details", { class: "card more" },
      h("summary", { text: "More details" }),
      idField,
      selectField("bodyRegion", "Body region", v.bodyRegions),
      selectField("place", "Where", v.places),
      selectField("level", "Level", v.levels),
      h("label", { class: "opt" }, Object.assign(h("input", { type: "checkbox", onchange: (ev) => { f.quiet = ev.target.checked; syncReview(); } }), { checked: f.quiet }), h("span", { class: "opt-text" }, h("span", { class: "opt-name", text: "Quiet" }))),
      h("label", { class: "opt" }, Object.assign(h("input", { type: "checkbox", onchange: (ev) => { f.floorOnly = ev.target.checked; syncReview(); } }), { checked: f.floorOnly }), h("span", { class: "opt-text" }, h("span", { class: "opt-name", text: "Floor only" })))));

  const saveBar = h("div", { class: "savebar" },
    h("span", { class: "save-status", id: "ex-status", "aria-live": "polite" }),
    f.isNew ? null : h("button", { class: "btn", id: "ex-save", type: "button", onclick: () => saveReview() }, "Save"),
    h("button", { class: "btn primary", id: "ex-save-next", type: "button", onclick: onSaveAndNext }, "Save and next"));

  $("ex-form").replaceChildren(h("div", { class: "review", id: "ex-review" },
    bar,
    h("div", { class: "review-head" },
      h("h2", { id: "ex-title" }),
      h("span", { class: "badge known", id: "ex-state-badge" })),
    h("div", { class: "review-grid" }, watchSide, main),
    h("div", { class: "problems", id: "ex-problems", role: "alert", hidden: true }),
    saveBar));
  renderClipList();
  syncGroups();
  refreshWatch();
  syncReview();
}

/* saving */

function setSaving(on) {
  ex.saving = on;
  for (const id of ["ex-save", "ex-save-next"]) {
    const b = $(id);
    if (b) b.disabled = on;
  }
}

// Returns true when the exercise is saved (or needed no save).
async function saveReview() {
  const f = ex.form;
  if (!f || ex.saving) return false;
  if (ex.local.some((l) => l.uploading)) {
    videoStatus("Wait for the video to finish uploading, then save.", true);
    notice("A video is still uploading. Wait for it to finish, then save.");
    return false;
  }
  ex.showErrors = true;
  const problems = problemsNow();
  syncReview();
  if (problems.length) {
    focusField(problems[0].field);
    return false;
  }
  setSaving(true);
  try {
    const changed = dataSignature(f) !== ex.dataSig || f.isNew;
    let version = null;
    if (changed) {
      const out = await call("save_exercise", L.savePayload(f));
      if (!out.ok) {
        problemList($("ex-problems"), (out.problems ?? []).map(L.plainProblem));
        notice("The server did not accept this exercise. The reasons are above the Save button.");
        return false;
      }
      version = out.version;
      const prev = ex.rows.find((r) => r.id === f.exerciseId);
      ex.rows = [...ex.rows.filter((r) => r.id !== f.exerciseId), L.rowFromForm(f, prev)];
    }
    setChecked(f.exerciseId, f.checked);
    if (f.isNew) {
      f.isNew = false;
      ex.queue = [f.exerciseId];
      if (ex.idInput) ex.idInput.readOnly = true;
    }
    ex.sig = L.formSignature(f);
    ex.dataSig = dataSignature(f);
    ex.showErrors = false;
    problemList($("ex-problems"), []);
    for (const entry of Object.values(ex.fields)) { entry.err.hidden = true; entry.box.classList.remove("invalid"); }
    $("err-clips").hidden = true;
    notice(changed ? `Saved. It is live for members (library version ${version}).` : "Marked as checked. Nothing changed, so nothing was published.", true);
    syncReview();
    renderOverview();
    if (changed) loadExercises({ quiet: true });
    return true;
  } catch (e) {
    notice(friendly(e));
    return false;
  } finally {
    setSaving(false);
  }
}

async function onSaveAndNext() {
  const f = ex.form;
  if (!f) return;
  const id = f.exerciseId;
  if (!(await saveReview())) return;
  const target = nextTarget() ?? (ex.queue.length > 1 ? L.neighbour(ex.queue, id, 1) : null);
  if (target) {
    await openReview(target, ex.queue);
  } else {
    await closeReview();
    notice(ex.queue.length > 1 ? "That was the last one in this list." : "Saved.", true);
  }
}

/* choosing and uploading a video */

const hex4 = () => [...crypto.getRandomValues(new Uint8Array(4))].map((b) => b.toString(16).padStart(2, "0")).join("");

function frameOf(video) {
  return new Promise((resolve, reject) => {
    video.onloadedmetadata = () => { video.currentTime = Math.min(1, video.duration / 2); };
    video.onseeked = () => {
      const w = Math.min(640, video.videoWidth), hgt = Math.round((video.videoHeight * w) / video.videoWidth);
      const canvas = document.createElement("canvas");
      canvas.width = w; canvas.height = hgt;
      canvas.getContext("2d").drawImage(video, 0, 0, w, hgt);
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("poster"))), "image/webp", 0.8);
    };
    video.onerror = () => reject(new Error("video"));
  });
}

function putFile(path, blob, contentType, onProgress) {
  return new Promise((resolve, reject) => {
    const task = uploadBytesResumable(storageRef(storage, path), blob, { contentType, cacheControl: "public, max-age=31536000" });
    task.on("state_changed", (s) => onProgress?.(s.totalBytes ? s.bytesTransferred / s.totalBytes : 0), reject, () => resolve());
  });
}

async function onClipChosen(ev) {
  const input = ev.target;
  const file = input.files[0];
  const f = ex.form;
  if (!file) return;
  const stop = (text) => { videoStatus(text, true); input.value = ""; };
  if (!/^[a-z0-9_]{1,64}$/.test(f.exerciseId)) { stop("Type the English name first, so the video can be filed under it."); return; }
  if (file.type !== "video/mp4") { stop("The video must be an mp4 file."); return; }
  if (file.size > 10 * 1024 * 1024) { stop(`That video is ${(file.size / 1048576).toFixed(1)} MB. The limit is 10 MB.`); return; }
  const angle = $("ex-angle").value;
  const url = URL.createObjectURL(file);
  const localClip = { form: f, angle, url, file: null, seconds: null, uploading: true };
  ex.local.push(localClip);
  refreshWatch();
  syncReview();
  const forget = () => {
    ex.local = ex.local.filter((l) => l !== localClip);
    URL.revokeObjectURL(url);
  };
  const bar = $("ex-progress");
  const show = (fraction) => {
    if (!bar) return;
    bar.hidden = false;
    bar.value = fraction;
    videoStatus(`Uploading ${Math.round(fraction * 100)}%`);
  };
  try {
    videoStatus("Reading the video...");
    const video = document.createElement("video");
    video.muted = true; video.preload = "auto"; video.src = url;
    const posterBlob = await frameOf(video);
    const seconds = Math.round(video.duration * 100) / 100;
    const clipName = `${f.exerciseId}_${angle}_${hex4()}.mp4`;
    const posterName = `${f.exerciseId}_${hex4()}.webp`;
    const base = `content/exercises/${f.exerciseId}/`;
    show(0);
    await putFile(base + clipName, file, "video/mp4", (p) => show(p * 0.95));
    await putFile(base + posterName, posterBlob, "image/webp", () => {});
    if (ex.form !== f) { forget(); return; }
    f.clips = [...f.clips.filter((c) => c.angle !== angle), { file: clipName, angle, seconds }].slice(0, 2);
    if (f.clips.length === 1 || angle === f.clips[0].angle) f.poster = { file: posterName };
    if (!f.poster.file) f.poster = { file: posterName };
    readAsDataUrl(posterBlob).then((data) => exMedia.posters.set(base + posterName, data)).catch(() => {});
    for (const old of ex.local.filter((l) => l !== localClip && l.form === f && l.angle === angle)) {
      ex.local = ex.local.filter((l) => l !== old);
      URL.revokeObjectURL(old.url);
    }
    localClip.file = clipName; localClip.seconds = seconds; localClip.uploading = false;
    renderClipList();
    refreshWatch();
    syncReview();
    videoStatus("Video uploaded. Press Save to publish it.");
  } catch (e) {
    forget();
    refreshWatch();
    syncReview();
    const why = e?.code ? L.storageErrorText(e, navigator.onLine !== false).text : "The file could not be read as a video.";
    videoStatus(`The upload failed. ${why}`, true);
  } finally {
    if (bar) bar.hidden = true;
    input.value = "";
  }
}

/* keyboard: space plays, arrows move between exercises */

const TYPING = new Set(["INPUT", "SELECT", "TEXTAREA", "BUTTON", "SUMMARY", "A"]);

function onReviewKey(ev) {
  if (!ex.form || state.tab !== "exercises" || ev.defaultPrevented || ev.altKey || ev.ctrlKey || ev.metaKey || ev.shiftKey) return;
  if ($("dialog").open) return;
  const t = ev.target;
  if (t.closest?.('[role="tablist"]') || t.isContentEditable) return;
  const arrow = ev.key === "ArrowRight" || ev.key === "ArrowLeft";
  const tickable = t.tagName === "BUTTON" || (t.tagName === "INPUT" && t.type === "checkbox");
  const usesArrows = ["SELECT", "TEXTAREA", "SUMMARY"].includes(t.tagName) || (t.tagName === "INPUT" && !tickable);
  if (arrow ? usesArrows : TYPING.has(t.tagName)) return;
  if (ev.key === " ") { ev.preventDefault(); ex.watch?.toggle(); }
  else if (ev.key === "ArrowRight") { ev.preventDefault(); stepReview(1); }
  else if (ev.key === "ArrowLeft") { ev.preventDefault(); stepReview(-1); }
}

/* events */

/* form pieces shared by the event and food forms */

function field(label, control) {
  return h("label", { class: "field" }, h("span", { class: "flabel", text: label }), control);
}

function textInput(key, type = "text", form) {
  return h("input", { type, value: form[key] ?? "", oninput: (ev) => { form[key] = ev.target.value; } });
}

function selectInput(key, options, form, label = LABEL) {
  const el = h("select", { onchange: (ev) => { form[key] = ev.target.value; } },
    options.map((o) => h("option", { value: o, text: label(o) })));
  el.value = form[key];
  return el;
}

const evs = { rows: [], loaded: false, loadFailed: false, filter: "all", query: "", form: null, sig: "", previews: new Map() };
const EVENT_STATUS_LABEL = { draft: "Draft", published: "Published", cancelled: "Cancelled" };
const EVENT_MODE_LABEL = { place: "In person", online: "Online" };

async function loadEvents({ quiet = false } = {}) {
  if (!evs.loaded && !quiet) { evs.loadFailed = false; renderEvents(); }
  try {
    const data = await call("list_events_admin", {});
    evs.rows = data.events ?? [];
    evs.loaded = true;
    evs.loadFailed = false;
    if (!quiet) notice("");
  } catch (e) {
    if (!quiet) notice(friendly(e));
    if (!evs.loaded) evs.loadFailed = true;
  }
  if (!quiet || state.tab === "events") renderEvents();
  setBadge("events", L.upcomingEvents(evs.rows), "coming up");
}

const EVENT_EMPTY = {
  all: ["No events yet.", "Press Add event to create one. It stays a draft until you set it to Published."],
  draft: ["No drafts.", "Events you have not published yet wait here."],
  published: ["Nothing is published.", "Published events show to verified women, who can reserve a seat."],
  cancelled: ["No cancelled events.", "An event you set to Cancelled moves here."],
};

function renderEvents() {
  const counts = L.countBy(evs.rows, (r) => r.status);
  const byKey = { all: evs.rows.length, draft: counts.draft ?? 0, published: counts.published ?? 0, cancelled: counts.cancelled ?? 0 };
  for (const chip of $("ev-filters").querySelectorAll(".chip")) {
    chip.setAttribute("aria-pressed", String(chip.dataset.filter === evs.filter));
    chip.querySelector(".count").textContent = evs.loaded ? String(byKey[chip.dataset.filter]) : "";
  }
  const list = $("ev-list");
  if (!evs.loaded) {
    list.replaceChildren(...(evs.loadFailed ? [] : skeletons(3)));
    setBusy(list, !evs.loadFailed);
    if (evs.loadFailed) setEmpty($("ev-empty"), { title: "The events could not be loaded.", hint: "Check your internet connection and try again.", art: "plug", action: { label: "Try again", onclick: () => loadEvents() } });
    else $("ev-empty").hidden = true;
    return;
  }
  setBusy(list, false);
  const rows = L.filterEvents(evs.rows, { status: evs.filter, query: evs.query });
  list.replaceChildren(...rows.map((r, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: r.titleEn || r.titleAr || "Untitled event" }),
        h("div", { class: "meta" }, h("span", { class: `badge${r.status === "published" ? " sage" : r.status === "cancelled" ? " known" : ""}`, text: EVENT_STATUS_LABEL[r.status] ?? r.status })),
        h("div", { class: "muted", text: `${r.startsAt ? whenText(r.startsAt) : "No date"} · ${EVENT_MODE_LABEL[r.mode] ?? ""}` }),
        h("div", { class: "muted", text: L.seatsText(r) })),
      h("button", { class: "btn", type: "button", "aria-label": `Edit ${r.titleEn || r.titleAr || "event"}`, onclick: () => openEventForm(r) }, "Edit")))));
  if (rows.length) $("ev-empty").hidden = true;
  else if (evs.query.trim()) setEmpty($("ev-empty"), { title: `No event matches "${evs.query.trim()}".`, hint: "Try part of the title or the venue.", art: "query", action: { label: "Clear search", onclick: () => { evs.query = ""; $("ev-search").value = ""; renderEvents(); } } });
  else setEmpty($("ev-empty"), { title: EVENT_EMPTY[evs.filter][0], hint: EVENT_EMPTY[evs.filter][1], art: "hub" });
}

function dropPreviews() {
  for (const url of evs.previews.values()) if (url.startsWith("blob:")) URL.revokeObjectURL(url);
  evs.previews = new Map();
}

async function openEventForm(row) {
  if (evs.form && JSON.stringify(evs.form) !== evs.sig && !(await confirmDiscard("event"))) return;
  dropPreviews();
  evs.form = row ? L.eventToForm(row) : L.blankEvent(L.newEventId(hex4() + hex4()));
  evs.sig = JSON.stringify(evs.form);
  renderEventForm();
  $("ev-form").scrollIntoView({ behavior: calmScroll(), block: "start" });
  if (row) loadStoredPictures(evs.form);
}

async function confirmDiscard(what) {
  const choice = await askDialog({
    title: "Throw away your changes?",
    body: `You have changes to this ${what} that are not saved.`,
    actions: [{ id: "keep", label: "Keep editing", safe: true }, { id: "discard", label: "Discard changes", kind: "danger" }],
  });
  return choice === "discard";
}

function areaInput(key, form, max) {
  return h("textarea", { rows: 3, maxlength: max, oninput: (ev) => { form[key] = ev.target.value; } }, form[key] ?? "");
}

function mediaItem(f, kind, name) {
  const url = evs.previews.get(name);
  const preview = kind === "image"
    ? (url ? h("img", { class: "thumb", src: url, alt: "" }) : h("span", { class: "thumb empty", "aria-hidden": "true" }))
    : (url ? h("video", { class: "thumb", src: url, controls: true, muted: true, preload: "metadata" })
           : h("button", { class: "btn", type: "button", onclick: () => loadStoredVideo(f, name) }, "Load preview"));
  const key = kind === "image" ? "imageFiles" : "videoFiles";
  return h("li", { class: "media" }, preview,
    h("span", { class: "muted name", text: name }),
    h("button", { class: "btn", type: "button", "aria-label": `Remove ${name}`, onclick: () => {
      f[key] = f[key].filter((n) => n !== name);
      evs.previews.delete(name);
      renderEventForm();
    } }, "Remove"));
}

function renderEventForm(focusMode = false) {
  const f = evs.form;
  if (!f) { $("ev-form").replaceChildren(); return; }
  const place = f.mode === "place";
  const seatsInput = textInput("capacity", "number", f);
  seatsInput.min = String(Math.max(1, f.seatsTaken || 1));
  seatsInput.max = String(L.EVENT_LIMITS.seats);
  seatsInput.step = "1";
  const modeSelect = selectInput("mode", L.EVENT_MODES, f, (o) => EVENT_MODE_LABEL[o]);
  modeSelect.addEventListener("change", () => renderEventForm(true));
  $("ev-form").replaceChildren(h("div", { class: "card" },
    h("h2", { text: f.isNew ? "Add event" : `Edit ${f.titleEn || "event"}` }),
    field("Title (English)", textInput("titleEn", "text", f)),
    field("Title (Egyptian Arabic)", textInput("titleAr", "text", f)),
    field("Description (English)", areaInput("descriptionEn", f, L.EVENT_LIMITS.description)),
    field("Description (Egyptian Arabic)", areaInput("descriptionAr", f, L.EVENT_LIMITS.description)),
    field("Starts (Cairo time)", textInput("startsLocal", "datetime-local", f)),
    field("Ends (Cairo time)", textInput("endsLocal", "datetime-local", f)),
    field("Where", modeSelect),
    place ? [
      field("Venue name", textInput("placeName", "text", f)),
      field("Address", textInput("locationAddress", "text", f)),
      field("Google Maps link", textInput("locationUrl", "url", f)),
    ] : field("Event link (https)", textInput("link", "url", f)),
    field(f.seatsTaken ? `Seats (${f.seatsTaken} already booked)` : "Seats", seatsInput),
    field("Status", selectInput("status", L.EVENT_STATUSES, f, (o) => EVENT_STATUS_LABEL[o])),
    h("p", { class: "muted", text: "Draft is only visible to you. Published shows to verified women. Cancelled hides it and keeps the seats record." }),
    h("h3", { text: "Pictures" }),
    h("p", { class: "muted", text: `Up to ${L.EVENT_LIMITS.images}. Each is shrunk to a webp under 1 MB. The first one is the cover.` }),
    h("ul", { class: "media-list" }, f.imageFiles.map((n) => mediaItem(f, "image", n))),
    h("input", { type: "file", accept: "image/*", multiple: true, id: "ev-images", "aria-label": "Add pictures", onchange: onEventImages }),
    h("h3", { text: "Videos" }),
    h("p", { class: "muted", text: `Up to ${L.EVENT_LIMITS.videos} mp4 files, each under 10 MB.` }),
    h("ul", { class: "media-list" }, f.videoFiles.map((n) => mediaItem(f, "video", n))),
    h("input", { type: "file", accept: "video/mp4", multiple: true, id: "ev-videos", "aria-label": "Add videos", onchange: onEventVideos }),
    h("div", { class: "problems", id: "ev-problems", role: "alert", hidden: true }),
    h("div", { class: "actions" },
      h("button", { class: "btn primary", id: "ev-save", type: "button", onclick: saveEvent }, f.status === "published" ? "Save, live now" : "Save"),
      h("button", { class: "btn", type: "button", onclick: async () => {
        if (JSON.stringify(evs.form) !== evs.sig && !(await confirmDiscard("event"))) return;
        dropPreviews(); evs.form = null; renderEventForm();
      } }, "Cancel"))));
  if (focusMode) modeSelect.focus();
}

async function loadStoredPictures(f) {
  for (const name of f.imageFiles) {
    try {
      const bytes = await getBytes(storageRef(storage, `content/events/${f.eventId}/${name}`), L.EVENT_LIMITS.imageBytes);
      evs.previews.set(name, await readAsDataUrl(new Blob([bytes], { type: name.endsWith(".webp") ? "image/webp" : "image/jpeg" })));
    } catch (e) {
      continue;
    }
    if (evs.form !== f) return;
    renderEventForm();
  }
}

async function loadStoredVideo(f, name) {
  try {
    notice("Loading the video...");
    const bytes = await getBytes(storageRef(storage, `content/events/${f.eventId}/${name}`), L.EVENT_LIMITS.videoBytes);
    evs.previews.set(name, URL.createObjectURL(new Blob([bytes], { type: "video/mp4" })));
    notice("");
    if (evs.form === f) renderEventForm();
  } catch (e) {
    notice("The video could not be loaded.");
  }
}

async function shrinkImage(file) {
  const bitmap = await createImageBitmap(file);
  try {
    for (const step of L.shrinkSteps(bitmap.width, bitmap.height)) {
      const canvas = document.createElement("canvas");
      canvas.width = step.width; canvas.height = step.height;
      canvas.getContext("2d").drawImage(bitmap, 0, 0, step.width, step.height);
      const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/webp", step.quality));
      if (blob && blob.type === "image/webp" && L.fileFits(blob.size, "image")) return blob;
    }
  } finally {
    bitmap.close();
  }
  return null;
}

async function onEventImages(ev) {
  const f = evs.form;
  const files = [...ev.target.files];
  ev.target.value = "";
  if (!files.length) return;
  if (!L.canAddFiles(f.imageFiles.length, files.length, "image")) { notice(`An event holds at most ${L.EVENT_LIMITS.images} pictures.`); return; }
  const base = `content/events/${f.eventId}/`;
  let added = 0;
  try {
    for (const file of files) {
      notice(`Preparing picture ${added + 1} of ${files.length}...`);
      const blob = await shrinkImage(file);
      if (!blob) { notice(`${file.name} is too large even after shrinking. Pick a smaller picture.`); break; }
      const name = L.eventFileName(f.eventId, hex4(), "webp");
      await putFile(base + name, blob, "image/webp");
      f.imageFiles = [...f.imageFiles, name];
      evs.previews.set(name, await readAsDataUrl(blob));
      added += 1;
    }
    if (added) notice(`${added} picture${added === 1 ? "" : "s"} uploaded. Press Save to publish the changes.`, true);
  } catch (e) {
    notice(`The upload failed. ${e?.code ? L.storageErrorText(e, navigator.onLine !== false).text : "Check your connection and try again."}`);
  }
  renderEventForm();
}

async function onEventVideos(ev) {
  const f = evs.form;
  const files = [...ev.target.files];
  ev.target.value = "";
  if (!files.length) return;
  if (!L.canAddFiles(f.videoFiles.length, files.length, "video")) { notice(`An event holds at most ${L.EVENT_LIMITS.videos} videos.`); return; }
  if (files.some((file) => file.type !== "video/mp4" || !L.fileFits(file.size, "video"))) {
    notice("Each video must be an mp4 under 10 MB.");
    return;
  }
  const base = `content/events/${f.eventId}/`;
  try {
    for (const file of files) {
      notice("Uploading the video...");
      const name = L.eventFileName(f.eventId, hex4(), "mp4");
      await putFile(base + name, file, "video/mp4", (p) => notice(`Uploading the video... ${Math.round(p * 100)}%`));
      f.videoFiles = [...f.videoFiles, name];
      evs.previews.set(name, URL.createObjectURL(file));
    }
    notice("Video uploaded. Press Save to publish the changes.", true);
  } catch (e) {
    notice(`The upload failed. ${e?.code ? L.storageErrorText(e, navigator.onLine !== false).text : "Check your connection and try again."}`);
  }
  renderEventForm();
}

async function saveEvent() {
  const f = evs.form;
  const problems = L.eventProblems(f);
  problemList($("ev-problems"), problems);
  if (problems.length) { notice(`${problems.length} thing${problems.length === 1 ? "" : "s"} to fix before saving. They are listed above the Save button.`); $("ev-problems").scrollIntoView({ behavior: calmScroll(), block: "center" }); return; }
  $("ev-save").disabled = true;
  try {
    const out = await call("save_event", L.eventPayload(f));
    if (!out.ok) { problemList($("ev-problems"), (out.problems ?? []).map(L.plainProblem)); notice("The server did not accept this event. The reasons are above the Save button."); return; }
    notice(f.status === "published" ? "Saved. Verified women can see it now." : "Saved.", true);
    dropPreviews();
    evs.form = null;
    renderEventForm();
    await loadEvents();
  } catch (e) {
    notice(friendly(e));
  } finally {
    const btn = $("ev-save");
    if (btn) btn.disabled = false;
  }
}

/* community foods */

const fd = { candidates: [], published: [], loaded: false, loadFailed: false, filter: "waiting", query: "", vocab: { categories: [], allergens: [] }, form: null, rejectArmed: null };

async function loadFoods({ quiet = false } = {}) {
  if (!fd.loaded && !quiet) { fd.loadFailed = false; renderFoods(); }
  try {
    const data = await call("list_community_foods", {});
    fd.candidates = data.candidates ?? [];
    fd.published = data.published ?? [];
    fd.vocab = data.vocab ?? fd.vocab;
    fd.loaded = true;
    fd.loadFailed = false;
    if (!quiet) notice("");
  } catch (e) {
    if (!quiet) notice(friendly(e));
    if (!fd.loaded) fd.loadFailed = true;
  }
  if (!quiet || state.tab === "foods") renderFoods();
  setBadge("foods", fd.candidates.length, "waiting");
}

function renderFoods() {
  const counts = { waiting: fd.candidates.length, published: fd.published.length };
  for (const chip of $("fd-filters").querySelectorAll(".chip")) {
    chip.setAttribute("aria-pressed", String(chip.dataset.filter === fd.filter));
    chip.querySelector(".count").textContent = fd.loaded ? String(counts[chip.dataset.filter]) : "";
  }
  const list = $("fd-list");
  if (!fd.loaded) {
    list.replaceChildren(...(fd.loadFailed ? [] : skeletons(3)));
    setBusy(list, !fd.loadFailed);
    if (fd.loadFailed) setEmpty($("fd-empty"), { title: "The foods could not be loaded.", hint: "Check your internet connection and try again.", art: "plug", action: { label: "Try again", onclick: () => loadFoods() } });
    else $("fd-empty").hidden = true;
    return;
  }
  setBusy(list, false);
  const waiting = fd.filter === "waiting";
  const rows = L.filterFoods(waiting ? fd.candidates : fd.published, fd.query);
  list.replaceChildren(...(waiting ? rows.map((c, i) => foodCandidate(c, i)) : rows.map((f, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: `${f.nameEn} · ${f.nameAr}` }),
        h("div", { class: "meta" }, h("span", { class: "badge sage", text: "Published" })),
        h("div", { class: "muted", text: `${LABEL(f.category)} · ${L.macrosText(f)}` }),
        h("div", { class: "muted", text: f.allergens.length ? `Allergens: ${f.allergens.map(L.allergenLabel).join(", ")}` : "No allergens" })))))));
  if (rows.length) $("fd-empty").hidden = true;
  else if (fd.query.trim()) setEmpty($("fd-empty"), { title: `No food matches "${fd.query.trim()}".`, hint: "Try part of the name or an ingredient.", art: "query", action: { label: "Clear search", onclick: () => { fd.query = ""; $("fd-search").value = ""; renderFoods(); } } });
  else if (waiting) setEmpty($("fd-empty"), { title: "No foods are waiting.", hint: "When women confirm a meal and offer it to everyone, it appears here for you to approve with names, a category and allergens.", art: "basket" });
  else setEmpty($("fd-empty"), { title: "Nothing is published yet.", hint: "Foods you approve appear here, and every member's phone picks them up within a day.", art: "basket" });
}

function foodCandidate(c, i) {
  const title = c.nameEn || c.nameAr || "this food";
  const armed = fd.rejectArmed === c.key;
  return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: c.nameEn || c.nameAr || "Unnamed food" }),
        h("div", { class: "meta" }, h("span", { class: "badge", text: L.confirmText(c.confirmCount) })),
        h("div", { class: "muted", text: L.itemsText(c.items) }),
        h("div", { class: "muted", text: L.macrosText(c) }))),
    h("div", { class: "actions" },
      h("button", { class: "btn primary", type: "button", "aria-label": `Approve ${title}`, onclick: () => openFoodForm(c) }, "Approve"),
      armed ? null : h("button", { class: "btn quiet-danger", type: "button", "aria-label": `Reject ${title}`, onclick: () => rejectFood(c) }, "Reject")),
    armed ? h("div", { class: "confirm-strip", role: "group", "aria-label": `Reject ${title}` },
      h("p", { class: "muted", text: `Reject "${title}" for good? It will not be offered again, and this can not be undone here.` }),
      h("button", { class: "btn danger", type: "button", "data-reject-armed": "", onclick: () => rejectFood(c) }, `Reject ${title}`),
      h("button", { class: "btn", type: "button", onclick: () => { fd.rejectArmed = null; renderFoods(); } }, "Keep it waiting")) : null);
}

function openFoodForm(candidate) {
  fd.form = L.foodToForm(candidate);
  renderFoodForm(candidate);
  $("fd-form").scrollIntoView({ behavior: calmScroll(), block: "start" });
}

function renderFoodForm(candidate) {
  const f = fd.form;
  if (!f) { $("fd-form").replaceChildren(); return; }
  const category = h("select", { onchange: (ev) => { f.category = ev.target.value; } },
    h("option", { value: "", text: "Pick a category" }),
    fd.vocab.categories.map((o) => h("option", { value: o, text: LABEL(o) })));
  category.value = f.category;
  const boxes = fd.vocab.allergens.map((token) => h("label", { class: "check" },
    h("input", { type: "checkbox", checked: f.allergens.includes(token), onchange: (ev) => { fd.form = L.toggleAllergen(fd.form, token, ev.target.checked); renderFoodForm(candidate); } }),
    h("span", { text: L.allergenLabel(token) })));
  $("fd-form").replaceChildren(h("div", { class: "card" },
    h("h2", { text: `Approve ${candidate.nameEn || candidate.nameAr || "food"}` }),
    h("p", { class: "muted", text: `${L.itemsText(candidate.items)}. ${L.macrosText(candidate)}.` }),
    field("Name (English)", textInput("nameEn", "text", f)),
    field("Name (Egyptian Arabic)", textInput("nameAr", "text", f)),
    field("Category", category),
    h("h3", { text: "Allergens" }),
    h("p", { class: "muted", text: "Tick every allergen this meal can contain, or confirm it has none." }),
    h("div", { class: "allergens" }, boxes),
    h("label", { class: "check" },
      h("input", { type: "checkbox", checked: f.allergensNone, onchange: (ev) => { fd.form = L.setNoAllergens(fd.form, ev.target.checked); renderFoodForm(candidate); } }),
      h("span", { text: "I checked: none of these allergens" })),
    h("div", { class: "problems", id: "fd-problems", role: "alert", hidden: true }),
    h("div", { class: "actions" },
      h("button", { class: "btn primary", id: "fd-save", type: "button", onclick: approveFood }, "Approve and publish"),
      h("button", { class: "btn", type: "button", onclick: () => { fd.form = null; renderFoodForm(); } }, "Cancel"))));
}

async function approveFood() {
  const problems = L.foodProblems(fd.form, fd.vocab);
  problemList($("fd-problems"), problems);
  if (problems.length) { notice(`${problems.length} thing${problems.length === 1 ? "" : "s"} to fix before publishing. They are listed above the button.`); return; }
  $("fd-save").disabled = true;
  try {
    const out = await call("review_community_food", L.foodPayload(fd.form, "approve"));
    if (!out.ok) { problemList($("fd-problems"), (out.problems ?? []).map(L.plainProblem)); return; }
    notice("Published. Phones pick it up within a day.", true);
    fd.form = null;
    renderFoodForm();
    await loadFoods();
  } catch (e) {
    notice(friendly(e));
  } finally {
    const btn = $("fd-save");
    if (btn) btn.disabled = false;
  }
}

async function rejectFood(candidate) {
  const step = L.rejectStep(fd.rejectArmed, candidate.key);
  fd.rejectArmed = step.armed;
  if (!step.send) {
    renderFoods();
    document.querySelector("[data-reject-armed]")?.focus();
    return;
  }
  try {
    const out = await call("review_community_food", L.foodPayload(L.foodToForm(candidate), "reject"));
    if (!out.ok) { notice((out.problems ?? []).map(L.plainProblem).join(" ")); return; }
    notice("Rejected. It will not show again.", true);
    if (fd.form?.key === candidate.key) { fd.form = null; renderFoodForm(); }
    await loadFoods();
  } catch (e) {
    notice(friendly(e));
  }
}

/* tabs and wiring */

const TABS = ["queue", "calendar", "phones", "exercises", "events", "foods", "coaches", "payments", "refunds", "payouts", "reports", "settings"];

// The coaching tabs a signed-in account may use; the server refuses the rest anyway.
const allowedTabs = () => TABS.filter((t) => !L.COACHING_TABS.includes(t) || L.coachingTabsFor(claims).includes(t));

function applyClaims() {
  const allowed = new Set(allowedTabs());
  for (const t of L.COACHING_TABS) $(`tab-${t}`).hidden = !allowed.has(t);
  tabHints();
}

// The strip scrolls sideways on narrow screens: a chevron and a fade show on each side that has more tabs.
function tabHints() {
  const strip = $("tabs"), prev = $("tabs-prev"), next = $("tabs-next");
  const left = !strip.hidden && strip.scrollLeft > 1;
  const right = !strip.hidden && strip.scrollLeft < strip.scrollWidth - strip.clientWidth - 1;
  const had = document.activeElement;
  prev.hidden = !left;
  next.hidden = !right;
  // A chevron that hides under the keyboard hands focus on instead of dropping it.
  if ((had === prev && !left) || (had === next && !right)) {
    (left ? prev : right ? next : strip.querySelector('[aria-selected="true"]'))?.focus({ preventScroll: true });
  }
  strip.classList.toggle("more-left", left);
  strip.classList.toggle("more-right", right);
}

// Brings the first tab hidden under the fade to the middle, which is where the strip snaps.
function scrollTabs(dir) {
  const strip = $("tabs");
  const box = strip.getBoundingClientRect();
  const tabs = [...strip.querySelectorAll('[role="tab"]:not([hidden])')];
  const target = dir > 0
    ? tabs.find((t) => t.getBoundingClientRect().right > box.right - 56)
    : tabs.findLast((t) => t.getBoundingClientRect().left < box.left + 56);
  target?.scrollIntoView({ inline: "center", block: "nearest", behavior: calmScroll() });
}

function ensureCoaching() {
  coaching ??= mountCoaching({
    h, $, call, notice, askDialog, setEmpty, skeletons, setBadge,
    getState: () => ({ tab: state.tab, claims, personalStorage }),
  });
  return coaching;
}

function openTab(name) {
  const tab = $(`tab-${name}`);
  tab.scrollIntoView({ inline: "center", block: "nearest", behavior: calmScroll() });
}

// Counts for the tab badges, read quietly in the background after sign-in.
function primeBadges() {
  if (state.tab !== "queue") loadQueue({ quiet: true });
  if (state.tab !== "events") loadEvents({ quiet: true });
  if (state.tab !== "foods") loadFoods({ quiet: true });
  for (const t of L.coachingTabsFor(claims)) if (state.tab !== t) ensureCoaching().load(t, { quiet: true });
}

async function requestTab(name) {
  if (name === state.tab || !allowedTabs().includes(name)) return;
  if (state.tab === "exercises" && ex.form && !(await leaveReview())) return;
  showTab(name);
}

function showTab(name) {
  state.tab = name;
  for (const t of TABS) {
    const on = t === name;
    const btn = $(`tab-${t}`);
    btn.setAttribute("aria-selected", String(on));
    btn.tabIndex = on ? 0 : -1;
    $(`panel-${t}`).hidden = !on;
  }
  notice("");
  openTab(name);
  window.scrollTo({ top: 0, behavior: "auto" });
  if (name !== "exercises") {
    ex.form = null;
    renderReview();
    releaseExerciseMedia();
  }
  if (name === "queue") loadQueue();
  if (name === "calendar") { loadSettings().then(loadCalendar); }
  if (name === "phones") loadPhones();
  if (name === "exercises") loadExercises();
  if (name === "events") loadEvents();
  if (name === "foods") loadFoods();
  if (L.COACHING_TABS.includes(name)) ensureCoaching().load(name);
  else coaching?.release();
  if (name === "settings") { loadSettings(); if (L.isAdmin(claims)) ensureCoaching().loadSettings(); }
}

function wire() {
  $("tabs").addEventListener("scroll", tabHints, { passive: true });
  new ResizeObserver(tabHints).observe($("tabs"));
  document.fonts?.ready.then(tabHints);
  $("tabs-prev").addEventListener("click", () => scrollTabs(-1));
  $("tabs-next").addEventListener("click", () => scrollTabs(1));
  TABS.forEach((t) => {
    $(`tab-${t}`).addEventListener("click", () => requestTab(t));
    $(`tab-${t}`).addEventListener("keydown", (ev) => {
      const step = ev.key === "ArrowRight" ? 1 : ev.key === "ArrowLeft" ? -1 : ev.key === "Home" ? "first" : ev.key === "End" ? "last" : 0;
      if (!step) return;
      ev.preventDefault();
      const shown = allowedTabs();
      const at = shown.indexOf(t);
      const next = step === "first" ? shown[0] : step === "last" ? shown[shown.length - 1] : shown[(at + step + shown.length) % shown.length];
      requestTab(next).then(() => $(`tab-${next}`).focus());
    });
  });
  $("notice-close").addEventListener("click", () => notice(""));
  $("chips").addEventListener("click", (ev) => {
    const chip = ev.target.closest(".chip");
    if (!chip) return;
    state.status = chip.dataset.status;
    state.selected = new Set();
    renderQueue();
  });
  $("search").addEventListener("input", (ev) => { state.query = ev.target.value; renderQueue(); });
  $("select-all").addEventListener("change", () => { state.selected = L.toggleAll(state.selected, visibleRows()); renderQueue(); });
  $("approve-selected").addEventListener("click", onApproveSelected);
  $("toast-undo").addEventListener("click", onUndo);

  $("ex-search").addEventListener("input", (ev) => { ex.query = ev.target.value; renderExercises(); });
  $("ex-filters").addEventListener("click", (ev) => {
    const chip = ev.target.closest(".chip");
    if (!chip) return;
    ex.filter = chip.dataset.filter;
    renderOverview();
    renderExercises();
  });
  $("ex-new").addEventListener("click", openNewReview);
  $("ex-next").addEventListener("click", () => {
    const id = L.firstToReview(ex.rows, isChecked, ex.vocab);
    if (id) openReview(id, exTodoQueue());
  });
  document.addEventListener("keydown", onReviewKey);
  window.addEventListener("beforeunload", (ev) => { if (exDirty()) { ev.preventDefault(); ev.returnValue = ""; } });

  $("ev-new").addEventListener("click", () => openEventForm(null));
  $("ev-search").addEventListener("input", (ev) => { evs.query = ev.target.value; renderEvents(); });
  $("ev-filters").addEventListener("click", (ev) => {
    const chip = ev.target.closest(".chip");
    if (!chip) return;
    evs.filter = chip.dataset.filter;
    renderEvents();
  });
  $("fd-search").addEventListener("input", (ev) => { fd.query = ev.target.value; renderFoods(); });
  $("fd-filters").addEventListener("click", (ev) => {
    const chip = ev.target.closest(".chip");
    if (!chip) return;
    fd.filter = chip.dataset.filter;
    renderFoods();
  });

  for (const chip of document.querySelectorAll("[data-view]")) {
    chip.addEventListener("click", () => { state.calView = chip.dataset.view; loadCalendar(); });
  }
  const move = (n) => { state.calDay = L.addDays(state.calDay, state.calView === "week" ? 7 * n : n); loadCalendar(); };
  $("cal-prev").addEventListener("click", () => move(-1));
  $("cal-next").addEventListener("click", () => move(1));
  $("cal-today").addEventListener("click", () => { state.calDay = L.cairoDayKey(new Date().toISOString()); loadCalendar(); });
  $("avail-add").addEventListener("click", () => { state.settings.availability.push({ weekday: 1, start: "09:00", end: "12:00" }); renderAvailability(); });
  $("avail-save").addEventListener("click", () => saveSettings("Availability saved."));
  $("settings-save").addEventListener("click", () => saveSettings("Settings saved."));
  $("listed").addEventListener("change", () => saveSettings("Saved."));

  $("phones-input").addEventListener("input", (ev) => {
    const n = L.parsePhoneList(ev.target.value).length;
    $("phones-preview").textContent = n ? `${n} number${n === 1 ? "" : "s"} ready to add.` : "";
  });
  $("phones-add").addEventListener("click", addPhones);
}

// Shown until the first answer about the sign-in arrives.
function doneBooting() {
  $("booting").hidden = true;
  unmountArt($("booting-art"));
}

function boot() {
  wire();
  mountArt($("booting-art"), "relay", { play: true });
  if (PLACEHOLDER.test(JSON.stringify(firebaseConfig)) || PLACEHOLDER.test(recaptchaSiteKey)) {
    doneBooting();
    notice("Setup needed: fill in admin-web/config.js with the Firebase web app config and the reCAPTCHA Enterprise site key.");
    return;
  }
  if (["localhost", "127.0.0.1"].includes(location.hostname)) self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  const app = initializeApp(firebaseConfig);
  initializeAppCheck(app, { provider: new ReCaptchaEnterpriseProvider(recaptchaSiteKey), isTokenAutoRefreshEnabled: true });
  functions = getFunctions(app, functionsRegion);
  storage = getStorage(app, "gs://own-hub.firebasestorage.app");
  personalStorage = getStorage(app, "gs://own-hub-personal");
  const auth = getAuth(app);

  $("login-form").addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const submit = $("login-submit");
    submit.disabled = true;
    submit.textContent = "Signing in...";
    notice("");
    try {
      await signInWithEmailAndPassword(auth, $("email").value.trim(), $("password").value);
      $("password").value = "";
    } catch (e) {
      notice(friendly(e));
      $("password").focus();
    } finally {
      submit.disabled = false;
      submit.textContent = "Sign in";
    }
  });
  $("signout").addEventListener("click", async () => {
    if (ex.form && !(await leaveReview())) return;
    signOut(auth);
  });
  onAuthStateChanged(auth, async (user) => {
    doneBooting();
    if (user) unmountArt($("login-art"));
    else mountArt($("login-art"), "padlock", { play: true });
    $("login").hidden = !!user;
    $("app").hidden = !user;
    $("tabs").hidden = !user;
    $("signout").hidden = !user;
    if (user) {
      try { claims = (await user.getIdTokenResult()).claims ?? {}; } catch (e) { claims = {}; }
      applyClaims();
      showTab(allowedTabs().includes(state.tab) ? state.tab : "queue");
      primeBadges();
    } else {
      claims = {};
      coaching?.release();
      hideToast();
      $("email").focus?.();
    }
  });
}

boot();
