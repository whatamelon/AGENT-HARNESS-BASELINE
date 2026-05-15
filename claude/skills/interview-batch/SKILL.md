---
name: interview-batch
description: "여러 명·여러 일·여러 부서의 고객 인터뷰 transcript를 일괄 통합 분석한다. interview-to-phase가 단일 transcript 1건 추출용이라면 이 스킬은 4일 동안 8명을 인터뷰해서 N건의 transcript이 쌓였을 때의 통합 분석 어댑터. 토픽 클러스터링, 인터뷰이 간 모순 탐지(같은 fact를 다르게 진술하는 곳=암묵지 골드존), 합의/단독 항목 분류, 메타 검증 체크리스트(부서 간 비교)를 자동 생성한다. 4일 사이클(Day N 처리 → Day N+1 보강 질문)을 cron으로 돌릴 수 있다. 사용자가 '4일 인터뷰', '다중 인터뷰 통합', '인터뷰 batch', 'transcript batch', '부서 간 인터뷰', '인터뷰이 간 모순', '암묵지 분화 탐지', '메타 검증', 'cross-interview', 'AS 통합 작성', '인터뷰 N건 분석', 'interview cluster', '암묵지 분기점', 'multi-interview' 등을 언급하거나, .interviews/ 폴더에 N건 이상의 transcript가 누적된 경우 반드시 이 스킬을 사용한다."
---

# /interview-batch — 다중 인터뷰 통합 분석기

## 역할

`interview-to-phase`가 transcript 1건 → AS-NNN 1개를 만든다면, 이 스킬은 **4일·8명·30시간** 분량의 transcript 무더기를 받아 **인터뷰이 간 합의/모순/공백을 가시화**하고 통합 AS-NNN을 만든다. AX 컨설팅 4일 인터뷰 시나리오의 핵심 어댑터.

가장 큰 가치는 "**같은 fact에 대한 인터뷰이별 진술 차이**"를 자동 탐지하는 것 — 이게 진짜 암묵지가 분화된 지점이고, AX 자동화의 결정적 입력이다.

## 핵심 원칙

1. **단일 transcript 처리는 위임**: 각 transcript는 `interview-to-phase extract`로 먼저 처리되어 AS draft + extraction-notes가 생성된 상태를 가정. 본 스킬은 그 위에서 동작.
2. **모순은 보존, 해소는 인간**: 모순 발견 시 자동으로 한쪽을 선택하지 않는다. 양쪽 모두 보존하고 메타 검증 체크리스트로 인간(도메인 책임자)에게 escalate.
3. **부서 간 보호막**: 부서별로 진술 강도/관점이 다르므로 클러스터링 시 부서 메타데이터 보존.
4. **점진 누적**: Day 1~4 매일 호출 가능. 새 transcript이 추가되면 기존 분석 결과에 병합 (덮어쓰지 않음).
5. **검증 가능한 합의도**: 1명 진술 = `proposed`, 2~3명 동일 진술 = `in_review`, 4명 이상 = `verified` 후보. 단 자동 verified 승급은 금지 (인간 확인 필수).

## 호출 방법

```
# 모드 1: 일괄 통합 분석 (전체 누적 transcript 처리)
/interview-batch analyze --project=<name> [--day=N] [--since=<date>]

# 모드 2: 다음 인터뷰 보강 질문 생성 (Day N 결과 → Day N+1 PREP)
/interview-batch next-prep --project=<name> --gaps-from=<day-N-summary>

# 모드 3: 메타 검증 체크리스트 (부서 간 비교)
/interview-batch meta-verify --project=<name> --as=<AS-NNN> --recipient=<role>

# 모드 4: 합의도 리포트 (현재까지 verified/in_review/proposed 통계)
/interview-batch consensus-report --project=<name>

# 모드 5: 매일 자동 사이클 (cron 또는 Hermes scheduled)
/interview-batch daily-cycle --project=<name>
# = analyze + next-prep + consensus-report 묶음
```

