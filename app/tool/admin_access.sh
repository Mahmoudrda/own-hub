#!/usr/bin/env bash
# The owner's admin build, and the admin claim that lets it do anything.
#
# Two separate things, and both are needed:
#
#   1. The build. The console (Z01 to Z18) is never in a store build: a release
#      binary refuses every admin route whatever is defined. This makes a
#      PROFILE build with --dart-define=ADMIN_BUILD=true, for the owner's own
#      phone only, and writes it under build/admin/, a path nothing uploads
#      from. Profile builds attest App Check with the debug provider, so the
#      debug token has to be registered once in the Firebase console
#      (App Check > Apps > Manage debug tokens) and passed here.
#
#        OWNHUB_APP_CHECK_DEBUG_TOKEN=<token> bash tool/admin_access.sh build
#        adb install -r build/admin/own-hub-admin-<version>.apk
#
#      Or straight onto a connected phone (Android or iPhone):
#
#        OWNHUB_APP_CHECK_DEBUG_TOKEN=<token> bash tool/admin_access.sh run
#
#   2. The claim. Being in the admin build is not being an admin: every write
#      the console makes and every count it reads is refused by the server
#      unless the account holds the `admin` claim. Sign in to the app once with
#      the owner's phone number, copy the uid from Firebase console >
#      Authentication, then, with owner credentials
#      (`gcloud auth application-default login`):
#
#        bash tool/admin_access.sh grant  <uid>
#        bash tool/admin_access.sh check  <uid>
#        bash tool/admin_access.sh revoke <uid>
#
#      Safe to run twice. Sign out and in again on the phone afterwards, so
#      the token carries the change.
#
#   3. Pictures and clips. The member app never asks for the photo library,
#      so media for recipes, events and exercises is uploaded from this
#      computer, with the same owner credentials:
#
#        bash tool/admin_access.sh upload-media recipes om_ali ~/Pictures/om-ali.jpg
#        bash tool/admin_access.sh upload-media events <eventId> cover.png
#        bash tool/admin_access.sh upload-media exercises glute_bridge bridge.mp4
#
#      jpg, png and webp become WebP at most 1600 px on the longest side; mp4
#      is uploaded as it is; over 200 MB is refused. Each lands in
#      content/<collection>/<id>/ and appears in the console's media library,
#      ready to be chosen. Add --keep-original after the id to skip the WebP.

set -euo pipefail
CALLER_PWD="$PWD"
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-flutter}"
FUNCTIONS="../functions"

usage() {
  sed -n '2,48p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

need_token() {
  if [ -z "${OWNHUB_APP_CHECK_DEBUG_TOKEN:-}" ]; then
    echo "Set OWNHUB_APP_CHECK_DEBUG_TOKEN to the debug token registered in" >&2
    echo "the Firebase console; without it every callable answers app_check_missing." >&2
    exit 1
  fi
}

DEFINES=(
  --dart-define=ADMIN_BUILD=true
  --dart-define=OWNHUB_APP_CHECK_DEBUG_TOKEN="${OWNHUB_APP_CHECK_DEBUG_TOKEN:-}"
)

claim() {
  local mode="$1" uid="${2:-}"
  if [ -z "$uid" ]; then
    echo "Which uid? bash tool/admin_access.sh $mode <uid>" >&2
    exit 2
  fi
  local flag=()
  case "$mode" in
    grant) flag=() ;;
    check) flag=(--check) ;;
    revoke) flag=(--revoke) ;;
  esac
  (cd "$FUNCTIONS" && GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-own-hub}" \
    .venv/bin/python -m tools.grant_admin --uid "$uid" ${flag[@]+"${flag[@]}"})
}

case "${1:-}" in
  build)
    for arg in "$@"; do
      if [ "$arg" = "--release" ]; then
        echo "Refused: the admin build is never a release build." >&2
        exit 1
      fi
    done
    need_token
    VERSION="$(grep -E '^version: ' pubspec.yaml | head -1 | awk '{print $2}')"
    "$FLUTTER" build apk --profile "${DEFINES[@]}"
    mkdir -p build/admin
    OUT="build/admin/own-hub-admin-${VERSION}.apk"
    cp build/app/outputs/flutter-apk/app-profile.apk "$OUT"
    echo
    echo "Admin build: $OUT"
    echo "For the owner's phone only. Never upload it to a store or share it."
    ;;
  run)
    need_token
    "$FLUTTER" run --profile "${DEFINES[@]}"
    ;;
  grant | check | revoke)
    claim "$1" "${2:-}"
    ;;
  upload-media)
    if [ "$#" -lt 4 ]; then
      echo "Usage: bash tool/admin_access.sh upload-media <collection> <id> [--keep-original] <file>..." >&2
      exit 2
    fi
    collection="$2"
    doc="$3"
    shift 3
    extra=()
    if [ "${1:-}" = "--keep-original" ]; then
      extra=(--keep-original)
      shift
    fi
    files=()
    for f in "$@"; do
      case "$f" in
        /*) files+=("$f") ;;
        *) files+=("$CALLER_PWD/$f") ;;
      esac
    done
    (cd "$FUNCTIONS" && GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:-own-hub}" \
      .venv/bin/python -m tools.upload_media --collection "$collection" \
      --doc "$doc" ${extra[@]+"${extra[@]}"} "${files[@]}")
    ;;
  *)
    usage
    ;;
esac
