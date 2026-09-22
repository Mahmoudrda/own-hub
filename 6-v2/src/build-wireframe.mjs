// Builds the v2 wireframe: one .dc.html artboard per chapter, plus canvas.json.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as K from './kit.mjs';
import { all, flows } from './all-screens.mjs';
import { features, areas } from './features.mjs';
import { brief } from './brief.mjs';
import { C, R, F, TY } from './tokens.mjs';
import { toArabic, hasArabic, RTL_CSS } from './i18n.mjs';

const { rowHeader, panel, panelBlock, cellGrid, cell, cellTitle, cellText, cellSo, source, kv, table, strip, screenCol, note, icon, row, card, btn, chipRow, linear, segs, listItem, snackbar } = K;
const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, '../wireframe');
fs.mkdirSync(path.join(OUT, 'artboards'), { recursive: true });

const doc = (rows) => `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Rubik:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
  body{margin:0;background:${C.canvas};font-family:${F.ui};-webkit-font-smoothing:antialiased;}
  a{color:${C.primaryDim};text-decoration:none;border-bottom:1px solid ${C.outlineVariant}}
  a:hover{color:${C.primary}}
  ${RTL_CSS}
</style>
</helmet>
<div style="padding:72px 80px 140px;display:flex;flex-direction:column;gap:96px;min-width:max-content">${rows.join('\n')}
</div>
</x-dc>
</body>
</html>`;

const artboards = [];
function add(file, title, rows, w, h, page) {
  fs.writeFileSync(path.join(OUT, 'artboards', file), doc(rows));
  artboards.push({ file, title, w, h, page });
}

// ---------- brief ----------
const whoCells = brief.who.map(([t, d]) => cell(cellTitle(t) + cellText(d)));
const problemCells = brief.problem.map(p => cell(cellText(p)));
const pillarCells = brief.pillars.map(([t, d, f]) => cell(cellTitle(t) + cellText(d) + source(f)));
const proofCells = brief.proof.map(([t, d]) => cell(cellTitle(t) + cellText(d)));
const themeCells = brief.themes.map(t => cell(cellText(t)));
const guardCells = brief.guardrails.map(g => {
  const line = `${icon('close', { size: 18, color: C.error })}<div style="flex:1;font-size:16px;line-height:24px;color:${C.onSurface}">${g}</div>`;
  return cell(row(line, { gap: 10, justify: 'flex-start', align: 'flex-start' }), C.surfaceLowest);
});
const openCells = brief.open.map(o => cell(cellText(o), C.amberContainer));
const factRows = brief.facts.map((f, i) => kv(f[0], f[1], { last: i >= brief.facts.length - 2 })).join('');

const briefRows = [
  rowHeader('The product', `${brief.name} — what we are building`, brief.oneLine, 1100),
  panel([
    panelBlock('Who it is for', cellGrid(whoCells, 4)),
    panelBlock('The problem she has today', cellGrid(problemCells, 4)),
    panelBlock('What we promise — the six pillars', cellGrid(pillarCells, 3)),
    panelBlock('Proof the content team can use', cellGrid(proofCells, 5)),
  ].join('')),
  panel([
    panelBlock('Content themes — topics, not scripts. The words stay the founder\'s.', cellGrid(themeCells, 4)),
    panelBlock('Guardrails — never in any campaign', cellGrid(guardCells, 2)),
    panelBlock('Facts', `<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:0 48px">${factRows}</div>`),
    panelBlock('Open — owner decisions before launch', cellGrid(openCells, 4)),
  ].join('')),
];
add('Main.dc.html', 'Brief', briefRows, 1760, 2150, 'page-1');

