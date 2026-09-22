// Component kit. Every screen in the product is written with these.
import { C, F, TY, R, E, M } from './tokens.mjs';
import { icon } from './icons.mjs';
export { icon };
export { C, F, TY, R, E, M };

const ty = (k, color = C.onSurface) => { const [s, l, w] = TY[k]; return `font-size:${s}px;line-height:${l}px;font-weight:${w};color:${color}`; };
export const go = (id) => (id ? ` data-go="${id}"` : '');
const cursor = (id) => (id ? ';cursor:pointer' : '');

export const h = (text, k = 'headline', color = C.onPrimaryContainer) => `<div style="${ty(k, color)}">${text}</div>`;
export const t = (text, { k = 'body', color = C.onSurface } = {}) => `<div style="${ty(k, color)}">${text}</div>`;
export const m = (text, k = 'bodyM') => `<div style="${ty(k, C.onSurfaceVariant)}">${text}</div>`;
export const strong = (text, k = 'titleM', color = C.onSurface) => `<div style="${ty(k, color)}">${text}</div>`;
export const rtl = (text, k = 'body') => { const [s, l] = TY[k]; return `<div style="font-size:${s + 2}px;line-height:${Math.round(l * 1.28)}px;color:${C.onSurface};direction:rtl">${text}</div>`; };

export const phone = (inner, { bg = C.surface, layered = false } = {}) => `<div style="width:390px;height:844px;background:${bg};border:1px solid ${C.outlineVariant};border-radius:36px;overflow:hidden;display:flex;flex-direction:column${layered ? ';position:relative' : ''}">${inner}</div>`;
export const statusBar = (time = '9:41', { color = C.onSurface } = {}) => `<div style="height:44px;flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;padding:0 24px"><div style="font-size:14px;font-weight:600;color:${color}">${time}</div><div style="display:flex;align-items:center;gap:7px"><div style="width:16px;height:11px;background:${color};border-radius:2px"></div><div style="width:13px;height:11px;background:${color};border-radius:2px"></div><div style="width:24px;height:12px;border:1.5px solid ${color};border-radius:3px"></div></div></div>`;
export const homeBar = ({ bg = '', color = C.onSurface } = {}) => `<div style="height:34px;flex:0 0 auto;display:flex;align-items:center;justify-content:center${bg ? `;background:${bg}` : ''}"><div style="width:140px;height:5px;border-radius:999px;background:${color};opacity:.9"></div></div>`;

export const appBar = ({ title = '', lead = 'back', leadGo = '', actions = [], bg = 'transparent' } = {}) => {
  const leadIcon = lead === 'back' ? 'arrow_back' : lead === 'close' ? 'close' : '';
  return `<div style="height:64px;flex:0 0 auto;display:flex;align-items:center;gap:4px;padding:0 8px;background:${bg}">`
    + (leadIcon ? `<div style="width:48px;height:48px;border-radius:999px;display:flex;align-items:center;justify-content:center"${go(leadGo)}>${icon(leadIcon, { size: 24, color: C.onSurface })}</div>` : '<div style="width:8px"></div>')
    + `<div style="flex:1;min-width:0;${ty('titleM')};padding-left:4px">${title}</div>`
    + actions.map(a => `<div style="width:48px;height:48px;border-radius:999px;display:flex;align-items:center;justify-content:center"${go(a.go)}>${icon(a.icon, { size: 24, color: a.color || C.onSurfaceVariant })}</div>`).join('')
    + `</div>`;
};

const CLIENT_TABS = [
  { label: 'Home', icon: 'home', go: 'T01' }, { label: 'Train', icon: 'fitness_center', go: 'R01' },
  { label: 'Community', icon: 'groups', go: 'M01' }, { label: 'Eat', icon: 'restaurant', go: 'E01' },
  { label: 'Coaching', icon: 'sports', go: 'H01' },
];
const COACH_TABS = [
  { label: 'Today', icon: 'today', go: 'K07' }, { label: 'Clients', icon: 'group', go: 'W01' },
  { label: 'Chats', icon: 'chat_bubble', go: 'W10' }, { label: 'Earnings', icon: 'payments', go: 'K17' },
];
export const navBar = (active, role = 'client') => {
  const tabs = role === 'client' ? CLIENT_TABS : COACH_TABS;
  return `<div style="flex:0 0 auto;background:${C.surfaceLow};border-top:1px solid ${C.outlineVariant};padding:8px 4px 0;display:grid;grid-template-columns:repeat(${tabs.length},1fr)">`
    + tabs.map(tb => { const on = tb.label === active; return `<div style="height:60px;display:flex;flex-direction:column;align-items:center;gap:4px"${go(on ? '' : tb.go)}>`
      + `<div style="width:56px;height:32px;border-radius:999px;display:flex;align-items:center;justify-content:center;background:${on ? C.primaryContainer : 'transparent'}">${icon(tb.icon, { size: 24, color: on ? C.onPrimaryContainer : C.onSurfaceVariant, fill: on })}</div>`
      + `<div style="${ty('nav', on ? C.onPrimaryContainer : C.onSurfaceVariant)};font-weight:600">${tb.label}</div></div>`; }).join('')
    + `</div>${homeBar({ bg: C.surfaceLow })}`;
};

