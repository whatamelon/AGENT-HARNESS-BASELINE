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
    total_errors = ts_errors + py_errors

    # ── 출력 구성 ───────────────────────────────────────
    lines = []
    lines.append(f"## 🔍 자동 품질 검사 | 수정 파일 {file_count}개")
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
