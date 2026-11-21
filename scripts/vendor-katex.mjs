#!/usr/bin/env node
// Vendor the KaTeX stylesheet + WOFF2 fonts from node_modules into
// public/katex/ so the DEV server can serve full KaTeX styling at
// /katex/katex.min.css (matches the href in src/pages/blog/[slug].astro).
//
// This is a dev-time convenience only: `npm run build` replaces it with a
// trimmed, glyph-subset, content-hashed copy under /assets/ (see
// finalize-katex.mjs), and the dev copy is deleted from dist.
// The directory is gitignored — it is always regenerated from the pinned
// katex version in package.json.
import { cpSync, mkdirSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, 'node_modules', 'katex', 'dist');
const out = join(root, 'public', 'katex');

mkdirSync(join(out, 'fonts'), { recursive: true });
cpSync(join(src, 'katex.min.css'), join(out, 'katex.min.css'));

let count = 0;
for (const file of readdirSync(join(src, 'fonts'))) {
  if (file.endsWith('.woff2')) {
    cpSync(join(src, 'fonts', file), join(out, 'fonts', file));
    count += 1;
  }
}

console.log(`vendor:katex — copied katex.min.css + ${count} woff2 fonts to public/katex/ (dev only)`);
