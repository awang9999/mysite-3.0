// Astro 7 config — mysite-3.0
// Stack decisions: docs/HOSTING.md D3 (MPP, real URLs), D11 (build-time
// KaTeX), D12 (Astro), DESIGN §10 (zero JS).
import { defineConfig } from 'astro/config';
import { unified } from '@astrojs/markdown-remark';
import remarkMath from 'remark-math';
import rehypeKatexAria from './src/lib/rehype-katex-aria.ts';
import rehypeExternalLinks from './src/lib/rehype-external-links.ts';

const SITE = 'https://alexander-wang.net';

export default defineConfig({
  site: SITE,
  markdown: {
    // Astro 7: the remark/rehype pipeline is passed to the unified processor
    // directly. smartypants off — the owner-approved copy uses plain
    // apostrophes and literal em dashes and must render exactly as written.
    processor: unified({
      smartypants: false,
      remarkPlugins: [remarkMath],
      rehypePlugins: [
        // $…$ and $$…$$ → KaTeX HTML at build time (D11). 'html' output keeps
        // the page light (no MathML duplication); the wrapper adds a
        // role="img" + aria-label (TeX source) to every equation.
        [rehypeKatexAria, { output: 'html' }],
        // Append an inline arrow (↗) to absolute external links.
        [rehypeExternalLinks, SITE],
      ],
    }),
  },
});
