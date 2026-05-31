#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
const dir = process.argv[2];
if (!dir) { console.error('Usage: synthesize-dossier.mjs <dossier-dir>'); process.exit(2); }
function readJson(name){ return JSON.parse(fs.readFileSync(path.join(dir,name),'utf8')); }
const source = readJson('source-index.json');
const graph = readJson('evidence-graph.json');
const byId = new Map((source.items||[]).map(i=>[i.id,i]));
const items = graph.items || [];
const high = items.filter(i=>i.scores.overall>=0.75);
const stale = items.filter(i=>i.scores.overall<0.45 || i.scores.recency<0.25);
const contradictions = items.filter(i=>(i.tags||[]).includes('contradicted'));
const demo = items.filter(i=>i.scores.demo_usefulness>=0.65).slice(0,5);
const timeline = [...items].filter(i=>byId.get(i.id)?.timestamp).sort((a,b)=>String(byId.get(a.id).timestamp).localeCompare(String(byId.get(b.id).timestamp)));
function bullet(item){ const src=byId.get(item.id)||{}; return `- [${item.scores.overall.toFixed(2)}] ${item.title || item.id} (${item.id}, ${item.source}/${item.evidence_type}) — ${item.summary || src.summary || ''}`; }
function claimMap(list){ return list.flatMap(i=>(i.claims||[]).map(c=>`- ${c} — evidence: ${i.id} (${i.scores.overall.toFixed(2)})`)).join('\n') || '- Pending evidence claims'; }
const customer = source.customer || source.dossier_id;
const top = items[0];
const topSummary = top ? `${top.summary} Evidence: ${top.id}.` : 'Pending evidence collection.';
const dossier = `# Evidence Dossier: ${customer}\n\n## Executive Context\n${topSummary}\n\n## Connector Report\nSee \`connector-report.json\`. Auth gaps must be handled before broad collection.\n\n## High-Purity Facts\n${high.map(bullet).join('\n') || '- None yet'}\n\n## Current Context Timeline\n${timeline.map(i=>`- ${byId.get(i.id).timestamp}: ${i.title} (${i.id})`).join('\n') || '- No timestamped evidence yet'}\n\n## Stale or Low-Purity Evidence\n${stale.map(bullet).join('\n') || '- None identified'}\n\n## Contradictions and Resolution\n${contradictions.map(bullet).join('\n') || '- No explicit contradictions tagged'}\n\n## Demo Opportunities\n${demo.map(bullet).join('\n') || '- Pending evidence-backed demo opportunities'}\n\n## Critical Unknowns\n- Confirm deployment constraints and data class before live demo.\n- Confirm final meeting wow moment with customer-facing owner if not directly evidenced.\n\n## Recommended Brief Summary\nUse \`recommended-brief.md\`; every claim should cite evidence id or be marked inference.\n\n## Source Index\n- Indexed sources: ${(source.items||[]).length}\n- Scored sources: ${items.length}\n`;
const brief = `# Recommended AIDP Demo Brief\n\n## Customer and Industry\n${customer}\n\n## Proposal Objective\n${source.scope?.objective || 'Prepare proposal demo'}\n\n## Current Best Interpretation\n${topSummary}\n\n## Demo Wow Moment\n${demo[0]?.summary || 'Inference pending: choose the clearest evidence-backed workflow as wow moment.'}\n\n## Target Users and Jobs\n- Inferred from high-purity evidence; verify if not explicit.\n\n## Constraints and Data Policy\n- Confirm data class before deploy.\n- Do not use restricted/confidential data externally without sanitized fixtures and approval.\n\n## Available Assets\n- See source-index evidence URIs and raw artifacts.\n\n## Benchmark Candidates\n- Derive from current problem domain during aidp-demo-goal Research stage.\n\n## Proposed Demo Flow\n${demo.slice(0,3).map((i,idx)=>`${idx+1}. ${i.title} — evidence: ${i.id}`).join('\n') || '1. Pending evidence-backed flow'}\n\n## Success Criteria\n- Demo maps to high-purity customer pain.\n- Security/privacy/deploy constraints respected.\n- Proposal package links every claim to evidence.\n\n## Evidence Map\n${claimMap(high.length ? high : items.slice(0,3))}\n\n## Assumptions\n- Any uncited recommendation is inference and must be verified before customer-facing use.\n\n## Open Questions\n- Which deployment path is allowed?\n- Which sample/sanitized data can be used?\n- Who approves final demo narrative?\n`;
fs.writeFileSync(path.join(dir,'evidence-dossier.md'), dossier);
fs.writeFileSync(path.join(dir,'recommended-brief.md'), brief);
console.log(JSON.stringify({status:'synthesized', dossier:path.join(dir,'evidence-dossier.md'), recommended_brief:path.join(dir,'recommended-brief.md')}, null, 2));
