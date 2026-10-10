---
name: Own Hub
description: A printed women's training edition she writes in; exact print underneath, a hand of ink, pencil and marker on top.
colors:
  rose-ink: "#B4526E"
  rose-ink-deep: "#A8455F"
  blush-marker: "#FFD9E3"
  blush-soft: "#F8E1E7"
  on-blush: "#4A1C2E"
  sage: "#4F7359"
  sage-soft: "#6E9478"
  sage-container: "#DDEDE1"
  on-sage: "#1E3826"
  caution-amber: "#8A5A17"
  caution-amber-container: "#FBEBD6"
  problem-red: "#A84A4A"
  problem-red-container: "#FBE0E0"
  page: "#FFF8F9"
  sheet-white: "#FFFFFF"
  page-tint: "#FFF1F4"
  grouped-tint: "#FBEAEF"
  print-ink: "#241A1E"
  quiet-print: "#6B5C61"
  pencil: "#9C838A"
  pencil-faint: "#EBDCDF"
  inverse-page: "#37292E"
  on-inverse-page: "#FFECF0"
typography:
  cover:
    fontFamily: "Rubik"
    fontSize: "38px"
    fontWeight: 500
    lineHeight: 1.08
    letterSpacing: "-0.6px"
  section:
    fontFamily: "Rubik"
    fontSize: "28px"
    fontWeight: 500
    lineHeight: 1.14
    letterSpacing: "-0.35px"
  folio:
    fontFamily: "Rubik"
    fontSize: "17px"
    fontWeight: 500
    lineHeight: 1.3
  display:
    fontFamily: "Rubik"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.25
  headline:
    fontFamily: "Rubik"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1.269
  title-l:
    fontFamily: "Rubik"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.3
  title-m:
    fontFamily: "Rubik"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.353
  title-s:
    fontFamily: "Rubik"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.333
  body:
    fontFamily: "Rubik"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  body-m:
    fontFamily: "Rubik"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.467
  label:
    fontFamily: "Rubik"
    fontSize: "15px"
    fontWeight: 500
    lineHeight: 1.333
  nav:
    fontFamily: "Rubik"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.333
  hand-latin:
    fontFamily: "La Belle Aurore, Aref Ruqaa, Rubik"
    fontSize: "23px"
    fontWeight: 400
    lineHeight: 1.1
  hand-arabic:
    fontFamily: "Aref Ruqaa, Rubik"
    fontSize: "18.9px"
    fontWeight: 400
    lineHeight: 1.35
rounded:
  tight-min: "3px"
  control: "6px"
  button: "7px"
  card-tight: "7px"
  dialog: "10px"
  button-loose: "15px"
  card-loose: "18px"
  loose-max: "22px"
  circle: "999px"
spacing:
  hairline: "3px"
  chip-gap: "8px"
  stack: "10px"
  card-gap: "12px"
  gutter: "16px"
  card-padding: "16px"
components:
  button-filled:
    backgroundColor: "{colors.rose-ink}"
    textColor: "#FFFFFF"
    typography: "{typography.label}"
    rounded: "{rounded.button}"
    padding: "6px 12px"
    height: "56px"
  button-tonal:
    backgroundColor: "{colors.blush-marker}"
    textColor: "{colors.on-blush}"
    typography: "{typography.label}"
    rounded: "{rounded.button}"
    padding: "6px 12px"
    height: "56px"
  button-sage:
    backgroundColor: "{colors.sage}"
    textColor: "#FFFFFF"
    typography: "{typography.label}"
    rounded: "{rounded.button}"
    padding: "6px 12px"
    height: "56px"
  button-outlined:
    textColor: "{colors.print-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.button}"
    padding: "6px 12px"
    height: "56px"
  button-text:
    textColor: "{colors.rose-ink-deep}"
    typography: "{typography.label}"
    padding: "6px 12px"
    height: "44px"
  card-outlined:
    backgroundColor: "{colors.sheet-white}"
    rounded: "{rounded.card-tight}"
    padding: "{spacing.card-padding}"
  card-filled:
    backgroundColor: "{colors.grouped-tint}"
    rounded: "{rounded.card-tight}"
    padding: "{spacing.card-padding}"
  card-error:
    backgroundColor: "{colors.problem-red-container}"
    textColor: "{colors.print-ink}"
    rounded: "{rounded.card-tight}"
    padding: "{spacing.card-padding}"
  card-selected:
    backgroundColor: "{colors.sheet-white}"
    rounded: "{rounded.card-tight}"
    padding: "{spacing.card-padding}"
  chip:
    textColor: "{colors.quiet-print}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: "40px"
  chip-selected:
    backgroundColor: "{colors.blush-marker}"
    textColor: "{colors.on-blush}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: "40px"
  field:
    backgroundColor: "{colors.page-tint}"
    textColor: "{colors.print-ink}"
    typography: "{typography.body}"
    height: "60px"
  fact-highlight:
    backgroundColor: "{colors.blush-soft}"
    textColor: "{colors.rose-ink-deep}"
    typography: "{typography.label}"
    height: "34px"
  nav-bar:
    backgroundColor: "{colors.page}"
    textColor: "{colors.quiet-print}"
    typography: "{typography.nav}"
  undo-bar:
    backgroundColor: "{colors.inverse-page}"
    textColor: "{colors.on-inverse-page}"
    typography: "{typography.body-m}"
    rounded: "{rounded.control}"
