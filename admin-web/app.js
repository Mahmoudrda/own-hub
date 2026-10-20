import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app-check.js";
import { getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";
import { getStorage, ref as storageRef, uploadBytes } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-storage.js";
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

function textInput(key, type = "text") {
  return h("input", { type, value: ex.form[key] ?? "", oninput: (ev) => { ex.form[key] = ev.target.value; } });
}

function selectInput(key, options) {
  const el = h("select", { onchange: (ev) => { ex.form[key] = ev.target.value; } },
    options.map((o) => h("option", { value: o, text: LABEL(o) })));
  el.value = ex.form[key];
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

/* tabs and wiring */

const TABS = ["queue", "calendar", "phones", "exercises", "settings"];

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
