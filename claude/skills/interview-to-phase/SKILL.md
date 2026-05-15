---
name: interview-to-phase
description: "고객 직원 인터뷰 녹취(transcript)를 project-lifecycle의 phase 파일(00.organizations / 01.workflows / 20.as_is_analysis / 21.system_landscape / 22.access_control)로 변환한다. AX(AI Transformation) 컨설팅에서 직원의 암묵지(tacit knowledge)를 명시지(explicit knowledge)로 추출하는 핵심 어댑터. CTA(Cognitive Task Analysis), CDM(Critical Decision Method), Knowledge Audit, 5 Whys, Think-aloud 기법을 적용. fact 출처 trace, 인터뷰이 검증 체크리스트, 모순/공백 탐지를 자동 생성한다. 사용자가 '인터뷰 추출', '녹취 정리', 'transcript phase 변환', '암묵지 명시지화', '인터뷰 → AS', '직원 인터뷰 분석', 'tacit knowledge', 'CTA 분석', 'pain points 추출', '도메인 용어집 추출', '인터뷰 질문지 생성', '인터뷰 검증 체크리스트', 'AX 인터뷰', 'Whisper transcript 처리', '암묵지 추출' 등을 언급하거나, AS/SYS/ROLE phase가 비어있고 인터뷰 자료가 준비된 시점에 반드시 이 스킬을 사용한다."
---

# /interview-to-phase — 인터뷰 녹취 → Phase 산출물 변환기

## 역할

AX 컨설팅의 가장 어려운 단계 — **직원의 암묵지를 인터뷰로 꺼내서 lifecycle phase 파일로 정착**시키는 어댑터다. 인터뷰는 사람이 진행하지만, 사전 질문지 설계, 녹취 분석, phase 파일 작성, 인터뷰이 검증 체크리스트 생성을 자동화한다.

이 스킬의 출력이 `project-lifecycle`의 입력이 되고, 그 산출물이 `phase-validator`를 거쳐 `lifecycle-to-brief`로 흘러가 aidp-os/OMC team에 도달한다. 즉 **풀 자동화 파이프라인의 출발점**이다.

## 핵심 원칙

1. **암묵지는 직접 묻지 않는다**: "당신의 암묵지는 무엇입니까"는 답이 안 나온다. CTA/CDM/Knowledge Audit 같은 우회 기법으로만 추출된다.
2. **모든 fact는 출처를 갖는다**: phase 파일에 작성하는 모든 사실은 transcript의 어느 발언에서 왔는지 trace 가능해야 한다.
3. **추론과 발언을 구분한다**: LLM이 발언에서 추론한 것은 `proposed`, 발언 자체는 직접 인용으로 마킹.
4. **검증 없이 verified 없다**: 어떤 fact도 인터뷰이의 명시적 확인 없이 `verified`로 마킹되지 않는다.
5. **모순을 환영한다**: 인터뷰 중 발견된 모순/공백은 `_contradictions.md`에 별도 기록. 해소가 아니라 가시화가 목적.
6. **인터뷰이 시간을 절약한다**: 검증 체크리스트는 5분 이내 응답 가능하도록 설계.

## 호출 방법

이 스킬은 4가지 모드로 동작한다.

### 모드 1: 인터뷰 사전 준비 (`prep`)

```
/interview-to-phase prep --topic=<area> --interviewee-role=<role> --industry=<industry>
```

목적: 인터뷰 전 질문지 + 진행 가이드 생성.

출력: `.interviews/<date>_<topic>/PREP.md`

### 모드 2: Transcript 추출 (`extract`)

```
/interview-to-phase extract \
  --transcript=<file.md> \
  --topic=<area> \
  --interviewee=<name-or-role> \
  --project=<project-name> \
  [--sources=<dir>]    # 고객이 제공한 원본 자료 (XLSX/PDF/이미지)
```

목적: transcript에서 phase 파일 생성.

출력: `.projects/<project>/{00,01,20,21,22}/...` + `.interviews/<date>_<topic>/`

### 모드 3: 인터뷰이 검증 체크리스트 생성 (`verify`)

```
/interview-to-phase verify --as=<AS-NNN> [--out=<email|slack|markdown>]
```

목적: 작성된 AS phase 파일을 인터뷰이가 5분 안에 검토할 수 있는 체크리스트로 변환.

출력: `.interviews/<date>_<topic>/CHECKLIST_<AS-NNN>.md` (인쇄/이메일 가능 형태)

### 모드 4: 기존 phase 보완 (`enhance`)

```
/interview-to-phase enhance \
  --transcript=<new-transcript.md> \
  --target-as=<AS-NNN>
```

