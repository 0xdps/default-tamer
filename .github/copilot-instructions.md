# Default Tamer Website — Copilot Instructions

## Project Overview

This is the marketing/documentation website for Default Tamer, a macOS browser routing app. Built with **Astro**, **Tailwind CSS v3**, and **@tailwindplus/elements v1**.

---

## Mandatory: Use @tailwindplus/elements for Interactive Components

**When creating or updating any page, component, or feature on the website, you MUST use `@tailwindplus/elements` for all interactive UI behavior.** Do not write custom JavaScript for interactivity — always reach for the appropriate Tailwind Plus element first. If a Tailwind Plus element exists for the interaction you need, use it. Check the component selection table below before implementing any interactive pattern.

The website loads `@tailwindplus/elements@1` via CDN in `BaseLayout.astro`. All interactive UI components MUST use these elements instead of custom JavaScript or vanilla HTML solutions.

### Component Selection Rules

| Need | MUST Use | NEVER Do |
|------|----------|----------|
| Show/hide content (FAQ, accordion, collapsible) | `<el-disclosure>` | Plain `<details>` without wrapper, custom JS toggle |
| Modal/dialog | `<el-dialog>` + `<dialog>` | Custom modal div, `display:none` toggle |
| Tabbed content | `<el-tab-group>` | Custom tab JS, radio button hacks |
| Dropdown menu | `<el-dropdown>` + `<el-menu>` | Custom dropdown JS, hover-only dropdowns |
| Anchored popup | `<el-popover>` | Custom tooltip JS, title attributes for rich content |
| Form select | `<el-select>` + `<el-options>` | Plain `<select>` when custom styling needed |
| Search/combobox | `<el-autocomplete>` | Custom search input JS |
| Copy to clipboard | `<el-copyable>` | Custom clipboard JS |

### Required Global CSS

All Tailwind Plus custom elements MUST have `display: block` set in `global.css`:

```css
@layer base {
  el-disclosure, el-dialog, el-dialog-panel, el-dialog-backdrop,
  el-tab-group, el-tab-list, el-tab-panels, el-dropdown,
  el-popover, el-popover-group, el-select, el-autocomplete,
  el-command-palette, el-command-list, el-command-group, el-copyable {
    display: block;
  }
}
```

---

### Current Migration Status

#### ✅ Already Using Tailwind Plus Elements

| Component | Where Used | Status |
|-----------|-----------|--------|
| `<el-disclosure>` | `index.astro` FAQ (4 items), `docs/index.astro` FAQ (6 items), `docs/troubleshooting.astro` Common Questions (5 items), `Header.astro` mobile docs sub-nav | ✅ Complete |
| `<el-dialog>` | `Header.astro` mobile menu, `SearchPalette.astro` search modal | ✅ Complete |
| `<el-dropdown>` + `<el-menu>` | `Header.astro` desktop Docs dropdown | ✅ Complete |
| `<el-copyable>` | `docs/troubleshooting.astro` (2 code blocks), `docs/advanced-usage.astro` (6 code blocks) | ✅ Complete |
| `<el-tab-group>` | `docs/setup-rules.astro` Rule Types (3 tabs), `docs/advanced-usage.astro` Regex Examples (5 tabs) + Rule Chaining (3 tabs), `features.astro` Screenshot gallery (3 tabs) | ✅ Complete |
| Global CSS `display: block` | `global.css` — all custom elements registered | ✅ Complete |

#### ✅ Pages With No Interactive Elements (No Migration Needed)

`404.astro`, `changelog.astro`, `download.astro`, `docs/getting-started.astro`, `guides/index.astro`, `guides/[slug].astro`, `Footer.astro`, `Breadcrumbs.astro`, `SEO.astro`

---

### Disclosure Pattern (FAQ)

Every `<details>` element MUST be wrapped in `<el-disclosure>`:

```html
<el-disclosure>
  <details class="group bg-white border-2 border-gray-light rounded-xl overflow-hidden hover:border-primary transition-colors duration-300">
    <summary class="flex items-center justify-between p-6 cursor-pointer font-semibold text-lg list-none">
      <span class="group-open:text-primary transition-colors duration-300">Question?</span>
      <span class="text-primary text-2xl group-open:rotate-45 transition-transform duration-300">+</span>
    </summary>
    <div class="px-6 pb-6 text-gray leading-relaxed">
      Answer content.
    </div>
  </details>
</el-disclosure>
```

