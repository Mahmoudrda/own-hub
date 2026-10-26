# WO-04f: "Needs attention" on the coach's desk (C3, part 3)
Depends on: WO-04d, WO-04e (uses `CheckIns` and `AttentionRow` from `check_in.dart`)
Size: M
Reads first: `app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart` lines 61-130 (state class) and 225-300 (the list `build` returns) and 339-390 (`_section`, `_title`); `app/lib/features/private_coaching/domain/check_in.dart` (from WO-04e); `app/test/features/private_coaching/desk/desk_views_test.dart` (first 80 lines)

## Why
Rahma wants one list of the clients who need her today. Today the desk (K07) has separate sections for new requests, waiting for reply, ending soon, follow-ups and unread, but nothing for a client who stopped answering, said her training slipped, or gave a health answer. The server (WO-04d) builds the list with reasons; this order draws it at the top of K07 and opens the client on tap.

## Final result
K07, only when the list is not empty, shows a first section above the others:
- Heading EN "Needs attention" / AR "محتاجة متابعة".
- One `AppListItem` row per client (at most 5; the rows sit next to each other so they count as one control in the budget): title = client first name; subtitle = her reasons joined with " · ", from this table:
  | reason | English | Egyptian Arabic |
  |---|---|---|
  | noCheckIn | No check-in yet | لسه ماجاوبتش على التشيك إن |
  | missedSessions | Training slipped this week | التمرين اتأخر الأسبوع ده |
  | healthFlag | Health answer to read | فيه إجابة صحية محتاجة تقرأيها |
  | unread | Unread message | رسالة ماتقرتش |
- Tap on a row (1 tap) opens that client (`onOpenClient(subId)`, which K07 already routes to W02). From there Message is one more tap.
- If more than 5 clients qualify, a muted line EN "And {count} more" / AR "و{count} كمان" is NOT shown; instead the existing "Clients" outlined button below already lists all (no new control).
- While the list loads, or if the callable fails, or while `CHECK_INS_LIVE` is off on the server: nothing is shown (no spinner, no error). The desk is unchanged.
Wording rule: reasons describe the situation, never the woman ("Training slipped", not "She failed").

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart` | edit | load the list; draw the section |
| `app/lib/features/private_coaching/presentation/desk/desk_text.dart` | edit | `attentionReasonText(l10n, reason)` |
| `app/test/features/private_coaching/desk/desk_views_test.dart` | edit | three tests |

## Steps
1. File `desk_text.dart` (UNVERIFIED how it is organised: `sed -n 1,40p app/lib/features/private_coaching/presentation/desk/desk_text.dart`; it holds functions of `(AppL10n l10n, ...) => String` such as `intakeSummary`). Append:
```dart
/// A reason on the "Needs attention" list, in words about the week, not about her.
String attentionReasonText(AppL10n l10n, String reason) => switch (reason) {
  'noCheckIn' => l10n.noCheckInYet,
  'missedSessions' => l10n.trainingSlippedThisWeek,
  'healthFlag' => l10n.healthAnswerToRead,
  'unread' => l10n.unreadMessage,
  _ => '',
};
```
Add `import` of `app_l10n.dart` only if the file does not have it.
2. File `coach_desk_view.dart`, class `_CoachDeskViewState`: add a field and load it once. Find `initState` (UNVERIFIED: `grep -n "initState" app/lib/features/private_coaching/presentation/desk/coach_desk_view.dart`). Add:
```dart
  List<AttentionRow> _attention = const <AttentionRow>[];

  Future<void> _loadAttention() async {
    final rows = await CheckIns.store.needsAttention();
    if (mounted) setState(() => _attention = rows);
  }
```
and in `initState` (after `super.initState();`) call `unawaited(_loadAttention());` (`import 'dart:async';` if missing). Add imports `../../domain/check_in.dart`. If there is no `initState`, add one: `@override void initState() { super.initState(); unawaited(_loadAttention()); }`.
3. Same file, in the list that `build` returns (the one that holds `if (model.followUps.isNotEmpty) ..._section(` at about line 249), insert BEFORE the first `if (model.requests...` / earliest section element (read lines 225-250 to find the first element) this block:
```dart
      if (_attention.isNotEmpty) ...[
        _title(l10n.needsAttention),
        for (final row in _attention.take(kDeskSectionRows))
          AppListItem(
            variant: AppCardVariant.filled,
            title: row.clientName,
            subtitle: row.reasons
                .map((r) => attentionReasonText(l10n, r))
                .where((t) => t.isNotEmpty)
                .join(' · '),
            onTap: () => widget.onOpenClient?.call(row.subId),
          ),
      ],
```
Imports needed: `../../../../ui/app_list_item.dart`. `kDeskSectionRows` is defined at line 28 of this file. `_title(String)` is the heading helper at about line 287 (verified to exist: `Widget _title(String text) => Semantics(header: true, ...`).
4. Strings and tests as below.

## Strings to add
`app/tool/_wo04f_strings.json`, then `cd app && python3 tool/add_strings.py tool/_wo04f_strings.json && flutter gen-l10n`. No placeholders.
| English | Egyptian Arabic |
|---|---|
| Needs attention | محتاجة متابعة |
| No check-in yet | لسه ماجاوبتش على التشيك إن |
| Training slipped this week | التمرين اتأخر الأسبوع ده |
| Health answer to read | فيه إجابة صحية محتاجة تقرأيها |
| Unread message | رسالة ماتقرتش |
(Check first with `grep -n '"Needs attention"\|"Unread message"' app/lib/l10n/app_en.arb`; if present with the same Arabic, drop it from the JSON.)

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `desk_views_test.dart` | `K07 lists clients that need attention, with reasons, first` | `CheckIns.override = InMemoryCheckInStore(rows: [AttentionRow(subId: 's1', relId: 'r1', clientName: 'Mona', reasons: ['noCheckIn','unread'])])`; pump the desk with the file's existing helper; `pumpAndSettle`; expect 'Needs attention', 'Mona', 'No check-in yet · Unread message'; the heading's top is above the next section heading |
| same | `tapping a row opens that client` | pass `onOpenClient: (id) => opened = id`; tap 'Mona'; `opened == 's1'` |
| same | `no rows means no heading, in Arabic too` | store with empty rows: `find.text('Needs attention')` and `find.text('محتاجة متابعة')` both `findsNothing`; a second case with `Locale('ar')` and one row shows 'محتاجة متابعة' and 'رسالة ماتقرتش' |
Reset in `tearDown`: `CheckIns.override = null;`
Run: `cd app && flutter test test/features/private_coaching/desk/`

## Verify
- `flutter analyze` clean; the run prints `All tests passed!`; existing desk tests unchanged.

## Do not
- Do not call the callable on every rebuild (only `initState`). Do not show a spinner or an error for this list. Do not add a filled button.

## Done checklist
- [ ] text helper, state, section
- [ ] 5 strings EN and AR
- [ ] 3 tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
