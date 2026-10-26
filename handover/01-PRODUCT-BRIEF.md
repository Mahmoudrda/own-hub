# Own Hub product brief (guide 1 of 2)

Verified against the working tree of `~/ownhub`, branch `feat/motivation-2026-10-13`, on 26 Oct 2026 (HEAD `6ed9864` plus a dirty tree, see section 9.4). Every path is from the repo root unless it starts with `lib/` or `test/` (then it is under `app/`). Guide 2 is `handover/02-IMPLEMENTATION-GUIDE.md`; the work orders are in `handover/work-orders/`. Anything marked `UNVERIFIED` has the command that verifies it next to it.

---

## 1. What Own Hub is

| Item | Fact |
|---|---|
| Product | Women-only fitness app for Egypt: training (video-led workouts), food logging, progress, cycle-aware suggestions, events, and private coaching with a real coach. |
| Who it is for | Women in Egypt, adults only (18+). Every account is checked at sign-up (ID card scan plus selfie, or a live woman reviewer). Men are out of scope. |
| Stack | Flutter app in `app/` (Dart, Material 3). Python 3.12 Firebase Cloud Functions in `functions/`. Firebase project `own-hub`, functions region `europe-west3` (Frankfurt). Static staff dashboard `admin-web/` (Cloudflare Pages project `ownhub-reviewers`). Static public site `site/` (generator `site/_build/build.py`). |
| Bundle ids | iPhone `com.ownhub.fitness`; widget extension `com.ownhub.fitness.OwnHubWidgets`; App Group `group.com.ownhub.fitness`. Android application id `com.ownhub.app` (kept; `app/android/app/build.gradle*`). |
| Repo | github.com/Mahmoudrda/own-hub. Working branch `feat/motivation-2026-10-13`. Never push `main`. |
| Release state | iOS 1.0.0 (build 424738) is in App Store review. `app/pubspec.yaml` still says `version: 1.0.0+1`; the 1.1.0 bump is done by the owner at ship time. Android store submission not started. Release 2 (simpler screens) is built on this branch; the emotional redesign and production plan are the next phases (`docs/plan/PRODUCTION-RELEASE-PLAN.md`, `docs/plan/EMOTIONAL-REDESIGN-GUIDE.md`). |

### 1.1 The two people (never mix them)

| Person | Role | Rule |
|---|---|---|
| Mahmoud Reda | Publisher and owner. Gives every go/no-go (commit, push, deploy, store upload). | Nothing is committed, pushed or deployed without his explicit OK in chat. |
| Rahma Mohsen | A real coach. Brand face and voice (videos, recipe book, "A message from Rahma" E11). | Never write a line in Rahma's voice unless she approved that exact line. Owner rule: publisher and brand face are never mixed (`.claude/CLAUDE.md`). |

### 1.2 Languages and tone (hard rules, tests enforce some)

| Rule | Detail | Enforced by |
|---|---|---|
| Two languages, equal | English (`en`) and Egyptian Arabic (`ar`). RTL is first class. | `test/i18n_guard_test.dart` (no hard-coded Arabic outside an allowlist; both ARB files have the same keys) |
| Arabic is Egyptian everywhere | Including legal text, consent, camera consent, pledge (DECISIONS D45, 14 Oct 2026). Spoken Egyptian in a plain everyday register, not slang, not teen chat, not Modern Standard. | `app/test/i18n/egyptian_arabic_test.dart`, review; `DECISIONS.md` D45 |
| Feminine address | Imperative and "you" are feminine in Arabic: `ابدئي` not `ابدأ`, `سجّلي` not `سجّل`. | review |
| Western digits | `0-9` in both languages, also inside Arabic text. Use `countLabel(int)` from `lib/domain/format/number_label.dart`. | review (UNVERIFIED that a test checks digits: `grep -rln "٠-٩" app/test`) |
| No em dashes | Not in any product string, either language. Use a comma, a full stop or a middle dot. | `test/gamification_rules_test.dart` ("no em dash in any product string, in either language") |
| No emoji in UI chrome | Only where she types them. | review |
| No guilt or loss wording | Never "lose", "break", "miss", "at risk", "behind", missed-day counts, body shaming. | `test/product_rules_test.dart` (RULE 3 and others), `test/features/train/notification_copy_policy_test.dart` |
| Say what happens | Button copy states the payoff; messages say what happened and what happens next. One idea per line. | review |

Real copy pairs from `app/lib/l10n/app_en.arb` / `app_ar.arb` (copy the register, not the words):

| Key (`AppL10n.<key>`) | English | Egyptian Arabic |
|---|---|---|
| `startEverythingsReady` | Start, everything's ready | ابدئي، كل حاجة جاهزة |
| `logFood` | Log food | سجّلي أكلك |
| `undo` | Undo | تراجعي |
| `later` / `notNow` | Later / Not now | بعدين / مش دلوقتي |
| `restDay` | Rest day | يوم راحة |
| `youreIn` | You're in | إنتِ معانا |
| `welcomeBack` | Welcome back | أهلًا بيكي تاني |
| `sessionsThisWeek` | Sessions this week | تمارين الأسبوع ده |
| `moreOptions` | More options | خيارات تانية |
| `doMyOwnPlanInstead` | Do my own plan instead | هعمل خطتي أنا بدل كده |
| `ofTargetKcal` (param `{target}`) | of {target} kcal | من {target} سعرة |

### 1.3 Explicitly out of scope (do not build, do not switch on)

| Out of scope | Why / where it is held off |
|---|---|
| Payments of any kind | `Feature.payments: false` in `lib/domain/flags/feature_flags.dart` (shipped set); `COACH_PAYMENTS_LIVE = False` in `functions/coaching/__init__.py`; `coachPaymentsLive()` in `firebase/firestore.rules`. Coaching is free at launch. Screens H04 (Pay), K05, K17 stay dark. |
| Community, groups, stories, reels, video posts | `Feature.community*: false`. M-screens exist but are dark. |
| The assistant (X01-X03, K26, K27) | `Feature.assistant: false`. |
| Voice logging (E03) | `Feature.voiceLogging: false`. |
| Coach planner tools W04-W11, K19-K23, coach results/reviews/ads/portfolio builder (B-screens) | `coachPlanning`, `coachResults`, `coachReviews`, `coachAds`, `coachPortfolio`: false. |
| Legacy "coached" mock flow G01-G17 | `Feature.coachedLife: false`. The live coaching feature is `lib/features/private_coaching/` (H and K screens). |
| A mascot or character | The kitten was removed (owner, 25 Oct); `lib/ui/hand/mascot/` and `lib/app_state/kitten_setting.dart` are gone. A few stale code comments still say "kitten" (harmless; do not bring it back). |
| Streak pressure, leaderboards, ranking women, chance-based rewards, countdown/loss framing | DECISIONS D37-D41. |
| Sounds | Specified in `docs/plan/EMOTIONAL-REDESIGN-GUIDE.md` 5.3, not built (no audio package in `app/pubspec.yaml`). Do not add unless a work order says so. |
| Storing ID or selfie images | Never stored anywhere (`functions/main.py` module docstring). |
| Admin console in a store build | Compiled out; `resolvesInThisBuild` in `lib/routing/app_router.dart`; `lib/config/admin_build.dart`. |

---

## 2. Design system (exact)

Source of truth is `6-v2/src/tokens.mjs`. `app/lib/theme/app_tokens.dart` is GENERATED from it by `node 6-v2/src/build-flutter.mjs` (which also writes `lib/routing/app_routes.dart` and `lib/l10n/app_*.arb`). Never hand-edit `app_tokens.dart` or `app_routes.dart`. After a colour change run `cd app && flutter test test/qa/round2/r2_41_app_palette_contrast_test.dart`.

Palette (DECISIONS D49, 16 Oct 2026): Linen is the page, Pale Pink leads (the one filled action, markers, selected state), Petrol is the hint (links, icons, ticks, progress, text colour family). Pink is never body text (1.53:1 on Linen). Text on pink is `onActionPrimary` (dark petrol). Sage is only for real achievement/restorative. Flutter uses the `AppColors.*` names; never write a raw hex in a screen.

### 2.1 Colours (`AppColors`, hex identical in `tokens.mjs`)

