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
import re
import subprocess
from pathlib import Path

# 장식 eyebrow / 영문 UI 라벨 강제 게이트
# 룰 SSOT: ~/.config/claude-sync/claude/rules/no-decorative-eyebrow.md
#
# 허용(고유명사/플랫폼/한국 통용 약어) — 이건 슬롭 아님
EYEBROW_ALLOW = {
    "YOUTUBE", "INSTAGRAM", "KAKAO", "NAVER", "TIKTOK", "X",
    "BMW", "AUDI", "BENZ", "KIA", "GENESIS", "TESLA", "VOLVO", "LEXUS",
    "CEO", "VIP", "EV", "PT", "AS", "OK", "ID", "OS", "QR", "FAQ", "CS",
}
# eyebrow 스타일 시그널 (섹션 타이틀 위 장식 키커)
_EYEBROW_STYLE = ("uppercase", "tracking-wider")
# 영문 ALL CAPS 리터럴 (한글 없음, 변수보간 없음)
_RX_LABEL_PROP = re.compile(r'label\s*[=:]\s*["\']([^"\'{}]+)["\']')
_RX_JSX_TEXT = re.compile(r'>\s*([A-Z][A-Z0-9 ._·\-&/]{2,})\s*<')
_RX_HANGUL = re.compile(r'[가-힣]')


def _is_english_allcaps_slop(text: str) -> bool:
    t = text.strip()
    if not t or _RX_HANGUL.search(t) or "{" in t:
        return False
    letters = [c for c in t if c.isalpha()]
    if not letters or not all(c.isascii() and c.isupper() for c in letters):
        return False
    if len([c for c in letters]) < 2:
        return False
    # 토큰이 전부 allowlist면 통과 (예: "CEO", "BMW")
    tokens = [w for w in re.split(r'[ ·/&\-_.]+', t) if w]
    if tokens and all(w in EYEBROW_ALLOW for w in tokens):
        return False
    return True


def check_eyebrow_slop(files: list) -> tuple:
    """장식 eyebrow / 비기능 영문 UI 라벨 탐지 (세션 수정 파일만)"""
    hits = []
    for f in files:
        if not f.endswith((".tsx", ".jsx", ".ts", ".js")):
            continue
        p = Path(f)
        if not p.exists() or p.name == "quality-check.py":
            continue
        try:
            lines = p.read_text(encoding="utf-8").splitlines()
        except Exception:
            continue
        for i, line in enumerate(lines):
            stripped = line.lstrip()
            # 주석 라인 제외 (예시/문서가 오탐 안 되게)
            if stripped.startswith(("//", "*", "/*", "#")):
                continue
            # 1) label= / label: 영문 ALL CAPS 리터럴
            for m in _RX_LABEL_PROP.finditer(line):
                if _is_english_allcaps_slop(m.group(1)):
                    hits.append(f"{p.name}:{i+1}  label \"{m.group(1).strip()}\"")
            # 2) eyebrow 스타일 className + 인접 영문 ALL CAPS JSX 텍스트
            window = "\n".join(lines[i:i + 3])
            if all(s in line for s in _EYEBROW_STYLE):
                for m in _RX_JSX_TEXT.finditer(window):
                    if _is_english_allcaps_slop(m.group(1)):
                        hits.append(f"{p.name}:{i+1}  eyebrow \"{m.group(1).strip()}\"")
    # 중복 제거 (순서 보존)
    seen = set()
    uniq = []
    for h in hits:
        if h not in seen:
            seen.add(h)
            uniq.append(h)
    return len(uniq), uniq[:12]


# ── no-design-slop A/B 게이트 ──────────────────────────
# 룰 SSOT: ~/.config/claude-sync/claude/rules/no-design-slop.md

_COMMENT_PREFIX = ("//", "*", "/*", "#")


def _iter_code_lines(files, exts):
    """주석 제외 코드 라인 yield: (path, lineno, line)"""
    for f in files:
        if not f.endswith(exts):
            continue
        p = Path(f)
        if not p.exists() or p.name == "quality-check.py":
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        for i, line in enumerate(text.splitlines()):
            if line.lstrip().startswith(_COMMENT_PREFIX):
                continue
            yield p, i + 1, line


def _dedup(hits, cap=12):
    seen, out = set(), []
    for h in hits:
        if h not in seen:
            seen.add(h)
            out.append(h)
    return len(out), out[:cap]


