import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app-check.js";
import { getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";
import { getStorage, ref as storageRef, uploadBytes, getBytes } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-storage.js";
import { getFunctions, httpsCallable } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-functions.js";
import { firebaseConfig, recaptchaSiteKey, functionsRegion } from "./config.js";
import * as L from "./logic.js";

const $ = (id) => document.getElementById(id);
const PLACEHOLDER = /REPLACE_WITH/;
const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

const state = {
  rows: [],
  status: "pending",
  query: "",
  selected: new Set(),
  busy: new Set(),
  undo: null,
  tab: "queue",
  calView: "week",
  calDay: L.cairoDayKey(new Date().toISOString()),
  settings: { firstName: "", listed: false, autoPassKnown: false, availability: [], slotMinutes: 15 },
  phones: [],
  reschedule: null,
  declineArmed: null,
};

let functions = null;
let storage = null;
let undoTimer = null;

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

function notice(text, ok = false) {
  const el = $("notice");
  el.textContent = text || "";
  el.hidden = !text;
  el.classList.toggle("ok", ok);
}

const FRIENDLY = {
  "functions/unauthenticated": "Your account is not set up as a reviewer. Ask the owner.",
  "functions/permission-denied": "This account can not do that. Ask the owner.",
  "functions/failed-precondition": "That did not work yet. Refresh and try again.",
  "functions/not-found": "That request is gone. Refresh the list.",
  "auth/invalid-credential": "Wrong email or password.",
  "auth/invalid-login-credentials": "Wrong email or password.",
  "auth/too-many-requests": "Too many tries. Wait a minute and try again.",
  "auth/network-request-failed": "No connection. Check your internet.",
};

function friendly(error) {
  return FRIENDLY[error?.code] || "Something went wrong. Try again, or tell the owner.";
}

async function call(name, data = {}) {
  const result = await httpsCallable(functions, name)(data);
  return result.data;
}

function whenText(iso) {
  if (!iso) return "";
  return new Intl.DateTimeFormat([], { timeZone: L.TIMEZONE, weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(iso));
}

/* queue */

async function loadQueue() {
  try {
    const data = await call("list_review_queue", {});
    state.rows = L.normalizeRows(data);
    state.selected = L.pruneSelection(state.selected, state.rows);
    notice("");
  } catch (e) {
    notice(friendly(e));
  }
  renderQueue();
}

function visibleRows() {
  return L.filterRows(state.rows, { status: state.status, query: state.query });
}

function renderQueue() {
  const counts = L.statusCounts(state.rows);
  for (const chip of $("chips").querySelectorAll(".chip")) {
    const s = chip.dataset.status;
    chip.setAttribute("aria-pressed", String(s === state.status));
    chip.querySelector(".count").textContent = counts[s] ? String(counts[s]) : "";
  }
  const rows = visibleRows();
  const list = $("list");
  list.replaceChildren(...rows.map((row, i) => card(row, i)));
  $("empty").hidden = rows.length > 0;
  const selectable = L.selectableUids(rows);
  $("bulk").hidden = selectable.length === 0;
  $("select-all").checked = selectable.length > 0 && selectable.every((id) => state.selected.has(id));
  const n = [...state.selected].filter((id) => selectable.includes(id)).length;
  $("approve-selected").textContent = n ? `Approve selected (${n})` : "Approve selected";
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
    head.append(h("input", {
      type: "checkbox",
      "aria-label": `Select ${title}`,
      checked: state.selected.has(row.uid),
      onchange: () => { state.selected = L.toggleSelection(state.selected, row.uid); renderQueue(); },
    }));
    if (state.selected.has(row.uid)) head.firstChild.checked = true;
  }
  head.append(h("div", { class: "who" },
    h("div", { class: "name", text: title }),
    h("div", { class: "meta" },
      h("span", { class: `badge ${approved ? "sage" : ""}`, text: status[0].toUpperCase() + status.slice(1) }),
      row.knownReviewer ? h("span", { class: "badge known", text: "Knows you" }) : null,
      approved && L.approvedViaText(row) ? h("span", { class: "via", text: L.approvedViaText(row) }) : null,
      meta.flatMap((m, k) => (k ? [" · ", m] : [m])))));
  if (approved) {
    const toggle = h("input", { type: "checkbox", role: "switch", disabled: busy, "aria-label": `Approved: ${title}. Turn off to revoke. It can take up to an hour to lock her account.` });
    toggle.checked = true;
    toggle.addEventListener("change", () => { if (!toggle.checked) onRevoke(row.uid); });
    head.append(h("label", { class: "switch" }, toggle, h("span", { class: "track" }), h("span", { class: "sr", text: "Approved" })));
  }

  const el = h("li", { class: `item${state.selected.has(row.uid) ? " selected" : ""}`, vars: { "--i": Math.min(i, 8) }, "data-uid": row.uid }, head);

  if (approved) el.append(h("p", { class: "muted", text: "Revoking can take up to an hour to lock her account, until her sign-in refreshes." }));

  if (!approved) {
    const actions = h("div", { class: "actions" },
      h("button", { class: "btn big primary", type: "button", disabled: busy, onclick: () => onApprove(row.uid) }, "Approve"),
      h("button", { class: "btn", type: "button", disabled: busy, onclick: () => onKnown(row.uid) }, "Known person (instant pass)"));
    if (row.phone) {
      actions.append(
        h("a", { class: "btn ghost", href: L.telHref(row.phone) }, "Call"),
        h("a", { class: "btn ghost", href: L.waHref(row.phone), target: "_blank", rel: "noopener noreferrer" }, "WhatsApp"));
    }
    actions.append(h("button", { class: "btn ghost", type: "button", "aria-expanded": String(state.reschedule === row.uid), onclick: () => { state.reschedule = state.reschedule === row.uid ? null : row.uid; renderQueue(); } }, "Reschedule"));
    el.append(actions);
    const armed = state.declineArmed === row.uid;
    const reasonSel = h("select", { "aria-label": "Reason for declining", disabled: busy },
      ...L.DECLINE_REASONS.map((r) => h("option", { value: r.value, text: r.label })));
    const declineBtn = h("button", { class: `btn ${armed ? "danger" : "ghost"}`, type: "button", disabled: busy, "data-decline": row.uid,
      onclick: () => onDecline(row.uid, reasonSel.value) }, armed ? "Tap again to decline" : "Decline");
    actions.append(declineBtn);
    if (armed) {
      el.append(h("div", { class: "resched", role: "group" }, reasonSel,
        h("span", { class: "muted", text: "She will be told her check was not passed. This is recorded." }),
        h("button", { class: "btn ghost", type: "button", onclick: () => { state.declineArmed = null; renderQueue(); } }, "Keep waiting")));
    }
    if (state.reschedule === row.uid) {
      const input = h("input", { type: "datetime-local", "aria-label": "New call time (Cairo time)" });
      el.append(h("div", { class: "resched" }, input,
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

async function onRevoke(uid) {
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

function startUndo(uids, text) {
  state.undo = L.createUndo(uids, Date.now());
  showToast(text, state.undo);
}

function showToast(text, undo) {
  clearInterval(undoTimer);
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
  $("toast").hidden = true;
}

async function onUndo() {
  const undo = state.undo;
  if (!undo || !L.undoActive(undo, Date.now())) { hideToast(); return; }
  hideToast();
  try {
    await Promise.all(undo.uids.map((uid) => revokeOne(uid)));
    notice("Undone. They are pending again.", true);
  } catch (e) {
    notice(friendly(e));
  }
  await loadQueue();
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
      autoPassKnown: !!s.autoPassKnown,
      availability: (s.availability ?? []).map((r) => ({ ...r })),
      slotMinutes: s.slotMinutes ?? 15,
    };
  } catch (e) {
    notice(friendly(e));
  }
  $("first-name").value = state.settings.firstName;
  $("auto-pass").checked = state.settings.autoPassKnown;
  $("listed").checked = state.settings.listed;
  renderAvailability();
}

async function saveSettings(message) {
  const next = {
    ...state.settings,
    firstName: $("first-name").value.trim(),
    autoPassKnown: $("auto-pass").checked,
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
  try {
    state.phones = (await call("list_preapproved_phones", {})).phones ?? [];
    notice("");
  } catch (e) {
    notice(friendly(e));
  }
  renderPhones();
}

function renderPhones() {
  $("phones-list").replaceChildren(...state.phones.map((p, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" }, h("div", { class: "name phone", text: p })),
      h("button", { class: "btn ghost", type: "button", "aria-label": `Remove ${p}`, onclick: () => removePhone(p) }, "Remove")))));
  $("phones-empty").hidden = state.phones.length > 0;
}

async function addPhones() {
  const phones = L.parsePhoneList($("phones-input").value);
  if (!phones.length) { notice("No valid numbers found."); return; }
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
  } catch (e) {
    notice(friendly(e));
  }
  renderPhones();
}

/* exercises */

const ex = { rows: [], vocab: null, form: null };
const LABEL = (v) => v.replace(/_/g, " ");

async function loadExercises() {
  try {
    const data = await call("list_exercises", {});
    ex.rows = data.exercises ?? [];
    ex.vocab = data.vocab;
    notice("");
  } catch (e) {
    notice(friendly(e));
  }
  renderExercises();
}

function renderExercises() {
  const q = $("ex-search").value.trim().toLowerCase();
  const rows = ex.rows.filter((r) => !q || [r.id, r.nameEn, r.nameAr, r.pattern, r.kind, ...(r.primaryMuscles ?? [])].join(" ").toLowerCase().includes(q))
    .sort((a, b) => a.nameEn.localeCompare(b.nameEn));
  $("ex-list").replaceChildren(...rows.map((r, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: r.nameEn }),
        h("div", { class: "muted", text: `${LABEL(r.kind)} · ${LABEL(r.pattern)} · ${(r.primaryMuscles ?? []).map(LABEL).join(", ")} · ${r.clips?.length ?? 0} clip(s)` })),
      h("button", { class: "btn ghost", type: "button", onclick: () => openForm(r) }, "Edit")))));
  $("ex-empty").hidden = rows.length > 0;
}

