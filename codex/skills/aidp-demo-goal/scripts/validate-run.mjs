#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const runDir = process.argv[2];
if (!runDir) {
  console.error('Usage: validate-run.mjs <run-dir>');
  process.exit(2);
}

const required = [
  'run.json',
  'lock.json',
  'brief.md',
  'events.jsonl',
  'stage-gates.json',
  'benchmark-rubric.json'
];

const missing = required.filter((file) => !fs.existsSync(path.join(runDir, file)));
if (missing.length) {
  console.error(`Missing required files: ${missing.join(', ')}`);
  process.exit(1);
}

function readJson(file) {
  const full = path.join(runDir, file);
  try {
    return JSON.parse(fs.readFileSync(full, 'utf8'));
  } catch (error) {
    console.error(`Invalid JSON in ${file}: ${error.message}`);
    process.exit(1);
  }
}

const run = readJson('run.json');
const lock = readJson('lock.json');
const rubric = readJson('benchmark-rubric.json');

for (const key of ['run_id', 'slug', 'status', 'customer', 'meeting', 'current_stage']) {
  if (!(key in run)) {
    console.error(`run.json missing ${key}`);
    process.exit(1);
  }
}

for (const key of ['run_id', 'active_goal_state', 'leader_epoch', 'lock_seq', 'last_event_hash', 'artifact_hash']) {
  if (!(key in lock)) {
    console.error(`lock.json missing ${key}`);
    process.exit(1);
  }
}

if (lock.run_id !== run.run_id) {
  console.error('lock.json run_id does not match run.json run_id');
  process.exit(1);
}

if (!Array.isArray(rubric.references) || rubric.references.length < 3) {
  console.error('benchmark-rubric.json requires at least 3 references');
  process.exit(1);
}

if (!Array.isArray(rubric.dimensions) || rubric.dimensions.length < 3) {
  console.error('benchmark-rubric.json requires at least 3 dimensions');
  process.exit(1);
}

const weight = rubric.dimensions.reduce((sum, dimension) => sum + Number(dimension.weight || 0), 0);
if (Math.abs(weight - 1) > 0.001) {
  console.error(`benchmark dimension weights must sum to 1; got ${weight}`);
  process.exit(1);
}

const eventsPath = path.join(runDir, 'events.jsonl');
const lines = fs.readFileSync(eventsPath, 'utf8').split('\n').filter(Boolean);
let previousSeq = 0;
const ids = new Set();
for (const [index, line] of lines.entries()) {
  let event;
  try {
    event = JSON.parse(line);
  } catch (error) {
    console.error(`events.jsonl line ${index + 1} invalid JSON: ${error.message}`);
    process.exit(1);
  }
  if (event.seq !== previousSeq + 1) {
    console.error(`events.jsonl line ${index + 1} seq gap: expected ${previousSeq + 1}, got ${event.seq}`);
    process.exit(1);
  }
  previousSeq = event.seq;
  if (!event.event_id || ids.has(event.event_id)) {
    console.error(`events.jsonl line ${index + 1} missing/duplicate event_id`);
    process.exit(1);
  }
  ids.add(event.event_id);
}

console.log(JSON.stringify({ status: 'pass', run_id: run.run_id, events: lines.length }, null, 2));
