#!/bin/zsh
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

script_path="${0:A}"
script_dir="${script_path:h}"
repo_root="${CHEATSHEET_REPO_ROOT:-${script_dir:h}}"
project_file="${repo_root}/project.yml"

if [[ ! -f "$project_file" ]]; then
  echo "error: project.yml not found at $project_file" >&2
  exit 1
fi

ruby - "$project_file" <<'RUBY'
path = ARGV.fetch(0)
content = File.read(path)
matches = content.scan(/^([ \t]*)CURRENT_PROJECT_VERSION:[ \t]*"?([0-9]+)"?[ \t]*$/)

if matches.length != 1
  abort "error: expected exactly one numeric CURRENT_PROJECT_VERSION in #{path}, found #{matches.length}"
end

current = matches.first[1].to_i
next_build = current + 1
updated = content.sub(/^([ \t]*)CURRENT_PROJECT_VERSION:[ \t]*"?[0-9]+"?[ \t]*$/) do
  "#{$1}CURRENT_PROJECT_VERSION: \"#{next_build}\""
end

File.write(path, updated)
puts "CheatSheet build number: #{current} -> #{next_build}"
RUBY

if [[ "${CHEATSHEET_SKIP_XCODEGEN:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required to refresh CheatSheet.xcodeproj after bumping the build number" >&2
  exit 1
fi

xcodegen generate --spec "$project_file" --project "$repo_root" --project-root "$repo_root" --quiet
