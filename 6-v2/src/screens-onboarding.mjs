import * as K from './kit.mjs';
const { C, R, phone, statusBar, body, footer, card, row, col, h, t, m, strong, pill, btn, icon, chip, chipRow, segs, linear, sheet, sageNote, listItem, appBar, media, spacer, field } = K;

const opt = (title, sub, sel = false, goId = '') => card(row(`${col(`${strong(title, 'titleM')}${sub ? m(sub) : ''}`, { gap: 3, grow: true })}${sel ? icon('check_circle', { size: 26, color: C.primary, fill: true }) : `<div style="width:26px;height:26px;border-radius:999px;border:2px solid ${C.outlineVariant};box-sizing:border-box"></div>`}`, { gap: 12 }), { v: sel ? 'selected' : 'outlined', pad: '14px 16px', go: goId });

const step = (n, title, sub, inner, next, back) => phone(
  statusBar()
  + appBar({ leadGo: back, title: `Step ${n} of 4`, actions: [{ icon: 'close', go: 'T01' }] })
  + body(h(title, 'display') + (sub ? m(sub) : '') + `<div style="height:2px"></div>` + inner, { pad: '0 16px 0', gap: 12 })
  + footer(btn('Continue', { h: 56, go: next }) + btn('Skip', { v: 'text', h: 44, size: 15, go: next })));

const O01 = step(1, 'What do you want most?', 'Pick one. It changes the program, not the app.',
  opt('Get stronger', 'Build up, lift a bit more each week', true) + opt('Feel better in my body', 'Energy, sleep, less back pain') + opt('Lose weight steadily', 'Slowly, without cutting food you love') + opt('Get back into it', 'After a break, a birth, or an injury'), 'O02', 'C16');

const O02 = step(2, 'Where will you train?', 'You can change it on any day.',
  opt('At home', 'Quiet moves, floor, nothing to carry', true) + opt('A ladies-only gym', 'Machines and free weights') + opt('Both', 'Home on weekdays, gym when I can')
  + col(`${m('What do you have at home?')}${chipRow([{ label: 'Nothing', sel: true }, { label: 'A mat' }, { label: 'Dumbbells' }, { label: 'Bands' }], -1, { grow: false })}`, { gap: 8 }), 'O03', 'O01');

const O03 = step(3, 'How much time do you really have?', 'Be honest. This becomes your weekly goal.',
  col(`${m('Days a week')}${chipRow(['2', '3', '4'], 1)}`, { gap: 8 })
  + col(`${m('Minutes a session')}${chipRow(['10', '15', '20', '30'], 1)}`, { gap: 8 })
  // Not "Three sessions a week is your goal": O03 offers 2, 3 and 4 and the
  // note stated one of them to every woman. The rule, with the number left to
  // the chips she just tapped. `schedule_view.dart:121` ships this sentence.
  + sageNote('Reach your goal and the week counts, and a week you miss is covered by a rest week once you have earned one.'), 'O04', 'O02');

const O04 = step(4, 'Anything we should train around?', 'Only you and your coach ever see this.',
  // THE THREE ROWS CARRY NO SUBTITLE, AND THAT IS THE DESIGN, NOT AN OMISSION.
  //
  // They read "Pelvic floor first, cleared from week six" and "Safe movements,
  // nothing on the belly", which were clinical claims this app is in no
  // position to make. They were rewritten to describe the training instead, and
  // the training they describe does not happen: `starting_program.dart` never
  // reads `intake.lifeStage` and the catalogue holds one programme, so all four
  // answers lead to the same eight-week beginner plan.
  //
  // `life_stage_view.dart` holds the three sentences behind
  // `lifeStageShapesTraining()`, which measures the selector rather than
  // trusting a comment, and shows the note below while it is false. When a
  // postpartum programme is authored they come back by themselves. Anything
  // written back into this mockup in the meantime is a promise again.
  opt('Nothing right now', '', true) + opt('After a birth', '') + opt('Pregnant', '') + opt('A knee, back or shoulder', '')
  + sageNote('We save your answer with the rest of your setup. Nothing in your sessions changes from it yet.'), 'O05', 'O03');

const O05 = phone(
  statusBar()
  + body(
    col(`${m('Built from your four answers')}${h('Three days a week, 15 minutes, at home', 'headline')}`, { gap: 6 })
    + card(
      row(`${col(`${strong('Beginner foundations', 'titleL')}${m('8 weeks · quiet · no equipment')}`, { gap: 3, grow: true })}${icon('workspace_premium', { size: 28, color: C.primaryDim })}`)
      + media({ label: 'coach demo still', h: 130 })
      + t('Week 1 starts with four moves on the floor. Nothing jumps, nothing needs a neighbour to be out.', { k: 'bodyM', color: C.onSurfaceVariant }), { gap: 12 })
    + card(row(`${icon('calendar_month', { size: 24, color: C.tertiary })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">Your week: Monday, Tuesday and Thursday. Change any day by tapping it.</div>`, { gap: 10, justify: 'flex-start' }), { v: 'sage', pad: '12px 14px' })
  , { pad: '4px 16px 0', gap: 14 })
  + footer(btn('Start day 1 now', { h: 56, ic: 'play_arrow', go: 'R03' }) + row(`${btn('I will start tomorrow', { v: 'text', h: 44, size: 15, go: 'T06' })}${btn('Pick a different program', { v: 'text', h: 44, size: 15, go: 'R11' })}`, { gap: 8 })));

export const screens = [
  { id: 'O01', html: O01, metric: '1 tap', note: 'Four questions, each one tap, each skippable, and the app stays usable if she skips all of them. The goal changes the program, never the interface.' },
  { id: 'O02', html: O02, metric: '2 taps', note: 'Equipment is asked as chips rather than a list, because the honest answer for most women here is "nothing", and that answer must be the easy one.' },
  { id: 'O03', html: O03, metric: 'sets the weekly goal', note: 'This is the screen that defines the whole rewards system: her answer becomes the weekly goal that counts weeks, and the rest-week rule is explained here, once, before she can ever fail it.' },
  { id: 'O04', html: O04, metric: 'optional, private', note: 'Life stage is asked plainly and kept private. Postpartum and pregnancy change the program, and the copy is careful to promise adaptation, not medical advice.' },
  { id: 'O05', html: O05, metric: '1 tap into day 1', note: 'The answers come back as a named program with her days already set, so the four questions visibly paid for something. One primary button, and the alternative is a real choice rather than a dead end.' },
];
