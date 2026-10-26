# WO-03a: Move details in the data (superset flag, rest, note, weight) and on the client's phone
Depends on: none
Size: M
Reads first: `app/lib/features/train/domain/workout_library.dart` lines 67-146 (AuthoredMove); `app/lib/features/private_coaching/presentation/plans/coach_plan_logic.dart` lines 94-308; `functions/coaching/plans.py` lines 40-106 and 135-165; `app/lib/features/train/presentation/authored_workout.dart` lines 33-70; `app/lib/features/train/domain/my_plan.dart` lines 134-158

## Why (one paragraph, product reason in plain words)
Rahma writes weight, rest, a note and "superset" on every move when she coaches. The data model and the server already carry weight (`kg` on the day), rest (`restSeconds`) and notes (`notesEn`, `notesAr`), but the coach editor has no way to set them (WO-03b adds the screen) and there is no superset flag anywhere. This order adds the flag end to end (model, server check, what the client reads) and one pure function the editor will call to change all four things at once. No screen changes here.

## Final result
- Nothing new on screen except one line on the client's move card. In a coach plan, a move with the flag shows as its first cue line: English "Superset: go straight to the next move, then rest." / Arabic "سوبر سيت: روحي على الحركة اللي بعدها علطول، وبعدين ارتاحي." (the cue list is already drawn in the workout view, see `plannedMoveFrom` in `authored_workout.dart`).
- `AuthoredMove` has a new field `supersetWithNext` (bool, default false), saved in `toJson` as `supersetWithNext`, read in `fromJson`.
- `changeMoveDetails(...)` in `coach_plan_logic.dart` sets rest, note (both languages), superset and target weight of one move in one call, with the same limits the server uses.
- The server accepts `supersetWithNext` (bool) in a move and refuses anything else as before.
- Decision recorded (owner can change it): the workout runner does NOT alternate two moves. The flag is a prescription shown to the client, like a note. Say so in the final report.

## Files to edit or create
| path | create or edit | what changes in one line |
|---|---|---|
| app/lib/features/train/domain/workout_library.dart | edit | `supersetWithNext` field, JSON, `copyWith` |
| app/lib/features/train/domain/my_plan.dart | edit | `_cleanMove` keeps the flag |
| app/lib/features/train/domain/programme_week.dart | edit | `capped` keeps the flag |
| app/lib/features/private_coaching/presentation/plans/coach_plan_logic.dart | edit | `changeMove` and `stampSafetyTags` keep the flag; new `changeMoveDetails` |
| app/lib/features/train/presentation/authored_workout.dart | edit | superset cue first in `cues` |
| functions/coaching/plans.py | edit | `_MOVE_KEYS` and bool check |
| app/test/features/private_coaching/plans/plan_logic_test.dart | edit | tests for `changeMoveDetails` |
| functions/tests/test_coaching_plans.py | edit | server test for the flag |

