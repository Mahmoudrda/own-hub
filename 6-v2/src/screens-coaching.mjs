import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, sageNote, listItem, appBar, media, avatar, spacer, field, toggle, rtl, shot, followBtn, followUpStrip, sectionHead } = K;

const coachRow = (name, spec, meta, goId = 'H02') => listItem({
  lead: avatar(52, { initial: name[0] }), title: name, sub: `${spec}<br>${meta}`,
  trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: goId, pad: '12px 14px',
});
const bubble = (text, mine = false, { voice = false } = {}) => `<div style="display:flex;justify-content:${mine ? 'flex-end' : 'flex-start'}"><div style="max-width:78%;background:${mine ? C.primaryContainer : C.surfaceLowest};border:1px solid ${mine ? 'transparent' : C.outlineVariant};border-radius:${mine ? '18px 18px 6px 18px' : '18px 18px 18px 6px'};padding:10px 14px;font-size:15px;line-height:22px;color:${C.onSurface}">${voice ? `<div style="display:flex;align-items:center;gap:8px">${icon('play_arrow', { size: 20, color: C.primaryDim, fill: true })}<div style="display:flex;align-items:center;gap:2px">${[10, 16, 22, 14, 20, 12, 18, 10, 14, 8].map(hh => `<div style="width:3px;height:${hh}px;border-radius:2px;background:${C.primary}"></div>`).join('')}</div><span style="font-size:13px;color:${C.onSurfaceVariant}">0:24</span></div>` : text}</div></div>`;

