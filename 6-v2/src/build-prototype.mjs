// Builds the clickable prototype: one self-contained page.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { all, flows } from './all-screens.mjs';
import { features, areas } from './features.mjs';
import { brief } from './brief.mjs';
import { fontCss } from './fonts.mjs';
import { toArabic, hasArabic, RTL_CSS, missingReport } from './i18n.mjs';
import * as K from './kit.mjs';
import { C, F } from './tokens.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, '../prototype');
fs.mkdirSync(OUT, { recursive: true });

const research = [
  ['Entry is the problem, not duration', '141 food journalers and 5,526 forum posts: the failures are entry barriers, negative nudges and social features.', 'Cordeiro et al., CHI 2015', 'Cut decisions, not seconds. The app writes the entry and she agrees to it.'],
  ['Frequency beats completeness', 'Logging frequency tracked weight loss; time per day fell from 23.2 to 14.6 minutes over six months.', 'Harvey et al., Obesity 2019', 'A half-logged day is a logged day. No screen asks her to finish one.'],
  ['A missed day does not break a habit', 'Missing one opportunity cost under half a point of automaticity and recovered quickly; habits took 18–254 days.', 'Lally et al., EJSP 2010', 'A missed day is never displayed. The week is the unit of consistency.'],
  ['Broken streaks are the damage', 'Intact streaks raise engagement; the loss is worst when she blames herself, and repair softens it.', 'Silverman & Barasch, JCR 2023', 'Weeks, automatic rest weeks, outward attribution, and a total that never falls.'],
  ['Gamification works, modestly — and lasts', 'Hedges g 0.33–0.48, about +500 to +2,183 steps a day, sustained at follow-up rather than novelty.', 'Mazeas et al., JMIR 2022', 'Points stay, sized as an aid: only goal-moving behaviour earns them, capped daily.'],
  ['Two Phase 1 claims did not survive', '"Passive logging backfires" could not be verified anywhere, and "gamification fades after six months" is contradicted above.', 'unverified · contradicted', 'Detected walks are allowed — as a proposal she confirms with one tap.'],
  ['The card decides, not the face', "Egypt's 14-digit national ID number encodes sex in the 13th digit and carries date of birth.", 'Egyptian National Identity Card', 'The gate is a government record. The selfie only proves the card is hers.'],
  ['Appearance-based gates lose in court', 'A women-only app excluded a member on "gender-related appearance"; in May 2026 Australia\'s Full Federal Court called it direct discrimination and doubled damages.', 'Tickle v Giggle, appeal 2026', 'No AI face-gender classification anywhere in the product.'],
  ['Who can actually do this here', 'Valify is Egyptian and licensed, checking against the National Registry; uqudo covers the Egyptian ID with passive liveness and face match.', 'Valify · uqudo', 'Valify first, uqudo as fallback and for passports.'],
  ['The law lands in October 2026', 'The PDPL Executive Regulations arrived 1 November 2025: biometric processing needs explicit consent and a licence, after a one-year grace period.', 'Law 151/2020 · Decree 816/2025', 'Explicit consent before the ID step; images deleted; only the result kept.'],
];

const system = [
  ['Weekly goal — the only streak', 'Her goal is 2–4 sessions a week, set during setup. A week counts when she meets it, or logs food on four days. Every four counted weeks earns a rest week, capped at two, used automatically.'],
  ['Points — an immediate yes', 'Session 15 · planned session +5 · personal best 10 · food logged today 5 · protein goal 5 · week counted 30. Capped at 50 a day. Nothing for opening the app, posting or inviting.'],
  ['Levels — everything she has done', 'Points add up to levels that never drop. Early levels come fast; every fifth level opens something she can use.'],
  ['Tiers — how steady she is now', 'First steps (1 counted week) · Showing up (4) · Regular (10 + 3 bests) · Strong (20 + 10 bests) · Unshakeable (40 + 20 bests).'],
  ['Keeping and losing a tier', 'A tier holds while four of the last eight weeks count. Below that she slips one tier — never more — and one counted week brings it back. Unlocks are never removed.'],
  ['Personal bests — against herself', 'More reps at a weight, more weight for the reps, a longer hold, or a harder version. A 3 kg dumbbell counts like a 30 kg barbell. Recalled sessions never set one.'],
];

