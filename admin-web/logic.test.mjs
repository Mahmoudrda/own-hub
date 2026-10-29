import test from "node:test";
import assert from "node:assert/strict";
import * as L from "./logic.js";
import { readFileSync } from "node:fs";

test("phone list parser", () => {
  const out = L.parsePhoneList("+201012345678, 01012345679\n٠١٠١٢٣٤٥٦٧٨٠\n+201012345678; abc, 123");
  assert.deepEqual(out, ["+201012345678", "01012345679", "010123456780"]);
  assert.deepEqual(L.parsePhoneList("0020 101 234 5678"), ["+201012345678"]);
  assert.deepEqual(L.parsePhoneList(" , \n "), []);
});

test("approved rows say how she got in", () => {
  assert.equal(L.approvedViaText({ approvedVia: "known_contact" }), "via known contact");
  assert.equal(L.approvedViaText({ approvedVia: "knownContact" }), "via known contact");
  assert.equal(L.approvedViaText({ approvedVia: "knownPerson" }), "as a known person");
  assert.equal(L.approvedViaText({ approvedVia: "approve" }), "by a reviewer");
  assert.equal(L.approvedViaText({ approvedVia: "testPhone" }), "via a test number");
  assert.equal(L.approvedViaText({ approvedVia: "preapproved", approvedBy: "Mona" }), "via pre-approved (Mona)");
  assert.equal(L.approvedViaText({ approvedVia: "preapproved", approvedBy: "k3J9sd8f7Gh2LpQ0wZxv5NbMcT1a" }), "via pre-approved");
  assert.equal(L.approvedViaText({ approvedVia: "something_new" }), "via something new");
  assert.equal(L.approvedViaText({}), "");
});

test("contact links", () => {
  assert.equal(L.waHref("+20 101 234 5678"), "https://wa.me/201012345678");
  assert.equal(L.telHref("+201012345678"), "tel:+201012345678");
  assert.equal(L.waHref(undefined), "");
});

const rows = [
  { uid: "a1", state: "pending", displayName: "Mona Ali", phone: "+201011111111" },
  { uid: "b2", state: "pending", scheduledFor: "2026-10-20T10:00:00Z", displayName: "Sara" },
  { uid: "c3", state: "approved", displayName: "Nour Hassan" },
];

test("status filter and search", () => {
  assert.deepEqual(L.filterRows(rows, { status: "pending" }).map((r) => r.uid), ["a1"]);
  assert.deepEqual(L.filterRows(rows, { status: "scheduled" }).map((r) => r.uid), ["b2"]);
  assert.deepEqual(L.filterRows(rows, { status: "approved", query: "nour" }).map((r) => r.uid), ["c3"]);
  assert.deepEqual(L.filterRows(rows, { status: "pending", query: "٠١٠١١١" }).map((r) => r.uid), ["a1"]);
  assert.deepEqual(L.filterRows(rows, { status: "pending", query: "zzz" }), []);
  assert.deepEqual(L.statusCounts(rows), { pending: 1, scheduled: 1, approved: 1 });
});

test("bulk selection", () => {
  let sel = L.toggleSelection(new Set(), "a1");
  assert.ok(sel.has("a1"));
  sel = L.toggleSelection(sel, "a1");
  assert.equal(sel.size, 0);
  const all = L.toggleAll(new Set(), rows);
  assert.deepEqual([...all].sort(), ["a1", "b2"]);
  assert.equal(L.toggleAll(all, rows).size, 0);
  assert.deepEqual([...L.pruneSelection(new Set(["a1", "c3", "zz"]), rows)], ["a1"]);
});

test("undo timer state", () => {
  const undo = L.createUndo(["a1"], 1000);
  assert.equal(L.undoRemaining(undo, 1000), 8000);
  assert.equal(L.undoRemaining(undo, 5000), 4000);
  assert.equal(L.undoFraction(undo, 5000), 0.5);
  assert.ok(L.undoActive(undo, 8999));
  assert.ok(!L.undoActive(undo, 9000));
  assert.equal(L.undoRemaining(undo, 20000), 0);
  assert.equal(L.undoRemaining(null, 0), 0);
});

test("Cairo time helpers", () => {
  assert.equal(L.cairoLocalToIso("2026-01-15T10:00"), "2026-01-15T08:00:00.000Z");
  assert.equal(L.cairoLocalToIso("2026-07-15T10:00"), "2026-07-15T07:00:00.000Z");
  assert.equal(L.cairoDayKey("2026-07-15T21:30:00Z"), "2026-07-16");
  assert.equal(L.cairoTime("2026-01-15T08:05:00Z"), "10:05");
  assert.equal(L.weekStartSaturday("2026-10-18"), "2026-10-17");
  assert.equal(L.weekStartSaturday("2026-10-17"), "2026-10-17");
  assert.equal(L.addDays("2026-12-31", 1), "2027-01-01");
});

test("grouping and availability", () => {
  const groups = L.groupBookings(
    [{ uid: "x", start: "2026-01-15T09:00:00Z" }, { uid: "y", start: "2026-01-15T08:00:00Z" }],
    "2026-01-15",
    2,
  );
  assert.deepEqual(groups[0].items.map((b) => b.uid), ["y", "x"]);
  assert.equal(groups[1].items.length, 0);
  assert.ok(L.validAvailability([{ weekday: 1, start: "09:00", end: "12:00" }]));
  assert.ok(!L.validAvailability([{ weekday: 8, start: "09:00", end: "12:00" }]));
  assert.ok(!L.validAvailability([{ weekday: 1, start: "12:00", end: "09:00" }]));
});

const eventForm = (over = {}) => ({
  ...L.blankEvent("ev_0123456789abcdef"),
  titleEn: "Stretch", titleAr: "تمدد", startsLocal: "2030-03-01T18:00", endsLocal: "2030-03-01T20:00",
  placeName: "Zamalek gym", capacity: "20", ...over,
});

test("event ids and file names fit what the server accepts", () => {
  const id = L.newEventId("0123456789ABCDEF99");
  assert.equal(id, "ev_0123456789abcdef");
  const name = L.eventFileName(id, "a1b2c3d4", "webp");
  assert.match(name, /^[a-z0-9][a-z0-9_-]{0,80}\.(webp|jpg|jpeg)$/);
  assert.match(L.eventFileName(id, "a1b2c3d4", "mp4"), /^[a-z0-9][a-z0-9_-]{0,80}\.mp4$/);
});

test("file names stay valid for an event id with capitals", () => {
  const name = L.eventFileName("Xy9ZaBcD3fGh", "A1B2C3D4", "webp");
  assert.equal(name, "xy9zabcd3fgh_a1b2c3d4.webp");
  assert.match(name, /^[a-z0-9][a-z0-9_-]{0,80}\.(webp|jpg|jpeg)$/);
  assert.match(L.eventFileName("Xy9ZaBcD3fGh", "a1b2", "mp4"), /^[a-z0-9][a-z0-9_-]{0,80}\.mp4$/);
});

test("the cover file survives the form round trip", () => {
  const form = L.eventToForm({ eventId: "e1", coverFile: "cover_1.webp", mode: "place", imageFiles: [], videoFiles: [] });
  assert.equal(form.coverFile, "cover_1.webp");
  assert.equal(L.eventPayload({ ...eventForm(), coverFile: form.coverFile }).coverFile, "cover_1.webp");
  assert.equal(L.eventPayload(eventForm()).coverFile, null);
});

test("goo.gl is a map link only under /maps/", () => {
  assert.ok(!L.isMapsUrl("https://goo.gl/abc"));
  assert.ok(!L.isMapsUrl("https://maps.google.com/x\n"));
  assert.ok(!L.isMapsUrl("https://goo.gl/mapsevil"));
  assert.ok(L.isMapsUrl("https://goo.gl/maps/abc"));
});

