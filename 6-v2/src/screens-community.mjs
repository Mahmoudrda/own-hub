import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, navBar, sheet, snackbar, sageNote, listItem, appBar, avatar, spacer, field, toggle,
  shot, storyRing, storiesRail, followBtn, railBtn, fullMedia, photoGrid, statCol, iconTabs, storyBars, followUpStrip, sectionHead } = K;

// The feed header carries the three things a social app opens with:
// what is new for her, search, and the camera.
const feedHead = (title, { search = 'M10', create = 'M03', activity = 'M14' } = {}) =>
  `<div style="flex:0 0 auto;height:54px;padding:0 4px 0 16px;display:flex;align-items:center;justify-content:space-between">`
  + `<div style="font-size:20px;line-height:26px;font-weight:600;color:${C.onPrimaryContainer}">${title}</div>`
  + `<div style="display:flex">${iconBtn('groups', { d: 44, go: 'M04' })}${iconBtn('favorite', { d: 44, go: activity })}${iconBtn('search', { d: 44, go: search })}${iconBtn('photo_camera', { d: 44, go: create })}</div></div>`;

const actionBar = (likes, comments, { saved = false } = {}) =>
  `<div style="padding:0 14px;display:flex;align-items:center;gap:15px;flex:0 0 auto">`
  + `<div style="display:flex;align-items:center;gap:5px">${icon('favorite', { size: 25, color: C.primary, fill: true })}<span style="font-size:14px;font-weight:600;color:${C.onSurface}">${likes}</span></div>`
  + `<div style="display:flex;align-items:center;gap:5px"${K.go('M02')}>${icon('comment', { size: 25, color: C.onSurface })}<span style="font-size:14px;font-weight:600;color:${C.onSurface}">${comments}</span></div>`
  + `${icon('send', { size: 25, color: C.onSurface })}<div style="flex:1"></div>${icon('bookmark', { size: 25, color: saved ? C.primary : C.onSurface, fill: saved })}</div>`;

const postHead = (name, meta, { more = 'M08', profile = 'M07', follow = '' } = {}) =>
  `<div style="padding:0 6px 0 14px;display:flex;align-items:center;gap:10px;flex:0 0 auto">${avatar(38, { initial: name[0] })}`
  + `<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:1px"${K.go(profile)}>`
  + `<div style="display:flex;align-items:center;gap:4px;font-size:15px;font-weight:600;color:${C.onSurface}">${name}${icon('verified', { size: 15, color: C.primaryDim, fill: true })}</div>`
  + `<div style="font-size:12px;color:${C.onSurfaceVariant}">${meta}</div></div>`
  + (follow ? followBtn(follow, { h: 32 }) : '') + iconBtn('more_vert', { d: 38, go: more }) + `</div>`;

const caption = (name, text, { comments = '', ago = '' } = {}) =>
  `<div style="padding:0 14px;display:flex;flex-direction:column;gap:4px;flex:0 0 auto">`
  + `<div style="font-size:15px;line-height:21px;color:${C.onSurface}"><span style="font-weight:600">${name}</span> ${text}</div>`
  + (comments ? `<div style="font-size:14px;color:${C.onSurfaceVariant}"${K.go('M02')}>${comments}</div>` : '')
  + (ago ? `<div style="font-size:12px;color:${C.onSurfaceVariant}">${ago}</div>` : '') + `</div>`;

const post = (name, meta, text, o = {}) => {
  const { tone = 'warm', blur = true, likes = '124', comments = '18', mh = 292, ago = '', video = false, dur = '', follow = '', all = '', saved = false, tag = '' } = o;
  return `<div style="display:flex;flex-direction:column;gap:9px;flex:0 0 auto;padding-bottom:4px">`
    + postHead(name, meta, { follow })
    + shot('', { h: mh, r: 0, tone, blurFace: blur, play: video, dur, tag, go: 'M02' })
    + actionBar(likes, comments, { saved })
    + caption(name, text, { comments: all, ago })
    + `</div>`;
};