const H01 = phone(
  statusBar()
  + body(
    row(`${h('Coaching', 'titleL')}${iconBtn('filter_list')}`)
    + m('Every coach here is a verified woman with checked certificates.')
    + chipRow([{ label: 'Postpartum', sel: true }, { label: 'Arabic' }, { label: 'Under 2,000 EGP' }], -1, { grow: false })
    + coachRow('Nourhan El-Sayed', 'Postpartum strength · Giza', '4.8 ★ (126) · from 1,800 EGP · replies in ~2h')
    + coachRow('Mariam Hassan', 'Beginners and home training · Cairo', '4.9 ★ (88) · from 1,500 EGP · replies in ~4h')
    + coachRow('Dina Farid', 'Ladies-gym strength · Alexandria', '4.7 ★ (54) · from 2,200 EGP · replies in ~1h')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Coaching'));

// Rendered from the page she designed in the builder: her cover, her headline,
// her method, her offers, her consented results. Two coaches never look alike here.
const H02 = phone(
  `<div style="position:relative;flex:0 0 auto">`
  + shot('', { h: 182, r: 0, tone: 'dusk' })
  + `<div style="position:absolute;left:0;right:0;top:0">${statusBar('9:41', { color: '#FFFFFF' })}`
  + `<div style="display:flex;align-items:center;justify-content:space-between;padding:0 6px">${iconBtn('arrow_back', { d: 44, color: '#FFFFFF', go: 'H01' })}<div style="display:flex">${iconBtn('favorite', { d: 44, color: '#FFFFFF' })}${iconBtn('share', { d: 44, color: '#FFFFFF' })}</div></div></div>`
  + `<div style="position:absolute;left:0;right:0;bottom:0;padding:13px 16px;background:linear-gradient(180deg,transparent,rgba(36,26,30,.74))">`
  + `<div style="font-size:23px;line-height:28px;font-weight:700;color:#FFFFFF">Back to lifting, after birth</div>`
  + `<div style="font-size:13px;color:rgba(255,255,255,.88);margin-top:3px">Giza · at home · 20 minutes</div></div></div>`
  + body(
    row(`${avatar(50, { initial: 'N' })}${col(`${row(`${strong('Nourhan El-Sayed', 'titleM')}${icon('verified', { size: 16, color: C.primaryDim, fill: true })}`, { gap: 5, justify: 'flex-start' })}${m('4.8 ★ (126) · replies in ~2h · 12 spots left')}`, { gap: 2, grow: true })}${followBtn('follow', { h: 34 })}`, { gap: 11, justify: 'flex-start' })
    + card(row(`${icon('verified_user', { size: 20, color: C.tertiary })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">NASM CPT · pre and postnatal · checked by us 12 March</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'sage', pad: '10px 12px' })
    + sectionHead('How I work')
    + row(`${[['1', 'We talk first'], ['2', 'The floor weeks'], ['3', 'Back under a weight']].map(([n, ti]) => `<div style="flex:1;border-radius:${R.md}px;border:1px solid ${C.outlineVariant};background:${C.surfaceLowest};padding:9px 10px;display:flex;flex-direction:column;gap:5px"><div style="width:24px;height:24px;border-radius:999px;background:${C.primaryContainer};display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;color:${C.onPrimaryContainer}">${n}</div><div style="font-size:13px;line-height:17px;font-weight:600;color:${C.onSurface}">${ti}</div></div>`).join('')}`, { gap: 7 })
    + sectionHead('What I offer')
    + card(row(`${col(`${strong('Monthly coaching', 'titleM')}${m('Plan, weekly review, chat')}`, { gap: 2, grow: true })}${strong('1,800 EGP', 'titleM')}`), { gap: 8, go: 'H03' })
    + sectionHead('Client results')
    + followUpStrip([{ tone: 'sand', blur: true, label: 'Week 1' }, { tone: 'rose', blur: true, label: 'Week 8' }, { tone: 'sage', blur: true, label: 'Now', now: true }], { h: 74 })
    + m('Mai agreed to show these, chose the pictures, and can withdraw them.')
  , { pad: '10px 16px 0', gap: 10 })
  + footer(btn('See her packages', { h: 54, go: 'H03' }) + btn('Message before you decide', { v: 'outlined', h: 46, size: 15, go: 'H06' }), { pad: '8px 16px 12px' }));

const H03 = phone(
  statusBar()
  + appBar({ title: 'Nourhan El-Sayed', leadGo: 'H02' })
  + body(
    card(row(`${col(`${strong('Monthly coaching', 'titleL')}${m('Cancel any time · renews monthly')}`, { gap: 3, grow: true })}${col(`${strong('1,800', 'titleL')}${m('EGP a month')}`, { gap: 0 })}`)
      + col(['A plan built for your days and equipment', 'A weekly check-in she answers by voice', 'Chat, replies in about 2 hours', 'Your meals reviewed once a week'].map(x => row(`${icon('check', { size: 20, color: C.tertiary })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">${x}</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' })).join(''), { gap: 8 }), { v: 'selected', gap: 12 })
    + card(row(`${col(`${strong('Plan only', 'titleM')}${m('A program, no check-ins')}`, { gap: 3, grow: true })}${strong('900 EGP', 'titleM')}`), { gap: 8 })
    + sageNote('You are paying a person, not a subscription: she keeps 80% of it.')
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Continue · 1,800 EGP', { h: 56, go: 'H04' })));

const H04 = phone(
  statusBar()
  + appBar({ title: 'Pay', lead: 'close', leadGo: 'H03' })
  + body(
    card(row(`${col(`${strong('Monthly coaching with Nourhan', 'titleM')}${m('Starts today · renews 16 October')}`, { gap: 3, grow: true })}${strong('1,800 EGP', 'titleM')}`), { v: 'filled', pad: '14px 16px' })
    + strong('How would you like to pay?', 'titleM')
    + listItem({ lead: icon('credit_card', { size: 24, color: C.primaryDim }), title: 'Card', sub: 'Visa, Mastercard, Meeza', trail: icon('check_circle', { size: 24, color: C.primary, fill: true }), v: 'selected' })
    + listItem({ lead: icon('account_balance_wallet', { size: 24, color: C.primaryDim }), title: 'Mobile wallet', sub: 'Vodafone Cash, Orange Money, Etisalat, InstaPay' })
    + listItem({ lead: icon('receipt_long', { size: 24, color: C.primaryDim }), title: 'Fawry', sub: 'Pay with a code at any Fawry point' })
    + m('Your coach is paid after your first check-in. If she never replies, you get your money back.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Pay 1,800 EGP', { h: 56, ic: 'lock', go: 'G01' })));

const H05 = phone(
  statusBar()
  + body(
    row(`${h('Coaching', 'titleL')}${iconBtn('chat', { go: 'H06' })}`)
    + card(row(`${avatar(48, { initial: 'N' })}${col(`${strong('Nourhan El-Sayed', 'titleM')}${m('Your coach since today · replies in ~2h')}`, { gap: 3, grow: true })}${iconBtn('chat', { d: 44, bg: C.primaryContainer, color: C.onPrimaryContainer, go: 'H06' })}`, { gap: 12 }), { v: 'tonal' })
    + card(row(`${col(`${strong('This week from Sara', 'titleM')}${m('3 sessions · protein 95 g a day')}`, { gap: 3, grow: true })}${btn('Open', { v: 'tonal', h: 40, size: 15, go: 'G04' })}`), { gap: 8 })
    + card(row(`${icon('event_available', { size: 24, color: C.amber })}${col(`${strong('Weekly review due', 'titleM')}${m('One minute · it is filled in from your logs')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' }) + btn('Do it now', { h: 48, size: 15, go: 'G12' }), { v: 'amber', gap: 10 })
    + listItem({ lead: icon('history', { size: 24, color: C.primaryDim }), title: 'Last review', sub: 'Sara replied with a voice note', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G13' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Coaching'));

const H06 = phone(
  statusBar()
  + appBar({ title: 'Nourhan El-Sayed', leadGo: 'H05', actions: [{ icon: 'more_vert' }] })
  + body(
    `<div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:10px;justify-content:flex-end">`
    + bubble('Welcome Mai! I looked at your answers, so we start on the floor this week, nothing standing.')
    + bubble('', true, { voice: true })
    + bubble('The squat felt heavy at 12 kg but I finished all three sets.', true)
    + bubble('That is exactly right. Keep 12 kg on Thursday and we add reps, not weight.')
    + `</div>`
  , { pad: '0 16px 0', gap: 10 })
  + footer(card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Message or hold to talk</div>${icon('image', { size: 22, color: C.onSurfaceVariant })}`, { gap: 10, justify: 'flex-start' }), { pad: '12px 14px', r: R.full })));

export const screens = [
  { id: 'H01', html: H01, metric: 'a list, not a swipe deck', note: 'Coaches are a decision, not a game: a list with the three things that decide it — specialty, price in EGP, and how fast she replies. A swipe deck would hide exactly those.' },
  { id: 'H02', html: H02, metric: 'credentials before claims', note: 'The verified certificates card sits above her sales copy, and "12 spots left" is a real capacity number rather than urgency theatre. Messaging before buying is offered, because most women will not pay a stranger.' },
  { id: 'H03', html: H03, metric: '2 packages, no tiers', note: 'Two packages, each stated as what she gets weekly. The line about the coach keeping 80% is there because it changes how the price reads: this is a person, not a subscription.' },
  { id: 'H04', html: H04, metric: 'the payment methods Egypt uses', note: 'Card, mobile wallet and Fawry, because a card-only checkout excludes most of the market. The refund promise is stated before payment, where it reduces the fear rather than after, where it reads as an apology.' },
  { id: 'H05', html: H05, metric: 'one thing waiting at a time', note: 'With a coach, the tab becomes a relationship: her plan, the check-in that is due, and the last reply. The check-in is the product — it is what she paid for and what keeps her.' },
  { id: 'H06', html: H06, metric: 'voice first', note: 'Voice notes are the primary gesture on both sides, which is how Egyptian women actually message and how a coach can answer ten clients in the time typing would take three.' },
];