test("map links: only Google Maps hosts over https", () => {
  for (const ok of [
    "https://maps.google.com/?q=maadi", "https://www.google.com/maps/place/x",
    "https://goo.gl/maps/abc", "https://maps.app.goo.gl/abc",
  ]) assert.ok(L.isMapsUrl(ok), ok);
  for (const bad of [
    "http://maps.google.com/x", "https://evil.example.com/maps", "https://maps.google.com.evil.example/x",
    "https://goo.gl@evil.example/x", "https://www.google.com/search?q=x", "https://www.google.com/mapsevil",
    "https://maps.google.com/ x", "", undefined,
  ]) assert.ok(!L.isMapsUrl(bad), String(bad));
});

test("event times are Cairo local in the form and UTC on the wire", () => {
  assert.equal(L.cairoLocalFromIso("2026-01-15T08:05:00Z"), "2026-01-15T10:05");
  assert.equal(L.cairoLocalFromIso("2026-07-15T07:05:00Z"), "2026-07-15T10:05");
  assert.equal(L.cairoLocalFromIso(null), "");
  const form = L.eventToForm({ eventId: "e1", startsAt: "2026-07-15T07:00:00Z", endsAt: "2026-07-15T09:00:00Z", capacity: 12, seatsTaken: 3 });
  assert.equal(form.startsLocal, "2026-07-15T10:00");
  assert.equal(form.capacity, "12");
  assert.equal(L.eventPayload({ ...form, titleEn: "a", titleAr: "b" }).startsAt, "2026-07-15T07:00:00.000Z");
});

test("event form problems mirror the server limits", () => {
  assert.deepEqual(L.eventProblems(eventForm()), []);
  assert.ok(L.eventProblems(eventForm({ titleEn: " " })).length);
  assert.ok(L.eventProblems(eventForm({ titleAr: "" })).length);
  assert.ok(L.eventProblems(eventForm({ titleEn: "x".repeat(121) })).length);
  assert.ok(L.eventProblems(eventForm({ endsLocal: "2030-03-01T17:00" })).length);
  assert.ok(L.eventProblems(eventForm({ startsLocal: "" })).length);
  assert.ok(L.eventProblems(eventForm({ placeName: "" })).length);
  assert.ok(L.eventProblems(eventForm({ locationUrl: "https://evil.example.com/maps" })).length);
  assert.deepEqual(L.eventProblems(eventForm({ locationUrl: "https://goo.gl/maps/abc", locationAddress: "12 Road 9" })), []);
  assert.ok(L.eventProblems(eventForm({ locationAddress: "x".repeat(301) })).length);
  assert.ok(L.eventProblems(eventForm({ mode: "online", link: "http://meet.example.com/a" })).length);
  assert.deepEqual(L.eventProblems(eventForm({ mode: "online", link: "https://meet.example.com/a", placeName: "" })), []);
  for (const bad of ["0", "-1", "2.5", "abc", "100001"]) assert.ok(L.eventProblems(eventForm({ capacity: bad })).length, bad);
  assert.ok(L.eventProblems(eventForm({ imageFiles: Array(7).fill("a.webp") })).length);
  assert.ok(L.eventProblems(eventForm({ videoFiles: ["a.mp4", "b.mp4", "c.mp4"] })).length);
  assert.ok(L.eventProblems(eventForm({ status: "live" })).length);
});

test("seats booked bound the seats and publishing needs seats", () => {
  assert.ok(L.eventProblems(eventForm({ seatsTaken: 5, capacity: "4" })).length);
  assert.ok(L.eventProblems(eventForm({ seatsTaken: 5, capacity: "" })).length);
  assert.deepEqual(L.eventProblems(eventForm({ seatsTaken: 5, capacity: "5" })), []);
  assert.ok(L.eventProblems(eventForm({ capacity: "", status: "published" })).length);
  assert.deepEqual(L.eventProblems(eventForm({ capacity: "", status: "draft" })), []);
});

test("the payload keeps only the fields of the chosen mode and never sends seats taken", () => {
  const place = L.eventPayload(eventForm({ locationUrl: "https://goo.gl/maps/abc", link: "https://x.example.com/a", seatsTaken: 9 }));
  assert.equal(place.link, null);
  assert.equal(place.locationUrl, "https://goo.gl/maps/abc");
  assert.equal(place.capacity, 20);
  assert.ok(!("seatsTaken" in place));
  const online = L.eventPayload(eventForm({ mode: "online", link: " https://meet.example.com/a ", placeName: "Old" }));
  assert.equal(online.link, "https://meet.example.com/a");
  assert.equal(online.placeName, null);
  assert.equal(online.locationUrl, null);
  assert.equal(L.eventPayload(eventForm({ capacity: "" })).capacity, null);
  assert.equal(L.eventPayload(eventForm({ descriptionEn: "  " })).descriptionEn, null);
});

test("booked seats read as seatsTaken / capacity", () => {
  assert.equal(L.seatsText({ seatsTaken: 3, capacity: 20 }), "3 / 20 booked");
  assert.equal(L.seatsText({ capacity: null }), "0 booked, no seat limit set");
  assert.equal(L.seatsLeft({ seatsTaken: 3, capacity: 20 }), 17);
  assert.equal(L.seatsLeft({ seatsTaken: 30, capacity: 20 }), 0);
  assert.equal(L.seatsLeft({ capacity: null }), null);
});

test("file limits: six pictures of 1 MiB, two clips of 10 MiB", () => {
  assert.ok(L.canAddFiles(4, 2, "image"));
  assert.ok(!L.canAddFiles(5, 2, "image"));
  assert.ok(L.canAddFiles(1, 1, "video"));
  assert.ok(!L.canAddFiles(2, 1, "video"));
  assert.ok(L.fileFits(1024 * 1024, "image"));
  assert.ok(!L.fileFits(1024 * 1024 + 1, "image"));
  assert.ok(L.fileFits(10 * 1024 * 1024, "video"));
  assert.ok(!L.fileFits(10 * 1024 * 1024 + 1, "video"));
  assert.ok(!L.fileFits(0, "video"));
});

test("shrinking an image tries smaller sizes and lower quality, never larger", () => {
  const steps = L.shrinkSteps(4000, 3000);
  assert.equal(steps[0].width, 1600);
  assert.equal(steps[0].height, 1200);
  assert.ok(steps.every((s) => s.width <= 1600 && s.quality <= 0.85));
  assert.equal(L.shrinkSteps(800, 600)[0].width, 800);
  assert.ok(steps.length >= 8);
});

const FOOD_VOCAB = { categories: ["egyptianDishes", "proteins"], allergens: ["gluten", "tree_nuts"] };
const CANDIDATE = { key: "a".repeat(24), nameEn: "Koshary", nameAr: null, kcal: 520, proteinG: 18, carbsG: 90, fatG: 9,
  items: [{ name: "rice", grams: 200 }, { name: "lentils", grams: 100 }], confirmCount: 3 };

test("community food rows read plainly", () => {
  assert.equal(L.confirmText(1), "1 woman confirmed this");
  assert.equal(L.confirmText(3), "3 women confirmed this");
  assert.equal(L.macrosText(CANDIDATE), "520 kcal · protein 18 g · carbs 90 g · fat 9 g");
  assert.equal(L.itemsText(CANDIDATE.items), "rice 200 g, lentils 100 g");
  assert.equal(L.itemsText(undefined), "");
  assert.equal(L.allergenLabel("tree_nuts"), "tree nuts");
});