| Token | Hex | Use |
|---|---|---|
| `surface` / `brandLinen` / `onPrimary` | `#FCF8F2` | page background |
| `surfaceLowest` / `white` | `#FFFFFF` | cards, sheets |
| `surfaceLow` / `illustrationBg` | `#F8F2EA` | art background |
| `surfaceContainer` / `canvas` | `#F4EDE3` | grouped fill |
| `surfaceHigh` | `#EFE7DB` | raised fill |
| `surfaceHighest` / `outlineVariant` / `borderWarm` | `#E8DED3` | hairlines between rows |
| `primary` / `brandPetrol` / `progressPrimary` / `chartPrimary` | `#1A5D74` | links, icons, ticks, progress, ink |
| `primaryDim` / `petrolDark` / `onSurface` / `ink` / `onActionPrimary` / `onPrimaryContainer` | `#123F50` | text, text on pink |
| `primaryContainer` / `brandPink` / `actionPrimary` / `progressAccent` / `chartSecondary` | `#F4BEBB` | the filled primary button, marker, selected |
| `primarySoft` / `pinkSoft` / `secondaryContainer` | `#F9DEDC` | soft pink fill (tonal card, pill) |
| `pinkShade` / `actionPressed` | `#E8A5A2` | pressed pink |
| `pinkDeep` | `#D98A87` | deep pink accent |
| `secondary` | `#4E6E79` | secondary |
| `petrolMuted` / `chartMuted` | `#668B96` | muted chart |
| `onSurfaceVariant` / `textSecondary` | `#4E6068` | secondary text |
| `outline` | `#60858F` | meaningful borders (not decoration) |
| `tertiary` / `statusSuccess` | `#4C6E55` | sage: done |
| `tertiarySoft` | `#65896F` | sage fill, progress on sage |
| `tertiaryContainer` | `#DDEDE1` | sage card |
| `onTertiaryContainer` | `#1E3826` | text on sage card |
| `error` / `statusError` | `#A34848` | genuine problem |
| `errorContainer` / `onErrorContainer` | `#FBE0E0` / `#4E1C1C` | error card |
| `amber` / `statusWarning` | `#8A5A17` | warning text |
| `amberContainer` | `#FBEBD6` | warning fill |
| `inverseSurface` / `inverseOnSurface` | `#123F50` / `#FCF8F2` | dark chip / its text |
| `onTertiary`, `onError`, `onSecondary` | `#FFFFFF`, `#FFFFFF`, `#FCF8F2` | |

Hand-art ink roles live in `lib/theme/hand_tokens.dart` (`HandInk.ink = AppColors.primary`, `inkDeep`, `pencil = outline`, `marker = primaryContainer`, `done = tertiary`).

### 2.2 Type, spacing, radius, shadow, motion

| Group | Tokens (`lib/theme/app_tokens.dart`) |
|---|---|
| Font | Rubik for English and Arabic. Files `app/assets/fonts/Rubik-400.ttf`, `-500`, `-600`, `-700` (declared in `app/pubspec.yaml` family `Rubik`). Also `ArefRuqaa-400/700.ttf` and `LaBelleAurore-400.ttf` (brand handwriting only) and `OFL-*.txt` licences. Regenerate fonts with `python3 6-v2/scripts/build_fonts.py`. |
| `AppText` (size / weight) | `display` 32/700, `headline` 26/700, `titleL` 20/600, `titleM` 17/600, `titleS` 15/600, `body` 16/400, `bodyM` 15/400, `label` 15/500, `nav` 12/500. Hero figures use `display` at 48 with tabular figures (`AppStatHero`). |
| `AppSpace` | `s4 s8 s12 s16 s20 s24 s32 s40` |
| `AppIconSize` | `s16 s20 s24 s32` |
| `AppRadius` | `xs 8`, `sm 12`, `md 16`, `lg 20`, `xl 28`, `full 999` |
| `AppShadow` | `none`, `card` (1px, 6% petrol), `raised` (2px, 8% petrol). No glass, no gradients, no glows. |
| `AppMotion` | `fast 150ms`, `short 220`, `med 320`, `long 460`; curves `emphasized`, `decelerate`, `accelerate`, `spring`. Hand animations use `HandTiming` (`lib/ui/hand/motion.dart`: `short 150`, `medium 220`, `long 400`, `pressIn 90`, `pressOut 180`, `progress 600`, `shimmer 1400`, `confetti 900`). Anything that moves first asks `handMotionOff(context)` (`lib/ui/hand/draw_on.dart`) and shows its final state instead. |
| Layout constants | `AppScaffold` body padding `kBodyPadding = fromLTRB(16,4,16,0)`, footer `kFooterPadding = fromLTRB(16,10,16,14)`, gap between children `kStackGap = 10` (`lib/ui/app_scaffold.dart`). Min tap target 44. |

### 2.3 Hand-drawn art and motion (`lib/ui/hand/`, import everything with `import '.../ui/hand/hand.dart';`)

| File | One line |
|---|---|
| `hand.dart` | The one import that exports the whole hand layer. |
| `hand_geometry.dart` | Seeded wobbly lines/shapes; same seed means the same drawing every frame. |
| `hand_painters.dart` | The painters (ink, pencil, marker strokes) behind every mark; each takes a `seed`. |
| `hand_seed_name.dart` | `HandSeedName` mixin-interface: a widget names the card it sits in so its sketch is stable. |
| `hand_surface.dart` | `HandSurface`: every container (fill + drawn frame + press give). |
| `hand_marks.dart` | `HandUnderline`, `HandCircled`, `HandTick`, `HandArrow`, `MarkerHighlight`, `HandRule`, `HandNote`, `HandFigure`, `PaperPage`. |
| `art_marks.dart`, `art_palette.dart` | `ArtMark`: product illustrations painted in code; their colours. |
| `food_marks.dart` | `FoodMark`: 16 painted food marks. |
| `book_card.dart` | `BookCard`/`BookTitle`: Rahma's recipe-book card (pink paper, clips). |
| `draw_on.dart` | `DrawOn` (a mark draws on once), `HandPressable` (a press that gives), `handMotionOff`. |
| `spring_pop.dart` | `SpringPop(child, delay, from)`: arrives with a small spring, once. |
| `stagger_in.dart` | `StaggerIn(index, child, group)` and `StaggerIn.all(children)`: list rows arrive 40-60 ms apart, max 6. |
| `hand_swap.dart` | `HandSwap`: cross-fade + size ease between two states (give each state a key). |
| `skeleton.dart` | `Skeleton(width, height, radius)`: loading placeholder with a shimmer. |
| `moment.dart` | `Moment(size, delay)`: the shared "done" beat, a tick that draws on with a spring pop. New and uncommitted. |
| `paper_confetti.dart` | `PaperConfetti`: the one celebration, R10 only, for a real best or a first session. |
| `finish_wipe.dart` | `FinishWipe`: pink ribbon wipe that reveals R10. |
| `finger_tilt.dart`, `tilt_parallax.dart` | Card leans to the finger; art drifts with the phone tilt (Home hero art only). |
| `page_transition.dart` | Route transition (fade through on Android, native slide on iPhone). |
| `launch_splash.dart` | The mark drawing on at cold start. |
| `motion.dart` | `HandTiming` durations/curves. |

### 2.4 Shared widgets (`lib/ui/`, constructor signatures verified in the files)

Rule: use these; never build a one-off button, card, row, sheet or menu. Imports are relative (`'../../../ui/app_button.dart'`) or `package:own_hub/ui/app_button.dart` in tests.

**AppButton** (`app_button.dart`). `AppButton(String label, {Key? key, VoidCallback? onPressed, AppButtonVariant variant = filled, double height = 56, double fontSize = 17, IconData? icon, bool haptic = false})`. Variants: `filled` (the ONE primary, pink), `tonal`, `sage` (restorative), `outlined`, `text` (lowest weight, never destructive). Only `filled` counts as a primary in the budget tests.
```dart
AppButton(l10n.startEverythingsReady, icon: Icons.play_arrow, onPressed: onStart),
AppButton(l10n.later, variant: AppButtonVariant.text, height: 44, fontSize: 15, onPressed: onLater),
AppButton(l10n.save, variant: AppButtonVariant.outlined, onPressed: null), // null = disabled
```

