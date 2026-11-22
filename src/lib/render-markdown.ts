// Render a raw markdown string with the site's shared pipeline at build
// time. Astro 7's `render()` from astro:content only accepts content
// collection entries, so the changelog page (content/changelog.yaml `body`
// fields) renders through the processor's own runtime renderer instead.
import type { MarkdownRenderer } from '@astrojs/markdown-remark';
import { markdownProcessor } from './markdown-pipeline';

let rendererPromise: Promise<MarkdownRenderer> | null = null;

function getRenderer(): Promise<MarkdownRenderer> {
  // The site sets no shiki/smartypants/image options anywhere, so the shared
  // options bag stays empty — Astro's defaults apply, identical to the
  // pipeline the blog posts go through.
  rendererPromise ??= markdownProcessor.createRenderer({});
  return rendererPromise;
}

export async function renderMarkdown(markdown: string): Promise<string> {
  const { code } = await (await getRenderer()).render(markdown);
  return code;
}
