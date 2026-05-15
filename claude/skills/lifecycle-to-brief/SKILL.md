---
name: lifecycle-to-brief
description: ".projects/<name>/ 의 project-lifecycle 산출물(TB/IMP/UX/WBS/Timeline/AS/ROLE)을 합성해 aidp-os 투입용 산출물 3종(.aidp-brief.json / CLAUDE.md / .omc-team-pool.json)을 생성한다. aidp-os의 service brief, MenuTree, Page, Feature, DesignWireframe과 OMC team의 task pool 포맷으로 변환하여 자동 사냥 파이프라인을 가동한다. 사용자가 'aidp brief 생성', 'service brief 변환', 'phase to aidp', 'lifecycle to brief', 'aidp-os 투입', '자동 사냥 시작', 'OMC team 투입', 'omc-team-pool 생성', '.aidp-brief.json 만들기', 'CLAUDE.md 자동 생성', '도메인 규칙 합성', 'AX 자동화 가동', '인터뷰 결과 코드 변환', 'TB IMP UX 합성', 'WBS task pool 변환', '환각 방지 CLAUDE.md', 'lifecycle 합성' 등을 언급하거나, project-lifecycle phase 작성이 충분히 완료되어 aidp-os/OMC team 자동 실행으로 넘어가야 할 때 반드시 이 스킬을 사용한다."
---

# /lifecycle-to-brief — Lifecycle → AIDP-OS + OMC Team 변환기

## 역할

`.projects/<name>/` 워크스페이스에 누적된 project-lifecycle 산출물을 합성하여 **aidp-os 자동 코드 생성 + OMC team 자동 사냥**의 두 파이프라인이 즉시 가동될 수 있는 입력 3종을 생성하는 **합성 어댑터**로서 행동한다.

이 스킬은 인터뷰부터 배포까지의 풀 자동화 파이프라인에서 **앞단(인터뷰/온톨로지/명시지)과 뒷단(코드 생성/배포)을 잇는 다리** 역할을 한다.

## 핵심 원칙

1. **검증 우선**: 합성 전 `phase-validator`를 자동 호출. FAIL 발견 시 합성 중단 (원본 무결성 보장).
2. **변환만 한다, 생성하지 않는다**: lifecycle에 없는 정보를 발명하지 않는다. 누락은 `_warnings.md`에 기록한다.
3. **CLAUDE.md가 본질**: service brief는 표면, CLAUDE.md(도메인 규칙·환각 방지 규칙)가 자동 사냥 품질의 90%를 결정한다.
4. **WBS의 refs를 컨텍스트 채널로**: OMC team task pool의 각 task는 refs에 명시된 phase 파일을 자동 컨텍스트로 적재한다.
5. **양방향 흐름**: 합성 후 OMC team이 task 완료 시 WBS work_item.status를 자동 갱신할 수 있도록 매핑 정보를 보존한다.

## 호출 방법

```
/lifecycle-to-brief                              # 현재 디렉토리의 .projects/<유일한 프로젝트>/ 변환
/lifecycle-to-brief <project-name>               # 명시
/lifecycle-to-brief <project-name> --output=<d>  # 출력 디렉토리 (기본: .aidp/)
/lifecycle-to-brief <project-name> --skip-validate  # phase-validator 스킵 (위험)
/lifecycle-to-brief <project-name> --dry-run     # 합성 결과 미리보기만 (파일 저장 안 함)
/lifecycle-to-brief <project-name> --partial=tb,imp,ux  # 특정 phase 산출물만
```

기본 동작:
1. `phase-validator <project>` 자동 실행
2. PASS/WARN이면 합성 진행, FAIL이면 중단 + 위반 목록 출력
3. 합성 결과를 `<output>/` (기본 `.aidp/`)에 저장
4. 재검증 (sanity check)
5. 사용 가이드 출력 (다음 단계 명령어)

---

## 변환 절차

### Step 0: 사전 검증 + 입력 파일 인덱싱

