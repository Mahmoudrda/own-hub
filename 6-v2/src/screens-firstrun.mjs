import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, navBar, sageNote, listItem, appBar, avatar, spacer, field, toggle, sectionHead, shot } = K;

// Every other screen in this product is drawn populated. These six are the same
// screens on the first day, when there is nothing in them yet — which is the only
// state a new person actually meets. An empty state is the onboarding.
const nothingYet = (ic, title, body1, goId = '') => card(
  row(`<div style="width:44px;height:44px;border-radius:999px;background:${C.surfaceContainer};display:flex;align-items:center;justify-content:center;flex:0 0 auto">${icon(ic, { size: 22, color: C.onSurfaceVariant })}</div>`
    + col(`${strong(title, 'titleM')}${m(body1)}`, { gap: 3, grow: true }), { gap: 12, justify: 'flex-start', align: 'flex-start' }),
  { v: 'filled', pad: '13px 14px', go: goId });

const todoRow = (ic, title, sub, goId) => listItem({
  lead: `<div style="width:34px;height:34px;border-radius:10px;background:${C.primaryContainer};display:flex;align-items:center;justify-content:center;flex:0 0 auto">${icon(ic, { size: 18, color: C.onPrimaryContainer })}</div>`,
  title, sub, trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: goId, pad: '10px 12px',
});

