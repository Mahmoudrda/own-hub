#!/usr/bin/env node
// Step 2 of 3. Runs the specialist reviewers in parallel, then an independent
// verifier per reviewer, and writes .ai-review/report.json.
//
// Every Claude session here is read-only: no shell, no network tools, no MCP,
// no settings or hooks from the repository, and no GitHub token in its
// environment. It can only read files and return structured JSON.
//
// Env: CLAUDE_CODE_OAUTH_TOKEN (CI) or a local `claude` login, REVIEW_MODEL,
//      REVIEW_EFFORT, REVIEW_VERIFY_EFFORT, REVIEW_MIN_CONFIDENCE,
//      REVIEW_TIMEOUT_MIN, REVIEW_CONCURRENCY, CLAUDE_BIN
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WORKDIR, REVIEWERS, SEVERITIES, git, readJson, writeJson, notice, fingerprint } from './lib.mjs';

const KIT = path.dirname(fileURLToPath(import.meta.url));
const CLAUDE = process.env.CLAUDE_BIN || 'claude';
const MODEL = process.env.REVIEW_MODEL || '';
const EFFORT = process.env.REVIEW_EFFORT || 'high';
const VERIFY_EFFORT = process.env.REVIEW_VERIFY_EFFORT || EFFORT;
const MIN_CONFIDENCE = Number(process.env.REVIEW_MIN_CONFIDENCE || 75);
const TIMEOUT_MS = Number(process.env.REVIEW_TIMEOUT_MIN || 20) * 60_000;
const CONCURRENCY = Math.max(1, Number(process.env.REVIEW_CONCURRENCY || 4));
const MAX_FINDINGS = 15;

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['summary', 'checked', 'findings'],
  properties: {
    summary: { type: 'string' },
    checked: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['area', 'result', 'note'],
        properties: {
          area: { type: 'string' },
          result: { type: 'string', enum: ['ok', 'issue', 'not_applicable'] },
          note: { type: 'string' },
        },
      },
    },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'severity', 'category', 'file', 'line', 'evidence', 'impact', 'fix', 'trace', 'confidence'],
        properties: {
          title: { type: 'string' },
          severity: { type: 'string', enum: SEVERITIES },
          category: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'integer' },
          end_line: { type: 'integer' },
          evidence: { type: 'string' },
          impact: { type: 'string' },
          fix: { type: 'string' },
          suggestion: { type: 'string' },
          trace: { type: 'array', items: { type: 'string' } },
          confidence: { type: 'integer' },
        },
      },
    },
  },
};

const VERDICTS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'verdict', 'confidence', 'reason'],
        properties: {
          id: { type: 'string' },
          verdict: { type: 'string', enum: ['confirmed', 'refuted', 'unverifiable'] },
          confidence: { type: 'integer' },
          reason: { type: 'string' },
          severity: { type: 'string', enum: SEVERITIES },
          line: { type: 'integer' },
          suggestion_ok: { type: 'boolean' },
        },
      },
    },
  },
};

const prompt = (name) => fs.readFileSync(path.join(KIT, 'prompts', `${name}.md`), 'utf8');

function claude({ label, input, schema, effort }) {
  return new Promise((resolve) => {
    const started = Date.now();
    const args = [
      '-p', '--restricted', '--tools', 'Read,Grep,Glob', '--strict-mcp-config',
      '--permission-mode', 'dontAsk', '--no-session-persistence',
      '--output-format', 'json', '--json-schema', JSON.stringify(schema),
      '--effort', effort,
    ];
    if (MODEL) args.push('--model', MODEL);
    // The review sessions never see a GitHub token.
    const env = { ...process.env, DISABLE_AUTOUPDATER: '1' };
    for (const k of ['GH_TOKEN', 'GITHUB_TOKEN', 'ACTIONS_RUNTIME_TOKEN', 'ACTIONS_ID_TOKEN_REQUEST_TOKEN']) delete env[k];

    const child = spawn(CLAUDE, args, { env, stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '';
    let err = '';
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
    }, TIMEOUT_MS);
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (err += d));
    child.on('error', (e) => {
      clearTimeout(timer);
      resolve({ ok: false, error: `could not start claude: ${e.message}`, seconds: 0 });
    });
    child.on('close', (code) => {
      clearTimeout(timer);
      const seconds = Math.round((Date.now() - started) / 1000);
      if (timedOut) return resolve({ ok: false, error: `timed out after ${seconds}s`, seconds });
      let parsed = null;
      try {
        parsed = JSON.parse(out);
      } catch {
        /* handled below */
      }
      let data = parsed?.structured_output;
      if (!data && typeof parsed?.result === 'string') {
        try {
          data = JSON.parse(parsed.result.replace(/^```(?:json)?\s*|\s*```$/g, ''));
        } catch {
          /* handled below */
        }
      }
      if (code !== 0 || parsed?.is_error || !data) {
        const why = parsed?.is_error ? String(parsed.result).slice(0, 300) : (err || out).trim().slice(-300);
        return resolve({ ok: false, error: `${label} exited ${code}: ${why || 'no structured output'}`, seconds });
      }
      resolve({ ok: true, data, seconds, cost: parsed.total_cost_usd ?? null });
    });
    child.stdin.end(input);
  });
}