```bash
# 0-1. 검증
/phase-validator <project> --strict

# 0-2. 인덱스 빌드
find .projects/<project>/30.to_be_directions/ -name "TB-*.md" -type f
find .projects/<project>/40.implementation_plans/ -name "IMP-*.md" -type f
find .projects/<project>/41.ui_design/ -name "UX-*.md" -type f
find .projects/<project>/41.ui_design/ -name "to-be" -type d
find .projects/<project>/22.access_control/ -name "ROLE-*.md" -type f
find .projects/<project>/20.as_is_analysis/ -name "AS-*.md" -type f
ls .projects/<project>/80.project_management/wbs/
ls .projects/<project>/80.project_management/timeline/
```

각 파일의 frontmatter를 파싱하여 in-memory 그래프 구축 (id → frontmatter + 본문 위치).

### Step 1: `.aidp-brief.json` 생성

aidp-os의 `Project` / `MenuTree` / `Page` / `Feature` / `DesignWireframe` 스키마와 정합한 단일 JSON 객체를 생성한다.

#### 1-1. Project record

```json
{
  "project": {
    "name": "<TB 최상위.title 또는 사용자 인자>",
    "description": "<TB 최상위.\"개선 배경\" 섹션 첫 문단>",
    "framework": "next",
    "language": "ts",
    "database": "postgres",
    "packageManager": "npm",
    "serviceDescription": "<TB-NNN.\"개선 방향\" 섹션들 합성>",
    "targetUsers": ["<WF-*.RACI 표에서 R/A 역할 추출>"],
    "referenceServices": [],
    "industry": "<frontmatter.tags의 org 값 첫번째>",
    "subIndustry": "",
    "primaryColor": "#000000",
    "secondaryColor": "#ffffff",
    "fontFamily": "Pretendard",
    "tone": "professional",
    "serviceType": "internal-tool",
    "codingAgent": "claude-code",
    "codingModel": "claude-opus-4-7"
  }
}
```

매핑 규칙:
- `name`: 사용자 `--name` 인자 > TB 최상위 title > project frontmatter
- `description`: TB 본문에서 마크다운 H1 다음 첫 문단 (200자 이내 trim)
- `serviceDescription`: 모든 TB의 "개선 방향" 섹션 헤더(방향 1, 2, ...) + 첫 문장 합성. 2000자 cap.
- `targetUsers`: 모든 WF의 RACI 표에서 R/A 역할 unique 추출 (정렬: 빈도 desc)
- `industry`: project frontmatter의 tags.org. 매핑 테이블 (`som-group` → "유통/물류", `lgd-tech-academy` → "교육/HR")
- `primaryColor` / `fontFamily` 등: 사용자 입력. 미지정 시 디폴트.

#### 1-2. MenuTree records (계층 트리)

UX-NNN의 "정보 구조 (IA)" 섹션 또는 `_sitemap/mapping.md`에서 트리 추출.

```
/master-integration                    [SCR-MDI-001] 통합 대시보드
├── /product                           [SCR-MDI-002] 품목 매트릭스
│   ├── /product/new                   신규 발의 폼 (variant)
```

→ 변환:

```json
"menuTree": [
  {
    "path": "/master-integration",
    "title": "통합 대시보드",
    "screenId": "SCR-MDI-001",
    "depth": 1,
    "parent": null,
    "layoutHint": "dashboard",
    "children": [
      {
        "path": "/product",
        "title": "품목 매트릭스",
        "screenId": "SCR-MDI-002",
        "depth": 2,
        "parent": "/master-integration",
        "layoutHint": "list",
        "children": [
          { "path": "/product/new", "title": "신규 발의 폼", "screenId": null, "depth": 3, "parent": "/product", "layoutHint": "form", "children": [] }
        ]
      }
    ]
  }
]
```

`layoutHint` 자동 판정 규칙:
- `dashboard.html` 또는 "대시보드" → `dashboard`
- `matrix.html`, `list.html`, "리스트", "현황" → `list`
- `request.html`, `new.html`, "발의", "등록", "작성" → `form`
- `[id]/`, `detail.html`, "상세" → `detail`
- `gallery.html`, "갤러리" → `gallery`
- `settings.html`, `config.html`, "설정" → `settings`

최대 4단계 깊이 (aidp-os 제약).

