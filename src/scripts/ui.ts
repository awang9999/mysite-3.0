// ---------------------------------------------------------------------------
// The site's only JavaScript (owner, 2026-11-21): theme toggle + mobile
// hamburger nav. Vanilla, dependency-free, no framework, no hydration
// (DESIGN §10). Everything else on the site stays static HTML/CSS.
// ---------------------------------------------------------------------------

const root = document.documentElement;
const systemDark = window.matchMedia('(prefers-color-scheme: dark)');

/* ---------- Theme toggle (DESIGN §8) -------------------------------------
   Priority: saved choice (localStorage) > OS preference. The CSS mirrors
   this: :root[data-theme='…'] beats the prefers-color-scheme media query.
   A pre-paint inline snippet in <head> restores the saved choice so there's
   no flash of the wrong scheme. */

const themeBtn = document.querySelector<HTMLButtonElement>('.theme-toggle');

function storedTheme(): 'light' | 'dark' | null {
  try {
    const t = localStorage.getItem('theme');
    return t === 'light' || t === 'dark' ? t : null;
  } catch {
    return null;
  }
}

function effectiveTheme(): 'light' | 'dark' {
  return storedTheme() ?? (systemDark.matches ? 'dark' : 'light');
}

// The icon shows the theme you'd switch TO (moon in light, sun in dark);
// the aria-label says the same, so screen readers hear the action.
function syncThemeButton(): void {
  if (!themeBtn) return;
  const to = effectiveTheme() === 'dark' ? 'light' : 'dark';
  themeBtn.setAttribute('aria-label', `Switch to ${to} theme`);
}

themeBtn?.addEventListener('click', () => {
  const next = effectiveTheme() === 'dark' ? 'light' : 'dark';
  try {
    localStorage.setItem('theme', next);
  } catch {
    /* storage unavailable (private mode) — toggle still works this page load */
  }
  root.dataset.theme = next;
  syncThemeButton();
});

// If the user never chose, keep the label in sync when the OS theme flips.
systemDark.addEventListener('change', syncThemeButton);
syncThemeButton();

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
