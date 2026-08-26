#!/bin/zsh
# Captures the CheatSheet widget on the iPhone Home Screen.
#
# The widget reads its note from the shared App Group, which only exists when
# the app is built with its entitlements — so unlike the in-app captures this
# build is signed (no CODE_SIGNING_ALLOWED=NO). A disposable simulator is
# created for every run so demo content can never replace real notes.

set -euo pipefail

repo_root=${0:A:h:h}
device_name=${1:-"iPhone 17 Pro Max"}
device_class=${2:-iphone-6.9}
bundle_id="com.wesleykeetch.wesleycheatsheet"
capture_dir="$repo_root/Docs/AppStoreScreenshots/raw/$device_class"

if ! command -v xcodegen >/dev/null 2>&1; then
    print -u2 "error: xcodegen is required (brew install xcodegen)"
    exit 1
fi

device_spec=$(xcrun simctl list devices available --json | DEVICE_NAME="$device_name" python3 -c '
import json, os, re, sys

wanted = os.environ["DEVICE_NAME"]


def version(runtime):
    match = re.search(r"iOS-([0-9]+)(?:-([0-9]+))?", runtime)
    return (int(match.group(1)), int(match.group(2) or 0)) if match else (0, 0)


devices = json.load(sys.stdin)["devices"]
candidates = [
    (version(runtime), runtime, device.get("deviceTypeIdentifier", ""))
    for runtime, entries in devices.items()
    if "iOS" in runtime
    for device in entries
    if device.get("isAvailable") and device["name"] == wanted
]
if candidates:
    _, runtime, device_type = max(candidates)
    print(f"{device_type}|{runtime}")
')

if [[ -z "$device_spec" ]]; then
    print -u2 "error: no available simulator named '$device_name'"
    exit 1
fi

device_type=${device_spec%%|*}
runtime=${device_spec#*|}
temporary_device_name="CheatSheet Widget Screenshot $$"
udid=$(xcrun simctl create "$temporary_device_name" "$device_type" "$runtime")

cleanup_simulator() {
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
}
trap cleanup_simulator EXIT INT TERM

# A stable scratch root keeps rebuilds incremental instead of leaving a fresh
# multi-hundred-megabyte DerivedData tree behind on every run.
temp_root="${TMPDIR:-/private/tmp}/CheatSheetWidgetShot"
project_root="$temp_root/Project"
staging_dir="$temp_root/captures"
rm -rf "$project_root" "$staging_dir"
mkdir -p "$project_root" "$staging_dir" "$capture_dir"
chmod 777 "$staging_dir"

print "Generating a local project outside File Provider..."
xcodegen generate \
    --spec "$repo_root/project.yml" \
    --project "$project_root" \
    --project-root "$repo_root"

for directory in CheatSheetApp CheatSheetWidgets CheatSheetTests CheatSheetUITests Shared; do
    ln -s "$repo_root/$directory" "$project_root/$directory"
done

project="$project_root/CheatSheet.xcodeproj"

print "Booting disposable $device_name simulator ($udid)..."
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || xcrun simctl boot "$udid" || true
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true

xcrun simctl ui "$udid" appearance dark >/dev/null 2>&1 || true
xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true

# Signed build: the App Group entitlement is what lets the widget read the note.
print "Building a signed simulator build..."
xcodebuild build-for-testing \
    -project "$project" \
    -scheme CheatSheetiOSUI \
    -destination "id=$udid" \
    -derivedDataPath "$temp_root/DerivedData" \
    SDK_STAT_CACHE_ENABLE=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    >/dev/null

app_path="$temp_root/DerivedData/Build/Products/Debug-iphonesimulator/CheatSheet.app"

print "Seeding the shared store with demo notes..."
xcrun simctl uninstall "$udid" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app_path"
xcrun simctl launch "$udid" "$bundle_id" \
    -cheatsheet-screenshot-mode -cheatsheet-demo-content -cheatsheet-skip-onboarding >/dev/null
sleep 5
xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true

print "Adding the widget to the Home Screen..."
TEST_RUNNER_CHEATSHEET_SCREENSHOT_DIR="$staging_dir" \
xcodebuild test-without-building \
    -project "$project" \
    -scheme CheatSheetiOSUI \
    -destination "id=$udid" \
    -derivedDataPath "$temp_root/DerivedData" \
    -only-testing:CheatSheetiOSUITests/WidgetScreenshotUITests \
    SDK_STAT_CACHE_ENABLE=NO \
    COMPILER_INDEX_STORE_ENABLE=NO

staged_files=("$staging_dir"/*.png(N))
if (( ${#staged_files} == 0 )); then
    print -u2 "error: no captures were written"
    exit 1
fi

cp "$staging_dir"/02-widget.png "$capture_dir/"
print "Wrote $capture_dir/02-widget.png"
print "Debug stages: $staging_dir"