function toRow(r) {
  return {
    exerciseId: r.id, name_en: r.nameEn, name_ar: r.nameAr, kind: r.kind,
    primaryMuscles: [...r.primaryMuscles], secondaryMuscles: [...r.secondaryMuscles],
    bodyRegion: r.bodyRegion, pattern: r.pattern, equipment: [...r.equipment], place: r.place, level: r.level,
    quiet: r.quiet, floorOnly: r.floorOnly, contraindicationTags: [...(r.tags ?? [])],
    setup_en: r.setupEn ?? "", setup_ar: r.setupAr ?? "",
    clips: (r.clips ?? []).map((c) => ({ file: c.file, angle: c.angle, seconds: c.seconds })),
    poster: { file: r.poster?.file ?? "" },
  };
}

function openForm(r) {
  if (!ex.vocab) { notice("The exercise list has not loaded. Open the tab again."); return; }
  const v = ex.vocab;
  ex.form = r ? { ...toRow(r), isNew: false } : {
    exerciseId: "", name_en: "", name_ar: "", kind: v.kinds[0], primaryMuscles: [], secondaryMuscles: [],
    bodyRegion: v.bodyRegions[0], pattern: v.patterns[0], equipment: ["none"], place: v.places[0], level: v.levels[0],
    quiet: false, floorOnly: false, contraindicationTags: ["none"], setup_en: "", setup_ar: "",
    clips: [], poster: { file: "" }, isNew: true,
  };
  renderForm();
  $("ex-form").scrollIntoView({ behavior: "smooth", block: "start" });
}

