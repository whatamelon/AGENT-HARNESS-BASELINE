#!/usr/bin/env python3
"""
designslop 전수 감사 (Tier F) — "Stop hook은 세션 수정파일만 스캔"의 구조적 보완.

quality-check.py 와 동일한 designslop_detectors.run_all 을 호출 → 로직 드리프트 0.
레포 전체를 1회 훑어 구조화 리포트(JSON+요약) 산출, baseline 대비 신규 위반만 게이트.

usage:
  designslop-audit.py <root> [--json out.json] [--baseline] [--quiet]
    --baseline : 현재 위반을 .designslop-baseline.json 으로 저장(수용 기준선)
    (baseline 존재 시 기본 동작 = baseline 대비 '신규' 위반만 비영점 종료)
exit: 0=신규 위반 없음, 1=신규 A위반 존재
"""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import designslop_detectors as ds  # noqa: E402

_IGNORE = {"node_modules", ".git", "dist", "build", ".next", ".expo",
           "ios", "android", "coverage", ".turbo", "__pycache__", ".omc", ".omx"}
_EXTS = (".tsx", ".jsx", ".ts", ".js")


def collect(root: Path):
    out = []
    for p in root.rglob("*"):
        if not p.is_file() or p.suffix not in _EXTS:
            continue
        if any(part in _IGNORE for part in p.parts):
            continue
        out.append(str(p))
    return sorted(out)


def flatten(r: dict):
    """run_all 결과 → {signature: line} 평탄화 (baseline 비교용)"""
    sigs = {}
    for tier in ("gate", "warn"):
        for kind, (_, details) in r[tier].items():
            for d in details:
                sigs[f"{tier}:{kind}:{d}"] = d
    return sigs


def main(argv):
    if len(argv) < 2:
        print("usage: designslop-audit.py <root> [--json out] [--baseline] [--quiet]")
        return 2
    root = Path(argv[1]).resolve()
    if not root.is_dir():
        print(f"ERROR: not a dir: {root}")
        return 2
    quiet = "--quiet" in argv
    make_baseline = "--baseline" in argv
    json_out = None
    if "--json" in argv:
        json_out = argv[argv.index("--json") + 1]

    files = collect(root)
    r = ds.run_all(files)
    sigs = flatten(r)
    baseline_path = root / ".designslop-baseline.json"

    if make_baseline:
        baseline_path.write_text(
            json.dumps(sorted(sigs.keys()), ensure_ascii=False, indent=2),
            encoding="utf-8")
        print(f"baseline 저장: {baseline_path} ({len(sigs)} signatures)")
        return 0

    known = set()
    if baseline_path.is_file():
        try:
            known = set(json.loads(baseline_path.read_text(encoding="utf-8")))
        except Exception:
            known = set()
    new_sigs = [s for s in sigs if s not in known]
    new_gate = [s for s in new_sigs if s.startswith("gate:")]

    report = {
        "root": str(root),
        "files_scanned": len(files),
        "gate_count": r["gate_count"],
        "warn_count": r["warn_count"],
        "ledger_count": len(r["review_ledger"]),
        "baseline_known": len(known),
        "new_violations": len(new_sigs),
        "new_gate_violations": len(new_gate),
        "gate": {k: v[1] for k, v in r["gate"].items()},
        "warn": {k: v[1] for k, v in r["warn"].items()},
        "review_ledger": r["review_ledger"],
        "new": new_sigs,
    }
    if json_out:
        Path(json_out).write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if not quiet:
        print(f"=== designslop audit: {root} ===")
        print(f"scanned {len(files)} files | "
              f"A(gate)={r['gate_count']} B(warn)={r['warn_count']} "
              f"ledger={len(r['review_ledger'])}")
        if known:
            print(f"baseline={len(known)} → 신규 위반 {len(new_sigs)} "
                  f"(신규 A {len(new_gate)})")
        for tier in ("gate", "warn"):
            for kind, (c, det) in r[tier].items():
                if c:
                    print(f"  [{tier}/{kind}] {c}")
                    for d in det[:8]:
                        print(f"    - {d}")
        if r["review_ledger"]:
            print(f"  [ledger] {len(r['review_ledger'])} (퍼지 추적)")

    return 1 if new_gate else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
