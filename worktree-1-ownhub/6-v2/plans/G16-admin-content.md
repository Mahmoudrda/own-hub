# G16 — Admin content console

`DECISIONS.md` **D12**. The owner asked for meals and workouts to be addable from inside the app,
with a bulk option for CSVs, videos and pictures.

**This is not an accessory to Phase 2 — it unblocks it.** `SCHEMA-SPINE.md` says
`contraindicationTags[]`, `allergens[]` and `dietTags[]` are "mandatory, not enrichment… without them
the safety rules are decorative", and none of that content exists. `P0-EAT-01` cannot pass, and the
exercise safety filter is inert, *because the library is empty*. This console is how it gets filled.

---

## 1. Who can open it

A third role, reusing D11 unchanged. `roles.held` is **server-write-only**, so a woman cannot grant
herself admin any more than she can grant herself coach. Rules gate on
`request.auth.token.admin == true` — the same custom-claim pattern already used by
`token.verified` and `token.coachV == 'active'`.

An account holding admin sees it through the same profile-picture switcher, with its own bottom
navigation: **Library · Import · Media · Export**. Four tabs, matching the trainee and coach bars.

**An admin is staff, not a member.** This console manages the content library. It is not a window
into anyone's account, and nothing in it reads `users/**`.

---

## 2. Screens — flow `admin`, ids `Z01`–`Z11`

| id | screen | what it is for |
|---|---|---|
| `Z01` | Content library | Counts per collection, and — the useful part — **how many rows are missing a mandatory safety tag** |
| `Z02` | Exercises | List, search, filter to "missing contraindication tags" |
| `Z03` | Edit exercise | One move: names, equipment, pattern, contraindication tags, media |
| `Z04` | Foods | List, search, filter to "missing allergens" |
| `Z05` | Edit food | Names, portions, macros, allergens, diet tags |
| `Z06` | Recipes | List and edit; same tags as foods |
| `Z07` | Programmes | The starting programmes O05 offers |
| `Z08` | Bulk import | Choose a CSV, see the column mapping |
| `Z09` | Import check | The dry run: what would change, and every row that fails, with its reason |
| `Z10` | Media library | Bulk upload videos and pictures, link them to a row |
| `Z11` | Export | Choose collections, get CSVs and a media bundle |

`Z01` is the landing tab. It leads with what is *missing* rather than what exists, because an
incomplete library is the failure mode that matters and a count of rows hides it.

---

## 3. Bulk import

### 3.1 Dry run, then commit. Never partially applied.

`Z08` → `Z09` → commit. The file is parsed and validated **in full** before anything is written. If
any row fails, nothing is written at all.

This is not fastidiousness. A half-imported food library, where some rows lack `allergens[]`, is
**worse than no import**: the gaps are invisible in the UI, and `AllergyGuard` reads a missing tag as
*unknown, therefore unsafe*, so it fails closed and starts interrupting women who have no allergy.
An import that stops and names its bad rows is recoverable; one that half-succeeded is not.

### 3.2 Missing is not the same as none

A mandatory safety column must carry an **explicit** value. `none` is valid and means "this contains
no allergens". Empty is **rejected**, named row by row at `Z09`.

That distinction is the whole safety model: the guard cannot tell a blank cell from a food nobody got
round to tagging, so the importer refuses to create blanks.

### 3.3 Content is bilingual in the CSV, not in the dictionary

`HANDOFF.md` is explicit that the library carries its own display text because it is **content from a
build-time bundle, not copy from the dictionary**. So every CSV carries `name_en` and `name_ar`, and
none of this passes through `6-v2/i18n/` or the ARB.

### 3.4 The four schemas

Pipe-separated for list columns. `id` is stable and is what an update matches on.

```
exercises.csv
  exerciseId, name_en, name_ar, equipment, pattern,
  contraindicationTags, quiet, floorOnly, videoFile, thumbFile

foods.csv
  foodId, name_en, name_ar, portions, kcal, proteinG, carbsG, fatG,
  allergens, dietTags

recipes.csv
  recipeId, name_en, name_ar, minutes, ingredients, allergens, dietTags, photoFile

programs.csv
  programId, name_en, name_ar, weeks, daysPerWeek, sessionLength, quiet, equipment
```

