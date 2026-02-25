# Changelog

All notable changes to Default Tamer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Replaced custom GitHub-based update checker with [Sparkle](https://sparkle-project.org/) (`SPUStandardUpdaterController`) — automatic background update checks, delta updates, and native macOS update UI are now handled by the Sparkle framework
- Update preferences in the About tab now use Sparkle's `CheckForUpdatesViewModel` instead of a custom alert flow
- Release data (`release.json`) now includes `edSignature` and `size` fields required for Sparkle appcast signature verification
- Font loading in the website simplified to a standard blocking `<link>` (removed non-critical CSS lazy-load pattern)
- JSON-LD structured data script tag fixed to use `is:inline` to prevent Astro from processing it
- Split developer documentation out of `README.md` into `DEVELOPER.md`

### Added

- Sparkle appcast endpoint (`/appcast.xml`) served from the website for `SPUUpdater` to consume
- "Danger Zone" section in Preferences → General with a factory-reset button (`AppState.resetToDefaults()`) that clears all rules, settings, and first-run state

### Removed

- Custom `UpdateManager` implementation (GitHub Releases API polling, rate limiting, manual version comparison, `AvailableUpdate` / `UpdateError` models)
- `UpdateNotificationView` — superseded by Sparkle's native update UI
- `release.ts` data module replaced by `release.json`
- Removed inaccurate claim in README that default rules (Slack → Chrome, Cursor → Chrome) are created on first launch — no default rules have ever been created by the app

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
- `⌥` Option key browser chooser override
- Configurable fallback browser
- Rule management UI with drag & drop reordering
- Optional activity logging (privacy-first, URLs sanitized before storage)
- Launch at login support
- First-run setup wizard
- Menu bar integration with popover interface

