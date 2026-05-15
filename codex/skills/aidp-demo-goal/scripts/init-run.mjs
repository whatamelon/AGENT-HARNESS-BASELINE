#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

function arg(name, fallback = undefined) {
  const flag = `--${name}`;
  const i = process.argv.indexOf(flag);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return fallback;
}

const outRoot = arg('out-root', '.omx/goal-runs');
const slug = (arg('slug', 'aidp-demo') || 'aidp-demo').toLowerCase().replace(/[^a-z0-9가-힣-]+/gi, '-').replace(/^-+|-+$/g, '') || 'aidp-demo';
const customer = arg('customer', 'Unknown Customer');
const industry = arg('industry', 'Unknown');
const dataClass = arg('data-class', 'internal');
const objective = arg('objective', 'Prepare proposal demo prototype');
const wow = arg('wow', 'Show working prototype tied to customer pain');
const now = new Date().toISOString();
const runId = `${now.slice(0, 10).replaceAll('-', '')}-${slug}`;
const runDir = path.join(outRoot, runId);
fs.mkdirSync(runDir, { recursive: true });
for (const dir of ['team', 'research', 'planning', 'design', 'implementation', 'qa', 'deployment/screenshots', 'proposal-package', 'completion']) {
  fs.mkdirSync(path.join(runDir, dir), { recursive: true });
}

function write(file, data) {
  fs.writeFileSync(path.join(runDir, file), data);
}
function json(data) {
  return `${JSON.stringify(data, null, 2)}\n`;
}
function hash(data) {
  return crypto.createHash('sha256').update(data).digest('hex');
}

const run = {
  run_id: runId,
  slug,
  status: 'intake',
  customer: { name: customer, industry, data_class: dataClass },
  meeting: { date: null, goal: objective, wow_moment: wow },
  current_stage: 'intake',
  created_at: now,
  updated_at: now
};
const runJson = json(run);
const artifactHash = hash(runJson);
const lock = {
  run_id: runId,
  active_goal_state: 'none',
  codex_goal_snapshot_id: null,
  codex_goal_objective: null,
  ultragoal_goal_id: null,
  team_id: null,
  leader_session: process.env.OMX_SESSION_ID || null,
  leader_epoch: 1,
  lock_owner: 'leader',
  lock_seq: 0,
  lock_idempotency_key: hash(`${runId}:init`),
  last_event_id: null,
  last_event_hash: 'genesis',
  artifact_hash: artifactHash,
  last_heartbeat_at: now,
  resume_policy: 'manual-required'
};
const rubric = {
  references: [{ name: 'reference-1' }, { name: 'reference-2' }, { name: 'reference-3' }],
  dimensions: [
    { name: 'business fit', weight: 0.35, scale: '1-5' },
    { name: 'workflow coverage', weight: 0.2, scale: '1-5' },
    { name: 'UX clarity', weight: 0.15, scale: '1-5' },
    { name: 'enterprise readiness', weight: 0.15, scale: '1-5' },
    { name: 'demo wow factor', weight: 0.15, scale: '1-5' }
  ],
  threshold: 4,
  scorer: 'leader',
  citation_policy: { min_sources: 3, stale_after_days: 30 }
};

write('run.json', runJson);
write('lock.json', json(lock));
write('brief.md', `# AIDP Demo Goal Brief\n\n## Customer\n- Name: ${customer}\n- Industry: ${industry}\n\n## Problem\n- Desired outcome: ${objective}\n- Demo wow moment: ${wow}\n\n## Constraints\n- Data class: ${dataClass}\n\n## Success Criteria\n- Prototype must show: ${wow}\n- Benchmark threshold: ${rubric.threshold}/5\n`);
write('events.jsonl', '');
write('stage-gates.json', json({ stages: ['intake', 'research', 'planning', 'design', 'development', 'qa', 'deployment', 'demo_readiness', 'completion'], current: 'intake' }));
write('benchmark-rubric.json', json(rubric));
write('traceability-matrix.md', '# Traceability Matrix\n\n| Customer problem | Demo moment | Evidence |\n|---|---|---|\n');
write('team/launch.md', '# Team Launch\n\nNot launched. Use full mode only.\n');
write('team/evidence.jsonl', '');
write('team/terminal-summary.md', '# Team Terminal Summary\n\nPending.\n');
write('deployment/vercel.json', json({ status: 'not_started' }));
write('deployment/smoke.txt', 'not started\n');
write('deployment/rollback.md', '# Rollback\n\nPending.\n');
write('proposal-package/demo-script.md', '# Demo Script\n\nPending.\n');
write('proposal-package/architecture-brief.md', '# Architecture Brief\n\nPending.\n');
write('proposal-package/benchmark-scorecard.md', '# Benchmark Scorecard\n\nPending.\n');
write('proposal-package/roadmap.md', '# Roadmap\n\nPending.\n');
write('proposal-package/security-privacy-audit.md', '# Security Privacy Audit\n\nPending.\n');
write('completion-audit.json', json({ status: 'not_started', required_evidence: [] }));

console.log(JSON.stringify({ status: 'created', run_dir: runDir, run_id: runId }, null, 2));
