# WO-03b: Weight, rest, note and superset in Rahma's day editor
Depends on: WO-03a
Size: M
Reads first: `app/lib/features/private_coaching/presentation/plans/coach_day_editor_view.dart` (all 360 lines); `app/lib/ui/app_sheet.dart` (the `showAppSheet` signature); `app/lib/ui/app_field.dart` (constructor parameters); `app/test/features/private_coaching/plans/plan_screens_test.dart` (how the day editor is pumped)

## Why
Rahma builds a day by picking moves, then she needs to say how heavy, how long to rest, a short note, and whether two moves are a superset. Today the move card only has sets and reps (or a hold). She must not be sent to another app for the rest.

## Final result
Screen: the day editor (title is the day's name). Top to bottom: day name field, then one card per move, then the footer button.
Each move card keeps what it has (name, clip button, sets stepper, reps or hold stepper, up, down, remove) and gains ONE control in the bottom row: a text button "Move details" / "تفاصيل الحركة" between the arrows and the bin. Under the stepper line it shows a one-line summary only when something is set, for example `12.5 kg · Rest 90 seconds · Superset` / `12.5 كجم · راحة 90 ثانية · سوبر سيت` (use existing strings `l10n.kg`, `l10n.restSecondsSeconds(n)`; the word Superset is the new string below).
Tapping "Move details" opens a bottom sheet (`showAppSheet`), top to bottom:
1. Title: the move's name.
2. Field "Target weight (kg)" / "الوزن المطلوب (كجم)", hint "Leave empty for bodyweight" / "سيبيها فاضية لو بوزن الجسم". Decimal keyboard, max 6 characters.
3. Rest stepper, label `l10n.restBetweenSets` (existing), minus and plus change by 15 seconds, 0 to 600, value shown as `l10n.restSecondsSeconds(n)`.
4. Field "Note for her" / "ملاحظة ليها", up to 300 characters, 3 lines.
5. Switch row "Superset with the next move" / "سوبر سيت مع الحركة اللي بعدها" (disabled on the last move of the day).
6. One filled button "Save details" / "حفظ التفاصيل".
Budget: the sheet has 1 filled primary and 4 other controls (weight, rest steppers count as one stepper pair, note, switch). Tap path to set a weight on a move: Move details (1), tap the weight field and type (2), Save details (3) = 3 taps.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| app/lib/features/private_coaching/presentation/plans/coach_day_editor_view.dart | edit | "Move details" button, summary line, `_MoveDetailsSheet` |
| app/test/features/private_coaching/plans/plan_screens_test.dart | edit | 3 widget tests |

## Steps
1. File `coach_day_editor_view.dart`, add imports after line 28: `import '../../../../ui/app_sheet.dart';` and `import '../../../train/domain/workout_library.dart' show AuthoredMove, WorkoutLimits;` (replace the existing line 25 `show AuthoredMove` import with this one so there is only one).
2. In `_CoachDayEditorViewState` add after `_watch` (about line 114):
```dart
  Future<void> _details(int m) async {
    final plan = _plan;
    final i = widget.dayIndex;
    final day = plan.days[i];
    final move = day.session.moves[m];
    final lang = Localizations.localeOf(context).languageCode;
    await showAppSheet<void>(
      context: context,
      children: [
        _MoveDetailsSheet(
          title: lang == 'ar' && move.nameAr.isNotEmpty
              ? move.nameAr
              : move.nameEn,
          kg: day.kgAt(m),
          rest: move.restSeconds,
          note: lang == 'ar' && move.notesAr.isNotEmpty
              ? move.notesAr
              : move.notesEn,
          superset: move.supersetWithNext,
          isLast: m == day.session.moves.length - 1,
          onSave: ({kg, required rest, required note, required superset}) {
            _save(
              changeMoveDetails(
                _plan,
                i,
                m,
                restSeconds: rest,
                note: note,
                superset: superset,
                kg: kg,
                clearKg: kg == null,
              ),
            );
          },
        ),
      ],
    );
  }
```
3. In `build`, the `_MoveCard(` call (about line 153-175): add `kg: plan.days[i].kgAt(m),` and `onDetails: () => unawaited(_details(m)),` after `onWatch: ...` (about line 162).
4. In `_MoveCard` (about line 183): add constructor params `required this.kg, required this.onDetails,` and fields `final double? kg;` `final VoidCallback onDetails;`. After the `Wrap(...)` of steppers (ends about line 282) insert the summary line:
```dart
        if (kg != null || move.supersetWithNext || move.notesEn.isNotEmpty)
          Text(
            <String>[
              if (kg != null) '${weightLabel(kg!)} ${l10n.kg}',
              if (move.restSeconds > 0)
                l10n.restSecondsSeconds(countLabel(move.restSeconds)),
              if (move.supersetWithNext) l10n.superset,
            ].join(' · '),
            key: ValueKey('move-summary-$index'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
```
Add `import '../../../train/domain/weight_label.dart';` (it holds `weightLabel`, used in `authored_workout.dart` line 10 as `../domain/weight_label.dart`). In the bottom `Row` (about line 283-308) insert between the down arrow and `const Spacer(),`:
```dart
            TextButton(
              key: ValueKey('move-details-$index'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onDetails,
              child: Text(l10n.moveDetails),
            ),
```
5. Append the sheet widget at the end of the file:
```dart
class _MoveDetailsSheet extends StatefulWidget {
  const _MoveDetailsSheet({
    required this.title,
    required this.kg,
    required this.rest,
    required this.note,
    required this.superset,
    required this.isLast,
    required this.onSave,
  });

  final String title;
  final double? kg;
  final int rest;
  final String note;
  final bool superset;
  final bool isLast;
  final void Function({
    double? kg,
    required int rest,
    required String note,
    required bool superset,
  })
  onSave;

  @override
  State<_MoveDetailsSheet> createState() => _MoveDetailsSheetState();
}

class _MoveDetailsSheetState extends State<_MoveDetailsSheet> {
  late final TextEditingController _kg = TextEditingController(
    text: widget.kg == null ? '' : weightLabel(widget.kg!),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.note,
  );
  late int _rest = widget.rest;
  late bool _superset = widget.superset && !widget.isLast;

  @override
  void dispose() {
    _kg.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _kgValue {
    final v = double.tryParse(_kg.text.trim().replaceAll(',', '.'));
    return v == null || v < kMinWeightKg ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: AppText.titleL),
        AppField(
          key: const ValueKey('details-kg'),
          controller: _kg,
          label: l10n.targetWeightKg,
          hint: l10n.leaveEmptyForBodyweight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [LengthLimitingTextInputFormatter(6)],
        ),
        _Stepper(
          keyPrefix: 'details-rest',
          label: l10n.restBetweenSets,
          value: countLabel(_rest),
          onMinus: _rest <= 0
              ? null
              : () => setState(() => _rest = (_rest - 15).clamp(0, 600)),
          onPlus: _rest >= WorkoutLimits.maxRestSeconds
              ? null
              : () => setState(() => _rest = (_rest + 15).clamp(0, 600)),
        ),
        AppField(
          key: const ValueKey('details-note'),
          controller: _note,
          label: l10n.noteForHer,
          maxLines: 3,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
        ),
        SwitchListTile(
          key: const ValueKey('details-superset'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.supersetWithTheNextMove),
          value: _superset,
          onChanged: widget.isLast
              ? null
              : (v) => setState(() => _superset = v),
        ),
        AppButton(
          l10n.saveDetails,
          key: const ValueKey('details-save'),
          onPressed: () {
            widget.onSave(
              kg: _kgValue,
              rest: _rest,
              note: _note.text,
              superset: _superset,
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
```
UNVERIFIED: `AppField` parameters `hint`, `keyboardType`, `maxLines`. Verify: `sed -n 1,80p app/lib/ui/app_field.dart`. If a parameter is missing, use `TextField` with the same `InputDecoration(labelText: ..., hintText: ...)` for that one field and keep the key. `WorkoutLimits` is in `workout_library.dart`, imported in step 1. The step-1 import must also expose `kMinWeightKg` (it is in `custom_workout.dart`, already imported at line 22).

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| moveDetails | Move details | تفاصيل الحركة |
| targetWeightKg | Target weight (kg) | الوزن المطلوب (كجم) |
| leaveEmptyForBodyweight | Leave empty for bodyweight | سيبيها فاضية لو بوزن الجسم |
| noteForHer | Note for her | ملاحظة ليها |
| supersetWithTheNextMove | Superset with the next move | سوبر سيت مع الحركة اللي بعدها |
| superset | Superset | سوبر سيت |
| saveDetails | Save details | حفظ التفاصيل |

Command: put these 7 pairs in `/tmp/ownhub-wo03b.json` under `"strings"` (English text as the key) and run `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03b.json && flutter gen-l10n`. Use the getter names the script prints; if one of these English texts already exists the script reuses its getter, which is fine.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| app/test/features/private_coaching/plans/plan_screens_test.dart | `day editor: details sheet saves weight, rest, note, superset` | Pump `CoachDayEditorView` the way the existing day-editor test does (copy its setup). Tap `move-details-0`. Enter `12.5` in `details-kg`, tap `details-rest-plus` twice, enter `Slow` in `details-note`, tap `details-superset`, tap `details-save`. Assert the state's plan: `days[0].kgAt(0) == 12.5`, `restSeconds == 90` (60 + 30), `notesEn == 'Slow'`, `supersetWithNext == true`; `move-summary-0` text contains `12.5`. |
| same | `day editor: empty weight clears the target` | Same setup with a plan whose move has a kg; open details, clear `details-kg`, save; assert `kgAt(0) == null`. |
| same | `day editor: last move cannot be a superset` | Open details on the last move; assert the `details-superset` switch `onChanged` is null. |
Budget: add a case to `app/test/qa/screen_budget_test.dart` only if the day editor is already listed there (UNVERIFIED: `grep -n "CoachDayEditor\|day-editor" app/test/qa/screen_budget_test.dart`); if listed, run it.
Run: `cd app && flutter test test/features/private_coaching/plans/plan_screens_test.dart`.

## Verify
`flutter analyze lib/features/private_coaching/presentation/plans` -> `No issues found!`; the test command -> `All tests passed!`. Also run the Arabic case once: the existing test file has an Arabic pump helper (UNVERIFIED name, `grep -n "ar'" app/test/features/private_coaching/plans/plans_support.dart`); the sheet must show no overflow.

## Do not
No em dashes. Do not change `PlanEditorView` (it is shared with the member's own plan). Do not add a second filled button to the sheet. Do not commit.

## Done checklist
- [ ] Button and summary on the card  - [ ] Sheet saves all four  - [ ] Strings in EN and AR  - [ ] 3 tests pass

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-03c.
