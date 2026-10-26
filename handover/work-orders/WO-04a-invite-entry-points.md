# WO-04a: "Invite a client" where Rahma can reach it (C1, part 1)
Depends on: none
Size: S
Reads first: `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart` (whole file, 270 lines); `app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart` lines 28-60 and 255-285; `app/lib/routing/app_router.dart` lines 4983-5012 (K18, K07) and 7296-7318 (`shareCoachInvite`); `app/test/features/private_coaching/coach/coach_test.dart` lines 41-95 (`_host`, `_open`) and 171-200

## Why
The plan says the invite callable is missing. It is NOT missing (checked 26 Oct): `functions/main.py:1798 create_coach_invite` and `:1820 accept_coach_invite` exist, `functions/coaching/invites.py` is complete, the app side `app/lib/app_state/coach_invite_state.dart` (`CallableCoachInviteStore`) and `AppRouter.shareCoachInvite` (`app_router.dart:7299`) exist, and C01 already takes a code (`invite_code_sheet.dart`). The only gap: the one "Invite a client" row lives in `features/coach/presentation/coach_today_view.dart`, an old screen no route builds (K07 builds `CoachDeskView`, `app_router.dart:4998`), and `shareCoachInvite` has no caller. So Rahma cannot reach it. This order adds two doors to the live screens. No server change.

## Final result
K18 "My coach space" (`CoachSpaceView`), top to bottom: the profile card with the accepting switch; the dashboard card (only when `onOpenDashboard` is set); then ONE run of list rows, now five: **Invite a client** (new, first row), My portfolio, My packages, Photos and results, Preview my portfolio, My application. Adjacent `AppListItem` rows count as one control in the budget, so the budget does not change.
- Row title EN "Invite a client" / AR "ادعي عميلة" (existing string `inviteAClient`). Subtitle EN "Already coaching someone? Send her your code on WhatsApp." / AR "فيه حد بتدرّبيه دلوقتي؟ ابعتيلها الكود بتاعك على WhatsApp." (existing `alreadyCoachingSomeoneSendHerYourCode`). Leading icon `Icons.person_add_alt`, trailing `Icons.share`.
- Tap: WhatsApp share sheet opens with the message (1 tap to WhatsApp, 2 to pick a contact, 3 to send = 3 taps).
K07 desk (`CoachDeskView`) when she has no clients and nothing to do: the existing empty state ("No clients yet" / "Share your portfolio link so members can ask to join.") now has ONE filled button under it: EN "Invite a client" / AR "ادعي عميلة". Same action. This is the first screen a new coach sees, so it is 1 tap from the desk.
Failure texts already exist: `weCouldNotMakeYourCodeTry` ("We could not make your code. Try again in a moment." / "ماقدرناش نعمل الكود بتاعك. جرّبي تاني كمان شوية.") and `weCouldNotOpenWhatsappYourCode`.

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart` | edit | new optional `onInviteClient`; new first list row |
| `app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart` | edit | new optional `onInviteClient`; button in the no-clients state |
| `app/lib/routing/app_router.dart` | edit | pass `onInviteClient` in K18 and K07 |
| `app/test/features/private_coaching/coach/coach_test.dart` | edit | one test for K18 |
| `app/test/features/private_coaching/desk/desk_views_test.dart` | edit | one test for K07 |

## Steps
1. File `coach_space_view.dart`, class `CoachSpaceView` constructor (about line 30). Add after `this.onOpenChats,`:
```dart
    this.onInviteClient,
```
and after the field `final VoidCallback? onOpenChats;` (about line 48):
```dart
  /// "Invite a client": her code, shared on WhatsApp.
  final VoidCallback? onInviteClient;
