// Pulls every visible string out of the built screens so they can be translated.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { all } from './all-screens.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const counts = new Map();
const skip = /^[\s·—–\-|/\\()[\]{}<>+*%.,;:!?]*$/;

for (const s of all) {
  // text nodes only: strip tags, keep what a person would read
  const text = s.html.replace(/<style[\s\S]*?<\/style>/g, '').split(/<[^>]+>/g);
  for (const raw of text) {
    const v = raw.replace(/\s+/g, ' ').trim();
    if (!v || skip.test(v)) continue;
    if (/^[؀-ۿ\s\d.,:؟!،]+$/.test(v)) continue; // already Arabic
    counts.set(v, (counts.get(v) || 0) + 1);
  }
}
const rows = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
fs.writeFileSync(path.join(here, '../i18n/strings.json'), JSON.stringify(rows.map(([s, n]) => ({ s, n })), null, 1));
console.log('unique strings:', rows.length, '| total occurrences:', rows.reduce((a, b) => a + b[1], 0));
console.log('longest:', rows.filter(r => r[0].length > 90).length, '| short labels (<25 chars):', rows.filter(r => r[0].length < 25).length);
