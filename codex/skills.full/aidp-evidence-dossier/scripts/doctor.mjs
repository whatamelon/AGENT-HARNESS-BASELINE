#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';

function has(cmd, args = ['--version']) {
  const result = spawnSync(cmd, args, { stdio: 'ignore' });
  return result.status === 0 || result.status === 1;
}
function run(cmd, args) {
  const result = spawnSync(cmd, args, { encoding: 'utf8' });
  return { status: result.status, stdout: result.stdout || '', stderr: result.stderr || '' };
}
function exists(p) { return fs.existsSync(p.replace(/^~/, os.homedir())); }

const ghStatus = has('gh') ? run('gh', ['auth', 'status']) : { status: 127, stderr: 'gh missing' };
const checks = {
  node: has('node', ['--version']),
  python3: has('python3', ['--version']),
  slackMcpConfig: exists('~/.codex/config.toml') && fs.readFileSync(`${os.homedir()}/.codex/config.toml`, 'utf8').includes('[mcp_servers.slack]'),
  gws: has('gws', ['--help']),
  gh: has('gh', ['--version']),
  ghAuthOk: ghStatus.status === 0,
  localFiles: true
};
const sources = [];
if (checks.slackMcpConfig) sources.push({ source: 'slack', status: 'available', note: 'MCP config detected; use MCP Slack tools in-agent' });
if (checks.gws) sources.push({ source: 'google_workspace', status: 'available', note: 'gws CLI detected; auth checked per command' });
if (checks.gh) sources.push({ source: 'github', status: checks.ghAuthOk ? 'available' : 'auth_invalid', note: checks.ghAuthOk ? 'gh auth ok' : 'run gh auth login -h github.com' });
sources.push({ source: 'local_files', status: 'available', note: 'read user-provided files/images in allowed workspace' });

console.log(JSON.stringify({ checks, sources, blockers: sources.filter(s => s.status === 'auth_invalid') }, null, 2));
