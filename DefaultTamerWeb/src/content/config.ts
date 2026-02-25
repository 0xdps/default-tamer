import { defineCollection, z } from 'astro:content';

const changelog = defineCollection({
  type: 'content',
  schema: z.object({
    version: z.string(),            // e.g. "0.0.2"
    date: z.string(),               // ISO date e.g. "2026-02-23"
    isUnreleased: z.boolean().optional().default(false),
  }),
});

const guides = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    category: z.string().optional(),
    order: z.number().optional(),
    featured: z.boolean().optional().default(false),
  }),
});

export const collections = { changelog, guides };
