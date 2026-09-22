// Z01–Z11 — the admin content console. DECISIONS.md D12, plan G16.
//
// Staff only, and outside the 161 member-facing screens. It exists because the
// content library is EMPTY: `foods.allergens[]` and
// `exercises.contraindicationTags[]` are "mandatory, not enrichment"
// (SCHEMA-SPINE §1) and unauthored, which is exactly why P0-EAT-01 cannot pass
// and the exercise safety filter has nothing to filter on. This console is how
// that content arrives.
//
// `navBar()` hardcodes the client and coach tab sets, so the admin bar is local
// to this file — the same position screens-cycle.mjs takes with its own
// `toggleRow`. Type styles are inlined because `ty()` is not exported.
import * as K from './kit.mjs';
const {
  C, R, phone, statusBar, body, footer, card, row, col, t, m, strong, pill,
  btn, icon, iconBtn, chip, chipRow, listItem, appBar, field, sageNote, banner,
  table, sectionHead, spacer, go, homeBar, segmented,
} = K;

const ADMIN_TABS = [
  { label: 'Library', icon: 'inventory_2', go: 'Z01' },
  { label: 'Import', icon: 'upload_file', go: 'Z08' },
  { label: 'Media', icon: 'perm_media', go: 'Z10' },
  { label: 'Export', icon: 'download', go: 'Z11' },
];

const adminNav = (active) =>
  `<div style="flex:0 0 auto;background:${C.surfaceLow};border-top:1px solid ${C.outlineVariant};padding:8px 4px 0;display:grid;grid-template-columns:repeat(${ADMIN_TABS.length},1fr)">`
  + ADMIN_TABS.map(tb => {
    const on = tb.label === active;
    return `<div style="height:60px;display:flex;flex-direction:column;align-items:center;gap:4px"${go(on ? '' : tb.go)}>`
      + `<div style="width:56px;height:32px;border-radius:999px;display:flex;align-items:center;justify-content:center;background:${on ? C.primaryContainer : 'transparent'}">${icon(tb.icon, { size: 24, color: on ? C.onPrimaryContainer : C.onSurfaceVariant, fill: on })}</div>`
      + `<div style="font-size:12px;line-height:16px;font-weight:600;color:${on ? C.onPrimaryContainer : C.onSurfaceVariant}">${tb.label}</div></div>`;
  }).join('')
  + `</div>${homeBar({ bg: C.surfaceLow })}`;

/// A collection row on Z01. The count is secondary; what leads is how many rows
/// are MISSING a mandatory safety tag, because an incomplete library is the
/// failure that matters and a total hides it.
const collectionRow = (ic, title, count, missing, goId) => listItem({
  lead: icon(ic, { size: 24, color: C.primaryDim }),
  title,
  sub: missing > 0
    ? `${count} rows · ${missing} missing a safety tag`
    : `${count} rows · all tagged`,
  trail: missing > 0
    ? pill(String(missing), { bg: C.errorContainer, fg: C.onErrorContainer })
    : icon('check_circle', { size: 22, color: C.tertiary, fill: true }),
  go: goId,
  pad: '10px 14px',
});

const Z01 = phone(
  statusBar()
  + appBar({ title: 'Content library', lead: '', actions: [{ icon: 'help_outline', go: 'Z08' }] })
  + body(
    banner('Nothing here is a member’s data. This console manages the library only.', { v: 'sage', ic: 'lock' })
    + sectionHead('Collections')
    + collectionRow('fitness_center', 'Exercises', 0, 0, 'Z02')
    + collectionRow('restaurant', 'Foods', 0, 0, 'Z04')
    + collectionRow('menu_book', 'Recipes', 0, 0, 'Z06')
    + collectionRow('calendar_month', 'Programmes', 0, 0, 'Z07')
    + sageNote('The library is empty. Until foods carry allergens and exercises carry contraindications, the safety filters have nothing to filter on — they are not decorative, they are off.')
    + btn('Import a CSV', { go: 'Z08', icon: 'upload_file' })
  , { pad: '0 16px 0', gap: 10 })
  + adminNav('Library'));

