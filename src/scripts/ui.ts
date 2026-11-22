// ---------------------------------------------------------------------------
// The site's only JavaScript (owner, 2026-11-21): theme toggle + mobile
// hamburger nav. Vanilla, dependency-free, no framework, no hydration
// (DESIGN §10). Everything else on the site stays static HTML/CSS.
// ---------------------------------------------------------------------------

const root = document.documentElement;

/* ---------- Theme picker (DESIGN §8) --------------------------------------
   Three choices: auto (follow the OS), light, dark. Stored in
   localStorage under 'theme' as 'auto' | 'light' | 'dark' — the old
   two-state 'light'/'dark' values are valid choices, so nothing migrates.
   - auto  → no data-theme on <html>; the CSS prefers-color-scheme media
             query decides (works with no JS at all, and tracks live OS
             flips for free).
   - light/dark → data-theme set; beats the media query.
   data-choice on <html> drives the button icon (auto = monitor, light =
   sun, dark = moon) and is set pre-paint by the <head> snippet, so the
   icon is right on the first frame. This module re-asserts both and wires
   the dropdown (open/close + selection). */

type ThemeChoice = 'auto' | 'light' | 'dark';

const themeBtn = document.querySelector<HTMLButtonElement>('.theme-toggle');
const themePicker = document.querySelector<HTMLElement>('.theme-picker');
const themeItems = Array.from(
  document.querySelectorAll<HTMLButtonElement>('.theme-menu [data-value]'),
);

function storedChoice(): ThemeChoice {
  try {
    const t = localStorage.getItem('theme');
    if (t === 'auto' || t === 'light' || t === 'dark') return t;
  } catch {
    /* storage unavailable (private mode) — fall back to auto */
  }
  return 'auto';
}

function applyChoice(choice: ThemeChoice, save: boolean): void {
  if (choice === 'auto') delete root.dataset.theme;
  else root.dataset.theme = choice;
  root.dataset.choice = choice;
  if (save) {
    try {
      localStorage.setItem('theme', choice);
    } catch {
      /* storage unavailable (private mode) — choice still works this page load */
    }
  }
  themeBtn?.setAttribute('aria-label', `Theme: ${choice === 'auto' ? 'automatic' : choice}`);
  themeItems.forEach((item) =>
    item.setAttribute('aria-checked', String(item.dataset.value === choice)),
  );
}

function setThemeMenuOpen(open: boolean): void {
  if (!themePicker) return;
  themePicker.dataset.open = String(open);
  themeBtn?.setAttribute('aria-expanded', String(open));
}

themeBtn?.addEventListener('click', () =>
  setThemeMenuOpen(themePicker?.dataset.open !== 'true'),
);

themeItems.forEach((item) =>
  item.addEventListener('click', () => {
    applyChoice(item.dataset.value as ThemeChoice, true);
    setThemeMenuOpen(false);
    themeBtn?.focus();
  }),
);

// Close the theme menu on Escape or a click outside it.
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') setThemeMenuOpen(false);
});
document.addEventListener('click', (event) => {
  if (themePicker?.dataset.open === 'true' && !themePicker.contains(event.target as Node)) {
    setThemeMenuOpen(false);
  }
});

applyChoice(storedChoice(), false);

/* ---------- Mobile hamburger nav (DESIGN §4) ------------------------------ */

const nav = document.querySelector<HTMLElement>('.nav');
const burger = document.querySelector<HTMLButtonElement>('.nav-burger');

function setMenuOpen(open: boolean): void {
  if (!nav || !burger) return;
  nav.dataset.open = String(open);
  burger.setAttribute('aria-expanded', String(open));
  burger.setAttribute('aria-label', open ? 'Close menu' : 'Menu');
}

burger?.addEventListener('click', () => setMenuOpen(nav?.dataset.open !== 'true'));

// Close on navigation, Escape, or a click outside the header.
document.querySelectorAll('#nav-links a').forEach((link) =>
  link.addEventListener('click', () => setMenuOpen(false))
);
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') setMenuOpen(false);
});
document.addEventListener('click', (event) => {
  if (nav?.dataset.open === 'true' && !nav.contains(event.target as Node)) {
    setMenuOpen(false);
  }
});