목적: 추가 인터뷰의 새 사실을 기존 AS에 병합 (덮어쓰지 않음, 변경 이력 보존).

---

## 모드 1 상세: 인터뷰 사전 준비

### 출력 PREP.md 구조

```markdown
# 인터뷰 사전 준비 — <topic>

## 인터뷰이
- 이름/역할: <interviewee-role>
- 산업: <industry>
- 예상 소요: 60~90분

## 인터뷰 목표
1. <topic> 영역의 AS-IS 프로세스 파악
2. 직원의 암묵지(매뉴얼에 없지만 모두 아는 규칙) 추출
3. Pain Points 식별
4. 이상치/엣지케이스 수집

## 진행 구조 (90분 기준)

| 시간 | 단계 | 기법 |
|---|---|---|
| 0~10분 | 라포 형성 + 컨텍스트 수집 | Open-ended |
| 10~25분 | 일반 흐름 파악 | Think-aloud |
| 25~50분 | 깊이 탐색 (CTA/CDM) | Critical Decision Method |
| 50~70분 | 암묵지 발굴 | Knowledge Audit |
| 70~85분 | 엣지케이스 수집 | "이 규칙이 안 통하는 경우?" |
| 85~90분 | 마무리 + 후속 약속 | Wrap-up |

## 질문 카드

### A. 라포 + 컨텍스트 (10분)
1. 이 일을 얼마나 오래 하셨어요?
2. 신입 시절 가장 어려웠던 부분은?
3. 지금은 하루를 어떻게 시작하시나요?

### B. 일반 흐름 (Think-Aloud, 15분)
4. <topic> 업무를 처음부터 끝까지 한 번 설명해 주세요. 마치 옆에서 신입이 보고 있다고 생각하시면서.
5. (피인터뷰자가 막히면) "방금 그 단계, 결정은 어떻게 하세요?"
6. 평소에 자주 쓰는 도구/시스템/엑셀 양식은?
7. (시스템 화면을 같이 보면서) 이 화면에서 가장 자주 누르는 버튼이 뭐예요?

### C. Critical Decision Method (25분)
> CDM 핵심: 어려운 의사결정 케이스를 회고시키며 추론 과정을 추출.

8. 지난 6개월 동안 가장 어려웠던 의사결정 케이스 1~2개를 들려주세요.
9. (각 케이스에 대해)
   - 그때 어떤 정보를 보고 있었어요?
   - 어떤 선택지가 있었고, 왜 그 옵션을 골랐어요?
   - 다시 돌아간다면 다른 결정 했을까요?
   - 그 결정의 결과는 어땠어요?
   - 비슷한 상황에서 다른 분은 다르게 결정할 것 같아요?
10. 신입에게 이 케이스를 가르친다면 어떻게 설명하시겠어요?

### D. Knowledge Audit (Klein 기법, 20분)
> 암묵지 골드존 — 매뉴얼에 없지만 모두 아는 것.

11. 이 일에서 매뉴얼에 안 적혀 있지만 다들 아는 규칙은?
12. 신입이 자주 틀리는 부분은? 왜 자주 틀려요?
13. "그냥 직감으로" 판단하는 부분이 있다면? 어떤 신호로 판단해요?
14. 이 일이 잘 되고 있는지/잘못되고 있는지 어떻게 알아채세요? 어떤 지표/감각?
15. 이 일을 잘 하는 사람과 못 하는 사람 차이는 뭐예요?

### E. 엣지케이스 + 5 Whys (15분)
16. 방금 말씀하신 규칙들이 안 통하는 예외 케이스가 있나요?
17. (예외에 대해) 그 예외는 왜 그렇게 처리하세요?
18. (답변에 대해) 그건 또 왜 그렇게요?
19. (5번 반복)
20. 이 분야에서 가장 사고가 많이 나는 시점/유형은?

### F. 마무리 (5분)
21. 지금 이 일에서 가장 답답한/비효율적인 부분은?
22. 만약 이 일의 일부를 자동화한다면 어디부터 자동화하면 좋을까요?
23. 다음에 더 깊이 얘기 나눌 만한 분야는?

## 인터뷰 진행 팁
- ❌ "이게 맞나요?" 같은 yes/no 질문 — 답이 굳어진다
- ✅ "그 결정은 어떻게 하세요?" — 추론 과정이 나온다
- ❌ AI/시스템 얘기 먼저 꺼내기 — 기술 편향이 들어간다
- ✅ 사람이 어떻게 일하는지 먼저, 시스템은 그 다음
- ❌ 메모하느라 눈 안 보기 — 라포 깨진다
- ✅ 녹음 동의 받고 메모는 키워드만

## 녹음 동의 스크립트
"오늘 인터뷰 내용을 녹음해도 될까요? 정리할 때 놓치는 부분이 없도록 하기 위해서고, 다른 분에게 공유하지 않습니다. 정리한 결과는 다시 보내드려서 확인 받겠습니다."
```