// ---------- features ----------
function relPill(r) {
  const bg = r === 'Launch' ? C.tertiaryContainer : r === 'Soon after' ? C.amberContainer : C.surfaceHigh;
  const fg = r === 'Launch' ? C.tertiary : r === 'Soon after' ? C.amber : C.onSurfaceVariant;
  return `<span style="display:inline-flex;height:24px;padding:0 10px;border-radius:999px;align-items:center;font-size:13px;font-weight:600;background:${bg};color:${fg}">${r}</span>`;
}
const mono = (x) => `<span style="font-family:${F.mono};font-size:13px;color:${C.onSurfaceVariant}">${x}</span>`;
const featureBlocks = areas.map(area => {
  const rows = features.filter(f => f.area === area).map(f => [mono(f.id), `<strong>${f.name}</strong>`, f.gets, f.who, relPill(f.release), mono(f.screens.join(' ') || '—')]);
  return panelBlock(area, table(['', 'Feature', 'What she gets', 'Who', 'When', 'Screens'], rows, { widths: ['64px', '230px', '1fr', '90px', '120px', '180px'] }));
}).join('');
const counts = { launch: features.filter(f => f.release === 'Launch').length, soon: features.filter(f => f.release === 'Soon after').length, later: features.filter(f => f.release === 'Later').length };
const featureRows = [
  rowHeader('Feature list', `${features.length} features, and when to expect them`, `Everything the product does, grouped the way she meets it: ${counts.launch} at launch, ${counts.soon} soon after, ${counts.later} later. The screens column points at the wireframe, so every feature can be seen rather than imagined.`, 1100),
  panel(featureBlocks, { width: 1760, gap: 28 }),
];
add('Features.dc.html', 'Features', featureRows, 1960, 4900, 'page-1');

// ---------- design system ----------
function swatch(name, hex, on) {
  return `<div style="border-radius:14px;overflow:hidden;border:1px solid ${C.outlineVariant}"><div style="height:64px;background:${hex};display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:600;color:${on}">${hex}</div><div style="padding:8px 10px;background:${C.surfaceLowest};font-size:14px;color:${C.onSurface}">${name}</div></div>`;
}
const swatches = [
  ['primary', C.primary, '#fff'], ['primaryContainer', C.primaryContainer, C.onPrimaryContainer],
  ['tertiary — progress', C.tertiary, '#fff'], ['tertiaryContainer', C.tertiaryContainer, C.onTertiaryContainer],
  ['amber — a win', C.amber, '#fff'], ['error', C.error, '#fff'],
  ['surface', C.surface, C.onSurface], ['surfaceContainer', C.surfaceContainer, C.onSurface],
  ['onSurface', C.onSurface, '#fff'], ['onSurfaceVariant', C.onSurfaceVariant, '#fff'],
  ['outlineVariant', C.outlineVariant, C.onSurface], ['inverseSurface', C.inverseSurface, '#fff'],
].map(s => swatch(s[0], s[1], s[2])).join('');
function typeRow(k, label) {
  const t = TY[k];
  return row(`<div style="width:190px;font-family:${F.mono};font-size:13px;color:${C.onSurfaceVariant}">${t[0]}/${t[1]}/${t[2]}</div><div style="flex:1;font-size:${t[0]}px;line-height:${t[1]}px;font-weight:${t[2]};color:${C.onSurface}">${label}</div>`, { gap: 20, justify: 'flex-start' });
}
const typeRows = [['display', 'One question per screen'], ['headline', 'Screen titles'], ['titleL', 'Card titles'], ['titleM', 'List rows'], ['body', 'Everything she has to read'], ['bodyM', 'Secondary lines'], ['nav', 'Navigation labels only']].map(x => typeRow(x[0], x[1])).join('');
const arabicRow = row(`<div style="width:190px;font-family:${F.mono};font-size:13px;color:${C.onSurfaceVariant}">arabic +2px</div><div style="flex:1;font-size:18px;line-height:31px;color:${C.onSurface};direction:rtl">ابدئي تمرين اليوم — الأرقام تبقى كما هي: +20 100 555 0132</div>`, { gap: 20, justify: 'flex-start' });
const componentSamples = [
  btn('Primary action', { h: 56 }), btn('Tonal', { v: 'tonal', h: 56 }), btn('Outlined', { v: 'outlined', h: 56 }), btn('Text button', { v: 'text', h: 56 }),
  chipRow(['Quiet', 'No equipment', '10 min'], 0, { grow: false }), segs(3, 2), linear(64), snackbar('Set 2 saved · 12 kg × 10'),
  listItem({ lead: icon('restaurant', { size: 24, color: C.primaryDim }), title: 'List row', sub: 'Supporting line', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }) }),
  card(cellTitle('Card, outlined') + cellText('The default container'), {}),
  card(cellTitle('Sage — protective') + cellText('Confirmations, and anything that costs her nothing'), { v: 'sage' }),
  card(cellTitle('Amber — a win or a wait') + cellText('Personal bests, review queues'), { v: 'amber' }),
].join('');
const motionTable = table(['Moment', 'What moves', 'Duration'], [
  ['Screen push', 'Slide 24px and fade', '320ms'],
  ['Tab switch', 'Cross-fade; the nav pill slides between tabs', '220ms'],
  ['Bottom sheet', 'Slide up, scrim fades in', '320ms'],
  ['Set logged', 'Button presses, check springs in, rest ring starts', '220ms'],
  ['Meal logged', 'Slot fills, protein bar animates, snackbar rises', '460ms'],
  ['Points and level', 'Points count up, then the level bar fills', '460ms'],
  ['Tier change', 'The name cross-fades once — no fanfare on a slip', '320ms'],
  ['Finished', 'The one confetti burst in the product', '900ms'],
  ['Reduced motion', 'Everything above becomes instant', '0ms'],
], { widths: ['240px', '1fr', '140px'] });
const dsRows = [
  rowHeader('Design system', 'Pink, Material 3, minimal', 'Google\'s shapes and colour roles, an Egyptian pink palette, one type family that covers Arabic and Latin, and motion that explains rather than decorates. Every pairing here is contrast-checked — the measured numbers are in review/design-language.md.', 1100),
  panel([
    panelBlock('Colour roles', `<div style="display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:12px">${swatches}</div>`),
    panelBlock('Type — Rubik, one family for both scripts', `<div style="display:flex;flex-direction:column;gap:12px">${typeRows}${arabicRow}</div>`),
    panelBlock('Components', `<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px;align-items:start">${componentSamples}</div>`),
    panelBlock('Motion', motionTable),
  ].join(''), { width: 1660 }),
];
add('Design-system.dc.html', 'Design system', dsRows, 1860, 3100, 'page-1');

