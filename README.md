# Default Tamer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

> A macOS menu bar utility that intelligently routes URLs to the correct browser based on source app and URL rules.

**Set Default Tamer as your default browser once — from then on, your links open exactly where you want them.**

---

## Features

- **Smart Routing** — Route links based on source app (Slack, Cursor, etc.) and URL patterns
- **Domain Rules** — Send specific domains to specific browsers
- **Override Chooser** — Hold ⌥ Option while clicking any link to manually pick a browser
- **Fallback Browser** — Configurable default for unmatched links
- **Launch at Login** — Optionally start at system login
- **Activity Logging** — Optional, privacy-first diagnostic log of recent routes
- **Privacy First** — All processing is local; no network calls, no telemetry

## Installation

Download the latest `.dmg` from [GitHub Releases](https://github.com/0xdps/default-tamer/releases), install, then:

1. Launch Default Tamer
2. Click **"Open System Settings"** in the first-run window
3. Go to System Settings → Desktop & Dock → Default web browser → select **Default Tamer**

## How It Works

Rules are evaluated in order. The first matching rule wins; unmatched links go to your fallback browser.

| Rule Type | Example |
|---|---|
| **Source App** | Slack → Chrome |
| **Domain (exact)** | `github.com` → Firefox |
| **Domain (suffix)** | `.atlassian.net` → Chrome |
| **Domain (contains)** | `jira` → Chrome |
| **URL Pattern** | Contains `/admin` → Safari |
| **URL Regex** | Advanced matching |

Two rules are created on first launch: Slack → Chrome and Cursor → Chrome.

## Privacy

- Processes all data locally — no network requests
- Stores no personal information
- Activity logging is opt-in; URLs are sanitized before storage (tokens, API keys, secrets are stripped)

## Roadmap

See [open issues](../../issues) for planned features.

Potential future additions: Chrome profile selection, import/export rules, "always show chooser" per-app mode, iCloud sync.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## For Developers

**Prerequisites:** macOS 13.0+, Xcode 14.0+, [`just`](https://github.com/casey/just)

```bash
git clone --recurse-submodules https://github.com/0xdps/default-tamer.git
cd default-tamer
just deploy          # Build and run
```

**Common commands:**

```bash
just deploy          # Fast rebuild + deploy (UI iteration)
just fresh           # Full clean rebuild from scratch
just logs            # Stream live app logs
just settings        # Dump current UserDefaults
just reset           # Reset first-run flag
just reset-all       # Wipe all app data and settings
just bump 0.0.2      # Bump version, tag, push → triggers CI release
```

Run `just` or `just --list` for the full command reference.

**Project layout:**

```
DefaultTamer/
├── Models/       # Data models (Browser, Rule, Settings, RouteLog)
├── Services/     # Core logic (Router, BrowserManager, PersistenceManager, …)
├── Views/        # SwiftUI views
└── Utilities/    # Helpers
```

Key files: `AppDelegate.swift` (URL event handling), `AppState.swift` (state), `Router.swift` (rule evaluation).

## License

MIT — see [LICENSE](LICENSE).
