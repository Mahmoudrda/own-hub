#!/usr/bin/env node
// Step 3 of 3. Publishes .ai-review/report.json. Runs no AI.
//   pull request -> one review with inline comments on the changed lines
//   push         -> job summary, annotations, and an issue when there are findings
//
// Env: GH_TOKEN, GITHUB_REPOSITORY, REVIEW_FAIL_ON (none|critical|high),
//      REVIEW_PUSH_REPORT (issue|summary), REVIEW_DRY_RUN=1
import fs from 'node:fs';
import path from 'node:path';
import {
  WORKDIR, MARKER, REVIEWERS, SEVERITIES, SEVERITY_ICON, gh, readJson, notice,
} from './lib.mjs';

const DRY = process.env.REVIEW_DRY_RUN === '1';
const FAIL_ON = (process.env.REVIEW_FAIL_ON || 'none').toLowerCase();
const PUSH_REPORT = (process.env.REVIEW_PUSH_REPORT || 'issue').toLowerCase();
const server = process.env.GITHUB_SERVER_URL || 'https://github.com';

const report = readJson(path.join(WORKDIR, 'report.json'));
if (!report || report.meta?.skipped) {
  console.log('No report to publish.');
  process.exit(0);
}
const { meta, reviewers, findings } = report;
const repo = meta.repo || process.env.GITHUB_REPOSITORY || '';

function summaryOut(md) {
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, md + '\n');
}

if (report.not_configured) {
  summaryOut('### AI review did not run\n\nThe `CLAUDE_CODE_OAUTH_TOKEN` secret is not set for this repository.');
  process.exit(0);
}

// If no reviewer could run, say so loudly and post nothing: a green check or a
// "no issues" comment would be false assurance.
if (reviewers.length && reviewers.every((r) => r.status === 'failed')) {
  const why = String(reviewers[0].error || 'unknown error').replace(/^.*? exited \d+: /, '');
  const limit = /session limit|usage limit|rate limit|limit reached|quota/i.test(why);
  const text = limit
    ? `AI review did not run: your Claude plan's usage limit is used up (${why}). Re-run this workflow after it resets.`
    : `AI review did not run: ${why}`;
  fs.writeFileSync(path.join(WORKDIR, 'report.md'), `### ${text}\n`);
  summaryOut(`### ${text}\n\nNothing was reviewed and nothing was posted. Use "Re-run jobs" on this run to try again.`);
  notice('error', text);
  process.exit(1);
}

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const where = (f) => (f.end_line > f.line ? `${f.file}:${f.line}-${f.end_line}` : `${f.file}:${f.line}`);
const link = (f) => {
  const anchor = f.end_line > f.line ? `#L${f.line}-L${f.end_line}` : `#L${f.line}`;
  return repo ? `[\`${where(f)}\`](${server}/${repo}/blob/${meta.head}/${encodeURI(f.file)}${anchor})` : `\`${where(f)}\``;
};
const bySeverity = (a, b) => SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity);

const confirmed = findings.filter((f) => f.status === 'confirmed').sort(bySeverity);
const needsHuman = findings.filter((f) => f.status === 'needs_human').sort(bySeverity);
const refuted = findings.filter((f) => f.status === 'refuted');
const broken = reviewers.filter((r) => r.status === 'failed' || r.verifier === 'failed');

function heading(f) {
  const also = f.also?.length ? ` (also flagged by ${f.also.map((a) => REVIEWERS[a].label).join(', ')})` : '';
  return `**${SEVERITY_ICON[f.severity]} ${cap(f.severity)} · ${REVIEWERS[f.reviewer].label} · ${f.title}**${also}`;
}

// The full write-up for one finding. `withSuggestion` adds a one-click fix
// block, which only works inside an inline pull request comment.
function body(f, withSuggestion) {
  const out = [heading(f), '', f.evidence.trim(), '', `**Why it matters:** ${f.impact.trim()}`, '', `**Fix:** ${f.fix.trim()}`];
  if (withSuggestion && f.suggestion?.trim()) {
    out.push('', '```suggestion', f.suggestion.replace(/\s+$/, ''), '```');
  }
  const detail = [];
  if (f.trace?.length) detail.push('Path followed:', ...f.trace.map((t) => `- ${t}`), '');
  if (f.verifier) detail.push(`Independent check (${f.verifier.confidence}% confident): ${f.verifier.reason.trim()}`);
  if (detail.length) out.push('', '<details><summary>How this was verified</summary>', '', ...detail, '', '</details>');
  out.push('', `<!-- ${MARKER}:fp=${f.fp} -->`);
  return out.join('\n');
}

