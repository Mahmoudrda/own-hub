#!/usr/bin/env bash
# Separate red-before-code contract pack. Never calls production services.
set -u
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
results="$repo_root/acceptance/free_launch/results"
mkdir -p "$results"
status=0
run_suite() {
  local name="$1"
  shift
  if "$@" >"$results/$name.log" 2>&1; then
    echo "PASS $name"
  else
    local code=$?
    echo "FAIL $name (exit $code): $results/$name.log"
    tail -n 8 "$results/$name.log"
    status=1
  fi
}
cd "$repo_root/app" || exit 1
if command -v flutter >/dev/null 2>&1; then
  for suite in existing_behavior media_surface progression_contract first_gym_contract; do
    run_suite "$suite" flutter test --no-pub "../acceptance/free_launch/flutter/${suite}_test.dart"
  done
else
  echo 'FAIL: flutter is not available'; status=1
fi
cd "$repo_root" || exit 1
if [[ -x functions/.venv/bin/python ]]; then
  run_suite commission env PYTHONPATH="$repo_root/functions" functions/.venv/bin/python -m pytest acceptance/free_launch/python -q
else
  echo 'FAIL: create functions/.venv and install requirements plus pytest first'; status=1
fi
echo "Contract pack exit: $status (all failures remain release blockers for their feature)."
exit "$status"
