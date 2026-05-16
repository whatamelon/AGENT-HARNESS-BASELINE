#!/usr/bin/env python3
"""
no-design-slop 디텍터 — 단일 소스 (SSOT).

quality-check.py(Stop 게이트, 세션 수정파일) 와 designslop-audit.py(전수 감사)
양쪽이 이 모듈만 호출 → 로직 드리프트 0.

룰 SSOT: ~/.config/agent-harness-baseline/claude/rules/no-design-slop.md
구조 계층:
  A 강제(exit2): eyebrow/영문라벨, D1 아이콘혼용, D2 border·radius arbitrary,
                 D-EMOJI 이모지데코, D6 네비(프로젝트 매니페스트 선언 시)
  B 경고      : D3 raw hex, D4 리스트 빈상태, D7 Modal close, D9 과도 shadow
  레저(추적)  : 정규식으로 못 거르는 퍼지 케이스를 버리지 않고 review 레저에 적재
프로젝트 확장: 레포 루트의 `.designslop.json` 로 네비 컴포넌트명/예외를 선언
"""
import re
import json
from pathlib import Path

_COMMENT_PREFIX = ("//", "*", "/*", "#")

# ── 공유 헬퍼 ─────────────────────────────────────────


def _iter_code_lines(files, exts):
    """주석 제외 코드 라인 yield: (path, lineno, line)"""
    for f in files:
        if not f.endswith(exts):
            continue
        p = Path(f)
        if not p.exists() or p.name in ("quality-check.py", "designslop_detectors.py"):
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        for i, line in enumerate(text.splitlines()):
            if line.lstrip().startswith(_COMMENT_PREFIX):
                continue
            yield p, i + 1, line


# 테스트/스토리/목 파일은 출하 UI 아님 → 디텍터 대상 제외 (의도적 픽스처 문자열)
_IS_FIXTURE = re.compile(r'(\.test\.|\.spec\.|\.stories\.|/__tests__/|/__mocks__/|\.cy\.|/e2e/)')


def _is_fixture(path: str) -> bool:
    return bool(_IS_FIXTURE.search(path.replace("\\", "/")))


def _dedup(hits, cap=12):
    seen, out = set(), []
    for h in hits:
        if h not in seen:
            seen.add(h)
            out.append(h)
    return len(out), out[:cap]


# ── 프로젝트 매니페스트 (D6/예외의 구조적 해법) ────────
# "전역 컴포넌트명이 프로젝트마다 다름"을 추측이 아니라 선언으로 해결.


def find_manifest(start_dir: str):
    """start_dir 에서 위로 올라가며 .designslop.json 탐색 (없으면 None).
    캐시 없음 — None 캐싱 시 동일 프로세스에서 매니페스트 추가가 stale 됨."""
    d = Path(start_dir)
    for _ in range(40):
        mf = d / ".designslop.json"
        if mf.is_file():
            try:
                return json.loads(mf.read_text(encoding="utf-8"))
            except Exception:
                return None
        if d.parent == d:
            break
        d = d.parent
    return None


# ── eyebrow / 영문 UI 라벨 (A) ────────────────────────
EYEBROW_ALLOW = {
    "YOUTUBE", "INSTAGRAM", "KAKAO", "NAVER", "TIKTOK", "X",
    "BMW", "AUDI", "BENZ", "KIA", "GENESIS", "TESLA", "VOLVO", "LEXUS",
    "CEO", "VIP", "EV", "PT", "AS", "OK", "ID", "OS", "QR", "FAQ", "CS",
}
_EYEBROW_STYLE = ("uppercase", "tracking-wider")
_RX_LABEL_PROP = re.compile(r'label\s*[=:]\s*["\']([^"\'{}]+)["\']')
_RX_JSX_TEXT = re.compile(r'>\s*([A-Z][A-Z0-9 ._·\-&/]{2,})\s*<')
_RX_HANGUL = re.compile(r'[가-힣]')


def _is_english_allcaps_slop(text: str, allow: set) -> bool:
    t = text.strip()
    if not t or _RX_HANGUL.search(t) or "{" in t:
        return False
    letters = [c for c in t if c.isalpha()]
    if not letters or not all(c.isascii() and c.isupper() for c in letters):
        return False
    if len(letters) < 2:
        return False
    if t in allow:  # 선언된 다단어 예외 원문 매칭 (예: "WIN THIS")
        return False
    tokens = [w for w in re.split(r'[ ·/&\-_.]+', t) if w]
    if tokens and all(w in allow for w in tokens):
        return False
    return True


