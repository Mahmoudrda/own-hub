import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, navBar, sageNote, listItem, appBar, avatar, spacer, field, toggle, kv, sectionHead } = K;

// Grounded, not generative. Every suggestion is selected from the 124-move video
// library or the verified Egyptian food library and carries the source it came
// from; it drafts and never publishes, because in this product publishing is what
// changes a plan. The word "AI" stays off screen until the feature ships.
const source = (label, ic = 'menu_book') => pill(label, { bg: C.surfaceContainer, color: C.onSurfaceVariant, ic });

const ask = (text) => `<div style="display:flex;justify-content:flex-end"><div style="max-width:80%;background:${C.primaryContainer};border-radius:18px 18px 6px 18px;padding:10px 14px;font-size:15px;line-height:22px;color:${C.onSurface}">${text}</div></div>`;
const reply = (inner) => `<div style="display:flex;justify-content:flex-start"><div style="max-width:88%;background:${C.surfaceLowest};border:1px solid ${C.outlineVariant};border-radius:18px 18px 18px 6px;padding:11px 13px;display:flex;flex-direction:column;gap:8px">${inner}</div></div>`;

const X01 = phone(
  statusBar()
  + appBar({ title: 'Assistant', leadGo: 'T01', actions: [{ icon: 'info', go: 'X03' }] })
  + body(
    ask('My knee hurts on the squats today')
    + reply(`<div style="font-size:15px;line-height:22px;color:${C.onSurface}">Two moves in your session work the same muscles without loading the knee. Both are already approved by Sara.</div>`
      + `<div style="display:flex;gap:6px;flex-wrap:wrap">${source('From your plan', 'list_alt')}${source('124-move library')}</div>`)
    + listItem({ lead: icon('fitness_center', { size: 21, color: C.primaryDim }), title: 'Glute bridge', sub: '3 × 12 · nothing on the knee', trail: K.logBtn(false, 'Swap', { go: 'R05' }), pad: '9px 11px' })
    + listItem({ lead: icon('fitness_center', { size: 21, color: C.primaryDim }), title: 'Box squat to a chair', sub: '3 × 10 · less depth', trail: K.logBtn(false, 'Swap', { go: 'R05' }), pad: '9px 11px' })
    + card(row(`${icon('info', { size: 20, color: C.primaryDim })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">Swapping changes today only. Your plan from Sara is untouched.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'tonal', pad: '10px 12px' })
    + listItem({ lead: icon('support_agent', { size: 21, color: C.error }), title: 'Sharp or new pain?', sub: 'Some questions it will not answer, and should not', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'X02', pad: '9px 11px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Ask, or hold to talk</div>${icon('send', { size: 22, color: C.primaryDim })}`, { gap: 10, justify: 'flex-start' }), { pad: '11px 13px', r: R.full })
    + btn('Ask Sara instead', { v: 'outlined', h: 44, size: 14, go: 'H06' })));