const Z02 = phone(
  statusBar()
  + appBar({ title: 'Exercises', leadGo: 'Z01', actions: [{ icon: 'add', go: 'Z03' }] })
  + body(
    field({ label: '', value: 'Search 0 exercises', trail: icon('search', { size: 22, color: C.onSurfaceVariant }) })
    + chipRow([{ label: 'All', sel: true }, { label: 'Missing contraindications' }, { label: 'No video' }])
    + card(col(`${strong('No exercises yet', 'titleM')}${m('Import exercises.csv, or add one at a time. Every row needs contraindication tags — write “none” when there are none.')}`, { gap: 6 }), { v: 'filled' })
    + btn('Import exercises.csv', { go: 'Z08', v: 'tonal' })
  , { pad: '0 16px 0', gap: 10 })
  + adminNav('Library'));

const Z03 = phone(
  statusBar()
  + appBar({ title: 'Edit an exercise', lead: 'close', leadGo: 'Z02' })
  + body(
    field({ label: 'Exercise id', value: 'goblet_squat', helper: 'Stable. Changing it orphans everything that referenced it.' })
    + field({ label: 'Name (English)', value: 'Goblet squat' })
    + field({ label: 'الاسم (العربية)', value: 'القرفصاء بالدمبل' })
    + field({ label: 'Equipment', value: 'dumbbell' })
    + field({ label: 'Contraindication tags', value: '', error: 'Required. Write “none” if there are none. Blank is not the same thing.' })
    + sageNote('A missing tag reads as “unknown, therefore unsafe” and the filter fails closed. That is why blank is refused rather than accepted quietly.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save', { go: 'Z02' })));

const Z04 = phone(
  statusBar()
  + appBar({ title: 'Foods', leadGo: 'Z01', actions: [{ icon: 'add', go: 'Z05' }] })
  + body(
    field({ label: '', value: 'Search 0 foods', trail: icon('search', { size: 22, color: C.onSurfaceVariant }) })
    + chipRow([{ label: 'All', sel: true }, { label: 'Missing allergens' }, { label: 'No macros' }])
    + card(col(`${strong('No foods yet', 'titleM')}${m('Import foods.csv. Every row needs an allergens value — “none” is valid and means it contains none.')}`, { gap: 6 }), { v: 'filled' })
    + btn('Import foods.csv', { go: 'Z08', v: 'tonal' })
  , { pad: '0 16px 0', gap: 10 })
  + adminNav('Library'));

