# WO-01b: remove the unused string `n31212Kg` and the stale kitten strings
Depends on: none (run after WO-01a so test runs are clean)
Size: S (under 1 hour)
Reads first:
- `6-v2/i18n/msa/02.json` lines 82-86
- `6-v2/i18n/strings.json` lines 1665-1675
- `6-v2/src/build-flutter.mjs` lines 845-890 (the write-through to `app/`)
- `app/tool/add_strings.py` lines 1-40 (how strings reach the app)

## Why
Batch A removed screen R13 ("Move logged") from the wireframe. The build review listed two strings that nothing uses any more: `finishHere` and `n31212Kg` ("3 × 12 · 12 kg", the R13 row for the Goblet squat). Checked on the current tree:
- `finishHere` is already gone from `app/lib/l10n/app_en.arb`, `app_ar.arb`, `6-v2/i18n/strings.json`, `6-v2/i18n/ar.json`, `6-v2/i18n/msa/08.json`. Nothing to do.
- `n31212Kg` is still in `app/lib/l10n/app_en.arb` line 305, `app/lib/l10n/app_ar.arb` line 305, `6-v2/flutter/app_en.arb`, `6-v2/flutter/app_ar.arb`, and in the generated `app/lib/l10n/app_l10n.dart` (line 1916), `app_l10n_en.dart` (line 943) and `app_l10n_ar.dart` (line 943). No file under `app/lib` outside `l10n/` uses it, and no wireframe screen renders the bare text "3 × 12 · 12 kg" any more (the string "Goblet squat · 3 × 12 · 12 kg" in `6-v2/src/screens-coachplan.mjs:58` is a different string and stays).
- The arb files are generated from `6-v2/i18n/ar.json`, which `6-v2/src/merge-i18n.mjs` builds from `6-v2/i18n/msa/*.json` and `6-v2/i18n/ar-extra.json`. So the source line to delete is in `msa/02.json`, not in the arb files (a hand edit of the arb would come back at the next build).
- Side effect, wanted: `6-v2/flutter/app_en.arb` and `app_ar.arb` still hold the two kitten strings (`theKittenShowsYouAroundAndMoves`, `theKittenStaysStill`) that were already removed from `ar.json` and from `app/lib/l10n`. Running the build refreshes them away.
- Left alone on purpose: `english_imxmn` ("English · العربية") is also unused by the app now (the profile language row lost its subtitle), but the wireframe screen A02 still shows that text (`6-v2/src/screens-account.mjs:25`), so it stays in the dictionary.

The build script also writes `app/lib/routing/app_routes.dart` and `app/lib/theme/app_tokens.dart`. Verified in a scratch copy: it writes them unformatted, over the files that are formatted today. Step 6 handles that.

## Final result
No screen changes. The key `n31212Kg` is gone from the 6-v2 sources, both arb pairs and the three generated Dart files. `6-v2/flutter/*.arb` no longer carry the two kitten keys. `app/lib/routing/app_routes.dart` keeps its current formatted content. `app/lib/theme/app_tokens.dart` goes back to its committed (HEAD) content.

## Files to edit or create
| path | create or edit | what changes in one line |
|---|---|---|
| 6-v2/i18n/msa/02.json | edit | delete the line `"3 × 12 · 12 kg": "3 × 12 · 12 كجم",` |
| 6-v2/i18n/strings.json | edit | delete the 4-line entry for `"3 × 12 · 12 kg"` |
| 6-v2/i18n/ar.json | generated | rebuilt by `node src/merge-i18n.mjs` |
| 6-v2/flutter/app_en.arb, app_ar.arb | generated | rebuilt by `node src/build-flutter.mjs` |
| app/lib/l10n/app_en.arb, app_ar.arb | generated | written by the same script |
| app/lib/l10n/app_l10n.dart, app_l10n_en.dart, app_l10n_ar.dart | generated | rebuilt by `flutter gen-l10n` |
| app/lib/routing/app_routes.dart | generated, then formatted | restored by `dart format` (step 6) |
| app/lib/theme/app_tokens.dart | generated | returns to HEAD content (step 6) |

(Two files are edited by hand. The rest are command output, which is why this order lists more than 8 paths.)

## Steps
1. Check the start state. From `~/ownhub`:
   ```
   grep -rn "n31212Kg" app/lib app/test 6-v2/flutter | grep -v "app/lib/l10n/app_l10n"
   ```
   Expect exactly 4 lines: `app/lib/l10n/app_en.arb:305`, `app/lib/l10n/app_ar.arb:305`, `6-v2/flutter/app_en.arb:305`, `6-v2/flutter/app_ar.arb:305`. If any line is under `app/lib/features`, `app/lib/routing` or `app/test`, the string is used: stop and follow "If stuck".
