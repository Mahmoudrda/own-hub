import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, banner, sageNote, listItem, appBar, media, avatar, spacer, field, toggle, logBtn, kv } = K;

const coachRow = (sub = 'Sunday to Thursday, 9:00 to 17:00 · replies within one working day') => row(`${avatar(48, { initial: 'S' })}${col(`${row(`${strong('Coach Sara Hany', 'titleM')}${icon('verified', { size: 16, color: C.primaryDim, fill: true })}`, { gap: 5, justify: 'flex-start' })}${m(sub)}`, { gap: 3, grow: true })}${iconBtn('chat', { d: 44, bg: C.primaryContainer, color: C.onPrimaryContainer, go: 'G14' })}`, { gap: 12 });
const dateStrip = (sel = 3) => `<div style="display:flex;gap:6px">${['Sat 12', 'Sun 13', 'Mon 14', 'Tue 16', 'Wed 17', 'Thu 18'].map((d, i) => `<div style="flex:1;border-radius:14px;padding:8px 4px;text-align:center;font-size:13px;font-weight:600;background:${i === sel ? C.primary : C.surfaceLowest};color:${i === sel ? '#FFFFFF' : C.onSurfaceVariant};border:1px solid ${i === sel ? 'transparent' : C.outlineVariant}" data-go="G04">${d.split(' ')[0]}<div style="font-size:15px">${d.split(' ')[1]}</div></div>`).join('')}</div>`;
const setRow = (n, prescribed, actual, state) => `<div style="border-radius:${R.md}px;padding:10px 12px;display:flex;align-items:center;gap:10px;background:${state === 'done' ? C.tertiaryContainer : C.surfaceLowest};border:${state === 'now' ? `2px solid ${C.primary}` : `1px solid ${C.outlineVariant}`}">`
  + (state === 'done' ? icon('check_circle', { size: 20, color: C.tertiary, fill: true }) : `<div style="width:20px;height:20px;border-radius:999px;border:2px solid ${state === 'now' ? C.primary : C.outlineVariant};box-sizing:border-box"></div>`)
  + `<div style="flex:1;font-size:15px;font-weight:600;color:${C.onSurface}">Set ${n}</div>`
  + `<div style="font-size:13px;color:${C.onSurfaceVariant};text-align:right">prescribed<br><span style="font-size:15px;font-weight:600;color:${C.onSurface}">${prescribed}</span></div>`
  + `<div style="width:1px;height:28px;background:${C.outlineVariant}"></div>`
  + `<div style="font-size:13px;color:${C.onSurfaceVariant};text-align:right">you did<br><span style="font-size:15px;font-weight:600;color:${actual === '—' ? C.onSurfaceVariant : C.tertiary}">${actual}</span></div></div>`;
const bubble = (text, mine = false, { voice = false, state = '', attach = '' } = {}) => `<div style="display:flex;justify-content:${mine ? 'flex-end' : 'flex-start'}"><div style="max-width:80%;display:flex;flex-direction:column;gap:4px;align-items:${mine ? 'flex-end' : 'flex-start'}">`
  + (attach ? `<div style="background:${C.surfaceLowest};border:1px solid ${C.outlineVariant};border-radius:14px;padding:10px 12px;display:flex;align-items:center;gap:10px;cursor:pointer" data-go="G06">${icon('fitness_center', { size: 20, color: C.primaryDim })}<div style="font-size:14px;font-weight:600;color:${C.onSurface}">${attach}</div></div>` : '')
  + `<div style="background:${mine ? C.primaryContainer : C.surfaceLowest};border:1px solid ${mine ? 'transparent' : C.outlineVariant};border-radius:${mine ? '18px 18px 6px 18px' : '18px 18px 18px 6px'};padding:10px 14px;font-size:15px;line-height:22px;color:${C.onSurface}">`
  + (voice ? `<div style="display:flex;align-items:center;gap:8px">${icon('play_arrow', { size: 20, color: C.primaryDim, fill: true })}<div style="display:flex;align-items:center;gap:2px">${[10, 16, 22, 14, 20, 12, 18, 10, 14, 8, 16, 12].map(hh => `<div style="width:3px;height:${hh}px;border-radius:2px;background:${C.primary}"></div>`).join('')}</div><span style="font-size:13px;color:${C.onSurfaceVariant}">0:24</span></div>` : text)
  + `</div>${state ? `<div style="font-size:12px;color:${C.onSurfaceVariant}">${state}</div>` : ''}</div></div>`;

