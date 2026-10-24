export const STATUSES = ["pending", "scheduled", "approved"];
export const UNDO_MS = 8000;
export const TIMEZONE = "Africa/Cairo";

const ARABIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";
const PERSIAN_DIGITS = "۰۱۲۳۴۵۶۷۸۹";

export function westernDigits(text) {
  return String(text ?? "").replace(/[٠-٩۰-۹]/g, (c) => {
    const a = ARABIC_DIGITS.indexOf(c);
    return String(a >= 0 ? a : PERSIAN_DIGITS.indexOf(c));
  });
}

export function parsePhoneList(text) {
  const seen = new Set();
  const phones = [];
  for (const raw of westernDigits(text).split(/[,;\n\r\t]+/)) {
    let token = raw.trim().replace(/[\s\-().]/g, "");
    if (!token) continue;
    if (token.startsWith("00")) token = "+" + token.slice(2);
    if (!/^\+?\d+$/.test(token)) continue;
    const digits = token.replace(/\D/g, "");
    if (digits.length < 7 || digits.length > 15) continue;
    if (!seen.has(token)) {
      seen.add(token);
      phones.push(token);
    }
  }
  return phones;
}

export function phoneDigits(phone) {
  return westernDigits(phone).replace(/\D/g, "");
}

export function telHref(phone) {
  const d = phoneDigits(phone);
  return d ? `tel:+${d}` : "";
}

export function waHref(phone) {
  const d = phoneDigits(phone);
  return d ? `https://wa.me/${d}` : "";
}

export function rowStatus(row) {
  if (row.state === "approved") return "approved";
  if (row.state === "scheduled" || (row.state === "pending" && row.scheduledFor)) return "scheduled";
  return "pending";
}

const VIA_LABELS = {
  knowncontact: "via known contact",
  knownperson: "as a known person",
  approve: "by a reviewer",
  testphone: "via a test number",
  storereviewer: "via the store review list",
  known_contact: "via known contact",
  known: "via known contact",
  preapproved: "via pre-approved",
  pre_approved: "via pre-approved",
  preapproved_phone: "via pre-approved",
  reviewer: "by a reviewer",
  manual: "by a reviewer",
  review: "by a reviewer",
};

/** How an approved row got in: "via known contact", "via pre-approved", and who did it when the server says. */
export function approvedViaText(row) {
  const via = String(row?.approvedVia ?? "").trim();
  if (!via) return "";
  const key = via.toLowerCase().replace(/[\s-]+/g, "_");
  const label = VIA_LABELS[key] ?? `via ${via.replace(/_/g, " ")}`;
  const by = String(row?.approvedBy ?? "").trim();
  const readable = by && (/\s/.test(by) || by.length < 20);
  return readable ? `${label} (${by})` : label;
}

export function filterRows(rows, { status = "pending", query = "" } = {}) {
  const q = westernDigits(query).trim().toLowerCase();
  const qDigits = q.replace(/\D/g, "");
  return rows.filter((row) => {
    if (status && rowStatus(row) !== status) return false;
    if (!q) return true;
    const name = String(row.displayName ?? "").toLowerCase();
    if (name.includes(q)) return true;
    if (qDigits && phoneDigits(row.phone ?? "").includes(qDigits)) return true;
    return String(row.uid ?? "").toLowerCase().startsWith(q);
  });
}

export function statusCounts(rows) {
  const counts = { pending: 0, scheduled: 0, approved: 0 };
  for (const row of rows) counts[rowStatus(row)] += 1;
  return counts;
}

export function toggleSelection(selected, uid) {
  const next = new Set(selected);
  if (next.has(uid)) next.delete(uid);
  else next.add(uid);
  return next;
}

export function selectableUids(rows) {
  return rows.filter((r) => rowStatus(r) !== "approved").map((r) => r.uid);
}

export function toggleAll(selected, rows) {
  const ids = selectableUids(rows);
  const all = ids.length > 0 && ids.every((id) => selected.has(id));
  return all ? new Set() : new Set(ids);
}

export function pruneSelection(selected, rows) {
  const live = new Set(selectableUids(rows));
  return new Set([...selected].filter((id) => live.has(id)));
}

// Undo of a removed pre-approved number: the server brings back the exact record it
// removed (who confirmed her age, and when). The browser never sends adultSeen for it.
export function restorePhonesRequest(phones) {
  return { restore: [...phones] };
}

// Old numbers saved before the 18+ tick was recorded approve no one until it is added again.
export function phoneAgeNote(phone, needing) {
  return (needing ?? []).includes(phone) ? "Needs the 18+ tick again: add this number again to approve women with it." : "";
}

export function createUndo(uids, now, ms = UNDO_MS) {
  return { uids: [...uids], expiresAt: now + ms, ms };
}

export function undoRemaining(undo, now) {
  if (!undo) return 0;
  return Math.max(0, undo.expiresAt - now);
}

export function undoActive(undo, now) {
  return undoRemaining(undo, now) > 0;
}

export function undoFraction(undo, now) {
  if (!undo) return 0;
  return undoRemaining(undo, now) / undo.ms;
}

export function normalizeRows(data) {
  if (Array.isArray(data)) return data;
  if (data && Array.isArray(data.rows)) return data.rows;
  return [];
}

function cairoParts(date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).formatToParts(date);
  const get = (t) => parts.find((p) => p.type === t).value;
  return { y: get("year"), m: get("month"), d: get("day"), h: get("hour"), min: get("minute") };
}

export function cairoDayKey(iso) {
  const p = cairoParts(new Date(iso));
  return `${p.y}-${p.m}-${p.d}`;
}

export function cairoTime(iso) {
  const p = cairoParts(new Date(iso));
  return `${p.h}:${p.min}`;
}

export function cairoLocalToIso(local) {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(local || "");
  if (!m) return null;
  const asUtc = Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]);
  let guess = asUtc;
  for (let i = 0; i < 2; i += 1) {
    const p = cairoParts(new Date(guess));
    const shown = Date.UTC(+p.y, +p.m - 1, +p.d, +p.h, +p.min);
    guess += asUtc - shown;
  }
  return new Date(guess).toISOString();
}

