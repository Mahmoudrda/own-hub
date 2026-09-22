import * as K from './kit.mjs';
const { C, R, phone, statusBar, body, footer, card, row, col, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, navBar, sheet, sageNote, listItem, appBar, avatar, toggle, field, media, spacer } = K;

const setting = (ic, title, sub, trail, goId = '') => listItem({ lead: icon(ic, { size: 24, color: C.primaryDim }), title, sub, trail: trail || icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: goId, pad: '8px 14px' });

const A01 = phone(
  statusBar()
  + appBar({ title: 'Notifications', leadGo: 'T01', actions: [{ icon: 'settings', go: 'A02' }] })
  + body(
    listItem({ lead: avatar(44, { ic: 'sports' }), title: 'Sara replied to your review', sub: '2 hours ago · voice note', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'G13', v: 'tonal' })
    + listItem({ lead: avatar(44, { ic: 'groups' }), title: 'Beginners group reached 146 sessions', sub: 'Yesterday · 5 days left', go: 'M06' })
    + listItem({ lead: avatar(44, { ic: 'favorite' }), title: 'Habiba and 12 others liked your best', sub: 'Yesterday', go: 'M02' })
    + listItem({ lead: avatar(44, { ic: 'restaurant' }), title: 'Breakfast, your usual?', sub: 'Tuesday 8:40 · logged from the lock screen', go: 'T03' })
    + sageNote('One nudge a day at most, at the hour you usually log. Ignore three and they stop by themselves.')
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

const A02 = phone(
  statusBar()
  + appBar({ title: '', leadGo: 'T01' })
  + body(
    row(`${avatar(56, { initial: 'M' })}${col(`${row(`${strong('Mai Farouk', 'titleL')}${icon('verified', { size: 18, color: C.primaryDim, fill: true })}`, { gap: 6, justify: 'flex-start' })}${m('Verified woman · Regular · level 7')}`, { gap: 4, grow: true })}${iconBtn('edit', { go: 'M07' })}`, { gap: 12, justify: 'flex-start' })
    + setting('self_improvement', 'My cycle', 'Period day 2 · symptom tracking', '', 'Y03')
    + setting('sports', 'My coach', 'Sara Hany · day 9 of 30', '', 'G04')
    + setting('language', 'Language', 'English · العربية', '', 'A02')
    + setting('notifications', 'Notifications', 'One a day, quiet 10pm to 8am', '', 'A01')
    + setting('lock', 'Privacy', 'Who sees your profile and wins', '', 'A03')
    + setting('shield', 'Safety Centre', 'Reports, blocked members, help', '', 'A04')
    + setting('download', 'Your data', 'Download everything, or delete your account')
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

const A03 = phone(
  statusBar()
  + appBar({ title: 'Privacy', leadGo: 'A02' })
  + body(
    sageNote('Your logs, weight, photos and phone number are never visible to another member. These settings are only about what you choose to show.')
    + setting('person', 'Profile visible to members', 'Name, tier and groups', toggle(true))
    + setting('trophy', 'Show my personal bests', 'Numbers only, never weight from a scale', toggle(true))
    + setting('blur_on', 'Blur faces in my photos', 'On by default for every post', toggle(true))
    + setting('sports', 'My coach can see my logs', 'Sessions, food days and bests', toggle(true))
    + setting('self_improvement', 'Cycle information', 'Energy and appetite only · you choose', '', 'Y12')
    + m('Your ID and selfie were deleted after the check. Only the result is kept.')
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

const A04 = phone(
  statusBar()
  + appBar({ title: 'Safety Centre', leadGo: 'A02' })
  + body(
    card(row(`${icon('verified_user', { size: 26, color: C.tertiary })}${col(`${strong('Every member is verified', 'titleM')}${m('ID checked, women only, reviewed by women')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' }), { v: 'sage' })
    + setting('flag', 'Report someone', 'A woman moderator reads it within an hour', '', 'M08')
    + setting('block', 'Blocked members', '2 blocked', '', 'A04')
    + setting('history', 'Reports you made', '1 · resolved in 40 minutes', '', 'A04')
    + setting('help', 'What happens when I report?', 'The three steps, plainly')
    + setting('support_agent', 'Talk to a human', 'A woman on the team, 9am to 9pm')
    + m('If you are in danger right now, call 122. This app cannot reach the police for you.')
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Home'));

export const screens = [
  { id: 'A01', html: A01, metric: 'few, and worth it', note: 'Notifications are things a person did or a thing she can act on, never engagement bait. The meal nudge appears here as a log she completed without opening the app, and the rule about them stopping is stated where she would go to turn them off.' },
  { id: 'A02', html: A02, metric: 'settings she can read', note: 'Seven rows, each one in her words. Download and delete sit at the bottom as ordinary settings rather than buried in a legal page, which is both the regulation and the decent thing.' },
  { id: 'A03', html: A03, metric: 'what she shows, not what we keep', note: 'The first line separates the two questions women actually ask — what is stored, and what other people see. Face blur is a privacy setting, not a camera feature, so it lives here as well as in the composer.' },
  { id: 'A04', html: A04, metric: 'one hour, promised', note: 'Safety is a place, not a menu item: reporting, blocked members, past reports, what happens next, and a human. The emergency line names the Egyptian number and is honest that the app cannot call it for her.' },
];