## 사전 가정 (입력 상태)

본 스킬을 호출하기 전에:

```
.interviews/<project>/
├── <date>_<topic>_<interviewee>/
│   ├── transcript.md              ← Whisper/Hermes 결과
│   ├── audio/                     ← 원본 음성 (참조용)
│   └── ... (PREP.md 등)
├── ...
└── _index.json                    ← 본 스킬이 관리

.projects/<project>/20.as_is_analysis/
├── AS-NNN_<topic>/                ← interview-to-phase 결과 (각 인터뷰별 draft)
│   ├── AS-NNN_<topic>.md
│   ├── sources/transcript_<date>.md
│   └── analysis/_extraction-notes.md
└── ...
```

각 AS-NNN은 **단일 인터뷰 기반 draft 상태**. 본 스킬이 통합하면 같은 토픽의 여러 AS draft를 1개로 병합하고, 모순/합의 노트를 추가한다.

---

## 모드 1 상세: `analyze` (일괄 통합)

### Step 0: 인덱스 빌드

```
.interviews/<project>/_index.json:
{
  "interviews": [
    {
      "id": "INT-001",
      "date": "2026-05-01",
      "interviewee": "김부장",
      "role": "무역팀 부장",
      "department": "무역팀",
      "duration_min": 88,
      "transcript_path": ".interviews/.../transcript.md",
      "as_draft_ids": ["AS-001"],
      "global_utterance_id_prefix": "Day1-I1"
    },
    ...
  ],
  "global_utterance_count": 2847,
  "topics_seen": ["수입 발주", "통관", "원가 관리", ...]
}
```

발언 ID는 글로벌 형식: `Day{N}-I{인터뷰번호}-U{발언번호}` (예: `Day2-I3-U156`)

### Step 1: 토픽 클러스터링

전체 transcript의 발언을 토픽 단위로 클러스터링.

기본 토픽 카테고리 (산업별 변형):
- 업무 흐름 (워크플로우)
- 의사결정 규칙
- 시스템/도구 사용
- Pain Points
- 엣지케이스
- 외부 협업
- 데이터 흐름
- KPI / 성과 지표

각 토픽 클러스터에 대해 발언 ID 매핑 + 해당 인터뷰이 목록 생성:

```
{
  "topic": "PO 등록 시점 결정",
  "interviewees": ["김부장", "박과장", "이대리"],
  "utterances": [
    "Day1-I1-U67", "Day1-I1-U89",
    "Day2-I3-U23", "Day2-I3-U156",
    "Day3-I5-U102"
  ],
  "as_drafts_touched": ["AS-001", "AS-005", "AS-016"]
}
```

### Step 2: Cross-Reference 분석

같은 토픽의 발언들을 인터뷰이별로 비교. LLM에게 다음 4가지 분류 요청:

| 분류 | 정의 | 처리 |
|---|---|---|
| **합의 (Consensus)** | 2명 이상 인터뷰이가 동일/유사한 fact 진술 | `in_review` 마킹 + 다음 검증 단계 후보 |
| **모순 (Contradiction)** | 같은 fact에 대해 2명 이상이 다른 진술 | `_contradictions.md`에 보존, 메타 검증 필수 |
| **단독 (Single-source)** | 1명만 진술 | `proposed` 마킹, 다른 인터뷰이 확인 필요 |
| **공백 (Gap)** | 토픽 범위 안인데 발언 자체 없음 | `_gaps.md`, 후속 인터뷰 대상 |

### Step 3: 통합 AS-NNN 작성/병합

같은 토픽의 여러 AS draft를 **단일 AS로 병합**:

