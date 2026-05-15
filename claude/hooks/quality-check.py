#!/usr/bin/env python3
"""
🏭 완료 후 품질 검사 시스템
Stop 훅에서 실행 — 3가지 역할:
  1. 수정 기록 확인 (CCTV 요약)
  2. 오류 자동 체크 (TypeScript / Python)
  3. 어깨너머 선배 체크리스트 (에러처리 / 보안)
"""
import sys
import json
import subprocess
from pathlib import Path

# 디텍터는 단일 소스 모듈에서 import (hook ↔ audit 드리프트 0).
# fail-safe: 부분 동기화/미설치 머신에서 모듈이 없어도 quality-check 자체는
# 절대 죽지 않는다 (ts/py/CCTV 체크 보존). 디자인 슬롭만 조용히 비활성.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import designslop_detectors as ds  # noqa: E402
except Exception:
    class _NoopDS:
        @staticmethod
        def run_all(_files):
            z = (0, [])
            return {
                "gate": {"eyebrow": z, "icon": z, "border": z,
                         "emoji": z, "nav": z},
                "warn": {"hex": z, "list": z, "modal": z, "shadow": z},
                "gate_count": 0, "warn_count": 0, "review_ledger": [],
            }
    ds = _NoopDS()


def check_typescript_errors(files: list) -> tuple:
    """TypeScript 오류 체크 (tsconfig가 있는 프로젝트만)"""
    ts_files = [f for f in files if f.endswith((".ts", ".tsx"))]
    if not ts_files:
        return 0, []

    # tsconfig.json 위치 탐색
    tsconfig_dir = None
    for f in ts_files:
        d = Path(f).parent
        while str(d) != str(d.parent):
            if (d / "tsconfig.json").exists():
                tsconfig_dir = d
                break
            d = d.parent
        if tsconfig_dir:
            break

    if not tsconfig_dir:
        return 0, []

    try:
        result = subprocess.run(
            ["npx", "tsc", "--noEmit", "--pretty", "false"],
            capture_output=True,
            text=True,
            cwd=tsconfig_dir,
            timeout=30,
        )
        combined = result.stdout + result.stderr
        error_lines = [l.strip() for l in combined.splitlines() if "error TS" in l]
        return len(error_lines), error_lines[:5]
    except Exception:
        return 0, []


