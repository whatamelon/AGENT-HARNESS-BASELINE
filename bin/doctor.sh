#!/usr/bin/env bash
# doctor.sh — symlink/git/secret 상태 점검
set -uo pipefail

SSOT="$HOME/.config/claude-sync"
errors=0

check_link() {
  local link="$1" target="$2"
  if [[ ! -L "$link" ]]; then
    echo "❌ NOT a symlink: $link"; ((errors++))
  elif [[ "$(readlink "$link")" != "$target" ]]; then
    echo "❌ wrong target: $link → $(readlink "$link")"
    echo "   expected: $target"; ((errors++))
  else
    echo "✓ $link"
  fi
}

echo "── Symlink 검증 ──"
for d in skills agents commands rules hooks hud; do
  check_link "$HOME/.claude/$d" "$SSOT/claude/$d"
done
check_link "$HOME/.claude/notify.sh" "$SSOT/claude/notify.sh"
check_link "$HOME/.claude/CLAUDE.md" "$SSOT/claude/CLAUDE.md"
check_link "$HOME/DESIGN.md" "$SSOT/design/DESIGN.md"
check_link "$HOME/getdesign.md" "$SSOT/design/getdesign.md"
check_link "$HOME/.claude/DESIGN.md" "$SSOT/design/DESIGN.md"
check_link "$HOME/.claude/getdesign.md" "$SSOT/design/getdesign.md"
check_link "$HOME/.codex/DESIGN.md" "$SSOT/design/DESIGN.md"
check_link "$HOME/.codex/getdesign.md" "$SSOT/design/getdesign.md"
check_link "$HOME/.claude/.mcp.json" "$SSOT/claude/mcp.shared.json"
check_link "$HOME/.config/projects" "$SSOT/config/projects"

echo ""
echo "── DESIGN harness 상태 ──"
for f in \
  "$SSOT/design/DESIGN.md" \
  "$SSOT/design/getdesign.md" \
  "$SSOT/design/harness/visual-check.mjs" \
  "$SSOT/design/harness/CLAUDE_CODE_PROMPT.md" \
  "$SSOT/design/harness/README.md"; do
  if [[ -f "$f" ]]; then
    echo "✓ $f"
  else
    echo "❌ missing: $f"; ((errors++))
  fi
done

echo ""
echo "── settings.json 상태 ──"
if [[ -f "$HOME/.claude/settings.local.json" ]]; then
  echo "✓ settings.local.json 존재 ($(stat -f%Sp $HOME/.claude/settings.local.json))"
  if jq empty "$HOME/.claude/settings.local.json" 2>/dev/null; then
    echo "✓ JSON valid"
    keys=$(jq -r '.env | keys | join(", ")' "$HOME/.claude/settings.local.json" 2>/dev/null)
    echo "  env keys: $keys"
  else
    echo "❌ JSON invalid"; ((errors++))
  fi
else
  echo "⚠ settings.local.json 없음 — install.sh 다시 돌리거나 직접 만들기"
fi

echo ""
echo "── 셸 source 라인 ──"
grep -q "claude-sync/shell/zshrc.shared" "$HOME/.zshrc" 2>/dev/null \
  && echo "✓ ~/.zshrc 에 source 있음" \
  || { echo "❌ ~/.zshrc 에 source 없음"; ((errors++)); }
grep -q "claude-sync/shell/zprofile.shared" "$HOME/.zprofile" 2>/dev/null \
  && echo "✓ ~/.zprofile 에 source 있음" \
  || { echo "❌ ~/.zprofile 에 source 없음"; ((errors++)); }

echo ""
echo "── 1Password CLI ──"
if command -v op >/dev/null; then
  echo "✓ op 설치 ($(op --version))"
  if op vault list >/dev/null 2>&1; then
    echo "✓ op signin 됨"
  else
    echo "⚠ op signin 안 됨 — 'op signin' 실행 필요"
  fi
else
  echo "❌ op 미설치"; ((errors++))
fi

echo ""
echo "── Git 상태 ──"
cd "$SSOT" 2>/dev/null && {
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "?")
  echo "✓ branch: $branch"
  remote=$(git remote get-url origin 2>/dev/null || echo "(원격 없음)")
  echo "  remote: $remote"
  if [[ "$remote" != "(원격 없음)" ]]; then
    counts=$(git rev-list --left-right --count "origin/$branch...HEAD" 2>/dev/null || echo "? ?")
    behind=$(echo "$counts" | awk '{print $1}')
    ahead=$(echo "$counts" | awk '{print $2}')
    echo "  behind: $behind, ahead: $ahead"
  fi
  modified=$(git status --short | wc -l | tr -d ' ')
  echo "  uncommitted: $modified files"
} || { echo "❌ SSOT git 접근 실패"; ((errors++)); }

