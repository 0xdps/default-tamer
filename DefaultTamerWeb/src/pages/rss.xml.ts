import rss from '@astrojs/rss';
import type { APIContext } from 'astro';

export async function GET(context: APIContext) {
  return rss({
    title: 'Default Tamer',
    description: 'Intelligent browser routing for macOS.',
    site: context.site!.toString(),
    items: [],
  });
}
