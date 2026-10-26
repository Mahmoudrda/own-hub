# WO-04c: iOS associated domains, Android app links, the website's link files and the "no app yet" page (C1, part 3)
Depends on: WO-04b (the paths `/c/<code>` and `/p/<uid>` are defined there)
Size: M
Reads first: `app/ios/Runner/Runner.entitlements` (whole, 17 lines); `app/android/app/src/main/AndroidManifest.xml` lines 100-120; `site/_build/build.py` lines 60-100 and 775-790; `site/_build/pages_en.py` lines 1925-1945 (the `support` page, the pattern to copy); `site/_headers` (whole); `site/_redirects` last 12 lines

## Why
For a tap on `https://own-hub.app/c/ABCD2345` to open the app, Apple needs the Associated Domains entitlement plus a file at `/.well-known/apple-app-site-association`, and Android needs an `autoVerify` intent filter plus `/.well-known/assetlinks.json`. Today none exists (checked 26 Oct: no `site/.well-known/`, no `associated-domains` key, the only intent filters are MAIN/LAUNCHER, BOOT_COMPLETED and the widget). A woman without the app must not land on a 404: she gets a short page that says what to do.

## Final result
- The site serves, with no redirect and with content type `application/json`: `https://own-hub.app/.well-known/apple-app-site-association` and `https://own-hub.app/.well-known/assetlinks.json`.
- `https://own-hub.app/c/<anything>` and `https://own-hub.app/p/<anything>` (and `/ar/...` is not used; one page each language is reached from the page's own language link) both answer 200 with the page `/join`. The page has no script (the site's CSP forbids scripts) so it cannot read the code; it says to use the code in the message.
- Page `/join` (English), top to bottom: H1 "Open this in Own Hub"; paragraph "Own Hub is a training app for women only. If your coach sent you this link, install the app. When you sign up, tap I have a code from my coach and type the code from her message."; the store badges the home page uses (the site's `store_badges` helper; each shows the site's "to be completed" marker until the store links are set in `site/config.json`, which is the site's existing rule); small link "العربية" to `/ar/join`.
- Page `/ar/join`: H1 "افتحي ده في Own Hub"; paragraph "Own Hub تطبيق تمرين للستات بس. لو مدرّبتك بعتتلك اللينك ده، نزّلي التطبيق. ولما تسجّلي اضغطي «معايا كود من مدرّبتي» واكتبي الكود اللي في رسالتها."; badges; link "English" to `/join`.
- iPhone and Android with the app installed: the link opens the app (WO-04b handles the path).

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/ios/Runner/Runner.entitlements` | edit | `com.apple.developer.associated-domains` = `applinks:own-hub.app` |
| `app/android/app/src/main/AndroidManifest.xml` | edit | `autoVerify` intent filter on MainActivity |
| `site/.well-known/apple-app-site-association` | create | JSON, no extension |
| `site/.well-known/assetlinks.json` | create | JSON |
| `site/_headers` | edit | content type rule for the two files |
| `site/_redirects` | edit | rewrite `/c/*` and `/p/*` to `/join` with status 200 |
| `site/_build/build.py` | edit | `STATIC` gains `.well-known`; page key `join` in `PATHS`, `FILES`, `NOINDEX` |
| `site/_build/pages_en.py`, `site/_build/pages_ar.py` | edit | the `join` page |
(Nine files: do the two `pages_*` edits as one step; if the agent prefers, split the site half into WO-04c2.)

## Steps
1. `Runner.entitlements`: inside the top `<dict>`, after the `com.apple.security.application-groups` array (before `</dict>`), add:
```xml
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:own-hub.app</string>
	</array>
```
Owner step (cannot be done in code; write it in `docs/owner/OWNER-TODO.md` under the same dated list the file already uses): in the Apple developer portal, App ID `com.ownhub.fitness`, tick Associated Domains, regenerate the store profile, then `app/tool/build_ios.sh` (its preflight reads the entitlements; if a preflight check fails on the new key, stop and ask).
2. `AndroidManifest.xml`: inside the `<activity ...>` that holds the MAIN/LAUNCHER filter, directly after that `</intent-filter>` (about line 116), add:
```xml
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="own-hub.app" android:pathPrefix="/c/"/>
                <data android:scheme="https" android:host="own-hub.app" android:pathPrefix="/p/"/>
            </intent-filter>
```
Flutter 3.47 handles links by default; the manifest has no `flutter_deeplinking_enabled` entry (grep printed none), so add nothing else.
3. Create `site/.well-known/apple-app-site-association` (team id verified: `DEVELOPMENT_TEAM = NC94DG55XR` in `app/ios/Runner.xcodeproj/project.pbxproj`; bundle id `com.ownhub.fitness`):
```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["NC94DG55XR.com.ownhub.fitness"],
        "components": [
          { "/": "/c/*", "comment": "A coach's invite" },
          { "/": "/p/*", "comment": "A coach's profile" }
        ]
      }
    ]
  }
}
```
4. Create `site/.well-known/assetlinks.json`. The release fingerprints are the owner's; do not invent them:
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.ownhub.app",
      "sha256_cert_fingerprints": []
    }
  }
]
```
Add to `docs/owner/OWNER-TODO.md`: "Paste the SHA-256 of the Play App Signing key (Play Console, Setup, App signing) and of the upload key into `site/.well-known/assetlinks.json`, then redeploy the site. Until then Android opens these links in the browser (the /join page), not the app."
5. `site/_headers`: add at the end:
```
/.well-known/apple-app-site-association
  Content-Type: application/json
  Cache-Control: public, max-age=3600

/.well-known/assetlinks.json
  Content-Type: application/json
  Cache-Control: public, max-age=3600
```
The `/*` rule's headers also apply; none of them sets Content-Type, so the rules do not clash (the header comment at the top of the file forbids two rules setting the same header on one path).
6. `site/_redirects`: add above the line `# --- The generator is not part of the website`:
```
# --- App links: the app opens these; without it the visitor lands on /join --
/c/*                   /join               200
/p/*                   /join               200
```
7. `site/_build/build.py`: line 779 `STATIC = ("assets", "_headers", "_redirects")` becomes `STATIC = ("assets", "_headers", "_redirects", ".well-known")`. In `PATHS` (line 72) add `"join": ("/join", "/ar/join"),`; in `FILES` (line 96) add `"join": ("join.html", "ar/join.html"),`; in `NOINDEX` (line 83) make it `{"waitlist-joined", "waitlist-check", "waitlist-later", "join"}`. UNVERIFIED whether other tables key on the page set (sitemap, link checker, nav): run `grep -n "waitlist-later\|NOINDEX\|PATHS\[" site/_build/build.py` and `grep -rn "waitlist-later" site/_build/*.py tests 2>/dev/null` and add `join` wherever `waitlist-check` is listed and a plain page is expected.
8. `site/_build/pages_en.py`, directly after the `pages["support"] = {...}` block, add (copy the dict shape; keys `title`, `description`, `body`):
```python
    pages["join"] = {
        "title": "Open this in Own Hub",
        "description": "How to open a coach's invitation or profile link in Own Hub.",
        "body": """
    <div class="wrap">
      <div class="prose">
        <h1>Open this in Own Hub</h1>
        <p class="lede">Own Hub is a training app for women only. If your coach
        sent you this link, install the app. When you sign up, tap <b>I have a
        code from my coach</b> and type the code from her message.</p>
        <p><a href="/ar/join">العربية</a></p>
      </div>
    </div>
""",
    }
```
and in `pages_ar.py` after its `pages["support"]` block the same with the Arabic texts above, `<p><a href="/join">English</a></p>`, and `lang`/direction handled by the generator as for the other Arabic pages. The store badges: UNVERIFIED how `store_badges(cfg, lang, where=...)` is injected into a page body (`pages_en.py` line 114-130 builds `hero_badges` inside `build`, not in `pages[...]`). Read `grep -n "store_badges" site/_build/pages_en.py site/_build/build.py`; if a body can use a `{{...}}` token for badges, use it; if not, leave the badges out of this page (the paragraph is enough) and say so in the report.
9. Build and check: `cd site && python3 _build/build.py` (as in `deploy.sh --dry-run`: `site/_build/deploy.sh https://own-hub.app --dry-run`).

## Strings to add
None in the app. The site texts are in step 8.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `app/test/features/coach/own_hub_link_test.dart` (created in WO-04b) | `the app's link paths are the ones the site and the manifest name` | read `../site/.well-known/apple-app-site-association`, `../app/android/app/src/main/AndroidManifest.xml` (run from `app/`, so `../site/...` and `android/app/src/main/AndroidManifest.xml`), `../site/_redirects`; assert the AASA text contains `/c/*` and `/p/*` and `NC94DG55XR.com.ownhub.fitness`; manifest contains `android:pathPrefix="/c/"`, `android:pathPrefix="/p/"` and `android:host="own-hub.app"`; `_redirects` contains `/c/*` and `/p/*`; entitlements (`ios/Runner/Runner.entitlements`) contain `applinks:own-hub.app` |
Run: `cd app && flutter test test/features/coach/own_hub_link_test.dart`

## Verify
- `python3 -c "import json;json.load(open('site/.well-known/apple-app-site-association'));json.load(open('site/.well-known/assetlinks.json'));print('ok')"` prints `ok`.
- The dry-run build folder (the script prints it) contains `.well-known/apple-app-site-association`, `join.html`, `ar/join.html`.
- After the owner deploys (not the agent): `curl -sI https://own-hub.app/.well-known/apple-app-site-association | head -5` shows `200` and `content-type: application/json` with no `location:` header; `curl -s -o /dev/null -w "%{http_code}" https://own-hub.app/c/ABCD2345` prints `200`. Cloudflare Pages must keep dot folders: UNVERIFIED, this curl is the check. If it prints 404, the deploy script ignores `.well-known`; then report it and stop (do not rename the folder).
- Real devices (owner): iPhone with the store build: tap the link in Notes; Android release build: `adb shell pm get-app-links com.ownhub.app` shows `own-hub.app: verified` once the fingerprints are in.

## Do not
- Do not invent SHA-256 fingerprints. Do not add other paths to the link files. Do not add a script to the site (the CSP in `_headers` has no script-src on purpose). Do not put the code anywhere a crawler could index it (`join` is noindex).
- Do not change the `aps-environment` value in the entitlements (the build script handles it).

## Done checklist
- [ ] entitlements + manifest + two `.well-known` files
- [ ] `_headers`, `_redirects`, `build.py`, two page files
- [ ] build dry-run succeeds; test passes
- [ ] two owner lines added to `docs/owner/OWNER-TODO.md`

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
