# Work orders from agent 02: coach and client chat upgrades (plan C2, part of C10)

Order of work (dependencies in brackets):

1. `WO-02a-chat-server-media.md` (none): contract limits and enums, server checks for photo, video and voice lines, chat rate limits, report throttle, push text constant (generic default, first-name variant), pytest.
2. `WO-02d-chat-permissions-privacy.md` (none, can run beside 02a): `record` package, Android RECORD_AUDIO, iOS microphone text in English and Egyptian Arabic, privacy manifest, Play data safety, App Store answers, exact privacy-policy text in both languages, deletion-coverage check.
3. `WO-02b-chat-rules.md` (02a): Firestore message rule, Storage `chat-media` rule, two indexes, rules tests for both.
4. `WO-02c-chat-app-data.md` (02a, 02b): Dart contract mirror, message types, upload and send, controller, fakes, tests.
5. `WO-02e-chat-photo-video-ui.md` (02c, 02d): "+" for both people, photo and video pickers, media bubbles with read ticks, full screen viewers, thread control budget test.
6. `WO-02f-chat-voice-notes.md` (02c, 02d, 02e): hold to record, slide to cancel, playable voice bubble, mic/send in one slot.
7. `WO-02g-chat-saved-replies.md` (02e): per-coach saved replies on the phone, 10 starters in English and Egyptian Arabic, add/edit/delete inside the "+" sheet.

Read receipts already exist (clock, one tick, two blue ticks; `tickOf` in `chat_logic.dart`); 02e makes media bubbles carry them and tests it. No separate order.

Decisions left open for the owner (defaults built, nothing blocks): chat-media hold (default: show at once, images cleaned, reportable; "before" is coded but has no release queue), push text (default generic), retention of chat files (text promises deletion with the chat and the account; 02d step 9 must be true first).

Not built (named so nobody assumes it): a reviewer queue or dashboard view for reported chat media; an orphan sweep for uploads with no message; a hidden-line notice that names the reason (rate, media, held); video re-encoding or location stripping.
