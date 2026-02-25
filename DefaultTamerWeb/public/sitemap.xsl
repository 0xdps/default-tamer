<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:sm="http://www.sitemaps.org/schemas/sitemap/0.9"
  exclude-result-prefixes="sm">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>Sitemap — Default Tamer</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f8fafc; color: #1e293b; min-height: 100vh; }
          header { background: #1e293b; padding: 20px 40px; display: flex; align-items: center; gap: 12px; }
          header a { text-decoration: none; display: flex; align-items: center; gap: 12px; }
          header span.title { color: #fff; font-size: 1.1rem; font-weight: 600; }
          header span.badge { background: #f97316; color: #fff; font-size: 0.7rem; font-weight: 700; padding: 2px 8px; border-radius: 9999px; letter-spacing: 0.05em; text-transform: uppercase; }
          main { max-width: 860px; margin: 48px auto; padding: 0 24px; }
          h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: 8px; }
          p.sub { color: #64748b; font-size: 0.9rem; margin-bottom: 32px; }
          table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
          thead tr { background: #f1f5f9; }
          th { text-align: left; padding: 12px 20px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; }
          td { padding: 14px 20px; border-top: 1px solid #e2e8f0; font-size: 0.9rem; }
          td a { color: #f97316; text-decoration: none; word-break: break-all; }
          td a:hover { text-decoration: underline; }
          td.priority { color: #64748b; font-size: 0.85rem; }
          td.lastmod { color: #64748b; font-size: 0.85rem; white-space: nowrap; }
          tr:last-child td { border-bottom: none; }
        </style>
      </head>
      <body>
        <header>
          <a href="/">
            <span class="title">Default Tamer</span>
            <span class="badge">Sitemap</span>
          </a>
        </header>
        <main>
          <h1>XML Sitemap</h1>
          <p class="sub">
            <xsl:value-of select="count(sm:urlset/sm:url)"/> URLs indexed for search engines.
          </p>
          <table>
            <thead>
              <tr>
                <th>URL</th>
                <th>Last Modified</th>
                <th>Priority</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="sm:urlset/sm:url">
                <tr>
                  <td>
                    <a href="{sm:loc}"><xsl:value-of select="sm:loc"/></a>
                  </td>
                  <td class="lastmod">
                    <xsl:value-of select="sm:lastmod"/>
                  </td>
                  <td class="priority">
                    <xsl:value-of select="sm:priority"/>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </main>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
