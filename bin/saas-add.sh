#!/usr/bin/env zsh
# saas-add.sh
# 새 SaaS 플러그인을 인터랙티브로 자동 생성. 신방식 (_lib.sh 패턴 사용).
# 사용: saas-add <name>  (예: saas-add sentry)
# zsh 사용 이유: macOS bash 3.2는 associative array (declare -A) 미지원

set -euo pipefail

readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly B='\033[1;34m'; readonly N='\033[0m'
readonly SSOT="$HOME/.config/agent-harness-baseline"
readonly SAAS_DIR="$SSOT/shell/saas"
readonly MAP_DIR="$HOME/.config/projects"

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "사용: saas-add <name>"
  echo ""
  echo "현재 등록된 SaaS:"
  for f in "$SAAS_DIR"/*.sh; do
    bn="$(basename "$f" .sh)"
    [[ "$bn" == _* ]] && continue
    echo "  - $bn"
  done
  exit 1
fi

if ! [[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo -e "${R}❌${N} name은 소문자/숫자/하이픈만 허용"
  exit 1
fi

if [[ "$NAME" == _* ]]; then
  echo -e "${R}❌${N} _ 로 시작하는 이름은 헬퍼 전용"
  exit 1
fi

PLUGIN="$SAAS_DIR/$NAME.sh"
MAP="$MAP_DIR/$NAME.json"

if [[ -f "$PLUGIN" ]]; then
  echo -e "${Y}⚠${N} $PLUGIN 이미 존재 — 덮어쓰기? (y/N)"
  read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] || exit 0
fi

echo -e "${B}▶ $NAME 플러그인 인터랙티브 생성 (신방식)${N}\n"

# ─── 1. 마커 파일 (default suffix) ─────────────────────────
echo "1) 마커 파일 (프로젝트 루트 기준 default 경로)"
echo "   예: .vercel/project.json, .sentryclirc, wrangler.toml, supabase/config.toml"
echo -n "마커: "
read -r MARKER

# ─── 2. 마커 탐색 maxdepth ────────────────────────────────
echo ""
echo -n "2) 자동 탐색 maxdepth (기본 4, monorepo는 5~6 권장): "
read -r MAXDEPTH
MAXDEPTH="${MAXDEPTH:-4}"

# ─── 3. ID 추출 방식 ──────────────────────────────────────
echo ""
echo "3) 마커에서 프로젝트 ID 추출 방식?"
echo "   a) JSON path (예: .projectId)"
echo "   b) regex (sed group, 예: ^project_id\\s*=\\s*\"\\([^\"]*\\)\")"
echo "   c) 디렉터리 이름 (basename of project root)"
echo "   d) 추출 안 함 (마커 존재만 확인)"
echo -n "선택 (a/b/c/d): "
read -r EXTRACT_TYPE

case "$EXTRACT_TYPE" in
  a)
    echo -n "   JSON path: "
    read -r EXTRACT_ARG
    EXTRACT_BLOCK="id=\$(jq -r '$EXTRACT_ARG' \"\$marker_file\" 2>/dev/null)"
    ;;
  b)
    echo -n "   sed group 패턴 (예: ^project_id\\s*=\\s*\"\\([^\"]*\\)\"): "
    read -r EXTRACT_ARG
    EXTRACT_BLOCK="id=\$(grep -E '$EXTRACT_ARG' \"\$marker_file\" 2>/dev/null | head -1 | sed 's/.*$EXTRACT_ARG.*/\\1/')"
    ;;
  c)
    EXTRACT_BLOCK='id=$(basename "$(__find_project_root)")'
    ;;
  d)
    EXTRACT_BLOCK='id=present'
    ;;
  *) echo "잘못된 선택"; exit 1 ;;
esac

# ─── 4. 매핑 값 형태 ──────────────────────────────────────
echo ""
echo "4) 매핑 파일 값 형태?"
echo "   a) 단순 문자열 ('op://...' 1개 — 환경변수 1개에 쓰임)"
echo "   b) 객체 ({ field: 'op://...', ... } — 여러 환경변수)"
echo -n "선택 (a/b): "
read -r MAP_TYPE

# ─── 5. export할 환경변수 ─────────────────────────────────
echo ""
echo "5) export할 환경변수 이름들 (공백 구분, 예: SENTRY_AUTH_TOKEN SENTRY_DSN):"
read -r EXPORT_VARS

typeset -A FIELD_FOR_VAR
if [[ "$MAP_TYPE" == "b" ]]; then
  echo ""
  echo "   각 환경변수가 매핑 객체의 어느 필드를 쓸지:"
  for v in ${(s: :)EXPORT_VARS}; do
    echo -n "   $v ← 필드명 (예: token, db_password): "
    read -r f
    FIELD_FOR_VAR[$v]="$f"
  done
fi

# ─── 플러그인 생성 (_lib.sh 사용 신방식) ──────────────────
echo -e "\n${B}▶ 플러그인 생성: $PLUGIN${N}"