export const body = (inner, { pad = '4px 16px 0', gap = 10 } = {}) => `<div style="flex:1;min-height:0;box-sizing:border-box;padding:${pad};display:flex;flex-direction:column;gap:${gap}px;overflow:hidden">${inner}</div>`;
export const footer = (inner, { gap = 10, pad = '10px 16px 14px' } = {}) => `<div style="flex:0 0 auto;padding:${pad};display:flex;flex-direction:column;gap:${gap}px">${inner}</div>`;
export const spacer = () => `<div style="flex:1;min-height:0"></div>`;
export const row = (inner, { gap = 12, align = 'center', justify = 'space-between', wrap = false } = {}) => `<div style="display:flex;align-items:${align};justify-content:${justify};gap:${gap}px${wrap ? ';flex-wrap:wrap' : ''}">${inner}</div>`;
export const col = (inner, { gap = 6, grow = false } = {}) => `<div style="display:flex;flex-direction:column;gap:${gap}px${grow ? ';flex:1;min-width:0' : ''}">${inner}</div>`;
export const grid = (inner, { cols = 2, gap = 8 } = {}) => `<div style="display:grid;grid-template-columns:repeat(${cols},minmax(0,1fr));gap:${gap}px">${inner}</div>`;

const CARD_V = {
  outlined: `background:${C.surfaceLowest};border:1px solid ${C.outlineVariant}`,
  filled: `background:${C.surfaceContainer};border:1px solid transparent`,
  tonal: `background:${C.primaryContainer};border:1px solid transparent`,
  sage: `background:${C.tertiaryContainer};border:1px solid transparent`,
  amber: `background:${C.amberContainer};border:1px solid transparent`,
  error: `background:${C.errorContainer};border:1px solid transparent`,
  elevated: `background:${C.surfaceLowest};border:1px solid transparent;box-shadow:${E.e1}`,
  selected: `background:${C.surfaceLowest};border:2px solid ${C.primary}`,
};
export const card = (inner, { v = 'outlined', pad = '16px', gap = 12, r = R.lg, go: g = '', flex = '0 0 auto' } = {}) => `<div style="${CARD_V[v]};border-radius:${r}px;padding:${pad};flex:${flex};display:flex;flex-direction:column;gap:${gap}px${cursor(g)}"${go(g)}>${inner}</div>`;
export const listItem = ({ lead = '', title = '', sub = '', trail = '', go: g = '', v = 'outlined', r = R.md, pad = '12px 14px' } = {}) => `<div style="${CARD_V[v]};border-radius:${r}px;padding:${pad};display:flex;align-items:center;gap:12px;flex:0 0 auto${cursor(g)}"${go(g)}>${lead}<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:3px"><div style="${ty('titleM')}">${title}</div>${sub ? `<div style="${ty('bodyM', C.onSurfaceVariant)}">${sub}</div>` : ''}</div>${trail}</div>`;

