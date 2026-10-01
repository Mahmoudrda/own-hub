# Where every illustration in this app comes from

**Status: resolved. Every illustration in Own Hub is original to this project,
drawn and painted in code, and carries no third-party licence.**

This directory holds this file and nothing else. There is no image asset in it,
`pubspec.yaml` bundles no illustration, and `app_art_test.dart` fails the build
if either of those changes.

## Where the illustrations actually are

`app/lib/ui/hand/art_marks.dart` — 32 marks drawn as `CustomPainter` paths,
seeded from their own name so each one comes out identical on every draw,
wrapped in `ExcludeSemantics`, and costing zero bytes of binary asset. Six of
the food marks delegate to `app/lib/ui/hand/food_marks.dart`, which drew the
recipe-card shapes the same way and for the same reason.

`app/lib/ui/hand/art_palette.dart` — what they are painted in. Twelve
two-colour tones, each a solid fill and a deeper line, mixed against the
product's own `#FFF8F9` surface and `#A24661` rose.

`app/lib/theme/app_art.dart` names them. `app/lib/theme/screen_art.dart` places
them, one table for the whole product.

Copyright in them is the project's. Nothing needs attributing, nothing needs
tracking, and nothing needs re-licensing if this app is sold, sublicensed or
white-labelled.

The 32 names, which `app_art_test.dart` checks this file still lists:

`running`, `dance`, `strong_arms`, `squat_weights`, `lunge_kneeling`,
`lunge_warrior`, `plank`, `stretch_seated`, `side_stretch`, `rest_floor`,
`meditation`, `overhead_raise`, `dumbbells`, `boxing_gloves`, `yoga_mat`,
`trainers`, `gym_bag`, `spin_bike`, `headphones`, `bowl_salad`, `buddha_bowl`,
`plate_mixed`, `steak`, `toast_egg`, `breakfast`, `bruschetta`, `pasta`,
`fruit_basket`, `apple`, `grapes`, `watermelon`, `nuts`.

---

# History: why the previous set was removed, and why it cannot come back

This half of the file is kept deliberately. It is the reason nobody should drop
a stock illustration into this app without a licence in hand, and it is easier
to argue with a record than with a rule.

## What was here

`app/assets/art/` shipped 57 illustrations at three densities — 171 WebP files,
about 4.8 MB — bundled through three `assets/art/` lines in `pubspec.yaml`. They
came from two PDFs the owner supplied, `Icons.pdf` and `More icons.pdf`.

Until a licence audit in September 2026 there was **no licence record for any of
them anywhere in the repository**: `find . -iname "*licen*"` returned two ONNX
model licences and two OFL font licences, and nothing else.

## The finding

`assets/art/cupcake.webp` was **byte-for-byte the cupcake on the Sweet Tooth
Breakfast divider** of `Rahoma's Recipe Book.pdf`. That book was made in Canva:
its PDF producer string says so and its author metadata reads
`Rahma Mohssen1234`.

Canva's Content Licence Agreement permits using an element **within a design**
and explicitly prohibits extracting an element and using it as a stand-alone
asset or sublicensing it. An illustration inside an app binary is a stand-alone
asset. The same is true of the Freepik and Flaticon free tiers, which carry
per-asset licences and per-asset attribution.

That was not a risk assessment. It was the licence text, and the app had been
shipping against it since before the recipe feature existed.

## The provenance was re-examined in October 2026, and the finding got stronger

The first audit rested on one byte-identical match plus a producer string. That
is good evidence a file passed **through** Canva and not proof the artwork is
Canva's to license — a designer can upload her own or separately-licensed work
into Canva and it exports identically. So the question was asked again properly,
because if Rahma owned or had licensed this art there was no problem at all and
the right answer was to put the originals back with the licence recorded.

She did not. Four things, in order of weight:

1. **The pack is not a pack.** Page 2 of `Icons.pdf` holds fifteen fitness
   illustrations in at least six visibly different drawing styles — a textured
   gouache pull-up, a flat-vector warrior lunge, a hard-outlined seated stretch,
   an airbrushed cake. A set somebody owns, or licensed as a unit, is
   stylistically coherent. This is the signature of searching a stock element
   library for "woman running", "boxing gloves" and "yoga mat" and keeping
   whatever looked good.
2. **Both icon PDFs are one Canva design.** `Icons.pdf` and `More icons.pdf`
   carry the same `pdf:Keywords="DAHVvqM8xqg,BAF7HRpRuMA"`; the second is the
   first re-exported with more pages. They are an asset board assembled inside
   Canva, not an export of files she already had.
3. **All three PDFs are flagged as containing AI-generated content.** Their XMP
   carries `ContainsAiGeneratedContent:ContainsAiGeneratedContent="Yes"`, which
   Canva writes when a design contains output from its own AI tools. On a design
   whose entire content is these illustrations, that points at Canva's generator
   rather than at an upload. It does not settle the question by itself — Canva
   sets the flag broadly — but it points the same way as everything else.
