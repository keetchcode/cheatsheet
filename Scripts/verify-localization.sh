#!/bin/zsh
set -euo pipefail

repo_root="${CHEATSHEET_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$repo_root"

ruby <<'RUBY'
require "json"

CATALOGS = {
  "CheatSheetApp/Resources/Localizable.xcstrings" => %w[
    CheatSheetApp/Sources/NoteStore.swift
    CheatSheetApp/Sources/PersistenceStatusBanner.swift
    CheatSheetApp/Sources/MenuBarQuickAccessView.swift
    CheatSheetApp/Sources/ChecklistLineView.swift
    Shared/Sources/CheatSheetNote.swift
    Shared/Sources/DisplayLine.swift
    Shared/Sources/CheatSheetNote+Trash.swift
    Shared/Sources/CheatSheetNoteRepository.swift
  ],
  "CheatSheetWidgets/Resources/Localizable.xcstrings" => %w[
    CheatSheetWidgets/Sources/CheatSheetWidgetView.swift
    CheatSheetWidgets/Sources/WidgetLineView.swift
  ]
}.freeze

LANGUAGES = %w[en es].freeze
PLACEHOLDER_PATTERN = /%(?:\d+\$)?[@dlfsu]+/.freeze
STABLE_KEY_CALL_PATTERN = /String\(\s*localized:\s*"([a-zA-Z0-9.]+)",\s*defaultValue:/m.freeze

errors = []

CATALOGS.each do |catalog_path, source_files|
  catalog = JSON.parse(File.read(catalog_path))

  errors << "#{catalog_path}: sourceLanguage must be 'en'" unless catalog["sourceLanguage"] == "en"

  strings = catalog["strings"] || {}
  errors << "#{catalog_path}: has no strings" if strings.empty?

  strings.each do |key, entry|
    localizations = entry["localizations"] || {}
    values = {}

    LANGUAGES.each do |language|
      value = localizations.dig(language, "stringUnit", "value")
      if value.nil? || value.empty?
        errors << "#{catalog_path}: '#{key}' is missing a non-empty '#{language}' translation"
      else
        values[language] = value
      end
    end

    next unless values["en"] && values["es"]

    if key.include?(".") && values["es"] == key
      errors << "#{catalog_path}: '#{key}' was not translated -- the Spanish value equals the raw key"
    end

    en_placeholders = values["en"].scan(PLACEHOLDER_PATTERN).sort
    es_placeholders = values["es"].scan(PLACEHOLDER_PATTERN).sort
    if en_placeholders != es_placeholders
      errors << "#{catalog_path}: '#{key}' has mismatched format specifiers " \
                 "(en: #{en_placeholders.inspect}, es: #{es_placeholders.inspect})"
    end
  end

  source_files.each do |source_file|
    source = File.read(source_file)
    source.scan(STABLE_KEY_CALL_PATTERN).each do |(key)|
      unless strings.key?(key)
        errors << "#{source_file} references key '#{key}' which is missing from #{catalog_path}"
      end
    end
  end
end

unless errors.empty?
  warn "Localization verification failed:"
  errors.each { |message| warn "  - #{message}" }
  abort
end
RUBY

echo "Localization verified."