// ---------- architecture ----------
function tree(title, tabs) {
  const cols = tabs.map(t => {
    const items = t[1].map(i => `<div style="border-radius:12px;border:1px solid ${C.outlineVariant};background:${C.surfaceLowest};padding:10px 12px;display:flex;flex-direction:column;gap:3px"><div style="font-size:15px;font-weight:600;color:${C.onSurface}">${i[0]}</div><div style="font-family:${F.mono};font-size:11px;color:${C.onSurfaceVariant}">${i[1]}</div></div>`).join('');
    return `<div style="display:flex;flex-direction:column;gap:8px"><div style="height:36px;border-radius:999px;background:${C.primaryContainer};display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600;color:${C.onPrimaryContainer}">${t[0]}</div>${items}</div>`;
  }).join('');
  return card(`<div style="font-size:18px;font-weight:600;color:${C.onPrimaryContainer}">${title}</div><div style="display:grid;grid-template-columns:repeat(${tabs.length},minmax(0,1fr));gap:12px">${cols}</div>`, { pad: '24px', gap: 16 });
}
const clientTree = tree('5 tab roots', [
  ['Home', [['Today — logging lives here', 'L0'], ['Progress — tier, level, week', 'L1'], ['Milestones · bests · body', 'L2'], ['Notifications', 'L1'], ['Profile, privacy, Safety Centre', 'L1 → L2']]],
  ['Train', [['Train hub', 'L0'], ['Program', 'L1'], ['Workout day', 'L2'], ['Exercise video', 'sheet'], ['Active workout', 'full screen']]],
  ['Community', [['Feed', 'L0 — centre'], ['Post and comments', 'L1'], ['Groups, group', 'L1 → L2'], ['Group goal', 'L2'], ['Report, block, mute', 'sheet']]],
  ['Eat', [['Eat hub', 'L0'], ['One box — say or type', 'sheet'], ['Recipes', 'L1'], ['Recipe', 'L2'], ['Week plan, grocery list', 'L1 → L2']]],
  ['Coaching', [['Find a coach', 'L0'], ['Coach profile', 'L1'], ['Package, pay', 'sheet → modal'], ['My coach, chat', 'L1'], ['Check-in and reply', 'L1 → L2']]],
]);
const coachTree = tree('4 tab roots', [
  ['Today', [['Queue: check-ins, enquiries', 'L0'], ['Check-in review', 'L1'], ['New enquiry', 'L1']]],
  ['Clients', [['Clients by state', 'L0'], ['Client detail', 'L1'], ['Plan builders', 'L2'], ['Move picker', 'sheet']]],
  ['Chats', [['Threads by waiting time', 'L0'], ['Conversation', 'L1']]],
  ['Earnings', [['Earnings and payouts', 'L0'], ['Public profile editor', 'L1']]],
]);
const budgetTable = table(['Journey', 'Phase 1 draft', 'This version'], [
  ['Log a set mid-workout', '1 tap', '1 tap — or 1 for the whole move'],
  ['Log a session trained without the phone', '2 taps', '2 taps, 1 from the evening card'],
  ['Count a walk the phone saw', 'not possible', '1 tap'],
  ['Log her usual meal', '1 tap', '1 tap, or 1 from the lock screen'],
  ['Log a plate of three things', '1 tap once saved by hand', '1 tap — plates save themselves'],
  ['Change a portion', '2–3 taps', '1 chip'],
  ['Log something new', '2 taps by voice', '2 taps, said or typed'],
  ['See where she stands', '0 — it is on Today', '0 — it is on Today'],
], { widths: ['1fr', '260px', '320px'] });
const archRows = [
  rowHeader('Architecture', 'Five tabs, nothing deeper than three levels', 'The Phase 1 navigation decision holds: five labelled tabs for the client, four for the coach. What changed is where logging lives — on Today and in one box on Eat — so both budgeted journeys are a single tap.', 1100),
  panel([
    panelBlock('Client', clientTree),
    panelBlock('Coach', coachTree),
    panelBlock('The journeys we budget, and what they cost now', budgetTable),
  ].join(''), { width: 1660 }),
];
add('Architecture.dc.html', 'Architecture', archRows, 1860, 2500, 'page-1');

