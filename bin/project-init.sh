#!/usr/bin/env bash
# project-init.sh
# 새 프로젝트를 sync 시스템에 등록.
# 사용: cd <프로젝트>; ~/.config/claude-sync/bin/project-init.sh [vault]
# vault 생략 시 'Employee' (변경 가능: $VAULT 환경변수)

set -euo pipefail

readonly PROJECT_DIR="$PWD"
readonly PROJECT_NAME="$(basename "$PROJECT_DIR")"
readonly VAULT="${1:-${VAULT:-Employee}}"
readonly SSOT="$HOME/.config/claude-sync"

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly B='\033[1;34m'; readonly N='\033[0m'
step() { echo -e "\n${B}▶${N} $*"; }
info() { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}⚠${N} $*"; }

step "프로젝트: $PROJECT_NAME (vault=$VAULT)"

# 0) 사전 체크
[[ -d ".git" ]] || warn "git repo 아님 — 진행은 가능하지만 권장 X"
op vault get "$VAULT" >/dev/null 2>&1 || { echo "❌ vault '$VAULT' 없음"; op vault list; exit 1; }

# 1) Vercel 매핑
step "1. Vercel 매핑"
if [[ -f ".vercel/project.json" ]]; then
  PID=$(jq -r .projectId .vercel/project.json)
  MAP="$HOME/.config/projects/vercel.json"
  EXISTING=$(jq -r --arg k "$PID" '.[$k] // empty' "$MAP" 2>/dev/null)

  if [[ -n "$EXISTING" ]]; then
    info "이미 매핑됨: $PID → $EXISTING"
  else
    REF="op://${VAULT}/Vercel-${PROJECT_NAME}/token"
    # 1Password 항목 없으면 생성
    if ! op item get "Vercel-${PROJECT_NAME}" --vault="$VAULT" >/dev/null 2>&1; then
      warn "1Password 항목 'Vercel-${PROJECT_NAME}' 미존재 — 토큰 입력 받음"
      echo -n "Vercel token (vercel.com/account/tokens 에서 발급): "
      read -rs TOKEN; echo
      op item create --category=password --vault="$VAULT" --title="Vercel-${PROJECT_NAME}" \
        password="$TOKEN" >/dev/null
      info "1Password 항목 생성: $VAULT/Vercel-${PROJECT_NAME}"
    fi
    # 매핑 추가 (jq로 업데이트)
    tmp=$(mktemp)
    jq --arg k "$PID" --arg v "$REF" '.[$k] = $v' "$MAP" > "$tmp" && mv "$tmp" "$MAP"
    info "vercel.json 매핑 추가: $PID → $REF"
  fi
else
  warn ".vercel/project.json 없음 — 'vercel link' 먼저 실행하면 자동 등록됨"
fi

# 2) Supabase 매핑
step "2. Supabase 매핑"
if [[ -f "supabase/config.toml" ]]; then
  PREF=$(grep -E '^project_id' supabase/config.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
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
        echo -n "Supabase access token (supabase.com/dashboard/account/tokens): "
        read -rs ACC; echo
        echo -n "DB password (Supabase 프로젝트 설정 → Database): "
        read -rs DBP; echo
        op item create --category=password --vault="$VAULT" --title="Supabase-${PROJECT_NAME}" \
          password="$ACC" "db-password[concealed]=$DBP" >/dev/null
        # 'access-token' alias 필드 추가 (편의)
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
  warn "supabase/config.toml 없음 — 'supabase init && supabase link --project-ref XXX' 후 재실행"
fi

# 3) .env.template 자동 생성
step "3. .env.template 작성"
if [[ -f ".env.template" ]]; then
  info ".env.template 이미 존재 — 그대로 둠 (필요시 수동 편집)"
elif [[ -f ".env" ]]; then
  # 기존 .env에서 키 추출 → 템플릿화
  awk -F= '/^[A-Z_][A-Z0-9_]*=/ {
    key=$1
    print key "={{ op://'"$VAULT"'/'"$PROJECT_NAME"'-Env/" tolower(key) " }}"
  }' .env > .env.template
  info ".env.template 생성 ($(wc -l < .env.template) 줄)"
  warn "→ 1Password에 ${VAULT}/${PROJECT_NAME}-Env 항목을 만들고 각 키를 필드로 추가하세요"
else
  cat > .env.template <<EOF
# .env.template — op inject로 .env 생성
# 사용: op inject -i .env.template -o .env
# 새 키 추가 시 이 파일에 정의 후 1Password에 동일 필드명으로 항목 만들기

# 예시:
# DATABASE_URL={{ op://${VAULT}/${PROJECT_NAME}-Env/database-url }}
# ANTHROPIC_API_KEY={{ op://${VAULT}/${PROJECT_NAME}-Env/anthropic-api-key }}
EOF
  info ".env.template 빈 템플릿 생성"
fi

# 4) .gitignore에 .env 추가
step "4. .gitignore"
if [[ -f ".gitignore" ]]; then
  if grep -qE '^\.env$|^\.env\*' .gitignore; then
    info "이미 .env 무시됨"
  else
    echo "" >> .gitignore
    echo "# Secrets" >> .gitignore
    echo ".env" >> .gitignore
    echo ".env.local" >> .gitignore
    echo ".env.*.local" >> .gitignore
    info ".gitignore 에 .env 추가"
  fi
else
  cat > .gitignore <<'EOF'
.env
.env.local
.env.*.local
EOF
  info ".gitignore 신규 생성"
fi

# 5) 한 번 inject 시도
step "5. .env 첫 주입"
if op inject --force -i .env.template -o .env 2>/dev/null; then
  info ".env 생성됨"
else
  warn "주입 실패 — 1Password에 해당 항목/필드가 아직 없을 수 있음"
  warn "필요 항목 만든 후: ${B}env-sync${N}"
fi

# 6) 매핑 sync (claude-sync repo로 push)
step "6. 매핑 변경분 sync"
(cd "$SSOT" && {
  if [[ -n "$(git status --porcelain config/projects)" ]]; then
    git add config/projects
    git commit -m "feat: register $PROJECT_NAME ($(hostname -s))" --quiet
    git push --quiet 2>/dev/null && info "claude-sync repo에 push" || warn "push 실패 (수동: cd $SSOT && git push)"
  else
    info "변경 없음"
  fi
})

# 7) 검증
step "7. 검증"
echo "  cd 다시 해서 환경변수 잡히는지 확인:"
echo -e "  ${B}cd .. && cd \"$PROJECT_DIR\" && env | grep -E 'VERCEL|SUPABASE'${N}"

echo -e "\n${G}✅ project-init 완료${N}: $PROJECT_NAME"