`videoFile` / `thumbFile` / `photoFile` name a file in the media upload, resolved at commit. A row
naming a file that was never uploaded is a validation failure, not a broken link discovered later by
a woman mid-workout.

### 3.5 Validation rules

| rule | why |
|---|---|
| `allergens` non-empty on every food and recipe | spine: mandatory, not enrichment |
| `contraindicationTags` non-empty on every exercise | spine: same |
| `name_en` and `name_ar` both present | the library is bilingual content |
| ids unique within the file, and stable across imports | an id that moves repoints every reference to it |
| every named media file exists in the upload | a dead link reaches her as a workout that will not play |
| macros numeric and non-negative | |
| unknown columns rejected, not ignored | a typo in a header silently dropping `allergens` is the exact failure this console exists to prevent |

---

## 4. Media

Videos and pictures go to **Cloud Storage**, never to Firestore.

**There is no `firebase/storage.rules` in this repo at all** — it has to be created. Paths:

```
content/exercises/{exerciseId}/{file}     admin write, signed-in read
content/recipes/{recipeId}/{file}         admin write, signed-in read
content/programs/{programId}/{file}       admin write, signed-in read
```

Read is `signedIn()`, not public: this is a women-only product and the library is behind the gate
like everything else.

`Z10` uploads a batch, shows which files are still unlinked, and links them by filename to the ids the
CSV named.

---

## 5. Export

**Content only. Never her.**

The export produces one CSV per collection, in exactly the import schema — so an export can be edited
and re-imported — plus the media referenced by those rows.

### What it may never touch

No export path may reach `users/**`, cycle data, check-ins, measurements, progress photos, meal or
session logs, phone numbers, names, or verification results.

This product tells her that her ID photo and selfie are deleted and that her logs are never shown to
members. An admin bulk-export of user media would make both statements false. Under PDPL it is also
the difference between exporting a content catalogue and exporting regulated personal data, some of
it biometric.

**A test asserts the export manifest contains no `users/` path**, in the same spirit as the guard that
makes a daily streak unstorable: the rule is enforced by the code being unable to express the
violation, not by remembering.

If an export of a woman's own data is ever needed — a PDPL data-subject request — that is `A02`'s
"download everything", it belongs to her, and it is not an admin feature.

---

## 6. Rules to add

### Firestore

`isAdmin()` beside the existing `isVerified()` / `isCoach()` helpers, then the four content
collections change from `allow write: if false` to `allow write: if isAdmin()`. Read stays
`signedIn()`.

`SCHEMA-SPINE.md` is amended: those four are no longer READ-ONLY but **admin-write,
everyone-else-read**.

The single-`match`-block invariant is untouched — these are top-level collections, not
`users/{uid}` subcollections.

### Storage

New file, as above. Admin write, signed-in read, and **nothing under `content/` may be world-readable**.

---

## 7. Test cases

| what it proves |
|---|
| A non-admin cannot write `exercises`, `foods`, `recipes` or `programs` — rules test |
| A non-admin cannot reach any `Z` screen |
| An import with one invalid row writes **nothing** |
| A food row with an empty `allergens` cell is rejected; `none` is accepted |
| An exercise row naming a media file that was not uploaded is rejected |
| A re-import with the same ids updates rather than duplicating |
| The export round-trips: export → import produces an identical library |
| **The export manifest contains no `users/` path** |
| The console renders right-to-left in Arabic like every other screen |

---

## 8. Open, and not for me to decide

- **Who holds admin.** Setting `token.admin` is a server operation and needs an owner process — who
  grants it, who revokes it, and what happens when a staff member leaves.
- **Whether import runs client-side or through a Cloud Function.** A large CSV plus media is a poor
  fit for a phone on Egyptian mobile data. The screens are the same either way; the commit step is
  not. Recommendation: validate on device for instant feedback, commit through a Function.
- **Retention of an export.** A downloaded content bundle is not personal data, but it is still the
  product's whole library sitting on someone's laptop.
