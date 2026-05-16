#!/usr/bin/env zsh
# project-init.sh
# 새 프로젝트를 sync 시스템에 등록.
# 신방식: shell/saas/_lib.sh 의 __find_marker 사용 — 자동 탐색 + .agent-harness-baseline.json 자동 생성.
# zsh 사용 이유: associative array (typeset -A) — macOS bash 3.2 미지원

set -euo pipefail

readonly PROJECT_DIR="$PWD"
readonly PROJECT_NAME="$(basename "$PROJECT_DIR")"
readonly VAULT="${1:-${VAULT:-Employee}}"
readonly SSOT="$HOME/.config/agent-harness-baseline"

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly B='\033[1;34m'; readonly N='\033[0m'
step() { echo -e "\n${B}▶${N} $*"; }
info() { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}⚠${N} $*"; }
err()  { echo -e "  ${R}✗${N} $*"; }

# _lib.sh 로드
source "$SSOT/shell/saas/_lib.sh"

step "프로젝트: $PROJECT_NAME (vault=$VAULT)"

# 0) 사전 체크
[[ -d ".git" ]] || warn "git repo 아님 — 진행은 가능하지만 권장 X"
op vault get "$VAULT" >/dev/null 2>&1 || { err "vault '$VAULT' 없음"; op vault list; exit 1; }

# 프로젝트 루트 (마커가 서브디렉터리에 있어도 여기 기준)
PROJECT_ROOT="$(__find_project_root)"
info "project root: $PROJECT_ROOT"

# .agent-harness-baseline.json 명시 매핑이 필요한지 추적
typeset -A NEEDS_EXPLICIT

# ─── 헬퍼: 마커 발견했는데 비표준 위치면 명시 매핑 후보로 마킹 ──
__check_explicit_needed() {
  local plugin="$1" marker_file="$2" default_suffix="$3"
  # marker_file의 PROJECT_ROOT 기준 상대경로
  local rel="${marker_file#$PROJECT_ROOT/}"
  # 표준 위치인지 확인 (예: vercel은 .vercel/project.json, supabase는 supabase/config.toml)
  if [[ "$rel" != "$default_suffix" ]]; then
    NEEDS_EXPLICIT[$plugin]="$rel"
    info "[$plugin] 비표준 위치 발견: $rel — .agent-harness-baseline.json에 기록 권장"
  fi
}

# ─── 1) Vercel 매핑 ──────────────────────────────────────
step "1. Vercel 매핑"
VERCEL_MARKER=$(__find_marker vercel ".vercel/project.json" 4)
if [[ -n "$VERCEL_MARKER" ]]; then
  info "마커 발견: ${VERCEL_MARKER#$PROJECT_ROOT/}"
  __check_explicit_needed vercel "$VERCEL_MARKER" ".vercel/project.json"

  PID=$(jq -r .projectId "$VERCEL_MARKER")
  MAP="$HOME/.config/projects/vercel.json"
  EXISTING=$(jq -r --arg k "$PID" '.[$k] // empty' "$MAP" 2>/dev/null)

  if [[ -n "$EXISTING" ]]; then
    info "이미 매핑됨: $PID → $EXISTING"
  else
    REF="op://${VAULT}/Vercel-${PROJECT_NAME}/token"
    if ! op item get "Vercel-${PROJECT_NAME}" --vault="$VAULT" >/dev/null 2>&1; then
      warn "1Password 항목 'Vercel-${PROJECT_NAME}' 미존재 — 토큰 입력"
      echo -n "  Vercel token (vercel.com/account/tokens): "
      read -rs TOKEN; echo
      op item create --category=password --vault="$VAULT" --title="Vercel-${PROJECT_NAME}" \
        password="$TOKEN" >/dev/null
      info "1Password 항목 생성: $VAULT/Vercel-${PROJECT_NAME}"
    fi
    tmp=$(mktemp)
    jq --arg k "$PID" --arg v "$REF" '.[$k] = $v' "$MAP" > "$tmp" && mv "$tmp" "$MAP"
    info "vercel.json 매핑 추가: $PID → $REF"
  fi
else
  warn "Vercel 마커 없음 — 'vercel link' 후 재실행"
fi

# ─── 2) Supabase 매핑 ────────────────────────────────────
step "2. Supabase 매핑"
SUPA_MARKER=$(__find_marker supabase "supabase/config.toml" 4)
if [[ -n "$SUPA_MARKER" ]]; then
  info "마커 발견: ${SUPA_MARKER#$PROJECT_ROOT/}"
  __check_explicit_needed supabase "$SUPA_MARKER" "supabase/config.toml"

  PREF=$(grep -E '^project_id' "$SUPA_MARKER" | head -1 | sed 's/.*"\(.*\)".*/\1/')
  if [[ -n "$PREF" ]]; then
    MAP="$HOME/.config/projects/supabase.json"
    EXISTING=$(jq --arg k "$PREF" '.[$k] // empty' "$MAP" 2>/dev/null)

    if [[ -n "$EXISTING" && "$EXISTING" != "null" && "$EXISTING" != '""' ]]; then
      info "이미 매핑됨: $PREF"
    else
      REF_T="op://${VAULT}/Supabase-${PROJECT_NAME}/access-token"
      REF_DB="op://${VAULT}/Supabase-${PROJECT_NAME}/db-password"
      if ! op item get "Supabase-${PROJECT_NAME}" --vault="$VAULT" >/dev/null 2>&1; then
        warn "1Password 항목 'Supabase-${PROJECT_NAME}' 미존재 — 입력"
        echo -n "  Supabase access token (supabase.com/dashboard/account/tokens): "
        read -rs ACC; echo
        echo -n "  DB password (Supabase 프로젝트 설정 → Database): "
        read -rs DBP; echo
        op item create --category=password --vault="$VAULT" --title="Supabase-${PROJECT_NAME}" \
          password="$ACC" "db-password[concealed]=$DBP" >/dev/null
        op item edit "Supabase-${PROJECT_NAME}" --vault="$VAULT" \
          "access-token[concealed]=$ACC" >/dev/null
        info "1Password 항목 생성"
      fi
      tmp=$(mktemp)
      jq --arg k "$PREF" --argjson v "{\"token\":\"$REF_T\",\"db_password\":\"$REF_DB\"}" \
        '.[$k] = $v' "$MAP" > "$tmp" && mv "$tmp" "$MAP"
      info "supabase.json 매핑 추가: $PREF"
    fi
  fi
