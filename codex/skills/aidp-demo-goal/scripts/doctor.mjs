#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

function has(cmd, args = ['--version']) {
  const result = spawnSync(cmd, args, { stdio: 'ignore' });
  return result.status === 0 || result.status === 1;
}

function fileExists(p) {
  return fs.existsSync(p.replace(/^~/, os.homedir()));
}

const checks = {
  node: has('node', ['--version']),
  python3: has('python3', ['--version']),
  git: has('git', ['--version']),
  omx: has('omx', ['--version']),
  tmux: has('tmux', ['-V']),
  vercel: has('vercel', ['--version']),
  codexHooks: fileExists('~/.codex/hooks.json'),
  claudeSync: fileExists('~/.config/claude-sync'),
  designslopAudit: fileExists('~/.config/claude-sync/claude/hooks/designslop-audit.py')
};

let mode = 'portable';
if (checks.node && checks.omx) mode = 'workstation';
if (checks.node && checks.omx && checks.tmux && checks.codexHooks && checks.designslopAudit) mode = 'full';

const capabilities = {
  portable: [
    'create and validate run documents',
    'generate brief, rubric, gates, completion audit',
    'manual Team/Ultragoal/deploy handoff text'
  ],
  workstation: [
    'all portable capabilities',
    'OMX/Ultragoal artifacts and checkpoints when active goal state matches',
    'manual or non-tmux execution lanes'
  ],
  full: [
    'all workstation capabilities',
    'tmux Team execution',
    'Codex/Claude Stop hook designslop gate',
    'long-running worker coordination'
  ]
};

const blockers = [];
if (!checks.node) blockers.push('node missing: scripts cannot run; use manual templates only');
if (mode !== 'full') {
  if (!checks.omx) blockers.push('omx missing: no Ultragoal/Team runtime');
  if (!checks.tmux) blockers.push('tmux missing: no durable Team panes');
  if (!checks.designslopAudit) blockers.push('designslop audit missing: visual slop gate manual/unavailable');
  if (!checks.codexHooks) blockers.push('Codex hooks missing: no automatic Stop gate');
}
if (!checks.vercel) blockers.push('vercel missing: live deploy requires alternative adapter or approved fallback');

console.log(JSON.stringify({ mode, checks, capabilities: capabilities[mode], blockers }, null, 2));
