#!/usr/bin/env node
import fs from 'node:fs';

const input = fs.readFileSync(0, 'utf8').trim();
let data = {};
try { data = input ? JSON.parse(input) : {}; } catch { data = {}; }

const RESET = '\x1b[0m';
const DIM = '\x1b[2m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const CYAN = '\x1b[36m';

function num(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function clamp(n, lo = 0, hi = 100) {
  return Math.max(lo, Math.min(hi, n));
}

function colorByRemaining(rem) {
  if (rem == null) return DIM;
  if (rem <= 15) return RED;
  if (rem <= 35) return YELLOW;
  return GREEN;
}

function bar(rem, width = 8) {
  if (rem == null) return `${DIM}[────────] --%${RESET}`;
  const pct = clamp(Math.round(rem));
  const filled = Math.round((pct / 100) * width);
  const s = '█'.repeat(filled) + '░'.repeat(width - filled);
  const c = colorByRemaining(pct);
  return `${c}[${s}] ${pct}%${RESET}`;
}

function remainingFromUsed(used) {
  const u = num(used);
  return u == null ? null : clamp(100 - u);
}

function contextRemaining() {
  const rem = num(data.context_window?.remaining_percentage);
  if (rem != null) return clamp(rem);
  const used = num(data.context_window?.used_percentage);
  return used == null ? null : clamp(100 - used);
}

function resetText(epochSeconds) {
  const ts = num(epochSeconds);
  if (ts == null) return '';
  const diff = Math.max(0, Math.round(ts - Date.now() / 1000));
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  if (d > 0) return `${d}d${h}h`;
  if (h > 0) return `${h}h${m}m`;
  return `${m}m`;
}

const model = data.model?.display_name || data.model?.id || 'Claude';
const cwd = data.workspace?.current_dir || data.cwd || '';
const dir = cwd ? cwd.split('/').filter(Boolean).pop() || '/' : '';

const fiveRem = remainingFromUsed(data.rate_limits?.five_hour?.used_percentage);
const weekRem = remainingFromUsed(data.rate_limits?.seven_day?.used_percentage);
const ctxRem = contextRemaining();
const fiveReset = resetText(data.rate_limits?.five_hour?.resets_at);
const weekReset = resetText(data.rate_limits?.seven_day?.resets_at);

const parts = [
  `${CYAN}${model}${RESET}${dir ? `${DIM}@${dir}${RESET}` : ''}`,
  `5h ${bar(fiveRem)}${fiveReset ? `${DIM} reset:${fiveReset}${RESET}` : ''}`,
  `7d ${bar(weekRem)}${weekReset ? `${DIM} reset:${weekReset}${RESET}` : ''}`,
  `ctx ${bar(ctxRem)}`,
];

console.log(parts.join(' | '));
