# Own Hub

A women-only fitness app for Egypt: workouts, meals, a private community, cycle tracking, and
coaching between women. Flutter, iOS and Android, Arabic and English, one custom design language on
both platforms.

## Layout

| Path | What is in it |
|---|---|
| `app/` | The Flutter application. This is the product. |
| `6-v2/src/` | The screen inventory and the build scripts that generate part of the app. |
| `6-v2/i18n/` | The Arabic dictionary, keyed by the English source string. |
| `firebase/` | Security rules and functions for the backend, which is not connected yet. |

## Running it

```sh
cd app
flutter pub get
flutter run                                   # English
flutter run --dart-define=OWNHUB_LOCALE=ar    # Arabic
```

The app opens straight onto Home. There is no account, because the first release does not need one:
it is Today, Train, Eat, My cycle and Progress, and all of it works on the phone with nothing behind
it. The community, the coach side, payments and the assistant are switched off until there is a back
end to support them honestly, and each switch is one line in `FeatureFlags.shipped`
(`app/lib/domain/flags/feature_flags.dart`), which says why.

To walk the whole product, including the parts the first release does not ship, run the tests: the
crawler, the journeys and the large-text sweep all build `FeatureFlags.everything`.

```sh
OWNHUB_QA_REPORT=/tmp/crawl.tsv flutter test test/qa/tap_crawler_test.dart
```

`tool/release_preflight.sh` is the gate before any submission. It refuses a build that still carries
the testing affordances, checks Play's 16 KB page alignment on every native library, reads which key
signed the bundle, and fails while the four public pages have no address.

## Generated files, do not edit by hand

Three things in `app/` are written by the scripts in `6-v2/src/` and will be overwritten:

- `app/lib/theme/app_tokens.dart` and `app/lib/routing/app_routes.dart`
- `app/lib/l10n/*.arb` and everything generated from them

To add or change a UI string, use the helper, which takes a lock, merges both languages, regenerates
and prints the getter name each string got:

```sh
cd app
python3 tool/add_strings.py strings.json
```

Arabic is Modern Standard Arabic addressed to a woman. Western digits in both languages.

## Tests

```sh
cd app
flutter analyze
flutter test                      # the whole suite
flutter test test/journeys        # whole features, walked the way a woman would
```

`test/qa/tap_crawler_test.dart` opens every screen and taps every control on it, writing a report of
what each tap did:

```sh
OWNHUB_QA_REPORT=/tmp/crawl.tsv flutter test test/qa/tap_crawler_test.dart
```

## Release builds

```sh
cd app
flutter build appbundle --release                   # Android, for Play
flutter build apk --release --split-per-abi         # Android, for a direct install
flutter build ipa --release                         # iOS
```

Signing keys and service credentials are never committed. Android reads them from
`android/key.properties`, which stays on the machine that builds.

### Never hand out a universal APK

`flutter build apk --release` without `--split-per-abi` produces ONE file carrying machine code for
all three CPU families Android runs on. A phone runs exactly one of them, so two of the three are
dead weight on every handset that receives the file. Read off the build in
`build/app/outputs/flutter-apk`:

| in the universal APK | |
|---|---|
| the whole file | 98.9 MB |
| arm64-v8a, what every phone since about 2015 runs | 29.6 MB |
| armeabi-v7a, only for a 32-bit handset | 24.3 MB |
| x86_64, only for an emulator | 32.2 MB |
| **dead weight on any one phone** | **56.5 MB** |

Play never ships that file: it splits the AAB per device, so a Play install is about 42 MB. But an
APK sent over WhatsApp is the whole file, and in Egypt that is how a build actually reaches someone.
`--split-per-abi` writes `app-arm64-v8a-release.apk` (about 42 MB), `app-armeabi-v7a-release.apk`
and `app-x86_64-release.apk` instead. `app-arm64-v8a-release.apk` is the one to send to a woman,
`app-x86_64-release.apk` is for an emulator and nothing else.

`tool/release_preflight.sh` fails when the only APK in the output directory is the universal one.
