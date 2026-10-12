import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, sageNote, listItem, appBar, media, avatar, spacer, field, toggle, kv } = K;

// One thing a screen. The count is in the title and a line under it fills as
// she goes: eleven short steps read shorter than one long form.
const STEPS = 11;
const step = (n, title, sub, inner, next, back, primary = 'Continue') => phone(
  statusBar()
  + appBar({ leadGo: back, title: `${n} of ${STEPS}`, actions: [{ icon: 'close' }] })
  + body(linear(Math.round((n / STEPS) * 100), { h: 6, c: C.primary }) + h(title, 'headline') + (sub ? m(sub) : '') + `<div style="height:2px"></div>` + inner, { pad: '0 16px 0', gap: 12 })
  + footer(btn(primary, { h: 56, go: next }) + btn('Save and close', { v: 'text', h: 44, size: 15, go: 'K07' })));

const K01 = step(1, 'Add a photo of you', 'Women choose a person they can see. Take it now, or add it later from your page.',
  `<div style="align-self:center">${avatar(120, { ic: 'photo_camera' })}</div>`
  + btn('Take a photo', { v: 'tonal', h: 48, size: 15, ic: 'photo_camera' })
  + row(`${strong('Blur faces in my photos', 'titleS')}${pill('On')}`)
  + m('Faces blurred before it uploads.'), 'K08', 'C13');

const K08 = step(2, 'Tell clients who you are', 'This is the top of your public profile.',
  field({ label: 'Name', value: '' })
  + field({ label: 'City', value: '' })
  + field({ label: 'One line about you', value: '' }), 'K03', 'K01');

const K03 = step(3, 'What do you coach?', 'Pick up to three. Clients filter by these.',
  chipRow([{ label: 'Postpartum', sel: true }, { label: 'Beginners', sel: true }], -1, { grow: false })
  + chipRow([{ label: 'Strength', sel: true }, { label: 'Weight loss' }, { label: 'Pregnancy' }], -1, { grow: false }), 'K10', 'K08');

const K10 = step(4, 'How you coach', 'Clients look for a coach by language and by where they train.',
  col(`${m('Languages')}${chipRow([{ label: 'العربية', sel: true }, { label: 'English' }], -1, { grow: false })}`, { gap: 8 })
  + col(`${m('Where your clients train')}${chipRow([{ label: 'At home', sel: true }, { label: 'Ladies-only gym' }], -1, { grow: false })}`, { gap: 8 }), 'K04', 'K03');

