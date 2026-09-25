#!/usr/bin/env bash
# Pre-submission gate. Run it the morning you submit; every check must PASS.
#
# Adapted from flutter-store-release-guide.md Phase 8, plus the gates this app
# needs that the guide could not know about:
#   1. No testing affordance may reach a store. The first release ships with no
#      account, so "an account is required" can no longer be what separates a
#      testing build from a real one: the index of every screen, the printed
#      sign-in code and the test payment rail all key off the build mode now,
#      and this checks that they still do.
#   2. The four public pages must have addresses in lib/config/legal_links.dart.
#      The in-app privacy row is drawn only when they do, so an empty value is
#      not a cosmetic gap: it is a missing store requirement.
#   3. The public URLs are also fetched when RELEASE_BASE_URL is set; without it
#      those checks are reported as SKIP, never silently passed.
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
echo "-- this is a store build, not a testing build --"
check "testing aids need a debug build"    "grep -q 'kDebugMode && !featureFlags.isOn(Feature.accountRequired)' lib/routing/app_router.dart"
check "no aid keys off a flag alone"       "! grep -rn 'isTestMode' lib/app_state | grep -q 'accountRequired'"
check "the console is compiled out"        "grep -q 'resolvesInThisBuild' lib/routing/app_router.dart"
check "release guards pass"                "flutter test test/release_readiness_test.dart"

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
echo "-- secrets hygiene --"
check "key.properties is ignored"          "git check-ignore -q android/key.properties"
check "keystores are ignored"              "grep -q '\*\.jks' ../.gitignore"
check "no signing material in history"     "[ -z \"\$(git log --all --name-only --pretty=format: -- '*.jks' '*.keystore' '*.p8' '*.p12' 'key.properties' | grep . || true)\" ]"
found=$(find . -path ./build -prune -o \( -name '*.jks' -o -name '*.keystore' -o -name '*.p8' -o -name '*.p12' \) -print 2>/dev/null | head -5)
if [ -z "$found" ]; then ok "no signing material inside the repo"; else bad "signing material inside the repo: $found"; fi
# The generated `lib/firebase_options.dart` is excluded, and only it.
#
# A Firebase apiKey is not a secret: it is a public project identifier that
# ships inside every Android and iOS binary by design, it authorises nothing on
# its own, and what protects the data is firebase/firestore.rules. Treating it
# as a secret here would mean deleting the file the app cannot compile without.
#
# `AIza` still fails everywhere else, because a Gemini key looks identical and
# IS a secret that would bill us. The exclusion is one path, not a relaxed
# pattern, and the same reasoning is pinned by tests in
# `test/product_rules_test.dart` and
# `test/features/assistant/assistant_product_rules_test.dart`, each paired with
# a second test proving the exclusion cannot hide a real key.
check "no API key literal in lib/"         "! grep -rqE 'sk-ant-|AIza[0-9A-Za-z_-]{30}' --exclude=firebase_options.dart lib"
check "the firebase_options exclusion is not hiding a model key" \
      "! grep -nE 'sk-ant-|ANTHROPIC|AIza[0-9A-Za-z_-]{30}' lib/firebase_options.dart | grep -qvE 'apiKey:'"

echo
echo "-- release build hygiene --"
check "no bare print() in lib/"            "! grep -rn --include='*.dart' -E '^[[:space:]]*print\(' lib | grep -q ."

echo
echo "-- the four public pages --"
check "legal links filled in"              "! grep -qE \"static const String (privacyPolicy|terms|support|deleteAccount) = ''\" lib/config/legal_links.dart"

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
echo "-- the built bundle, when there is one --"
AAB=build/app/outputs/bundle/release/app-release.aab
if [ -f "$AAB" ]; then
  tmp=$(mktemp -d)
  unzip -q -o "$AAB" 'base/lib/*' -d "$tmp" 2>/dev/null || true
  libs=$(find "$tmp/base/lib/arm64-v8a" "$tmp/base/lib/x86_64" -name '*.so' 2>/dev/null)
  if [ -n "$libs" ]; then
    # Play requires 16 KB page alignment on every 64-bit native library.
    if python3 tool/elf_align.py $libs | grep -q 'TOO SMALL'; then
      bad "every 64-bit library is 16 KB aligned"
      python3 tool/elf_align.py $libs | sed 's/^/        /'
    else
      ok "every 64-bit library is 16 KB aligned"
    fi
  fi
  # Which key signed it, read from the signature block's own name: Gradle
  # names it after the key alias, so a debug fallback is META-INF/ANDROIDD.RSA
  # and an upload key called "upload" is META-INF/UPLOAD.RSA. This is read from
  # the file rather than from keytool because keytool needs a JDK, and a check
  # that silently passes when a tool is missing is worse than no check.
  sig=$(unzip -l "$AAB" | awk '{print $4}' \
    | grep -m1 -E '^META-INF/[^/]+\.(RSA|EC|DSA)$' || true)
  case "$sig" in
    '')
      bad "the bundle is signed (built unsigned: no android/key.properties)" ;;
    META-INF/ANDROIDD.*)
      bad "the bundle is signed with the DEBUG key; Play refuses that upload" ;;
    *)
      ok "the bundle is signed with $(basename "$sig" | cut -d. -f1)" ;;
  esac
else
  na "bundle checks (16 KB alignment, signing)" "no app-release.aab built yet"
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
