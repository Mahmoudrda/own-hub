# Own Hub — Flutter application

The women-only fitness product for Egypt. The clickable prototype, design tokens, Arabic dictionary
and screen inventory live in `../6-v2/`, and several files in here are **generated from them** — see
*Generated files* before editing anything.

**Read `../DECISIONS.md` first.** It is authoritative and overrides every other document, including
this one. Then `../BUILD-BRIEF.md` §2, which lists eleven non-negotiable product rules drawn from
cited research and a legal check: breaking one is a defect, not a variation.

---

## State

| | |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | green |
| Android build | `app-debug.apk`, `com.ownhub.app` |
| iOS build | `Runner.app` (simulator), `com.ownhub.app` |
| `flutter doctor` | no issues on any line |
| Routing | 155 destinations wired, of 161 screens |
| Screens | **not built** — the destinations render a named placeholder |
| Backend | **not built** — no Firebase project yet |

## Prerequisites

1. **Flutter 3.47.4** (stable), Dart 3.13.3.
2. **A JDK for Android.** macOS ships a `/usr/bin/java` *stub* that reports no runtime, so
   `flutter doctor` says only `Could not determine java version`:
   ```sh
   brew install openjdk@17
   flutter config --jdk-dir /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
   ```
3. **Android SDK `cmdline-tools`** — the SDK and emulator can be present while this one component is
   missing, which blocks every Gradle build. Then `flutter doctor --android-licenses`.
4. **Xcode + CocoaPods** for iOS (`brew install cocoapods`).
5. **Python 3 with `fonttools` and `brotli`**, only to rebuild fonts.

Two things that catch people out here:

- **`flutter` is not on `PATH` in a non-interactive shell.** It is in `~/.zshrc`, so your terminal
  finds it but scripts and CI report "command not found". Export it explicitly:
  `export PATH="$HOME/development/flutter/bin:$PATH"`.
- **No Android emulator is defined.** `flutter build apk` works; `flutter run` on Android needs an AVD
  or a physical device. `flutter run -d chrome` is the quickest look.

## Run

```sh
flutter pub get
flutter test
flutter run -d chrome
flutter build apk --debug
flutter build ios --simulator --debug
```

---

## Generated files — do not hand-edit

Editing one of these appears to work and is silently reverted on the next regeneration.

| File | Generated from | Command |
|---|---|---|
| `lib/theme/app_tokens.dart` | `../6-v2/src/tokens.mjs` | `node src/build-flutter.mjs` in `../6-v2` |
| `lib/routing/app_routes.dart` | `../6-v2/src/inventory.mjs` | same |
| `lib/l10n/app_en.arb`, `app_ar.arb` | `../6-v2/i18n/ar.json` | same |
| `lib/l10n/app_l10n*.dart` | the ARB files | `flutter gen-l10n` |
| `assets/fonts/Rubik-*.ttf` | `../6-v2/assets/fonts/*.woff2` | `python3 6-v2/scripts/build_fonts.py` |
| `../6-v2/tests/TEST-CASES.csv` | the inventory **+ every plan in `../6-v2/plans/`** | `python3 6-v2/scripts/build_testcases.py` |

Full regeneration from the repo root:

```sh
cd 6-v2 && node src/build-flutter.mjs && cd ..
cp 6-v2/flutter/app_en.arb 6-v2/flutter/app_ar.arb app/lib/l10n/
cp 6-v2/flutter/app_tokens.dart app/lib/theme/
cp 6-v2/flutter/app_routes.dart app/lib/routing/
python3 6-v2/scripts/build_fonts.py
python3 6-v2/scripts/build_testcases.py
cd app && flutter gen-l10n && flutter test
```

### Localisation

1,789 keys, English and Modern Standard Arabic, exact parity. Keys are semantic (`continueLabel`,
`today`) and disambiguated by a **fingerprint of the source string**, never by position — an
order-assigned suffix would silently repoint a key to a different string if the dictionary were
reordered. **Every string goes through `AppL10n`**; no hardcoded English or Arabic in a widget.

One accepted cost: because keys derive from the English source, editing an English line changes its
key and orphans the Arabic. The dictionary is keyed by source text anyway, so the edit already
orphaned it — the key just makes it visible. **Edit the dictionary, never the ARB, then regenerate.**

Arabic is addressed to a woman in the second person feminine, renders two points larger with more
line height, and mirrors directional icons. Numbers stay Western (`1,800 EGP`) inside Arabic text,
so isolated numeric spans need an explicit LTR direction.

### Fonts

Rubik covers both scripts. The repo ships it as per-script `.woff2` subsets of a **variable** font,
and Flutter loads neither woff2 nor two files for one weight — so `build_fonts.py` pins the `wght`
axis **first** (merging a variable font fails outright) and merges the latin, latin-ext and arabic
subsets into one TTF per weight. It probes both scripts afterwards and fails loudly, because a
missing Arabic subset renders the whole UI as tofu boxes with no error.

---

## Routing

`lib/routing/app_router.dart` derives its table from the generated inventory: **155 destinations
across all 16 flows**, both roles. `DECISIONS.md` D1 withdrew the MVP cut, so the scope is the whole
product.

Six screens are **deliberately not routable** — T06, E09, M17, K24, W11, B14. Per `HANDOFF.md` rule
16 they are the day-one *renderings* of Home, Eat, Community, the coach's Today, her Clients and her
portfolio: branches inside those routes, chosen when the collection is empty. `test/routing_test.dart`
enforces this. An unbuilt destination renders a conspicuous placeholder naming its screen id, because
the brief forbids a silent stub that looks complete.

## Tests

`test/` currently holds the foundation guards, which assert what fails *silently* otherwise:

- `foundations_test.dart` — tokens, RTL, the font resolving, Arabic rendering as glyphs not tofu.
- `routing_test.dart` — scope, all 16 flows, and the six non-routable states.
- `product_rules_test.dart` — executable guards for the §2 rules that can be checked mechanically: no
  streak may exist in code *or* copy, no calorie countdown, no face-gender classification, no ranking
  by weight or followers, no confirmation dialog on a logging path, no API key in the source.
- `i18n_guard_test.dart` — no hardcoded Arabic outside a tested allowlist, ARB parity.

The full specification is `../6-v2/tests/TEST-CASES.csv` — **592 cases, 146 P0, 36 P1, 410 P2** —
written before implementation so tests cannot be shaped to fit the code. Every P0 and P1 must become
an executable test.

## Not built yet

- The 161 screens, the data layer, and the backend. `../6-v2/plans/` holds a plan per feature group;
  `../6-v2/plans/RECONCILIATION.md` holds the cross-group decisions, the cost model and the open
  questions.
- This directory is **not under version control**.
