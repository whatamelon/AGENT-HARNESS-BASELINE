#!/usr/bin/env bash
# saas-add.sh
# 새 SaaS 플러그인을 인터랙티브로 자동 생성.
# 사용: saas-add <name>  (예: saas-add sentry)

set -euo pipefail

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly B='\033[1;34m'; readonly N='\033[0m'
readonly SSOT="$HOME/.config/claude-sync"
readonly SAAS_DIR="$SSOT/shell/saas"
readonly MAP_DIR="$HOME/.config/projects"

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "사용: saas-add <name>"
  echo ""
  echo "현재 등록된 SaaS:"
  ls "$SAAS_DIR"/*.sh 2>/dev/null | xargs -I {} basename {} .sh | sed 's/^/  - /'
  exit 1
fi

# 소문자, 알파벳 + 숫자 + 하이픈만
if ! [[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo -e "${R}❌${N} name은 소문자/숫자/하이픈만"
  exit 1
fi

PLUGIN="$SAAS_DIR/$NAME.sh"
MAP="$MAP_DIR/$NAME.json"

if [[ -f "$PLUGIN" ]]; then
  echo -e "${Y}⚠${N} $PLUGIN 이미 존재 — 덮어쓰기? (y/N)"
  read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] || exit 0
fi

echo -e "${B}▶ $NAME 플러그인 인터랙티브 생성${N}\n"

# 1. 마커 파일
echo -n "1) 마커 파일 경로 (프로젝트 루트 기준, 예: .vercel/project.json, .sentryclirc, wrangler.toml): "
read -r MARKER

# 2. ID 추출 방식
echo ""
echo "2) 마커에서 프로젝트 ID 추출 방식?"
echo "   a) JSON path (예: .projectId)"
echo "   b) regex (예: ^project=(.+))"
echo "   c) 디렉터리 이름 (basename)"
echo "   d) 추출 안 함 (마커 존재 여부만)"
echo -n "선택 (a/b/c/d): "
read -r EXTRACT_TYPE

case "$EXTRACT_TYPE" in
  a)
    echo -n "   JSON path (예: .projectId): "
    read -r EXTRACT_ARG
    EXTRACT_CMD="jq -r '$EXTRACT_ARG' \"\$d/$MARKER\" 2>/dev/null"
    ;;
  b)
    echo -n "   regex 패턴 (sed 그룹, 예: ^project_id\\s*=\\s*\"\\([^\"]*\\)\"): "
    read -r EXTRACT_ARG
    EXTRACT_CMD="grep -E '$EXTRACT_ARG' \"\$d/$MARKER\" 2>/dev/null | head -1 | sed 's/.*$EXTRACT_ARG.*/\\1/'"
    ;;
  c)
    EXTRACT_CMD='basename "$d"'
    ;;
  d)
    EXTRACT_CMD='echo present'
    ;;
  *) echo "잘못된 선택"; exit 1 ;;
esac

# 3. 매핑 값 형태
echo ""
echo "3) 매핑 파일 값 형태?"
echo "   a) 단순 문자열 ('op://...' 1개)"
echo "   b) 객체 (여러 op 참조)"
echo -n "선택 (a/b): "
read -r MAP_TYPE

# 4. export할 환경변수들
echo ""
echo "4) export할 환경변수 이름들 (공백 구분, 예: SENTRY_AUTH_TOKEN SENTRY_DSN):"
read -r EXPORT_VARS

# 환경변수 1개당 매핑 키 (옵션 b일 때)
declare -A FIELD_FOR_VAR
if [[ "$MAP_TYPE" == "b" ]]; then
  echo ""
  echo "   각 환경변수가 매핑 객체의 어느 필드를 쓸지:"
  for v in $EXPORT_VARS; do
    echo -n "   $v ← 필드명 (예: token, db_password): "
    read -r f
    FIELD_FOR_VAR[$v]="$f"
  done
fi

# ─── 플러그인 생성 ─────────────────────────────────────────
echo -e "\n${B}▶ 플러그인 생성: $PLUGIN${N}"

cat > "$PLUGIN" <<EOF
#!/usr/bin/env bash
# $NAME SaaS plugin (saas-add 자동 생성: $(date +%FT%T))
# 마커: <project>/$MARKER
# 매핑: ~/.config/projects/$NAME.json
# Export: $EXPORT_VARS