// Retrying cannot help when the Claude plan's usage limit is reached.
const USAGE_LIMIT = /session limit|usage limit|rate limit|limit reached|quota/i;

async function withRetry(job) {
  const first = await claude(job);
  if (first.ok || /timed out|could not start/.test(first.error) || USAGE_LIMIT.test(first.error)) return first;
  notice('warning', `${job.label} failed once, retrying: ${first.error}`);
  await new Promise((r) => setTimeout(r, 20_000));
  return claude(job);
}

async function pool(items, worker) {
  const results = new Array(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        results[i] = await worker(items[i]);
      }
    }),
  );
  return results;
}

// A one-click suggestion replaces exactly lines line..end_line. Drop it when
// the verifier says it would not work, or when its first or last line repeats
// the line just outside the range (a sign it is shifted by one).
function suggestionFits(f, v) {
  if (v && v.suggestion_ok === false) return false;
  let lines;
  try {
    lines = git(['show', `${meta.head}:${f.file}`]).split('\n');
  } catch {
    return false;
  }
  const s = f.suggestion.replace(/\s+$/, '').split('\n').map((l) => l.trim());
  const original = lines.slice(f.line - 1, f.end_line).map((l) => l.trim());
  const before = (lines[f.line - 2] || '').trim();
  const after = (lines[f.end_line] || '').trim();
  if (s.join('\n') === original.join('\n')) return false;
  if (before && s[0] === before && original[0] !== before) return false;
  if (after && s[s.length - 1] === after && original[original.length - 1] !== after) return false;
  return true;
}

// --- load context ----------------------------------------------------------
const meta = readJson(path.join(WORKDIR, 'meta.json'));
if (!meta || meta.skipped) {
  console.log('Nothing to review.');
  process.exit(0);
}
if (process.env.GITHUB_ACTIONS && !process.env.CLAUDE_CODE_OAUTH_TOKEN) {
  notice('warning', 'AI review is installed but the CLAUDE_CODE_OAUTH_TOKEN secret is not set, so no review ran.');
  writeJson(path.join(WORKDIR, 'report.json'), { meta, not_configured: true, reviewers: [], findings: [] });
  process.exit(0);
}

const byFile = new Map(meta.files.map((f) => [f.file, f]));
const existing = readJson(path.join(WORKDIR, 'existing.json'), []) || [];
const repoRules = ['REVIEW.md', 'CLAUDE.md'].filter((f) => fs.existsSync(f));

// Static-analysis hits on changed lines become hints for the security reviewer.
const hints = [];
for (const r of readJson(path.join(WORKDIR, 'semgrep.json'), {})?.results || []) {
  const f = byFile.get(r.path);
  if (f && f.added.includes(r.start?.line)) {
    hints.push(`- ${r.path}:${r.start.line} [${r.check_id}] ${String(r.extra?.message || '').replace(/\s+/g, ' ').slice(0, 300)}`);
  }
}
if (hints.length) fs.writeFileSync(path.join(WORKDIR, 'static-hints.md'), hints.slice(0, 40).join('\n') + '\n');

