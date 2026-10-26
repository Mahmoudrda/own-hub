# WO-02d: Microphone permission, audio package, and the privacy wording for audio, photo and video in chat
Depends on: none (can run in parallel with WO-02a)
Size: M
Reads first: `app/pubspec.yaml` lines 95-130, `app/android/app/src/main/AndroidManifest.xml` lines 1-40, `app/ios/Runner/Info.plist` lines 20-40, `app/ios/Runner/PrivacyInfo.xcprivacy` lines 100-140, `app/android/play-data-safety.txt` (all), `docs/release/launch-pack/app-store-privacy-answers.md` (all)

## Why
Voice notes need the microphone on both phones, and video from the camera needs it on iPhone. Both stores and the privacy policy must say, before the build, that audio, photos and video sent in coaching chat are collected. Android currently strips `RECORD_AUDIO` on purpose; that must change in the same release as the Play form.

## Package decision (checked 26 Oct 2026, offline)
- Recording: `record` (pub.dev). NOT in the offline pub cache (`ls ~/.pub-cache/hosted/pub.dev | grep -i "^record"` shows only `record_use`, an unrelated SDK package). Version `^6.1.2`, licence and minimums are UNVERIFIED from memory: licence believed BSD-3-Clause (a permissive licence, no store problem), iOS 12.0 and Android minSdk 23 (this app: iOS 15.5, minSdk 24, both fine). Verify with the commands in step 1 before any code uses it.
- Playback: no new package. `video_player ^2.14.1` is already a dependency and plays an `.m4a` (AAC) over `networkUrl` on both platforms. UNVERIFIED on a device: verify in WO-02f on the Android emulator `ownhub_pixel8` and a real iPhone. Rejected: `just_audio`, `audioplayers` (not cached, and a second player is not needed).
- Photo and video: `image_picker ^1.2.4` (already a dependency): `pickImage`, `pickVideo(maxDuration: 30 s)`. The photo library uses the system picker (no permission). The camera uses the CAMERA permission already declared.

## Final result
- The app asks for the microphone only when she first holds the mic button.
- iPhone sheet text (English / Egyptian Arabic) below; Android manifest declares `RECORD_AUDIO`.
- Privacy policy, Play data safety and App Store answers carry the exact text below.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `app/pubspec.yaml` | edit | add `record` |
| `app/android/app/src/main/AndroidManifest.xml` | edit | declare RECORD_AUDIO instead of removing it |
| `app/ios/Runner/Info.plist` | edit | `NSMicrophoneUsageDescription`, extend the camera sentence |
| `app/ios/Runner/en.lproj/InfoPlist.strings`, `app/ios/Runner/ar.lproj/InfoPlist.strings` | edit | same keys in both languages |
| `app/ios/Runner/PrivacyInfo.xcprivacy` | edit | two collected data types |
| `app/android/play-data-safety.txt` | edit | audio, photos and videos lines |
| `docs/release/launch-pack/app-store-privacy-answers.md` | edit | microphone, audio, photos or videos answers |
| `site/privacy.html` | edit | one new section (and `site/ar/privacy.html` UNVERIFIED path: `ls site/ar`) |

