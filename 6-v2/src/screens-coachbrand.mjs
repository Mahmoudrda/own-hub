import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, navBar, sheet, snackbar, sageNote, listItem, appBar, avatar, spacer, field, toggle, kv,
  shot, followBtn, photoGrid, blockItem, miniSite, swatchRow, typeCard, canvasBar, sectionHead, followUpStrip } = K;

// Her page is a stack of blocks she chose and ordered. Nothing here is a fixed
// template: the same builder can produce a one-screen card or a long sales page.
const HER_PAGE = [{ k: 'hero', tone: 'dusk' }, { k: 'text', n: 3 }, { k: 'cards', n: 2 }, { k: 'grid' }, { k: 'text', n: 2 }, { k: 'cta' }];

// ---------------- hub ----------------
const B01 = phone(
  statusBar()
  + appBar({ title: 'My portfolio', leadGo: 'K07', actions: [{ icon: 'visibility', go: 'B10' }] })
  + body(
    row(`${miniSite(HER_PAGE, { w: 112, go: 'B10' })}${col(`${strong('Nourhan El-Sayed', 'titleM')}${m('Published 4 days ago · version 3')}${row(`${pill('Live', { bg: C.tertiaryContainer, color: C.tertiary, ic: 'check_circle' })}${pill('6 sections', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`, { gap: 6, justify: 'flex-start' })}`, { gap: 6, grow: true })}`, { gap: 13, justify: 'flex-start', align: 'flex-start' })
    + row(`${btn('Design it', { h: 48, ic: 'edit', go: 'B02' })}${btn('Preview', { v: 'outlined', h: 48, size: 15, go: 'B10' })}`, { gap: 9 })
    + card(row(`${col(`${strong('This week', 'titleM')}${m('Views → profile → enquiries')}`, { gap: 2, grow: true })}${icon('chevron_right', { size: 21, color: C.onSurfaceVariant })}`, { gap: 10 })
      + row(`${col(`${strong('1,204', 'titleL')}${m('views')}`, { gap: 0 })}${col(`${strong('86', 'titleL')}${m('opened')}`, { gap: 0 })}${col(`${strong('9', 'titleL')}${m('enquiries')}`, { gap: 0 })}`, { gap: 8, justify: 'space-between' }), { gap: 10, go: 'B12' })
    + listItem({ lead: icon('image', { size: 22, color: C.primaryDim }), title: 'Design an ad', sub: 'Your look, sized for the feed, a story or a reel cover', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'B09' })
    + listItem({ lead: icon('trending_up', { size: 22, color: C.primaryDim }), title: 'Client results', sub: '4 published · each one consented', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'B08' })
    + sageNote('Nothing about this page is a template we hand you. The sections, the order, the colours and the words are yours. We only check the certificates behind the badge.')
  , { pad: '0 16px 0', gap: 11 })
  + navBar('Today', 'coach'));

// ---------------- the canvas ----------------
const B02 = phone(
  statusBar()
  + canvasBar('Your page', { leftGo: 'B01', right: [{ icon: 'visibility', go: 'B10' }, { label: 'Publish', v: 'filled', go: 'B11' }] })
  + body(
    row(`${chipRow([{ label: 'Sections', sel: true }, { label: 'Your look', go: 'B05' }, { label: 'Media', go: 'B13' }], -1, { grow: true })}`, { gap: 0 })
    + blockItem({ ic: 'image', title: 'Cover', sub: 'Photo, headline, one line', go: 'B04' })
    + blockItem({ ic: 'person', title: 'Who I am', sub: 'Three short paragraphs', go: 'B04' })
    + blockItem({ ic: 'checklist', title: 'How I work', sub: 'Your four steps', go: 'B07' })
    + blockItem({ ic: 'payments', title: 'What I offer', sub: '2 offers, written by you', go: 'B06' })
    + blockItem({ ic: 'trending_up', title: 'Client results', sub: '4 stories · consented', go: 'B08' })
    + blockItem({ ic: 'videocam', title: 'A minute with me', sub: 'Hidden for now', on: false, go: 'B13' })
    + card(row(`${icon('add', { size: 23, color: C.primaryDim })}<div style="flex:1;font-size:16px;font-weight:600;color:${C.primaryDim}">Add a section</div>`, { gap: 11, justify: 'flex-start' }), { v: 'filled', pad: '12px 14px', go: 'B03' })
    + m('Drag to reorder. The eye hides a section without deleting what is in it.')
  , { pad: '10px 16px 0', gap: 9 }));

