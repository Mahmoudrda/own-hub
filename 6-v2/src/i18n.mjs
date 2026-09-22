// Renders the Arabic version of any screen: swap the text, flip the layout.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const dictPath = path.join(here, '../i18n/ar.json');
export const dict = fs.existsSync(dictPath) ? JSON.parse(fs.readFileSync(dictPath, 'utf8')) : null;
export const hasArabic = () => !!dict;

const missing = new Map();
export const missingReport = () => [...missing.entries()].sort((a, b) => b[1] - a[1]);

// Directional icons that must mirror in right-to-left.
export const RTL_CSS = `[dir="rtl"] svg[data-icon="arrow_back"],[dir="rtl"] svg[data-icon="arrow_forward"],[dir="rtl"] svg[data-icon="chevron_right"],[dir="rtl"] svg[data-icon="chevron_left"],[dir="rtl"] svg[data-icon="send"],[dir="rtl"] svg[data-icon="play_arrow"],[dir="rtl"] svg[data-icon="skip_next"],[dir="rtl"] svg[data-icon="swap_horiz"]{transform:scaleX(-1)}`;

const skip = /^[\s·—–\-|/\\()[\]{}<>+*%.,;:!?]*$/;

export function toArabic(html) {
  if (!dict) return null;
  let out = html.replace(/>([^<>]+)</g, (whole, txt) => {
    const v = txt.replace(/\s+/g, ' ').trim();
    if (!v || skip.test(v)) return whole;
    if (/^[؀-ۿ\s\d.,:؟!،+]+$/.test(v)) return whole; // already Arabic
    const hit = dict[v];
    if (!hit) { missing.set(v, (missing.get(v) || 0) + 1); return whole; }
    return `>${hit}<`;
  });
  // the phone frame itself becomes right-to-left
  out = out.replace('width:390px;height:844px;', 'width:390px;height:844px;direction:rtl;');
  return out;
}

// Arabic sits 2px larger with more line height, per the type rules.
export const AR_FONT_CSS = `[dir="rtl"] .screen-wrap,[dir="rtl"] .ar-screen{font-feature-settings:"liga" 1}`;
