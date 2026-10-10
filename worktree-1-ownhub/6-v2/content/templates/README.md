# Content templates

The exact columns the admin bulk importer (`Z08` → `Z09`) accepts. Plan: `6-v2/plans/G16-admin-content.md`.

Every file here is a working example, not a sketch — fill in more rows and import it.

## The rules that will reject your file

The importer validates the **whole file** before writing anything. If one row fails, nothing is
written. A half-imported library is worse than none, because the gaps are invisible and the safety
guards read a missing tag as *unknown, therefore unsafe*.

- **`allergens` and `contraindicationTags` may never be blank.** Write `none` when there genuinely
  are none. Blank is rejected — the guard cannot tell an untagged row from a safe one, so it refuses
  to create the ambiguity.
- **Both `name_en` and `name_ar` are required.** The library is bilingual content and does not pass
  through the app's translation dictionary.
- **List columns are pipe-separated**: `dumbbell|barbell`, `vegetarian|vegan`.
- **Ids are stable.** Re-importing a row with an existing id updates it; changing an id creates a new
  row and orphans everything that referenced the old one.
- **Unknown column headers are rejected, not ignored.** A typo like `allergen` silently dropping the
  `allergens` column is exactly the failure this refuses to allow.
- **Every media file named must be in the upload.** A row pointing at a missing video is rejected
  here, rather than reaching a woman mid-workout as a clip that will not play.

## Why the tags are mandatory

`SCHEMA-SPINE.md`: "`contraindicationTags[]`, `allergens[]` and `dietTags[]` are **mandatory, not
enrichment** … without them the safety rules are decorative." Knowing a dish is koshari does not tell
the app whether it contains nuts, and knowing a move is a squat does not tell it whether it loads the
pelvic floor.
