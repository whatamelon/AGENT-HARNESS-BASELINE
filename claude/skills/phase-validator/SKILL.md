---
name: phase-validator
description: ".projects/ 워크스페이스의 project-lifecycle 산출물 무결성을 검증한다. AS/TB/IMP/UX/WBS/Timeline 파일이 변경된 후 필수 호출. fact_summary 정합성(verified/proposed/unverified 카운트와 본문 일치), upstream_refs/downstream_refs 양방향 링크, change_log entry 누락, status 전이 규칙(todo→doing→done/blocked), TB 핵심 차단 요인 변경 금지, IMP AC 무단 추가 금지, REQ Story와 WBS Task 혼동, phase 작성 순서(AS→TB→IMP→WBS), 99.requests CHG-* 경유 없이 정책 변경, fact_summary와 frontmatter schema 위반 등을 탐지한다. 사용자가 'phase 검증', 'phase validate', '온톨로지 무결성', 'project-lifecycle 검증', '환각 검증', 'cross-ref 검증', 'fact 검증', 'change_log 누락', 'WBS 검증', 'OMC team 출력 검증', 'AS-IS 검증', 'TB 변경 검증', '추적성 검증', 'traceability check', '.projects 검증', 'phase integrity' 등을 언급하거나, OMC team/ralph/autopilot의 검증자(verifier) 단계에서 .projects/ 파일이 변경된 직후 반드시 이 스킬을 사용한다."
---

# /phase-validator — Project-Lifecycle 무결성 검증기

## 역할

`.projects/<name>/` 워크스페이스에 있는 project-lifecycle 산출물(00~99 phase 파일)이 변경된 후, 다음 8가지 무결성 규칙을 위반하지 않았는지 검증하는 **환각 방지 게이트**로서 행동한다. OMC team / ralph / autopilot의 자동 사냥 루프에서 verifier로 호출되거나, 사용자가 명시적으로 호출한다.

## 핵심 원칙

1. **READ-ONLY 원칙**: 위반을 발견해도 자동 수정하지 않는다. PASS / FAIL / WARN 보고서만 생성한다. 수정은 호출자(사람 또는 다른 에이전트)의 책임이다.
2. **증거 기반 판정**: 모든 FAIL 항목은 `file:line` 또는 `frontmatter.field` 단위로 정확한 증거를 제시한다.
3. **부분 검증 허용**: 특정 phase만 검증하도록 인자를 받을 수 있다.
4. **블록 비탐지 = 묵인 아님**: 검증 범위 밖이거나 정보 부족인 항목은 `INCONCLUSIVE`로 명시한다.

## 호출 방법

```
/phase-validator                          # 현재 작업 디렉토리의 .projects/ 전체 검증
/phase-validator <project-name>           # .projects/<project-name>/ 검증
/phase-validator --phase=20,30,40         # 특정 phase만 검증
/phase-validator --since=<git-ref>        # git-ref 이후 변경된 파일만 검증
/phase-validator --strict                 # WARN도 FAIL로 취급 (CI 모드)
```

OMC team 통합 시 task의 verifier 단계에서 자동 호출:
```
/phase-validator --since=HEAD~1 --strict
```

## 검증 절차

### Step 0: 사전 조사

```bash
# 대상 워크스페이스 확인
ls .projects/
# 변경 범위 파악 (--since 인자가 있을 때)
git diff --name-only <ref> HEAD -- .projects/
# 검증 대상 파일 목록 결정
find .projects/<project>/ -name "*.md" -o -name "WBS-*.md" -type f
```

### Step 1: Frontmatter Schema 검증

각 `.md` 파일의 YAML 프론트매터를 읽고 phase별 필수 필드를 확인한다.

| Phase | 필수 필드 |
|---|---|
| 모든 phase | `id`, `phase`, `project`, `status`, `created_at`, `updated_at`, `change_log` |
| `as_is_analysis` | `fact_summary` (verified/in_review/proposed/unverified 카운트) |
| `requirements` | `upstream_refs` (배열), `downstream_refs` (배열) |
| `to_be_directions` | `upstream_refs` (AS-* 1개 이상 포함 필수) |
| `implementation_plans` | `upstream_refs` (TB-* 1개 이상 포함 필수) |
| `ui_design` | `screens_total`, `screens_as_is_html`, `screens_to_be_html` |
| `project_management` (WBS) | `work_items` 배열, 각 item에 `id`, `title`, `refs`, `status`, `estimate` |
| `project_management` (Timeline) | `milestones` 배열, 각 milestone에 `id`, `target_date`, `status`, `epic_refs` |

