// Typed loaders for the YAML data files in content/ (editor-owned).
// content/ stays the single source of truth — nothing here is a copy.
// Build-time only: the module runs during `astro dev`/`astro build`, both of
// which run with cwd = the project root.
import fs from 'node:fs';
import path from 'node:path';
import { load as parseYaml } from 'js-yaml';

// Company logos for experience entries (owner, 2026-11-21). 64 px square
// PNGs, ~3 KB each, filling a 48 px chip edge to edge (object-fit: cover).
// Keys are referenced from content/experience.yaml (`logo:`).
import logoAws from '../assets/logo-aws.png';
import logoAmazonMusic from '../assets/logo-amazon-music.png';
import logoCornell from '../assets/logo-cornell.png';
import logoTae from '../assets/logo-tae.png';

export interface SiteLink {
  label: string;
  href: string;
  external?: boolean;
  /** Open in a new tab (owner 2026-11-22: the résumé link). */
  newTab?: boolean;
}

export interface Site {
  title: string;
  description: string;
  author: string;
  email: string;
  resume: { href: string };
  nav: SiteLink[];
  footer: { copyright: string; links: SiteLink[] };
  socials: Record<string, string>;
}

export interface ExperienceEntry {
  role: string;
  company?: string;
  location?: string;
  dates: string;
  bullets: string[];
  links?: SiteLink[];
  logo?: string;
  /** Resolved at load time (see LOGOS) — Astro asset import, not a string. */
  logoAsset?: { src: string; width: number; height: number };
}

export interface ExperienceFile {
  entries: ExperienceEntry[];
}

const LOGOS: Record<string, { src: string; width: number; height: number }> = {
  aws: logoAws,
  'amazon-music': logoAmazonMusic,
  cornell: logoCornell,
  tae: logoTae,
};

export interface FeaturedProject {
  name: string;
  hook: string;
  body?: string;
  tags?: string[];
  links?: SiteLink[];
  year: number;
}

export interface ArchivedProject {
  name: string;
  line: string;
  year: number;
  links?: SiteLink[];
}

export interface ProjectsFile {
  lead?: string;
  featured: FeaturedProject[];
  archive: ArchivedProject[];
}

export interface BlogIndexPost {
  slug: string;
  title: string;
  date: string;
  summary: string;
  readingTime: number;
  series?: string;
  part?: number;
}

export interface BlogIndexFile {
  lead?: string;
  posts: BlogIndexPost[];
}

const contentDir = path.resolve(process.cwd(), 'content');

function loadYaml<T>(relativePath: string): T {
  const file = path.join(contentDir, relativePath);
  return parseYaml(fs.readFileSync(file, 'utf8')) as T;
}

export const site = loadYaml<Site>('site.yaml');
const experienceRaw = loadYaml<ExperienceFile>('experience.yaml');
// Resolve the `logo` key to an Astro asset import (Astro 7: asset imports
// are { src, width, height } objects, not strings).
export const experience: ExperienceFile = {
  ...experienceRaw,
  entries: experienceRaw.entries.map((entry) =>
    entry.logo
      ? { ...entry, logoAsset: LOGOS[entry.logo] }
      : { ...entry },
  ),
};
export const projects = loadYaml<ProjectsFile>('projects.yaml');
export const blogIndex = loadYaml<BlogIndexFile>('blog/index.yaml');

// Nav label for a given path (used as the page h1 on subpages).
export function navLabelFor(path: string): string {
  return site.nav.find((item) => item.href === path)?.label ?? path;
}