const B03 = phone(
  statusBar()
  + canvasBar('Your page', { leftGo: 'B02' })
  + body(blockItem({ ic: 'image', title: 'Cover', sub: 'Photo, headline, one line' }) + blockItem({ ic: 'person', title: 'Who I am', sub: 'Three short paragraphs' }), { pad: '10px 16px 0', gap: 9 })
  + sheet(
    h('Add a section', 'titleL')
    + grid(
      [['checklist', 'How I work'], ['payments', 'What I offer'], ['trending_up', 'Client results'], ['forum', 'What they said'],
      ['videocam', 'Video'], ['photo_library', 'Gallery'], ['verified_user', 'Certificates'], ['help', 'Questions'],
      ['schedule', 'When I am free'], ['menu_book', 'Something free'], ['bar_chart', 'Numbers'], ['send', 'Ask me']]
        .map(([ic, label]) => `<div style="border-radius:${R.md}px;border:1.5px solid ${C.outlineVariant};background:${C.surfaceLowest};padding:11px 10px;display:flex;flex-direction:column;gap:7px;cursor:pointer" data-go="B04">${icon(ic, { size: 21, color: C.primaryDim })}<div style="font-size:14px;font-weight:600;color:${C.onSurface}">${label}</div></div>`).join('')
      , { cols: 3, gap: 8 })
    + m('Pick as many as you want, in any order. A section can appear more than once.')
    , { gap: 11 }),
  { layered: true });

// ---------------- editing one block ----------------
const B04 = phone(
  statusBar()
  + canvasBar('Cover', { left: 'close', leftGo: 'B02', right: [{ label: 'Done', v: 'filled', go: 'B02' }] })
  + body(
    `<div style="position:relative;flex:0 0 auto">${shot('', { h: 150, r: R.md, tone: 'dusk' })}<div style="position:absolute;left:0;right:0;bottom:0;padding:12px 14px;background:linear-gradient(180deg,transparent,rgba(36,26,30,.66));border-radius:0 0 ${R.md}px ${R.md}px"><div style="font-size:19px;font-weight:700;color:#FFFFFF">Back to lifting, after birth</div><div style="font-size:13px;color:rgba(255,255,255,.88)">Giza · at home · 20 minutes</div></div><div style="position:absolute;right:9px;top:9px;height:32px;padding:0 11px;border-radius:999px;background:rgba(255,255,255,.92);display:flex;align-items:center;gap:5px;font-size:13px;font-weight:600;color:${C.onSurface}">${icon('photo_camera', { size: 15, color: C.onSurface })}Change</div></div>`
    + sectionHead('Layout')
    + row(`${['Text over photo', 'Photo above', 'No photo'].map((x, i) => `<div style="flex:1;border-radius:${R.md}px;border:${i === 0 ? `2px solid ${C.primary}` : `1.5px solid ${C.outlineVariant}`};background:${C.surfaceLowest};padding:9px;display:flex;flex-direction:column;gap:6px;align-items:center"><div style="width:100%;height:34px;border-radius:6px;background:${i === 2 ? C.surfaceContainer : C.primarySoft};display:flex;align-items:${i === 1 ? 'flex-end' : 'center'};justify-content:center"><div style="width:70%;height:5px;border-radius:3px;background:${C.primary};opacity:.5"></div></div><div style="font-size:12px;font-weight:600;color:${C.onSurface};text-align:center">${x}</div></div>`).join('')}`, { gap: 8 })
    + field({ label: 'Headline', value: 'Back to lifting, after birth' })
    + field({ label: 'One line under it', value: 'Giza · at home · 20 minutes' })
    + row(`${col(`${strong('Darken the photo', 'titleS')}${m('So the words stay readable')}`, { gap: 2, grow: true })}${linear(62, { h: 8, c: C.primary })}`, { gap: 12 })
  , { pad: '10px 16px 0', gap: 11 }));

