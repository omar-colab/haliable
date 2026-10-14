#!/usr/bin/env bash
# Run the live demo-barcode probe (HaliableTests/DemoBarcodeProbeTests) and print
# its report. The probe hits the network, so it is skipped in the normal suite;
# this is the supported way to run it on purpose.
#
#   ./scripts/run-demo-probe.sh
#
# The flag is set in the app's UserDefaults (xcodebuild cannot set an environment
# variable on a unit-test host) and is ALWAYS cleared on exit — leave it set and
# the probe starts running inside the normal 135-test suite.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."

# The UDID is the parenthesised field before the state, e.g.
#   iPhone 17 Pro (550D61A2-…-97273134C979) (Shutdown)
DEVICE="${1:-$(xcrun simctl list devices available \
  | sed -n 's/^ *iPhone 17 Pro (\([0-9A-F-]\{36\}\)).*/\1/p' | head -1)}"
[ -n "$DEVICE" ] || { echo "No iPhone 17 Pro simulator found. Pass a device UDID as \$1."; exit 1; }

xcrun simctl bootstatus "$DEVICE" -b >/dev/null
# The flag is a timestamp and the test only honours it for ten minutes, so there is
# nothing to clean up — which matters, because the runner leaves the simulator shut
# down and a cleanup step here cannot always reach it.
xcrun simctl spawn "$DEVICE" defaults write app.haliable.ios HALIABLE_DEMO_PROBE -int "$(date +%s)"

LOG=$(mktemp -t haliable-probe)
echo "Running the probe (needs network; ~1 min)…"
xcodebuild test -scheme Haliable \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -derivedDataPath build/dd \
  -only-testing:HaliableTests/DemoBarcodeProbeTests \
  CODE_SIGNING_ALLOWED=NO > "$LOG" 2>&1 || { tail -40 "$LOG"; exit 1; }

# xcodebuild buffers test stdout into the .xcresult, not the build log.
RESULT=$(ls -dt build/dd/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool get log --path "$RESULT" --type action 2>/dev/null | python3 -c '
import json, sys

def walk(node):
    if isinstance(node, dict):
        out = node.get("emittedOutput")
        if isinstance(out, str) and "DEMO BARCODE PROBE" in out:
            yield out
        for child in node.values():
            yield from walk(child)
    elif isinstance(node, list):
        for child in node:
            yield from walk(child)

found = sorted(set(walk(json.load(sys.stdin))), key=len)
print(found[-1] if found else "No probe output in the result bundle — did the test skip?")
'
