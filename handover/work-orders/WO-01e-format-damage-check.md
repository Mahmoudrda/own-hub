# WO-01e: check the tree for formatting damage before anything is committed
Depends on: WO-01a, WO-01b, WO-01c
Size: S (under 1 hour)
Reads first:
- `git status --short` (run it; the list changes while builders work)
- `6-v2/src/build-flutter.mjs` lines 849-885 (the files this script writes into `app/`)

## Why
The earlier kitten builder may have run `dart format` over files it did not otherwise change, which buries real changes in a commit under whitespace. The check below compares, for every changed Dart file, the size of the diff as it is with the size of the diff after both sides are formatted. A file whose raw diff is 20 or more lines larger than its formatted diff is formatting damage.

Result of that check on the tree today (26 Oct 2026, 109 changed Dart files): exactly one file, `app/lib/theme/app_tokens.dart`, with a 203-line diff against 0 real changes. It is a generated file (`6-v2/src/tokens.mjs` through `build-flutter.mjs`); the committed version equals what the generator writes (checked: zero differences), and the tree version is a `dart format` of it. Reverting it is the right fix, and WO-01b step 5 already does it, because `build-flutter.mjs` copies its own output over the file. This order proves that happened and nothing else is damaged.

Two facts that follow, so nobody "fixes" them:
- `dart format --set-exit-if-changed lib` will report `app_tokens.dart` as changed once it is reverted. That is how it is committed at HEAD and it is not part of any gate (`app/tool/release_preflight.sh` does not run `dart format`).
- `app/lib/routing/app_routes.dart` is also generated but is committed formatted. `build-flutter.mjs` writes it unformatted. WO-01b step 6 formats it again. The check at the end of this order proves it.

## Final result
A short report: the output of the damage script, the output of the two `git diff --stat` checks, and either "no damage" or the list of files you reverted.

## Files to edit or create
None, unless the script lists a file other than `app_tokens.dart` (see step 3).

## Steps
1. Run the damage script. From `~/ownhub`, paste this whole block into the shell:
```
python3 - <<'PY'
import subprocess, os, difflib
def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, errors='ignore', **kw)
def fmt(src):
    r = run(['dart', 'format', '--output=show', '--summary=none'], input=src)
    return r.stdout if r.returncode == 0 else None
def changed_lines(a, b):
    return sum(1 for l in difflib.unified_diff(a.splitlines(), b.splitlines(), lineterm='', n=0)
               if l[:1] in '+-' and l[:3] not in ('+++', '---'))
bad = []
for f in run(['git', 'diff', '--name-only']).stdout.split():
    if not f.endswith('.dart') or '/l10n/' in f or not os.path.exists(f):
        continue
    old = run(['git', 'show', 'HEAD:' + f]).stdout
    new = open(f, encoding='utf8').read()
    raw = changed_lines(old, new)
    real = changed_lines(fmt(old) or old, fmt(new) or new)
    if raw - real >= 20:
        bad.append((f, raw, real))
print('FORMAT-ONLY DAMAGE (file, raw diff lines, real diff lines):')
for row in sorted(bad, key=lambda r: r[2] - r[1]):
    print('  ', row)
print('files with damage:', len(bad))
PY
```
   Expected output after WO-01b is done:
   ```
   FORMAT-ONLY DAMAGE (file, raw diff lines, real diff lines):
   files with damage: 0
   ```
   (Before WO-01b it lists `('app/lib/theme/app_tokens.dart', 203, 0)`.)
2. Prove the two generated files are as intended:
   ```
   cd ~/ownhub && git diff --stat -- app/lib/theme/app_tokens.dart
   cd ~/ownhub && git diff --stat -- app/lib/routing/app_routes.dart
   ```
   The first prints nothing. The second prints `1 file changed, 2 insertions(+), 4 deletions(-)` (the removal of screen R13).
3. If step 1 lists any file other than `app_tokens.dart`: do not guess. For each such file, run `git diff -w --stat -- <file>` and `git diff --stat -- <file>`, and write both numbers, the file name and the script's two numbers into your report and into `handover/QUESTIONS.md`. Do not revert it: a file can have real changes mixed with the reformatting, and `git checkout` would delete the real ones.
4. Check that no stray scratch test file is in the tree: `git status --short | grep "zz_"`. Expected: one line, `?? app/test/zz_probe_parser_test.dart` (it belongs to another session's probe, it is not product code). Do not delete it and do not stage it. If other `zz_` files show up that you created, delete those.

## Strings to add
None.

## Tests to add or change
None.

## Verify
- Step 1 prints `files with damage: 0`.
- Step 2: first command prints nothing; second prints exactly the 2 insertions and 4 deletions line.
- `cd ~/ownhub/app && dart format --output=none lib test 2>&1 | grep -v zz_probe` lists no file except possibly `Changed lib/theme/app_tokens.dart` (only if it shows because the revert happened; this is expected and fine).

## Do not
- Do not run `dart format` on the whole `lib` or `test` folder. It would recreate the damage in the other direction.
- Do not run `git checkout` or `git restore` on any file except `app/lib/theme/app_tokens.dart`, and only if step 2's first command printed something.
- Do not stage anything yet (that is WO-01g).

## Done checklist
- [ ] Damage script output pasted in the report
- [ ] Both `git diff --stat` checks as expected
- [ ] `zz_` files accounted for

## If stuck
The script crashes or `dart` is not found: run `which dart` (expected `/Users/mahmoudreda/development/flutter/bin/dart`) and stop; write the question to `handover/QUESTIONS.md` and move to WO-01f.
