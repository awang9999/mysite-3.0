// Astro 7 config — mysite-3.0
// Stack decisions: docs/HOSTING.md D3 (MPP, real URLs), D11 (build-time
// KaTeX), D12 (Astro), DESIGN §10 (zero JS).
// The markdown pipeline itself lives in src/lib/markdown-pipeline.ts so the
// changelog page can render raw markdown strings with the exact same one.
import { defineConfig } from 'astro/config';
import { markdownProcessor, SITE_ORIGIN } from './src/lib/markdown-pipeline.ts';

export default defineConfig({
  site: SITE_ORIGIN,
  markdown: {
    processor: markdownProcessor,
  },
});
