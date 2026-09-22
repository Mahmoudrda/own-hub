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

The app currently opens straight onto Home as a guest who holds both roles, trainee and coach, so
every part of it can be browsed without an account. That is a feature flag, `Feature.accountRequired`
in `app/lib/domain/flags/feature_flags.dart`. **Switch it back on before any public release.**

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
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS
```

Signing keys and service credentials are never committed. Android reads them from
`android/key.properties`, which stays on the machine that builds.
