import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// content/ is the single source of truth for all copy (editor-owned).
// These collections wire it into Astro without moving or duplicating anything.

const link = z.object({
  label: z.string(),
  href: z.string(),
  external: z.boolean().optional(),
});

// Blog posts: markdown with KaTeX math, rendered by the markdown pipeline.
// Default entry id is the frontmatter `slug` (matches the filename stem).
export const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './content/blog' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    slug: z.string(),
    summary: z.string(),
    readingTime: z.number(),
    series: z.string().optional(),
    part: z.number().optional(),
  }),
});

// One-off prose pages (hero, about, 404) — frontmatter carries all copy.
export const sitePages = defineCollection({
  loader: glob({ pattern: '{home,about,404}.md', base: './content' }),
  schema: z
    .object({
      name: z.string().optional(),
      role: z.string().optional(),
      bio: z.string().optional(),
      links: z.array(link).optional(),
      // 404.md writes `title: 404` (YAML parses it as a number) — coerce,
      // don't reformat the owner-approved file.
      title: z.coerce.string().optional(),
      lead: z.string().optional(),
      line: z.string().optional(),
    })
    .passthrough(),
});

export const collections = { blog, sitePages };