#### 1-3. Page records

UX-NNN의 "화면 인벤토리" 표 1행 = 1 Page.

```json
"pages": [
  {
    "name": "통합 대시보드",
    "path": "/master-integration",
    "menuTreeRef": "/master-integration",
    "scenarioDescription": "<인벤토리 표의 \"사용자 시나리오\" 컬럼>",
    "components": ["entity 카드 7개", "카운터 카드 3종"],
    "wireframeFile": "to-be/dashboard.html",
    "layoutHint": "dashboard",
    "screenId": "SCR-MDI-001",
    "uxRef": "UX-001",
    "tbRef": "TB-018",
    "impRef": "IMP-021"
  }
]
```

`tbRef` / `impRef`: UX의 frontmatter `upstream_refs`에서 가져옴. 추적성 보존.

#### 1-4. Feature records (구현 단위)

IMP-NNN의 모든 AC 1행 = 1 Feature. AC는 다음 표에서 추출:
- "이미 구현된 기능" 표 → `status: "completed"`
- "구현 필요 기능" 표 (PARTIAL) → `status: "in_progress"`
- "구현 필요 기능" 표 (FAIL/미검증) → `status: "todo"`

```json
"features": [
  {
    "name": "ATP 자동차감",
    "description": "주문 확정(confirmed) 시 예약 재고 차감, 취소/반품 시 복원. Optimistic Locking",
    "status": "todo",
    "priority": 1,
    "complexity": "high",
    "estimateDays": 12,
    "pageRef": null,
    "impRef": "IMP-005",
    "storyRef": "REQ-005-S01",
    "acceptanceCriteria": "ATP < 주문수량 시 경고 + 입고 예정일 기반 납기일 자동 계산",
    "techDesign": "<IMP의 \"기술 설계\" 섹션 해당 항목>"
  }
]
```

### 1-5. DesignWireframe records (직접 import)

UX-NNN의 `to-be/*.html` 파일이 이미 존재하면 aidp-os가 새로 생성하지 않고 import만.

```json
"wireframes": [
  {
    "pagePath": "/master-integration",
    "type": "to-be",
    "format": "html-tailwind",
    "sourceFile": "<absolute-path>/.projects/.../UX-001_master-data-integration/to-be/dashboard.html",
    "skipForgeIteration": false,
    "uxRef": "UX-001"
  }
]
```

`skipForgeIteration: false` — aidp-os의 FORGE 3-pass 개선은 여전히 적용 (HTML이 아직 미완성일 수 있음).
`skipForgeIteration: true` — UX frontmatter `status: approved`인 경우 자동 설정 (시간 절약).

---

### Step 2: `CLAUDE.md` 생성 (자동 사냥의 진짜 입력)

aidp-os가 코딩 에이전트(Claude Code)에게 전달할 프로젝트별 지시사항. 이게 20시간 자동 사냥의 품질 상한선을 결정한다.

#### 구조

