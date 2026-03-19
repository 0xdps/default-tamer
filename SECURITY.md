# Security Policy

## Supported Versions

Only the latest release receives security fixes. Older versions are not patched.

| Version | Supported |
| ------- | --------- |
| 0.0.x (latest) | ✅ |
| < latest | ❌ |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report security issues by emailing: **security@defaulttamer.app**

Include:
- A clear description of the vulnerability
- Steps to reproduce or a proof-of-concept
- The Default Tamer version affected
- macOS version and any other relevant environment details

You can expect an acknowledgement within **48 hours** and a status update within **7 days**. If the vulnerability is confirmed, a patch will be released as soon as possible and you will be credited in the release notes (unless you prefer to remain anonymous).

## Scope

Default Tamer is a local macOS app with no network-facing server component. The main attack surface is:

- **URL routing** — malformed or malicious URLs passed to the app via the `defaultbrowser://` scheme
- **Rule import** — JSON rule files loaded from disk
- **Browser detection** — reading app bundle metadata from `/Applications`
- **Local data** — settings and rules stored in `UserDefaults` and `~/Library/Application Support/DefaultTamer`

Reports outside this scope (e.g. issues in third-party dependencies like Sparkle or SQLite.swift) should be reported directly to those projects.