생성 시 LLM은 다음을 활용:
- 산업별 도메인 지식 (있으면 적용)
- 인터뷰이 직군별 변형 (영업/생산/회계/CS 별 질문 카드)
- 이전 인터뷰 결과(있으면)에서 후속 질문 추가

---

## 모드 2 상세: Transcript 추출

### 입력 형식

권장 transcript 포맷 (Whisper diarization 결과):
```
[00:01:23] 인터뷰어: 이 일을 얼마나 오래 하셨어요?
[00:01:30] 김부장: 한 12년 됐죠. 처음엔 신입으로 들어와서...
[00:02:45] 김부장: 저희는 PO를 받으면 일단 엑셀에 기록을 하는데, 그게 SERP에 입력하기 전에 검토를 거쳐야 해서...
```

타임코드와 화자 분리가 필수. 없으면 LLM이 1차 정리 후 진행.

### Step 0: Transcript 인덱싱

1. transcript를 읽고 발언 단위로 분할
2. 각 발언에 ID 부여 (`U1, U2, ...`)
3. 발언 분류:
   - **사실 진술** (FactStatement): "PO를 받으면 엑셀에 기록을 한다"
   - **의견/추측** (Opinion): "그게 비효율적이라고 생각해요"
   - **감정/Pain Point** (Pain): "이게 너무 답답해요"
   - **예외/엣지케이스** (Edge): "근데 이런 경우엔 다르게 해요"
   - **암묵지** (Tacit): "매뉴얼엔 없는데 다들 그렇게 해요"
   - **모순** (Contradiction): 이전 발언과 충돌
   - **공백** (Gap): 인터뷰어가 묻지 않은/대답하지 않은 영역

### Step 1: 조직 추출 (`00.organizations/`)

발언에서 조직 단위/팀/직책을 추출.

추출 패턴:
- "저희 팀은...", "...팀이랑 협업해요", "...본부에서 결재가 떨어져야"
- 조직도 그림이나 RACI 표가 transcript에 첨부됐으면 그것을 우선
- 모호하면 `proposed` 마킹 + `_contradictions.md`에 노트

생성 파일: `00.organizations/ORG-NNN_<slug>.md`

```yaml
---
id: ORG-NNN
title: <조직명>
phase: organizations
project: <project>
status: draft
created_at: <today>
updated_at: <today>
author: ""
upstream_refs: []
downstream_refs: []
tags:
  - org: <slug>
fact_summary:
  verified: 0
  in_review: 0
  proposed: <count>
  unverified: 0
sources:
  - interview: .interviews/<date>_<topic>/transcript.md
change_log:
  - date: <today>
    request_id: ""
    description: "interview-to-phase 자동 추출 (검증 미완)"
---

# ORG-NNN <조직명>

## 조직 개요

> 출처: U23, U45 (proposed)

- 조직 유형: <type or "추정">
- 상위 조직: <if mentioned>
- 핵심 역할: <one-liner>

## 관련 발언

| 발언 ID | 인용 | 추출된 사실 |
|---|---|---|
| U23 | "저희 팀은 영업관리팀인데..." | 영업관리팀 존재 (proposed) |
| U45 | "...팀장님이 결재를 하시면..." | 영업관리팀 팀장 직책 존재 (proposed) |

## 검증 필요 항목

- [ ] 정확한 조직명/약칭 (인터뷰이 확인)
- [ ] 상위/하위 조직 관계
- [ ] 인원 수
- [ ] 핵심 KPI
```

### Step 2: 워크플로우 추출 (`01.workflows/`)

발언에서 업무 흐름을 추출. Think-aloud 답변(질문 4)이 핵심 소스.

생성 파일: `01.workflows/WF-NNN_<level>-<slug>.md`

본문에 Mermaid flowchart 자동 생성:
```mermaid
flowchart LR
    A[PO 수령<br/>(엑셀 등록)] --> B[검토<br/>(팀장)]
    B --> C[SERP 입력]
    C --> D[입고 확인<br/>(물류팀)]
```

흐름 단계는 transcript에서 추출한 동사구를 그대로 사용. RACI 표는 발언 ID 매핑과 함께 추가.