**AppBigButton** (`app_big_button.dart`). `AppBigButton(String label, {required String subtitle, VoidCallback? onPressed, bool sage = false, bool haptic = false})`. Two-line button for R07 only (log the set; subtitle says what happens next).
```dart
AppBigButton(label, subtitle: nextLine, onPressed: onLog), // label names HER set; real call at mid_set_view.dart:502
```

**AppCard** (`app_card.dart`). `AppCard({required List<Widget> children, AppCardVariant variant = outlined, EdgeInsets padding = EdgeInsets.all(16), double gap = 12, double borderRadius = AppRadius.lg, VoidCallback? onTap, int? seed})`. Variants `outlined` (default, white + hairline), `filled` (grey group), `tonal` (pink: the app speaking), `sage` (restorative), `error`, `selected` (soft pink ringed). A card is seeded from its children so it draws the same each visit.
```dart
AppCard(variant: AppCardVariant.tonal, children: [Text(l10n.welcomeBack, style: AppText.titleM), Text(body)]),
```

**AppListItem** (`app_list_item.dart`). `AppListItem({String title = '', Widget? titleWidget, String subtitle = '', Widget? leading, Widget? trailing, VoidCallback? onTap, AppCardVariant variant = outlined, EdgeInsets padding = EdgeInsets.symmetric(horizontal:14, vertical:12), double borderRadius = AppRadius.md})`. Also `HandIconRing({required Icon icon, int seed = 0, double size = 40, Color? color})` for a leading icon. Adjacent rows count as one control in the budget.
```dart
AppListItem(leading: HandIconRing(icon: Icon(Icons.flag_outlined)), title: l10n.report, onTap: onReport),
```

**AppSheet / showAppSheet** (`app_sheet.dart`). `Future<T?> showAppSheet<T>({required BuildContext context, required List<Widget> children, double gap = 14, bool dismissible = true})`; widget `AppSheet({required List<Widget> children, double gap = 14})`. For a decision that belongs to the screen underneath. Never use it to ask "are you sure" about a log (logging offers Undo).
```dart
final choice = await showAppSheet<VoidCallback>(context: context, gap: 8, children: [
  AppListItem(title: l10n.shortVersion, onTap: () => Navigator.of(context).pop(onShort)),
]);
```

**AppOverflowMenu / AppOverflowItem** (`app_overflow_menu.dart`). `AppOverflowItem({required IconData icon, required String label, required VoidCallback onTap, String? confirmMessage})` (`confirmMessage` set = destructive: first tap asks the question inside the same sheet); `AppOverflowMenu({Key? key, required List<AppOverflowItem> items, Color? color})` draws a 48x48 "..." button (key `overflow-menu`, tooltip `moreOptions`). Put rare and destructive actions here, not on the screen.
```dart
AppOverflowMenu(items: [AppOverflowItem(icon: Icons.flag_outlined, label: l10n.report, confirmMessage: askText, onTap: onReport)]),
```

**AppStatHero / AppStat** (`app_stat_hero.dart`). `AppStat({required String value, required String label})`; `AppStatHero({required AppStat hero, List<AppStat> others = const [], Widget Function(TextStyle)? heroBuilder})`; asserts `others.length <= 3` (max 4 figures total).
```dart
AppStatHero(hero: AppStat(value: countLabel(4), label: l10n.sessionsThisWeek), others: [AppStat(value: countLabel(120), label: l10n.minutes)]),
```

**AppSegmented** (`app_segmented.dart`). `AppSegmented({required List<String> items, required int selectedIndex, ValueChanged<int>? onChanged})`. Counts as one control.
```dart
AppSegmented(items: [l10n.progress, l10n.activities], selectedIndex: _segment, onChanged: (i) => setState(() => _segment = i)),
```

**AppTopBar** (`app_scaffold.dart`). `AppTopBar({String title = '', VoidCallback? onBack, List<Widget> actions = const [], IconData leadingIcon = Icons.arrow_back, bool showChrome = true})`; 64 high; `Icons.close` for a screen drawn over another. The chrome (her picture, language switch) is added by the bar on routed screens and is NOT counted in budgets.
```dart
appBar: AppTopBar(title: l10n.eat, onBack: () => Navigator.of(context).maybePop(), actions: [AppOverflowMenu(items: items)]),
```

**AppScaffold** (`app_scaffold.dart`). `AppScaffold({required List<Widget> children, List<Widget> footer = const [], PreferredSizeWidget? appBar, Color? backgroundColor, bool scrollable = true, bool footerScrollsWhenLarge = false, String? staggerGroup, bool showArt = true, double gap = kStackGap, bool showChrome = true})`. The body is a column with 10 px gaps; `footer` is pinned to the bottom (put the one primary there); `AppSpacer` pushes content apart (then `scrollable: false`).
```dart
AppScaffold(appBar: AppTopBar(title: l10n.train), children: [card, list], footer: [AppButton(l10n.start, onPressed: onStart)])
```

**AppNavBar / NavDestination** (`app_nav_bar.dart`). `AppNavBar({required String activeScreenId, List<NavDestination>? destinations, ValueChanged<String>? onSelect})`. Tab roots pass it as `bottomNavigationBar:` of their own `Scaffold` (examples: `progress_view.dart:242`, `quiet_week_view.dart:150`). `NavDestination({required screenId, required icon, required activeIcon, required String Function(AppL10n) label, bool isAction = false})`. Lists: `traineeTabs`, `coachTabs`, `logFoodAction`; `tabsFor(AppRole)` filters tabs whose feature is off.
```dart
bottomNavigationBar: AppNavBar(activeScreenId: 'T01', onSelect: (id) => AppRouter.goToTab(context, id)),
```

**Moment** (`hand/moment.dart`). `Moment({double size = 48, Duration delay = Duration.zero})`: ExcludeSemantics + SpringPop + `HandTick(drawOn: true)`. Use for any "saved/done" confirmation instead of a modal or a character. Not on R07, R09, charts, errors.
```dart
Row(children: [const Moment(size: 28), const SizedBox(width: 8), Text(l10n.saved)]),
```

**Skeleton** (`hand/skeleton.dart`). `Skeleton({double? width, double? height, double radius = 8})`. Replace a bare spinner on a main screen with skeletons shaped like the final layout.
```dart
Column(children: [Skeleton(height: 120, radius: AppRadius.lg), const SizedBox(height: 12), Skeleton(height: 56)]),
```

**Others** (signatures verified; look at the file before first use):

| Widget | File | Constructor (essentials) |
|---|---|---|
| `AppChip`, `AppChipRow` | `app_chip_row.dart` | `AppChip(label, {selected=false, icon, onTap, height=40})`; `AppChipRow({required items, required selected, onTap, grow=true, height=40})` |
| `AppToggle` | `app_toggle.dart` | `AppToggle({required bool value, ValueChanged<bool>? onChanged, String? semanticLabel})` |
| `AppField` | `app_field.dart` | `AppField({controller, focusNode, label, hint, helper, errorText, keyboardType, textInputAction, textDirection, autofillHints, autofocus, onChanged, onSubmitted, trailing, maxLines=1, inputFormatters, textAlign})` |
| `AppCodeField` | `app_code_field.dart` | six-digit code entry (sign-in) |
| `AppPill` | `app_pill.dart` | `AppPill(label, {background=primarySoft, foreground=primaryDim, icon})` |
| `AppProgressBar` | `app_progress.dart` | `AppProgressBar({required double percent /*0..100*/, height=8, colour=tertiarySoft, trackColour})` |
| `AppRingStat` | `app_ring_stat.dart` | `AppRingStat({required fraction, required big, required small, size=96, thickness=12, color, animateIn=false})` |
| `AppStepBar` | `app_step_bar.dart` | `AppStepBar({required step, required total, height=6, color})` |
| `AppWeekSegments` | `app_week_segments.dart` | `AppWeekSegments({required total, required filled, height=10, color, style=WeekStyle.bar, popIndex})` |
| `AppEmptyState` | `app_empty_state.dart` | `AppEmptyState({required IconData icon, required String title, required String body, VoidCallback? onTap, String? art})` |
| `AppSageNote` | `app_sage_note.dart` | `AppSageNote(String text)` |
| `AppSplitRow` | `app_split_row.dart` | `AppSplitRow({required start, required end, spacing=12, runSpacing=4})` |
| `AppUndoBar` | `app_undo_bar.dart` | `AppUndoBar({required message, required undoLabel, onUndo})` (5-second undo after a log) |
| `AppAvatar` | `app_avatar.dart` | `AppAvatar({firstName, size=36, onOpenProfile, roles, onRoleChanged, isSelf=true})` |
| `AppMedia` | `app_media.dart` | `AppMedia({width, height=180, kind=AppMediaKind.video, borderRadius, showPlayButton=true, badge, child})` |
| `AppLogButton`, `AppWhiteButton` | `app_log_button.dart`, `app_white_button.dart` | `AppLogButton(label, {onPressed, primary=false, haptic=false})`; `AppWhiteButton(label, {onPressed, height=56, fontSize=17, icon})` |
| `ScreenArtStrip`, `ScreenArtInline` | `screen_art_strip.dart` | `ScreenArtStrip({size=92})`; art ids in `lib/theme/screen_art.dart`, `app_art.dart` |
| `MedicalDisclaimer`, `LanguageSwitch`, `SignInPill`, `ContentImage`, `MealImage` | `medical_disclaimer.dart` etc. | shared fixed pieces; reuse as is |

