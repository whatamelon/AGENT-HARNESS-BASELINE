#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

function arg(name, fallback = undefined) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const slug = (arg('slug', 'customer-demo') || 'customer-demo').toLowerCase().replace(/[^a-z0-9가-힣-]+/gi, '-').replace(/^-+|-+$/g, '') || 'customer-demo';
const customer = arg('customer', 'Unknown Customer');
const objective = arg('objective', 'Prepare proposal demo brief');
const outRoot = arg('out-root', '.omx/evidence');
const now = new Date().toISOString();
const dir = path.join(outRoot, slug);
fs.mkdirSync(dir, { recursive: true });
for (const sub of ['raw/slack','raw/gmail','raw/drive','raw/calendar','raw/github','raw/files','raw/images']) fs.mkdirSync(path.join(dir, sub), { recursive: true });
function write(file, data) { fs.writeFileSync(path.join(dir, file), data); }
function json(data) { return `${JSON.stringify(data, null, 2)}\n`; }
write('intake.md', `# Evidence Intake\n\n- Customer: ${customer}\n- Objective: ${objective}\n- Scope: TBD\n- Forbidden scopes: TBD\n- Created: ${now}\n`);
write('connector-report.json', json({ created_at: now, connectors: [] }));
write('source-index.json', json({ dossier_id: slug, customer, project: null, created_at: now, scope: { objective }, items: [] }));
write('evidence-graph.json', json({ dossier_id: slug, scored_at: now, items: [], summary: { high_purity: 0, stale_or_low: 0, contradictions: 0 } }));
write('evidence-dossier.md', `# Evidence Dossier: ${customer}\n\n## Executive Context\nPending evidence collection.\n\n## High-Purity Facts\n\n## Current Context Timeline\n\n## Stale or Low-Purity Evidence\n\n## Contradictions and Resolution\n\n## Demo Opportunities\n\n## Critical Unknowns\n\n## Recommended Brief Summary\n`);
write('recommended-brief.md', `# Recommended AIDP Demo Brief

## Customer and Industry
${customer}

## Proposal Objective
${objective}

## Current Best Interpretation
Pending evidence scoring.

## Demo Wow Moment
Pending evidence scoring.

## Target Users and Jobs

## Constraints and Data Policy

## Available Assets

## Benchmark Candidates

## Proposed Demo Flow

## Success Criteria

## Evidence Map

## Assumptions

## Open Questions
`);
write('open-questions.md', '# Open Questions\n\n');
console.log(JSON.stringify({ status: 'created', dossier_dir: dir, dossier_id: slug }, null, 2));