// ---------------- client, day one ----------------
const T06 = phone(
  statusBar()
  + body(
    row(`${h('Tuesday', 'titleL')}${pill('Day 1', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + card(
      row(`${col(`${strong('Beginner foundations', 'titleL')}${m('Monday, Tuesday, Thursday · 15 min')}`, { gap: 3, grow: true })}${icon('workspace_premium', { size: 26, color: C.primaryDim })}`)
      + t('Four moves on the floor. Nothing jumps, nothing needs the neighbours out.', { k: 'bodyM', color: C.onSurfaceVariant })
      + btn('Start day 1', { h: 54, ic: 'play_arrow', go: 'R03' }), { v: 'tonal', gap: 10 })
    + listItem({ lead: icon('checklist', { size: 22, color: C.primaryDim }), title: 'Your first week', sub: '2 of 5 done · nothing expires', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'T07', v: 'tonal', pad: '10px 12px' })
    + nothingYet('history', 'Nothing logged yet', 'Today\'s session and the meal you usually eat at this hour will sit here. Log one thing and it starts filling itself in.')
    + listItem({ lead: icon('restaurant', { size: 22, color: C.primaryDim }), title: 'Tell us one thing you eat', sub: 'One meal is enough to start the guessing', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'E09', pad: '10px 12px' })
    + listItem({ lead: icon('groups', { size: 22, color: C.primaryDim }), title: '4,210 women in the beginners group', sub: 'Nobody there has been training over a year', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'M17', pad: '10px 12px' })
    + sageNote('Three sessions makes the week count, and a rest week covers one you miss.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Home'));

const E09 = phone(
  statusBar()
  + body(
    row(`${h('Eat', 'titleL')}${pill('Day 1', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + nothingYet('restaurant', 'No plates yet', 'Log something twice and it becomes a one-tap plate here, in the size you actually serve, not in grams.')
    + card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:16px;color:${C.onSurfaceVariant}">Say or type what you ate</div>${icon('keyboard', { size: 22, color: C.onSurfaceVariant })}`, { gap: 10, justify: 'flex-start' }), { pad: '14px 16px', r: R.full, go: 'E02' })
    + sectionHead('Or start from one of these')
    + listItem({ title: 'Ful and baladi', sub: 'Breakfast · 410 kcal · 22 g protein', trail: K.logBtn(true, 'Log', { go: 'E04' }), v: 'selected' })
    + listItem({ title: 'Koshari bowl, medium', sub: 'Lunch · 540 kcal · 18 g protein', trail: K.logBtn(false, 'Log', { go: 'E04' }) })
    + listItem({ title: 'Eggs and tea', sub: 'Breakfast · 290 kcal', trail: K.logBtn(false, 'Log', { go: 'E04' }) })
    + m('No countdown, no red numbers. Protein is the only target, and it is a bar that fills.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Eat'));

const M17 = phone(
  statusBar()
  + body(
    row(`${h('Community', 'titleL')}${iconBtn('search', { go: 'M10' })}`)
    + card(row(`${icon('verified', { size: 24, color: C.tertiary, fill: true })}${col(`${strong('You are verified · the room is open', 'titleM')}${m('Every woman you will see here passed the same check.')}`, { gap: 2, grow: true })}`, { gap: 11, justify: 'flex-start', align: 'flex-start' }), { v: 'sage', pad: '12px 14px' })
    + nothingYet('groups', 'Your feed is empty on purpose', 'It fills with the groups you join, never a public timeline. Join one and its posts appear here.')
    + sectionHead('Groups for someone starting out', 'See all', { go: 'M04' })
    + listItem({ lead: avatar(42, { ic: 'self_improvement' }), title: 'Beginners group', sub: '4,210 women · nobody over a year in', trail: btn('Join', { v: 'tonal', h: 38, size: 14, go: 'M04' }), pad: '10px 12px' })
    + listItem({ lead: avatar(42, { ic: 'child_care' }), title: 'Postpartum rebuild', sub: '1,860 women · cleared from week six', trail: btn('Join', { v: 'tonal', h: 38, size: 14, go: 'M04' }), pad: '10px 12px' })
    + listItem({ lead: avatar(42, { ic: 'groups' }), title: 'Cairo, west side', sub: 'Ladies-only gyms and walking groups', trail: btn('Join', { v: 'tonal', h: 38, size: 14, go: 'M04' }), pad: '10px 12px' })
    + sageNote('Faces arrive blurred, and nothing here leaves the room.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Community'));

// ---------------- coach, day one ----------------
const K24 = phone(
  statusBar()
  + body(
    row(`${col(`${m('Tuesday 16 September')}${h('Today', 'titleL')}`, { gap: 1, grow: true })}${iconBtn('notifications')}`)
    + card(row(`${icon('hourglass_top', { size: 24, color: C.amber })}${col(`${strong('We are checking your certificates', 'titleM')}${m('Usually the same day. You can build everything else now.')}`, { gap: 2, grow: true })}`, { gap: 11, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '12px 14px' })
    + nothingYet('group', 'No clients yet', 'When a woman asks to work with you she lands here, in her own words.', 'W11')
    + listItem({ lead: icon('checklist', { size: 22, color: C.primaryDim }), title: 'Your first week', sub: '2 of 4 done', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'K25', v: 'tonal', pad: '10px 12px' })
    + sectionHead('Worth doing before your first client')
    + todoRow('image', 'Finish your page', 'Clients decide from it · 3 sections so far', 'B14')
    + todoRow('repeat', 'Save a split', 'Write your week once, use it on everyone', 'K19')
    + todoRow('nutrition', 'Add a meal you always prescribe', 'It waits in your own collection', 'W07')
    + row(`${strong('Earnings this month', 'titleM')}${strong('0 EGP', 'titleM')}`)
    + m('You keep 80% of what she pays.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Today', 'coach'));

const W11 = phone(
  statusBar()
  + body(
    row(`${h('Clients', 'titleL')}${pill('0 of 20', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + nothingYet('group', 'Nobody yet', 'Women who ask to work with you appear here, the longest-waiting first, so you never have to hunt for who needs a reply.')
    + card(
      row(`${icon('image', { size: 23, color: C.primaryDim })}${col(`${strong('Your page is how they find you', 'titleM')}${m('It is live for 1,204 women a month once published.')}`, { gap: 2, grow: true })}`, { gap: 11, justify: 'flex-start', align: 'flex-start' })
      + btn('Work on my page', { h: 46, size: 15, go: 'B14' }), { v: 'tonal', gap: 11 })
    + sectionHead('Ready for when she arrives')
    + todoRow('repeat', 'My splits', 'Nothing saved yet', 'K19')
    + todoRow('checklist', 'Assessment', 'Runs before her first week', 'K21')
    + m('Accepting a client takes one of your 20 places. She pays only once you accept.')
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Clients', 'coach'));

const B14 = phone(
  statusBar()
  + appBar({ title: 'My portfolio', leadGo: 'K24', actions: [{ icon: 'visibility', go: 'B10' }] })
  + body(
    row(`<div style="width:104px;flex:0 0 auto;border-radius:12px;border:1.5px dashed ${C.outline};background:${C.surfaceLow};height:132px;display:flex;align-items:center;justify-content:center">${icon('add', { size: 26, color: C.outline })}</div>`
      + col(`${strong('Your page is empty', 'titleM')}${m('Not a template with your name dropped in. A stack of sections you choose and order yourself.')}`, { gap: 5, grow: true }), { gap: 13, justify: 'flex-start', align: 'flex-start' })
    + sectionHead('Most coaches start with these three')
    + todoRow('image', 'A cover', 'One photo, one sentence about what you do', 'B04')
    + todoRow('payments', 'One offer', 'What it is called, what is in it, what it costs', 'B06')
    + todoRow('checklist', 'How you work', 'Your method, in the words you already use', 'B07')
    + card(row(`${icon('add', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;font-weight:600;color:${C.primaryDim}">Browse all 12 sections</div>`, { gap: 10, justify: 'flex-start' }), { v: 'filled', pad: '11px 13px', go: 'B03' })
    + sageNote('Nothing here is decided for you. Two coaches on this platform should not look alike.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Start with a cover', { h: 54, go: 'B04' })));

export const screens = [
  { id: 'T06', html: T06, metric: 'day one, nothing logged', note: 'The Home every other screen assumes she has already outgrown. The program she just chose is the one filled card; everything else states plainly what will appear there and offers the single smallest action that starts it. The weekly rule is said once, before she can fail it.' },
  { id: 'E09', html: E09, metric: 'no history to rank', note: 'Eat normally leads with what she usually eats at this hour — which is nothing on day one. So it explains the mechanism instead ("log it twice and it becomes a plate") and offers three real Egyptian starters, because an empty box asks her to invent an answer.' },
  { id: 'M17', html: M17, metric: 'empty on purpose', note: 'An empty community feed reads as abandonment unless you say why. This one says the feed is groups she joins rather than a public timeline, which turns the emptiness into the product\'s main promise, and offers three groups matched to a beginner.' },
  { id: 'K24', html: K24, metric: '0 clients, 3 things to do', note: 'A new coach currently meets a Today built for someone with twelve clients. This is the same screen with nothing in it: the verification wait, what a client will look like when she arrives, and the three pieces of real work that are worth doing before that — none of them busywork.' },
  { id: 'W11', html: W11, metric: 'the page is the answer', note: 'The empty client list points at the one thing that actually fills it. Coaches blame the platform for no clients; this screen names the real lever and links straight to it.' },
  { id: 'B14', html: B14, metric: '3 sections to start', note: 'A blank builder is paralysing, so this names the three sections most coaches start with while stating that nothing is decided for her. The dashed placeholder shows the shape of a page without suggesting a template.' },
];
