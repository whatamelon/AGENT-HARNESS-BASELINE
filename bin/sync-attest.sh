#!/usr/bin/env bash
# sync-attest.sh
# Produce a machine-local attestation that Claude Code and Codex skill surfaces
# are current, equivalent by visible skill name, and runtime-healthy.

set -euo pipefail

SSOT="${CLAUDE_SYNC_HOME:-$HOME/.config/claude-sync}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
LEGACY_SKILLS_DIR="${LEGACY_SKILLS_DIR:-$HOME/.agents/skills}"
OUT="${SYNC_ATTESTATION_OUT:-$SSOT/state/sync-attestation.json}"

allow_dirty=0
skip_fetch=0
skip_doctor=0
skip_generate=0

usage() {
  cat <<'EOF'
Usage: sync-attest.sh [--allow-dirty] [--skip-fetch] [--skip-doctor] [--skip-generate] [--out <file>]

Checks and records:
  - git HEAD equals origin/<branch>
  - working tree is clean, unless --allow-dirty is used
  - skill surfaces are regenerated before verification, unless --skip-generate is used
  - Claude skill names equal Codex skill names
  - broken / absolute top-level symlinks are absent
  - ~/.agents/skills resolves to ~/.codex/skills
  - file manifest hash for both skill surfaces
  - shared DESIGN.md/getdesign.md entrypoints are linked for home, Claude, and Codex
  - omx doctor reports 0 warnings / 0 failed, unless --skip-doctor is used

Writes a machine-local JSON attestation to:
  ~/.config/claude-sync/state/sync-attestation.json
EOF
}

