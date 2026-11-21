// Typed loaders for the YAML data files in content/ (editor-owned).
// content/ stays the single source of truth — nothing here is a copy.
// Build-time only: the module runs during `astro dev`/`astro build`, both of
// which run with cwd = the project root.
import fs from 'node:fs';
import path from 'node:path';
import { load as parseYaml } from 'js-yaml';

export interface SiteLink {
  label: string;
  href: string;
  external?: boolean;
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
}

export interface ExperienceFile {
  lead?: string;
  entries: ExperienceEntry[];
}

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
export const experience = loadYaml<ExperienceFile>('experience.yaml');
export const projects = loadYaml<ProjectsFile>('projects.yaml');
export const blogIndex = loadYaml<BlogIndexFile>('blog/index.yaml');

// Nav label for a given path (used as the page h1 on subpages).
export function navLabelFor(path: string): string {
  return site.nav.find((item) => item.href === path)?.label ?? path;
}
