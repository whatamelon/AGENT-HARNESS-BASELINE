# 자동 품질 검사 시스템

설치일: 2026-02-22

---

## 개요

Claude Code가 작업을 끝냈다고 해도 실수가 남아있는 경우가 많다.
이 시스템은 공장의 자동 검사 라인처럼 3단계로 품질을 검증한다.

```
파일 수정 → [CCTV 기록] → 응답 완료 → [오류 체크] → [셀프체크 리마인더]
```

---

## 파일 구조

```
~/.claude/
├── hooks/
│   ├── file-tracker.py      # 1. CCTV 기록 장치
│   ├── quality-check.py     # 2. 완료 후 검사 + 3. 셀프체크 리마인더
│   └── README.md            # 이 문서
└── logs/
    ├── file-changes.log     # 영구 수정 이력 (누적)
    └── sessions/
        └── {session_id}.txt # 세션별 수정 파일 목록
```

---

## 장치 1: CCTV 기록 (file-tracker.py)

**트리거:** `Edit`, `Write`, `MultiEdit` 도구 사용 직후 (PostToolUse)

**역할:** 어떤 파일을 언제 수정했는지 자동 기록

**출력 예시 (`~/.claude/logs/file-changes.log`):**
```
auth.service.ts    14:23:01    /src/auth/auth.service.ts
api.routes.ts      14:23:08    /src/routes/api.routes.ts
db.schema.ts       14:23:15    /src/db/db.schema.ts
user.model.ts      14:23:22    /src/models/user.model.ts
```

**세션 파일 (`~/.claude/logs/sessions/{session_id}.txt`):**
- 현재 세션에서 수정된 파일 목록 (중복 없이)
- 품질 검사 시 소비(삭제)됨

---

## 장치 2: 완료 후 검사 (quality-check.py — 오류 체크 부분)

**트리거:** Claude 응답 완료 시 (Stop)

**역할:** 수정된 파일에서 오류를 자동 탐지

| 언어 | 체크 방법 | 소요 시간 |
|------|-----------|----------|
| TypeScript / TSX | `npx tsc --noEmit` (tsconfig 기준) | ~30초 |
| Python | `python3 -m py_compile` (파일별) | ~1초 |

**판정 기준:**
| 오류 수 | 동작 |
|---------|------|
| 0개 | ✅ 이상 없음 |
| 1~5개 | ⚠️ 즉시 수정 권장 |
| 6개 이상 | 🚨 전문 에이전트 추천 (`/build-fix`, `/ultraqa`) |

---

## 장치 3: 셀프체크 리마인더 (quality-check.py — 리마인더 부분)

**트리거:** 완료 후 검사와 동시 (Stop)

**역할:** 옆자리 선배처럼 조용히 두 가지를 물어봄

```
방금 수정한 파일들, 이것도 확인했나요?

1. ❓ 에러 처리 — 예외 상황은 처리했나요?
2. ❓ 보안 — 하드코딩된 값, 입력 검증, 권한 확인 완료?
```

**특징:** 막는 것이 아니라 확인을 유도하는 방식 (exit 2로 Claude에게 전달)

---

## 훅 설정 (`~/.claude/settings.json`)

```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [
        {
          "type": "command",
          "command": "python3 /Users/denny/.claude/hooks/file-tracker.py"
        }
      ]
    }
  ],
  "Stop": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "python3 /Users/denny/.claude/hooks/quality-check.py"
        }
      ]
    }
  ]
}
```

---

## 무한루프 방지

Stop 훅에서 `exit 2`를 반환하면 Claude가 재실행된다.
재실행된 Claude가 다시 응답을 마치면 Stop 훅이 다시 실행될 수 있다.

이를 막기 위해 두 가지 방어 장치가 있다:

1. **`stop_hook_active: true` 감지** — 이미 Stop 훅이 유발한 실행이면 즉시 `exit 0`
2. **세션 파일 소비** — 파일을 읽은 즉시 삭제하여 두 번 실행되지 않도록

---

## CCTV 로그 관리

영구 로그 파일은 자동 삭제되지 않는다. 필요 시 수동 정리:

```bash
# 로그 확인
cat ~/.claude/logs/file-changes.log

# 오늘 수정된 파일만 보기
grep "$(date '+%H')" ~/.claude/logs/file-changes.log

# 로그 초기화 (선택)
> ~/.claude/logs/file-changes.log
```

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| 품질 검사가 실행 안 됨 | python3 경로 문제 | `which python3` 확인 후 settings.json 수정 |
| TypeScript 체크 안 됨 | tsconfig.json 없음 | 프로젝트 루트에 tsconfig.json 필요 |
| 루프 발생 | stop_hook_active 로직 오류 | quality-check.py 첫 10줄 확인 |
| 세션 파일 누적 | 비정상 종료 | `rm ~/.claude/logs/sessions/*.txt` |