---

## 3. App architecture in plain words

### 3.1 Folder map of `app/lib`

| Folder | What lives there |
|---|---|
| `main.dart` | `main()` boots Firebase, reads the local snapshot, then `runApp(OwnHubApp())`. Nothing waits on the network before the first frame (D44). |
| `features/<area>/{domain,data,presentation}` | One folder per product area. `presentation` = screens and view models; `domain` = pure Dart rules/models (no Flutter, no Firebase); `data` = repositories and I/O. Areas: `signup`, `onboarding`, `today`, `train`, `eat`, `progress` (the You tab and Insights), `cycle`, `events`, `followup`, `account` (settings/privacy/safety), `private_coaching` (LIVE coaching: member and coach), `coach`, `coachbrand`, `coachplan`, `coaching`, `coached`, `community`, `assistant`, `admin` (staff console, compiled out of store builds), `testing`. |
| `domain/` | Cross-feature pure logic: `analytics/analytics_gateway.dart`, `clock/app_clock.dart` (use `AppClock.now()`, never `DateTime.now()`), `flags/feature_flags.dart`, `format/` (`countLabel`, day keys), `identity/user_roles.dart`, `logging/log_command_bus.dart` (the undo window), `rewards/`, `safety/`, `training/`, `week/`. |
| `app_state/` | 73 files of process-wide state holders, persistence, consent, Firebase boot (see 3.4 and 3.5). |
| `routing/` | `app_router.dart` (about 10,900 lines: all screen builders and navigation), `app_routes.dart` (GENERATED id to route name table), `screen_features.dart` (`kScreenFeatures`: screen id to `Feature`), `coaching_wiring.dart`, `session_over_redirect.dart`. |
| `theme/` | `app_tokens.dart` (GENERATED), `hand_tokens.dart`, `app_art.dart`, `screen_art.dart`, `body_map_tokens.dart`, `recipe_book_tokens.dart`, `hand_theme.dart`. |
| `ui/` | Shared widgets (2.4) and `ui/hand/` (2.3). |
| `l10n/` | `app_en.arb`, `app_ar.arb` (GENERATED, synced from `6-v2/flutter/`), `app_l10n*.dart` (generated by `flutter gen-l10n`; class `AppL10n`). |
| `config/` | Legal links, care links, team contact, founder video, admin build flag. |
| `data/` | `pending_answers.dart`, `sync/`. |

Assets: `app/assets/{art,brand,content,fonts,icon}`. Content packs (recipes, exercises, notification lines `assets/content/notification_lines.json`) are generated by `app/tool/*.py`.

### 3.2 How a screen is built

1. The screen is a Dart view in `lib/features/<area>/presentation/<name>_view.dart`: a `StatelessWidget` or `StatefulWidget` that receives data and CALLBACKS through its constructor (`onBack`, `onStart`, `onOpenEvents` ...). It does not call the router or global state itself where avoidable.
2. Body is `AppScaffold(appBar: AppTopBar(...), children: [...], footer: [the one AppButton])` using the shared widgets in 2.4. All text is `AppL10n.of(context).<key>` (`final l10n = AppL10n.of(context);`).
3. The screen's id (T01 ...) is registered in the builder map `static final Map<String, WidgetBuilder> _built` in `lib/routing/app_router.dart` (about line 1367). The builder reads the shared state, constructs the view and wires every navigation edge, e.g. `'T09': (context) { ...; return EventsView(events: EventsState.instance.upcoming, onBack: () => Navigator.of(context).maybePop(), ...); }`.
4. Navigation edges live ONLY in the router builder: `AppRouter.goTo(context, 'R03')` pushes a screen; `AppRouter.goToTab(context, 'P01')` switches tab (E02 always opens over the current tab).
5. The router wraps each screen in `RedrawOnChange` (rebuilds on `AppChanges.bump()`, only while visible) and `ScreenScope(screenId: id)`.
6. The screen must have a switch: `kScreenFeatures` in `lib/routing/screen_features.dart` (or `AppRouter.ungatedScreens`). `test/domain/flags/every_feature_has_a_switch_test.dart` fails otherwise.

### 3.3 Routing

| Piece | File | Facts |
|---|---|---|
| Id to route | `lib/routing/app_routes.dart` (GENERATED from `6-v2/src/inventory.mjs`) | `appRoutes['T01']` is `AppRoute(name: '/today/t01', flow: 'today', title: ...)`; header says "196 screens across 17 flows". `AppRouter.appDestinations` is the same minus `firstRunStates`. |
| Resolve | `AppRouter.onGenerateRoute` | Order: id known, `resolvesInThisBuild` (admin out of store builds), `screenIsOn` (else `FeatureOff` screen), `verificationGate` (whole-app women-only gate), camera consent for C10/C10b/C11 (`_opensALens`), analytics screen view (`reportsScreenView`), build via `_built[id]` else `NotBuiltYet`. |
| Screen on? | `AppRouter.screenIsOn(id)` | `ungatedScreens` always on; else flow feature (`featureForFlow(flow)`) AND the screen's own feature (`kScreenFeatures`) must be on. |
| Verification gate | `AppRouter.openBeforeVerification = {signup, onboarding, account, admin}` | Everything else needs a server `verified` claim. Do not add flows to that set. |
| Guest | `D62` | A guest may finish her first workout before sign-up; R06/R07 go through `GuestSession`. |
| Open a screen by hand | `cd app && flutter run --route /train/r01` | Route names are lower-case id: `/<flow>/<id>`. |

### 3.4 State pattern, local storage, Firebase

| Topic | How it works (files) |
|---|---|
| State holders | Singletons in `lib/app_state/`: `class XState { XState._(); static final XState instance = XState._(); ... }` (example `training_streak_state.dart`). Mutations call `AppChanges.bump()` (`app_changes.dart`) AFTER the change, from a callback, never during build. Screens redraw via `RedrawOnChange`. No Provider/Bloc/Riverpod. |
| Local storage | One JSON document, one `shared_preferences` key, debounced writes, flushed on pause: `local_persistence.dart` writes, `app_snapshot.dart` shapes it. A new persisted thing needs a section in `app_snapshot.dart` (capture + read, each in its own guard; schema constant `kSnapshotSchema`) and an erase line in `account_data.dart`. A bad snapshot must never stop the app. |
| Cloud copy | `cloud_store.dart` mirrors her data to Firestore under her uid only when signed in AND verified; the phone stays the copy the app reads. |
| Firebase | Auth (phone), App Check, Firestore, Storage (buckets `own-hub-personal` and `own-hub.firebasestorage.app`), Cloud Functions (callables, `europe-west3`), FCM, Crashlytics (consent only), Analytics. Boot in `firebase_boot.dart`. Plugins in `app/pubspec.yaml`. |
| Analytics | `lib/domain/analytics/analytics_gateway.dart`: `AppRouter.analytics.track(AnalyticsEvent.x, {AnalyticsProp.y: AnalyticsValue.token('z')})`. Keys are enums, values are closed types (`flag`, `token`, bucketed numbers). There is deliberately NO free-text or Map API: a leak must not compile. Sinks: `firebase_analytics_sink.dart`, `posthog_analytics.dart`, `debug_analytics_sink.dart`, `TeeAnalyticsSink`. Never send phone, name, ID, weight, photo, cycle data, typed text. `reportsScreenView` excludes the cycle flow and `P04`, `E10`. |
| Consent | Statistics: `analytics_consent.dart` (key `own_hub.analytics_allowed_v2`, off until she opts in, C06 or Profile > Privacy). Crash reports: `crash_consent.dart` (off until opt-in). Both default OFF; nothing is collected before they are read. Server consents (`record_consent`, `record_legal_acceptance`, `record_pledge`, `record_health_consent`, meal-photo consent) store version, locale, app version and time. |
| Feature flags | `lib/domain/flags/feature_flags.dart`: enum `Feature` (over 60 values) with `parent` chain (`isOn` is false if any ancestor is off), compiled `FeatureFlags.shipped`, `FeatureFlags.everything` (tests), `allOff`. Server overlay `meta/features` via `remote_features.dart` can switch OFF a feature with `serverMayTurnOff` and ON only with `serverMayTurnOn`; it can never open community/coach/assistant or close sign-up/gate/Home/privacy. Runtime holder `AppRouter.featureFlags`. Staff flip flags on screen Z14. A new feature needs: enum value + `shipped` line + `kScreenFeatures` lines. |
| Notifications | `reminder_scheduler.dart`, `notification_sync.dart`, `notification_taps.dart`; AI-written line bank `assets/content/notification_lines.json` is picked on the phone. |
| Haptics | `lib/app_state/haptics.dart`: `AppHaptics.play(HapticMoment.setLogged / actionDone / sessionFinished / bigMoment)`; behind `Feature.haptics`. Always paired with a visual; one per moment. |