const K04 = step(5, 'How many clients can you take?', 'Your prices live on your page, where you write them in your own words.',
  field({ label: 'Clients at once', value: '' })
  + card(row(`${icon('payments', { size: 22, color: C.primaryDim })}${col(`${strong('You keep 80%', 'titleM')}${m('Of every price you set on your page.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'tonal' })
  + sageNote('You will write your offers when you design your page: what each one is called, what is in it and what it costs.'), 'K11', 'K10');

// The card is drawn by the app, the same for every coach. The client adds her
// own photos and agrees in her own app; nothing here is an example result.
const K11 = step(6, "Your clients' results", "Each result is a before and an after, laid out the same way on every coach's page. Your client adds her own photos and agrees in her own app, so it is always hers to share.",
  card(row(`${col(`${m('Before')}${media({ label: '', h: 150, v: 'photo', ic: '' })}`, { gap: 6, grow: true })}${col(`${m('After')}${media({ label: '', h: 150, v: 'photo', ic: '' })}`, { gap: 6, grow: true })}`, { gap: 10 }), { v: 'outlined' })
  + m('Faces stay hidden unless she chooses to show hers.')
  + sageNote('When your check is done, ask any client from her page on your desk.'), 'K12', 'K04');

const K12 = step(7, 'What your clients say', 'Only women you coach here can write one, so every word is real.',
  card(col(`${pill('Coached here')}<div style="height:10px;border-radius:6px;background:${C.outlineVariant}"></div><div style="height:10px;width:70%;border-radius:6px;background:${C.outlineVariant}"></div>`, { gap: 8 }), { v: 'outlined' })
  + m('Her words show with her first name only, and she can take them back.')
  + sageNote('When your check is done, ask any client from her page on your desk.'), 'K02', 'K11');

const K02 = step(8, 'Show us your certificates', 'A woman on our team checks them, usually the same day.',
  card(row(`${icon('add', { size: 24, color: C.primaryDim })}<div style="flex:1;font-size:16px;font-weight:600;color:${C.primaryDim}">Add a certificate</div>`, { gap: 12, justify: 'flex-start' }), { v: 'filled' })
  + sageNote('Photos of the certificate are enough. We check the issuing body ourselves, and unverified coaches cannot take clients.'), 'K13', 'K12');

const K13 = step(9, 'How we treat each other', 'As a coach you agree to the same three rules as every woman here.',
  col(`${strong('1 · What is said here stays here', 'titleS')}${m('No screenshots, no sharing anyone else outside.')}`, { gap: 2 })
  + col(`${strong("2 · No comments on anyone else's body", 'titleS')}${m('Not even a compliment. Talk about the work instead.')}`, { gap: 2 })
  + col(`${strong('3 · No selling, no recruiting', 'titleS')}${m('Coaches have profiles for that.')}`, { gap: 2 })
  + row(`${icon('check_box', { size: 24, color: C.primary })}<div style="flex:1">I agree to these three rules</div>`, { gap: 10, justify: 'flex-start' }), 'K05', 'K02');

const K05 = step(10, 'Where should we send your money?', 'Paid out on the 1st of each month.',
  listItem({ lead: icon('account_balance_wallet', { size: 24, color: C.primaryDim }), title: 'Mobile wallet', sub: 'Vodafone Cash' })
  + listItem({ lead: icon('payments', { size: 24, color: C.primaryDim }), title: 'Bank account', sub: 'Any Egyptian bank' })
  + sageNote('We never show your wallet number or your address to clients.'), 'K06', 'K13');

const K06 = phone(
  statusBar()
  + appBar({ title: '11 of 11', lead: '' })
  + body(
    spacer()
    + `<div style="align-self:center;width:88px;height:88px;border-radius:999px;background:${C.amberContainer};display:flex;align-items:center;justify-content:center">${icon('hourglass_top', { size: 46, color: C.amber })}</div>`
    + `<div style="text-align:center;font-size:26px;line-height:34px;font-weight:600;color:${C.onPrimaryContainer}">We're checking your certificates</div>`
    + `<div style="text-align:center;font-size:16px;line-height:24px;color:${C.onSurfaceVariant};padding:0 8px">Usually the same day. We will text you the moment your profile is live.</div>`
    + card(col(`${strong('You can start now', 'titleM')}${m('Build your first plan and a meal template so your first client gets it on day one.')}`, { gap: 4 }), { v: 'sage' })
    + spacer(), { gap: 14 })
  + footer(btn('Build my first plan', { h: 56, go: 'K20' }) + btn('See my Today', { v: 'text', h: 44, size: 15, go: 'K24' })));

const K07 = phone(
  statusBar()
  + body(
    row(`${col(`${m('Tuesday 16 September')}${h('Today', 'titleL')}`, { gap: 1, grow: true })}${iconBtn('notifications')}`)
    + card(row(`${col(`${strong('3 check-ins waiting', 'titleM')}${m('Oldest: 19 hours · you promise 24')}`, { gap: 3, grow: true })}${btn('Start', { h: 44, size: 15, go: 'W09' })}`, { gap: 12 }), { v: 'amber' })
    + listItem({ lead: avatar(44, { initial: 'N' }), title: 'Nour Adel', sub: 'Review due · day 9 of 30 · waiting 19 hours', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'W09' })
    + listItem({ lead: avatar(44, { initial: 'S' }), title: 'Sara Adel', sub: 'Check-in · 1 of 3 sessions · second quiet week', trail: icon('warning', { size: 22, color: C.amber }), go: 'W09' })
    + listItem({ lead: avatar(44, { initial: 'R' }), title: 'Rana Tarek', sub: 'New enquiry · postpartum, home, 20 min', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'K09' })
    + listItem({ lead: icon('image', { size: 24, color: C.primaryDim }), title: 'My portfolio', sub: '1,204 views · 9 enquiries this month', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'B01' })
    + row(`${strong('Earnings this month', 'titleM')}${strong('21,600 EGP', 'titleM')}`)
    + linear(72, { h: 10, c: C.primary })
    + m('12 clients · payout on 1 October')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Today', 'coach'));

const K09 = phone(
  statusBar()
  + appBar({ title: 'New enquiry', leadGo: 'K07' })
  + body(
    row(`${avatar(56, { initial: 'R' })}${col(`${strong('Rana Tarek', 'titleL')}${m('Verified woman · joined 3 days ago')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' })
    + card(col(`${strong('What she is asking for', 'titleM')}${m('Postpartum, 4 months · trains at home · 20 minutes · 3 days a week')}`, { gap: 4 }), { v: 'filled' })
    + card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">"I want to feel strong enough to carry my son without my back hurting."</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'filled', pad: '12px 14px' })
    + sageNote('Accepting takes one spot of your 20. She pays only when you accept.')
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Accept and send a welcome', { h: 56, go: 'W10' }) + btn('Not a fit for me', { v: 'text', h: 44, size: 15, go: 'K07' })));

const K16 = phone(
  statusBar()
  + appBar({ title: 'Sara Adel', leadGo: 'W10', actions: [{ icon: 'person', go: 'W02' }] })
  + body(
    card(row(`${icon('warning', { size: 22, color: C.amber })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">Second quiet week. Her rest week is already used.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '12px 14px' })
    + `<div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:10px;justify-content:flex-end">`
    + `<div style="display:flex;justify-content:flex-start"><div style="max-width:78%;background:${C.surfaceLowest};border:1px solid ${C.outlineVariant};border-radius:18px 18px 18px 6px;padding:10px 14px;font-size:15px;line-height:22px;color:${C.onSurface}">I could not train this week, work was impossible.</div></div>`
    + `<div style="display:flex;justify-content:flex-end"><div style="max-width:78%;background:${C.primaryContainer};border-radius:18px 18px 6px 18px;padding:10px 14px;font-size:15px;line-height:22px;color:${C.onSurface}">Then this week is two sessions, ten minutes each. I moved them to Sunday and Wednesday.</div></div>`
    + `</div>`
  , { pad: '0 16px 0', gap: 10 })
  + footer(card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Hold to talk</div>${icon('send', { size: 22, color: C.primaryDim })}`, { gap: 10, justify: 'flex-start' }), { pad: '12px 14px', r: R.full })));

const K17 = phone(
  statusBar()
  + body(
    row(`${h('Earnings', 'titleL')}${iconBtn('receipt_long')}`)
    + card(col(`${m('September so far')}${h('21,600 EGP', 'display')}${m('Your 80% of 27,000 EGP · 12 clients')}`, { gap: 4 }) + linear(72, { h: 10, c: C.primary }) + m('Payout on 1 October to Vodafone Cash · 010 xxx xx32'), { v: 'tonal', gap: 10 })
    + strong('This month', 'titleM')
    + listItem({ title: '10 monthly packages', sub: '18,000 EGP · your share 14,400', trail: '' })
    + listItem({ title: '2 plan-only packages', sub: '1,800 EGP · your share 1,440', trail: '' })
    + listItem({ title: '1 renewal from August', sub: '7,200 EGP · your share 5,760', trail: '' })
    + listItem({ lead: icon('account_balance_wallet', { size: 24, color: C.primaryDim }), title: 'Payout method', sub: 'Vodafone Cash · change any time', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'K18' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Earnings', 'coach'));

const K18 = phone(
  statusBar()
  + appBar({ title: 'Your public profile', leadGo: 'K17', actions: [{ icon: 'visibility', go: 'H02' }] })
  + body(
    card(row(`${icon('visibility', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">This is exactly what a client sees. Tap the eye to open it as she would.</div>`, { gap: 10, justify: 'flex-start', align: 'flex-start' }), { v: 'tonal', pad: '12px 14px' })
    + row(`${avatar(64, { initial: 'N' })}${col(`${strong('Nourhan El-Sayed', 'titleM')}${m('Postpartum strength · Giza')}`, { gap: 3, grow: true })}${iconBtn('edit')}`, { gap: 12, justify: 'flex-start' })
    + listItem({ lead: icon('edit', { size: 22, color: C.primaryDim }), title: 'Design your page', sub: 'Sections, colours and words · all yours', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'B01', v: 'tonal' })
    + listItem({ title: 'Certificates', sub: 'NASM CPT · pre and postnatal · verified', trail: icon('verified', { size: 22, color: C.tertiary, fill: true }) })
    + listItem({ title: 'Packages', sub: '1,800 EGP monthly · 900 EGP plan only', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'B06' })
    + listItem({ title: 'Spots', sub: '12 of 20 taken', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }) })
    + listItem({ title: 'Reply time shown to clients', sub: 'About 2 hours · measured, not typed', trail: '' })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Earnings', 'coach'));

export const screens = [
  { id: 'K01', html: K01, metric: 'a person, not a logo', note: 'The coach side is denser than the client side on purpose: she is at a desk with time, not standing on a microbus. Her photo is asked for first because clients choose a face.' },
  { id: 'K08', html: K08, metric: 'name and city', note: 'Her name, her city and one line, on a screen of their own. Her photo was the step before.' },
  { id: 'K10', html: K10, metric: 'two small choices', note: 'Languages and where her clients train, apart from what she coaches, so no screen asks three things at once.' },
  { id: 'K11', html: K11, metric: 'drawn by the app', note: 'A result is a before and an after, laid out by the app the same way on every page, so no coach designs one. The client adds her own photos and agrees in her own app; the coach can only ask.' },
  { id: 'K12', html: K12, metric: 'real words only', note: 'Only women she coaches here can write about her, so a review cannot be invented. First name only, and the client can take it back.' },
  { id: 'K13', html: K13, metric: 'the same three rules', note: 'The community rules on their own screen, agreed with one tick, the same words and version as the pledge every member agrees to.' },
  { id: 'K02', html: K02, metric: 'checked, same day', note: 'Certificates are photographed, not typed, and the platform does the verifying. Saying plainly that unverified coaches cannot take clients is what makes the badge worth something to the woman paying.' },
  { id: 'K03', html: K03, metric: '3 specialties, no more', note: 'Capping specialties at three keeps the client-side filters meaningful; a coach who claims everything ranks for nothing.' },
  { id: 'K04', html: K04, metric: 'her price, her maths', note: 'The 80% share is shown as a number in EGP next to her price, so the deal is concrete. Capacity is asked here so "12 spots left" on her profile is true rather than marketing.' },
  { id: 'K05', html: K05, metric: 'wallet or bank', note: 'Payout by mobile wallet first, because that is how most Egyptian coaches actually get paid, and a promise that her number is never shown to clients.' },
  { id: 'K06', html: K06, metric: 'not a dead end', note: 'Waiting for verification comes with work she can do: build a plan template so her first client gets something on day one.' },
  { id: 'K07', html: K07, metric: 'queue first, earnings second', note: 'The coach opens on what people are waiting for, ordered by how long they have waited, against the reply time she promised. Money is present but below the work.' },
  { id: 'K09', html: K09, metric: 'accept or decline, clearly', note: 'An enquiry carries the client\'s situation and her own words. Declining is offered as a neutral choice, because forced matches make both sides miserable.' },
  { id: 'K16', html: K16, metric: 'context above the thread', note: 'The banner tells her what the app already knows — second quiet week, rest week used — so her reply can be about the person rather than the data.' },
  { id: 'K17', html: K17, metric: '80% stated everywhere', note: 'Earnings show the gross, her share, and the payout date and destination. Nothing about the cut is hidden or rounded.' },
  { id: 'K18', html: K18, metric: 'edit what clients see', note: 'The profile editor previews the real client view, and the reply-time claim is measured by the platform rather than typed by the coach.' },
];
