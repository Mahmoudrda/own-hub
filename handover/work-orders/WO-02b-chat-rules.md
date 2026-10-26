# WO-02b: Firestore and Storage rules for chat media, indexes, and their rules tests
Depends on: WO-02a (field names and limits)
Size: M
Reads first: `firebase/firestore.rules` lines 1160-1210, `firebase/storage.rules` lines 195-270 and 300-330, `firebase/firestore.indexes.json` (find the `messages` entries), `test/rules/20-private-coaching.test.js` lines 240-330, `test/rules/storage/storage.test.js` lines 60-120 and 324-345

## Why
The client writes the message document and uploads the file itself, so the rules are the first wall: only the two people of a relationship can read or write a chat file, only within size and type limits, and a message document can carry only the new fields in the right shape. The server (WO-02a) is the second wall.

## Final result
- Firestore: a party of an open, unblocked thread can create `image`, `video`, `audio` messages with `mediaPath` (path of her own folder), `durationMs`, `bytes`; nothing else new.
- Storage (personal bucket, `own-hub-personal`): `chat-media/{relId}/{uid}/{file}`. relId is `{coachUid}__{clientUid}`. Write: the signed-in verified owner `uid`, who must also be one of the two uids in relId, image/jpeg up to 3 MB, video/mp4 or video/quicktime up to 25 MB, audio/mp4 or audio/aac up to 2 MB. Read: either of the two uids in relId. Delete: only the owner folder's uid.
- Two composite indexes so the server's rate-limit queries work.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `firebase/firestore.rules` | edit | message create allows 3 new types and 3 keys |
| `firebase/storage.rules` | edit | new `chat-media` match above the catch-all |
| `firebase/firestore.indexes.json` | edit | `messages` (senderUid, createdAt) and `reports` (reporterUid, createdAt) |
| `test/rules/20-private-coaching.test.js` | edit | new tests in `describe('chat messages')` |
| `test/rules/storage/storage.test.js` | edit | new tests |