```markdown
# <project-name> — 도메인 규칙 + 환각 방지 가이드

> 이 문서는 lifecycle-to-brief가 자동 생성. 수동 편집 시 다음 합성 때 덮어쓰임.
> 영구 변경은 .projects/<name>/의 해당 phase 파일을 수정 후 재합성.

## 1. 사업 컨텍스트

<TB 최상위.개선 배경 섹션 그대로>

## 2. 검증된 Pain Points (인터뷰 verified만)

> AS-NNN의 verified=true fact만. proposed/unverified는 §6에 별도.

### {AS-001} 수입 발주 프로세스 현황
- {verified fact 1} (출처: AS-001 §X)
- {verified fact 2} (출처: AS-001 §Y)
...

## 3. 도메인 용어집

| 용어 | 정의 | 사용 맥락 | 출처 |
|---|---|---|---|
| {AS-NNN/sources의 _glossary.md 또는 본문에서 추출} | ... | ... | AS-NNN |

## 4. 절대 잊지 말아야 할 엣지케이스

> AS-NNN의 "예외" 또는 "엣지케이스" 섹션 verified만.

- {edge case 1}: 발생 조건 → 처리 방식 (출처)
...

## 5. RBAC (권한 모델)

> 22.access_control/ROLE-*.md 합성

| Role | 권한 범위 | 화면 접근 | 출처 |
|---|---|---|---|
| {ROLE-001 code: SUPER_ADMIN} | 전체 | * | ROLE-001 |
...

## 6. 핵심 차단 요인 (TB의 횡단 미구현 패턴)

> TB의 "핵심 차단 요인" 표 그대로. 이 5가지가 모든 의사결정의 우선순위 기준.

| # | 차단 요인 | 영향 | 심각도 | TB 설계 영향 |
|---|---|---|---|---|
{TB-001의 표 복사}

## 7. 외부 시스템 연동 제약

> AS-NNN의 "시스템별 역할 현황" 표 합성.

| 시스템 | 현재 역할 | 한계 | 제약 |
|---|---|---|---|
...

## 8. 환각 방지 규칙 (자동 사냥 시 반드시 준수)

코딩 에이전트는 다음을 절대 하지 말 것:

- ❌ AS의 verified=true fact 외 인용 금지 (proposed/unverified는 "추정" 마킹 필수)
- ❌ TB의 "핵심 차단 요인" 5개 외 새 차단 요인 발명 금지
- ❌ IMP의 "구현 필요 기능" AC 외 새 요구사항 추가 금지
- ❌ §3 도메인 용어집 외 새 용어 도입 금지 (필요 시 99.requests CHG 발의)
- ❌ §5 RBAC 외 권한 정책 변경 금지
- ❌ 모든 phase 파일 수정 시 change_log entry 필수 (date, request_id, description)

위반 시 phase-validator가 PR을 reject 한다.

## 9. 변경 절차 (자동 사냥 도중)

추가 요구사항이나 명세 변경이 필요한 경우:
1. 99.requests/ 에 CHG-NNN 파일 작성
2. 영향받는 phase 파일의 change_log에 request_id 추가
3. 본문 수정
4. /phase-validator 통과 확인
5. 그 후에야 코드 변경

## 10. 진행 상태 (참고)

> 80.project_management/_overview.md 스냅샷 (자동 사냥 시작 시점)

WBS-001 진척률: {N}%
{블로커 목록}
```

#### 합성 규칙

- §2 Pain Points: AS-NNN.body에서 "Pain Points" 또는 "비효율" 또는 "현행 한계" 헤더 아래 verified 마킹된 항목만.
- §3 Glossary: AS-NNN의 sources/_glossary.md 또는 본문 표에서 "용어/정의" 컬럼.
- §4 Edge cases: AS-NNN의 "예외", "엣지케이스", "이슈", "리스크" 헤더.
- §5 RBAC: ROLE-*.md의 frontmatter `code` + body 권한 매트릭스 row 합성.
- §6: TB-001 또는 가장 최상위 TB의 "핵심 차단 요인" 표 그대로.
- §7: AS-NNN의 "시스템별 역할 현황" 표 + AS-NNN의 sources에 명시된 외부 시스템.
- §10: PM `_overview.md` 의 진척률/블로커 표.

총 길이 cap: **8000 토큰** (약 2만자). 초과 시 §2/§4/§5의 항목 수를 verified 우선순위로 잘라냄.

---

### Step 3: `.omc-team-pool.json` 생성

OMC team의 swarm/team 모드가 atomic claim 가능한 task pool 포맷.

#### 구조