def check_python_errors(files: list) -> tuple:
    """Python 문법 오류 체크"""
    py_files = [f for f in files if f.endswith(".py") and Path(f).exists()]
    errors = []

    for f in py_files:
        try:
            result = subprocess.run(
                ["python3", "-m", "py_compile", f],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode != 0:
                errors.append(f"{Path(f).name}: {result.stderr.strip()[:80]}")
        except Exception:
            pass

    return len(errors), errors


def main():
    try:
        input_data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    # 무한루프 방지: Stop 훅이 이미 Claude 재실행을 유발한 경우
    if input_data.get("stop_hook_active"):
        sys.exit(0)

    session_id = input_data.get("session_id", "unknown")

    log_dir = Path.home() / ".claude" / "logs"
    session_file = log_dir / "sessions" / f"{session_id}.txt"

    # 이번 세션에 수정된 파일이 없으면 조용히 종료
    if not session_file.exists():
        sys.exit(0)

    content = session_file.read_text(encoding="utf-8").strip()
    if not content:
        session_file.unlink(missing_ok=True)
        sys.exit(0)

    files = [f.strip() for f in content.splitlines() if f.strip()]
    file_count = len(files)

    # 세션 파일 소비 (한 번만 체크하도록)
    session_file.unlink(missing_ok=True)

    # ── 오류 체크 ──────────────────────────────────────
    ts_errors, ts_details = check_typescript_errors(files)
    py_errors, py_details = check_python_errors(files)
    _r = ds.run_all(files)
    eb_count, eb_details = _r["gate"]["eyebrow"]
    d1_count, d1_details = _r["gate"]["icon"]
    d2_count, d2_details = _r["gate"]["border"]
    em_count, em_details = _r["gate"]["emoji"]
    nav_count, nav_details = _r["gate"]["nav"]
    d3_count, d3_details = _r["warn"]["hex"]
    d4_count, d4_details = _r["warn"]["list"]
    d7_count, d7_details = _r["warn"]["modal"]
    d9_count, d9_details = _r["warn"]["shadow"]
    gate_count = _r["gate_count"]
    warn_count = _r["warn_count"]
    ledger = _r["review_ledger"]
    total_errors = ts_errors + py_errors

    # ── 출력 구성 ───────────────────────────────────────
    lines = []
    lines.append(f"## 🔍 자동 품질 검사 | 수정 파일 {file_count}개")
    lines.append("")

    # 디자인 슬롭 A계층 — 최상단 강제 (글로벌 Iron Law)
    if gate_count > 0:
        lines.append(f"### 🚫 디자인 슬롭(A) {gate_count}건 — 반드시 수정")
        if eb_count > 0:
            lines.append(f"**장식 eyebrow / 영문 UI 라벨 ({eb_count})**")
            for d in eb_details:
                lines.append(f"- `{d}`")
        if d1_count > 0:
            lines.append(f"**아이콘 라이브러리 혼용 ({d1_count})** — 단일 세트로 통일")
            for d in d1_details:
                lines.append(f"- `{d}`")
        if d2_count > 0:
            lines.append(f"**border/radius arbitrary 값 ({d2_count})** — 디자인 토큰 사용")
            for d in d2_details:
                lines.append(f"- `{d}`")
        if em_count > 0:
            lines.append(f"**이모지 데코 ({em_count})** — 제거 또는 lucide 아이콘 치환")
            for d in em_details:
                lines.append(f"- `{d}`")
        if nav_count > 0:
            lines.append(f"**글로벌 네비 오노출 ({nav_count})** — 비-탭루트에서 제거 (.designslop.json 선언 기준)")
            for d in nav_details:
                lines.append(f"- `{d}`")
        lines.append("")
        lines.append(
            "→ 룰: `~/.config/claude-sync/claude/rules/no-design-slop.md` · "
            "`no-decorative-eyebrow.md` (예외: 브랜드 고유명사, 통용 약어, var/theme 토큰)"
        )
        lines.append("")

    # 디자인 슬롭 B계층 — 점검 경고 (비차단)
    if warn_count > 0:
        lines.append(f"### ⚠️ 디자인 슬롭(B) 점검 {warn_count}건")
        if d3_count > 0:
            lines.append(f"**컴포넌트 raw hex ({d3_count})** — 토큰 매칭 시 전환 (shadowColor/SVG/브랜드 예외)")
            for d in d3_details:
                lines.append(f"- `{d}`")
        if d4_count > 0:
            lines.append(f"**리스트 빈 상태 누락 ({d4_count})** — ListEmptyComponent 추가")
            for d in d4_details:
                lines.append(f"- `{d}`")
        if d7_count > 0:
            lines.append(f"**Modal 닫기 누락 ({d7_count})** — onRequestClose/백드롭")
            for d in d7_details:
                lines.append(f"- `{d}`")
        if d9_count > 0:
            lines.append(f"**과도한 shadow ({d9_count})** — 평평+hairline 우선")
            for d in d9_details:
                lines.append(f"- `{d}`")
        lines.append("")

    # review 레저 — 정규식으로 못 거르는 퍼지 케이스를 버리지 않고 추적(비차단)
    if ledger:
        try:
            with open(log_dir / "designslop-review.jsonl", "a", encoding="utf-8") as lf:
                for e in ledger:
                    lf.write(json.dumps(e, ensure_ascii=False) + "\n")
        except Exception:
            pass
        lines.append(f"### 🗂 review 레저 +{len(ledger)}건 (퍼지 케이스 추적 · 비차단)")
        for e in ledger[:6]:
            lines.append(f"- `{e['file']}` {e['kind']}: {e['note']}")
        lines.append("")

    # CCTV 기록
    lines.append("### 📋 CCTV 기록 (이번 세션)")
    for f in files:
        name = Path(f).name
        mark = "✓" if Path(f).exists() else "✗"
        lines.append(f"- {mark} `{name}`")
    lines.append("")

    # 오류 검사 결과
    if total_errors == 0:
        lines.append("### 🔬 오류 검사: ✅ 이상 없음")
    else:
        lines.append(f"### 🔬 오류 검사: {total_errors}개 발견")
        if ts_errors > 0:
            lines.append(f"- TypeScript: {ts_errors}개 오류")
            for d in ts_details:
                lines.append(f"  - `{d}`")
        if py_errors > 0:
            lines.append(f"- Python: {py_errors}개 오류")
            for d in py_details:
                lines.append(f"  - `{d}`")
        lines.append("")
        if total_errors <= 5:
            lines.append(
                "⚠️ **오류가 적습니다** → 지금 바로 수정해주세요."
            )
        else:
            lines.append("🚨 **오류가 많습니다** → 전문 에이전트를 사용하세요:")
            lines.append("- `/oh-my-claudecode:build-fix` — 빌드 오류 전문")
            lines.append("- `/oh-my-claudecode:ultraqa` — 종합 QA 사이클")

    # 셀프체크 리마인더
    lines.append("")
    lines.append("---")
    lines.append(f"### 👀 어깨너머 선배 체크 | 파일 {file_count}개")
    lines.append("")
    lines.append("방금 수정한 파일들, 이것도 확인했나요?")
    lines.append("")
    lines.append("1. ❓ **에러 처리** — 예외 상황은 처리했나요?")
    lines.append("2. ❓ **보안** — 하드코딩된 값, 입력 검증, 권한 확인 완료?")

    # stdout → Claude에게 전달 (exit 2)
    print("\n".join(lines))
    sys.exit(2)


if __name__ == "__main__":
    main()