### Dialog Pattern (Modals)

```html
<el-dialog>
  <button commandfor="dialog-id" command="show-modal">Open</button>
  <dialog id="dialog-id">
    <el-dialog-panel>
      <button commandfor="dialog-id" command="close">✕</button>
      <!-- Content -->
    </el-dialog-panel>
    <el-dialog-backdrop class="fixed inset-0 bg-black/50"></el-dialog-backdrop>
  </dialog>
</el-dialog>
```

### Tabs Pattern

```html
<el-tab-group>
  <el-tab-list class="flex gap-1 rounded-lg bg-gray-lighter p-1">
    <button class="flex-1 rounded-md px-4 py-2.5 text-sm font-semibold aria-selected:bg-white aria-selected:text-primary">Tab 1</button>
    <button class="...">Tab 2</button>
  </el-tab-list>
  <el-tab-panels>
    <div>Panel 1</div>
    <div>Panel 2</div>
  </el-tab-panels>
</el-tab-group>
```

### Dropdown Pattern

```html
<el-dropdown>
  <button>Trigger</button>
  <el-menu anchor="bottom start" class="rounded-xl bg-white shadow-xl ring-1 ring-black/5 p-2" style="--anchor-gap: 8px">
    <a href="/link" class="block px-3 py-2 rounded-lg text-sm hover:bg-gray-lighter">Item</a>
  </el-menu>
</el-dropdown>
```

### Copyable Pattern (Code Blocks)

Use for terminal commands in docs pages:

```html
<el-copyable id="snippet">npm install @tailwindplus/elements</el-copyable>

<button command="--copy" commandfor="snippet">
  <span class="in-data-copied:hidden">Copy</span>
  <span class="not-in-data-copied:hidden">Copied!</span>
</button>
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
| `gray` | `#64748b` | Body text, secondary text |
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
| Primary button | `rounded-lg bg-primary px-6 py-3 text-sm font-semibold text-white hover:bg-primary-dark transition-all duration-200` |
| Ghost link | `text-primary font-semibold hover:text-primary-dark transition-colors duration-200` |

---

## Page Structure

### Layout Hierarchy

```
BaseLayout.astro
├── SEO.astro (meta tags)
├── Google Fonts (Outfit + Plus Jakarta Sans)
├── @tailwindplus/elements CDN script (defer)
├── Header.astro (sticky nav with el-dropdown + el-dialog)
├── <main><slot /></main>
├── Footer.astro
├── SearchPalette.astro (⌘K search using el-dialog)
└── Back to top button (vanilla JS scroll listener)
```

### Page Types

1. **Marketing pages** (`index.astro`, `features.astro`, `download.astro`) — Full-width sections with `hero-section`, feature grids, CTAs
2. **Docs hub** (`docs/index.astro`) — Cards grid + quick links + FAQ with `<el-disclosure>`
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

- **Guides:** `src/content/guides/*.md` — frontmatter: `title`, `description`, `category`, `order`, `featured`
- **Blog:** `src/content/blog/*.md` — defined but empty

---

## Don'ts

- ❌ Don't use `<details>` without `<el-disclosure>` wrapper
- ❌ Don't create custom JavaScript for show/hide, tabs, modals, dropdowns, popovers, filtering, or clipboard
- ❌ Don't write scoped `<style>` blocks
- ❌ Don't import or reference any CSS framework other than Tailwind
- ❌ Don't use the theme-color `#3b82f6` (blue) — our brand is orange `#f97316`
- ❌ Don't hardcode the site URL — it should come from `astro.config.mjs`
- ❌ Don't add `font-family` declarations — use `font-heading` or `font-sans` tokens
- ❌ Don't use absolute positioning for dropdowns/popovers — use `el-menu`/`el-popover` with `anchor`
- ❌ Don't implement copy-to-clipboard manually — use `<el-copyable>`
