# Phase 1 — acceptance

Every P0 and P1 case from `TEST-CASES.csv` whose **primary flow** is a Phase 1
screen (C01–C16, O01–O05, T01–T08, R01–R13).

**32 cases: 28 P0, 4 P1.**

**Phase 1 is not done until each is an executable, passing test** — not a
document someone has read. Judge each PASS / FAIL / NOT COVERED. "Not covered"
is a real result and must be reported, never rounded up to a pass.

Community, Coaching, Assistant and Cycle cases are deliberately **excluded**:
those features are not built until phases 2 and 3, and listing them here would
produce guaranteed failures that teach people to ignore the suite.

## Cases that reach one screen beyond Phase 1

Verify the Phase 1 half. Mark the rest **not yet reachable** — not failed.

| ID | reaches | which is |
|---|---|---|
| `P0-FR-01` | E09 | Eat (phase 2) |
| `P0-LOG-09` | E01 | Eat (phase 2) |
| `P0-LOG-12` | P01 | Progress (phase 2) |
| `P0-RWD-01` | P01 | Progress (phase 2) |
| `P0-RWD-02` | P01 | Progress (phase 2) |
| `P0-WEEK-01` | P01 | Progress (phase 2) |
| `P0-WEEK-02` | P01 | Progress (phase 2) |
| `P0-WEEK-03` | P01 | Progress (phase 2) |
| `P0-WEEK-04` | P01 | Progress (phase 2) |
| `P1-RULE-03` | P01 | Progress (phase 2) |
| `P1-RULE-09` | E04 | Eat (phase 2) |


## P1 — 4 cases

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P1-RULE-03` | Product rule guard | T01,T04,T05,P01,T07 | No daily streak exists anywhere |
| `P1-RULE-07` | Product rule guard | C12,C13 | ID and selfie images are deleted after the check |
| `P1-RULE-08` | Product rule guard | C10,C11,C15 | No face-based gender classification exists in the codebase |
| `P1-RULE-09` | Product rule guard | R07,R09,E04,T02 | Undo, never a confirmation dialog, for logging |

## P0 — 28 cases

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P0-A11Y-01` | Arabic right-to-left across every in-scope screen | all in-scope |  |
| `P0-FR-01` | Day one — nothing logged | T06,E09 |  |
| `P0-FR-02` | First-week arc has no failure state | T07 | Rule 3 + gamification harm evidence |
| `P0-LOG-01` | Log one set mid-workout | R07,R09 | Rule 9: undo, not confirmation |
| `P0-LOG-02` | Undo a set within five seconds | R09,R07 | Rule 9 |
| `P0-LOG-03` | Log a whole move in one tap | R07,R13 |  |
| `P0-LOG-04` | Log a session trained without the phone | T01,T02,R12 | Rule: recalled sessions never set a personal best |
| `P0-LOG-05` | Change a set value without a keyboard | R08 |  |
| `P0-LOG-09` | Log offline, sync later | T01,E01,R07 | Offline-first requirement |
| `P0-LOG-12` | An unplanned walk or class is scored as unplanned | T02,R12,P01 | Only a live session earns full credit or a personal best |
| `P0-NAV-01` | Two-tap reachability | all in-scope |  |
| `P0-ONB-01` | Intake produces a usable starting program | O01,O02,O03,O04,O05 |  |
| `P0-ONB-02` | Intake left at its defaults still publishes a plan | O01,O05,T06 | HANDOFF rule 17: the empty state is the onboarding |
| `P0-ONB-03` | Equipment and place actually constrain the program | O02,O05,R03 | Rule: the plan respects her stated constraints |
| `P0-RWD-01` | An award cannot be granted twice by an offline replay | R10,P01 | Spine C4 (corrected): an increment never travels alone |
| `P0-RWD-02` | The daily points cap holds even when several sessions sync at once | R10,P01 |  |
| `P0-VER-01` | Verification — happy path | C06,C07,C09,C10,C11,C12,C13 | Rule 7: images deleted, result kept |
| `P0-VER-02` | Verification — code autofill on Android | C07 | Rule: never request SMS read permission |
| `P0-VER-03` | Verification — code entered by hand on iOS | C07 |  |
| `P0-VER-04` | Verification — pending, reviewer needed | C12,C14 |  |
| `P0-VER-05` | Verification — niqab path | C09,C15,C14 | Rule 8: no face-based gender inference |
| `P0-VER-06` | Verification — rejected | C12,C15 |  |
| `P0-VER-07` | Verification — no network mid-check | C10,C11,C12 |  |
| `P0-VER-08` | Verification — the code length on screen matches the code sent | C06,C07 | Rule: the UI never promises a format the backend does not send |
| `P0-WEEK-01` | A week counts | T01,P01 | Rule 3: weeks, not days |
| `P0-WEEK-02` | A missed week is repaired by a banked rest week | T04,P01 | Rule 3 |
| `P0-WEEK-03` | A tier slips, shown once | T05,P01 | Rule: nothing earned is taken away |
| `P0-WEEK-04` | A week repaired by a rest week pays no points | T04,P01 | Rule 3 + nothing earned is taken away |
