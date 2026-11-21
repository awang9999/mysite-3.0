#!/usr/bin/env node
/**
 * Post-build KaTeX finalizer (production only):
 *
 * `astro build` copies the dev-time vendored KaTeX (public/katex → dist/katex,
 * full 20-face WOFF2 set, ~1.2 MB) into dist so the build never fails. This
 * script then:
 *
 * 1. Scans the built HTML of the math pages and extracts the exact visible
 *    glyph set (text inside .katex-html subtrees — MathML/aria content needs
 *    no rendered glyphs; U+200B zero-width spaces are excluded).
 * 2. Determines which KaTeX font faces are actually referenced by parsing
 *    katex.min.css itself: every rule that sets a KaTeX font-family maps to a
 *    face (via the @font-face table); a face is kept when the classes its
 *    rule names appear in the built math markup (plus the base `.katex`
 *    rule, which always applies). No hard-coded class→face table.
 * 3. Subsets each kept face to the used glyph set with pyftsubset
 *    (fontTools), content-hashes the results, and writes them to
 *    dist/_astro/katex/ (Astro 7's asset prefix).
 * 4. Trims katex.min.css to the kept @font-face blocks (swapping the srcs to
 *    the hashed subset files and forcing font-display:swap) and writes it
 *    as dist/_astro/katex.min.<hash>.css.
 * 5. Rewrites the math pages' stylesheet href to the hashed CSS and deletes
 *    the full dev-time copy from dist/.
 *
 * Requires: python3 + fontTools (pyftsubset).
 */
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const katexSrc = join(root, 'node_modules', 'katex', 'dist');
const PLACEHOLDER = '/katex/katex.min.css';

if (!existsSync(dist)) {
  console.error('finalize-katex: no dist/ found — run `astro build` first.');
  process.exit(1);
}

// ---------- Helpers ----------
function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, files);
    else if (entry.endsWith('.html')) files.push(full);
  }
  return files;
}

function decodeEntities(s) {
  return s
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(+d))
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&');
}

/**
 * Extract every outer KaTeX span, balanced to its closing tag.
 * Matches <span class="katex"> and, after the aria pass,
 * <span class="katex" aria-label="…" role="img">. The label is serialized
 * HTML (no raw '>'), so [^>]* is safe; class="katex-html" & co. don't match
 * because the regex requires the closing quote right after 'katex'.
 */
function katexBlocks(html) {
  const blocks = [];
  const OPEN = /<span class="katex"[^>]*>/g;
  let m;
  while ((m = OPEN.exec(html)) !== null) {
    let depth = 0;
    let end = m.index;
    for (const mm of html.slice(m.index).matchAll(/<span\b|<\/span>/g)) {
      depth += mm[0] === '</span>' ? -1 : 1;
      end = m.index + mm.index + mm[0].length;
      if (depth === 0) break;
    }
    blocks.push(html.slice(m.index, end));
    OPEN.lastIndex = end;
  }
  return blocks;
}

// ---------- 1. Collect used glyphs + class tokens from the built HTML ----------
const used = new Set();
const htmlClasses = new Set();
let pageCount = 0;
for (const file of walk(dist)) {
  const html = readFileSync(file, 'utf8');
  if (!html.includes('class="katex"')) continue;
  pageCount += 1;
  for (const block of katexBlocks(html)) {
    for (const cm of block.matchAll(/class="([^"]*)"/g)) {
      for (const c of cm[1].split(/\s+/)) htmlClasses.add(c);
    }
    // Visible markup only: the .katex-html subtree (the aria-label carries
    // the raw TeX for screen readers; it is never rendered, so its text
    // needs no glyphs).
    const visibleStart = block.indexOf('<span class="katex-html"');
    if (visibleStart === -1) continue;
    const visible = block.slice(visibleStart, block.length - '</span>'.length);
    for (const ch of decodeEntities(visible.replace(/<[^>]*>/g, ''))) {
      // U+200B (zero-width space) is invisible and rendered by no font —
      // it needs no subsetted glyph.
      if (ch.codePointAt(0) === 0x200b) continue;
      used.add(ch);
    }
  }
}
if (used.size === 0) {
  console.warn('finalize-katex: no KaTeX markup found in dist — skipping.');
  rmSync(join(dist, 'katex'), { recursive: true, force: true });
  process.exit(0);
}
console.log(`finalize-katex: ${pageCount} math pages, ${used.size} unique glyphs, ${htmlClasses.size} class tokens`);

// ---------- 2. Derive the used faces from katex.min.css ----------
const css = readFileSync(join(katexSrc, 'katex.min.css'), 'utf8');

