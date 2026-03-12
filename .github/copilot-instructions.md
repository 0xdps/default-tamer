# Default Tamer Website — Copilot Instructions

## Project Overview

This is the marketing/documentation website for Default Tamer, a macOS browser routing app. Built with **Astro**, **Tailwind CSS v3**, and **native HTML interactions** powered by a lightweight script.

---

## Mandatory: Use Native HTML Interactions

**When creating or updating interactive UI, use native HTML patterns first (`<details>`, `<dialog>`, semantic buttons/links) and wire behavior through the shared script at `public/scripts/custom-interactions.js`.**

Do not re-introduce `@tailwindplus/elements` or `el-*` tags unless explicitly requested by the maintainer.

### Interaction Rules

| Need | Preferred Pattern | Avoid |
|------|-------------------|-------|
| Show/hide content (FAQ, accordion, collapsible) | Native `<details>` + `<summary>` | Custom div toggles with ad-hoc state |
| Modal/dialog | Native `<dialog>` with `data-dialog-trigger` / `data-dialog-close` hooks | `display:none` modal implementations |
| Copy to clipboard | `data-copy` button targeting an element ID | Per-page custom clipboard scripts |
| Keyboard-accessible menus/tabs | Reuse handlers in `custom-interactions.js` | Duplicated one-off keyboard logic |

### Current Interaction Architecture

- Shared script: `DefaultTamerWeb/public/scripts/custom-interactions.js`
- Global behavior styles: `DefaultTamerWeb/src/styles/global.css` (native `dialog` and `details` styling)
- Base layout loader: `DefaultTamerWeb/src/layouts/BaseLayout.astro` loads the shared interaction script

### Native FAQ Pattern

```html
<details class="group bg-white border-2 border-gray-light rounded-xl overflow-hidden hover:border-primary transition-colors duration-300">
  <summary class="flex items-center justify-between p-6 cursor-pointer font-semibold text-lg list-none">
    <span class="group-open:text-primary transition-colors duration-300">Question?</span>
    <span class="text-primary text-2xl group-open:rotate-45 transition-transform duration-300">+</span>
  </summary>
  <div class="px-6 pb-6 text-gray leading-relaxed">
    Answer content.
  </div>
</details>
```

### Native Dialog Pattern

```html
<button data-dialog-trigger="dialog-id">Open</button>

<dialog id="dialog-id">
  <div class="relative z-10">
    <button data-dialog-close>✕</button>
    <!-- Content -->
  </div>
  <div class="fixed inset-0 bg-black/50"></div>
</dialog>
```

### Clipboard Pattern (Code Blocks)

```html
<pre id="snippet">npm install default-tamer</pre>

<button data-copy="snippet">Copy</button>
```

---

## Styling Rules

### ALWAYS Use Tailwind Utilities

- **NEVER** write scoped `<style>` blocks in `.astro` files
- **NEVER** create new CSS classes when Tailwind utilities exist
- **ALWAYS** use Tailwind utility classes directly in HTML
- **EXCEPTION:** Shared component classes in `global.css` (`.card-animated`, `.callout-*`, `.docs-wrapper`, `.docs-page`, `.docs-content`, `.prose`, `.hero-section`, and doc-specific component classes)

### Brand Colors (from tailwind.config.mjs)

| Token | Value | Usage |
|-------|-------|-------|
| `primary` | `#f97316` | Links, CTAs, active states, accents |
| `primary-dark` | `#ea580c` | Hover states for primary |
| `secondary` | `#10b981` | Gradient accent (rarely alone) |
| `dark` | `#1e293b` | Text, dark backgrounds |
| `dark-light` | `#334155` | Hover for dark elements |
| `gray` | `#475569` | Body text, secondary text |
| `gray-light` | `#e2e8f0` | Borders, dividers |
| `gray-lighter` | `#f8fafc` | Background surfaces |

### Typography

- **Headings:** `font-heading` (Outfit)
- **Body:** `font-sans` (Plus Jakarta Sans) — applied via base layer
- **Never** add font-family inline or import other fonts

### Component Patterns

| Pattern | Classes |
|---------|---------|
| Card | `card-animated p-6 bg-white border-2 border-gray-light rounded-xl hover:border-primary hover:-translate-y-2 transition-all duration-300 hover:shadow-xl` |
| Hero section | `hero-section` (defined in global.css) |
| Info callout | `callout-info` |
| Warning callout | `callout-warning` |
| Success callout | `callout-success` |
| Docs wrapper (prose pages) | `docs-wrapper prose` |
| Docs page (sidebar layout) | `docs-page` + `docs-content` (used in troubleshooting, advanced-usage) |
| Primary button | `rounded-lg bg-primary px-6 py-3 text-sm font-semibold text-dark hover:bg-primary-dark transition-all duration-200` |
| Ghost link | `text-primary font-semibold hover:text-primary-dark transition-colors duration-200` |

---

## Page Structure

### Layout Hierarchy

```
BaseLayout.astro
├── SEO.astro (meta tags)
├── Google Fonts (Outfit + Plus Jakarta Sans)
├── custom-interactions.js (async)
├── Header.astro (sticky nav with native dialog/menu patterns)
├── <main><slot /></main>
├── Footer.astro
├── SearchPalette.astro (⌘K search using native dialog)
└── Back to top button (vanilla JS scroll listener)
```

### Page Types