---

# Design System: Own Hub

## Overview

**Creative North Star: "The Annotated Edition"**

Own Hub is a printed women's edition that she writes in, kept like a training diary. There are two layers and they never trade places. Underneath is an exact printed page: Rubik on a strict column, controls that do not bend, figures that are true to the unit. On top is a reader's hand in rose ink, pencil and blush marker: an underline that overshoots, a loop closed past its own start, a tick, one pencil arrow pointing at the thing to do. The hand annotates what the print already says; it never carries meaning on its own.

Imperfection is rationed, because it is only worth anything against precision. Every mark takes a `HandLevel` (structural, crafted, expressive, signature) and a seed: the same seed draws the same shape on every frame and every visit, a different seed draws a different one, so a screen of cards is never one template repeated and nothing shimmers. Most of every screen is structural or crafted; a screen spends one or two signature marks at most, usually on its masthead. Tone comes from pencil hatching, never from gradients or shadows. The page is warm, rose-tinted paper with a faint grain; light theme only.

The world refuses the category's greeting-plus-stat-tiles-plus-card-carousel dashboard. Today is a cover, not a dashboard: a date line, this week's session set large and underlined twice, the week as hand-circled marks, one arrow, one ink-outlined action, a quiet ruled list below. Nothing is ranked and nothing is "won": done is sage, never gold or red.

**Key Characteristics:**
- Two layers: exact print underneath, a seeded human hand on top.
- Four-level imperfection budget; one or two signature marks per screen.
- Rose ink for every mark, blush marker for highlights, sage for done, near-black ink for type.
- Pencil hatching for tone; no gradients, no blurred shadows.
- Three tight corners and one loose corner per surface; no pills.
- Presses compress or push the body onto its off-register outline; nothing ripples.
- Every directional mark mirrors in Arabic; data marks are exact.

## Colors

A rose-and-paper palette where colour is a role in a person's kit (pen, marker, pencil, done) rather than a decoration.

### Primary
- **Rose Ink** (rose-ink): the reader's pen. Every hand mark (underlines, loops, arrows, the next-session ring, focused field line) and the filled primary button's body. Also owns whole fields where the app speaks (tonal hatching).
- **Deep Rose Ink** (rose-ink-deep): ink for marks that sit on blush, text-button labels and underlines, and the off-register outline under a filled button, so contrast holds.
- **Blush Marker** (blush-marker): the marker swath laid behind a word or an active nav icon, the selected chip's fill, the tonal button body, and text selection.
- **Blush Soft** (blush-soft): the paler swath behind a stated fact (level, programme week) and the secondary log button.

### Secondary
- **Sage** (sage): done. Ticks, logged-session strokes, restorative actions (rest week), and the sage card's hatching. Because nothing in this product is won.
- **Soft Sage** (sage-soft): the nib colour for exact data marks: ring arcs, progress strokes, logged week segments.
- **Sage Container / On Sage** (sage-container, on-sage): the sage note's text and the restorative big button's outline.

