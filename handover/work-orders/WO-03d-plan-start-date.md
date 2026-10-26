# WO-03d: A plan has a start date (server, repository, model)
Depends on: none
Size: M
Reads first: `functions/coaching/plans.py` lines 257-345; `app/lib/features/private_coaching/domain/coach_plan.dart` lines 200-285; `app/lib/features/private_coaching/data/coaching_repository.dart` lines 163-169; `app/lib/features/private_coaching/data/firestore_coaching_repository.dart` lines 806-829; `functions/tests/test_coaching_plans.py` lines 1-100

## Why
Rahma assigns a plan "to start on Saturday". Weeks (WO-03e) and the meal-plan day 1 both need a start date. Today the plan's day 1 is the publish day. This order adds an optional `startsOn` (a Cairo calendar date, `YYYY-MM-DD`) to the publish call and to the stored plan. UI comes in WO-03g. A plan without `startsOn` behaves exactly as today.

## Final result
No screen. The callable `publish_coach_plan` accepts `startsOn` (string). The server refuses a date in the past (Cairo today is allowed) or more than 60 days ahead with the existing refusal `plan_invalid`. The plan document at `plans/{clientUid}/coachPlans/{planId}` gets `startsOn` (string). `CoachPlan.startsOn` is a `DateTime?` holding midnight of that date (date-only). `CoachingRepository.publishCoachPlan` has a new optional `String? startsOn` parameter.

## Files to edit or create
| path | file action | change |
|---|---|---|
| functions/coaching/plans.py | edit | `_start_date` check, write `startsOn` |
| app/lib/features/private_coaching/domain/coach_plan.dart | edit | `startsOn` field, parse, request key |
| app/lib/features/private_coaching/data/coaching_repository.dart | edit | interface param |
| app/lib/features/private_coaching/data/firestore_coaching_repository.dart | edit | pass it |
| app/test/features/private_coaching/support/ (fake repository) | edit | UNVERIFIED: `grep -rn "publishCoachPlan" app/test | head` lists every fake that must take the new parameter |
| functions/tests/test_coaching_plans.py | edit | 3 tests |
| app/test/features/private_coaching/models_test.dart | edit | 1 test |

## Steps
1. File `plans.py`. Add `import zoneinfo` under `import os` (line 18). Add after `check_body` (about line 255):
```python
CAIRO = zoneinfo.ZoneInfo("Africa/Cairo")
MAX_START_DAYS_AHEAD = 60


def start_date(value: Any, now: dt.datetime) -> Optional[str]:
    """None when absent; else a Cairo date string from today to 60 days ahead."""
    if value is None:
        return None
    _check(isinstance(value, str) and len(value) == 10)
    try:
        day = dt.date.fromisoformat(value)
    except ValueError:
        raise common.bad(errors.PLAN_INVALID)
    today = now.astimezone(CAIRO).date()
    _check(today <= day <= today + dt.timedelta(days=MAX_START_DAYS_AHEAD))
    return value
```
In `publish` (about line 257) after the line `body = data.get("body")` and the `check_body(...)` call (about line 283) add `starts_on = start_date(data.get("startsOn"), now)`. In the `transaction.set(plan_ref, {...})` dict (about line 322-331) add after `"publishedAt": now,`:
```python
                **({"startsOn": starts_on} if starts_on else {}),
```
2. File `coach_plan.dart`. In `class CoachPlan` constructor add `this.startsOn,` after `this.publishedAt,` (about line 223); field `final DateTime? startsOn;` after `final DateTime? publishedAt;`. In `fromMap` (about line 262-275) add before `publishedAt: readTime(...)`: `startsOn: _dateOnly(map['startsOn']),`. Add at file end:
```dart
/// "2026-11-01" as a date-only DateTime, or null.
DateTime? _dateOnly(Object? raw) {
  if (raw is! String || raw.length != 10) return null;
  final d = DateTime.tryParse(raw);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}
```
In `publishPlanRequest` (about line 277-300) add parameter `String? startsOn,` after `String? planId,` and the map entry `'startsOn': ?startsOn,` after `'planId': ?planId,`.
3. File `coaching_repository.dart`, `publishCoachPlan` (about line 163-169): add `String? startsOn,` after `String? planId,`. File `firestore_coaching_repository.dart` (about line 806-829): add the same parameter and pass `startsOn: startsOn,` into `publishPlanRequest(...)`.
4. Fix every fake: run `cd app && grep -rn "publishCoachPlan" test lib | grep -v "^lib/features/private_coaching/data"` and add `String? startsOn,` to each override signature found.

## Strings to add
None.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| functions/tests/test_coaching_plans.py | `test_start_date_is_stored` | `NOW` is the file's constant (see line ~10, UNVERIFIED value: `grep -n "^NOW" functions/tests/test_coaching_plans.py`). Build `d = (NOW.astimezone(plans.CAIRO).date() + dt.timedelta(days=3)).isoformat()`; `publish(db, req(startsOn=d))`; read the new plan doc (copy how existing tests read it) and assert `["startsOn"] == d`. |
| same | `test_start_date_in_the_past_or_too_far_is_refused` | `startsOn` = yesterday, = 61 days ahead, = "2026-13-40", = 5 (int): each `refused(db, req(startsOn=x), errors.PLAN_INVALID)`. |
| same | `test_no_start_date_writes_no_key` | publish without it; assert `"startsOn" not in doc`. |
| app/test/features/private_coaching/models_test.dart | `CoachPlan reads startsOn` | `CoachPlan.fromMap('p', {'kind': 'workout', 'body': <a valid one-day body, copy from this file>, 'startsOn': '2026-11-07'})!.startsOn == DateTime(2026, 11, 7)`; a bad value gives null. |
Run: `cd functions && .venv/bin/python -m pytest tests/test_coaching_plans.py -q` and `cd app && flutter test test/features/private_coaching/models_test.dart`.

## Verify
Both end green. `cd app && flutter analyze lib test` -> `No issues found!` (the fakes compile).

## Do not
No new callable, no new Firestore rule. The meal plan body still carries no nutrition keys. Do not store the date as a timestamp (a Cairo date must not shift with the phone's zone). Do not commit.

## Done checklist
- [ ] Server check and write  - [ ] Model and request  - [ ] Fakes updated  - [ ] Tests pass

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-03a.
