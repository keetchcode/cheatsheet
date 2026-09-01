#!/bin/zsh
# Asserts the active Xcode exposes the SDK major version this branch ships against.
# Usage: Scripts/verify-build-sdk.sh [--warn]
#
# App Store submissions must be built with a released SDK. A machine that also
# carries an Xcode beta will silently build against the beta SDK, and the
# rejection only surfaces at upload time. Run this before archiving.
#
# The expected major is a branch-level contract: the iOS 26 line pins 26, and an
# iOS 27 adoption branch overrides it with CHEATSHEET_EXPECTED_SDK_MAJOR=27.

set -euo pipefail

expected_major="${CHEATSHEET_EXPECTED_SDK_MAJOR:-26}"

warn_only=0
if [[ "${1:-}" == "--warn" ]]; then
    warn_only=1
elif [[ -n "${1:-}" ]]; then
    print -u2 "error: unknown argument '${1}' (expected --warn or no argument)"
    exit 2
fi

if ! [[ "$expected_major" == <-> ]]; then
    print -u2 "error: CHEATSHEET_EXPECTED_SDK_MAJOR must be an integer, got '$expected_major'"
    exit 2
fi

developer_dir=$(xcode-select -p)
# Take the first line without a pipe: `| head -n 1` can SIGPIPE xcodebuild,
# and pipefail would turn that race into an intermittent exit 141.
xcode_version=$(xcodebuild -version 2>/dev/null || true)
xcode_version="${xcode_version%%$'\n'*}"
: "${xcode_version:=unknown (xcodebuild unavailable)}"

mismatches=()

for sdk in macosx iphoneos iphonesimulator; do
    if ! sdk_version=$(xcrun --sdk "$sdk" --show-sdk-version 2>/dev/null); then
        mismatches+=("$sdk: SDK not installed in $developer_dir")
        continue
    fi

    sdk_major="${sdk_version%%.*}"
    if [[ "$sdk_major" != "$expected_major" ]]; then
        mismatches+=("$sdk: found $sdk_version, expected ${expected_major}.x")
    fi
done

if (( ${#mismatches} == 0 )); then
    print "SDK check passed: ${xcode_version} exposes the expected ${expected_major}.x SDKs."
    exit 0
fi

label="error"
(( warn_only )) && label="warning"

print -u2 "${label}: active toolchain does not match the expected SDK major (${expected_major})."
print -u2 "  Xcode:         ${xcode_version}"
print -u2 "  DEVELOPER_DIR: ${developer_dir}"
for mismatch in "${mismatches[@]}"; do
    print -u2 "  - ${mismatch}"
done

if (( warn_only )); then
    print -u2 "Continuing anyway (--warn). Do not archive for submission from this toolchain."
    exit 0
fi

print -u2 ""
print -u2 "Select a matching Xcode before building for submission, for example:"
print -u2 "  sudo xcode-select -s /Applications/Xcode.app"
print -u2 "  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/verify-build-sdk.sh"
exit 1