1. **Marketing pages** (`index.astro`, `features.astro`, `download.astro`) — Full-width sections with `hero-section`, feature grids, CTAs
2. **Docs hub** (`docs/index.astro`) — Cards grid + quick links + FAQ with native `<details>`
3. **Docs prose pages** (`docs/getting-started.astro`, `docs/setup-rules.astro`) — `<div class="docs-wrapper prose">`
4. **Docs sidebar pages** (`docs/troubleshooting.astro`, `docs/advanced-usage.astro`) — `<section class="docs-page">` with sticky sidebar TOC
5. **Guide pages** (`guides/[slug].astro`) — Content collection, rendered markdown

### Docs Pages Convention

- **Prose layout:** Wrap content in `<div class="docs-wrapper prose">`
- **Sidebar layout:** Use `<section class="docs-page">` with `<div class="docs-content">` and `<aside>` for sticky TOC
- Use `callout-info`, `callout-warning`, `callout-success` for callout boxes
- Use TOC with `bg-gray-lighter p-6 rounded-lg mb-12`
- Section headings: `text-3xl text-dark border-b-2 border-gray-light pb-2 mt-12 mb-6`

---

## Content Collections

- **Changelog:** `src/content/changelog/*.md` — frontmatter: `version`, `date`, `isUnreleased` (optional, defaults false)
- **Guides:** `src/content/guides/*.md` — frontmatter: `title`, `description`, `category`, `order`, `featured`

---

## Changelog Workflow

The project uses a **two-track changelog** system:

| Track | File | Audience | Updated when |
|-------|------|----------|--------------|
| Developer log | `CHANGELOG.md` (repo root) | Contributors, git history | Every meaningful commit |
| User-facing | `DefaultTamerWeb/src/content/changelog/*.md` | End users on the website | Every release |

### ❗ NEVER read `CHANGELOG.md` for the website

The website `/changelog` page reads exclusively from `src/content/changelog/`. Do **not** modify `changelog.astro` to read `CHANGELOG.md` again.

---

### When to update `CHANGELOG.md` (developer log)

Update after **any** commit that changes behaviour, fixes a bug, adds a feature, or changes the build/release process. Use [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) categories:

- `### Added` — new features
- `### Changed` — changes to existing behaviour
- `### Fixed` — bug fixes
- `### Removed` — removed features
- `### Deprecated` — soon-to-be removed features
- `### Security` — security fixes

Entries go under `## [Unreleased]` until a version is tagged.

**Tone:** technical and implementation-level. This is a developer log.

---

### When to create a user-facing changelog entry

Create a new file in `src/content/changelog/` when a **new version is released** (i.e. when `[Unreleased]` is promoted to a version in `CHANGELOG.md`). Do **not** create entries for unreleased work.

### How to create a user-facing entry

**Filename:** `src/content/changelog/{version}.md` — e.g. `0.1.0.md`

**Template:**

```md
---
version: "0.1.0"
date: "YYYY-MM-DD"
---

### Added

- Plain-language description of what users can now do. Focus on the benefit.

### Fixed

- What was broken and what the user experience is now.
```

**Allowed `### ` headings** (these are styled as coloured badges on the website):
`Added`, `Fixed`, `Changed`, `Improved`, `Updated`, `Removed`, `Security`

**Tone rules — MUST follow:**

- ✅ Write for a non-technical user: "Default Tamer now checks for updates automatically" not "Replaced custom UpdateManager with Sparkle SPUStandardUpdaterController"
- ✅ Focus on what the user can do or what changed for them
- ✅ One bullet per distinct user-visible change
- ❌ Never mention internal class names, framework names, file names, or implementation details
- ❌ Never copy-paste entries from `CHANGELOG.md` verbatim
- ❌ Never create an entry for internal refactors that have no user-visible effect
- ❌ Never include an entry for website-only changes (styling, copy, docs updates)

**Examples:**

| ❌ Developer log (wrong for website) | ✅ User-facing (correct) |
|--------------------------------------|-------------------------|
| Replaced custom GitHub-based update checker with Sparkle | Default Tamer now checks for updates automatically in the background |
| Migrates `hasCompletedFirstRun` UserDefaults flag to file sentinel | First-run setup wizard no longer reappears after updating the app |
| Removed `UpdateNotificationView` struct | *(no entry — not user-visible)* |

### Sorting

Entries are sorted **newest first** automatically by `changelog.astro` using semantic version comparison. No manual ordering needed.

For unreleased entries, use a version number higher than the current latest release (e.g. `9.9.9`) to ensure it always sorts to the top — the version is never shown to users on the card, only used internally for ordering.

### 10-release cap

Only the 10 most recent entries are shown on the website. Older releases automatically get a "View full changelog on GitHub" CTA pointing to `CHANGELOG.md`. No action needed when adding new entries.

---

## Don'ts

- ❌ Don't use `@tailwindplus/elements` or any `el-*` tags
- ❌ Don't add page-specific interactive scripts when behavior can live in `public/scripts/custom-interactions.js`
- ❌ Don't write scoped `<style>` blocks
- ❌ Don't import or reference any CSS framework other than Tailwind
- ❌ Don't use the theme-color `#3b82f6` (blue) — our brand is orange `#f97316`
- ❌ Don't hardcode the site URL — it should come from `astro.config.mjs`
- ❌ Don't add `font-family` declarations — use `font-heading` or `font-sans` tokens
- ❌ Don't duplicate UI indicators in both markup and CSS pseudo-elements (e.g., double FAQ plus icons)
- ❌ Don't read `CHANGELOG.md` from the website — the website uses `src/content/changelog/*.md` only
- ❌ Don't copy developer log entries to user-facing changelog files verbatim — rewrite for end users
- ❌ Don't create a user-facing changelog entry for internal refactors, website-only changes, or unreleased work
