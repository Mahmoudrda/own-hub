import * as K from './kit.mjs';
const { C, R, E, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, bigBtn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, banner, sageNote, listItem, homeBar, appBar, media, avatar, spacer, field } = K;

const moveRow = (name, detail, { done = false, now = false, go = 'R04' } = {}) => listItem({
  lead: done ? icon('check_circle', { size: 26, color: C.tertiary, fill: true }) : `<div style="width:26px;height:26px;border-radius:999px;border:2px solid ${now ? C.primary : C.outlineVariant};box-sizing:border-box"></div>`,
  title: name, sub: detail, trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go, v: now ? 'selected' : 'outlined',
});

const setRow = (label, value, state) => `<div style="height:52px;border-radius:${R.md}px;padding:0 14px;display:flex;align-items:center;gap:10px;background:${state === 'done' ? C.tertiaryContainer : C.surfaceLowest};border:${state === 'now' ? `2px solid ${C.primary}` : `1px solid ${C.outlineVariant}`};flex:0 0 auto">`
  + (state === 'done' ? icon('check_circle', { size: 22, color: C.tertiary, fill: true }) : `<div style="width:22px;height:22px;border-radius:999px;border:2px solid ${state === 'now' ? C.primary : C.outlineVariant};box-sizing:border-box"></div>`)
  + `<div style="flex:1;font-size:16px;font-weight:600;color:${C.onSurface}">${label}</div><div style="font-size:16px;font-weight:600;color:${state === 'done' ? C.onTertiaryContainer : C.onSurfaceVariant}">${value}</div></div>`;

const R01 = phone(
  statusBar()
  + body(
    row(`${h('Train', 'titleL')}${iconBtn('search', { go: 'R11' })}`)
    + card(
      row(`${col(`${m('Postpartum rebuild')}${strong('Week 3 of 8', 'titleL')}`, { gap: 1, grow: true })}${ringStat(66, '2/3', 'week', { size: 68, thickness: 9 })}`)
      + `<div style="display:flex;gap:8px">${chip('Mon ✓', { sel: true, grow: true })}${chip('Today', { grow: true, go: 'R03' })}${chip('Thu', { grow: true })}</div>`
      + btn('Continue · from Sara', { h: 56, ic: 'play_arrow', go: 'G06' })
      + btn('See the whole program', { v: 'text', h: 40, size: 15, go: 'R02' }), { gap: 10 })
    + col(`${strong('Short ones that still count')}${`<div style="display:flex;gap:8px">`
      + [['10 min', 'Floor only', 'R06'], ['15 min', 'Quiet', 'R03'], ['20 min', 'Dumbbells', 'R03']].map(([a, b, g]) => `<div style="flex:1;border-radius:${R.md}px;border:1px solid ${C.outlineVariant};background:${C.surfaceLowest};padding:12px;display:flex;flex-direction:column;gap:4px;cursor:pointer" data-go="${g}"><div style="font-size:17px;font-weight:600;color:${C.onSurface}">${a}</div><div style="font-size:14px;color:${C.onSurfaceVariant}">${b}</div></div>`).join('') + `</div>`}`, { gap: 10 })
    + col(`${row(`${strong('All workouts')}${m('124 videos')}`)}${chipRow([{ label: 'Quiet', ic: 'volume_off' }, { label: 'No equipment' }, { label: '10 min' }], -1, { grow: false })}`, { gap: 10 })
    + listItem({ lead: icon('self_improvement', { size: 24, color: C.primaryDim }), title: 'Not feeling it today?', sub: 'See a gentler option based on your check-in', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'Y06' })
  )
  + navBar('Train'));

