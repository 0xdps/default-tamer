import type { APIRoute } from 'astro';

const siteUrl = 'https://www.defaulttamer.app';
const today = new Date().toISOString().split('T')[0];

const pages = [
  { loc: '/',           priority: '1.0', changefreq: 'weekly'  },
  { loc: '/download/',  priority: '0.9', changefreq: 'weekly'  },
  { loc: '/docs/',      priority: '0.8', changefreq: 'monthly' },
  { loc: '/changelog/', priority: '0.7', changefreq: 'weekly'  },
  { loc: '/privacy/',   priority: '0.5', changefreq: 'monthly' },
];

export const GET: APIRoute = () => {
  const urls = pages
    .map(
      ({ loc, priority, changefreq }) => `
  <url>
    <loc>${siteUrl}${loc}</loc>
    <lastmod>${today}</lastmod>
    <changefreq>${changefreq}</changefreq>
    <priority>${priority}</priority>
  </url>`
    )
    .join('');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="/sitemap.xsl"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}
</urlset>`;

  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' },
  });
};
