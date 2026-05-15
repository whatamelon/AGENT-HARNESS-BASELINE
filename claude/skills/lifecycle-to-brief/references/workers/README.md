# OMC Team Worker Prompts — AIDP Pipeline

이 디렉토리는 `lifecycle-to-brief`가 생성한 `omc-team-pool.json`을 처리할 8명의 워커에 대한 system prompt 템플릿이다. 4명의 Claude + 4명의 Codex로 구성된 자동 사냥 팀.

## 워커 카탈로그

| ID | 파일 | 모델 | 역할 | 영역 |
|---|---|---|---|---|
| C1 | `claude-architect.md` | opus | 아키텍처/스펙 작성 | TB, IMP 신규 |
| C2 | `claude-implementer-be.md` | opus | 백엔드 구현 | API, DB, 비즈니스 |
| C3 | `claude-implementer-fe.md` | sonnet | 프론트엔드 구현 | React, UI |
| C4 | `claude-tester.md` | sonnet | E2E 테스트 | Playwright |
| X1 | `codex-implementer-be-helper.md` | codex | 백엔드 보조 | 작은 BE task |
| X2 | `codex-implementer-fe-helper.md` | codex | 프론트엔드 보조 | 작은 FE task |
| X3 | `codex-refactorer.md` | codex | 리팩토링/빌드 fix | quality-loop |
| X4 | `codex-doc-writer.md` | codex | 문서/이력 | UG, change_log |

## 영역 분리 (충돌 방지)

| 영역 | 소유 워커 | 다른 워커 접근 |
|---|---|---|
| `apps/web/src/lib/`, `apps/web/src/app/api/` | C2 / X1 | C3/X2 금지 |
| `apps/web/src/components/`, `apps/web/src/app/(pages)/` | C3 / X2 | C2/X1 금지 |
| `e2e/` | C4 | 금지 |
| `.projects/<name>/30~40` (TB, IMP 본문) | C1 | 외엔 frontmatter만 (status, change_log) |
| `.projects/<name>/60~70` (UG, UAT) | X4 | C4가 UAT만 작성 가능 |
| `_dashboard.md`, `change_log` entry | X4 | 모두 entry는 추가, 본문은 X4 |

## Task 분배 정책 (priority_score 기준)

```
priority_score
   1.0 ─┐
        │ Claude #1, #2 (opus)
        │ — 핵심 / 복잡 / architectural
   0.8 ─┤
        │ Claude #3, #4 (sonnet)
        │ — 표준 작업
   0.5 ─┤
        │ Codex #1~4
        │ — 작은 단위, 보조, 정리
   0.0 ─┤
        │ 보류 큐
  -1.0 ─┘ blocker — 절대 분배 안 함
```

## Claim 룰

1. 모든 워커는 `omc-team-pool.json` 의 `tasks[]` 에서 task 하나만 동시 보유
2. claim 시 `claimed_by` (워커 ID) + `claimed_at` 원자 업데이트
3. 60분 timeout — 시간 초과 시 자동 회수
4. 같은 task 중복 claim 금지 (race condition은 file lock으로 처리)
5. 자기 영역 밖의 task 는 claim 금지 (각 워커 프롬프트의 "받는 task" 섹션 참조)

## 공통 환각 방지 규칙 (모든 워커 강제)

CLAUDE.md §8을 모든 워커가 system prompt에 인용:

- ❌ AS의 verified=true fact 외 인용 금지
- ❌ TB의 "핵심 차단 요인" 5개 외 새 발명 금지
- ❌ IMP의 AC 외 새 요구사항 추가 금지
- ❌ 도메인 용어집 외 새 용어 도입 금지
- ❌ RBAC 외 권한 정책 변경 금지
- ❌ change_log entry 누락 금지

위반 시 `phase-validator`가 PR/변경을 reject. 모든 워커는 task 완료 직전 자체적으로 `/phase-validator --since=<task-start> --strict` 실행.

## 협업 흐름 (Handoff)

```
C1 (architect) — 신규 IMP 작성
       ↓ ref 매핑된 task 생성
C2/X1 (BE) — 백엔드 구현
       ↓
C3/X2 (FE) — 프론트엔드 구현
       ↓
X3 (refactorer) — quality-loop, simplify, build fix
       ↓
C4 (tester) — Playwright E2E 작성/실행
       ↓ test failure 시 C2/C3에 회신
X4 (doc-writer) — UG, change_log, _dashboard 갱신
```

## 사용 방법

OMC team 가동 시 각 워커에게 해당 .md 파일을 system prompt 로 주입:

```bash
/oh-my-claudecode:team \
  --pool=.aidp/omc-team-pool.json \
  --workers=8 \
  --worker-prompts=$HOME/wishket/claude-settings/.claude/skills/lifecycle-to-brief/references/workers/ \
  --duration=20h
```

또는 `lifecycle-to-brief`의 합성 후 자동 생성된 `.aidp/team-config.json`이 워커별 프롬프트 경로를 명시.

## 튜닝 노트

이 프롬프트는 **첫 번째 자동 사냥 시점에 거의 무조건 수정 필요**. 실제 돌려보면:
- 어떤 워커가 task를 못 claim해서 idle (filter가 너무 좁음)
- 어떤 워커가 다른 영역 침범 (영역 정의가 모호)
- 환각 패턴이 워커마다 다름 (CLAUDE.md 참조 강도 조정)

자동 사냥 1회 완료 후 `_post-mortem.md` 작성하여 워커 프롬프트 v2 갱신.