export const btn = (label, { v = 'filled', h: ht = 56, icon: ic = '', go: g = '', size = 17 } = {}) => {
  const styles = {
    filled: `background:${C.primary};color:${C.onPrimary};border:none`,
    tonal: `background:${C.primaryContainer};color:${C.onPrimaryContainer};border:none`,
    sage: `background:${C.tertiary};color:${C.onTertiary};border:none`,
    outlined: `background:transparent;color:${C.onSurface};border:1.5px solid ${C.outlineVariant}`,
    text: `background:transparent;color:${C.primaryDim};border:none`,
    white: `background:${C.surfaceLowest};color:${C.onSurface};border:none`,
  }[v];
  return `<div style="height:${ht}px;border-radius:999px;${styles};display:flex;align-items:center;justify-content:center;gap:8px;font-size:${size}px;font-weight:600;flex:0 0 auto${cursor(g)}"${go(g)}>${ic ? icon(ic, { size: 20, color: 'currentColor' }) : ''}${label}</div>`;
};
export const bigBtn = (label, sub, { go: g = '', v = 'filled' } = {}) => `<div style="height:84px;border-radius:26px;background:${v === 'filled' ? C.primary : C.tertiary};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px${cursor(g)}"${go(g)}><div style="font-size:23px;font-weight:600;color:#FFFFFF">${label}</div><div style="font-size:15px;color:#FFFFFF;opacity:.92">${sub}</div></div>`;
export const iconBtn = (name, { d = 48, bg = 'transparent', color = C.onSurfaceVariant, go: g = '', fill = false, size = 24 } = {}) => {
  const hit = Math.max(d, 44); // visual disc stays at d; the tap target never goes below 44
  return `<div style="width:${hit}px;height:${hit}px;flex:0 0 auto;display:flex;align-items:center;justify-content:center${cursor(g)}"${go(g)}><div style="width:${d}px;height:${d}px;border-radius:999px;background:${bg};display:flex;align-items:center;justify-content:center">${icon(name, { size, color, fill })}</div></div>`;
};
export const logBtn = (primary = false, label = 'Log', { go: g = '' } = {}) => `<div style="height:44px;padding:0 18px;flex:0 0 auto;border-radius:999px;background:${primary ? C.primary : C.primarySoft};color:${primary ? C.onPrimary : C.primaryDim};display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600${cursor(g)}"${go(g)}>${label}</div>`;
export const pill = (text, { bg = C.primarySoft, color = C.primaryDim, ic = '' } = {}) => `<div style="height:34px;padding:0 12px;border-radius:999px;background:${bg};display:flex;align-items:center;gap:6px;font-size:14px;font-weight:600;color:${color};flex:0 0 auto">${ic ? icon(ic, { size: 16, color }) : ''}${text}</div>`;
export const chip = (label, { sel = false, ic = '', grow = false, h: ht = 40, go: g = '' } = {}) => `<div style="height:${ht}px;padding:0 14px;border-radius:999px;${sel ? `background:${C.primaryContainer};border:1.5px solid ${C.primary};color:${C.onPrimaryContainer}` : `background:transparent;border:1.5px solid ${C.outlineVariant};color:${C.onSurface}`};display:flex;align-items:center;justify-content:center;gap:6px;font-size:15px;font-weight:500${grow ? ';flex:1' : ';flex:0 0 auto'}${cursor(g)}"${go(g)}>${ic ? icon(ic, { size: 18, color: sel ? C.onPrimaryContainer : C.onSurfaceVariant }) : ''}${label}</div>`;
export const chipRow = (items, sel = -1, { grow = true, h: ht = 40, scroll = false } = {}) => `<div style="display:flex;gap:8px${scroll ? ';overflow:hidden' : ''}">${items.map((x, i) => chip(typeof x === 'string' ? x : x.label, { sel: i === sel || (typeof x === 'object' && x.sel), ic: typeof x === 'object' ? x.ic : '', grow, h: ht, go: typeof x === 'object' ? x.go : '' })).join('')}</div>`;
export const segmented = (items, sel = 0) => `<div style="height:44px;display:flex;border:1.5px solid ${C.outlineVariant};border-radius:999px;overflow:hidden;flex:0 0 auto">${items.map((x, i) => `<div style="flex:1;display:flex;align-items:center;justify-content:center;gap:6px;font-size:15px;font-weight:600;background:${i === sel ? C.primaryContainer : 'transparent'};color:${i === sel ? C.onPrimaryContainer : C.onSurfaceVariant}${i ? `;border-left:1.5px solid ${C.outlineVariant}` : ''}">${i === sel ? icon('check', { size: 18, color: C.onPrimaryContainer }) : ''}${x}</div>`).join('')}</div>`;
export const field = ({ label: lb = '', value = '', helper = '', error = '', focus = false, trail = '' } = {}) => `<div style="display:flex;flex-direction:column;gap:6px;flex:0 0 auto"><div style="height:60px;border-radius:${R.md}px;background:${C.surfaceContainer};border:${focus ? `2px solid ${C.primary}` : error ? `2px solid ${C.error}` : '1.5px solid transparent'};padding:0 16px;display:flex;align-items:center;gap:10px"><div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:1px">${lb ? `<div style="font-size:12px;font-weight:500;color:${error ? C.error : focus ? C.primaryDim : C.onSurfaceVariant}">${lb}</div>` : ''}<div style="font-size:17px;color:${value ? C.onSurface : C.onSurfaceVariant}">${value || ''}</div></div>${trail}</div>${error ? `<div style="${ty('bodyM', C.error)};padding:0 12px">${error}</div>` : helper ? `<div style="${ty('bodyM', C.onSurfaceVariant)};padding:0 12px">${helper}</div>` : ''}</div>`;

