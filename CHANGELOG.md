# Changelog

All notable changes to Default Tamer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2026-02-23

### Changed

- First-run setup state is now stored as a file sentinel in Application Support instead of UserDefaults, so it survives app updates and only resets on a full uninstall
- Diagnostics and routing feedback settings temporarily hidden from Preferences (coming soon)

### Fixed

- Migrates existing `hasCompletedFirstRun` UserDefaults flag to the new file-based sentinel on first launch after update

## [0.0.1] - 2026-02-22

### Added

- Initial release of Default Tamer
- Smart URL routing based on source app and URL/domain rules
- ⌥ Option key browser chooser override
- Configurable fallback browser
- Rule management UI with drag & drop reordering
- Optional activity logging (privacy-first, URLs sanitized before storage)
- Launch at login support
- First-run setup wizard
- Menu bar integration with popover interface

