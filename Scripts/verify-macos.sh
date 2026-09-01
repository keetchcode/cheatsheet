#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
temp_root=$(mktemp -d "${TMPDIR:-/private/tmp}/CheatSheetVerification.XXXXXX")
project_root="$temp_root/Project"

mkdir -p "$project_root"

if ! command -v xcodegen >/dev/null 2>&1; then
    print -u2 "error: xcodegen is required (brew install xcodegen)"
    exit 1
fi

# Local machines may carry an Xcode beta. Warn rather than fail: beta-SDK
# builds are fine for development, but must never be archived for submission.
"$repo_root/Scripts/verify-build-sdk.sh" --warn

print "Generating a local project outside File Provider..."
xcodegen generate \
    --spec "$repo_root/project.yml" \
    --project "$project_root" \
    --project-root "$repo_root"

# XcodeGen keeps plist and entitlement paths relative to the generated project.
for directory in CheatSheetApp CheatSheetWidgets CheatSheetTests Shared; do
    ln -s "$repo_root/$directory" "$project_root/$directory"
done

project="$project_root/CheatSheet.xcodeproj"
common_settings=(
    CODE_SIGNING_ALLOWED=NO
    SDK_STAT_CACHE_ENABLE=NO
    COMPILER_INDEX_STORE_ENABLE=NO
)

print "Running arm64 tests..."
xcodebuild \
    -project "$project" \
    -scheme CheatSheet \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$temp_root/DerivedData-arm64" \
    -parallel-testing-enabled NO \
    "${common_settings[@]}" \
    test

print "Running x86_64 tests..."
xcodebuild \
    -project "$project" \
    -scheme CheatSheet \
    -destination 'platform=macOS,arch=x86_64' \
    -derivedDataPath "$temp_root/DerivedData-x86_64" \
    -parallel-testing-enabled NO \
    "${common_settings[@]}" \
    test

print "Building universal Release app..."
xcodebuild \
    -project "$project" \
    -scheme CheatSheetApp \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$temp_root/DerivedData-release" \
    "${common_settings[@]}" \
    'ARCHS=arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    build

binary="$temp_root/DerivedData-release/Build/Products/Release/wesleycheatsheet.app/Contents/MacOS/wesleycheatsheet"
lipo -info "$binary"

print "Verification succeeded. Artifacts: $temp_root"
