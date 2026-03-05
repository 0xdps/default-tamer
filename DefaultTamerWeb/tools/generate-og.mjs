/**
 * Generates public/images/og-image.png — the 1200×630 Open Graph image used for
 * social sharing. Based on routing-flow.svg with branding overlaid.
 *
 * Run: node tools/generate-og.mjs
 */

import { Resvg } from '@resvg/resvg-js';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

// ── 1. Read and prepare the routing-flow SVG ──────────────────────────────
const raw = await fs.readFile(
  path.join(root, 'public/images/routing-flow.svg'),
  'utf-8'
);

// Extract inner content (strip outer <svg> wrapper)
const innerContent = raw.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

// Remove all animation elements — resvg renders a static snapshot at t=0,
// which hides animated dots (opacity:0 initially). Stripping is cleaner.
const staticContent = innerContent
  .replace(/<animateMotion[\s\S]*?<\/animateMotion>/g, '')
  .replace(/<animate\b[^/]*/g, s => s + '/>')   // self-close any stray tags (resvg ignores them anyway)
  .replace(/<animateTransform[^>]*\/>/g, '')
  // Remove the hidden animated URL label groups (opacity:0 at t=0, messy)
  .replace(/<g opacity="0">[\s\S]*?<\/g>/g, '');

// Namespace all IDs to avoid conflicts with outer SVG defs
const namespacedContent = staticContent
  .replace(/\bid="([^"]+)"/g, 'id="rf-$1"')
  .replace(/url\(#([^)]+)\)/g, 'url(#rf-$1)')
  .replace(/href="#([^"]+)"/g, 'href="#rf-$1"');

// ── 2. Layout math ────────────────────────────────────────────────────────
// OG canvas: 1200×630
// routing-flow viewport: 900×480
// Scale to fill full 1200px width → ratio = 1200/900 = 1.3333
// Height at that scale: 480 × 1.3333 = 640 → clip/hide 10px on bottom (fine, content ends ~440)
// X offset: 0 (fills full width)
// Y offset: -5 (hide the rounded top corners of the inner bg rect, content starts at y≈42)
const scale = 1200 / 900;
const xOffset = 0;
const yOffset = -5;

// ── 3. Build the OG SVG ───────────────────────────────────────────────────
const ogSvg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="ogBg" x1="0" y1="0" x2="1200" y2="630" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#0f172a"/>
      <stop offset="100%" stop-color="#1e293b"/>
    </linearGradient>
    <!-- Gradient to darken bottom strip for footer text -->
    <linearGradient id="bottomFade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0f172a" stop-opacity="0"/>
      <stop offset="100%" stop-color="#0f172a" stop-opacity="0.85"/>
    </linearGradient>
    <!-- Gradient to darken top strip for header text -->
    <linearGradient id="topFade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0f172a" stop-opacity="0.9"/>
      <stop offset="100%" stop-color="#0f172a" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <!-- Base background -->
  <rect width="1200" height="630" fill="url(#ogBg)"/>

  <!-- Routing flow diagram — scaled to fill full width -->
  <g transform="translate(${xOffset}, ${yOffset}) scale(${scale})">
    ${namespacedContent}
  </g>

  <!-- Top overlay for branding legibility -->
  <rect x="0" y="0" width="1200" height="130" fill="url(#topFade)"/>

  <!-- Bottom overlay for footer legibility -->
  <rect x="0" y="510" width="1200" height="120" fill="url(#bottomFade)"/>

  <!-- ── Branding ── -->
  <!-- Badge pill -->
  <rect x="56" y="24" width="232" height="32" rx="16"
        fill="#f97316" fill-opacity="0.15"
        stroke="#f97316" stroke-width="1" stroke-opacity="0.5"/>
  <text x="172" y="45"
        font-family="system-ui, ui-sans-serif, -apple-system, sans-serif"
        font-size="13" font-weight="700" fill="#f97316"
        text-anchor="middle" letter-spacing="1.2">macOS · FREE · OPEN SOURCE</text>

  <!-- App name -->
  <text x="56" y="110"
        font-family="system-ui, ui-sans-serif, -apple-system, sans-serif"
        font-size="58" font-weight="800" fill="white">Default</text>
  <text x="370" y="110"
        font-family="system-ui, ui-sans-serif, -apple-system, sans-serif"
        font-size="58" font-weight="800" fill="#f97316">Tamer</text>

  <!-- Tagline -->
  <text x="56" y="145"
        font-family="system-ui, ui-sans-serif, -apple-system, sans-serif"
        font-size="22" fill="#94a3b8">Intelligent Browser Routing for macOS</text>

  <!-- ── Footer ── -->
  <text x="600" y="615"
        font-family="system-ui, ui-sans-serif, -apple-system, monospace"
        font-size="15" fill="#64748b" text-anchor="middle"
        letter-spacing="0.5">defaulttamer.app</text>
</svg>`;

// ── 4. Render to PNG ──────────────────────────────────────────────────────
const resvg = new Resvg(ogSvg, {
  fitTo: { mode: 'original' },
  font: { loadSystemFonts: true },
});

const rendered = resvg.render();
const png = rendered.asPng();

const outPath = path.join(root, 'public/images/og-image.png');
await fs.writeFile(outPath, png);

const stat = await fs.stat(outPath);
console.log(`✅  OG image generated: public/images/og-image.png (${(stat.size / 1024).toFixed(1)} KB)`);
