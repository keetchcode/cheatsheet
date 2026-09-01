#!/bin/zsh
set -euo pipefail

repo_root="${CHEATSHEET_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$repo_root"

for file in \
  CheatSheetApp/Info.plist \
  CheatSheetApp/iOSInfo.plist \
  CheatSheetWidgets/Info.plist \
  CheatSheetApp/CheatSheet.entitlements \
  CheatSheetApp/CheatSheet-iOS.entitlements \
  CheatSheetWidgets/CheatSheetWidgets.entitlements \
  CheatSheetWidgets/CheatSheetWidgets-iOS.entitlements
do
  plutil -lint "$file" >/dev/null
done

ruby <<'RUBY'
project = File.read("project.yml")
source = File.read("Shared/Sources/CheatSheetNote.swift")
entitlement_paths = [
  "CheatSheetApp/CheatSheet.entitlements",
  "CheatSheetApp/CheatSheet-iOS.entitlements",
  "CheatSheetWidgets/CheatSheetWidgets.entitlements",
  "CheatSheetWidgets/CheatSheetWidgets-iOS.entitlements"
]
entitlements = entitlement_paths.to_h { |path| [path, File.read(path)] }

abort "archive preActions must not mutate project.yml" if project.include?("preActions:")

hardened_runtime_count = project.scan(/ENABLE_HARDENED_RUNTIME:\s*YES/).length
abort "expected Hardened Runtime on macOS app and widget Release settings" unless hardened_runtime_count >= 2

# The shipping floor is a contract. Nothing else in the build asserts it: the
# SDK check only sees the toolchain, and the simulator resolver only sees
# runtimes, so a silent regression to an older deployment target would pass
# every other gate.
minimum_floor = Gem::Version.new("26.0")
{ "iOS" => /^\s*iOS:\s*"([0-9.]+)"/, "macOS" => /^\s*macOS:\s*"([0-9.]+)"/ }.each do |platform, pattern|
  match = project.match(pattern)
  abort "project.yml must declare a #{platform} deployment target" if match.nil?
  actual = Gem::Version.new(match[1])
  if actual < minimum_floor
    abort "#{platform} deployment target #{actual} is below the supported floor #{minimum_floor}"
  end
end

# options.deploymentTarget.macOS is the single source of truth. A second
# MACOSX_DEPLOYMENT_TARGET in settings.base silently overrides it.
if project.include?("MACOSX_DEPLOYMENT_TARGET")
  abort "remove MACOSX_DEPLOYMENT_TARGET from settings.base; options.deploymentTarget.macOS owns the macOS floor"
end

ios_group = "group.com.wesleykeetch.wesleycheatsheet"
mac_group = "HD39MR492X.com.wesleykeetch.wesleycheatsheet"

abort "iOS App Group missing from shared source" unless source.include?(ios_group)
abort "macOS App Group missing from shared source" unless source.include?(mac_group)
abort "iOS App Group missing from project.yml" unless project.include?(ios_group)
abort "macOS App Group missing from project.yml" unless project.include?(mac_group)

entitlements.each do |path, content|
  expected = path.include?("-iOS") ? ios_group : mac_group
  abort "#{path} does not contain expected App Group #{expected}" unless content.include?(expected)
end

# The app and widget share notes through UserDefaults(suiteName:) on an App
# Group, which requires the 1C8F.1 reason in addition to app-local CA92.1.
[
  "CheatSheetApp/Resources/PrivacyInfo.xcprivacy",
  "CheatSheetWidgets/Resources/PrivacyInfo.xcprivacy"
].each do |path|
  manifest = File.read(path)
  abort "#{path} must declare UserDefaults reason CA92.1" unless manifest.include?("CA92.1")
  abort "#{path} must declare App Group UserDefaults reason 1C8F.1" unless manifest.include?("1C8F.1")
end
RUBY

echo "Project configuration verified."