test("approving a food needs both names, a category and an explicit allergen answer", () => {
  const form = L.foodToForm(CANDIDATE);
  assert.deepEqual(form, { key: CANDIDATE.key, nameEn: "Koshary", nameAr: "", category: "", allergens: [], allergensNone: false });
  assert.equal(L.foodProblems(form, FOOD_VOCAB).length, 3);
  const ready = { ...form, nameAr: "كشري", category: "egyptianDishes", allergensNone: true };
  assert.deepEqual(L.foodProblems(ready, FOOD_VOCAB), []);
  assert.ok(L.foodProblems({ ...ready, category: "desserts" }, FOOD_VOCAB).length);
  assert.ok(L.foodProblems({ ...ready, nameAr: " " }, FOOD_VOCAB).length);
  assert.ok(L.foodProblems({ ...ready, nameEn: "x".repeat(61) }, FOOD_VOCAB).length);
});

test("allergen ticks and the none confirmation exclude each other", () => {
  let form = L.foodToForm(CANDIDATE);
  form = L.setNoAllergens(form, true);
  form = L.toggleAllergen(form, "gluten", true);
  assert.deepEqual(form.allergens, ["gluten"]);
  assert.equal(form.allergensNone, false);
  form = L.setNoAllergens(form, true);
  assert.deepEqual(form.allergens, []);
  assert.equal(form.allergensNone, true);
  form = L.toggleAllergen(L.toggleAllergen(L.setNoAllergens(form, false), "gluten", true), "gluten", false);
  assert.deepEqual(form.allergens, []);
});

test("the food payloads match what the callable reads", () => {
  const form = { ...L.foodToForm(CANDIDATE), nameAr: " كشري ", category: "egyptianDishes", allergens: ["gluten"] };
  assert.deepEqual(L.foodPayload(form, "approve"), {
    key: CANDIDATE.key, action: "approve", nameEn: "Koshary", nameAr: "كشري",
    category: "egyptianDishes", allergens: ["gluten"], allergensNone: false,
  });
  assert.deepEqual(L.foodPayload(form, "reject"), { key: CANDIDATE.key, action: "reject" });
  assert.equal(L.foodPayload({ ...form, allergens: [], allergensNone: true }, "approve").allergensNone, true);
});

test("rejecting a food takes two steps on the same candidate", () => {
  assert.deepEqual(L.rejectStep(null, "k1"), { armed: "k1", send: false });
  assert.deepEqual(L.rejectStep("k1", "k1"), { armed: null, send: true });
  assert.deepEqual(L.rejectStep("k1", "k2"), { armed: "k2", send: false });
});

test("decline needs two steps and sends only a known reason", () => {
  assert.deepEqual(L.rejectStep(null, "u1"), { armed: "u1", send: false });
  assert.deepEqual(L.rejectStep("u1", "u1"), { armed: null, send: true });
  assert.equal(L.declineReason("notClear"), "notClear");
  assert.equal(L.declineReason("anything else"), "other");
  assert.equal(L.declineReason(undefined), "other");
  assert.deepEqual(L.DECLINE_REASONS.map((r) => r.value), ["notClear", "notMatching", "other"]);
});

test("exercise media paths are built only from safe parts", () => {
  assert.equal(L.exerciseMediaPath("arm_circles", "arm_circles_front_007ce952.mp4"), "content/exercises/arm_circles/arm_circles_front_007ce952.mp4");
  assert.equal(L.exerciseMediaPath("arm_circles", "../secret.mp4"), "");
  assert.equal(L.exerciseMediaPath("arm_circles", "a/b.mp4"), "");
  assert.equal(L.exerciseMediaPath("arm_circles", "a..b.mp4"), "");
  assert.equal(L.exerciseMediaPath("Arm Circles", "a.mp4"), "");
  assert.equal(L.exerciseMediaPath("", "a.mp4"), "");
  assert.equal(L.exerciseMediaPath("arm_circles", ""), "");
  assert.equal(L.exerciseMediaPath("arm_circles", undefined), "");
  assert.equal(L.posterMime("x.webp"), "image/webp");
  assert.equal(L.posterMime("x.JPG"), "image/jpeg");
  assert.equal(L.posterMime("x.png"), "image/png");
});

test("clips show front first and the labels say what is on screen", () => {
  const clips = [{ angle: "otherSide", file: "d" }, { angle: "side", file: "b" }, { angle: "mystery", file: "e" }, { angle: "front", file: "a" }, { angle: "rear", file: "c" }];
  assert.deepEqual(L.orderClips(clips).map((c) => c.file), ["a", "b", "c", "d", "e"]);
  assert.deepEqual(L.orderClips([{ angle: "x", file: "1" }, { angle: "y", file: "2" }]).map((c) => c.file), ["1", "2"]);
  assert.deepEqual(L.orderClips(null), []);
  assert.equal(L.angleLabel("front"), "Front view");
  assert.equal(L.angleLabel("otherSide"), "Other side view");
  assert.equal(L.angleLabel("three_quarter"), "Three quarter");
  assert.equal(L.viewLabel("front", "Arm circles"), "Front view of Arm circles");
  assert.equal(L.viewLabel("side", "  "), "Side view of this exercise");
  assert.equal(L.clipSecondsText(8.46), "8.5 s");
  assert.equal(L.clipSecondsText(12), "12 s");
  assert.equal(L.clipSecondsText(0), "");
  assert.equal(L.clipSecondsText(null), "");
  assert.equal(L.slotCaption({ angle: "front", seconds: 8.5, uploading: false }), "Front view · 8.5 s");
  assert.equal(L.slotCaption({ angle: "side", seconds: null, uploading: true }), "Side view · uploading");
});

test("the watch list merges saved clips with clips chosen on this machine", () => {
  const clips = [{ angle: "side", file: "s.mp4", seconds: 6 }, { angle: "front", file: "f.mp4", seconds: 8 }];
  const saved = L.watchItems(clips, []);
  assert.deepEqual(saved.map((i) => [i.key, i.angle, i.localUrl]), [["file:f.mp4", "front", null], ["file:s.mp4", "side", null]]);

  const uploading = [{ angle: "front", url: "blob:1", file: null, seconds: null, uploading: true }];
  const mid = L.watchItems(clips, uploading);
  assert.deepEqual(mid.map((i) => [i.key, i.uploading, i.localUrl]), [["local:blob:1", true, "blob:1"], ["file:s.mp4", false, null]]);

  const done = [{ angle: "front", url: "blob:1", file: "f2.mp4", seconds: 9, uploading: false }];
  const after = L.watchItems([{ angle: "front", file: "f2.mp4", seconds: 9 }, clips[0]], done);
  assert.equal(after[0].key, "local:blob:1");
  assert.equal(after[0].localUrl, "blob:1");
  assert.equal(after[0].file, "f2.mp4");
  assert.equal(after[1].key, "file:s.mp4");

  assert.deepEqual(L.watchItems([], []), []);
  assert.deepEqual(L.watchItems(undefined, undefined), []);
  const stale = L.watchItems(clips, [{ angle: "front", url: "blob:9", file: "gone.mp4", uploading: false }]);
  assert.deepEqual(stale.map((i) => i.key), ["file:f.mp4", "file:s.mp4"]);
});

