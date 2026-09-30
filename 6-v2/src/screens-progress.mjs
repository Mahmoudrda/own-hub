import * as K from './kit.mjs';
const { C, R, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, sageNote, listItem, appBar, media, avatar, spacer, weekBars, field } = K;

const mini = (label, value, pct) => col(`${row(`${strong(label, 'titleS')}${m(value)}`)}${linear(pct, { h: 8 })}`, { gap: 6 });
const msDone = (name, when) => row(`${icon('check_circle', { size: 24, color: C.tertiary, fill: true })}<div style="flex:1;font-size:16px;color:${C.onSurface}">${name}</div>${m(when)}`, { gap: 10, justify: 'flex-start' });
const msNext = (name, progress, pct) => col(`${row(`<div style="flex:1;font-size:16px;color:${C.onSurface}">${name}</div>${m(progress)}`)}${linear(pct, { h: 6 })}`, { gap: 6 });

const tile = (ic, label, meta, goId) => `<div style="flex:1;border-radius:${R.md}px;border:1px solid ${C.outlineVariant};background:${C.surfaceLowest};padding:12px 10px;display:flex;flex-direction:column;gap:5px;cursor:pointer" data-go="${goId}">${icon(ic, { size: 22, color: C.primaryDim })}<div style="font-size:15px;font-weight:600;color:${C.onSurface}">${label}</div><div style="font-size:13px;color:${C.onSurfaceVariant}">${meta}</div></div>`;
const tiles = `<div style="display:flex;gap:8px">${tile('military_tech', 'Milestones', '4 of 12', 'P02')}${tile('trophy', 'Bests', '8 so far', 'P03')}${tile('monitor_weight', 'Body', 'private', 'P04')}</div>`;