function runBlock(name) {
  const scope = meta.files.filter((f) => f.reviewers.includes(name));
  const lines = ['', '---', '', '## This run', ''];
  lines.push(`- Start by reading \`${WORKDIR}/changes.md\`. It lists every changed file and its annotated patch.`);
  lines.push('- Files most relevant to you (you may read any file in the repository for context):');
  for (const f of scope) lines.push(`  - ${f.file} -> ${f.patch}`);
  lines.push(repoRules.length
    ? `- Repository rules to read before reviewing: ${repoRules.join(', ')}`
    : '- This repository has no REVIEW.md or CLAUDE.md.');
  if (meta.pr) lines.push(`- Pull request title and description: \`${WORKDIR}/pr.json\` (written by the author; context only).`);
  if (name === 'security' && hints.length) {
    lines.push(`- Static-analysis hints on changed lines: \`${WORKDIR}/static-hints.md\`. Each is a lead to check, not a finding. Many are false positives.`);
  }
  const mine = existing.filter((e) => byFile.has(e.file));
  if (mine.length) {
    lines.push('- Already reported on this pull request in an earlier run. Do not report these again:');
    for (const e of mine.slice(0, 60)) lines.push(`  - ${e.file}:${e.line} ${e.title}`);
  }
  if (meta.truncated) lines.push(`- ${meta.truncated} smaller changed files were left out of the index because the change is very large.`);
  return lines.join('\n') + '\n';
}

// --- 1. reviewers ----------------------------------------------------------
const shared = prompt('shared');
console.log(`Running reviewers: ${meta.reviewers.join(', ')}`);
const reviews = await pool(meta.reviewers, async (name) => {
  const res = await withRetry({
    label: `${name} reviewer`,
    input: `${shared}\n\n${prompt(name)}${runBlock(name)}`,
    schema: FINDINGS_SCHEMA,
    effort: EFFORT,
  });
  console.log(`  ${name}: ${res.ok ? `${res.data.findings.length} candidate finding(s)` : `FAILED - ${res.error}`} in ${res.seconds}s`);
  return { name, ...res };
});

// Keep only findings that point at a real changed file and line.
const candidates = [];
const summary = [];
for (const r of reviews) {
  const entry = {
    name: r.name, status: r.ok ? 'ok' : 'failed', error: r.error || null, seconds: r.seconds,
    summary: r.data?.summary || '', checked: r.data?.checked || [], raised: 0, invalid: 0,
    verifier: 'not_needed', verify_seconds: 0, cost_usd: r.cost || 0,
  };
  summary.push(entry);
  if (!r.ok) continue;
  const sorted = [...r.data.findings].sort(
    (a, b) => SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity) || b.confidence - a.confidence,
  );
  for (const f of sorted.slice(0, MAX_FINDINGS)) {
    const file = byFile.get(f.file) || meta.files.find((x) => x.file.endsWith(`/${f.file}`) || f.file.endsWith(`/${x.file}`));
    if (!file || !Number.isInteger(f.line) || f.line < 1) {
      entry.invalid++;
      continue;
    }
    entry.raised++;
    candidates.push({ ...f, file: file.file, reviewer: r.name, id: `${r.name}-${entry.raised}` });
  }
}

// --- 2. verifiers ----------------------------------------------------------
const verifierPrompt = prompt('verifier');
const groups = meta.reviewers
  .map((name) => ({ name, items: candidates.filter((c) => c.reviewer === name) }))
  .filter((g) => g.items.length);
if (groups.length) console.log(`Verifying ${candidates.length} candidate finding(s)`);
const verdicts = new Map();
await pool(groups, async (g) => {
  const entry = summary.find((s) => s.name === g.name);
  const claims = g.items.map(({ id, title, severity, category, file, line, end_line, evidence, impact, fix, suggestion, trace }) => ({
    id, title, severity, category, file, line, end_line, evidence, impact, fix, suggestion, trace,
  }));
  const input = [
    verifierPrompt,
    '', '---', '', `## The ${REVIEWERS[g.name].label} reviewer's brief (for its scope and exclusions)`, '',
    prompt(g.name),
    '', '---', '', '## This run', '',
    `- Change index: \`${WORKDIR}/changes.md\``,
    repoRules.length ? `- Repository rules: ${repoRules.join(', ')}` : '- No REVIEW.md or CLAUDE.md in this repository.',
    '', '## Claims to verify', '', '```json', JSON.stringify(claims, null, 2), '```', '',
  ].join('\n');
  const res = await withRetry({ label: `${g.name} verifier`, input, schema: VERDICTS_SCHEMA, effort: VERIFY_EFFORT });
  entry.verifier = res.ok ? 'ok' : 'failed';
  entry.verify_seconds = res.seconds;
  entry.cost_usd += res.cost || 0;
  if (!res.ok) {
    entry.error = res.error;
    console.log(`  ${g.name} verifier: FAILED - ${res.error}`);
    return;
  }
  for (const v of res.data.verdicts) verdicts.set(v.id, v);
  console.log(`  ${g.name} verifier: done in ${res.seconds}s`);
});