export const linear = (pct, { h: ht = 8, c = C.tertiarySoft, bg = C.outlineVariant } = {}) => `<div style="height:${ht}px;border-radius:999px;background:${bg};overflow:hidden;flex:0 0 auto"><div style="width:${pct}%;height:100%;background:${c};border-radius:999px"></div></div>`;
export const segs = (n, filled, { h: ht = 10, c = C.tertiarySoft } = {}) => `<div style="display:flex;gap:6px;flex:0 0 auto">${Array.from({ length: n }, (_, i) => `<div style="flex:1;height:${ht}px;border-radius:999px;background:${i < filled ? c : C.outlineVariant}"></div>`).join('')}</div>`;
export const ringStat = (pct, big, small, { size = 96, c = C.tertiarySoft, track = C.outlineVariant, thickness = 12 } = {}) => `<div style="width:${size}px;height:${size}px;flex:0 0 auto;border-radius:999px;background:conic-gradient(${c} 0 ${pct}%,${track} ${pct}% 100%);display:flex;align-items:center;justify-content:center"><div style="width:${size - thickness * 2}px;height:${size - thickness * 2}px;border-radius:999px;background:${C.surfaceLowest};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px"><div style="font-size:${Math.round(size / 4.2)}px;font-weight:600;color:${C.onSurface};line-height:1">${big}</div><div style="font-size:13px;color:${C.onSurfaceVariant}">${small}</div></div></div>`;
export const weekBars = (weeks) => `<div style="display:flex;gap:5px;align-items:flex-end;flex:0 0 auto">${weeks.map(w => `<div style="flex:1;height:${w === 2 ? 34 : w === 1 ? 28 : 16}px;border-radius:5px;background:${w === 2 ? C.tertiary : w === 1 ? C.tertiarySoft : C.outlineVariant}"></div>`).join('')}</div>`;
export const avatar = (size = 40, { initial = '', bg = C.primaryContainer, color = C.onPrimaryContainer, ic = '' } = {}) => `<div style="width:${size}px;height:${size}px;flex:0 0 auto;border-radius:999px;background:${bg};display:flex;align-items:center;justify-content:center;font-size:${Math.round(size / 2.6)}px;font-weight:600;color:${color}">${ic ? icon(ic, { size: Math.round(size / 1.9), color }) : initial}</div>`;
export const badge = (count) => `<div style="min-width:20px;height:20px;padding:0 6px;border-radius:999px;background:${C.error};color:${C.onError};font-size:12px;font-weight:600;display:flex;align-items:center;justify-content:center;flex:0 0 auto">${count}</div>`;
export const toggle = (on) => `<div style="width:52px;height:32px;flex:0 0 auto;border-radius:999px;background:${on ? C.primary : C.surfaceHighest};border:2px solid ${on ? C.primary : C.outline};display:flex;align-items:center;justify-content:${on ? 'flex-end' : 'flex-start'};padding:0 3px"><div style="width:${on ? 24 : 16}px;height:${on ? 24 : 16}px;border-radius:999px;background:${on ? C.onPrimary : C.outline};${on ? '' : 'margin:0 4px'}"></div></div>`;
export const media = ({ label = 'video', h: ht = 180, r = R.md, ic = 'play_arrow', v = 'video', chipText = '' } = {}) => `<div style="height:${ht}px;border-radius:${r}px;background:${v === 'photo' ? C.surfaceHigh : C.secondaryContainer};display:flex;align-items:center;justify-content:center;position:relative;flex:0 0 auto;overflow:hidden">${ic ? `<div style="width:56px;height:56px;border-radius:999px;background:${C.surfaceLowest};display:flex;align-items:center;justify-content:center;box-shadow:${E.e1}">${icon(ic, { size: 28, color: C.primary, fill: true })}</div>` : ''}<div style="position:absolute;left:10px;bottom:8px;font-family:${F.mono};font-size:12px;color:${C.onSurfaceVariant}">${label}</div>${chipText ? `<div style="position:absolute;right:10px;bottom:8px;height:26px;padding:0 10px;border-radius:999px;background:${C.surfaceLowest};display:flex;align-items:center;font-size:13px;font-weight:600;color:${C.onSurface}">${chipText}</div>` : ''}</div>`;
export const sheet = (inner, { gap = 14, pad = '12px 16px 0' } = {}) => `<div style="position:absolute;inset:0;background:${C.scrim}"></div><div style="position:absolute;left:0;right:0;bottom:0;background:${C.surfaceLowest};border-radius:${R.xl}px ${R.xl}px 0 0;padding:${pad};display:flex;flex-direction:column;gap:${gap}px;box-shadow:${E.e3}"><div style="width:36px;height:4px;border-radius:999px;background:${C.outlineVariant};align-self:center;flex:0 0 auto"></div>${inner}${homeBar()}</div>`;
export const snackbar = (text, { action = 'Undo', go: g = '' } = {}) => `<div style="background:${C.inverseSurface};border-radius:${R.md}px;padding:10px 10px 10px 18px;display:flex;align-items:center;gap:12px;flex:0 0 auto;box-shadow:${E.e2}"><div style="flex:1;font-size:15px;color:${C.inverseOnSurface}">${text}</div>${action ? `<div style="height:40px;padding:0 16px;border-radius:999px;background:${C.surfaceLowest};display:flex;align-items:center;font-size:15px;font-weight:600;color:${C.primaryDim}"${go(g)}>${action}</div>` : ''}</div>`;
export const banner = (text, { v = 'sage', ic = 'check_circle' } = {}) => card(row(`${icon(ic, { size: 22, color: v === 'sage' ? C.tertiary : C.primaryDim })}<div style="flex:1;${ty('bodyM')}">${text}</div>`, { gap: 10, justify: 'flex-start' }), { v, pad: '12px 14px', r: R.md });
export const sageNote = (text) => `<div style="background:${C.tertiaryContainer};border-radius:${R.md}px;padding:12px 14px;${ty('body', C.onTertiaryContainer)};flex:0 0 auto">${text}</div>`;