```json
{
  "schema_version": "1.0",
  "project": "<project-name>",
  "generated_at": "2026-04-30T22:00:00Z",
  "source": {
    "wbs": "80.project_management/wbs/WBS-001_overall/WBS-001_overall.md",
    "timeline": "80.project_management/timeline/TL-001_overall/TL-001_overall.md",
    "dashboard": "_dashboard.md"
  },
  "claim_protocol": {
    "atomic_field": "claimed_by",
    "claimed_at_field": "claimed_at",
    "timeout_minutes": 60,
    "max_concurrent_per_worker": 1,
    "context_load_strategy": "auto-from-refs"
  },
  "validation_hook": {
    "command": "/phase-validator --since=task-start --strict",
    "on_fail": "rollback-and-feedback"
  },
  "tasks": [
    {
      "id": "WBS-001-T26",
      "title": "outbox cron 복구 + nWMS 입고지시 자동 발송",
      "wbs_status": "blocked",
      "claim_status": "available",
      "claimed_by": null,
      "claimed_at": null,
      "estimate": "5d",
      "estimate_hours": 40,
      "milestone_ref": "MS-008",
      "milestone_title": "통합 재고 연동 오픈",
      "milestone_due": "2026-04-27",
      "milestone_status": "at_risk",
      "priority_score": 0.92,
      "blocked_by": ["CHG-001"],
      "refs": ["IMP-001", "REQ-009"],
      "context_files": [
        ".projects/.../40.implementation_plans/IMP-001_nwms-interface-implementation/IMP-001_nwms-interface-implementation.md",
        ".projects/.../10.requirements/REQ-009-S02.md"
      ],
      "domain_rules_file": ".aidp/CLAUDE.md",
      "completion_protocol": {
        "on_done": [
          "Update WBS-001-T26.status to 'done'",
          "Update WBS-001-T26.completed_at to today",
          "Update WBS-001-T26.actual",
          "Append change_log entry to WBS-001 with this task id",
          "Run /phase-validator"
        ]
      }
    }
  ],
  "milestones": [
    {
      "id": "MS-008",
      "title": "통합 재고 연동 오픈",
      "target_date": "2026-04-27",
      "status": "at_risk",
      "epic_refs": ["REQ-009"],
      "task_ids": ["WBS-001-T26", "WBS-001-T27", "WBS-001-T29"]
    }
  ],
  "blockers": [
    {
      "id": "CHG-001",
      "title": "outbox cron 미동작",
      "impact": "T26,T27,T29 blocked → MS-008 at_risk",
      "priority": "CRITICAL",
      "source_file": ".projects/.../99.requests/CHG-001.md"
    }
  ]
}
```

#### Priority Score 알고리즘

```python
def priority_score(task):
    score = 0.0

    # 1. Milestone urgency (0~0.5)
    days_to_due = (task.milestone_due - today).days
    if task.milestone_status == "delayed":
        score += 0.5
    elif task.milestone_status == "at_risk":
        score += 0.4
    elif task.milestone_status == "on_track" and days_to_due <= 7:
        score += 0.3
    elif task.milestone_status == "on_track" and days_to_due <= 14:
        score += 0.2
    else:
        score += 0.1

    # 2. Dependency weight (0~0.3)
    # downstream task 수에 비례
    n_downstream = count_tasks_blocked_by_this(task.id)
    score += min(0.3, n_downstream * 0.05)

    # 3. Estimate efficiency (0~0.1)
    # 작은 task일수록 빠른 dopamine — OMC team 사기 유지
    if task.estimate_hours <= 8:
        score += 0.1
    elif task.estimate_hours <= 24:
        score += 0.05

    # 4. Refs richness (0~0.1)
    # IMP/REQ 다수 참조 = 컨텍스트 풍부 = 환각 위험 ↓
    if len(task.refs) >= 3:
        score += 0.1
    elif len(task.refs) >= 1:
        score += 0.05

    # 5. Blocker penalty (∞)
    if task.blocked_by:
        return -1.0  # 절대 분배 금지

    return score  # 0~1.0
```

분배 룰:
- `priority_score >= 0.8`: 즉시 분배
- `0.5 <= score < 0.8`: 큐에 적재, 워커 가용 시
- `0 <= score < 0.5`: 보류 큐
- `score == -1.0`: blocker 해소 전까지 손대지 않음

#### Context Load 전략

OMC team 워커가 task를 claim하면, `context_files`의 파일들이 자동으로 워커의 컨텍스트에 적재된다 (read-only). 이 파일들이 워커의 진실 정본이며, 이 외의 정보는 **추정**으로 마킹해야 한다.

`domain_rules_file` (`.aidp/CLAUDE.md`)는 모든 task에 공통 적재. 환각 방지의 1차 방어선.

#### 완료 프로토콜

