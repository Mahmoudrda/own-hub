# Where every illustration in this app comes from

**Status: resolved. Every illustration in Own Hub is original to this project,
drawn in code, and carries no third-party licence.**

This directory holds this file and nothing else. There is no image asset in it,
`pubspec.yaml` bundles no illustration, and `app_art_test.dart` fails the build
if either of those changes.

## Where the illustrations actually are

`app/lib/ui/hand/art_marks.dart` — 32 marks drawn as `CustomPainter` paths in
the app's hand-drawn language, seeded from their own name so each one wobbles
identically on every draw, coloured from the theme, wrapped in
`ExcludeSemantics`, and costing zero bytes of binary asset. Six of the food
marks delegate to `app/lib/ui/hand/food_marks.dart`, which drew the recipe-card
shapes the same way and for the same reason.

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

# History: why the previous set was removed

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

## The rule this leaves behind

**Do not add a bundled illustration to this app.** If one is ever genuinely
needed:

1. Its licence must be named in this file, with its source and acquisition
   date, before it is committed.
2. A free tier is not a licence. Read the actual agreement, and read the clause
   about stand-alone assets and sublicensing in particular.
3. Share-alike licences are out. OpenMoji is CC BY-SA 4.0; share-alike on an
   app's bundled assets is a problem nobody wants to discover after launch.
4. If it can be drawn instead, draw it. `art_marks.dart` shows how, and the
   whole 4.8 MB this repository used to carry is what that saved.

## Everything else third-party in this repository, and its licence

| What | Licence | Where the text lives |
|---|---|---|
| Aref Ruqaa (Arabic hand face) | SIL Open Font Licence 1.1 | `assets/fonts/OFL-ArefRuqaa.txt`, registered in `main.dart` so it shows on the licences page |
| La Belle Aurore (Latin hand face) | SIL Open Font Licence 1.1 | `assets/fonts/OFL-LaBelleAurore.txt`, registered in `main.dart` |
| Rubik (interface face) | SIL Open Font Licence 1.1 | shipped subset; the licence text still needs to sit beside the other two |
| ML Kit face-detection models | Google ML Kit terms, via the `google_mlkit_face_detection` package | the package's own licence, surfaced by `LicenseRegistry` |
| Dart and Flutter packages | their own, all surfaced by `LicenseRegistry` on the licences page | `pubspec.lock` |
| `assets/icon/icon-1024.png` | original to this project — a typographic monogram, not stock | no licence needed |
| `assets/content/rahma_recipes.json` | the owner's own writing, extracted from her book by `tool/extract_rahma_book.py` | owner's, no third party |

One row above is still open: **Rubik's OFL text is not in `assets/fonts/`** even
though the family is bundled and the other two hand faces have theirs. That is a
missing file, not a licence problem — Rubik is OFL 1.1 and the licence permits
the use — but the OFL requires the notice to travel with the font, so the text
should be added beside the other two and registered in `main.dart` with them.
