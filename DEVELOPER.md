# Developer Guide

**Prerequisites:** macOS 13.0+, Xcode 14.0+, [`just`](https://github.com/casey/just)

```bash
git clone --recurse-submodules https://github.com/0xdps/default-tamer.git
cd default-tamer
just deploy          # Build and run
```

## Common Commands

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

## Project Layout

```
DefaultTamer/
├── Models/       # Data models (Browser, Rule, Settings, RouteLog)
├── Services/     # Core logic (Router, BrowserManager, PersistenceManager, …)
├── Views/        # SwiftUI views
└── Utilities/    # Helpers
```

Key files: `AppDelegate.swift` (URL event handling), `AppState.swift` (state), `Router.swift` (rule evaluation).