## Steps
1. File `app/lib/features/train/domain/workout_library.dart`, class `AuthoredMove` (about line 67). Add the constructor parameter after `this.needsEquipment = false,` (about line 83): `this.supersetWithNext = false,`. Add the field after `final bool needsEquipment;` (about line 106):
```dart
  /// She wants this move done, then the next one straight away, then the rest.
  /// A prescription shown to the member; the session runner does not alternate.
  final bool supersetWithNext;
```
In `toJson` (about line 108-124) add after `'needsEquipment': needsEquipment,`: `'supersetWithNext': supersetWithNext,`. In `fromJson` (about line 126-145) add after `needsEquipment: j['needsEquipment'] == true,`: `supersetWithNext: j['supersetWithNext'] == true,`. Then add this method before `operator ==` (about line 147):
```dart
  AuthoredMove copyWith({
    int? restSeconds,
    String? notesEn,
    String? notesAr,
    bool? supersetWithNext,
  }) => AuthoredMove(
    exerciseId: exerciseId,
    nameEn: nameEn,
    nameAr: nameAr,
    sets: sets,
    reps: reps,
    holdSeconds: holdSeconds,
    restSeconds: restSeconds ?? this.restSeconds,
    notesEn: notesEn ?? this.notesEn,
    notesAr: notesAr ?? this.notesAr,
    safetyEn: safetyEn,
    safetyAr: safetyAr,
    contraindications: contraindications,
    quiet: quiet,
    floorOnly: floorOnly,
    needsEquipment: needsEquipment,
    supersetWithNext: supersetWithNext ?? this.supersetWithNext,
  );
```
2. File `app/lib/features/train/domain/my_plan.dart`, function `_cleanMove` (about line 134), the `return AuthoredMove(` block ends with `needsEquipment: m.needsEquipment,` (about line 157). Add after it: `supersetWithNext: m.supersetWithNext,`.
3. File `app/lib/features/train/domain/programme_week.dart`, local function `capped` inside `scaleSession` (about line 62-78). After `needsEquipment: m.needsEquipment,` (about line 77) add `supersetWithNext: m.supersetWithNext,`.
4. File `app/lib/features/private_coaching/presentation/plans/coach_plan_logic.dart`. (a) In `changeMove` (about line 176-213) replace the whole `final next = AuthoredMove(...)` block (lines 189-210) with a copy that keeps every field:
```dart
  final next = AuthoredMove(
    exerciseId: m.exerciseId,
    nameEn: m.nameEn,
    nameAr: m.nameAr,
    sets: (sets ?? m.sets).clamp(kMinSets, kMaxSets),
    reps: timed ? null : (reps ?? m.reps ?? 10).clamp(kMinReps, kMaxReps),
    holdSeconds: timed
        ? (holdSeconds ?? m.holdSeconds ?? 30).clamp(
            kMinHoldSeconds,
            kMaxHoldSeconds,
          )
        : null,
    restSeconds: m.restSeconds,
    notesEn: m.notesEn,
    notesAr: m.notesAr,
    safetyEn: m.safetyEn,
    safetyAr: m.safetyAr,
    contraindications: m.contraindications,
    quiet: m.quiet,
    floorOnly: m.floorOnly,
    needsEquipment: m.needsEquipment,
    supersetWithNext: m.supersetWithNext,
  );
```
(b) In `stampSafetyTags` (about line 266-283) add `supersetWithNext: m.supersetWithNext,` after `needsEquipment: m.needsEquipment,` (about line 282). (c) Add this new function after `removeMove` (after about line 226):
```dart
/// Move [move] of day [i] with a new rest, note, superset flag and target
/// weight. Pass only what changes. [clearKg] says "no target weight"
/// (bodyweight). The note is written in both languages, the way a day name is.
MyPlan changeMoveDetails(
  MyPlan plan,
  int i,
  int move, {
  int? restSeconds,
  String? note,
  bool? superset,
  double? kg,
  bool clearKg = false,
}) {
  if (i < 0 || i >= plan.days.length) return plan;
  final session = plan.days[i].session;
  if (move < 0 || move >= session.moves.length) return plan;
  final clean = note == null ? null : cleanNoteText(note);
  final next = session.moves[move].copyWith(
    restSeconds: restSeconds?.clamp(0, WorkoutLimits.maxRestSeconds),
    notesEn: clean,
    notesAr: clean,
    supersetWithNext: superset,
  );
  final moves = [...session.moves]..[move] = next;
  final targets = [...plan.days[i].targetKg]..length = session.moves.length;
  if (clearKg) {
    targets[move] = null;
  } else if (kg != null && kg >= kMinWeightKg) {
    targets[move] = kg.clamp(kMinWeightKg, kMaxWeightKg).toDouble();
  }
  return _withDay(plan, i, _sessionWith(session, moves: moves), kg: targets);
}

/// A note as one tidy line of at most the server's limit.
String cleanNoteText(String text) {
  final one = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length > WorkoutLimits.maxText
      ? one.substring(0, WorkoutLimits.maxText).trim()
      : one;
}
```
`WorkoutLimits`, `kMinWeightKg` and `kMaxWeightKg` are already imported through `workout_library.dart` and `custom_workout.dart` (both imported at the top of this file, lines 20 and 24). UNVERIFIED that `WorkoutLimits.maxText` is public: verify with `grep -n "maxText\|maxRestSeconds" app/lib/features/train/domain/workout_library.dart` (it printed lines 59 and 63 in the research).
5. File `app/lib/features/train/presentation/authored_workout.dart`, function `plannedMoveFrom`, the `cues:` list (about line 56-63). Replace:
```dart
    cues: [
      for (final text in [
        _pick(languageCode, move.safetyEn, move.safetyAr),
        _pick(languageCode, move.notesEn, move.notesAr),
      ])
        if (text.trim().isNotEmpty) text.trim(),
    ],
```
with:
```dart
    cues: [
      for (final text in [
        _pick(languageCode, move.safetyEn, move.safetyAr),
        if (move.supersetWithNext) l10n.supersetGoStraightToTheNextMove,
        _pick(languageCode, move.notesEn, move.notesAr),
      ])
        if (text.trim().isNotEmpty) text.trim(),
    ],
```
The getter name `supersetGoStraightToTheNextMove` is what `add_strings.py` prints for the string below. If it prints another name, use that name.
6. File `functions/coaching/plans.py`. In `_MOVE_KEYS` (about line 65-68) add `"supersetWithNext"` to the set. In `_check_move` (about line 137) change `for key in ("quiet", "floorOnly", "needsEquipment"):` to `for key in ("quiet", "floorOnly", "needsEquipment", "supersetWithNext"):`.
7. Add the strings (next section), then run `flutter gen-l10n` (done by the script).

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| supersetGoStraightToTheNextMove | Superset: go straight to the next move, then rest. | سوبر سيت: روحي على الحركة اللي بعدها علطول، وبعدين ارتاحي. |

