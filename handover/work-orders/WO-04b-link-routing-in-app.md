# WO-04b: open an invite or profile link inside the app, and share both (C1, part 2)
Depends on: WO-04a
Size: M
Reads first: `app/lib/features/coach/domain/coach_invite.dart` (whole, 84 lines); `app/lib/main.dart` lines 604-660 (`_firstRunStack`); `app/lib/routing/app_router.dart` lines 529-552 (`onGenerateRoute` top) and 7296-7318 (`shareCoachInvite`); `app/lib/routing/coaching_wiring.dart` lines 251-256 (`CoachPortfolioArgs`); `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart`

## Why
Rahma sends an invite or her profile link on WhatsApp. If the woman has the app, tapping the link must open the app: an invite link stores the code and sends her request to the coach (exactly what typing the code on C01 does); a profile link opens Rahma's page (H02). Without the app she sees a web page (WO-04c) and types the code from the message. Flutter 3.47 (`flutter --version` printed 3.47.4) hands a platform link to the app as a route name equal to the URL path, for example `/c/ABCD2345`, both on a cold start (`defaultRouteName`) and while running (`onGenerateRoute`). No `app_links` package is needed.
Path choice: `/c/<code>` for an invite, `/p/<uid>` for a profile. NOT `/coach/<uid>`: `/coach/k07`, `/coach/k18` are existing route names (`app_routes.dart`). Flows `c` and `p` do not exist (checked: flows are account, admin, assistant, coach, coach-setup, coachbrand, coached, coaching, coachplan, community, cycle, eat, onboarding, progress, signup, today, train).

## Final result
- Rahma, K18 list: a new second row **Share my profile link** (EN) / **ابعتي لينك صفحتي** (AR), subtitle EN "Members who open it land on your page and can ask to join." / AR "أي عضوة تفتحه توصل لصفحتك وتقدر تطلب تنضم ليكي." Shown only when her portfolio is live. Tap opens the phone share sheet with: EN "Train with me on Own Hub: https://own-hub.app/p/<uid>" / AR "تدرّبي معايا على Own Hub: https://own-hub.app/p/<uid>". 2 taps to send (row, then pick the chat).
- Invite message (the existing "Invite a client" action) now carries the link and the code: EN "Join me on Own Hub, the training app for women only. Open this link: {link} If it does not open the app, install Own Hub, tap I have a code from my coach when you sign up and enter {code}." / AR "انضمّي ليّا على Own Hub، تطبيق التمرين للستات بس. افتحي اللينك ده: {link} ولو مافتحش التطبيق، نزّلي Own Hub، ولما تسجّلي اضغطي «معايا كود من مدرّبتي» واكتبي {code}."
- A woman with the app, taps an invite link:
  - app closed: the app opens on its front door as always; the code is kept; if she is verified it is sent at once and a notice says "Your coach has your request." / "طلبك وصل لمدرّبتك." (existing `yourCoachHasYourRequest`); if not verified it waits, as with a typed code, and the existing hooks (`redeemPendingInvite`, `app_router.dart` lines 1961, 2085, 2155) send it after her check.
  - app running: a small screen **OwnHubLinkView** opens: title EN "Your coach's invitation" / AR "دعوة مدرّبتك"; body EN "Saved. Once you are in, we will connect you with your coach." / AR "اتحفظ. أول ما تبقي معانا، هنوصّلك بمدرّبتك." (existing `savedOnceYouAreInWeWill`); ONE filled button EN "Continue" / AR "كمّلي" that pops. Invite code is redeemed in the background; the notice above shows when it lands. 1 tap.
- Profile link: app closed or running: Rahma's page H02 opens on top of the front door (the verification gate in `onGenerateRoute` sends an unverified woman to her check instead, as for every screen). 0 taps.
- A link that does not parse (wrong code, bad uid) is ignored: the front door opens; running app shows `OwnHubLinkView` with EN "This link does not work. Ask your coach to send it again." / AR "اللينك ده مش شغّال. اطلبي من مدرّبتك تبعتهولك تاني." and the same Continue button.