### 3.5 Strings (every user-visible word)

Pipeline: English key text and Egyptian Arabic go into `6-v2/i18n/ar-extra.json` -> `node 6-v2/src/merge-i18n.mjs` -> `node 6-v2/src/build-flutter.mjs` (writes `6-v2/flutter/app_*.arb`, syncs them and `app_routes.dart`, `app_tokens.dart` into `app/lib/...`) -> `flutter gen-l10n` (output `app/lib/l10n/app_l10n*.dart`, class `AppL10n`, config `app/l10n.yaml`). `app/tool/add_strings.py` runs all of that under a lock and prints the getter name.

Usage (verified in `app/tool/add_strings.py`):
```json
// /tmp-free place: write it in the session scratchpad, e.g. strings.json
{
  "strings": {
    "Short version": "نسخة قصيرة",
    "of {target} kcal": "من {target} سعرة"
  },
  "parameterised": {
    "of {target} kcal": {
      "description": "The day's kcal target, under the kcal eaten in the ring.",
      "placeholders": {"target": {"type": "String", "example": "1,700"}}
    }
  }
}
```
```
cd ~/ownhub && python3 app/tool/add_strings.py /path/to/strings.json
# prints:  Short version                           l10n.shortVersion
#          of {target} kcal                        l10n.ofTargetKcal
```
Then use `l10n.shortVersion` and `l10n.ofTargetKcal('1,700')`. Rules: every key in `parameterised` must also be in `strings`; re-adding an existing English text OVERWRITES its Arabic (check `grep -n '"English text"' 6-v2/i18n/ar-extra.json` first); the getter name is derived from the English text; if the output says `l10n.??` the string was not found in the ARB, stop and report. Never hand-edit `app/lib/l10n/*.arb` or `app_l10n*.dart`. Never hard-code an Arabic literal in Dart (`i18n_guard_test.dart` fails).

When the 6-v2 prototype sources must change (`6-v2/src/`): only when a screen is added, removed or renamed (edit `inventory.mjs`, `features.mjs`, and the matching `screens-<flow>.mjs`, then run `node 6-v2/src/build-flutter.mjs` so `app_routes.dart` regenerates) or when a token changes (`tokens.mjs`). Adding a string or changing the Flutter UI does NOT require editing the prototype. The prototype build scripts are `build-prototype.mjs` and `build-wireframe.mjs` (outputs under `6-v2/prototype`, `6-v2/wireframe`); they are owner-facing review artefacts, not required for app tests.

---

## 4. Backend and tooling folders

### 4.1 `functions/` (Python 3.12, Firebase Functions Gen 2, entry `functions/main.py`, 92 decorated functions: 83 callables, 3 schedulers, 5 Firestore triggers, 1 HTTP)

| Folder | What it does |
|---|---|
| `identity/` | Women-only verification pipeline: `nid.py` (parse 14-digit ID), `arabic.py` (reads the printed sex word), `faces.py` + `models/` (YuNet detection, SFace match, ONNX, licences included), `pipeline.py`, `decisions.py`, `dedupe.py` (one card, one account), `review.py`/`scheduling.py` (live woman-reviewer calls or ladies-only gym visit, 72 h SLA), `approvals.py` (approve/revoke, pre-approved phones, `adultConfirmedBy` 18+ tick), `ledger.py` (cost ledger), `webhook.py`, `providers*.py`, `push.py`, `reasons.py` (user-safe hints). Images are never written anywhere. |
| `coaching/` | Private coaching: `applications.py`, `certificates.py`, `profiles.py`, `media.py`, `moderation.py`, `packages.py`, `plans.py`, `sessions.py`, `chat.py`, `subscriptions.py`, `proofs.py`, `payouts.py`, `refunds.py`, `receipts.py`, `invites.py`, `claims.py` (custom claims), `push.py`, contract `coaching_contract.json` (copy also in the app). Three switches in `__init__.py` (`COACH_PAYMENTS_LIVE = False`). |
| `account/` | `deletion.py` + `deletion_manifest.json` (erase everything incl. Storage prefixes), `manifest.py` (data export). Kept outside `identity/` because identity may not touch Storage. |
| `console/` | Owner/staff dashboard back end: `dashboard.py` (counts only), `access.py` (every read logged to `adminAccessLog`), `exercise_editor.py`, `oplog.py`. |
| `events/` | `seats.py` (reserve/cancel seat), `admin.py` (save/list events). |
| `community/` | `counts.py` like/comment counters. |
| `nutrition/` | Meal photo estimate (`photo.py`, `meal.py`): model names foods and grams; ALL numbers come from `egyptian_dishes.json` / `usda_foods.json`. `community_foods.py`. Photo is never stored. |
| `waitlist/` | `join.py` public waitlist. |
| `tests/` | pytest suite (fakes: `fake_firestore.py`, `fake_blobs.py`). Autouse guard forbids reaching a real Firestore. |
| `tools/` | One-off scripts (e.g. `e2e_coaching.py`). |

### 4.2 Rules, dashboard, site

| Item | Facts |
|---|---|
| `firebase/firestore.rules` (1,839 lines) | Gate helpers `signedIn()`, `isVerified()` (token `verified == true`, server-minted only), `isAdmin()`, `isCoach()`, `coachPaymentsLive()`. App data is verified-only; writes that matter are callable-only. Indexes `firebase/firestore.indexes.json`. Tests `test/rules/*.test.js` (446). |
| `firebase/storage.rules` (278) / `storage.library.rules` (70) | Personal bucket (`own-hub-personal`) vs public library bucket (`own-hub.firebasestorage.app`). Tests `test/rules/storage/storage.test.js` (33). |
| `firebase.json` | codebase `identity`, runtime python312, emulator ports (auth 9099, firestore 8080, storage 9199, functions 5001); hosting config. `firebase.emulator.json` (auth 9098, firestore 8088, storage 9198) is the one the rules tests use. |
| `admin-web/` | Static staff dashboard (no build step): `index.html`, `app.js` (Firebase web SDK via CDN, App Check, callables), `logic.js` (pure helpers, tested by `logic.test.mjs`), `coaching.js`, `art.js`, `styles.css`, `config.js`, `_headers`, `vendor/hairline`. Deploy: `cd ~/ownhub && npx wrangler pages deploy admin-web --project-name ownhub-reviewers` (owner runs). |
| `site/` | Public website (EN root + `site/ar/`): privacy, terms, coach terms, support, delete-account, waitlist. Generated by `python3 site/_build/build.py` (run from `site/`); deploy by `site/_build/deploy.sh <https url>`; Hairline drawings by `site/_build/capture_hairline.py`. Do not hand-edit generated HTML; edit `site/_build/pages_en.py` / `pages_ar.py`. |
| `firebase/ops/` | Alert policies, TTL policies, reviewer secrets script (owner ops). |