Command: write `/tmp/ownhub-wo03a.json` as `{"strings": {"Superset: go straight to the next move, then rest.": "سوبر سيت: روحي على الحركة اللي بعدها علطول، وبعدين ارتاحي."}}` then `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03a.json && flutter gen-l10n`.

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| app/test/features/private_coaching/plans/plan_logic_test.dart | `changeMoveDetails sets rest, note, superset and kg` | Arrange: `planFromSplit(...)` from the helper in `plans_support.dart` (open it first and use its split builder, UNVERIFIED name: `grep -n "AuthoredProgramme\|MyPlan" app/test/features/private_coaching/plans/plans_support.dart`). Act: `changeMoveDetails(plan, 0, 0, restSeconds: 120, note: '  slow   down ', superset: true, kg: 12.5)`. Assert: move 0 has `restSeconds == 120`, `notesEn == 'slow down'`, `notesAr == 'slow down'`, `supersetWithNext == true`, day 0 `targetKg[0] == 12.5`, `revision` is one higher, and move 1 is untouched. |
| same | `changeMoveDetails clamps and clears` | Act: rest 9999, kg 500 -> assert rest 600, kg 200. Then `clearKg: true` -> `targetKg[0] == null`. Out-of-range day or move index returns the same plan object (`identical`). |
| same | `changeMove keeps the superset flag` | Set the flag, then `changeMove(..., sets: 5)`; assert flag still true and `stampSafetyTags` keeps it. |
| functions/tests/test_coaching_plans.py | `test_superset_flag_is_accepted_and_must_be_a_bool` | Build `workout()` body, set `body["days"][0]["session"]["moves"][0]["supersetWithNext"] = True`; `publish(db, req(body=body))` succeeds. Set it to `"yes"`: `refused(db, req(body=body), errors.PLAN_INVALID)`. |

Run: `cd app && flutter test test/features/private_coaching/plans/plan_logic_test.dart` and `cd functions && .venv/bin/python -m pytest tests/test_coaching_plans.py -q`.

## Verify
- `cd app && flutter analyze lib/features/train lib/features/private_coaching` prints `No issues found!`.
- The two commands above end with `All tests passed!` and `passed` with 0 failed.
- `grep -n "supersetWithNext" app/lib functions/coaching` shows hits in the 6 source files listed.

## Do not
- Do not change `restSeconds` defaults or the 3 starting programmes' content.
- Do not touch the workout runner (`workout_session_state.dart`); superset is a cue only.
- No em dashes in strings. Do not commit or push.

## Done checklist
- [ ] Flag in model, JSON, server
- [ ] `changeMoveDetails` and `cleanNoteText` added
- [ ] Client cue shows
- [ ] Tests pass, analyze clean

## If stuck
An anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-03c, which does not depend on this order.
