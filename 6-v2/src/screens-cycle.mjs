import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, banner, sageNote, listItem, appBar, media, avatar, spacer, field, toggle, logBtn } = K;

const tabs = (active) => row(`${chip('Today', { sel: active === 0, grow: true, go: active === 0 ? '' : 'Y03' })}${chip('Calendar', { sel: active === 1, grow: true, go: active === 1 ? '' : 'Y08' })}${chip('Patterns', { sel: active === 2, grow: true, go: active === 2 ? '' : 'Y10' })}`, { gap: 8 });
const optCard = (title, sub, sel, goId) => card(row(`${col(`${strong(title, 'titleM')}${sub ? m(sub) : ''}`, { gap: 3, grow: true })}${sel ? icon('check_circle', { size: 26, color: C.primary, fill: true }) : `<div style="width:26px;height:26px;border-radius:999px;border:2px solid ${C.outlineVariant};box-sizing:border-box"></div>`}`, { gap: 12 }), { v: sel ? 'selected' : 'outlined', pad: '14px 16px', go: goId });
const toggleRow = (title, sub, on) => card(row(`${col(`${strong(title, 'titleM')}${sub ? m(sub) : ''}`, { gap: 2, grow: true })}${toggle(on)}`, { gap: 12 }), { pad: '12px 14px' });
const why = (goId = 'Y05') => row(`${icon('info', { size: 18, color: C.primaryDim })}<div style="font-size:14px;font-weight:600;color:${C.primaryDim}">Why this suggestion?</div>`, { gap: 6, justify: 'flex-start' }).replace('<div style="display:flex', `<div data-go="${goId}" style="cursor:pointer;display:flex`);

// day cell for the month grid: logged = solid, estimated = outlined, always with a text label
const day = (n, kind = '') => {
  const base = 'height:46px;border-radius:12px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;font-size:14px;';
  if (kind === 'logged') return `<div style="${base}background:${C.onPrimaryContainer};color:#FFFFFF;font-weight:600">${n}<div style="font-size:12px;opacity:.9">day 1</div></div>`;
  if (kind === 'est') return `<div style="${base}border:1.5px dashed ${C.onPrimaryContainer};color:${C.onPrimaryContainer};font-weight:600">${n}<div style="font-size:12px">est.</div></div>`;
  if (kind === 'today') return `<div style="${base}border:2px solid ${C.primary};color:${C.onSurface};font-weight:600">${n}<div style="font-size:12px;color:${C.primaryDim}">today</div></div>`;
  if (kind === 'check') return `<div style="${base}background:${C.surfaceContainer};color:${C.onSurface}">${n}<div style="width:5px;height:5px;border-radius:999px;background:${C.tertiary}"></div></div>`;
  return `<div style="${base}color:${C.onSurfaceVariant}">${n}</div>`;
};