// ---- wireframe canvas pieces ----
export const note = (title, metric, text) => `<div style="display:flex;flex-direction:column;gap:6px;width:390px"><div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap"><div style="font-size:17px;font-weight:600;color:${C.onPrimaryContainer}">${title}</div>${metric ? `<div style="height:26px;padding:0 10px;border-radius:999px;background:${C.primarySoft};display:flex;align-items:center;font-family:${F.mono};font-size:11px;color:${C.primaryDim}">${metric}</div>` : ''}</div><div style="font-size:15px;line-height:22px;color:${C.onSurfaceVariant}">${text}</div></div>`;
export const screenCol = (phoneHtml, noteHtml, id = '') => `\n      <div style="display:flex;flex-direction:column;gap:16px;width:390px;flex:0 0 auto"${id ? ` data-screen="${id}"` : ''}>\n        ${phoneHtml}\n        ${noteHtml}\n      </div>`;
export const strip = (title, cols) => `\n  <div style="display:flex;flex-direction:column;gap:24px">\n    <div style="font-size:24px;font-weight:600;color:${C.onPrimaryContainer}">${title}</div>\n    <div style="display:flex;gap:36px;align-items:flex-start">${cols.join('')}\n    </div>\n  </div>`;
export const rowHeader = (no, title, lede, maxw = 920) => `\n  <div style="display:flex;flex-direction:column;gap:8px;max-width:${maxw}px">\n    <div style="font-size:14px;font-weight:600;color:${C.primaryDim}">${no}</div>\n    <div style="font-size:38px;font-weight:600;color:${C.onPrimaryContainer};letter-spacing:-.02em">${title}</div>\n    <div style="font-size:16px;line-height:1.65;color:${C.onSurfaceVariant};text-wrap:pretty">${lede}</div>\n  </div>`;
export const panel = (inner, { width = 1560, gap = 32, pad = 40 } = {}) => `\n  <div style="background:${C.surfaceLowest};border:1px solid ${C.outlineVariant};border-radius:24px;padding:${pad}px;width:${width}px;display:flex;flex-direction:column;gap:${gap}px">${inner}\n  </div>`;
export const panelBlock = (title, inner, { gap = 18 } = {}) => `\n    <div style="display:flex;flex-direction:column;gap:${gap}px">\n      <div style="font-size:22px;font-weight:600;color:${C.onPrimaryContainer}">${title}</div>\n      ${inner}\n    </div>`;
export const cellGrid = (cells, n = 3) => `<div style="display:grid;grid-template-columns:repeat(${n},minmax(0,1fr));gap:1px;background:${C.outlineVariant};border:1px solid ${C.outlineVariant};border-radius:16px;overflow:hidden">${cells.join('')}</div>`;
export const cell = (inner, bg = C.surfaceLow) => `<div style="background:${bg};padding:22px;display:flex;flex-direction:column;gap:10px">${inner}</div>`;
export const cellTitle = (text) => `<div style="font-size:15px;font-weight:600;color:${C.primaryDim}">${text}</div>`;
export const cellText = (text, color = C.onSurface, w = 400) => `<div style="font-size:16px;line-height:24px;color:${color};font-weight:${w}">${text}</div>`;
export const cellSo = (text) => cellText(text, C.tertiary, 600);
export const source = (text) => `<div style="font-family:${F.mono};font-size:12px;line-height:18px;color:${C.onSurfaceVariant}">${text}</div>`;
export const kv = (k, v, { last = false } = {}) => `<div style="display:flex;justify-content:space-between;align-items:baseline;gap:16px;padding:9px 0${last ? '' : `;border-bottom:1px solid ${C.outlineVariant}`}"><div style="font-size:16px;line-height:22px;color:${C.onSurface}">${k}</div><div style="font-size:16px;font-weight:600;color:${C.onSurface};text-align:right;flex:0 0 auto">${v}</div></div>`;
export const table = (headers, rows, { widths = [], zebra = true } = {}) => `<div style="border:1px solid ${C.outlineVariant};border-radius:16px;overflow:hidden">`
  + `<div style="display:grid;grid-template-columns:${widths.length ? widths.join(' ') : `repeat(${headers.length},1fr)`};background:${C.surfaceHigh}">${headers.map(x => `<div style="padding:12px 16px;font-size:14px;font-weight:600;color:${C.onPrimaryContainer}">${x}</div>`).join('')}</div>`
  + rows.map((r, i) => `<div style="display:grid;grid-template-columns:${widths.length ? widths.join(' ') : `repeat(${headers.length},1fr)`};background:${zebra && i % 2 ? C.surfaceLow : C.surfaceLowest};border-top:1px solid ${C.outlineVariant}">${r.map(cl => `<div style="padding:12px 16px;font-size:15px;line-height:22px;color:${C.onSurface}">${cl}</div>`).join('')}</div>`).join('')
  + `</div>`;

