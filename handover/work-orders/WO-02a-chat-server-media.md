# WO-02a: Chat server: photo, video and voice message types, media checks, rate limits, push text constant
Depends on: none
Size: L
Reads first: `functions/coaching/chat.py` (all, 296 lines), `functions/coaching/blobs.py`, `functions/coaching/push.py` lines 1-30 and 70-95, `functions/main.py` lines 1865-1875 and 2393-2410, `functions/tests/test_coaching_chat.py` lines 76-135, `functions/tests/fake_blobs.py`

## Why
Rahma needs photo and short video form checks and voice notes in the coaching chat. Today the server only knows `text` and `recipe` from a client. The server must (1) accept three new client message types, (2) check the uploaded file really exists under the right path and is clean, (3) stop one account flooding the thread or the bucket, (4) report a flooding reporter, and (5) keep the push text generic by default with a first-name variant behind one constant (owner decision 5 is open, default generic).

Owner decision 4 (hold vs screen after) is also open. Default built here: `CHAT_MEDIA_HOLD = "after"`: the other party sees the media at once, images are re-encoded on the server (no EXIF/location), and every media line can be reported. The value `"before"` is also coded: the line is hidden (reason `held`) and nobody can release it yet because the dashboard queue is NOT built. Do not set `"before"`.

## Final result
No screen. Server behaviour:
- A client may create messages of type `image`, `video`, `audio` with fields `mediaPath`, `durationMs` (video/audio), `bytes`.
- On create the trigger checks: path is `chat-media/{relId}/{senderUid}/{file}`, the file exists, size and type are within limits, the sender is under the rate limits. Any failure hides the line (`hidden: true`, `hiddenReason`), deletes the file and sends no push.
- Images are re-encoded to JPEG (long side 1600) and written back.
- More than 20 messages from one sender in 60 seconds, or more than 30 media lines in an hour, hides the extra line (`hiddenReason: "rate"`).
- A reporter with more than 10 reports in 24 hours gets the report flagged `throttled: true` and no evidence copy.
- `push.NEW_MESSAGE_TEXT_MODE = "generic"`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `contracts/coaching_contract.json` | edit | new limits, enum values, `chatMediaPathPattern` |
| `functions/coaching/coaching_contract.json` | edit | byte-identical copy of the above (a test checks it) |
| `functions/coaching/blobs.py` | edit | add `info(path)` |
| `functions/tests/fake_blobs.py` | edit | add `info(path)` |
| `functions/coaching/chat.py` | edit | media check, rate limit, hold constant |
| `functions/coaching/push.py` | edit | `NEW_MESSAGE_TEXT_MODE`, `newMessageFrom` text, `send_kind` name |
| `functions/main.py` | edit | pass blobs and reencode to `on_message`; report throttle in `on_coaching_report` |
| `functions/tests/test_coaching_chat.py` | edit | new tests (also `test_coaching_push.py`, see Tests) |

(`firebase/firestore.indexes.json` is edited in WO-02b.)

