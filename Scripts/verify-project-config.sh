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
RUBY

echo "Project configuration verified."