const R02 = phone(
  statusBar()
  + appBar({ title: 'Postpartum rebuild', leadGo: 'R01', actions: [{ icon: 'download', go: 'R02' }] })
  + body(
    media({ label: 'coach demo still', h: 150, chipText: '8 weeks' })
    + row(`${chip('3 days a week', {})}${chip('At home', {})}${chip('Quiet', {})}`, { gap: 8, justify: 'flex-start' })
    + t('Rebuilt around the pelvic floor first. Cleared for postpartum from week six, with your doctor\'s go-ahead.', { k: 'bodyM', color: C.onSurfaceVariant })
    + row(`${strong('Week 3')}${m('2 of 3 done')}`)
    + moveRow('Day 1 · Full body', '15 min · done Monday', { done: true, go: 'R03' })
    + moveRow('Day 2 · Legs and glutes', '15 min · today', { now: true, go: 'R03' })
    + moveRow('Day 3 · Upper body', '20 min · Thursday', { go: 'R03' })
    + btn('Change program', { v: 'text', h: 44, size: 15, go: 'R11' })
  , { pad: '0 16px 0' })
  + footer(btn('Start day 2', { h: 56, ic: 'play_arrow', go: 'R03' })));

const R03 = phone(
  statusBar()
  + appBar({ title: 'Legs and glutes', leadGo: 'R01', actions: [{ icon: 'more_vert' }] })
  + body(
    row(`${col(`${h('15 minutes, 5 moves', 'titleL')}${m('Quiet · no equipment · floor')}`, { gap: 2, grow: true })}`)
    + moveRow('Glute bridge', '3 × 12 · bodyweight')
    + moveRow('Goblet squat', '3 × 10 · 12 kg suggested', { now: true })
    + moveRow('Step-back lunge', '3 × 10 each side')
    + moveRow('Hip thrust hold', '3 × 30 seconds')
    + moveRow('Dead bug', '3 × 8 each side')
    + m('Tap any move to watch it or swap it.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Start — everything\'s ready', { h: 56, ic: 'play_arrow', go: 'R07' }) + btn('I already did it', { v: 'text', h: 44, size: 15, go: 'T02' })));