// GitHub rejects comment, review and issue bodies over 65,536 characters.
const LIMIT = 60_000;

function overview(inlineSet, repeats = new Set()) {
  const full = buildOverview(inlineSet, repeats, false);
  if (full.length <= LIMIT) return full;
  const compact = buildOverview(inlineSet, repeats, true);
  if (compact.length <= LIMIT) return compact;
  return `${compact.slice(0, LIMIT)}\n\n_Report cut short to fit GitHub's size limit. The full report is in this run's ai-review-report artifact._\n<!-- ${MARKER} -->`;
}

function buildOverview(inlineSet, repeats, compact) {
  const out = [];
  const total = confirmed.length;
  const counts = SEVERITIES.map((s) => [s, confirmed.filter((f) => f.severity === s).length]).filter(([, n]) => n);
  out.push(`## AI review: ${total ? `${total} finding${total === 1 ? '' : 's'}` : 'no confirmed issues'}${broken.length ? ' (incomplete)' : ''}`);
  out.push('');
  if (total) out.push(counts.map(([s, n]) => `${SEVERITY_ICON[s]} ${n} ${s}`).join(' · '), '');
  if (broken.length) {
    out.push(`> **Incomplete review.** ${broken.map((r) => `${REVIEWERS[r.name].label} ${r.status === 'failed' ? 'reviewer' : 'verifier'} failed`).join('; ')}. A clean result below does not cover those areas.`, '');
  }
  out.push('| Reviewer | Result | Raised | Confirmed | Rejected by verifier |', '|---|---|---|---|---|');
  for (const r of reviewers) {
    const label = `${REVIEWERS[r.name].icon} ${REVIEWERS[r.name].label}`;
    const result = r.status === 'failed' ? 'did not run' : r.confirmed ? 'issues found' : 'clean';
    out.push(`| ${label} | ${result} | ${r.raised ?? 0} | ${r.confirmed ?? 0} | ${r.refuted ?? 0} |`);
  }
  const skippedReviewers = Object.keys(REVIEWERS).filter((n) => !reviewers.some((r) => r.name === n));
  if (skippedReviewers.length) {
    out.push('', `Not run because no relevant files changed: ${skippedReviewers.map((n) => REVIEWERS[n].label).join(', ')}.`);
  }
  out.push('');

  const notInline = confirmed.filter((f) => !inlineSet.has(f) && !repeats.has(f));
  if (inlineSet.size) {
    out.push('### Findings', '');
    for (const f of confirmed.filter((x) => inlineSet.has(x))) {
      out.push(`- ${SEVERITY_ICON[f.severity]} ${link(f)} ${f.title} _(${REVIEWERS[f.reviewer].label})_`);
    }
    out.push('');
  }
  if (notInline.length) {
    out.push(inlineSet.size ? '### Findings on lines outside the diff' : '### Findings', '');
    for (const f of notInline) out.push(`#### ${link(f)}`, '', body(f, false), '');
  }
  if (repeats.size) {
    out.push('### Still open from an earlier review', '');
    for (const f of confirmed.filter((x) => repeats.has(x))) {
      out.push(`- ${SEVERITY_ICON[f.severity]} ${link(f)} ${f.title} _(${REVIEWERS[f.reviewer].label})_`);
    }
    out.push('');
  }
  if (needsHuman.length) {
    out.push('### Needs a human look', '', 'Serious if true, but the independent check could not confirm them.', '');
    for (const f of needsHuman) {
      out.push(`- ${SEVERITY_ICON[f.severity]} ${link(f)} **${f.title}** _(${REVIEWERS[f.reviewer].label})_: ${f.impact.trim()}${f.verifier ? ` Verifier: ${f.verifier.reason.trim()}` : ' The verifier did not run.'}`);
    }
    out.push('');
  }

  if (compact) out.push('_Some detail was left out to fit GitHub\'s size limit. The full report is in this run\'s ai-review-report artifact._', '');
  if (!compact) out.push('<details><summary>What each reviewer checked</summary>', '');
  for (const r of compact ? [] : reviewers) {
    out.push(`**${REVIEWERS[r.name].icon} ${REVIEWERS[r.name].label}**${r.status === 'failed' ? ` did not run: ${String(r.error).replace(/^.*? exited \d+: /, '')}` : ''}`, '');
    if (r.summary) out.push(r.summary.trim(), '');
    for (const c of r.checked || []) {
      const mark = c.result === 'ok' ? '✅' : c.result === 'issue' ? '⚠️' : '➖';
      out.push(`- ${mark} **${c.area}:** ${c.note}`);
    }
    out.push('');
  }
  if (!compact) out.push('</details>', '');

  if (refuted.length && !compact) {
    out.push('<details><summary>Raised by a reviewer, rejected by the verifier</summary>', '');
    for (const f of refuted) out.push(`- \`${where(f)}\` ${f.title}: ${f.verifier.reason.trim()}`);
    out.push('', '</details>', '');
  }
  const secs = reviewers.reduce((n, r) => n + (r.seconds || 0) + (r.verify_seconds || 0), 0);
  out.push(`<sub>${meta.files.length} file(s) reviewed at ${meta.head.slice(0, 7)}${meta.truncated ? `, ${meta.truncated} smaller files left out` : ''} · ${secs}s of review time · advisory only, a person should make the final call</sub>`);
  out.push(`<!-- ${MARKER} -->`);
  return out.join('\n');
}