## Files to edit or create
| path | action | what changes |
|---|---|---|
| `app/lib/features/coach/domain/coach_invite.dart` | edit | add `OwnHubLink`, `parseOwnHubLink`, `kLinkHost`, `inviteLinkFor`, `profileLinkFor` |
| `app/lib/features/coach/presentation/own_hub_link_view.dart` | create | the small screen |
| `app/lib/main.dart` | edit | cold start handling in `_firstRunStack` |
| `app/lib/routing/app_router.dart` | edit | warm start in `onGenerateRoute`; `followLink`; new message in `shareCoachInvite`; `shareProfileLink` |
| `app/lib/features/private_coaching/presentation/coach/coach_space_view.dart` | edit | `onShareProfile` row |
| `app/test/features/coach/own_hub_link_test.dart` | create | parse tests and view test |
| `app/test/features/private_coaching/coach/coach_test.dart` | edit | profile row test |

## Steps
1. File `coach_invite.dart`, end of file (after `enum InviteRedemption`). Add:
```dart
/// The host the links live on. Same string as `site/config.json` "baseUrl".
const String kLinkHost = 'https://own-hub.app';

String inviteLinkFor(String code) => '$kLinkHost/c/$code';
String profileLinkFor(String coachUid) => '$kLinkHost/p/$coachUid';

enum OwnHubLinkKind { invite, profile }

class OwnHubLink {
  const OwnHubLink(this.kind, this.value);

  final OwnHubLinkKind kind;

  /// The normalised code, or the coach's uid.
  final String value;
}

final RegExp _uidShape = RegExp(r'^[A-Za-z0-9]{6,128}$');

/// What a platform link names, or null. [routeName] is the path (and query)
/// the platform hands the app, for example `/c/ABCD2345` or `/p/<uid>`.
OwnHubLink? parseOwnHubLink(String routeName) {
  final uri = Uri.tryParse(routeName);
  if (uri == null) return null;
  final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (parts.length != 2) return null;
  if (parts[0] == 'c') {
    final code = normaliseInviteCode(parts[1]);
    return code == null ? null : OwnHubLink(OwnHubLinkKind.invite, code);
  }
  if (parts[0] == 'p' && _uidShape.hasMatch(parts[1])) {
    return OwnHubLink(OwnHubLinkKind.profile, parts[1]);
  }
  return null;
}
```
2. Create `app/lib/features/coach/presentation/own_hub_link_view.dart`:
```dart
/// The screen a link opens while the app is already running. Invite links are
/// kept and sent by [AppRouter.followLink]; this only says so.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/coach_invite.dart';

class OwnHubLinkView extends StatefulWidget {
  const OwnHubLinkView({super.key, required this.link, required this.onOpen});

  /// Null when the link did not parse.
  final OwnHubLink? link;

  /// Called once, after the first frame, with the parsed link.
  final void Function(OwnHubLink link) onOpen;

  @override
  State<OwnHubLinkView> createState() => _OwnHubLinkViewState();
}

class _OwnHubLinkViewState extends State<OwnHubLinkView> {
  @override
  void initState() {
    super.initState();
    final link = widget.link;
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onOpen(link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ok = widget.link != null;
    return AppScaffold(
      showArt: false,
      appBar: AppTopBar(
        title: l10n.yourCoachsInvitation,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Text(ok ? l10n.savedOnceYouAreInWeWill : l10n.thisLinkDoesNotWorkAsk),
        AppButton(
          l10n.continueLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
```
`l10n.continueLabel`: UNVERIFIED getter. Run `grep -n '"continue' app/lib/l10n/app_en.arb | head` and use the existing Continue string's getter if one has the value "Continue" and Arabic "كمّلي"; only add a new string (see Strings) if none exists with those exact values. UNVERIFIED: `AppScaffold(showArt:, appBar: AppTopBar(...), children:)` and `AppTopBar` come from `ui/app_scaffold.dart`; this is the shape `coach_space_view.dart` uses (verified lines 79-86), so copy it.
3. File `app_router.dart`, method `onGenerateRoute` (line 529). After the line `if (name == null) return null;` insert:
```dart
    final link = parseOwnHubLink(name);
    if (link != null || _looksLikeOwnHubLink(name)) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => OwnHubLinkView(link: link, onOpen: followLink),
      );
    }
```
and add the helper next to `screenIdForRoute` (top level, about line 483):
```dart
/// A path shaped like a link (`/c/...` or `/p/...`) that did not parse, so she
/// sees "This link does not work" rather than a developer page.
bool _looksLikeOwnHubLink(String name) =>
    name.startsWith('/c/') || name.startsWith('/p/');
```
Add imports `../features/coach/presentation/own_hub_link_view.dart` (`coach_invite.dart` is already imported at line 131).
4. Same file, in class `AppRouter` directly above `shareCoachInvite` (about line 7297) add:
```dart
  /// A link the platform opened. An invite is kept and sent when she may send
  /// it ([redeemPendingInvite] checks); a profile opens that coach's page, and
  /// the verification gate in [onGenerateRoute] decides if she may see it.
  static void followLink(OwnHubLink link) {
    switch (link.kind) {
      case OwnHubLinkKind.invite:
        CoachInviteState.instance.keepPending(link.value);
        unawaited(redeemPendingInvite());
      case OwnHubLinkKind.profile:
        unawaited(
          navigatorKey?.currentState?.pushNamed(
            appRoutes['H02']!.name,
            arguments: CoachPortfolioArgs(link.value),
          ),
        );
    }
  }
```
UNVERIFIED: `navigatorKey` is a static `GlobalKey<NavigatorState>?` on `AppRouter` (used at line 7287 as `navigatorKey?.currentState?.overlay?.context`, so it exists). `CoachPortfolioArgs` is imported already (used line 4989).
5. Same file, `shareCoachInvite` (line 7299): replace
```dart
    final opened = await openOutside(
      whatsAppShareUri(l10n.joinMeOnOwnHubTheTraining(shown)),
    );
```
with
```dart
    final opened = await openOutside(
      whatsAppShareUri(
        l10n.joinMeOnOwnHubOpenThisLink(inviteLinkFor(code), shown),
      ),
    );
```
(getter name printed by `add_strings.py`; positional order = order of the placeholders `link`, `code` in the English text.) Then below `shareCoachInvite` add:
```dart
  /// `K18`'s "Share my profile link": the phone's share sheet with one line.
  static Future<void> shareProfileLink(
    BuildContext context,
    String coachUid,
  ) async {
    final text = AppL10n.of(context).trainWithMeOnOwnHub(profileLinkFor(coachUid));
    await SharePlus.instance.share(ShareParams(text: text));
  }
```
(`SharePlus` and `ShareParams` are already imported: used at line 6465.)
6. File `main.dart`, `_firstRunStack` (line ~635). It starts with `final initial = _openable(supplied);`. Insert BEFORE that line:
```dart
    // A link from the platform: keep what it names; the front door still opens.
    final link = parseOwnHubLink(supplied);
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppRouter.followLink(link),
      );
    }
```
`_openable('/c/ABCD2345')` already answers the front door (`screenIdForRoute` is null), so nothing else changes. Add `import 'features/coach/domain/coach_invite.dart';` (UNVERIFIED: `grep -n "coach_invite" app/lib/main.dart` printed nothing, so it is not imported). For a profile link on a cold start `followLink` pushes H02 after the first frame; the splash (`LaunchSplash`) covers it.
7. File `coach_space_view.dart`: add `this.onShareProfile,` to the constructor and `final void Function(String coachUid)? onShareProfile;` as a field (same style as `onPreviewPortfolio`). In `build`, directly after the `onInviteClient` row from WO-04a insert:
```dart
              if (widget.onShareProfile != null && live)
                _nav(
                  title: l10n.shareMyProfileLink,
                  subtitle: l10n.membersWhoOpenItLandOnYour,
                  icon: Icons.link,
                  onTap: () => widget.onShareProfile!(profile.uid),
                ),
```
In `app_router.dart` entry `'K18'` add `onShareProfile: (coachUid) => unawaited(shareProfileLink(context, coachUid)),`.
8. Tests per the table.

