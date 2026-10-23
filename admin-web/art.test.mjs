// The line drawings come from a vendored copy of Hairline: the file must be the
// pinned release, and every figure the dashboard asks for must exist in it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const here = new URL(".", import.meta.url);
const read = (name) => readFileSync(new URL(name, here), "utf8");

const PINNED = "16fdfec136dc99cf3f65730989364797f0bbb228b7bca60c4d422e0e12ce3b7d";
const EXPECTED = ["basket", "cabinet", "drawer", "hub", "lockers", "loupe", "padlock", "plot", "plug", "query", "relay", "settle", "sieve", "stack", "vault"];

const exported = new Set(
  read("vendor/hairline/index.d.ts").match(/export \{([^}]*)\}/)[1]
    .split(",").map((s) => s.trim()).filter((s) => s && !s.startsWith("type ")),
);

const sources = ["app.js", "coaching.js"].map(read).join("\n");
const used = new Set([
  ...[...sources.matchAll(/\bart: "([a-z]+)"/g)].map((m) => m[1]),
  ...[...sources.matchAll(/\bmountArt\([^,]+, "([a-z]+)"/g)].map((m) => m[1]),
]);

test("the vendored Hairline file is the pinned v0.5.1 build", () => {
  const sum = createHash("sha256").update(readFileSync(new URL("vendor/hairline/index.js", here))).digest("hex");
  assert.equal(sum, PINNED);
  assert.match(read("vendor/hairline/LICENSE"), /MIT License/);
});

test("every figure the dashboard names exists in the library", () => {
  assert.ok(exported.size > 30, "export list not found in index.d.ts");
  for (const name of used) assert.ok(exported.has(name), name);
  assert.deepEqual([...used].sort(), EXPECTED);
  assert.ok(!used.has("slow"));
});

test("every empty state names its figure", () => {
  const calls = sources.split("\n").filter((line) => /\bsetEmpty\(/.test(line) && !/function setEmpty/.test(line));
  assert.ok(calls.length >= 20, `only ${calls.length} setEmpty calls found`);
  for (const line of calls) assert.match(line, /\bart: "[a-z]+"/, line.trim().slice(0, 80));
});
