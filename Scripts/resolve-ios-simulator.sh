#!/bin/zsh
# Prints the UDID of the newest available iPhone or iPad simulator.
# Usage: Scripts/resolve-ios-simulator.sh [iphone|ipad]
#
# A bare `-destination 'platform=iOS Simulator,name=iPhone 16'` resolves to
# OS:latest. When the installed runtime is newer than that device (for example
# iOS 26, which ships the iPhone 17 family), xcodebuild matches nothing and the
# build fails. Resolving a concrete UDID keeps CI and local runs working across
# Xcode upgrades.

set -euo pipefail

device_family=${1:-iphone}
case "$device_family" in
    iphone) device_prefix="iPhone" ;;
    ipad) device_prefix="iPad" ;;
    *)
        print -u2 "error: device family must be 'iphone' or 'ipad'"
        exit 2
        ;;
esac

udid=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys


def version(runtime):
    match = re.search(r"iOS-([0-9]+)(?:-([0-9]+))?", runtime)
    return (int(match.group(1)), int(match.group(2) or 0)) if match else (0, 0)


prefix = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
candidates = [
    (version(runtime), device["udid"])
    for runtime, entries in devices.items()
    if "iOS" in runtime
    for device in entries
    if device.get("isAvailable") and device["name"].startswith(prefix)
]
print(max(candidates)[1] if candidates else "")
' "$device_prefix")

if [[ -z "$udid" ]]; then
    print -u2 "error: no available $device_prefix simulator found"
    exit 1
fi

print "$udid"
