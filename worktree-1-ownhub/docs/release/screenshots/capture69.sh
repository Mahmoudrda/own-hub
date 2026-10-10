#!/usr/bin/env bash
# Capture screens from a named simulator, one launch each.
#   capture69.sh <udid> <out-dir> <route:name> ...
set -uo pipefail
udid="$1"; shift
out="$1"; shift
mkdir -p "$out"
for spec in "$@"; do
  route="${spec%%:*}"
  name="${spec##*:}"
  xcrun simctl launch --terminate-running-process "$udid" com.ownhub.app --route="$route" >/dev/null 2>&1
  sleep 5
  xcrun simctl io "$udid" screenshot "$out/$name.png" >/dev/null 2>&1
  printf '  %s\n' "$name"
done
