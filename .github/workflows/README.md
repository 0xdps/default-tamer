# CI/CD Workflows

This directory contains GitHub Actions workflows for automated building, testing, and deployment.

## Workflows

### 1. Build and Test (`build.yml`)

**Triggers:**

- Push to `trunk` or `main` branches
- Pull requests to `trunk` or `main` branches

**What it does:**

- Checks out code
- Sets up Xcode 16
- Installs XcodeGen
- Generates Xcode project
- Builds the app in Debug configuration
- Runs tests
- Uploads build artifacts

**Status Badge:**

```markdown
[![Build Status](https://github.com/0xdps/default-tamer/actions/workflows/build.yml/badge.svg)](https://github.com/0xdps/default-tamer/actions/workflows/build.yml)
```

### 2. CodeQL (`codeql.yml`)

**Triggers:**

- Push to `trunk` or `main` branches
- Pull requests to `trunk` or `main` branches
- Weekly schedule (Mondays 08:00 UTC)

**What it does:**

- Runs GitHub CodeQL static analysis on Swift code
- Results appear in the Security tab

### 3. Release (`release.yml`)

**Triggers:**

- Push of version tags matching `v*` (e.g., `v0.0.8`)

**What it does:**

- Builds a universal (arm64 + x86_64) Release app
- Signs with Developer ID certificate
- Creates a notarized DMG
- Publishes a GitHub Release with the DMG and release notes from `CHANGELOG.md`

**Usage:**

```bash
# Bump VERSION.txt, promote [Unreleased] in CHANGELOG.md, then:
git tag -a v0.0.8 -m "Release v0.0.8"
git push origin v0.0.8
```

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `BUILD_CERTIFICATE_BASE64` | Developer ID Application certificate (base64-encoded .p12) |
| `P12_PASSWORD` | Password for the .p12 certificate |
| `KEYCHAIN_PASSWORD` | Temporary keychain password used during the build |
| `DEVELOPER_ID_NAME` | Full name of the Developer ID signing identity |
| `TEAM_ID` | Apple Developer Team ID |
| `APPLE_ID_USER` | Apple ID email for notarization |
| `APPLE_ID_TEAM` | Apple Developer Team ID for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `SCRIPTS_DEPLOY_TOKEN` | GitHub token with read access to the private scripts submodule |


## Adding Tests

When you add tests to the project:

1. Create test files in `DefaultTamerTests/`
2. The `build.yml` workflow will automatically run them
3. Code coverage reports will be generated

Example test structure:

```
DefaultTamer.xcodeproj
DefaultTamer/
DefaultTamerTests/
  ├── BrowserManagerTests.swift
  ├── RouterTests.swift
  └── RuleTests.swift
```

## Troubleshooting

### Build fails on CI

- Check Xcode version compatibility
- Ensure `project.yml` is up to date
- Verify all dependencies are available

### Release fails

- Confirm all required secrets are set in repository Settings → Secrets
- Ensure `VERSION.txt` is bumped and `[Unreleased]` is promoted in `CHANGELOG.md` before tagging
- Ensure tag format is `vX.Y.Z`

## Status Badge

```markdown
[![Build](https://github.com/0xdps/default-tamer/actions/workflows/build.yml/badge.svg)](https://github.com/0xdps/default-tamer/actions/workflows/build.yml)
```