# D1 — 아이콘 라이브러리 혼용 (한 파일에 2+ 패밀리)
_ICON_FAMILY = [
    (re.compile(r'["\']lucide-react(-native)?["\']'), "lucide"),
    (re.compile(r'["\']@heroicons/'), "heroicons"),
    (re.compile(r'["\']react-icons'), "react-icons"),
    (re.compile(r'["\']@expo/vector-icons'), "expo-vector-icons"),
    (re.compile(r'["\']react-native-vector-icons'), "rn-vector-icons"),
    (re.compile(r'["\'](@phosphor-icons/|phosphor-react)'), "phosphor"),
    (re.compile(r'["\']@tabler/icons'), "tabler"),
    (re.compile(r'["\']react-feather["\']'), "feather"),
]


def check_icon_mixing(files: list) -> tuple:
    hits = []
    cur = None
    fams = set()
    for p, ln, line in _iter_code_lines(files, (".tsx", ".jsx", ".ts", ".js")):
        if cur is not None and p != cur:
            if len(fams) >= 2:
                hits.append(f"{cur.name}  아이콘 라이브러리 혼용: {', '.join(sorted(fams))}")
            fams = set()
        cur = p
        if "import" in line or "require(" in line:
            for rx, name in _ICON_FAMILY:
                if rx.search(line):
                    fams.add(name)
    if cur is not None and len(fams) >= 2:
        hits.append(f"{cur.name}  아이콘 라이브러리 혼용: {', '.join(sorted(fams))}")
    return _dedup(hits)


# D2 — border/radius arbitrary 값 (디자인 토큰 위반)
_RX_ARBITRARY = re.compile(r'\b(rounded|border)(-[a-zA-Z]+)*-\[[^\]]+\]')
_RX_TOKEN_OK = re.compile(r'-\[(var\(|theme\()')


def check_border_radius_arbitrary(files: list) -> tuple:
    hits = []
    for p, ln, line in _iter_code_lines(files, (".tsx", ".jsx")):
        for m in _RX_ARBITRARY.finditer(line):
            if _RX_TOKEN_OK.search(m.group(0)):
                continue
            hits.append(f"{p.name}:{ln}  arbitrary `{m.group(0)}`")
    return _dedup(hits)


# D3 — 컴포넌트 내 arbitrary hex (토큰/테마/SVG/shadow 제외) — 경고(B)
_RX_HEX = re.compile(r'#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3}(?:[0-9a-fA-F]{2})?)?\b')
_RX_PATH_TOKEN = re.compile(r'(colors|theme|tokens?|palette|tailwind\.config|/design|\.config\.)', re.I)


def check_arbitrary_hex(files: list) -> tuple:
    hits = []
    for f in files:
        if not f.endswith((".tsx", ".jsx")):
            continue
        if _RX_PATH_TOKEN.search(f):
            continue
        p = Path(f)
        if not p.exists():
            continue
        try:
            raw = p.read_text(encoding="utf-8")
        except Exception:
            continue
        for i, line in enumerate(raw.splitlines()):
            s = line.lstrip()
            if s.startswith(_COMMENT_PREFIX):
                continue
            # SVG 내부 구조색 / RN shadow 관용구 / 브랜드 표기는 예외
            if any(t in line for t in ("shadowColor", "fill=", "<Path", "<Svg", 'd="M', "BRAND", "brand")):
                continue
            for m in _RX_HEX.finditer(line):
                hx = m.group(0).lower()
                if hx in ("#000", "#fff", "#000000", "#ffffff"):
                    continue
                hits.append(f"{p.name}:{i+1}  raw hex `{m.group(0)}` → 토큰 사용")
    return _dedup(hits)


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
    eb_count, eb_details = check_eyebrow_slop(files)
    d1_count, d1_details = check_icon_mixing(files)
    d2_count, d2_details = check_border_radius_arbitrary(files)
    d3_count, d3_details = check_arbitrary_hex(files)
    gate_count = eb_count + d1_count + d2_count
    total_errors = ts_errors + py_errors

    # ── 출력 구성 ───────────────────────────────────────
    lines = []
    lines.append(f"## 🔍 자동 품질 검사 | 수정 파일 {file_count}개")
    lines.append("")

    # 장식 eyebrow / 영문 라벨 — 최상단 강제 (글로벌 Iron Law)
    if eb_count > 0:
        lines.append(f"### 🚫 장식 eyebrow / 영문 UI 라벨 슬롭: {eb_count}건 — 반드시 수정")
        for d in eb_details:
            lines.append(f"- `{d}`")
        lines.append("")
        lines.append(
            "→ 섹션 타이틀 위 키커 제거 / 영문 라벨 한국어화. "
            "예외: 브랜드·플랫폼 고유명사, 통용 약어(CEO 등). "
            "룰: `~/.config/claude-sync/claude/rules/no-decorative-eyebrow.md`"
        )
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