```markdown
## 역할 및 책임 (RACI) — Proposed

> ⚠ 이 표는 인터뷰 발언에서 추정. 인터뷰이 검토 필요.

| 단계 | 영업관리팀 | 물류팀 | 회계팀 | 출처 |
|---|:-:|:-:|:-:|---|
| PO 등록 | **R/A** | I | - | U67 |
| 입고 확인 | C | **R/A** | I | U89 |
```

### Step 3: AS-IS 분석 (`20.as_is_analysis/`)

가장 풍부한 추출이 일어나는 단계. 폴더 구조:

```
20.as_is_analysis/AS-NNN_<topic>/
├── AS-NNN_<topic>.md       ← 메인 파일
├── sources/                 ← 원본 자료
│   ├── transcript_<date>.md   ← 원본 transcript 백업
│   ├── <customer-supplied-files>  ← --sources=<dir> 인자로 들어온 것
└── analysis/
    ├── _extraction-notes.md ← fact trace
    ├── _contradictions.md   ← 모순/공백 노트
    ├── _glossary-draft.md   ← 도메인 용어집 (proposed)
    └── _review-checklist.md ← 인터뷰이 검증 체크리스트
```

#### `AS-NNN_<topic>.md` 구조

```yaml
---
id: AS-NNN
title: <topic 한국어 제목>
phase: as_is_analysis
project: <project>
status: draft
created_at: <today>
updated_at: <today>
author: ""
fact_summary:
  verified: 0
  in_review: 0
  proposed: <count of FactStatement>
  unverified: <count of unclear>
upstream_refs:
  - REQ-NNN  # 매핑 가능 시
downstream_refs: []
sources:
  - interview: .interviews/<date>_<topic>/
  - customer_files: <if provided>
tags:
  - org: <ORG-NNN slug>
  - workflow: WF-NNN
change_log:
  - date: <today>
    request_id: ""
    description: "interview-to-phase 자동 추출 — 인터뷰이 검증 미완"
---

# AS-NNN <title>

> 출처: 인터뷰 <date> with <interviewee-role>
> 검증 상태: 🔴 미검증 (모든 fact가 proposed/unverified)

## 분석 대상

- 인터뷰이: <role> (<years>년 경력)
- 분석 범위: <업무 영역>
- 관련 시스템: SYS-NNN, SYS-NNN
- 관련 조직: ORG-NNN

## 현행 프로세스

### 전체 흐름 (Think-aloud 기반)

```mermaid
flowchart TD
    {Mermaid 자동 생성}
```

> 출처: U23~U67 (Think-aloud 답변)

### 단계별 업무 — Proposed

| # | 단계 | 담당 | 시스템 | 빈도 | 출처 |
|---|---|---|---|---|---|
| ① | PO 등록 | 무역팀 | 엑셀 | 일 5~10건 | U23 |
| ② | 검토 | 팀장 | 카카오워크 | 동일 | U45 |
| ... | | | | | |

## Pain Points (인터뷰 직접 인용)

> ⚠ 모든 항목 인터뷰이 검토 필수.

### P-001 [proposed] PO 등록 후 SERP 입력 이중 작업
- 직접 인용 (U67): "엑셀에 한 번 쓰고 SERP에 또 한 번 쓰는데 이게 진짜 시간 낭비예요"
- 발생 빈도: 매일 (proposed)
- 영향: 일 30분 손실 추정 (unverified)
- 추출 신뢰도: 높음 (직접 인용)

### P-002 [proposed] 통관 정보 부족 시 추측 발주
- 직접 인용 (U89): "통관이 언제 끝날지 모르니까 그냥 감으로 발주를 잡아요"
- ...

## 도메인 규칙 — 암묵지 (Knowledge Audit 추출)

> ⚠ 매뉴얼에 없는 규칙. 다른 직원에게도 확인 필요.

### R-001 [unverified] PO 등록 시 Payment Term 우선순위
- 직접 인용 (U112): "Payment Term이 없으면 그냥 비워둬요. 근데 보통은 60일이에요. T/T 거래는 30일이고."
- 추출된 if-then:
  - if (Payment Term 명시 없음) → 60일 가정
  - if (T/T 거래) → 30일 가정
- 검증 필요: 다른 무역팀원도 같은 규칙 적용?

## 엣지케이스

### E-001 [proposed] 분할 통관
- 직접 인용 (U134): "BL 하나에 PO 여러 개가 묶이거나, PO 하나가 BL 두세 개로 쪼개지기도 해요"
- 처리 방식: <인용에서 추출>
- 빈도: <answered or "unknown">

## 의사결정 분기 (CDM 추출)

### D-001 [proposed] 발주 시점 결정
- 케이스 (U178): "지난번에 환율이 많이 올라서 좀 미뤘는데, 결과적으로 더 올라서 손해 봤어요"
- 추론 과정:
  - 입력 정보: 환율, 재고, 리드타임
  - 의사결정 규칙: 정성적 판단 (정량 모델 부재)
  - 신호: <when do you decide?>

## 시스템별 역할 현황

| 시스템 | 역할 | 한계 | 출처 |
|---|---|---|---|
| sERP | 입고 등록 | PO 관리 불가 | U67, U89 |
| 엑셀 | PO 마스터 | 버전 충돌 위험 | U67 |
| 카카오워크 | 결재 | 데이터 연동 없음 | U45 |

## 검증 필요 항목 (인터뷰이 확인)

체크리스트 별도 파일: `analysis/_review-checklist.md` 참조.

핵심 항목:
- [ ] 단계별 업무 표가 실제 흐름과 일치
- [ ] Pain Points P-001~P-XXX 모두 동의
- [ ] 도메인 규칙 R-001~R-XXX 모두 동의
- [ ] 엣지케이스 E-001~E-XXX 발생 빈도 정정
```