워커가 task를 끝내면 `completion_protocol.on_done`의 단계를 자동 실행:
1. WBS work_item.status를 doing → done
2. completed_at, actual 채우기
3. WBS-001 frontmatter의 change_log에 entry 추가
4. /phase-validator로 검증 (FAIL 시 rollback)

이 프로토콜은 OMC team의 워커 프롬프트에 자동 주입된다.

---

## 출력 디렉토리 구조

기본 출력 위치: `.aidp/`

```
.aidp/
├── brief.json                  # aidp-os 투입 (Step 1)
├── CLAUDE.md                   # 도메인 규칙 (Step 2)
├── omc-team-pool.json          # OMC team 투입 (Step 3)
├── _warnings.md                # 합성 중 발견된 누락/모호함
├── _trace.json                 # 입력 → 출력 매핑 trace (디버깅용)
└── README.md                   # 다음 단계 가이드 (자동 생성)
```

`_warnings.md` 예시:
```markdown
# 합성 경고

## WARN: TB-007의 "개선 방향 4"에 본문 없음
- 파일: .projects/.../30.to_be_directions/TB-007/...md
- 영향: serviceDescription에 해당 방향 누락
- 조치: TB-007에 본문 작성 후 재합성

## WARN: AS-013에 verified fact 0건
- 영향: CLAUDE.md §2에 AS-013 항목 없음
- 조치: AS-013 인터뷰 검증 진행
```

`_trace.json`: 출력의 모든 필드가 어느 입력 파일/라인에서 왔는지 trace. 환각 의심 시 인간이 검토 가능.

`README.md`: 다음 명령 가이드.

```markdown
# 다음 단계

## aidp-os 투입
\`\`\`bash
# aidp-os 웹 UI에서:
# 1. /projects 새 프로젝트 생성
# 2. .aidp/brief.json import
# 3. .aidp/CLAUDE.md를 CLAUDE.md 템플릿에 붙여넣기
# 4. /workspace 초기화
\`\`\`

## OMC team 자동 사냥 가동
\`\`\`bash
/oh-my-claudecode:team --pool=.aidp/omc-team-pool.json --claude-workers=4 --codex-workers=4 --duration=20h
\`\`\`

## 진행 모니터링
\`\`\`bash
# 진척률 갱신
/lifecycle-to-brief <project> --refresh-status

# 다시 합성 (phase 변경 후)
/lifecycle-to-brief <project>
\`\`\`
```

---

## 합성 후 자동 검증 (Sanity Check)

생성된 산출물이 자체 무결성 규칙을 만족하는지 자동 검증:

| 체크 | 룰 |
|---|---|
| brief.json schema | aidp-os Project 스키마 매치 |
| brief.json.menuTree | 최대 깊이 ≤ 4 |
| brief.json.pages | 모든 page가 menuTree 노드와 매칭 |
| brief.json.features | 모든 feature가 page 또는 imp에 매핑 |
| CLAUDE.md | 8000 토큰 이내 |
| omc-team-pool.json | 모든 task의 refs가 실제 파일과 매칭 |
| omc-team-pool.json | priority_score 0~1 범위 (blocker 제외) |
| 추적성 | brief.json의 모든 페이지가 UX/IMP refs 보유 |

실패 시 `_warnings.md`에 추가 + 사용자에게 보고.

---

## OMC Team 통합 사용 패턴

### 추천 워커 구성 (8 에이전트)

| 워커 | 역할 | 전문성 |
|---|---|---|
| Claude #1 (opus) | Architect | TB 일관성 검증, 신규 IMP 작성 |
| Claude #2 (opus) | Implementer-A | 백엔드 (API, DB, 비즈니스 로직) |
| Claude #3 (sonnet) | Implementer-B | 프론트엔드 (React, UI) |
| Claude #4 (sonnet) | Tester | Playwright E2E, 검증 |
| Codex #1 | Implementer-C | 백엔드 보조 (병렬) |
| Codex #2 | Implementer-D | 프론트엔드 보조 (병렬) |
| Codex #3 | Refactorer | quality-loop, simplify |
| Codex #4 | Doc-writer | UG, change_log, 진행 보고 |

