#!/usr/bin/env bash
# bootstrap-doctor.sh
# 부트스트랩이 제대로 됐는지 광범위 검증.
# doctor.sh (agent-harness-baseline 자체) 보다 더 넓은 범위 — 시스템 + CLI 인증까지.

set -uo pipefail

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly B='\033[1;34m'; readonly N='\033[0m'
readonly SSOT="$HOME/.config/agent-harness-baseline"

ok=0; warn=0; err=0
check() {
  local desc="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "  ${G}✓${N} $desc"; ((ok++))
  else
    echo -e "  ${R}✗${N} $desc"; ((err++))
  fi
}
soft() {
  local desc="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "  ${G}✓${N} $desc"; ((ok++))
  else
    echo -e "  ${Y}⚠${N} $desc (선택)"; ((warn++))
  fi
}

echo -e "\n${B}══ 시스템 ══${N}"
check "macOS" "[[ \$(uname) = Darwin ]]"
check "Xcode CLT" "xcode-select -p"
check "Homebrew" "command -v brew"
soft  "Rosetta (Apple Silicon)" "[[ \$(uname -m) = arm64 ]] && /usr/bin/pgrep -q oahd || [[ \$(uname -m) != arm64 ]]"

echo -e "\n${B}══ 핵심 CLI ══${N}"
for c in git gh node npm jq op claude; do
  check "$c" "command -v $c"
done

echo -e "\n${B}══ 추가 CLI (있으면 좋음) ══${N}"
for c in pnpm bun yarn python3 uv ruby gcloud docker supabase vercel firebase wrangler; do
  soft "$c" "command -v $c"
done

echo -e "\n${B}══ Claude Code ══${N}"
check "~/.claude 존재" "[[ -d \$HOME/.claude ]]"
check "skills symlink" "[[ -L \$HOME/.claude/skills ]]"
check "agents symlink" "[[ -L \$HOME/.claude/agents ]]"
check "settings.json" "[[ -f \$HOME/.claude/settings.json ]]"
check "settings.json valid JSON" "jq empty \$HOME/.claude/settings.json"
check "settings.local.json" "[[ -f \$HOME/.claude/settings.local.json ]]"

echo -e "\n${B}══ 셸 통합 ══${N}"
check "~/.zshrc 에 source" "grep -q agent-harness-baseline/shell/zshrc.shared \$HOME/.zshrc"
check "~/.zprofile 에 source" "grep -q agent-harness-baseline/shell/zprofile.shared \$HOME/.zprofile"
check "~/.config/projects symlink" "[[ -L \$HOME/.config/projects ]]"

echo -e "\n${B}══ 자동 sync ══${N}"
check "launchd plist" "launchctl list | grep -q com.denny.agent-harness-baseline"
check "git remote 등록" "(cd \$SSOT && git remote get-url origin)"

# 무인화 머신(맥미니)으로 표시됐을 때만 전원/잠금 굳힘 상태를 검증
MACHINE_TYPE="$( [[ -f "$SSOT/.machine.json" ]] && jq -r '.machineType // "unknown"' "$SSOT/.machine.json" 2>/dev/null || echo unknown )"
if [[ "$MACHINE_TYPE" == "macmini-headless" ]]; then
  echo -e "\n${B}══ 무인화 (맥미니 항시가동) ══${N}"
  check "시스템 잠자기 끔 (pmset sleep 0)"        "pmset -g | grep -E '^ *sleep ' | grep -q ' 0'"
  check "디스크 잠자기 끔 (pmset disksleep 0)"     "pmset -g | grep -E '^ *disksleep ' | grep -q ' 0'"
  check "정전 후 자동 재시작 (autorestart 1)"      "pmset -g | grep -qE '^ *autorestart *1'"
  soft  "원격 깨우기 (womp 1)"                     "pmset -g | grep -qE '^ *womp *1'"
  soft  "화면보호기 끔 (screensaver idleTime 0)"    "[[ \$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null) == 0 ]]"
else
  echo -e "\n${B}══ 무인화 ══${N}"
  soft "맥미니 무인화 미적용 (machineType=$MACHINE_TYPE)" "true"
fi

echo -e "\n${B}══ CLI 인증 ══${N}"
soft "1Password (op vault list)" "op vault list"
soft "GitHub (gh auth status)" "gh auth status"
soft "gcloud (gcloud auth list)" "gcloud auth list 2>/dev/null | grep -q ACTIVE"
soft "Supabase (supabase projects)" "supabase projects list"
soft "Docker (docker info)" "docker info"
soft "Vercel (vercel whoami)" "vercel whoami"
soft "Claude (claude config)" "claude --version"

echo -e "\n${B}══ 결과 ══${N}"
echo "  ${G}✓${N} OK: $ok"
echo "  ${Y}⚠${N} WARN: $warn (필수 아님)"
echo "  ${R}✗${N} FAIL: $err"

if [[ $err -gt 0 ]]; then
  echo -e "\n${R}❌ 부트스트랩 미완료${N} — bootstrap-new-mac.sh 다시 실행하거나 cli-login-checklist.md 참조"
  exit 1
elif [[ $warn -gt 5 ]]; then
  echo -e "\n${Y}⚠ 일부 도구 미설치${N} — 필요한 것만 골라서 설치"
  exit 0
else
  echo -e "\n${G}✅ 부트스트랩 완료 — 작업 시작 가능${N}"
  exit 0
fi