#### `analysis/_extraction-notes.md` (Fact Trace)

```markdown
# 추출 노트

> 모든 fact의 발언 ID 매핑. 환각 의심 시 인간이 검토.

## 추출 통계
- 총 발언 수: <N>
- FactStatement: <count>
- Opinion: <count>
- Pain: <count>
- Edge: <count>
- Tacit: <count>
- Contradiction: <count>
- Gap: <count>

## Fact 매핑 표

| Fact ID | 본문 위치 | 발언 ID | 인용 | 분류 | 신뢰도 |
|---|---|---|---|---|:-:|
| F-001 | §단계별 업무 ① | U23 | "저희는 PO를 받으면 일단 엑셀에..." | FactStatement | 높음 |
| F-002 | §Pain Points P-001 | U67 | "엑셀에 한 번 쓰고 SERP에 또..." | Pain | 높음 |
| F-003 | §도메인 규칙 R-001 | U112 | "Payment Term이 없으면 그냥..." | Tacit | 중간 |
| F-004 | §엣지케이스 E-001 | U134 | "BL 하나에 PO 여러 개가..." | Edge | 높음 |

## LLM 추론 항목

> 직접 인용이 아니라 LLM이 추론한 것. 별도 검증 필수.

| 추론 ID | 본문 위치 | 근거 발언 | 추론 내용 | 추론 방식 |
|---|---|---|---|---|
| I-001 | §전체 흐름 (Mermaid) | U23+U45+U67 | 4단계 순차 흐름 | 시간 순 정렬 |
| I-002 | §Pain Points 영향 | U67 | "일 30분 손실" | 직원 발언에 시간 추정 추가 |

## 신뢰도 기준
- **높음**: 직접 인용, 한 발언에서 명확히 도출
- **중간**: 다수 발언 종합 필요, 또는 부분 추론
- **낮음**: 대부분 LLM 추론, 발언은 단편적
```

#### `analysis/_contradictions.md`

```markdown
# 모순/공백 노트

## 모순 (Contradictions)

### C-001: PO 등록 주체
- U23 (인터뷰이 발언): "저희 무역팀이 직접 등록해요"
- U89 (인터뷰이 발언): "...아 그건 영업관리팀이 등록할 때도 있고요"
- 해소 필요: 누가 정본 등록자? 아니면 둘 다 가능?

## 공백 (Gaps)

### G-001: 야간/주말 PO 처리
- 인터뷰에서 다뤄지지 않음
- 후속 인터뷰 필요

### G-002: 시스템 장애 시 백업 프로세스
- 질문은 했으나 답변 모호 (U156: "그땐 그냥 손으로...")
- 구체화 필요

## 데이터 부재 (Unverifiable)

### V-001: 일 처리 건수
- 인터뷰이 발언: "한 5~10건" (U23) — 정량 데이터 없음
- 검증 방법: sERP 로그 데이터 확인 또는 1주일 기록
```

#### `analysis/_glossary-draft.md`

```markdown
# 도메인 용어집 (Draft)

| 용어 | 영문/약칭 | 정의 | 사용 맥락 | 출처 |
|---|---|---|---|---|
| 무역팀 | - | 수입 발주 + 통관 담당 부서 | 사내 호칭 | U23 |
| PO | Purchase Order | 수입 발주 단위 | 영문 약칭 그대로 사용 | U23 |
| BL | Bill of Lading | 선하증권. 화물 운송 계약서 | 통관 시점 핵심 문서 | U134 |
| Payment Term | - | 대금 지급 조건 (60일/30일 등) | 발주 시 결정 | U112 |
| T/T | Telegraphic Transfer | 전신환 송금 | 결제 방식 중 하나 | U112 |
| SERP | - | 사내 ERP 시스템 (소문자 e의 약칭?) | 시스템 호칭 | U67 |

## 검증 필요
- [ ] SERP 정확한 명칭/대소문자
- [ ] 사내에서 통용되는 다른 약칭
- [ ] 같은 의미인데 다르게 부르는 단어
```

