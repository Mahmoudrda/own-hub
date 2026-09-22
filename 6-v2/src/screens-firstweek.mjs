import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sageNote, listItem, appBar, avatar, spacer, sectionHead } = K;

// A first-week arc, not a badge layer. The health-app evidence is that visible
// failure indicators and daily streaks erode the motivation they were built to
// create, so this has neither: the steps wait, nothing expires, and the reward is
// the points system that already exists rather than a parallel currency.
const step = (n, title, sub, state, goId) => {
  const done = state === 'done', now = state === 'now';
  return `<div style="border-radius:${R.md}px;padding:11px 12px;display:flex;align-items:center;gap:11px;background:${done ? C.tertiaryContainer : C.surfaceLowest};border:${now ? `2px solid ${C.primary}` : `1px solid ${C.outlineVariant}`}${goId ? ';cursor:pointer' : ''}"${goId ? ` data-go="${goId}"` : ''}>`
    + (done
      ? icon('check_circle', { size: 24, color: C.tertiary, fill: true })
      : `<div style="width:24px;height:24px;border-radius:999px;border:2px solid ${now ? C.primary : C.outlineVariant};box-sizing:border-box;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;color:${now ? C.primary : C.onSurfaceVariant}">${n}</div>`)
    + `<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:2px"><div style="font-size:15px;font-weight:600;color:${done ? C.onTertiaryContainer : C.onSurface}">${title}</div><div style="font-size:13px;color:${C.onSurfaceVariant}">${sub}</div></div>`
    + (done ? `<div style="font-size:13px;font-weight:600;color:${C.tertiary}">done</div>` : now ? icon('chevron_right', { size: 21, color: C.primary }) : '')
    + `</div>`;
};

const T07 = phone(
  statusBar()
  + appBar({ title: 'Your first week', leadGo: 'T06', actions: [{ icon: 'close', go: 'T06' }] })
  + body(
    row(`${ringStat(40, '2', 'of 5', { size: 78, thickness: 10 })}${col(`${strong('Two done, three waiting', 'titleM')}${m('No timer on any of them. Miss a day and nothing here changes.')}`, { gap: 3, grow: true })}`, { gap: 13, justify: 'flex-start' })
    + col(`${step(1, 'Log one set', 'You did · goblet squat, 12 kg', 'done')}${step(2, 'Log one meal', 'You did · ful and baladi', 'done')}${step(3, 'Finish one session', '15 minutes, five moves', 'now', 'R03')}${step(4, 'Join one group', 'Beginners, postpartum or your city', '', 'M04')}${step(5, 'Add a follow-up picture', 'Once you have a post to follow up on', '', 'M11')}`, { gap: 7 })
    + card(row(`${icon('workspace_premium', { size: 22, color: C.primaryDim })}${col(`${strong('35 points so far', 'titleM')}${m('The same points the rest of the app gives. Nothing extra for opening it.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'tonal', pad: '11px 13px' })
    + sageNote('Finishing all five is not a deadline. It is the shortest path to knowing where everything is.')
  , { pad: '0 16px 0', gap: 11 })
  + footer(btn("Start today's session", { h: 54, ic: 'play_arrow', go: 'R03' })));

const T08 = phone(
  statusBar()
  + body(
    `<div style="height:8px"></div>`
    + `<div style="align-self:center;width:76px;height:76px;border-radius:999px;background:${C.tertiaryContainer};display:flex;align-items:center;justify-content:center">${icon('check_circle', { size: 40, color: C.tertiary, fill: true })}</div>`
    + `<div style="text-align:center;font-size:26px;line-height:33px;font-weight:600;color:${C.onPrimaryContainer}">You know your way around</div>`
    + `<div style="text-align:center;font-size:15px;line-height:23px;color:${C.onSurfaceVariant};padding:0 10px">All five done. Nothing about the app changes from here. You have just already used every part of it once.</div>`
    + card(col(`${strong('What it added up to', 'titleM')}${row(`${m('Points')}${strong('90', 'titleS')}`)}${row(`${m('Level')}${strong('2', 'titleS')}`)}${row(`${m('This week')}${strong('3 of 3 · it counted', 'titleS')}`)}`, { gap: 7 }), { v: 'sage', gap: 8 })
    + card(row(`${icon('spa', { size: 22, color: C.tertiary })}${col(`${strong('Your first rest week is banked', 'titleM')}${m('It covers a week you miss, without being asked.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { pad: '11px 13px' })
  , { pad: '4px 16px 0', gap: 12 })
  + footer(btn('Back to today', { h: 54, go: 'T01' }) + btn('See your progress', { v: 'text', h: 42, size: 15, go: 'P01' })));

const K25 = phone(
  statusBar()
  + appBar({ title: 'Your first week', leadGo: 'K24', actions: [{ icon: 'close', go: 'K24' }] })
  + body(
    row(`${ringStat(50, '2', 'of 4', { size: 78, thickness: 10 })}${col(`${strong('Two done', 'titleM')}${m('Each one is work a client will actually see. None of it is a tour.')}`, { gap: 3, grow: true })}`, { gap: 13, justify: 'flex-start' })
    + col(`${step(1, 'Publish your page', 'Live for 1,204 women a month', 'done')}${step(2, 'Save one split', 'Upper / lower · on 3 clients', 'done')}${step(3, 'Set up an assessment', 'It runs before anyone’s first week', 'now', 'K21')}${step(4, 'Answer your first enquiry', 'She pays only once you accept', '', 'K09')}`, { gap: 7 })
    + card(row(`${icon('verified_user', { size: 22, color: C.tertiary })}${col(`${strong('Certificates cleared this morning', 'titleM')}${m('Your page is visible and you can take clients.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'sage', pad: '11px 13px' })
    + sageNote('Nothing here expires, and no client sees your progress through it.')
  , { pad: '0 16px 0', gap: 11 })
  + footer(btn('Set up the assessment', { h: 54, go: 'K21' }) + btn('Back to today', { v: 'text', h: 42, size: 15, go: 'K24' })));

export const screens = [
  { id: 'T07', html: T07, metric: '5 steps, no deadline', note: 'The activation evidence for onboarding checklists is strong, but the health-app evidence is that daily targets and visible failure erode motivation as life pressure rises. So this arc has five concrete first actions and deliberately no timer, no streak and no failed state — the steps simply wait. The reward is the points system that already exists, and the copy says plainly that nothing extra is given for opening the app.' },
  { id: 'T08', html: T08, metric: 'quiet, not confetti', note: 'Completion is a calm summary rather than a second celebration — the one confetti burst in this product belongs to finishing a workout, and spending it here would cheapen that. What it names is what carried forward: points, level, the week that counted, and the first banked rest week.' },
  { id: 'K25', html: K25, metric: '4 steps, all real work', note: 'The coach arc is the same shape with a different payload: every step produces something a client will see, so finishing it leaves her with a published page, a saved split, an assessment and an accepted client rather than a completed tutorial. Her progress through it is never shown to clients.' },
];