while (($#)); do
  case "$1" in
    --allow-dirty) allow_dirty=1 ;;
    --skip-fetch) skip_fetch=1 ;;
    --skip-doctor) skip_doctor=1 ;;
    --skip-generate) skip_generate=1 ;;
    --out)
      [[ $# -ge 2 ]] || { echo "--out requires a file path" >&2; exit 2; }
      OUT="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -d "$SSOT/.git" ]] || { echo "FAIL: missing claude-sync git repo: $SSOT" >&2; exit 1; }

if (( skip_generate == 0 )); then
  if [[ -x "$SSOT/bootstrap/install-shared-skills.sh" ]]; then
    "$SSOT/bootstrap/install-shared-skills.sh" >/dev/null
  fi
  if [[ -x "$SSOT/bootstrap/install-codex-skills.sh" ]]; then
    "$SSOT/bootstrap/install-codex-skills.sh" >/dev/null
  fi
  if [[ -x "$SSOT/bin/codex-bridge.sh" ]]; then
    "$SSOT/bin/codex-bridge.sh" --quiet >/dev/null 2>&1 || true
  fi
  if [[ -x "$SSOT/bootstrap/install-claude-codex-skills.sh" ]]; then
    "$SSOT/bootstrap/install-claude-codex-skills.sh" >/dev/null
  fi
  if [[ -x "$SSOT/bin/link-design.sh" ]]; then
    "$SSOT/bin/link-design.sh" >/dev/null
  fi
fi

mkdir -p "$(dirname "$OUT")"

PY_ALLOW_DIRTY="$allow_dirty" \
PY_SKIP_FETCH="$skip_fetch" \
PY_SKIP_DOCTOR="$skip_doctor" \
PY_SSOT="$SSOT" \
PY_CLAUDE_SKILLS_DIR="$CLAUDE_SKILLS_DIR" \
PY_CODEX_SKILLS_DIR="$CODEX_SKILLS_DIR" \
PY_LEGACY_SKILLS_DIR="$LEGACY_SKILLS_DIR" \
PY_OUT="$OUT" \
python3 <<'PY'
import hashlib
import json
import os
import socket
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def run(cmd, cwd=None, check=False):
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(f"{cmd!r} failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return proc


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def real(path: Path) -> str:
    return str(path.expanduser().resolve(strict=False))


def skill_names(root: Path) -> list[str]:
    if not root.exists():
        return []
    names = []
    for entry in root.iterdir():
        # Visible skills are top-level directories that contain SKILL.md.
        # Ignore helper folders such as .system and editor/local metadata.
        if entry.is_dir() and (entry / "SKILL.md").is_file():
            names.append(entry.name)
    return sorted(set(names))


def broken_symlinks(root: Path) -> list[str]:
    if not root.exists():
        return [str(root)]
    broken = []
    for path in root.rglob("*"):
        if path.is_symlink() and not path.exists():
            broken.append(str(path))
    return sorted(broken)


def absolute_top_symlinks(root: Path) -> list[str]:
    if not root.exists():
        return []
    absolute = []
    for entry in root.iterdir():
        if entry.is_symlink():
            target = os.readlink(entry)
            if os.path.isabs(target):
                absolute.append(f"{entry} -> {target}")
    return sorted(absolute)


def iter_manifest_files(root: Path):
    if not root.exists():
        return
    for path in sorted(root.rglob("*"), key=lambda p: str(p)):
        if path.is_dir():
            continue
        if path.is_symlink():
            # Record symlink target text instead of dereferenced content so
            # portability issues change the manifest.
            yield path, f"symlink:{os.readlink(path)}".encode()
            continue
        if path.is_file():
            try:
                yield path, path.read_bytes()
            except OSError:
                continue


def surface_manifest(label: str, root: Path) -> dict:
    entries = []
    for path, data in iter_manifest_files(root) or []:
        rel = str(path.relative_to(root))
        entries.append({
            "path": rel,
            "sha256": sha256_bytes(data),
        })
    digest_payload = json.dumps(entries, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return {
        "label": label,
        "root": str(root),
        "file_count": len(entries),
        "sha256": sha256_bytes(digest_payload),
    }


def parse_doctor(text: str) -> dict:
    import re
    result = {"ok": False, "passed": None, "warnings": None, "failed": None}
    match = re.search(r"Results:\s*(\d+)\s+passed,\s*(\d+)\s+warnings,\s*(\d+)\s+failed", text)
    if match:
        passed, warnings, failed = map(int, match.groups())
        result.update({
            "ok": warnings == 0 and failed == 0,
            "passed": passed,
            "warnings": warnings,
            "failed": failed,
        })
    return result


ssot = Path(os.environ["PY_SSOT"]).expanduser()
claude_root = Path(os.environ["PY_CLAUDE_SKILLS_DIR"]).expanduser()
codex_root = Path(os.environ["PY_CODEX_SKILLS_DIR"]).expanduser()
legacy_root = Path(os.environ["PY_LEGACY_SKILLS_DIR"]).expanduser()
out = Path(os.environ["PY_OUT"]).expanduser()
design_root = ssot / "design"
allow_dirty = os.environ["PY_ALLOW_DIRTY"] == "1"
skip_fetch = os.environ["PY_SKIP_FETCH"] == "1"
skip_doctor = os.environ["PY_SKIP_DOCTOR"] == "1"

checks = []

def add_check(name, ok, **extra):
    checks.append({"name": name, "ok": bool(ok), **extra})


branch = run(["git", "symbolic-ref", "--short", "HEAD"], cwd=ssot).stdout.strip() or "HEAD"
if not skip_fetch and branch != "HEAD":
    run(["git", "fetch", "--quiet", "origin", branch], cwd=ssot)

head = run(["git", "rev-parse", "HEAD"], cwd=ssot, check=True).stdout.strip()
origin_ref = f"origin/{branch}" if branch != "HEAD" else "HEAD"
origin = run(["git", "rev-parse", origin_ref], cwd=ssot).stdout.strip()
if not origin:
    origin = head

status = run(["git", "status", "--porcelain"], cwd=ssot, check=True).stdout.splitlines()
clean = len(status) == 0
add_check("git_head_matches_origin", head == origin, head=head, origin=origin, branch=branch)
add_check("git_worktree_clean", clean or allow_dirty, clean=clean, dirty_entries=status)

claude_names = skill_names(claude_root)
codex_names = skill_names(codex_root)
missing_in_codex = sorted(set(claude_names) - set(codex_names))
missing_in_claude = sorted(set(codex_names) - set(claude_names))
shared = sorted(set(claude_names) & set(codex_names))
add_check("skill_name_sets_equal", not missing_in_codex and not missing_in_claude,
          missing_in_codex=missing_in_codex, missing_in_claude=missing_in_claude)

broken = broken_symlinks(codex_root) + broken_symlinks(claude_root)
absolute = absolute_top_symlinks(codex_root) + absolute_top_symlinks(claude_root)
add_check("no_broken_skill_symlinks", not broken, broken_symlinks=broken)
add_check("top_level_skill_symlinks_relative", not absolute, absolute_symlinks=absolute)
add_check("legacy_agents_skills_points_to_codex", real(legacy_root) == real(codex_root),
          legacy_real=real(legacy_root), codex_real=real(codex_root))

design_expected = {
    str(Path.home() / "DESIGN.md"): design_root / "DESIGN.md",
    str(Path.home() / "getdesign.md"): design_root / "getdesign.md",
    str(Path.home() / ".claude" / "DESIGN.md"): design_root / "DESIGN.md",
    str(Path.home() / ".claude" / "getdesign.md"): design_root / "getdesign.md",
    str(Path.home() / ".codex" / "DESIGN.md"): design_root / "DESIGN.md",
    str(Path.home() / ".codex" / "getdesign.md"): design_root / "getdesign.md",
}
design_links = []
for link, target in design_expected.items():
    lp = Path(link)
    tp = Path(target)
    design_links.append({
        "link": link,
        "target": str(target),
        "is_symlink": lp.is_symlink(),
        "resolves": real(lp) == real(tp),
        "target_exists": tp.is_file(),
    })
add_check("shared_design_entrypoints_linked", all(x["is_symlink"] and x["resolves"] and x["target_exists"] for x in design_links),
          design_links=design_links)

doctor = {"skipped": skip_doctor}
if not skip_doctor:
    proc = run(["omx", "doctor"], cwd=Path.home())
    doctor = {
        "skipped": False,
        "exit_code": proc.returncode,
        "summary": parse_doctor(proc.stdout + "\n" + proc.stderr),
    }
    add_check("omx_doctor_clean", proc.returncode == 0 and doctor["summary"].get("ok"), **doctor)

surfaces = [
    surface_manifest("claude", claude_root),
    surface_manifest("codex", codex_root),
]
combined_payload = json.dumps(surfaces, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
manifest = {
    "surfaces": surfaces,
    "combined_sha256": sha256_bytes(combined_payload),
}

attestation = {
    "schema": 1,
    "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
    "machine": socket.gethostname(),
    "ssot": str(ssot),
    "git": {
        "branch": branch,
        "head": head,
        "origin": origin,
        "clean": clean,
    },
    "skills": {
        "claude_count": len(claude_names),
        "codex_count": len(codex_names),
        "shared_count": len(shared),
        "missing_in_codex": missing_in_codex,
        "missing_in_claude": missing_in_claude,
        "name_set_sha256": sha256_bytes("\n".join(shared).encode()),
    },
    "manifest": manifest,
    "design": {
        "root": str(design_root),
        "links": design_links,
        "design_sha256": sha256_bytes((design_root / "DESIGN.md").read_bytes()) if (design_root / "DESIGN.md").is_file() else None,
        "getdesign_sha256": sha256_bytes((design_root / "getdesign.md").read_bytes()) if (design_root / "getdesign.md").is_file() else None,
    },
    "runtime": {
        "omx_doctor": doctor,
    },
    "checks": checks,
    "result": "PASS" if all(c["ok"] for c in checks) else "FAIL",
}

tmp = out.with_suffix(out.suffix + ".tmp")
tmp.write_text(json.dumps(attestation, ensure_ascii=False, indent=2) + "\n")
tmp.replace(out)

print(f"Sync Attestation: {attestation['result']}")
print(f"machine: {attestation['machine']}")
print(f"branch: {branch}")
print(f"head: {head[:12]}")
print(f"origin: {origin[:12]}")
print(f"clean: {clean}")
print(f"claude skills: {len(claude_names)}")
print(f"codex skills: {len(codex_names)}")
print(f"shared names: {len(shared)}")
print(f"name set sha256: {attestation['skills']['name_set_sha256']}")
print(f"manifest sha256: {manifest['combined_sha256']}")
print(f"design sha256: {attestation['design']['design_sha256']}")
print(f"getdesign sha256: {attestation['design']['getdesign_sha256']}")
if not skip_doctor:
    summary = doctor.get("summary", {})
    print(f"omx doctor: {summary.get('passed')} passed, {summary.get('warnings')} warnings, {summary.get('failed')} failed")
print(f"attestation: {out}")

if attestation["result"] != "PASS":
    print("\nFailed checks:", file=sys.stderr)
    for check in checks:
        if not check["ok"]:
            print(f"  - {check['name']}", file=sys.stderr)
    sys.exit(1)
PY