#### `analysis/_review-checklist.md` (인터뷰이용)

```markdown
# AS-NNN 검증 체크리스트

> <interviewee-name>님께
> 인터뷰 결과를 정리했습니다. **5분 안에** 확인해 주세요.
> 틀린 부분이 있으면 그 항목 옆에 한 줄로 정정 부탁드립니다.

## 1. 단계별 업무 (5단계)

- [ ] ① PO 등록 — 무역팀 — 엑셀
- [ ] ② 검토 — 팀장 — 카카오워크
- [ ] ③ ...
- [ ] ④ ...
- [ ] ⑤ ...

→ 빠진 단계나 틀린 담당이 있나요? _____________

## 2. Pain Points (5건)

- [ ] P-001: PO 등록 후 SERP 입력 이중 작업 (시간 낭비)
- [ ] P-002: 통관 정보 부족 시 추측 발주
- [ ] ...

→ 이 중에 동의 안 하시는 항목이 있나요? _____________
→ 이 외에 더 큰 Pain Point가 있나요? _____________

## 3. 매뉴얼에 없는 규칙 (3건)

- [ ] R-001: Payment Term 없으면 60일, T/T면 30일 가정
- [ ] R-002: ...
- [ ] R-003: ...

→ 다른 무역팀원도 같은 규칙으로 일하시나요? _____________

## 4. 엣지케이스 (4건)

- [ ] E-001: 분할 통관 — BL ↔ PO 다대다 매칭
- [ ] E-002: ...

→ 빠진 예외 케이스가 있나요? _____________

## 5. 우리가 놓친 것

- 야간/주말 PO 처리 방식?
- 시스템 장애 시 백업?
- 일 처리 건수 정확한 통계?

→ 위 질문들 중 답변 가능한 것 있으면 말씀 부탁드려요.

---

확인이 끝나면 이 체크리스트를 회신해 주세요.
회신 받으면 verified 상태로 phase 파일을 갱신하고, 시스템 설계로 넘어갑니다.
```

### Step 4: 시스템 현황 추출 (`21.system_landscape/`)

발언에서 언급된 외부/내부 시스템 추출. AS의 "시스템별 역할 현황" 표와 cross-ref.

생성 파일: `21.system_landscape/SYS-NNN_<system-slug>.md`

핵심 정보:
- 시스템명, 역할, 한계
- 라이프사이클 단계 (planning/partial/live/deprecated)
- 다른 시스템과의 인터페이스
- 데이터 정본 여부

전부 `proposed` 상태. 시스템 운영 부서 추가 인터뷰 또는 IT팀 검증 필요.

### Step 5: RBAC 추정 (`22.access_control/`)

가장 보수적으로 작성. 발언에서 권한 정책 직접 도출이 어렵기 때문.

생성 파일: `22.access_control/ROLE-NNN_<slug>.md`

```yaml
---
id: ROLE-NNN
title: <역할명>
code: <UPPER_SNAKE>
phase: access_control
status: draft
fact_summary:
  verified: 0
  proposed: 0
  unverified: <count>   # 대부분 unverified로 시작
---

# ROLE-NNN <역할명>

## 권한 매트릭스 — Unverified

> ⚠ 이 매트릭스는 인터뷰 발언에서 추정. RACI ≠ RBAC. IT팀/관리자 검증 필수.

| 화면/기능 | 조회 | 생성 | 수정 | 승인 | 출처 |
|---|:-:|:-:|:-:|:-:|---|
| PO 등록 | ✓ | ✓ | ✓ | - | U23 (RACI에서 추정) |
| ... | | | | | |

## 검증 필요
- [ ] 실제 시스템의 권한 설정과 일치 (IT팀 export)
- [ ] 권한 위임/대리 정책
- [ ] 부서장 부재 시 권한
```

---

### Step 6: 인덱스 갱신

추출 완료 시:

1. 각 phase의 `_overview.md` 갱신 (문서 상태 카운터)
2. `.interviews/<date>_<topic>/SUMMARY.md` 작성:
   - 인터뷰 메타 (일자, 인터뷰이, 소요)
   - 생성된 phase 파일 목록
   - 추출 통계 (FactStatement/Pain/Edge/Tacit 카운트)
   - 모순/공백/검증 미완 항목 카운트
   - 다음 액션 (검증 발송, 후속 인터뷰 대상)
