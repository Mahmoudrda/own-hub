# WO-02g: Saved replies for the coach, inside the "+" sheet
Depends on: WO-02e (the "+" sheet and `ShareChoices`)
Size: M
Reads first: `app/lib/ui/app_sheet.dart` (does `AppSheet` scroll? does it take `children` and `gap`), `app/lib/features/private_coaching/presentation/chat/chat_sheets.dart` (`ShareChoices`, `showShareSheet`, `SheetAction`, as left by WO-02e), `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` (`_composer`, `_text`, `_focus`), `app/lib/features/private_coaching/domain/chat_screen.dart` (`ChatScreen.screen`), `app/lib/ui/app_button.dart` (constructor of the filled button)

## Why
Rahma types the same sentences all day. A saved reply puts one into the message box in two taps ("+" then the reply), and she can still change it before sending. Replies are per coach and stay on her phone (shared_preferences, already a dependency; nothing about them reaches the server, so no rules or privacy change). Sending still goes through the same chat screen, so a saved reply can never carry a number, payment name or link.

## Final result
Only the coach sees this. "+" opens the sheet; at the top, a small heading "Saved replies" / "ردود محفوظة", then her replies, each row: the reply text (two lines at most) and, at the end, a pencil button (48 px, tooltip "Edit reply" / "عدّلي الرد"). Tapping the row closes the sheet and puts the text in the message box (if the box already has text, the reply is added after a space), keyboard open, cursor at the end. Under the replies a row "Add a reply" / "ضيفي رد" with a plus icon. Under that, the media rows and the share rows from WO-02e.

The editor is a second bottom sheet: title "New reply" or "Edit reply" ("رد جديد" / "عدّلي الرد"), one text box (hint "Write your reply" / "اكتبي الرد", up to 300 characters, 5 lines), one filled button "Save" / "احفظي" (disabled while empty), and for an existing reply a plain text button "Delete" / "امسحي". Two taps from the thread reach any editor (the "+" then the pencil or "Add a reply"). If the text would be refused by the chat screen (phone number, payment name, link, abuse) the editor shows that refusal in red under the box and does not save. Up to 20 replies; at 20 the "Add a reply" row is hidden.

First time a coach opens the sheet she already has the 10 starter replies below (copied once into her list, in the app language at that moment; after that they are hers to edit or delete). If she deletes all ten, the list stays empty; the starters are never copied again.

The thread keeps 5 controls on screen (back, menu, "+", field, mic or send): the replies live inside the sheet.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `app/lib/features/private_coaching/data/saved_reply_store.dart` | create | per-coach list on the phone |
| `app/lib/features/private_coaching/presentation/chat/saved_replies_sheet.dart` | create | the editor sheet and the list rows |
| `app/lib/features/private_coaching/presentation/chat/chat_sheets.dart` | edit | `ShareChoices` gets replies fields; the sheet shows them first |
| `app/lib/features/private_coaching/presentation/chat/chat_thread_view.dart` | edit | load, insert, edit |
| `app/test/features/private_coaching/chat/saved_replies_test.dart` | create | store and view tests |