4. **The WebP files carry no metadata at all.** No EXIF, no XMP, no ICC: the
   files hold `VP8X`, `ALPH` and `VP8` chunks and nothing more. Whatever
   provenance the originals had was stripped on conversion, so the files
   themselves can neither confirm a licence nor rescue one.

**Confidence: high that these are Canva library elements and/or Canva AI output,
and therefore cannot be shipped; not certain which of the two.** Both end in the
same place, because the Content Licence Agreement governs either way. The one
thing that would overturn it is a receipt — an invoice, a licence key, or a
stock-site download in Rahma's name. If that exists, this file is where to
record it, and the decision below should be reopened.

## The licensed alternatives were compared before drawing again

The first replacement — 32 marks in a single thin rose ink — was licence-clean
and the owner rejected it on sight. He was right: he had asked for clean, flat,
colourful illustrations and a page of one-ink line drawings is none of those. So
the licensed sets were looked at properly rather than skipped.

| Set | Licence | Why it was not adopted |
|---|---|---|
| **Microsoft Fluent Emoji** | **MIT**, © Microsoft Corporation — genuinely permissive: use, modify and sublicense allowed, requiring only that the notice travels with it | **The best of them, and still wrong here.** Its objects are excellent, and close to what the owner liked: the green salad, the pot of food, the grapes, the running shoe, the backpack and the boxing glove are exactly the register this product wants. Its **people** are not. Every human emoji ships with a face, a skin tone and visible hair — `Woman dancing` is a flamenco dancer in a red dress with a flower in her hair. Twelve of this app's 32 marks are a woman's body, and this product has already decided it will not take a position on her hair, her dress or her colour. A set that cannot draw her without doing all three cannot supply those twelve. Its palette is saturated primaries too — a cyan bowl, a yellow arm — which on a `#FFF8F9` page reads as a sticker, the same complaint the Canva pack attracted. |
| **Twemoji** | CC-BY 4.0 | Same problem with people, plus a standing attribution obligation for decoration nobody reads. |
| **OpenMoji** | CC BY-SA 4.0 | Share-alike on a commercial app's bundled assets. Out, as it was in September. |
| **Noto Emoji** | OFL 1.1 / Apache 2.0 | Licence is fine. Same problem with people, and flatter and plainer than what was asked for. |

There is no openly licensed flat illustration set of **faceless, hairless human
figures**. That is the real reason this set is painted rather than licensed: the
binding constraint is the brief, not the licence.

Adopting any of them would also have meant deleting `app_art_test.dart`'s
`no illustration file is shipped at all`, which is the check standing between
this app and a repeat of September.

## What was done about it

The owner confirmed Canva as the source and asked for the designs without the
exposure. So the visual intent was kept and the assets were replaced with
original work: the placement table in `screen_art.dart` still says what each
screen is about, and what it draws is now painted rather than bundled.

Fifty-seven names became thirty-two, because the old set named subjects rather
than shapes. `running`, `run_side`, `jogger` and `dumbbell_run` were four files
of a woman running; `bowl_salad`, `bowl_green`, `salad_blue` and `salad_wood`
were four bowls of leaves. At the size these are drawn, in one ink, each of
those groups is one drawing, and four near-identical drawings would be
decoration pretending to be information. Eight names — `cupcake`, `cookies`,
`cake_slice`, `fries`, `pancakes`, `wrap`, `taco`, `pineapple` — were placed on
no screen at all and were dropped rather than redrawn.

In October the same geometry was **repainted in colour**, which is what the
owner's rejection actually asked for: solid fills, a deeper line round them, and
a second colour where a shape has a part that is not the colour of the rest of
it — a yolk in its white, an apple's leaf, the leaves in a bowl. That is
`art_palette.dart`. The marks are flat and colourful now and still cost nothing,
and every figure is a single rose pictogram with a plain circle for a head: no
face, no hair, no skin tone, no garment.

## The rule this leaves behind

**Do not add a bundled illustration to this app.** If one is ever genuinely
needed:

1. Its licence must be named in this file, with its source and acquisition
   date, before it is committed.
2. A free tier is not a licence. Read the actual agreement, and read the clause
   about stand-alone assets and sublicensing in particular.
3. Share-alike licences are out. OpenMoji is CC BY-SA 4.0; share-alike on an
   app's bundled assets is a problem nobody wants to discover after launch.
4. A permissive licence is necessary and not sufficient. Microsoft Fluent Emoji
   is MIT and was still turned down, on what it draws rather than on what it
   allows. Judge the pictures against the brief before judging the terms.
5. If it can be drawn instead, draw it. `art_marks.dart` shows how, and the
   whole 4.8 MB this repository used to carry is what that saved.

## Everything else third-party in this repository, and its licence