---

## 5. Product features, screen ids and rules

### 5.1 Tab bar (`lib/ui/app_nav_bar.dart`)

| Role | Tabs (screen id) |
|---|---|
| Trainee (default) | Home `T01`, Train `R01`, centre "+ Log food" `E02` (an ACTION: opens over the current tab, never active), Eat `E01`, You `P01`. |
| Coach | Today `K07`, Clients `W01`, Chats `W10`, Earnings `K17` (`K17` is hidden while `Feature.payments` is off; `tabsFor` filters). |
| Not tabs | Events (`T09`) and Community are rows on You; coaching is reached from You and Train ("Find a coach" `H01`); Insights is `P07` ("See more" on You). |

### 5.2 Screens by area (all 196 ids are in `lib/routing/app_routes.dart`; shipped means the flow is on in `FeatureFlags.shipped`)

| Area (flow) | Ids and titles |
|---|---|
| Sign-up and women-only check (`signup`, 18) | C01 Welcome, C02 Language, C03 What's inside, C04 Look around first (tour), C05 Join to save this, C06 Phone number (terms, optional statistics/crash switches), C07 The code, C08 Client or coach, C09 Why we check, C09b Before the camera opens (consent), C10 Scan your ID, C10b Back of the card, C11 Quick selfie (liveness), C12 Checking, C13 You're in, C14 Waiting for a reviewer, C15 Verify with a woman reviewer, C16 Community pledge |
| Setup (`onboarding`, 6) | O01 Her goal, O02 Where and with what, O03 Days and minutes, O04 Life stage (safety screening), O05 Your starting program, O06 What you have at home |
| Home (`today`, 9) | T01 Today, T02 I already did it, T03 Lock screen, T04 After a quiet week, T05 When a tier slips, T06 Day one, T07 Your first week, T08 First week done, T09 Events |
| Train (`train`, 14) | R01 Train, R02 Program, R03 Workout day, R04 Exercise video, R05 Swap a move, R06 Follow-along, R07 Mid-set, R08 Change a set, R09 Resting, R10 Finished, R11/R14 libraries (dark; Explore on R01 holds both), R12 Logged from memory, R15 Exercise demo. (R13 was deleted.) |
| Eat (`eat`, 13) | E01 Eat, E02 Type it (food search), E03 Say it (dark), E04 After a log, E05 Recipes, E06 Recipe, E07 Week plan, E08 Grocery list, E09 Eat day one, E10 What you cannot eat (allergies; never in analytics), E11 A message from Rahma, E12 Snap your meal, E13 Check your meal |
| You and progress (`progress`, 7) | P01 You (tab root), P02 Milestones, P03 Personal bests, P04 Body, privately, P05 Progress card (share), P06 Your muscles, P07 Insights |
| My cycle (`cycle`, 14) | Y01-Y14 (never in analytics) |
| Account (`account`, 4) | A01 Notifications, A02 Profile and settings, A03 Privacy, A04 Safety Centre |
| Member coaching (`coaching`, 6) | H01 Find a coach, H02 Coach profile, H03 Choose a package, H04 Pay (dark), H05 My coach, H06 Chat |
| Coach side (`coach-setup` 11, `coach` 7) | K01-K13 setup/apply, K07 Today (desk), K09 New enquiry, K16 Conversation, K17 Earnings (dark), K18 Public profile, K24/K25 day one |
| Dark flows | `coached` G01-G17, `community` M01-M17, `coachbrand` B01-B14, `coachplan` W01-W11 + K19-K27 (W01, W02, W03, W06, W10 are on via `coachApp`), `assistant` X01-X03, `admin` Z01-Z18 (staff only, not in store builds) |

Local map: use `graphify query "<screen id or concept>"` first, then read the file.

### 5.3 Release-2 simplification rules ("one screen, one purpose")

| Rule | Detail |
|---|---|
| One filled primary | At most ONE `AppButtonVariant.filled` (pink) per screen state. Everything else is `tonal`, `outlined` or `text`. |
| At most 5 other controls above the fold | Measured at 390x844 and 375x667, EN and AR, excluding the tab bar AND the shared top-bar chrome (her picture, language switch). Owner decisions of 24 Oct: chrome excluded; a list row plus its own trailing "+" is ONE control; adjacent `AppListItem` rows are one control; the segments of one `AppSegmented` are one. |
| At most 4 hero figures | `AppStatHero` asserts `others.length <= 3`. |
| Rare/destructive goes in an overflow menu | `AppOverflowMenu`; a destructive row asks first inside the same sheet. |
| Logging never asks "are you sure" | It offers a 5-second Undo (`AppUndoBar`, `LogCommandBus`). |
| Defaults are recommendations | Preselect last used / her plan; button copy states the payoff. |
| Emotional additions never add a control | See 5.4. |

Tests that enforce them (run from `app/`):

| Test file | What it asserts |
|---|---|
| `test/qa/screen_budget_test.dart` | Per-screen budget for ids in its `simplified` set: T01, E01, E02, P01, A02, H05, H02, H03, T09 (plus Train screens R01, R02, R03, R07, R09, R10 in their main states). `kChromeCounts = false`. Helpers `screenIds`, `budgets`, `expectWithinBudget`. |
| `test/qa/step8_budget_test.dart` | A02, H05, H02, H03, T09 in every state, EN and AR, both sizes (new, uncommitted). |
| `test/qa/one_primary_action_test.dart` | Key screens lead with at most one filled primary. |
| `test/helpers/control_counter.dart` | `countControlsAboveFold(tester, {includeChrome})`; counting rules in its header. Its own tests: `test/qa/control_counter_test.dart`. |
| `test/helpers/primary_actions.dart` | `filledPrimaryActions(tester)`, `expectAtMostOnePrimaryAction`. |
| `test/qa/large_text_sweep_test.dart`, `tap_crawler_test.dart` | Small phones / large text; opens every screen. |
| `test/nav_reachability_test.dart` | Share of screens reachable from the shipped app (floors currently 75 and 92, lowered with owner OK). |

Pattern to add a budget assertion: use the harness in `test/qa/round1/round1_harness.dart` (`useShippingApp()`, `phone(tester)`, `open(tester, route, locale:)`), then `expectWithinBudget(tester, 'R01')`.

### 5.4 Emotional design rules (summary of `docs/plan/EMOTIONAL-REDESIGN-GUIDE.md`, 305 lines)

1. Goal: calm, capable, looked after, delighted at the right moments; never judged, rushed or watched. Reliability and clarity first, then motion, touch, colour, words.
2. Fixed points not to redesign: the workout video player and how workouts play; the Events area (T09). They may take shared tokens and motion only.
3. Budgets above still hold. Emotional work NEVER adds a control.
4. No mascot or character. Delight = drawn marks, motion, colour, words (`Moment`).
5. Calm surface: Linen ground, space, one emphasised element per screen; remove dead cards and any metric shown twice; one icon family; no decorative emoji.
6. Colour with intent: pink fills the one primary; petrol for links/icons/data; sage only for real achievement; AA contrast incl. on pink.
7. Every action is answered: press feedback about 0.1 s, result within about 1 s, longer waits show honest progress (response ladder in guide 5.6); no fake waits (D39).
8. Forgiving: undo for last set and last food; nothing she typed is lost on error; destructive actions in an overflow menu that says what will happen.
9. Defaults read as a recommendation; button copy states the payoff ("Start, 4 moves ready").
10. Progress starts ahead: count what she already did; never start a meter at zero.
11. Value before ask: she trains once before an account (D62); never blur a result behind a wall.
12. One peak (R10) and one kind ending per flow; fix low points before adding highs.
13. Make it hers: name things, choices, greet by first name if known, otherwise no name (never "You" as a name).
14. Motion: all timings from `HandTiming`, no magic numbers in screens; entering decelerates, leaving accelerates, spring only for a mark pop; animations play once, never loop where she reads or does a set, never delay the next task; reduced motion shows the final state.
15. Haptics confirm, never decorate: set logged light, session finished medium, food logged selection tick, one per moment, always with a visual.
16. Sound: specified (synthesised, short, quiet, switch in Profile) but NOT built; do not add.
17. State design: empty = small drawn art + one warm line + the single next step; loading = `Skeleton` matching the layout, never a bare spinner on a main screen; error = keep her work, plain cause, one next step, no blame/codes; offline = say what still works; success = `Moment` or a one-line confirmation, never a modal for a small success; permission asks only when the purpose is obvious.
18. Microcopy: predict the outcome before the tap; one idea per line; no exclamation marks except real wins; no jokes in errors or safety; test every string in EN and AR at 200% text.
19. Moments catalog (M1 tick, M2 welcome, M3 set done, M4 rest ring, M5 R10 peak with count-up and confetti only for a real best or a first session, M6 week closed, M7 welcome back with no missed-day counts, M8 food logged, M9 milestone, M10 verified, M11 stagger, M12 tilt on Home hero only): at most ONE moment per screen state; none on R07, R09, Progress charts or error states; each plays once per trigger.
20. Guardrails: never imply a medical effect; honest rewards only (D41); competition only against her own past (D38).