__load_$NAME() {
  local map="\$HOME/.config/projects/$NAME.json"
  local d="\$PWD"

  while [[ "\$d" != "/" && "\$d" != "\$HOME" ]]; do
    if [[ -f "\$d/$MARKER" && -f "\$map" ]]; then
      local id
      id=\$($EXTRACT_CMD)

      if [[ -n "\$id" ]]; then
        local cfg
        cfg=\$(jq --arg k "\$id" '.[\$k] // empty' "\$map" 2>/dev/null)

        if [[ -n "\$cfg" && "\$cfg" != "null" && "\$cfg" != '""' ]]; then
          local out=""
EOF

if [[ "$MAP_TYPE" == "a" ]]; then
  # 단순 문자열 → 첫 번째 환경변수에 매핑
  FIRST_VAR=$(echo "$EXPORT_VARS" | awk '{print $1}')
  cat >> "$PLUGIN" <<EOF
          local ref
          ref=\$(echo "\$cfg" | jq -r 'if type == "string" then . else empty end')
          if [[ -n "\$ref" && "\$ref" != "null" ]] && command -v op >/dev/null; then
            export $FIRST_VAR=\$(op read "\$ref" 2>/dev/null)
            out="$FIRST_VAR"
          fi
EOF
else
  # 객체 → 각 필드별로
  for v in $EXPORT_VARS; do
    f="${FIELD_FOR_VAR[$v]}"
    cat >> "$PLUGIN" <<EOF
          local ref_$v
          ref_$v=\$(echo "\$cfg" | jq -r '.$f // empty')
          if [[ -n "\$ref_$v" && "\$ref_$v" != "null" ]] && command -v op >/dev/null; then
            export $v=\$(op read "\$ref_$v" 2>/dev/null)
            out="\$out $v"
          fi
EOF
  done
fi

cat >> "$PLUGIN" <<EOF
          [[ -n "\$out" ]] && echo "\$out"
        fi
      fi
      break
    fi
    d="\${d:h}"
  done
}
EOF

chmod +x "$PLUGIN"
echo -e "  ${G}✓${N} $PLUGIN 작성 완료 ($(wc -l < "$PLUGIN") 줄)"

# ─── 매핑 파일 ─────────────────────────────────────────────
echo -e "\n${B}▶ 매핑 파일 생성: $MAP${N}"
if [[ -f "$MAP" ]]; then
  echo -e "  ${Y}⚠${N} 이미 존재 — 그대로 둠"
else
  if [[ "$MAP_TYPE" == "a" ]]; then
    cat > "$MAP" <<EOF
{
  "_comment": "$NAME 매핑. 키 = 프로젝트 ID, 값 = op://... 참조.",
  "_example_key": "op://Employee/${NAME}-MyApp/token"
}
EOF
  else
    cat > "$MAP" <<EOF
{
  "_comment": "$NAME 매핑. 키 = 프로젝트 ID, 값 = { 필드: op://... } 객체.",
  "_example_key": {
$(for v in $EXPORT_VARS; do f="${FIELD_FOR_VAR[$v]}"; echo "    \"$f\": \"op://Employee/${NAME}-MyApp/$f\","; done | sed '$ s/,$//')
  }
}
EOF
  fi
  echo -e "  ${G}✓${N} 빈 매핑 템플릿 생성"
fi

# ─── 안내 ─────────────────────────────────────────────────
echo -e "\n${G}✅ $NAME 플러그인 추가 완료${N}\n"
echo "다음 단계:"
echo "  1. ${B}exec zsh${N} 로 셸 재시작 (새 플러그인 인식)"
echo "  2. 프로젝트 디렉터리에서 마커 ($MARKER) 확인"
echo "  3. ${B}\$EDITOR $MAP${N} 매핑 추가"
echo "  4. 1Password에 vault 항목 추가"
echo "  5. cd 다시 → ${B}env | grep $(echo $EXPORT_VARS | tr ' ' '|')${N} 확인"
echo ""
echo "claude-sync에 push:"
echo "  ${B}cs-sync${N}"
