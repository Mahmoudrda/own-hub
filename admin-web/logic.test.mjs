import test from "node:test";
import assert from "node:assert/strict";
import * as L from "./logic.js";

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
