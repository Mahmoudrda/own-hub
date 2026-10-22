#!/usr/bin/env bash
# Private coaching, end to end, on the local Firebase emulators only.
#
#   app/tool/e2e_coaching.sh run     boot the emulators, seed, run the server
#                                    journey (functions/tools/e2e_coaching.py),
#                                    print PASS/FAIL per step, shut down
#   app/tool/e2e_coaching.sh start   boot the emulators and keep them up
#                                    (auth 9299, firestore 8288, functions 5101,
#                                    storage 9399), for the app or the runner
#   app/tool/e2e_coaching.sh seed    create the five phone accounts
#   app/tool/e2e_coaching.sh codes   latest SMS code per phone (emulator)
#   app/tool/e2e_coaching.sh dump    like run, and also write every coaching
#                                    document to app/test/fixtures/coaching_server_docs.json
#                                    (E2E_DUMP=1 does the same with run or journey)
#   app/tool/e2e_coaching.sh journey run the journey against emulators already up
#
# The app, debug build only, against the emulators (Android emulator shown;
# 10.0.2.2 is the host machine):
#   cd app && flutter run --dart-define=OWNHUB_EMULATOR_HOST=10.0.2.2
# Sign in with a seeded phone (+201000000001 reviewer, 02 admin, 03 coach,
# 04 client, 05 stranger); the SMS code is in the emulator log or `codes`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="${E2E_CONFIG:-$ROOT/firebase.e2e.json}"
PY="$ROOT/functions/.venv/bin/python"
ONLY="auth,firestore,storage,functions"
# The Firestore emulator needs a real Java; /usr/bin/java is only a stub here.
if ! java -version >/dev/null 2>&1; then
  for jdk in /opt/homebrew/opt/openjdk@21 /opt/homebrew/opt/openjdk@17; do
    [ -x "$jdk/bin/java" ] && export PATH="$jdk/bin:$PATH" && break
  done
fi
# No real Google credentials: anything the emulators do not cover must fail
# rather than reach production (push, Secret Manager, Vertex). The Admin SDK
# still wants some credential to build a Storage client, so it gets a throwaway
# service-account file (a fresh key, trusted by nobody) whose token endpoint is a local server that hands out a
# dummy token (functions/tools/e2e_fake_token.py).
TOKEN_PORT=9599
WORK="$(mktemp -d)"
export CLOUDSDK_CONFIG="$WORK/gcloud"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$WORK/key.pem" 2>/dev/null
"$PY" - "$WORK" "$TOKEN_PORT" <<'PYJSON'
import json, sys
work, port = sys.argv[1], sys.argv[2]
json.dump({
    "type": "service_account", "project_id": "own-hub", "private_key_id": "e2e",
    "private_key": open(f"{work}/key.pem").read(),
    "client_email": "e2e@own-hub.iam.gserviceaccount.com", "client_id": "1",
    "token_uri": f"http://127.0.0.1:{port}/token",
}, open(f"{work}/adc.json", "w"))
PYJSON
export GOOGLE_APPLICATION_CREDENTIALS="$WORK/adc.json"
(cd "$ROOT/functions" && exec "$PY" -m tools.e2e_fake_token "$TOKEN_PORT") &
TOKEN_PID=$!
trap 'kill $TOKEN_PID 2>/dev/null || true; rm -rf "$WORK"' EXIT
# macOS: the Functions emulator forks workers, and Objective-C libraries
# loaded by OpenCV abort the fork unless this is set.
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
# requests asks macOS for proxy settings after the fork, which also aborts.
export NO_PROXY='*' no_proxy='*'
# OpenCV's thread pool crashes (SIGSEGV in cv::resize) inside the forked worker.
export OPENCV_FOR_THREADS_NUM=1 OMP_NUM_THREADS=1
FB=(firebase --config "$CONFIG" --project own-hub)

py() { (cd "$ROOT/functions" && "$PY" -m "$@"); }

DUMP_ARGS=""
FIXTURE="$ROOT/app/test/fixtures/coaching_server_docs.json"
if [ "${1:-}" = dump ] || [ -n "${E2E_DUMP:-}" ]; then DUMP_ARGS="--dump '$FIXTURE'"; fi
[ "${1:-}" = dump ] && set -- run

case "${1:-run}" in
  run)
    cd "$(dirname "$CONFIG")"
    "${FB[@]}" emulators:exec --only "$ONLY" \
      "cd '$ROOT/functions' && '$PY' -m tools.e2e_coaching $DUMP_ARGS"
    ;;
  start)
    cd "$(dirname "$CONFIG")"
    "${FB[@]}" emulators:start --only "$ONLY"
    ;;
  seed) py tools.e2e_seed ;;
  codes) py tools.e2e_seed codes ;;
  journey) py tools.e2e_coaching ${DUMP_ARGS:+--dump "$FIXTURE"} ;;
  *) sed -n 2,20p "$0"; exit 2 ;;
esac
