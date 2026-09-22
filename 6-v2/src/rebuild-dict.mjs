// One-off: turn the index-keyed Arabic batches into a key-keyed dictionary.
// The indexes referred to the FIRST extraction; keys survive any re-extraction.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, '../i18n');
const listFile = process.argv[2];

const printable = (line) => [...line].filter(ch => ch.charCodeAt(0) >= 32).join('');
const byIndex = new Map();
for (const raw of fs.readFileSync(listFile, 'utf8').split('\n')) {
  const line = printable(raw);
  const cut = line.indexOf('|');
  if (cut < 1) continue;
  const head = line.slice(0, cut);
  if (!/^[0-9]+$/.test(head)) continue;
  byIndex.set(Number(head), line.slice(cut + 1));
}
console.log('source strings recovered from the original list:', byIndex.size);

const base = {};
let mapped = 0, orphan = 0;
for (const file of fs.readdirSync(dir).filter(f => /^ar-part[0-9]+\.json$/.test(f)).sort()) {
  for (const [idx, ar] of JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'))) {
    const en = byIndex.get(idx);
    if (!en) { orphan++; continue; }
    base[en] = ar;
    mapped++;
  }
}
fs.writeFileSync(path.join(dir, 'ar-base.json'), JSON.stringify(base, null, 1));
console.log('key-based dictionary written:', mapped, 'pairs ·', orphan, 'indexes with no source');
for (const k of ['Coaching', 'Meals for today', 'Period day 2', 'Publish plan', 'Weekly review']) {
  console.log('  check |', JSON.stringify(k), '->', JSON.stringify(base[k]));
}