**FAIL 조건**:
- 필수 필드 누락
- `id` 형식 위반 (예: AS는 `AS-NNN`, WBS work_item은 `WBS-NNN-TNN`)
- `status`가 정의된 enum이 아님 (`draft|reviewed|approved|deprecated`)
- `phase` 필드와 실제 폴더 위치 불일치 (e.g. 30 폴더에 `phase: as_is_analysis`)

### Step 2: Cross-Reference 양방향 정합

`upstream_refs` / `downstream_refs`의 양방향 일치를 검증한다.

```
A.downstream_refs에 B가 있다  ↔  B.upstream_refs에 A가 있다
```

**FAIL 조건**:
- A는 B를 downstream으로 선언했으나 B의 upstream에 A가 없음 (또는 그 반대)
- 참조한 ID가 실제로 존재하지 않음 (deadref)
- 자기 자신을 참조 (self-loop)
- AS가 IMP를 직접 참조 (phase 순서 위반 — TB 거쳐야 함)

**WARN 조건**:
- 고립 노드: upstream도 downstream도 없는 문서 (의도적인지 확인 필요)
- 순환 참조: A → B → C → A (가능하지만 의심)

### Step 3: Phase 작성 순서 규칙

```
AS (현황) → TB (방향) → IMP (계획) → UX/UG/UAT (산출물) → WBS (실행)
```

**FAIL 조건**:
- TB의 upstream에 AS가 없음 (TB는 반드시 AS 기반)
- IMP의 upstream에 TB가 없음 (IMP는 반드시 TB 기반)
- WBS work_item의 `refs`에 IMP 또는 REQ Story ID가 하나도 없음 (work_item은 실행 대상이 명확해야 함)
- 99.requests의 CHG-NNN 없이 TB의 "핵심 차단 요인" 또는 "개선 방향" 섹션이 변경됨 (`change_log` request_id 비어있음)

### Step 4: Fact Summary 정합

AS-NNN 파일에서 `fact_summary` 카운트와 본문의 fact 마킹이 일치하는지 검증한다.

본문에서 fact 추출 패턴:
- `[F]` 또는 `[F-NNN]` 형태의 reference
- 표 안의 fact 행 (예: 무역팀 핵심 업무 4단계 데이터 실증 표)
- "verified", "proposed", "unverified" 마커가 명시된 항목

**FAIL 조건**:
- `fact_summary.verified` 카운트 > 본문에서 발견된 verified 마킹 fact 수
- 새로 추가된 fact가 `verified`로 표시됐는데 `change_log`에 승급 entry 없음
- 본문의 fact 총합 ≠ frontmatter 카운트 합계 (오차 ±2 허용)

**WARN 조건**:
- `proposed` 비율이 50% 초과 (검증 미완 상태)
- `unverified` 비율이 25% 초과 (위험)

### Step 5: TB / IMP 변경 제약

TB-NNN의 다음 섹션은 99.requests 경유 없이 변경 금지:
- "핵심 차단 요인" 표
- "개선 방향" 섹션 헤더 (방향 1, 2, ...)
- "100% 완성 Story" 표

IMP-NNN의 다음 섹션은 REQ 갱신 → IMP 갱신 순서 필수:
- "구현 필요 기능" 표의 AC 행 (추가/삭제)
- "우선순위 요약" 표의 Story (추가)

검증 방법:
1. `git diff <ref> HEAD -- .projects/<name>/30.to_be_directions/TB-*.md` 실행
2. 변경된 hunk가 위 보호 섹션에 있으면 `change_log` entry의 `request_id` 필드 확인
3. `request_id`가 비어있거나 `99.requests/`에 해당 CHG 파일이 없으면 FAIL

### Step 6: WBS Status 전이 규칙

`status-glossary.md` 정의:

```
todo  → doing | blocked
doing → done  | blocked
done  → (변경 없음)
blocked → doing | todo
```

