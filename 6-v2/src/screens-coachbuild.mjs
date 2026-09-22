import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, sageNote, listItem, appBar, avatar, spacer, field, toggle, kv, sectionHead } = K;

// A split is the shape of a training week that outlives one client: name it once,
// apply it to anybody. Day slots reuse the session editor the planner already has.
const slot = (label, value, { rest = false, go: g = 'W04' } = {}) =>
  `<div style="border-radius:${R.md}px;padding:10px 12px;display:flex;align-items:center;gap:10px;background:${rest ? C.surfaceLow : C.surfaceLowest};border:1px solid ${C.outlineVariant};cursor:pointer" data-go="${g}">`
  + `<div style="width:54px;font-size:13px;font-weight:600;color:${C.onSurfaceVariant}">${label}</div>`
  + `<div style="flex:1;font-size:15px;color:${rest ? C.onSurfaceVariant : C.onSurface}">${value}</div>`
  + icon(rest ? 'spa' : 'edit', { size: 18, color: C.onSurfaceVariant }) + `</div>`;

const splitRow = (name, shape, used) => listItem({
  lead: icon('repeat', { size: 22, color: C.primaryDim }), title: name, sub: `${shape} · ${used}`,
  trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'K20', pad: '11px 13px',
});

// Pass / modify / refer. Three outcomes, because a screen that only passes or fails
// pushes a coach into pretending she is qualified to decide.
const screenRow = (name, note, sel) => card(
  col(`${strong(name, 'titleS')}${m(note)}`, { gap: 2 })
  + `<div style="display:flex;gap:6px">${['Pass', 'Modify', 'Refer'].map((x, i) => `<div style="flex:1;height:32px;border-radius:999px;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:600;${i === sel ? `background:${C.primaryContainer};color:${C.onPrimaryContainer}` : `border:1.5px solid ${C.outlineVariant};color:${C.onSurfaceVariant}`}">${x}</div>`).join('')}</div>`,
  { pad: '10px 12px', gap: 8 });

const compareRow = (name, before, now, better) =>
  `<div style="border-radius:${R.md}px;padding:10px 12px;display:flex;align-items:center;gap:10px;background:${C.surfaceLowest};border:1px solid ${C.outlineVariant}">`
  + `<div style="flex:1;font-size:15px;font-weight:600;color:${C.onSurface}">${name}</div>`
  + `<div style="font-size:13px;color:${C.onSurfaceVariant};text-align:right">at intake<br><span style="font-size:15px;font-weight:600;color:${C.onSurface}">${before}</span></div>`
  + `<div style="width:1px;height:28px;background:${C.outlineVariant}"></div>`
  + `<div style="font-size:13px;color:${C.onSurfaceVariant};text-align:right">now<br><span style="font-size:15px;font-weight:600;color:${better ? C.tertiary : C.onSurface}">${now}</span></div></div>`;