| What | Licence | Where the text lives |
|---|---|---|
| Aref Ruqaa (Arabic hand face) | SIL Open Font Licence 1.1 | `assets/fonts/OFL-ArefRuqaa.txt`, registered in `main.dart` so it shows on the licences page |
| La Belle Aurore (Latin hand face) | SIL Open Font Licence 1.1 | `assets/fonts/OFL-LaBelleAurore.txt`, registered in `main.dart` |
| Rubik (interface face) | SIL Open Font Licence 1.1 | `assets/fonts/OFL-Rubik.txt`, registered in `main.dart`; also the face the brand wordmark is set in |
| ML Kit face-detection models | Google ML Kit terms, via the `google_mlkit_face_detection` package | the package's own licence, surfaced by `LicenseRegistry` |
| Dart and Flutter packages | their own, all surfaced by `LicenseRegistry` on the licences page | `pubspec.lock` |
| `assets/brand/*.svg`, `assets/icon/*.png` and every generated launcher icon | original to this project, built from the owner's own identity sheet | see "The brand mark" below |
| `assets/content/rahma_recipes.json` | the owner's own writing, extracted from her book by `tool/extract_rahma_book.py` | owner's, no third party |

## The brand mark, and what it is made of

**Status: resolved. The mark is geometry this repository owns, and the only
third-party thing in it is a font the repository already licenses.**

On 30 September 2026 the owner chose concept 02, "The Outfit Monogram", from a
three-concept identity sheet made for him: a ring with a diagonal blade
through it, a slashed O. The sheet is his, commissioned work he supplied.

What is in the repository is **not** that sheet. The sheet is a lossy JPEG
photograph of a presentation board, and anything cropped out of it would be
soft at every size. The mark was measured off it and then **rebuilt as
construction geometry** in `assets/brand/ownhub-mark.svg`: one circle with a
thick stroke, one blade made of two quadratic Beziers, and a mask that cuts
the blade's clearance out of the ring. The file carries its own construction
numbers. No pixel of the JPEG is in this repository.

| What | Licence | Where the text lives |
|---|---|---|
| `assets/brand/ownhub-mark.svg` | original, the project's | drawn from construction values, not traced |
| `assets/brand/ownhub-lockup.svg` | original, the project's, plus Rubik outlines (below) | same file, commented |
| `assets/icon/icon-1024.png`, `assets/icon/icon-foreground.png` | original, the project's | rendered from the SVG master by `tool/render_brand_icons.py` |
| `assets/icon/icon-1024-previous.png`, `assets/icon/icon-foreground-previous.png` | original, the project's | the "OH" monogram these replaced, kept rather than deleted |
| every `ios/.../AppIcon.appiconset/*.png` and `android/.../ic_launcher*.png` | original, the project's | generated by `flutter_launcher_icons`, then redrawn from the same SVG at each size |

The wordmark in `ownhub-lockup.svg` is **Rubik Medium (500) converted to
outlines**. Rubik is SIL Open Font Licence 1.1, already bundled here with its
licence text at `assets/fonts/OFL-Rubik.txt`. The OFL covers the font
software; it does not reach the documents or artwork made with the font, so
outlines of "OWN HUB" in an SVG carry no onward obligation, carry no Reserved
Font Name, and need no attribution on anything they are printed on. The
attribution is recorded here anyway, because the next person to ask should not
have to work it out again.

Two things that were deliberately **not** done, and should stay not done:

1. Nothing was traced, cropped or upscaled out of the identity sheet. If the
   mark ever needs changing, change the numbers in the SVG and re-render.
2. No font was added. The sheet's wordmark is a wider geometric face than
   Rubik and nothing in this repository matches it exactly; a closer match was
   not worth a typeface with an unclear licence, and a bundled font is a
   licence obligation that travels with every build.

---

The row that used to be open here is closed. Rubik's OFL text was missing from
`assets/fonts/` while the family was bundled; it now sits at
`assets/fonts/OFL-Rubik.txt` beside the other two and is registered in
`main.dart`, so the notice travels with the font as the OFL requires.

## 1 October 2026: the originals are back, by the owner's decision

The owner reviewed the painted marks and chose to ship the original
illustrations from `Icons.pdf` and `More icons.pdf` instead. Thirty two of
them are bundled again, one per name in `lib/theme/app_art.dart`, at 1x, 2x and
3x. The other twenty five from the old pack stay out of the binary.

Running, dance, strong_arms, squat_weights, lunge_kneeling, lunge_warrior,
plank, stretch_seated, side_stretch, rest_floor, meditation, overhead_raise,
dumbbells, boxing_gloves, yoga_mat, trainers, gym_bag, spin_bike, headphones,
bowl_salad, buddha_bowl, plate_mixed, steak, toast_egg, breakfast, bruschetta,
pasta, fruit_basket, apple, grapes, watermelon, nuts.

What this does not change: no licence document for these files has been found
in the repository. The risk described above is accepted by the owner, not
resolved. Before the store submission, put the Canva account and plan the
icons were exported from (or the purchase record for each) in this file. If
that record cannot be produced, the painted marks are still in
`lib/ui/hand/art_marks.dart` and switching back is a one-line change to
`AppArt.image`.
