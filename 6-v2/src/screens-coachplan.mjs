import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, banner, sageNote, listItem, appBar, media, avatar, spacer, field, toggle, kv, logBtn } = K;

const clientRow = (name, sub, tag, tone, goId = 'W02') => listItem({
  lead: avatar(44, { initial: name[0] }), title: name, sub,
  trail: pill(tag, { bg: tone === 'amber' ? C.amberContainer : tone === 'sage' ? C.tertiaryContainer : C.surfaceContainer, color: tone === 'amber' ? C.amber : tone === 'sage' ? C.tertiary : C.onSurfaceVariant }), go: goId,
});
const daySlot = (label, value, state = '') => `<div style="border-radius:${R.md}px;padding:10px 12px;display:flex;align-items:center;gap:10px;background:${state === 'gap' ? C.errorContainer : C.surfaceLowest};border:1px solid ${state === 'gap' ? C.error : C.outlineVariant}">`
  + `<div style="width:76px;font-size:13px;font-weight:600;color:${C.onSurfaceVariant}">${label}</div>`
  + `<div style="flex:1;font-size:15px;color:${state === 'gap' ? C.error : C.onSurface}">${value}</div>`
  + icon(state === 'gap' ? 'add' : 'edit', { size: 18, color: state === 'gap' ? C.error : C.onSurfaceVariant }) + `</div>`;