### Tertiary
- **Caution Amber** (caution-amber, caution-amber-container): a caution that is not a failure (a draft, something unpublished). Drawn as a precise outline only.
- **Problem Red** (problem-red, problem-red-container): genuine problems and medical guidance only; the one card family that keeps a flat tint, and a field's straight 2px error line.

### Neutral
- **Page** (page): the paper every screen sits on, under a faint grain, and the nav bar (it is the foot of the page, not a tray).
- **Sheet White** (sheet-white): an outlined card, a bottom sheet, a dialog: a sheet laid on the page.
- **Page Tint / Grouped Tint** (page-tint, grouped-tint): the field well; the filled (grouped) card.
- **Print Ink** (print-ink): printed type and structural rules. It is also the button-outlined frame at 72% alpha.
- **Quiet Print** (quiet-print): secondary copy, inactive nav labels, field labels.
- **Pencil** (pencil): construction lines, hatching, ruled rows, card frames (55%), icon rings (70%), the grab handle.
- **Faint Pencil** (pencil-faint): track under exact data marks, dividers.
- **Inverse Page** (inverse-page, on-inverse-page): the in-page undo bar and dark player surfaces only.

### Named Rules
**The Four Inks Rule.** Rose is the pen, blush is the marker, sage is done, print-ink sets the type. A mark in any other colour is a mark in the wrong kit.

**The Nothing Is Won Rule.** Completion is sage. Unfilled or missed is neutral pencil, never red; there is no "missed" styling anywhere.

**The Hatched Tone Rule.** The tonal (rose) and sage card families carry their colour as pencil hatching at 0.3 opacity over paper, not as a flat fill. Amber is outline-only. Error alone keeps a flat tint, because a problem is stated precisely.

## Typography

**Reading Font:** Rubik (400/500/600/700), both scripts.
**Hand (Latin and all numerals):** La Belle Aurore, falling back to Aref Ruqaa then Rubik.
**Hand (Arabic):** Aref Ruqaa.

**Character:** One reading family at editorial scale contrast (a large, slightly tight medium weight against small quiet type) with no serif and no mono. The two hands are set rarely, as notes in the margin.

