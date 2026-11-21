/**
 * rehype-katex wrapper that keeps KaTeX's HTML output but adds accessible
 * names: html-only output ships no MathML and no aria-label, so each .katex
 * element gets role="img" with the TeX source as aria-label. (A full
 * MathML pass would be more accessible but roughly doubles the math bytes —
 * the page budget is why we stay HTML-only; see TODOS.md 2.2 report.)
 *
 * Works by capturing the TeX sources in document order before katex
 * replaces the math elements, then labeling the generated .katex elements
 * in the same order.
 */
import rehypeKatex from 'rehype-katex';
import { toText } from 'hast-util-to-text';
import { visit } from 'unist-util-visit';
import type { Plugin } from 'unified';

const classNameOf = (el: { properties?: Record<string, unknown> }): string[] => {
  const cls = el.properties?.className;
  return Array.isArray(cls) ? (cls as string[]) : [];
};

const isMathSource = (el: { properties?: Record<string, unknown> }) => {
  const cls = classNameOf(el);
  return cls.includes('math-inline') || cls.includes('math-display');
};

const isKatexOuter = (el: { properties?: Record<string, unknown> }) => {
  const cls = classNameOf(el);
  return (
    cls.includes('katex') &&
    !cls.includes('katex-html') &&
    !cls.includes('katex-display') &&
    !cls.includes('katex-mathml')
  );
};

export default function rehypeKatexAria(
  katexOptions?: Record<string, unknown>,
): Plugin<[], never> {
  const katex = rehypeKatex(katexOptions as never);
  return (tree: never, file: never) => {
    const sources: string[] = [];
    visit(tree, 'element', (el: { properties?: Record<string, unknown> }) => {
      if (isMathSource(el)) {
        sources.push(toText(el as never, { whitespace: 'pre' }));
      }
    });
    katex(tree as never, file);
    let i = 0;
    visit(tree, 'element', (el: { properties?: Record<string, unknown> }) => {
      if (isKatexOuter(el)) {
        const src = sources[i++];
        if (src) {
          el.properties!['aria-label'] = src;
          el.properties!.role = 'img';
        }
      }
    });
  };
}