function field(label, control) {
  return h("label", { class: "field" }, h("span", { class: "muted", text: label }), control);
}

function textInput(key, type = "text", form = ex.form) {
  return h("input", { type, value: form[key] ?? "", oninput: (ev) => { form[key] = ev.target.value; } });
}

function selectInput(key, options, form = ex.form, label = LABEL) {
  const el = h("select", { onchange: (ev) => { form[key] = ev.target.value; } },
    options.map((o) => h("option", { value: o, text: label(o) })));
  el.value = form[key];
  return el;
}

function checks(key, options) {
  return h("div", { class: "chips" }, options.map((o) => {
    const box = h("input", { type: "checkbox", checked: ex.form[key].includes(o), onchange: (ev) => {
      const set = new Set(ex.form[key]);
      if (ev.target.checked) set.add(o); else set.delete(o);
      ex.form[key] = [...set];
    } });
    return h("label", { class: "chip" }, box, " ", LABEL(o));
  }));
}

function renderForm() {
  const f = ex.form, v = ex.vocab;
  if (!f) { $("ex-form").replaceChildren(); return; }
  const angle = h("select", { id: "ex-angle" }, v.angles.map((a) => h("option", { value: a, text: LABEL(a) })));
  const file = h("input", { type: "file", accept: "video/mp4", id: "ex-file", onchange: onClipChosen });
  const idInput = textInput("exerciseId");
  if (!f.isNew) idInput.readOnly = true;
  $("ex-form").replaceChildren(h("div", { class: "card" },
    h("h2", { text: f.isNew ? "Add exercise" : `Edit ${f.name_en}` }),
    field("Id (lowercase letters, digits and _, cannot change later)", idInput),
    field("Name (English)", textInput("name_en")),
    field("Name (Egyptian Arabic)", textInput("name_ar")),
    field("Type", selectInput("kind", v.kinds)),
    field("Movement pattern", selectInput("pattern", v.patterns)),
    field("Body region", selectInput("bodyRegion", v.bodyRegions)),
    field("Where", selectInput("place", v.places)),
    field("Level", selectInput("level", v.levels)),
    field("Main muscles", checks("primaryMuscles", v.muscles)),
    field("Helping muscles", checks("secondaryMuscles", v.muscles)),
    field("Equipment", checks("equipment", v.equipment)),
    field("Safety tags (pregnancy and postpartum filters use these)", checks("contraindicationTags", v.contraindicationTags)),
    h("label", { class: "chip" }, h("input", { type: "checkbox", checked: f.quiet, onchange: (ev) => { f.quiet = ev.target.checked; } }), " Quiet"),
    h("label", { class: "chip" }, h("input", { type: "checkbox", checked: f.floorOnly, onchange: (ev) => { f.floorOnly = ev.target.checked; } }), " Floor only"),
    h("h3", { text: "Videos" }),
    h("p", { class: "muted", id: "ex-clips", text: f.clips.map((c) => `${LABEL(c.angle)}: ${c.file}`).join(" · ") || "No video yet." }),
    h("p", { class: "muted", text: "Pick the angle, then an mp4 under 10 MB. The picture is taken from the video." }),
    angle, file,
    h("div", { class: "actions" },
      h("button", { class: "btn primary", id: "ex-save", type: "button", onclick: saveExercise }, "Save, live now"),
      h("button", { class: "btn ghost", type: "button", onclick: () => { ex.form = null; renderForm(); } }, "Cancel"))));
}

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

