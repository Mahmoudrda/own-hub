import * as K from './kit.mjs';
const { C, R, F, phone, statusBar, body, footer, card, row, col, grid, h, t, m, strong, pill, btn, iconBtn, icon, chip, chipRow, segs, linear, ringStat, navBar, sheet, snackbar, banner, sageNote, listItem, homeBar, appBar, media, avatar, spacer, field, logBtn, rtl } = K;

const slot = (name, value, state) => `<div style="flex:1;border-radius:${R.md}px;padding:10px;display:flex;flex-direction:column;gap:4px;background:${state === 'done' ? C.tertiaryContainer : state === 'now' ? C.surfaceLowest : C.surfaceLow};border:${state === 'now' ? `1.5px solid ${C.primary}` : '1px solid ' + C.outlineVariant}">`
  + `<div style="display:flex;align-items:center;gap:4px;font-size:13px;font-weight:600;color:${state === 'done' ? C.tertiary : state === 'now' ? C.primaryDim : C.onSurfaceVariant}">${state === 'done' ? icon('check', { size: 14, color: C.tertiary }) : ''}${name}</div>`
  + `<div style="font-size:14px;line-height:19px;color:${C.onSurface}">${value}</div></div>`;

const mealRow = (title, meta, primary = false, goId = 'E04') => listItem({ title, sub: meta, trail: logBtn(primary, 'Log', { go: goId }), v: primary ? 'selected' : 'outlined' });

const boxRow = (text = 'Say or type what you ate') => card(row(`${icon('mic', { size: 22, color: C.primaryDim })}<div style="flex:1;font-size:16px;color:${C.onSurfaceVariant}">${text}</div>${icon('keyboard', { size: 22, color: C.onSurfaceVariant })}`, { gap: 10, justify: 'flex-start' }), { pad: '14px 16px', r: R.full, go: 'E02' });

const parsed = (name, meta, sizes, sel) => card(
  row(`${col(`${strong(name, 'titleM')}${m(meta)}`, { gap: 3, grow: true })}${iconBtn('remove', { d: 40, bg: C.surfaceLow, color: C.error })}`)
  + chipRow(sizes, sel), { gap: 10, pad: '12px 14px' });