const X02 = phone(
  statusBar()
  + appBar({ title: 'Assistant', leadGo: 'X01', actions: [{ icon: 'info', go: 'X03' }] })
  + body(
    ask('I have sharp pain low down and bleeding between periods. Is that normal?')
    + reply(`<div style="font-size:15px;line-height:22px;color:${C.onSurface}">I am not able to answer that one. It is a medical question, and guessing at it would not be safe.</div>`)
    + card(row(`${icon('support_agent', { size: 22, color: C.error })}${col(`${strong('This needs a doctor, not an app', 'titleM')}${m('Bleeding between periods with sharp pain should be looked at by a clinician.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'error', pad: '11px 13px' })
    + btn('Find care near you', { h: 48, size: 15, go: 'Y11' })
    + btn('Message Sara', { v: 'outlined', h: 44, size: 14, go: 'H06' })
    + card(col(`${strong('What I did with that message', 'titleM')}${m('Nothing was logged and nothing was shared. Your cycle information is not visible to me unless you turn that on.')}`, { gap: 3 }), { pad: '11px 13px' })
    + sageNote('It refuses rather than hedging. A fitness assistant that answers medical questions is the one thing this product will not ship.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Back', { v: 'outlined', h: 46, size: 15, go: 'X01' })));

const X03 = phone(
  statusBar()
  + appBar({ title: 'What it can and cannot do', leadGo: 'X01' })
  + body(
    sectionHead('It can')
    + col(['Find a move for your equipment and your knee', 'Swap today’s exercise for an approved alternative', 'Tell you the portion of a dish you already log', 'Explain a rule: why a week counted, what a rest week covers']
      .map(x => row(`${icon('check', { size: 19, color: C.tertiary })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">${x}</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' })).join(''), { gap: 7 })
    + sectionHead('It cannot')
    + col(['Diagnose anything, or answer a medical question', 'Change your plan · only Sara publishing does that', 'See your cycle information unless you share it', 'Invent a meal or a quantity: every gram comes from the food library']
      .map(x => row(`${icon('close', { size: 19, color: C.error })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">${x}</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' })).join(''), { gap: 7 })
    + card(col(`${strong('What leaves your phone', 'titleM')}${m('Your question, your equipment and what you are avoiding. Never your name, your photos, your weight or your ID.')}`, { gap: 3 }), { v: 'sage', pad: '11px 13px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Ask something', { h: 54, go: 'X01' })));

const K26 = phone(
  statusBar()
  + appBar({ title: 'Draft · Nour', lead: 'close', leadGo: 'W03', actions: [{ icon: 'info', go: 'X03' }] })
  + body(
    card(col(`${strong('Drafted from what you already wrote', 'titleM')}${kv('Split', 'Upper / lower · 4 days')}${kv('Assessment', 'Knee · no deep bends')}${kv('Days', '30 · 18 sessions, 8 rest')}${kv('Moves', 'All from your 124-move library', { last: true })}`, { gap: 2 }), { gap: 8 })
    + card(row(`${icon('check_circle', { size: 21, color: C.tertiary, fill: true })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">Her avoid list was applied first: deep knee bends and high impact never appear.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'sage', pad: '10px 12px' })
    + sectionHead('Week 1')
    + col([['Sun', 'Upper body · 20 min'], ['Mon', 'Rest day'], ['Tue', 'Lower body · box squat, not goblet'], ['Thu', 'Upper body · 20 min']]
      .map(([d, v]) => `<div style="border-radius:${R.md}px;padding:9px 11px;display:flex;align-items:center;gap:10px;background:${C.surfaceLowest};border:1px solid ${C.outlineVariant}"><div style="width:42px;font-size:13px;font-weight:600;color:${C.onSurfaceVariant}">${d}</div><div style="flex:1;font-size:14px;color:${C.onSurface}">${v}</div></div>`).join(''), { gap: 6 })
    + card(row(`${icon('warning', { size: 21, color: C.amber })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">Nothing is published. This opens as a draft in your planner, and you decide what she sees.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '10px 12px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Open in my planner', { h: 54, go: 'W03' }) + btn('Discard the draft', { v: 'text', h: 42, size: 15, go: 'W03' })));

const K27 = phone(
  statusBar()
  + appBar({ title: 'Meal draft · Nour', lead: 'close', leadGo: 'W06', actions: [{ icon: 'info', go: 'X03' }] })
  + body(
    card(row(`${icon('warning', { size: 21, color: C.error })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">No nuts. Vegetarian on weekdays. Applied before anything was chosen.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'error', pad: '10px 12px' })
    + col([['Breakfast', 'Ful with oil and cumin · 410 kcal'], ['Lunch', 'Koshari bowl, medium · 540 kcal'], ['Dinner', 'Lentil soup and eggs · 380 kcal']]
      .map(([d, v]) => `<div style="border-radius:${R.md}px;padding:9px 11px;display:flex;align-items:center;gap:10px;background:${C.surfaceLowest};border:1px solid ${C.outlineVariant}"><div style="width:66px;font-size:13px;font-weight:600;color:${C.onSurfaceVariant}">${d}</div><div style="flex:1;font-size:14px;color:${C.onSurface}">${v}</div></div>`).join(''), { gap: 6 })
    + card(col(`${strong('Every number came from the food library', 'titleM')}${m('Nothing was calculated. A dish without verified values is offered without totals, never with invented ones.')}`, { gap: 3 }), { v: 'sage', pad: '11px 13px' })
    + row(`${chip('Protein 92 g', { sel: true })}${chip('Cost 46 EGP')}${chip('7 days')}`, { gap: 7, justify: 'flex-start' })
    + m('Her own plates are used first, because a meal plan she has never cooked is one she will not follow.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Open in the meal planner', { h: 54, go: 'W06' }) + btn('Discard the draft', { v: 'text', h: 42, size: 15, go: 'W06' })));

export const screens = [
  { id: 'X01', html: X01, metric: 'grounded, with its sources', note: 'Every answer carries the place it came from — her plan, or the 124-move library — because an assistant that cannot show its source is indistinguishable from one that guessed. The suggestions are selections from the library rather than generated text, the swap changes today only, and "ask Sara instead" sits in the footer as a first-class option rather than a fallback.' },
  { id: 'X02', html: X02, metric: 'refuses, does not hedge', note: 'The most important screen in the feature. A fitness assistant asked a medical question must decline, and the research is explicit that guardrails cannot diagnose or substitute for clinical judgement. It routes to care and to her human coach, and states what it did with the message — nothing logged, nothing shared — because that is the fear the question creates.' },
  { id: 'X03', html: X03, metric: 'two lists, both honest', note: 'The cannot-do list is longer and more specific than the can-do list, which is the opposite of how these features are usually sold. It names the four real boundaries: no diagnosis, no plan changes, no cycle data without sharing, and no invented quantities.' },
  { id: 'K26', html: K26, metric: 'drafts, never publishes', note: 'The coach-side payoff: her own split plus the client\'s assessment become a 30-day draft in seconds, with the avoid list applied before selection rather than checked afterwards. It opens in her planner as a draft — publishing stays the human act that changes a plan, which is the rule the rest of the product already enforces.' },
  { id: 'K27', html: K27, metric: '0 invented quantities', note: 'Allergies are applied before anything is chosen, not validated after. The stated rule — a dish without verified values is offered without totals rather than with plausible ones — is the difference between a tool a coach can defend to a client and one she cannot.' },
];