def check_eyebrow_slop(files: list) -> tuple:
    hits = []
    for f in files:
        if not f.endswith((".tsx", ".jsx", ".ts", ".js")):
            continue
        p = Path(f)
        if not p.exists() or p.name in ("quality-check.py", "designslop_detectors.py"):
            continue
        mf = find_manifest(str(p.parent)) or {}
        mf_labels = list(mf.get("allow", {}).get("englishLabels", []))
        allow = (EYEBROW_ALLOW | set(mf_labels)
                 | {w for lbl in mf_labels
                    for w in re.split(r'[ ·/&\-_.]+', lbl) if w})
        try:
            lines = p.read_text(encoding="utf-8").splitlines()
        except Exception:
            continue
        for i, line in enumerate(lines):
            if line.lstrip().startswith(_COMMENT_PREFIX):
                continue
            for m in _RX_LABEL_PROP.finditer(line):
                if _is_english_allcaps_slop(m.group(1), allow):
                    hits.append(f"{p.name}:{i+1}  label \"{m.group(1).strip()}\"")
            window = "\n".join(lines[i:i + 3])
            if all(s in line for s in _EYEBROW_STYLE):
                for m in _RX_JSX_TEXT.finditer(window):
                    if _is_english_allcaps_slop(m.group(1), allow):
                        hits.append(f"{p.name}:{i+1}  eyebrow \"{m.group(1).strip()}\"")
    return _dedup(hits)


# ── D1 아이콘 라이브러리 혼용 (A) ─────────────────────
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


# ── D2 border/radius arbitrary (A) ────────────────────
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


# ── D3 컴포넌트 raw hex (B) ───────────────────────────
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
            if any(t in line for t in ("fill=", "<Path", "<Svg", 'd="M', "BRAND", "brand")):
                continue
            for m in _RX_HEX.finditer(line):
                hx = m.group(0).lower()
                if hx in ("#000", "#fff", "#000000", "#ffffff"):
                    continue
                if "shadowColor" in line[max(0, m.start() - 16):m.start()]:
                    continue
                hits.append(f"{p.name}:{i+1}  raw hex `{m.group(0)}` → 토큰 사용")
    return _dedup(hits)


# ── D-EMOJI 이모지 데코 (A) ───────────────────────────
# 텍스트 통용 글리프 제외: 화살표, ✓(2713), ★☆(2605/06), ♠♥♦♣(2660-2667),
# 1F000-1F2FF(마작/카드). 데코 본체는 1F300↑ + 큐레이트 BMP.
_RX_EMOJI = re.compile(
    "["
    "\U0001F300-\U0001FAFF"
    "\U00002600-\U00002604\U00002607-\U0000265F\U00002668-\U000026FF"
    "\U0001F1E6-\U0001F1FF"
    "\U0000231A\U0000231B\U000023E9-\U000023FF"
    "\U00002705\U00002708\U00002728\U00002733\U00002734"
    "\U0000274C\U00002764\U00002B50\U00002B55"
    "]"
)


def check_emoji_deco(files: list) -> tuple:
    hits = []
    for p, ln, line in _iter_code_lines(files, (".tsx", ".jsx")):
        s = line.lstrip()
        if s.startswith("import ") or "require(" in line:
            continue
        seen = "".join(sorted(set(_RX_EMOJI.findall(line))))
        if seen:
            hits.append(f"{p.name}:{ln}  이모지 데코 `{seen}` — 제거 or lucide 아이콘")
    return _dedup(hits)


# ── D6 글로벌 네비/헤더 (A, 매니페스트 선언 시에만) ────
# "컴포넌트명이 프로젝트마다 다름"의 구조적 해법: 추측 안 함, 프로젝트가 선언.
# .designslop.json:
#   {"nav":{"globalComponents":["GlobalBottomNav"],
#           "tabRootGlobs":["**/(tabs)/**"]}}
def check_nav_violations(files: list) -> tuple:
    hits = []
    for f in files:
        if not f.endswith((".tsx", ".jsx")):
            continue
        p = Path(f)
        if not p.exists():
            continue
        mf = find_manifest(str(p.parent))
        nav = (mf or {}).get("nav") if mf else None
        if not nav or not nav.get("globalComponents"):
            continue  # 선언 없으면 비활성 → 오탐 0
        tab_globs = nav.get("tabRootGlobs", [])
        posix = p.as_posix()
        is_tab_root = any(Path(posix).match(g) for g in tab_globs)
        if is_tab_root:
            continue
        try:
            t = p.read_text(encoding="utf-8")
        except Exception:
            continue
        for comp in nav["globalComponents"]:
            if re.search(r'<%s[\s/>]' % re.escape(comp), t):
                hits.append(
                    f"{p.name}  비-탭루트에 글로벌 네비 `<{comp}>` 노출 "
                    f"(.designslop.json nav 선언 기준)"
                )
                break
    return _dedup(hits)