```
.projects/<project>/20.as_is_analysis/AS-001_<topic>/
├── AS-001_<topic>.md           ← 통합 본문 (병합 결과)
├── sources/
│   ├── transcripts/
│   │   ├── Day1_김부장.md
│   │   ├── Day2_박과장.md
│   │   └── Day3_이대리.md
│   └── (고객 자료)
└── analysis/
    ├── _extraction-notes.md     ← 발언 ID 매핑 (글로벌)
    ├── _contradictions.md       ← 모순 노트
    ├── _consensus.md            ← 합의 매트릭스
    ├── _gaps.md                 ← 미답변 영역
    ├── _glossary-draft.md       ← 통합 용어집
    └── _review-checklist.md     ← 메타 검증 (부서별)
```

병합 본문 구조:

```markdown
---
id: AS-001
title: 수입 발주 프로세스 현황
phase: as_is_analysis
project: <project>
status: draft
fact_summary:
  verified: 0
  in_review: 14    # 2명 이상 합의
  proposed: 31     # 1명 단독
  unverified: 8    # LLM 추론 또는 모호
sources:
  interviews: [INT-001, INT-003, INT-005]
  customer_files: [...]
consensus_count: 14
contradiction_count: 6
gap_count: 4
upstream_refs: []
downstream_refs: []
change_log:
  - date: <today>
    description: "interview-batch v1: 3건 transcript 통합 (김부장/박과장/이대리)"
---

# AS-001 수입 발주 프로세스 현황

> ⚠ 통합 검증 미완. 합의 14 / 모순 6 / 단독 31 / 공백 4.
> 메타 검증 체크리스트: analysis/_review-checklist.md

## 합의된 사실 (in_review — 2명 이상 동일 진술)

### F-001 [in_review, 3명] PO 등록은 무역팀이 엑셀에 직접 기입
- 출처:
  - 김부장 (Day1-I1-U23): "저희가 수입일정 엑셀에 PO를 등록해요"
  - 박과장 (Day2-I3-U45): "PO는 무역팀이 엑셀로 관리"
  - 이대리 (Day3-I5-U12): "발주 등록은 우리가 엑셀에"
- 합의 강도: ★★★ (3/3)

### F-002 [in_review, 2명] 통관 정보는 통관대장에 별도 기록
...

## 모순 사항 (Contradictions — 별도 검증 필수)

### C-001 [contradiction, 2명] PO 마스터 정본의 위치
- 김부장 (Day1-I1-U67): "엑셀이 SSOT. SERP는 그냥 입고만 등록"
- 박과장 (Day2-I3-U89): "정식으로는 SERP가 SSOT인데 실무는 엑셀로 가요"
- 갈등 지점: 정책 vs 실무. 어느 쪽이 통합 ERP의 출발점이 되어야 하는가?
- 검증 대상: CFO 또는 무역팀장
- 영향: TB-001 정본 시스템 결정에 결정적

### C-002 [contradiction, 2명] Payment Term 기본값
- 김부장 (Day1-I1-U112): "T/T는 30일, 나머지는 60일"
- 이대리 (Day3-I5-U178): "공급사마다 다른데 보통 45일을 쓰는 것 같아요"
- 영향: 자동 발주 시스템의 기본 정책 결정

## 단독 진술 (proposed — 1명만 진술, 검증 필요)

### S-001 [proposed, 김부장] BL 분할 통관 시 별도 엑셀 시트 운영
- 출처: Day1-I1-U134
- 다른 인터뷰이가 언급 안 함 → 김부장 개인 처리 방식?
- 후속 질문: "BL 분할 시 어떻게 처리하시나요?" (박/이/다른 무역팀)

## 미답변 영역 (Gaps)

### G-001 야간/주말 PO 처리
- 누구도 답변 안 함 (4일 인터뷰 모두에서)
- 후속 인터뷰 대상: 야근하는 직원

### G-002 시스템 장애 시 백업 프로세스
- 김부장만 모호하게 답변, 다른 사람 미답
- 후속: IT팀 인터뷰 별도 필요

## 도메인 규칙 (암묵지 합의 — 강도 기준)

(R-001~Rxxx — 합의 강도별 정렬)
```

### Step 4: 합의도 산출 알고리즘