// ---------------- her look ----------------
const B05 = phone(
  statusBar()
  + canvasBar('Your look', { leftGo: 'B02', right: [{ icon: 'visibility', go: 'B10' }, { label: 'Done', v: 'filled', go: 'B02' }] })
  + body(
    row(`${miniSite([{ k: 'hero', tone: 'dusk' }, { k: 'text', n: 2 }, { k: 'cards', n: 2 }, { k: 'cta' }], { w: 92 })}${col(`${strong('This is yours, not ours', 'titleM')}${m('Colour, type and shape change every section at once. Nothing you write moves.')}`, { gap: 4, grow: true })}`, { gap: 12, justify: 'flex-start', align: 'flex-start' })
    + sectionHead('Colour')
    + swatchRow(['#B4526E', '#4F7359', '#8A5A17', '#4A5B8C', '#7A4A7E', '#2F6E6A'], 0)
    + sectionHead('Type')
    + row(`${typeCard('Calm and plain', 'Aa', { sel: true })}${typeCard('Strong and wide', 'Aa')}${typeCard('Soft and round', 'Aa')}`, { gap: 8 })
    + sectionHead('Corners')
    + row(`${[['Sharp', 4], ['Soft', 14], ['Round', 26]].map(([lb, rr], i) => `<div style="flex:1;border-radius:${R.md}px;border:${i === 1 ? `2px solid ${C.primary}` : `1.5px solid ${C.outlineVariant}`};padding:10px;display:flex;flex-direction:column;align-items:center;gap:7px"><div style="width:42px;height:28px;border-radius:${rr}px;background:${C.primarySoft}"></div><div style="font-size:12px;font-weight:600;color:${C.onSurface}">${lb}</div></div>`).join('')}`, { gap: 8 })
    + card(row(`${icon('visibility', { size: 22, color: C.primaryDim })}${col(`${strong('Contrast is checked for you', 'titleM')}${m('We will not let you pick text a client cannot read.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'sage', pad: '11px 13px' })
  , { pad: '10px 16px 0', gap: 10 }));

// ---------------- offers ----------------
const B06 = phone(
  statusBar()
  + canvasBar('What I offer', { left: 'close', leftGo: 'B02', right: [{ label: 'Done', v: 'filled', go: 'B02' }] })
  + body(
    m('Write your own offers. Two is common, one is fine, and nothing forces them to look alike.')
    + card(
      row(`${col(`${strong('Monthly coaching', 'titleM')}${m('Plan, weekly review, chat')}`, { gap: 3, grow: true })}${iconBtn('drag_handle', { d: 32 })}`)
      + row(`${field({ label: 'Price a month', value: '1,800 EGP' })}`, { gap: 0 })
      + col(['A plan built for your days', 'A weekly review answered by voice', 'Chat, replies in about 2 hours'].map(x => row(`${icon('check', { size: 18, color: C.tertiary })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">${x}</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' })).join(''), { gap: 6 })
      + row(`${chip('Add a line', { ic: 'add', h: 34 })}${chip('Badge: most picked', { h: 34, sel: true })}`, { gap: 7, justify: 'flex-start' })
      , { v: 'selected', gap: 10 })
    + card(row(`${col(`${strong('Plan only', 'titleM')}${m('A program, no check-ins · 900 EGP')}`, { gap: 3, grow: true })}${iconBtn('edit', { d: 32 })}`), { gap: 8 })
    + card(row(`${icon('add', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;font-weight:600;color:${C.primaryDim}">Add another offer</div>`, { gap: 10, justify: 'flex-start' }), { v: 'filled', pad: '11px 13px' })
    + card(row(`${col(`${strong('Clients at once', 'titleM')}${m('Shown on your page as spots left.')}`, { gap: 2, grow: true })}${strong('20', 'titleL')}`), { gap: 8 })
    + sageNote('You keep 80% of every price you write here. The client sees the price; she never sees our share.')
  , { pad: '10px 16px 0', gap: 10 }));

// ---------------- her method ----------------
const B07 = phone(
  statusBar()
  + canvasBar('How I work', { left: 'close', leftGo: 'B02', right: [{ label: 'Done', v: 'filled', go: 'B02' }] })
  + body(
    m('Your method, in your own steps. Name them whatever you call them with clients.')
    + [['1', 'We talk first', 'Twenty minutes, no charge, before you pay anything.'], ['2', 'The floor weeks', 'Pelvic floor and breathing before a single squat.'], ['3', 'Back under a weight', 'Slowly, with your doctor’s clearance.'], ['4', 'You keep it', 'The last month you run the plan, I only watch.']]
      .map(([n, ti, sub]) => card(row(`<div style="width:30px;height:30px;border-radius:999px;background:${C.primaryContainer};display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:700;color:${C.onPrimaryContainer};flex:0 0 auto">${n}</div>${col(`${strong(ti, 'titleS')}${m(sub)}`, { gap: 2, grow: true })}${icon('drag_handle', { size: 19, color: C.outline })}`, { gap: 10, align: 'flex-start' }), { pad: '10px 12px', gap: 0 })).join('')
    + card(row(`${icon('add', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;font-weight:600;color:${C.primaryDim}">Add a step</div>`, { gap: 10, justify: 'flex-start' }), { v: 'filled', pad: '11px 13px' })
  , { pad: '10px 16px 0', gap: 9 }));

// ---------------- results, with consent ----------------
const B08 = phone(
  statusBar()
  + canvasBar('Client results', { left: 'close', leftGo: 'B02', right: [{ label: 'Done', v: 'filled', go: 'B02' }] })
  + body(
    card(row(`${icon('handshake', { size: 22, color: C.tertiary })}${col(`${strong('She has to agree, in the app', 'titleM')}${m('We ask her, she picks the pictures, and she can withdraw it later.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'sage', pad: '11px 13px' })
    + card(
      row(`${avatar(34, { initial: 'M' })}${col(`${strong('Mai Farouk', 'titleS')}${m('Consented 2 September · she chose blur')}`, { gap: 2, grow: true })}${pill('Live', { bg: C.tertiaryContainer, color: C.tertiary })}`)
      + followUpStrip([{ tone: 'sand', blur: true, label: 'Week 1' }, { tone: 'rose', blur: true, label: 'Week 8' }, { tone: 'sage', blur: true, label: 'Now', now: true }], { h: 82 })
      + t('Carried both kids up the stairs. 24 sessions, no weight ever discussed.', { k: 'bodyM' })
      , { gap: 10 })
    + card(row(`${avatar(34, { initial: 'H' })}${col(`${strong('Hala Mostafa', 'titleS')}${m('Numbers only · she declined photos')}`, { gap: 2, grow: true })}${pill('Live', { bg: C.tertiaryContainer, color: C.tertiary })}`) + row(`${chip('Plank 20s → 75s')}${chip('12 weeks')}`, { gap: 7, justify: 'flex-start' }), { gap: 9 })
    + card(row(`${icon('add', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;font-weight:600;color:${C.primaryDim}">Ask another client</div>`, { gap: 10, justify: 'flex-start' }), { v: 'filled', pad: '11px 13px' })
    + m('A result can be pictures, numbers, or her sentence, whichever she agreed to.')
  , { pad: '10px 16px 0', gap: 10 }));

// ---------------- the ad ----------------
const B09 = phone(
  statusBar()
  + canvasBar('Design an ad', { leftGo: 'B01', right: [{ label: 'Save to media', v: 'filled', go: 'B13' }] })
  + body(
    chipRow([{ label: 'Feed', sel: true }, { label: 'Story' }, { label: 'Reel cover' }], -1, { grow: true })
    + `<div style="position:relative;flex:0 0 auto;align-self:center">${shot('', { h: 260, w: '260px', r: R.md, tone: 'dusk' })}`
    + `<div style="position:absolute;inset:0;padding:16px;display:flex;flex-direction:column;justify-content:flex-end;gap:7px;background:linear-gradient(180deg,rgba(36,26,30,.12),rgba(36,26,30,.68));border-radius:${R.md}px">`
    + `<div style="font-size:23px;line-height:28px;font-weight:700;color:#FFFFFF">Six weeks after birth, on the floor</div>`
    + `<div style="font-size:14px;color:rgba(255,255,255,.9)">Nourhan · Giza · from 1,800 EGP</div>`
    + `<div style="align-self:flex-start;height:34px;padding:0 14px;border-radius:999px;background:#FFFFFF;display:flex;align-items:center;font-size:14px;font-weight:600;color:${C.onSurface}">Ask me</div></div></div>`
    + row(`${chip('Your colours', { sel: true, h: 34 })}${chip('Change photo', { ic: 'photo_camera', h: 34 })}${chip('Edit words', { ic: 'edit', h: 34 })}`, { gap: 7, justify: 'flex-start' })
    + card(row(`${icon('warning', { size: 21, color: C.amber })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">No weight-loss promises and no timelines. We check every ad against the same rules before it runs.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'amber', pad: '10px 12px' })
  , { pad: '10px 16px 0', gap: 11 }));

// ---------------- preview and publish ----------------
const B10 = phone(
  `<div style="position:absolute;inset:0;overflow:hidden;display:flex;flex-direction:column">`
  + statusBar()
  + `<div style="flex:1;min-height:0;display:flex;flex-direction:column;gap:11px;overflow:hidden">`
  + `<div style="position:relative;flex:0 0 auto">${shot('', { h: 230, r: 0, tone: 'dusk' })}`
  + `<div style="position:absolute;left:0;right:0;bottom:0;padding:14px 16px;background:linear-gradient(180deg,transparent,rgba(36,26,30,.7))">`
  + `<div style="font-size:24px;line-height:29px;font-weight:700;color:#FFFFFF">Back to lifting, after birth</div>`
  + `<div style="font-size:13px;color:rgba(255,255,255,.88);margin-top:3px">Giza · at home · 20 minutes</div></div></div>`
  + `<div style="padding:0 16px;display:flex;flex-direction:column;gap:11px">`
  + row(`${avatar(48, { initial: 'N' })}${col(`${row(`${strong('Nourhan El-Sayed', 'titleM')}${icon('verified', { size: 16, color: C.primaryDim, fill: true })}`, { gap: 5, justify: 'flex-start' })}${m('4.8 ★ (126) · replies in ~2h')}`, { gap: 2, grow: true })}${followBtn('follow', { h: 34 })}`, { gap: 11, justify: 'flex-start' })
  + t('I take women from six weeks after birth back to lifting, slowly.', { k: 'bodyM' })
  + card(row(`${col(`${strong('Monthly coaching', 'titleM')}${m('Plan, weekly review, chat')}`, { gap: 2, grow: true })}${strong('1,800 EGP', 'titleM')}`), { gap: 8 })
  + `</div></div>`
  + `<div style="position:absolute;left:16px;right:16px;bottom:22px;display:flex;gap:9px">${btn('Back to editing', { v: 'white', h: 48, size: 15, go: 'B02' })}${btn('Publish', { h: 48, size: 15, go: 'B11' })}</div>`
  + `</div>`,
  { layered: true });

const B11 = phone(
  statusBar()
  + appBar({ title: 'Publish', lead: 'close', leadGo: 'B02' })
  + body(
    card(col(`${strong('What changed since version 3', 'titleM')}${kv('Cover photo', 'replaced')}${kv('How I work', 'added')}${kv('Monthly coaching', '1,650 → 1,800 EGP')}${kv('A minute with me', 'hidden', { last: true })}`, { gap: 2 }), { gap: 8 })
    + card(row(`${icon('schedule', { size: 21, color: C.primaryDim })}${col(`${strong('Live within a minute', 'titleM')}${m('Women already reading it see the old one until it swaps.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'tonal', pad: '11px 13px' })
    + card(row(`${icon('history', { size: 21, color: C.onSurfaceVariant })}${col(`${strong('Version 3 is kept', 'titleM')}${m('Go back to it any time.')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { pad: '11px 13px' })
    + sageNote('Your price change applies to new clients only. Everyone already with you keeps what she agreed to.')
  , { pad: '0 16px 0', gap: 11 })
  + footer(btn('Publish version 4', { h: 56, ic: 'rocket_launch', go: 'B12' }) + btn('Keep as a draft', { v: 'text', h: 44, size: 15, go: 'B02' })));

const B12 = phone(
  statusBar()
  + appBar({ title: 'What it is doing', leadGo: 'B01', actions: [{ icon: 'share' }] })
  + body(
    card(col(`${m('Last 30 days')}${h('1,204 views', 'display')}${m('86 opened your page · 9 asked to work with you')}`, { gap: 4 }) + linear(7, { h: 10, c: C.primary }) + m('Seven women in a hundred who see you ask. The average here is four.'), { v: 'tonal', gap: 10 })
    + sectionHead('Which section they stop on')
    + [['Cover', 92], ['Client results', 71], ['What I offer', 54], ['How I work', 38]].map(([lb, pct]) => col(`${row(`${strong(lb, 'titleS')}${m(String(pct) + '%')}`)}${linear(pct, { h: 7 })}`, { gap: 5 })).join('')
    + card(row(`${icon('info', { size: 21, color: C.primaryDim })}<div style="flex:1;font-size:14px;line-height:20px;color:${C.onSurface}">Women who reach Client results ask twice as often. It sits fifth. Try moving it up.</div>`, { gap: 9, justify: 'flex-start', align: 'flex-start' }), { v: 'sage', pad: '10px 12px', go: 'B02' })
  , { pad: '0 16px 0', gap: 11 })
  + navBar('Today', 'coach'));

const B13 = phone(
  statusBar()
  + canvasBar('Your media', { leftGo: 'B02', right: [{ label: 'Done', v: 'filled', go: 'B02' }] })
  + body(
    chipRow([{ label: 'All', sel: true }, { label: 'Photos' }, { label: 'Video' }], -1, { grow: false })
    + photoGrid([
      shot('', { h: 108, r: R.xs, tone: 'dusk' }), shot('', { h: 108, r: R.xs, tone: 'sage' }), shot('', { h: 108, r: R.xs, tone: 'sand', dur: '0:58', play: true }),
      shot('', { h: 108, r: R.xs, tone: 'rose' }), shot('', { h: 108, r: R.xs, tone: 'mint' }), shot('', { h: 108, r: R.xs, tone: 'warm', dur: '1:24', play: true }),
    ], { cols: 3, gap: 4 })
    + card(row(`${icon('photo_camera', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;font-weight:600;color:${C.primaryDim}">Add photos or a video</div>`, { gap: 10, justify: 'flex-start' }), { v: 'filled', pad: '11px 13px' })
    + card(row(`${icon('blur_on', { size: 21, color: C.primaryDim })}${col(`${strong('Blur any client who is in shot', 'titleM')}${m('On unless she consented to her face.')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 10 }), { v: 'tonal', pad: '10px 12px' })
  , { pad: '10px 16px 0', gap: 11 }));

export const screens = [
  { id: 'B01', html: B01, metric: 'her page, her decisions', note: 'The portfolio gets its own home rather than living inside settings, because for a coach this page is the product. Views, opens and enquiries sit together as one funnel, which is the only number that tells her whether the page is working.' },
  { id: 'B02', html: B02, metric: '0 fixed templates', note: 'The canvas is a list of blocks she chose, dragged into her order, each one hideable without being deleted. This is the whole answer to "I do not want every coach to get the same page": the page is a stack, and she owns the stack.' },
  { id: 'B03', html: B03, metric: '12 blocks, any order', note: 'Twelve section types, addable more than once. A coach who sells one thing builds a three-block card; a coach with a method and testimonials builds a long page. Neither is the default.' },
  { id: 'B04', html: B04, metric: 'layout is a choice', note: 'Editing a block offers real layout variants rather than a fixed slot, and the overlay slider exists because a coach who uploads a bright photo needs her headline to stay readable without knowing what contrast means.' },
  { id: 'B05', html: B05, metric: 'colour, type, shape', note: 'One screen restyles the whole page, which is what makes two coaches on this platform look genuinely different. Contrast is validated behind the scenes so freedom never produces text a client cannot read.' },
  { id: 'B06', html: B06, metric: 'she writes the offer', note: 'Offers are authored, not configured: her own name for the package, her own lines, her own badge. The 80% share is restated here because this is the screen where she decides what to charge.' },
  { id: 'B07', html: B07, metric: 'her method, her words', note: 'Coaches sell a method, and every good one already has names for its phases. The builder asks for those names instead of imposing "Assessment, Programming, Delivery".' },
  { id: 'B08', html: B08, metric: 'consent before publication', note: 'Client results exist because coaches need them, and they are gated behind in-app consent the client can withdraw. She picks the pictures, blur stays on unless she turns it off, and a result can be numbers or a sentence if she declines photos entirely.' },
  { id: 'B09', html: B09, metric: '3 sizes, one look', note: 'The ad designer inherits her colours and type, so her feed post, her story and her reel cover match her page without her rebuilding anything. The rules banner is the same one the brief applies to our own campaigns.' },
  { id: 'B10', html: B10, metric: 'exactly what a client sees', note: 'Preview is the real client-side rendering, not an approximation, with editing and publishing one tap away so she can loop without losing her place.' },
  { id: 'B11', html: B11, metric: 'versioned, never surprising', note: 'Publishing states what changed, keeps the previous version, and promises that a price rise applies only to new clients — the thing a coach is most afraid of getting wrong in public.' },
  { id: 'B12', html: B12, metric: 'views → enquiries', note: 'Insights answer one question: does the page turn attention into work. Section attention is shown so she can act on it, and the one suggestion is phrased as something to try rather than an instruction.' },
  { id: 'B13', html: B13, metric: 'blur unless consented', note: 'Her media library keeps the same rule as the community: any client in shot is blurred unless that client agreed to her face being shown.' },
];
