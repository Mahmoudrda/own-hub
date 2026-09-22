import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '../assets/fonts');
let css = null;
export function fontCss() {
  if (css) return css;
  const faces = JSON.parse(fs.readFileSync(path.join(dir, 'rubik.json'), 'utf8'));
  css = faces.map(f => `@font-face{font-family:'Rubik';font-style:normal;font-weight:${f.weight};font-display:swap;src:url(data:font/woff2;base64,${fs.readFileSync(path.join(dir, f.file)).toString('base64')}) format('woff2');unicode-range:${f.range};}`).join('\n');
  return css;
}
export const fontSizeKB = () => Math.round(fontCss().length / 1024);