---

## 6. Safety and legal rules (never weaken)

| Rule | Where it lives | What must stay true |
|---|---|---|
| Women-only verification | `functions/identity/*`, `AppRouter.verificationGate`, `openBeforeVerification`, `firebase/firestore.rules` `isVerified()`, `Feature.accountRequired` | No product screen opens before the server `verified` claim. Review is a live woman reviewer (video call or ladies-only gym visit). The niqab route (C15) is camera-free by structure. Do not add flows to `openBeforeVerification`. Do not mint `verified` from the client. |
| No ID/selfie storage | `functions/main.py` header | Images exist only in request memory; no bucket, no log, no analytics. |
| 18+ confirmation | `functions/identity/approvals.py` (`adultConfirmedBy`, `needing_age_tick`, `set_preapproved(... adult_seen)`) | A pre-approved phone number approves nobody unless a reviewer ticked 18+; numbers added before the tick need re-adding with the tick. |
| Consent records | `record_consent`, `record_legal_acceptance`, `record_pledge`, `record_health_consent`, `record_meal_photo_consent` in `functions/main.py`; versions in `functions/identity/config.py` (e.g. `PLEDGE_VERSION`) | Server stores version + locale + app version + time; client versions must equal the server's current ones. Health backup needs its own separate consent. Meal photos need consent before the first photo (E12). |
| Health flags | `lib/features/private_coaching/presentation/desk/coach_desk_view.dart` (`anyHealthYes`, `healthAnswersToReadFirst`), `lib/domain/safety/*`, O04 life-stage screening | A coach must see flagged health answers before accepting; life-stage screening runs before any plan; exercise candidates are filtered by `exercise_candidate_filter.dart`. Do not bypass in new flows. |
| Allergy guard | `lib/features/eat/domain/allergy_guard.dart`, `app/tool/allergen_tripwire.py` | Never suggest a food she marked unsafe. |
| Privacy | `analytics_gateway.dart`, `analytics_consent.dart`, `crash_consent.dart`, account deletion/export in `functions/account/` | No health/body/cycle/typed text in analytics; deletion removes everything incl. Storage; manifest tests must pass. |
| No loss or guilt wording | D37-D41, `test/product_rules_test.dart` | Streak: she controls it, pauses allowed, ending is silent, never in a notification/widget. Never "lose", "break", "miss", "at risk", missed-day counts, body shaming, ranking, chance rewards. |
| Payments stay off | see 1.3 | `Feature.payments` false; `COACH_PAYMENTS_LIVE` False; rules `coachPaymentsLive()` false. |
| Medical disclaimer | `lib/ui/medical_disclaimer.dart`, `test/release/compliance_copy_test.dart` | "Not a medical device" wording stays where the test requires it, both languages. No copy promises a video call. |
| Coach fee (D63) | `docs/plan` + `DECISIONS.md` D63 | Members see the coach's own price; Own Hub keeps 15% (8% for her own invited clients) from the coach side. |

---

## 7. Exact commands

Setup once per shell: `export PATH="$HOME/development/flutter/bin:$PATH"` (Flutter 3.47.4, Dart ^3.13.3). `timeout` does not exist on this Mac. Run Flutter commands from `~/ownhub/app`.

| Task | Command | Success looks like |
|---|---|---|
| Dependencies | `cd ~/ownhub/app && flutter pub get` | `Got dependencies!` |
| Analyze | `cd ~/ownhub/app && flutter analyze` | `No issues found!` (verified 26 Oct, 18 s) |
| One test file | `cd ~/ownhub/app && flutter test test/qa/screen_budget_test.dart` | last line `All tests passed!` |
| One folder | `flutter test test/routing` | `All tests passed!` |
| Full Flutter suite | `cd ~/ownhub/app && flutter test` (10 to 28 min; run in the background and read the output file) | `All tests passed!` with `+N ~M` (N passed, M skipped). Last full green run: `+8803 ~108` (24 Oct). On the current dirty tree see 9.4. |
| pytest (functions + site) | `cd ~/ownhub/functions && venv/bin/python -m pytest -q -p no:cacheprovider` | `3459 passed in ~60s` (verified 26 Oct) |
| Firestore rules | `cd ~/ownhub && PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH firebase emulators:exec --config firebase.emulator.json --only firestore,auth --project own-hub "cd test/rules && npm test"` | `ℹ tests 446`, `ℹ pass 446`, `ℹ fail 0`, `Script exited successfully (code 0)` (verified 26 Oct; one rare flaky failure seen once: rerun) |
| Storage rules | `cd ~/ownhub/test/rules && PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm run test:storage` | `ℹ pass 33`, `ℹ fail 0` (verified 26 Oct) |
| Staff dashboard | `cd ~/ownhub/admin-web && node --test` | `ℹ pass 77`, `ℹ fail 0` (verified 26 Oct) |
| Regenerate tokens/routes/ARB | `cd ~/ownhub/6-v2 && node src/merge-i18n.mjs && node src/build-flutter.mjs && cd ../app && flutter gen-l10n` | prints `tokens and routes written for 196 screens`, `app files synced: N` |
| Add strings | `python3 ~/ownhub/app/tool/add_strings.py /path/strings.json` | one line per string `English   l10n.getter` |
| Website build | `cd ~/ownhub/site && python3 _build/build.py` | page list; covered by pytest |
| Release preflight | `cd ~/ownhub/app && bash tool/release_preflight.sh` (add `RELEASE_BASE_URL=https://own-hub.app` for URL checks) | all lines PASS or SKIP; last recorded 83 pass / 0 fail (23 Oct); see 9.4 for today's count |
| Coaching end to end | `cd ~/ownhub && bash app/tool/e2e_coaching.sh run` | PASS per step (30 passed, 1 skipped on 23 Oct; not re-run today) |
| Knowledge graph | `cd ~/ownhub && graphify query "<question>"`; after changing code `graphify update .` | |
| Run on Android emulator | `~/Library/Android/sdk/emulator/emulator -avd ownhub_pixel8` then `cd ~/ownhub/app && flutter run -d emulator-5554` (confirm id with `flutter devices`); open a screen: `flutter run --route /train/r01`; Arabic: `--dart-define=OWNHUB_LOCALE=ar`; local Firebase emulators: `--dart-define=OWNHUB_EMULATOR_HOST=10.0.2.2` | |
| iOS | The iOS 26.3 simulator CANNOT run the app (ML Kit ships no arm64 simulator slice). Use the Android emulator `ownhub_pixel8`. Booted simulator devices exist (iPhone 17 Pro etc.) but are for builds only. | |
| Build iPhone (owner uploads) | `cd ~/ownhub/app && bash tool/build_ios.sh` | IPA at `app/build/ios/ipa/own_hub.ipa`; owner uploads with Transporter |
| Build Android | `cd ~/ownhub/app && bash tool/build_release.sh` | AAB (owner uploads to Play) |
| Store screenshots | `OWNHUB_SCREENSHOTS_DIR=$HOME/ownhub/docs/release/launch-pack/screenshots flutter test test/store/store_screenshots_test.dart` | |

Deploys (functions, rules, indexes, dashboard, site, stores) are run by the OWNER. Order for the release-2 changes: functions, then `storage.rules`, then the dashboard within minutes, then the owner re-adds pre-approved numbers with the 18+ tick, the app last. An agent never deploys.