cat > "$PLUGIN" <<HEADER
#!/usr/bin/env bash
# $NAME SaaS plugin (saas-add 자동 생성: $(date +%FT%T))
# 마커: <project>/$MARKER (자동 탐색, monorepo 지원)
# 매핑: ~/.config/projects/$NAME.json
# Export: $EXPORT_VARS
#
# 명시적 마커 경로 지정 (.agent-harness-baseline.json):
#   { "saas": { "$NAME": { "marker": "subdir/$MARKER" } } }

source "\$HOME/.config/agent-harness-baseline/shell/saas/_lib.sh"

__load_$NAME() {
  local map="\$HOME/.config/projects/$NAME.json"
  [[ -f "\$map" ]] || return 0
  __is_saas_disabled $NAME && return 0

  local marker_file
  marker_file=\$(__find_marker $NAME "$MARKER" $MAXDEPTH)
  [[ -z "\$marker_file" ]] && return 0

  local id
  $EXTRACT_BLOCK
  [[ -z "\$id" || "\$id" == "null" ]] && return 0

  local cfg
  cfg=\$(jq --arg k "\$id" '.[\$k] // empty' "\$map" 2>/dev/null)
  [[ -z "\$cfg" || "\$cfg" == "null" || "\$cfg" == '""' ]] && return 0

  local out=""
HEADER

if [[ "$MAP_TYPE" == "a" ]]; then
  FIRST_VAR=${${(s: :)EXPORT_VARS}[1]}
  cat >> "$PLUGIN" <<BLOCK
  local ref
  ref=\$(echo "\$cfg" | jq -r 'if type == "string" then . else empty end')
  if [[ -n "\$ref" && "\$ref" != "null" ]] && command -v op >/dev/null; then
    export $FIRST_VAR=\$(op read "\$ref" 2>/dev/null)
    out="$FIRST_VAR"
  fi
BLOCK
else
  for v in ${(s: :)EXPORT_VARS}; do
    f="${FIELD_FOR_VAR[$v]}"
    cat >> "$PLUGIN" <<BLOCK
  local ref_$v
  ref_$v=\$(echo "\$cfg" | jq -r '.$f // empty')
  if [[ -n "\$ref_$v" && "\$ref_$v" != "null" ]] && command -v op >/dev/null; then
    export $v=\$(op read "\$ref_$v" 2>/dev/null)
    out="\$out $v"
  fi
BLOCK
  done
fi

cat >> "$PLUGIN" <<'FOOTER'
  [[ -n "$out" ]] && echo "$out"
}
FOOTER

chmod +x "$PLUGIN"
echo -e "  ${G}✓${N} $PLUGIN ($(wc -l < "$PLUGIN") 줄)"

# ─── 매핑 파일 ─────────────────────────────────────────────
echo -e "\n${B}▶ 매핑 파일: $MAP${N}"
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
    FIELDS_JSON=""
    for v in ${(s: :)EXPORT_VARS}; do
      f="${FIELD_FOR_VAR[$v]}"
      FIELDS_JSON="$FIELDS_JSON    \"$f\": \"op://Employee/${NAME}-MyApp/$f\","
      FIELDS_JSON="${FIELDS_JSON}\n"
    done
    FIELDS_JSON="${FIELDS_JSON%,*}"
    cat > "$MAP" <<EOF
{
  "_comment": "$NAME 매핑. 키 = 프로젝트 ID, 값 = { 필드: op://... } 객체.",
  "_example_key": {
$(echo -e "$FIELDS_JSON")
  }
}
EOF
  fi
  echo -e "  ${G}✓${N} 빈 매핑 템플릿"
fi

# ─── 자가 검증 ─────────────────────────────────────────────
echo -e "\n${B}▶ 자가 검증${N}"
if zsh -c "source $PLUGIN; type __load_$NAME >/dev/null 2>&1"; then
  echo -e "  ${G}✓${N} 함수 정의 OK"
else
  echo -e "  ${R}✗${N} 함수 정의 실패 — 플러그인 수동 검토 필요"
fi

# ─── 안내 ─────────────────────────────────────────────────
echo -e "\n${G}✅ $NAME 플러그인 추가 완료${N}\n"
echo "다음 단계:"
echo "  1. ${B}exec zsh${N} (새 플러그인 인식)"
echo "  2. 프로젝트에서 마커 ($MARKER) 확인 — 비표준 위치면 .agent-harness-baseline.json 에 marker 명시"
echo "  3. ${B}\$EDITOR $MAP${N} 매핑 추가"
echo "  4. 1Password에 vault 항목 추가"
echo "  5. cd 다시 → ${B}env | grep $(echo $EXPORT_VARS | tr ' ' '|')${N} 확인"
echo ""
echo "  ${B}ahb-sync${N}  # agent-harness-baseline 에 push (다른 머신 동기화)"
