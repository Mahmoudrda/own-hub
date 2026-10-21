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