```python
def consensus_score(fact, all_utterances, total_interviewees):
    """0~1 사이의 합의 점수"""
    supporting_interviewees = unique_speakers(fact.utterances)
    contradicting_interviewees = unique_speakers(contradicting_utterances(fact))

    # 1. 진술자 수 비율
    support_ratio = len(supporting_interviewees) / total_interviewees

    # 2. 직접 인용 강도 (명시적 진술 vs 암시적)
    explicit_ratio = explicit_quotes(fact) / total_quotes(fact)

    # 3. 모순 페널티
    if contradicting_interviewees:
        contradiction_penalty = 0.5
    else:
        contradiction_penalty = 0

    score = support_ratio * 0.6 + explicit_ratio * 0.4 - contradiction_penalty
    return max(0, min(1, score))

# 매핑:
# score >= 0.7: in_review (자동 verified 후보, 단 인간 확인 필수)
# 0.4 <= score < 0.7: proposed (추가 인터뷰 또는 검증)
# score < 0.4: unverified (LLM 추론 또는 약한 단독 진술)
```

자동 `verified` 승급은 금지. `in_review`까지만 자동, 그 이후는 메타 검증 체크리스트(모드 3)로.

---

## 모드 2 상세: `next-prep` (다음날 보강 질문)

Day N 결과를 보고 Day N+1 인터뷰를 위한 PREP.md 자동 생성.

### Step 1: Day N의 갭/모순 추출

```
- _gaps.md → 답변 안 된 토픽
- _contradictions.md → 검증 필요 모순
- _consensus.md → 합의되었지만 약한 (support_ratio < 0.5) 항목
- _glossary-draft.md → 모호한 용어 (정의 없거나 출처 부족)
```

### Step 2: Day N+1 인터뷰이 매칭

다음 날 인터뷰이 명단(사용자 입력)을 받고, 각 인터뷰이가 답변하기 좋은 질문 매칭:

```
input: 박팀장 (관리팀, 회계 담당)
matches:
  - C-001 (PO 정본 시스템) — 회계 관점에서 어떻게 보는지
  - G-002 (시스템 장애 백업) — 회계 관리 차원에서
  - S-007 (분개 자동화) — 박팀장의 영역
```

### Step 3: PREP.md 생성 (`interview-to-phase prep` 호출)

기본 질문지에 보강 질문을 우선순위로 끼워넣음:

```markdown
# 인터뷰 사전 준비 — 박팀장 (Day 4, 회계 관점)

## 핵심 검증 항목 (이전 인터뷰에서 발견된 모순/공백)

### 모순 검증 (3건 — 우선순위 높음)
1. **PO 정본 시스템**: 김부장은 "엑셀이 SSOT", 박과장은 "정식은 SERP". 회계 관점에서 어느 쪽 데이터를 신뢰하시나요?
2. **Payment Term 기본값**: 30/45/60일 진술이 엇갈림. 회계 처리 시 어떤 기준을 사용하시나요?
...

### 공백 채움 (2건)
1. 시스템 장애 시 회계 처리 백업?
2. 월말 결산에서 미통관 PO 처리?

## 일반 흐름 (간소화 — 시간 절약)
이전 인터뷰에서 충분히 다뤄진 부분은 생략하고, 회계 고유 영역만:
- AR/AP 처리
- 분개 생성 시점
- 외화 환율 처리
...

## 시간 배분 (60분 단축)
- 0~5분: 라포 + 컨텍스트
- 5~25분: 모순 검증 (3건)
- 25~40분: 공백 채움 (2건)
- 40~55분: 회계 고유 영역
- 55~60분: 마무리
```

### Step 4: PREP 저장

`.interviews/<project>/<날짜>_<인터뷰이>/PREP.md` — 인터뷰 시작 직전 인터뷰어가 인쇄해서 들고 감.

---

## 모드 3 상세: `meta-verify` (부서 간 메타 검증)

기존 `interview-to-phase verify`는 인터뷰이 1인 검증. 이 모드는 **부서 책임자(CFO, 운영본부장 등)에게 부서 간 모순을 보여주고 결정 받는 체크리스트**.

