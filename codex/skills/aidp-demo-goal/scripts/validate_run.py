#!/usr/bin/env python3
import json, sys
from pathlib import Path

if len(sys.argv) != 2:
    print("Usage: validate_run.py <run-dir>", file=sys.stderr)
    sys.exit(2)
run_dir = Path(sys.argv[1])
required = ["run.json", "lock.json", "brief.md", "events.jsonl", "stage-gates.json", "benchmark-rubric.json"]
missing = [name for name in required if not (run_dir / name).exists()]
if missing:
    print(f"Missing required files: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

def read_json(name):
    try:
        return json.loads((run_dir / name).read_text())
    except Exception as e:
        print(f"Invalid JSON in {name}: {e}", file=sys.stderr)
        sys.exit(1)

run = read_json("run.json")
lock = read_json("lock.json")
rubric = read_json("benchmark-rubric.json")
for key in ["run_id", "slug", "status", "customer", "meeting", "current_stage"]:
    if key not in run:
        print(f"run.json missing {key}", file=sys.stderr)
        sys.exit(1)
for key in ["run_id", "active_goal_state", "leader_epoch", "lock_seq", "last_event_hash", "artifact_hash"]:
    if key not in lock:
        print(f"lock.json missing {key}", file=sys.stderr)
        sys.exit(1)
if lock["run_id"] != run["run_id"]:
    print("lock.json run_id does not match run.json run_id", file=sys.stderr)
    sys.exit(1)
if len(rubric.get("references", [])) < 3:
    print("benchmark-rubric.json requires at least 3 references", file=sys.stderr)
    sys.exit(1)
dimensions = rubric.get("dimensions", [])
if len(dimensions) < 3:
    print("benchmark-rubric.json requires at least 3 dimensions", file=sys.stderr)
    sys.exit(1)
weight = sum(float(d.get("weight", 0)) for d in dimensions)
if abs(weight - 1) > 0.001:
    print(f"benchmark dimension weights must sum to 1; got {weight}", file=sys.stderr)
    sys.exit(1)
previous = 0
ids = set()
for idx, line in enumerate((run_dir / "events.jsonl").read_text().splitlines(), 1):
    if not line.strip():
        continue
    try:
        event = json.loads(line)
    except Exception as e:
        print(f"events.jsonl line {idx} invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    if event.get("seq") != previous + 1:
        print(f"events.jsonl line {idx} seq gap: expected {previous + 1}, got {event.get('seq')}", file=sys.stderr)
        sys.exit(1)
    previous = event["seq"]
    event_id = event.get("event_id")
    if not event_id or event_id in ids:
        print(f"events.jsonl line {idx} missing/duplicate event_id", file=sys.stderr)
        sys.exit(1)
    ids.add(event_id)
print(json.dumps({"status": "pass", "run_id": run["run_id"], "events": previous}, indent=2))
