# Default Tamer Website (Astro)

Modern, multi-page website for Default Tamer built with Astro framework.

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ 
- npm or pnpm

### Installation

```bash
cd website
npm install
```

### Development

```bash
npm run dev
```

Visit `http://localhost:4321`

### Build

```bash
npm run build
```

Output will be in `dist/` directory.

### Preview Build

```bash
npm run preview
```

## 📁 Project Structure

```
website/
├── public/              # Static assets
│   ├── images/         # Screenshots, icons, logos
│   ├── robots.txt      # SEO robots file
│   └── site.webmanifest
├── src/
│   ├── components/     # Reusable Astro components
│   │   ├── Header.astro
│   │   ├── Footer.astro
│   │   └── SEO.astro
│   ├── content/        # Markdown content (Content Collections)
│   │   ├── config.ts   # Content collections schema
│   │   ├── guides/     # Guide posts (Markdown)
│   │   └── blog/       # Blog posts (Markdown) - future
│   ├── layouts/        # Page layouts
│   │   └── BaseLayout.astro
│   ├── pages/          # File-based routing
│   │   ├── index.astro        # Homepage
│   │   ├── features.astro     # Features page
│   │   ├── download.astro     # Download page
│   │   ├── docs/              # Documentation pages
│   │   │   └── index.astro
│   │   └── guides/            # Guides (dynamic routing)
│   │       ├── index.astro    # Guides listing
│   │       └── [slug].astro   # Individual guide pages
│   ├── styles/         # Global styles
│   │   └── global.css
│   └── utils/          # Utility functions
├── astro.config.mjs    # Astro configuration
├── package.json
└── tsconfig.json
```

## 📝 Content Management

### Adding a New Guide

1. Create a new Markdown file in `src/content/guides/`:

```bash
touch src/content/guides/my-new-guide.md
```

2. Add frontmatter:

```markdown
---
title: "My New Guide Title"
description: "Brief description of the guide"
category: "Getting Started"
pubDate: 2026-02-10
featured: true
order: 3
---

# My New Guide Title

Your content here...
```

3. The guide will automatically appear on `/guides` page

### Content Collections Schema

Guides follow this schema (defined in `src/content/config.ts`):

- **title**: string (required)
- **description**: string (required)
- **category**: string (required) - e.g., "Getting Started", "Advanced", "Tips"
- **pubDate**: date (required)
- **featured**: boolean (default: false) - shows in featured section
- **order**: number (optional) - controls sorting order

## 🎨 Styling

- Global styles: `src/styles/global.css`
- Component styles: Scoped `<style>` blocks in each `.astro` file
- CSS Variables: Defined in `global.css` root

### CSS Variables

```css
--primary: #3b82f6;
--secondary: #8b5cf6;
--accent: #ec4899;
--dark: #4a576c;
--gray: #64748b;
```

## 🔗 Routing

Astro uses file-based routing:

- `/` → `src/pages/index.astro`
- `/features` → `src/pages/features.astro`
- `/download` → `src/pages/download.astro`
- `/docs` → `src/pages/docs/index.astro`
- `/guides` → `src/pages/guides/index.astro`
- `/guides/[slug]` → `src/pages/guides/[slug].astro` (dynamic)

## 🚢 Deployment

### Netlify

1. Connect your GitHub repository
2. Set build settings:
   - **Build command:** `npm run build`
   - **Publish directory:** `dist`
   - **Base directory:** `website`
3. Deploy!

### Vercel

1. Import GitHub repository
2. Framework: **Astro**
3. Root directory: `website`
4. Deploy!

### GitHub Pages

1. Update `astro.config.mjs`:
```js
export default defineConfig({
  site: 'https://yourusername.github.io',
  base: '/default-tamer',
});
```

2. Build and deploy:
```bash
npm run build
# Deploy dist/ folder to gh-pages branch
```

## 📊 SEO

### Meta Tags

SEO meta tags are managed in `src/components/SEO.astro`:
- Auto-generates Open Graph tags
- Twitter Card support
- Canonical URLs
- Structured data (JSON-LD)

