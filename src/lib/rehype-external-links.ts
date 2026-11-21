// Rehype plugin: mark absolute http(s) links that leave the site as
// external (target="_blank") and append the DESIGN §7 external-link arrow.
// mailto:, relative, and same-origin links are untouched.
// Registered in astro.config.mjs as [rehypeExternalLinks, SITE_ORIGIN].
import type { Element, Root } from 'hast';

const ARROW: Element = {
  type: 'element',
  tagName: 'span',
  properties: { class: 'ext-arrow', 'aria-hidden': 'true' },
  children: [
    {
      type: 'element',
      tagName: 'svg',
      properties: {
        viewBox: '0 0 12 12',
        width: '0.7em',
        height: '0.7em',
        fill: 'none',
        stroke: 'currentColor',
        'stroke-width': 1.5,
        'aria-hidden': true,
      },
      children: [
        {
          type: 'element',
          tagName: 'path',
          properties: { d: 'M3.5 8.5L8.5 3.5M4.5 3.5h4v4' },
          children: [],
        },
      ],
    },
  ],
};

function visit(node: Root | Element, origin: string): void {
  if (node.type !== 'element' && node.type !== 'root') return;
  for (const child of node.children) {
    if (child.type !== 'element') continue;
    if (child.tagName === 'a') {
      const href = child.properties?.href;
      if (typeof href === 'string' && /^https?:\/\//i.test(href) && !href.startsWith(origin)) {
        child.properties = {
          ...child.properties,
          target: '_blank',
          rel: 'noopener noreferrer',
        };
        child.children.push(structuredClone(ARROW));
      }
    }
    visit(child, origin);
  }
}

export default function rehypeExternalLinks(origin = 'https://alexander-wang.net') {
  return (tree: Root): void => {
    visit(tree, origin);
  };
}
