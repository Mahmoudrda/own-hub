// The dashboard is served by Cloudflare Pages, which reads _headers; the admin
// target in firebase.json describes the same site. Both must send the same
// security headers.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const here = new URL(".", import.meta.url);
const firebase = JSON.parse(readFileSync(new URL("../firebase.json", here), "utf8"));
const admin = firebase.hosting.find((h) => h.target === "admin");
const pages = new Map(
  readFileSync(new URL("_headers", here), "utf8")
    .split("\n")
    .filter((line) => line.startsWith("  "))
    .map((line) => {
      const at = line.indexOf(":");
      return [line.slice(0, at).trim(), line.slice(at + 1).trim()];
    }),
);

test("_headers sends every header firebase.json sets for the dashboard", () => {
  const all = admin.headers.find((r) => r.source === "**").headers;
  for (const { key, value } of all) assert.equal(pages.get(key), value, key);
});

test("the dashboard cannot be framed and forces HTTPS", () => {
  assert.equal(pages.get("X-Frame-Options"), "DENY");
  assert.match(pages.get("Content-Security-Policy"), /frame-ancestors 'none'/);
  assert.match(pages.get("Strict-Transport-Security"), /max-age=\d{7,}/);
});

test("every header line fits Cloudflare's 2,000 character limit", () => {
  for (const line of readFileSync(new URL("_headers", here), "utf8").split("\n")) {
    assert.ok(line.length <= 2000, line.slice(0, 60));
  }
});