// ---------- research ----------
const loggingCells = [
  cell(cellTitle('Entry is the problem, not duration') + cellText('141 food journalers and 5,526 forum posts: the failures are entry barriers, negative nudges and social features.') + source('Cordeiro et al., CHI 2015') + cellSo('So: cut decisions, not seconds. The app writes the entry and she agrees.')),
  cell(cellTitle('Frequency beats completeness') + cellText('Logging frequency tracked weight loss; time per day fell from 23.2 to 14.6 minutes over six months.') + source('Harvey et al., Obesity 2019') + cellSo('So: a half-logged day is a logged day, and no screen asks her to finish one.')),
  cell(cellTitle('A missed day does not break a habit') + cellText('Missing one opportunity cost under half a point of automaticity and recovered quickly; habits took 18–254 days to form.') + source('Lally et al., EJSP 2010') + cellSo('So: a missed day is never displayed. The week is the unit.')),
  cell(cellTitle('Broken streaks are the damage') + cellText('Intact streaks raise engagement; the loss is worst when she blames herself, and repair softens it.') + source('Silverman & Barasch, JCR 2023') + cellSo('So: weeks, automatic rest weeks, outward attribution, and a total that never falls.')),
  cell(cellTitle('Gamification works, modestly — and lasts') + cellText('Hedges g 0.33–0.48, roughly +500 to +2,183 steps a day, sustained at follow-up rather than novelty.') + source('Mazeas et al., JMIR 2022') + cellSo('So: points stay, sized as an aid. Only goal-moving behaviour earns them, capped daily.')),
  cell(cellTitle('Two Phase 1 claims did not survive') + cellText('"Passive logging backfires" could not be verified anywhere, and "gamification fades after six months" is contradicted above.') + source('unverified · contradicted') + cellSo('So: detected walks are allowed — as a proposal she confirms with one tap.')),
];
const verifyCells = [
  cell(cellTitle('The card decides, not the face') + cellText('Egypt\'s 14-digit national ID number encodes sex in the 13th digit and carries date of birth, so a government record answers the question.') + source('Egyptian National Identity Card')),
  cell(cellTitle('Appearance-based gates lose in court') + cellText('A women-only app excluded a member on "gender-related appearance"; in May 2026 the Full Federal Court of Australia called it direct discrimination and doubled damages.') + source('Tickle v Giggle, appeal 2026')),
  cell(cellTitle('Who can actually do this here') + cellText('Valify is Egyptian and licensed, checking against the National Registry; uqudo covers the Egyptian ID with passive liveness and face match.') + source('Valify · uqudo')),
  cell(cellTitle('The law lands in October 2026') + cellText('The PDPL Executive Regulations arrived 1 November 2025: biometric processing needs explicit consent and a licence, after a one-year grace period.') + source('Law 151/2020 · Decree 816/2025')),
];
const flowTable = table(['Step', 'Screen', 'What happens', 'Why it is built this way'], [
  ['1', 'C06–C07', 'Phone number and a six-digit code', 'Cheap account binding, no password'],
  ['2', 'C08', 'Client or coach', 'Coaches also upload certificates'],
  ['3', 'C09', 'What is read, what is kept, ~90 seconds, explicit consent', 'The regulations require it, and completion improves when the reason is stated'],
  ['4', 'C10', 'ID card front, auto-captured; sex and age read from the number', 'A government record, not a guess about her face'],
  ['5', 'C11', 'Selfie with passive liveness, matched to the ID photo', 'Proves the card is hers — no gender inference anywhere'],
  ['6', 'C12', 'Usually seconds; otherwise a woman reviewer', 'Edge cases get a person, not a rejection'],
  ['7a', 'C13', 'Verified: the community opens, both images deleted', 'The payoff, and the promise kept'],
  ['7b', 'C14', 'Pending: workouts, recipes and coaches stay open', 'Never a dead end'],
  ['7c', 'C15', 'Niqab path: a woman reviewer, or a partner gym in person', 'No face photo required or kept'],
], { widths: ['70px', '110px', '1fr', '1fr'] });
const ownerCells = [
  cell(cellText('Minimum age — 16 or 18, read from the ID. Needs legal sign-off.'), C.amberContainer),
  cell(cellText('The written membership policy, including trans women, reviewed by an Egyptian lawyer.'), C.amberContainer),
  cell(cellText('Passport sign-up for non-Egyptian residents: yes or no.'), C.amberContainer),
  cell(cellText('Which ladies-only gyms partner for in-person checks, and who pays reviewers.'), C.amberContainer),
];
const researchRows = [
  rowHeader('Research', 'What the evidence says, and what it changed', 'Every claim was checked against the source named under it. Full write-ups live in research/logging-and-rewards.md and research/women-only-verification.md.', 1100),
  panel([
    panelBlock('Logging and rewards', cellGrid(loggingCells, 3)),
    panelBlock('Women-only verification', cellGrid(verifyCells, 4)),
    panelBlock('The sign-up flow we build', flowTable),
    panelBlock('Owner decisions before launch', cellGrid(ownerCells, 4)),
    panelBlock('Cycle-aware training — what the evidence allows', cellGrid([
      cell(cellTitle('Phase is a weak basis for prescribing') + cellText('Performance is at most trivially reduced in the early follicular phase, with large variation and poor-quality studies. The authors recommend a personalised approach instead of general guidelines.') + source('McNulty et al., Sports Medicine 2020') + cellSo('So: no four-phase schedule anywhere. Symptoms she logs today drive every suggestion.')),
      cell(cellTitle('Strength timing does not hold up') + cellText('An umbrella review found it premature to claim cycle phase meaningfully affects acute strength or long-term adaptations, with phase verification poor or absent throughout.') + source('Colenso-Semple et al., Frontiers 2023') + cellSo('So: nothing promises better results from training on a particular day.')),
      cell(cellTitle('Symptoms, pain and iron') + cellText('PMS symptoms vary between people and months; gentle movement helps some period pain; heavy periods raise iron-deficiency risk, and vitamin C helps absorb plant iron.') + source('NHS · NIH') + cellSo('So: short check-ins, optional mobility, ordinary iron-containing meals — and never a diagnosis or a supplement.')),
      cell(cellTitle('Dates cannot confirm ovulation') + cellText('Cycle length varies and hormonal contraception can suppress ovulation, so a calendar cannot confirm it.') + source('NHS: menstrual cycle') + cellSo('So: logged and estimated look different, symptom-only mode exists, and no day is ever labelled confirmed ovulation.')),
    ], 4)),
    panelBlock('Online coaching — product patterns, not health claims', cellGrid([
      cell(cellTitle('One plan, one set of logs') + cellText('Coaching platforms assign from a library, schedule meals across a month, collect intake and check-ins, and keep one conversation per relationship.') + source('Everfit · ABC Trainerize') + cellSo('So: coaching never creates a second food diary or workout history.')),
      cell(cellTitle('Prescribed is not completed') + cellText('A prescription and a result are different records, and mixing them is how adherence numbers become fiction.') + source('design decision') + cellSo('So: every set shows prescribed beside actual, and untouched sets stay empty.')),
      cell(cellTitle('A message is not a plan change') + cellText('Chat that claims a change, with nothing changed behind it, is the common failure of coaching over WhatsApp.') + source('design decision') + cellSo('So: publishing changes the plan, and the change appears as a labelled card in both views.')),
      cell(cellTitle('Her body, her call') + cellText('Coach approval is never required to stop exercising, and cycle information is shared only in the pieces she chooses.') + source('design decision') + cellSo('So: easier option and rest are always available, and sharing is three switches, off by default.')),
    ], 4)),
  ].join(''), { width: 1660 }),
];
add('Research.dc.html', 'Research', researchRows, 1860, 3100, 'page-1');