# ── D4 리스트 빈 상태 (B) ─────────────────────────────
def check_list_empty_state(files: list) -> tuple:
    hits = []
    for f in files:
        if not f.endswith((".tsx", ".jsx")):
            continue
        p = Path(f)
        if not p.exists():
            continue
        try:
            t = p.read_text(encoding="utf-8")
        except Exception:
            continue
        if ("<FlatList" in t or "<SectionList" in t) and "ListEmptyComponent" not in t:
            hits.append(f"{p.name}  FlatList/SectionList — ListEmptyComponent(빈 상태) 누락")
    return _dedup(hits)


# ── D7 RN Modal close (B) ─────────────────────────────
def check_modal_close(files: list) -> tuple:
    hits = []
    for f in files:
        if not f.endswith((".tsx", ".jsx")):
            continue
        p = Path(f)
        if not p.exists():
            continue
        try:
            t = p.read_text(encoding="utf-8")
        except Exception:
            continue
        if re.search(r'<Modal[\s>]', t) and "onRequestClose" not in t:
            hits.append(f"{p.name}  <Modal> onRequestClose(백/뒤로가기 닫기) 누락")
    return _dedup(hits)


# ── D9 과도 shadow (B) ────────────────────────────────
_RX_SHADOW_R = re.compile(r'shadowRadius:\s*([0-9]+(?:\.[0-9]+)?)')
_RX_ELEVATION = re.compile(r'elevation:\s*([0-9]+)')


def check_excessive_shadow(files: list) -> tuple:
    hits = []
    for p, ln, line in _iter_code_lines(files, (".tsx", ".jsx")):
        for m in _RX_SHADOW_R.finditer(line):
            if float(m.group(1)) > 16:
                hits.append(f"{p.name}:{ln}  shadowRadius {m.group(1)} (>16 과함)")
        for m in _RX_ELEVATION.finditer(line):
            if int(m.group(1)) > 12:
                hits.append(f"{p.name}:{ln}  elevation {m.group(1)} (>12 과함)")
    return _dedup(hits)


# ── 레저(추적) — 정규식이 못 거르는 퍼지 케이스를 버리지 않음 ──
# 못 잡는 게 아니라 "불확실"로 구조화 → review 큐로 이관(비차단).
_RX_MAP_JSX = re.compile(r'\.map\(\s*\(?[\w{},\s]*\)?\s*=>\s*[\(<]')
_RX_CUSTOM_OVERLAY = re.compile(r'<([A-Z]\w*)(Sheet|Dialog|Popup|Drawer)\b')
_RX_SHADOW_COMPUTED = re.compile(r'shadowRadius:\s*[^\d\s]')


def collect_review_ledger(files: list) -> list:
    out = []
    for f in files:
        if not f.endswith((".tsx", ".jsx")):
            continue
        p = Path(f)
        if not p.exists():
            continue
        try:
            t = p.read_text(encoding="utf-8")
        except Exception:
            continue
        if _RX_MAP_JSX.search(t) and not any(
            k in t for k in ("ListEmptyComponent", "Empty", "Skeleton", "length === 0", "length===0", ".length ? ")
        ):
            out.append({"file": p.name, "kind": "list-map-no-empty",
                        "note": ".map 렌더 리스트 — 빈/로딩 상태 확인 필요(정규식 판별 불가)"})
        for m in _RX_CUSTOM_OVERLAY.finditer(t):
            if "onRequestClose" not in t and "onClose" not in t and "backdrop" not in t.lower():
                out.append({"file": p.name, "kind": "custom-overlay-review",
                            "note": f"커스텀 오버레이 <{m.group(1)}{m.group(2)}> 닫기 동선 확인 필요"})
                break
        if _RX_SHADOW_COMPUTED.search(t):
            out.append({"file": p.name, "kind": "computed-shadow-review",
                        "note": "계산식 shadowRadius — 과도 여부 수치 판별 불가, 리뷰 필요"})
    # dedup
    seen, uniq = set(), []
    for e in out:
        k = (e["file"], e["kind"])
        if k not in seen:
            seen.add(k)
            uniq.append(e)
    return uniq


# ── 단일 진입점 (hook + audit 공용) ───────────────────
def run_all(files: list) -> dict:
    """모든 디텍터 1회 실행. hook/audit 가 이 dict 만 소비 → 드리프트 0."""
    files = [f for f in files if not _is_fixture(f)]
    gate = {
        "eyebrow": check_eyebrow_slop(files),
        "icon": check_icon_mixing(files),
        "border": check_border_radius_arbitrary(files),
        "emoji": check_emoji_deco(files),
        "nav": check_nav_violations(files),
    }
    warn = {
        "hex": check_arbitrary_hex(files),
        "list": check_list_empty_state(files),
        "modal": check_modal_close(files),
        "shadow": check_excessive_shadow(files),
    }
    gate_count = sum(c for c, _ in gate.values())
    warn_count = sum(c for c, _ in warn.values())
    return {
        "gate": gate,
        "warn": warn,
        "gate_count": gate_count,
        "warn_count": warn_count,
        "review_ledger": collect_review_ledger(files),
    }
