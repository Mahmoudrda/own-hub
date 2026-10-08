// Shared helpers for the review kit. No dependencies beyond Node 20+.
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

export const WORKDIR = process.env.REVIEW_WORKDIR || '.ai-review';
export const MARKER = 'ai-review-kit';

export const REVIEWERS = {
  security: { label: 'Security', icon: '🛡️' },
  ux: { label: 'UX', icon: '🧭' },
  ui: { label: 'UI & accessibility', icon: '🎨' },
  scalability: { label: 'Scalability', icon: '📈' },
};

export const SEVERITIES = ['critical', 'high', 'medium', 'low'];
export const SEVERITY_ICON = { critical: '🔴', high: '🟠', medium: '🟡', low: '🔵' };

export function git(args, opts = {}) {
  return execFileSync('git', args, {
    encoding: 'utf8',
    maxBuffer: 512 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
    ...opts,
  });
}

export function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

export function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value, null, 2));
}

export function setOutput(name, value) {
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${String(value).replace(/\n/g, ' ')}\n`);
  }
}

export function notice(level, message) {
  // level: notice | warning | error. Shows as an annotation in GitHub Actions.
  console.log(process.env.GITHUB_ACTIONS ? `::${level}::${message}` : `[${level}] ${message}`);
}

// Stable id for a finding, so re-reviews of the same PR do not repost it.
export function fingerprint(f) {
  const title = String(f.title || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  return crypto
    .createHash('sha1')
    .update([f.reviewer, f.file, f.category, title].join('|'))
    .digest('hex')
    .slice(0, 12);
}

// [1,2,3,7,8] -> "1-3, 7-8"
export function toRanges(nums) {
  const out = [];
  let start = null;
  let prev = null;
  for (const n of [...new Set(nums)].sort((a, b) => a - b)) {
    if (start === null) {
      start = prev = n;
    } else if (n === prev + 1) {
      prev = n;
    } else {
      out.push(start === prev ? `${start}` : `${start}-${prev}`);
      start = prev = n;
    }
  }
  if (start !== null) out.push(start === prev ? `${start}` : `${start}-${prev}`);
  return out.join(', ');
}

const IGNORE = [
  /(^|\/)(node_modules|vendor|dist|build|out|\.next|\.nuxt|\.svelte-kit|coverage|__snapshots__|\.dart_tool|Pods|target|\.venv|venv|__pycache__)\//,
  /(^|\/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|Cargo\.lock|poetry\.lock|uv\.lock|Gemfile\.lock|composer\.lock|pubspec\.lock|go\.sum)$/,
  /\.(min\.(js|css)|map|png|jpe?g|gif|webp|avif|ico|svg|pdf|woff2?|ttf|otf|eot|mp4|mov|webm|mp3|wav|zip|gz|tgz|tar|jar|bin|exe|dll|so|dylib|snap)$/i,
  /\.(g|freezed|gen|pb)\.(dart|go|ts|js)$/,
  /_pb2(_grpc)?\.py$/,
  /^\.github\/review-kit\//,
  /^\.ai-review\//,
];

const DOCS = /\.(md|mdx?|markdown|txt|rst|adoc)$/i;
const STYLE = /\.(css|scss|sass|less|styl)$/i;
const FRONTEND_EXT =
  /\.(tsx|jsx|vue|svelte|astro|html?|css|scss|sass|less|styl|erb|ejs|hbs|handlebars|njk|liquid|twig|dart|swift|kt|xib|storyboard)$/i;
const FRONTEND_PATH =
  /(^|\/)(components?|pages|views|screens|widgets|ui|layouts?|templates|frontend|client|web|public|static|app)\//i;
const SCRIPT_EXT = /\.(ts|js|mjs|cjs|php)$/i;

export function isIgnored(file) {
  return IGNORE.some((re) => re.test(file));
}

// Decide which reviewers a file is relevant to.
export function classify(file) {
  if (DOCS.test(file)) return { kind: 'docs', reviewers: [] };
  const blade = /\.blade\.php$/i.test(file);
  const frontend = blade || FRONTEND_EXT.test(file) || (SCRIPT_EXT.test(file) && FRONTEND_PATH.test(file));
  if (STYLE.test(file)) return { kind: 'style', reviewers: ['ux', 'ui'] };
  if (frontend) return { kind: 'frontend', reviewers: ['security', 'ux', 'ui', 'scalability'] };
  return { kind: 'code', reviewers: ['security', 'scalability'] };
}

// Parse a unified diff for one file into new-file line numbers.
// `added` are lines the change introduced; `commentable` are lines GitHub
// accepts for an inline review comment (anything inside a hunk).
export function parseHunks(diff) {
  const added = [];
  const commentable = [];
  const rows = [];
  let line = 0;
  let inHunk = false;
  for (const raw of diff.split('\n')) {
    const m = raw.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$/);
    if (m) {
      line = Number(m[1]);
      inHunk = true;
      rows.push({ type: 'hunk', text: m[2].trim() });
      continue;
    }
    if (!inHunk) continue;
    if (raw.startsWith('+')) {
      added.push(line);
      commentable.push(line);
      rows.push({ type: '+', line, text: raw.slice(1) });
      line++;
    } else if (raw.startsWith('-')) {
      rows.push({ type: '-', text: raw.slice(1) });
    } else if (raw.startsWith(' ')) {
      commentable.push(line);
      rows.push({ type: ' ', line, text: raw.slice(1) });
      line++;
    }
  }
  return { added, commentable, rows };
}

// Render hunks with the new-file line number on every line, so reviewers
// never have to compute line numbers from hunk headers.
export function annotate(file, rows, maxRows = 1500) {
  const out = [`FILE: ${file}`, 'Columns: marker | line number in the NEW file | code', ''];
  let n = 0;
  for (const r of rows) {
    if (n++ >= maxRows) {
      out.push(`... patch truncated after ${maxRows} rows; read the file itself for the rest ...`);
      break;
    }
    if (r.type === 'hunk') out.push(`@@ ${r.text}`);
    else if (r.type === '-') out.push(`-       | ${r.text}`);
    else out.push(`${r.type} ${String(r.line).padStart(5)} | ${r.text}`);
  }
  return out.join('\n') + '\n';
}

// Minimal GitHub REST client. Only context.mjs and post.mjs use it; the
// review step never receives a GitHub token.
export async function gh(method, url, body) {
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (!token) throw new Error('No GitHub token available');
  const base = process.env.GITHUB_API_URL || 'https://api.github.com';
  const res = await fetch(url.startsWith('http') ? url : base + url, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      accept: 'application/vnd.github+json',
      'x-github-api-version': '2022-11-28',
      'user-agent': MARKER,
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    const err = new Error(`GitHub ${method} ${url} -> ${res.status}: ${text.slice(0, 400)}`);
    err.status = res.status;
    throw err;
  }
  return data;
}

export async function ghAll(url, maxPages = 5) {
  const out = [];
  for (let page = 1; page <= maxPages; page++) {
    const sep = url.includes('?') ? '&' : '?';
    const batch = await gh('GET', `${url}${sep}per_page=100&page=${page}`);
    if (!Array.isArray(batch) || batch.length === 0) break;
    out.push(...batch);
    if (batch.length < 100) break;
  }
  return out;
}