### 7.1 Git rules

| Rule | Detail |
|---|---|
| Branch | Work on `feat/motivation-2026-10-13`. Never push to `main`. Never push at all unless the owner says so in chat. |
| Commit only when the work order says so (or the owner says so). | Stage explicit paths (`git add path1 path2`), never `git add -A` / `.`. |
| NO `Co-Authored-By` line, no AI attribution, no "Generated with" line in commits or PRs. | Owner rule, overrides tool defaults. |
| Never stage `.claude/CLAUDE.md` | It is local only (matched by the `*.md` rule in `.gitignore`). |
| Ignored by default | `*.md` and `docs/` are in `.gitignore`; existing docs were force-added. New `.md` files need `git add -f` and only if the work order says to. |
| No AI comments or planning markdown in source | Code comments explain WHY only; no TODO-from-AI, no planning labels. |
| Scratch | Do not commit `firestore-debug.log`, `own_hub_tmp/`, `app/test/zz_probe_parser_test.dart` (untracked probe file, see 9.4). |
| Commit message | One short imperative line, then a short body of what and why. |

---

## 8. Glossary

| Term | Meaning |
|---|---|
| Screen id | Letter + number from `appRoutes`: C sign-up, O setup, T home, R train, E eat, P you/progress, Y cycle, G coached (dark), M community (dark), H member coaching, A account, X assistant (dark), K coach, W coach tools, B coach brand (dark), Z staff admin. Lower-case suffix `b` = a sub-step (C09b, C10b). |
| Flow | Group of screens (17). `AppRoute.flow`. Gate and flags work per flow and per screen. |
| `Feature` / flag | Enum switch in `feature_flags.dart`; `shipped` is what stores get; `meta/features` is the server overlay; Z14 is the staff screen. |
| Dark | Built and compiled but unreachable (flag off). |
| Gate / claim | The whole-app women-only gate; the server-minted `verified` token claim. |
| Pre-approved number | A phone number a reviewer approved in advance; needs the 18+ tick (`adultConfirmedBy`). |
| Reviewer | A woman who does the live check for a flagged sign-up. |
| Lens screens | C10, C10b, C11 (the only screens that open a camera). |
| Budget | The per-screen limit: 1 filled primary, 5 other controls above the fold. |
| Chrome | Her picture + language switch drawn by the top bar; excluded from budgets. |
| Hand layer | `lib/ui/hand/`: hand-drawn marks and motion. |
| Moment | The `Moment` widget and the moments catalog M1-M12. |
| Peak | R10 "Finished": the one big celebration of a session. |
| Linen / Petrol / Pale Pink | The three brand colours (D49). |
| D-number | Owner decision in `DECISIONS.md` (D9 name, D11 train/coach/both, D25 flags and gate, D37-D41 streak/challenge/waits/peak/honest rewards, D45 Egyptian Arabic everywhere, D49 palette, D59 food one-tap, D62 guest first workout, D63 coach fee). |
| WP / wave / batch | Plan units: WP1-WP9 (launch pass), waves 1-6 (release 2), batch A (A1 workout, A2 eat, A3 settings/coaching/events) and batch B. Phases 1-6 in `PRODUCTION-RELEASE-PLAN.md`. |
| Tier | Training level tabs (`tier_tabs.dart`, `ViewedTier`). |
| Programme / plan | Starting programme (O05), her week (R02), 30-day coach plan (H05). |
| Snapshot | The one local JSON document of her week (`app_snapshot.dart`). |
| `AppChanges.bump()` | The signal that makes visible screens redraw. |
| `useShippingApp()` | Test harness helper that builds the app with the shipped flag set. |
| `l10n` | `AppL10n.of(context)`; getter names come from the English text. |
| Z screens | Staff-only console, never in a store build. |
| Rahma's book | Recipe pack from `app/tool/extract_rahma_book.py`, shown on `BookCard`. |

---

## 9. How to work (protocol for weaker agents)

### 9.1 Loop

1. Open `handover/00-START-HERE.md`, then this file once. Then take ONE work order from `handover/work-orders/` in the order `handover/02-IMPLEMENTATION-GUIDE.md` (or the INDEX files) lists. Read only that order and the files it names.
2. Check `Depends on:`. If a dependency is not done, do not start; pick the next independent order.
3. Read the "Reads first" files. Confirm each anchor exists (`grep -n "<anchor>" <file>`). If an anchor is missing or the code differs from the order, STOP (9.3).
4. Do the steps in order, one file at a time. Copy code exactly. Do not refactor, rename, reformat or "improve" anything outside the step. Use the existing widgets in 2.4; never invent a button, card, sheet or color.
5. After each step run `cd ~/ownhub/app && dart format <changed files> && flutter analyze`. Fix only what you caused.
6. Add strings only through `add_strings.py` (3.5). Never hand-edit generated files (`app_tokens.dart`, `app_routes.dart`, `app/lib/l10n/*`).
7. Run the order's Verify commands and compare with the expected output. Paste real output into your report. Never claim "passed" without having run it.
8. After code changes run `cd ~/ownhub && graphify update .`.
9. Tick the Done checklist. Do not commit unless the order says so (7.1).

### 9.2 Report format (end of every work order)

```
WO-NN: <title>
Status: DONE | PARTIAL | BLOCKED
Files changed: <paths>
Strings added: <English keys, getter names>
Commands run and real output: <command> -> <last 5 lines>
Checklist: [x] ... [ ] ...
Deviations from the order: <none | what and why>
Questions written to handover/QUESTIONS.md: <none | list>
```

### 9.3 When to stop

Stop and append to `~/ownhub/handover/QUESTIONS.md` (create it if absent) when: an anchor or file in the order is missing or different; a test fails twice for a reason you do not understand; a step would need to touch a file not listed; a change would weaken a rule in section 6; a budget test fails and the only fix is to add a control or remove a required one; you are tempted to guess a key, id or behaviour. Write: work order id, step number, file:line, what you expected, what you saw, the command output. Then move to the next work order that does not depend on this one. Never "fix" by deleting a test, lowering a threshold, skipping a guard or adding a flag to bypass the gate.

### 9.4 Known dirty-tree facts (26 Oct 2026, verify with `git status --short`)

| Fact | Detail |
|---|---|
| Uncommitted changes | `git status --short` lists about 131 entries (126 files changed, 1,945 insertions, 2,521 deletions). They are batch A (workout follow-ups, Eat trim, step 8 settings/coaching/events, R10 undo and count-up, R13 deletion, budgets) plus the kitten removal and 6-v2 prototype/string changes. Last commits: `ec272aa` (release 2 waves 1-3), then docs commits up to `6ed9864`. Do not commit them yourself unless a work order says so. Do not revert them. |
| Deleted (tracked) | `app/lib/app_state/kitten_setting.dart`, `app/test/features/train/move_logged_view_test.dart` (R13 removed). |
| New untracked | `app/lib/ui/hand/moment.dart`, `app/test/ui/hand/moment_test.dart`, `app/test/features/train/finish_reveal_test.dart`, `app/test/qa/step8_budget_test.dart`, `app/test/routing/last_log_undo_test.dart`, and a scratch `app/test/zz_probe_parser_test.dart` (not part of the product; do not commit, do not delete without the owner). |
| Two failing Flutter tests (verified 26 Oct) | `app/test/features/train/training_reminders_test.dart`: group "Home reminder offer", test "her days, preselected from her week, are set once allowed". `app/test/app_state/getting_started_test.dart:242`: "the meal photo tip only where she can take one the plan leaves it out and marks it done" (expected length 2, actual 0). They belong to the dirty tree; do not "fix" by editing the tests unless a work order says so. |
| Verified green today | `flutter analyze` No issues; pytest 3459 passed; Firestore rules 446/0; storage rules 33/0; admin-web 77/0. `release_preflight.sh` printed `78 passed, 1 failed, 3 skipped` (the single FAIL line was not captured; run the script and `grep FAIL` before relying on it). |
| Full `flutter test` on this tree | A full run was started 26 Oct; the result is appended in 9.5 if it finished before this file was closed. |
| Stale comments | A few source comments still mention "kitten". Harmless. |
| Disk | Disk was filled once (24 Oct); keep `app/build` (holds the IPA in review). |

### 9.5 Full-suite result on the dirty tree

(filled in below if available)
