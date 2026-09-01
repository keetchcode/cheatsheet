#!/bin/zsh
# Prints the UDID of the newest available iPhone or iPad simulator that meets a
# minimum iOS runtime.
# Usage: Scripts/resolve-ios-simulator.sh [iphone|ipad]
#
# A bare `-destination 'platform=iOS Simulator,name=iPhone 16'` resolves to
# OS:latest. When the installed runtime is newer than that device, xcodebuild
# matches nothing and the build fails. Resolving a concrete UDID keeps CI and
# local runs working across Xcode upgrades.
#
# The floor matters as much as the pick: without it, the newest *available*
# runtime may still be older than the app supports, and the whole suite runs
# green against a configuration nobody ships. Below the floor we fail loudly
# rather than substituting an older runtime.
#
# There is a ceiling too. simctl keeps listing a beta OS runtime as available
# after you switch back to the release Xcode, and "newest wins" would then send
# every shipping test run onto the beta OS. Runtimes from a newer major than the
# active SDK are excluded, so the toolchain sets the ceiling and an iOS 27
# branch needs no special case.

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

min_runtime="${CHEATSHEET_MIN_IOS_RUNTIME:-26.5}"

if ! sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null); then
    print -u2 "error: no iOS simulator SDK in $(xcode-select -p)"
    exit 2
fi
sdk_major="${sdk_version%%.*}"

udid=$(xcrun simctl list devices available --json | python3 -c '
import json, re, sys


def version(runtime):
    match = re.search(r"iOS-([0-9]+)(?:-([0-9]+))?", runtime)
    return (int(match.group(1)), int(match.group(2) or 0)) if match else (0, 0)


def family(device, prefix):
    # Match on deviceTypeIdentifier, not the display name: a simulator can be
    # renamed to anything ("QA-Standard-17") and still be an iPhone.
    identifier = device.get("deviceTypeIdentifier", "")
    marker = "SimDeviceType."
    if marker in identifier:
        return identifier.split(marker, 1)[1].startswith(prefix)
    return device["name"].startswith(prefix)


prefix, raw_floor, sdk_major = sys.argv[1], sys.argv[2], int(sys.argv[3])

parts = raw_floor.split(".")
if not (1 <= len(parts) <= 2) or not all(p.isdigit() for p in parts):
    sys.stderr.write(
        "error: CHEATSHEET_MIN_IOS_RUNTIME must look like 26 or 26.5, got %r\n" % raw_floor
    )
    raise SystemExit(2)
floor = (int(parts[0]), int(parts[1]) if len(parts) > 1 else 0)

devices = json.load(sys.stdin)["devices"]
runtimes = {r: e for r, e in devices.items() if "iOS-" in r}

# Rank: newest runtime, then prefer a stock-named device over a renamed one,
# then by name so the pick is reproducible. Renamed simulators are typically
# scratch devices and are likelier to be stale or mid-teardown.
candidates = [
    (version(runtime), device["name"].startswith(prefix), device["name"], device["udid"])
    for runtime, entries in runtimes.items()
    for device in entries
    if device.get("isAvailable")
    and family(device, prefix)
    and version(runtime) >= floor
    and version(runtime)[0] <= sdk_major
]

if candidates:
    print(max(candidates)[3])
    raise SystemExit(0)

lines = [
    "error: no %s simulator available on iOS %s or newer" % (prefix, raw_floor),
    "  required: iOS >= %s (override with CHEATSHEET_MIN_IOS_RUNTIME)" % raw_floor,
    "  ceiling:  iOS major <= %d (the active simulator SDK)" % sdk_major,
    "  found, by runtime:",
]
if runtimes:
    for runtime in sorted(runtimes, key=version, reverse=True):
        matching = [d for d in runtimes[runtime] if d.get("isAvailable") and family(d, prefix)]
        major, minor = version(runtime)
        if major > sdk_major:
            note = "   (newer than the active SDK)"
        elif (major, minor) < floor:
            note = "   (below floor)"
        else:
            note = ""
        lines.append("    iOS %d.%d  %d %s%s" % (major, minor, len(matching), prefix, note))
else:
    lines.append("    (no iOS runtimes installed)")
lines.append("  fix: install a runtime via Xcode > Settings > Components, then create a device:")
lines.append("       xcrun simctl create <name> <device-type-id> <runtime-id>")
sys.stderr.write("\n".join(lines) + "\n")
raise SystemExit(1)
' "$device_prefix" "$min_runtime" "$sdk_major")

print "$udid"