분배 정책:
- priority_score ≥ 0.8 → Claude opus 워커 (#1, #2)
- 0.5 ≤ score < 0.8 → Claude sonnet 또는 Codex
- 작은 task (≤8h) → Codex (속도 우선)
- 검증 작업 → Claude #4 전담

### 자동 사냥 루프

```
[20시간 시작]
    ↓
while (pool에 available task 있음 && 시간 남음):
    워커별 priority_score 최고 task claim
        ↓
    워커 실행 (context_files 자동 적재)
        ↓
    완료 시 /phase-validator --strict
        ↓
    PASS → completion_protocol.on_done 실행
    FAIL → task 회수, feedback 전달, 재시도 (max 2회)
        ↓
[20시간 종료 또는 모든 task done]
    ↓
최종 보고 (변경된 파일, 진척률, 미해결 task, 블로커)
```

---

## 환각 방지의 종합 메커니즘

`lifecycle-to-brief` + `phase-validator` + `CLAUDE.md`가 함께 작동하는 환각 방지 시스템:

| 게이트 | 책임 |
|---|---|
| 1. 사전 검증 | phase-validator가 입력 무결성 보장 |
| 2. 합성 보존 | lifecycle-to-brief가 정보 추가/변형 안 함 (변환만) |
| 3. context 강제 | OMC team이 task의 refs만 컨텍스트로 사용 |
| 4. CLAUDE.md 규칙 | 워커가 §8 환각 방지 규칙 명시적 따름 |
| 5. 사후 검증 | task 완료 시 phase-validator로 변경 검증 |
| 6. trace 가능 | _trace.json으로 모든 출력의 출처 역추적 |
| 7. 변경 제약 | TB/IMP 보호 섹션은 99.requests CHG 경유 강제 |
| 8. fact attribution | verified/proposed/unverified 구분 강제 |

이 8중 방어가 20시간 자동 사냥에서 환각이 새 명세를 만들어 자기 인용하는 패턴을 차단한다.

---

## 한계

이 스킬이 **하지 않는** 것:

1. **인터뷰 진행**: 직접 인터뷰 하지 않음. AS-NNN이 채워져 있어야 함 (별도 스킬 또는 사람).
2. **품질 평가**: TB의 "개선 방향"이 사업적으로 옳은지 판단 안 함.
3. **코드 생성**: aidp-os에 위임. 이 스킬은 입력만 만듦.
4. **OMC team 실행**: 별도로 `/oh-my-claudecode:team` 호출 필요.
5. **외부 PMS sync**: WBS의 `pms_uuid`로 외부 PMS 동기화는 별도 도구.

---

## 예시 실행

```bash
# som-erp 프로젝트를 변환
$ /lifecycle-to-brief som-integrated-erp

# 출력:
[STEP 0] phase-validator --strict
  PASS: 142 / FAIL: 0 / WARN: 8 / INCONCLUSIVE: 1
  진행 ✓

[STEP 1] brief.json 생성
  - Project: SOM 통합 ERP
  - MenuTree: 32 nodes (depth 4)
  - Pages: 47
  - Features: 332 (PASS=79, PARTIAL=94, FAIL=159)
  - Wireframes: 6 (UX-001 to-be import)

[STEP 2] CLAUDE.md 생성
  - Pain Points: 38 verified
  - Glossary: 156 terms
  - Edge cases: 24
  - RBAC roles: 8
  - 핵심 차단 요인: 5
  - 길이: 5,847 토큰

[STEP 3] omc-team-pool.json 생성
  - Tasks: 51 (todo=18, doing=14, done=16, blocked=3)
  - Milestones: 23
  - Blockers: 1 (CHG-001 CRITICAL)
  - 평균 priority_score: 0.62

[STEP 4] sanity check
  PASS

산출물 위치: .aidp/
├── brief.json (47KB)
├── CLAUDE.md (32KB)
├── omc-team-pool.json (18KB)
├── _warnings.md (3건)
├── _trace.json (89KB)
└── README.md

다음 단계: .aidp/README.md 참조

⚠ 주의: blocker 1건(CHG-001) 미해결. OMC team 가동 전 처리 권장.
```
