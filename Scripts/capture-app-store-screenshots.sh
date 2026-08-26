#!/bin/zsh
# Captures native-resolution App Store screenshots from the real iOS app.
#
# Usage: Scripts/capture-app-store-screenshots.sh [iphone-6.9|ipad-13] ...
#
# Each device class runs the AppStoreScreenshotUITests suite on a simulator
# whose native screen size already equals the pixel size App Store Connect
# requires, so nothing is ever scaled. Raw PNGs land in
# Docs/AppStoreScreenshots/raw/<device-class>/.
#
# Like Scripts/verify-macos.sh, the Xcode project is generated under /private/tmp:
# a checkout inside a File Provider-managed Documents folder can make xcodebuild
# block in NSFileCoordinator.

set -euo pipefail

repo_root=${0:A:h:h}
output_root="$repo_root/Docs/AppStoreScreenshots/raw"

typeset -A device_names
device_names=(
    iphone-6.9 "iPhone 17 Pro Max"
    ipad-13    "iPad Pro 13-inch (M5)"
)

device_classes=("$@")
if (( ${#device_classes} == 0 )); then
    device_classes=(iphone-6.9 ipad-13)
fi

run_with_timeout() {
    local timeout_seconds=$1
    shift

    "$@" &
    local command_pid=$!
    (
        sleep "$timeout_seconds"
        kill "$command_pid" >/dev/null 2>&1 || true
    ) &
    local watchdog_pid=$!

    wait "$command_pid" >/dev/null 2>&1
    local command_status=$?
    kill "$watchdog_pid" >/dev/null 2>&1 || true
    wait "$watchdog_pid" >/dev/null 2>&1 || true
    return "$command_status"
}

if ! command -v xcodegen >/dev/null 2>&1; then
    print -u2 "error: xcodegen is required (brew install xcodegen)"
    exit 1
fi

resolve_udid() {
    local name=$1
    xcrun simctl list devices available --json | DEVICE_NAME="$name" python3 -c '
import json, os, re, sys

wanted = os.environ["DEVICE_NAME"]


def version(runtime):
    match = re.search(r"iOS-([0-9]+)(?:-([0-9]+))?", runtime)
    return (int(match.group(1)), int(match.group(2) or 0)) if match else (0, 0)


devices = json.load(sys.stdin)["devices"]
candidates = [
    (version(runtime), device["udid"])
    for runtime, entries in devices.items()
    if "iOS" in runtime
    for device in entries
    if device.get("isAvailable") and device["name"] == wanted
]
print(max(candidates)[1] if candidates else "")
'
}

# A stable scratch root keeps rebuilds incremental instead of leaving a fresh
# multi-hundred-megabyte DerivedData tree behind on every run.
temp_root="${TMPDIR:-/private/tmp}/CheatSheetScreenshots"
project_root="$temp_root/Project"
rm -rf "$project_root"
mkdir -p "$project_root"

print "Generating a local project outside File Provider..."
xcodegen generate \
    --spec "$repo_root/project.yml" \
    --project "$project_root" \
    --project-root "$repo_root"

for directory in CheatSheetApp CheatSheetWidgets CheatSheetTests CheatSheetUITests Shared; do
    ln -s "$repo_root/$directory" "$project_root/$directory"
done

project="$project_root/CheatSheet.xcodeproj"

for device_class in "${device_classes[@]}"; do
    device_name=${device_names[$device_class]:-}
    if [[ -z "$device_name" ]]; then
        print -u2 "error: unknown device class '$device_class'"
        exit 1
    fi

    udid=$(resolve_udid "$device_name")
    if [[ -z "$udid" ]]; then
        print -u2 "error: no available simulator named '$device_name'"
        exit 1
    fi

    capture_dir="$output_root/$device_class"
    # Not cleared: the widget shot is produced by capture-widget-screenshot.sh
    # and lives in the same directory. Captures are overwritten by name.
    mkdir -p "$capture_dir"

    # The simulator sandbox may redirect absolute paths, so captures are written
    # to a scratch directory and copied out afterwards.
    staging_dir="$temp_root/$device_class"
    mkdir -p "$staging_dir"
    rm -f "$staging_dir"/*.png(N)
    chmod 777 "$staging_dir"

    print "Booting $device_name ($udid)..."
    run_with_timeout 30 xcrun simctl bootstatus "$udid" -b || xcrun simctl boot "$udid" || true
    run_with_timeout 30 xcrun simctl bootstatus "$udid" -b || true

    # Simulator accessibility settings persist across unrelated test runs.
    # Store captures use the standard content size and contrast so a previous
    # accessibility QA pass cannot silently crop otherwise valid screenshots.
    xcrun simctl ui "$udid" content_size large >/dev/null 2>&1 || true
    xcrun simctl ui "$udid" increase_contrast disabled >/dev/null 2>&1 || true

    # A clean, Apple-standard status bar across the whole set.
    run_with_timeout 10 xcrun simctl status_bar "$udid" override \
        --time "9:41" \
        --dataNetwork wifi \
        --wifiMode active \
        --wifiBars 3 \
        --cellularMode active \
        --cellularBars 4 \
        --batteryState charged \
        --batteryLevel 100 || true

    # Two passes. Most of the set uses the app's dark palette, which suits the
    # developer audience, but shipping one light shot shows the app adapts.
    for pass_spec in "dark:testCaptureAppStoreScreenshots" "light:testCaptureLightAppearance"; do
        appearance=${pass_spec%%:*}
        test_method=${pass_spec##*:}

        xcrun simctl ui "$udid" appearance "$appearance" >/dev/null 2>&1 || true

        result_bundle="$temp_root/$device_class-$appearance.xcresult"
        rm -rf "$result_bundle"

        print "Capturing $device_class ($appearance) on $device_name..."
        TEST_RUNNER_CHEATSHEET_SCREENSHOT_DIR="$staging_dir" \
        xcodebuild test \
            -project "$project" \
            -scheme CheatSheetiOSUI \
            -destination "id=$udid" \
            -derivedDataPath "$temp_root/DerivedData-$device_class" \
            -resultBundlePath "$result_bundle" \
            -only-testing:CheatSheetiOSUITests/AppStoreScreenshotUITests/$test_method \
            CODE_SIGNING_ALLOWED=NO \
            SDK_STAT_CACHE_ENABLE=NO \
            COMPILER_INDEX_STORE_ENABLE=NO
    done

    xcrun simctl ui "$udid" appearance dark >/dev/null 2>&1 || true

    staged_files=("$staging_dir"/*.png(N))
    if (( ${#staged_files} > 0 )); then
        cp "${staged_files[@]}" "$capture_dir/"
    else
        print "Direct write produced nothing; exporting attachments from the result bundle..."
        xcrun xcresulttool export attachments \
            --path "$result_bundle" \
            --output-path "$capture_dir" >/dev/null
    fi

    print "Wrote $(ls "$capture_dir" | wc -l | tr -d ' ') files to $capture_dir"
done

print "Raw captures are in $output_root"