test("the cache drops the least recently used entry and spares pinned ones", () => {
  const evicted = [];
  const pinned = new Set();
  const cache = new L.LruCache(3, { onEvict: (value, key) => evicted.push(key), isPinned: (key) => pinned.has(key) });
  cache.set("a", 1); cache.set("b", 2); cache.set("c", 3);
  cache.get("a");
  cache.set("d", 4);
  assert.deepEqual(evicted, ["b"]);
  assert.deepEqual(cache.keys(), ["c", "a", "d"]);

  pinned.add("c");
  cache.set("e", 5);
  assert.deepEqual(evicted, ["b", "a"]);
  assert.deepEqual(cache.keys(), ["c", "d", "e"]);

  pinned.add("d"); pinned.add("e"); pinned.add("f");
  cache.set("f", 6);
  assert.equal(cache.size, 4);
  pinned.clear();
  cache.set("g", 7);
  assert.equal(cache.size, 3);

  cache.set("g", 8);
  assert.ok(evicted.includes("g"));
  assert.equal(cache.get("missing"), undefined);
  assert.equal(cache.delete("missing"), false);
  const before = evicted.length;
  cache.clear();
  assert.equal(cache.size, 0);
  assert.equal(evicted.length, before + 3);
  assert.equal(L.MEDIA_CACHE.videos, 12);
  assert.equal(L.MEDIA_CACHE.posters, 60);
});