## Steps
1. File `firebase/firestore.rules`, `match /messages/{msgId}` create rule (about lines 1176-1204). Replace the three clauses that mention keys and type with:
```
                      && request.resource.data.keys().hasOnly(
                           ['senderUid', 'type', 'text', 'recipeId', 'createdAt',
                            'mediaPath', 'durationMs', 'bytes'])
                      && request.resource.data.keys().hasAll(
                           ['senderUid', 'type', 'createdAt'])
                      && request.resource.data.createdAt == request.time
                      && request.resource.data.type in ['text', 'recipe', 'image', 'video', 'audio']
```
Keep the existing `text` size and ten-digit clause. Replace the final `(request.resource.data.type == 'text' ? ... : ...)` clause with:
```
                      && (request.resource.data.type == 'text'
                          ? (('text' in request.resource.data)
                             && request.resource.data.text.size() >= 1
                             && !('recipeId' in request.resource.data)
                             && !('mediaPath' in request.resource.data))
                          : request.resource.data.type == 'recipe'
                          ? (request.resource.data.recipeId is string
                             && request.resource.data.recipeId.matches(
                                  '^[a-z0-9_-]{1,80}$')
                             && !('mediaPath' in request.resource.data))
                          : (!('text' in request.resource.data)
                             && !('recipeId' in request.resource.data)
                             && request.resource.data.mediaPath is string
                             && request.resource.data.mediaPath.matches(
                                  '^chat-media/' + relId + '/' + request.auth.uid + '/[A-Za-z0-9_.-]{1,80}$')
                             && request.resource.data.bytes is int
                             && request.resource.data.bytes > 0
                             && request.resource.data.bytes <= 25000000
                             && (request.resource.data.type == 'image'
                                 ? !('durationMs' in request.resource.data)
                                 : (request.resource.data.durationMs is int
                                    && request.resource.data.durationMs >= 500
                                    && request.resource.data.durationMs <= 121500))));
```
(`relId` is the wildcard of the enclosing match; if the emulator rejects it as undefined inside the nested match, UNVERIFIED: use `get(...)` free alternative `request.resource.data.mediaPath.split('/')[1] == relId`; verify with the Verify command.)
2. File `firebase/storage.rules`. Directly above the line `// ------------------------------------------------------------- default` (the catch-all section) insert:
```
    // -------------------------------------------------- coaching chat media
    //
    // chat-media/{relId}/{uid}/{file}. relId is {coachUid}__{clientUid}. The
    // two people of the thread read; only the folder's owner (one of the two)
    // writes, verified, within the limits. The service re-checks every file
    // when the message arrives and deletes what does not pass.
    function inThread(relId) {
      return signedIn() && request.auth.uid in relId.split('__');
    }

    function isChatVideo() {
      return request.resource.contentType in ['video/mp4', 'video/quicktime'];
    }

    function isChatAudio() {
      return request.resource.contentType in ['audio/mp4', 'audio/aac'];
    }

    function chatMediaWrite(relId, uid) {
      return coachClientsLiveStorage()
          && isOwner(uid)
          && inThread(relId)
          && request.auth.token.get('verified', false) == true
          && ((request.resource.contentType == 'image/jpeg' && request.resource.size <= 3 * 1024 * 1024)
              || (isChatVideo() && request.resource.size <= 25 * 1024 * 1024)
              || (isChatAudio() && request.resource.size <= 2 * 1024 * 1024));
    }

    match /chat-media/{relId}/{uid}/{file} {
      allow read: if coachClientsLiveStorage() && inThread(relId);
      allow create: if chatMediaWrite(relId, uid) && resource == null;
      allow update: if false;
      allow delete: if isOwner(uid);
    }

```
and next to `coachPaymentsLive()` add
```
    function coachClientsLiveStorage() {
      return true;
    }
```
(Firestore's `coachClientsLive()` is the matching switch; they move in the same release.)
3. File `firebase/firestore.indexes.json`. In the `indexes` array add (copy the exact object formatting of a neighbouring entry; UNVERIFIED: run `grep -n collectionGroup firebase/firestore.indexes.json | head` first):
```json
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "senderUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "reports",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "reporterUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
```
4. File `test/rules/20-private-coaching.test.js`, inside `describe('chat messages', ...)` after the test `'a run of ten digits ...'`, add the tests in the table below (helper `media`):
```js
  const media = (sender, type, extra = {}) => ({
    senderUid: sender, type, bytes: 1000,
    mediaPath: `chat-media/${REL}/${sender}/a1.jpg`,
    ...(type === 'image' ? {} : { durationMs: 5000 }),
    createdAt: serverTimestamp(), ...extra,
  });
```
5. File `test/rules/storage/storage.test.js`: add the tests below at the end, before the last test (`admin content uploads...`), using the file's existing helpers (`env.authenticatedContext(uid, {verified: true})` style; copy from the `gallery:` test at about line 398, UNVERIFIED helper names: open it first).
6. Run Verify.

## Strings to add
None.

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| `20-private-coaching.test.js` | `both parties can send image, video and voice lines` | HER sends `media(HER,'image')`, `media(HER,'video')`, coach sends `media(COACH,'audio')` (mediaPath uses own uid) : `assertSucceeds` each |
| same | `media needs its own folder, a size and a duration` | fails for: path in the other person's folder; path `chat-media/other__rel/...`; no `bytes`; `bytes: 26000000`; video without `durationMs`; video `durationMs: 100`; image with `durationMs` |
| same | `media cannot carry text, a recipe id or an unknown key` | `media(HER,'image',{text:'hi'})`, `{recipeId:'abc'}`, `{hidden:true}`, `{thumbPath:'x'}` all `assertFails` |
| same | `text and recipe cannot carry a media path` | `{...text(HER), mediaPath:'x'}` fails |
| same | `media obeys the open, active and block rules` | REL_ENDED, REL_CLOSED and REL_BLOCK senders fail (use each relId in the path) |
| `storage.test.js` | `chat media: the owner in the thread writes within the limits` | `chat-media/a__b/a/x.jpg` as uid `a` verified, jpeg 3 MB ok, 3 MB+1 fails, mp4 25 MB ok, 26 MB fails, audio/mp4 2 MB ok, audio/mpeg fails, image/png fails |
| same | `chat media: only the two people read, only the owner deletes` | uid `a` and `b` read; uid `c` read fails; `b` deletes `a`'s file fails; `a` deletes ok; second create at same path fails (no overwrite) |
| same | `chat media: a stranger or an unverified caller cannot write` | uid `c` writes `chat-media/a__b/c/x.jpg` fails; unverified `a` fails; anonymous fails |

## Verify
- Firestore rules: start the emulator the way `HOW-TO-RUN.md` section 6b says (UNVERIFIED exact command: `sed -n 149,175p HOW-TO-RUN.md`), then `cd test/rules && npm test -- 20-private-coaching.test.js` : the summary ends with `fail 0`.
- Storage rules: `cd test/rules && npm run test:storage` : `fail 0`.
- `python3 -m pytest functions/tests/test_rules_text.py -q` : `passed` (it reads the rules as text; if it fails on the new text, fix the text test only if it asserts a literal that this order changed, and write the change to QUESTIONS.md).

## Do not
- Do not touch `user-media/` or `coach-docs/` rules. Do not make chat files readable by `isAdmin()` or by reviewers: a woman's body photos stay between her and her coach. Staff see a reported file only through a later, separate order.
- Do not allow update on a chat file.

## Done checklist
- [ ] message rule extended
- [ ] storage `chat-media` match added above the catch-all
- [ ] two indexes added
- [ ] rules tests written and green

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