## Strings to add
Write `/tmp`-free file `app/tool/_wo04b_strings.json` (delete it after), then run `cd app && python3 tool/add_strings.py tool/_wo04b_strings.json`. The tool prints each getter name; use exactly those. Expected getters (first seven words, camel case): see the column.
| English (the key) | Egyptian Arabic | expected getter |
|---|---|---|
| Join me on Own Hub, the training app for women only. Open this link: {link} If it does not open the app, install Own Hub, tap I have a code from my coach when you sign up and enter {code}. | انضمّي ليّا على Own Hub، تطبيق التمرين للستات بس. افتحي اللينك ده: {link} ولو مافتحش التطبيق، نزّلي Own Hub، ولما تسجّلي اضغطي «معايا كود من مدرّبتي» واكتبي {code}. | `joinMeOnOwnHubTheTrainingApp` (the old string `joinMeOnOwnHubTheTraining` has the same first seven words? it has 8 words before "app", so the new key may collide and get a suffix; use the printed name) |
| Share my profile link | ابعتي لينك صفحتي | `shareMyProfileLink` |
| Members who open it land on your page and can ask to join. | أي عضوة تفتحه توصل لصفحتك وتقدر تطلب تنضم ليكي. | `membersWhoOpenItLandOnYour` |
| Train with me on Own Hub: {link} | تدرّبي معايا على Own Hub: {link} | `trainWithMeOnOwnHubLink` |
| Your coach's invitation | دعوة مدرّبتك | `yourCoachsInvitation` |
| This link does not work. Ask your coach to send it again. | اللينك ده مش شغّال. اطلبي من مدرّبتك تبعتهولك تاني. | `thisLinkDoesNotWorkAsk` |
| Continue | كمّلي | exists? run the grep in step 2 |
`parameterised` block of the JSON: the first string gets placeholders `link` and `code` (type String, examples `https://own-hub.app/c/ABCD2345` and `ABCD-2345`); "Train with me..." gets `link`. Then `cd app && flutter gen-l10n`. Wherever this order wrote a getter name that differs from the printed one, use the printed one.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| `app/test/features/coach/own_hub_link_test.dart` | `parseOwnHubLink reads an invite, with spaces, case and a query` | `parseOwnHubLink('/c/abcd2345?x=1')` is `OwnHubLink(invite, 'ABCD2345')`; `'/c/ABCD-2345'` same value |
| same | `rejects what is not a link` | null for `/c/short`, `/c/0000OOOO` (not in alphabet), `/p/ab`, `/coach/k07`, `/signup/c01`, `/c`, `/`, `/c/ABCD2345/extra` |
| same | `reads a profile uid` | `parseOwnHubLink('/p/abc123XYZ789')` kind profile, value `abc123XYZ789` |
| same | `OwnHubLinkView calls onOpen once for a good link and not for a bad one` | pump with the `_host` pattern from `coach_test.dart` lines 41-56; link good: `pumpAndSettle`, `opened == 1`; link null: shows 'This link does not work. Ask your coach to send it again.' and `opened == 0`; tap 'Continue' pops |
| same | `followLink keeps the code` | `CoachInviteState.instance.reset(); AppRouter.coachInviteStoreOverride = InMemoryCoachInviteStore(); AppRouter.followLink(const OwnHubLink(OwnHubLinkKind.invite, 'TEST2345'));` then `CoachInviteState.instance.pendingCode == 'TEST2345'` (redeem is skipped: `isVerified` is false in a test; UNVERIFIED, if the test gets a different value read `redeemPendingInvite` lines 7277-7294) |
| `coach_test.dart` (group `coach space`) | `K18 shows Share my profile link only when live, and passes her uid` | `_open(... onShareProfile: (u) => got = u)` with `_me(published: true)` plus an active package (copy how the test at line 172 makes a live coach): tap, `got == 'me'`; with `published: false` the text is `findsNothing` |
Run: `cd app && flutter test test/features/coach/own_hub_link_test.dart test/features/private_coaching/coach/coach_test.dart test/features/coach/coach_onboarding_test.dart`

## Verify
- Those three files: `All tests passed!`
- `cd app && flutter analyze` prints `No issues found!`
- Android emulator after WO-04c: `adb shell am start -a android.intent.action.VIEW -d "https://own-hub.app/c/ABCD2345" com.ownhub.app` opens the app (cold) and `... /p/<a real uid>` opens the coach page for a verified account.

## Do not
- Do not accept any other path as a link; never put a name, phone number or plan in a link.
- Do not show the coach's name before the request is sent (the code is a bearer secret and the server returns no name).
- Do not change `functions/coaching/invites.py`.
- No em dashes in any string.

## Done checklist
- [ ] parse + view + router + main wired
- [ ] two new rows/strings in EN and AR, getters match printed output
- [ ] tests pass, analyze clean

## If stuck
Anchor not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
