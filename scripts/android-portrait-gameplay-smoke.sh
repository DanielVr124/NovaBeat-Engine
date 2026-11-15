#!/usr/bin/env bash
set -euo pipefail

APK_PATH="${1:?Usage: $0 path/to/NovaBeat-Android.apk}"
PACKAGE_ID="me.funkin.fnf"
OUTPUT_DIR="artifacts/android-portrait-layout"
mkdir -p "$OUTPUT_DIR"

test -s "$APK_PATH"
adb wait-for-device
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell wm size 480x1040
adb shell wm density 160

adb install -r "$APK_PATH"
adb shell run-as "$PACKAGE_ID" sh -c 'mkdir -p files && : > files/novabeat-portrait-test'
adb logcat -c
adb shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1

wait_for_log_marker() {
  local marker="$1"
  for attempt in $(seq 1 120); do
    if adb logcat -d | grep -Fq "$marker"; then return 0; fi
    sleep 1
  done
  echo "Timed out waiting for marker: $marker" >&2
  adb logcat -d > "$OUTPUT_DIR/logcat-timeout.txt"
  exit 1
}

capture_screen() {
  local name="$1"
  adb exec-out screencap -p > "$OUTPUT_DIR/$name"
  test -s "$OUTPUT_DIR/$name"
}

wait_for_log_marker "NOVABEAT_LAYOUT_TEST: START_TUTORIAL"
wait_for_log_marker "NOVABEAT_LAYOUT_TEST: PLAYSTATE_CREATED"
sleep 8
capture_screen "portrait-gameplay-initial.png"

# Trigger both orientation transitions to test repeated viewport reflows.
adb shell settings put system user_rotation 1
sleep 4
adb shell settings put system user_rotation 0
sleep 5
capture_screen "portrait-gameplay-after-rotation.png"
sleep 4
capture_screen "portrait-gameplay-late.png"

adb logcat -d > "$OUTPUT_DIR/logcat.txt"

if grep -Eq 'NOVABEAT_LAYOUT_TEST: (LAYOUT_FAIL|NOTE_FAIL|TOUCH_MISSING)' "$OUTPUT_DIR/logcat.txt"; then
  echo "Portrait gameplay geometry assertions failed. See the uploaded diagnostic artifact." >&2
  exit 1
fi

layout_passes="$(grep -c 'NOVABEAT_LAYOUT_TEST: LAYOUT_PASS' "$OUTPUT_DIR/logcat.txt" || true)"
if [[ "$layout_passes" -lt 2 ]]; then
  echo "Expected two or more passing portrait reports; found $layout_passes." >&2
  exit 1
fi

note_reports="$(grep -c 'NOVABEAT_LAYOUT_TEST: NOTE lane=' "$OUTPUT_DIR/logcat.txt" || true)"
if [[ "$note_reports" -lt 4 ]]; then
  echo "Expected four or more live note/receptor center checks; found $note_reports." >&2
  exit 1
fi

python3 - "$OUTPUT_DIR" <<'PY'
import pathlib
import struct
import sys

root = pathlib.Path(sys.argv[1])
for name in (
    "portrait-gameplay-initial.png",
    "portrait-gameplay-after-rotation.png",
    "portrait-gameplay-late.png",
):
    path = root / name
    data = path.read_bytes()
    if len(data) < 8 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"Invalid PNG screenshot: {name}")
    width, height = struct.unpack(">II", data[16:24])
    if width >= height:
        raise SystemExit(f"Expected portrait screenshot, got {width}x{height}: {name}")
    if len(data) < 12000:
        raise SystemExit(f"Screenshot is unexpectedly small ({len(data)} bytes): {name}")
    print(f"Verified {name}: {width}x{height}, {len(data)} bytes")
PY

{
  echo "## Android portrait gameplay test passed"
  echo
  echo "- Installed and launched the same APK that will be published."
  echo "- Entered the real Tutorial PlayState."
  echo "- Checked all four receptor bounds, ordering, and centered placement."
  echo "- Checked each live touch target against its matching receptor."
  echo "- Checked runtime falling-note centers against their receptors."
  echo "- Forced landscape then portrait and repeated the geometry assertions."
  echo "- Captured three portrait gameplay screenshots and complete logcat."
} >> "$GITHUB_STEP_SUMMARY"
