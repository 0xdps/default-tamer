# Changelog

All notable changes to Default Tamer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Optional, opt-in anonymous usage analytics via self-hosted Umami (`AnalyticsManager.swift`)
  - Events: `app_launch`, `app_updated`, `rule_created`, `first_rule_created`, `rule_deleted`, `link_routed`, `chooser_shown`, `routing_failed`
  - `routing_failed` fires in `BrowserManager.openURLWithFallback` with `reason: browser_unavailable` (target browser missing) or `reason: no_fallback` (both target and fallback failed); no browser names or bundle IDs included
  - Each event carries only aggregate/categorical data — no URLs, domains, source app names, or personal information
  - Anonymous `installID` (random UUID) attached to events for session deduplication; never linked to any identity
- `AppState.validateBrowserTargets()`: on launch, checks every enabled rule's `targetBrowserId` against installed browsers; auto-disables any rule whose browser is missing and persists the change via `PersistenceManager.saveRules`
- `RuleSidebarRow` now shows an orange `exclamationmark.triangle.fill` icon (with tooltip) next to any rule whose target browser is not installed, whether the rule is enabled or disabled
- Toast warning shown at startup (via `ToastManager.warning`) when one or more rules are auto-disabled due to a missing browser
- `ExternalLinks.privacy` constant pointing to `https://www.defaulttamer.app/privacy`
- Privacy Policy link in `FirstRunView` consent step (below the telemetry toggle)
- Privacy Policy link in Preferences → General → Diagnostics section (next to telemetry toggle)
- Privacy Policy link in Preferences → About tab links row
- Privacy Policy link as `NSTextField` accessory view in `checkAndPromptTelemetryConsent()` `NSAlert` (existing-user Day 0 consent prompt)
- `/privacy` page on the website with full transparency disclosure: all tracked events listed with exact fields, never-collected list, anonymous install ID explanation, opt-out steps, and website analytics disclosure
- `Privacy Policy` link added to website footer Resources column
- `/privacy/` added to `sitemap.xml.ts`

### Changed

- Telemetry consent text in `FirstRunView` and `PreferencesWindow` updated: replaced generic "Helps us" bullets with context explaining the solo/open-source nature of the project and specific actionable signals (rule type usage, routing failure rate, macOS version spread)
- JSON-LD `featureList` and FAQ structured data on homepage updated to match new privacy posture
- Homepage hero stat "0 / Network Calls" replaced with "Opt-in / Analytics"

## [0.0.6] - 2026-03-12

### Added

- Browser list refresh controls in Add Rule, Edit Rule, First Run, and Preferences so newly installed browsers can be selected without restarting the app
- Startup browser discovery refresh to keep available browser lists up to date on launch

### Changed

- Release pipeline and app version metadata now consistently use dynamic version/build values from project settings

## [0.0.5] - 2026-02-27

### Added

- Dedicated `/release-notes` page serving only the current version's changelog as lightweight HTML — Sparkle update dialog no longer loads the full website
- Sparkle EdDSA signing step in `release.sh` (local builds) — signs the DMG and prints the `edSignature` + `size` for `release.json`
- `SPARKLE_PRIVATE_KEY` GitHub Actions secret for CI Sparkle signing

### Fixed

- Sparkle updates failed after download because `edSignature` in `release.json` was `"PLACEHOLDER"` — CI now signs the DMG with `sign_update` using the EdDSA private key
- CI `sign_update` discovery used incorrect search paths that missed the SPM artifacts directory; now searches `build/DerivedData/SourcePackages/artifacts/` first
- Appcast `releaseNotesLink` pointed to `/changelog` (full website); now points to `/release-notes` (clean, minimal page)

## [0.0.4] - 2026-02-27

### Added

- `ExternalLinks` constants struct centralising GitHub, Issues, Buy Me a Coffee, website, and developer website URLs (`Constants.swift`)
- "Buy Me a Coffee" link in the About tab alongside GitHub and Report an Issue links
- Developer credit ("Made by 0xdps") with links to `dps.codes` and `defaulttamer.app` in the About tab
- Activity Log toggle in Preferences → General → Diagnostics (previously hidden as "coming soon")
- App icon hover effect in `MenuHeaderView` — spring scale animation with accent color glow
- Hover highlight on the routing toggle row in `MenuHeaderView`
- "Buy Me a Coffee" link in website footer Community column
- Buy Me a Coffee CTA banner on the website Download page ("What's Next" section)
- Buy Me a Coffee floating widget (BMC-Widget) in `BaseLayout.astro` with Umami analytics tracking

### Changed

- Replaced `Toggle` + custom `ActiveSwitchStyle` in `MenuHeaderView` with a direct Capsule-based toggle view (36×20 with 16px knob) to fix vertical alignment issues inside NSMenu-hosted SwiftUI views
- Routing toggle row in `MenuHeaderView` is now full-width with edge-to-edge hover highlight
- About tab links (GitHub, Report an Issue) now use `ExternalLinks` constants instead of hardcoded strings
- `Info.plist` version strings now use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` build settings instead of hardcoded values

### Removed

- `showRoutingFeedback` property from `Settings` model — routing toast notifications were never visible to users because they only rendered inside the popover/preferences window, which is closed when URLs are routed
- `toggleRoutingFeedback()` method from `AppState`
- All toast notification calls from `executeRouteAction()` and `openURLFromChooser()` in `AppState`
- `ActiveSwitchStyle` custom `ToggleStyle` from `MenuHeaderView`

### Fixed

- Deploy script (`quick-deploy.sh`) now preserves sandbox entitlements during ad-hoc re-signing — previously `codesign --force --deep --sign -` stripped entitlements, causing the app to read UserDefaults from the wrong location and lose all rules

## [0.0.3] - 2026-02-25

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

