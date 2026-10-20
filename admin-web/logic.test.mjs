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