### Sitemap

To add sitemap generation:

```bash
npm install @astrojs/sitemap
```

Update `astro.config.mjs`:
```js
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://defaulttamer.com',
  integrations: [sitemap()],
});
```

### RSS Feed (for blog)

```bash
npm install @astrojs/rss
```

Create `src/pages/rss.xml.js` to generate RSS feed.

## 🎯 Performance

- **Lighthouse Score:** 95-100
- **Zero JavaScript by default** - Astro ships HTML/CSS only
- **Lazy loading images** - Use `loading="lazy"` on images
- **Optimized builds** - CSS minification, tree-shaking

### Performance Tips

1. Use WebP images with fallbacks:
```html
<picture>
  <source srcset="/images/screenshot.webp" type="image/webp">
  <img src="/images/screenshot.png" alt="Screenshot">
</picture>
```

2. Lazy load images below the fold:
```html
<img src="..." loading="lazy">
```

3. Preload critical assets:
```html
<link rel="preload" href="/fonts/custom.woff2" as="font" type="font/woff2" crossorigin>
```

## 🧪 Development Tips

### Hot Module Reloading

Changes to `.astro`, `.md`, and `.css` files automatically reload.

### TypeScript

Project uses strict TypeScript. Types are defined in:
- `src/content/config.ts` - Content collections
- Component props - Inline interfaces

### Adding New Pages

1. Create `.astro` file in `src/pages/`
2. Import `BaseLayout`
3. Add to navigation in `src/components/Header.astro`

Example:
```astro
---
import BaseLayout from '../layouts/BaseLayout.astro';
---

<BaseLayout title="New Page" description="Description">
  <section>
    <div class="container">
      <h1>New Page</h1>
    </div>
  </section>
</BaseLayout>
```

## 🔧 Customization

### Changing Colors

Edit CSS variables in `src/styles/global.css`:

```css
:root {
  --primary: #your-color;
  --secondary: #your-color;
}
```

### Updating Navigation

Edit `src/components/Header.astro`:

```astro
const navItems = [
  { href: '/features', label: 'Features' },
  { href: '/new-page', label: 'New Page' }, // Add here
];
```

### Modifying Footer

Edit `src/components/Footer.astro`:

```astro
const footerColumns = [
  {
    title: 'New Section',
    links: [...]
  }
];
```

## 📦 Adding Integrations

Astro supports many integrations:

```bash
# React (if needed)
npx astro add react

# Tailwind CSS
npx astro add tailwind

# MDX (enhanced Markdown)
npx astro add mdx
```

## 🐛 Troubleshooting

### Build Errors

```bash
# Clear cache and rebuild
rm -rf node_modules .astro dist
npm install
npm run build
```

### Type Errors

```bash
# Run type checking
npm run astro check
```

### Port Already in Use

```bash
# Use different port
npm run dev -- --port 3000
```

## 📚 Resources

- [Astro Documentation](https://docs.astro.build)
- [Astro Content Collections](https://docs.astro.build/en/guides/content-collections/)
- [Astro Integrations](https://astro.build/integrations/)

## 🎉 Benefits Over Old Structure

### Before (index.html)
- ✅ 1 massive HTML file (1,500+ lines)
- ✅ Hard to maintain
- ✅ No content separation
- ✅ Manual SEO for each section
- ✅ All content loads at once

### After (Astro)
- ✅ Modular, component-based
- ✅ Easy to maintain
- ✅ Markdown for guides (easy editing)
- ✅ Auto-generated pages from content
- ✅ Better SEO (individual pages)
- ✅ Faster page loads
- ✅ Scalable for future growth

## 🔮 Future Enhancements

- [ ] Add blog functionality
- [ ] Implement search (Algolia/Pagefind)
- [ ] Add dark mode toggle
- [ ] RSS feed for guides
- [ ] Internationalization (i18n)
- [ ] Interactive demos
- [ ] Video tutorials section

## 📄 License

Same as main project (MIT License)