## Steps
1. Run `cd app && flutter pub add record` (needs the network; if it fails with no network, write the failure to `handover/QUESTIONS.md` and stop this order). Then verify: `grep -n "^version\|^repository" ~/.pub-cache/hosted/pub.dev/record-*/pubspec.yaml`, `head -5 ~/.pub-cache/hosted/pub.dev/record-*/LICENSE`, and `grep -rn "minSdk\|platform :ios\|s.platform" ~/.pub-cache/hosted/pub.dev/record_android-*/android/build.gradle ~/.pub-cache/hosted/pub.dev/record_darwin-*/darwin/*.podspec`. Write the three real answers (version, licence name, minimum iOS, minimum Android) in the report. If the licence is not MIT, BSD or Apache, stop and ask. Add this comment above the line in `pubspec.yaml`:
```yaml
  # Chat voice notes (hold to record, AAC in an .m4a file, 120 s at most).
  # The microphone is asked for only on the first hold. Declared as audio
  # data in ios/Runner/PrivacyInfo.xcprivacy and android/play-data-safety.txt.
```
2. File `AndroidManifest.xml`. Replace the line
`<uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove" />`
with
```xml
    <!-- Voice notes in the coaching chat (hold to record). Asked at the
         first hold, never at launch. The camera capture still records no
         sound (enableAudio is false); video messages use the system camera
         app through image_picker. Declared in play-data-safety.txt. -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
```
and in the comment above (the block starting `Stripped from the MERGED manifest`) change the words `Neither may reach a store build` to `READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE may not reach a store build`.
3. File `Info.plist`. After the `NSCameraUsageDescription` string add:
```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>Own Hub uses the microphone only when you hold the mic button in a coaching chat to record a voice note, or record a video with sound to send your coach. Nothing is recorded until you press, and nothing is sent until you let go. Voice notes and videos you send are kept for the length of your coaching so you and your coach can listen and watch again.</string>
```
and append to the existing camera sentence, before the final full stop of the whole string: ` Photos and videos you choose to send in a coaching chat are uploaded to your coach.` Also add to the comment near line 25 that photo-library access still uses the system picker (no `NSPhotoLibraryUsageDescription`, unchanged).
4. File `app/ios/Runner/en.lproj/InfoPlist.strings`: add the same two edits (the key `"NSMicrophoneUsageDescription" = "<same English text>";`). File `ar.lproj/InfoPlist.strings`:
```
"NSMicrophoneUsageDescription" = "Own Hub بتستخدم الميكروفون بس لما تفضلي ضاغطة على زرار الميكروفون في شات التدريب عشان تسجّلي رسالة صوتية، أو لما تصوّري فيديو بصوت تبعتيه لمدرّبتك. مفيش حاجة بتتسجّل قبل ما تضغطي، ومفيش حاجة بتتبعت قبل ما تسيبي الزرار. الرسايل الصوتية والفيديوهات اللي بتبعتيها بتفضل طول مدة التدريب عشان إنتي ومدرّبتك تسمعوها وتشوفوها تاني.";
```
and append to the Arabic camera string, before its closing quote: ` والصور والفيديوهات اللي بتختاري تبعتيها في شات التدريب بتترفع لمدرّبتك.`
5. File `PrivacyInfo.xcprivacy`: inside the `NSPrivacyCollectedDataTypes` array add two `<dict>` entries copying the layout of the existing `PhoneNumber` entry (lines ~125-135, open it first): types `NSPrivacyCollectedDataTypeAudioData` and `NSPrivacyCollectedDataTypePhotosorVideos`, `NSPrivacyCollectedDataTypeLinked` = true, `NSPrivacyCollectedDataTypeTracking` = false, purposes `NSPrivacyCollectedDataTypePurposeAppFunctionality`. If `PhotosorVideos` already exists (line 46 mentions it in a comment, UNVERIFIED if as a key: `grep -n "PhotosorVideos" app/ios/Runner/PrivacyInfo.xcprivacy`), do not duplicate it; only add `AudioData`.
6. File `app/android/play-data-safety.txt`: open it, find how photos and videos and audio are written (UNVERIFIED current wording; `grep -n -i "audio\|photo\|video" app/android/play-data-safety.txt`) and make these answers true:
```
Audio files (voice notes): Collected = yes. Shared = no. Required = no (optional feature).
  Purpose: App functionality. Encrypted in transit: yes. Deletion: deleted with the coaching chat or her account.
Photos and videos: Collected = yes (chat photos and clips in addition to the coach photos already declared).
  Shared = no. Required = no. Purpose: App functionality. Encrypted in transit: yes.
```
7. File `docs/release/launch-pack/app-store-privacy-answers.md`: add under the data types list:
```
Audio Data: Yes, collected. Linked to the user: Yes. Used for tracking: No. Purpose: App Functionality.
  Where: voice notes she records and sends to her coach in a coaching chat.
Photos or Videos: Yes, collected. Linked: Yes. Tracking: No. Purpose: App Functionality.
  Where: form-check photos and short clips she or her coach sends in a coaching chat.
Microphone: used only on a press and hold in a coaching chat. No speech recognition. No recording is made in the background.
```
(The App Store review note: "Voice notes and video in coaching chat need a coaching relationship; the reviewer test account has one" is added by the owner in `docs/release/review-notes.md`; not this order.)
8. File `site/privacy.html` (and the Arabic page): add a section in the same markup as its neighbours (open the file, copy a heading and paragraph pair). Exact English text:
```
Voice notes, photos and videos in coaching chat
If you coach with a coach on Own Hub you can send her, and she can send you, voice notes, photos and short videos (up to 120 seconds of audio and 30 seconds of video). Own Hub asks for your microphone only when you press and hold the mic button, and for your camera or a photo you pick only when you choose to send one. We store these files so that you and your coach, and nobody else, can listen and watch again. They are sent over an encrypted connection and are not used for advertising, for training any model, or for anything other than showing them in the chat. Photos are re-saved without the location and device details your phone adds. Videos can still contain such details, so film in a place you are happy to share. If a message is reported, a woman reviewer at Own Hub may see that file. The files are deleted when the coaching chat is deleted and when you delete your account.
```
Exact Egyptian Arabic text:
```
رسايل صوتية وصور وفيديوهات في شات التدريب
لو بتتدرّبي مع مدرّبة على Own Hub تقدري تبعتيلها، وهي كمان تبعتلك، رسايل صوتية وصور وفيديوهات قصيرة (لحد 120 ثانية صوت و30 ثانية فيديو). Own Hub بتطلب الميكروفون بس لما تضغطي وتفضلي ضاغطة على زرار الميكروفون، وبتطلب الكاميرا أو صورة تختاريها بس لما تقرري تبعتيها. بنحفظ الملفات دي عشان إنتي ومدرّبتك بس، ومحدش غيركم، تسمعوها وتشوفوها تاني. بتتبعت بإتصال مشفّر، ومش بنستخدمها في إعلانات ولا لتدريب أي نموذج ولا لأي حاجة غير إنها تظهر في الشات. الصور بنحفظها من غير الموقع وبيانات الموبايل اللي موبايلك بيضيفها. الفيديوهات ممكن يفضل فيها الحاجات دي، فصوّري في مكان مرتاحة إنه يتشاف. لو رسالة اتبلّغ عنها، ممكن مراجِعة من Own Hub تشوف الملف ده. الملفات بتتمسح لما شات التدريب يتمسح ولما تمسحي حسابك.
```
9. Retention claim check: the text says files are deleted with the chat and the account. UNVERIFIED that deletion does this: run `grep -n "chat-media\|STORAGE_PREFIXES" functions/account/deletion.py` ; if `chat-media/` is not covered, add `"chat-media/"` handling per the file's existing pattern (a prefix list), and write it to `handover/QUESTIONS.md` because chat files are keyed by relId, not by uid (a prefix delete by uid will not find them; the deletion order must list `chat-media/{relId}/{uid}/` for each of her relationships). Do not publish the privacy text until this is true.
10. Run Verify.