async function postPullRequest() {
  const existing = new Set((readJson(path.join(WORKDIR, 'existing.json'), []) || []).map((e) => e.fp));
  const repeats = new Set(confirmed.filter((f) => existing.has(f.fp)));
  const inline = confirmed.filter((f) => f.inline && !repeats.has(f));
  const comments = inline.map((f) => ({
    path: f.file,
    line: f.end_line,
    side: 'RIGHT',
    ...(f.end_line > f.line ? { start_line: f.line, start_side: 'RIGHT' } : {}),
    body: body(f, true),
  }));
  const payload = { commit_id: meta.head, event: 'COMMENT', body: overview(new Set(inline), repeats), comments };
  if (DRY) return console.log(JSON.stringify(payload, null, 2));
  let inlineCount = comments.length;
  try {
    await gh('POST', `/repos/${repo}/pulls/${meta.pr}/reviews`, payload);
  } catch (err) {
    if (err.status !== 422 || !comments.length) throw err;
    // GitHub rejects the whole review if one line is not in its diff. Fall
    // back to putting every finding in the review body.
    notice('warning', `Inline comments were rejected (${err.message.slice(0, 120)}); posting them in the summary instead.`);
    await gh('POST', `/repos/${repo}/pulls/${meta.pr}/reviews`, { commit_id: meta.head, event: 'COMMENT', body: overview(new Set(), repeats) });
    inlineCount = 0;
  }
  console.log(`Posted review on pull request #${meta.pr} with ${inlineCount} inline comment(s).`);
}

async function postPush() {
  for (const f of confirmed) {
    const level = f.severity === 'critical' || f.severity === 'high' ? 'error' : 'warning';
    const msg = `${f.impact} Fix: ${f.fix}`.replace(/\r?\n/g, ' ').replace(/::/g, ':');
    if (process.env.GITHUB_ACTIONS) console.log(`::${level} file=${f.file},line=${f.line},endLine=${f.end_line},title=${REVIEWERS[f.reviewer].label}: ${f.title.replace(/[,:]/g, ' ')}::${msg}`);
  }
  if (PUSH_REPORT !== 'issue' || (!confirmed.length && !needsHuman.length && !broken.length)) return;
  const subject = (meta.files.length === 1 ? meta.files[0].file : `${meta.files.length} files`);
  const title = confirmed.length
    ? `AI review: ${confirmed.length} finding${confirmed.length === 1 ? '' : 's'} in ${meta.head.slice(0, 7)} (${subject})`
    : `AI review: ${meta.head.slice(0, 7)} needs a human look (${subject})`;
  const payload = { title, body: overview(new Set()) };
  if (DRY) return console.log(JSON.stringify(payload, null, 2));
  const issue = await gh('POST', `/repos/${repo}/issues`, payload);
  console.log(`Opened issue #${issue.number} with the review.`);
}

const text = overview(new Set());
fs.writeFileSync(path.join(WORKDIR, 'report.md'), text + '\n');
summaryOut(text);

try {
  if (meta.pr) await postPullRequest();
  else await postPush();
} catch (err) {
  notice('error', `Could not publish the review: ${err.message}`);
  process.exitCode = 1;
}

const gate = FAIL_ON === 'critical' ? ['critical'] : FAIL_ON === 'high' ? ['critical', 'high'] : [];
const blocking = confirmed.filter((f) => gate.includes(f.severity));
if (blocking.length) {
  notice('error', `${blocking.length} confirmed ${FAIL_ON}-or-worse finding(s). Failing because REVIEW_FAIL_ON=${FAIL_ON}.`);
  process.exitCode = 1;
}
