# Changelog

All notable changes to Default Tamer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.7] - 2026-03-19

### Fixed

- `AppState.toggleDiagnostics()` now calls `diagnosticsManager.clearLogs()` and `ActivityDatabase.shared.deleteAllLogs()` when the Activity Log is disabled; previously existing route history was silently retained in both the SQLite database and in-memory `recentRoutes` array with no way for the user to clear it
- `BrowserManager` completely rewrote browser discovery: replaced keyword/category heuristics with a `allowedParents` standard-location allowlist (`/Applications`, `~/Applications`, system dirs) eliminating helper bundles, Xcode DerivedData builds, Puppeteer caches, DMG-mounted apps, and other noise; added `nonBrowserBundleIds` exclusion set for apps (iTerm2, Choosy, Finicky, etc.) that register for `http://` without being browsers; `displayNameFromURL` now reads `CFBundleDisplayName`/`CFBundleName` directly from the bundle instead of calling `NSWorkspace.shared.displayName` off the main actor; added 5-second `Task`-based timeout around `LSCopyApplicationURLsForURL` to prevent permanently stuck spinner
- `AppState` now pipes `browserManager.objectWillChange` and `diagnosticsManager.objectWillChange` into its own `objectWillChange` via Combine sinks stored in a `cancellables` set; previously `browserManager` was a plain `let` so any `@Published` change on it (available browsers, refresh spinner state) never triggered re-renders on views observing `appState` as `@EnvironmentObject`
- Analytics events now include `browser: "DefaultTamer"` in the Umami payload so the dashboard no longer shows "unknown" in the browser column

### Added

- `just dmg-preview` recipe: builds a debug `.app` and packages it as `dist/preview.dmg` without signing or notarization, for rapid local iteration on the installer window appearance
- `create-dmg.sh` background image support: accepts `private/assets/dmg-background.svg` (auto-converted to PNG via `rsvg-convert`) or a static `dmg-background.png` fallback; background is placed in the hidden `.background/` folder and applied to the Finder window via AppleScript
- `private/assets/dmg-background.svg`: placeholder DMG installer background (dark `#0f172a`→`#1e293b` gradient, brand orange/green glow blobs, vertical app→Applications install flow with dashed arrow)

- Removed broken `rulesQueue` DispatchQueue barrier pattern in `AppState`; all rule mutations are now direct `@MainActor` calls, eliminating the false sense of thread-safety
- Added `Thread.isMainThread` guard in `AppResolver.findBundleIdUsingSpotlight` to prevent semaphore deadlock when called from the main thread
- `DatabaseConstants.currentVersion` corrected from `1` to `2`; the v1→v2 migration was previously unreachable due to the mismatch
- `NSRegularExpression` objects in `Router` are now cached by pattern string to avoid recompilation on every URL routing decision
- `AnalyticsManager.sendEvent` now reads `telemetryEnabled` from the in-memory `AppState` (fast path); disk fallback only when `AppDelegate` is unavailable
- `SourceAppDetector` returns early when Apple Event detection yields ≥ 90% confidence, skipping all subsequent detection stages
- `Settings.chooserModifierKey` is now wired through to `Router` via a new `chooserModifierFlags` computed property; previously the modifier was hardcoded to `.option` regardless of the user's setting
- All cache-miss paths in `BrowserManager.loadCachedBrowsers()` now dispatch `Task.detached { await refreshBrowsersInBackground() }` instead of the synchronous `discoverBrowsers()`, preventing main-thread blocking at app init
- Removed `defaults.synchronize()` calls from `PersistenceManager`; the method is deprecated and was causing spurious error throws
- `AppState.pendingTabSelection` type changed from `Int?` to `PreferenceTab?`; eliminates silent breakage if tab order changes
- Removed overly-broad alternation-with-quantifier pattern from `RegexValidator.dangerousPatterns`; it was falsely rejecting valid patterns such as `(https?|http)+`
- `ApplicationScanner` now observes `NSWorkspace.didLaunchApplicationNotification` and invalidates `cachedApps` when a newly-launched app is not already in the cache, preventing stale app lists after installs
- `AnalyticsManager.writeDebugLog` now uses a proper `do/catch` block instead of silently discarding I/O errors
- `Rule.slackToChrome()` and `cursorToChrome()` replaced with parameterised `slackRule(targetBrowserId:)` and `cursorRule(targetBrowserId:)`; previously hardcoded `com.google.Chrome` as the target

### Changed

- Extracted `TelemetryConsentDescription` as a shared SwiftUI view; `FirstRunView` and `PreferencesWindow` now reference the single definition instead of duplicating the copy

### Added

- Optional, opt-in anonymous usage analytics via self-hosted Umami (`AnalyticsManager.swift`) — tracks aggregate events (`app_launch`, `app_updated`, `rule_created`, `first_rule_created`, `rule_deleted`, `link_routed`, `chooser_shown`, `routing_failed`); no URLs, domains, or personal data; anonymous install ID only
- `routing_failed` event in `BrowserManager.openURLWithFallback` with `reason: browser_unavailable` or `reason: no_fallback`
- `AppState.validateBrowserTargets()` — on launch, auto-disables rules whose target browser is no longer installed and saves via `PersistenceManager`
- `RuleSidebarRow` warning icon (`exclamationmark.triangle.fill`) when a rule's target browser is not installed
- Startup toast via `ToastManager.warning` when rules are auto-disabled due to a missing browser
- `ExternalLinks.privacy` constant (`https://www.defaulttamer.app/privacy`)
- Privacy Policy links in `FirstRunView`, Preferences Diagnostics section, About tab, and the existing-user `NSAlert` consent prompt
- `/privacy` page on the website with full event-by-event disclosure
- Privacy Policy link in website footer; `/privacy/` in sitemap

### Changed

- Telemetry consent copy in `FirstRunView` and `PreferencesWindow` updated with solo/open-source context and specific signals
- Homepage privacy claims updated to reflect opt-in analytics; JSON-LD and hero stat updated accordingly

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