// ---- social surfaces: stories, feed media, reels, grids, follow-ups ----
// Photographs are stand-ins. Each tone is a different woman's post, so a feed
// reads as a feed instead of a column of identical grey boxes.
export const PHOTO = {
  warm: 'linear-gradient(150deg,#F7DFE7 0%,#E8BACA 48%,#CE93A8 100%)',
  sage: 'linear-gradient(150deg,#DFEEE3 0%,#B7D3C0 48%,#8FB39B 100%)',
  dusk: 'linear-gradient(150deg,#ECDDF1 0%,#CBB5D9 48%,#9F87B4 100%)',
  sand: 'linear-gradient(150deg,#F8EAD8 0%,#E7CEAF 48%,#CCAD86 100%)',
  mint: 'linear-gradient(150deg,#DDEEEC 0%,#B2D4CF 48%,#86AFA9 100%)',
  rose: 'linear-gradient(150deg,#FBE4E4 0%,#F0C0C0 48%,#D79898 100%)',
  night: 'linear-gradient(170deg,#4A3A40 0%,#32262B 55%,#241A1E 100%)',
};

export const shot = (label = '', { h: ht = 220, w = '', r = R.md, tone = 'warm', blurFace = false, play = false, dur = '', tag = '', grow = false, go: g = '' } = {}) =>
  `<div style="position:relative;${w ? `width:${w};` : ''}${grow ? 'flex:1;min-width:0;' : 'flex:0 0 auto;'}height:${ht}px;border-radius:${r}px;background:${PHOTO[tone] || PHOTO.warm};overflow:hidden${cursor(g)}"${go(g)}>`
  + `<div style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(255,255,255,.16),rgba(36,26,30,.10))"></div>`
  + (blurFace ? `<div style="position:absolute;left:50%;top:13%;transform:translateX(-50%);width:${Math.max(26, Math.round(ht * 0.19))}px;height:${Math.max(26, Math.round(ht * 0.19))}px;border-radius:999px;background:rgba(255,255,255,.5);box-shadow:0 0 0 5px rgba(255,255,255,.16)"></div>` : '')
  + (play ? `<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center"><div style="width:54px;height:54px;border-radius:999px;background:rgba(255,255,255,.86);display:flex;align-items:center;justify-content:center">${icon('play_arrow', { size: 28, color: C.primaryDim, fill: true })}</div></div>` : '')
  + (dur ? `<div style="position:absolute;right:8px;top:8px;height:22px;padding:0 8px;border-radius:999px;background:rgba(36,26,30,.55);color:#FFFFFF;font-size:11px;font-weight:600;display:flex;align-items:center">${dur}</div>` : '')
  + (tag ? `<div style="position:absolute;left:8px;top:8px;height:24px;padding:0 9px;border-radius:999px;background:rgba(255,255,255,.92);color:${C.onSurface};font-size:12px;font-weight:600;display:flex;align-items:center">${tag}</div>` : '')
  + (label ? `<div style="position:absolute;left:10px;bottom:8px;font-family:${F.mono};font-size:11px;color:rgba(36,26,30,.58)">${label}</div>` : '')
  + `</div>`;

export const storyRing = (label, { initial = '', seen = false, mine = false, size = 60, tone = 'warm', go: g = '' } = {}) =>
  `<div style="display:flex;flex-direction:column;align-items:center;gap:6px;flex:0 0 auto;width:${size + 12}px${cursor(g)}"${go(g)}>`
  + `<div style="position:relative;width:${size}px;height:${size}px;border-radius:999px;padding:2.5px;background:${seen ? C.outlineVariant : `conic-gradient(from 140deg,${C.primary},${C.amber},${C.tertiary},${C.primary})`};box-sizing:border-box">`
  + `<div style="width:100%;height:100%;border-radius:999px;border:2px solid ${C.surface};box-sizing:border-box;background:${PHOTO[tone]};display:flex;align-items:center;justify-content:center;font-size:${Math.round(size / 2.9)}px;font-weight:600;color:${C.onPrimaryContainer}">${initial}</div>`
  + (mine ? `<div style="position:absolute;right:-1px;bottom:-1px;width:21px;height:21px;border-radius:999px;background:${C.primary};border:2px solid ${C.surface};display:flex;align-items:center;justify-content:center">${icon('add', { size: 13, color: C.onPrimary })}</div>` : '')
  + `</div>`
  + `<div style="font-size:12px;color:${C.onSurfaceVariant};max-width:${size + 12}px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${label}</div></div>`;

export const storiesRail = (items, { pad = '2px 14px 10px' } = {}) => `<div style="display:flex;gap:10px;padding:${pad};overflow:hidden;flex:0 0 auto">${items.join('')}</div>`;