3. `_dashboard.md` (프로젝트 최상위)에 entry 추가:
   ```
   - 2026-XX-XX: <interviewee-role> 인터뷰 → AS-NNN, ORG-NNN, WF-NNN 생성 (검증 미완)
   ```

---

## 모드 3 상세: 인터뷰이 검증 체크리스트

기존 AS 파일을 읽고 `_review-checklist.md`를 재생성한다 (인터뷰이가 답변하기 좋은 형태).

옵션:
- `--out=email`: 이메일 본문 형식 (HTML 가능)
- `--out=slack`: Slack 메시지 형식 (블록 단위)
- `--out=markdown`: 기본

검증 답변이 회수되면 다음 단계:
1. 답변 매핑: `[x]` 표시된 항목 → `verified`로 승급
2. 정정 사항이 있는 항목 → 본문 수정 + change_log entry
3. 추가 정보가 있는 항목 → AS에 새 fact 추가 (`proposed` → 검증 후 `verified`)
4. fact_summary 카운터 갱신
5. `change_log`에 검증 일자 + 인터뷰이 이름 기록

---

## 모드 4 상세: 기존 phase 보완

추가 인터뷰의 transcript를 기존 AS에 병합한다. **덮어쓰지 않는다**.

병합 규칙:
- 새 fact가 기존과 일치 → 신뢰도 ↑ (`proposed` 2회 매칭 시 `in_review` 승급)
- 새 fact가 기존과 다름 → `_contradictions.md`에 추가, 둘 다 보존
- 새로운 영역 → 새 섹션 추가, 출처 발언 ID 명시
- change_log에 병합 entry 추가

---

## 암묵지 추출 패턴 (LLM 휴리스틱)

LLM이 transcript를 분석할 때 다음 키워드/표현이 나타나면 특별히 표시:

### 암묵지 신호 (Tacit Knowledge Markers)
- "그냥 (직감으로/감으로/느낌으로)" → 정량화 안 된 의사결정 규칙
- "(다들/보통/원래) 그렇게 (해요/하죠/하니까)" → 사내 관습
- "매뉴얼엔 없는데/공식적으로는 아닌데" → 명시 안 된 규칙
- "신입은 자주 (틀려요/실수해요/모르더라고요)" → 학습 곡선
- "이상하게/괜히/왠지" → 추론 안 된 직관
- "(예외/특이/이런 경우)는 다르게" → 엣지케이스
- "옛날엔/예전엔/원래는" → 역사적 맥락
- "...라고 봐야죠/...아닐까요" → 가설 발언

### Pain Point 신호
- "답답해요/짜증나요/번거로워요"
- "(시간/노력/비용)이 (많이/너무) 들어요"
- "...하면 좋겠는데"
- "이게 (왜) 이렇게 돼야 하는지 모르겠어요"

### 모순 신호
- 같은 개념에 대한 다른 정의
- 시간/주체/순서 불일치
- "근데 (사실/실은/사실은)" 다음 발언

### 환각 위험 신호 (LLM 자기 검열)
- 인터뷰이가 안 말한 숫자를 말한 경우 → `unverified`
- 인터뷰이가 안 말한 시스템 이름을 말한 경우 → `unverified`
- "일반적으로 ERP에서는..." 같은 일반 지식 인용 → 출처 없음 → 본문 포함 금지

---

## Fact 분류 규칙

| 분류 | 조건 | 예시 |
|---|---|---|
| `verified` | 인터뷰이 검증 체크리스트에서 [x] 받음 | (모드 3 이후) |
| `in_review` | 2명 이상 인터뷰이가 같은 fact 진술 | "다들 60일이라고 해요" + 다른 인터뷰이도 동일 |
| `proposed` | 1명이 명시적으로 진술 (직접 인용 가능) | "PO를 받으면 엑셀에 등록해요" |
| `unverified` | LLM 추론, 발언 모호, 시스템 export 부재 | "일 5~10건" 추정치 |

추출 직후엔 `verified=0` 보장. `proposed`와 `unverified`만 존재.

---

## 환각 방지 메커니즘

이 스킬이 LLM 환각을 막는 6가지 게이트:

| # | 게이트 | 작동 방식 |
|---|---|---|
| 1 | 발언 ID trace | 모든 fact에 `Uxxx` 매핑 강제. trace 없으면 본문 진입 금지 |
| 2 | 직접 인용 우선 | 인용 가능한 사실은 인용 형태로. 추론은 별도 마킹 |
| 3 | verified 금지 | 추출 단계에서 verified 절대 발생 안 함 |
| 4 | 모순 가시화 | 충돌하는 발언은 둘 다 보존, 해소 강요 안 함 |
| 5 | 일반 지식 차단 | 인터뷰이가 말 안 한 도메인 지식 인용 금지 |
| 6 | 인터뷰이 루프 | 검증 체크리스트로 인터뷰이가 직접 차단 |