// @font-face table: "family|style|weight" -> woff2 filename.
// Minified KaTeX CSS drops the trailing ';' of single-declaration blocks, so
// the terminator is optional.
const unq = (s) => (s ?? '').trim().replace(/^"|"$/g, '');
const facesTable = {};
for (const m of css.matchAll(/@font-face\s*{([^}]*)}/g)) {
  const d = m[1];
  const fam = unq(/font-family:\s*([^;}]*)/.exec(d)?.[1]);
  const style = unq(/font-style:\s*([^;}]*)/.exec(d)?.[1]) || 'normal';
  const weight = unq(/font-weight:\s*([^;}]*)/.exec(d)?.[1]) || '400';
  const file = /url\((fonts\/[^)]+\.woff2)\)/.exec(d)?.[1]?.replace('fonts/', '');
  if (fam && file) facesTable[`${fam}|${style}|${weight}`] = file;
}

// Class rules that set a KaTeX font-family (skip @font-face blocks).
// Handles both `font-family:` declarations and the `font:` shorthand used by
// the base `.katex` rule (e.g. `font:normal 1.21em KaTeX_Main,math,...`).
function fontSpec(decl) {
  const famProp = /font-family:\s*([^;}]*)/.exec(decl)?.[1];
  if (famProp) {
    const fam = unq(famProp);
    if (!fam.startsWith('KaTeX')) return null;
    const style = unq(/font-style:\s*([^;}]*)/.exec(decl)?.[1]) || 'normal';
    const weight = unq(/font-weight:\s*([^;}]*)/.exec(decl)?.[1]) || '400';
    return { fam, style, weight };
  }
  const short = /\bfont:\s*([^;}]+)/.exec(decl)?.[1];
  if (!short) return null;
  // Everything after the size token is the family list.
  const familyPart = short.split(/\s\d(?:\.\d+)?(?:em|ex|rem|px|%|vw|vh|ch|pt|pc)\b/).pop();
  const fam = unq(familyPart.split(',')[0]);
  if (!fam.startsWith('KaTeX')) return null;
  const style = /(^|\s)(italic|oblique)\b/.test(short) ? 'italic' : 'normal';
  const weight = /\b(bold|\d{3,4})\b/.exec(short);
  return { fam, style, weight: weight ? (weight[1] === 'bold' ? '700' : weight[1]) : '400' };
}
// Comma-separated selector lists are ALTERNATIVES — each selector is
// tracked separately, so `.katex .amsrm,.katex .mathbb{…}` applies when
// EITHER class appears, not both.
const fontRules = [];
for (const m of css.matchAll(/([^{}]+)\{([^}]*)\}/g)) {
  const selector = m[1].trim();
  if (selector.startsWith('@')) continue;
  const spec = fontSpec(m[2]);
  if (!spec) continue;
  const file = facesTable[`${spec.fam}|${spec.style}|${spec.weight}`];
  for (const sel of selector.split(',')) {
    const classes = new Set();
    for (const c of sel.matchAll(/\.([a-zA-Z][\w-]*)/g)) classes.add(c[1]);
    fontRules.push({ file, classes: [...classes] });
  }
}

// A face is used when:
//  - a base rule applies to `.katex` itself (always present on math pages), or
//  - any distinctive class (i.e. not 'katex') of one of its rules appears in
//    the built math markup. (KaTeX's class names are unique per face, so
//    this never over-selects; if it ever did, the extra cost is one small
//    subsetted face.)
const keptFaces = new Map(); // woff2 filename -> reason
for (const rule of fontRules) {
  if (!rule.file) {
    console.error(`finalize-katex: font-family rule has no matching @font-face: ${rule.classes}`);
    process.exit(1);
  }
  // Multi-class rules (descendant selectors like .delimsizing.mult
  // .delim-size1>span) span elements, so requiring every distinctive class
  // to appear somewhere in the markup is the safe, precise-enough check:
  // it only ever over-selects when the classes genuinely all appear.
  const distinctive = rule.classes.filter((c) => c !== 'katex');
  const applies = distinctive.length === 0 || distinctive.every((c) => htmlClasses.has(c));
  if (applies && !keptFaces.has(rule.file)) {
    keptFaces.set(rule.file, distinctive.length === 0 ? 'base .katex rule' : `classes ${distinctive.join('+')}`);
  }
}

// ---------- 3. Subset the kept faces to the used glyph set ----------
// Astro 7 ships build assets under /_astro/ — follow the same convention so
// the deploy tiering (immutable hashed assets) covers one prefix.
const fontsDir = join(katexSrc, 'fonts');
const outDir = join(dist, '_astro', 'katex');
mkdirSync(outDir, { recursive: true });