## Steps
1. File `saved_reply_store.dart` (create):
```dart
/// A coach's saved replies, kept on her phone under one key per coach.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedReply {
  const SavedReply({required this.id, required this.text});
  final String id;
  final String text;
}

const int kSavedReplyMax = 20;
const int kSavedReplyChars = 300;

class SavedReplyStore {
  SavedReplyStore({SharedPreferences? prefs}) : _prefs = prefs;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static String _key(String coachUid) => 'savedReplies.v1.$coachUid';

  /// Her list; the first time ever, [seed] is copied in and stored.
  Future<List<SavedReply>> load(String coachUid, List<String> seed) async {
    final prefs = await _p;
    final raw = prefs.getString(_key(coachUid));
    if (raw == null) {
      final list = <SavedReply>[
        for (var i = 0; i < seed.length; i++)
          SavedReply(id: 's$i', text: seed[i]),
      ];
      await save(coachUid, list);
      return list;
    }
    try {
      final data = jsonDecode(raw) as List<Object?>;
      return <SavedReply>[
        for (final row in data)
          if (row is Map && row['id'] is String && row['text'] is String)
            SavedReply(id: row['id'] as String, text: row['text'] as String),
      ];
    } catch (_) {
      return const <SavedReply>[];
    }
  }

  Future<void> save(String coachUid, List<SavedReply> list) async {
    final prefs = await _p;
    await prefs.setString(
      _key(coachUid),
      jsonEncode(<Object?>[
        for (final r in list) <String, String>{'id': r.id, 'text': r.text},
      ]),
    );
  }
}
```
2. File `saved_replies_sheet.dart` (create): exports `Future<String?> showReplyEditor(BuildContext context, {String? initial})` that returns the new text, the empty string `''` when she taps Delete, or null when dismissed. Build it with `showModalBottomSheet` + `AppSheet` exactly like `showShareSheet`, with `isScrollControlled: true` and bottom padding `MediaQuery.viewInsetsOf(sheet).bottom` so the keyboard does not cover Save. Body: a `TextField` (`maxLength: kSavedReplyChars`, `minLines: 1`, `maxLines: 5`, `autofocus: true`, `textCapitalization: sentences`), a refusal line, the `AppButton` filled "Save", and for `initial != null` a `TextButton` "Delete". On Save: `final reason = ChatScreen.screen(text.trim()); if (reason != null) { show the matching refusal text }` using the same four getters the thread uses (`phoneNumbersCantBeSentInThe`, `paymentDetailsCantBeSharedInThe`, `linksCantBeSentInTheChat`, `someWordsInThisMessageArentAllowed`; see `_refusalText` in `chat_thread_view.dart`), else `Navigator.pop(sheet, text.trim())`. Use the filled button class and its real constructor from `app/lib/ui/app_button.dart` (UNVERIFIED parameter names: open the file).
3. File `chat_sheets.dart`. Add to `ShareChoices` the fields `this.replies = const <SavedReply>[], this.onUseReply, this.onEditReply, this.onAddReply,` with types `List<SavedReply>`, `void Function(SavedReply)?`, `void Function(SavedReply)?`, `VoidCallback?` (also carry them in `withMedia`, and add them to `any` as `|| onUseReply != null`). In `showShareSheet`, before the media rows, when `choices.onUseReply != null`:
```dart
        if (choices.onUseReply != null) ...[
          Text(l10n.savedReplies, style: AppText.titleS.copyWith(color: AppColors.ink)),
          for (final reply in choices.replies)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      choices.onUseReply!(reply);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          reply.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.editReply,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.edit_outlined),
                  color: AppColors.primary,
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    choices.onEditReply!(reply);
                  },
                ),
              ],
            ),
          if (choices.onAddReply != null && choices.replies.length < kSavedReplyMax)
            SheetAction(
              icon: Icons.add,
              label: l10n.addAReply,
              onTap: () => run(sheet, choices.onAddReply!),
            ),
          const Divider(height: 24),
        ],
```
Imports: `../../data/saved_reply_store.dart`. If `AppSheet` does not scroll (see Reads first), wrap the whole `children` list content in a `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7), child: SingleChildScrollView(child: Column(...)))` instead of passing the rows directly; keep `AppSheet` as the outer frame.
4. File `chat_thread_view.dart`. Add constructor parameter `this.savedReplyStore,` with field `final SavedReplyStore? savedReplyStore;` and a second `this.starterReplies = const <String>[],` (`final List<String> starterReplies;`, the ten strings, supplied by the wiring below). State:
```dart
  late final SavedReplyStore _replyStore = widget.savedReplyStore ?? SavedReplyStore();
  List<SavedReply> _replies = const <SavedReply>[];

  bool get _iAmCoach => !widget.otherIsCoach;

  Future<void> _loadReplies() async {
    if (!_iAmCoach) return;
    final list = await _replyStore.load(widget.myUid, widget.starterReplies);
    if (mounted) setState(() => _replies = list);
  }

  void _useReply(SavedReply reply) {
    final current = _text.text;
    final next = current.trim().isEmpty ? reply.text : '${current.trimRight()} ${reply.text}';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _editReply(SavedReply? reply) async {
    final text = await showReplyEditor(context, initial: reply?.text);
    if (text == null || !mounted) return;
    final next = <SavedReply>[..._replies];
    if (reply == null) {
      if (text.isNotEmpty && next.length < kSavedReplyMax) {
        next.add(SavedReply(id: 'r${DateTime.now().microsecondsSinceEpoch}', text: text));
      }
    } else {
      final at = next.indexWhere((r) => r.id == reply.id);
      if (at >= 0) {
        if (text.isEmpty) {
          next.removeAt(at);
        } else {
          next[at] = SavedReply(id: reply.id, text: text);
        }
      }
    }
    setState(() => _replies = next);
    await _replyStore.save(widget.myUid, next);
  }
```
Call `unawaited(_loadReplies());` at the end of `initState`. In the "+" button's `showShareSheet(context, widget.share.withMedia(...))` call (from WO-02e) chain the reply fields: build `final choices = widget.share.withMedia(...)` and pass `_iAmCoach ? choices.withReplies(replies: _replies, onUseReply: _useReply, onEditReply: _editReply, onAddReply: () => _editReply(null)) : choices` where `withReplies` is a method added to `ShareChoices` in step 3 that copies all fields (write it like `withMedia`). Do not call `_editReply` from a sheet callback before the sheet is popped (the code above pops first).
5. File `app/lib/routing/coaching_wiring.dart`, in the `ChatThreadView(` call (about line 181) add `starterReplies: iAmClient ? const <String>[] : starterRepliesOf(l10n),` and define `starterRepliesOf(AppL10n l10n)` in `saved_replies_sheet.dart` returning the ten getters from the strings table in the table's order.
6. Add strings: `app/tool/strings_wo02g.json`, `python3 app/tool/add_strings.py app/tool/strings_wo02g.json`, use the printed getter names (they replace the guessed ones above: `savedReplies`, `editReply`, `addAReply`, and `starterRepliesOf` uses the ten starter getters), delete the JSON. `Save`, `Delete` and `New reply` may already exist: reuse the printed names.
7. Write the tests (below). Run Verify.

