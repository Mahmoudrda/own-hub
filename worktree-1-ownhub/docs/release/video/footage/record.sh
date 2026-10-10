#!/bin/bash
#
# Re-record the launch-video take, and cut the ten clips out of it.
#
#   bash docs/release/video/footage/record.sh
#
# The walk itself is app/integration_test/demo_drive_test.dart. It is built as
# the app's own entry point and launched with simctl rather than run through
# `flutter test`: with a `flutter test` session attached, the app is force-quit
# part way through every take that is being screen-recorded.
#
# After a re-take the clip in/out points below are almost certainly wrong — the
# walk's own pacing shifts by a second or two between runs. Re-derive them from
# the driver's printed timeline (/tmp/demo_timeline.txt): each `DEMOMARK|<ms>|`
# is milliseconds from the app's first frame, and video seconds = ms/1000 plus
# the offset between the recorder starting and that first frame (5.39 s in the
# take this was written for). Then update timings.md.
set -eu

UDID=${UDID:-04852D18-AA25-4FD6-996E-488DECDACA1C}
ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
APP="$ROOT/app"
OUT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/development/flutter/bin:$PATH"

echo "==> building the walk as the app entry point"
cd "$APP"
flutter build ios --simulator --debug \
  --target=integration_test/demo_drive_test.dart \
  --dart-define=OWNHUB_LOCALE=en

echo "==> installing"
xcrun simctl terminate "$UDID" com.ownhub.app >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP/build/ios/iphonesimulator/Runner.app"
# A clean status bar: full bars, full battery, no carrier text.
#
# The time is overridden to NOW, not to Apple's 9:41, and this matters. The app
# draws its own clock — Home prints the hour she logged her meal — and
# `status_bar override` FREEZES the bar at whatever it is told, so a bar fixed
# at 9:41 above a meal row reading "4:53 PM" is one frame contradicting itself.
# Set to the current minute, the two clocks agree for the whole two-and-a-half
# minute take. (Clearing the override does not restart the bar's clock; only a
# reboot does.)
xcrun simctl status_bar "$UDID" override --time "$(date +%-I:%M)" --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
sleep 2

echo "==> recording"
rm -f "$OUT/demo.mov"
xcrun simctl io "$UDID" recordVideo --codec h264 "$OUT/demo.mov" > /tmp/rec.log 2>&1 &
RECPID=$!
sleep 3

xcrun simctl spawn "$UDID" log stream --predicate 'process == "Runner"' --style compact \
  > /tmp/runner_log.txt 2>&1 &
LOGPID=$!
sleep 1
xcrun simctl launch "$UDID" com.ownhub.app > /dev/null 2>&1

for _ in $(seq 1 900); do
  grep -q "done|end-of-walk" /tmp/runner_log.txt 2>/dev/null && break
  grep -q "nothing hit-testable" /tmp/runner_log.txt 2>/dev/null && break
  sleep 0.2
done
sleep 2

kill -INT "$RECPID"; sleep 5
kill "$LOGPID" 2>/dev/null || true
xcrun simctl terminate "$UDID" com.ownhub.app >/dev/null 2>&1 || true

sed -E 's/^.*\(Flutter\) flutter: //' /tmp/runner_log.txt \
  | grep -E "^DEMOMARK|^DEMODUMP" > /tmp/demo_timeline.txt
echo "==> walk timeline in /tmp/demo_timeline.txt"
tail -1 /tmp/demo_timeline.txt

echo "==> cutting clips (in/out points from the last take — check them)"
cut() { # name start duration
  ffmpeg -v error -y -ss "$2" -i "$OUT/demo.mov" -t "$3" \
    -an -vf "fps=30" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
    -movflags +faststart "$OUT/$1.mp4"
  echo "    $1.mp4"
}
cut 00-setup       17.28  8.44
cut 01-home        31.92  5.10
cut 02-session     39.12  5.10
cut 03-mid-set     46.52  5.60
cut 04-finish      54.10 12.30
cut 05-tabs        74.87  5.10
cut 06-eat         82.17  9.58
cut 07-cycle      109.12 13.89
cut 08-privacy    133.02  5.40
cut 09-home-again 140.12  6.80

echo "==> done. Clear the status bar override with:"
echo "    xcrun simctl status_bar $UDID clear"