**FAIL 조건**:
- `done`이 다른 상태로 전환됨 (작업 되돌림은 신규 work_item 생성으로 해야 함)
- `todo`에서 `done`으로 직접 전환 (`doing` 단계 누락)
- `status: blocked`인데 `blocked_reason`이 비어있음
- `status: doing`인데 `started_at`이 비어있음
- `status: done`인데 `completed_at` 또는 `actual` 비어있음

### Step 7: REQ Story vs WBS Task 분리 (Story ≠ Task)

원칙: REQ Story는 *비즈니스 가치 단위*, WBS Task는 *실행 단위*.

**FAIL 조건**:
- WBS work_item의 `id`가 REQ-NNN-Snn 형태 (Story ID를 work_item ID로 직접 사용)
- WBS work_item.title이 REQ Story 제목을 그대로 복사 (실행 동사 없음)
- REQ Story.title이 작업 동사로 시작 ("구현하기", "만들기" 등) — Story는 가치 표현이어야 함

**WARN 조건**:
- WBS work_item.estimate가 14d 초과 — 너무 큰 task는 분해 필요
- 1 Story → N Task 매핑이 N=1뿐 (Story가 곧 Task인 의심)

### Step 8: Change Log 무결성

모든 phase 파일은 변경 시 `change_log`에 entry 추가가 필수다.

**FAIL 조건**:
- git diff에서 변경된 phase 파일의 `change_log`에 신규 entry가 없음 (`updated_at`만 갱신됐을 때)
- entry 포맷 위반: `{date, request_id, description}` 셋 중 하나라도 누락
- 같은 일자에 동일 request_id로 entry가 3개 이상 — 너무 잦은 변경은 묶어서 단일 entry로

**WARN 조건**:
- entry의 `description`이 50자 미만 (구체성 부족)
- `request_id`가 비어있는 entry 비율 > 30%

---

## 출력 포맷

검증 결과는 다음 구조의 보고서로 출력한다. JSON 모드(`--json`)와 마크다운 모드(기본) 둘 다 지원.

### 마크다운 보고서

```markdown
# Phase Validation Report

**Project**: <project-name>
**Scope**: <전체 | --since=ref | --phase=20,30>
**Run at**: 2026-04-30 21:15

## 요약

| 결과 | 카운트 |
|---|:-:|
| 🟢 PASS | 142 |
| 🔴 FAIL | 3 |
| 🟡 WARN | 8 |
| ⚪ INCONCLUSIVE | 1 |

**판정**: 🔴 FAIL — 3건의 무결성 위반이 있어 머지 불가.

## FAIL 상세

### F-01 [Step 2] Cross-ref 양방향 불일치
- 파일: `.projects/som-integrated-erp/30.to_be_directions/TB-005.md:14`
- 위반: `downstream_refs: [IMP-005]` 선언, 그러나 `IMP-005.upstream_refs`에 `TB-005` 없음
- 수정: 둘 중 하나에 누락된 ref 추가

### F-02 [Step 3] Phase 순서 위반
- 파일: `.projects/som-integrated-erp/40.implementation_plans/IMP-007.md:9`
- 위반: `upstream_refs: [REQ-007]` — IMP는 반드시 TB-* 참조 필수
- 수정: TB-007 추가 또는 작성 후 ref

### F-03 [Step 5] TB 보호 섹션 무단 변경
- 파일: `.projects/som-integrated-erp/30.to_be_directions/TB-001.md:42-58`
- 위반: "핵심 차단 요인" 표 행 추가, 그러나 change_log entry의 request_id 비어있음
- 수정: 99.requests/CHG-NNN 작성 후 change_log에 request_id 추가

## WARN 상세

(생략 — 8건)

## INCONCLUSIVE 상세

### I-01 [Step 4] Fact summary 정합 — 본문 파싱 불완전
- 파일: `.projects/som-integrated-erp/20.as_is_analysis/AS-009/AS-009.md`
- 사유: fact 마킹이 `[F]`도 `verified` 키워드도 사용하지 않은 자유 형식. 자동 카운트 불가.
- 권장: 사람 검토 필요.
```

### JSON 보고서 (`--json`)