// ---------------- feed ----------------
const M01 = phone(
  statusBar()
  + feedHead('Community')
  + storiesRail([
    storyRing('Your day', { initial: 'M', mine: true, seen: true, go: 'M03' }),
    storyRing('Habiba', { initial: 'H', tone: 'sage', go: 'M13' }),
    storyRing('Nada', { initial: 'N', tone: 'sand', go: 'M13' }),
    storyRing('Coach Sara', { initial: 'S', tone: 'rose', go: 'M13' }),
    storyRing('Yasmin', { initial: 'Y', tone: 'mint', seen: true, go: 'M13' }),
  ])
  + body(
    post('Nada Samir', 'Postpartum rebuild', 'Four weeks in and I carried both kids up the stairs without stopping.', { tone: 'sage', likes: '412', comments: '27', all: 'See all 27 comments', ago: '2 hours ago', mh: 268 })
    + post('Habiba Nasr', 'Beginners group', 'First week done. My knees did not hurt once.', { tone: 'sand', likes: '96', comments: '18', follow: 'follow', mh: 268 })
  , { pad: '0', gap: 14 })
  + navBar('Community'));

// ---------------- post and comments ----------------
const M02 = phone(
  statusBar()
  + appBar({ title: 'Post', leadGo: 'M01', actions: [{ icon: 'more_vert', go: 'M08' }] })
  + body(
    postHead('Nada Samir', 'Postpartum rebuild · 2 hours ago')
    + shot('', { h: 220, r: 0, tone: 'sage', blurFace: true })
    + actionBar('412', '27')
    + caption('Nada Samir', 'Four weeks in and I carried both kids up the stairs without stopping. Started at ten minutes a day on the floor.')
    + `<div style="padding:0 14px;display:flex;flex-direction:column;gap:9px">`
    + row(`${avatar(32, { initial: 'S' })}${col(`<div style="font-size:14px;line-height:20px;color:${C.onSurface}"><span style="font-weight:600">Sara Adel</span> This is the exact thing I needed to read today.</div>`, { gap: 2, grow: true })}${icon('favorite', { size: 17, color: C.onSurfaceVariant })}`, { gap: 9, justify: 'flex-start', align: 'flex-start' })
    + row(`${avatar(32, { initial: 'N' })}${col(`<div style="font-size:14px;line-height:20px;color:${C.onSurface}"><span style="font-weight:600">Nourhan El-Sayed</span> ${pill('Coach', { bg: C.amberContainer, color: C.amber })} Week five adds the standing moves. Message me if your back complains.</div>`, { gap: 3, grow: true })}${icon('favorite', { size: 17, color: C.onSurfaceVariant })}`, { gap: 9, justify: 'flex-start', align: 'flex-start' })
    + `</div>`
  , { pad: '0', gap: 10 })
  + footer(card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:15px;color:${C.onSurfaceVariant}">Say something kind</div>${icon('send', { size: 22, color: C.primaryDim })}`, { gap: 10, justify: 'flex-start' }), { pad: '11px 14px', r: R.full }), { pad: '6px 16px 12px' }));

// ---------------- create ----------------
const M03 = phone(
  statusBar()
  + appBar({ title: 'Create', lead: 'close', leadGo: 'M01' })
  + body(
    grid(
      `<div style="border-radius:${R.lg}px;overflow:hidden;position:relative;height:126px"${K.go('M16')}>${shot('', { h: 126, r: R.lg, tone: 'dusk' })}<div style="position:absolute;left:0;right:0;bottom:0;padding:10px 12px;background:linear-gradient(180deg,transparent,rgba(36,26,30,.62))"><div style="display:flex;align-items:center;gap:6px">${icon('videocam', { size: 19, color: '#FFFFFF' })}<div style="font-size:15px;font-weight:600;color:#FFFFFF">Reel</div></div></div></div>`
      + `<div style="border-radius:${R.lg}px;overflow:hidden;position:relative;height:126px"${K.go('M11')}>${shot('', { h: 126, r: R.lg, tone: 'sage' })}<div style="position:absolute;left:0;right:0;bottom:0;padding:10px 12px;background:linear-gradient(180deg,transparent,rgba(36,26,30,.62))"><div style="display:flex;align-items:center;gap:6px">${icon('history', { size: 19, color: '#FFFFFF' })}<div style="font-size:15px;font-weight:600;color:#FFFFFF">Follow-up</div></div></div></div>`
      , { cols: 2, gap: 10 })
    + listItem({ lead: icon('image', { size: 23, color: C.primaryDim }), title: 'Photo or post', sub: 'Faces blurred before it uploads', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }), go: 'M11' })
    + listItem({ lead: icon('trophy', { size: 23, color: C.amber }), title: 'A personal best', sub: 'Numbers only, never a weight from the scale', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }) })
    + listItem({ lead: icon('mic', { size: 23, color: C.primaryDim }), title: 'A voice note', sub: 'Up to a minute, for the group', trail: icon('chevron_right', { size: 21, color: C.onSurfaceVariant }) })
    + card(row(`${icon('blur_on', { size: 23, color: C.primaryDim })}${col(`${strong('Faces blurred', 'titleM')}${m('On before you ask. Tap to show yours.')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 11 }), { v: 'tonal', pad: '11px 13px' })
    + sageNote('Only verified women can see anything you post here, and screenshots are against the pledge everyone agreed to.')
  , { pad: '0 16px 0', gap: 11 })
  + navBar('Community'));