## Strings to add
None in the l10n files (the permission texts are in `InfoPlist.strings`).

## Tests to add or change
| file | test name | exact arrange, act and assert |
|---|---|---|
| UNVERIFIED which test guards the manifest: `grep -rln "RECORD_AUDIO" app/test app/tool` | existing manifest or preflight test | change its expectation from "RECORD_AUDIO is removed" to "RECORD_AUDIO is declared and READ/WRITE_EXTERNAL_STORAGE are removed" |
| same search for `NSMicrophoneUsageDescription` | existing Info.plist test | expect the key present in `Info.plist` and both `InfoPlist.strings` |

## Verify
- `cd app && flutter pub get` : `Got dependencies!`
- `cd app && flutter analyze` : `No issues found!`
- `grep -n "RECORD_AUDIO" app/android/app/src/main/AndroidManifest.xml` : one line without `tools:node="remove"`.
- `plutil -lint app/ios/Runner/Info.plist app/ios/Runner/PrivacyInfo.xcprivacy` : both `OK`.
- `cd app && tool/build_ios.sh --help` is NOT run here; preflight is run by the owner (`app/tool/build_ios.sh` preflight expects 83/0 earlier; if it checks Info.plist keys it will now list the new one).

## Do not
- Do not add `NSSpeechRecognitionUsageDescription` (no speech recognition in chat).
- Do not add `NSPhotoLibraryUsageDescription` or any storage permission (system picker only).
- Do not publish the privacy text before step 9 is true.
- Do not use em dashes in any text above (none are used).

## Done checklist
- [ ] `record` added and licence, version, minimums reported
- [ ] manifest, Info.plist, both InfoPlist.strings
- [ ] privacy manifest, Play safety file, App Store answers
- [ ] privacy page EN and AR
- [ ] deletion coverage answered

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