// ---------------- splits ----------------
const K19 = phone(
  statusBar()
  + appBar({ title: 'My splits', leadGo: 'W01', actions: [{ icon: 'search' }] })
  + body(
    m('A split is a week shape you write once and apply to any client. Editing a split never changes a plan you already published.')
    + splitRow('Full body ×3', '3 days · Sun, Tue, Thu', 'on 7 clients')
    + splitRow('Upper / lower', '4 days · 2 on, 1 off', 'on 3 clients')
    + splitRow('Push · pull · legs', '6 days · advanced', 'on 1 client')
    + splitRow('Postpartum floor weeks', '3 days · weeks 1–4', 'on 5 clients')
    + card(row(`${icon('add', { size: 23, color: C.primaryDim })}<div style="flex:1;font-size:16px;font-weight:600;color:${C.primaryDim}">Build a split</div>`, { gap: 11, justify: 'flex-start' }), { v: 'filled', pad: '12px 14px', go: 'K20' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Clients', 'coach'));

const K20 = phone(
  statusBar()
  + appBar({ title: 'Build a split', lead: 'close', leadGo: 'K19' })
  + body(
    field({ label: 'Name it', value: 'Upper / lower' })
    + col(`${m('How many days before it repeats?')}${chipRow(['3', '4', '5', '6', '7'], 1, { grow: true })}`, { gap: 7 })
    + col(`${slot('Day 1', 'Upper body · 20 min')}${slot('Day 2', 'Lower body · 20 min')}${slot('Day 3', 'Rest day', { rest: true })}${slot('Day 4', 'Upper body · 20 min')}`, { gap: 7 })
    + card(row(`${col(`${strong('Keep her easier options', 'titleM')}${m('Approved substitutions carry into every client you apply this to.')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 11 }), { v: 'sage', pad: '10px 12px' })
    + m('Applying a split writes these days across the month. You still tailor sets, weights and notes per client.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save this split', { h: 54, go: 'K19' }) + btn('Save and apply', { v: 'outlined', h: 46, size: 15, go: 'W03' })));

// ---------------- assessment ----------------
const K21 = phone(
  statusBar()
  + appBar({ title: 'Assessment · Nour', lead: 'close', leadGo: 'W02', actions: [{ icon: 'history', go: 'K22' }] })
  + body(
    segs(2, 1)
    + col(`${strong('Health and clearance', 'titleM')}${m('Step 1 of 2')}`, { gap: 3 })
    + card(
      col(`${m('Stage')}${chipRow(['Pregnant', '0 to 6 weeks', '6 weeks to 1 year', 'Over a year'], 2, { grow: false })}`, { gap: 6 })
      + row(`${col(`${strong("Doctor's clearance to train", 'titleS')}${m('Recorded 2 September')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 10 })
      + col(`${m('Birth')}${chipRow(['Vaginal', 'Caesarean', 'Prefer not to say'], 1, { grow: false })}`, { gap: 6 })
      , { v: 'sage', gap: 10 })
    + card(col(`${strong('What to avoid', 'titleM')}${m('These write straight onto her plan, so a session can never prescribe them.')}`, { gap: 2 })
      + row(`${chip('High impact', { sel: true })}${chip('Deep knee bends', { sel: true })}${chip('Loaded twisting')}`, { gap: 6, justify: 'flex-start', wrap: true })
      + field({ label: 'Pain, injuries or surgery', value: 'Right knee, sore on stairs since March' })
      , { v: 'amber', gap: 9 })
    + m('Nothing here is shown to other members, ever.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Continue', { h: 54, go: 'K23' })));

const K23 = phone(
  statusBar()
  + appBar({ title: 'Assessment · Nour', leadGo: 'K21' })
  + body(
    segs(2, 2)
    + col(`${strong('Movement screening', 'titleM')}${m('Step 2 of 2')}`, { gap: 3 })
    + screenRow('Sit to stand', 'Five times, no hands', 0)
    + screenRow('Single-leg balance', 'Ten seconds each side', 1)
    + screenRow('Pelvic floor symptoms', 'Any leaking, heaviness or doming', 2)
    + sectionHead('Baseline')
    + card(col(`${kv('Sit to stand', '5 with hands')}${kv('Plank hold', '20 s')}${kv('Single-leg balance', '4 s', { last: true })}`, { gap: 0 }), { pad: '4px 14px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save assessment', { h: 54, go: 'W02' }) + btn('Save only', { v: 'text', h: 42, size: 15, go: 'W02' })));

const K22 = phone(
  statusBar()
  + appBar({ title: 'Re-assessment · week 4', leadGo: 'W02', actions: [{ icon: 'visibility', go: 'K21' }] })
  + body(
    card(row(`${icon('history', { size: 21, color: C.primaryDim })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">Filled in from her intake. Change what has moved, and nothing is overwritten until you save.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'tonal', pad: '10px 12px' })
    + sectionHead('Baseline')
    + col(`${compareRow('Sit to stand', '5 with hands', '5 no hands', true)}${compareRow('Plank hold', '20 s', '75 s', true)}${compareRow('Single-leg balance', '4 s', '11 s', true)}${compareRow('Knee pain on stairs', 'Most days', 'Twice a week', true)}`, { gap: 7 })
    + card(row(`${icon('warning', { size: 21, color: C.amber })}${col(`${strong('Pelvic floor: still referred', 'titleM')}${m('She is seeing a physiotherapist. Loaded jumping stays off her plan.')}`, { gap: 2, grow: true })}`, { gap: 9, justify: 'flex-start' }), { v: 'amber', pad: '10px 12px' })
    + sageNote('A re-assessment never edits a published plan by itself. Save it, then adjust her weeks, the same way a message never changes a plan.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save and adjust her plan', { h: 54, go: 'W03' }) + btn('Save only', { v: 'text', h: 42, size: 15, go: 'W02' })));

export const screens = [
  { id: 'K23', html: K23, metric: 'refer is a real answer', note: 'The second half of the assessment. Screening offers pass, modify and refer, so a coach is never forced to rule out something outside her scope, and the baseline reuses the personal-best vocabulary the client already sees — a re-test feeds the same ladder rather than a private one.' },
  { id: 'K19', html: K19, metric: 'write once, use on everyone', note: 'A split is the missing object on the coach side: the week shape a coach already has in her head — full body three times, upper/lower, push-pull-legs — saved once instead of retyped per client. The count of clients on each split is there because that is what makes her cautious about editing one.' },
  { id: 'K20', html: K20, metric: 'a week shape, not a plan', note: 'Building a split is naming it, choosing how many days before it repeats, and filling the slots — each of which opens the session editor the planner already uses, so nothing new has to be learned. Applying it writes the days; tailoring sets and weights per client stays where it was.' },
  { id: 'K21', html: K21, metric: 'the source of "what to avoid"', note: 'Until now the coach screens displayed a client\'s contraindications and allergies that no screen ever captured. This is where they come from. Clearance, stage and birth type are asked because the product elsewhere promises "with your doctor\'s clearance", and a promise nobody collects is a liability. Screening offers refer as a first-class outcome, so a coach is never forced to pretend she can rule something out.' },
  { id: 'K22', html: K22, metric: 'intake beside now', note: 'Re-assessment reuses the prescribed-beside-actual pattern from the client\'s own workout screens, so improvement is read the same way everywhere. Saving it never edits a published plan on its own — the same rule that stops a chat message from moving a session.' },
];
