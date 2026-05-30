import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const changelog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/changelog' }),
  schema: z.object({
    version: z.string(),            // e.g. "0.0.2"
    date: z.string(),               // ISO date e.g. "2026-02-23"
    isUnreleased: z.boolean().optional().default(false),
  }),
});

export const collections = { changelog };