const Z05 = phone(
  statusBar()
  + appBar({ title: 'Edit a food', lead: 'close', leadGo: 'Z04' })
  + body(
    field({ label: 'Food id', value: 'koshari' })
    + field({ label: 'Name (English)', value: 'Koshari' })
    + field({ label: 'الاسم (العربية)', value: 'كشري' })
    + row(`${field({ label: 'kcal', value: '430' })}${field({ label: 'Protein g', value: '13' })}`, { gap: 10 })
    + field({ label: 'Allergens', value: 'gluten', helper: 'Pipe-separated. “none” if it contains none.' })
    + field({ label: 'Diet tags', value: 'vegetarian|vegan' })
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save', { go: 'Z04' })));

const Z06 = phone(
  statusBar()
  + appBar({ title: 'Recipes', leadGo: 'Z01', actions: [{ icon: 'add', go: 'Z05' }] })
  + body(
    chipRow([{ label: 'All', sel: true }, { label: 'Missing allergens' }, { label: 'No photo' }])
    + card(col(`${strong('No recipes yet', 'titleM')}${m('Import recipes.csv. Allergens and diet tags are required, and every photo named must be in the media upload.')}`, { gap: 6 }), { v: 'filled' })
    + btn('Import recipes.csv', { go: 'Z08', v: 'tonal' })
  , { pad: '0 16px 0', gap: 10 })
  + adminNav('Library'));

const Z07 = phone(
  statusBar()
  + appBar({ title: 'Programmes', leadGo: 'Z01', actions: [{ icon: 'add', go: 'Z08' }] })
  + body(
    card(col(`${strong('No programmes yet', 'titleM')}${m('O05 offers a starting programme from this collection. With none authored, it has nothing to offer and selection cannot reflect her answers.')}`, { gap: 6 }), { v: 'filled' })
    + btn('Import programs.csv', { go: 'Z08', v: 'tonal' })
  , { pad: '0 16px 0', gap: 10 })
  + adminNav('Library'));

const Z08 = phone(
  statusBar()
  + appBar({ title: 'Bulk import', leadGo: 'Z01' })
  + body(
    segmented(['Exercises', 'Foods', 'Recipes', 'Programmes'], 1)
    + card(col(`${icon('upload_file', { size: 32, color: C.primaryDim })}${strong('Choose a CSV file', 'titleM')}${m('foods.csv · the template is in 6-v2/content/templates')}`, { gap: 8 }), { v: 'outlined', pad: '22px 16px' })
    + sectionHead('Columns it expects')
    + table(['Column', 'Required'], [
      ['foodId', 'yes'],
      ['name_en / name_ar', 'yes, both'],
      ['kcal, proteinG', 'yes'],
      ['allergens', 'yes — “none” allowed'],
      ['dietTags', 'yes'],
    ], { widths: ['1.6fr', '1fr'] })
    + sageNote('Unknown column headers are refused rather than ignored. A typo like “allergen” silently dropping the allergens column is exactly the failure this refuses to allow.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Check the file', { go: 'Z09' })));

const Z09 = phone(
  statusBar()
  + appBar({ title: 'Import check', leadGo: 'Z08' })
  + body(
    banner('Nothing has been written yet.', { v: 'sage', ic: 'info' })
    + row(`${col(`${strong('118', 'display')}${m('rows ready')}`, { gap: 2, grow: true })}${col(`${strong('4', 'display')}${m('rows with problems')}`, { gap: 2, grow: true })}`, { gap: 12 })
    + sectionHead('Rows with problems')
    + table(['Row', 'Problem'], [
      ['14', 'allergens is blank — write “none”'],
      ['31', 'name_ar missing'],
      ['52', 'photo koshari.jpg was not uploaded'],
      ['77', 'duplicate foodId “ful_medames”'],
    ], { widths: ['0.5fr', '2fr'] })
    + sageNote('Fix these rows and import again. Nothing is saved until every row passes — a half-imported library is worse than none, because the gaps are invisible and the guard reads a missing tag as unsafe.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Import everything', { go: 'Z01', v: 'filled' }) + btn('Back to the file', { go: 'Z08', v: 'text' })));

const Z10 = phone(
  statusBar()
  + appBar({ title: 'Media library', leadGo: 'Z01', actions: [{ icon: 'add_photo_alternate', go: 'Z10' }] })
  + body(
    segmented(['All', 'Unlinked', 'Videos', 'Photos'], 1)
    + card(col(`${strong('Upload videos and pictures', 'titleM')}${m('Dropped here, then linked by filename to the rows your CSV named. Members read them signed-in — nothing under content/ is public.')}`, { gap: 6 }), { v: 'filled' })
    + sectionHead('Not linked to anything yet', '4 files')
    + table(['File', 'Size'], [
      ['goblet_squat.mp4', '12 MB'],
      ['glute_bridge.mp4', '9 MB'],
      ['koshari.jpg', '240 KB'],
      ['lentil_soup.jpg', '190 KB'],
    ], { widths: ['2fr', '0.8fr'] })
  , { pad: '0 16px 0', gap: 10 })
  + adminNav('Media'));

const Z11 = phone(
  statusBar()
  + appBar({ title: 'Export', leadGo: 'Z01' })
  + body(
    banner('No member data is ever included: no logs, no photos, no cycle.', { v: 'sage', ic: 'lock' })
    + sectionHead('What to export')
    + listItem({ lead: icon('fitness_center', { size: 22, color: C.primaryDim }), title: 'Exercises', sub: 'CSV + videos', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + listItem({ lead: icon('restaurant', { size: 22, color: C.primaryDim }), title: 'Foods', sub: 'CSV', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + listItem({ lead: icon('menu_book', { size: 22, color: C.primaryDim }), title: 'Recipes', sub: 'CSV + photos', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + listItem({ lead: icon('calendar_month', { size: 22, color: C.primaryDim }), title: 'Programmes', sub: 'CSV', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + sageNote('CSVs and media, in the same shape you import them — so an export can be edited and re-imported.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Export the content library', { go: 'Z11' })));

// D18 — the two forms that did not exist. Modelled on Z03 and Z05 exactly,
// because they are the same screen with a different contract: ContentFormView
// is parameterised by collection and draws whichever columns it can label.
const Z12 = phone(
  statusBar()
  + appBar({ title: 'Edit a recipe', lead: 'close', leadGo: 'Z06' })
  + body(
    field({ label: 'Recipe id', value: 'om_ali', helper: 'Stable. Changing it orphans everything that referenced it.' })
    + field({ label: 'Name (English)', value: 'Om Ali' })
    + field({ label: 'الاسم (العربية)', value: 'أم علي' })
    + field({ label: 'Minutes', value: '35' })
    + field({ label: 'Ingredients', value: 'puff pastry|milk|nuts|sugar' })
    + field({ label: 'Allergens', value: '', error: 'Required. Write “none” if there are none. Blank is not the same thing.' })
    + sageNote('A recipe that names a photo nobody uploaded is refused at validation, rather than reaching a woman as a card with a missing image.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save', { go: 'Z06' })));

const Z13 = phone(
  statusBar()
  + appBar({ title: 'Edit a programme', lead: 'close', leadGo: 'Z07' })
  + body(
    field({ label: 'Programme id', value: 'six_week_return', helper: 'Stable. Changing it orphans everything that referenced it.' })
    + field({ label: 'Name (English)', value: 'Six week return' })
    + field({ label: 'الاسم (العربية)', value: 'العودة في ستة أسابيع' })
    + field({ label: 'Weeks', value: '6' })
    + field({ label: 'Days a week', value: '3' })
    + field({ label: 'Session length', value: '20' })
    + sageNote('A programme is a shape: weeks, days, session length. It holds no ingredient and no movement of its own, so there is no safety column for a guard to read off it.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save', { go: 'Z07' })));

// D25 - the feature switchboard.
const Z14 = phone(
  statusBar()
  + appBar({ title: 'Feature flags', leadGo: 'Z01' })
  + body(
    banner('Turning a feature off hides it everywhere, for everyone.', { v: 'sage', ic: 'lock' })
    + sectionHead('Built and live')
    + listItem({ lead: icon('today', { size: 22, color: C.primaryDim }), title: 'Today and logging', sub: 'On', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + listItem({ lead: icon('fitness_center', { size: 22, color: C.primaryDim }), title: 'Train', sub: 'On', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + listItem({ lead: icon('restaurant', { size: 22, color: C.primaryDim }), title: 'Eat', sub: 'On', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + listItem({ lead: icon('favorite', { size: 22, color: C.primaryDim }), title: 'My cycle', sub: 'On', trail: icon('check_circle', { size: 22, color: C.primary, fill: true }) })
    + sectionHead('Not switched on yet')
    + listItem({ lead: icon('groups', { size: 22, color: C.primaryDim }), title: 'Community', sub: 'Off', trail: icon('radio_button_unchecked', { size: 22, color: C.onSurfaceVariant }) })
    + listItem({ lead: icon('photo_camera', { size: 22, color: C.primaryDim }), title: 'Video and reels', sub: 'Off · blur export is unmeasured on a budget handset', trail: icon('radio_button_unchecked', { size: 22, color: C.onSurfaceVariant }) })
    + listItem({ lead: icon('badge', { size: 22, color: C.primaryDim }), title: 'Coaching', sub: 'Off', trail: icon('radio_button_unchecked', { size: 22, color: C.onSurfaceVariant }) })
    + listItem({ lead: icon('payments', { size: 22, color: C.primaryDim }), title: 'Payments', sub: 'Off · no payment provider is connected', trail: icon('radio_button_unchecked', { size: 22, color: C.onSurfaceVariant }) })
    + sageNote('A feature inside another one cannot be on while the one around it is off. Switching Community off switches off everything inside it, so nothing is left reachable on its own.')
  , { pad: '0 16px 0', gap: 10 })
  + footer(btn('Save', { go: 'Z01' })));

export const screens = [
  { id: 'Z14', html: Z14, metric: 'ship it dark', note: 'Every feature in the product with a switch beside it. A flow can be finished, merged and left unreachable until it is actually ready - which is what stops a half-built coaching marketplace reaching a woman because a branch landed. The nesting is the load-bearing part: a sub-feature cannot be on while the feature around it is off, so there is no way to strand one.' },
  { id: 'Z12', html: Z12, metric: 'one at a time, too', note: 'Recipes could be imported in bulk and not authored by hand, which made "add a meal from inside the app" true of foods and not of recipes. The form is the same widget as Z03 and Z05 — generated from the schema — so the column added to recipes.csv tomorrow appears here without anyone editing a screen.' },
  { id: 'Z13', html: Z13, metric: 'a shape, not a safety tag', note: 'The only collection with no safety column, and deliberately: a programme holds no ingredient and no movement, so there is nothing for a guard to read off it. Its numbers are all required though — a programme with no week count is not a smaller programme, it is an unusable one.' },
  { id: 'Z01', html: Z01, metric: 'what is missing, first', note: 'The landing tab leads with how many rows lack a mandatory safety tag rather than how many rows exist. An incomplete library is the failure mode that matters, and a total hides it — a food with no allergens value is not a smaller library, it is a guard that fails closed on every woman.' },
  { id: 'Z02', html: Z02, metric: '0 authored', note: 'The 124-move library does not exist. The filter chips name the two states worth finding: rows missing contraindication tags, and rows whose video was never uploaded.' },
  { id: 'Z03', html: Z03, metric: 'blank is refused', note: 'The contraindication field shows its error state deliberately. Blank and “none” are different facts: the guard cannot tell an untagged row from a safe one, so the importer refuses to create the ambiguity rather than accepting it quietly.' },
  { id: 'Z04', html: Z04, metric: 'allergens required', note: 'Same rule on foods, where it matters most. Knowing a dish is koshari does not tell the app whether it contains nuts.' },
  { id: 'Z05', html: Z05, metric: 'bilingual content', note: 'name_en and name_ar are both required. The library carries its own display text because it is content from a build-time bundle, not copy from the translation dictionary.' },
  { id: 'Z06', html: Z06, metric: 'photo must exist', note: 'A recipe naming a photo that was never uploaded is rejected at validation — rather than reaching a woman as a card with a missing image.' },
  { id: 'Z07', html: Z07, metric: 'O05 depends on this', note: 'With no programmes authored, O05 offers a preview of content that does not exist and selection cannot reflect her four answers.' },
  { id: 'Z08', html: Z08, metric: 'the contract, stated', note: 'The expected columns are on screen before the file is chosen, so a mismatch is caught by reading rather than by failing. Unknown headers are refused, not ignored.' },
  { id: 'Z09', html: Z09, metric: 'nothing written yet', note: 'The dry run. The whole file is validated before anything is written, and every bad row is named with its reason. If one row fails, nothing is written — a half-imported library is worse than none, because the gaps are invisible and the safety guards read a missing tag as unsafe.' },
  { id: 'Z10', html: Z10, metric: 'unlinked, first', note: 'Bulk upload, then linked by filename to the ids the CSV named. The list leads with files linked to nothing, because those are the ones that will break a row at validation. Read requires a signed-in account: this is a women-only product and the library sits behind the same gate.' },
  { id: 'Z11', html: Z11, metric: 'content only, ever', note: 'One CSV per collection in exactly the import schema, plus the media those rows reference. No users/** path is reachable from here — not logs, not photos, not cycle. The app tells her that her ID photo is deleted and her logs are never shown to members; an admin bulk-export of user media would make both statements false, and under PDPL it is the line between a content catalogue and regulated personal data.' },
];