다음 단계의 `phase-validator`가 이 게이트들이 제대로 적용됐는지 검증한다.

---

## 한계

이 스킬이 **하지 않는** 것:

1. **인터뷰 진행**: 사람이 직접. 이 스킬은 사전 준비/사후 정리만.
2. **녹취 변환**: Whisper/Otter 등 외부 도구 필요. transcript는 입력으로 주어진다고 가정.
3. **다국어 처리**: 한국어 인터뷰 가정. 영문/혼용은 별도 보강 필요.
4. **음성 분석**: 톤/감정/말끝 흐림 등 비언어 신호 분석 안 함.
5. **사실 검증**: 발언이 진실인지 거짓인지 판단 안 함. 검증은 인터뷰이 + 다른 데이터 소스.
6. **인터뷰이 신뢰도 평가**: 모든 인터뷰이를 동등하게 대함.

---

## 예시 실행

### 사전 준비
```bash
$ /interview-to-phase prep \
    --topic="수입 발주 프로세스" \
    --interviewee-role="무역팀 부장" \
    --industry="유통/물류"

# 출력: .interviews/2026-04-30_import-procurement/PREP.md
# 인터뷰 시작 전 PREP.md 읽고 진행
```

### 추출
```bash
$ /interview-to-phase extract \
    --transcript=.interviews/2026-04-30_import-procurement/transcript.md \
    --topic="수입 발주 프로세스" \
    --interviewee="김부장" \
    --project=som-integrated-erp \
    --sources=.interviews/2026-04-30_import-procurement/customer-files/

# 출력:
# .projects/som-integrated-erp/00.organizations/ORG-006_무역팀.md
# .projects/som-integrated-erp/01.workflows/WF-020_lv2-import-procurement.md
# .projects/som-integrated-erp/20.as_is_analysis/AS-017_import-procurement-process/
#   ├── AS-017_import-procurement-process.md
#   ├── sources/transcript_2026-04-30.md
#   ├── sources/<customer-files>
#   └── analysis/{_extraction-notes,_contradictions,_glossary-draft,_review-checklist}.md
# .projects/som-integrated-erp/21.system_landscape/SYS-009_kakao-work.md
# .projects/som-integrated-erp/22.access_control/ROLE-006_trade-team-staff.md
# .interviews/2026-04-30_import-procurement/SUMMARY.md

# 추출 통계:
# - FactStatement: 47
# - Pain: 8
# - Edge: 5
# - Tacit: 12
# - Contradiction: 2
# - Gap: 4
# - 검증 필요 항목: 76
# 다음: /interview-to-phase verify --as=AS-017 → 김부장에게 발송
```

### 검증
```bash
$ /interview-to-phase verify --as=AS-017 --out=email

# 출력: .interviews/2026-04-30_import-procurement/CHECKLIST_AS-017.html
# 김부장에게 이메일 발송, 5분 안에 회신 가능
```

### 검증 답변 회수 후 (수동 또는 별도 모드)
체크된 항목을 verified로 승급, 정정 사항 반영, fact_summary 갱신.

### 보완 (2차 인터뷰)
```bash
$ /interview-to-phase enhance \
    --transcript=.interviews/2026-05-02_import-procurement-followup/transcript.md \
    --target-as=AS-017

# 새 발언이 기존 AS-017에 병합. _contradictions.md 갱신.
```

---

## 종합 워크플로우 (이 스킬 + 다음 단계)

```
[Day 1] /interview-to-phase prep   → 질문지 인쇄
[Day 1] (인터뷰 진행, 녹음)
[Day 1] (Whisper transcribe)
[Day 1] /interview-to-phase extract → AS/ORG/WF/SYS/ROLE 자동 생성
[Day 2] /interview-to-phase verify  → 인터뷰이에게 체크리스트 발송
[Day 3] (체크리스트 회수, verified 승급)
[Day 3] /phase-validator             → 무결성 검증
[Day 4] (TB/IMP/UX 작성 — /project-lifecycle)
[Day 5] /lifecycle-to-brief         → aidp-os 입력 + OMC team pool 생성
[Day 5] aidp-os + OMC team 가동      → 20시간 자동 사냥
[Day 6+] (배포, 검수)
```

총 5일 안에 인터뷰부터 자동 사냥 완료까지. 인터뷰이의 시간은 **인터뷰 90분 + 검증 5분**만 소비된다.