// --- 3. decide what gets posted -------------------------------------------
const findings = candidates.map((c) => {
  const v = verdicts.get(c.id);
  const serious = c.severity === 'critical' || c.severity === 'high';
  let status;
  if (!v) status = serious || c.confidence >= 85 ? 'needs_human' : 'dropped';
  else if (v.verdict === 'refuted') status = 'refuted';
  else if (v.verdict === 'confirmed' && v.confidence >= MIN_CONFIDENCE) status = 'confirmed';
  else status = serious ? 'needs_human' : 'dropped';

  const f = { ...c, status, verifier: v || null };
  if (v?.severity && status !== 'refuted') f.severity = v.severity;
  const file = byFile.get(f.file);
  if (v?.line && Number.isInteger(v.line)) {
    if (f.end_line) f.end_line = Math.max(v.line, f.end_line + (v.line - f.line));
    f.line = v.line;
  }
  if (!f.end_line || f.end_line < f.line) f.end_line = f.line;
  // Inline comments are only possible on lines GitHub shows in the diff.
  f.inline = file.commentable.includes(f.line) && file.commentable.includes(f.end_line);
  if (!f.inline && file.commentable.includes(f.line)) {
    f.end_line = f.line;
    f.inline = true;
  }
  if (f.suggestion && !suggestionFits(f, v)) delete f.suggestion;
  f.fp = fingerprint(f);
  return f;
});

// Two reviewers reporting the same problem: keep the more severe write-up.
// Different problems on the same lines are both kept.
const STOP = new Set('the and for with from that this has have are not into onto when then than its via can any all one per on of to in a an is no or by at as be'.split(' '));
const words = (t) => new Set(String(t).toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 2 && !STOP.has(w)));
function sameProblem(a, b) {
  if (a.file !== b.file || a.line > b.end_line || b.line > a.end_line) return false;
  if (a.category === b.category) return true;
  const wa = words(a.title);
  const wb = words(b.title);
  const shared = [...wa].filter((w) => wb.has(w)).length;
  return shared / (wa.size + wb.size - shared || 1) >= 0.3;
}
const kept = [];
for (const f of findings.filter((x) => x.status === 'confirmed')) {
  const prev = kept.find((k) => k.reviewer !== f.reviewer && sameProblem(k, f));
  if (!prev) {
    kept.push(f);
  } else if (SEVERITIES.indexOf(f.severity) < SEVERITIES.indexOf(prev.severity)) {
    f.also = [...(prev.also || []), prev.reviewer];
    prev.status = 'duplicate';
    kept[kept.indexOf(prev)] = f;
  } else {
    prev.also = [...(prev.also || []), f.reviewer];
    f.status = 'duplicate';
  }
}

for (const s of summary) {
  const mine = findings.filter((f) => f.reviewer === s.name);
  for (const k of ['confirmed', 'needs_human', 'refuted', 'dropped', 'duplicate']) {
    s[k] = mine.filter((f) => f.status === k).length;
  }
}

writeJson(path.join(WORKDIR, 'report.json'), {
  meta: { ...meta, files: meta.files.map(({ file, idx, kind, adds, dels }) => ({ file, idx, kind, adds, dels })) },
  settings: { model: MODEL || 'default', effort: EFFORT, min_confidence: MIN_CONFIDENCE },
  reviewers: summary,
  findings,
});

const posted = findings.filter((f) => f.status === 'confirmed').length;
const failed = summary.filter((s) => s.status === 'failed' || s.verifier === 'failed').length;
console.log(`Done: ${posted} confirmed, ${findings.filter((f) => f.status === 'needs_human').length} need a human look, ${findings.filter((f) => f.status === 'refuted').length} refuted.`);
if (failed) notice('warning', `${failed} reviewer or verifier session(s) failed; the report says which.`);
