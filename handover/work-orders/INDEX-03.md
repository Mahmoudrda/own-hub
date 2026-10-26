# INDEX-03: Rahma's builders (C4 workouts, C5 assign to many, C6 weeks, C7 meals)

Order of work (dependencies in each file). A and C and D have no dependencies and may go first, in any order.

| order | file | one line |
|---|---|---|
| 1 | WO-03a-move-fields-domain.md | C4: superset flag, `changeMoveDetails` (rest, note, weight), server key, client cue |
| 2 | WO-03b-day-editor-details-sheet.md | C4: "Move details" sheet in the day editor (weight, rest, note, superset); 3 taps to set a weight |
| 3 | WO-03c-duplicate-day-and-seeded-splits.md | C4: one-tap Duplicate on a day card; locks in that the 3 splits (x3 levels) are already offered as starting templates |
| 4 | WO-03d-plan-start-date.md | C5/C6: optional `startsOn` through the callable, the plan doc and `CoachPlan` |
| 5 | WO-03e-weeks-data-and-today.md | C6: `week` on each day, limits 4 weeks and 120 KB, server checks, `todaysWorkoutDay` follows the start date |
| 6 | WO-03f-weeks-screens.md | C4/C6: Week headings, "Repeat last week", client week line on Plan and Home |
| 7 | WO-03g-assign-to-many-clients.md | C5: "Send to more clients" sheet with start date, loop with partial-failure card and retry (workout and meal) |
| 8 | WO-03h-meal-goal-swaps-and-eating-gate.md | C7: `goal` (kcal, protein) and `swaps` in the meal body, server hold `eating_history_hold` |
| 9 | WO-03i-coach-meal-builder-target-swaps-gate.md | C7: target card, gate card for flagged clients, swaps sheet, only signed recipes, owner gate how-to |
| 10 | WO-03j-client-meal-plan-swap-grocery-log.md | C7: client Eat card: target line, swap in 2 taps, grocery list in 1, log in 1 tap (locked by a test) |

Findings the coordinator should know
- Duplicate day already exists (Add a day, Copy of X: 2 taps); the audit missed it. Seeding the 3 splits is already done (`coachSplits()`, 9 rows = 3 families x 3 levels).
- Multi-week was impossible, not just unlabelled: 7-day cap on client and server, `todaysWorkoutDay` rotates by sessions done this calendar week, and one week is about 18 KB against a 60 KB body limit. WO-03e raises limits and changes Today (decision recorded: last week repeats after the final week; before the start date the coach card is hidden).
- Superset is a new field; the workout runner does not alternate two moves (shown as a cue only). Owner call if she wants the runner to alternate.
- Tap counts: set weight 3; add one exercise 3 (target 2, not reachable without redesign of the picker); duplicate day 1; assign to one more client 3 plus Publish; repeat a week 1; swap 2; grocery list 1; log a coach meal 1.
- The eating-history flag does not exist yet (made by C9). WO-03h/03i read `intake.health.eatingHistory`; until C9 lands the gate never fires.
- The 39 recipes already carry a draft sign-off stamp (`recipe_signoff.json`); WO-03i adds the code gate (`allergensKnown`) and documents the owner switch.
- Swap choices on the client are in memory only (lost on restart); persistence is a named follow-up.