const W01 = phone(
  statusBar()
  + body(
    row(`${h('Clients', 'titleL')}${pill('12 of 20', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + row(`${chip('Needs reply', { sel: true })}${chip('Reviews due')}${chip('Plan needed')}${chip('Assessment due')}`, { gap: 8, justify: 'flex-start', wrap: true })
    + clientRow('Nour Adel', '8 Sep to 7 Oct · review due today · day 9', 'Reply', 'amber')
    + clientRow('Mai Farouk', '1 Sep to 30 Sep · on track · day 16', 'On track', 'sage')
    + clientRow('Sara Adel', '12 Sep to 11 Oct · 1 session in 2 weeks', 'Quiet', '')
    + card(row(`${icon('checklist', { size: 24, color: C.amber })}${col(`${strong('3 things waiting', 'titleM')}${m('Oldest 19 hours · you promise one working day')}`, { gap: 3, grow: true })}${btn('Start', { h: 40, size: 14, go: 'W09' })}`, { gap: 12 }), { v: 'amber' })
    + row(`${btn('Build a plan', { v: 'tonal', h: 48, size: 15, go: 'W03' })}${btn('My splits', { v: 'outlined', h: 48, size: 15, ic: 'repeat', go: 'K19' })}`, { gap: 8 })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Clients', 'coach'));

const W02 = phone(
  statusBar()
  + appBar({ title: 'Nour Adel', leadGo: 'W01', actions: [{ icon: 'chat', go: 'K16' }] })
  + body(
    listItem({ lead: icon('checklist', { size: 22, color: C.primaryDim }), title: 'Assessment', sub: 'Done 2 September · re-assess in 2 weeks', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'K21', v: 'tonal', pad: '10px 12px' })
    + card(col(`${kv('Goal', 'Get stronger after birth')}${kv('Trains', 'Sun, Tue, Thu · 20 min')}${kv('Where', 'At home · 3 kg dumbbells')}${kv('Avoid', 'High impact, deep knee bends', { last: true })}`, { gap: 0 }), { pad: '6px 16px' })
    + card(row(`${icon('warning', { size: 19, color: C.amber })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">No nuts. Vegetarian on weekdays. Both from her assessment.</div>`, { gap: 8, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '9px 11px' })
    + card(row(`${ringStat(84, '84%', 'done', { size: 72, thickness: 9 })}${col(`${strong('8 weeks with you', 'titleM')}${m('21 of 25 planned sessions')}${m('Bests: squat 12 kg · plank 45 s')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' }), { gap: 8 })
    + card(
      row(`${strong('Shared by Nour', 'titleM')}${pill('Her choice', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Energy and appetite</div>${pill('Shared', { bg: C.tertiaryContainer, color: C.tertiary })}`), { gap: 8 })
    + row(`${btn('Plan', { h: 46, size: 14, go: 'W03' })}${btn('Meals', { v: 'tonal', h: 46, size: 14, go: 'W06' })}${btn('Review', { v: 'outlined', h: 46, size: 14, go: 'W09' })}`, { gap: 6 })
  , { pad: '0 16px 0', gap: 9 })
  + navBar('Clients', 'coach'));

const W03 = phone(
  statusBar()
  + appBar({ title: 'Nour · workouts', leadGo: 'W02', actions: [{ icon: 'visibility', go: 'G04' }] })
  + body(
    row(`${pill('Draft', { bg: C.amberContainer, color: C.amber })}${m('8 Sep to 7 Oct · 30 days')}`)
    + row(`${chip('Week 1', { grow: true })}${chip('Week 2', { sel: true, grow: true })}${chip('Week 3', { grow: true })}${chip('Week 4', { grow: true })}`, { gap: 6 })
    + col(`${daySlot('Sun 13', 'Full-body strength · 35 min')}${daySlot('Mon 14', 'Rest day')}${daySlot('Tue 16', 'Full-body strength · 35 min')}${daySlot('Wed 17', 'Nothing assigned', 'gap')}${daySlot('Thu 18', 'Upper body · 20 min')}`, { gap: 8 })
    + row(`${btn('Apply a split', { v: 'tonal', h: 44, size: 14, ic: 'repeat', go: 'K19' })}${btn('Add workout', { v: 'outlined', h: 44, size: 14, ic: 'add', go: 'W04' })}`, { gap: 8 })
    + row(`${btn('Copy this week', { v: 'text', h: 40, size: 14, go: 'W05' })}${btn('Save as a split', { v: 'text', h: 40, size: 14, go: 'K20' })}${btn('Draft it for me', { v: 'text', h: 40, size: 14, go: 'K26' })}`, { gap: 8 })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Preview and publish', { h: 54, go: 'W08' })));

const W04 = phone(
  statusBar()
  + appBar({ title: 'Tue 16 · session', leadGo: 'W03' })
  + body(
    field({ label: 'Session name', value: 'Full-body strength' })
    + col(`${daySlot('1', 'Glute bridge · 3 × 12')}${daySlot('2', 'Goblet squat · 3 × 12 · 12 kg')}${daySlot('3', 'Step-back lunge · 3 × 10')}`, { gap: 8 })
    + card(col(`${strong('Rest between sets', 'titleM')}${chipRow(['30 s', '45 s', '60 s'], 1)}`, { gap: 8 }), { pad: '12px 14px' })
    + field({ label: 'Note for her', value: 'Keep 12 kg and aim for 12 reps.' })
    + card(row(`${col(`${strong('Add an easier option', 'titleM')}${m('Box squat to a chair · approved substitution')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 12 }), { v: 'sage', pad: '12px 14px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save to Tuesday', { h: 54, go: 'W03' }) + btn('Add another exercise', { v: 'text', h: 44, size: 15, go: 'W04' })));

const W05 = phone(
  statusBar()
  + appBar({ title: 'Nour · workouts', leadGo: 'W03' })
  + body(row(`${pill('Draft', { bg: C.amberContainer, color: C.amber })}${m('Week 2')}`), { pad: '0 16px 0' })
  + navBar('Clients', 'coach')
  + sheet(
    h('Copy week 2', 'titleL')
    + m('Choose where it goes. You can tailor individual sessions afterwards.')
    + row(`${chip('Week 3', { sel: true, grow: true })}${chip('Week 4', { sel: true, grow: true })}${chip('Last 2 days', { grow: true })}`, { gap: 8 })
    + card(col(`${strong('What will change', 'titleM')}${kv('Days written', '10')}${kv('Existing assignments replaced', '2 · Sun 20, Tue 22', { last: true })}`, { gap: 0 }), { v: 'amber', pad: '6px 14px' })
    + btn('Copy and replace those 2 days', { h: 54, go: 'W03' })
    + btn('Cancel', { v: 'text', h: 44, size: 15, go: 'W03' }), { gap: 12 }),
  { layered: true });

const W06 = phone(
  statusBar()
  + appBar({ title: 'Nour · meals', leadGo: 'W02', actions: [{ icon: 'visibility', go: 'G10' }] })
  + body(
    card(row(`${icon('warning', { size: 22, color: C.error })}<div style="flex:1;font-size:15px;line-height:21px;color:${C.onSurface}">No nuts. Vegetarian on weekdays.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'error', pad: '10px 12px' })
    + row(`${chip('Day 8', { grow: true })}${chip('Day 9', { sel: true, grow: true })}${chip('Day 10', { grow: true })}${chip('Day 11', { grow: true })}`, { gap: 6 })
    + col(`${daySlot('Breakfast', 'Ful with oil and cumin')}${daySlot('Lunch', 'Koshari bowl, medium')}${daySlot('Dinner', 'Lentil soup and eggs')}${daySlot('Snack', 'Nothing assigned', 'gap')}`, { gap: 8 })
    + row(`${btn('Select app meal', { v: 'tonal', h: 44, size: 14, grow: true, go: 'W06' })}${btn('Create meal', { v: 'outlined', h: 44, size: 14, ic: 'add', go: 'W07' })}${btn('Draft a week', { v: 'text', h: 44, size: 14, go: 'K27' })}`, { gap: 8 })
    + m('4 of 30 days still need a meal or an explicit free choice.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Preview and publish', { h: 54, go: 'W08' })));

const W07 = phone(
  statusBar()
  + appBar({ title: 'Create a meal', lead: 'close', leadGo: 'W06' })
  + body(
    field({ label: 'Name', value: 'Yogurt, dates and cinnamon' })
    + field({ label: 'Ingredients and amounts', value: '200 g yogurt · 3 dates · 5 g cinnamon' })
    + row(`${field({ label: 'Servings', value: '1' })}${field({ label: 'Prep time', value: '3 min' })}`, { gap: 8 })
    + col(`${m('Labels')}${chipRow([{ label: 'Vegetarian', sel: true }, { label: 'Nut-free', sel: true }, { label: 'Quick' }], -1, { grow: false })}`, { gap: 6 })
    + field({ label: 'Note for her', value: 'Good before an evening session.' })
    + card(m('Nutrition details unavailable. This meal uses ingredients without verified values, so no totals are shown.'), { v: 'filled', pad: '10px 12px' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save to my meals and assign', { h: 54, go: 'W06' }) + m('Saved to your own collection. It is not added to the app’s public library.')));

const W08 = phone(
  statusBar()
  + appBar({ title: 'Publish to Nour', leadGo: 'W03' })
  + body(
    card(col(`${strong('What Nour will get', 'titleM')}${kv('Dates', '8 Sep to 7 Oct · 30 days')}${kv('Workouts', '18 sessions · 8 rest days')}${kv('Meals', '116 of 120 slots assigned')}${kv('Approved options', '6 easier sessions', { last: true })}`, { gap: 0 }), { gap: 8 })
    + card(row(`${icon('checklist', { size: 22, color: C.amber })}<div style="flex:1;font-size:15px;line-height:21px;color:${C.onSurface}">No assessment on file. Publish anyway, or complete it first.</div>${btn('Open', { v: 'tonal', h: 36, size: 13, go: 'K21' })}`, { gap: 10, justify: 'flex-start' }), { v: 'amber', pad: '10px 12px' })
    + card(row(`${icon('warning', { size: 22, color: C.amber })}<div style="flex:1;font-size:15px;line-height:21px;color:${C.onSurface}">4 meal slots are still empty. Publish them as a free choice, or go back and fill them.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '10px 12px' })
    + row(`${btn('Preview her day', { v: 'outlined', h: 44, size: 14, go: 'G04' })}${btn('Fill the gaps', { v: 'text', h: 44, size: 14, go: 'W06' })}`, { gap: 8 })
    + sageNote('Revisions default to future dates. A session she has already started, and anything she has already logged, stay on the version she used.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Publish plan', { h: 56, ic: 'send', go: 'W01' })));

const W09 = phone(
  statusBar()
  + appBar({ title: 'Nour · review', leadGo: 'W01', actions: [{ icon: 'person', go: 'W02' }] })
  + body(
    card(col(`${strong('Her week', 'titleM')}${kv('Workouts', '3 of 3 · one swapped for an easier option')}${kv('Food logged', '5 days · 2 days not logged')}${kv('Manageable?', 'About right')}${kv('Shared wellbeing', 'Energy: low on 2 days', { last: true })}`, { gap: 0 }), { gap: 8 })
    + card(m('“Morning sessions before the kids wake up worked. Thursday is too long.”'), { v: 'filled', pad: '12px 14px' })
    + m('Two days without a food log are shown as not logged, not as meals skipped.')
    + card(row(`${iconBtn('mic', { d: 40, bg: C.primaryContainer, color: C.onPrimaryContainer })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Hold to reply by voice</div>${iconBtn('send', { d: 40, color: C.primaryDim })}`, { gap: 10, justify: 'flex-start' }), { pad: '10px 12px', r: R.full })
    + row(`${btn('Adjust workouts', { v: 'tonal', h: 44, size: 14, grow: true, go: 'W03' })}${btn('Adjust meals', { v: 'outlined', h: 44, size: 14, go: 'W06' })}`, { gap: 8 })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save feedback and publish changes', { h: 54, ic: 'send', go: 'W01' })));

const W10 = phone(
  statusBar()
  + body(
    row(`${h('Inbox', 'titleL')}${iconBtn('filter_list')}`)
    + row(`${chip('Unread', { sel: true })}${chip('Awaiting reply')}${chip('All')}`, { gap: 8, justify: 'flex-start' })
    + listItem({ lead: avatar(46, { initial: 'N' }), title: 'Nour Adel', sub: 'Waiting 19 hours · “Can we make Thursday shorter?”', trail: K.badge(2), go: 'K16', v: 'selected' })
    + listItem({ lead: avatar(46, { initial: 'S' }), title: 'Sara Adel', sub: 'Waiting 6 hours · voice note 0:42', trail: K.badge(1), go: 'K16' })
    + listItem({ lead: avatar(46, { initial: 'M' }), title: 'Mai Farouk', sub: 'You: keep 12 kg on Thursday', go: 'K16' })
    + card(col(`${strong('Saved replies', 'titleM')}${m('Open as an editable draft. Nothing is sent automatically as personal feedback.')}`, { gap: 3 }) + row(`${chip('First week check')}${chip('Missed sessions')}`, { gap: 8, justify: 'flex-start' }), { v: 'filled', gap: 8 })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Chats', 'coach'));

export const screens = [
  { id: 'W01', html: W01, metric: 'queue, not a dashboard', note: 'The coach opens on who is waiting and for how long, measured against the reply time she promised her clients. Filters are states she acts on — needs reply, review due, plan needed — instead of charts she reads.' },
  { id: 'W02', html: W02, metric: 'her constraints, always visible', note: 'Everything needed to write a safe plan sits on one screen: goal, days, equipment, what to avoid, allergies. The shared-cycle panel shows only what the client chose, and says plainly that "not shared" is not "no symptoms".' },
  { id: 'W03', html: W03, metric: 'draft until published', note: 'A week at a time, with gaps shown in red rather than left silent. Editing an assignment never touches the library workout, and copying a week is a deliberate action with its own confirmation.' },
  { id: 'W04', html: W04, metric: 'assign, then tailor', note: 'A session starts from the library and becomes this client\'s: her order, her sets, her rest, her note. The easier option is attached here, which is what lets her swap mid-session without waiting for a reply.' },
  { id: 'W05', html: W05, metric: 'overwrites are named', note: 'Bulk copying states exactly how many days it writes and which existing assignments it would replace, before it happens. Coaches lose trust the first time a copy silently erases work.' },
  { id: 'W06', html: W06, metric: 'allergies on screen while editing', note: 'The client\'s restrictions stay visible above the meal slots, and an incompatible ingredient blocks assignment rather than warning afterwards. Empty slots are counted so nothing publishes half-planned by accident.' },
  { id: 'W07', html: W07, metric: 'no invented numbers', note: 'A coach-created meal captures what a client needs to cook it. Where verified nutrition data does not exist, the screen says so instead of calculating a plausible-looking total, and the meal stays in the coach\'s own collection.' },
  { id: 'W08', html: W08, metric: 'preview before it is real', note: 'Publishing shows the whole month, the gaps, and what the client will actually see. Revisions default to future dates, and a session already running or already logged is never rewritten underneath her.' },
  { id: 'W09', html: W09, metric: 'reviewed means answered', note: 'The check-in sits beside her actual results, with unlogged days labelled as unlogged rather than counted as failures. Marking it reviewed requires saving feedback, so the client always gets a reply.' },
  { id: 'W10', html: W10, metric: 'sorted by waiting time', note: 'The inbox is the same conversation the client sees, ordered by who has waited longest. Saved replies open as drafts she must edit — a template sent verbatim as personal feedback is worse than no reply.' },
];
