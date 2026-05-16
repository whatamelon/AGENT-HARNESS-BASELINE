#!/usr/bin/env bash
# op-service-account.sh — 1Password Service Account 토큰을 macOS 로그인 Keychain에
# 저장/조회/삭제. 토큰은 SSOT(git) 어디에도 평문으로 남지 않는다.
#
# 사용:
#   op-service-account.sh store     # 토큰 입력(숨김) → Keychain 저장 (argv/히스토리 노출 없음)
#   op-service-account.sh print     # 토큰을 stdout으로 (셸 주입용; 없으면 무출력·exit 1)
#   op-service-account.sh status    # Keychain 보유 + op 인증 동작 검증
#   op-service-account.sh rm        # Keychain에서 삭제
#
# 셸 주입은 zprofile.shared가 'print'를 호출해서 OP_SERVICE_ACCOUNT_TOKEN export.
#
# Keychain 항목: service="op-service-account", account="$USER" (login keychain).
# 로그인 keychain은 로그인 시 자동 unlock → 사용자 프로세스는 프롬프트 없이 read.
# 트레이드오프: 사용자로 실행되는 모든 프로세스가 read 가능 (env 변수와 동일 신뢰모델).

set -euo pipefail

readonly SVC="op-service-account"
readonly ACCT="${USER}"
readonly G='\033[0;32m'; readonly Y='\033[1;33m'; readonly R='\033[0;31m'; readonly N='\033[0m'

cmd="${1:-}"

case "$cmd" in
  store)
    # -w 인자 없이 주면 security가 숨김 프롬프트로 받음 → argv/히스토리 노출 0.
    printf '%s' "Service Account 토큰 붙여넣기 (입력 숨김): " >&2
    # -U: 이미 있으면 덮어쓰기(로테이션). -T "": 어떤 앱도 ACL 추가 안 함(= 기본 사용자 접근).
    if security add-generic-password -a "$ACCT" -s "$SVC" -U -w; then
      echo >&2
      echo -e "${G}✓ Keychain 저장 완료 (service=$SVC account=$ACCT)${N}" >&2
      echo -e "${Y}→ 새 로그인 셸부터 적용. 즉시 적용: exec zsh -l${N}" >&2
    else
      echo >&2
      echo -e "${R}✗ 저장 실패${N}" >&2
      exit 1
    fi
    ;;

  print)
    tok="$(security find-generic-password -a "$ACCT" -s "$SVC" -w 2>/dev/null || true)"
    if [ -z "$tok" ]; then
      exit 1
    fi
    printf '%s' "$tok"
    ;;

  status)
    if ! security find-generic-password -a "$ACCT" -s "$SVC" -w >/dev/null 2>&1; then
      echo -e "${R}✗ Keychain에 토큰 없음${N} — 'op-service-account.sh store' 먼저" >&2
      exit 1
    fi
    echo -e "${G}✓ Keychain 보유${N}"
    tok="$(security find-generic-password -a "$ACCT" -s "$SVC" -w 2>/dev/null)"
    if OP_SERVICE_ACCOUNT_TOKEN="$tok" op whoami 2>/dev/null; then
      echo -e "${G}✓ op 인증 동작 (Service Account)${N}"
    else
      echo -e "${R}✗ op whoami 실패 — 토큰 무효/만료 또는 op 미설치${N}" >&2
      exit 1
    fi
    ;;

  rm)
    if security delete-generic-password -a "$ACCT" -s "$SVC" >/dev/null 2>&1; then
      echo -e "${G}✓ Keychain에서 삭제${N}" >&2
    else
      echo -e "${Y}⚠ 항목 없음 (이미 삭제됨)${N}" >&2
    fi
    ;;

  *)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