```
2. Same file, method `build`, list `<Widget>[ ... ]` returned by the `CoachDataGate` builder. Find the line `_nav(` whose `title: l10n.myPortfolio,` (about line 148). Insert BEFORE that `_nav(` call:
```dart
              if (widget.onInviteClient != null)
                _nav(
                  title: l10n.inviteAClient,
                  subtitle: l10n.alreadyCoachingSomeoneSendHerYourCode,
                  icon: Icons.person_add_alt,
                  onTap: widget.onInviteClient!,
                ),
```
(`_nav` shows an `AppChevron`; that is acceptable here. Do not change `_nav`.)
3. File `coach_desk_view.dart`, class `CoachDeskView` constructor (about line 31). Add `this.onInviteClient,` after `this.onOpenClients,` and the field after `final ValueChanged<DeskFilter>? onOpenClients;`:
```dart
  /// "Invite a client" under the empty state.
  final VoidCallback? onInviteClient;
```
4. Same file, find `if (nothingToDo)` then the `model.clients.isEmpty ? AppEmptyState(... title: l10n.noClientsYet ...` expression (about lines 270-282). Directly AFTER the closing of that `if (nothingToDo) ...` element (before `if (model.clients.isNotEmpty) AppButton(`), insert:
```dart
      if (nothingToDo && model.clients.isEmpty && widget.onInviteClient != null)
        AppButton(l10n.inviteAClient, onPressed: widget.onInviteClient),
```
(`AppButton` default variant is `filled`, the one primary. The `Clients ·` button below only shows when clients exist, so there is never a second filled button.)
5. File `app_router.dart`, entry `'K18'` (about line 4983). After `onOpenChats: () => goToTab(context, 'W10'),` add:
```dart
        onInviteClient: () => unawaited(shareCoachInvite(context)),
```
Entry `'K07'` (about line 4998): after `onOpenClients: (filter) => goToTab(context, 'W01', arguments: filter),` add:
```dart
        onInviteClient: () => unawaited(shareCoachInvite(context)),
```
6. Tests (see table). Do not edit `shareCoachInvite`; WO-04b changes its message.

## Strings to add
None. `inviteAClient`, `alreadyCoachingSomeoneSendHerYourCode`, `weCouldNotMakeYourCodeTry`, `weCouldNotOpenWhatsappYourCode` exist in `app/lib/l10n/app_en.arb` (lines 3385-3406) and `app_ar.arb`.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `app/test/features/private_coaching/coach/coach_test.dart` (group `coach space`) | `K18 offers Invite a client first and calls back once` | Arrange: copy `_open` but pass `onInviteClient: () => taps++` to `CoachSpaceView` (add an optional named parameter `onInviteClient` to `_open` and forward it). Act: `await tester.tap(find.text('Invite a client'))`. Assert: `taps == 1`; `find.text('Invite a client')` is above `find.text('My portfolio')` (`tester.getTopLeft(...).dy` smaller). Second case: without the callback `find.text('Invite a client')` is `findsNothing`. |
| `app/test/features/private_coaching/desk/desk_views_test.dart` | `K07 with no clients shows one Invite a client button` | Arrange: pump `CoachDeskView(state: <the empty state this file already builds>, onInviteClient: () => taps++)` using the file's existing helper (UNVERIFIED helper name: `grep -n "CoachDeskView(" app/test/features/private_coaching/desk/desk_views_test.dart | head -3`). Act: tap `find.text('Invite a client')`. Assert: taps 1, and `find.byType(AppButton)` with variant filled count is 1. |
Run: `cd app && flutter test test/features/private_coaching/coach/coach_test.dart test/features/private_coaching/desk/desk_views_test.dart`

## Verify
- `cd app && flutter analyze lib/features/private_coaching lib/routing/app_router.dart` prints `No issues found!`
- the two test files print `All tests passed!`
- `cd app && flutter test test/qa/screen_budget_test.dart` still passes (K18 budget unchanged: the new row joins the existing list run).
- Android emulator `ownhub_pixel8`: sign in as an approved coach, open K18, tap the row: WhatsApp opens (or the honest notice shows the code).

## Do not
- Do not edit `functions/` (the callables exist). Do not edit `coach_today_view.dart` (dead; leave it).
- Do not add a second filled button to K07 or K18.
- Do not change `invites.py` rules (one live code per coach, 30 days, no attempt counter).

## Done checklist
- [ ] K18 row first in the list, EN and AR read right
- [ ] K07 empty state button
- [ ] Two tests pass; analyze clean; budget test passes

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