### Hierarchy
- **Cover** (500, 38px, 1.08, -0.6px): the one focal line of a cover screen (Today's session, the welcome line). Underlined by hand at signature level.
- **Section** (500, 28px, 1.14, -0.35px): hub mastheads (Train, Eat, Community, Progress, Cycle, coach desk).
- **Folio** (500, 17px, 1.3): the masthead's date line.
- **Display / Headline** (600, 32px / 26px): generated brand scale; for large figures and non-cover headings.
- **Title L / M / S** (600, 20 / 17 / 15px): card and row titles.
- **Body / Body M** (400, 16px 1.5 / 15px 1.467): reading copy, subtitles.
- **Label** (500, 15px): controls. Buttons set it at 17px/600.
- **Nav** (500, 12px): bottom navigation labels.
- **Hand** (400): Latin is set at 1.28x the requested size to match Rubik's x-height (default 18 → 23px, line-height 1.1); Arabic at 1.05x (line-height 1.35). Notes are usually rotated a few degrees.

### Named Rules
**The Four Words Rule.** Handwriting is limited to existing strings of four words or fewer ("Up next") and decorative numerals. It never sets a paragraph, a control label, or anything that must be read to act. A note that repeats printed text is marked decorative so a screen reader hears it once.

**The Painted Figure Rule.** A hand-set figure (HandFigure) is painted, not laid out as Text, and excluded from semantics; the same figure is always stated in print. The hand-set numeral "1" gets a drawn flag, because La Belle Aurore's bare stroke does not read as a one.

**The One Family Rule.** Rubik is the only reading face. There is no serif, no mono, and no small tracked label above a title.

## Layout

A single phone column. Body padding is 4px top and 16px sides, children stacked 10px apart; the footer (the primary action, within thumb reach) is padded 10px 16px 14px and pinned. Cards pad 16px with 12px between children; chips sit 8px apart and wrap rather than scroll. Rows are open lines in a diary, ruled underneath in pencil, not a stack of boxes.

Cover screens are set on the page itself rather than in cards: date line, a pencil rule, the focal line large, the week's marks, one arrow down to the action, then a ruled list. Illustrations come from the screen-art table; a cover places its own art inline beside the title (placesOwnArt / inlineFor) instead of in the strip above.

Every tap target is at least 44pt even when the visual height is smaller (text button 40, chip 40). Heights are floors, never fixed: at large text sizes buttons, fields and chips grow instead of clipping. Above 1.3x text scale several layouts stack (empty state, Today's walk row, others), and footers flagged footerScrollsWhenLarge join the scrolling body. Nav labels clamp at 1.35x; the mid-set display figures clamp at 1.3x.

Arabic mirrors all of it: directional padding and alignment throughout, and every directional painter reads the ambient Directionality.

## Elevation & Depth

Flat. There are no blurred shadows and no gradients anywhere in the hand layer; stock Material elevation is set to 0 on dialogs, sheets and snack bars. Depth is printed, not lit: a sheet-white surface on the rose page, pencil hatching for tone, and on the product's own voice (filled buttons, tonal cards) a second outline set 3px off, like a print whose colours did not quite register. That offset is a stroked outline in a deeper shade of the body's own colour, never a filled drop block.

### Shadow Vocabulary
- **Off-register outline** (stroked outline offset 3px, 3px, mirrored in RTL): filled, tonal and sage buttons (outline in rose-ink-deep / rose-ink / on-sage), the tonal card (rose-ink at 85%), the primary log button. On press the body slides onto it and the offset closes.
- **Paper grain**: a faint repeated tile under every screen (print-ink at 1.8–5%, pencil at 5%).
- **Scrim**: print-ink at 45% behind a bottom sheet.

### Named Rules
**The Printed Depth Rule.** Nothing floats. A surface is lifted only by registration (the 3px offset outline) or by being a whiter sheet on the page; tone is always hatching density, never a gradient.

## Shapes

Surfaces are cut, not moulded. Each one has three tight corners and one loose corner, and the seed chooses which corner is loose, so no two cards on a screen share a silhouette. Tight radius is the caller's brand radius × 0.35 (clamped 3–8px); the loose one is × 0.9 (clamped 10–22px). A card at the brand's 20px radius draws 7px and 18px; buttons draw 7px and 15px; controls (chips, segmented strip) 6px. A speech bubble names its loose corner (HandCorner) so the tail sits where it means something, named by reading direction so it turns round in Arabic.

Frames are one nib stroke walked round the outline and run a little past the start, so the ends overlap where the pen came back. Strokes taper toward their ends and vary in weight; widths are fine 1.25, pen 1.7, felt 2.4, pencil 0.7. The only full circles are avatars, rings and the hand's own loops. Bottom sheets have unequal top corners (14px and 22px) and a short pencil stroke for a grab handle. Empty states are a dashed pencil box: space left for her to fill in.

### Named Rules
**The No Pill Rule.** Nothing is a stadium. Status "pills" are marker swaths behind words; buttons are cut blocks with one loose corner.

**The Seeded Hand Rule.** Every mark takes a seed derived from what it holds; the same content draws the same shape every time. Nothing reads a clock or a global random source.

## Components

### Buttons
Printed blocks that give under the finger.
- **Shape:** tight corners (7px) with one loose corner (15px), 56px minimum height, label 17px/600.
- **Filled (one per screen):** rose-ink body, white label, rose-ink-deep outline 3px off-register. **Tonal:** blush body, on-blush label, rose-ink outline. **Sage:** restorative actions; sage body, on-sage outline.
- **Outlined:** no fill, framed by hand in print-ink at 72%, 1.2 stroke.
- **Text:** rose-ink-deep label underlined in pen (crafted, 1.2); never destructive.
- **Press:** a body with an offset outline is pushed onto it (no scale); others compress to 0.97. No ripple anywhere; focus shows blush marker at 60%.

### Chips
- **Style:** 40px visual, 44pt target, 15px medium label, framed in pencil (70%), control radius.
- **Selected:** blush fill, ringed in rose ink at expressive level. Selection state belongs to the caller.

### Fact highlight (was the pill)
A never-tappable fact (level, programme week) drawn as a tilted marker swath behind the words, blush-soft by default with rose-ink-deep text, 34px minimum.

### Cards / Containers
One HandSurface, seven families, mapped only in `app_card.dart`:
- **Outlined:** sheet-white, pencil frame at 55%, crafted.
- **Filled:** grouped tint, no frame.
- **Tonal:** the app's own voice; rose pencil hatching, rose off-register outline, no fill.
- **Sage:** restful; sage hatching, no line.
- **Amber:** precise amber outline at 60%, structural, no tint.
- **Error:** problem-red tint with a precise 45% outline, structural.
- **Selected:** sheet-white ringed in 2px rose ink, expressive.
- **Padding:** 16px, 12px between children.

### Inputs / Fields
- **Style:** 60px minimum on page-tint with a 6px top radius and a pencil line beneath; label inside the field above the value.
- **Focus:** the line is drawn again in rose ink (pen + 0.3), drawn on.
- **Error:** a straight 2px problem-red line; a problem is stated plainly, not sketched.

### Lists / Rows
An outlined row is a diary line: open on the page, ruled underneath in pencil. A leading icon sits in a small pencil ring (HandIconRing). Coloured variants stay surfaces drawn like cards; selected is the 2px rose ring.

### Navigation
The bottom bar sits on the page under a pencil rule, not on a tinted tray. The active tab is marked four ways: a marker swath behind the icon, the filled icon, rose colour, and a pen line under its name. Labels clamp at 1.35x. Four destinations per role. Top bars are transparent with dark status-bar content.

### Hand marks (signature)
- **HandUnderline:** overshoots both ends; at signature level the pen returns for a shorter second pass (Today's double underline).
- **HandCircled:** a loop closed past its own start.
- **HandTick:** sage, short stroke down, long bowed stroke up.
- **HandArrow:** pencil, bowing, given in 0–1 box space; one per screen, pointing at the action or value.
- **MarkerHighlight, HandRule, HandNote, HandFigure, PaperPage** as described above.
All are decoration over content that already says what it means: ExcludeSemantics, no taps.

### Week and data marks
- **Week, marks form (Today, Progress):** one hand circle per session; a sage tick inside each logged one, the next ringed in rose ink at signature/felt, the rest in pencil with their hand-set number.
- **Week, bar form:** short strokes; sage nib for logged, pencil for to-come. No seven-day variant.
- **Ring stat / progress:** a nib stroke over a pencil guide that starts at twelve o'clock and sweeps exactly the value. Only stroke weight varies, never length. Figures sit in print.

### Hub mastheads
Each hub's single signature mark is deliberately different: Today double underline; Train marker; Eat loop; Community single underline; Progress circled week marks plus a contents line; Cycle loop (title page); coach desk marker.

### Motion
Marks a person would be seen drawing (circles, ticks, focus lines, cover underlines, the arrow) draw on once over 420ms on a pen curve, with short staggered delays; frames, rules and fills never draw on, because the page is printed. Presses take 90ms in and 180ms out. With reduced motion (disableAnimations or accessibleNavigation), marks are simply there, nothing scales, and a press shows a faint 5% ink shade instead.

## Do's and Don'ts

### Do:
- **Do** give every mark a HandLevel and a seed from its content; keep most of a screen structural or crafted and spend at most one or two signature marks.
- **Do** keep data marks exact: rings, progress and week segments sweep precisely the value.
- **Do** pass Directionality to every directional painter so underlines start from the right, arrows point forward and loose corners turn round in Arabic.
- **Do** make tone with pencil hatching (cards at 0.3 opacity) and depth with the 3px off-register outline.
- **Do** vary the masthead mark per hub rather than reusing one.
- **Do** treat heights as floors, keep 44pt targets, and stack layouts above 1.3x text scale.
- **Do** mark decorative hand marks ExcludeSemantics and paint hand-set figures.

### Don't:
- **Don't** use gradients, blurred shadows, Material ripples or elevation.
- **Don't** draw a pill or stadium; use three tight corners and one loose corner, or a marker swath.
- **Don't** set handwriting longer than four words, on controls, or for anything she must read to act.
- **Don't** add a second reading family, a serif, a mono, or a small tracked label above a title.
- **Don't** colour missed or unfilled states red, or celebrate done in anything but sage.
- **Don't** let a hand mark overstate a value or carry information the print does not.
- **Don't** hand-edit `app_tokens.dart`; it is generated from the prototype's tokens. The hand layer lives in `hand_tokens.dart`.
- **Don't** add a dark theme; the edition is printed on light paper.
