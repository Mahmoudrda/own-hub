// Builds i18n/ar.json from the Arabic sources in i18n/msa/ (the folder keeps
// its old name; the app's Arabic is polished Egyptian since 2026-10-12, with
// legal and consent wording still in Modern Standard Arabic),
// then reports what the current screens still need.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, '../i18n');
const msaDir = path.join(dir, 'msa');

const dict = {};
const files = fs.existsSync(msaDir) ? fs.readdirSync(msaDir).filter(f => f.endsWith('.json')).sort() : [];
for (const f of files) Object.assign(dict, JSON.parse(fs.readFileSync(path.join(msaDir, f), 'utf8')));
const extra = path.join(dir, 'ar-extra.json');
if (fs.existsSync(extra)) Object.assign(dict, JSON.parse(fs.readFileSync(extra, 'utf8')));
fs.writeFileSync(path.join(dir, 'ar.json'), JSON.stringify(dict, null, 1));

const strings = JSON.parse(fs.readFileSync(path.join(dir, 'strings.json'), 'utf8'));
const arabicOnly = /^[؀-ۿ\s0-9.,:!+]+$/;
// A parameterised entry covers the concrete string the mockup renders.
// "We sent six digits to {phone}." in the dictionary and "…to +20 100 555 0132."
// on screen are the same message; reporting the rendered form as missing would
// mean this can never reach zero once a string is parameterised.
const placeholderRe = /\{[A-Za-z_]\w*\}/;
const asRegex = (t) => new RegExp('^' + t
  .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  .replace(/\\\{[A-Za-z_]\w*\\\}/g, '.+') + '$');
const parameterised = Object.keys(dict).filter(k => placeholderRe.test(k)).map(asRegex);
const covered = (v) => (v in dict) || parameterised.some(re => re.test(v));
const needed = strings.filter(x => !arabicOnly.test(x.s));
const missing = needed.filter(x => !covered(x.s));
console.log('source files:', files.length, '| dictionary entries:', Object.keys(dict).length);
console.log('strings on screens now:', needed.length, '| covered:', needed.length - missing.length, '| missing:', missing.length);
missing.forEach(x => console.log('   MISSING |', x.s));
