import * as K from './kit.mjs';
const { C, R, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, bigBtn, iconBtn, icon, chipRow, segs, navBar, sheet, snackbar, banner, sageNote, listItem, homeBar, appBar, media, logBtn, avatar, linear } = K;

export const plate = (name, kcal, goId = 'E04') => `<div style="flex:1;border-radius:${R.md}px;background:${C.surfaceLow};border:1px solid ${C.outlineVariant};padding:12px;display:flex;flex-direction:column;gap:6px;cursor:pointer" data-go="${goId}"><div style="font-size:16px;font-weight:600;line-height:21px;color:${C.onSurface}">${name}</div><div style="font-size:14px;color:${C.onSurfaceVariant}">${kcal}</div></div>`;

const greeting = (day, name, right = '') => row(`${h(day, 'titleL')}<div style="display:flex;align-items:center;gap:6px">${pill('Level 7 · Regular')}${right}</div>`);

const workoutCard = () => card(
  row(`${strong('Legs and glutes', 'titleL')}${pill('Week 3 of 8', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
  + t('15 min · 5 moves · quiet, no equipment, last week’s weights', { k: 'bodyM', color: C.onSurfaceVariant })
  + btn("Start, everything's ready", { h: 54, ic: 'play_arrow', go: 'R07' })
  + btn('I already did it', { v: 'text', h: 40, go: 'T02' }), { gap: 10 });

const mealCard = () => card(
  row(`${strong('Breakfast, your usual')}${m('8:40')}`)
  + `<div style="display:flex;gap:8px">${plate('Ful and baladi', '410 kcal')}${plate('Eggs and tea', '290 kcal')}</div>`
  , { gap: 10, go: 'E02' });

const weekCard = (done, goal, line) => card(
  row(`${strong(`This week, ${done} of ${goal}`)}${m(line)}`)
  + segs(goal, done), { gap: 8, pad: '12px 16px', go: 'P01' });

const T01 = phone(
  statusBar()
  + body(
    greeting('Tuesday', '', iconBtn('psychology', { go: 'X01' }) + iconBtn('notifications', { go: 'A01' }))
    + card(row(`${icon('directions_walk', { size: 26, color: C.tertiary })}${col(`${strong('Walk this morning · 32 min')}`, { gap: 2, grow: true })}${btn('Count it', { v: 'sage', h: 44, size: 15, go: 'T01' })}`, { gap: 10, justify: 'flex-start' }), { v: 'sage', pad: '8px 12px', r: R.md })
    + workoutCard()
    + mealCard()
    + weekCard(1, 3, 'Two more and the week counts.')
    + listItem({ lead: icon('self_improvement', { size: 22, color: C.primaryDim }), title: 'My cycle · period day 2', sub: '', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'Y03' })
  )
  + navBar('Home'));

const T02 = phone(
  statusBar()
  + body(greeting('Tuesday', '') + workoutCard() + mealCard())
  + navBar('Home')
  + sheet(
    h('What did you do?', 'titleL')
    + m('Tap one and it is saved. Undo for five seconds.')
    + listItem({ title: "Legs and glutes, today's plan", sub: "15 min · 5 moves · last week's weights", trail: logBtn(true, 'Save', { go: 'R12' }), v: 'selected' })
    + listItem({ title: 'Upper body, like last Thursday', sub: '20 min · 6 moves', trail: logBtn(false, 'Save', { go: 'R12' }) })
    + card(strong('A class or a walk') + m('Counts by time alone') + chipRow(['20 min', '30 min', '45 min', '1 hour'], 1), { v: 'filled', pad: '12px 14px', gap: 8 })
    + btn('Or say it: "Zumba, 40 minutes"', { v: 'outlined', h: 52, ic: 'mic', size: 15 }), { gap: 12 }),
  { layered: true });

const T03 = phone(
  statusBar('', { color: '#FFFFFF' })
  + body(
    `<div style="height:8px"></div>`
    + `<div style="text-align:center;font-size:17px;font-weight:500;color:rgba(255,255,255,.85)">Tuesday 16 September</div>`
    + `<div style="text-align:center;font-size:82px;line-height:92px;font-weight:600;color:#FFFFFF;letter-spacing:-.02em">8:42</div>`
    + `<div style="flex:1"></div>`
    + card(
      // Where a notification draws the app's icon. The app shows the brand
      // tile here (assets/brand/logo/ownhub-tile.png, 28 px, 9 px corners);
      // this generator draws no images, so a neutral tile stands in for it.
      row(`<div role="img" aria-label="Own Hub brand mark" style="width:28px;height:28px;flex:none;border-radius:9px;background:${C.surfaceContainer};border:1px solid ${C.outlineVariant}"></div><div style="flex:1;font-size:14px;font-weight:600;color:${C.onSurfaceVariant}">Own Hub</div>${m('now', 'nav')}`, { gap: 8 })
      + strong('Breakfast, your usual?', 'titleM')
      + m('Ful and baladi · 410 kcal · 22 g protein')
      + `<div style="display:flex;gap:8px">${btn('Log it', { h: 48, size: 15, go: 'T01' })}${btn('Something else', { v: 'outlined', h: 48, size: 15, go: 'E02' })}</div>`,
      { v: 'elevated', gap: 8, pad: '14px' })
    + `<div style="height:8px"></div>`, { pad: '8px 12px 0', gap: 10 })
  + homeBar({ color: '#FFFFFF' }), { bg: '#241A1E' });

const T04 = phone(
  statusBar()
  + body(
    greeting('Monday', '')
    + card(
      row(`${icon('spa', { size: 24, color: C.tertiary })}${strong('Your 14 weeks are safe', 'titleM')}`, { gap: 10, justify: 'flex-start' })
      + t('A rest week covered last week, so nothing changed. The next one comes after four counted weeks.', { k: 'bodyM' }), { v: 'sage', gap: 8, pad: '14px 16px' })
    + card(
      row(`${strong('The shortest one we have', 'titleL')}${pill('10 min', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
      + t('Four moves, floor only, nothing to carry. It counts toward your week like any session.', { k: 'bodyM', color: C.onSurfaceVariant })
      + btn('Start the 10 minutes', { h: 54, ic: 'play_arrow', go: 'R07' }), { gap: 10 })
    + card(row(`${strong('Or just log breakfast')}${m('8:40')}`) + `<div style="display:flex;gap:8px">${plate('Ful and baladi', '410 kcal')}${plate('Eggs and tea', '290 kcal')}</div>`, { gap: 10 })
    + weekCard(0, 3, 'Nothing is lost. One session starts it.')
  )
  + navBar('Home'));

const T05 = phone(
  statusBar()
  + body(greeting('Monday', '') + workoutCard())
  + navBar('Home')
  + sheet(
    h('You are Showing up for now', 'titleL')
    + t('Regular asks for four of your last eight weeks, and three counted. One more counted week brings it back.', { k: 'bodyM', color: C.onSurfaceVariant })
    + card(
      `<div style="font-size:15px;font-weight:600;color:${C.tertiary}">Kept, all of it</div>`
      + [['Your 14 counted weeks', 'calendar_month'], ['Level 7 and every point', 'workspace_premium'], ['Everything Regular opened', 'lock']].map(([x, ic]) => row(`${icon(ic, { size: 20, color: C.tertiary })}<div style="flex:1;font-size:15px;color:${C.onSurface}">${x}</div>`, { gap: 10, justify: 'flex-start' })).join(''),
      { v: 'sage', gap: 8, pad: '12px 14px' })
    + btn('Start 10 minutes', { h: 56, ic: 'play_arrow', go: 'R07' })
    + btn('Make this week 2 sessions', { v: 'outlined', h: 48, size: 15, go: 'T01' }), { gap: 12 }),
  { layered: true });

export const screens = [
  { id: 'T01', html: T01, metric: 'walk 1 tap · set 1 tap · meal 1 tap', note: 'Everything she might log today is already written here: the walk her phone counted, the session from her plan with last week\'s weights, and the breakfast she has at this hour. After 8pm an unlogged session flips its button to "Did it — log Legs and glutes", so the usual case is one tap. The box takes anything else.' },
  { id: 'T02', html: T02, metric: '2 taps for a whole session', note: 'For the woman who trains without her phone, which is most of them. Three likely answers instead of one guess: today\'s plan, her last other session, and time-only activity like a class or a walk. Sets are copied from the last run and marked "as last time", so recalled sessions never set a personal best.' },
  { id: 'T03', html: T03, metric: '1 tap, app stays closed', note: 'One nudge a day at most, at the hour she usually logs, and only for a meal she has had three times or more. The button logs it without opening the app. Three ignored in a row stops them, and they thin out by themselves once she logs most days.' },
  { id: 'T04', html: T04, metric: 'the screen that decides retention', note: 'Monday is a fresh start, so this is when the app speaks. What was protected is said before anything else, then the ask shrinks to the shortest session and an even smaller meal log. No red, no zero, no count of what was missed.' },
  { id: 'T05', html: T05, metric: 'shown once, then silent', note: 'Slipping is shown once, on the Monday it happens, framed by how close the way back is — one counted week, not the ten it took to get there. Everything earned is listed as kept, and she can shrink this week\'s goal in one tap: a goal she can meet beats a goal she abandons.' },
];