async function onClipChosen(ev) {
  const file = ev.target.files[0];
  const f = ex.form;
  if (!file) return;
  if (!/^[a-z0-9_]{1,64}$/.test(f.exerciseId)) { notice("Type a valid id first."); ev.target.value = ""; return; }
  if (file.type !== "video/mp4" || file.size > 10 * 1024 * 1024) { notice("The video must be an mp4 under 10 MB."); ev.target.value = ""; return; }
  const angle = $("ex-angle").value;
  const url = URL.createObjectURL(file);
  try {
    notice("Uploading...");
    const video = document.createElement("video");
    video.muted = true; video.preload = "auto"; video.src = url;
    const posterBlob = await frameOf(video);
    const seconds = Math.round(video.duration * 100) / 100;
    const clipName = `${f.exerciseId}_${angle}_${hex4()}.mp4`;
    const posterName = `${f.exerciseId}_${hex4()}.webp`;
    const base = `content/exercises/${f.exerciseId}/`;
    await uploadBytes(storageRef(storage, base + clipName), file, { contentType: "video/mp4", cacheControl: "public, max-age=31536000" });
    await uploadBytes(storageRef(storage, base + posterName), posterBlob, { contentType: "image/webp", cacheControl: "public, max-age=31536000" });
    f.clips = [...f.clips.filter((c) => c.angle !== angle), { file: clipName, angle, seconds }].slice(0, 2);
    if (f.clips.length === 1 || angle === f.clips[0].angle) f.poster = { file: posterName };
    if (!f.poster.file) f.poster = { file: posterName };
    $("ex-clips").textContent = f.clips.map((c) => `${LABEL(c.angle)}: ${c.file}`).join(" · ");
    notice("Video uploaded. Press Save to publish.", true);
  } catch (e) {
    notice("The upload failed. Check your connection and try again.");
  } finally {
    URL.revokeObjectURL(url);
    ev.target.value = "";
  }
}

