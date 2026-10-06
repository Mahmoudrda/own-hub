#!/usr/bin/env bash
# The one way a release build is made, so a crash in it can be read.
#
# A release build is obfuscated AOT code. Without the symbols that
# `--split-debug-info` writes, a Dart stack in Crashlytics is a column of
# addresses nobody can act on. This script builds with those symbols kept under
# build/symbols/<version> (gitignored with the rest of build/) and prints the
# exact upload command to run once the build is the one being shipped. The
# Crashlytics Gradle plugin is deliberately not used: the build stays plain
# Flutter, and the upload is one visible step.
#
#   bash tool/build_release.sh
#
# Android, what this script does:
#   1. flutter build appbundle  --release --obfuscate --split-debug-info=build/symbols/<version>
#   2. flutter build apk        --release --split-per-abi --obfuscate
#                               --split-debug-info=build/symbols/<version>/apk
#      The APK build is a second compile. When its symbols match the bundle's
#      they are dropped; when they do not, a second upload line is printed.
#   3. Prints the upload for the Android Firebase app:
#        firebase crashlytics:symbols:upload --app=<android app id> build/symbols/<version>
#      Run it (owner or integrator, signed in with `firebase login`) after every
#      release build that is uploaded to Play or handed out. Keep the symbols
#      folder for as long as that build is installed anywhere: a build's
#      symbols cannot be made again later.
#
# iOS, the equivalent (run on the Mac that archives; not automated here):
#   1. Dart symbols:
#        flutter build ipa --release --obfuscate \
#          --split-debug-info=build/symbols/<version>-ios \
#          --dart-define=APP_VERSION=<version> \
#          --export-options-plist=ios/ExportOptions.plist
#        firebase crashlytics:symbols:upload \
#          --app=1:681714989950:ios:0e2cab381dd5cd91fbd12f build/symbols/<version>-ios
#   2. Native symbols (dSYM). Release is already DEBUG_INFORMATION_FORMAT =
#      dwarf-with-dsym, so the archive carries them in
#      build/ios/archive/Runner.xcarchive/dSYMs. Upload them with the tool the
#      FirebaseCrashlytics pod ships:
#        ios/Pods/FirebaseCrashlytics/upload-symbols \
#          -gsp ios/Runner/GoogleService-Info.plist -p ios \
#          build/ios/archive/Runner.xcarchive/dSYMs
#      After App Store processing, download the dSYMs App Store Connect made
#      for that build and upload them the same way if Crashlytics reports a
#      missing dSYM.
#
# Nothing here reads or prints key.properties, a keystore or a Firebase config
# file. Signing is android/app/build.gradle.kts's job, and it refuses to sign a
# release with the debug key.

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(grep -E '^version: ' pubspec.yaml | head -1 | awk '{print $2}')"
if [ -z "$VERSION" ]; then
  echo "No version line in pubspec.yaml." >&2
  exit 1
fi
SYMBOLS="build/symbols/$VERSION"

# The app the upload is for. Checked against firebase_options.dart so a
# reconfigured project cannot leave this pointing at the wrong app.
ANDROID_APP_ID="1:681714989950:android:3ba803734abd9ca3fbd12f"
if ! grep -q "appId: '$ANDROID_APP_ID'" lib/firebase_options.dart; then
  echo "The Android app id here no longer matches lib/firebase_options.dart." >&2
  echo "Update ANDROID_APP_ID and the upload line in tool/build_release.sh." >&2
  exit 1
fi

if [ -d "$SYMBOLS" ]; then
  echo "$SYMBOLS already exists. A version is built once; bump the version" >&2
  echo "in pubspec.yaml, or move the old symbols away if they were uploaded." >&2
  exit 1
fi

echo "== Own Hub release build $VERSION =="

# The version recorded beside every acceptance and consent she gives
# (lib/features/signup/domain/legal_acceptance.dart, kAppVersion).
DEFINES=(--dart-define=APP_VERSION="$VERSION")

flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOLS" "${DEFINES[@]}"

flutter build apk --release --split-per-abi --obfuscate --split-debug-info="$SYMBOLS/apk" "${DEFINES[@]}"

same=1
for f in "$SYMBOLS"/apk/*.symbols; do
  if ! cmp -s "$f" "$SYMBOLS/$(basename "$f")"; then same=0; fi
done
if [ "$same" -eq 1 ]; then
  rm -rf "$SYMBOLS/apk"
fi

echo
echo "Built:"
echo "  build/app/outputs/bundle/release/app-release.aab"
echo "  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (the one to hand out)"
echo "Symbols: $SYMBOLS"
echo
echo "Upload the Dart symbols for this build to Crashlytics:"
echo
echo "  firebase crashlytics:symbols:upload --app=1:681714989950:android:3ba803734abd9ca3fbd12f $SYMBOLS"
if [ "$same" -eq 0 ]; then
  echo "  firebase crashlytics:symbols:upload --app=1:681714989950:android:3ba803734abd9ca3fbd12f $SYMBOLS/apk"
fi
echo
echo "Keep $SYMBOLS for as long as this build is installed anywhere."