## Steps
1. File `contracts/coaching_contract.json`. In `limits`, after the line `"pushThrottleMinutes": 3,` insert:
```json
    "chatImageMaxBytes": 3000000,
    "chatImageLongSidePx": 1600,
    "chatVideoMaxBytes": 25000000,
    "chatVideoMaxSeconds": 30,
    "chatAudioMaxBytes": 2000000,
    "chatAudioMaxSeconds": 120,
    "chatMessagesPerMinute": 20,
    "chatMediaPerHour": 30,
    "reportsPerDay": 10,
```
In `enums.messageTypeClient` (about line 291) replace the list with `["text", "recipe", "image", "video", "audio"]`. Then copy the file: `cp contracts/coaching_contract.json functions/coaching/coaching_contract.json`.
2. File `functions/coaching/blobs.py`, class `PersonalBlobs`, after `exists`, add:
```python
    def info(self, path: str):
        """(size in bytes, content type) of a file, or None when it is not there."""
        try:
            blob = self._bucket.blob(path)
            blob.reload()
            return int(blob.size or 0), blob.content_type or ""
        except Exception:
            return None
```
3. File `functions/tests/fake_blobs.py`, class `FakeBlobs`, after `exists`, add:
```python
    def info(self, path: str):
        if path not in self.objects:
            return None
        data, content_type = self.objects[path]
        return len(data), content_type
```
4. File `functions/coaching/chat.py`. After `CONTACT, PAYMENT, LINK, ABUSE = ...` add:
```python
CHAT_MEDIA_HOLD = "after"
"""Owner decision 4 (open). "after": media shows at once and can be reported.
"before": media is hidden with reason "held"; NO release path exists yet, so
do not switch it until the dashboard queue is built."""

MEDIA_TYPES = ("image", "video", "audio")
_MEDIA_MIME = {
    "image": ("image/jpeg",),
    "video": ("video/mp4", "video/quicktime"),
    "audio": ("audio/mp4", "audio/aac", "audio/x-m4a"),
}
_MEDIA_MAX = {
    "image": LIMITS["chatImageMaxBytes"],
    "video": LIMITS["chatVideoMaxBytes"],
    "audio": LIMITS["chatAudioMaxBytes"],
}
_MEDIA_SECONDS = {"video": LIMITS["chatVideoMaxSeconds"], "audio": LIMITS["chatAudioMaxSeconds"]}


def media_problem(rel_id: str, sender: str, data: dict, blobs) -> Optional[str]:
    """None when the media line is fine, else the hiddenReason."""
    kind = data.get("type")
    path = data.get("mediaPath")
    if not isinstance(path, str) or not path.startswith(f"chat-media/{rel_id}/{sender}/") or ".." in path:
        return "media"
    found = blobs.info(path)
    if found is None:
        return "media"
    size, content_type = found
    if size <= 0 or size > _MEDIA_MAX[kind] or content_type not in _MEDIA_MIME[kind]:
        return "media"
    if kind in _MEDIA_SECONDS:
        ms = data.get("durationMs")
        if isinstance(ms, bool) or not isinstance(ms, int) or not 500 <= ms <= _MEDIA_SECONDS[kind] * 1000 + 1500:
            return "media"
    return None


def too_fast(db, rel_ref, sender: str, kind: str, now: dt.datetime) -> bool:
    """More than chatMessagesPerMinute lines in 60 s, or chatMediaPerHour media
    lines in an hour, from this sender (the new line counts)."""
    lines = rel_ref.collection("messages")
    minute = lines.where("senderUid", "==", sender).where("createdAt", ">=", now - dt.timedelta(seconds=60))
    if sum(1 for _ in minute.stream()) > LIMITS["chatMessagesPerMinute"]:
        return True
    if kind in MEDIA_TYPES:
        hour = lines.where("senderUid", "==", sender).where("createdAt", ">=", now - dt.timedelta(hours=1))
        if sum(1 for m in hour.stream() if (m.to_dict() or {}).get("type") in MEDIA_TYPES) > LIMITS["chatMediaPerHour"]:
            return True
    return False
```
Change the signature of `on_message` (about line 160) to add `blobs=None, reencode=None,` after `notify: common.Notify,`, i.e.
`def on_message(db, rel_id, message_id, data, *, now, notify, blobs=None, reencode=None) -> dict:` (keep the existing one-parameter-per-line formatting). Inside, right after the line `reason = None` and the existing `if is_client_type and isinstance(data.get("text"), str): reason = screen(...)` block, add:
```python
    kind = data.get("type")
    if reason is None and is_client_type and too_fast(db, rel_ref, sender, kind, now):
        reason = "rate"
    if reason is None and kind in MEDIA_TYPES:
        if blobs is None:
            reason = "media"
        elif CHAT_MEDIA_HOLD == "before":
            reason = "held"
        else:
            reason = media_problem(rel_id, sender, data, blobs)
        if reason is None and kind == "image" and reencode is not None:
            try:
                blobs.write(data["mediaPath"], reencode(blobs.read(data["mediaPath"]), long_side=LIMITS["chatImageLongSidePx"]), "image/jpeg")
            except Exception:
                reason = "media"
        if reason is not None and blobs is not None and isinstance(data.get("mediaPath"), str) \
                and data["mediaPath"].startswith(f"chat-media/{rel_id}/{sender}/"):
            blobs.delete(data["mediaPath"])
```
Find the line `changes = {"lastMessageAt": now, "lastMessage": {**preview(data, hidden), "at": now}}`; `preview` already returns type "hidden" when hidden, so no change there. The existing hidden branch (`transaction.update(message_ref, {"hidden": True, "hiddenReason": reason, "text": ""})`) already works for the new reasons; also add `"mediaPath": None` to that update dict so a hidden line leaves no path. In `preview()` nothing changes for media (words stay empty).
5. File `functions/coaching/push.py`. After the `TITLE` constant block (before `TEXT = {`, find with `grep -n "^TEXT" functions/coaching/push.py`) add `NEW_MESSAGE_TEXT_MODE = "generic"  # "generic" or "first_name" (owner decision 5)`. Inside `TEXT`, after the `"newMessage"` entry add:
```python
    "newMessageFrom": {
        "en": (TITLE, "{name} sent you a message."),
        "ar": (TITLE, "{name} بعتتلك رسالة."),
    },
```
Replace `text_for` and the top of `send_kind`:
```python
def text_for(kind: str, locale: Optional[str], name: str = "") -> tuple[str, str]:
    """Title and body for a kind. Arabic is the fallback, as for every push."""
    by_locale = TEXT[kind]
    title, body = by_locale.get(locale or "", by_locale["ar"])
    return title, body.replace("{name}", name)
```
In `send_kind`, first lines become:
```python
    kind, _, name = kind.partition(":")
    if kind not in TEXT:
        return 0
```
and the `texts=` lambda becomes `texts=lambda phone_locale: text_for(kind, phone_locale, name)`.
6. File `functions/coaching/chat.py`, `on_message`, at the end: replace `notify(recipient, "newMessage")` with:
```python
    if recipient is not None:
        from . import push

        label = "newMessage"
        if push.NEW_MESSAGE_TEXT_MODE == "first_name" and recipient == parties_client(db, rel_id):
            first = _coach_first_name(db, sender)
            label = f"newMessageFrom:{first}" if first else "newMessage"
        notify(recipient, label)
```
and add the two helpers above `on_message` (only the coach is ever named, never a client):
```python
def parties_client(db, rel_id: str):
    return (db.collection("relationships").document(rel_id).get().to_dict() or {}).get("clientUid")


def _coach_first_name(db, coach_uid: str) -> str:
    name = (db.collection("coaches").document(coach_uid).get().to_dict() or {}).get("displayName") or ""
    return name.split()[0][:20] if name.split() else ""
```
7. File `functions/main.py`, function `on_coaching_message` (about line 2398): change the `chat.on_message(` call to add `blobs=_PersonalBlobs(), reencode=_reencode,` after `notify=_coaching_notify,` (`_PersonalBlobs` and `_reencode` already exist: used at lines 1955-1969).
8. File `functions/main.py`, function `on_coaching_report` (about line 2415): before `moderation.capture_evidence(...)` insert the throttle:
```python
        from datetime import timedelta

        db = store.db()
        data = event.data.to_dict() or {}
        since = _coaching_now() - timedelta(hours=24)
        mine = db.collection("reports").where("reporterUid", "==", data.get("reporterUid")).where("createdAt", ">=", since)
        if sum(1 for _ in mine.stream()) > common_limits()["reportsPerDay"]:
            db.collection("reports").document(event.params["reportId"]).update({"throttled": True})
            return
```
and add near the other helpers in main.py `def common_limits(): from coaching import common; return common.LIMITS`. (If you prefer, import `common` inside the function; keep it one place.)
9. Files `functions/tests/test_coaching_chat.py` and `functions/tests/test_coaching_push.py`: add the tests listed below.
10. Run the commands in Verify.

