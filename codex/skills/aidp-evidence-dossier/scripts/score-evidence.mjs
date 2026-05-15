#!/usr/bin/env node
import fs from 'node:fs';
const file = process.argv[2];
if (!file) { console.error('Usage: score-evidence.mjs <source-index.json>'); process.exit(2); }
const index = JSON.parse(fs.readFileSync(file, 'utf8'));
const now = process.env.AIDP_EVIDENCE_NOW ? new Date(process.env.AIDP_EVIDENCE_NOW) : new Date();
const halfLife = { schedule:14, budget:30, rfp:90, signed_doc:365, customer_statement:60, meeting_note:60, email:60, slack_thread:45, calendar_event:14, technical_artifact:90, screenshot:90, internal_note:30, github_issue:90, github_pr:90, other:60 };
const authorityMap = { rfp:0.95, signed_doc:0.95, customer_decision_maker:0.9, customer_operator:0.78, customer_engineer:0.74, technical_artifact:0.72, system:0.65, internal_engineer:0.58, internal_sales:0.55, unknown:0.35 };
const directnessMap = { direct:1, relayed:0.68, inferred:0.42 };
function clamp(x){ return Math.max(0, Math.min(1, x)); }
function ageDays(ts){ if(!ts) return 999; const d = new Date(ts); if(Number.isNaN(d.getTime())) return 999; return Math.max(0, (now-d)/86400000); }
function recency(item){ const type = item.evidence_type || 'other'; const hl = halfLife[type] || 60; return clamp(Math.pow(0.5, ageDays(item.timestamp)/hl)); }
function authority(item){ return Math.max(authorityMap[item.evidence_type] || 0, authorityMap[item.speaker_role] || 0.35); }
function specificity(item){ return clamp(((item.claims||[]).length ? 0.45 : 0) + Math.min((item.summary||'').length/200, .35) + ((item.tags||[]).length ? .2 : 0)); }
function demoUse(item){ const text = `${item.summary||''} ${(item.claims||[]).join(' ')} ${(item.tags||[]).join(' ')}`.toLowerCase(); let s=0.35; for (const k of ['demo','prototype','workflow','pain','problem','자동','화면','미팅','제안','wow','dashboard','대시보드']) if(text.includes(k)) s+=0.08; if(['screenshot','technical_artifact','rfp','customer_statement'].includes(item.evidence_type)) s+=0.1; return clamp(s); }
function contextFit(item){ const obj = JSON.stringify(index.scope||{}).toLowerCase(); const text = `${item.title||''} ${item.summary||''} ${(item.claims||[]).join(' ')} ${(item.tags||[]).join(' ')}`.toLowerCase(); if(!obj || obj === '{}') return 0.6; const tokens = obj.split(/[^a-z0-9가-힣]+/).filter(t=>t.length>=2); if(!tokens.length) return 0.6; const hits = tokens.filter(t=>text.includes(t)).length; return clamp(0.35 + hits/Math.min(tokens.length, 8)*0.65); }
function score(item){
  const rec = recency(item), auth = authority(item), dir = directnessMap[item.directness] ?? 0.5, spec = specificity(item), demo = demoUse(item), ctx = contextFit(item);
  const purity = clamp(0.34*dir + 0.30*auth + 0.24*spec + 0.12*((item.uri||'') ? 1 : 0));
  const contradictionPenalty = (item.tags||[]).includes('contradicted') ? 0.25 : 0;
  const overall = clamp(0.28*purity + 0.18*rec + 0.18*auth + 0.16*ctx + 0.20*demo - contradictionPenalty);
  const reasons = [];
  reasons.push(`authority=${auth.toFixed(2)}`); reasons.push(`recency=${rec.toFixed(2)} age_days=${ageDays(item.timestamp).toFixed(1)}`); reasons.push(`directness=${dir.toFixed(2)}`); reasons.push(`demo_usefulness=${demo.toFixed(2)}`);
  if(contradictionPenalty) reasons.push('contradiction penalty applied');
  return { id:item.id, source:item.source, evidence_type:item.evidence_type, title:item.title, summary:item.summary, scores:{ purity:+purity.toFixed(3), recency:+rec.toFixed(3), authority:+auth.toFixed(3), context_fit:+ctx.toFixed(3), demo_usefulness:+demo.toFixed(3), overall:+overall.toFixed(3) }, reasons, claims:item.claims||[], tags:item.tags||[] };
}
const items = (index.items||[]).map(score).sort((a,b)=>b.scores.overall-a.scores.overall);
const summary = { total:items.length, high_purity:items.filter(i=>i.scores.overall>=0.75).length, stale_or_low:items.filter(i=>i.scores.overall<0.45 || i.scores.recency<0.25).length, contradictions:items.filter(i=>(i.tags||[]).includes('contradicted')).length };
console.log(JSON.stringify({ dossier_id:index.dossier_id, scored_at:now.toISOString(), items, summary }, null, 2));