2. File `6-v2/i18n/msa/02.json`. Anchor: the line `"3 × 12 · 12 kg": "3 × 12 · 12 كجم",` (about line 84, unique; the line above it is `"3 × 10 · 12 kg suggested": ...` and the line below it is `"3 × 15 · 9 September · was 3 × 12": ...`). Delete that one line. Before:
   ```
    "3 × 10 · 12 kg suggested": "3 × 10 · مقترح 12 كجم",
    "3 × 12 · 12 kg": "3 × 12 · 12 كجم",
    "3 × 15 · 9 September · was 3 × 12": "3 × 15 · 9 سبتمبر · كان 3 × 12",
   ```
   After:
   ```
    "3 × 10 · 12 kg suggested": "3 × 10 · مقترح 12 كجم",
    "3 × 15 · 9 September · was 3 × 12": "3 × 15 · 9 سبتمبر · كان 3 × 12",
   ```
3. File `6-v2/i18n/strings.json`. Anchor: the entry whose `"s"` is exactly `"3 × 12 · 12 kg",` (about line 1671; do not touch the entry `"Goblet squat · 3 × 12 · 12 kg"` at about line 3603). Delete these four lines (1670-1673 in the file as it is today):
   ```
    {
     "s": "3 × 12 · 12 kg",
     "n": 1
    },
   ```
   Check the JSON still parses: `python3 -c "import json;json.load(open('6-v2/i18n/strings.json'));json.load(open('6-v2/i18n/msa/02.json'))"` prints nothing.
4. Rebuild the dictionary. From `~/ownhub/6-v2`: `node src/merge-i18n.mjs`. Expected first two lines:
   ```
   source files: 14 | dictionary entries: 4243
   strings on screens now: 1831 | covered: 1813 | missing: 18
   ```
   (Before this order it said 4244, 1832, 1814, 18. The 18 missing are old and unrelated, such as the single word `On`.)
5. Rebuild the arb files and copy them into the app. From `~/ownhub/6-v2`: `node src/build-flutter.mjs`. Expected last lines:
   ```
   ARB files written: 4243 strings
   tokens and routes written for 196 screens
     synced -> app/lib/l10n/app_en.arb
     synced -> app/lib/l10n/app_ar.arb
     synced -> app/lib/routing/app_routes.dart
     synced -> app/lib/theme/app_tokens.dart
   app files synced: 4
     ARB changed — run `flutter gen-l10n` in app/ to regenerate AppL10n
   ```
6. Put the formatting right again. From `~/ownhub/app`:
   ```
   dart format lib/routing/app_routes.dart
   git diff --stat -- lib/theme/app_tokens.dart
   ```
   The second command must print nothing (the script wrote back exactly what is committed, which removes the 203-line whitespace-only change that was in the tree). `app_routes.dart` must show the same 3-line change as before this order (`git diff --stat -- lib/routing/app_routes.dart` says `1 file changed, 2 insertions(+), 4 deletions(-)`, the R13 removal).
7. Regenerate the Dart strings. From `~/ownhub/app`: `flutter gen-l10n`. Then run the checks in "Verify".

## Strings to add
None. One string is removed.

| key | English | Egyptian Arabic |
|---|---|---|
| n31212Kg (removed) | 3 × 12 · 12 kg | 3 × 12 · 12 كجم |

## Tests to add or change
None. The existing suites prove nothing else reads the key: `flutter analyze` fails on a missing getter, and the screens that print strings are covered by the full run in WO-01f.

## Verify
1. `cd ~/ownhub && grep -rn "n31212Kg" app 6-v2 | grep -v "/build/"` prints nothing.
2. `cd ~/ownhub && grep -rn "theKittenShowsYouAroundAndMoves\|theKittenStaysStill" app/lib 6-v2/flutter` prints nothing.
3. `cd ~/ownhub && git diff --stat -- app/lib/theme/app_tokens.dart` prints nothing.
4. `cd ~/ownhub/app && flutter analyze lib test` ends with `No issues found!`.
5. `cd ~/ownhub/app && flutter test test/release_readiness_test.dart test/baked_in_samples_test.dart` ends with `All tests passed!`.
6. `cd ~/ownhub && grep -c "\"finishHere\"" app/lib/l10n/app_en.arb app/lib/l10n/app_ar.arb` prints `app/lib/l10n/app_en.arb:0` and `app/lib/l10n/app_ar.arb:0` (the other half of the review item stays gone).

## Do not
- Do not edit the arb files or `app_l10n*.dart` by hand.
- Do not run `node src/extract-strings.mjs`. It rewrites all of `strings.json` and would add or remove unrelated lines.
- Do not delete `english_imxmn` or any other unused key. The tree has about 810 old unused keys that are not part of this review.
- Do not commit the `6-v2/flutter/app_tokens.dart` file if `git status` lists it; it must be unchanged.
- No em dashes in any string.

## Done checklist
- [ ] Start state check showed the 4 expected lines
- [ ] Both source lines deleted and both JSON files parse
- [ ] `merge-i18n` and `build-flutter` printed the expected numbers
- [ ] `app_routes.dart` formatted again, `app_tokens.dart` has no diff
- [ ] `flutter gen-l10n` ran
- [ ] Verify 1 to 6 all as described

## If stuck
The numbers in step 4 or 5 differ (for example 4244 instead of 4243): the line was not deleted or another builder added a string meanwhile; compare `git diff 6-v2/i18n/ar.json | head -40` and stop. Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-01c.