const E01 = phone(
  statusBar('1:12')
  + body(
    row(`${h('Eat', 'titleL')}${pill('Ramadan mode off', { bg: C.surfaceContainer, color: C.onSurfaceVariant })}`)
    + card(
      `<div style="display:flex;gap:8px">${slot('Breakfast', 'Ful and baladi', 'done')}${slot('Lunch', 'Now', 'now')}${slot('Dinner', 'Later', 'later')}</div>`
      + col(`${row(`${strong('Protein', 'titleS')}${m('22 of 95 g')}`)}${linear(23, { h: 10 })}`, { gap: 6 })
      + m('About 410 kcal so far today'), { gap: 12 })
    + row(`${strong('Lunch, from your plan')}${pill('From Sara', { ic: 'sports' })}`)
    + mealRow('Koshari bowl, medium', 'Planned by Sara · 1 serving · 540 kcal', true, 'G10')
    + mealRow('Molokhia with chicken', '460 kcal · 34 g protein')
    + mealRow("Yesterday's lunch again", "Ta'ameya, salad, baladi · 520 kcal")
    + listItem({ lead: icon('menu_book', { size: 23, color: C.primaryDim }), title: 'Recipes', sub: 'Egyptian dishes with portions and cost per serving', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E05' })
    + boxRow()
  , { pad: '4px 16px 0', gap: 8 })
  + navBar('Eat'));

const E02 = phone(
  statusBar('1:14')
  + appBar({ title: '', lead: 'close', leadGo: 'E01' })
  + body(
    field({ value: 'koshari and 2 eggs', focus: true, trail: `<div data-go="E03" style="cursor:pointer">${icon('mic', { size: 22, color: C.primaryDim })}</div>` })
    + `<div style="font-size:15px;font-weight:600;color:${C.tertiary}">We'll log</div>`
    + parsed('Koshari bowl', '540 kcal · 18 g protein', ['Small', 'Medium', 'Large'], 1)
    + parsed('Boiled eggs', '156 kcal · 13 g protein', ['1', '2', '3'], 1)
    + `<div style="font-size:15px;font-weight:600;color:${C.onSurfaceVariant}">Or one you've had before</div>`
    + mealRow('Koshari bowl and salad', 'Your plate · 600 kcal')
    + btn('All foods, 4,100 in the list', { v: 'text', h: 40, size: 15 })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Log both · 696 kcal', { h: 56, go: 'E04' })));

const E03 = phone(
  statusBar('9:26')
  + appBar({ title: '', lead: 'close', leadGo: 'E01' })
  + body(
    h('We heard this', 'headline')
    + `<div style="display:flex;align-items:center;gap:3px;height:40px">${[14, 26, 38, 20, 34, 44, 22, 30, 16, 24].map((hh, i) => `<div style="flex:1;height:${hh}px;border-radius:999px;background:${i < 7 ? C.primary : C.outlineVariant}"></div>`).join('')}</div>`
    + card(rtl('تناولتُ طبق كشري متوسط وبيضتين'), { v: 'filled', pad: '14px 16px' })
    + `<div style="font-size:15px;font-weight:600;color:${C.tertiary}">So we're logging</div>`
    + parsed('Koshari bowl, medium', '540 kcal · 18 g protein', ['Small', 'Medium', 'Large'], 1)
    + parsed('Two boiled eggs', '156 kcal · 13 g protein', ['1', '2', '3'], 1)
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn("That's right · log 696 kcal", { h: 56, go: 'E04' }) + btn('Say it again', { v: 'text', h: 44, size: 15, ic: 'mic' })));

const E04 = phone(
  statusBar('1:15')
  + body(
    row(`${h('Eat', 'titleL')}${pill('+5 points', { bg: C.tertiaryContainer, color: C.tertiary, ic: 'add' })}`)
    + card(
      `<div style="display:flex;gap:8px">${slot('Breakfast', 'Ful and baladi', 'done')}${slot('Lunch', 'Koshari, 2 eggs', 'done')}${slot('Dinner', 'Later', 'later')}</div>`
      + col(`${row(`${strong('Protein', 'titleS')}${row(`${m('53 of 95 g')}<div style="font-size:14px;font-weight:600;color:${C.tertiary}">+31 g</div>`, { gap: 6, justify: 'flex-end' })}`)}${linear(56, { h: 10 })}`, { gap: 6 })
      + m('About 1,106 kcal so far today'), { gap: 12 })
    + row(`${strong('Dinner, your usual')}${m('Tuesdays')}`)
    + mealRow('Lentil soup and eggs', '380 kcal · 26 g protein')
    + mealRow('Chicken and rice', '520 kcal · 38 g protein')
    + listItem({ lead: icon('menu_book', { size: 23, color: C.primaryDim }), title: 'Recipes', sub: 'Egyptian dishes with portions and cost per serving', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E05' })
    + boxRow()
    + snackbar('Lunch logged · 696 kcal', { action: 'Undo', go: 'E01' })
  , { pad: '4px 16px 0', gap: 10 })
  + navBar('Eat'));

const E05 = phone(
  statusBar()
  + appBar({ title: 'Recipes', leadGo: 'E01', actions: [{ icon: 'search' }] })
  + body(
    chipRow([{ label: 'High protein', sel: true }, { label: 'Under 20 min' }, { label: 'Cheap' }, { label: 'Ramadan' }], -1, { grow: false })
    + listItem({ lead: media({ label: '', h: 64, r: R.sm, ic: '' }).replace('height:64px', 'height:64px;width:64px'), title: 'Koshari, portioned', sub: '22 min · 540 kcal · 18 g protein · 14 EGP', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E06' })
    + listItem({ lead: media({ label: '', h: 64, r: R.sm, ic: '' }).replace('height:64px', 'height:64px;width:64px'), title: 'Ful with egg and cumin', sub: '10 min · 310 kcal · 19 g protein · 8 EGP', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E06' })
    + listItem({ lead: media({ label: '', h: 64, r: R.sm, ic: '' }).replace('height:64px', 'height:64px;width:64px'), title: 'Molokhia with chicken', sub: '45 min · 460 kcal · 34 g protein · 26 EGP', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E06' })
    + listItem({ lead: media({ label: '', h: 64, r: R.sm, ic: '' }).replace('height:64px', 'height:64px;width:64px'), title: 'Yoghurt, dates and nuts', sub: '3 min · 280 kcal · 14 g protein · 12 EGP', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E06' })
    + listItem({ lead: icon('shopping_cart', { size: 24, color: C.primaryDim }), title: 'This week\'s plan and list', sub: '5 dinners · one shop', trail: icon('chevron_right', { size: 22, color: C.onSurfaceVariant }), go: 'E07' })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Eat'));

const E06 = phone(
  statusBar()
  + appBar({ title: '', leadGo: 'E05', actions: [{ icon: 'bookmark' }, { icon: 'share' }] })
  + body(
    media({ label: 'food photo', h: 160, ic: '' })
    + col(`${h('Koshari, portioned', 'headline')}${m('22 min · 4 servings · 14 EGP a serving')}`, { gap: 4 })
    + row(`${chip('540 kcal')}${chip('18 g protein')}${chip('Vegetarian')}`, { gap: 8, justify: 'flex-start' })
    + card(row(`${col(`${strong('Your portion', 'titleM')}${m('Medium bowl, the one you usually serve')}`, { gap: 3, grow: true })}${chipRow(['S', 'M', 'L'], 1, { grow: false })}`), { v: 'filled', pad: '12px 14px' })
    + t('Rice, lentils and pasta cooked together, with the fried onions on top and the sauce on the side so you decide how much goes on.', { k: 'bodyM', color: C.onSurfaceVariant })
  , { pad: '0 16px 0', gap: 12 })
  + footer(btn('Cooked it, log my bowl', { h: 56, ic: 'check', go: 'E04' }) + btn('See the steps', { v: 'outlined', h: 48, size: 15 })));

const E07 = phone(
  statusBar()
  + appBar({ title: 'This week', leadGo: 'E05', actions: [{ icon: 'autorenew' }] })
  + body(
    m('Five dinners, built from recipes you have logged before. Swap any of them.')
    + ['Monday · Molokhia with chicken', 'Tuesday · Koshari, portioned', 'Wednesday · Lentil soup and eggs', 'Thursday · Grilled chicken and salad', 'Friday · Ful with egg'].map((x, i) => listItem({ title: x.split(' · ')[1], sub: x.split(' · ')[0], trail: icon('swap_horiz', { size: 22, color: C.primaryDim }), go: 'E06' })).join('')
    + card(row(`${icon('shopping_cart', { size: 24, color: C.primaryDim })}${col(`${strong('One shop covers it', 'titleM')}${m('23 items · about 640 EGP')}`, { gap: 3, grow: true })}`, { gap: 12, justify: 'flex-start' }), { v: 'tonal', go: 'E08' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('See the grocery list', { h: 56, go: 'E08' })));

const E08 = phone(
  statusBar()
  + appBar({ title: 'Grocery list', leadGo: 'E07', actions: [{ icon: 'share' }] })
  + body(
    m('Grouped the way you shop. Tick as you go. It remembers.')
    + col([['Vegetables', ['Tomatoes 1 kg', 'Onions 1 kg', 'Molokhia, frozen 400 g']], ['Protein', ['Chicken 1 kg', 'Eggs 20', 'Lentils 500 g']], ['Cupboard', ['Rice 1 kg', 'Pasta 500 g', 'Cumin']]]
      .map(([g, items]) => card(`<div style="font-size:15px;font-weight:600;color:${C.primaryDim}">${g}</div>` + items.map((it, i) => row(`${i === 0 ? icon('check_circle', { size: 22, color: C.tertiary, fill: true }) : `<div style="width:22px;height:22px;border-radius:999px;border:2px solid ${C.outlineVariant};box-sizing:border-box"></div>`}<div style="flex:1;font-size:16px;color:${i === 0 ? C.onSurfaceVariant : C.onSurface};${i === 0 ? 'text-decoration:line-through' : ''}">${it}</div>`, { gap: 10, justify: 'flex-start' })).join(''), { gap: 10, pad: '12px 14px' })).join(''), { gap: 10 })
  , { pad: '0 16px 0', gap: 10 })
  + navBar('Eat'));

export const screens = [
  { id: 'E01', html: E01, metric: '1 tap to log · 0 to see today', note: 'The hub leads with what is already done and what she usually eats at this hour on this day, ranked by how often, with the count shown so the guess can be checked. Plates she eats together became one row by themselves. Calories are a calm running total, never a countdown going red.' },
  { id: 'E02', html: E02, metric: '1 line, 1 tap', note: 'Search and describing a meal are the same box. Three letters bring her own history first; a whole sentence in English, Arabic or Franco becomes items with the size already picked from what she usually has. Sizes are chips on the row, so she never opens a food to fix one.' },
  { id: 'E03', html: E03, metric: '1 tap, 1 sentence, 1 confirm', note: 'A voice note is one of her three fluent gestures. The interface is Modern Standard Arabic, but speech recognition has to accept how she actually talks — Egyptian dialect, not dictation grammar. The transcript is shown so a misheard word is obvious, and every item can be resized or removed before anything is saved.' },
  { id: 'E04', html: E04, metric: '0 extra taps', note: 'The reward for a meal is small and immediate: the slot fills, protein moves by what she just ate, the next slot slides up, and five points land once a day for logging anything — never per item, so there is no reason to split a plate.' },
  { id: 'E05', html: E05, metric: 'filters she thinks in', note: 'Recipes are filtered by protein, time and cost, and every card carries the price per serving in EGP. Food that costs more than her week allows is not a recipe, it is an advert.' },
  { id: 'E06', html: E06, metric: '1 tap to log a portion', note: 'The recipe page ends where logging starts: cooked it, log my bowl, in her usual size. Portions are the objects she serves — a bowl in three sizes — not grams.' },
  { id: 'E07', html: E07, metric: 'swap, do not rebuild', note: 'The week plan is made of recipes she has already logged, so it is recognisable rather than aspirational, and every row swaps in one tap.' },
  { id: 'E08', html: E08, metric: 'one shop', note: 'The list is grouped the way an Egyptian market trip actually goes, with a running total in EGP, and it survives being closed mid-shop.' },
];
