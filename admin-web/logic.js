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