echo ""
echo "── launchd 자동 sync ──"
launchctl_list=$(launchctl list 2>/dev/null)
if echo "$launchctl_list" | grep -q "com.denny.claude-sync"; then
  echo "✓ launchd 등록됨 (com.denny.claude-sync)"
else
  echo "⚠ launchd 미등록 — bin/install-launchd.sh 실행"
fi

echo ""
echo "── CC ↔ Codex 통합 ──"

# ~/AGENTS.md (Codex 글로벌 컨벤션, 자동 생성)
if [[ -f "$HOME/AGENTS.md" ]]; then
  if head -1 "$HOME/AGENTS.md" | grep -q "AUTO-GENERATED"; then
    echo "✓ ~/AGENTS.md 빌드됨 ($(wc -c < "$HOME/AGENTS.md" | tr -d ' ') bytes)"
  else
    echo "⚠ ~/AGENTS.md 에 AUTO-GENERATED 마커 없음 — 직접 편집된 듯. 'rebuild-agents-md.sh --force' 권장"
  fi
else
  echo "⚠ ~/AGENTS.md 없음 — 'bin/rebuild-agents-md.sh' 실행"
fi

# 외부 공유 스킬 풀 (CC + Codex 양쪽 의존)
if [[ -d "$HOME/.agents/skills" ]]; then
  shared_count=$(ls "$HOME/.agents/skills" 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ ~/.agents/skills ($shared_count 개)"
else
  echo "❌ ~/.agents/skills 없음 — 'bootstrap/install-shared-skills.sh' 실행"; ((errors++))
fi

# Codex 스킬 통합 (Codex 설치된 경우만)
if [[ -d "$HOME/.codex/skills" ]]; then
  codex_count=$(ls "$HOME/.codex/skills" 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ ~/.codex/skills ($codex_count 개)"
  if [[ -L "$HOME/.codex/skills/react-patterns" ]]; then
    echo "✓ CC 전용 스킬 노출됨 (react-patterns 등 7개)"
  else
    echo "⚠ CC 전용 스킬 미노출 — 'bootstrap/install-codex-skills.sh' 실행"
  fi
fi

# 빌더/인스톨러 실행 권한
for s in bin/rebuild-agents-md.sh bootstrap/install-shared-skills.sh bootstrap/install-codex-skills.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# PostToolUse hook trigger 등록 여부
if jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("rebuild-agents-md"))' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
  echo "✓ PostToolUse hook 에 rebuild-agents-md trigger 등록"
else
  echo "⚠ PostToolUse hook trigger 미등록 — rules/MEMORY 수정해도 자동 빌드 안 됨"
fi

# Codex bridge
if [[ -x "$SSOT/bin/codex-bridge.sh" ]]; then
  echo "✓ bin/codex-bridge.sh"
else
  echo "❌ bin/codex-bridge.sh 실행 권한/존재 X"; ((errors++))
fi
check_link "$HOME/.codex/agents" "$SSOT/codex/agents"
check_link "$HOME/.codex/hooks" "$SSOT/codex/hooks"
check_link "$HOME/.codex/memories" "$SSOT/codex/memories"
if [[ -f "$HOME/.codex/hooks.json" ]] && cmp -s "$HOME/.codex/hooks.json" "$SSOT/codex/hooks.json"; then
  echo "✓ ~/.codex/hooks.json matches SSOT copy"
else
  echo "⚠ ~/.codex/hooks.json differs from SSOT — run codex-bridge"
fi
if jq -e '.hooks.Stop[]?.hooks[]? | select(.command | contains("codex-bridge"))' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
  echo "✓ Claude Stop hook 에 codex-bridge 등록"
else
  echo "⚠ Claude Stop hook 에 codex-bridge 미등록"
fi
if jq -e '.hooks.Stop[]?.hooks[]? | select(.command | contains("codex-bridge"))' "$HOME/.codex/hooks.json" >/dev/null 2>&1; then
  echo "✓ Codex Stop hook 에 codex-bridge 등록"
else
  echo "⚠ Codex Stop hook 에 codex-bridge 미등록"
fi

echo ""
echo "── Phase 1: 두 맥북 살아있음 인프라 ──"

# 페르소나
if [[ -f "$SSOT/.machine.json" ]]; then
  persona=$(jq -r '.persona' "$SSOT/.machine.json" 2>/dev/null)
  emoji=$(jq -r '.emoji' "$SSOT/.machine.json" 2>/dev/null)
  echo "✓ 페르소나: $emoji $persona"
else
  echo "❌ .machine.json 없음 — 'bin/persona.sh --init' 실행"; ((errors++))
fi

# 활동 ledger
if [[ -d "$SSOT/state/activity" ]]; then
  ledger_count=$(ls "$SSOT/state/activity"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
  echo "✓ state/activity ($ledger_count ledger 파일)"
else
  echo "❌ state/activity/ 없음"; ((errors++))
fi

# helper 실행 권한
for s in bin/persona.sh bin/ledger-append.sh bin/ledger-query.sh bin/notify-activity.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# sync immediate 모드 인식
if grep -q -- "--immediate" "$SSOT/bin/sync.sh" 2>/dev/null; then
  echo "✓ sync.sh --immediate 모드 지원"
else
  echo "❌ sync.sh --immediate 미지원"; ((errors++))
fi
if grep -q "codex-bridge.sh" "$SSOT/bin/sync.sh" 2>/dev/null; then
  echo "✓ sync.sh 에 codex-bridge 자동 실행 등록"
else
  echo "⚠ sync.sh 에 codex-bridge 자동 실행 미등록"
fi

# bats 설치
if command -v bats >/dev/null; then
  echo "✓ bats $(bats --version | awk '{print $2}')"
else
  echo "⚠ bats 미설치 — 'brew install bats-core' (테스트 환경)"
fi

echo ""
echo "── Phase 2: HUD + Stop hook + Catchup ──"

# Phase 2 helper 실행 권한
for s in bin/hud-machines.sh bin/summarize-session.sh bin/notify-session-end.sh bin/hud-catchup.sh bin/daily-digest.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# state 디렉터리들
[[ -d "$SSOT/state/hud-cache" ]] && echo "✓ state/hud-cache" || echo "⚠ state/hud-cache 없음"

# zsh RPROMPT segment
if grep -q "__claude_sync_hud_rprompt" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh RPROMPT segment 등록"
else
  echo "❌ RPROMPT segment 미등록"; ((errors++))
fi

# zsh precmd catchup hook
if grep -q "__claude_sync_catchup" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh precmd catchup hook 등록"
else
  echo "⚠ precmd catchup hook 미등록"
fi

# Stop hook 등록 (notify-session-end)
if jq -e '.hooks.Stop[]?.hooks[]? | select(.command | contains("notify-session-end"))' "$HOME/.claude/settings.json" >/dev/null 2>&1; then
  echo "✓ Stop hook 에 notify-session-end 등록"
else
  echo "⚠ Stop hook trigger 미등록 — settings 확인"
fi

# launchd digest plist
if echo "$launchctl_list" | grep -q "com.denny.claude-sync-digest"; then
  echo "✓ launchd digest 등록 (com.denny.claude-sync-digest)"
else
  echo "⚠ launchd digest 미등록"
fi

echo ""
echo "── Phase 3: 셋업 라이브 중계 + 첫 인사 ──"

# helper 실행 권한
for s in bin/notify-step.sh bin/greet.sh; do
  if [[ -x "$SSOT/$s" ]]; then
    echo "✓ $s"
  else
    echo "❌ $s 실행 권한/존재 X"; ((errors++))
  fi
done

# wizard-state.json greeted 마커
if [[ -f "$SSOT/state/wizard-state.json" ]]; then
  if jq -e '.greeted' "$SSOT/state/wizard-state.json" >/dev/null 2>&1; then
    greeted=$(jq -r '.greeted' "$SSOT/state/wizard-state.json")
    echo "✓ wizard-state.greeted = $greeted"
  else
    echo "⚠ wizard-state.json 에 .greeted 필드 없음 (mac-setup 첫 실행 후 자동 추가)"
  fi
fi

# zsh precmd greet hook
if grep -q "__maybe_greet" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh precmd greet hook 등록"
else
  echo "❌ greet precmd hook 미등록"; ((errors++))
fi

# mac-setup notify-step 통합
if grep -q "notify-step" "$SSOT/bin/mac-setup.sh" 2>/dev/null; then
  echo "✓ mac-setup.sh notify-step 통합"
else
  echo "⚠ mac-setup.sh notify-step 미통합 — 라이브 중계 X"
fi

# bootstrap-new-mac notify-step 통합
if grep -q "notify-step" "$SSOT/bootstrap/bootstrap-new-mac.sh" 2>/dev/null; then
  echo "✓ bootstrap-new-mac.sh notify-step 통합"
else
  echo "⚠ bootstrap-new-mac.sh notify-step 미통합"
fi

echo ""
echo "── Phase 4: 통합 대시보드 (activity) ──"

if [[ -x "$SSOT/bin/activity.sh" ]]; then
  echo "✓ bin/activity.sh"
else
  echo "❌ bin/activity.sh 실행 권한/존재 X"; ((errors++))
fi

if grep -q "alias activity=" "$SSOT/shell/zshrc.shared" 2>/dev/null; then
  echo "✓ zsh alias activity 등록"
else
  echo "❌ alias activity 미등록"; ((errors++))
fi

if command -v fzf >/dev/null; then
  echo "✓ fzf $(fzf --version | head -1)"
else
  echo "⚠ fzf 미설치 — activity --tui plain text fallback"
fi

echo ""
echo "── Phase 5: 신규 자산 (secrets / work-log / srcsht) ──"

# install-secrets.sh
if [[ -x "$SSOT/bin/install-secrets.sh" ]]; then
  echo "✓ bin/install-secrets.sh"
else
  echo "❌ bin/install-secrets.sh 실행 권한/존재 X"; ((errors++))
fi

# settings.local.example.json op:// 패턴
if grep -q "{{ op://" "$SSOT/claude/settings.local.example.json" 2>/dev/null; then
  echo "✓ settings.local.example.json op:// template"
else
  echo "⚠ settings.local.example.json op:// 패턴 없음 (구버전 \$(op read) 패턴일 수 있음)"
fi

# ~/.claude/settings.local.json env 4개
if [[ -f "$HOME/.claude/settings.local.json" ]]; then
  env_count=$(jq '.env | keys | length' "$HOME/.claude/settings.local.json" 2>/dev/null || echo 0)
  if [[ "$env_count" -ge 4 ]]; then
    echo "✓ settings.local.json env 필드 (${env_count}개)"
  else
    echo "⚠ settings.local.json env 필드 부족 (${env_count}) — install-secrets 실행 권장"
  fi
else
  echo "⚠ ~/.claude/settings.local.json 없음 — install-secrets 실행 필요"
fi

# agent-work-log-harness
if [[ -d "$HOME/.config/agent-work-log-harness/.git" ]]; then
  echo "✓ agent-work-log-harness clone"
else
  echo "❌ ~/.config/agent-work-log-harness 미설치"; ((errors++))
fi
if [[ -L "$HOME/.local/bin/ensure-work-log-task" ]]; then
  echo "✓ ensure-work-log-task 심링크"
else
  echo "❌ ~/.local/bin/ensure-work-log-task 심링크 없음 — work-log-harness install.sh 실행 필요"; ((errors++))
fi

# srcsht-rename launchd
if [[ -f "$SSOT/bin/srcsht-rename.sh" ]]; then
  echo "✓ bin/srcsht-rename.sh"
else
  echo "❌ bin/srcsht-rename.sh 없음"; ((errors++))
fi
if [[ -f "$SSOT/launchd/com.denny.srcsht-rename.plist" ]]; then
  echo "✓ launchd/com.denny.srcsht-rename.plist (template)"
else
  echo "❌ srcsht plist template 없음"; ((errors++))
fi
if launchctl list 2>/dev/null | grep -q "com.denny.srcsht-rename"; then
  echo "✓ srcsht-rename launchd active"
else
  echo "⚠ srcsht-rename launchd 미등록 (bootstrap step 12에서 처리)"
fi

# LaunchAgents plist 파일 타입 + 사이즈 검증 (macOS 26.x 심링크 차단 대비)
for label in com.denny.claude-sync com.denny.claude-sync-digest com.denny.srcsht-rename; do
  plist="$HOME/Library/LaunchAgents/${label}.plist"
  if [[ -L "$plist" ]]; then
    echo "⚠ $label.plist 심링크 — macOS 26.x LaunchAgents 차단 가능 (bootstrap step 12 재실행 권장)"
  elif [[ -f "$plist" ]]; then
    sz=$(wc -c < "$plist" | tr -d ' ')
    if [[ "$sz" -gt 0 ]]; then
      echo "✓ $label.plist (${sz} bytes 실파일)"
    else
      echo "❌ $label.plist 0 bytes — bootstrap step 12 재실행 필요"; ((errors++))
    fi
  else
    echo "⚠ $label.plist 없음 (해당 launchd 사용 안 함)"
  fi
done

echo ""
[[ $errors -eq 0 ]] && echo "✅ All good ($errors errors)" || echo "❌ $errors errors"
exit $errors