const swatches = [['primary', C.primary, '#fff'], ['primaryContainer', C.primaryContainer, C.onPrimaryContainer], ['tertiary', C.tertiary, '#fff'], ['tertiaryContainer', C.tertiaryContainer, C.onTertiaryContainer], ['amber', C.amber, '#fff'], ['error', C.error, '#fff'], ['surface', C.surface, C.onSurface], ['surfaceContainer', C.surfaceContainer, C.onSurface], ['onSurface', C.onSurface, '#fff'], ['onSurfaceVariant', C.onSurfaceVariant, '#fff'], ['outlineVariant', C.outlineVariant, C.onSurface], ['inverseSurface', C.inverseSurface, '#fff']];
const componentSamples = [
  ['Primary button', K.btn('Start — everything\'s ready', { h: 56 })],
  ['Tonal', K.btn('Count it', { v: 'tonal', h: 48 })],
  ['Chips — how values change', K.chipRow(['Small', 'Medium', 'Large'], 1, { grow: false })],
  ['Week segments', K.segs(3, 2)],
  ['Progress', K.linear(64)],
  ['Snackbar with undo', K.snackbar('Set 2 saved · 12 kg × 10')],
  ['List row', K.listItem({ lead: K.icon('restaurant', { size: 24, color: C.primaryDim }), title: 'Koshari bowl and salad', sub: 'Your plate · 600 kcal', trail: K.logBtn(true) })],
  ['Sage card — protective', K.card(K.strong('Your 14 weeks are safe', 'titleM') + K.m('A rest week covered last week.'), { v: 'sage' })],
];
const motion = [['Screen push', 'Slide 24px and fade', '320ms'], ['Tab switch', 'Cross-fade; the nav pill slides', '220ms'], ['Bottom sheet', 'Slide up, scrim fades', '320ms'], ['Set logged', 'Button presses, check springs in, rest ring starts', '220ms'], ['Meal logged', 'Slot fills, protein bar animates, snackbar rises', '460ms'], ['Points and level', 'Points count up, then the level bar fills', '460ms'], ['Finished', 'The one confetti burst in the product', '900ms'], ['Reduced motion', 'Everything becomes instant', '0ms']];

const scenarios = [
  ['New user', 'No records at all. Setup is optional and the normal app still works.', 'C04'],
  ['Period with low energy', '16 September, period day 2, low energy and mild cramps. A gentler option is offered.', 'Y03'],
  ['Same period, feeling good', 'Same dates, high energy, no cramps — the usual strength session stays.', 'Y14'],
  ['Severe symptoms', 'Severe cramps replace the workout suggestion with medical guidance.', 'Y11'],
  ['Irregular or on contraception', 'Logged dates and symptom-led cards, with no phase and no forecast.', 'Y14'],
  ['Prepare and publish', 'Coach fills 30 days, previews gaps, and publishes to Nour.', 'W08'],
  ['Start without searching', 'Client taps Start on Home and lands in the assigned session.', 'G06'],
  ['Eat and log', 'Planned lunch logged, then corrected to the portion she actually ate.', 'G11'],
  ['Cycle support while coached', 'An easier option is taken; with sharing off the coach sees only the change.', 'W02'],
  ['Chat with context', 'A workout is attached, a voice note is previewed, the plan update lands as a card.', 'G14'],
  ['Weekly review', 'Review submitted, answered, and a future plan revision published.', 'G13'],
  ['Empty and ended', 'The subscription ends: history stays readable, coaching actions close.', 'G16'],
];

const UI_AR = {
  'Walkthrough': 'الشاشات', 'Features': 'المميزات', 'Brief': 'الملخص', 'Design system': 'نظام التصميم',
  'Research': 'البحث', 'Build notes': 'ملاحظات التنفيذ', 'Screens': 'الشاشات', 'Back': 'رجوع',
  'Show taps': 'إظهار مواضع الضغط', 'Taps shown': 'مواضع الضغط ظاهرة', 'Features here': 'المميزات هنا',
  'Goes to': 'ينتقل إلى', 'Scenarios': 'سيناريوهات', 'Women-only fitness · Egypt': 'لياقة للنساء فقط · مصر',
  'Supporting screen — no feature of its own.': 'شاشة مساعدة — بلا ميزة خاصة بها.',
};