export const followBtn = (state = 'follow', { go: g = '', h: ht = 34, grow = false } = {}) => {
  const v = {
    follow: [`background:${C.primary};color:${C.onPrimary};border:none`, 'Follow'],
    following: [`background:transparent;color:${C.onSurface};border:1.5px solid ${C.outlineVariant}`, 'Following'],
    back: [`background:${C.primaryContainer};color:${C.onPrimaryContainer};border:none`, 'Follow back'],
    requested: [`background:${C.surfaceContainer};color:${C.onSurfaceVariant};border:none`, 'Requested'],
  }[state];
  return `<div style="height:${ht}px;padding:0 16px;border-radius:999px;${v[0]};display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600;${grow ? 'flex:1' : 'flex:0 0 auto'}${cursor(g)}"${go(g)}>${v[1]}</div>`;
};

export const railBtn = (name, label, { fill = false, color = '#FFFFFF', go: g = '', size = 29 } = {}) =>
  `<div style="display:flex;flex-direction:column;align-items:center;gap:3px${cursor(g)}"${go(g)}>${icon(name, { size, color, fill })}<div style="font-size:12px;font-weight:600;color:${color}">${label}</div></div>`;

export const fullMedia = ({ tone = 'dusk', top = '.44', bottom = '.66' } = {}) =>
  `<div style="position:absolute;inset:0;background:${PHOTO[tone]}"></div>`
  + `<div style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(36,26,30,${top}) 0%,rgba(36,26,30,0) 24%,rgba(36,26,30,0) 50%,rgba(36,26,30,${bottom}) 100%)"></div>`;

export const photoGrid = (cells, { cols = 3, gap = 2 } = {}) => `<div style="display:grid;grid-template-columns:repeat(${cols},minmax(0,1fr));gap:${gap}px;flex:0 0 auto">${cells.join('')}</div>`;

export const statCol = (n, label, { go: g = '' } = {}) =>
  `<div style="display:flex;flex-direction:column;align-items:center;gap:1px;flex:1${cursor(g)}"${go(g)}><div style="font-size:18px;font-weight:600;color:${C.onSurface}">${n}</div><div style="font-size:13px;color:${C.onSurfaceVariant}">${label}</div></div>`;

export const iconTabs = (items, sel = 0) =>
  `<div style="display:flex;border-top:1px solid ${C.outlineVariant};flex:0 0 auto">${items.map((it, i) => `<div style="flex:1;height:46px;display:flex;align-items:center;justify-content:center;border-bottom:2px solid ${i === sel ? C.primary : 'transparent'}${cursor(it.go)}"${go(it.go)}>${icon(it.icon, { size: 22, color: i === sel ? C.primary : C.onSurfaceVariant, fill: i === sel })}</div>`).join('')}</div>`;

export const storyBars = (n, active) =>
  `<div style="display:flex;gap:4px">${Array.from({ length: n }, (_, i) => `<div style="flex:1;height:3px;border-radius:999px;background:rgba(255,255,255,.34);overflow:hidden"><div style="width:${i < active ? 100 : i === active ? 45 : 0}%;height:100%;background:#FFFFFF;border-radius:999px"></div></div>`).join('')}</div>`;

// The follow-up strip: one post, revisited. Each frame is a picture she added
// later to the same post, so a single row carries weeks without a comparison score.
export const followUpStrip = (frames, { h: ht = 74, r = R.sm } = {}) =>
  `<div style="display:flex;gap:5px;align-items:flex-end;flex:0 0 auto">`
  + frames.map((f, i) => `${i ? `<div style="width:12px;height:${ht}px;display:flex;align-items:center;justify-content:center;flex:0 0 auto">${icon('arrow_forward', { size: 14, color: C.outline })}</div>` : ''}`
    + `<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:4px">${shot('', { h: ht, r, tone: f.tone, blurFace: f.blur, grow: true, go: f.go || '' })}<div style="font-size:11px;font-weight:600;color:${f.now ? C.primaryDim : C.onSurfaceVariant};text-align:center">${f.label}</div></div>`).join('')
  + `</div>`;

// ---- portfolio builder pieces ----
export const blockItem = ({ ic = 'view_agenda', title = '', sub = '', on = true, go: g = '', drag = true } = {}) =>
  `<div style="background:${C.surfaceLowest};border:1px solid ${C.outlineVariant};border-radius:${R.md}px;padding:10px 12px;display:flex;align-items:center;gap:10px;flex:0 0 auto${cursor(g)}"${go(g)}>`
  + (drag ? icon('drag_handle', { size: 20, color: C.outline }) : '')
  + `<div style="width:34px;height:34px;border-radius:10px;background:${on ? C.primaryContainer : C.surfaceContainer};display:flex;align-items:center;justify-content:center;flex:0 0 auto">${icon(ic, { size: 19, color: on ? C.onPrimaryContainer : C.onSurfaceVariant })}</div>`
  + `<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:1px"><div style="font-size:15px;font-weight:600;color:${on ? C.onSurface : C.onSurfaceVariant}">${title}</div>${sub ? `<div style="font-size:12px;color:${C.onSurfaceVariant}">${sub}</div>` : ''}</div>`
  + icon(on ? 'visibility' : 'visibility_off', { size: 19, color: C.onSurfaceVariant })
  + `</div>`;

