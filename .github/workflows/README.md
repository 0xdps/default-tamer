# CI/CD Workflows

This directory contains GitHub Actions workflows for automated building, testing, and deployment.

## Workflows

### 1. Build and Test (`build.yml`)

**Triggers:**

- Push to `trunk` or `main` branches
- Pull requests to `trunk` or `main` branches

**What it does:**

- Checks out code
- Sets up Xcode 15.0
- Installs XcodeGen
- Generates Xcode project
- Builds the app in Debug configuration
- Runs tests (when available)
- Uploads build artifacts

**Status Badge:**

```markdown
[![Build Status](https://github.com/0xdps/default-tamer/actions/workflows/build.yml/badge.svg)](https://github.com/0xdps/default-tamer/actions/workflows/build.yml)
```

### 2. Deploy Website (`deploy-website.yml`)

**Triggers:**

- Push to `trunk` or `main` branches (when `website/**` files change)
- Manual workflow dispatch

**What it does:**

- Deploys the `website` folder to GitHub Pages
- Automatically updates the live website

**Setup Required:**

1. Go to Settings → Pages
2. Source: GitHub Actions
3. The website will be available at: `https://0xdps.github.io/default-tamer/`

### 3. Release (`release.yml`)

**Triggers:**

- Push of version tags (e.g., `v1.0.0`)

**What it does:**

- Builds Release configuration
- Creates a DMG file
- Creates a GitHub Release (draft)
- Uploads DMG as release asset

**Usage:**

```bash
# Create and push a version tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Setup Instructions

### For Build Workflow

No additional setup required! The workflow will run automatically on push/PR.

### For Website Deployment

1. Enable GitHub Pages:
   - Go to repository Settings → Pages
   - Source: **GitHub Actions**
   - Save

2. The website will deploy automatically when you push changes to the `website/` folder

### For Release Workflow

1. **Update Team ID** (for code signing):
   - Edit `ExportOptions.plist`
   - Replace `YOUR_TEAM_ID` with your Apple Developer Team ID
   - Or remove signing for development builds

2. **Create a release:**

   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

3. The workflow will create a draft release with the DMG
4. Edit the release notes and publish when ready

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

### Website deployment fails

- Ensure GitHub Pages is enabled
- Check that `website/` folder exists
- Verify workflow permissions

### Release fails

- Update `ExportOptions.plist` with correct Team ID
- Check code signing settings
- Ensure tag format is `vX.Y.Z`

## Status Badges

Add these to your README.md:

```markdown
[![Build](https://github.com/0xdps/default-tamer/actions/workflows/build.yml/badge.svg)](https://github.com/0xdps/default-tamer/actions/workflows/build.yml)
[![Website](https://github.com/0xdps/default-tamer/actions/workflows/deploy-website.yml/badge.svg)](https://github.com/0xdps/default-tamer/actions/workflows/deploy-website.yml)
```
