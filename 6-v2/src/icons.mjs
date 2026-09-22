import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '../assets/icons');
const cache = new Map();
export const missing = new Set();
export function icon(name, { size = 24, color = 'currentColor', fill = false, extra = '' } = {}) {
  const key = `${name}${fill ? '-fill' : ''}`;
  if (!cache.has(key)) {
    const file = path.join(dir, `${key}.svg`);
    if (!fs.existsSync(file)) { missing.add(key); cache.set(key, null); }
    else cache.set(key, fs.readFileSync(file, 'utf8').replace(/<svg[^>]*>/, '').replace('</svg>', '').trim());
  }
  const p = cache.get(key);
  if (!p) return `<div style="width:${size}px;height:${size}px;border-radius:4px;background:${color};opacity:.25;flex:0 0 auto"></div>`;
  return `<svg data-icon="${name}" viewBox="0 -960 960 960" width="${size}" height="${size}" fill="${color}" style="flex:0 0 auto;display:block${extra ? ';' + extra : ''}">${p}</svg>`;
}
