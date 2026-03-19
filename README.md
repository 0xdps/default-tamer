# Default Tamer

[![Latest Release](https://img.shields.io/github/v/release/0xdps/default-tamer?color=orange&label=Download)](https://github.com/0xdps/default-tamer/releases/latest)
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

Download **[DefaultTamer-v0.0.7.dmg](https://github.com/0xdps/default-tamer/releases/download/v0.0.7/DefaultTamer-v0.0.7.dmg)** — or browse all releases on the [Releases page](https://github.com/0xdps/default-tamer/releases).

Once downloaded, open the DMG and drag Default Tamer to Applications, then:

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

## Privacy

- Processes all data locally — no network requests
- Stores no personal information
- Activity logging is opt-in; URLs are sanitized before storage (tokens, API keys, secrets are stripped)

## Roadmap

See [open issues](../../issues) for planned features.

Potential future additions: Chrome profile selection, import/export rules, "always show chooser" per-app mode, iCloud sync.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Developer setup instructions are in [DEVELOPER.md](DEVELOPER.md).

## License

MIT — see [LICENSE](LICENSE).
