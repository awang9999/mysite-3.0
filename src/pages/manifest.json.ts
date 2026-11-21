// Web app manifest — the minimal one (3.8): name, colors, start_url.
// Emitted at build time (not a static file) so name/description come from
// content/site.yaml — the single source of truth.
// Colors are the light `--bg` token (DESIGN §1); a manifest has no media
// query, so it carries the base (light) scheme. The only icon is the SVG
// favicon — no raster icons (DESIGN §9.13).
import type { APIRoute } from 'astro';
import { site } from '../lib/data';

export const GET: APIRoute = () =>
  new Response(
    JSON.stringify(
      {
        name: site.title,
        description: site.description,
        start_url: '/',
        scope: '/',
        display: 'standalone',
        background_color: '#faf9f6', // --bg (light, DESIGN §1)
        theme_color: '#faf9f6', // --bg (light, DESIGN §1)
        icons: [
          { src: '/favicon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
        ],
      },
      null,
      2,
    ),
    { headers: { 'content-type': 'application/manifest+json; charset=utf-8' } },
  );