const G01 = phone(
  statusBar()
  + appBar({ title: 'Your coaching', lead: 'close', leadGo: 'H05' })
  + body(
    card(coachRow('Registered dietitian and coach · postpartum strength'), { v: 'tonal' })
    + card(col(`${kv('Package', '30 days · 8 Sep to 7 Oct')}${kv('Reviews', 'Every 7 days, and on day 30', { last: true })}`, { gap: 0 }), { pad: '4px 16px' })
    + segs(3, 1)
    + col(`${strong('Your training', 'titleM')}${m('Step 1 of 3 · saved as you go')}`, { gap: 3 })
    + col(`${m('Goal')}${chipRow(['Get stronger', 'Feel better', 'Lose weight'], 0, { grow: false })}`, { gap: 6 })
    + col(`${m('Days you can train')}${chipRow(['Sat', 'Sun', 'Mon', 'Tue', 'Thu'], 1, { grow: true })}`, { gap: 6 })
    + col(`${m('Time per session')}${chipRow(['15 min', '20 min', '30 min'], 1, { grow: true })}`, { gap: 6 })
    + col(`${m('Where and with what')}${chipRow(['At home', 'Dumbbells 3 kg'], -1, { grow: false })}`, { gap: 6 })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Continue', { h: 56, go: 'G17' })));

const G02 = phone(
  statusBar()
  + appBar({ title: 'Your coaching', leadGo: 'G01' })
  + body(
    segs(3, 3)
    + col(`${strong('Your support', 'titleM')}${m('Step 3 of 3')}`, { gap: 3 })
    + field({ label: 'Reminder time', value: '7:30 in the morning', trail: icon('schedule', { size: 22, color: C.primaryDim }) })
    + card(row(`${col(`${strong('Daily check-in', 'titleM')}${m('One short sheet. It does not mean a daily reply.')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 12 }), { pad: '12px 14px' })
    + card(
      col(`${strong('Share cycle information with Sara', 'titleM')}${m('Off unless you turn it on. Coaching never requires it.')}`, { gap: 3 })
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Energy and appetite</div>${toggle(false)}`)
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Cycle symptoms</div>${toggle(false)}`)
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Period dates and patterns</div>${toggle(false)}`)
      + btn('See exactly what she would see', { v: 'text', h: 40, size: 15, go: 'Y12' }), { v: 'sage', gap: 10 })
    + m('Your workout results and food logs are part of coaching. Cycle information is separate, and yours.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Send to Sara', { h: 56, ic: 'send', go: 'G03' })));

const G03 = phone(
  statusBar()
  + body(
    row(`${h('Coaching', 'titleL')}${pill('Preparing', { bg: C.amberContainer, color: C.amber })}`)
    + card(coachRow(), { v: 'tonal' })
    + card(row(`${icon('hourglass_top', { size: 26, color: C.amber })}${col(`${strong('Sara is preparing your plan', 'titleM')}${m('She has your intake. Most plans arrive within a working day.')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start', align: 'flex-start' }), { v: 'amber' })
    + btn('Message Sara', { h: 52, ic: 'chat', go: 'G14' })
    + m('Nothing is scheduled yet, so nothing is shown as assigned. Your own workouts and recipes still work.')
    + listItem({ lead: icon('fitness_center', { size: 22, color: C.primaryDim }), title: 'Train on your own meanwhile', sub: 'The library is open as usual', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'R01' })
    + listItem({ lead: icon('self_improvement', { size: 22, color: C.primaryDim }), title: 'My cycle', sub: 'Works with or without a coach', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'Y03' })
    + listItem({ lead: icon('visibility', { size: 22, color: C.primaryDim }), title: 'See an example day', sub: 'What today looks like once she publishes', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G04' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Coaching'));

const G04 = phone(
  statusBar()
  + body(
    row(`${h('Coaching', 'titleL')}${pill('Day 9 of 30', { ic: 'event_available' })}`)
    + dateStrip()
    + card(
      row(`${strong('Full-body strength', 'titleL')}${pill('35 min', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
      + m('From Sara · dumbbells 3 kg · “Keep the squat at 12 kg, aim for 12 reps.”')
      + btn('Start workout', { h: 54, ic: 'play_arrow', go: 'G06' }), { gap: 10 })
    + card(
      row(`${strong("Today's meals", 'titleM')}${btn('See all', { v: 'text', h: 36, size: 14, go: 'G05' })}`)
      + listItem({ title: 'Lunch · koshari bowl, medium', sub: '1 serving · from your plan', trail: logBtn(true, 'Log', { go: 'G10' }), v: 'filled', pad: '8px 12px' }), { gap: 8 })
    + listItem({ lead: icon('event_available', { size: 22, color: C.amber }), title: 'Weekly review due', sub: 'One minute · mostly filled in already', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G12', v: 'amber' })
    + listItem({ lead: icon('info', { size: 22, color: C.primaryDim }), title: 'Your Thursday workout was updated', sub: 'Sara shortened it to 20 minutes', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G13' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Coaching'));

const G05 = phone(
  statusBar()
  + appBar({ title: 'Your 30 days', leadGo: 'G04', actions: [{ icon: 'info' }] })
  + body(
    row(`${m('8 Sep to 7 Oct 2026')}${pill('Day 9', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + `<div style="display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:6px">`
    + Array.from({ length: 30 }, (_, i) => {
      const n = i + 1; const done = n < 9; const today = n === 9; const rest = [3, 7, 10, 14, 17, 21, 24, 28].includes(n);
      const bg = today ? C.primary : done ? C.tertiaryContainer : C.surfaceLowest;
      const fg = today ? '#FFFFFF' : done ? C.onTertiaryContainer : C.onSurface;
      return `<div style="border-radius:12px;padding:6px 4px;text-align:center;background:${bg};color:${fg};border:1px solid ${today || done ? 'transparent' : C.outlineVariant};cursor:pointer" data-go="G04"><div style="font-size:15px;font-weight:600">${n}</div><div style="font-size:12px;opacity:.85">${rest ? 'rest' : done ? 'done' : 'train'}</div></div>`;
    }).join('')
    + `</div>`
    + row(`${row(`${icon('check_circle', { size: 16, color: C.tertiary, fill: true })}<div style="font-size:13px;color:${C.onSurface}">Completed</div>`, { gap: 5, justify: 'flex-start' })}${row(`${icon('self_improvement', { size: 16, color: C.onSurfaceVariant })}<div style="font-size:13px;color:${C.onSurface}">Rest day</div>`, { gap: 5, justify: 'flex-start' })}`, { gap: 14, justify: 'flex-start' })
    + listItem({ lead: icon('event_available', { size: 22, color: C.primaryDim }), title: 'Subscription · 8 Sep to 7 Oct', sub: 'What happens when it ends', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G16' })
  , { pad: '0 16px 0', gap: 12 })
  + navBar('Coaching'));

const G06 = phone(
  statusBar()
  + appBar({ title: 'Move 2 of 5', lead: 'close', leadGo: 'G04', actions: [{ icon: 'pause' }] })
  + body(
    row(`${col(`${h('Goblet squat', 'headline')}${m('From Coach Sara')}`, { gap: 2, grow: true })}${pill('Her note', { ic: 'info', bg: C.primarySoft, color: C.primaryDim })}`)
    + card(m('“Keep 12 kg and aim for 12 reps. Stop at 10 if your knees complain.”'), { v: 'sage', pad: '12px 14px' })
    + col(`${setRow(1, '12 kg × 12', '12 kg × 12', 'done')}${setRow(2, '12 kg × 12', '—', 'now')}${setRow(3, '12 kg × 12', '—', '')}`, { gap: 8 })
    + row(`${btn('Swap exercise', { v: 'outlined', h: 44, size: 14, go: 'G08' })}${btn('Ask about this', { v: 'outlined', h: 44, size: 14, go: 'G14' })}${btn('Skip', { v: 'text', h: 44, size: 14 })}`, { gap: 6 })
  , { pad: '0 16px 0', gap: 12 })
  + footer(K.bigBtn('Complete set 2', 'Rest timer starts itself', { go: 'G07' })));

const G07 = phone(
  statusBar()
  + appBar({ title: 'Move 2 of 5', lead: 'close', leadGo: 'G04', actions: [{ icon: 'pause' }] })
  + body(
    snackbar('Set 2 saved · 12 kg × 12', { action: 'Undo', go: 'G06' })
    + `<div style="flex:1;min-height:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px">`
    + ringStat(55, '0:45', 'rest', { size: 190, thickness: 14 })
    + `<div style="max-width:300px;text-align:center;font-size:15px;line-height:22px;color:${C.onSurfaceVariant}">Sara set 45 seconds between these sets.</div></div>`
    + card(row(`${col(`${m('Up next')}${strong('Set 3 · 12 kg × 12', 'titleM')}`, { gap: 2, grow: true })}${btn('Skip timer', { v: 'text', h: 40, size: 14, go: 'G06' })}`), { gap: 6, pad: '12px 14px' })
    + row(`${btn('Share form video', { v: 'outlined', h: 44, size: 14, ic: 'videocam', go: 'G15' })}${btn('Finish workout', { v: 'outlined', h: 44, size: 14, go: 'G09' })}`, { gap: 8 })
  , { pad: '4px 16px 0', gap: 10 })
  + footer(btn("I'm ready, next set", { h: 54, go: 'G06' })));

const G08 = phone(
  statusBar()
  + appBar({ title: 'Move 2 of 5', lead: 'close', leadGo: 'G06' })
  + body(row(`${h('Goblet squat', 'headline')}${m('From Coach Sara')}`), { pad: '0 16px 0' })
  + navBar('Coaching')
  + sheet(
    h('Swap this exercise', 'titleL')
    + m('Sara approved these in advance, so you do not have to wait for a reply.')
    + listItem({ title: 'Box squat to a chair', sub: 'Coach-approved · same muscles, less depth', trail: icon('check_circle', { size: 24, color: C.primary, fill: true }), v: 'selected', go: 'G06' })
    + listItem({ title: 'Glute bridge', sub: 'Coach-approved · nothing standing', go: 'G06' })
    + btn('Ask Sara for something else', { v: 'outlined', h: 48, size: 15, go: 'G14' })
    + btn('Skip this exercise', { v: 'text', h: 44, size: 15, go: 'G06' }), { gap: 10 }),
  { layered: true });

const G09 = phone(
  statusBar()
  + body(
    `<div style="height:6px"></div>`
    + col(`${h('Session done', 'display')}${m('Full-body strength · 34 minutes · from Coach Sara')}`, { gap: 6 })
    + card(col(`${kv('Sets completed', '12 of 14')}${kv('Skipped', '2 · lunges')}${kv('Personal best', '1 · goblet squat 12 kg × 12', { last: true })}`, { gap: 0 }), { v: 'sage', pad: '8px 16px' })
    + col(`${m('How hard was it?')}${chipRow(['Easy', 'About right', 'Hard'], 1)}`, { gap: 8 })
    + field({ label: 'Anything Sara should know? Optional', value: 'Knees felt fine today.' })
    + m('Your actual numbers go to Sara. Prescribed values are never counted as completed work.')
  , { pad: '4px 16px 0', gap: 12 })
  + footer(btn('Save and send to Sara', { h: 56, ic: 'send', go: 'G04' }) + btn('Back to today', { v: 'text', h: 44, size: 15, go: 'G04' })));

const G10 = phone(
  statusBar('1:12')
  + appBar({ title: 'Log lunch', lead: 'close', leadGo: 'G04' })
  + body(
    row(`${chip('From your plan', { sel: true, grow: true })}${chip('Recent', { grow: true, go: 'E02' })}${chip('Search', { grow: true, go: 'E02' })}`, { gap: 8 })
    + card(
      media({ label: 'food photo', h: 120, ic: '' })
      + col(`${strong('Koshari bowl, medium', 'titleL')}${m('1 serving · 540 kcal · 18 g protein')}`, { gap: 3 })
      + m('Sara’s note: “Add the salad if you are still hungry after.”')
      + row(`${chip('Rice, lentils, pasta')}${chip('Tomato sauce')}`, { gap: 8, justify: 'flex-start' }), { gap: 10 })
    + row(`${btn('Adjust portion', { v: 'outlined', h: 44, size: 14, go: 'G11' })}${btn('An alternative', { v: 'outlined', h: 44, size: 14, go: 'E02' })}${btn('Something else', { v: 'text', h: 44, size: 14, go: 'E02' })}`, { gap: 6 })
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Ate this', { h: 56, ic: 'check', go: 'G11' })));

const G11 = phone(
  statusBar('1:13')
  + body(
    row(`${h('Eat', 'titleL')}${pill('From your plan', { ic: 'sports' })}`)
    + card(
      `<div style="display:flex;gap:8px">${['Breakfast · logged', 'Lunch · logged', 'Dinner · planned'].map((s, i) => `<div style="flex:1;border-radius:14px;padding:10px;background:${i < 2 ? C.tertiaryContainer : C.surfaceLow};border:1px solid ${i < 2 ? 'transparent' : C.outlineVariant}"><div style="font-size:13px;font-weight:600;color:${i < 2 ? C.tertiary : C.onSurfaceVariant}">${s.split(' · ')[0]}</div><div style="font-size:13px;color:${C.onSurface}">${s.split(' · ')[1]}</div></div>`).join('')}</div>`
      + col(`${row(`${strong('Protein', 'titleS')}${m('53 of 95 g')}`)}${linear(56, { h: 10 })}`, { gap: 6 }), { gap: 10 })
    + card(
      row(`${col(`${strong('Koshari bowl, medium', 'titleM')}${m('Logged 1:13 · 1 serving')}`, { gap: 3, grow: true })}${btn('Edit', { v: 'tonal', h: 40, size: 14, go: 'G10' })}`)
      + row(`${chip('½ serving', { grow: true })}${chip('1 serving', { sel: true, grow: true })}${chip('1½', { grow: true })}`, { gap: 8 })
      + btn('Add another serving', { v: 'text', h: 40, size: 14 }), { gap: 10 })
    + m('Changing the plan never changes a log you already saved. Tapping twice does not create a second log.')
    + snackbar('Lunch logged · 1 serving', { action: 'Undo', go: 'G10' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Eat'));

const G12 = phone(
  statusBar()
  + appBar({ title: 'Weekly review', lead: 'close', leadGo: 'G04' })
  + body(
    card(col(`${strong('Your week, from your logs', 'titleM')}${kv('Workouts completed', '3 of 3')}${kv('Days you logged food', '5')}${kv('Shared with Sara', 'Energy and appetite', { last: true })}`, { gap: 0 }), { gap: 8 })
    + col(`${strong('How manageable was your plan?', 'titleM')}${chipRow(['Easy', 'About right', 'Hard to fit in'], 1)}`, { gap: 8 })
    + field({ label: 'What worked well? Optional', value: 'Morning sessions before the kids wake up.' })
    + col(`${m('What would you like to change?')}${chipRow(['Workout time', 'Difficulty'], -1, { grow: false })}${chipRow(['Meals', 'Schedule'], 0, { grow: false })}`, { gap: 6 })
    + card(row(`${col(`${strong('Add weight or photos?', 'titleM')}${m('Optional. Never required.')}`, { gap: 2, grow: true })}${toggle(false)}`, { gap: 12 }), { pad: '12px 14px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Send to Sara', { h: 56, ic: 'send', go: 'G13' })));

const G13 = phone(
  statusBar()
  + appBar({ title: 'Weekly review', leadGo: 'G04' })
  + body(
    row(`${pill('Coach replied', { bg: C.tertiaryContainer, color: C.tertiary, ic: 'check' })}${m('2 hours after you sent it')}`)
    + card(row(`${avatar(40, { initial: 'S' })}${col(`${strong('Sara Hany', 'titleM')}${m('Sunday 20 September')}`, { gap: 2, grow: true })}`, { gap: 12, justify: 'flex-start' }) + bubble('', false, { voice: true }), { gap: 10 })
    + card(
      strong('What we agreed', 'titleM')
      + col([['Keep 12 kg on squats, add reps instead', 'fitness_center'], ['Thursday drops to 20 minutes', 'schedule']].map(([x, ic]) => row(`${icon(ic, { size: 20, color: C.tertiary })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">${x}</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' })).join(''), { gap: 10 }), { v: 'sage', gap: 10 })
    + card(row(`${icon('autorenew', { size: 22, color: C.primaryDim })}${col(`${strong('Plan updated', 'titleM')}${m('Thursday 18 September onwards · published by Sara')}`, { gap: 2, grow: true })}${icon('chevron_right', { size: 22, color: C.onSurfaceVariant })}`, { gap: 10 }), { v: 'tonal', go: 'G05' })
    + m('Yesterday’s logs and any session you already started stay as they were.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Reply in chat', { h: 52, ic: 'chat', go: 'G14' })));

const G14 = phone(
  statusBar()
  + appBar({ title: 'Sara Hany', leadGo: 'G04', actions: [{ icon: 'more_vert' }] })
  + body(
    card(m('Sun to Thu, 9:00 to 17:00 Cairo · replies within one working day. Not monitored at night.'), { v: 'filled', pad: '10px 12px' })
    + `<div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:8px;justify-content:flex-end">`
    + bubble('Can we make Thursday shorter? I have 20 minutes.', true, { state: 'Read', attach: 'Thursday · full-body strength' })
    + bubble('Yes, I have updated Thursday. The new session is in your plan.')
    + `<div style="display:flex;justify-content:center"><div style="background:${C.tertiaryContainer};border-radius:999px;padding:6px 14px;font-size:13px;font-weight:600;color:${C.tertiary};cursor:pointer" data-go="G05">Plan updated · Thursday 18 September</div></div>`
    + bubble('', true, { voice: true, state: 'Delivered' })
    + `</div>`
  , { pad: '4px 16px 0', gap: 8 })
  + footer(card(row(`${iconBtn('add', { d: 36, color: C.primaryDim, go: 'G15' })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Message Sara</div>${iconBtn('mic', { d: 36, color: C.primaryDim, go: 'G15' })}`, { gap: 8, justify: 'flex-start' }), { pad: '10px 12px', r: R.full })));

const G15 = phone(
  statusBar()
  + appBar({ title: 'Sara Hany', leadGo: 'G14' })
  + body(
    `<div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:8px;justify-content:flex-end">`
    + bubble('Yes, I have updated Thursday. The new session is in your plan.')
    + `</div>`
    + card(
      row(`${strong('Voice note', 'titleM')}${pill('0:12', { bg: C.errorContainer, color: C.error })}`)
      + `<div style="display:flex;align-items:center;gap:3px;height:44px">${[14, 26, 38, 20, 34, 44, 22, 30, 16, 24, 36, 18, 28, 12].map((hh, i) => `<div style="flex:1;height:${hh}px;border-radius:999px;background:${i < 9 ? C.primary : C.outlineVariant}"></div>`).join('')}</div>`
      + row(`${btn('Cancel', { v: 'text', h: 44, size: 14 })}${btn('Preview', { v: 'outlined', h: 44, size: 14 })}${btn('Send', { h: 44, size: 14, ic: 'send', go: 'G14' })}`, { gap: 8 }), { gap: 10 })
    + row(`${chip('Photo', { ic: 'image', grow: true })}${chip('Form clip', { ic: 'videocam', grow: true })}${chip("Today's workout", { ic: 'fitness_center', grow: true })}`, { gap: 8 })
    + m('Nothing is sent when you pick it. You preview first, then send.')
  , { pad: '4px 16px 0', gap: 10 })
  + footer(card(row(`${iconBtn('add', { d: 36, color: C.primaryDim })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Recording…</div>${iconBtn('mic', { d: 36, bg: C.primary, color: '#FFFFFF' })}`, { gap: 8, justify: 'flex-start' }), { pad: '10px 12px', r: R.full })));

const G16 = phone(
  statusBar()
  + body(
    row(`${h('Coaching', 'titleL')}${pill('Ended 7 Oct', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + card(row(`${icon('info', { size: 24, color: C.onSurfaceVariant })}${col(`${strong('Your 30 days with Sara have ended', 'titleM')}${m('Everything you did is still here to read.')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start', align: 'flex-start' }), { v: 'filled' })
    + listItem({ lead: icon('history', { size: 22, color: C.primaryDim }), title: 'Your 30-day plan', sub: 'Readable · no new assignments', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G05' })
    + listItem({ lead: icon('forum', { size: 22, color: C.primaryDim }), title: 'Your conversation', sub: 'Readable · new messages are closed', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G14' })
    + listItem({ lead: icon('checklist', { size: 22, color: C.primaryDim }), title: 'Your reviews', sub: '4 reviews and the day-30 wrap-up', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G13' })
    + sageNote('Your own workouts, recipes, logs and My cycle carry on exactly as before. Cycle sharing switched itself off when the coaching ended.')
    + btn('Work with Sara again', { h: 52, go: 'H03' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Coaching'));

const G17 = phone(
  statusBar()
  + appBar({ title: 'Your coaching', leadGo: 'G01' })
  + body(
    segs(3, 2)
    + col(`${strong('Your food', 'titleM')}${m('Step 2 of 3')}`, { gap: 3 })
    + col(`${m('Anything you cannot eat')}${row(`${chip('No nuts', { sel: true })}${chip('No dairy')}${chip('No gluten')}${chip('No shellfish')}`, { gap: 6, justify: 'flex-start', wrap: true })}`, { gap: 6 })
    + col(`${m('How you usually eat')}${chipRow([{ label: 'Everything' }, { label: 'Vegetarian on weekdays', sel: true }], -1, { grow: false })}`, { gap: 6 })
    + col(`${m('Time you have to cook')}${chipRow(['10 min', '20 min', '45 min'], 1, { grow: true })}`, { gap: 6 })
    + card(row(`${col(`${strong('Someone else cooks at home', 'titleM')}${m('Sara will plan around the family pot.')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 11 }), { pad: '11px 13px' })
    + m('This is the only place your allergies come from. Sara sees them while she writes every meal.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Continue', { h: 56, go: 'G02' })));

export const screens = [
  { id: 'G17', html: G17, metric: 'the missing middle step', note: 'Intake announced three steps and delivered two. This is the food step it skipped — and the only place in the product where a client states her allergies, which the coach screens were already displaying as though someone had asked.' },
  { id: 'G01', html: G01, metric: 'saved as you go', note: 'Intake opens with what she bought — the coach, the dates, the review cadence, the hours — before it asks her for anything. Training questions are chips, and her existing profile answers are reused rather than asked twice.' },
  { id: 'G02', html: G02, metric: 'cycle sharing starts off', note: 'The third step separates two consents that most apps merge: coaching sees her training and food, and cycle information stays hers unless she switches it on. The preview shows exactly what the coach would see before anything is shared.' },
  { id: 'G03', html: G03, metric: 'no invented assignments', note: 'While the plan is being written, nothing is faked. Chat works, the library works, My cycle works, and the state says plainly that nothing is scheduled yet.' },
  { id: 'G04', html: G04, metric: 'start 1 tap · log 1 tap', note: 'Today is the coach plan: the session with her note on it, the meals already chosen, the review that is due, and any change she published. The month is one tap away, so this screen only ever shows the next actions.' },
  { id: 'G05', html: G05, metric: '30 deliberate days', note: 'Four full weeks plus two days, with rest days placed on purpose rather than left blank. Meals repeat, and the copy says so — a month of food is not thirty new recipes, and pretending otherwise is how coaches burn out.' },
  { id: 'G06', html: G06, metric: 'prescribed and actual, side by side', note: 'Every set shows what Sara prescribed next to what she actually did, and untouched sets are never pre-filled or counted. Swapping offers the coach-approved options first, so she is not stuck waiting for a reply mid-session.' },
  { id: 'G07', html: G07, metric: '0 taps to rest', note: 'The rest timer is the coach\'s, not a default: it runs the seconds Sara set. Undo sits inside the confirmation, and finishing early is always available — an assigned session is still hers to stop.' },
  { id: 'G08', html: G08, metric: 'approved first, ask second', note: 'Substitutions the coach approved in advance turn a blocked session into a completed one. Asking is offered after them, and skipping stays available without asking anyone.' },
  { id: 'G09', html: G09, metric: 'actual work only', note: 'The summary reports completed and skipped sets honestly, adds optional effort and a note, and sends the real numbers. Nothing here converts a prescription into a result.' },
  { id: 'G10', html: G10, metric: 'planned meal, 1 tap', note: 'Opening lunch from Home lands on today\'s planned lunch with the serving and the coach note ready. Adjusting the portion, choosing an alternative or eating something else are all secondary — because most days, she ate the thing.' },
  { id: 'G11', html: G11, metric: 'one log, corrected in place', note: 'A logged meal can be edited to the portion she actually ate, and a deliberate second helping is a separate action so repeated taps never double-count. The same log appears in Eat, on Home and in the coach\'s view.' },
  { id: 'G12', html: G12, metric: '1 minute, mostly pre-filled', note: 'The review is written from her logs, so the only new input is how manageable it felt and what she would change. Weight and photos are offered, off by default, and never required.' },
  { id: 'G13', html: G13, metric: 'a reply that changes the plan', note: 'The coach\'s answer arrives with the two things they agreed and a labelled plan update that actually exists in the plan. A message that says something changed, with nothing changed behind it, is how coaching over chat fails.' },
  { id: 'G14', html: G14, metric: 'context attached, states shown', note: 'Familiar messaging with the app\'s own design: attachments open the record they refer to, delivery states are visible, and the header states real working hours so nobody expects a 2am reply. Plan updates appear as system cards, separate from what the coach wrote.' },
  { id: 'G15', html: G15, metric: 'preview before send', note: 'Voice notes are the fastest way both sides communicate here. Nothing sends on selection: record, preview, then send, with cancel available throughout — and a failed send retries without duplicating the message.' },
  { id: 'G16', html: G16, metric: 'history stays readable', note: 'When the 30 days end, nothing is deleted and nothing pretends to be active. New assignments and messages close, the self-guided app and My cycle continue, and optional cycle sharing switches itself off with the relationship.' },
];
