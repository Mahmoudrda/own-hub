import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, navBar, sheet, banner, sageNote, listItem, homeBar, appBar, media, avatar, spacer, field, rtl, ringStat } = K;

const promise = (ic, title, text) => row(`${icon(ic, { size: 26, color: C.primaryDim })}${col(`${strong(title, 'titleM')}${m(text)}`, { gap: 2, grow: true })}`, { gap: 14, justify: 'flex-start', align: 'flex-start' });
const bullet = (ic, text) => row(`${icon(ic, { size: 22, color: C.tertiary })}<div style="flex:1;font-size:15px;line-height:22px;color:${C.onSurface}">${text}</div>`, { gap: 12, justify: 'flex-start', align: 'flex-start' });
const digitBox = (d, focus = false) => `<div style="flex:1;height:68px;border-radius:${R.md}px;background:${C.surfaceContainer};border:${focus ? `2px solid ${C.primary}` : '1.5px solid transparent'};display:flex;align-items:center;justify-content:center;font-size:30px;font-weight:600;color:${C.onSurface}">${d}</div>`;

const C01 = phone(
  statusBar()
  + body(
    spacer()
    + `<div style="align-self:center;width:88px;height:88px;border-radius:28px;background:${C.primary};display:flex;align-items:center;justify-content:center">${icon('self_improvement', { size: 48, color: '#FFFFFF', fill: true })}</div>`
    + `<div style="text-align:center;font-family:${F.mono};font-size:12px;color:${C.onSurfaceVariant}">logotype</div>`
    + `<div style="text-align:center;font-size:30px;line-height:38px;font-weight:600;color:${C.onPrimaryContainer};padding:0 8px">A room full of women training like you</div>`
    + `<div style="text-align:center;font-size:16px;line-height:24px;color:${C.onSurfaceVariant};padding:0 16px">Quiet workouts for home, food you already cook, and a community only women can enter.</div>`
    + spacer(), { gap: 14 })
  + footer(btn('Get started', { h: 56, go: 'C02' }) + btn('I already have an account', { v: 'text', h: 48, size: 15, go: 'C06' })));

const C02 = phone(
  statusBar()
  + appBar({ title: '', lead: '' })
  + body(
    col(`${h('اختاري لغتك', 'headline')}${h('Choose your language', 'titleL')}`, { gap: 4 })
    + m('You can change this any time in settings.')
    + `<div style="height:8px"></div>`
    + listItem({ title: 'العربية', sub: 'الفصحى · كل شيء في التطبيق', trail: icon('check_circle', { size: 26, color: C.primary, fill: true }), v: 'selected', pad: '16px', go: 'C03' })
    + listItem({ title: 'English', sub: 'Everything in the app', pad: '16px', go: 'C03' })
  , { pad: '0 16px 0' })
  + footer(btn('Continue', { h: 56, go: 'C03' })));

const C03 = phone(
  statusBar()
  + appBar({ leadGo: 'C02' })
  + body(
    h("What's inside", 'display')
    + `<div style="height:4px"></div>`
    + promise('volume_off', 'Quiet workouts for home', 'No jumping, no equipment, ten minutes counts. Your neighbours will never know.')
    + promise('restaurant', 'Food you already cook', 'Koshari, ful and molokhia in the portions you actually serve. No grams, no calorie shaming.')
    + promise('verified_user', 'Women only, every member checked', 'Every account is verified with ID before she can see a single post.')
    + promise('sports', 'Coaches who get it', 'Verified women coaches, paid monthly in Egyptian pounds.')
  , { pad: '0 16px 0', gap: 18 })
  + footer(btn('Create my account', { h: 56, go: 'C06' }) + btn('Look around first', { v: 'text', h: 48, size: 15, go: 'C04' })));