## Strings to add
| English | Egyptian Arabic |
|---|---|
| Saved replies | ردود محفوظة |
| Edit reply | عدّلي الرد |
| Add a reply | ضيفي رد |
| New reply | رد جديد |
| Write your reply | اكتبي الرد |
| Save | احفظي |
| Delete | امسحي |
| Great work today. I am proud of you. | برافو عليكي النهاردة. فخورة بيكي. |
| How did the session feel? Tell me what was easy and what was hard. | إزاي كانت التمرينة؟ قوليلي إيه اللي كان سهل وإيه اللي كان صعب. |
| Send me a short video of that exercise from the side and I will check your form. | ابعتيلي فيديو قصير للتمرين ده من الجنب وأنا أراجع الوضعية. |
| Lower the weight a little and focus on a slow, steady movement. | قلّلي الوزن شوية وركّزي على حركة بطيئة وثابتة. |
| Rest well today. Recovery is part of the plan. | ارتاحي كويس النهاردة. الراحة جزء من الخطة. |
| Remember to drink water and eat your protein today. | افتكري تشربي مية وتاكلي البروتين بتاعك النهاردة. |
| If anything hurts, stop and tell me. Do not push through pain. | لو حاجة وجعتك وقّفي وقوليلي. ماتكمّليش مع الوجع. |
| I saw your weekly check-in. Thank you. I will update your plan. | شفت متابعتك الأسبوعية. شكرًا ليكي. هعدّل الخطة بتاعتك. |
| Missed a day? No problem. Pick up with the next session. | فاتك يوم؟ مفيش مشكلة. كمّلي بالتمرينة الجاية. |
| Send me a photo of your meal and I will give you my notes. | ابعتيلي صورة وجبتك وأنا أقولك رأيي. |

(The ten starters are the last ten rows, in that order. None contains a number, a link or a payment name; all pass `ChatScreen.screen`, and a test checks it.)

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| `saved_replies_test.dart` | `the first load copies the starters and stores them` | `SharedPreferences.setMockInitialValues({})`; `final s = SavedReplyStore(); final a = await s.load('c1', ['x','y']);` assert 2 items; `s.load('c1', ['other'])` still returns `x`,`y` |
| same | `a deleted starter list stays empty` | save `[]` for `c1`; `load('c1', ['x'])` returns empty |
| same | `lists are per coach` | save one for `c1`; `load('c2', [])` empty |
| same | `a broken value reads as empty` | `setMockInitialValues({'savedReplies.v1.c1': 'not json'})`; `load` returns empty |
| same | `every starter passes the chat screen` | for each of the 10 English and 10 Arabic starters (from `AppL10nEn()` and `AppL10nAr()`), `ChatScreen.screen(text) == null` and length <= 300 |
| same | `tapping a reply puts it in the box, not sent` | pump `ChatThreadView` as a coach (`otherIsCoach: false`, `savedReplyStore: SavedReplyStore(prefs: ...)`, `starterReplies: ['Hello there']`); tap "+" tooltip; tap `Hello there`; assert the `TextField` controller text is `Hello there` and the fake repo logged no `sendText` |
| same | `a reply is added after existing text with a space` | type `Hi`, open sheet, tap reply: text `Hi Hello there` |
| same | `add, edit and delete take two taps to the editor` | "+" then "Add a reply" opens the editor (`find.text('New reply')`); enter `Well done`, tap `Save`; reopen "+": `Well done` is listed; tap the edit pencil, clear, tap `Delete`; reopen: gone |
| same | `the editor refuses a phone number` | enter `call 01012345678`, tap Save; the phone-number refusal text shows; the list is unchanged |
| same | `a client has no saved replies` | `otherIsCoach: true`: open "+": no `Saved replies` heading |
| `chat_budget_test.dart` | existing coach test | still `<= 5` with replies loaded |

## Verify
- `cd app && flutter test test/features/private_coaching/chat/` : `All tests passed!`
- `cd app && flutter analyze lib/features/private_coaching lib/routing test/features/private_coaching` : `No issues found!`

## Do not
- Do not store replies on the server or in `coaches/{uid}/drafts` (that would need new rules and a privacy change).
- Do not send a reply on tap. Do not bypass `ChatScreen`.
- Do not add any control to the thread row (budget): everything is inside the sheet.

## Done checklist
- [ ] store with seed-once
- [ ] sheet section and editor
- [ ] insert, add, edit, delete work
- [ ] strings added
- [ ] tests and budget test green

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
