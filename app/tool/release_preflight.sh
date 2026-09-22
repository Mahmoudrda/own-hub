#!/usr/bin/env bash
# Pre-submission gate. Run it the morning you submit; every check must PASS.
#
# Adapted from flutter-store-release-guide.md Phase 8 in two ways that matter:
#   1. This project is NOT a git repository, so the guide's git-history secret
#      scans cannot run. They are replaced with filesystem checks that catch the
#      same mistake (signing material sitting inside the repo).
#   2. The public URLs do not exist yet. Set RELEASE_BASE_URL to enable those
#      checks; they are reported as SKIP, never silently passed.
#
#   RELEASE_BASE_URL=https://ownhub.example bash tool/release_preflight.sh

set -uo pipefail
cd "$(dirname "$0")/.."

pass=0; fail=0; skip=0
ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
na()   { printf '  SKIP  %s  (%s)\n' "$1" "$2"; skip=$((skip+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "== Own Hub release preflight =="
echo
echo "-- build health --"
check "flutter analyze clean"              "flutter analyze lib test"
check "flutter test passes"                "flutter test"

echo
echo "-- identity and versioning --"
check "no com.example package id"          "! grep -rq 'com\.example' android/app/build.gradle.kts ios/Runner.xcodeproj/project.pbxproj"
check "applicationId is com.ownhub.app"    "grep -q 'applicationId = \"com.ownhub.app\"' android/app/build.gradle.kts"
check "pubspec description is not template" "! grep -q 'A new Flutter project' pubspec.yaml"
check "version line present"               "grep -qE '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' pubspec.yaml"

echo
echo "-- Google Play hard requirements --"
check "compileSdk pinned to 36"            "grep -q 'compileSdk = 36' android/app/build.gradle.kts"
check "targetSdk pinned to 36"             "grep -q 'targetSdk = 36' android/app/build.gradle.kts"
check "R8 minification enabled"            "grep -q 'isMinifyEnabled = true' android/app/build.gradle.kts"
check "proguard rules exist"               "[ -f android/app/proguard-rules.pro ]"
if [ -f android/key.properties ]; then
  ok "release keystore configured"
else
  bad "release keystore configured (android/key.properties missing - release builds fall back to DEBUG signing and Play will reject the upload)"
fi

echo
echo "-- Apple hard requirements --"
check "privacy manifest present"           "[ -f ios/Runner/PrivacyInfo.xcprivacy ]"
check "privacy manifest in Xcode target"   "grep -q 'PrivacyInfo.xcprivacy' ios/Runner.xcodeproj/project.pbxproj"
check "export compliance declared"         "grep -q ITSAppUsesNonExemptEncryption ios/Runner/Info.plist"
check "ExportOptions.plist present"        "[ -f ios/ExportOptions.plist ]"
check "team id filled in"                  "! grep -q 'YOUR_TEAM_ID' ios/ExportOptions.plist"
check "iPhone-only (iPad not declared)"    "! grep -q 'TARGETED_DEVICE_FAMILY = \"1,2\"' ios/Runner.xcodeproj/project.pbxproj"

echo
echo "-- secrets hygiene (filesystem, this repo is not under git) --"
check "key.properties is gitignored"       "grep -q 'key.properties' .gitignore"
check "keystores are gitignored"           "grep -q '\*\.jks' .gitignore"
found=$(find . -path ./build -prune -o \( -name '*.jks' -o -name '*.keystore' -o -name '*.p8' -o -name '*.p12' \) -print 2>/dev/null | head -5)
if [ -z "$found" ]; then ok "no signing material inside the repo"; else bad "signing material inside the repo: $found"; fi
check "no API key literal in lib/"         "! grep -rqE 'sk-ant-|AIza[0-9A-Za-z_-]{30}' lib"

echo
echo "-- release build hygiene --"
check "no bare print() in lib/"            "! grep -rn --include='*.dart' -E '^[[:space:]]*print\(' lib | grep -q ."

echo
echo "-- public URLs --"
if [ -n "${RELEASE_BASE_URL:-}" ]; then
  for path in privacy terms support delete-account; do
    check "$RELEASE_BASE_URL/$path reachable" "curl -sSfI -o /dev/null '$RELEASE_BASE_URL/$path'"
  done
else
  na "privacy / terms / support / delete-account URLs" "RELEASE_BASE_URL not set"
fi

echo
echo "-- store assets --"
if [ -f assets/icon/icon-1024.png ]; then
  ok "1024 icon master present"
else
  bad "1024 icon master present (assets/icon/icon-1024.png missing - owner must supply)"
fi

echo
printf '== %d passed, %d failed, %d skipped ==\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || echo "DO NOT SUBMIT while anything above says FAIL."
exit $(( fail > 0 ? 1 : 0 ))