// A scaled-down stand-in for her page, so the builder shows shape rather than words.
export const miniSite = (rows, { w = 104, go: g = '' } = {}) =>
  `<div style="width:${w}px;flex:0 0 auto;border-radius:12px;border:1px solid ${C.outlineVariant};background:${C.surfaceLowest};padding:5px;display:flex;flex-direction:column;gap:4px;overflow:hidden${cursor(g)}"${go(g)}>`
  + rows.map(r => {
    if (r.k === 'hero') return `<div style="height:38px;border-radius:7px;background:${PHOTO[r.tone || 'warm']}"></div>`;
    if (r.k === 'text') return `<div style="display:flex;flex-direction:column;gap:2.5px;padding:0 2px">${Array.from({ length: r.n || 3 }, (_, i) => `<div style="height:3.5px;border-radius:2px;background:${C.outlineVariant};width:${[100, 86, 64][i % 3]}%"></div>`).join('')}</div>`;
    if (r.k === 'cards') return `<div style="display:grid;grid-template-columns:repeat(${r.n || 2},1fr);gap:3px">${Array.from({ length: r.n || 2 }, () => `<div style="height:16px;border-radius:5px;background:${C.primarySoft}"></div>`).join('')}</div>`;
    if (r.k === 'grid') return `<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:2px">${Array.from({ length: 6 }, (_, i) => `<div style="height:13px;border-radius:3px;background:${PHOTO[['sage', 'sand', 'rose', 'mint', 'dusk', 'warm'][i]]}"></div>`).join('')}</div>`;
    return `<div style="height:11px;border-radius:5px;background:${C.primary}"></div>`;
  }).join('')
  + `</div>`;

export const swatchRow = (colors, sel = 0, { d = 34 } = {}) =>
  `<div style="display:flex;gap:9px;flex:0 0 auto">${colors.map((c, i) => `<div style="width:${d}px;height:${d}px;border-radius:999px;background:${c};display:flex;align-items:center;justify-content:center;box-shadow:${i === sel ? `0 0 0 2.5px ${C.surfaceLowest},0 0 0 4.5px ${c}` : 'none'};flex:0 0 auto">${i === sel ? icon('check', { size: 17, color: '#FFFFFF' }) : ''}</div>`).join('')}</div>`;

export const typeCard = (name, sample, { sel = false, family = '' } = {}) =>
  `<div style="flex:1;min-width:0;border-radius:${R.md}px;padding:11px 12px;background:${C.surfaceLowest};border:${sel ? `2px solid ${C.primary}` : `1.5px solid ${C.outlineVariant}`};display:flex;flex-direction:column;gap:3px">`
  + `<div style="font-size:19px;font-weight:700;color:${C.onSurface}${family ? `;font-family:${family}` : ''}">${sample}</div>`
  + `<div style="font-size:12px;color:${C.onSurfaceVariant}">${name}</div></div>`;

export const canvasBar = (title, { left = 'arrow_back', leftGo = '', right = [] } = {}) =>
  `<div style="height:56px;flex:0 0 auto;display:flex;align-items:center;gap:4px;padding:0 6px;border-bottom:1px solid ${C.outlineVariant};background:${C.surfaceLowest}">`
  + `<div style="width:44px;height:44px;border-radius:999px;display:flex;align-items:center;justify-content:center${cursor(leftGo)}"${go(leftGo)}>${icon(left, { size: 23, color: C.onSurface })}</div>`
  + `<div style="flex:1;min-width:0;font-size:16px;font-weight:600;color:${C.onSurface}">${title}</div>`
  + right.map(a => a.label
    ? `<div style="height:36px;padding:0 14px;border-radius:999px;background:${a.v === 'filled' ? C.primary : C.primaryContainer};color:${a.v === 'filled' ? C.onPrimary : C.onPrimaryContainer};display:flex;align-items:center;font-size:14px;font-weight:600;flex:0 0 auto;margin-right:6px${cursor(a.go)}"${go(a.go)}>${a.label}</div>`
    : `<div style="width:44px;height:44px;border-radius:999px;display:flex;align-items:center;justify-content:center${cursor(a.go)}"${go(a.go)}>${icon(a.icon, { size: 22, color: C.onSurfaceVariant })}</div>`).join('')
  + `</div>`;

export const sectionHead = (title, action = '', { go: g = '' } = {}) =>
  `<div style="display:flex;align-items:baseline;justify-content:space-between;gap:10px;flex:0 0 auto"><div style="font-size:15px;font-weight:600;color:${C.onSurface}">${title}</div>${action ? `<div style="font-size:14px;font-weight:600;color:${C.primaryDim}${cursor(g)}"${go(g)}>${action}</div>` : ''}</div>`;