// ---------------- groups ----------------
const M04 = phone(
  statusBar()
  + appBar({ title: 'Groups', leadGo: 'M01', actions: [{ icon: 'search', go: 'M10' }] })
  + body(
    sectionHead('Yours')
    + listItem({ lead: avatar(44, { ic: 'self_improvement' }), title: 'Beginners group', sub: '4,210 women · 38 posts today', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'M05' })
    + listItem({ lead: avatar(44, { ic: 'child_care' }), title: 'Postpartum rebuild', sub: '1,860 women · 12 posts today', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'M05' })
    + sectionHead('Suggested for you')
    + listItem({ lead: avatar(44, { ic: 'restaurant' }), title: 'Ramadan training', sub: 'Opens with Ramadan · 6,400 women', trail: btn('Join', { v: 'tonal', h: 38, size: 14 }) })
    + listItem({ lead: avatar(44, { ic: 'groups' }), title: 'Cairo, west side', sub: 'Ladies-only gyms and walking groups', trail: btn('Join', { v: 'tonal', h: 38, size: 14 }) })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Community'));

const M05 = phone(
  statusBar()
  + appBar({ title: 'Beginners group', leadGo: 'M04', actions: [{ icon: 'more_vert', go: 'M08' }] })
  + body(
    card(row(`${col(`${strong('4,210 women', 'titleM')}${m('Nobody here has been training more than a year.')}`, { gap: 3, grow: true })}${btn('Joined', { v: 'tonal', h: 38, size: 14 })}`), { v: 'tonal', pad: '11px 13px' })
    + listItem({ lead: icon('celebration', { size: 23, color: C.amber }), title: '200 sessions together', sub: '146 done · 5 days left', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'M06', v: 'amber' })
    + post('Habiba Nasr', 'Beginners group', 'First week done. My knees did not hurt once.', { tone: 'sand', likes: '96', comments: '18', mh: 212 })
  , { pad: '0 16px 0', gap: 11 })
  + navBar('Community'));

const M06 = phone(
  statusBar()
  + appBar({ title: '', leadGo: 'M05' })
  + body(
    col(`${m('Beginners group')}${h('200 sessions in two weeks', 'headline')}`, { gap: 4 })
    + card(
      row(`${col(`<div style="font-size:38px;line-height:44px;font-weight:600;color:${C.onSurface}">146</div>${m('together so far')}`, { gap: 2, grow: true })}${m('5 days left')}`)
      + linear(73, { h: 12 })
      + t('31 of 48 women have finished their part.', { k: 'bodyM', color: C.onSurfaceVariant }), { gap: 10 })
    + card(row(`${strong('Your part')}${m('3 of 4 sessions')}`) + segs(4, 3) + t('One more and you have finished, whatever anyone else does.', { k: 'bodyM', color: C.onSurfaceVariant }), { gap: 10, v: 'sage' })
    + sageNote('Your sessions count here as you save them. There is nothing extra to log. Nobody sees your weights, only that a session happened.')
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn("Start today's session", { h: 56, ic: 'play_arrow', go: 'R03' })));

// ---------------- profile ----------------
const M07 = phone(
  statusBar()
  + appBar({ title: 'Habiba Nasr', leadGo: 'M01', actions: [{ icon: 'more_vert', go: 'M08' }] })
  + body(
    row(`${avatar(72, { initial: 'H' })}${row(`${statCol('34', 'posts')}${statCol('612', 'followers', { go: 'M15' })}${statCol('208', 'following', { go: 'M15' })}`, { gap: 0, justify: 'space-between' })}`, { gap: 14, justify: 'flex-start' })
    + col(`${row(`${strong('Habiba Nasr', 'titleM')}${icon('verified', { size: 17, color: C.primaryDim, fill: true })}`, { gap: 5, justify: 'flex-start' })}${m('Verified woman · joined March · Showing up')}${t('Training in a small flat, quietly. Beginners group.', { k: 'bodyM' })}`, { gap: 3 })
    + row(`${followBtn('follow', { h: 38, grow: true })}${btn('Message', { v: 'outlined', h: 38, size: 14 })}${iconBtn('person', { d: 38, bg: C.surfaceContainer })}`, { gap: 8 })
    + m('She chooses what shows here. Logs, weight and photos are never on a profile.')
  , { pad: '0 16px 10px', gap: 11 })
  + iconTabs([{ icon: 'photo_library' }, { icon: 'videocam', go: 'M09' }, { icon: 'history', go: 'M12' }], 0)
  + photoGrid([
    shot('', { h: 118, r: 0, tone: 'sand', blurFace: true, go: 'M02' }), shot('', { h: 118, r: 0, tone: 'sage', go: 'M02' }), shot('', { h: 118, r: 0, tone: 'rose', blurFace: true, go: 'M02' }),
    shot('', { h: 118, r: 0, tone: 'mint', go: 'M02' }), shot('', { h: 118, r: 0, tone: 'dusk', blurFace: true, go: 'M02' }), shot('', { h: 118, r: 0, tone: 'warm', go: 'M02' }),
  ])
  + navBar('Community'));

// ---------------- safety ----------------
const M08 = phone(
  statusBar()
  + appBar({ title: 'Post', leadGo: 'M02' })
  + body(postHead('Nada Samir', 'Postpartum rebuild') + shot('', { h: 180, r: 0, tone: 'sage', blurFace: true }), { pad: '0', gap: 9 })
  + navBar('Community')
  + sheet(
    h('What would you like to do?', 'titleL')
    + listItem({ lead: icon('flag', { size: 23, color: C.error }), title: 'Report this post', sub: 'A woman moderator reads it, usually within an hour', go: 'M01' })
    + listItem({ lead: icon('block', { size: 23, color: C.onSurface }), title: 'Block Nada', sub: 'She disappears from your feed and cannot message you', go: 'M01' })
    + listItem({ lead: icon('do_not_disturb_on', { size: 23, color: C.onSurface }), title: 'Mute this group for a week', sub: 'Still a member, just quiet', go: 'M01' })
    + btn('Cancel', { v: 'text', h: 46, size: 15, go: 'M02' }), { gap: 9 }),
  { layered: true });

// ---------------- reels ----------------
const M09 = phone(
  fullMedia({ tone: 'dusk' })
  + `<div style="position:absolute;left:0;right:0;top:0;padding:8px 16px 0">${statusBar('9:41', { color: '#FFFFFF' })}`
  + `<div style="display:flex;align-items:center;justify-content:space-between;margin-top:2px"><div style="font-size:19px;font-weight:600;color:#FFFFFF">Reels</div>${icon('photo_camera', { size: 24, color: '#FFFFFF' })}</div></div>`
  + `<div style="position:absolute;right:10px;bottom:118px;display:flex;flex-direction:column;align-items:center;gap:19px">`
  + railBtn('favorite', '2,140', { fill: true })
  + railBtn('comment', '86', { go: 'M02' })
  + railBtn('send', 'Share')
  + railBtn('bookmark', 'Save', { go: 'M15' })
  + iconBtn('more_vert', { d: 30, color: '#FFFFFF', go: 'M08' })
  + `</div>`
  + `<div style="position:absolute;left:0;right:74px;bottom:104px;padding:0 16px;display:flex;flex-direction:column;gap:9px">`
  + `<div style="display:flex;align-items:center;gap:9px">${avatar(34, { initial: 'S', bg: 'rgba(255,255,255,.22)', color: '#FFFFFF' })}<div style="font-size:15px;font-weight:600;color:#FFFFFF">Coach Sara Hany</div>${followBtn('follow', { h: 30 })}</div>`
  + `<div style="font-size:14px;line-height:20px;color:#FFFFFF">Three floor moves for a flat with thin walls. No jumping, nothing to carry.</div>`
  + `<div style="display:flex;align-items:center;gap:7px">${icon('mic', { size: 15, color: '#FFFFFF' })}<div style="font-size:13px;color:rgba(255,255,255,.9)">Her voice · 0:34</div></div>`
  + `</div>`
  + `<div style="position:absolute;left:0;right:0;bottom:0">${navBar('Community')}</div>`,
  { bg: C.inverseSurface, layered: true });

// ---------------- explore ----------------
const M10 = phone(
  statusBar()
  + appBar({ title: '', leadGo: 'M01' })
  + body(
    field({ value: 'Search women, groups and moves', trail: icon('search', { size: 21, color: C.onSurfaceVariant }) })
    + chipRow([{ label: 'For you', sel: true }, { label: 'Postpartum' }, { label: 'Quiet' }, { label: 'Ramadan' }], -1, { grow: false })
    + photoGrid([
      shot('', { h: 116, r: R.xs, tone: 'sage', go: 'M02' }), shot('', { h: 116, r: R.xs, tone: 'sand', blurFace: true, go: 'M02' }), shot('', { h: 116, r: R.xs, tone: 'rose', dur: '0:22', play: true, go: 'M09' }),
      shot('', { h: 116, r: R.xs, tone: 'mint', go: 'M02' }), shot('', { h: 116, r: R.xs, tone: 'dusk', dur: '0:41', play: true, go: 'M09' }), shot('', { h: 116, r: R.xs, tone: 'warm', blurFace: true, go: 'M02' }),
      shot('', { h: 116, r: R.xs, tone: 'sand', go: 'M02' }), shot('', { h: 116, r: R.xs, tone: 'sage', blurFace: true, go: 'M02' }), shot('', { h: 116, r: R.xs, tone: 'rose', go: 'M02' }),
    ], { cols: 3, gap: 4 })
  , { pad: '0 16px 0', gap: 11 })
  + navBar('Community'));

// ---------------- the follow-up picture ----------------
const M11 = phone(
  statusBar()
  + appBar({ title: 'Add a follow-up', lead: 'close', leadGo: 'M03' })
  + body(
    m('Pick the post you are following up on. The new picture joins it instead of starting again.')
    + card(row(`${shot('', { h: 56, w: '56px', r: R.sm, tone: 'sand', blurFace: true })}${col(`${strong('First week done. My knees did not hurt once.', 'titleS')}${m('Posted 8 weeks ago · 96 likes')}`, { gap: 3, grow: true })}${icon('check_circle', { size: 23, color: C.primary, fill: true })}`, { gap: 11 }), { v: 'selected', pad: '10px 12px' })
    + row(`${col(`${m('Then · 21 July')}${shot('', { h: 128, r: R.md, tone: 'sand', blurFace: true, grow: true })}`, { gap: 5, grow: true })}${col(`${m('Now · 16 September')}${shot('', { h: 128, r: R.md, tone: 'sage', blurFace: true, grow: true })}`, { gap: 5, grow: true })}`, { gap: 9, align: 'flex-end' })
    + field({ label: 'Say what changed', value: 'Eight weeks. Same flat, same 15 minutes.' })
    + card(row(`${icon('blur_on', { size: 22, color: C.primaryDim })}${col(`${strong('Faces blurred in both', 'titleM')}${m('On by default, on the old one too.')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 11 }), { v: 'tonal', pad: '10px 12px' })
    + card(row(`${icon('trophy', { size: 22, color: C.amber })}${col(`${strong('Add what it cost you', 'titleM')}${m('24 sessions · 8 counted weeks')}`, { gap: 2, grow: true })}${toggle(true)}`, { gap: 11 }), { v: 'amber', pad: '10px 12px' })
  , { pad: '0 16px 0', gap: 11 })
  + footer(btn('Post the follow-up', { h: 56, go: 'M12' })));

const M12 = phone(
  statusBar()
  + appBar({ title: 'Eight weeks', leadGo: 'M01', actions: [{ icon: 'more_vert', go: 'M08' }] })
  + body(
    postHead('Habiba Nasr', 'Beginners group · just now')
    + `<div style="padding:0 14px">${followUpStrip([
      { tone: 'sand', blur: true, label: 'Week 1' },
      { tone: 'rose', blur: true, label: 'Week 4' },
      { tone: 'sage', blur: true, label: 'Now', now: true },
    ], { h: 128 })}</div>`
    + actionBar('318', '41', { saved: true })
    + caption('Habiba Nasr', 'Eight weeks. Same flat, same 15 minutes.', { comments: 'See all 41 comments' })
    + `<div style="padding:0 14px">${card(row(`${icon('trophy', { size: 22, color: C.amber })}${col(`${strong('What it cost her', 'titleM')}${m('24 sessions · 8 counted weeks · no weight shown')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { v: 'amber', pad: '10px 12px' })}</div>`
    + `<div style="padding:0 14px">${sageNote('A follow-up stays on the first post, so a thread is one woman over time, never two women side by side.')}</div>`
  , { pad: '0', gap: 10 })
  + navBar('Community'));

// ---------------- stories ----------------
const M13 = phone(
  fullMedia({ tone: 'rose', top: '.5' })
  + `<div style="position:absolute;left:0;right:0;top:0;padding:6px 12px 0">${statusBar('9:41', { color: '#FFFFFF' })}`
  + `<div style="padding:0 2px">${storyBars(4, 1)}</div>`
  + `<div style="display:flex;align-items:center;gap:9px;margin-top:11px;padding:0 2px">${avatar(34, { initial: 'N', bg: 'rgba(255,255,255,.22)', color: '#FFFFFF' })}`
  + `<div style="flex:1;min-width:0"><div style="font-size:15px;font-weight:600;color:#FFFFFF">Nada Samir</div><div style="font-size:12px;color:rgba(255,255,255,.82)">3 hours ago</div></div>`
  + `${iconBtn('more_vert', { d: 34, color: '#FFFFFF', go: 'M08' })}${iconBtn('close', { d: 34, color: '#FFFFFF', go: 'M01' })}</div></div>`
  + `<div style="position:absolute;left:16px;right:16px;bottom:150px">${card(row(`${icon('directions_walk', { size: 22, color: C.tertiary })}${col(`${strong('Walk before the school run', 'titleM')}${m('32 minutes · counted by her phone')}`, { gap: 2, grow: true })}`, { gap: 10, justify: 'flex-start' }), { pad: '11px 13px' })}</div>`
  + `<div style="position:absolute;left:0;right:0;bottom:92px;padding:0 16px;display:flex;align-items:center;gap:10px">`
  + `<div style="flex:1;height:46px;border-radius:999px;border:1.5px solid rgba(255,255,255,.55);display:flex;align-items:center;padding:0 16px;font-size:15px;color:rgba(255,255,255,.9)">Send her something kind</div>`
  + `${icon('favorite', { size: 26, color: '#FFFFFF' })}${icon('send', { size: 26, color: '#FFFFFF' })}</div>`
  + `<div style="position:absolute;left:0;right:0;bottom:0">${K.homeBar({ color: '#FFFFFF' })}</div>`,
  { bg: C.inverseSurface, layered: true });

// ---------------- activity ----------------
const M14 = phone(
  statusBar()
  + appBar({ title: 'Activity', leadGo: 'M01' })
  + body(
    card(row(`${icon('history', { size: 23, color: C.primaryDim })}${col(`${strong('Eight weeks since your first post', 'titleM')}${m('Add a follow-up picture to it')}`, { gap: 2, grow: true })}${btn('Add', { v: 'tonal', h: 36, size: 14, go: 'M11' })}`, { gap: 11 }), { v: 'tonal', pad: '11px 13px' })
    + sectionHead('This week')
    + listItem({ lead: avatar(40, { initial: 'H' }), title: 'Habiba and 12 others liked your best', sub: 'Yesterday', trail: shot('', { h: 40, w: '40px', r: R.xs, tone: 'sand' }), go: 'M02', pad: '8px 12px' })
    + listItem({ lead: avatar(40, { initial: 'Y' }), title: 'Yasmin started following you', sub: '2 days ago', trail: followBtn('back', { h: 32 }), pad: '8px 12px' })
    + listItem({ lead: avatar(40, { initial: 'N' }), title: 'Nada commented: “This is the exact thing I needed.”', sub: '2 days ago', trail: shot('', { h: 40, w: '40px', r: R.xs, tone: 'sage' }), go: 'M02', pad: '8px 12px' })
    + listItem({ lead: avatar(40, { ic: 'groups' }), title: 'Beginners group reached 146 sessions', sub: '3 days ago · 5 days left', go: 'M06', pad: '8px 12px' })
    + sageNote('Nothing here is a number going up. Every line is a woman who did something, or a thing you can act on.')
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Community'));

// ---------------- saved ----------------
const M15 = phone(
  statusBar()
  + appBar({ title: 'Saved', leadGo: 'M07' })
  + body(
    chipRow([{ label: 'All', sel: true }, { label: 'Quiet moves' }, { label: 'Meals' }], -1, { grow: false })
    + photoGrid([
      shot('', { h: 112, r: R.xs, tone: 'mint', go: 'M02' }), shot('', { h: 112, r: R.xs, tone: 'rose', dur: '0:22', play: true, go: 'M09' }), shot('', { h: 112, r: R.xs, tone: 'sand', go: 'M02' }),
      shot('', { h: 112, r: R.xs, tone: 'sage', go: 'M02' }), shot('', { h: 112, r: R.xs, tone: 'warm', blurFace: true, go: 'M02' }), shot('', { h: 112, r: R.xs, tone: 'dusk', dur: '0:41', play: true, go: 'M09' }),
    ], { cols: 3, gap: 4 })
    + m('Only you can see what you saved.')
  , { pad: '0 16px 0', gap: 11 })
  + navBar('Community'));

// ---------------- record ----------------
const M16 = phone(
  fullMedia({ tone: 'night', top: '.3', bottom: '.5' })
  + `<div style="position:absolute;left:0;right:0;top:0;padding:6px 10px 0">${statusBar('9:41', { color: '#FFFFFF' })}`
  + `<div style="display:flex;align-items:center;justify-content:space-between">${iconBtn('close', { d: 40, color: '#FFFFFF', go: 'M03' })}<div style="font-size:15px;font-weight:600;color:#FFFFFF">0:12 / 1:00</div>${iconBtn('autorenew', { d: 40, color: '#FFFFFF' })}</div></div>`
  + `<div style="position:absolute;right:12px;top:130px;display:flex;flex-direction:column;gap:17px;align-items:center">`
  + railBtn('timer', '15s') + railBtn('bolt', 'Light') + railBtn('blur_on', 'Blur', { fill: true }) + railBtn('mic', 'Voice')
  + `</div>`
  + `<div style="position:absolute;left:0;right:0;bottom:118px;padding:0 16px">${chipRow([{ label: 'Reel', sel: true }, { label: 'Story' }, { label: 'Post' }], -1, { grow: true })}</div>`
  + `<div style="position:absolute;left:0;right:0;bottom:34px;padding:0 24px;display:flex;align-items:center;justify-content:space-between">`
  + `<div style="width:46px;height:46px;border-radius:12px;overflow:hidden">${shot('', { h: 46, w: '46px', r: 12, tone: 'sage', go: 'M11' })}</div>`
  + `<div style="width:74px;height:74px;border-radius:999px;border:4px solid rgba(255,255,255,.9);display:flex;align-items:center;justify-content:center"${K.go('M09')}><div style="width:58px;height:58px;border-radius:999px;background:${C.primary}"></div></div>`
  + `<div style="width:46px;height:46px;display:flex;align-items:center;justify-content:center">${icon('check_circle', { size: 38, color: '#FFFFFF', fill: true })}</div></div>`,
  { bg: C.inverseSurface, layered: true });

export const screens = [
  { id: 'M01', html: M01, metric: 'a feed, and every face checked', note: 'The feed now reads the way Instagram taught every woman in Egypt to read a feed: a stories rail, full-bleed pictures, likes, comments, share and save. What is different sits underneath — every ring belongs to an ID-verified woman, and faces arrive blurred unless she turned that off herself.' },
  { id: 'M02', html: M02, metric: 'comments, kindly', note: 'Coaches are labelled inside comments so advice is attributable. The composer offers a voice note first: it is the gesture she is most fluent in, and it is harder to be cruel out loud.' },
  { id: 'M03', html: M03, metric: '4 ways in, 1 of them new', note: 'Creating is camera-first, with Reel and Follow-up given the two big tiles. The personal-best card is still offered as the way to share a win without a body photo, and the blur switch is visible before anything is chosen.' },
  { id: 'M04', html: M04, metric: 'few groups, real ones', note: 'Groups are built around situations rather than interests: beginners, postpartum, Ramadan, city. Suggested groups say why they were suggested and how big they are.' },
  { id: 'M05', html: M05, metric: 'the group goal sits on top', note: 'A group is a feed plus one shared goal. The challenge card is first because a shared total is what makes a group feel like a room rather than a noticeboard.' },
  { id: 'M06', html: M06, metric: '0 extra logging', note: 'Challenges are shared totals, not leaderboards: everyone who does her part finishes, so there is no last place and no reason to compare a 3 kg dumbbell with a barbell.' },
  { id: 'M07', html: M07, metric: 'grid, tabs, follows', note: 'A profile is now a real social profile — posts, followers, following, a photo grid and tabs for reels and follow-ups. The restraint is in what is still missing: no logs, no weight, no photos she did not choose, and nothing that ranks one woman against another.' },
  { id: 'M08', html: M08, metric: '2 taps to safety', note: 'Report, block and mute sit in one sheet reachable from every post, profile and reel, with the response time stated. Mute exists because leaving a group should not be the only way to get quiet.' },
  { id: 'M09', html: M09, metric: 'full screen, vertical', note: 'The TikTok surface, built for a product where the clip is a woman coach showing three floor moves. The action rail is the familiar one; the audio line credits her own voice rather than a music library, which is both cheaper to licence and truer to the room.' },
  { id: 'M10', html: M10, metric: 'search and a grid', note: 'Explore is a mixed grid of photos and reels with the filters that actually narrow it here — postpartum, quiet, Ramadan. Reels are marked with a duration so a woman on mobile data knows what she is about to spend.' },
  { id: 'M11', html: M11, metric: 'the follow-up, composed', note: 'This is the new idea. Instead of posting a fresh before-and-after, she attaches a picture to a post she already made, so the pair is always her own two moments. Blur applies to both frames, and what it cost is offered as sessions and weeks — never a weight.' },
  { id: 'M12', html: M12, metric: '1 post, 3 moments', note: 'The thread that results: week 1, week 4, now, on one row with arrows. It gives the feed the transformation content it wants without ever putting two different women side by side, which is the comparison this product exists to avoid.' },
  { id: 'M13', html: M13, metric: '24 hours, then gone', note: 'Stories carry the small things a post is too heavy for — a walk before the school run. The reply bar sends privately, so encouragement does not have to be performed in front of a group.' },
  { id: 'M14', html: M14, metric: 'people, not counters', note: 'Activity is people who did something, plus one prompt: your first post is eight weeks old, add a follow-up. That prompt is the engine of the whole follow-up feature, and it is the only nudge on the screen.' },
  { id: 'M15', html: M15, metric: 'private by construction', note: 'Saved posts are collections only she can see, which is how women actually use saving on Instagram — as a private library, not a public signal.' },
  { id: 'M16', html: M16, metric: 'blur is a camera control', note: 'Recording puts blur on the rail beside the timer and the light, so it reads as an ordinary camera control rather than a privacy setting buried elsewhere. Mode switches at the bottom, the way every camera she already uses works.' },
];