test("the limiter never runs more than four tasks at once and keeps order", async () => {
  const run = L.createLimiter(L.POSTER_CONCURRENCY);
  let active = 0, peak = 0;
  const started = [];
  const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const results = await Promise.all(Array.from({ length: 10 }, (_, i) => run(async () => {
    started.push(i);
    active += 1; peak = Math.max(peak, active);
    await wait(5);
    active -= 1;
    return i * 2;
  })));
  assert.equal(peak, 4);
  assert.deepEqual(started, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
  assert.deepEqual(results, [0, 2, 4, 6, 8, 10, 12, 14, 16, 18]);
  await assert.rejects(run(() => { throw new Error("boom"); }), /boom/);
  assert.equal(await run(() => "still works"), "still works");
});

/* usability pass */

const VOCAB = {
  kinds: ["strength", "stretch"], patterns: ["squat", "hinge", "mobility"], bodyRegions: ["lower_body", "core"],
  places: ["both", "gym"], levels: ["beginner", "intermediate"],
};
const exRow = (id, extra = {}) => ({
  id, nameEn: id.toUpperCase(), nameAr: "ا", kind: "strength", pattern: "squat", primaryMuscles: ["glutes"],
  secondaryMuscles: [], equipment: ["none"], tags: ["none"], clips: [{ file: `${id}_front_ab.mp4`, angle: "front", seconds: 4 }],
  poster: { file: `${id}_ab.webp` }, ...extra,
});

test("error wording: known codes keep their words, unknown ones show the code", () => {
  assert.equal(L.friendlyMessage("auth/invalid-credential"), "Wrong email or password.");
  assert.equal(L.friendlyMessage("functions/not-found"), "That request is gone. Refresh the list.");
  assert.match(L.friendlyMessage("functions/unavailable"), /can not be reached/);
  assert.equal(L.friendlyMessage("functions/weird"), "Something went wrong (functions/weird). Try again, or tell the owner.");
  assert.equal(L.friendlyMessage(undefined), "Something went wrong. Try again, or tell the owner.");
});

test("server problems lose their developer prefix and read plainly", () => {
  assert.equal(L.plainProblem("hip_x: tag 'none' cannot sit with other tags"), "Safety tags: pick \"none\" on its own, or pick the real tags.");
  assert.equal(L.plainProblem("hip_x: a muscle is both primary and secondary"), "A muscle can be a main muscle or a helping muscle, not both.");
  assert.equal(L.plainProblem("squat: one or 2 clips"), "Add at least one video before saving.");
  assert.equal(L.plainProblem("x_front_ab.mp4 is not uploaded"), "A file (x_front_ab.mp4) is not uploaded yet. Upload the video again.");
  assert.equal(L.plainProblem("the library would be 950000 bytes"), "The library would be 950000 bytes.");
});

test("a storage failure says why, in words, with the code after it", () => {
  const missing = L.storageErrorText({ code: "storage/object-not-found", status_: 404 });
  assert.equal(missing.kind, "missing");
  assert.equal(missing.retry, false);
  assert.match(missing.text, /^Not found in storage\./);
  assert.match(missing.text, /\(storage\/object-not-found, HTTP 404\)$/);
  assert.equal(L.storageErrorText({ code: "storage/unauthorized" }).kind, "denied");
  assert.match(L.storageErrorText({ code: "storage/unauthenticated" }).text, /^Not allowed\./);
  assert.equal(L.storageErrorText({ code: "storage/retry-limit-exceeded" }).kind, "network");
  assert.equal(L.storageErrorText({ code: "storage/unknown", status_: 0 }).kind, "network");
  assert.equal(L.storageErrorText({ name: "TypeError", message: "Failed to fetch" }).kind, "network");
  assert.equal(L.storageErrorText({ code: "storage/unknown" }, false).kind, "network");
  assert.equal(L.storageErrorText({ code: "storage/unknown", status_: 503 }).kind, "server");
  const odd = L.storageErrorText({ code: "storage/something" });
  assert.equal(odd.kind, "unknown");
  assert.equal(odd.text, "Unexpected error while loading the video. (storage/something)");
  assert.equal(L.storageErrorText(null).text, "Unexpected error while loading the video.");
  assert.equal(L.httpStatusOf({ customData: { status: 403 } }), 403);
  assert.ok(L.isRetryableLoad({ code: "storage/retry-limit-exceeded" }));
  assert.ok(!L.isRetryableLoad({ code: "storage/object-not-found" }));
});

test("playback errors map the browser's media codes", () => {
  assert.match(L.playbackErrorText(4), /can not play this file/);
  assert.match(L.playbackErrorText(3), /damaged/);
  assert.match(L.playbackErrorText(2), /Network/);
  assert.equal(L.playbackErrorText(undefined), "This video could not be played.");
  assert.ok(L.SLOW_LOAD_MS >= 5000 && L.SLOW_LOAD_TEXT.includes("slow"));
});

test("the checklist has six items and the filters follow it", () => {
  const good = exRow("a");
  const items = L.exerciseChecklist(good, true, VOCAB);
  assert.deepEqual(items.map((i) => i.key), ["video", "kind", "pattern", "muscles", "tags", "checked"]);
  assert.ok(items.every((i) => i.ok));
  assert.deepEqual(L.exerciseState(good, true, VOCAB).missing, []);
  const unchecked = L.exerciseState(good, false, VOCAB);
  assert.ok(unchecked.needsTags && !unchecked.needsVideo && !unchecked.complete);
  const noClip = L.exerciseState(exRow("b", { clips: [] }), true, VOCAB);
  assert.ok(noClip.needsVideo && !noClip.needsTags);
  const bare = L.exerciseState(exRow("c", { primaryMuscles: [], tags: [], clips: [] }), true, VOCAB);
  assert.deepEqual(bare.missing.sort(), ["muscles", "tags", "video"]);
  assert.ok(bare.needsVideo && bare.needsTags);
  assert.ok(L.exerciseState(exRow("d", { kind: "yoga" }), true, VOCAB).needsTags);
  assert.ok(L.exerciseState(exRow("d", { kind: "yoga" }), true).complete);
});

test("progress counts, text and the filter row", () => {
  const rows = [exRow("a"), exRow("b"), exRow("c", { clips: [] }), exRow("d", { tags: [] })];
  const checked = new Set(["a", "c", "d"]);
  const counts = L.exerciseCounts(rows, (id) => checked.has(id), VOCAB);
  assert.deepEqual(counts, { total: 4, complete: 1, tags: 2, video: 1, all: 4 });
  assert.equal(L.progressText(counts), "1 of 4 complete");
  assert.equal(L.progressFraction(counts), 0.25);
  assert.equal(L.progressFraction({ total: 0, complete: 0 }), 0);
  const names = (filter, query = "") => L.filterExercises(rows, { filter, query, isChecked: (id) => checked.has(id), vocab: VOCAB }).map((r) => r.id);
  assert.deepEqual(names("tags"), ["b", "d"]);
  assert.deepEqual(names("video"), ["c"]);
  assert.deepEqual(names("complete"), ["a"]);
  assert.deepEqual(names("all"), ["a", "b", "c", "d"]);
  assert.deepEqual(names("all", "glutes"), ["a", "b", "c", "d"]);
  assert.deepEqual(names("all", "zzz"), []);
  assert.deepEqual(L.EX_FILTERS.map((f) => f.label), ["Needs tags", "Needs video", "Complete", "All"]);
});

test("next to review and the walk through a queue", () => {
  const rows = [exRow("b"), exRow("a"), exRow("c")];
  const done = new Set(["a"]);
  assert.equal(L.firstToReview(rows, (id) => done.has(id), VOCAB), "b");
  assert.equal(L.firstToReview(rows, () => true, VOCAB), null);
  const queue = ["a", "b", "c", "d"];
  assert.equal(L.neighbour(queue, "b", 1), "c");
  assert.equal(L.neighbour(queue, "a", -1), null);
  assert.equal(L.neighbour(queue, "d", 1), null);
  assert.equal(L.neighbour(queue, "zz", 1), null);
  assert.deepEqual(L.queuePosition(queue, "c"), { index: 2, number: 3, total: 4 });
  assert.equal(L.queuePosition(queue, "zz"), null);
  const finished = new Set(["a", "b", "c"]);
  assert.equal(L.nextUnfinished(queue, "b", (id) => finished.has(id)), "d");
  assert.equal(L.nextUnfinished(queue, "d", (id) => id === "b" || id === "c" || id === "d"), "a");
  assert.equal(L.nextUnfinished(queue, "a", () => true), null);
  assert.equal(L.nextUnfinished(["x"], "x", () => false), null);
});

test("ids come from names and avoid the ones in use", () => {
  assert.equal(L.exerciseId("Lat pulldown, wide grip"), "lat_pulldown_wide_grip");
  assert.equal(L.exerciseId("  Plank!! "), "plank");
  assert.equal(L.exerciseId("لا"), "");
  assert.equal(L.exerciseId("Plank", ["plank", "plank_2"]), "plank_3");
  assert.ok(L.exerciseId("x".repeat(100)).length <= 56);
});

test("none excludes the other tags and picking a real tag drops none", () => {
  assert.deepEqual(L.toggleExclusive(["jumping", "high_impact"], "none", true), ["none"]);
  assert.deepEqual(L.toggleExclusive(["none"], "jumping", true), ["jumping"]);
  assert.deepEqual(L.toggleExclusive(["jumping"], "high_impact", true), ["jumping", "high_impact"]);
  assert.deepEqual(L.toggleExclusive(["jumping", "high_impact"], "jumping", false), ["high_impact"]);
  assert.deepEqual(L.toggleExclusive(["none"], "none", false), []);
});

test("exercise problems mirror the server and name their field", () => {
  const form = L.formFromRow(exRow("a"), true);
  assert.deepEqual(L.exerciseProblems(form), []);
  const fields = (patch, opts) => L.exerciseProblems({ ...form, ...patch }, opts).map((p) => p.field);
  assert.deepEqual(fields({ name_en: "  " }), ["name_en"]);
  assert.deepEqual(fields({ name_ar: "a — b" }), ["name_ar"]);
  assert.deepEqual(fields({ name_en: "x".repeat(301) }), ["name_en"]);
  assert.deepEqual(fields({ kind: "stretch" }), ["pattern"]);
  assert.deepEqual(fields({ pattern: "mobility" }), ["pattern"]);
  assert.deepEqual(fields({ kind: "stretch", pattern: "mobility" }), []);
  assert.deepEqual(fields({ primaryMuscles: [] }), ["primaryMuscles"]);
  assert.deepEqual(fields({ secondaryMuscles: ["glutes"] }), ["secondaryMuscles"]);
  assert.deepEqual(fields({ equipment: ["none", "mat"] }), ["equipment"]);
  assert.deepEqual(fields({ contraindicationTags: [] }), ["contraindicationTags"]);
  assert.deepEqual(fields({ contraindicationTags: ["none", "jumping"] }), ["contraindicationTags"]);
  assert.deepEqual(fields({ clips: [] }), ["clips"]);
  assert.deepEqual(fields({ isNew: true, exerciseId: "Bad Id" }), ["exerciseId"]);
  assert.deepEqual(fields({ isNew: true, exerciseId: "a" }, { taken: ["a"] }), ["exerciseId"]);
  assert.deepEqual(fields({ isNew: true, exerciseId: "fresh" }, { taken: ["a"] }), []);
  assert.match(L.exerciseProblems({ ...form, secondaryMuscles: ["glutes"] })[0].message, /glutes can not be both/);
});

test("a new exercise starts with no safety tag chosen and a checked tick", () => {
  const f = L.blankExercise({ ...VOCAB });
  assert.deepEqual(f.contraindicationTags, []);
  assert.deepEqual(f.equipment, ["none"]);
  assert.equal(f.isNew, true);
  assert.equal(f.checked, true);
  assert.equal(f.kind, "strength");
});

test("the form round trip keeps the row, and the save payload drops local fields", () => {
  const row = exRow("a", { setupEn: "Stand tall.", setupAr: "اقفي" });
  const f = L.formFromRow(row, true);
  assert.equal(f.exerciseId, "a");
  assert.deepEqual(f.contraindicationTags, ["none"]);
  assert.equal(f.setup_en, "Stand tall.");
  const payload = L.savePayload(f);
  assert.ok(!("isNew" in payload) && !("checked" in payload));
  assert.equal(payload.name_en, "A");
  const back = L.rowFromForm({ ...f, name_en: " New name ", contraindicationTags: ["jumping"] }, { clips: [{ file: "a_front_ab.mp4", bytes: 99 }], poster: { file: "a_ab.webp", bytes: 7 } });
  assert.equal(back.nameEn, "New name");
  assert.deepEqual(back.tags, ["jumping"]);
  assert.equal(back.clips[0].bytes, 99);
  assert.equal(back.poster.bytes, 7);
  assert.equal(back.setupEn, "Stand tall.");
  const fresh = L.rowFromForm({ ...f, clips: [{ file: "n.mp4", angle: "side", seconds: 3 }], poster: { file: "n.webp" } }, null);
  assert.equal(fresh.clips[0].bytes, 0);
  assert.equal(fresh.poster.bytes, 0);
});

test("the form signature ignores tick order and spaces but sees real edits", () => {
  const a = L.formFromRow(exRow("a", { primaryMuscles: ["glutes", "quads"] }), true);
  const same = { ...a, primaryMuscles: ["quads", "glutes"], name_en: " A " };
  assert.equal(L.formSignature(a), L.formSignature(same));
  assert.notEqual(L.formSignature(a), L.formSignature({ ...a, pattern: "hinge" }));
  assert.notEqual(L.formSignature(a), L.formSignature({ ...a, checked: false }));
  assert.notEqual(L.formSignature(a), L.formSignature({ ...a, clips: [] }));
  assert.equal(L.formSignature(null), "");
});

test("every safety tag, kind and pattern in the contract has a plain hint", async () => {
  const { readFile } = await import("node:fs/promises");
  const contract = JSON.parse(await readFile(new URL("../contracts/exercise_library_contract.json", import.meta.url), "utf8"));
  for (const t of contract.contraindicationTags) assert.ok(L.hintFor("tags", t), `tag ${t}`);
  for (const k of contract.kinds) assert.ok(L.hintFor("kind", k), `kind ${k}`);
  for (const p of contract.patterns) assert.ok(L.hintFor("pattern", p), `pattern ${p}`);
  for (const text of [...Object.values(L.TAG_HINTS), ...Object.values(L.PATTERN_HINTS), ...Object.values(L.KIND_HINTS)]) {
    assert.ok(!/[–—]/.test(text), "no long dashes");
  }
  assert.equal(L.hintFor("tags", "nope"), "");
});

test("her ticks are read back safely from the browser's storage", () => {
  const set = new Set(["b", "a"]);
  assert.equal(L.serializeChecked(set), '["a","b"]');
  assert.deepEqual([...L.parseChecked('["a","b",3]')], ["a", "b"]);
  assert.equal(L.parseChecked("not json").size, 0);
  assert.equal(L.parseChecked(null).size, 0);
  assert.equal(L.parseChecked('{"a":1}').size, 0);
});

test("events and foods filter by status and search, and badges stay short", () => {
  const events = [
    { eventId: "e1", titleEn: "Yoga night", titleAr: "يوجا", status: "published", endsAt: "2099-01-01T00:00:00Z" },
    { eventId: "e2", titleEn: "Run club", titleAr: "جري", status: "draft", placeName: "Zamalek", endsAt: "2000-01-01T00:00:00Z" },
    { eventId: "e3", titleEn: "Old", titleAr: "قديم", status: "cancelled" },
  ];
  assert.deepEqual(L.countBy(events, (e) => e.status), { published: 1, draft: 1, cancelled: 1 });
  assert.deepEqual(L.filterEvents(events, { status: "draft" }).map((e) => e.eventId), ["e2"]);
  assert.deepEqual(L.filterEvents(events, { query: "zamalek" }).map((e) => e.eventId), ["e2"]);
  assert.deepEqual(L.filterEvents(events, { status: "published", query: "run" }), []);
  assert.deepEqual(L.filterEvents(events).map((e) => e.eventId), ["e1", "e2", "e3"]);
  assert.equal(L.upcomingEvents(events, Date.parse("2026-10-21")), 1);
  const foods = [{ key: "k1", nameEn: "Koshari", nameAr: "كشري", items: [{ name: "Lentils", grams: 100 }] }, { key: "k2", nameEn: "Foul", items: [] }];
  assert.deepEqual(L.filterFoods(foods, "lentil").map((f) => f.key), ["k1"]);
  assert.equal(L.filterFoods(foods, "").length, 2);
  assert.equal(L.badgeText(0), "");
  assert.equal(L.badgeText(7), "7");
  assert.equal(L.badgeText(250), "99+");
});

/* private coaching helpers */

test("coaching tabs follow the claim", () => {
  assert.equal(L.PAYMENTS_LIVE, false);
  assert.deepEqual(L.coachingTabsFor({ womanReviewer: true }), ["coaches", "reports"]);
  assert.deepEqual(L.coachingTabsFor({ finance: true }), []);
  assert.deepEqual(L.coachingTabsFor({ admin: true }), ["coaches", "reports"]);
  assert.deepEqual(L.coachingTabsFor({ finance: true }, true), ["payments", "refunds", "payouts"]);
  assert.deepEqual(L.coachingTabsFor({ finance: true, womanReviewer: true }, true), L.COACHING_TABS);
  assert.deepEqual(L.coachingTabsFor({ admin: true }, true), L.COACHING_TABS);
  assert.ok(!L.SECTIONS.includes("payout"));
  assert.deepEqual(L.coachingTabsFor({}), []);
  assert.deepEqual(L.coachingTabsFor(undefined), []);
  assert.equal(L.isAdmin({ womanReviewer: true }), false);
  assert.equal(L.isAdmin({ finance: true }), false);
  assert.equal(L.isAdmin({ admin: true }), true);
});

test("EGP and amount mismatch", () => {
  assert.equal(L.formatEgp(1250), "1,250 EGP");
  assert.equal(L.formatEgp(99.5), "99.50 EGP");
  assert.equal(L.formatEgp("x"), "");
  assert.equal(L.amountMismatch(1000, 1000), false);
  assert.equal(L.amountMismatch(1000, "1000"), false);
  assert.equal(L.amountMismatch(1000, 900), true);
  assert.equal(L.amountMismatch(undefined, 900), false);
});

test("timestamps arrive as ISO text", () => {
  assert.equal(L.toIso("2026-10-01T10:00:00Z"), "2026-10-01T10:00:00Z");
  assert.equal(L.toIso("not a date"), "");
  assert.equal(L.toIso(null), "");
});

test("a next page is appended in the server's order and a repeated row shows once", () => {
  const key = (x) => x.id;
  const first = [{ id: "a" }, { id: "b" }];
  assert.deepEqual(L.appendPage(first, [{ id: "c" }, { id: "d" }], key).map(key), ["a", "b", "c", "d"]);
  assert.deepEqual(L.appendPage(first, [{ id: "b" }, { id: "c" }], key).map(key), ["a", "b", "c"]);
  assert.deepEqual(L.appendPage(first, [], key).map(key), ["a", "b"]);
  assert.deepEqual(first.map(key), ["a", "b"]);
});

test("flag and reason labels", () => {
  assert.equal(L.flagLabel("duplicateReference"), "Reference already used");
  assert.equal(L.flagLabel("newFlag"), "new flag");
  assert.deepEqual(L.PROOF_REJECT_REASONS, ["amount_wrong", "not_received", "unreadable", "wrong_account", "duplicate", "other"]);
  assert.deepEqual(L.SECTION_REASONS, ["missing", "unclear", "unverifiable", "not_allowed", "other"]);
});

test("coaching errors speak in short staff words", () => {
  assert.equal(L.coachingMessage({ code: "functions/failed-precondition", message: "wrong_status" }), "Refresh and try again.");
  assert.equal(L.coachingMessage({ code: "functions/already-exists", details: { reason: "reference_used" } }), "That transfer reference is already attached to another payment.");
  assert.match(L.coachingMessage({ code: "functions/unavailable", message: "x" }), /can not be reached/);
});

test("accounts must be typed twice and match", () => {
  assert.equal(L.retypeMatch("Mona@InstaPay", " mona@instapay "), true);
  assert.equal(L.retypeMatch("٠١٠١٢٣٤٥٦٧٨", "01012345678"), true);
  assert.equal(L.retypeMatch("010 1234 5678", "01012345678"), true);
  assert.equal(L.retypeMatch("a@instapay", "b@instapay"), false);
  assert.equal(L.retypeMatch("", ""), false);
  assert.equal(L.retypeMatch("x", undefined), false);
});

test("receiving accounts form", () => {
  const good = { instapay: { address: "ownhub@instapay", again: "ownhub@instapay", holderName: "Mahmoud Reda", enabled: true }, vodafoneCash: { address: "", again: "", holderName: "", enabled: false } };
  assert.deepEqual(L.receivingProblems(good), []);
  assert.deepEqual(L.receivingPayload(good), { instapay: { address: "ownhub@instapay", holderName: "Mahmoud Reda", enabled: true }, vodafoneCash: { address: "", holderName: "", enabled: false } });
  // Only one rail on is a valid save, and the other one goes up empty even if it has leftovers typed in.
  const left = structuredClone(good);
  left.vodafoneCash = { address: "0101234567", again: "", holderName: "Old name", enabled: false };
  assert.deepEqual(L.receivingProblems(left), []);
  assert.deepEqual(L.receivingPayload(left).vodafoneCash, { address: "", holderName: "", enabled: false });
  const onlyVodafone = structuredClone(good);
  onlyVodafone.instapay = { address: "", again: "", holderName: "", enabled: false };
  onlyVodafone.vodafoneCash = { address: "01012345678", again: "01012345678", holderName: "Mona Ali", enabled: true };
  assert.deepEqual(L.receivingProblems(onlyVodafone), []);
  assert.deepEqual(L.receivingPayload(onlyVodafone), { instapay: { address: "", holderName: "", enabled: false }, vodafoneCash: { address: "01012345678", holderName: "Mona Ali", enabled: true } });
  const mismatch = structuredClone(good);
  mismatch.instapay.again = "other@instapay";
  assert.equal(L.receivingProblems(mismatch).length, 1);
  const badFormat = structuredClone(good);
  badFormat.vodafoneCash = { address: "0123", again: "0123", holderName: "A", enabled: true };
  assert.ok(L.receivingProblems(badFormat).some((p) => p.startsWith("Vodafone Cash")));
  const none = structuredClone(good);
  none.instapay.enabled = false;
  assert.ok(L.receivingProblems(none).some((p) => /at least one/.test(p)));
  const noHolder = structuredClone(good);
  noHolder.instapay.holderName = " ";
  assert.equal(L.receivingProblems(noHolder).length, 1);
});

test("seller details form", () => {
  const form = Object.fromEntries(L.SELLER_FIELDS.map(([k]) => [k, "x"]));
  form.vatRatePercent = "١٤";
  form.supportEmail = "help@own-hub.app";
  form.supportPhone = "٠١٠١٢٣٤٥٦٧٨";
  assert.deepEqual(L.sellerProblems(form), []);
  const p = L.sellerPayload(form);
  assert.equal(p.vatRatePercent, 14);
  assert.equal(p.supportPhone, "010 12345678".replace(" ", ""));
  assert.equal(L.sellerProblems({ ...form, vatRatePercent: "150" }).length, 1);
  assert.equal(L.sellerProblems({ ...form, supportEmail: "nope" }).length, 1);
  assert.equal(L.sellerProblems({}).length, L.SELLER_FIELDS.length - 1);
});

test("holder name match tolerates spacing, case and Arabic letter forms", () => {
  assert.equal(L.namesMatch("Mona  Ali", "mona ali"), true);
  assert.equal(L.namesMatch("أحمد", "احمد"), true);
  assert.equal(L.namesMatch("Mona Ali", "Mona Hassan"), false);
  assert.equal(L.namesMatch("", ""), false);
});

test("application decisions", () => {
  assert.equal(L.canApproveApplication([]), false);
  assert.equal(L.canApproveApplication(["c1"]), true);
  assert.equal(L.applicationDecisionProblems("approve", {}).length, 0);
  assert.equal(L.applicationDecisionProblems("reject", {}).length, 1);
  assert.equal(L.applicationDecisionProblems("reject", { personal: "" }).length, 1);
  assert.equal(L.applicationDecisionProblems("needs_changes", { personal: "missing" }).length, 0);
  assert.deepEqual(L.applicationPayload("u1", "approve", { ticked: ["c1"], reasons: { personal: "missing" }, note: " ok " }), { uid: "u1", decision: "approve", reasons: {}, checkedCertificates: ["c1"], note: "ok" });
  assert.deepEqual(L.applicationPayload("u1", "needs_changes", { ticked: ["c1"], reasons: { personal: "missing", bogus: "x", payout: "nonsense" }, note: "" }), { uid: "u1", decision: "needs_changes", reasons: { personal: "missing" }, checkedCertificates: [], note: "" });
});

test("file kinds", () => {
  assert.equal(L.fileKind("a/b/cert.PDF"), "pdf");
  assert.equal(L.fileKind("a/b/x", "application/pdf"), "pdf");
  assert.equal(L.fileKind("a/b/x.jpeg"), "image");
  assert.equal(L.fileKind("a/b/x", "image/png"), "image");
  assert.equal(L.fileKind("a/b/x.doc"), "other");
});

test("payout state and report decisions and badges", () => {
  assert.equal(L.payoutNeedsConfirm({ payoutState: "pending", pendingPayout: { account: "x" } }), true);
  assert.equal(L.payoutNeedsConfirm({ payoutState: "pending" }), true);
  assert.equal(L.payoutNeedsConfirm({ payoutState: "confirmed", pendingPayout: { account: "x" } }), true);
  assert.equal(L.payoutNeedsConfirm({ payoutState: "confirmed" }), false);
  assert.deepEqual(L.reportDecisionsFor("coachMessage"), ["dismiss", "hide_message", "suspend_coach", "end_coaching"]);
  assert.deepEqual(L.reportDecisionsFor("coachProfile"), ["dismiss", "suspend_coach", "end_coaching"]);
  assert.equal(L.payoutBadgeCount([{ amountEgp: 5 }, { amountEgp: 0 }, { amountEgp: 0, payoutState: "pending" }]), 2);
  assert.equal(L.payoutBadgeCount([]), 0);
});

test("the open report state is the one the server names", () => {
  assert.equal(L.REPORT_STATE_OPEN, "submitted");
});

test("seller form round trip and server limits", () => {
  const saved = { companyNameEn: "Own Hub LLC", companyNameAr: "أون هب", addressEn: "1 Street, Cairo", addressAr: "١ شارع القاهرة", commercialRegistration: "12345", taxCard: "678-90", vatRatePercent: 14, supportEmail: "help@own-hub.app", updatedAt: "x" };
  const form = L.sellerToForm(saved);
  assert.equal(form.vatRatePercent, "14");
  assert.equal(form.supportPhone, "");
  assert.deepEqual(L.sellerProblems(form), []);
  assert.equal(L.sellerPayload(form).vatRatePercent, 14);
  assert.equal(L.sellerProblems({ ...form, vatRatePercent: "15" }).length, 1);
  assert.equal(L.sellerProblems({ ...form, vatRatePercent: "7.5" }).length, 1);
  assert.deepEqual(L.sellerToForm(null), Object.fromEntries(L.SELLER_FIELDS.map(([k]) => [k, ""])));
});

const contract = JSON.parse(readFileSync(new URL("../contracts/coaching_contract.json", import.meta.url), "utf8"));
const sorted = (xs) => [...xs].sort();

test("every enum and reason the dashboard maps is in the contract, and none is missing", () => {
  const same = (name, mine, theirs) => assert.deepEqual(sorted(mine), sorted(theirs), name);
  same("application sections", Object.keys(L.SECTION_LABELS), contract.enums.applicationSections);
  same("section reasons", L.SECTION_REASONS, contract.enums.sectionReasons);
  same("application statuses", L.APPLICATION_STATUSES, contract.enums.applicationStatus);
  same("proof reject reasons", L.PROOF_REJECT_REASONS, contract.enums.proofRejectReasons);
  same("proof flags", Object.keys(L.PROOF_FLAG_LABELS), contract.enums.proofFlags);
  same("report decisions", L.REPORT_DECISIONS, contract.enums.reportDecision);
  same("report reasons", Object.keys(L.REPORT_REASON_LABELS), contract.enums.reportReasons);
  same("report kinds", Object.keys(L.REPORT_KIND_LABELS), contract.enums.reportSubjectKinds);
  same("coach rules", Object.keys(L.COACH_RULE_LABELS), contract.enums.coachRules);
  same("rails", Object.keys(L.RAIL_LABELS), Object.keys(contract.rails));
  for (const [rail, p] of Object.entries(contract.rails)) {
    assert.equal(L.RAIL_PATTERNS[rail].account.source, p.accountPattern, rail);
    assert.equal(L.RAIL_PATTERNS[rail].reference.source, p.referencePattern, rail);
  }
});

test("every reason the dashboard words is a contract reason, and staff_is_subject is worded", () => {
  const known = new Set(contract.reasons);
  for (const reason of Object.keys(L.COACHING_REASON_TEXT)) assert.ok(known.has(reason), reason);
  assert.equal(L.coachingMessage({ details: { reason: "staff_is_subject" } }), "You cannot decide your own case.");
});

test("accepted rules read as readable labels", () => {
  assert.deepEqual(L.acceptedRuleLabels(["accurateInfo", "noOffPlatformPayment"]), [L.COACH_RULE_LABELS.accurateInfo, L.COACH_RULE_LABELS.noOffPlatformPayment]);
  assert.deepEqual(L.acceptedRuleLabels(["mystery"]), ["mystery"]);
  assert.deepEqual(L.acceptedRuleLabels(undefined), []);
});

test("portfolio queue is for a woman reviewer only", () => {
  assert.equal(L.canDecidePortfolio({ womanReviewer: true }), true);
  assert.equal(L.canDecidePortfolio({ admin: true }), false);
  assert.equal(L.canDecidePortfolio({ finance: true }), false);
  assert.equal(L.canDecidePortfolio(undefined), false);
});

test("portfolio paths follow the kind", () => {
  assert.deepEqual(L.portfolioPaths({ kind: "transformation", beforePath: "b", afterPath: "a" }), ["b", "a"]);
  assert.deepEqual(L.portfolioPaths({ kind: "transformation", beforePath: "b" }), ["b"]);
  assert.deepEqual(L.portfolioPaths({ kind: "feedback", imagePath: "i" }), ["i"]);
  assert.deepEqual(L.portfolioPaths({ kind: "feedback", imagePath: null }), []);
  assert.deepEqual(L.portfolioPaths({ kind: "photo", imagePath: "p" }), ["p"]);
  assert.deepEqual(L.portfolioPaths({ kind: "other", imagePath: "p" }), []);
  assert.deepEqual(L.portfolioPaths(undefined), []);
});

test("portfolio decisions need a reason only to reject, and carry the coach", () => {
  const item = { coachUid: "c1", mediaId: "m1" };
  assert.deepEqual(L.PORTFOLIO_REJECT_REASONS, ["unclear", "not_allowed", "no_consent", "other"]);
  assert.deepEqual(L.portfolioRejectProblems("approve", ""), []);
  assert.deepEqual(L.portfolioRejectProblems("reject", ""), ["Pick a reason."]);
  assert.deepEqual(L.portfolioRejectProblems("reject", "mystery"), ["Pick a reason."]);
  assert.deepEqual(L.portfolioRejectProblems("reject", "no_consent"), []);
  assert.deepEqual(L.portfolioDecisionPayload(item, "approve", "unclear"), { coachUid: "c1", mediaId: "m1", decision: "approve", reason: "" });
  assert.deepEqual(L.portfolioDecisionPayload(item, "reject", "unclear"), { coachUid: "c1", mediaId: "m1", decision: "reject", reason: "unclear" });
  assert.equal(L.portfolioKey(item), "c1/m1");
});

test("signed agreement: who may decide, the reason, the payload and the badge", () => {
  assert.equal(L.canDecideAgreement({ womanReviewer: true }), true);
  assert.equal(L.canDecideAgreement({ admin: true }), true);
  assert.equal(L.canDecideAgreement({ finance: true }), false);
  assert.equal(L.canDecideAgreement(undefined), false);
  assert.deepEqual(L.agreementRejectProblems("verify", ""), []);
  assert.deepEqual(L.agreementRejectProblems("reject", "  "), ["Write the reason. She reads it."]);
  assert.equal(L.agreementRejectProblems("reject", "x".repeat(201)).length, 1);
  assert.deepEqual(L.agreementRejectProblems("reject", "The signature is cut off."), []);
  assert.deepEqual(L.agreementPayload({ uid: "c1" }, "verify", "ignored"), { uid: "c1", decision: "verify", reason: "" });
  assert.deepEqual(L.agreementPayload({ uid: "c1" }, "reject", " Blurry. "), { uid: "c1", decision: "reject", reason: "Blurry." });
  assert.equal(L.coachesBadgeCount(2, 3, 4), 9);
  assert.equal(L.coachesBadgeCount(2, 3, 4, 5), 14);
});

test("badge adds applications and photos; portfolio refusals are worded", () => {
  assert.equal(L.coachesBadgeCount(2, 3), 5);
  assert.equal(L.coachesBadgeCount(0, undefined), 0);
  assert.equal(L.coachingMessage({ details: { reason: "staff_is_subject" } }), "You cannot decide your own case.");
  assert.equal(L.coachingMessage({ details: { reason: "media_not_found" } }), L.COACHING_REASON_TEXT.media_not_found);
  assert.equal(L.coachingMessage({ details: { reason: "too_many_media" } }), L.COACHING_REASON_TEXT.too_many_media);
});

test("undoing a removed pre-approved number asks the server to restore it and confirms nothing itself", () => {
  const request = L.restorePhonesRequest(["+201001234567"]);
  assert.deepEqual(request, { restore: ["+201001234567"] });
  assert.equal("adultSeen" in request, false);
  assert.equal("add" in request, false);
});

test("an old number with no recorded 18+ tick is marked, a confirmed one is not", () => {
  assert.match(L.phoneAgeNote("+201001234567", ["+201001234567"]), /18\+ tick again/);
  assert.equal(L.phoneAgeNote("+201009999999", ["+201001234567"]), "");
  assert.equal(L.phoneAgeNote("+201001234567", undefined), "");
});

test("marketing videos: who decides, the reason, the payload, the month list and who is short", () => {
  assert.equal(L.canDecidePromo({ womanReviewer: true }), true);
  assert.equal(L.canDecidePromo({ admin: true }), false);
  assert.equal(L.canDecidePromo(undefined), false);
  assert.deepEqual(L.promoChangesProblems("approve", ""), []);
  assert.deepEqual(L.promoChangesProblems("changes", "  "), ["Write what she should change. She reads it."]);
  assert.equal(L.promoChangesProblems("changes", "x".repeat(201)).length, 1);
  assert.deepEqual(L.promoChangesProblems("changes", "The sound is low."), []);
  const item = { id: "v1", coachUid: "c1" };
  assert.deepEqual(L.promoPayload(item, "approve", "ignored"), { coachUid: "c1", videoId: "v1", decision: "approve", reason: "" });
  assert.deepEqual(L.promoPayload(item, "changes", "  Dark  "), { coachUid: "c1", videoId: "v1", decision: "changes", reason: "Dark" });
  assert.deepEqual(L.promoMonths("2026-02", 4), ["2026-02", "2026-01", "2025-12", "2025-11"]);
  assert.deepEqual(L.promoMonths("bad"), []);
  assert.equal(L.promoShort({ approved: 1, target: 2 }), true);
  assert.equal(L.promoShort({ approved: 2, target: 2 }), false);
  assert.equal(L.promoShort({}), true);
  assert.equal(L.promoCountLine({ approved: 1, target: 2, waiting: 1, changes: 0 }), "1 of 2 approved, 1 waiting");
  assert.equal(L.promoCountLine({ approved: 0, target: 2, waiting: 0, changes: 2 }), "0 of 2 approved, 2 to change");
  assert.equal(L.fileKind("coach-docs/c/promo/a.mp4"), "video");
  assert.equal(L.fileKind("x", "video/quicktime"), "video");
  assert.equal(L.coachingMessage({ details: { reason: "file_not_uploaded" } }), "That video is not in storage.");
});