// ---------- screen chapters ----------
const chapterLede = {
  signup: 'Verification moved to account creation, so no unverified visitor ever sees a member. The check reads her national ID card — the number carries sex and date of birth — and the selfie only proves the card is hers. A woman-reviewer path exists for women who will not show their face to a camera.',
  onboarding: 'Four questions, each one tap, each skippable. The third quietly sets the weekly goal that the whole rewards system counts.',
  today: 'Everything she might log today is already written on one screen: the walk her phone counted, the session from her plan with last week\'s weights, and the meal she usually eats at this hour.',
  train: 'Programs, videos and the active workout. Logging a set is confirming a sentence, a whole move can go in one tap, and timed follow-along moves log themselves.',
  eat: 'Her usual plates first, one box that takes a sentence typed or spoken, portions as chips, and a calm running total instead of a countdown.',
  progress: 'Weeks, not days. Points say that counted, levels hold everything she has ever done, tiers show how steady she is lately, and nothing earned is taken away.',
  community: 'The feed women already know how to read — a stories rail, full-bleed pictures, reels, follows and saves — except every account behind it is ID-verified, faces arrive blurred, and progress is posted as a follow-up picture on her own earlier post rather than a before-and-after of two strangers.',
  coaching: 'Finding, paying and working with a coach — and the weekly check-in written from her logs, which is the thing she actually pays for.',
  account: 'Notifications that earn their place, privacy stated as what she shows versus what we keep, and a Safety Centre with a promised response time.',
  'coach-setup': 'Six steps, denser than the client side because she is at a desk: photo, certificates, specialties, packages, payout, and work to do while she is checked.',
  coach: 'The coach app is a queue: who is waiting, for how long, against the reply time she promised. Client weeks are summarised from logs so her time goes on judgement.',
  cycle: 'Optional, and symptom-led. What she logs today drives every suggestion — never an inferred phase, never a forecast, and severe pain gets medical guidance instead of a workout.',
  coached: 'What she paid for: a 30-day plan that arrives in the app, a guided session carrying her coach\u2019s notes, meals already chosen, and a weekly review answered by a person.',
  coachbrand: 'The answer to \u201cevery coach gets the same page\u201d. Her portfolio is a stack of blocks she picks, orders, hides and styles herself, with her own offers, her own method, her ads, and client results that are gated behind consent the client can withdraw.',
  coachplan: 'The month, built. Assign sessions and meals across 30 days, tailor the numbers per client, copy a week, then publish \u2014 because publishing, not messaging, is what changes a plan.',
};
const pageFor = { 'coach-setup': 'page-3', coach: 'page-3', coachbrand: 'page-3', coachplan: 'page-3' };
let n = 0;
for (const f of flows) {
  const scr = all.filter(s => s.flow === f.id);
  const cols = scr.map(s => screenCol(s.html, note(`${s.id} — ${s.title}`, s.metric, s.note), s.id));
  const rows = [
    // `admin` is a third role, not a variety of client. Labelling it "Client"
    // would put the staff console in the same row header as the screens a
    // member sees, which is the one distinction this flow exists to make.
    rowHeader(`${{ coach: 'Coach', admin: 'Admin' }[f.role] ?? 'Client'} · ${String(++n).padStart(2, '0')}`, f.title, chapterLede[f.id], 1100),
    strip(`${scr.length} screens`, cols),
  ];
  const file = f.id.split('-').map(x => x[0].toUpperCase() + x.slice(1)).join('-') + '.dc.html';
  add(file, f.title, rows, 160 + scr.length * 390 + (scr.length - 1) * 36 + 40, 1480, pageFor[f.id] || 'page-2');
}

