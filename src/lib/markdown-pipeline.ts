// Single source of truth for the site's markdown pipeline.
//
// Used in two places:
//   1. astro.config.mjs — the `markdown.processor` option (blog posts, about)
//   2. src/lib/render-markdown.ts — build-time rendering of raw markdown
//      strings (the changelog page's `body` fields; Astro 7's `render()`
//      from astro:content only accepts content-collection entries)
//
// Stack decisions: docs/HOSTING.md D3 (MPP, real URLs), D11 (build-time
// KaTeX), D12 (Astro), DESIGN §10 (zero JS).
import { unified } from '@astrojs/markdown-remark';
import remarkMath from 'remark-math';
import rehypeKatexAria from './rehype-katex-aria';
import rehypeExternalLinks from './rehype-external-links';

export const SITE_ORIGIN = 'https://alexander-wang.net';

export const markdownProcessor = unified({
  // smartypants off — the owner-approved copy uses plain apostrophes and
  // literal em dashes and must render exactly as written.
  smartypants: false,
  remarkPlugins: [remarkMath],
  rehypePlugins: [
    // $…$ and $$…$$ → KaTeX HTML at build time (D11). 'html' output keeps
    // the page light (no MathML duplication); the wrapper adds a
    // role="img" + aria-label (TeX source) to every equation.
    [rehypeKatexAria, { output: 'html' }],
    // Append an inline arrow (↗) to absolute external links.
    [rehypeExternalLinks, SITE_ORIGIN],
  ],
});
