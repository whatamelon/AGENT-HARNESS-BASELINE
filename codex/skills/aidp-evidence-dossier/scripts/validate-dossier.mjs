#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
const dir = process.argv[2];
if (!dir) { console.error('Usage: validate-dossier.mjs <dossier-dir>'); process.exit(2); }
const required = ['intake.md','connector-report.json','source-index.json','evidence-graph.json','evidence-dossier.md','recommended-brief.md','open-questions.md'];
const missing = required.filter(f=>!fs.existsSync(path.join(dir,f)));
if(missing.length){ console.error(`Missing required files: ${missing.join(', ')}`); process.exit(1); }
function readJson(f){ try{return JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'));}catch(e){ console.error(`Invalid JSON in ${f}: ${e.message}`); process.exit(1);} }
const source = readJson('source-index.json');
const graph = readJson('evidence-graph.json');
if(!source.dossier_id || !Array.isArray(source.items)){ console.error('source-index.json missing dossier_id/items'); process.exit(1); }
if(graph.dossier_id !== source.dossier_id){ console.error('evidence-graph dossier_id mismatch'); process.exit(1); }
if(!Array.isArray(graph.items)){ console.error('evidence-graph items missing'); process.exit(1); }
const requiredSections = ['High-Purity Facts','Stale or Low-Purity Evidence','Contradictions','Demo Opportunities','Critical Unknowns'];
const dossier = fs.readFileSync(path.join(dir,'evidence-dossier.md'),'utf8');
for(const section of requiredSections){ if(!dossier.includes(section)){ console.error(`evidence-dossier.md missing ${section}`); process.exit(1); } }
const brief = fs.readFileSync(path.join(dir,'recommended-brief.md'),'utf8');
for(const section of ['Proposal Objective','Demo Wow Moment','Evidence Map']){ if(!brief.includes(section)){ console.error(`recommended-brief.md missing ${section}`); process.exit(1); } }
console.log(JSON.stringify({ status:'pass', dossier_id:source.dossier_id, sources:source.items.length, scored:graph.items.length }, null, 2));