### 출력

```markdown
# 메타 검증 체크리스트 — AS-001 수입 발주

> CFO/운영본부장님께
> 4일 인터뷰에서 부서 간 진술이 엇갈리는 항목이 6건 있습니다.
> 각 항목에 정답을 표시해 주세요. **소요 시간 약 15분**.

## 1. PO 정본 시스템 (Critical)

### 진술 비교
| 부서 | 인터뷰이 | 진술 |
|---|---|---|
| 무역팀 | 김부장 (12년) | "엑셀이 SSOT" |
| 영업관리팀 | 박과장 (8년) | "정식은 SERP, 실무는 엑셀" |
| 관리팀(회계) | 이부장 (15년) | "회계는 SERP만 신뢰" |

### 결정 옵션
- [ ] **A. 엑셀 = SSOT** (현행 실무 그대로)
- [ ] **B. SERP = SSOT** (정책 정합)
- [ ] **C. 통합 ERP가 SSOT** (TB-001 새 시스템)
- [ ] **D. 기타**: _____________

### 영향
- A → 통합 ERP는 엑셀 import 우선
- B → 엑셀 폐기, SERP 데이터 마이그레이션
- C → 엑셀/SERP 모두 마이그레이션, 양방향 sync 일시 운영

## 2. Payment Term 기본값 (Medium)
...

## 3~6 ...

## 결정 후 진행
회신 받으면 AS-001을 verified로 승급하고 TB-001 작성으로 넘어갑니다.
미결정 시 그 항목은 unverified로 남고 코드 생성 단계에서 사용자 입력 받습니다.
```

### 송신 채널

```
--out=email      → HTML 이메일 (테이블 정렬)
--out=slack      → Slack 블록 메시지
--out=pdf        → PDF (회의실 출력용)
--out=hermes     → Hermes Telegram/Signal로 발송 (맥미니 운영 시)
--out=markdown   → 기본 (사용자가 채널 결정)
```

---

## 모드 4 상세: `consensus-report` (합의도 리포트)

현재까지의 통합 분석 상태 요약. PM에게 매일 보고용.

```markdown
# AS-IS 분석 진척 리포트 — Day 3 종료 시점

## 전체

| 지표 | 값 | 변화 (Day 2 대비) |
|---|---|---|
| 누적 인터뷰 | 6명 (16h) | +2명 |
| 누적 발언 | 2,140건 | +680 |
| 추출된 fact | 287건 | +94 |
| 합의 (in_review) | 47 | +14 |
| 단독 (proposed) | 156 | +52 |
| 모순 | 18 | +6 |
| 공백 | 23 | +5 |

## 토픽별 커버리지

| 토픽 | 인터뷰이 수 | 합의 강도 |
|---|---|---|
| 수입 발주 (AS-001) | 3 | ★★★ 강함 |
| 통관 (AS-003) | 3 | ★★★ 강함 |
| 원가 관리 (AS-004) | 2 | ★★ 보통 |
| B2B 영업 (AS-005) | 2 | ★★ 보통 |
| 회계 (AS-012) | 1 | ★ 약함 (Day 4 박팀장 인터뷰 예정) |
| D2C 채널 (AS-011) | 0 | ❌ 미완 |

## 핵심 모순 (Critical 3건)

1. PO 정본 시스템 (3명 진술 엇갈림) — 메타 검증 필요
2. Payment Term 기본값 (2명) — 메타 검증 필요
3. nWMS 권한 정책 (2명) — IT팀 별도 확인 필요

## Day 4 인터뷰 권장 대상

- D2C 채널 담당자 (현재 0명) — 필수
- 회계팀 추가 1명 (현재 1명) — 권장
- IT팀 (시스템 장애/권한) — 권장
```

---

## 모드 5 상세: `daily-cycle` (cron 자동 실행)

Hermes의 scheduled automation으로 매일 22시 자동 실행:

```
hermes schedule create "매일 22시에 /interview-batch daily-cycle --project=som-erp 실행"
```

내부 동작:
1. `analyze` — 그날 추가된 transcript 통합 분석
2. `consensus-report` — 진척 리포트 생성
3. `next-prep` — 다음날 PREP.md 자동 생성 (인터뷰이 명단이 _index.json에 있을 때)
4. Slack/Telegram 알림 — "Day N 처리 완료, 진척률 X%, 모순 Y건"

cron 실패 시 Hermes가 재시도 + 사람에게 알림.

---

## 환각 방지 (interview-to-phase 6개 게이트 + 추가 4개)

기존 6개 게이트 + 본 스킬에서 추가:

| # | 게이트 | 작동 |
|---|---|---|
| 1~6 | (interview-to-phase 동일) | 발언 ID trace, verified 금지 등 |
| **7** | **글로벌 발언 ID** | 모든 fact는 `Day{N}-I{x}-U{y}` 매핑. 인터뷰 간 cross-ref 강제 |
| **8** | **합의 강도 보존** | 자동 verified 승급 절대 금지. in_review까지만 |
| **9** | **모순 보존 강제** | LLM이 "합리적인 쪽"을 자동 선택 시도 시 reject. 양쪽 보존만 허용 |
| **10** | **부서 메타 보존** | 클러스터링 시 인터뷰이의 부서/직급 메타데이터 잃지 않기 |

게이트 8~9 위반은 자동 사냥에서 가장 위험한 환각: "이 부장이 더 시니어니까 그 사람 말이 맞다" 같은 LLM의 권위 추론. 절대 금지.

---

## Hermes 호환 메모

본 스킬은 agentskills.io 표준을 따른다. Hermes에서 호출 가능:

```bash
hermes
> /interview-batch analyze --project=som-erp
```

Hermes의 빌트인 기능 활용:
- **음성 transcription**: 별도 transcript-pipeline 불필요
- **subagent 병렬**: 토픽 클러스터링/분류를 N개 subagent로 분할
- **scheduled cron**: daily-cycle 자동 실행
- **session search (FTS5)**: 과거 인터뷰 검색 — "지난주 김부장이 분개에 대해 뭐라 했지?"
- **메시징 게이트웨이**: meta-verify 체크리스트를 Telegram/Signal로 발송

---

## 한계

이 스킬이 **하지 않는** 것:

1. **단일 transcript 추출**: `interview-to-phase extract`에 위임
2. **음성 → 텍스트**: Hermes 또는 외부 Whisper에 위임
3. **인터뷰 진행**: 사람의 영역
4. **모순 자동 해소**: 인간 결정 (메타 검증) 필수
5. **사실 진위 판단**: "누가 맞나" 판정 안 함. 진술의 차이만 가시화.
6. **인터뷰이 신뢰도 평가**: 직급/경력 가중치 없음. 모두 동등.

---

## 종합 워크플로우

```
[Day 1]
  09:00~17:00  인터뷰 4건 (각 90분)
  17:00~18:00  Hermes로 음성 일괄 transcribe
  18:00       /interview-to-phase extract × 4 (병렬)
  19:00       /interview-batch daily-cycle --project=som-erp
  19:30       PM 보고: consensus-report 자동 메일
  20:00       Day 2 PREP.md 인쇄 (next-prep 결과)

[Day 2~3 동일 사이클]

[Day 4 종료]
  18:00       /interview-batch analyze --project=som-erp (최종)
  19:00       /interview-batch meta-verify --as=AS-001 --recipient=CFO --out=email
              (모순 6건 메타 검증 체크리스트 CFO에게 발송)
  
[Day 5 회수 후]
  /interview-to-phase verify --as=AS-001 (verified 승급)
  /phase-validator (무결성)
  → 자동 사냥 단계로 (project-lifecycle, lifecycle-to-brief, ...)
```

이 워크플로우면 30~40시간 인터뷰가 5일 안에 자동 사냥 가능 입력으로 변환된다.
