#!/usr/bin/env bash
# The one way the iPhone app is built for TestFlight and the App Store.
#
#   bash tool/build_ios.sh
#   BUILD_NUMBER=412345 bash tool/build_ios.sh    a build number of your own
#
# Run it on the Mac, from anywhere. It stops before building, with a sentence
# saying what to fix, when something an App Store build needs is missing:
# Xcode 26 or later (App Store Connect refuses anything older since 28 April
# 2026), the Firebase config file, the Apple team, or the four public pages.
#
# What it does:
#   1. Builds an obfuscated release with its Dart symbols kept under
#      build/symbols/<version>-ios, Google Analytics without the advertising
#      identifier, and the version recorded beside every consent.
#   2. Checks the archive carries no advertising identifier code.
#   3. Uploads the archive's dSYMs to Crashlytics when the upload tool is on
#      this Mac, and prints the Dart symbols upload.
#   4. Prints how to send the build to App Store Connect.
#
# The build number is the minutes since 1 January 2026 UTC, as in
# tool/build_release.sh: App Store Connect refuses a number it has already
# seen, and this one only goes up. The version name comes from pubspec.yaml.
#
# Nothing here reads or prints a key, a password or the Firebase config file's
# contents. Signing is Xcode's automatic signing with the team in
# ios/ExportOptions.plist and Runner.xcodeproj.

set -euo pipefail
cd "$(dirname "$0")/.."

stop() {
  echo >&2
  echo "Stop: $1" >&2
  exit 1
}

[ "$(uname)" = "Darwin" ] || stop "an iPhone build needs a Mac with Xcode."
command -v xcodebuild >/dev/null 2>&1 || stop "Xcode is not installed. Install it from the Mac App Store, open it once, then run this again."
XCODE="$(xcodebuild -version | head -1 | awk '{print $2}')"
[ "${XCODE%%.*}" -ge 26 ] 2>/dev/null || stop "Xcode $XCODE is too old. App Store Connect needs Xcode 26 or later. Update it from the Mac App Store."
command -v flutter >/dev/null 2>&1 || stop "flutter is not on PATH. Run: export PATH=\"\$HOME/development/flutter/bin:\$PATH\""
[ -f ios/Runner/GoogleService-Info.plist ] || stop "ios/Runner/GoogleService-Info.plist is missing. Download it from Firebase console > Project settings > Your apps > the iOS app, and put it there."
! grep -q 'YOUR_TEAM_ID' ios/ExportOptions.plist || stop "ios/ExportOptions.plist still says YOUR_TEAM_ID."
grep -q 'DEVELOPMENT_TEAM = ' ios/Runner.xcodeproj/project.pbxproj || stop "no Apple team is set on the Runner target."
! grep -qE "static const String (privacyPolicy|terms|support|deleteAccount) = ''" lib/config/legal_links.dart || stop "lib/config/legal_links.dart has an empty page address; a release build would refuse to start."

NAME="$(grep -E '^version: ' pubspec.yaml | head -1 | awk '{print $2}' | cut -d+ -f1)"
[ -n "$NAME" ] || stop "no version line in pubspec.yaml."
BUILD="${BUILD_NUMBER:-$(( ($(date -u +%s) - 1767225600) / 60 ))}"
VERSION="$NAME+$BUILD"
SYMBOLS="build/symbols/$VERSION-ios"
[ ! -d "$SYMBOLS" ] || stop "$SYMBOLS already exists. Wait a minute or set BUILD_NUMBER to a higher number."

# The iOS app the dSYMs and Dart symbols belong to, checked against
# firebase_options.dart so a reconfigured project cannot point this elsewhere.
IOS_APP_ID="1:681714989950:ios:02417d9df27fbcf2fbd12f"
grep -q "appId: '$IOS_APP_ID'" lib/firebase_options.dart || stop "the iOS app id here no longer matches lib/firebase_options.dart."

echo "== Own Hub iPhone build $VERSION (Xcode $XCODE) =="

# Google Analytics without the IDFA: firebase_analytics picks
# FirebaseAnalyticsCore only when this is set as the packages resolve.
export FIREBASE_ANALYTICS_WITHOUT_ADID=true

flutter build ipa --release --obfuscate --split-debug-info="$SYMBOLS" --build-name="$NAME" --build-number="$BUILD" --dart-define=APP_VERSION="$VERSION" --export-options-plist=ios/ExportOptions.plist

ARCHIVE="build/ios/archive/Runner.xcarchive"
APP="$ARCHIVE/Products/Applications/Runner.app"
[ -d "$APP" ] || stop "the archive was not made; read the flutter output above."

if grep -rlq ASIdentifierManager "$APP" 2>/dev/null; then
  stop "the archive contains the advertising identifier (ASIdentifierManager). Delete ios/Flutter/ephemeral/Packages and Xcode's DerivedData for Runner, then run this again so the packages resolve without it. Do not upload this build."
fi

echo
echo "No advertising identifier in the archive."

# dSYMs: the Swift Package Manager checkout first, then CocoaPods.
UPLOAD="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols' 2>/dev/null | head -1 || true)"
[ -n "$UPLOAD" ] || UPLOAD="$( [ -x ios/Pods/FirebaseCrashlytics/upload-symbols ] && echo ios/Pods/FirebaseCrashlytics/upload-symbols || true)"
if [ -n "$UPLOAD" ] && [ -d "$ARCHIVE/dSYMs" ]; then
  if "$UPLOAD" -gsp ios/Runner/GoogleService-Info.plist -p ios "$ARCHIVE/dSYMs"; then
    echo "dSYMs uploaded to Crashlytics."
  else
    echo "The dSYM upload failed. It does not block the release; run this later:"
    echo "  \"$UPLOAD\" -gsp ios/Runner/GoogleService-Info.plist -p ios $ARCHIVE/dSYMs"
  fi
else
  echo "Crashlytics' upload tool was not found on this Mac, so the dSYMs were not uploaded."
fi

IPA="$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
echo
echo "Built version $NAME, build $BUILD."
echo "  App:     ${IPA:-build/ios/ipa/ (no .ipa found: open the archive in Xcode instead)}"
echo "  Archive: $ARCHIVE"
echo "  Symbols: $SYMBOLS (keep this folder as long as the build is installed anywhere)"
echo
echo "Upload the Dart symbols for this build to Crashlytics:"
echo "  firebase crashlytics:symbols:upload --app=$IOS_APP_ID $SYMBOLS"
echo
echo "Send it to App Store Connect, either way:"
echo "  - Transporter (free on the Mac App Store): sign in, drag the .ipa in, Deliver."
echo "  - Xcode: open $ARCHIVE, then Distribute App > App Store Connect > Upload."
echo "It appears in App Store Connect > TestFlight after Apple processes it (often 10 to 30 minutes)."
