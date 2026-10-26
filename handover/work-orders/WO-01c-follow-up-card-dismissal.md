# WO-01c: the follow-up card's dismissal (keep the swipe, prove the screen-reader action)
Depends on: none
Size: S (under 1 hour)
Reads first:
- `app/lib/features/followup/presentation/follow_up_card.dart` lines 70-110 (the `build` method)
- `app/test/features/followup/follow_up_card_test.dart` lines 1-35 (imports, `_phone`, `_host`) and 245-275 (group `the way out`)
- `app/test/qa/screen_budget_test.dart` lines 41-100 (`kChromeCounts`, `expectWithinBudget`)

## Why
The build review for batch A said: the follow-up card on Home can only be sent away by swiping it. Until batch A it had a small close button (a 48 point `IconButton`, key `follow-up-not-now-<kind>`). Batch A replaced it with a `Dismissible` (the same key) and a screen-reader action called "Not now".

The obvious fix is to bring the close button back. It was tried on a copy of the tree and it fails: `app/test/qa/screen_budget_test.dart`, group "Home, asserted in every state", `T01 followUp en 390x844` and `T01 followUp ar 390x844` both stop with `Expected: a value less than or equal to <5>  Actual: <6>  T01: too many controls above the fold`. Home in the follow-up state already has 5 controls above the fold at 390x844 (1 filled primary plus 4 others, measured with the top bar left out), which is the whole budget, because `expectWithinBudget` counts the primary inside the 5. The budget is one of the owner's rules, so the close button cannot come back without the owner changing the rule.

So the design stays: swipe either way sends the card away until tomorrow, a screen-reader user gets the same thing as a named action, and switching the whole kind off lives on Notifications (A01, key `a01-follow-ups`, already covered by `app/test/journeys/follow_up_journey_test.dart`, test "the master switch on Notifications takes the card off Home"). What is missing is a test for the screen-reader action: nothing proves it exists. This order adds that test. No production code changes.

Owner decision to report (do not act on it): if the owner wants a visible close button she must first allow 6 controls on Home when a follow-up shows, or drop one of the other controls on that state of Home. Write that one line in your report.

## Final result
Home looks exactly as today. In `follow_up_card_test.dart` a new test shows that a screen reader finds one custom action labelled `Not now` on the card, that running it sends the card away until tomorrow (`notBefore[comeBack] == '2026-10-17'`).

## Files to edit or create
| path | create or edit | what changes in one line |
|---|---|---|
| app/test/features/followup/follow_up_card_test.dart | edit | one import and one new test in group `the way out` |

## Steps
1. Run the current card tests so you know the start state: `cd ~/ownhub/app && flutter test test/features/followup/follow_up_card_test.dart`. Expect `All tests passed!`.
2. File `app/test/features/followup/follow_up_card_test.dart`. Anchor: the line `import 'package:flutter/material.dart';` (about line 1-3, the first import). Add directly under it:
   ```dart
   import 'package:flutter/semantics.dart';
   ```
3. Same file. Anchor: inside `group('the way out', () {` (about line 247), the first test, which starts with `testWidgets('swiping it away hides the kind until tomorrow', (`. Insert this whole test directly above it (the card shown is `_card(_back)`, the come-back card, and `_back` is the same fixture that the swipe test below uses, so the date `2026-10-17` is the same):
   ```dart
       testWidgets('a screen reader gets Not now as an action', (tester) async {
         _phone(tester);
         final handle = tester.ensureSemantics();
         await tester.pumpWidget(_host(_card(_back)));
         await tester.pumpAndSettle();
         final actions = find.semantics.byPredicate(
           (node) =>
               node.getSemanticsData().customSemanticsActionIds?.isNotEmpty ??
               false,
         );
         expect(actions, findsOneWidget);
         final ids = actions
             .evaluate()
             .single
             .getSemanticsData()
             .customSemanticsActionIds!;
         expect(CustomSemanticsAction.getAction(ids.single)!.label, 'Not now');
         tester.semantics.performAction(
           actions,
           SemanticsAction.customAction,
           args: ids.single,
           checkForAction: false,
         );
         await tester.pump();
         expect(
           FollowUpState.instance.notBefore[FollowUpKind.comeBack],
           '2026-10-17',
         );
         handle.dispose();
       });

   ```
   The `pumpAndSettle` matters: the card fades in, and until that finishes it has no semantics at all.
4. Run the file again (command under "Verify").

## Strings to add
None. (The label `Not now` already exists as `l10n.notNow`; the card uses it.)

## Tests to add or change
| file | test name | exact arrange, act and assert in words |
|---|---|---|
| app/test/features/followup/follow_up_card_test.dart | a screen reader gets Not now as an action | Arrange: phone size, semantics switched on, the come-back card drawn and settled. Act: find the one semantics node with a custom action, run that action. Assert: exactly one such node, its action label is `Not now`, and after the action `FollowUpState.instance.notBefore[FollowUpKind.comeBack]` is `'2026-10-17'`. |

Command: `cd ~/ownhub/app && flutter test test/features/followup/follow_up_card_test.dart`

## Verify
1. The command above ends with `All tests passed!`.
2. `cd ~/ownhub/app && flutter test test/features/followup/follow_up_card_test.dart test/journeys/follow_up_journey_test.dart test/features/today/today_budget_test.dart test/qa/screen_budget_test.dart` ends with `All tests passed!`.
3. `cd ~/ownhub/app && dart format --output=none --set-exit-if-changed test/features/followup/follow_up_card_test.dart` prints `Formatted 1 file (0 changed)`.
4. `cd ~/ownhub/app && flutter analyze lib test` ends with `No issues found!`.
5. `git -C ~/ownhub diff --stat -- app/lib/features/followup` shows the same change as before this order (the `Dismissible` version); this order must not alter it.

## Do not
- Do not put the close `IconButton` back, and do not add any tappable "Not now" text, chip or link to the card. It breaks `screen_budget_test.dart` (6 controls against 5).
- Do not change `kChromeCounts`, `maxOtherControls` or any budget number.
- Do not remove the `Dismissible` or its key `follow-up-not-now-<kind>`; two tests swipe it by that key.
- Do not edit `follow_up_card.dart`, `follow_up_state.dart` or the journey test.

## Done checklist
- [ ] Start state green
- [ ] Import and test added exactly as shown
- [ ] Verify 1 to 4 pass
- [ ] Report contains the one-line owner decision about a visible close button

## If stuck
The new test cannot find the action (0 or 2 nodes): you probably skipped `pumpAndSettle`; if it still fails twice, stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-01d.