const kept = {}; // original filename -> hashed /_astro/katex/... url
const report = [];
const usedCodes = [...used].map((ch) => ch.codePointAt(0)).sort((a, b) => a - b);
for (const [face] of [...keptFaces.entries()].sort()) {
  const tmp = join(outDir, `.${face}`);
  execFileSync(
    'pyftsubset',
    [
      join(fontsDir, face),
      `--unicodes=${usedCodes.map((cp) => `U+${cp.toString(16).toUpperCase()}`).join(',')}`,
      '--desubroutinize',
      '--flavor=woff2',
      `--output-file=${tmp}`,
    ],
    { stdio: 'ignore' },
  );
  // Hash the SUBSET bytes (content-hashed per D5).
  const subsetBytes = readFileSync(tmp);
  const hash = createHash('sha256').update(subsetBytes).digest('hex').slice(0, 8);
  const newName = `${face.slice(0, -6)}.${hash}.woff2`;
  writeFileSync(join(outDir, newName), subsetBytes);
  rmSync(tmp);
  kept[face] = `/_astro/katex/${newName}`;
  report.push({ face, reason: keptFaces.get(face), bytes: subsetBytes.length });
}
if (report.length === 0) {
  console.error('finalize-katex: no faces kept — face selection looks wrong. Aborting.');
  process.exit(1);
}

// Safety check: every used glyph must exist in at least one kept face.
// (cmap is used only here — for verification, not for selection.)
const cmaps = JSON.parse(
  execFileSync(
    'python3',
    [
      '-c',
      `
import json, sys
from fontTools.ttLib import TTFont
out = {}
for path in sys.argv[1:]:
    font = TTFont(path)
    out[path.rsplit('/', 1)[1]] = sorted(font.getBestCmap().keys())
print(json.dumps(out))
`,
      ...Object.keys(kept).map((f) => join(fontsDir, f)),
    ],
    { maxBuffer: 16 * 1024 * 1024 },
  ).toString(),
);
const missing = [...used].filter(
  (ch) => !Object.values(cmaps).some((cps) => cps.includes(ch.codePointAt(0))),
);
if (missing.length > 0) {
  console.warn(
    `finalize-katex: WARNING — ${missing.length} used glyphs missing from all kept faces: ` +
      missing.map((ch) => `U+${ch.codePointAt(0).toString(16).toUpperCase()}`).join(' '),
  );
}

// ---------- 4. Trim the CSS to the kept faces ----------
let trimmed = css;
let keptBlocks = 0;
for (const m of css.matchAll(/@font-face\s*{[^}]*}/g)) {
  const block = m[0];
  const urlMatch = block.match(/url\((fonts\/[^)]+\.woff2)\)/);
  if (!urlMatch || !kept[urlMatch[1].slice('fonts/'.length)]) continue;
  const swapped = block
    .replace('font-display:block', 'font-display:swap')
    .replace(/src:[^;}]*/, `src:url(${kept[urlMatch[1].slice('fonts/'.length)]}) format("woff2")`);
  trimmed = trimmed.replace(block, swapped);
  keptBlocks += 1;
}
if (keptBlocks !== Object.keys(kept).length) {
  console.error(`finalize-katex: CSS rewrite mismatch — kept ${keptBlocks} @font-face blocks but subsetted ${Object.keys(kept).length} faces.`);
  process.exit(1);
}
// Drop the @font-face blocks that were NOT rewritten — they still point at
// url(fonts/…) for faces we are not shipping. (Kept blocks now reference
// /_astro/katex/… URLs, so this can only match unused ones.)
const unusedBlocks = trimmed.match(/@font-face\s*\{[^}]*url\(fonts\/[^}]*\}/g) ?? [];
if (unusedBlocks.length > 0) {
  trimmed = trimmed.replace(/@font-face\s*\{[^}]*url\(fonts\/[^}]*\}/g, '');
}
if ((trimmed.match(/@font-face/g) ?? []).length !== keptBlocks) {
  console.error(`finalize-katex: expected ${keptBlocks} @font-face blocks after trim, found ${(trimmed.match(/@font-face/g) ?? []).length}.`);
  process.exit(1);
}
const cssBytes = Buffer.from(trimmed, 'utf8');
const cssPath = `/_astro/katex.min.${createHash('sha256').update(cssBytes).digest('hex').slice(0, 8)}.css`;
writeFileSync(join(dist, cssPath.slice(1)), cssBytes);

// ---------- 5. Rewrite HTML hrefs and drop the dev copy ----------
for (const file of walk(dist)) {
  const html = readFileSync(file, 'utf8');
  if (html.includes(PLACEHOLDER)) {
    writeFileSync(file, html.split(PLACEHOLDER).join(cssPath));
  }
}
rmSync(join(dist, 'katex'), { recursive: true, force: true });

// ---------- Report ----------
console.log(`\nKaTeX faces kept (${report.length} of ${readdirSync(fontsDir).filter((f) => f.endsWith('.woff2')).length}):`);
for (const { face, reason, bytes } of report) {
  console.log(`  ${face.padEnd(32)} ${(bytes / 1024).toFixed(1).padStart(6)} KB  (${reason})`);
}
const total = report.reduce((n, r) => n + r.bytes, 0);
console.log(`  fonts total: ${(total / 1024).toFixed(1)} KB`);
console.log(`  css: ${cssPath} — ${(cssBytes.length / 1024).toFixed(1)} KB`);
console.log(`  pages referencing katex css: ${pageCount}`);