async function saveExercise() {
  const f = ex.form;
  const { isNew, ...row } = f;
  $("ex-save").disabled = true;
  try {
    const out = await call("save_exercise", row);
    if (!out.ok) { notice(out.problems.join(" | ")); return; }
    notice(`Saved and live (library version ${out.version}).`, true);
    ex.form = null;
    renderForm();
    await loadExercises();
  } catch (e) {
    notice(friendly(e));
  } finally {
    const btn = $("ex-save");
    if (btn) btn.disabled = false;
  }
}

/* events */

const evs = { rows: [], form: null, previews: new Map() };
const EVENT_STATUS_LABEL = { draft: "Draft", published: "Published", cancelled: "Cancelled" };
const EVENT_MODE_LABEL = { place: "In person", online: "Online" };

async function loadEvents() {
  try {
    const data = await call("list_events_admin", {});
    evs.rows = data.events ?? [];
    notice("");
  } catch (e) {
    notice(friendly(e));
  }
  renderEvents();
}

function renderEvents() {
  $("ev-list").replaceChildren(...evs.rows.map((r, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: r.titleEn || r.titleAr || r.eventId }),
        h("div", { class: "muted", text: `${r.startsAt ? whenText(r.startsAt) : "No date"} · ${EVENT_MODE_LABEL[r.mode] ?? ""}` }),
        h("div", { class: "muted", text: L.seatsText(r) })),
      h("span", { class: `badge${r.status === "published" ? " sage" : ""}`, text: EVENT_STATUS_LABEL[r.status] ?? r.status }),
      h("button", { class: "btn ghost", type: "button", onclick: () => openEventForm(r) }, "Edit")))));
  $("ev-empty").hidden = evs.rows.length > 0;
}

function dropPreviews() {
  for (const url of evs.previews.values()) if (url.startsWith("blob:")) URL.revokeObjectURL(url);
  evs.previews = new Map();
}

function openEventForm(row) {
  dropPreviews();
  evs.form = row ? L.eventToForm(row) : L.blankEvent(L.newEventId(hex4() + hex4()));
  renderEventForm();
  $("ev-form").scrollIntoView({ behavior: "smooth", block: "start" });
  if (row) loadStoredPictures(evs.form);
}

function areaInput(key, form, max) {
  return h("textarea", { rows: 3, maxlength: max, oninput: (ev) => { form[key] = ev.target.value; } }, form[key] ?? "");
}