const R04 = phone(
  statusBar()
  + appBar({ title: '', lead: 'close', leadGo: 'R03' })
  + body(
    media({ label: 'demo video, woman coach', h: 200 })
    + row(`${h('Goblet squat', 'titleL')}${pill('0:24', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + chipRow([{ label: 'Quiet' }, { label: 'No jumping' }, { label: 'Legs' }], -1, { grow: false })
    + col([['Heels flat, knees out over your toes', 'check'], ['Chest up, weight held at your chest', 'check'], ['Stand up strong, squeeze at the top', 'check']]
      .map(([x, ic]) => row(`${icon(ic, { size: 20, color: C.tertiary })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">${x}</div>`, { gap: 10, justify: 'flex-start' })).join(''), { gap: 10 })
    + sageNote('Knees sore? Swap it for a glute bridge. Same muscles, nothing on the floor.')
  , { pad: '0 16px 0' })
  + footer(btn('Back to the workout', { h: 56, go: 'R03' }) + btn('Swap this move', { v: 'outlined', h: 48, size: 15, go: 'R05' })));

const R05 = phone(
  statusBar()
  + appBar({ title: 'Legs and glutes', leadGo: 'R03' })
  + body(moveRow('Glute bridge', '3 × 12 · bodyweight') + moveRow('Goblet squat', '3 × 10 · 12 kg', { now: true }) + moveRow('Step-back lunge', '3 × 10 each side'), { pad: '0 16px 0', gap: 10 })
  + navBar('Train')
  + sheet(
    h('Swap this move', 'titleL')
    + m('Same muscles, quieter on the floor.')
    + listItem({ title: 'Glute bridge', sub: 'No standing, nothing to hold', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), v: 'selected' })
    + listItem({ title: 'Step-back lunge', sub: 'One leg at a time, holds the weight' })
    + btn('Swap it', { h: 56, go: 'R03' }), { gap: 12 }),
  { layered: true });

const R06 = phone(
  statusBar('', { color: '#FFFFFF' })
  + `<div style="flex:1;min-height:0;background:${C.inverseSurface};display:flex;flex-direction:column">`
  + `<div style="flex:1;min-height:0;display:flex;align-items:center;justify-content:center;position:relative">`
  + `<div style="font-family:${K.F.mono};font-size:12px;color:rgba(255,255,255,.55);position:absolute;top:12px;left:16px">follow-along video</div>`
  + ringStat(64, '0:24', 'left', { size: 168, c: C.primaryContainer, track: 'rgba(255,255,255,.18)', thickness: 14 })
  + `</div>`
  + `<div style="flex:0 0 auto;padding:16px;display:flex;flex-direction:column;gap:12px">`
  + row(`${col(`<div style="font-size:14px;color:rgba(255,255,255,.7)">Move 3 of 5</div><div style="font-size:24px;font-weight:600;color:#FFFFFF">Glute bridge</div>`, { gap: 2, grow: true })}${pill('logs itself', { bg: 'rgba(255,255,255,.16)', color: '#FFFFFF', ic: 'check' })}`)
  + `<div style="display:flex;gap:10px">${btn('Pause', { v: 'white', h: 56, ic: 'pause' })}${btn('Skip this move', { v: 'outlined', h: 56, size: 15, go: 'R07' })}</div>`
  + `</div></div>`
  + homeBar({ bg: C.inverseSurface, color: '#FFFFFF' }), { bg: C.inverseSurface });

const R07 = phone(
  statusBar()
  + appBar({ title: 'Move 2 of 5', lead: 'close', leadGo: 'R03', actions: [{ icon: 'pause' }] })
  + body(
    col(`${h('Goblet squat', 'headline')}${m('Set 2 of 3')}`, { gap: 2 })
    + card(
      row(`<div style="font-size:38px;line-height:46px;font-weight:600;color:${C.onSurface}">12 kg × 10</div>${btn('Change', { v: 'tonal', h: 44, size: 15, go: 'R08' })}`)
      + sageNote('Last Tuesday: 10 kg × 10, every set finished. So we added 2 kg.'), { gap: 12, pad: '18px' })
    + col(`${m('This move')}${setRow('Set 1', '12 kg × 10', 'done')}${setRow('Set 2', '12 kg × 10', 'now')}${setRow('Set 3', '12 kg × 10', 'next')}`, { gap: 8 })
  , { pad: '0 16px 0', gap: 14 })
  + footer(bigBtn('Done · 12 kg × 10', 'Rest starts itself', { go: 'R09' }) + btn('I did all 3 sets, log them', { v: 'text', h: 44, size: 15, go: 'R13' })));

const R08 = phone(
  statusBar()
  + appBar({ title: 'Move 2 of 5', lead: 'close', leadGo: 'R07' })
  + body(col(`${h('Goblet squat', 'headline')}${m('Set 2 of 3')}`, { gap: 2 }), { pad: '0 16px 0' })
  + sheet(
    col(`${h('What did you do?', 'titleL')}${m('Set 2 · Goblet squat')}`, { gap: 2 })
    + col(`${m('Weight')}${chipRow(['10 kg', '12 kg', '14 kg'], 1)}`, { gap: 8 })
    + col(`${m('Reps')}${chipRow(['8', '9', '10', '12'], 0)}`, { gap: 8 })
    + sageNote('Next time we keep 12 kg and aim for 10 again. A hard set never drops your weight by itself.')
    + btn('Save · 12 kg × 8', { h: 56, go: 'R09' })
    + btn('Type a different number', { v: 'text', h: 40, size: 15 }), { gap: 12 }),
  { layered: true });

const R09 = phone(
  statusBar()
  + appBar({ title: 'Move 2 of 5', lead: 'close', leadGo: 'R03', actions: [{ icon: 'pause' }] })
  + body(
    snackbar('Set 2 saved · 12 kg × 10', { action: 'Undo', go: 'R07' })
    + `<div style="flex:1;min-height:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px">`
    + ringStat(62, '0:38', 'rest', { size: 210, thickness: 14 })
    + `<div style="max-width:300px;text-align:center;font-size:16px;line-height:24px;color:${C.onSurfaceVariant}">Catch your breath. This starts and stops on its own.</div>`
    + `</div>`
    + card(row(`${col(`${m('Up next')}${strong('Goblet squat, set 3', 'titleM')}`, { gap: 2, grow: true })}${strong('12 × 10', 'titleM')}`), { gap: 6, pad: '14px 16px' })
  , { pad: '4px 16px 0', gap: 12 })
  + footer(btn("I'm ready, next set", { h: 56, go: 'R07' }) + btn('Add 30 seconds', { v: 'text', h: 44, size: 15 })));

const R10 = phone(
  statusBar()
  + body(
    `<div style="height:6px"></div>`
    + col(`${h("That's Tuesday done", 'display')}${t('15 minutes, 5 moves, 14 sets. You typed nothing.', { k: 'bodyM', color: C.onSurfaceVariant })}`, { gap: 6 })
    + card(
      row(`<div style="font-size:32px;font-weight:600;color:${C.tertiary}">+30 points</div>${m('490 total')}`)
      + m('Session 20 · personal best 10')
      + linear(50)
      + t('70 points to level 8.', { k: 'bodyM' }), { v: 'sage', gap: 10 })
    + card(row(`${strong('This week')}${m('2 of 3')}`) + segs(3, 2) + t('One more session and this week counts.', { k: 'bodyM', color: C.onSurfaceVariant }), { gap: 10, pad: '14px 16px' })
    + card(row(`${icon('trophy', { size: 24, color: C.amber, fill: true })}${col(`${strong('A personal best', 'titleM')}${m('Goblet squat, 12 kg × 10. Two kilos more than your best.')}`, { gap: 3, grow: true })}`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '14px 16px' })
  , { pad: '4px 16px 0', gap: 12 })
  + footer(btn('Back to today', { h: 56, go: 'T01' }) + btn('Share the squat with your group', { v: 'text', h: 44, size: 15, go: 'M03' })));

const R11 = phone(
  statusBar()
  + appBar({ title: '', leadGo: 'R01' })
  + body(
    field({ value: 'Search 124 workouts', trail: icon('search', { size: 22, color: C.onSurfaceVariant }) })
    + chipRow([{ label: 'Quiet', sel: true, ic: 'volume_off' }, { label: 'No equipment', sel: true }, { label: '10 min' }], -1, { grow: false })
    + m('18 workouts, quiet and no equipment')
    + listItem({ lead: media({ label: '', h: 56, r: R.sm, ic: 'play_arrow', chipText: '' }).replace('height:56px', 'height:56px;width:72px'), title: 'Floor legs, no jumping', sub: '10 min · beginner · Nour', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'R03' })
    + listItem({ lead: media({ label: '', h: 56, r: R.sm, ic: 'play_arrow' }).replace('height:56px', 'height:56px;width:72px'), title: 'Quiet full body', sub: '15 min · beginner · Mariam', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'R03' })
    + listItem({ lead: media({ label: '', h: 56, r: R.sm, ic: 'play_arrow' }).replace('height:56px', 'height:56px;width:72px'), title: 'Upper body at home', sub: '20 min · easy · Habiba', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'R03' })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Train'));

const R12 = phone(
  statusBar()
  + body(
    `<div style="height:6px"></div>`
    + col(`${h("That's Tuesday done", 'display')}${t('Logged from memory. Your week counts it like any other session.', { k: 'bodyM', color: C.onSurfaceVariant })}`, { gap: 6 })
    + card(
      row(`<div style="font-size:32px;font-weight:600;color:${C.tertiary}">+15 points</div>${m('475 total')}`)
      + m('Session 20')
      + linear(44)
      + t('85 points to level 8.', { k: 'bodyM' }), { v: 'sage', gap: 10 })
    + card(row(`${strong('This week')}${m('2 of 3')}`) + segs(3, 2) + t('One more session and this week counts.', { k: 'bodyM', color: C.onSurfaceVariant }), { gap: 10, pad: '14px 16px' })
    + card(row(`${icon('info', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">No personal best from this one. The numbers were copied, not measured.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'tonal', pad: '12px 14px' })
  , { pad: '4px 16px 0', gap: 12 })
  + footer(btn('Back to today', { h: 56, go: 'T01' })));

const R13 = phone(
  statusBar()
  + appBar({ title: 'Legs and glutes', leadGo: 'R03', actions: [{ icon: 'pause' }] })
  + body(
    snackbar('Goblet squat saved · 3 sets', { action: 'Undo', go: 'R07' })
    + col(`${h('2 of 5 moves done', 'titleL')}${m('Quiet · no equipment · floor')}`, { gap: 2 })
    + moveRow('Glute bridge', '3 × 12 · bodyweight', { done: true })
    + moveRow('Goblet squat', '3 × 12 · 12 kg', { done: true })
    + moveRow('Step-back lunge', '3 × 10 each side', { now: true })
    + moveRow('Hip thrust hold', '3 × 30 seconds')
    + moveRow('Dead bug', '3 × 8 each side')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Next move · step-back lunge', { h: 56, ic: 'play_arrow', go: 'R07' }) + btn('Finish here', { v: 'text', h: 44, size: 15, go: 'R10' })));

export const screens = [
  { id: 'R12', html: R12, metric: 'counts, but sets no best', note: 'The product states in two places that a session logged from memory never sets a personal best, because the numbers were copied. This is the screen that honours it: the week still counts, points are smaller, and the reason is written where the trophy would have been.' },
  { id: 'R13', html: R13, metric: 'the move, not the session', note: 'Logging a whole move returns her to the list with that move struck through and the next one live. Before this, the same tap declared the entire session finished with three moves untrained.' },
  { id: 'R01', html: R01, metric: 'her program first, library second', note: 'Train opens on the one thing she is in the middle of, with the week drawn as three chips she can tap. Short sessions sit above the library because a 10-minute floor session is what gets done on a bad day, and it counts the same.' },
  { id: 'R02', html: R02, metric: 'three levels deep, never four', note: 'The program page carries the promise (pelvic floor first, cleared from week six with a doctor) and the week. Downloading a week is offered here, where data cost is a decision she is already making.' },
  { id: 'R03', html: R03, metric: '1 tap to start · 1 to log it after', note: 'The day is a list of moves with the suggested weights already on them. Both ways in are on the same screen: start now, or say she already did it.' },
  { id: 'R04', html: R04, metric: 'a sheet, not a level', note: 'Exercise detail opens over the day so closing it returns her to the list. Three cues, not a paragraph, and the quieter alternative is offered before she has to ask.' },
  { id: 'R05', html: R05, metric: '2 taps', note: 'Swapping keeps the workout intact: same muscles, quieter or easier. The sheet leaves the list visible behind it, so she can see what she is changing.' },
  { id: 'R06', html: R06, metric: '0 taps to log', note: 'Timed follow-along moves log themselves as they finish — the timer is the log. Nothing to confirm, and the chip says so plainly so the silence is not mistaken for a missed log.' },
  { id: 'R07', html: R07, metric: '1 tap per set, or 1 per move', note: 'The numbers are a sentence she agrees with, not two steppers to fight. The button states exactly what it will save, so confirming and logging are one action. Women who train with the phone on the floor can log the whole move at once.' },
  { id: 'R08', html: R08, metric: '2 taps, no keyboard', note: 'Changing is the exception path: chips hold the values she is likeliest to mean — what was planned, one step either side, and what she did last time. The keyboard only appears if she asks for it, and a hard set never lowers her weight automatically.' },
  { id: 'R09', html: R09, metric: '0 taps required', note: 'The confirmation names the same numbers the button named, with undo inside it for five seconds. The next set is already stated, so the following tap needs no reading, and the timer ends itself if she puts the phone down.' },
  { id: 'R10', html: R10, metric: 'the one celebration', note: 'Confetti lives here and nowhere else. What she earned is named in the order she cares about: that it counted, how close the week is, what she beat. Sharing is a quiet link, because offering a post at the peak moment is a second decision on a screen that should have none.' },
  { id: 'R11', html: R11, metric: 'filters that match her life', note: 'The filters are the constraints she actually has — quiet, no equipment, ten minutes — not muscle-group jargon. The result count is shown so the filters explain the list.' },
];