export function addDays(key, n) {
  const d = new Date(`${key}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function weekStartSaturday(key) {
  const dow = new Date(`${key}T00:00:00Z`).getUTCDay();
  return addDays(key, -((dow + 1) % 7));
}

export function rangeFor(view, key) {
  const start = view === "week" ? weekStartSaturday(key) : key;
  const days = view === "week" ? 7 : 1;
  return {
    start,
    days,
    from: cairoLocalToIso(`${start}T00:00`),
    to: cairoLocalToIso(`${addDays(start, days)}T00:00`),
  };
}

export function groupBookings(bookings, startKey, days) {
  const out = [];
  for (let i = 0; i < days; i += 1) out.push({ day: addDays(startKey, i), items: [] });
  for (const b of [...bookings].sort((a, c) => String(a.start).localeCompare(String(c.start)))) {
    const slot = out.find((g) => g.day === cairoDayKey(b.start));
    if (slot) slot.items.push(b);
  }
  return out;
}

export function validAvailability(rows) {
  return rows.every(
    (r) =>
      Number.isInteger(r.weekday) &&
      r.weekday >= 1 &&
      r.weekday <= 7 &&
      /^\d{2}:\d{2}$/.test(r.start) &&
      /^\d{2}:\d{2}$/.test(r.end) &&
      r.start < r.end,
  );
}

export const EVENT_LIMITS = {
  title: 120,
  description: 2000,
  place: 120,
  address: 300,
  link: 510,
  mapUrl: 500,
  seats: 100000,
  images: 6,
  videos: 2,
  imageBytes: 1024 * 1024,
  videoBytes: 10 * 1024 * 1024,
};
export const EVENT_STATUSES = ["draft", "published", "cancelled"];
export const EVENT_MODES = ["place", "online"];

const MAPS_URL = /^https:\/\/((maps\.google\.com|maps\.app\.goo\.gl)([/?#]\S*)?|goo\.gl\/maps([/?#]\S*)?|www\.google\.com\/maps([/?#]\S*)?)$/;
const HTTPS_LINK = /^https:\/\/\S{3,500}$/;

export function newEventId(hex) {
  return `ev_${String(hex).toLowerCase().replace(/[^0-9a-f]/g, "").slice(0, 16)}`;
}

export function eventFileName(eventId, hex, ext) {
  const id = String(eventId).toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 60);
  const tail = String(hex).toLowerCase().replace(/[^a-z0-9]/g, "");
  return `${id || "ev"}_${tail}.${ext}`;
}

export function isMapsUrl(url) {
  return MAPS_URL.test(url || "") && (url || "").length <= EVENT_LIMITS.mapUrl;
}

export function cairoLocalFromIso(iso) {
  if (!iso) return "";
  const p = cairoParts(new Date(iso));
  return `${p.y}-${p.m}-${p.d}T${p.h}:${p.min}`;
}

export function blankEvent(eventId) {
  return {
    eventId, isNew: true, seatsTaken: 0,
    titleEn: "", titleAr: "", descriptionEn: "", descriptionAr: "",
    startsLocal: "", endsLocal: "", mode: "place", placeName: "", locationAddress: "",
    locationUrl: "", link: "", capacity: "", status: "draft", coverFile: null, imageFiles: [], videoFiles: [],
  };
}

export function eventToForm(row) {
  return {
    eventId: row.eventId, isNew: false, seatsTaken: row.seatsTaken ?? 0,
    titleEn: row.titleEn ?? "", titleAr: row.titleAr ?? "",
    descriptionEn: row.descriptionEn ?? "", descriptionAr: row.descriptionAr ?? "",
    startsLocal: cairoLocalFromIso(row.startsAt), endsLocal: cairoLocalFromIso(row.endsAt),
    mode: row.mode === "online" ? "online" : "place",
    placeName: row.placeName ?? "", locationAddress: row.locationAddress ?? "",
    locationUrl: row.locationUrl ?? "", link: row.link ?? "",
    capacity: row.capacity == null ? "" : String(row.capacity),
    status: row.status ?? "draft", coverFile: row.coverFile ?? null,
    imageFiles: [...(row.imageFiles ?? [])], videoFiles: [...(row.videoFiles ?? [])],
  };
}

export function eventProblems(f) {
  const out = [];
  const max = (value, limit, label) => {
    if (String(value ?? "").length > limit) out.push(`${label} is longer than ${limit} characters.`);
  };
  if (!f.titleEn.trim()) out.push("Add the English title.");
  if (!f.titleAr.trim()) out.push("Add the Arabic title.");
  max(f.titleEn, EVENT_LIMITS.title, "The English title");
  max(f.titleAr, EVENT_LIMITS.title, "The Arabic title");
  max(f.descriptionEn, EVENT_LIMITS.description, "The English description");
  max(f.descriptionAr, EVENT_LIMITS.description, "The Arabic description");
  const starts = cairoLocalToIso(f.startsLocal);
  const ends = cairoLocalToIso(f.endsLocal);
  if (!starts) out.push("Pick when it starts.");
  if (!ends) out.push("Pick when it ends.");
  if (starts && ends && !(starts < ends)) out.push("It must end after it starts.");
  if (!EVENT_MODES.includes(f.mode)) out.push("Pick in person or online.");
  if (f.mode === "online" && !HTTPS_LINK.test(f.link.trim())) out.push("An online event needs a link that starts with https://.");
  if (f.mode === "place") {
    if (!f.placeName.trim()) out.push("Add the venue name.");
    max(f.placeName, EVENT_LIMITS.place, "The venue name");
    max(f.locationAddress, EVENT_LIMITS.address, "The address");
    if (f.locationUrl.trim() && !isMapsUrl(f.locationUrl.trim())) {
      out.push("The map link must be a Google Maps link that starts with https://.");
    }
  }
  const seats = f.capacity === "" || f.capacity == null ? null : Number(f.capacity);
  if (seats !== null && (!Number.isInteger(seats) || seats < 1 || seats > EVENT_LIMITS.seats)) {
    out.push(`Seats must be a whole number from 1 to ${EVENT_LIMITS.seats}.`);
  } else if (f.seatsTaken > 0 && (seats === null || seats < f.seatsTaken)) {
    out.push(`${f.seatsTaken} seats are already booked, so seats cannot go below that.`);
  }
  if (f.status === "published" && seats === null) out.push("Set the seats before publishing, so women can reserve.");
  if (f.imageFiles.length > EVENT_LIMITS.images) out.push(`At most ${EVENT_LIMITS.images} pictures.`);
  if (f.videoFiles.length > EVENT_LIMITS.videos) out.push(`At most ${EVENT_LIMITS.videos} videos.`);
  if (!EVENT_STATUSES.includes(f.status)) out.push("Pick a status.");
  return out;
}

export function eventPayload(f) {
  const place = f.mode === "place";
  const text = (v) => (String(v ?? "").trim() === "" ? null : String(v).trim());
  return {
    eventId: f.eventId,
    titleEn: f.titleEn.trim(),
    titleAr: f.titleAr.trim(),
    descriptionEn: text(f.descriptionEn),
    descriptionAr: text(f.descriptionAr),
    startsAt: cairoLocalToIso(f.startsLocal),
    endsAt: cairoLocalToIso(f.endsLocal),
    mode: f.mode,
    placeName: place ? text(f.placeName) : null,
    locationAddress: place ? text(f.locationAddress) : null,
    locationUrl: place ? text(f.locationUrl) : null,
    link: place ? null : text(f.link),
    capacity: f.capacity === "" || f.capacity == null ? null : Number(f.capacity),
    imageFiles: [...f.imageFiles],
    videoFiles: [...f.videoFiles],
    status: f.status,
    coverFile: f.coverFile ?? null,
  };
}

export const DECLINE_REASONS = [
  { value: "notClear", label: "Photos or video not clear" },
  { value: "notMatching", label: "Does not match" },
  { value: "other", label: "Other" },
];

export function declineReason(value) {
  return DECLINE_REASONS.some((r) => r.value === value) ? value : "other";
}

export function rejectStep(armedKey, key) {
  return armedKey === key ? { armed: null, send: true } : { armed: key, send: false };
}

export function seatsText(row) {
  const taken = row.seatsTaken ?? 0;
  return row.capacity == null ? `${taken} booked, no seat limit set` : `${taken} / ${row.capacity} booked`;
}

export function seatsLeft(row) {
  return row.capacity == null ? null : Math.max(0, row.capacity - (row.seatsTaken ?? 0));
}

export function canAddFiles(current, adding, kind) {
  const limit = kind === "video" ? EVENT_LIMITS.videos : EVENT_LIMITS.images;
  return current + adding <= limit;
}

export function fileFits(size, kind) {
  const limit = kind === "video" ? EVENT_LIMITS.videoBytes : EVENT_LIMITS.imageBytes;
  return size > 0 && size <= limit;
}

export function shrinkSteps(width, height) {
  const longest = Math.max(width, height);
  const out = [];
  for (const edge of [1600, 1280, 960, 720]) {
    const scale = Math.min(1, edge / longest);
    for (const quality of [0.85, 0.7, 0.55, 0.4]) {
      out.push({ width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)), quality });
    }
  }
  return out;
}

/* community foods */

export const FOOD_NAME_MAX = 60;

export function confirmText(count) {
  return count === 1 ? "1 woman confirmed this" : `${count} women confirmed this`;
}

export function macrosText(c) {
  return `${c.kcal} kcal · protein ${c.proteinG} g · carbs ${c.carbsG} g · fat ${c.fatG} g`;
}

export function itemsText(items) {
  return (items ?? []).map((i) => `${i.name} ${i.grams} g`).join(", ");
}

export function foodToForm(candidate) {
  return {
    key: candidate.key,
    nameEn: candidate.nameEn ?? "",
    nameAr: candidate.nameAr ?? "",
    category: "",
    allergens: [],
    allergensNone: false,
  };
}

export function toggleAllergen(form, token, on) {
  const rest = form.allergens.filter((a) => a !== token);
  const allergens = on ? [...rest, token] : rest;
  return { ...form, allergens, allergensNone: allergens.length ? false : form.allergensNone };
}

export function setNoAllergens(form, on) {
  return { ...form, allergensNone: on, allergens: on ? [] : form.allergens };
}

export function foodProblems(form, vocab) {
  const problems = [];
  for (const [key, label] of [["nameEn", "English"], ["nameAr", "Arabic"]]) {
    const name = (form[key] ?? "").trim();
    if (!name) problems.push(`Add the ${label} name.`);
    else if (name.length > FOOD_NAME_MAX) problems.push(`The ${label} name is over ${FOOD_NAME_MAX} characters.`);
  }
  if (!vocab.categories.includes(form.category)) problems.push("Pick a category.");
  if (!form.allergens.length && !form.allergensNone) problems.push("Tick the allergens, or confirm there are none.");
  return problems;
}

export function foodPayload(form, action) {
  if (action === "reject") return { key: form.key, action };
  return {
    key: form.key,
    action,
    nameEn: form.nameEn.trim(),
    nameAr: form.nameAr.trim(),
    category: form.category,
    allergens: [...form.allergens],
    allergensNone: form.allergens.length === 0 && form.allergensNone,
  };
}

export function allergenLabel(token) {
  return token.replace(/_/g, " ");
}

/* exercise videos */

export const MEDIA_CACHE = { videos: 12, posters: 60 };
export const POSTER_CONCURRENCY = 4;
export const CLIP_MAX_BYTES = 10 * 1024 * 1024;
export const POSTER_MAX_BYTES = 2 * 1024 * 1024;

const CLIP_ORDER = ["front", "side", "rear", "otherSide"];
const ANGLE_NAMES = { front: "Front view", side: "Side view", rear: "Rear view", otherSide: "Other side view" };

export function exerciseMediaPath(exerciseId, file) {
  if (!/^[a-z0-9_]{1,64}$/.test(exerciseId ?? "")) return "";
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(file ?? "") || String(file).includes("..")) return "";
  return `content/exercises/${exerciseId}/${file}`;
}

export function posterMime(file) {
  const ext = String(file ?? "").split(".").pop().toLowerCase();
  if (ext === "png") return "image/png";
  if (ext === "jpg" || ext === "jpeg") return "image/jpeg";
  return "image/webp";
}

export function angleLabel(angle) {
  return ANGLE_NAMES[angle] ?? String(angle ?? "View").replace(/[_-]+/g, " ").replace(/^./, (c) => c.toUpperCase());
}

export function viewLabel(angle, name) {
  return `${angleLabel(angle)} of ${String(name ?? "").trim() || "this exercise"}`;
}

export function orderClips(items) {
  const rank = (a) => {
    const i = CLIP_ORDER.indexOf(a?.angle);
    return i < 0 ? CLIP_ORDER.length : i;
  };
  return (items ?? []).map((item, i) => ({ item, i })).sort((a, b) => rank(a.item) - rank(b.item) || a.i - b.i).map((x) => x.item);
}

export function clipSecondsText(seconds) {
  const n = Number(seconds);
  if (!Number.isFinite(n) || n <= 0) return "";
  return `${Math.round(n * 10) / 10} s`;
}

export function slotCaption(item) {
  const parts = [angleLabel(item.angle)];
  const length = clipSecondsText(item.seconds);
  if (length) parts.push(length);
  if (item.uploading) parts.push("uploading");
  return parts.join(" · ");
}

// What the Watch panel shows: saved clips in view order, plus clips chosen on
// this machine. A local clip plays from its own file straight away.
export function watchItems(clips, locals = []) {
  const uploading = locals.filter((l) => l.uploading);
  const replaced = new Set(uploading.map((l) => l.angle));
  const items = [];
  for (const c of clips ?? []) {
    if (replaced.has(c.angle)) continue;
    const local = locals.find((l) => !l.uploading && l.file === c.file);
    items.push({
      key: local ? `local:${local.url}` : `file:${c.file}`,
      angle: c.angle, file: c.file, seconds: c.seconds ?? null, localUrl: local ? local.url : null, uploading: false,
    });
  }
  for (const l of uploading) {
    items.push({ key: `local:${l.url}`, angle: l.angle, file: null, seconds: null, localUrl: l.url, uploading: true });
  }
  return orderClips(items);
}

// Least recently used cache. Pinned keys (still on screen) are never evicted.
export class LruCache {
  constructor(max, { onEvict = () => {}, isPinned = () => false } = {}) {
    this.max = max;
    this.onEvict = onEvict;
    this.isPinned = isPinned;
    this.map = new Map();
  }

  get size() { return this.map.size; }

  has(key) { return this.map.has(key); }

  keys() { return [...this.map.keys()]; }

  get(key) {
    if (!this.map.has(key)) return undefined;
    const value = this.map.get(key);
    this.map.delete(key);
    this.map.set(key, value);
    return value;
  }

  set(key, value) {
    if (this.map.has(key)) {
      const old = this.map.get(key);
      this.map.delete(key);
      if (old !== value) this.onEvict(old, key);
    }
    this.map.set(key, value);
    this.trim();
  }

  delete(key) {
    if (!this.map.has(key)) return false;
    const value = this.map.get(key);
    this.map.delete(key);
    this.onEvict(value, key);
    return true;
  }

  clear() {
    for (const key of this.keys()) this.delete(key);
  }

  trim() {
    for (const key of this.keys()) {
      if (this.map.size <= this.max) break;
      if (this.isPinned(key)) continue;
      this.delete(key);
    }
  }
}

// Runs at most `max` tasks at once; the rest wait in order.
export function createLimiter(max) {
  let active = 0;
  const queue = [];
  const pump = () => {
    while (active < max && queue.length) {
      const { task, resolve, reject } = queue.shift();
      active += 1;
      Promise.resolve().then(task).then(resolve, reject).finally(() => {
        active -= 1;
        pump();
      });
    }
  };
  return (task) => new Promise((resolve, reject) => {
    queue.push({ task, resolve, reject });
    pump();
  });
}

/* plain-language errors */

const FRIENDLY_CODES = {
  "functions/unauthenticated": "Your account is not set up as a reviewer. Ask the owner.",
  "functions/permission-denied": "This account can not do that. Ask the owner.",
  "functions/failed-precondition": "That did not work yet. Refresh and try again.",
  "functions/not-found": "That request is gone. Refresh the list.",
  "functions/unavailable": "The service can not be reached right now. Check your internet and try again.",
  "functions/deadline-exceeded": "That took too long. Try again.",
  "functions/internal": "The server had a problem. Try again, or tell the owner.",
  "functions/invalid-argument": "Some of what was sent was not accepted. Check the form and try again.",
  "functions/resource-exhausted": "Too many requests. Wait a minute and try again.",
  "auth/invalid-credential": "Wrong email or password.",
  "auth/invalid-login-credentials": "Wrong email or password.",
  "auth/too-many-requests": "Too many tries. Wait a minute and try again.",
  "auth/network-request-failed": "No connection. Check your internet.",
};

export function friendlyMessage(code) {
  if (FRIENDLY_CODES[code]) return FRIENDLY_CODES[code];
  return code ? `Something went wrong (${code}). Try again, or tell the owner.` : "Something went wrong. Try again, or tell the owner.";
}

// The server writes problems for developers ("hip_x: tag 'none' cannot sit with other tags").
export function plainProblem(text) {
  let t = String(text ?? "").trim().replace(/^[a-z0-9_]{1,64}: /, "");
  const rules = [
    [/^tag 'none' cannot sit with other tags/, "Safety tags: pick \"none\" on its own, or pick the real tags."],
    [/^equipment 'none' cannot sit with other equipment/, "Equipment: \"none\" can not be combined with other equipment."],
    [/^a muscle is both primary and secondary/, "A muscle can be a main muscle or a helping muscle, not both."],
    [/^a stretch is a mobility move/, "A stretch must use the mobility pattern, and only a stretch can."],
    [/^contraindicationTags is empty/, "Pick at least one safety tag, or \"none\"."],
    [/^primaryMuscles is empty/, "Pick at least one main muscle."],
    [/^one or \d+ clips/, "Add at least one video before saving."],
    [/^name_en is empty/, "Add the English name."],
    [/^name_ar is empty/, "Add the Arabic name."],
    [/^the exercise id may hold/, "The id may only hold lowercase letters, digits and underscores."],
    [/^(.+) is not uploaded$/, "A file ($1) is not uploaded yet. Upload the video again."],
  ];
  for (const [re, out] of rules) {
    if (re.test(t)) return t.replace(re, out);
  }
  if (!/[.!?]$/.test(t)) t += ".";
  return t.charAt(0).toUpperCase() + t.slice(1);
}

export function httpStatusOf(e) {
  const n = e?.status_ ?? e?.customData?.status ?? e?.customData?.httpStatus ?? e?.status;
  return Number.isInteger(n) ? n : null;
}

const detailOf = (code, status) => {
  const bits = [code, status != null ? `HTTP ${status}` : ""].filter(Boolean);
  return bits.length ? ` (${bits.join(", ")})` : "";
};

// Why a storage read failed, in words, with the code or HTTP status after it.
export function storageErrorText(e, online = true) {
  const code = String(e?.code ?? "");
  const status = httpStatusOf(e);
  const detail = detailOf(code, status);
  if (code === "storage/object-not-found" || status === 404) {
    return { kind: "missing", retry: false, text: `Not found in storage. The library lists this video, but the file is not there.${detail}` };
  }
  if (code === "storage/unauthorized" || code === "storage/unauthenticated" || status === 401 || status === 403) {
    return { kind: "denied", retry: true, text: `Not allowed. Your sign-in may have expired: sign out and in again, then retry.${detail}` };
  }
  if (!online || code === "storage/retry-limit-exceeded" || code === "storage/canceled" || code === "storage/network-request-failed" || status === 0 || e?.name === "TypeError") {
    return { kind: "network", retry: true, text: `Network problem. Check your internet connection, then retry.${detail}` };
  }
  if (code === "storage/quota-exceeded" || status === 429 || (status != null && status >= 500)) {
    return { kind: "server", retry: true, text: `Storage is busy or not answering. Try again in a minute.${detail}` };
  }
  if (code === "storage/invalid-argument" || code === "storage/invalid-root-operation") {
    return { kind: "badname", retry: false, text: `The video name in the library is not valid.${detail}` };
  }
  return { kind: "unknown", retry: true, text: `Unexpected error while loading the video.${detail}` };
}

// MediaError codes from the video element.
export function playbackErrorText(code) {
  switch (code) {
    case 1: return "Playback was stopped.";
    case 2: return "The video stopped downloading part way. Network problem. (media error 2)";
    case 3: return "This browser could not read the video data. The file may be damaged. (media error 3)";
    case 4: return "This browser can not play this file. (media error 4)";
    default: return "This video could not be played.";
  }
}

export const SLOW_LOAD_MS = 8000;
export const SLOW_LOAD_TEXT = "Still loading. The connection looks slow, and a video can be up to 10 MB.";

export function isRetryableLoad(e, online = true) {
  const t = storageErrorText(e, online);
  return t.kind === "network" || t.kind === "server";
}

/* exercise review workflow */

export const EX_FILTERS = [
  { key: "tags", label: "Needs tags" },
  { key: "video", label: "Needs video" },
  { key: "complete", label: "Complete" },
  { key: "all", label: "All" },
];

export const CHECKLIST_LABELS = {
  video: "Video added",
  kind: "Type chosen",
  pattern: "Movement pattern chosen",
  muscles: "Main muscles chosen",
  tags: "Safety tags chosen",
  checked: "Checked by you",
};

const inVocab = (value, list) => Boolean(value) && (!Array.isArray(list) || list.includes(value));

// The six things a finished exercise has. `checked` is her own tick on this browser.
export function exerciseChecklist(row, checked = false, vocab = null) {
  const ok = {
    video: (row?.clips?.length ?? 0) > 0,
    kind: inVocab(row?.kind, vocab?.kinds),
    pattern: inVocab(row?.pattern, vocab?.patterns),
    muscles: (row?.primaryMuscles?.length ?? 0) > 0,
    tags: (row?.tags?.length ?? 0) > 0,
    checked: Boolean(checked),
  };
  return Object.keys(CHECKLIST_LABELS).map((key) => ({ key, label: CHECKLIST_LABELS[key], ok: ok[key] }));
}

export function exerciseState(row, checked = false, vocab = null) {
  const items = exerciseChecklist(row, checked, vocab);
  const bad = new Set(items.filter((i) => !i.ok).map((i) => i.key));
  const needsVideo = bad.has("video");
  const needsTags = ["kind", "pattern", "muscles", "tags", "checked"].some((k) => bad.has(k));
  return { items, needsVideo, needsTags, complete: bad.size === 0, missing: [...bad] };
}

export function exerciseCounts(rows, isChecked = () => false, vocab = null) {
  const counts = { total: rows.length, complete: 0, tags: 0, video: 0, all: rows.length };
  for (const r of rows) {
    const s = exerciseState(r, isChecked(r.id), vocab);
    if (s.complete) counts.complete += 1;
    if (s.needsTags) counts.tags += 1;
    if (s.needsVideo) counts.video += 1;
  }
  return counts;
}

export function progressText(counts) {
  return `${counts.complete} of ${counts.total} complete`;
}

export function progressFraction(counts) {
  return counts.total ? counts.complete / counts.total : 0;
}

const byName = (a, b) => String(a.nameEn ?? "").localeCompare(String(b.nameEn ?? ""));

export function exerciseMatches(row, query) {
  const q = String(query ?? "").trim().toLowerCase();
  if (!q) return true;
  return [row.id, row.nameEn, row.nameAr, row.pattern, row.kind, ...(row.primaryMuscles ?? [])].join(" ").toLowerCase().includes(q);
}

// The rows to show for a filter and a search, in name order.
export function filterExercises(rows, { filter = "all", query = "", isChecked = () => false, vocab = null } = {}) {
  return rows
    .filter((r) => {
      if (!exerciseMatches(r, query)) return false;
      const s = exerciseState(r, isChecked(r.id), vocab);
      if (filter === "tags") return s.needsTags;
      if (filter === "video") return s.needsVideo;
      if (filter === "complete") return s.complete;
      return true;
    })
    .sort(byName);
}

// Position in a review queue: "3 of 40".
export function queuePosition(queue, id) {
  const i = queue.indexOf(id);
  return i < 0 ? null : { index: i, number: i + 1, total: queue.length };
}

export function neighbour(queue, id, step) {
  const i = queue.indexOf(id);
  if (i < 0) return null;
  return queue[i + step] ?? null;
}

// The next exercise after `id` that is not done, going round the end of the queue once.
export function nextUnfinished(queue, id, isDone) {
  const start = queue.indexOf(id);
  for (let step = 1; step <= queue.length; step += 1) {
    const candidate = queue[(start + step + queue.length) % queue.length];
    if (candidate !== id && !isDone(candidate)) return candidate;
  }
  return null;
}

// The first exercise still to do, in name order. `null` when everything is done.
export function firstToReview(rows, isChecked = () => false, vocab = null) {
  const list = [...rows].sort(byName);
  return list.find((r) => !exerciseState(r, isChecked(r.id), vocab).complete)?.id ?? null;
}

export function exerciseId(name, taken = []) {
  const base = String(name ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 56);
  if (!base) return "";
  const used = new Set(taken);
  if (!used.has(base)) return base;
  for (let n = 2; n < 100; n += 1) if (!used.has(`${base}_${n}`)) return `${base}_${n}`;
  return base;
}

export function toggleExclusive(list, token, on, exclusive = "none") {
  const rest = list.filter((t) => t !== token);
  if (!on) return rest;
  if (token === exclusive) return [exclusive];
  return [...rest.filter((t) => t !== exclusive), token];
}

export function blankExercise(vocab) {
  return {
    exerciseId: "", name_en: "", name_ar: "", kind: vocab.kinds[0], primaryMuscles: [], secondaryMuscles: [],
    bodyRegion: vocab.bodyRegions[0], pattern: vocab.patterns[0], equipment: ["none"], place: vocab.places[0], level: vocab.levels[0],
    quiet: false, floorOnly: false, contraindicationTags: [], setup_en: "", setup_ar: "",
    clips: [], poster: { file: "" }, isNew: true, checked: true,
  };
}

export function formFromRow(r, checked = false) {
  return {
    exerciseId: r.id, name_en: r.nameEn, name_ar: r.nameAr, kind: r.kind,
    primaryMuscles: [...(r.primaryMuscles ?? [])], secondaryMuscles: [...(r.secondaryMuscles ?? [])],
    bodyRegion: r.bodyRegion, pattern: r.pattern, equipment: [...(r.equipment ?? [])], place: r.place, level: r.level,
    quiet: Boolean(r.quiet), floorOnly: Boolean(r.floorOnly), contraindicationTags: [...(r.tags ?? [])],
    setup_en: r.setupEn ?? "", setup_ar: r.setupAr ?? "",
    clips: (r.clips ?? []).map((c) => ({ file: c.file, angle: c.angle, seconds: c.seconds })),
    poster: { file: r.poster?.file ?? "" }, isNew: false, checked: Boolean(checked),
  };
}

// What the save call receives: the form without its local-only fields.
export function savePayload(form) {
  const { isNew, checked, ...row } = form;
  return row;
}

// Changes when anything she can edit changes. Used to tell whether leaving loses work.
export function formSignature(form) {
  if (!form) return "";
  const p = savePayload(form);
  const sorted = (a) => [...a].sort();
  return JSON.stringify({
    ...p, primaryMuscles: sorted(p.primaryMuscles), secondaryMuscles: sorted(p.secondaryMuscles),
    equipment: sorted(p.equipment), contraindicationTags: sorted(p.contraindicationTags),
    name_en: p.name_en.trim(), name_ar: p.name_ar.trim(), checked: Boolean(form.checked),
  });
}

// The library row the list shows after a save, before the server list is read again.
export function rowFromForm(form, prev = null) {
  const p = savePayload(form);
  const bytes = new Map((prev?.clips ?? []).map((c) => [c.file, c.bytes]));
  const row = {
    id: p.exerciseId, nameEn: p.name_en.trim(), nameAr: p.name_ar.trim(), kind: p.kind,
    primaryMuscles: [...p.primaryMuscles], secondaryMuscles: [...p.secondaryMuscles],
    bodyRegion: p.bodyRegion, pattern: p.pattern, equipment: [...p.equipment], place: p.place, level: p.level,
    quiet: p.quiet, floorOnly: p.floorOnly, tags: [...p.contraindicationTags],
    clips: p.clips.map((c) => ({ file: c.file, angle: c.angle, seconds: c.seconds, bytes: bytes.get(c.file) ?? 0 })),
    poster: { file: p.poster.file, bytes: prev?.poster?.file === p.poster.file ? prev.poster.bytes : 0 },
  };
  if (p.setup_en) { row.setupEn = p.setup_en; row.setupAr = p.setup_ar; }
  return row;
}

const DASH = /[–—]/;

// The server's checks for one exercise, run before the call. Each problem names its field.
export function exerciseProblems(form, { taken = [] } = {}) {
  const out = [];
  const add = (field, message) => out.push({ field, message });
  const name = (key, label) => {
    const v = String(form[key] ?? "").trim();
    if (!v) add(key, `Add the ${label} name.`);
    else if (v.length > 300) add(key, `The ${label} name is over 300 characters.`);
    else if (DASH.test(v)) add(key, `The ${label} name has a long dash. Use a comma or a full stop.`);
  };
  name("name_en", "English");
  name("name_ar", "Arabic");
  if (form.isNew) {
    if (!/^[a-z0-9_]{1,64}$/.test(form.exerciseId)) add("exerciseId", "The id may only hold lowercase letters, digits and underscores.");
    else if (taken.includes(form.exerciseId)) add("exerciseId", "Another exercise already uses this id.");
  }
  if ((form.kind === "stretch") !== (form.pattern === "mobility")) {
    add("pattern", form.kind === "stretch" ? "A stretch must use the mobility pattern." : "The mobility pattern is only for stretches. Change the type to stretch, or pick another pattern.");
  }
  if (!form.primaryMuscles.length) add("primaryMuscles", "Pick at least one main muscle.");
  const both = form.primaryMuscles.filter((m) => form.secondaryMuscles.includes(m));
  if (both.length) add("secondaryMuscles", `${both.map((m) => m.replace(/_/g, " ")).join(", ")} can not be both a main and a helping muscle.`);
  if (!form.equipment.length) add("equipment", "Pick the equipment, or \"none\".");
  if (form.equipment.includes("none") && form.equipment.length > 1) add("equipment", "\"none\" can not be combined with other equipment.");
  if (!form.contraindicationTags.length) add("contraindicationTags", "Pick at least one safety tag, or \"none\" if nothing needs avoiding.");
  if (form.contraindicationTags.includes("none") && form.contraindicationTags.length > 1) add("contraindicationTags", "\"none\" can not be combined with other safety tags.");
  if (!form.clips.length) add("clips", "Add at least one video before saving.");
  return out;
}

// One line each: what the tag means for this move, in the words of the movement.
export const TAG_HINTS = {
  high_impact: "Hard landings or forceful impact through the body.",
  jumping: "Both feet leave the floor.",
  deep_knee_flexion: "The knees bend deeply, such as a deep squat or lunge.",
  loaded_twisting: "Turning the trunk while holding weight.",
  pelvic_floor_load: "Pushes or bears down through the pelvic floor.",
  breath_hold_valsalva: "Holding the breath while straining.",
  prone_position: "Lying face down on the belly.",
  supine_load: "Lying on the back while working against load.",
  overhead_load: "Weight held or pressed above the head.",
  wrist_load: "Weight through the hands and wrists, such as a plank or push-up.",
  none: "Nothing in this move needs avoiding. Pick this on its own.",
};

export const KIND_HINTS = {
  strength: "A move that works muscles against effort or weight.",
  stretch: "A stretch or mobility move. It uses the mobility pattern.",
};

export const PATTERN_HINTS = {
  squat: "Bending the knees and hips to lower the body.",
  hinge: "Folding at the hips with the back flat.",
  lunge: "One leg forward or back, lowering the body.",
  hip_thrust_bridge: "Lifting the hips from the floor or a bench.",
  push_horizontal: "Pressing away from the chest.",
  push_vertical: "Pressing overhead.",
  pull_horizontal: "Rowing toward the body.",
  pull_vertical: "Pulling down from above.",
  isolation_lower: "Works one lower-body muscle on its own.",
  isolation_upper: "Works one upper-body muscle on its own.",
  core_anti_extension: "Holding the trunk still, such as a plank.",
  core_flexion: "Curling the trunk, such as a crunch.",
  core_rotation: "Turning the trunk.",
  carry: "Walking while holding weight.",
  mobility: "A stretch or range-of-motion move.",
};

export function hintFor(group, token) {
  const table = group === "tags" ? TAG_HINTS : group === "kind" ? KIND_HINTS : group === "pattern" ? PATTERN_HINTS : {};
  return table[token] ?? "";
}

export const FIELD_LABELS = {
  name_en: "English name", name_ar: "Arabic name", exerciseId: "Id", kind: "Type", pattern: "Movement pattern",
  primaryMuscles: "Main muscles", secondaryMuscles: "Helping muscles", equipment: "Equipment",
  contraindicationTags: "Safety tags", clips: "Video",
};

// Her ticks live in this browser only. Stored as a JSON list of exercise ids.
export const CHECKED_KEY = "ownhub.reviewer.checkedExercises.v1";

export function parseChecked(text) {
  try {
    const v = JSON.parse(text);
    return new Set(Array.isArray(v) ? v.filter((x) => typeof x === "string") : []);
  } catch (e) {
    return new Set();
  }
}

export function serializeChecked(set) {
  return JSON.stringify([...set].sort());
}

/* counts and search for the other tabs */

export function countBy(rows, keyOf) {
  const out = {};
  for (const r of rows) {
    const k = keyOf(r);
    out[k] = (out[k] ?? 0) + 1;
  }
  return out;
}

export function filterEvents(rows, { status = "all", query = "" } = {}) {
  const q = String(query ?? "").trim().toLowerCase();
  return rows.filter((r) => {
    if (status !== "all" && r.status !== status) return false;
    if (!q) return true;
    return [r.titleEn, r.titleAr, r.placeName, r.eventId].join(" ").toLowerCase().includes(q);
  });
}

export function filterFoods(list, query = "") {
  const q = String(query ?? "").trim().toLowerCase();
  if (!q) return list;
  return list.filter((f) => [f.nameEn, f.nameAr, f.key, f.category, ...(f.items ?? []).map((i) => i.name)].join(" ").toLowerCase().includes(q));
}

export function upcomingEvents(rows, now = Date.now()) {
  return rows.filter((r) => r.status !== "cancelled" && (!r.endsAt || Date.parse(r.endsAt) >= now)).length;
}

export function badgeText(n, cap = 99) {
  if (!n || n < 0) return "";
  return n > cap ? `${cap}+` : String(n);
}

/* private coaching: tabs by claim, money, labels, forms */

export const COACHING_TABS = ["coaches", "payments", "refunds", "payouts", "reports"];

// Moves with the server's payments switch: false hides every money screen.
export const PAYMENTS_LIVE = false;
const MONEY_TABS = ["payments", "refunds", "payouts"];

// Which coaching tabs a staff member sees. The server refuses the rest anyway.
export function coachingTabsFor(claims, live = PAYMENTS_LIVE) {
  const c = claims ?? {};
  const out = new Set();
  if (c.admin) COACHING_TABS.forEach((t) => out.add(t));
  if (c.womanReviewer) { out.add("coaches"); out.add("reports"); }
  if (c.finance) MONEY_TABS.forEach((t) => out.add(t));
  return COACHING_TABS.filter((t) => out.has(t) && (live || !MONEY_TABS.includes(t)));
}

// Suspending a coach and editing the receiving accounts and seller details.
export const isAdmin = (claims) => !!claims?.admin;

export function formatEgp(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return "";
  const whole = Number.isInteger(v);
  return `${v.toLocaleString("en-US", { minimumFractionDigits: whole ? 0 : 2, maximumFractionDigits: 2 })} EGP`;
}

export function amountMismatch(expected, entered) {
  const a = Number(expected);
  const b = Number(entered);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return false;
  return Math.round(a * 100) !== Math.round(b * 100);
}

// Callable timestamps arrive as ISO text.
export function toIso(v) {
  return typeof v === "string" && !Number.isNaN(Date.parse(v)) ? v : "";
}

// A page of a list callable joined to what is already shown, in the order the
// server sent it. A row that came twice (the list moved between pages) shows once.
export function appendPage(items, page, key) {
  const seen = new Set(items.map(key));
  return [...items, ...page.filter((x) => !seen.has(key(x)))];
}

export const PROOF_FLAG_LABELS = {
  duplicateReference: "Reference already used",
  sameImage: "Same picture as another payment",
  nearImage: "Looks like another payment's picture",
  amountDiffers: "Amount differs",
  paidBeforeAccept: "Paid before the coach accepted",
};
export const flagLabel = (flag) => PROOF_FLAG_LABELS[flag] ?? String(flag ?? "").replace(/([A-Z])/g, " $1").toLowerCase();

export const PROOF_REJECT_LABELS = {
  amount_wrong: "Amount is wrong",
  not_received: "Money not received",
  unreadable: "Screenshot unreadable",
  wrong_account: "Paid to the wrong account",
  duplicate: "Duplicate payment",
  other: "Other",
};
export const PROOF_REJECT_REASONS = Object.keys(PROOF_REJECT_LABELS);

export const SECTION_LABELS = {
  personal: "Personal details",
  education: "Education",
  certificates: "Certificates",
  specialties: "Specialties",
  feedback: "Client feedback",
  transformations: "Transformations",
  approach: "Approach",
  payout: "Payout account",
  terms: "Terms and rules",
};
export const SECTIONS = Object.keys(SECTION_LABELS).filter((s) => PAYMENTS_LIVE || s !== "payout");

export const SECTION_REASON_LABELS = {
  missing: "Missing",
  unclear: "Unclear",
  unverifiable: "Can not be checked",
  not_allowed: "Not allowed",
  other: "Other",
};
export const SECTION_REASONS = Object.keys(SECTION_REASON_LABELS);

export const APPLICATION_STATUSES = ["submitted", "needs_changes", "approved", "rejected"];
export const APPLICATION_STATUS_LABELS = { submitted: "Submitted", needs_changes: "Needs changes", approved: "Approved", rejected: "Rejected" };

export const RAIL_LABELS = { instapay: "InstaPay", vodafoneCash: "Vodafone Cash" };
export const railLabel = (r) => RAIL_LABELS[r] ?? String(r ?? "");
export const RAIL_PATTERNS = {
  instapay: { account: /^[a-z0-9._-]{3,40}@instapay$/, reference: /^[A-Za-z0-9-]{6,40}$/ },
  vodafoneCash: { account: /^010[0-9]{8}$/, reference: /^[A-Za-z0-9-]{6,40}$/ },
};

export const COACH_RULE_LABELS = {
  accurateInfo: "Everything in the application is accurate",
  clientPhotoConsent: "Client photos are used only with the client's consent",
  noOffPlatformPayment: "No payments taken outside the app",
};
// The server stores the rules she accepted as a list of ids.
export const acceptedRuleLabels = (rules) => (rules ?? []).map((id) => COACH_RULE_LABELS[id] ?? String(id));

export const REPORT_STATE_OPEN = "submitted";
export const REPORT_DECISIONS = ["dismiss", "hide_message", "suspend_coach", "end_coaching"];
export const REPORT_DECISION_LABELS = { dismiss: "Dismiss", hide_message: "Hide message", suspend_coach: "Suspend coach", end_coaching: "End coaching" };
export const REPORT_KIND_LABELS = { coachMessage: "Chat message", coachProfile: "Coach profile", coachPlan: "Plan" };
export const REPORT_REASON_LABELS = {
  harassment: "Harassment", man_account: "Looks like a man's account", nudity: "Nudity", spam: "Spam", impersonation: "Impersonation",
  self_harm: "Self harm", off_platform_payment: "Asked to pay outside the app", unsafe_advice: "Unsafe advice", other: "Other",
};
export const reportDecisionsFor = (kind) => REPORT_DECISIONS.filter((d) => d !== "hide_message" || kind === "coachMessage");

// Short staff-facing words for the reasons the coaching callables refuse with.
export const COACHING_REASON_TEXT = {
  not_a_coach: "That person is not an active coach.",
  bad_request: "Some of what was sent was not accepted. Check the form.",
  application_not_found: "That application is gone. Refresh the list.",
  coach_suspended: "That coach is already suspended.",
  wrong_status: "Refresh and try again.",
  reference_used: "That transfer reference is already attached to another payment.",
  proof_not_found: "That payment is gone. Refresh the list.",
  request_not_found: "That request is gone. Refresh the list.",
  payout_account_pending: "Confirm her new payout account first.",
  nothing_owed: "Nothing is owed to her right now.",
  seller_not_set: "Set the seller details in Settings first.",
  staff_is_subject: "You cannot decide your own case.",
  report_not_found: "That report is gone. Refresh the list.",
  media_not_found: "That photo is gone. Refresh the list.",
  too_many_media: "That coach already has the most items she can have.",
};

export function coachingMessage(e) {
  const reason = String(e?.details?.reason ?? e?.message ?? "").trim();
  if (COACHING_REASON_TEXT[reason]) return COACHING_REASON_TEXT[reason];
  return friendlyMessage(e?.code);
}

/* accounts typed twice */

export function normaliseAccount(text) {
  return westernDigits(String(text ?? "")).replace(/\s+/g, "").toLowerCase();
}

export function retypeMatch(a, b) {
  const x = normaliseAccount(a);
  return x !== "" && x === normaliseAccount(b);
}

export function normaliseName(text) {
  return String(text ?? "")
    .normalize("NFKD")
    .replace(/[̀-ًͯ-ٟـ]/g, "")
    .replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .toLowerCase().replace(/\s+/g, " ").trim();
}

export const namesMatch = (a, b) => normaliseName(a) !== "" && normaliseName(a) === normaliseName(b);

export function accountProblems(account, rail) {
  const p = RAIL_PATTERNS[rail];
  const value = normaliseAccount(account);
  if (!value) return [];
  return p.account.test(value) ? [] : [rail === "instapay" ? "The InstaPay address looks like name@instapay." : "The Vodafone Cash number is 11 digits starting 010."];
}

export function receivingProblems(form) {
  const out = [];
  for (const rail of ["instapay", "vodafoneCash"]) {
    const f = form?.[rail] ?? {};
    const label = railLabel(rail);
    const address = normaliseAccount(f.address);
    if (f.enabled && !address) out.push(`${label}: add the account or turn it off.`);
    if (f.enabled && address) {
      out.push(...accountProblems(address, rail).map((p) => `${label}: ${p}`));
      if (!retypeMatch(f.address, f.again)) out.push(`${label}: type the account a second time, exactly the same.`);
      if (!String(f.holderName ?? "").trim()) out.push(`${label}: add the holder name.`);
    }
  }
  if (!out.length && !["instapay", "vodafoneCash"].some((r) => form?.[r]?.enabled)) out.push("Turn on at least one account so members can pay.");
  return out;
}

export function receivingPayload(form) {
  const one = (rail) => {
    const f = form?.[rail] ?? {};
    const address = normaliseAccount(f.address);
    if (!f.enabled || !address) return { address: "", holderName: "", enabled: false };
    return { address, holderName: String(f.holderName ?? "").trim(), enabled: true };
  };
  return { instapay: one("instapay"), vodafoneCash: one("vodafoneCash") };
}

export const SELLER_FIELDS = [
  ["companyNameEn", "Legal name (English)"],
  ["companyNameAr", "Legal name (Arabic)"],
  ["addressEn", "Address (English)"],
  ["addressAr", "Address (Arabic)"],
  ["commercialRegistration", "Commercial registration number"],
  ["taxCard", "Tax card number"],
  ["vatRatePercent", "VAT %"],
  ["supportEmail", "Support email"],
  ["supportPhone", "Support phone"],
];

export function sellerProblems(form) {
  const out = [];
  for (const [key, label] of SELLER_FIELDS) {
    if (key !== "supportPhone" && !String(form?.[key] ?? "").trim()) out.push(`${label}: fill this in.`);
  }
  const vat = Number(westernDigits(form?.vatRatePercent ?? ""));
  if (String(form?.vatRatePercent ?? "").trim() && !(Number.isInteger(vat) && vat >= 0 && vat <= 14)) out.push("VAT %: use a whole number from 0 to 14.");
  const email = String(form?.supportEmail ?? "").trim();
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) out.push("Support email: this does not look like an email.");
  return out;
}

// The saved seller details as the form holds them (numbers become text).
export function sellerToForm(seller) {
  const out = {};
  for (const [key] of SELLER_FIELDS) out[key] = seller?.[key] == null ? "" : String(seller[key]);
  return out;
}

export function sellerPayload(form) {
  const out = {};
  for (const [key] of SELLER_FIELDS) out[key] = String(form?.[key] ?? "").trim();
  out.vatRatePercent = Number(westernDigits(out.vatRatePercent));
  out.supportPhone = westernDigits(out.supportPhone);
  return out;
}

/* application review */

export const canApproveApplication = (ticked) => (ticked?.length ?? 0) >= 1;

// The server needs a reason on at least one section for Needs changes and Reject; the note is extra.
export function applicationDecisionProblems(decision, reasons) {
  if (decision === "approve") return [];
  return Object.values(reasons ?? {}).some(Boolean) ? [] : ["Pick a reason on at least one section."];
}

export function applicationPayload(uid, decision, { reasons = {}, ticked = [], note = "" } = {}) {
  const clean = {};
  for (const s of SECTIONS) if (SECTION_REASONS.includes(reasons[s])) clean[s] = reasons[s];
  return {
    uid,
    decision,
    reasons: decision === "approve" ? {} : clean,
    checkedCertificates: decision === "approve" ? [...ticked] : [],
    note: String(note ?? "").trim(),
  };
}

export function fileKind(path, mime = "") {
  const m = String(mime ?? "").toLowerCase();
  const ext = String(path ?? "").toLowerCase().split("?")[0].split(".").pop();
  if (m === "application/pdf" || ext === "pdf") return "pdf";
  if (m.startsWith("image/") || ["jpg", "jpeg", "png", "webp", "gif"].includes(ext)) return "image";
  return "other";
}

// An account waits for finance when the state is pending (first account) or a change was requested.
export const payoutNeedsConfirm = (coach) => coach?.payoutState === "pending" || !!coach?.pendingPayout;

/* badges: counts of what waits */

// Coaches the finance team still has something to do for: money owed or an account to confirm.
export const payoutBadgeCount = (coaches) => coaches.filter((c) => c.amountEgp > 0 || payoutNeedsConfirm(c)).length;

/* portfolio photos: the woman reviewer's check before members see them */

export const PORTFOLIO_KIND_LABELS = { transformation: "Transformation", feedback: "Feedback", photo: "Photo" };
export const PORTFOLIO_REJECT_LABELS = { unclear: "Unclear", not_allowed: "Not allowed", no_consent: "No consent", other: "Other" };
export const PORTFOLIO_REJECT_REASONS = Object.keys(PORTFOLIO_REJECT_LABELS);
export const PORTFOLIO_CONSENT_LINE = "Her client agreed in writing that members may see these photos";

// Only a woman reviewer may list, see and decide; the server refuses admins.
export const canDecidePortfolio = (claims) => !!claims?.womanReviewer;

// A row is told apart by coach and media id together.
export const portfolioKey = (item) => `${item?.coachUid}/${item?.mediaId}`;

// The storage paths an item shows, in display order.
export function portfolioPaths(item) {
  const list = item?.kind === "transformation" ? [item.beforePath, item.afterPath]
    : item?.kind === "feedback" || item?.kind === "photo" ? [item.imagePath] : [];
  return list.filter(Boolean);
}

export const portfolioRejectProblems = (decision, reason) =>
  decision === "reject" && !PORTFOLIO_REJECT_REASONS.includes(reason) ? ["Pick a reason."] : [];

export function portfolioDecisionPayload(item, decision, reason = "") {
  return { coachUid: item.coachUid, mediaId: item.mediaId, decision, reason: decision === "reject" ? reason : "" };
}

// What the Coaches tab badge counts: applications plus photos waiting.
export const coachesBadgeCount = (applications, photos) => (Number(applications) || 0) + (Number(photos) || 0);