```json
{
  "project": "som-integrated-erp",
  "scope": "--since=HEAD~1",
  "run_at": "2026-04-30T21:15:00Z",
  "summary": { "pass": 142, "fail": 3, "warn": 8, "inconclusive": 1 },
  "verdict": "FAIL",
  "findings": [
    {
      "level": "FAIL",
      "rule": "Step2.bidirectional_ref",
      "id": "F-01",
      "file": ".projects/.../TB-005.md",
      "line": 14,
      "violation": "downstream_refs: [IMP-005] declared but IMP-005.upstream_refs missing TB-005",
      "fix": "Add the missing ref on either side"
    }
  ]
}
```

---

## OMC Team 통합 사용 패턴

OMC team의 task 처리 사이클에 verifier로 끼워 넣는다:

```
[task claim]
    ↓
[task execute] (executor agent)
    ↓
[/phase-validator --since=task-start --strict]
    ↓
  PASS → task done, status update
  FAIL → task rolled back, regenerate with violation list as feedback
  WARN → task done, issue logged
```

OMC team의 verifier 프롬프트 예시:

```
You are the verifier for SOM ERP project. After the executor completes
a task, run /phase-validator --since=<task-start-sha> --strict and
return the JSON report. If verdict is FAIL, return the findings array
to the executor as the feedback for retry. Do NOT proceed to next task
until verdict is PASS or WARN.
```

---

## 환각 방지의 핵심 메커니즘

이 스킬이 **20시간 자동 사냥에서 환각을 막는 이유**:

| 환각 패턴 | 차단 메커니즘 |
|---|---|
| AS에 없는 fact를 인용해 새 요구사항 생성 | Step 4 (fact_summary 카운트 ≠ 본문 fact 수) |
| TB의 차단 요인을 슬쩍 추가/변경 | Step 5 (변경 시 CHG 경유 필수) |
| IMP에 새 AC 발명 | Step 5 (REQ 갱신 → IMP 갱신 순서) |
| done task를 todo로 되돌리기 | Step 6 (done은 종착 상태) |
| Story와 Task 혼동해서 일감 부풀리기 | Step 7 (분리 검증) |
| change_log 없이 슬쩍 수정 | Step 8 (entry 누락 FAIL) |
| 고아 문서 양산 | Step 2 WARN (orphan node) |
| phase 순서 무시 (TB 없이 IMP) | Step 3 (upstream chain 강제) |

이 8개 게이트가 모두 PASS여야만 OMC team의 변경이 승인된다. 즉 **자동 사냥 중 발생할 수 있는 거의 모든 종류의 환각이 schema 단위로 차단**된다.

---

## 한계

이 스킬이 **검증할 수 없는** 것:

1. **콘텐츠 정확성**: AS-001의 "356 PO" 같은 실증 데이터가 실제 엑셀 분석과 일치하는지는 검증 불가. 별도 데이터 검증 도구 필요.
2. **인터뷰 충실도**: AS의 Pain Points가 진짜 인터뷰이가 말한 내용인지 검증 불가. `analysis/_extraction-notes.md`의 trace 검토 필요.
3. **비즈니스 적합성**: TB의 "개선 방향"이 사업적으로 옳은지 검증 불가. 도메인 전문가 리뷰 필요.
4. **코드 정합성**: TB의 "Verification Report"가 실제 코드와 일치하는지 검증 불가. 별도 코드 검증 도구 필요.

이 4가지는 phase-validator의 책임 범위 밖이며, 별도 게이트(콘텐츠 리뷰 / 인터뷰 검수 / 비즈니스 사인오프 / 코드 verifier)에서 처리한다.

---

## 예시 실행

```bash
# 시나리오: OMC team의 워커가 IMP-005를 수정하고 WBS-001-T26을 doing으로 전환했다.
# 변경을 검증한다:
$ /phase-validator --since=HEAD~1 --strict

# 출력:
# 🔴 FAIL — 1건
# F-01 [Step 6] WBS-001-T26 status=doing이지만 started_at 비어있음
#       파일: .projects/som-integrated-erp/80.project_management/wbs/WBS-001_overall/WBS-001_overall.md
#       라인: 287
#       수정: started_at: 2026-04-30 추가
```

이 결과는 OMC team에게 "워커 X의 변경을 reject, started_at 추가 후 재시도"라는 신호로 작용한다.