function mediaItem(f, kind, name) {
  const url = evs.previews.get(name);
  const preview = kind === "image"
    ? (url ? h("img", { class: "thumb", src: url, alt: "" }) : h("span", { class: "thumb empty", "aria-hidden": "true" }))
    : (url ? h("video", { class: "thumb", src: url, controls: true, muted: true, preload: "metadata" })
           : h("button", { class: "btn ghost", type: "button", onclick: () => loadStoredVideo(f, name) }, "Load preview"));
  const key = kind === "image" ? "imageFiles" : "videoFiles";
  return h("li", { class: "media" }, preview,
    h("span", { class: "muted name", text: name }),
    h("button", { class: "btn ghost", type: "button", "aria-label": `Remove ${name}`, onclick: () => {
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
    h("h3", { text: "Pictures" }),
    h("p", { class: "muted", text: `Up to ${L.EVENT_LIMITS.images}. Each is shrunk to a webp under 1 MB. The first one is the cover.` }),
    h("ul", { class: "media-list" }, f.imageFiles.map((n) => mediaItem(f, "image", n))),
    h("input", { type: "file", accept: "image/*", multiple: true, id: "ev-images", "aria-label": "Add pictures", onchange: onEventImages }),
    h("h3", { text: "Videos" }),
    h("p", { class: "muted", text: `Up to ${L.EVENT_LIMITS.videos} mp4 files, each under 10 MB.` }),
    h("ul", { class: "media-list" }, f.videoFiles.map((n) => mediaItem(f, "video", n))),
    h("input", { type: "file", accept: "video/mp4", multiple: true, id: "ev-videos", "aria-label": "Add videos", onchange: onEventVideos }),
    h("div", { class: "actions" },
      h("button", { class: "btn primary", id: "ev-save", type: "button", onclick: saveEvent }, "Save"),
      h("button", { class: "btn ghost", type: "button", onclick: () => { dropPreviews(); evs.form = null; renderEventForm(); } }, "Cancel"))));
  if (focusMode) modeSelect.focus();
}

function readAsDataUrl(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
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
      await uploadBytes(storageRef(storage, base + name), blob, { contentType: "image/webp", cacheControl: "public, max-age=31536000" });
      f.imageFiles = [...f.imageFiles, name];
      evs.previews.set(name, await readAsDataUrl(blob));
      added += 1;
    }
    if (added) notice(`${added} picture${added === 1 ? "" : "s"} uploaded. Press Save to publish the changes.`, true);
  } catch (e) {
    notice("The upload failed. Check your connection and try again.");
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
      await uploadBytes(storageRef(storage, base + name), file, { contentType: "video/mp4", cacheControl: "public, max-age=31536000" });
      f.videoFiles = [...f.videoFiles, name];
      evs.previews.set(name, URL.createObjectURL(file));
    }
    notice("Video uploaded. Press Save to publish the changes.", true);
  } catch (e) {
    notice("The upload failed. Check your connection and try again.");
  }
  renderEventForm();
}

async function saveEvent() {
  const f = evs.form;
  const problems = L.eventProblems(f);
  if (problems.length) { notice(problems.join(" | ")); return; }
  $("ev-save").disabled = true;
  try {
    const out = await call("save_event", L.eventPayload(f));
    if (!out.ok) { notice(out.problems.join(" | ")); return; }
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

const fd = { candidates: [], published: [], vocab: { categories: [], allergens: [] }, form: null, rejectArmed: null };

async function loadFoods() {
  try {
    const data = await call("list_community_foods", {});
    fd.candidates = data.candidates ?? [];
    fd.published = data.published ?? [];
    fd.vocab = data.vocab ?? fd.vocab;
    notice("");
  } catch (e) {
    notice(friendly(e));
  }
  renderFoods();
}

function renderFoods() {
  $("fd-list").replaceChildren(...fd.candidates.map((c, i) => h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: c.nameEn || c.nameAr || c.key }),
        h("div", { class: "muted", text: L.itemsText(c.items) }),
        h("div", { class: "muted", text: L.macrosText(c) })),
      h("span", { class: "badge", text: L.confirmText(c.confirmCount) }),
      h("button", { class: "btn ghost", type: "button", onclick: () => openFoodForm(c) }, "Approve"),
      fd.rejectArmed === c.key
        ? [
          h("button", { class: "btn ghost", type: "button", "data-reject-armed": "", onclick: () => rejectFood(c) }, "Reject for good"),
          h("button", { class: "btn ghost", type: "button", onclick: () => { fd.rejectArmed = null; renderFoods(); } }, "Keep"),
        ]
        : h("button", { class: "btn ghost", type: "button", onclick: () => rejectFood(c) }, "Reject")))));
  $("fd-empty").hidden = fd.candidates.length > 0;
  $("fd-published").replaceChildren(...fd.published.map((f) => h("li", { class: "item" },
    h("div", { class: "item-head" },
      h("div", { class: "who" },
        h("div", { class: "name", text: `${f.nameEn} · ${f.nameAr}` }),
        h("div", { class: "muted", text: `${LABEL(f.category)} · ${L.macrosText(f)}` }),
        h("div", { class: "muted", text: f.allergens.length ? `Allergens: ${f.allergens.map(L.allergenLabel).join(", ")}` : "No allergens" }))))));
  $("fd-published-empty").hidden = fd.published.length > 0;
}