// ---------- the Arabic version ----------
if (hasArabic()) {
  for (const f of flows) {
    const scr = all.filter(s => s.flow === f.id);
    const cols = scr.map(s => screenCol(toArabic(s.html), note(`${s.id} — ${s.title}`, s.metric, s.note), s.id + '-ar'));
    const rows = [
      rowHeader(`${f.role === 'coach' ? 'المدربة' : 'العميلة'} · ${f.title}`, 'النسخة العربية', 'الشاشات نفسها بالعربية الفصحى، من اليمين إلى اليسار: الأيقونات الاتجاهية تنعكس، وتبقى الأرقام كما هي حتى تظل الأسعار وأرقام الهواتف مقروءة.', 1100),
      strip(`${scr.length} شاشة`, cols),
    ];
    const file = 'Ar-' + f.id.split('-').map(x => x[0].toUpperCase() + x.slice(1)).join('-') + '.dc.html';
    add(file, f.title + ' · عربي', rows, 160 + scr.length * 390 + (scr.length - 1) * 36 + 40, 1480, 'page-4');
  }
}

// ---------- canvas.json ----------
const pages = [{ id: 'page-1', name: 'Brief, features, system' }, { id: 'page-2', name: 'Client app' }, { id: 'page-3', name: 'Coach app' }, { id: 'page-4', name: 'العربية' }];
const laid = [];
for (const p of pages) {
  let x = 0;
  for (const a of artboards.filter(a => a.page === p.id)) {
    laid.push({ file: a.file, title: a.title, x, y: 0, w: a.w, h: a.h, page: p.id });
    x += a.w + 200;
  }
}
fs.writeFileSync(path.join(OUT, 'canvas.json'), JSON.stringify({ artboards: laid, pages, launch: { view: 'canvas', page: 'page-1' } }, null, 2));
console.log('artboards:', artboards.length);
for (const a of laid) console.log(' ', a.file.padEnd(26), `${a.w}×${a.h}`, a.page);