else
  warn "Supabase 마커 없음 — 'supabase init && supabase link --project-ref XXX' 후 재실행"
fi

# ─── 3) .agent-harness-baseline.json 자동 생성/갱신 (비표준 위치만) ─────
step "3. .agent-harness-baseline.json (명시 매핑)"
if (( ${#NEEDS_EXPLICIT[@]} > 0 )); then
  META="$PROJECT_ROOT/.agent-harness-baseline.json"
  LEGACY_META="$PROJECT_ROOT/.claude-sync.json"
  if [[ -f "$META" ]]; then
    cp "$META" "$META.bak.$(date +%s)"
    info "기존 .agent-harness-baseline.json 백업"
  elif [[ -f "$LEGACY_META" ]]; then
    cp "$LEGACY_META" "$META"
    info "legacy .claude-sync.json → .agent-harness-baseline.json 마이그레이션"
  else
    echo '{}' > "$META"
  fi

  for plugin in "${(@k)NEEDS_EXPLICIT}"; do
    rel="${NEEDS_EXPLICIT[$plugin]}"
    tmp=$(mktemp)
    jq --arg p "$plugin" --arg m "$rel" \
      '.saas = (.saas // {}) | .saas[$p] = (.saas[$p] // {}) | .saas[$p].marker = $m' \
      "$META" > "$tmp" && mv "$tmp" "$META"
    info "saas.$plugin.marker = $rel"
  done

  info "$PROJECT_ROOT/.agent-harness-baseline.json 갱신됨 — git commit 권장"
else
  info "표준 위치라 .agent-harness-baseline.json 불필요 (자동 탐색으로 충분)"
fi

# ─── 4) .env.template 자동 생성 ──────────────────────────
step "4. .env.template"
if [[ -f ".env.template" ]]; then
  info "이미 존재 — 그대로 둠"
elif [[ -f ".env" ]]; then
  awk -F= '/^[A-Z_][A-Z0-9_]*=/ {
    key=$1
    print key "={{ op://'"$VAULT"'/'"$PROJECT_NAME"'-Env/" tolower(key) " }}"
  }' .env > .env.template
  info ".env에서 키 추출 ($(wc -l < .env.template) 줄)"
  warn "→ 1Password에 ${VAULT}/${PROJECT_NAME}-Env 항목 만들고 각 키를 필드로 추가"
else
  cat > .env.template <<EOF
# .env.template — op inject로 .env 생성
# 사용: env-sync (또는 op inject -i .env.template -o .env)

# 예시:
# DATABASE_URL={{ op://${VAULT}/${PROJECT_NAME}-Env/database-url }}
# ANTHROPIC_API_KEY={{ op://${VAULT}/${PROJECT_NAME}-Env/anthropic-api-key }}
EOF
  info "빈 템플릿 생성"
fi

# ─── 5) .gitignore ──────────────────────────────────────
step "5. .gitignore"
if [[ -f ".gitignore" ]]; then
  if grep -qE '^\.env$|^\.env\*' .gitignore; then
    info "이미 .env 무시됨"
  else
    cat >> .gitignore <<'EOF'

# Secrets (agent-harness-baseline)
.env
.env.local
.env.*.local
EOF
    info ".env 패턴 추가"
  fi
else
  cat > .gitignore <<'EOF'
.env
.env.local
.env.*.local
EOF
  info "신규 생성"
fi

# ─── 6) .env 첫 주입 ────────────────────────────────────
step "6. .env 첫 주입"
if op inject --force -i .env.template -o .env 2>/dev/null; then
  chmod 600 .env
  info ".env 생성됨"
else
  warn "주입 실패 — 1Password 항목/필드 누락. 채운 뒤: env-sync"
fi

# ─── 7) 매핑 sync (agent-harness-baseline repo로 push) ──────────────
step "7. 매핑 변경분 sync"
(cd "$SSOT" && {
  if [[ -n "$(git status --porcelain config/projects)" ]]; then
    git add config/projects
    git commit -m "feat: register $PROJECT_NAME ($(hostname -s))" --quiet
    git push --quiet 2>/dev/null && info "agent-harness-baseline repo에 push" || warn "push 실패"
  else
    info "변경 없음"
  fi
})

# ─── 8) 검증 안내 ───────────────────────────────────────
step "8. 검증"
cat <<EOF
  cd 다시 해서 환경변수 잡히는지 확인:
    ${B}cd / && cd "$PROJECT_DIR" && env | grep -E 'VERCEL|SUPABASE'${N}

EOF

if (( ${#NEEDS_EXPLICIT[@]} > 0 )); then
  cat <<EOF
  ${Y}.agent-harness-baseline.json 이 새로 만들어졌으니 commit 권장:${N}
    ${B}cd "$PROJECT_ROOT" && git add .agent-harness-baseline.json && git commit -m "chore: agent-harness-baseline marker"${N}

EOF
fi

echo -e "${G}✅ project-init 완료${N}: $PROJECT_NAME"