## Strings to add
None (server codes only; the app words `rate`, `media`, `held` in WO-02e through the existing hidden notice).

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| `functions/tests/test_coaching_chat.py` | `test_a_good_image_is_kept_and_reencoded` | `FakeBlobs().put(f"chat-media/{REL}/client1/a.jpg", b"raw", "image/jpeg")`; `_add` a message `senderUid="client1", type="image", mediaPath=<that>`; call `chat.on_message(db, REL, "m1", row, now=NOW, notify=notes, blobs=blobs, reencode=lambda raw, long_side=None: b"clean:"+raw)`. Assert `result["hidden"] is False`, `blobs.objects[path][0] == b"clean:raw"`, `notes.sent == [("coach1","newMessage")]` |
| same | `test_media_from_the_wrong_path_is_hidden_and_deleted` | path `chat-media/{REL}/coach1/a.jpg` sent by client1; assert `hidden True`, `reason == "media"`, file in `blobs.deleted`, `notes.sent == []` |
| same | `test_missing_file_oversize_and_wrong_type_are_hidden` | three rows (no blob; blob of 3_000_001 bytes image/jpeg; blob image/png); each `reason == "media"` |
| same | `test_video_and_audio_need_a_sane_duration` | video with `durationMs=31600` hidden; with `30000` fine; audio `durationMs=0` hidden; `120000` fine |
| same | `test_hold_before_hides_media_with_reason_held` | `monkeypatch.setattr(chat, "CHAT_MEDIA_HOLD", "before")`; good image; assert `reason == "held"` |
| same | `test_the_21st_message_in_a_minute_is_hidden_as_rate` | add 20 text messages with `createdAt=NOW` from client1, then the 21st; assert last result `reason == "rate"`, first 20 not hidden |
| same | `test_the_31st_media_line_in_an_hour_is_hidden` | 31 good image rows spread 1 per 100 s (`createdAt=NOW - 100*i s`) then one now; assert `reason == "rate"` |
| `functions/tests/test_coaching_push.py` | `test_first_name_variant_fills_the_name` | `push.text_for("newMessageFrom","en","Rahma")[1] == "Rahma sent you a message."`; Arabic `"Rahma بعتتلك رسالة."` |
| same | `test_default_mode_is_generic` | `assert push.NEW_MESSAGE_TEXT_MODE == "generic"` |
| same | `test_send_kind_with_a_name_suffix` | `push.send_kind("her","newMessageFrom:Rahma", db=db, messaging=messaging, locale="en")`; body equals `"Rahma sent you a message."` (reuse the fixtures of the existing test at line 89) |
| `functions/tests/test_coaching_chat.py` | `test_first_name_mode_names_only_the_coach` | `monkeypatch.setattr(push,"NEW_MESSAGE_TEXT_MODE","first_name")`; seed `coaches/coach1` `displayName "Rahma Mohsen"`; coach message pushes `("client1","newMessageFrom:Rahma")`; client message pushes `("coach1","newMessage")` |

## Verify
- `cd functions && venv/bin/python -m pytest tests/test_coaching_chat.py tests/test_coaching_push.py tests/test_coaching_contract.py -q` : last line `N passed` and no failures. (If `venv/bin/python` is missing, `python3 -m pytest` from `functions/`; UNVERIFIED: run `ls functions/venv/bin/python`.)
- `cmp contracts/coaching_contract.json functions/coaching/coaching_contract.json` prints nothing.

## Do not
- Do not set `CHAT_MEDIA_HOLD` to `"before"` or `NEW_MESSAGE_TEXT_MODE` to `"first_name"` in this release.
- Do not loosen `screen()` or the text rules. Do not add a caption field to media.
- Do not change the Dart contract here (WO-02c does it; `app/test/contracts/coaching_contract_test.dart` will fail until then, that is expected).
- No em dashes in any string. No AI comments or attribution in code.

## Done checklist
- [ ] contract JSON edited and copied
- [ ] blobs `info` added in real and fake
- [ ] `on_message` media check, rate limit, hold constant
- [ ] push constant and name variant
- [ ] report throttle in main.py
- [ ] new pytest tests pass

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one (WO-02d does not depend on this).