const C04 = phone(
  statusBar()
  + body(
    row(`${h('Look around', 'titleL')}${btn('Join', { h: 40, size: 15, go: 'C06' })}`)
    + K.segmented(['Workouts', 'Recipes', 'Coaches'], 0)
    + listItem({ lead: media({ label: '', h: 56, r: R.sm }).replace('height:56px', 'height:56px;width:72px'), title: 'Quiet full body', sub: '15 min · beginner · no equipment', trail: icon('play_arrow', { size: 22, color: C.primaryDim }), go: 'C05' })
    + listItem({ lead: media({ label: '', h: 56, r: R.sm }).replace('height:56px', 'height:56px;width:72px'), title: 'Floor legs, no jumping', sub: '10 min · beginner', trail: icon('play_arrow', { size: 22, color: C.primaryDim }), go: 'C05' })
    + card(
      row(`${icon('shield', { size: 24, color: C.primaryDim })}${col(`${strong('Members and their posts are behind the check', 'titleM')}${m('We keep the community for verified women. Join and you will see all of it.')}`, { gap: 4, grow: true })}`, { gap: 12, justify: 'flex-start', align: 'flex-start' })
      + btn('Join · about two minutes', { h: 48, size: 15, go: 'C06' }), { v: 'tonal', gap: 12 })
  , { pad: '4px 16px 0', gap: 12 })
  + navBar('Train'));

const C05 = phone(
  statusBar()
  + body(row(`${h('Look around', 'titleL')}${btn('Join', { h: 40, size: 15, go: 'C06' })}`) + K.segmented(['Workouts', 'Recipes', 'Coaches'], 0), { pad: '4px 16px 0' })
  + navBar('Train')
  + sheet(
    h('Save this workout?', 'titleL')
    + t('We just need your number and a quick check that you are a woman. It takes about two minutes, once.', { k: 'bodyM', color: C.onSurfaceVariant })
    + btn('Join', { h: 56, go: 'C06' })
    + btn('Not now', { v: 'text', h: 44, size: 15, go: 'C04' }), { gap: 12 }));