const Y01 = phone(
  statusBar()
  + appBar({ title: 'My cycle', lead: 'close', leadGo: 'T01' })
  + body(
    h('Make it work for you', 'display')
    + m('You choose what to log. You can change or delete it any time.')
    + optCard('Track periods and symptoms', 'Dates, bleeding and how you feel', true)
    + optCard('Track symptoms only', 'No dates, no estimates · just how you feel')
    + col(`${m('Anything we should know? Optional.')}${chipRow([{ label: 'Irregular periods' }, { label: 'Hormonal contraception' }], -1, { grow: false })}${chipRow([{ label: 'Perimenopause' }, { label: 'Pregnant or postpartum' }], -1, { grow: false })}${chipRow([{ label: 'Prefer not to say' }, { label: 'None of these', sel: true }], -1, { grow: false })}`, { gap: 8 })
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Continue', { h: 56, go: 'Y02' }) + btn('Skip setup', { v: 'text', h: 44, size: 15, go: 'T01' })));

const Y02 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'Y01' })
  + body(
    h('Your dates, if you have them', 'headline')
    + field({ label: 'Last period start', value: '15 September 2026', trail: icon('calendar_month', { size: 22, color: C.primaryDim }) })
    + row(`${chip("I don't know", { grow: true })}${chip('Still bleeding', { sel: true, grow: true })}`, { gap: 8 })
    + field({ label: 'Usual cycle length', value: 'Not sure', helper: 'Count from the first day of one period to the first day of the next.' })
    + toggleRow('Show workout suggestions', '', true)
    + toggleRow('Show meal suggestions', '', true)
    + toggleRow('Show the cycle card on Home', '', true)
    + listItem({ lead: icon('restaurant', { size: 22, color: C.primaryDim }), title: 'Allergies and dietary preferences', sub: 'Already saved, edit in your profile', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'A02' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save preferences', { h: 56, go: 'Y03' })));

const Y03 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'T01', actions: [{ icon: 'settings', go: 'Y12' }] })
  + body(
    tabs(0)
    + card(row(`${strong('Period day 2', 'titleL')}${pill('Logged by you', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`), { gap: 6, pad: '10px 12px' })
    + btn('How are you feeling?', { h: 48, ic: 'mood', go: 'Y04' })
    + card(
      row(`${strong('A gentler option today', 'titleM')}${pill('App suggestion', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
      + m('You logged low energy and mild cramps.')
      + row(`${btn('View option', { v: 'tonal', h: 44, size: 15, grow: true, go: 'Y06' })}${btn('Keep mine', { v: 'outlined', h: 44, size: 15, go: 'G06' })}`, { gap: 8 }), { gap: 8 })
    + listItem({ lead: icon('restaurant', { size: 22, color: C.primaryDim }), title: 'Lentil soup and toast', sub: '20 min · vegetarian', trail: logBtn(false, 'View', { go: 'Y07' }), v: 'filled' })
  , { pad: '4px 16px 0', gap: 8 })
  + navBar('Home'));

const Y04 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'T01', actions: [{ icon: 'settings', go: 'Y12' }] })
  + body(tabs(0) + card(row(`${strong('Period day 2', 'titleL')}${pill('Logged by you', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`), { gap: 8 }), { pad: '4px 16px 0' })
  + navBar('Home')
  + sheet(
    h('How are you feeling?', 'titleL')
    + m('All of this is optional. Nothing is carried over from yesterday.')
    + col(`${m('Energy')}${chipRow(['Low', 'Okay', 'High'], 0)}`, { gap: 8 })
    + col(`${m('Cramps')}${chipRow([{ label: 'None' }, { label: 'Mild', sel: true }, { label: 'Moderate' }, { label: 'Severe', go: 'Y11' }], -1)}`, { gap: 8 })
    + col(`${m('Appetite')}${chipRow(['Less hungry', 'Usual', 'More hungry'], 1)}`, { gap: 8 })
    + btn('More to log: sleep, bloating, bleeding', { v: 'text', h: 40, size: 15 })
    + btn('Save check-in', { h: 56, go: 'Y03' })
    + btn('Skip', { v: 'text', h: 40, size: 15, go: 'Y03' }), { gap: 12 }),
  { layered: true });

const Y05 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'Y03' })
  + body(tabs(0) + card(strong('A gentler option today', 'titleM') + m('You logged low energy and mild cramps.'), { gap: 8 }), { pad: '4px 16px 0' })
  + navBar('Home')
  + sheet(
    h('Why this suggestion?', 'titleL')
    + card(col(`${m('What you logged')}${t('Low energy, mild cramps. Today only.', { k: 'bodyM' })}`, { gap: 4 }), { v: 'filled', pad: '12px 14px' })
    + t('Gentle movement may help some people with period pain. You can keep your plan, take the easier option, or rest. All three are fine.', { k: 'bodyM' })
    + row(`${icon('arrow_forward', { size: 18, color: C.primaryDim })}<div style="font-size:14px;font-weight:600;color:${C.primaryDim}">NHS: period pain</div>`, { gap: 6, justify: 'flex-start' })
    + sageNote('Cycle dates are estimates. This feature is for general wellbeing, not diagnosis or contraception.')
    + btn('Close', { v: 'outlined', h: 48, size: 15, go: 'Y03' }), { gap: 12 }),
  { layered: true });

const Y06 = phone(
  statusBar()
  + body(
    row(`${h('Train', 'titleL')}${iconBtn('search', { go: 'R11' })}`)
    + card(
      row(`${strong('Choose what feels right today', 'titleM')}${iconBtn('close', { d: 36 })}`)
      + m('You logged low energy and mild cramps.')
      + listItem({ lead: icon('fitness_center', { size: 22, color: C.onSurfaceVariant }), title: 'Planned: full-body strength', sub: '35 min · your program', v: 'filled' })
      + listItem({ lead: icon('self_improvement', { size: 22, color: C.tertiary }), title: 'Option: gentle mobility', sub: '15 min · floor only · coach-approved', v: 'selected' })
      + row(`${btn('Use this option', { h: 48, size: 15, go: 'R03' })}${btn('Keep my workout', { v: 'outlined', h: 48, size: 15, go: 'R03' })}`, { gap: 8 })
      + row(`${btn('Rest today', { v: 'text', h: 40, size: 15, go: 'T01' })}${why()}`, { gap: 8 }), { gap: 10 })
    + m('Stop if movement makes your symptoms worse.')
    + listItem({ lead: icon('play_arrow', { size: 22, color: C.primaryDim }), title: 'Postpartum rebuild · week 3', sub: 'Your program continues tomorrow', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'R02' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Train'));

const Y07 = phone(
  statusBar('1:12')
  + body(
    row(`${h('Meals for today', 'titleL')}${pill('3 options', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + row(`${chip('Quick', { sel: true })}${chip('Vegetarian')}${chip('High protein')}`, { gap: 8, justify: 'flex-start' })
    + card(col(`${strong('Lentil soup, tomato and toast', 'titleM')}${m('20 min · vegetarian · lentils provide iron, peppers provide vitamin C')}`, { gap: 3 }) + m('A simple option for a low-energy day.') + row(`${btn("Add to today's plan", { h: 44, size: 15, go: 'E04' })}${btn('Swap', { v: 'outlined', h: 44, size: 15 })}`, { gap: 8 }), { gap: 8 })
    + card(col(`${strong('Yogurt, oats and fruit', 'titleM')}${m('5 min · dairy-free swap available')}`, { gap: 3 }) + m('You logged more hunger. Add a snack if you want one.') + row(`${btn("Add to today's plan", { v: 'tonal', h: 44, size: 15, go: 'E04' })}${btn('View recipe', { v: 'outlined', h: 44, size: 15, go: 'E06' })}`, { gap: 8 }), { gap: 8 })
    + sageNote('Adding updates your plan. It does not log the meal as eaten.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Eat'));

const Y08 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'T01', actions: [{ icon: 'settings', go: 'Y12' }] })
  + body(
    tabs(1)
    + row(`${iconBtn('arrow_back', { d: 40 })}${strong('September 2026', 'titleM')}${iconBtn('chevron_right', { d: 40 })}`)
    + `<div style="display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:4px">`
    + ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(d => `<div style="text-align:center;font-size:12px;color:${C.onSurfaceVariant}">${d}</div>`).join('')
    + [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14].map(n => day(n)).join('')
    + day(15, 'logged') + day(16, 'today') + [17, 18, 19, 20].map(n => day(n, 'check')).join('') + day(21)
    + [22, 23, 24, 25, 26, 27, 28].map(n => day(n)).join('')
    + `</div>`
    + row(`${row(`<div style="width:14px;height:14px;border-radius:5px;background:${C.onPrimaryContainer}"></div><div style="font-size:13px;color:${C.onSurface}">Logged by you</div>`, { gap: 6, justify: 'flex-start' })}${row(`<div style="width:14px;height:14px;border-radius:5px;border:1.5px dashed ${C.onPrimaryContainer}"></div><div style="font-size:13px;color:${C.onSurface}">Estimated</div>`, { gap: 6, justify: 'flex-start' })}`, { gap: 12, justify: 'flex-start' })
    + card(m('Next period estimate: 12 to 14 October, based on your recorded cycles. Timing can change.'), { v: 'filled', pad: '10px 12px' })
    + row(`${btn('Log a period', { h: 48, size: 15, go: 'Y09' })}${btn('About cycle phases', { v: 'outlined', h: 48, size: 15, go: 'Y13' })}`, { gap: 8 })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Home'));

const Y09 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'Y08' })
  + body(tabs(1) + m('September 2026'), { pad: '4px 16px 0' })
  + navBar('Home')
  + sheet(
    h('Log a period', 'titleL')
    + field({ label: 'Start date', value: '15 September 2026', trail: icon('calendar_month', { size: 22, color: C.primaryDim }) })
    + field({ label: 'End date', value: 'Still bleeding', trail: icon('calendar_month', { size: 22, color: C.onSurfaceVariant }) })
    + m('Future dates are not accepted, and an end date cannot come before a start date.')
    + btn('Save', { h: 56, go: 'Y08' })
    + row(`${btn('Delete this period', { v: 'text', h: 44, size: 15 })}${btn('Cancel', { v: 'text', h: 44, size: 15, go: 'Y08' })}`, { gap: 8 }), { gap: 12 }),
  { layered: true });

const Y10 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'T01', actions: [{ icon: 'settings', go: 'Y12' }] })
  + body(
    tabs(2)
    + h('Your patterns', 'titleL')
    + card(
      m('Energy on the first three days of your last two periods')
      + `<div style="display:flex;gap:10px;align-items:flex-end;height:110px">`
      + [['Low', 30], ['Low', 30], ['Okay', 66], ['Low', 30], ['Low', 30], ['Okay', 66]].map(([lab, hgt]) => `<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;justify-content:flex-end"><div style="width:100%;height:${hgt}px;border-radius:8px;background:${lab === 'Low' ? C.primaryContainer : C.tertiaryContainer}"></div><div style="font-size:12px;color:${C.onSurfaceVariant}">${lab}</div></div>`).join('')
      + `</div>`
      + t('You logged low energy on 4 of 6 logged days in the first 3 days of your last 2 periods.', { k: 'bodyM' })
      + m('This describes your logs. It does not explain the cause or predict every cycle.'), { gap: 10 })
    + card(row(`${col(`${strong('Offer an easier workout when I log low energy', 'titleM')}${m('Changes what we suggest, never your plan')}`, { gap: 3, grow: true })}${toggle(true)}`, { gap: 12 }), { pad: '12px 14px' })
    + m('6 logged days · 2 cycles')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Home'));

const Y11 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'T01', actions: [{ icon: 'settings', go: 'Y12' }] })
  + body(
    tabs(0)
    + card(row(`${strong('Period day 2', 'titleL')}${pill('Severe cramps logged', { bg: C.errorContainer, color: C.error })}`), { gap: 8 })
    + card(
      row(`${icon('support_agent', { size: 26, color: C.error })}${strong('This needs more than a workout change', 'titleM')}`, { gap: 10, justify: 'flex-start', align: 'flex-start' })
      + t('Severe or unusual pain deserves medical advice. If the pain is worse than usual and pain relief has not helped, seek urgent care.', { k: 'bodyM' })
      + btn('Find care near you', { h: 48, size: 15 })
      + btn('Read NHS guidance on period pain', { v: 'outlined', h: 44, size: 15 }), { v: 'error', gap: 10 })
    + m('We are not suggesting a workout today. Your plan is still there when you want it.')
    + listItem({ lead: icon('self_improvement', { size: 22, color: C.onSurfaceVariant }), title: 'Rest today', sub: 'Marked as planned rest, it costs you nothing', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'T01' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Home'));

const Y12 = phone(
  statusBar()
  + appBar({ title: 'Cycle settings', leadGo: 'Y03' })
  + body(
    card(row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Show the cycle card on Home</div>${toggle(true)}`) + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Workout suggestions</div>${toggle(true)}`) + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Meal suggestions</div>${toggle(true)}`), { gap: 10, pad: '12px 14px' })
    + card(
      col(`${strong('Share with my coach', 'titleM')}${m('Off by default. Coaching never requires it.')}`, { gap: 2 })
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Energy and appetite</div>${toggle(true)}`)
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Cycle symptoms</div>${toggle(false)}`)
      + row(`<div style="flex:1;font-size:15px;color:${C.onSurface}">Period dates and patterns</div>${toggle(false)}`)
      + m('Sara would see: energy low, appetite usual, and “client selected a lighter session”.'), { v: 'sage', gap: 8, pad: '12px 14px' })
    + listItem({ lead: icon('edit', { size: 22, color: C.primaryDim }), title: 'Change how you use My cycle', sub: 'Dates and symptoms, or symptoms only', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'Y01', pad: '8px 12px' })
    + listItem({ lead: icon('visibility_off', { size: 22, color: C.primaryDim }), title: 'Symptom-only mode', sub: 'No dates, no estimates', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'Y14', pad: '8px 12px' })
    + btn('Delete cycle data', { v: 'text', h: 36, size: 15 })
  , { pad: '0 16px 0', gap: 8 })
  + navBar('Home'));

const Y13 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'Y08' })
  + body(tabs(1) + m('September 2026'), { pad: '4px 16px 0' })
  + navBar('Home')
  + sheet(
    h('About cycle phases', 'titleL')
    + col([['Menstruation', 'Bleeding. It happens during the follicular phase.'], ['Follicular phase', 'From the first day of bleeding until an egg is released.'], ['Ovulation', 'An egg is released. A calendar cannot confirm it.'], ['Luteal phase', 'After ovulation, until the next period starts.']]
      .map(([ttl, txt]) => card(col(`${strong(ttl, 'titleM')}${m(txt)}`, { gap: 3 }), { v: 'filled', pad: '12px 14px' })).join(''), { gap: 8 })
    + sageNote('No day ranges, no “you are here”, and no hormone chart, because none of that can be measured from dates.')
    + btn('Close', { v: 'outlined', h: 48, size: 15, go: 'Y08' }), { gap: 12 }),
  { layered: true });

const Y14 = phone(
  statusBar()
  + appBar({ title: 'My cycle', leadGo: 'T01', actions: [{ icon: 'settings', go: 'Y12' }] })
  + body(
    tabs(0)
    + card(row(`${col(`${strong('Your check-in guides today', 'titleL')}${m('Symptom-only mode. No dates, no estimates.')}`, { gap: 3, grow: true })}`), { gap: 8 })
    + btn('How are you feeling?', { h: 56, ic: 'mood', go: 'Y04' })
    + card(
      strong('Your planned workout', 'titleM')
      + listItem({ lead: icon('fitness_center', { size: 22, color: C.primaryDim }), title: 'Full-body strength, 35 min', sub: 'From your coach · unchanged', v: 'filled' })
      + m('Nothing changes until you tell us how you feel.'), { gap: 10 })
    + listItem({ lead: icon('calendar_month', { size: 22, color: C.primaryDim }), title: 'Add period dates', sub: 'Only if you want estimates later', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'Y02' })
    + sageNote('Irregular cycles, hormonal contraception and perimenopause all use this mode: your logs, no forecast.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Home'));

export const screens = [
  { id: 'Y01', html: Y01, metric: 'optional, and skippable', note: 'Setup asks two things and offers a symptom-only mode, because not every woman menstruates, tracks dates, or wants to. Context chips change what the feature will and will not infer — irregular cycles, contraception and perimenopause all switch off forecasting rather than guessing.' },
  { id: 'Y02', html: Y02, metric: 'no silent 28 days', note: 'Dates are optional and "I don\'t know" is a first-class answer. Nothing pre-fills a 28-day cycle, because an invented average becomes a prediction she never gave us the data for. Dietary preferences are linked, never asked twice.' },
  { id: 'Y03', html: Y03, metric: 'check-in 1 tap · nothing forced', note: 'The hub states the fact (period day 2, logged by you) and then hands over to how she feels. A period alone never forces a lighter workout: the suggestion appeared because she logged low energy and cramps, and the reason is written on the card.' },
  { id: 'Y04', html: Y04, metric: '3 taps, all optional', note: 'Energy, cramps and appetite fit on one sheet; sleep, bloating and bleeding sit behind "more to log". Nothing is carried over from yesterday, because a symptom diary that assumes continuity stops being a diary.' },
  { id: 'Y05', html: Y05, metric: 'her input, then the source', note: 'Every health claim shows what she logged, what the option is, and one source. The wording keeps all three choices equal — keep the plan, take the easier option, or rest — so the app never praises training through pain.' },
  { id: 'Y06', html: Y06, metric: '1 tap · undo · no rescheduling', note: 'The suggestion lives above the normal Train list and can be dismissed. Taking the option changes today only, never the week, and the coach-approved label separates what her coach pre-approved from what the app suggested.' },
  { id: 'Y07', html: Y07, metric: '3 options, never a list', note: 'Three choices, allergies respected before ranking, and the reason written on each card. Adding updates her plan and does not log the meal as eaten — the existing food-logging flow stays the only way something counts as eaten.' },
  { id: 'Y08', html: Y08, metric: 'logged and estimated look different', note: 'Solid means she logged it, dashed means it is an estimate, and both carry a text label so colour is never the only signal. The estimate is a range with the reason under it, and no day is ever labelled confirmed ovulation.' },
  { id: 'Y09', html: Y09, metric: 'edit and delete work', note: 'Periods can be added, edited and deleted. Future bleeding dates and end-before-start are rejected rather than silently accepted, and editing a date clears estimates built on the old one.' },
  { id: 'Y10', html: Y10, metric: 'her logs, not a score', note: 'One chart of her own reported energy around period starts, with the counts stated in words. No readiness score, no hormone curve, and missing days are shown as missing rather than as low energy.' },
  { id: 'Y11', html: Y11, metric: 'the workout suggestion is suppressed', note: 'Severe pain replaces the training card with medical advice, not a gentler workout. Heavy or worsening symptoms get a clinician link, never a meal-based answer.' },
  { id: 'Y12', html: Y12, metric: 'private by default', note: 'Sharing with a coach is three independent switches, all off until she turns them on, with a preview of exactly what he would see — and here the coach is a she, because every coach on the platform is a woman. Turning a switch off removes the panel from the coach view.' },
  { id: 'Y13', html: Y13, metric: 'education without day ranges', note: 'The phases are explained in plain words, including the fact that menstruation happens during the follicular phase. No fixed day ranges, no "you are here", and no four-part hormone chart implying measurement.' },
  { id: 'Y14', html: Y14, metric: 'no phase, no forecast', note: 'Symptom-only mode is the same hub without invented structure: no cycle ring, no phase name, no estimate. This is also what irregular cycles, hormonal contraception and perimenopause get, because dates cannot carry meaning there.' },
];