const data = {
  scenarios,
  ui: UI_AR,
  flows: flows.map(f => ({ ...f, screens: all.filter(s => s.flow === f.id).map(s => s.id) })),
  screens: all.map(s => ({ id: s.id, title: s.title, flow: s.flow, metric: s.metric, note: s.note, html: s.html, htmlAr: toArabic(s.html), links: [...new Set([...s.html.matchAll(/data-go="([^"]+)"/g)].map(m => m[1]).filter(Boolean))] })),
  features, areas, brief, research, system, swatches, motion,
  componentSamples: componentSamples.map(([n, h]) => ({ n, h })),
  state: [
    ['Profile', 'goal, days, session length, place, equipment, allergies, language'],
    ['Verification', 'result, method, date, reviewer path — never the ID images'],
    ['Cycle setup', 'mode, context flags, adaptation toggles, sharing switches'],
    ['Period entry', 'start, end or still bleeding, edited-at'],
    ['Daily check-in', 'energy, cramps, appetite, sleep, bloating, bleeding — all nullable, per day'],
    ['Weekly goal', 'sessions target, counted weeks, rest weeks banked, current run'],
    ['Workout log', 'session, assignment version, per-set actual weight and reps, skipped, duration'],
    ['Meal log', 'slot, item, servings, time, source (planned, search, voice, photo)'],
    ['Coaching relationship', 'coach, subscription dates, service hours, status, sharing choices'],
    ['Plan', 'version, draft or published, dated assignments, approved alternatives'],
    ['Review', 'due date, answers, coach response, linked plan revision'],
    ['Conversation', 'messages, attachment references, send and read state'],
  ],
  rules: [
    'A prescribed value is never a result. Actual entries start empty.',
    'A plan revision applies to future dates; a running session and existing logs keep their version.',
    'Logging twice on the same planned meal corrects the log; a second helping is a separate action.',
    'Suggestions come from today\'s check-in, never from an inferred cycle phase.',
    'Severe symptoms suppress the training suggestion and show the support state.',
    'Sharing switches are independent, default off, and revoke the coach\'s panels when turned off.',
    'Undo windows are five seconds. There are no confirmation dialogs for logging.',
  ],
  simulated: [
    'Identity verification (Valify or uqudo), including the woman-reviewer queue',
    'Push notifications and the one-a-day meal nudge with a lock-screen action',
    'Walk and workout detection via Health Connect and HealthKit',
    'Voice notes: recording, upload, playback, Arabic transcription for food',
    'Photo handling with on-device face blur before upload',
    'Payments (card, mobile wallet, Fawry) and coach payouts',
    'Video delivery with download-for-offline and low-data mode',
    'The moderation queue and the one-hour response promise',
  ],
};

const page = `<meta charset="utf-8">
<title>Women-Only Fitness Prototype</title>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&display=swap">
<style>
${fontCss()}
:root{
  --bg:#F4EAED; --panel:#FFFFFF; --panel-2:#FBF3F5; --ink:#241A1E; --ink-2:#6B5C61; --line:#E8D8DD;
  --accent:#B4526E; --accent-soft:#FFD9E3; --accent-ink:#4A1C2E; --sage:#4F7359; --amber:#8A5A17;
  --shadow:0 10px 40px rgba(36,26,30,.10); --radius:18px;
}
:root:not([data-theme="light"]){@media (prefers-color-scheme: dark){
  :root{--bg:#191114; --panel:#241A1E; --panel-2:#2E2226; --ink:#FFECF0; --ink-2:#C3ADB4; --line:#3B2C32;
  --accent:#FFB0C8; --accent-soft:#4A1C2E; --accent-ink:#FFD9E3; --shadow:0 10px 40px rgba(0,0,0,.45);}
}}
:root[data-theme="dark"]{--bg:#191114; --panel:#241A1E; --panel-2:#2E2226; --ink:#FFECF0; --ink-2:#C3ADB4; --line:#3B2C32;
  --accent:#FFB0C8; --accent-soft:#4A1C2E; --accent-ink:#FFD9E3; --shadow:0 10px 40px rgba(0,0,0,.45);}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:'Rubik',system-ui,sans-serif;font-size:15px;line-height:1.5}
h1,h2,h3{font-family:'Bricolage Grotesque','Rubik',system-ui,sans-serif;font-weight:700;margin:0;text-wrap:balance;letter-spacing:-.01em}
.top{position:sticky;top:env(safe-area-inset-top,0px);z-index:20;background:color-mix(in srgb,var(--bg) 88%,transparent);backdrop-filter:blur(12px);border-bottom:1px solid var(--line)}
.top-in{max-width:1560px;margin:0 auto;padding:12px 16px;display:flex;align-items:center;gap:16px;flex-wrap:wrap}
.brand{font-family:'Bricolage Grotesque','Rubik',sans-serif;font-weight:700;font-size:18px;letter-spacing:-.02em;display:flex;align-items:center;gap:10px}
.dot{width:26px;height:26px;border-radius:9px;background:var(--accent);display:grid;place-items:center;color:#fff;font-size:13px}
.tabs{display:flex;gap:4px;flex-wrap:wrap;margin-left:auto}
.tab{appearance:none;border:0;background:transparent;color:var(--ink-2);font:inherit;font-weight:500;padding:8px 14px;border-radius:999px;cursor:pointer}
.tab[aria-selected="true"]{background:var(--accent-soft);color:var(--accent-ink);font-weight:600}
.tab:focus-visible,.chip:focus-visible,.scr:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
main{max-width:1560px;margin:0 auto;padding:20px 16px 64px}
.walk{display:grid;grid-template-columns:260px minmax(0,1fr) 320px;gap:20px;align-items:start}
@media (max-width:1180px){.walk{grid-template-columns:240px minmax(0,1fr)}.side-r{grid-column:1/-1}}
@media (max-width:820px){.walk{grid-template-columns:1fr}}
.card{background:var(--panel);border:1px solid var(--line);border-radius:var(--radius);padding:16px}
.side h3{font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-2);margin-bottom:8px;font-weight:600;font-family:'Rubik',sans-serif}
.chapter{margin-bottom:14px}
.chapter-t{display:flex;align-items:center;justify-content:space-between;gap:8px;font-weight:600;font-size:14px;margin-bottom:6px}
.chapter-n{font-size:12px;color:var(--ink-2)}
.scr{display:block;width:100%;text-align:left;appearance:none;border:0;background:transparent;color:var(--ink-2);font:inherit;font-size:14px;padding:6px 10px;border-radius:10px;cursor:pointer}
.scr:hover{background:var(--panel-2);color:var(--ink)}
.scr[aria-current="true"]{background:var(--accent-soft);color:var(--accent-ink);font-weight:600}
.scr .id{font-family:'IBM Plex Mono',ui-monospace,monospace;font-size:11px;opacity:.7;margin-right:8px}
.stage{display:flex;flex-direction:column;align-items:center;gap:14px}
.stage-bar{display:flex;align-items:center;gap:8px;flex-wrap:wrap;justify-content:center}
.btn{appearance:none;border:1px solid var(--line);background:var(--panel);color:var(--ink);font:inherit;font-size:14px;font-weight:500;padding:8px 14px;border-radius:999px;cursor:pointer;display:inline-flex;align-items:center;gap:6px}
.btn:hover{border-color:var(--accent)}
.btn.on{background:var(--accent-soft);color:var(--accent-ink);border-color:transparent;font-weight:600}
.device{position:relative;width:412px;max-width:100%;padding:11px;border-radius:48px;background:linear-gradient(160deg,#3a2b31,#241A1E);box-shadow:var(--shadow)}
.screen-wrap{position:relative;width:390px;height:844px;border-radius:36px;overflow:hidden;background:#FFF8F9}
@media (max-width:520px){.device{width:100%;padding:8px;border-radius:40px}.screen-wrap{width:100%;height:760px}}
.screen-wrap>div{animation:enter .32s cubic-bezier(.2,0,0,1)}
@keyframes enter{from{opacity:0;transform:translateX(18px)}to{opacity:1;transform:none}}
.back-anim>div{animation:enterBack .32s cubic-bezier(.2,0,0,1)}
@keyframes enterBack{from{opacity:0;transform:translateX(-18px)}to{opacity:1;transform:none}}
.hot [data-go]{outline:2px dashed color-mix(in srgb,#B4526E 55%,transparent);outline-offset:1px;border-radius:8px}
[data-go]{cursor:pointer}
.meta-t{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.pill{display:inline-flex;align-items:center;height:24px;padding:0 10px;border-radius:999px;background:var(--accent-soft);color:var(--accent-ink);font-size:12px;font-weight:600;font-family:'IBM Plex Mono',monospace}
.note{color:var(--ink-2);font-size:14px;line-height:1.6;margin-top:10px}
.feat{display:flex;gap:8px;align-items:flex-start;padding:8px 0;border-top:1px solid var(--line)}
.feat .fid{font-family:'IBM Plex Mono',monospace;font-size:11px;color:var(--ink-2);padding-top:3px}
.grid{display:grid;gap:14px}
.g2{grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
.g3{grid-template-columns:repeat(auto-fit,minmax(240px,1fr))}
.g4{grid-template-columns:repeat(auto-fit,minmax(200px,1fr))}
table{width:100%;border-collapse:collapse;font-size:14px}
th{text-align:left;font-weight:600;color:var(--ink-2);font-size:12px;letter-spacing:.06em;text-transform:uppercase;padding:10px 12px;border-bottom:1px solid var(--line)}
td{padding:11px 12px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
.tbl-wrap{overflow-x:auto}
.tag{display:inline-flex;height:22px;align-items:center;padding:0 9px;border-radius:999px;font-size:12px;font-weight:600}
.tag.launch{background:#DDEDE1;color:#2F5238}.tag.soon{background:#FBEBD6;color:#7A4E12}.tag.later{background:var(--panel-2);color:var(--ink-2)}
:root[data-theme="dark"] .tag.launch,:root:not([data-theme="light"]) .tag.launch{filter:none}
.swatch{border-radius:12px;overflow:hidden;border:1px solid var(--line)}
.swatch .c{height:56px;display:grid;place-items:center;font-size:12px;font-weight:600;font-family:'IBM Plex Mono',monospace}
.swatch .n{padding:6px 10px;font-size:12px;background:var(--panel-2);color:var(--ink-2)}
.sample{background:#FFF8F9;border:1px solid #EBDCDF;border-radius:14px;padding:14px;color:#241A1E}
.sample-l{font-size:12px;color:#6B5C61;margin-bottom:8px;font-weight:600}
.lede{color:var(--ink-2);font-size:16px;line-height:1.65;max-width:70ch}
.sec{margin:26px 0 12px}
.kv{display:flex;justify-content:space-between;gap:16px;padding:9px 0;border-bottom:1px solid var(--line);font-size:14px}
.q{color:var(--ink-2);font-size:13px}
.bar{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.chip{appearance:none;border:1px solid var(--line);background:transparent;color:var(--ink-2);font:inherit;font-size:13px;padding:6px 12px;border-radius:999px;cursor:pointer}
.chip.on{background:var(--accent-soft);color:var(--accent-ink);border-color:transparent;font-weight:600}
@media (prefers-reduced-motion:reduce){.screen-wrap>div,.back-anim>div{animation:none}}
</style>
<div class="top"><div class="top-in">
  <div class="brand"><span class="dot">♀</span> Women-only fitness · Egypt</div>
  <div class="tabs" role="tablist">
    <button class="tab" role="tab" data-tab="walk" aria-selected="true">Walkthrough</button>
    <button class="tab" role="tab" data-tab="features" aria-selected="false">Features</button>
    <button class="tab" role="tab" data-tab="brief" aria-selected="false">Brief</button>
    <button class="tab" role="tab" data-tab="system" aria-selected="false">Design system</button>
    <button class="tab" role="tab" data-tab="research" aria-selected="false">Research</button>
    <button class="tab" role="tab" data-tab="build" aria-selected="false">Build notes</button>
  </div>
</div></div>
<main>
  <section id="walk"></section>
  <section id="features" hidden></section>
  <section id="brief" hidden></section>
  <section id="system" hidden></section>
  <section id="research" hidden></section>
  <section id="build" hidden></section>
</main>
<script id="data" type="application/json">${JSON.stringify(data).replace(/</g, '\\u003c')}</script>
<script>
const D = JSON.parse(document.getElementById('data').textContent);
const byId = Object.fromEntries(D.screens.map(s => [s.id, s]));
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;');
let state = { screen: 'C01', tab: 'walk', hot: true, stack: [], lang: 'en' };
const T = (en) => state.lang === 'ar' && D.ui[en] ? D.ui[en] : en;
const isAr = () => state.lang === 'ar';

function chapters() {
  return D.flows.map(f => \`<div class="chapter"><div class="chapter-t"><span>\${f.title}</span><span class="chapter-n">\${f.screens.length}</span></div>
    \${f.screens.map(id => \`<button class="scr" data-screen="\${id}" aria-current="\${id === state.screen}"><span class="id">\${id}</span>\${esc(byId[id].title)}</button>\`).join('')}</div>\`).join('');
}
function featuresFor(id) {
  return D.features.filter(f => f.screens.includes(id));
}
function renderWalk() {
  const s = byId[state.screen];
  const feats = featuresFor(s.id);
  document.getElementById('walk').innerHTML = \`<div class="walk">
    <aside class="side card" style="max-height:80vh;overflow:auto"><h3>\${T('Scenarios')}</h3>
      <div style="display:flex;flex-direction:column;gap:4px;margin-bottom:16px">\${D.scenarios.map(function (sc) { return '<button class="scr" data-screen="' + sc[2] + '" title="' + esc(sc[1]) + '">' + esc(sc[0]) + '</button>'; }).join('')}</div>
      <h3>\${T('Screens')}</h3>\${chapters()}</aside>
    <div class="stage">
      <div class="stage-bar">
        <button class="btn" id="back">← \${T('Back')}</button>
        <button class="btn \${state.hot ? 'on' : ''}" id="hot">\${state.hot ? T('Taps shown') : T('Show taps')}</button>
        <button class="btn \${isAr() ? 'on' : ''}" id="lang">\${isAr() ? 'English' : 'العربية'}</button>
        <span class="q">\${s.links.length} tappable link\${s.links.length === 1 ? '' : 's'} on this screen</span>
      </div>
      <div class="device"><div class="screen-wrap \${state.hot ? 'hot' : ''}" id="stage" dir="\${isAr() ? 'rtl' : 'ltr'}">\${isAr() && s.htmlAr ? s.htmlAr : s.html}</div></div>
    </div>
    <aside class="side-r card">
      <div class="meta-t"><h2 style="font-size:19px">\${s.id} · \${esc(s.title)}</h2></div>
      <div class="meta-t" style="margin-top:8px"><span class="pill">\${esc(s.metric)}</span></div>
      <p class="note">\${esc(s.note)}</p>
      <h3 style="margin-top:16px">\${T('Features here')}</h3>
      \${feats.length ? feats.map(f => \`<div class="feat"><span class="fid">\${f.id}</span><div><strong>\${esc(f.name)}</strong><div class="q">\${esc(f.gets)}</div></div></div>\`).join('') : '<div class="q">Supporting screen — no feature of its own.</div>'}
      \${s.links.length ? \`<h3 style="margin-top:16px">\${T('Goes to')}</h3><div style="display:flex;gap:6px;flex-wrap:wrap">\${s.links.map(l => \`<button class="chip" data-screen="\${l}">\${l} · \${esc(byId[l] ? byId[l].title : l)}</button>\`).join('')}</div>\` : ''}
    </aside></div>\`;
}
function renderFeatures() {
  const rel = ['Launch', 'Soon after', 'Later'];
  document.getElementById('features').innerHTML = \`<h1>Feature list</h1>
    <p class="lede">\${D.features.length} features, grouped the way she meets them. \${D.features.filter(f=>f.release==='Launch').length} are needed at launch. Tap a screen code to open that screen in the walkthrough.</p>
    \${D.areas.map(a => \`<div class="sec"><h2 style="font-size:20px;margin-bottom:8px">\${esc(a)}</h2><div class="card" style="padding:0"><div class="tbl-wrap"><table>
      <thead><tr><th></th><th>Feature</th><th>What she gets</th><th>Who</th><th>When</th><th>Screens</th></tr></thead>
      <tbody>\${D.features.filter(f => f.area === a).map(f => \`<tr><td class="q" style="font-family:'IBM Plex Mono',monospace">\${f.id}</td><td><strong>\${esc(f.name)}</strong></td><td>\${esc(f.gets)}</td><td class="q">\${f.who}</td><td><span class="tag \${f.release === 'Launch' ? 'launch' : f.release === 'Soon after' ? 'soon' : 'later'}">\${f.release}</span></td>
      <td>\${f.screens.map(x => \`<button class="chip" data-screen="\${x}" style="margin:2px 2px 0 0">\${x}</button>\`).join('') || '<span class="q">—</span>'}</td></tr>\`).join('')}</tbody></table></div></div></div>\`).join('')}\`;
}
function renderBrief() {
  const b = D.brief;
  document.getElementById('brief').innerHTML = \`<h1>\${esc(b.name)} — product brief</h1>
    <p class="lede">\${esc(b.oneLine)}</p>
    <div class="sec"><h2 style="font-size:20px">Who it is for</h2><div class="grid g4" style="margin-top:10px">\${b.who.map(w => \`<div class="card"><strong>\${esc(w[0])}</strong><p class="q" style="margin:6px 0 0">\${esc(w[1])}</p></div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">The problem she has today</h2><div class="grid g4" style="margin-top:10px">\${b.problem.map(p => \`<div class="card q">\${esc(p)}</div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">The six pillars</h2><div class="grid g3" style="margin-top:10px">\${b.pillars.map(p => \`<div class="card"><strong>\${esc(p[0])}</strong><p class="q" style="margin:6px 0 8px">\${esc(p[1])}</p><div>\${p[2].split(', ').map(x => \`<span class="chip" style="cursor:default;margin:2px 2px 0 0">\${x}</span>\`).join('')}</div></div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Proof to use</h2><div class="grid g3" style="margin-top:10px">\${b.proof.map(p => \`<div class="card"><strong>\${esc(p[0])}</strong><p class="q" style="margin:6px 0 0">\${esc(p[1])}</p></div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Content themes — topics, not scripts</h2><div class="grid g3" style="margin-top:10px">\${b.themes.map(t => \`<div class="card q">\${esc(t)}</div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Guardrails — never in any campaign</h2><div class="grid g2" style="margin-top:10px">\${b.guardrails.map(g => \`<div class="card" style="border-left:3px solid var(--accent)">\${esc(g)}</div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Facts</h2><div class="card" style="margin-top:10px">\${b.facts.map(f => \`<div class="kv"><span class="q">\${esc(f[0])}</span><strong style="text-align:right">\${esc(f[1])}</strong></div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Open — owner decisions</h2><div class="grid g4" style="margin-top:10px">\${b.open.map(o => \`<div class="card" style="border-color:var(--amber)">\${esc(o)}</div>\`).join('')}</div></div>\`;
}
function renderSystem() {
  document.getElementById('system').innerHTML = \`<h1>Design system</h1>
    <p class="lede">Material 3 shapes and colour roles, an Egyptian pink palette, Rubik for Arabic and Latin, and motion that explains rather than decorates. Every text pairing passes WCAG AA.</p>
    <div class="sec"><h2 style="font-size:20px">Colour</h2><div class="grid g4" style="margin-top:10px">\${D.swatches.map(s => \`<div class="swatch"><div class="c" style="background:\${s[1]};color:\${s[2]}">\${s[1]}</div><div class="n">\${s[0]}</div></div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Components</h2><div class="grid g3" style="margin-top:10px">\${D.componentSamples.map(c => \`<div class="sample"><div class="sample-l">\${esc(c.n)}</div>\${c.h}</div>\`).join('')}</div></div>
    <div class="sec"><h2 style="font-size:20px">Motion</h2><div class="card" style="padding:0;margin-top:10px"><div class="tbl-wrap"><table><thead><tr><th>Moment</th><th>What moves</th><th>Duration</th></tr></thead><tbody>\${D.motion.map(m => \`<tr><td><strong>\${esc(m[0])}</strong></td><td class="q">\${esc(m[1])}</td><td class="q">\${esc(m[2])}</td></tr>\`).join('')}</tbody></table></div></div></div>
    <div class="sec"><h2 style="font-size:20px">The progression system</h2><div class="grid g2" style="margin-top:10px">\${D.system.map(s => \`<div class="card"><strong>\${esc(s[0])}</strong><p class="q" style="margin:6px 0 0">\${esc(s[1])}</p></div>\`).join('')}</div></div>\`;
}
function renderResearch() {
  document.getElementById('research').innerHTML = \`<h1>Research</h1>
    <p class="lede">Every claim was checked against the source named under it, and two of the earlier draft's six claims did not survive.</p>
    <div class="grid g2" style="margin-top:14px">\${D.research.map(r => \`<div class="card"><strong>\${esc(r[0])}</strong><p class="q" style="margin:8px 0">\${esc(r[1])}</p>
      <div style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:var(--ink-2)">\${esc(r[2])}</div>
      <p style="margin:10px 0 0;color:var(--sage);font-weight:600">\${esc(r[3])}</p></div>\`).join('')}</div>\`;
}
function renderBuild() {
  var rows = D.state.map(function (r) { return '<tr><td><strong>' + esc(r[0]) + '</strong></td><td class="q">' + esc(r[1]) + '</td></tr>'; }).join('');
  var rules = D.rules.map(function (x) { return '<li>' + esc(x) + '</li>'; }).join('');
  var sim = D.simulated.map(function (x) { return '<li>' + esc(x) + '</li>'; }).join('');
  document.getElementById('build').innerHTML =
    '<h1>Build notes</h1>' +
    '<p class="lede">What a Flutter team needs from this mockup. Tokens, routes and both ARB string files are generated from the same source as these screens, so they cannot drift apart.</p>' +
    '<div class="grid g3" style="margin-top:14px">' +
    '<div class="card"><strong>Material 3</strong><p class="q" style="margin:6px 0 0">useMaterial3, navigation bar with a pill indicator, bottom sheets, snackbars with undo. Rubik covers both scripts; icons are Material Symbols Rounded.</p></div>' +
    '<div class="card"><strong>' + D.screens.length + ' routes</strong><p class="q" style="margin:6px 0 0">One per screen, grouped by flow, generated into app_routes.dart.</p></div>' +
    '<div class="card"><strong>Two locales</strong><p class="q" style="margin:6px 0 0">English and Egyptian Arabic in app_en.arb and app_ar.arb, right-to-left layout, mirrored directional icons, and Western numerals kept inside Arabic text.</p></div>' +
    '</div>' +
    '<div class="sec"><h2 style="font-size:20px">State the screens assume</h2><div class="card" style="padding:0;margin-top:10px"><div class="tbl-wrap"><table><thead><tr><th>Record</th><th>What the screens read</th></tr></thead><tbody>' + rows + '</tbody></table></div></div></div>' +
    '<div class="sec"><h2 style="font-size:20px">Rules that belong in the domain layer</h2><div class="card" style="margin-top:10px"><ol class="q" style="margin:0;padding-left:20px;line-height:1.9">' + rules + '</ol></div></div>' +
    '<div class="sec"><h2 style="font-size:20px">Simulated here, real work later</h2><div class="card" style="margin-top:10px"><ul class="q" style="margin:0;padding-left:20px;line-height:1.9">' + sim + '</ul></div></div>';
}
function show(tab) {
  state.tab = tab;
  for (const el of document.querySelectorAll('.tab')) el.setAttribute('aria-selected', String(el.dataset.tab === tab));
  for (const id of ['walk', 'features', 'brief', 'system', 'research', 'build']) document.getElementById(id).hidden = id !== tab;
  ({ walk: renderWalk, features: renderFeatures, brief: renderBrief, system: renderSystem, research: renderResearch, build: renderBuild })[tab]();
  window.scrollTo({ top: 0, behavior: 'instant' });
}
function goTo(id, push = true) {
  if (!byId[id]) return;
  if (push && id !== state.screen) state.stack.push(state.screen);
  state.screen = id;
  try { location.hash = id; } catch (e) {}
  if (state.tab !== 'walk') show('walk'); else renderWalk();
}
document.addEventListener('click', e => {
  const tab = e.target.closest('.tab'); if (tab) return show(tab.dataset.tab);
  const pick = e.target.closest('[data-screen]'); if (pick) return goTo(pick.dataset.screen);
  if (e.target.closest('#hot')) { state.hot = !state.hot; return renderWalk(); }
  if (e.target.closest('#lang')) { state.lang = state.lang === 'ar' ? 'en' : 'ar'; return renderWalk(); }
  if (e.target.closest('#back')) { const prev = state.stack.pop(); if (prev) goTo(prev, false); return; }
  const hotspot = e.target.closest('#stage [data-go]');
  if (hotspot) { e.preventDefault(); goTo(hotspot.dataset.go); }
});
document.addEventListener('keydown', e => {
  if (e.key === 'ArrowLeft') { const prev = state.stack.pop(); if (prev) goTo(prev, false); }
  if (e.key === 'ArrowRight') { const s = byId[state.screen]; if (s.links[0]) goTo(s.links[0]); }
});
const hash = (location.hash || '').replace('#', '');
if (byId[hash]) state.screen = hash;
show('walk');
</script>`;

fs.writeFileSync(path.join(OUT, 'index.html'), page);
console.log('prototype written:', (page.length / 1024 / 1024).toFixed(2), 'MB · screens', all.length, '· features', features.length);