const C06 = phone(
  statusBar()
  + appBar({ leadGo: 'C03', title: 'Step 1 of 2' })
  + body(
    h("What's your number?", 'display')
    + m('We text you a six-digit code. We never show your number to anyone.')
    + `<div style="height:4px"></div>`
    + row(`<div style="width:86px;height:60px;border-radius:${R.md}px;background:${C.surfaceContainer};display:flex;align-items:center;justify-content:center;font-size:17px;font-weight:600;color:${C.onSurface}">+20</div><div style="flex:1">${field({ value: '100 555 0132', focus: true })}</div>`, { gap: 10 })
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Send me a code', { h: 56, go: 'C07' }) + m('By joining you agree to the community rules.')));

const C07 = phone(
  statusBar()
  + appBar({ leadGo: 'C06', title: 'Step 2 of 2' })
  + body(
    h('Type the code', 'display')
    + m('We sent six digits to +20 100 555 0132.')
    + `<div style="height:4px"></div>`
    + `<div style="display:flex;gap:10px">${digitBox('4')}${digitBox('1')}${digitBox('7')}${digitBox('2')}${digitBox('9')}${digitBox('', true)}</div>`
    + sageNote('It checks itself the moment the sixth digit lands. On Android we read the message for you.')
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Continue', { h: 56, go: 'C08' }) + btn('Send it again', { v: 'text', h: 44, size: 15, go: 'C07' })));

const C08 = phone(
  statusBar()
  + appBar({ leadGo: 'C07' })
  + body(
    h('Which one are you?', 'display')
    + m('You can change this later by messaging us.')
    + `<div style="height:4px"></div>`
    + card(row(`${icon('self_improvement', { size: 30, color: C.primaryDim })}${col(`${strong("I'm here to train", 'titleL')}${m('Workouts, recipes and the community. Free.')}`, { gap: 3, grow: true })}${icon('check_circle', { size: 26, color: C.primary, fill: true })}`, { gap: 12, justify: 'flex-start' }), { v: 'selected', pad: '18px', go: 'C09' })
    + card(row(`${icon('sports', { size: 30, color: C.primaryDim })}${col(`${strong('I coach women', 'titleL')}${m('Take clients, set your packages, keep 80%.')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' }), { pad: '18px', go: 'C09' })
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Continue', { h: 56, go: 'C09' })));

const C09 = phone(
  statusBar()
  + appBar({ leadGo: 'C08' })
  + body(
    h('One check, then you are in', 'display')
    + t('This is the whole reason the community feels safe: every member is verified before she can see or say anything.', { k: 'bodyM', color: C.onSurfaceVariant })
    + card(
      bullet('id_card', 'We read your national ID card. The card itself says you are a woman. We never guess from your face.')
      + bullet('face', 'A selfie is matched to the photo on the card, only to prove the card is yours.')
      + bullet('delete', 'Both images are deleted after the check. We keep the result, nothing else.')
      + bullet('schedule', 'It takes about 90 seconds.'), { v: 'sage', gap: 12 })
    + m('Checked by a licensed Egyptian provider. Tap to read exactly what is stored.')
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Scan my ID', { h: 56, ic: 'id_card', go: 'C10' }) + btn('I wear niqab, check me another way', { v: 'text', h: 48, size: 15, go: 'C15' })));

const C10 = phone(
  statusBar('', { color: '#FFFFFF' })
  + appBar({ lead: 'close', leadGo: 'C09', title: '<span style="color:#FFFFFF">Your ID card</span>' })
  + `<div style="flex:1;min-height:0;background:${C.inverseSurface};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;padding:16px">`
  + `<div style="width:300px;height:190px;border-radius:18px;border:3px solid ${C.primaryContainer};display:flex;align-items:center;justify-content:center;position:relative"><div style="font-family:${F.mono};font-size:12px;color:rgba(255,255,255,.6)">front of the card</div></div>`
  + `<div style="text-align:center;font-size:17px;font-weight:600;color:#FFFFFF">Hold it flat, all four corners inside</div>`
  + `<div style="text-align:center;font-size:15px;line-height:22px;color:rgba(255,255,255,.75);max-width:300px">It photographs itself when it is sharp. Nothing is uploaded until you tap send.</div>`
  + `</div>`
  + footer(btn('Take it myself', { v: 'white', h: 52, size: 15, go: 'C11' }), { pad: '12px 16px 14px' })
  + homeBar({ color: '#FFFFFF' }), { bg: C.inverseSurface });

const C11 = phone(
  statusBar('', { color: '#FFFFFF' })
  + appBar({ lead: 'close', leadGo: 'C09', title: '<span style="color:#FFFFFF">Quick selfie</span>' })
  + `<div style="flex:1;min-height:0;background:${C.inverseSurface};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;padding:16px">`
  + `<div style="width:230px;height:300px;border-radius:999px;border:3px solid ${C.primaryContainer};display:flex;align-items:center;justify-content:center"><div style="font-family:${F.mono};font-size:12px;color:rgba(255,255,255,.6)">her face, live</div></div>`
  + `<div style="text-align:center;font-size:17px;font-weight:600;color:#FFFFFF">Look straight ahead. No smile needed.</div>`
  + `<div style="text-align:center;font-size:15px;line-height:22px;color:rgba(255,255,255,.75);max-width:300px">Matched to the photo on your card, then deleted. A woman reviews anything the check cannot decide.</div>`
  + `</div>`
  + footer(btn('Done', { v: 'white', h: 52, size: 15, go: 'C12' }), { pad: '12px 16px 14px' })
  + homeBar({ color: '#FFFFFF' }), { bg: C.inverseSurface });

const C12 = phone(
  statusBar()
  + appBar({ lead: '' })
  + body(
    spacer()
    + `<div style="align-self:center">${ringStat(72, '', '', { size: 132, thickness: 12, c: C.primary })}</div>`
    + `<div style="text-align:center;font-size:24px;font-weight:600;color:${C.onPrimaryContainer}">Checking your card</div>`
    + col(
      row(`${icon('check_circle', { size: 22, color: C.tertiary, fill: true })}<div style="flex:1;font-size:15px;color:${C.onSurface}">Card read</div>`, { gap: 10, justify: 'flex-start' })
      + row(`${icon('check_circle', { size: 22, color: C.tertiary, fill: true })}<div style="flex:1;font-size:15px;color:${C.onSurface}">Selfie matched to the card</div>`, { gap: 10, justify: 'flex-start' })
      + row(`${icon('autorenew', { size: 22, color: C.onSurfaceVariant })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Final check</div>`, { gap: 10, justify: 'flex-start' }), { gap: 10 })
    + spacer()
    + m('Usually seconds. If it needs a person, a woman reviewer takes it from here.')
  , { pad: '0 16px 0', gap: 14 })
  + footer(btn('Continue', { h: 56, go: 'C13' })));

const C13 = phone(
  statusBar()
  + body(
    spacer()
    + `<div style="align-self:center;width:96px;height:96px;border-radius:999px;background:${C.tertiaryContainer};display:flex;align-items:center;justify-content:center">${icon('verified', { size: 52, color: C.tertiary, fill: true })}</div>`
    + `<div style="text-align:center;font-size:30px;line-height:38px;font-weight:600;color:${C.onPrimaryContainer}">You're in, Mai</div>`
    + `<div style="text-align:center;font-size:16px;line-height:24px;color:${C.onSurfaceVariant};padding:0 12px">Verified in 74 seconds. Your ID photo and selfie have been deleted. We kept the result and nothing else.</div>`
    + card(bullet('groups', 'Every woman here went through the same check.') + bullet('visibility_off', 'Your number, your ID and your logs are never shown to members.'), { v: 'sage', gap: 10 })
    + spacer(), { gap: 14 })
  + footer(btn('Read the three rules', { h: 56, go: 'C16' }) + btn("I'm a coach, set up my profile", { v: 'text', h: 44, size: 15, go: 'K01' })));

const C14 = phone(
  statusBar()
  + appBar({ title: 'Being checked', lead: '' })
  + body(
    card(row(`${icon('hourglass_top', { size: 26, color: C.amber })}${col(`${strong('A woman reviewer is looking', 'titleM')}${m('Usually under two hours. We will text you.')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' }), { v: 'amber' })
    + strong('While you wait, everything here is open', 'titleM')
    + listItem({ lead: icon('fitness_center', { size: 24, color: C.primaryDim }), title: 'Workouts and videos', sub: 'All 124, including the quiet ones', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'R01' })
    + listItem({ lead: icon('restaurant', { size: 24, color: C.primaryDim }), title: 'Recipes', sub: 'With portions and cost per serving', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E05' })
    + listItem({ lead: icon('sports', { size: 24, color: C.primaryDim }), title: 'Coach profiles', sub: 'Browse, message when you are verified', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'H01' })
    + m('The community stays closed until the check is done. That is the point of it.')
  , { pad: '0 16px 0', gap: 12 })
  + navBar('Home'));

const C15 = phone(
  statusBar()
  + appBar({ leadGo: 'C09' })
  + body(
    h('Checked by a woman, no photo kept', 'headline')
    + t('If you do not show your face to a camera, nothing here asks you to. Choose either one. Your ID card is still read the same way.', { k: 'bodyM', color: C.onSurfaceVariant })
    + card(row(`${icon('videocam', { size: 26, color: C.primaryDim })}${col(`${strong('A short video check', 'titleM')}${m('Two minutes with a woman reviewer. Nothing is recorded or kept.')}`, { gap: 3, grow: true })}${icon('check_circle', { size: 24, color: C.primary, fill: true })}`, { gap: 12, justify: 'flex-start', align: 'flex-start' }), { v: 'selected', go: 'C14' })
    + card(row(`${icon('fitness_center', { size: 26, color: C.primaryDim })}${col(`${strong('In person at a ladies-only gym', 'titleM')}${m('12 partner gyms in Cairo, Giza and Alexandria.')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start', align: 'flex-start' }), { go: 'C14' })
    + sageNote('Only women review these checks. No man ever sees your face, your card or your name.')
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Book the video check', { h: 56, go: 'C14' })));

const C16 = phone(
  statusBar()
  + appBar({ leadGo: 'C13' })
  + body(
    h('How we treat each other', 'display')
    + m('Three rules. They are the whole reason this place works.')
    + card(col(`${strong('1 · What is said here stays here', 'titleM')}${m('No screenshots, no sharing anyone else outside.')}`, { gap: 4 }), { v: 'filled' })
    + card(col(`${strong('2 · No comments on anyone else\'s body', 'titleM')}${m('Not even a compliment. Talk about the work instead.')}`, { gap: 4 }), { v: 'filled' })
    + card(col(`${strong('3 · No selling, no recruiting', 'titleM')}${m('Coaches have profiles for that.')}`, { gap: 4 }), { v: 'filled' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('I agree, let me in', { h: 56, go: 'O01' }) + m('Break one and you lose your place. You can read them again any time.')));

export const screens = [
  { id: 'C01', html: C01, metric: 'nothing asked yet', note: 'Faces like hers before a single field. The promise is the room, not the workout library, because the room is what she cannot get anywhere else.' },
  { id: 'C02', html: C02, metric: 'first choice of all', note: 'Language before anything, in both scripts, set as a real choice rather than a device guess. Arabic is listed first and set two points larger with more line height, per the type rules.' },
  { id: 'C03', html: C03, metric: '4 promises, 1 screen', note: 'One screen instead of a three-panel swipe deck: nobody reads panel two. The women-only promise sits third because it is the reason she stays, and the last line answers "what does it cost".' },
  { id: 'C04', html: C04, metric: 'browse, no account', note: 'The preview is real content — workouts, recipes, coaches — but member posts are not in it. A women-only community that lets anyone read its posts is not women-only, and this is the screen where most products get that wrong.' },
  { id: 'C05', html: C05, metric: 'asked at the moment it pays', note: 'The account is asked for when she reaches for something that needs one, not on the way in. The sheet states the cost in time and the reason in one sentence.' },
  { id: 'C06', html: C06, metric: '1 field', note: 'Phone, no password. The country code is fixed and separate so the field only holds what she types.' },
  { id: 'C07', html: C07, metric: '0 extra taps on Android', note: 'The code checks itself when the sixth digit lands, and on Android it is read from the message. The resend lives at the bottom, where a stuck user looks.' },
  { id: 'C08', html: C08, metric: '1 tap, pre-selected', note: 'Client is pre-selected because most are, and coach onboarding is a different, longer path that should not be the default.' },
  { id: 'C09', html: C09, metric: '~90 seconds, stated', note: 'The riskiest screen in the product, so it states exactly what is read, what is matched, what is deleted, and how long it takes — and names the one thing people fear: we do not judge your face. Consent is explicit here, which the data-protection regulations require.' },
  { id: 'C10', html: C10, metric: 'auto-capture', note: 'The card is the gate: the national ID number carries sex and date of birth, so the decision comes from a government record instead of a guess. Auto-capture removes the blurry-photo retry loop that kills completion.' },
  { id: 'C11', html: C11, metric: 'liveness, then deleted', note: 'The selfie answers one question only — is this your card — and the copy says so. No face is classified by gender anywhere in this product; a court has already ruled that excluding someone on gender-related appearance is discrimination.' },
  { id: 'C12', html: C12, metric: 'seconds, usually', note: 'Progress is named step by step so a slow network does not read as a rejection, and the fallback to a woman reviewer is promised before it is needed.' },
  { id: 'C13', html: C13, metric: 'the payoff screen', note: 'Verification ends with what she bought: a room where everyone passed the same check. Deletion is restated at the moment she is most likely to believe it.' },
  { id: 'C14', html: C14, metric: 'never a dead end', note: 'A pending check still gives her the whole training and food side of the app. Only the community waits, and the copy makes that a feature rather than a punishment.' },
  { id: 'C15', html: C15, metric: 'no face, no photo kept', note: 'The niqab path is designed, not improvised: a live check with a woman reviewer or an in-person check at a partner gym, with the ID card doing the same work. Nothing is recorded, and only women review.' },
  { id: 'C16', html: C16, metric: '1 tap', note: 'Three rules, each one sentence, agreed once. The body-comments rule is the one that makes a women-only fitness community survive its first month.' },
];
