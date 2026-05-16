#!/usr/bin/env bash
# designslop-doctor — 어느 머신/어느 에이전트에서도 designslop 강제계가
# 실제로 배선됐는지 단언. Claude Code + Codex 양쪽 점검.
# 새 머신 bootstrap / 정기 sync 후 실행. doctor.sh 가 끝에서 호출.
set -uo pipefail

SSOT="${AGENT_HARNESS_BASELINE_HOME:-$HOME/.config/agent-harness-baseline}"
HOOKS="$SSOT/claude/hooks"
RULES="$SSOT/claude/rules"
fail=0
ok() { echo "  ✓ $1"; }
bad() { echo "  ✗ $1"; echo "    → $2"; fail=1; }

echo "── designslop-doctor ──"

# 1. python3
if command -v python3 >/dev/null 2>&1; then ok "python3"; else
  bad "python3 없음" "macOS python3 설치 필요 (xcode-select --install)"; fi

# 2. 단일 소스 모듈 컴파일
if [ -f "$HOOKS/designslop_detectors.py" ] && \
   python3 -m py_compile "$HOOKS/designslop_detectors.py" 2>/dev/null; then
  ok "designslop_detectors.py 컴파일"
else
  bad "designslop_detectors.py 누락/문법오류" "agent-harness-baseline git pull && bash $SSOT/bin/install.sh"; fi

# 3. quality-check 가 모듈 import (fail-safe 포함)
if [ -f "$HOOKS/quality-check.py" ] && python3 -c "
import sys; sys.path.insert(0,'$HOOKS')
import importlib.util as u
spec=u.spec_from_file_location('qc','$HOOKS/quality-check.py'); m=u.module_from_spec(spec)
spec.loader.exec_module(m); assert hasattr(m,'ds') and hasattr(m.ds,'run_all')
" 2>/dev/null; then
  ok "quality-check.py → ds.run_all 결선"
else
  bad "quality-check.py 모듈 결선 실패" "install.sh 재실행 / 모듈 동기화 확인"; fi

# 4. Claude Code 게이트 배선 (라이브 + SSOT 템플릿)
grep -q "quality-check.py" "$HOME/.claude/settings.json" 2>/dev/null \
  && ok "Claude settings.json Stop 게이트" \
  || bad "Claude settings.json 에 quality-check Stop 없음" "bash $SSOT/bin/install.sh"
grep -q "quality-check.py" "$SSOT/claude/settings.shared.json" 2>/dev/null \
  && ok "Claude SSOT 템플릿(settings.shared.json)" \
  || bad "SSOT settings.shared.json 에 게이트 없음 → 새 머신서 미배선" "settings.shared.json 에 Stop hook 추가"

# 5. Codex 게이트 배선 (라이브 + SSOT 템플릿)
grep -q "quality-check.py" "$HOME/.codex/hooks.json" 2>/dev/null \
  && ok "Codex hooks.json Stop 게이트" \
  || bad "Codex hooks.json 에 quality-check Stop 없음" "codex hooks.json Stop 에 quality-check.py 추가 후 codex-bridge"
grep -q "quality-check.py" "$SSOT/codex/hooks.json" 2>/dev/null \
  && ok "Codex SSOT 템플릿(codex/hooks.json)" \
  || bad "SSOT codex/hooks.json 에 게이트 없음 → 새 머신서 미배선" "codex/hooks.json 에 Stop hook 추가"

# 6. ~/.claude/hooks 심링크 (양 에이전트가 $HOME/.claude/hooks/* 참조)
if [ -e "$HOME/.claude/hooks/quality-check.py" ]; then ok "~/.claude/hooks 해석 가능"; else
  bad "~/.claude/hooks/quality-check.py 미해석" "bash $SSOT/bin/relink.sh"; fi

# 7. 룰/루브릭
for f in no-design-slop.md no-decorative-eyebrow.md designslop-rubric.json; do
  [ -f "$RULES/$f" ] && ok "rule: $f" || bad "rule 누락: $f" "agent-harness-baseline git pull"
done

# 8. 보조 스크립트 실행권한
for s in "$HOOKS/designslop-audit.py" "$SSOT/bin/omc-cancel-verify.sh"; do
  [ -x "$s" ] && ok "+x $(basename "$s")" || bad "$(basename "$s") 비실행" "chmod +x $s"
done

# 9. 룰이 양 AGENTS.md 에 주입됐나 (soft)
for am in "$HOME/.claude/CLAUDE.md" "$HOME/AGENTS.md" "$HOME/.codex/AGENTS.md"; do
  [ -f "$am" ] && grep -qiE "design.?slop|no-design-slop|agent-harness-baseline/claude/rules" "$am" 2>/dev/null \
    && ok "rules 주입: $(basename "$(dirname "$am")")/$(basename "$am")" \
    || echo "  · (soft) $am 에 룰 참조 약함 — rebuild-agents-md.sh 권장"
done

if [ "$fail" = "0" ]; then
  echo "── designslop: 양 에이전트·이 머신 배선 OK ──"; exit 0
else
  echo "── designslop: 배선 결함 있음 (위 → 지침) ──"; exit 1
fi