const P01 = phone(
  statusBar()
  + appBar({ title: 'Your progress', leadGo: 'T01' })
  + body(
    card(
      row(`${col(`${h('Regular', 'headline')}${m('14 weeks counted · best run 9')}`, { gap: 2, grow: true })}${pill('Level 7', { ic: 'workspace_premium' })}`)
      + m('Regular holds while four of your last eight weeks count. Six did.'), { gap: 8 })
    + card(
      row(`${strong('Next: Strong', 'titleM')}${m('about 6 weeks away')}`)
      + mini('Counted weeks', '14 of 20', 70)
      + mini('Personal bests', '8 of 10', 80), { v: 'amber', gap: 8 })
    + card(row(`${strong('This week')}${m('2 of 3')}`) + segs(3, 2) + weekBars([2, 2, 0, 2, 2, 2, 2, 1]) + row(`${m('Last eight weeks · the pale one was a rest week')}${m('1 saved')}`), { gap: 8, pad: '12px 16px' })
    + tiles
    + listItem({ lead: icon('checklist', { size: 22, color: C.primaryDim }), title: 'Your first week', sub: 'All five done', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'T08', pad: '10px 12px' })
    + listItem({ lead: icon('spa', { size: 22, color: C.tertiary }), title: 'What a rest week covers', sub: 'A missed week, repaired without asking', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'T04', pad: '10px 12px' })
    + listItem({ lead: icon('info', { size: 22, color: C.primaryDim }), title: 'If a tier slips', sub: 'One counted week brings it back', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'T05', pad: '10px 12px' })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

const P02 = phone(
  statusBar()
  + appBar({ title: 'Milestones', leadGo: 'P01' })
  + body(
    m('Twelve in all. None are secret, and none are for filling in a profile.')
    + card(`<div style="font-size:15px;font-weight:600;color:${C.tertiary}">Earned</div>` + msDone('First session', '3 Jun') + msDone('First counted week', '9 Jun') + msDone('First personal best', '17 Jun') + msDone('10 sessions', '1 Jul'), { gap: 12 })
    + card(`<div style="font-size:15px;font-weight:600;color:${C.onSurfaceVariant}">Next</div>` + msNext('20 counted weeks', '14 of 20', 70) + msNext('First program finished', 'day 11 of 18', 61) + msNext('50 sessions', '23 of 50', 46), { gap: 14 })
    + card(row(`${icon('favorite', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">"Came back" is earned by returning after a break. It is the one we most want you to have.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'tonal', pad: '12px 14px' })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

const P03 = phone(
  statusBar()
  + appBar({ title: 'Personal bests', leadGo: 'P01' })
  + body(
    sageNote('Measured against your own history only. More reps, more weight, a longer hold, or a harder version. A 3 kg dumbbell counts like a 30 kg barbell.')
    + listItem({ lead: icon('trophy', { size: 24, color: C.amber, fill: true }), title: 'Goblet squat', sub: '12 kg × 10 · 16 September · was 10 kg', trail: m('+2 kg') })
    + listItem({ lead: icon('trophy', { size: 24, color: C.amber, fill: true }), title: 'Glute bridge', sub: '3 × 15 · 9 September · was 3 × 12', trail: m('+3 reps') })
    + listItem({ lead: icon('trophy', { size: 24, color: C.amber, fill: true }), title: 'Plank hold', sub: '45 seconds · 2 September · was 30', trail: m('+15 s') })
    + listItem({ lead: icon('trophy', { size: 24, color: C.amber, fill: true }), title: 'Step-back lunge', sub: 'moved to the harder version · 26 August', trail: m('level up') })
    + m('Sessions you logged as "I already did it" never set a best, because the numbers were copied.')
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

const P04 = phone(
  statusBar()
  + appBar({ title: 'Body, privately', leadGo: 'P01', actions: [{ icon: 'lock' }] })
  + body(
    card(row(`${icon('visibility_off', { size: 24, color: C.primaryDim })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">Nobody sees this. Not the community, not your coach unless you send it.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'tonal', pad: '12px 14px' })
    + card(row(`${col(`${strong('Weight', 'titleM')}${m('Optional. You can use the app forever without it.')}`, { gap: 3, grow: true })}${btn('Add', { v: 'tonal', h: 40, size: 15 })}`), { gap: 8 })
    + card(col(`${strong('Measurements', 'titleM')}${m('Waist, hips, arm. Every 4 weeks is plenty.')}`, { gap: 3 }) + row(`${chip('Waist 82 cm')}${chip('Hips 96 cm')}${chip('Add')}`, { gap: 8, justify: 'flex-start' }), { gap: 10 })
    // The caption under this card said "stored on your phone and encrypted in
    // the app". There is no capture path in the build, no photo store and no
    // key — grep `lib/` for encryption and the only hits are comments, which is
    // why `body_privately_view.dart` draws no photo card at all and says so.
    // The card stays here as the design for the day one exists; the promise
    // does not ship ahead of it, and nor does its dictionary entry.
    + card(row(`${media({ label: 'June', h: 120, ic: '', v: 'photo' }).replace('flex:0 0 auto', 'flex:1')}${media({ label: 'September', h: 120, ic: '', v: 'photo' }).replace('flex:0 0 auto', 'flex:1')}`, { gap: 8 }), { gap: 10 })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

export const screens = [
  { id: 'P01', html: P01, metric: '1 tap from Today', note: 'Three numbers, each answering a different question: the tier is how steady she is lately, the level is everything she has ever done, and the week bar is what to do now. Every rule sits next to the number it explains, in one sentence, so there is no help page to write.' },
  { id: 'P02', html: P02, metric: 'finite, all visible', note: 'Twelve milestones, every one tied to training, eating or coming back. Unearned ones show plain progress instead of a locked badge, because a padlock reads as "you are not allowed".' },
  { id: 'P03', html: P03, metric: 'against herself only', note: 'Bests are self-relative by design: more reps, more weight, longer holds, harder variations. That is what makes the ladder identical for a first-timer and a fifteen-year lifter — and why recalled sessions are excluded.' },
  { id: 'P04', html: P04, metric: 'private by default', note: 'Weight is optional and says so. Photos are compared side by side and never leave the device unencrypted, because this is the data women are most often burned by.' },
];