function openFoodForm(candidate) {
  fd.form = L.foodToForm(candidate);
  renderFoodForm(candidate);
  $("fd-form").scrollIntoView({ behavior: "smooth", block: "start" });
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
    h("div", { class: "actions" },
      h("button", { class: "btn primary", id: "fd-save", type: "button", onclick: approveFood }, "Approve and publish"),
      h("button", { class: "btn ghost", type: "button", onclick: () => { fd.form = null; renderFoodForm(); } }, "Cancel"))));
}

async function approveFood() {
  const problems = L.foodProblems(fd.form, fd.vocab);
  if (problems.length) { notice(problems.join(" | ")); return; }
  $("fd-save").disabled = true;
  try {
    const out = await call("review_community_food", L.foodPayload(fd.form, "approve"));
    if (!out.ok) { notice(out.problems.join(" | ")); return; }
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
    if (!out.ok) { notice(out.problems.join(" | ")); return; }
    notice("Rejected. It will not show again.", true);
    if (fd.form?.key === candidate.key) { fd.form = null; renderFoodForm(); }
    await loadFoods();
  } catch (e) {
    notice(friendly(e));
  }
}

/* tabs and wiring */

const TABS = ["queue", "calendar", "phones", "exercises", "events", "foods", "settings"];

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
  if (name === "queue") loadQueue();
  if (name === "calendar") { loadSettings().then(loadCalendar); }
  if (name === "phones") loadPhones();
  if (name === "exercises") loadExercises();
  if (name === "events") loadEvents();
  if (name === "foods") loadFoods();
  if (name === "settings") loadSettings();
}

function wire() {
  TABS.forEach((t, i) => {
    $(`tab-${t}`).addEventListener("click", () => showTab(t));
    $(`tab-${t}`).addEventListener("keydown", (ev) => {
      const step = ev.key === "ArrowRight" ? 1 : ev.key === "ArrowLeft" ? -1 : 0;
      if (!step) return;
      const next = TABS[(i + step + TABS.length) % TABS.length];
      showTab(next);
      $(`tab-${next}`).focus();
    });
  });
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
  $("ex-search").addEventListener("input", renderExercises);
  $("ex-new").addEventListener("click", () => openForm(null));
  $("ev-new").addEventListener("click", () => openEventForm(null));

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
  $("auto-pass").addEventListener("change", () => saveSettings("Saved."));
  $("listed").addEventListener("change", () => saveSettings("Saved."));

  $("phones-input").addEventListener("input", (ev) => {
    const n = L.parsePhoneList(ev.target.value).length;
    $("phones-preview").textContent = n ? `${n} number${n === 1 ? "" : "s"} ready to add.` : "";
  });
  $("phones-add").addEventListener("click", addPhones);
}

function boot() {
  wire();
  if (PLACEHOLDER.test(JSON.stringify(firebaseConfig)) || PLACEHOLDER.test(recaptchaSiteKey)) {
    notice("Setup needed: fill in admin-web/config.js with the Firebase web app config and the reCAPTCHA Enterprise site key.");
    return;
  }
  if (["localhost", "127.0.0.1"].includes(location.hostname)) self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  const app = initializeApp(firebaseConfig);
  initializeAppCheck(app, { provider: new ReCaptchaEnterpriseProvider(recaptchaSiteKey), isTokenAutoRefreshEnabled: true });
  functions = getFunctions(app, functionsRegion);
  storage = getStorage(app, "gs://own-hub.firebasestorage.app");
  const auth = getAuth(app);

  $("login-form").addEventListener("submit", async (ev) => {
    ev.preventDefault();
    notice("Signing in...");
    try {
      await signInWithEmailAndPassword(auth, $("email").value.trim(), $("password").value);
      $("password").value = "";
      notice("");
    } catch (e) {
      notice(friendly(e));
    }
  });
  $("signout").addEventListener("click", () => signOut(auth));
  onAuthStateChanged(auth, (user) => {
    $("login").hidden = !!user;
    $("app").hidden = !user;
    $("signout").hidden = !user;
    if (user) showTab(state.tab);
    else hideToast();
  });
}

boot();
